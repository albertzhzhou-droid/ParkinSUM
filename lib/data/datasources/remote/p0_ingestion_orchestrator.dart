import 'dart:convert';

import '../../../domain/entities/cdss_records.dart';
import '../../../domain/usecases/clinical_decision_support_service.dart';
import '../../../domain/repositories/app_repository.dart';
import '../../../core/models/drug_definition.dart';
import '../../../core/models/food_item.dart';
import '../../models/interaction_rule_record.dart';
import 'china_cdc_food_platform_importer.dart';
import 'ciqual_p0_importer.dart';
import 'dailymed_p0_importer.dart';
import 'ema_p1_importer.dart';
import 'fdc_p0_importer.dart';
import 'fao_fbdg_p1_importer.dart';
import 'health_canada_dpd_p0_importer.dart';
import 'p0_import_models.dart';
import 'p0_import_support.dart';
import 'p0_source_urls.dart';
import 'pmda_p1_importer.dart';
import 'secondary_source_registry.dart';
import 'secondary_source_registry_importer.dart';
import 'catalog_interaction_audit.dart';
import 'locale_resource_seed_importer.dart';
import 'regional_seed_catalog_importer.dart';
import 'seed_catalog_importer.dart';
import 'source_fetch_client.dart';

/// 分阶段 checkpoint 名称：
/// - `fetch_completed`：bytes/HTML 已就位（远程或本地）；
/// - `bundle_parsed`：已解析为 [P0ImportBundle]；
/// - `promote_completed`：已写入 CDSS 数据库且 projected catalog 同步完成。
class P0IngestionCheckpoint {
  static const fetchPending = 'fetch_pending';
  static const fetchCompleted = 'fetch_completed';
  static const bundleParsed = 'bundle_parsed';
  static const promoteCompleted = 'promote_completed';
  static const failedBeforeFetch = 'failed_before_fetch';
  static const failedBeforeParse = 'failed_before_parse';
  static const failedBeforePromote = 'failed_before_promote';
}

/// 描述一个 import 任务的可重放输入。
///
/// - 本地路径包：保存原始路径与 bytes checksum，resume 时通过 [bytesSupplier] 重新读取；
/// - 远程任务：保存 URL/source key，resume 时直接调用 importer 的 fetch 路径。
class _ImportInputDescriptor {
  final String sourceKey;
  final String sourceLabel;
  final String inputKind; // 'local_bytes' | 'remote_fetch'
  final String? localPath;
  final String? checksum;
  final List<String> remoteUrls;
  final Map<String, Map<String, String>> Function() collectRemoteMetadata;
  final Future<P0ImportBundle> Function() buildBundle;

  const _ImportInputDescriptor({
    required this.sourceKey,
    required this.sourceLabel,
    required this.inputKind,
    required this.buildBundle,
    required this.collectRemoteMetadata,
    this.localPath,
    this.checksum,
    this.remoteUrls = const <String>[],
  });

  Map<String, Object?> toNotes({
    String? lastCompletedStage,
    bool cachedBundleAvailable = false,
  }) {
    final remoteMetadata = collectRemoteMetadata();
    final etags = remoteMetadata.values
        .map((entry) => entry['etag'])
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toList(growable: false);
    final lastModifiedValues = remoteMetadata.values
        .map((entry) => entry['last_modified'])
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toList(growable: false);
    final stableInputChecksum = checksum ??
        (remoteUrls.isEmpty
            ? null
            : stableHash('$sourceKey:${remoteUrls.join('|')}:$remoteMetadata'));
    final normalizedSourceUrl = remoteUrls.isNotEmpty
        ? remoteUrls.first
        : (localPath ?? '').isNotEmpty
            ? localPath
            : null;
    return <String, Object?>{
      'source_key': sourceKey,
      'importer_id': sourceKey,
      'input_kind': inputKind,
      if (localPath != null) 'local_path': localPath,
      if (normalizedSourceUrl != null) 'source_url': normalizedSourceUrl,
      if (remoteUrls.length == 1) 'remote_url': remoteUrls.single,
      if (stableInputChecksum != null) 'checksum': stableInputChecksum,
      if (remoteUrls.isNotEmpty) 'remote_urls': remoteUrls,
      if (etags.isNotEmpty) 'etag': etags.length == 1 ? etags.single : etags,
      if (lastModifiedValues.isNotEmpty)
        'last_modified': lastModifiedValues.length == 1
            ? lastModifiedValues.single
            : lastModifiedValues,
      if (remoteMetadata.isNotEmpty) 'remote_metadata': remoteMetadata,
      if (lastCompletedStage != null)
        'last_completed_stage': lastCompletedStage,
      'cached_bundle_available': cachedBundleAvailable,
    };
  }
}

/// P0 导入总控：
/// - 把多源 importer 串成单个可重复任务；
/// - 显式追踪 fetch / parse / promote 三个 stage；
/// - resume 时不会重复执行已完成的 stage，避免重复写入。
class P0IngestionOrchestrator {
  final ClinicalDecisionSupportService cdssService;
  final AppRepository? appRepository;
  final CiqualP0Importer ciqualImporter;
  final FdcP0Importer fdcImporter;
  final DailyMedP0Importer dailymedImporter;
  final HealthCanadaDpdP0Importer dpdImporter;
  final ChinaCdcFoodPlatformImporter chinaFoodImporter;
  final FaoFbdgP1Importer faoFbdgImporter;
  final EmaP1Importer emaImporter;
  final PmdaP1Importer pmdaImporter;
  final SecondarySourceRegistryImporter secondarySourceRegistryImporter =
      const SecondarySourceRegistryImporter();
  final SeedCatalogImporter seedCatalogImporter = const SeedCatalogImporter();
  final RegionalSeedCatalogImporter regionalSeedCatalogImporter =
      const RegionalSeedCatalogImporter();
  final LocaleResourceSeedImporter localeResourceSeedImporter =
      const LocaleResourceSeedImporter();

  /// Monotonic per-instance counter appended to `baseRunId` so back-to-back
  /// imports of the same source within the same microsecond cannot collide on
  /// `_pendingBundles` / `_completedReports` / `_inputDescriptors` keys.
  int _runSequence = 0;

  /// resumeToken → 已经成功 parse 但尚未 promote 的 bundle。
  /// promote 成功后会清空。
  final Map<String, P0ImportBundle> _pendingBundles =
      <String, P0ImportBundle>{};

  /// resumeToken → 已经 promote 完成的 report stub。
  /// 命中后 resume 直接返回成功，不再触发任何写入。
  final Map<String, P0OfflineImportStepReport> _completedReports =
      <String, P0OfflineImportStepReport>{};

  /// resumeToken → 输入描述符。
  final Map<String, _ImportInputDescriptor> _inputDescriptors =
      <String, _ImportInputDescriptor>{};

  final SourceFetchClient _fetchClient;

  P0IngestionOrchestrator({
    required this.cdssService,
    this.appRepository,
    required SourceFetchClient fetchClient,
  })  : _fetchClient = fetchClient,
        ciqualImporter = CiqualP0Importer(fetchClient: fetchClient),
        fdcImporter = FdcP0Importer(fetchClient: fetchClient),
        dailymedImporter = DailyMedP0Importer(fetchClient: fetchClient),
        dpdImporter = HealthCanadaDpdP0Importer(fetchClient: fetchClient),
        chinaFoodImporter =
            ChinaCdcFoodPlatformImporter(fetchClient: fetchClient),
        faoFbdgImporter = FaoFbdgP1Importer(fetchClient: fetchClient),
        emaImporter = EmaP1Importer(fetchClient: fetchClient),
        pmdaImporter = PmdaP1Importer(fetchClient: fetchClient);

  Future<P0ImportBundle> importCoreSources({
    required List<int> fdcIds,
    required String fdcApiKey,
    required List<String> dailyMedSetIds,
  }) async {
    var bundle = await ciqualImporter.fetchAndImport();
    for (final fdcId in fdcIds) {
      bundle = bundle.merge(
        await fdcImporter.fetchFoodDetail(apiKey: fdcApiKey, fdcId: fdcId),
      );
    }
    if (dailyMedSetIds.isNotEmpty) {
      bundle =
          bundle.merge(await dailymedImporter.fetchBySetIds(dailyMedSetIds));
    }
    bundle = bundle.merge(await dpdImporter.fetchAndImport());
    await cdssService.importBundle(bundle);
    await _syncProjectedCatalogs(bundle);
    return bundle;
  }

  Future<P0ImportBundle> importChinaSelectedFoods() async {
    final report = await importChinaSelectedFoodsDetailed();
    return report.bundle ?? const P0ImportBundle();
  }

  Future<P0OfflineImportStepReport> importChinaSelectedFoodsDetailed() {
    return _runRemoteSource(
      sourceKey: 'china_official_foods',
      sourceLabel: 'CHINA_CDC_FOOD_PLATFORM',
      remoteUrls: ChinaCdcFoodPlatformImporter.selectedFoodUrls,
      buildBundle: () => chinaFoodImporter.fetchSelectedFoods(),
      fetchClientForMetadata: _fetchClient,
    );
  }

  Future<P0ImportBundle> importFaoCountryDietProfile({
    required String countryCode,
    required String url,
  }) async {
    final bundle = await faoFbdgImporter.fetchCountryPage(
      countryCode: countryCode,
      url: url,
    );
    await cdssService.importBundle(bundle);
    await _syncProjectedCatalogs(bundle);
    return bundle;
  }

  Future<P0ImportBundle> importEmaMedicinesMetadata() async {
    final report = await importEmaMedicinesMetadataDetailed();
    return report.bundle ?? const P0ImportBundle();
  }

  Future<P0ImportBundle> importEmaPostAuthorisationMetadata() async {
    final report = await importEmaPostAuthorisationMetadataDetailed();
    return report.bundle ?? const P0ImportBundle();
  }

  Future<P0OfflineImportStepReport> importEmaMedicinesMetadataDetailed() {
    return _runRemoteSource(
      sourceKey: 'ema_medicines',
      sourceLabel: 'EMA',
      remoteUrls: const <String>[
        P0SourceUrls.emaMedicinesJson,
        P0SourceUrls.emaMedicinesXlsx,
      ],
      buildBundle: () => emaImporter.fetchAndImportMedicines(),
      fetchClientForMetadata: _fetchClient,
    );
  }

  Future<P0OfflineImportStepReport>
      importEmaPostAuthorisationMetadataDetailed() {
    return _runRemoteSource(
      sourceKey: 'ema_post_authorisation',
      sourceLabel: 'EMA',
      remoteUrls: const <String>[
        P0SourceUrls.emaPostAuthorisationJson,
        P0SourceUrls.emaPostAuthorisationXlsx,
      ],
      buildBundle: () => emaImporter.fetchAndImportPostAuthorisation(),
      fetchClientForMetadata: _fetchClient,
    );
  }

  Future<P0ImportBundle> importPmdaEnglishReferenceMetadata() async {
    final bundle = await pmdaImporter.fetchEnglishReferenceIndex();
    await cdssService.importBundle(bundle);
    await _syncProjectedCatalogs(bundle);
    return bundle;
  }

  Future<P0ImportBundle> importPmdaJapaneseSearchMetadata() async {
    final bundle = await pmdaImporter.fetchJapaneseSearchLanding();
    await cdssService.importBundle(bundle);
    await _syncProjectedCatalogs(bundle);
    return bundle;
  }

  Future<P0OfflineImportStepReport> resumeImportTask(String resumeToken) async {
    if (_completedReports.containsKey(resumeToken)) {
      return _completedReports[resumeToken]!;
    }
    final descriptor = _inputDescriptors[resumeToken];
    if (descriptor != null) {
      return _runWithDescriptor(
        descriptor: descriptor,
        baseRunId: resumeToken,
        cachedBundle: _pendingBundles[resumeToken],
      );
    }

    // 没有 in-process 描述符时，回退到 ingestion_run 表里的记录，沿用过去的入口。
    final rows = await cdssService.database.queryTable('ingestion_run');
    final matched = rows.where((row) {
      final notes = _safeDecodeMap('${row['notes_json'] ?? '{}'}');
      return notes['resume_token'] == resumeToken ||
          (notes['checkpoint'] is Map &&
              (notes['checkpoint'] as Map)['resume_run_id'] == resumeToken);
    }).toList(growable: false)
      ..sort(
        (left, right) => ((right['created_at'] as num?)?.toInt() ?? 0)
            .compareTo((left['created_at'] as num?)?.toInt() ?? 0),
      );
    if (matched.isEmpty) {
      return P0OfflineImportStepReport(
        sourceKey: 'unknown',
        sourceLabel: 'unknown',
        succeeded: false,
        errorMessage: 'No resumable import task found for $resumeToken',
        checkpoint: 'resume_lookup_failed',
        resumeToken: resumeToken,
      );
    }
    final notes = _safeDecodeMap('${matched.first['notes_json'] ?? '{}'}');
    final sourceKey = '${notes['source_key'] ?? ''}';
    switch (sourceKey) {
      case 'ema_medicines':
        return importEmaMedicinesMetadataDetailed();
      case 'ema_post_authorisation':
        return importEmaPostAuthorisationMetadataDetailed();
      case 'china_official_foods':
        return importChinaSelectedFoodsDetailed();
      default:
        return P0OfflineImportStepReport(
          sourceKey: sourceKey.isEmpty ? 'offline_source' : sourceKey,
          sourceLabel: '${matched.first['source_family'] ?? 'offline_source'}',
          succeeded: false,
          errorMessage:
              'This checkpoint needs the original local package path or bytes before it can resume.',
          attempts: (notes['attempt'] as num?)?.toInt() ?? 0,
          checkpoint: '${notes['checkpoint'] ?? 'manual_resume_required'}',
          resumeToken: resumeToken,
        );
    }
  }

  Map<String, dynamic> _safeDecodeMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return const <String, dynamic>{};
  }

  Future<P0ImportBundle> importOfflinePackages({
    List<int>? ciqualArchiveBytes,
    List<int>? fdcZipBytes,
    List<int>? dailyMedZipBytes,
    List<int>? dpdZipBytes,
    Map<String, String>? sourcePaths,
  }) async {
    final reports = await importOfflinePackagesDetailed(
      ciqualArchiveBytes: ciqualArchiveBytes,
      fdcZipBytes: fdcZipBytes,
      dailyMedZipBytes: dailyMedZipBytes,
      dpdZipBytes: dpdZipBytes,
      sourcePaths: sourcePaths,
    );
    var bundle = const P0ImportBundle();
    for (final report in reports.where((item) => item.bundle != null)) {
      bundle = bundle.merge(report.bundle!);
    }
    return bundle;
  }

  Future<List<P0OfflineImportStepReport>> importOfflinePackagesDetailed({
    List<int>? ciqualArchiveBytes,
    List<int>? fdcZipBytes,
    List<int>? dailyMedZipBytes,
    List<int>? dpdZipBytes,
    Map<String, String>? sourcePaths,
  }) async {
    final results = <P0OfflineImportStepReport>[];
    if (ciqualArchiveBytes != null) {
      results.add(await _runLocalSource(
        sourceKey: 'ciqual',
        sourceLabel: 'CIQUAL',
        bytes: ciqualArchiveBytes,
        localPath: sourcePaths?['ciqual'],
        parse: (b) async => ciqualImporter.importArchiveBytes(b),
      ));
    }
    if (fdcZipBytes != null) {
      results.add(await _runLocalSource(
        sourceKey: 'fdc',
        sourceLabel: 'FDC',
        bytes: fdcZipBytes,
        localPath: sourcePaths?['fdc'],
        parse: (b) async =>
            fdcImporter.importZipBytes(b, sourceLabel: 'fdc_bulk_zip'),
      ));
    }
    if (dailyMedZipBytes != null) {
      results.add(await _runLocalSource(
        sourceKey: 'dailymed',
        sourceLabel: 'DAILYMED',
        bytes: dailyMedZipBytes,
        localPath: sourcePaths?['dailymed'],
        parse: (b) async => dailymedImporter.importZipBytes(b),
      ));
    }
    if (dpdZipBytes != null) {
      results.add(await _runLocalSource(
        sourceKey: 'dpd',
        sourceLabel: 'HEALTH_CANADA_DPD',
        bytes: dpdZipBytes,
        localPath: sourcePaths?['dpd'],
        parse: (b) async => dpdImporter.importZipBytes(b),
      ));
    }
    return results;
  }

  /// Register the P1/P2/P3 secondary-source catalog as `source_document` rows
  /// only. This is opt-in and does not fetch upstream content; each entry is
  /// recorded with its tier, organization, license, and an explicit audit_gap
  /// for the unparsed body. Returns the bundle that was promoted.
  Future<P0ImportBundle> importSecondarySourceCatalog({
    List<SecondarySourceDeclaration>? declarations,
  }) async {
    final bundle = secondarySourceRegistryImporter.importDeclaredCatalog(
      declarations: declarations,
    );
    await cdssService.importBundle(bundle);
    return bundle;
  }

  /// Seed the App's food + medication catalog with a broad built-in list.
  /// This composes the global default seed catalog AND the regional
  /// (CN / JP / KR / IN / MED / MX / SEA / EE / MENA) extension so a single
  /// call covers most realistic logging scenarios. Conservative: emits two
  /// `SourceDocumentRecord` rows plus `projectedFoods` / `projectedDrugs`
  /// rows only — no observation, fact, or rule registry rows.
  Future<P0ImportBundle> importSeedCatalog() async {
    final base = seedCatalogImporter.importSeedCatalog();
    final regional = regionalSeedCatalogImporter.importRegionalSeedCatalog();
    final bundle = base.merge(regional);
    await cdssService.importBundle(bundle);
    await _syncProjectedCatalogs(bundle);
    return bundle;
  }

  /// Seed the App catalog with the regional extension only. Most callers
  /// should use `importSeedCatalog()` instead — this is exposed for tests
  /// and for environments that already have the global catalog seeded.
  Future<P0ImportBundle> importRegionalSeedCatalog() async {
    final bundle = regionalSeedCatalogImporter.importRegionalSeedCatalog();
    await cdssService.importBundle(bundle);
    await _syncProjectedCatalogs(bundle);
    return bundle;
  }

  /// Seed the `locale_resource_bundle` table with the regional locale
  /// rollout (`ko-KR`, `hi-IN`, `es-ES`, `es-MX`, `vi-VN`, `th-TH`,
  /// `id-ID`, `ru-RU`, `pl-PL`, `ar-SA`). Writes each row through the
  /// existing `database.insertLocaleResourceBundle()` channel and emits
  /// one audit `SourceDocumentRecord` recording the rollout. Returns the
  /// list of inserted rows for tests/auditors.
  ///
  /// Conservative: this only enriches the database table. It does NOT
  /// register the locale with the Flutter UI layer — `lib/core/i18n/app_i18n.dart`
  /// is owned by the UI team and intentionally outside the importer write
  /// area.
  /// Idempotency contract:
  ///
  /// 1. Each `LocaleResourceBundleRecord` is keyed by
  ///    `(locale_tag, namespace, key)`. All three database backends
  ///    (native sqflite, web in-memory, Firestore) implement that as an
  ///    UPSERT at the row level, so duplicate rows can never accumulate
  ///    even if this method is called many times.
  /// 2. On top of that, this method computes a stable seed checksum and
  ///    compares it against the previously persisted audit
  ///    `SourceDocumentRecord`. When the checksum matches (= the seed
  ///    payload has not changed since the last successful run) we skip the
  ///    row writes entirely and just return the in-memory row set. This
  ///    makes repeated bootstraps cheap and avoids unnecessary database
  ///    fan-out.
  /// 3. When the checksum changes (e.g. a new locale was added or a
  ///    translation was edited) we re-insert every row and overwrite the
  ///    audit document with the new checksum. Older rows that no longer
  ///    appear in the seed remain in the table — the orchestrator does NOT
  ///    silently delete user-tunable translations.
  Future<List<LocaleResourceBundleRecord>> seedLocaleResourceBundles({
    bool forceRewrite = false,
  }) async {
    final rows = localeResourceSeedImporter.buildLocaleSeedBundles();
    final localeTags = rows.map((r) => r.localeTag).toSet();
    final namespaces = rows.map((r) => r.namespace).toSet();
    final seedChecksum = _localeSeedChecksum(rows);

    // Try to short-circuit if a previous run already wrote this exact seed.
    if (!forceRewrite) {
      try {
        final existing =
            await cdssService.database.queryTable('source_document');
        final priorAudit = existing.firstWhere(
          (row) =>
              '${row['source_family'] ?? ''}' == 'LOCALE_RESOURCE_SEED' &&
              '${row['doc_type'] ?? ''}' == 'locale_resource_seed',
          orElse: () => const <String, Object?>{},
        );
        if (priorAudit.isNotEmpty) {
          final priorPayload =
              jsonDecode('${priorAudit['raw_payload'] ?? '{}'}')
                  as Map<String, dynamic>;
          if (priorPayload['seed_checksum'] == seedChecksum) {
            return rows;
          }
        }
      } catch (_) {
        // Table missing on first boot or non-Map payload — fall through to
        // full write path below.
      }
    }

    for (final row in rows) {
      await cdssService.database.insertLocaleResourceBundle(row);
    }
    final auditBundle = localeResourceSeedImporter.buildAuditSourceDocument(
      rowCount: rows.length,
      localeTags: localeTags,
      namespaces: namespaces,
      seedChecksum: seedChecksum,
    );
    await cdssService.importBundle(auditBundle);
    return rows;
  }

  /// Stable hash of the seed row payload. Keeps `(localeTag, namespace,
  /// key, text)` tuples as a sorted list so reordering inside the importer
  /// has no effect.
  String _localeSeedChecksum(List<LocaleResourceBundleRecord> rows) {
    final entries = rows
        .map((r) =>
            '${r.localeTag}|${r.namespace}|${r.key}|${r.text}|${r.pluralRule ?? ''}')
        .toList()
      ..sort();
    return stableHash(entries.join('\n'));
  }

  /// Reconcile the union of seed + regional catalog drugs against the
  /// interaction-engine `DrugTag` enum. Emits a single audit
  /// `SourceDocumentRecord` listing:
  ///   - any drug whose generic name should carry a DrugTag but does not
  ///     (`missing_tag_gaps`);
  ///   - any drug whose interaction class the current DrugTag enum cannot
  ///     represent (`schema_coverage_gaps` — PPI / SSRI / multivalent-cation
  ///     antacid / serotonergic opioid / dopamine antagonist).
  /// Conservative: never modifies catalog rows or rule registry; reviewers
  /// close gaps by tagging rows or filing a core enum extension.
  Future<P0ImportBundle> auditCatalogAgainstInteractionEngine() async {
    final base = seedCatalogImporter.importSeedCatalog();
    final regional = regionalSeedCatalogImporter.importRegionalSeedCatalog();
    final union = base.merge(regional);
    final auditBundle = CatalogInteractionAudit.buildAuditBundle(
      drugs: union.projectedDrugs,
      foods: union.projectedFoods,
    );
    await cdssService.importBundle(auditBundle);
    return auditBundle;
  }

  Future<void> importPreparedBundle(P0ImportBundle bundle) async {
    await cdssService.importBundle(bundle);
    await _syncProjectedCatalogs(bundle);
  }

  Future<P0OfflineImportStepReport> _runLocalSource({
    required String sourceKey,
    required String sourceLabel,
    required List<int> bytes,
    required String? localPath,
    required Future<P0ImportBundle> Function(List<int> bytes) parse,
  }) {
    final checksum = stableHash(bytes.join(','));
    final descriptor = _ImportInputDescriptor(
      sourceKey: sourceKey,
      sourceLabel: sourceLabel,
      inputKind: 'local_bytes',
      localPath: localPath,
      checksum: checksum,
      buildBundle: () => parse(bytes),
      collectRemoteMetadata: () => const <String, Map<String, String>>{},
    );
    final baseRunId =
        'import_${sourceKey}_${DateTime.now().microsecondsSinceEpoch}_${++_runSequence}';
    return _runWithDescriptor(
      descriptor: descriptor,
      baseRunId: baseRunId,
      cachedBundle: null,
    );
  }

  Future<P0OfflineImportStepReport> _runRemoteSource({
    required String sourceKey,
    required String sourceLabel,
    required List<String> remoteUrls,
    required Future<P0ImportBundle> Function() buildBundle,
    SourceFetchClient? fetchClientForMetadata,
  }) {
    final fetchClient = fetchClientForMetadata;
    final descriptor = _ImportInputDescriptor(
      sourceKey: sourceKey,
      sourceLabel: sourceLabel,
      inputKind: 'remote_fetch',
      remoteUrls: remoteUrls,
      buildBundle: buildBundle,
      collectRemoteMetadata: () {
        if (fetchClient == null || remoteUrls.isEmpty) {
          return const <String, Map<String, String>>{};
        }
        final metadata = <String, Map<String, String>>{};
        for (final url in remoteUrls) {
          final entry = fetchClient.lastFetchMetadata(url);
          if (entry.isNotEmpty) metadata[url] = entry;
        }
        return metadata;
      },
    );
    final baseRunId =
        'import_${sourceKey}_${DateTime.now().microsecondsSinceEpoch}_${++_runSequence}';
    return _runWithDescriptor(
      descriptor: descriptor,
      baseRunId: baseRunId,
      cachedBundle: null,
    );
  }

  Future<P0OfflineImportStepReport> _runWithDescriptor({
    required _ImportInputDescriptor descriptor,
    required String baseRunId,
    required P0ImportBundle? cachedBundle,
  }) async {
    _inputDescriptors[baseRunId] = descriptor;
    P0ImportBundle? bundle = cachedBundle;
    Object? lastError;
    String? lastCompletedStage =
        cachedBundle == null ? null : P0IngestionCheckpoint.bundleParsed;
    Map<String, Object?> describe() => descriptor.toNotes(
          lastCompletedStage: lastCompletedStage,
          cachedBundleAvailable: bundle != null,
        );

    for (var attempt = 1; attempt <= 2; attempt++) {
      // ---- parse stage ----
      if (bundle == null) {
        await _writeRun(
          baseRunId: baseRunId,
          attempt: attempt,
          stage: 'fetch_parse',
          status: 'running',
          checkpoint: P0IngestionCheckpoint.fetchPending,
          descriptor: describe(),
          extra: const {},
        );
        try {
          bundle = await descriptor.buildBundle();
          _pendingBundles[baseRunId] = bundle;
          lastCompletedStage = P0IngestionCheckpoint.bundleParsed;
          await _writeRun(
            baseRunId: baseRunId,
            attempt: attempt,
            stage: 'fetch_parse',
            status: 'parsed',
            checkpoint: P0IngestionCheckpoint.bundleParsed,
            descriptor: describe(),
            extra: {
              'source_document_count': bundle.sourceDocuments.length,
              'observation_count': bundle.observations.length,
              'crosswalk_count': bundle.conceptVariantCrosswalks.length,
            },
            completed: true,
          );
        } catch (error) {
          lastError = error;
          await _writeRun(
            baseRunId: baseRunId,
            attempt: attempt,
            stage: 'fetch_parse',
            status: attempt == 2 ? 'failed' : 'retry_scheduled',
            checkpoint: P0IngestionCheckpoint.failedBeforeParse,
            descriptor: describe(),
            extra: {
              'error_message': '$error',
              'next_action': attempt == 2 ? 'manual_resume' : 'retry',
            },
            completed: true,
          );
          continue;
        }
      } else {
        // parse 阶段已经在之前的 attempt/run 完成 → 这次 resume 直接跳到 promote。
        await _writeRun(
          baseRunId: baseRunId,
          attempt: attempt,
          stage: 'fetch_parse',
          status: 'skipped_already_parsed',
          checkpoint: P0IngestionCheckpoint.bundleParsed,
          descriptor: describe(),
          extra: const {'note': 'reusing cached bundle from prior attempt'},
          completed: true,
        );
      }

      // ---- promote stage ----
      try {
        final cdssReport = await cdssService.importBundle(bundle);
        await _syncProjectedCatalogs(bundle);
        lastCompletedStage = P0IngestionCheckpoint.promoteCompleted;
        await _writeRun(
          baseRunId: baseRunId,
          attempt: attempt,
          stage: 'promote',
          status: 'completed',
          checkpoint: P0IngestionCheckpoint.promoteCompleted,
          descriptor: describe(),
          extra: {
            'snapshot_id': cdssReport.promotedSnapshotId,
          },
          completed: true,
        );
        final report = P0OfflineImportStepReport(
          sourceKey: descriptor.sourceKey,
          sourceLabel: descriptor.sourceLabel,
          succeeded: true,
          bundle: bundle,
          report: cdssReport,
          attempts: attempt,
          checkpoint: P0IngestionCheckpoint.promoteCompleted,
          resumeToken: baseRunId,
        );
        _completedReports[baseRunId] = report;
        _pendingBundles.remove(baseRunId);
        return report;
      } catch (error) {
        lastError = error;
        await _writeRun(
          baseRunId: baseRunId,
          attempt: attempt,
          stage: 'promote',
          status: attempt == 2 ? 'failed' : 'retry_scheduled',
          checkpoint: P0IngestionCheckpoint.failedBeforePromote,
          descriptor: describe(),
          extra: {
            'error_message': '$error',
            'next_action': attempt == 2 ? 'manual_resume' : 'retry',
            'parsed_bundle_cached': true,
          },
          completed: true,
        );
        // bundle 仍然在 _pendingBundles 中，下一轮 attempt 会跳过 parse 阶段。
      }
    }

    return P0OfflineImportStepReport(
      sourceKey: descriptor.sourceKey,
      sourceLabel: descriptor.sourceLabel,
      succeeded: false,
      bundle: bundle,
      errorMessage: '$lastError',
      attempts: 2,
      checkpoint: bundle == null
          ? P0IngestionCheckpoint.failedBeforeParse
          : P0IngestionCheckpoint.failedBeforePromote,
      resumeToken: baseRunId,
    );
  }

  Future<void> _writeRun({
    required String baseRunId,
    required int attempt,
    required String stage,
    required String status,
    required String checkpoint,
    required Map<String, Object?> descriptor,
    required Map<String, Object?> extra,
    bool completed = false,
  }) async {
    final now = DateTime.now();
    await cdssService.database.insertIngestionRun(
      IngestionRunRecord(
        runId: '${baseRunId}_${stage}_attempt_$attempt',
        sourceFamily: '${descriptor['source_key'] ?? 'offline_source'}',
        stage: stage,
        status: status,
        snapshotId: 'pending',
        parentSnapshotId: null,
        notesJson: jsonEncode({
          'attempt': attempt,
          'retry_attempt': attempt,
          'max_attempts': 2,
          'checkpoint': checkpoint,
          'resume_supported': true,
          'resume_token': baseRunId,
          ...descriptor,
          ...extra,
        }),
        createdAt: now,
        completedAt: completed ? now : null,
      ),
    );
  }

  Future<void> _syncProjectedCatalogs(P0ImportBundle bundle) async {
    if (appRepository == null) return;
    if (bundle.projectedFoods.isEmpty && bundle.projectedDrugs.isEmpty) return;

    final currentFoods = await appRepository!.loadFoods();
    final currentDrugs = await appRepository!.loadMedications();
    final currentRules = await appRepository!.loadInteractionRules();

    final nextFoods = _mergeFoods(currentFoods, bundle.projectedFoods);
    final nextDrugs = _mergeDrugs(currentDrugs, bundle.projectedDrugs);

    await appRepository!.initialize(
      seedFoods: nextFoods,
      seedMedications: nextDrugs,
      seedRules:
          currentRules.isEmpty ? const <InteractionRuleRecord>[] : currentRules,
    );
  }

  List<FoodItem> _mergeFoods(List<FoodItem> current, List<FoodItem> incoming) {
    final byId = <String, FoodItem>{
      for (final item in current) item.id: item,
      for (final item in incoming) item.id: item,
    };
    return byId.values.toList(growable: false);
  }

  List<DrugDefinition> _mergeDrugs(
    List<DrugDefinition> current,
    List<DrugDefinition> incoming,
  ) {
    final byId = <String, DrugDefinition>{
      for (final item in current) item.id: item,
      for (final item in incoming) item.id: item,
    };
    return byId.values.toList(growable: false);
  }
}

class P0OfflineImportStepReport {
  final String sourceKey;
  final String sourceLabel;
  final bool succeeded;
  final P0ImportBundle? bundle;
  final CdssImportReport? report;
  final String? errorMessage;
  final int attempts;
  final String? checkpoint;
  final String? resumeToken;

  const P0OfflineImportStepReport({
    required this.sourceKey,
    required this.sourceLabel,
    required this.succeeded,
    this.bundle,
    this.report,
    this.errorMessage,
    this.attempts = 0,
    this.checkpoint,
    this.resumeToken,
  });
}
