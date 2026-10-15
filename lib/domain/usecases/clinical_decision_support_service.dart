import 'dart:convert';

import '../../core/db/cdss_database.dart';
import '../../core/models/food_item.dart';
import '../../core/models/drug_definition.dart';
import '../../core/i18n/app_i18n.dart';
import '../../core/security/cdss_identifier_factory.dart';
import '../../core/utils/qualified_value_parser.dart';
import '../entities/cdss_records.dart';
import '../entities/cdss_runtime.dart';
import '../entities/food_recommendation.dart';
import '../entities/rule_registry_models.dart';
import '../entities/runtime_context.dart';
import '../../data/datasources/remote/p0_import_models.dart';
import '../../data/datasources/remote/p0_import_support.dart';
import 'cdss_artifact_store.dart';
import 'fact_conflict_engine.dart';
import 'rule_explanation_projection.dart';
import 'rule_registry_compiler.dart';
import 'runtime_rule_engine.dart';
import 'runtime_rule_support.dart';
import 'knowledge_governance_service.dart';

/// Main application service that stitches together storage, fact ingestion,
/// runtime evaluation, and audit persistence.
///
/// 当前状态说明：
/// - 已有 source_document / provenance、staging/promote、rule_registry 编译、
///   runtime artifacts、conflict audit 与 version history 主链。
/// - 保持当前主表查询兼容；历史回放和 release diff 通过 cdss_record_history 承载。
class ClinicalDecisionSupportService {
  final CdssDatabase database;
  final FactConflictEngine factConflictEngine;
  final RuntimeRuleEngine runtimeRuleEngine;
  final RuntimeRuleSupport runtimeRuleSupport;
  final CdssArtifactStore artifactStore;
  final RuleRegistryCompiler ruleRegistryCompiler;
  final CdssIdentifierFactory identifierFactory;
  final KnowledgeGovernanceService? knowledgeGovernanceService;

  ClinicalDecisionSupportService({
    required this.database,
    required this.factConflictEngine,
    required this.runtimeRuleEngine,
    RuntimeRuleSupport? runtimeRuleSupport,
    CdssArtifactStore? artifactStore,
    RuleRegistryCompiler? ruleRegistryCompiler,
    CdssIdentifierFactory? identifierFactory,
    this.knowledgeGovernanceService,
  }) : runtimeRuleSupport = runtimeRuleSupport ?? const RuntimeRuleSupport(),
       artifactStore = artifactStore ?? createCdssArtifactStore(),
       ruleRegistryCompiler = ruleRegistryCompiler ?? RuleRegistryCompiler(),
       identifierFactory = identifierFactory ?? CdssIdentifierFactory();

  Future<void> initializeRuleRegistry({
    required List<RuleRegistryEntry> rules,
    required String rulesVersion,
  }) async {
    await database.initialize();
    for (final rule in rules) {
      // 把已编译规则快照化写入数据库，运行时会再按 snapshot/version 读取并校验编译。
      await database.insertRuleRegistry({
        'rule_id': rule.ruleId,
        'rule_version': rulesVersion,
        'status': rule.status,
        'rule_type': rule.ruleType.name,
        'priority_band': rule.priorityBand,
        'specificity_band': rule.specificityBand,
        'jurisdiction_json': jsonEncode(rule.jurisdictions),
        'applies_to_json': jsonEncode(rule.appliesTo),
        'predicate_json': jsonEncode(rule.conditions),
        'effect_json': jsonEncode({
          'decision': rule.thenClause.decision.wireValue,
          'severity': rule.thenClause.severity,
          // Persist every locale the rule supplied. `asLocaleMap()` always
          // includes the legacy `zh` / optional `en` keys plus any tags from
          // `RuleMessageSet.localized`, so existing readers that look up
          // `messages.zh` / `messages.en` keep working unchanged.
          'messages': rule.thenClause.messages.asLocaleMap(),
          'actions': rule.thenClause.actions,
          'output_tags': rule.thenClause.outputTags,
        }),
        'provenance_json': jsonEncode({
          'evidence_level': rule.provenance.evidenceLevel,
          'source_refs': rule.provenance.sourceRefs,
          'effective_from': rule.provenance.effectiveFrom?.toIso8601String(),
          'effective_to': rule.provenance.effectiveTo?.toIso8601String(),
        }),
        'override_json': jsonEncode(rule.override),
        'compiled_hash': '${rule.ruleId}_${rule.version}',
        'updated_at':
            rule.provenance.effectiveFrom?.millisecondsSinceEpoch ?? 0,
      });
    }
  }

  Future<void> initializeRegionalMasterData({
    required List<RegionJurisdictionMapRecord> regionMaps,
    required List<LocaleResourceBundleRecord> localeBundles,
    required List<CountryDietProfileRecord> dietProfiles,
    required List<MealTemplateRecord> mealTemplates,
    required List<FoodConceptRecord> foodConcepts,
    required List<FoodVariantRecord> foodVariants,
    required List<DrugConceptRecord> drugConcepts,
    required List<DrugProductVariantRecord> drugProductVariants,
  }) async {
    await database.initialize();
    for (final record in regionMaps) {
      await database.insertRegionJurisdictionMap(record);
    }
    for (final record in localeBundles) {
      await database.insertLocaleResourceBundle(record);
    }
    for (final record in dietProfiles) {
      await database.insertCountryDietProfile(record);
    }
    for (final record in mealTemplates) {
      await database.insertMealTemplate(record);
    }
    for (final record in foodConcepts) {
      await database.insertFoodConcept(record);
    }
    for (final record in foodVariants) {
      await database.insertFoodVariant(record);
    }
    for (final record in drugConcepts) {
      await database.insertDrugConcept(record);
    }
    for (final record in drugProductVariants) {
      await database.insertDrugProductVariant(record);
    }
  }

  Future<void> initializeKnowledgeBase({
    required List<SourceDocumentRecord> sourceDocuments,
    required List<VariantScopeRecord> variantScopes,
    required List<ObservationRecord> observations,
    required List<ResolvedFactRecord> resolvedFacts,
  }) async {
    await database.initialize();
    // 这里是 seed/bootstrap 写入，不做冲突合并。
    // 未完成：完整版本应先进入 staging，再跑 fact conflict engine 和发布快照。
    for (final record in sourceDocuments) {
      await database.insertSourceDocument(record);
    }
    for (final record in variantScopes) {
      await database.insertVariantScope(record);
    }
    for (final record in observations) {
      await database.insertObservation(record);
    }
    for (final record in resolvedFacts) {
      await database.insertResolvedFact(record);
    }
  }

  /// 可重复导入入口：
  /// - 供真正的 P0 抓取器在拉到官方源后写入数据库；
  /// - 当前导入会先进入物理 staging 表，再 promote 到正式表与发布快照。
  ///
  /// 仍未完成：
  /// - 更完整的人工 review 工单流仍是后续增强项；
  /// - 主表仍是当前投影，版本回放依赖 cdss_record_history。
  Future<CdssImportReport> importBundle(P0ImportBundle bundle) =>
      _importBundleWithIncumbents(bundle);

  Future<CdssImportReport> _importBundleWithIncumbents(
    P0ImportBundle bundle, {
    List<ResolvedFactRecord> additionalIncumbents = const [],
  }) async {
    final backend = database;
    if (backend is! CdssAtomicWriter) {
      throw UnsupportedError('Import requires atomic catalogue storage.');
    }
    CdssImportHeldException? held;
    final report = await (backend as CdssAtomicWriter)
        .runAtomicWrite<CdssImportReport?>(() async {
          try {
            return await _importBundleInsideAtomicWrite(
              bundle,
              additionalIncumbents: additionalIncumbents,
            );
          } on CdssImportHeldException catch (error) {
            // A deliberate hold is a committed review packet, not a partial
            // activation. Report it only after its complete evidence persists.
            held = error;
            return null;
          }
        });
    if (held != null) throw held!;
    // ignore: avoid_print
    print(
      '[CDSS] import committed atomically; observations=${bundle.observations.length}',
    );
    return report!;
  }

  Future<CdssImportReport> _importBundleInsideAtomicWrite(
    P0ImportBundle bundle, {
    List<ResolvedFactRecord> additionalIncumbents = const [],
    Map<String, _ReviewedImportChoice> reviewedChoices = const {},
  }) async {
    await database.initialize();
    final createdAt = DateTime.now();
    final baseHash = identifierFactory.inputDigest('import-bundle', {
      'source_documents': bundle.sourceDocuments
          .map((e) => e.sourceDocId)
          .toList(),
      'country_diet_profiles': bundle.countryDietProfiles
          .map((e) => e.countryCode)
          .toList(),
      'food_variants': bundle.foodVariants.map((e) => e.foodVariantId).toList(),
      'drug_variants': bundle.drugProductVariants
          .map((e) => e.drugProductVariantId)
          .toList(),
      'observations': bundle.observations.map((e) => e.observationId).toList(),
      'rule_registry': bundle.ruleRegistryRows
          .map((e) => e['rule_id'])
          .toList(),
      'runtime_events': bundle.runtimeEvents.map((e) => e.eventId).toList(),
      if (reviewedChoices.isNotEmpty)
        'reviewed_choices': {
          for (final e in reviewedChoices.entries)
            e.key: {
              'decision_id': e.value.decisionId,
              'original_rationale_sha256': e.value.originalRationaleSha256,
              'chosen_observation': e.value.observation.observationId,
            },
        },
    });
    final activeSnapshot = await latestPromotedSnapshot();
    final stagingSnapshotId = 'staging_${createdAt.microsecondsSinceEpoch}';
    final promotedSnapshotId = 'promoted_${createdAt.microsecondsSinceEpoch}';
    final runId = 'etl_${createdAt.microsecondsSinceEpoch}';

    await database.insertEngineSnapshot(
      EngineSnapshotRecord(
        snapshotId: stagingSnapshotId,
        factsVersion: stagingSnapshotId,
        rulesVersion: activeSnapshot?.rulesVersion ?? 'baseline_cdss_rules_v1',
        createdAt: createdAt,
        promotedAt: null,
        rollbackParent: activeSnapshot?.snapshotId,
        inputHash: baseHash,
      ),
    );
    await database.insertIngestionRun(
      IngestionRunRecord(
        runId: runId,
        sourceFamily: _bundleSourceFamily(bundle),
        stage: 'staging',
        status: 'running',
        snapshotId: stagingSnapshotId,
        parentSnapshotId: activeSnapshot?.snapshotId,
        notesJson: jsonEncode({
          'source_document_count': bundle.sourceDocuments.length,
          'country_diet_profile_count': bundle.countryDietProfiles.length,
          'observation_count': bundle.observations.length,
          'resolved_fact_count': bundle.resolvedFacts.length,
          'crosswalk_count': bundle.conceptVariantCrosswalks.length,
          'rule_registry_count': bundle.ruleRegistryRows.length,
          'runtime_event_count': bundle.runtimeEvents.length,
          'retry': {'attempt': 1, 'max_attempts': 1},
          'checkpoint': {
            'phase': 'staging_started',
            'resume_supported': true,
            'resume_run_id': runId,
          },
        }),
        createdAt: createdAt,
        completedAt: null,
      ),
    );

    for (final record in bundle.foodVariants) {
      await database.insertStagingRow('staging_food_variant', {
        'staging_id':
            'stg_food_${stableHash('$runId:${record.foodVariantId}')}',
        'run_id': runId,
        'food_variant_id': record.foodVariantId,
        'payload_json': jsonEncode({
          'food_variant_id': record.foodVariantId,
          'food_concept_id': record.foodConceptId,
          'jurisdiction': record.jurisdiction,
          'source_family': record.sourceFamily,
          'source_food_code': record.sourceFoodCode,
          'display_name_local': record.displayNameLocal,
          'is_authoritative_for_region': record.isAuthoritativeForRegion,
          'is_authoritative_fallback': record.isAuthoritativeFallback,
          'status': record.status,
          'fallback_chain_json': record.fallbackChainJson,
        }),
      });
    }
    for (final record in bundle.drugProductVariants) {
      await database.insertStagingRow('staging_drug_product_variant', {
        'staging_id':
            'stg_drug_${stableHash('$runId:${record.drugProductVariantId}')}',
        'run_id': runId,
        'drug_product_variant_id': record.drugProductVariantId,
        'payload_json': jsonEncode({
          'drug_product_variant_id': record.drugProductVariantId,
          'drug_concept_id': record.drugConceptId,
          'jurisdiction': record.jurisdiction,
          'regulator': record.regulator,
          'external_product_code': record.externalProductCode,
          'route': record.route,
          'dosage_form': record.dosageForm,
          'release_type': record.releaseType,
          'label_version': record.labelVersion,
          'source_status': record.sourceStatus,
        }),
      });
    }
    for (final record in _effectiveCrosswalks(bundle, runId, createdAt)) {
      await database.insertStagingRow('staging_concept_variant_crosswalk', {
        'staging_id': 'stg_xwalk_${stableHash('$runId:${record.crosswalkId}')}',
        'run_id': runId,
        'crosswalk_id': record.crosswalkId,
        'payload_json': jsonEncode(_crosswalkPayload(record)),
      });
    }
    for (final record in bundle.variantScopes) {
      await database.insertStagingRow('staging_variant_scope', {
        'staging_id': 'stg_scope_${stableHash('$runId:${record.scopeHash}')}',
        'run_id': runId,
        'scope_hash': record.scopeHash,
        'payload_json': jsonEncode({
          'scope_hash': record.scopeHash,
          'jurisdiction': record.jurisdiction,
          'brand': record.brand,
          'dosage_form': record.dosageForm,
          'release_type': record.releaseType,
          'salt_form': record.saltForm,
          'route': record.route,
          'preparation_state': record.preparationState,
          'cooking_state': record.cookingState,
          'plant_part': record.plantPart,
          'cultivar': record.cultivar,
          'sampling_frame': record.samplingFrame,
        }),
      });
    }
    for (final record in bundle.observations) {
      await database.insertStagingRow('staging_observation', {
        'staging_id': 'stg_obs_${stableHash('$runId:${record.observationId}')}',
        'run_id': runId,
        'observation_id': record.observationId,
        'payload_json': jsonEncode({
          'observation_id': record.observationId,
          'domain': record.domain,
          'entity_type': record.entityType,
          'entity_key': record.entityKey,
          'attribute_code': record.attributeCode,
          'value_type': record.valueType,
          'qualifier_kind': record.value.qualifierKind.wireValue,
          'raw_value_text': record.value.rawValueText,
          'low': record.value.low,
          'high': record.value.high,
          'value_num': record.value.valueNum,
          'unit': record.unit,
          'basis_type': record.basisType,
          'basis_amount': record.basisAmount,
          'scope_hash': record.scopeHash,
          'source_doc_id': record.sourceDocId,
          'record_locator': record.recordLocator,
          'method_code': record.methodCode,
          'extraction_confidence': record.extractionConfidence,
        }),
      });
    }
    for (final record in bundle.resolvedFacts) {
      final staged = _copyResolvedFactWithSnapshot(
        record,
        snapshotId: stagingSnapshotId,
        factVersion: stagingSnapshotId,
      );
      await database.insertStagingRow('staging_resolved_fact', {
        'staging_id': 'stg_fact_${stableHash('$runId:${staged.factId}')}',
        'run_id': runId,
        'fact_id': staged.factId,
        'payload_json': jsonEncode(_resolvedFactPayload(staged)),
      });
    }
    for (final row in bundle.ruleRegistryRows) {
      final ruleId = '${row['rule_id'] ?? ''}';
      await database.insertStagingRow('staging_rule_registry', {
        'staging_id': 'stg_rule_${stableHash('$runId:$ruleId')}',
        'run_id': runId,
        'rule_id': ruleId,
        'payload_json': jsonEncode(row),
      });
    }
    for (final record in bundle.runtimeEvents) {
      await database.insertStagingRow('staging_runtime_event', {
        'staging_id': 'stg_runtime_${stableHash('$runId:${record.eventId}')}',
        'run_id': runId,
        'event_id': record.eventId,
        'payload_json': jsonEncode(_runtimeEventPayload(record)),
      });
    }

    // Audit before any live catalogue or label row is replaced.
    final conflictRationales = await _auditImportConflicts(
      runId: runId,
      snapshotId: stagingSnapshotId,
      bundle: bundle,
      createdAt: createdAt,
      additionalIncumbents: additionalIncumbents,
      reviewedChoices: reviewedChoices,
    );
    if (conflictRationales.any((row) => row['needs_human_review'] == true)) {
      await _holdImport(
        runId: runId,
        snapshotId: stagingSnapshotId,
        bundle: bundle,
        rationales: conflictRationales,
        createdAt: createdAt,
        parentSnapshotId: activeSnapshot?.snapshotId,
      );
      throw CdssImportHeldException(
        runId: runId,
        stagingSnapshotId: stagingSnapshotId,
      );
    }

    for (final record in bundle.sourceDocuments) {
      await database.insertSourceDocument(record);
    }
    for (final record in bundle.countryDietProfiles) {
      await database.insertCountryDietProfile(record);
    }
    for (final record in bundle.foodConcepts) {
      await database.insertFoodConcept(record);
    }
    for (final record in bundle.drugConcepts) {
      await database.insertDrugConcept(record);
    }
    for (final record in bundle.drugLabelSections) {
      await database.insertDrugLabelSection(record);
    }
    for (final record in bundle.drugProductCodes) {
      await database.insertDrugProductCode(record);
    }
    for (final record in bundle.drugProductPackagings) {
      await database.insertDrugProductPackaging(record);
    }
    for (final record in bundle.drugProductMedias) {
      await database.insertDrugProductMedia(record);
    }

    // promote: 从 staging 表读取经过落盘的结果，再写正式表，确保导入链可回放。
    final stagedFoodVariants = await database.queryTable(
      'staging_food_variant',
    );
    for (final row in stagedFoodVariants.where(
      (row) => row['run_id'] == runId,
    )) {
      final payload =
          jsonDecode('${row['payload_json']}') as Map<String, dynamic>;
      await database.insertFoodVariant(
        FoodVariantRecord(
          foodVariantId: '${payload['food_variant_id']}',
          foodConceptId: '${payload['food_concept_id']}',
          jurisdiction: '${payload['jurisdiction']}',
          sourceFamily: '${payload['source_family']}',
          sourceFoodCode: payload['source_food_code']?.toString(),
          displayNameLocal: '${payload['display_name_local']}',
          isAuthoritativeForRegion:
              (payload['is_authoritative_for_region'] as bool?) ?? false,
          isAuthoritativeFallback:
              (payload['is_authoritative_fallback'] as bool?) ?? false,
          status: '${payload['status']}',
          fallbackChainJson: '${payload['fallback_chain_json']}',
        ),
      );
    }
    final stagedDrugVariants = await database.queryTable(
      'staging_drug_product_variant',
    );
    for (final row in stagedDrugVariants.where(
      (row) => row['run_id'] == runId,
    )) {
      final payload =
          jsonDecode('${row['payload_json']}') as Map<String, dynamic>;
      await database.insertDrugProductVariant(
        DrugProductVariantRecord(
          drugProductVariantId: '${payload['drug_product_variant_id']}',
          drugConceptId: '${payload['drug_concept_id']}',
          jurisdiction: '${payload['jurisdiction']}',
          regulator: '${payload['regulator']}',
          externalProductCode: '${payload['external_product_code']}',
          route: '${payload['route']}',
          dosageForm: '${payload['dosage_form']}',
          releaseType: '${payload['release_type']}',
          labelVersion: '${payload['label_version']}',
          sourceStatus: '${payload['source_status']}',
        ),
      );
    }
    final stagedScopes = await database.queryTable('staging_variant_scope');
    for (final row in stagedScopes.where((row) => row['run_id'] == runId)) {
      final payload =
          jsonDecode('${row['payload_json']}') as Map<String, dynamic>;
      await database.insertVariantScope(
        VariantScopeRecord(
          scopeHash: '${payload['scope_hash']}',
          jurisdiction: '${payload['jurisdiction']}',
          brand: payload['brand']?.toString(),
          dosageForm: payload['dosage_form']?.toString(),
          releaseType: payload['release_type']?.toString(),
          saltForm: payload['salt_form']?.toString(),
          route: payload['route']?.toString(),
          preparationState: payload['preparation_state']?.toString(),
          cookingState: payload['cooking_state']?.toString(),
          plantPart: payload['plant_part']?.toString(),
          cultivar: payload['cultivar']?.toString(),
          samplingFrame: payload['sampling_frame']?.toString(),
        ),
      );
    }
    final stagedObservations = await database.queryTable('staging_observation');
    for (final row in stagedObservations.where(
      (row) => row['run_id'] == runId,
    )) {
      final payload =
          jsonDecode('${row['payload_json']}') as Map<String, dynamic>;
      await database.insertObservation(
        ObservationRecord(
          observationId: '${payload['observation_id']}',
          domain: '${payload['domain']}',
          entityType: '${payload['entity_type']}',
          entityKey: '${payload['entity_key']}',
          attributeCode: '${payload['attribute_code']}',
          valueType: '${payload['value_type']}',
          value: QualifiedValue(
            rawValueText: '${payload['raw_value_text'] ?? ''}',
            qualifierKind: _qualifierKindFromWireValue(
              '${payload['qualifier_kind']}',
            ),
            low: (payload['low'] as num?)?.toDouble(),
            high: (payload['high'] as num?)?.toDouble(),
            valueNum: (payload['value_num'] as num?)?.toDouble(),
          ),
          unit: '${payload['unit']}',
          basisType: '${payload['basis_type']}',
          basisAmount: (payload['basis_amount'] as num?)?.toDouble(),
          scopeHash: '${payload['scope_hash']}',
          sourceDocId: '${payload['source_doc_id']}',
          recordLocator: '${payload['record_locator']}',
          methodCode: payload['method_code']?.toString(),
          extractionConfidence:
              (payload['extraction_confidence'] as num?)?.toDouble() ?? 0,
        ),
      );
    }

    final stagedFacts = await database.queryTable('staging_resolved_fact');
    for (final row in stagedFacts.where((row) => row['run_id'] == runId)) {
      final payload =
          jsonDecode('${row['payload_json']}') as Map<String, dynamic>;
      await database.insertResolvedFact(
        ResolvedFactRecord(
          factId:
              '${payload['fact_id']}_${stableHash(promotedSnapshotId).substring(0, 8)}',
          entityKey: '${payload['entity_key']}',
          attributeCode: '${payload['attribute_code']}',
          scopeHash: '${payload['scope_hash']}',
          resolutionStatus: '${payload['resolution_status']}',
          chosenObservationId: '${payload['chosen_observation_id']}',
          resolvedValue: QualifiedValue(
            rawValueText: '${payload['raw_value_text'] ?? ''}',
            qualifierKind: _qualifierKindFromWireValue(
              '${payload['qualifier_kind']}',
            ),
            low: (payload['resolved_low'] as num?)?.toDouble(),
            high: (payload['resolved_high'] as num?)?.toDouble(),
            valueNum: (payload['value_num'] as num?)?.toDouble(),
          ),
          resolvedUnit: '${payload['resolved_unit']}',
          resolutionPolicyId: '${payload['resolution_policy_id']}',
          snapshotId: promotedSnapshotId,
          factVersion: promotedSnapshotId,
          manualOverride: (payload['manual_override'] as bool?) ?? false,
        ),
      );
    }
    final stagedRules = await database.queryTable('staging_rule_registry');
    for (final row in stagedRules.where((row) => row['run_id'] == runId)) {
      final payload =
          jsonDecode('${row['payload_json']}') as Map<String, dynamic>;
      await database.insertRuleRegistry(payload);
    }
    final stagedRuntimeEvents = await database.queryTable(
      'staging_runtime_event',
    );
    for (final row in stagedRuntimeEvents.where(
      (row) => row['run_id'] == runId,
    )) {
      final payload =
          jsonDecode('${row['payload_json']}') as Map<String, dynamic>;
      await database.insertRuntimeEvent(
        RuntimeEventRecord(
          eventId: '${payload['event_id']}',
          patientId: '${payload['patient_id']}',
          eventType: '${payload['event_type']}',
          snapshotId: '${payload['snapshot_id']}',
          contextJson: '${payload['context_json']}',
          machineReadableJson: '${payload['machine_readable_json']}',
          humanReadableMarkdown: '${payload['human_readable_markdown']}',
          jurisdiction: '${payload['jurisdiction']}',
          timezone: '${payload['timezone']}',
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            (payload['created_at'] as num?)?.toInt() ?? 0,
          ),
        ),
      );
    }
    final stagedCrosswalks = await database.queryTable(
      'staging_concept_variant_crosswalk',
    );
    for (final row in stagedCrosswalks.where((row) => row['run_id'] == runId)) {
      final payload =
          jsonDecode('${row['payload_json']}') as Map<String, dynamic>;
      await database.insertStagingRow('concept_variant_crosswalk', payload);
    }
    final importArtifacts = await _writeArtifactSet(
      artifactId: 'import_$runId',
      snapshotId: promotedSnapshotId,
      channel: 'import_run',
      distributionType: 'import_artifacts',
      files: {
        'alerts.json': jsonEncode({
          'alerts': const <Map<String, dynamic>>[],
          'run_id': runId,
          'snapshot_id': promotedSnapshotId,
          'status': 'completed',
        }),
        'human_readable.md': _importHumanReadable(
          runId: runId,
          bundle: bundle,
          promotedSnapshotId: promotedSnapshotId,
        ),
        'audit.jsonl': toJsonLine({
          'event': 'import_promoted',
          'run_id': runId,
          'snapshot_id': promotedSnapshotId,
          'source_family': _bundleSourceFamily(bundle),
          'counts': {
            'source_documents': bundle.sourceDocuments.length,
            'observations': bundle.observations.length,
            'resolved_facts': bundle.resolvedFacts.length,
            'crosswalks': bundle.conceptVariantCrosswalks.length,
          },
        }),
        'release_readiness.json': jsonEncode({
          'status': 'pending_release_gate_evaluation',
          'snapshot_id': promotedSnapshotId,
          'blocking_issues': conflictRationales
              .where((item) => item['needs_human_review'] == true)
              .map((item) => 'unresolved_conflict:${item['cluster_key']}')
              .toList(growable: false),
        }),
        'conflict_rationale.json': const JsonEncoder.withIndent(
          '  ',
        ).convert(conflictRationales),
      },
      manifest: {
        'kind': 'import',
        'run_id': runId,
        'snapshot_id': promotedSnapshotId,
        'fallback': 'inline storage is used on backends without a filesystem',
      },
      createdAt: createdAt,
    );

    // The promoted snapshot is the activation marker read by runtime queries.
    // Persist it only after every result-affecting row and audit artifact has
    // succeeded, so an interrupted copy cannot become the active knowledge base.
    await database.insertEngineSnapshot(
      EngineSnapshotRecord(
        snapshotId: promotedSnapshotId,
        factsVersion: promotedSnapshotId,
        rulesVersion: activeSnapshot?.rulesVersion ?? 'baseline_cdss_rules_v1',
        createdAt: createdAt,
        promotedAt: DateTime.now(),
        rollbackParent: activeSnapshot?.snapshotId,
        inputHash: baseHash,
      ),
    );
    await database.insertIngestionRun(
      IngestionRunRecord(
        runId: '${runId}_promote',
        sourceFamily: _bundleSourceFamily(bundle),
        stage: 'promote',
        status: 'completed',
        snapshotId: promotedSnapshotId,
        parentSnapshotId: activeSnapshot?.snapshotId,
        notesJson: jsonEncode({
          'staging_snapshot_id': stagingSnapshotId,
          'promoted_snapshot_id': promotedSnapshotId,
          'rule_registry_count': bundle.ruleRegistryRows.length,
          'runtime_event_count': bundle.runtimeEvents.length,
          'crosswalk_count': bundle.conceptVariantCrosswalks.length,
          'artifact_path': importArtifacts.artifactPath,
          'artifact_files': importArtifacts.files,
          'checkpoint': {
            'phase': 'promote_completed',
            'resume_supported': true,
            'cleared_staging_run_id': runId,
          },
        }),
        createdAt: createdAt,
        completedAt: DateTime.now(),
      ),
    );
    await database.clearStagingRun(runId);
    return CdssImportReport(
      runId: runId,
      sourceFamily: _bundleSourceFamily(bundle),
      stagingSnapshotId: stagingSnapshotId,
      promotedSnapshotId: promotedSnapshotId,
      sourceDocumentCount: bundle.sourceDocuments.length,
      foodCount: bundle.foodVariants.length,
      drugCount: bundle.drugProductVariants.length,
      observationCount: bundle.observations.length,
      ruleRegistryCount: bundle.ruleRegistryRows.length,
      runtimeEventCount: bundle.runtimeEvents.length,
      completedAt: DateTime.now(),
    );
  }

  /// Read-only, evidence-bound preview for an explicit local source review.
  /// It confers no clinical authority, publication or upstream currency claim.
  Future<CdssReviewedImportPreview> previewReviewedImport({
    required String heldSnapshotId,
    required List<String> decisionIds,
  }) async {
    final backend = database;
    if (backend is! CdssAtomicWriter) {
      throw UnsupportedError('Review requires atomic catalogue storage.');
    }
    return (backend as CdssAtomicWriter).runAtomicWrite(() async {
      final prepared = await _prepareReviewedImport(
        heldSnapshotId,
        decisionIds,
      );
      return CdssReviewedImportPreview._(
        heldSnapshotId: heldSnapshotId,
        evidenceSha256: prepared.evidenceSha256,
        stateSha256: await _reviewActivationStateDigest(),
        decisionIds: List.unmodifiable(decisionIds.toList()..sort()),
        selectedObservations: List.unmodifiable([
          for (final choice in prepared.choices.values)
            Map<String, Object?>.unmodifiable({
              'cluster_key': choice.originalRationale['cluster_key'],
              'observation_id': choice.observation.observationId,
              'source_doc_id': choice.observation.sourceDocId,
              'raw_value_text': choice.observation.value.rawValueText,
              'unit': choice.observation.unit,
              'basis_type': choice.observation.basisType,
              'basis_amount': choice.observation.basisAmount,
              'scope_hash': choice.observation.scopeHash,
              'method_code': choice.observation.methodCode,
            }),
        ]),
      );
    });
  }

  /// Creates a new derived snapshot; never releases the original held one.
  /// A second confirmation or any intervening participating mutation fails.
  Future<CdssImportReport> activateReviewedImport({
    required CdssReviewedImportPreview preview,
    required String confirmationReference,
    required String confirmationReason,
    bool Function()? isSessionCurrent,
  }) async {
    if (confirmationReference.trim().isEmpty ||
        confirmationReason.trim().isEmpty) {
      throw ArgumentError(
        'An explicit local confirmation and reason are required.',
      );
    }
    final backend = database;
    if (backend is! CdssAtomicWriter) {
      throw UnsupportedError('Activation requires atomic catalogue storage.');
    }
    final report = await (backend as CdssAtomicWriter).runAtomicWrite(() async {
      if (isSessionCurrent != null && !isSessionCurrent()) {
        throw StateError('The local review session changed.');
      }
      if (await _reviewActivationStateDigest() != preview.stateSha256) {
        throw StateError('Catalogue state changed; review a new preview.');
      }
      final prepared = await _prepareReviewedImport(
        preview.heldSnapshotId,
        preview.decisionIds,
      );
      if (prepared.evidenceSha256 != preview.evidenceSha256) {
        throw StateError('Original review evidence changed.');
      }
      final result = await _importBundleInsideAtomicWrite(
        prepared.bundle,
        reviewedChoices: prepared.choices,
      );
      final receipt = <String, Object?>{
        'schema': 'parkinsum.reviewed-import-activation/1',
        'original_held_snapshot_id': preview.heldSnapshotId,
        'original_evidence_sha256': preview.evidenceSha256,
        'confirmed_state_sha256': preview.stateSha256,
        'review_decision_ids': preview.decisionIds,
        'derived_snapshot_id': result.promotedSnapshotId,
        'derived_run_id': result.runId,
        'confirmation_reference': confirmationReference.trim(),
        'confirmation_reason': confirmationReason.trim(),
        'original_hold_released': false,
        'source_currency_inferred': false,
        'reviewer_authentication_asserted': false,
        'clinical_approval': false,
      };
      // Receipt persistence shares the complete catalogue transaction. A
      // failure here rolls back rows, histories and the activation marker.
      await database.insertConflictAuditLog(
        ConflictAuditLogRecord(
          auditId: identifierFactory.newId('review_activation'),
          snapshotId: result.promotedSnapshotId,
          runId: result.runId,
          auditType: 'REVIEWED_IMPORT_ACTIVATION',
          target: preview.heldSnapshotId,
          decision: 'derived_snapshot_activated',
          winningRuleIdsJson: '[]',
          suppressedRuleIdsJson: '[]',
          sourceDocRefsJson: jsonEncode(
            prepared.bundle.sourceDocuments.map((e) => e.sourceDocId).toList(),
          ),
          inputHash: identifierFactory.inputDigest(
            'reviewed-import-activation',
            receipt,
          ),
          decisionReason: jsonEncode(receipt),
          machineActionsJson: '[]',
          humanMessage:
              'Explicit local source review; clinical qualification unchanged.',
          needsHumanReview: false,
          createdAt: DateTime.now(),
        ),
      );
      if (isSessionCurrent != null && !isSessionCurrent()) {
        throw StateError('The local review session changed.');
      }
      return result;
    });
    // ignore: avoid_print
    print(
      '[CDSS] reviewed import committed; choices=${preview.decisionIds.length}',
    );
    return report;
  }

  // Bind all defined CDSS tables, including decisions, histories and staging.
  // Row ordering is not an identity; no field or historical value is omitted.
  Future<String> _reviewActivationStateDigest() async =>
      identifierFactory.inputDigest('reviewed-import-current-state', {
        for (final table in const [
          'source_document',
          'food_concept',
          'food_variant',
          'drug_concept',
          'drug_product_variant',
          'drug_label_section',
          'drug_product_code',
          'drug_product_packaging',
          'drug_product_media',
          'concept_variant_crosswalk',
          'observation',
          'variant_scope',
          'resolved_fact',
          'rule_registry',
          'runtime_event',
          'conflict_audit_log',
          'human_review_ticket',
          'engine_snapshot',
          'user_profile',
          'region_jurisdiction_map',
          'locale_resource_bundle',
          'country_diet_profile',
          'meal_template',
          'recommendation_audit_log',
          'ingestion_run',
          'snapshot_distribution',
          'cdss_record_history',
          ..._reviewStagingTables,
        ])
          table: _stableReviewRows(await database.queryTable(table)),
      });

  Future<_PreparedReviewedImport> _prepareReviewedImport(
    String snapshotId,
    List<String> decisionIds,
  ) async {
    if (decisionIds.isEmpty ||
        decisionIds.toSet().length != decisionIds.length) {
      throw StateError('Exactly one current choice per conflict is required.');
    }
    final evidence = await loadHeldImportReviewEvidence(snapshotId: snapshotId);
    if (evidence['schema'] != 'parkinsum.held-import-review-evidence/2') {
      throw StateError(
        'This historical packet lacks complete activation resources.',
      );
    }
    final payload = Map<String, Object?>.from(evidence['payload'] as Map);
    final auditRows = (payload['conflict_audits'] as List).cast<Map>();
    final unresolved = auditRows
        .where(
          (r) =>
              r['needs_human_review'] == true || r['needs_human_review'] == 1,
        )
        .toList();
    if (unresolved.length != decisionIds.length || unresolved.isEmpty) {
      throw StateError(
        'Every original unresolved conflict needs an explicit choice.',
      );
    }
    final currentAudits = await database.queryTable('conflict_audit_log');
    final tickets = await database.queryTable('human_review_ticket');
    final choices = <String, _ReviewedImportChoice>{};
    final covered = <String>{};
    for (final id in decisionIds) {
      final rows = currentAudits
          .where(
            (r) =>
                r['audit_id'] == id &&
                r['audit_type'] == 'IMPORT_CONFLICT_REVIEW_DECISION',
          )
          .toList();
      if (rows.length != 1) {
        throw StateError('Review decision identity is ambiguous.');
      }
      final row = rows.single;
      final d = jsonDecode(row['decision_reason'] as String) as Map;
      if (d['schema'] != 'parkinsum.import-conflict-review-decision/1' ||
          d['action'] != 'choose_observation' ||
          row['decision'] != d['action'] ||
          d['activation_authorized'] != false ||
          d['clinical_approval'] != false ||
          d['snapshot_id'] != snapshotId ||
          row['snapshot_id'] != snapshotId ||
          d['run_id'] != payload['run_id'] ||
          row['run_id'] != payload['run_id'] ||
          d['evidence_sha256'] != evidence['input_sha256'] ||
          '${d['reviewer_reference'] ?? ''}'.trim().isEmpty ||
          '${d['reason'] ?? ''}'.trim().isEmpty ||
          row['input_hash'] !=
              identifierFactory.inputDigest('import-review-decision', d)) {
        throw StateError(
          'Only a current original-evidence choice can activate.',
        );
      }
      final original = unresolved
          .where((a) => a['audit_id'] == d['conflict_audit_id'])
          .toList();
      if (original.length != 1 || !covered.add('${d['conflict_audit_id']}')) {
        throw StateError('A conflict is missing or selected more than once.');
      }
      final audit = original.single;
      final matchingTickets = tickets
          .where((t) => t['ticket_id'] == d['ticket_id'])
          .toList();
      if (matchingTickets.length != 1 ||
          matchingTickets.single['status'] != 'open' ||
          matchingTickets.single['snapshot_id'] != snapshotId ||
          matchingTickets.single['run_id'] != payload['run_id'] ||
          matchingTickets.single['reason_code'] != 'unresolved_conflict' ||
          matchingTickets.single['target_type'] != audit['audit_type'] ||
          matchingTickets.single['target_id'] != audit['target'] ||
          audit['audit_type'] != 'FACT_CLUSTER_RESOLUTION' ||
          audit['decision'] != 'review_required' ||
          d['original_audit_sha256'] !=
              identifierFactory.inputDigest('original-conflict-audit', audit)) {
        throw StateError('Original ticket and conflict must still match.');
      }
      final rationale = Map<String, Object?>.from(
        jsonDecode(audit['decision_reason'] as String) as Map,
      );
      final edges = (rationale['comparison_edges'] as List).cast<Map>();
      // Scope/method/identity/quantity incompatibility needs corrected evidence,
      // not a preference that discards an independently applicable measurement.
      if (edges.isEmpty || edges.any((e) => e['numeric_comparable'] != true)) {
        throw StateError(
          'Incomparable evidence must be corrected or split by scope.',
        );
      }
      final participantIds = {
        for (final e in edges) ...[
          e['left_observation_id'],
          e['right_observation_id'],
        ],
      };
      final chosen = d['chosen_observation'];
      final chosenSource = d['chosen_source'];
      if (chosen is! Map ||
          chosenSource is! Map ||
          !participantIds.contains(chosen['observation_id'])) {
        throw StateError('An original graph participant is required.');
      }
      final history = payload['incumbent_evidence'] as Map;
      final originals = <Map>[
        ...(payload['observations'] as List).cast<Map>(),
        ...(history['observation'] as List).cast<Map>(),
      ].where((o) => o['observation_id'] == chosen['observation_id']).toList();
      final originalSources = <Map>[
        ...(payload['source_documents'] as List).cast<Map>(),
        ...(history['source_document'] as List).cast<Map>(),
      ].where((o) => o['source_doc_id'] == chosen['source_doc_id']).toList();
      final chosenHash = identifierFactory.inputDigest(
        'chosen-observation',
        chosen,
      );
      final sourceHash = identifierFactory.inputDigest(
        'chosen-source',
        chosenSource,
      );
      if (originals.isEmpty ||
          originalSources.isEmpty ||
          d['chosen_observation_sha256'] != chosenHash ||
          d['chosen_source_sha256'] != sourceHash ||
          originals.any(
            (o) =>
                identifierFactory.inputDigest('chosen-observation', o) !=
                chosenHash,
          ) ||
          originalSources.any(
            (o) =>
                identifierFactory.inputDigest('chosen-source', o) != sourceHash,
          )) {
        throw StateError(
          'Chosen original quantity/source changed or is ambiguous.',
        );
      }
      final observation = _observationFromRow(
        Map<String, Object?>.from(chosen),
      );
      if (observation.value.low == null ||
          observation.value.high == null ||
          !observation.value.low!.isFinite ||
          !observation.value.high!.isFinite ||
          observation.value.low! > observation.value.high! ||
          observation.value.qualifierKind == QualifierKind.parsingUncertainty ||
          observation.methodCode?.trim().isNotEmpty != true ||
          observation.recordLocator.trim().isEmpty ||
          observation.basisType.trim().isEmpty ||
          observation.unit.trim().isEmpty) {
        throw StateError(
          'An original qualified quantity, method and basis are required.',
        );
      }
      final key = '${audit['target']}';
      if (choices.containsKey(key)) {
        throw StateError('Conflicting choices for one cluster.');
      }
      choices[key] = _ReviewedImportChoice(
        decisionId: id,
        originalAuditId: '${audit['audit_id']}',
        originalRationale: rationale,
        originalRationaleSha256: identifierFactory.inputDigest(
          'reviewed-original-rationale',
          rationale,
        ),
        observation: observation,
      );
    }
    final originalBundle = _bundleFromReviewPayload(payload);
    final allSources = <String, SourceDocumentRecord>{
      for (final row in await database.queryTable('source_document'))
        '${row['source_doc_id']}': _sourceFromRow(row),
      for (final row
          in (payload['incumbent_evidence'] as Map)['source_document'] as List)
        '${(row as Map)['source_doc_id']}': _sourceFromRow(
          Map<String, Object?>.from(row),
        ),
      for (final source in originalBundle.sourceDocuments)
        source.sourceDocId: source,
    };
    final referencedSources = await _validateReviewedImportReferences(
      originalBundle,
    );
    referencedSources.addAll(
      choices.values.map((c) => c.observation.sourceDocId),
    );
    referencedSources.addAll(
      originalBundle.sourceDocuments.map((s) => s.sourceDocId),
    );
    final now = DateTime.now();
    for (final id in referencedSources) {
      final source = allSources[id];
      if (source == null) {
        throw StateError('Original source reference is missing.');
      }
      if (source.sourceStatus != 'active' ||
          source.rawPayload.trim().isEmpty ||
          source.checksum != stableHash(source.rawPayload) ||
          source.originUrl.trim().isEmpty ||
          (source.publishedAt?.isAfter(now) ?? false) ||
          (source.effectiveAt?.isAfter(now) ?? false)) {
        throw StateError(
          'Source lifecycle/content is not qualified for local activation.',
        );
      }
    }
    final facts = [
      for (final fact in originalBundle.resolvedFacts)
        if (!choices.values.any(
          (c) =>
              c.observation.entityKey == fact.entityKey &&
              c.observation.attributeCode == fact.attributeCode,
        ))
          fact,
      for (final choice in choices.values)
        ResolvedFactRecord(
          factId: 'reviewed_${choice.decisionId}',
          entityKey: choice.observation.entityKey,
          attributeCode: choice.observation.attributeCode,
          scopeHash: choice.observation.scopeHash,
          resolutionStatus: 'EXPLICIT_SOURCE_REVIEW',
          chosenObservationId: choice.observation.observationId,
          resolvedValue: choice.observation.value,
          resolvedUnit: choice.observation.unit,
          resolutionPolicyId: choice.decisionId,
          snapshotId: snapshotId,
          factVersion: snapshotId,
          manualOverride: true,
        ),
    ];
    final bundle = _reviewBundleWithFacts(originalBundle, facts);
    return _PreparedReviewedImport(
      bundle,
      choices,
      '${evidence['input_sha256']}',
    );
  }

  Future<Set<String>> _validateReviewedImportReferences(
    P0ImportBundle bundle,
  ) async {
    Future<Set<String>> ids(
      String table,
      String field,
      Iterable<String> incoming,
    ) async {
      final known = <String>{};
      for (final row in await database.queryTable(table)) {
        final id = row[field];
        if (id is! String || id.trim().isEmpty || !known.add(id)) {
          throw StateError('Ambiguous current resource identity.');
        }
      }
      final added = <String>{};
      for (final id in incoming) {
        if (id.trim().isEmpty || !added.add(id)) {
          throw StateError('Ambiguous incoming resource identity.');
        }
      }
      return {...known, ...added};
    }

    final foods = await ids(
      'food_variant',
      'food_variant_id',
      bundle.foodVariants.map((r) => r.foodVariantId),
    );
    final foodConcepts = await ids(
      'food_concept',
      'food_concept_id',
      bundle.foodConcepts.map((r) => r.foodConceptId),
    );
    final drugs = await ids(
      'drug_product_variant',
      'drug_product_variant_id',
      bundle.drugProductVariants.map((r) => r.drugProductVariantId),
    );
    final drugConcepts = await ids(
      'drug_concept',
      'drug_concept_id',
      bundle.drugConcepts.map((r) => r.drugConceptId),
    );
    final scopes = await ids(
      'variant_scope',
      'scope_hash',
      bundle.variantScopes.map((r) => r.scopeHash),
    );
    final sources = await ids(
      'source_document',
      'source_doc_id',
      bundle.sourceDocuments.map((r) => r.sourceDocId),
    );
    await ids(
      'observation',
      'observation_id',
      bundle.observations.map((r) => r.observationId),
    );
    final referencedSources = <String>{};
    void referenceSource(String id) {
      if (!sources.contains(id)) {
        throw StateError('Missing original resource source.');
      }
      referencedSources.add(id);
    }

    for (final row in bundle.foodVariants) {
      if (!foodConcepts.contains(row.foodConceptId)) {
        throw StateError('Missing food concept.');
      }
    }
    for (final row in bundle.drugProductVariants) {
      if (!drugConcepts.contains(row.drugConceptId) ||
          row.sourceStatus != 'active') {
        throw StateError(
          'Drug product identity or lifecycle is not qualified.',
        );
      }
    }
    for (final row in bundle.observations) {
      referenceSource(row.sourceDocId);
      if (!scopes.contains(row.scopeHash) ||
          (row.domain == 'food' && !foods.contains(row.entityKey)) ||
          (row.domain == 'drug' && !drugs.contains(row.entityKey))) {
        throw StateError('Observation catalogue/scope reference is missing.');
      }
    }
    final drugResources = [
      for (final row in bundle.drugLabelSections)
        (row.drugProductVariantId, row.sourceDocId),
      for (final row in bundle.drugProductCodes)
        (row.drugProductVariantId, row.sourceDocId),
      for (final row in bundle.drugProductPackagings)
        (row.drugProductVariantId, row.sourceDocId),
      for (final row in bundle.drugProductMedias)
        (row.drugProductVariantId, row.sourceDocId),
    ];
    for (final (product, source) in drugResources) {
      if (!drugs.contains(product)) {
        throw StateError('Missing drug product resource.');
      }
      referenceSource(source);
    }
    for (final row in bundle.conceptVariantCrosswalks) {
      referenceSource(row.sourceDocId);
      if ((row.domain == 'food' &&
              (!foods.contains(row.variantId) ||
                  !foodConcepts.contains(row.conceptId))) ||
          (row.domain == 'drug' &&
              (!drugs.contains(row.variantId) ||
                  !drugConcepts.contains(row.conceptId)))) {
        throw StateError('Missing crosswalk catalogue resource.');
      }
    }
    return referencedSources;
  }

  P0ImportBundle _reviewBundleWithFacts(
    P0ImportBundle b,
    List<ResolvedFactRecord> facts,
  ) => P0ImportBundle(
    sourceDocuments: b.sourceDocuments,
    countryDietProfiles: b.countryDietProfiles,
    foodConcepts: b.foodConcepts,
    foodVariants: b.foodVariants,
    drugConcepts: b.drugConcepts,
    drugProductVariants: b.drugProductVariants,
    drugLabelSections: b.drugLabelSections,
    drugProductCodes: b.drugProductCodes,
    drugProductPackagings: b.drugProductPackagings,
    drugProductMedias: b.drugProductMedias,
    conceptVariantCrosswalks: b.conceptVariantCrosswalks,
    variantScopes: b.variantScopes,
    observations: b.observations,
    resolvedFacts: facts,
    ruleRegistryRows: b.ruleRegistryRows,
    runtimeEvents: b.runtimeEvents,
    projectedFoods: b.projectedFoods,
    projectedDrugs: b.projectedDrugs,
  );

  // v2 is the complete held-package codec. Required groups and field types are
  // checked before mutation; historical v1 remains available for review only.
  P0ImportBundle _bundleFromReviewPayload(Map<String, Object?> payload) {
    final retained = payload['retained_catalog_rows'] as Map;
    final staged = payload['staging_rows'] as Map;
    List<Map<String, Object?>> rows(String table, {bool staging = false}) {
      final value = staging ? staged['staging_$table'] : retained[table];
      if (value is! List) {
        throw FormatException('Missing original group: $table');
      }
      return [
        for (final row in value)
          Map<String, Object?>.from(
            staging
                ? jsonDecode((row as Map)['payload_json'] as String) as Map
                : row as Map,
          ),
      ];
    }

    String text(Map<String, Object?> r, String key) => r[key] as String;
    String? optionalText(Map<String, Object?> r, String key) {
      if (!r.containsKey(key)) {
        throw FormatException('Missing original field: $key');
      }
      return r[key] as String?;
    }

    DateTime date(Map<String, Object?> r, String key) =>
        DateTime.fromMillisecondsSinceEpoch(r[key] as int);
    return P0ImportBundle(
      sourceDocuments: [
        for (final r in (payload['source_documents'] as List).cast<Map>())
          _sourceFromRow(Map<String, Object?>.from(r)),
      ],
      observations: [
        for (final r in rows('observation', staging: true))
          _observationFromRow(r),
      ],
      resolvedFacts: [
        for (final r in rows('resolved_fact', staging: true)) _factFromRow(r),
      ],
      ruleRegistryRows: [
        for (final r in rows('rule_registry', staging: true))
          Map<String, dynamic>.from(r),
      ],
      projectedFoods: [
        for (final r in rows('projected_foods'))
          FoodItem.fromJson(Map<String, dynamic>.from(r)),
      ],
      projectedDrugs: [
        for (final r in rows('projected_drugs'))
          DrugDefinition.fromJson(Map<String, dynamic>.from(r)),
      ],
      countryDietProfiles: [
        for (final r in rows('country_diet_profile'))
          CountryDietProfileRecord(
            countryCode: text(r, 'country_code'),
            guidelineSource: text(r, 'guideline_source'),
            mealPatternJson: text(r, 'meal_pattern_json'),
            stapleFoodsJson: text(r, 'staple_foods_json'),
            preferredProteinSourcesJson: text(
              r,
              'preferred_protein_sources_json',
            ),
            avoidanceNotesJson: text(r, 'avoidance_notes_json'),
          ),
      ],
      foodConcepts: [
        for (final r in rows('food_concept'))
          FoodConceptRecord(
            foodConceptId: text(r, 'food_concept_id'),
            canonicalNameEn: text(r, 'canonical_name_en'),
            canonicalNameZh: text(r, 'canonical_name_zh'),
            foodGroup: text(r, 'food_group'),
          ),
      ],
      foodVariants: [
        for (final r in rows('food_variant', staging: true))
          FoodVariantRecord(
            foodVariantId: text(r, 'food_variant_id'),
            foodConceptId: text(r, 'food_concept_id'),
            jurisdiction: text(r, 'jurisdiction'),
            sourceFamily: text(r, 'source_family'),
            sourceFoodCode: optionalText(r, 'source_food_code'),
            displayNameLocal: text(r, 'display_name_local'),
            isAuthoritativeForRegion: r['is_authoritative_for_region'] as bool,
            isAuthoritativeFallback: r['is_authoritative_fallback'] as bool,
            status: text(r, 'status'),
            fallbackChainJson: text(r, 'fallback_chain_json'),
          ),
      ],
      drugConcepts: [
        for (final r in rows('drug_concept'))
          DrugConceptRecord(
            drugConceptId: text(r, 'drug_concept_id'),
            genericName: text(r, 'generic_name'),
            atcLikeCode: text(r, 'atc_like_code'),
          ),
      ],
      drugProductVariants: [
        for (final r in rows('drug_product_variant', staging: true))
          DrugProductVariantRecord(
            drugProductVariantId: text(r, 'drug_product_variant_id'),
            drugConceptId: text(r, 'drug_concept_id'),
            jurisdiction: text(r, 'jurisdiction'),
            regulator: text(r, 'regulator'),
            externalProductCode: text(r, 'external_product_code'),
            route: text(r, 'route'),
            dosageForm: text(r, 'dosage_form'),
            releaseType: text(r, 'release_type'),
            labelVersion: text(r, 'label_version'),
            sourceStatus: text(r, 'source_status'),
          ),
      ],
      drugLabelSections: [
        for (final r in rows('drug_label_section'))
          DrugLabelSectionRecord(
            sectionId: text(r, 'section_id'),
            drugProductVariantId: text(r, 'drug_product_variant_id'),
            sourceDocId: text(r, 'source_doc_id'),
            sectionKey: text(r, 'section_key'),
            sectionTitle: text(r, 'section_title'),
            sectionText: text(r, 'section_text'),
          ),
      ],
      drugProductCodes: [
        for (final r in rows('drug_product_code'))
          DrugProductCodeRecord(
            productCodeId: text(r, 'product_code_id'),
            drugProductVariantId: text(r, 'drug_product_variant_id'),
            sourceDocId: text(r, 'source_doc_id'),
            codeSystem: text(r, 'code_system'),
            codeValue: text(r, 'code_value'),
            displayText: optionalText(r, 'display_text'),
          ),
      ],
      drugProductPackagings: [
        for (final r in rows('drug_product_packaging'))
          DrugProductPackagingRecord(
            packagingId: text(r, 'packaging_id'),
            drugProductVariantId: text(r, 'drug_product_variant_id'),
            sourceDocId: text(r, 'source_doc_id'),
            packageCode: optionalText(r, 'package_code'),
            description: text(r, 'description'),
            marketingStatus: optionalText(r, 'marketing_status'),
          ),
      ],
      drugProductMedias: [
        for (final r in rows('drug_product_media'))
          DrugProductMediaRecord(
            mediaId: text(r, 'media_id'),
            drugProductVariantId: text(r, 'drug_product_variant_id'),
            sourceDocId: text(r, 'source_doc_id'),
            mediaType: text(r, 'media_type'),
            mediaUrl: text(r, 'media_url'),
            caption: optionalText(r, 'caption'),
          ),
      ],
      conceptVariantCrosswalks: [
        for (final r in rows('concept_variant_crosswalk', staging: true))
          ConceptVariantCrosswalkRecord(
            crosswalkId: text(r, 'crosswalk_id'),
            domain: text(r, 'domain'),
            appEntityId: text(r, 'app_entity_id'),
            conceptId: text(r, 'concept_id'),
            variantId: text(r, 'variant_id'),
            externalIdSystem: text(r, 'external_id_system'),
            externalIdValue: text(r, 'external_id_value'),
            jurisdiction: text(r, 'jurisdiction'),
            sourceDocId: text(r, 'source_doc_id'),
            importRunId: optionalText(r, 'import_run_id'),
            confidence: (r['confidence'] as num).toDouble(),
            status: text(r, 'status'),
            mappingPayloadJson: text(r, 'mapping_payload_json'),
            createdAt: date(r, 'created_at'),
          ),
      ],
      variantScopes: [
        for (final r in rows('variant_scope', staging: true))
          VariantScopeRecord(
            scopeHash: text(r, 'scope_hash'),
            jurisdiction: text(r, 'jurisdiction'),
            brand: optionalText(r, 'brand'),
            dosageForm: optionalText(r, 'dosage_form'),
            releaseType: optionalText(r, 'release_type'),
            saltForm: optionalText(r, 'salt_form'),
            route: optionalText(r, 'route'),
            preparationState: optionalText(r, 'preparation_state'),
            cookingState: optionalText(r, 'cooking_state'),
            plantPart: optionalText(r, 'plant_part'),
            cultivar: optionalText(r, 'cultivar'),
            samplingFrame: optionalText(r, 'sampling_frame'),
          ),
      ],
      runtimeEvents: [
        for (final r in rows('runtime_event', staging: true))
          RuntimeEventRecord(
            eventId: text(r, 'event_id'),
            patientId: text(r, 'patient_id'),
            eventType: text(r, 'event_type'),
            snapshotId: text(r, 'snapshot_id'),
            contextJson: text(r, 'context_json'),
            machineReadableJson: text(r, 'machine_readable_json'),
            humanReadableMarkdown: text(r, 'human_readable_markdown'),
            jurisdiction: text(r, 'jurisdiction'),
            timezone: text(r, 'timezone'),
            createdAt: date(r, 'created_at'),
          ),
      ],
    );
  }

  Future<List<RuleRegistryEntry>> loadCompiledRulesFromRegistry({
    String? rulesVersion,
  }) async {
    await database.initialize();
    final rows = await database.queryTable('rule_registry');
    final allActiveRows = rows
        .where((row) => '${row['status'] ?? ''}' == 'active')
        .toList();
    final resolvedRulesVersion = await _resolveRuntimeRulesVersion(
      requestedRulesVersion: rulesVersion,
      activeRuleRows: allActiveRows,
    );
    final versionRows = resolvedRulesVersion == null
        ? allActiveRows
        : allActiveRows
              .where(
                (row) => '${row['rule_version'] ?? ''}' == resolvedRulesVersion,
              )
              .toList(growable: false);
    // A requested version is an exact pin. Falling back to every active row
    // can silently combine unrelated releases or resurrect a superseded rule.
    final candidateRows = versionRows;
    if (candidateRows.isEmpty) return const <RuleRegistryEntry>[];
    final compiled = <RuleRegistryEntry>[];
    for (final row in candidateRows) {
      try {
        compiled.add(
          ruleRegistryCompiler.compileJson(
            _ruleJsonFromRegistryRow(row),
            rulesVersion:
                resolvedRulesVersion ?? '${row['rule_version'] ?? 'db'}',
          ),
        );
      } catch (error) {
        await database.insertConflictAuditLog(
          ConflictAuditLogRecord(
            auditId: 'rule_compile_${stableHash('${row['rule_id']}:$error')}',
            snapshotId:
                resolvedRulesVersion ?? '${row['rule_version'] ?? 'unknown'}',
            runId: 'rule_registry_compile',
            auditType: 'RULE_COMPILE_FAILURE',
            target: '${row['rule_id'] ?? ''}',
            decision: 'REQUIRE_REVIEW',
            winningRuleIdsJson: '[]',
            suppressedRuleIdsJson: '[]',
            sourceDocRefsJson: '[]',
            inputHash: stableHash(jsonEncode(row)),
            decisionReason: '$error',
            machineActionsJson: jsonEncode([
              {'type': 'block_rule_from_runtime'},
            ]),
            humanMessage: 'Rule registry row failed validation: $error',
            needsHumanReview: true,
            createdAt: DateTime.now(),
          ),
        );
      }
    }
    return compiled;
  }

  Future<String?> _resolveRuntimeRulesVersion({
    required String? requestedRulesVersion,
    required List<Map<String, Object?>> activeRuleRows,
  }) async {
    final activeVersions = activeRuleRows
        .map((row) => '${row['rule_version'] ?? ''}')
        .where((value) => value.isNotEmpty)
        .toSet();
    final requested = requestedRulesVersion?.trim();
    if (requested != null &&
        requested.isNotEmpty &&
        requested != 'latest_promoted' &&
        activeVersions.contains(requested)) {
      return requested;
    }
    if (requested != null &&
        requested.isNotEmpty &&
        requested != 'latest_promoted') {
      // Preserve the requested identity so the caller can report a missing
      // pinned version; do not substitute a different promoted release.
      return requested;
    }
    final snapshots = await database.queryTable('engine_snapshot');
    final promoted =
        snapshots
            .where((row) => row['promoted_at'] != null)
            .toList(growable: false)
          ..sort(
            (left, right) => ((right['promoted_at'] as num?)?.toInt() ?? 0)
                .compareTo((left['promoted_at'] as num?)?.toInt() ?? 0),
          );
    for (final snapshot in promoted) {
      final version = '${snapshot['rules_version'] ?? ''}';
      if (activeVersions.contains(version)) return version;
    }
    return null;
  }

  /// 回滚到某个已发布快照。
  ///
  /// 当前策略：
  /// - 复制目标 snapshot 下的 resolved_fact，生成新的 promoted rollback snapshot；
  /// - source_document / observation / variant 本体仍保持 append-or-replace，不做物理删除。
  Future<String> rollbackToSnapshot({
    required String snapshotId,
    String reason = 'manual_rollback',
  }) async {
    await database.initialize();
    final facts = await database.queryTable('resolved_fact');
    final snapshots = await database.queryTable('engine_snapshot');
    final sourceFacts = facts
        .where((row) => '${row['snapshot_id']}' == snapshotId)
        .toList();
    if (sourceFacts.isEmpty) {
      throw StateError(
        'Snapshot $snapshotId has no resolved facts to rollback.',
      );
    }
    final targetSnapshot = snapshots.firstWhere(
      (row) => '${row['snapshot_id']}' == snapshotId,
      orElse: () => <String, Object?>{},
    );
    final rollbackSnapshotId = identifierFactory.newId('rollback');
    for (final row in sourceFacts) {
      final record = ResolvedFactRecord(
        factId: '${row['fact_id']}_$rollbackSnapshotId',
        entityKey: '${row['entity_key']}',
        attributeCode: '${row['attribute_code']}',
        scopeHash: '${row['scope_hash']}',
        resolutionStatus: '${row['resolution_status']}',
        chosenObservationId: '${row['chosen_observation_id']}',
        resolvedValue: QualifiedValue(
          rawValueText: '${row['raw_value_text'] ?? ''}',
          qualifierKind: _qualifierKindFromWireValue(
            '${row['qualifier_kind'] ?? 'missing'}',
          ),
          low: (row['resolved_low'] as num?)?.toDouble(),
          high: (row['resolved_high'] as num?)?.toDouble(),
          valueNum: (row['value_num'] as num?)?.toDouble(),
        ),
        resolvedUnit: '${row['resolved_unit']}',
        resolutionPolicyId: '${row['resolution_policy_id']}',
        snapshotId: rollbackSnapshotId,
        factVersion: rollbackSnapshotId,
        manualOverride: switch (row['manual_override']) {
          final bool value => value,
          final num value => value == 1,
          _ => false,
        },
      );
      await database.insertResolvedFact(record);
    }

    // As with import promotion, the active marker is written last. A failed
    // rollback copy therefore leaves the previously promoted snapshot active.
    await database.insertEngineSnapshot(
      EngineSnapshotRecord(
        snapshotId: rollbackSnapshotId,
        factsVersion: rollbackSnapshotId,
        rulesVersion:
            '${targetSnapshot['rules_version'] ?? 'baseline_cdss_rules_v1'}',
        createdAt: DateTime.now(),
        promotedAt: DateTime.now(),
        rollbackParent: snapshotId,
        inputHash: identifierFactory.inputDigest('rollback-reason', {
          'reason': reason,
        }),
      ),
    );
    await database.insertIngestionRun(
      IngestionRunRecord(
        runId: 'rollback_${DateTime.now().microsecondsSinceEpoch}',
        sourceFamily: 'SYSTEM',
        stage: 'rollback',
        status: 'completed',
        snapshotId: rollbackSnapshotId,
        parentSnapshotId: snapshotId,
        notesJson: jsonEncode({'reason': reason, 'rollback_from': snapshotId}),
        createdAt: DateTime.now(),
        completedAt: DateTime.now(),
      ),
    );
    return rollbackSnapshotId;
  }

  Future<EngineSnapshotRecord?> latestPromotedSnapshot() async {
    await database.initialize();
    final rows = await database.queryTable('engine_snapshot');
    final promoted =
        rows.where((row) => row['promoted_at'] != null).toList(growable: false)
          ..sort(
            (a, b) => ((b['promoted_at'] as num?)?.toInt() ?? 0).compareTo(
              (a['promoted_at'] as num?)?.toInt() ?? 0,
            ),
          );
    if (promoted.isEmpty) return null;
    final row = promoted.first;
    return EngineSnapshotRecord(
      snapshotId: '${row['snapshot_id']}',
      factsVersion: '${row['facts_version']}',
      rulesVersion: '${row['rules_version']}',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['created_at'] as num?)?.toInt() ?? 0,
      ),
      promotedAt: row['promoted_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (row['promoted_at'] as num).toInt(),
            ),
      rollbackParent: row['rollback_parent']?.toString(),
      inputHash: '${row['input_hash'] ?? ''}',
    );
  }

  Future<FactConflictResult> ingestObservation({
    required SourceDocumentRecord sourceDocument,
    required ObservationRecord observation,
    required List<ResolvedFactRecord> existingFacts,
    required VariantScopeRecord variantScope,
    required ResolvedFactRecord resolvedFact,
  }) async {
    await database.initialize();
    final result = factConflictEngine.classify(
      observation: observation,
      existingFacts: existingFacts,
    );
    // The single-record path uses the same staging and activation gate as a
    // bulk import. Supplied incumbents can add a hold, never bypass stored ones.
    try {
      await _importBundleWithIncumbents(
        P0ImportBundle(
          sourceDocuments: [sourceDocument],
          observations: [observation],
          variantScopes: [variantScope],
          resolvedFacts: [resolvedFact],
        ),
        additionalIncumbents: existingFacts,
      );
    } on CdssImportHeldException catch (error) {
      return FactConflictResult(
        type: result.type,
        reason: '$error',
        rejectedRationaleJson: result.rejectedRationaleJson,
        needsManualReview: true,
      );
    }
    return result;
  }

  Future<EngineRunOutput> run({
    required UnifiedRuntimeContext context,
    required List<RuleRegistryEntry> rules,
    required String factsVersion,
    required String rulesVersion,
  }) async {
    await database.initialize();

    // Production services resolve one complete, signed knowledge package.
    // Test/workbench instances without a governance service retain their
    // isolated registry/caller-supplied behavior.
    final governance = knowledgeGovernanceService;
    final governanceResolution = governance == null
        ? null
        : await governance.resolveAuthorizedRules();
    var governanceHoldReason =
        governanceResolution != null && !governanceResolution.allowed
        ? governanceResolution.reason
        : null;
    final resolvedRulesVersion = governanceResolution?.allowed == true
        ? governanceResolution!.rulesVersion ?? rulesVersion
        : rulesVersion;

    final regionRows = await database.queryTable('region_jurisdiction_map');
    final jurisdictionChain = runtimeRuleEngine.resolveJurisdictionChain(
      context,
      regionJurisdictionRows: regionRows,
    );
    final regionJurisdictionMapSource = runtimeRuleEngine
        .regionJurisdictionMapSource(
          context,
          regionJurisdictionRows: regionRows,
        );
    final i18n = AppI18n.fromLocaleTag(context.userProfile.displayLocale);

    final inputHash = identifierFactory.inputDigest(
      'runtime-evaluation',
      context.toJson(),
    );
    final snapshotId = identifierFactory.newId('snapshot');
    final snapshot = EngineSnapshotRecord(
      snapshotId: snapshotId,
      factsVersion: factsVersion,
      rulesVersion: resolvedRulesVersion,
      createdAt: DateTime.now(),
      promotedAt: null,
      rollbackParent: null,
      inputHash: inputHash,
    );
    await database.insertEngineSnapshot(snapshot);

    final registryRules = governanceResolution == null
        ? await loadCompiledRulesFromRegistry(rulesVersion: rulesVersion)
        : const <RuleRegistryEntry>[];
    var effectiveRules = governanceResolution == null
        ? <RuleRegistryEntry>[
            ...registryRules,
            ...rules.where(
              (rule) => !registryRules.any(
                (registered) => registered.ruleId == rule.ruleId,
              ),
            ),
          ]
        : governanceResolution.allowed
        ? List<RuleRegistryEntry>.of(governanceResolution.rules)
        : <RuleRegistryEntry>[];
    final candidates = runtimeRuleEngine.evaluateCandidates(
      context: context,
      rules: effectiveRules,
      regionJurisdictionRows: regionRows,
    );
    var sortedCandidates = runtimeRuleEngine.resolveByPriority(
      candidates,
      jurisdictionChain: jurisdictionChain,
    );

    final grouped = <String, List<RuleEvaluationCandidate>>{};
    for (final candidate in sortedCandidates) {
      grouped.putIfAbsent(candidate.rule.target, () => []).add(candidate);
    }
    final sameBandByTarget = {
      for (final entry in grouped.entries)
        entry.key: runtimeRuleSupport.evaluateSameBandEscalation(entry.value),
    };
    final applicableRules = effectiveRules
        .where(
          (rule) => runtimeRuleEngine.jurisdictionMatches(
            rule.jurisdictions,
            jurisdictionChain,
          ),
        )
        .toList(growable: false);

    final alerts = <RuntimeAlert>[];
    final auditEntries = <RuntimeAuditEntry>[];

    void addGovernanceHold(String reason) {
      final explanation =
          context.userProfile.displayLocale.toLowerCase().startsWith('zh')
          ? '知识规则包当前未获授权或已发生变化，自动判断已暂停，请人工复核。'
          : 'The authorized knowledge rule set is unavailable or changed during evaluation. Automated decision is held for manual review.';
      const target = 'knowledge-governance';
      final actions = <Map<String, dynamic>>[
        {
          'type': 'require_manual_review',
          'params': {'reason': reason},
        },
      ];
      alerts.add(
        RuntimeAlert(
          target: target,
          decision: RuntimeDecisionType.requireReview,
          severity: 'critical',
          explanation: explanation,
          actions: actions,
          evidenceSources: const <String>[],
          evidenceDetails: const <String>[],
          evidenceRecords: const <EvidenceReferenceDetail>[],
          ruleIds: const <String>[],
        ),
      );
      auditEntries.add(
        RuntimeAuditEntry(
          target: target,
          decision: RuntimeDecisionType.requireReview,
          winningRuleIds: const <String>[],
          suppressedRuleIds: const <String>[],
          sourceDocRefs: const <String>[],
          evidenceDetails: const <String>[],
          evidenceRecords: const <EvidenceReferenceDetail>[],
          inputHash: inputHash,
          decisionReason: reason,
          machineActions: actions,
          humanMessage: explanation,
          needsHumanReview: true,
        ),
      );
    }

    for (final entry in grouped.entries) {
      final bucket = entry.value;
      final winner = bucket.first;
      final sameBandEscalation =
          sameBandByTarget[entry.key] ??
          runtimeRuleSupport.evaluateSameBandEscalation(bucket);
      final sameBandConflict = sameBandEscalation.requiresReview;
      final missingFields = runtimeRuleSupport
          .collectRelevantMissingFields(
            context: context,
            rules: bucket.map((item) => item.rule).toList(growable: false),
          )
          .toList(growable: false);
      final localizedMissingFields = missingFields
          .map(i18n.missingFieldLabel)
          .toList(growable: false);

      var decision = winner.rule.thenClause.decision;
      var explanation = _localizedRuleMessage(
        i18n,
        winner.rule.thenClause.messages,
      );
      if (sameBandConflict || missingFields.isNotEmpty) {
        decision = RuntimeDecisionType.requireReview;
        explanation = sameBandConflict
            ? i18n.tr('runtime.same_band_conflict')
            : i18n.tr('runtime.missing_fields', {
                'fields': localizedMissingFields.join(', '),
              });
      }

      // 决策生成后始终补出 machine actions，保证自动动作和人工复核路径都可审计。
      final actions = [
        ...winner.rule.thenClause.actions,
        if (sameBandConflict || missingFields.isNotEmpty)
          {
            'type': 'require_manual_review',
            'params': {
              'reason': sameBandConflict
                  ? sameBandEscalation.reason
                  : 'missing_${missingFields.join("_")}',
              if (sameBandConflict)
                'suppressed_rule_ids': sameBandEscalation.suppressedRuleIds,
            },
          },
      ];
      final evidenceRecords = await _resolveEvidenceDetails(
        winner.rule.provenance.sourceRefs,
      );
      final evidenceDetails = evidenceRecords
          .map(_formatEvidenceDetail)
          .toList(growable: false);
      final auditMessageWithEvidence = _appendEvidenceDetails(
        explanation,
        evidenceDetails,
      );

      alerts.add(
        RuntimeAlert(
          target: entry.key,
          decision: decision,
          severity: winner.rule.thenClause.severity,
          explanation: explanation,
          actions: actions,
          evidenceSources: winner.rule.provenance.sourceRefs,
          evidenceDetails: evidenceDetails,
          evidenceRecords: evidenceRecords,
          ruleIds: bucket
              .map((item) => item.rule.ruleId)
              .toList(growable: false),
        ),
      );

      auditEntries.add(
        RuntimeAuditEntry(
          target: entry.key,
          decision: decision,
          winningRuleIds: [winner.rule.ruleId],
          suppressedRuleIds: bucket
              .skip(1)
              .map((item) => item.rule.ruleId)
              .toList(),
          sourceDocRefs: winner.rule.provenance.sourceRefs,
          evidenceDetails: evidenceDetails,
          evidenceRecords: evidenceRecords,
          inputHash: inputHash,
          decisionReason: auditMessageWithEvidence,
          machineActions: actions,
          humanMessage: auditMessageWithEvidence,
          needsHumanReview: decision == RuntimeDecisionType.requireReview,
        ),
      );
    }

    if (alerts.isEmpty && governanceHoldReason != null) {
      addGovernanceHold(governanceHoldReason);
    } else if (alerts.isEmpty) {
      final fallbackMissingFields = runtimeRuleSupport
          .collectRelevantMissingFields(
            context: context,
            rules: applicableRules,
          )
          .toList(growable: false);
      final localizedMissingFields = fallbackMissingFields
          .map(i18n.missingFieldLabel)
          .toList(growable: false);
      final decision = fallbackMissingFields.isEmpty
          ? RuntimeDecisionType.allow
          : RuntimeDecisionType.requireReview;
      final explanation = fallbackMissingFields.isEmpty
          ? i18n.tr('runtime.no_rules')
          : i18n.tr('runtime.missing_fields', {
              'fields': localizedMissingFields.join(', '),
            });

      final actions = fallbackMissingFields.isEmpty
          ? const <Map<String, dynamic>>[]
          : <Map<String, dynamic>>[
              {
                'type': 'require_manual_review',
                'params': {'missing_fields': fallbackMissingFields},
              },
            ];

      alerts.add(
        RuntimeAlert(
          target: 'runtime-context',
          decision: decision,
          severity: fallbackMissingFields.isEmpty ? 'low' : 'critical',
          explanation: explanation,
          actions: actions,
          evidenceSources: [i18n.tr('runtime.validation_source')],
          evidenceDetails: const <String>[],
          evidenceRecords: const <EvidenceReferenceDetail>[],
          ruleIds: const <String>[],
        ),
      );
      auditEntries.add(
        RuntimeAuditEntry(
          target: 'runtime-context',
          decision: decision,
          winningRuleIds: const [],
          suppressedRuleIds: const [],
          sourceDocRefs: [i18n.tr('runtime.validation_source')],
          evidenceDetails: const <String>[],
          evidenceRecords: const <EvidenceReferenceDetail>[],
          inputHash: inputHash,
          decisionReason: explanation,
          machineActions: actions,
          humanMessage: explanation,
          needsHumanReview: decision == RuntimeDecisionType.requireReview,
        ),
      );
    }

    // Rule tests, signature verification, and storage replay are asynchronous.
    // Re-read the anchored governance state immediately before persisting any
    // patient-level runtime result; a concurrent withdrawal turns this run
    // into an explicit hold instead of emitting a stale authorized decision.
    if (governance != null &&
        governanceResolution != null &&
        !await governance.isResolutionCurrent(governanceResolution)) {
      governanceHoldReason = 'knowledge_governance_changed_during_run';
      alerts.clear();
      auditEntries.clear();
      grouped.clear();
      effectiveRules = <RuleRegistryEntry>[];
      sortedCandidates = <RuleEvaluationCandidate>[];
      addGovernanceHold('knowledge_governance_changed_during_run');
    }

    final ruleHitTrace = _ruleHitTrace(
      rules: effectiveRules,
      candidates: sortedCandidates,
      groupedCandidates: grouped,
      sameBandByTarget: sameBandByTarget,
      context: context,
      jurisdictionChain: jurisdictionChain,
      regionJurisdictionMapSource: regionJurisdictionMapSource,
    );
    // Pure, read-only projection of what the engine just computed into the
    // documented RuleExplanation audit contract. Re-evaluates nothing.
    final ruleExplanations = projectRuleExplanations(
      auditEntries: auditEntries,
      ruleHitTrace: ruleHitTrace,
    );
    final ruleExplanationsJson = ruleExplanations
        .map((explanation) => explanation.toJson())
        .toList(growable: false);
    final alertsJson = {
      'alerts': alerts.map((alert) => alert.toJson()).toList(growable: false),
      'jurisdiction_chain': jurisdictionChain,
      'snapshot': {
        'facts_version': factsVersion,
        'rules_version': resolvedRulesVersion,
      },
      'compiled_rule_source': governanceResolution != null
          ? governanceHoldReason != null || !governanceResolution.allowed
                ? 'governance_held'
                : governanceResolution.isPrototypeBaseline
                ? 'exact_governed_prototype_baseline'
                : 'authorized_knowledge_package'
          : registryRules.isEmpty
          ? 'caller_supplied_rules'
          : 'database_rule_registry_snapshot',
      if (governanceResolution != null)
        'knowledge_governance': {
          'allowed':
              governanceResolution.allowed && governanceHoldReason == null,
          'reason': governanceHoldReason,
          'package_digest': governanceResolution.packageDigest,
          'prototype_baseline': governanceResolution.isPrototypeBaseline,
          'state_head_digest': governanceResolution.stateHeadDigest,
        },
      'trace_metadata': {
        'region_jurisdiction_source': regionJurisdictionMapSource,
        'warnings': [
          if (regionJurisdictionMapSource == 'runtime_static_map')
            'region_jurisdiction_map_static_fallback_possible',
        ],
      },
      'rule_hit_trace': ruleHitTrace,
    };

    // 输出同时写入 runtime_event、conflict_audit_log 和 artifact set：
    // machine-readable JSON、human-readable Markdown、audit JSONL、rule trace。
    final humanReadable = StringBuffer('# Runtime Decision\n\n');
    for (final alert in alerts) {
      humanReadable.writeln(
        '- ${alert.decision.name.toUpperCase()} [${alert.target}] ${alert.explanation}',
      );
      if (alert.evidenceDetails.isNotEmpty) {
        humanReadable.writeln(
          '  Evidence: ${alert.evidenceDetails.join(' | ')}',
        );
      }
    }

    final auditJsonl = [
      ...auditEntries.map((entry) => entry.toJson()),
      ...ruleHitTrace.map((entry) => {'event_type': 'rule_trace', ...entry}),
    ].map(toJsonLine).join();

    final runtimeEvent = RuntimeEventRecord(
      eventId: identifierFactory.newId('runtime'),
      patientId: context.userProfile.patientId,
      eventType: 'patient_level_runtime_evaluation',
      snapshotId: snapshot.snapshotId,
      contextJson: jsonEncode(context.toJson()),
      machineReadableJson: jsonEncode(alertsJson),
      humanReadableMarkdown: humanReadable.toString(),
      jurisdiction: jurisdictionChain.first,
      timezone: context.userProfile.timezone,
      createdAt: DateTime.now(),
    );
    await database.insertRuntimeEvent(runtimeEvent);
    await _writeArtifactSet(
      artifactId: runtimeEvent.eventId,
      snapshotId: snapshot.snapshotId,
      channel: 'runtime',
      distributionType: 'runtime_artifacts',
      files: {
        'alerts.json': const JsonEncoder.withIndent('  ').convert(alertsJson),
        'human_readable.md': humanReadable.toString(),
        'audit.jsonl': auditJsonl,
        'release_readiness.json': jsonEncode({
          'status': 'runtime_artifacts_generated',
          'snapshot_id': snapshot.snapshotId,
          'needs_human_review': auditEntries.any(
            (entry) => entry.needsHumanReview,
          ),
        }),
        'rule_trace.json': const JsonEncoder.withIndent(
          '  ',
        ).convert(ruleHitTrace),
        'conflict_rationale.json': const JsonEncoder.withIndent('  ').convert({
          'rule_hit_trace': ruleHitTrace,
          'audit_entries': auditEntries.map((entry) => entry.toJson()).toList(),
        }),
        // The documented audit contract, one row per registry rule (including
        // rules that did not fire). Readable back via
        // CdssArtifactStore.readArtifactSet.
        'rule_explanations.json': const JsonEncoder.withIndent(
          '  ',
        ).convert(ruleExplanationsJson),
      },
      manifest: {
        'kind': 'runtime',
        'event_id': runtimeEvent.eventId,
        'patient_id': context.userProfile.patientId,
        'rules_loaded_from_database': registryRules.isNotEmpty,
        'fallback': 'inline storage is used on backends without a filesystem',
      },
      createdAt: runtimeEvent.createdAt,
    );

    for (var index = 0; index < auditEntries.length; index++) {
      final entry = auditEntries[index];
      await database.insertConflictAuditLog(
        ConflictAuditLogRecord(
          auditId: '${runtimeEvent.eventId}_$index',
          snapshotId: snapshot.snapshotId,
          runId: runtimeEvent.eventId,
          auditType: 'RUNTIME_ALERT',
          target: entry.target,
          decision: entry.decision.wireValue,
          winningRuleIdsJson: jsonEncode(entry.winningRuleIds),
          suppressedRuleIdsJson: jsonEncode(entry.suppressedRuleIds),
          sourceDocRefsJson: jsonEncode(entry.sourceDocRefs),
          inputHash: entry.inputHash,
          decisionReason: entry.decisionReason,
          machineActionsJson: jsonEncode(entry.machineActions),
          humanMessage: entry.humanMessage,
          needsHumanReview: entry.needsHumanReview,
          createdAt: DateTime.now(),
        ),
      );
    }

    return EngineRunOutput(
      alertsJson: alertsJson,
      humanReadableMarkdown: humanReadable.toString(),
      auditLogJsonl: auditJsonl,
      alerts: alerts,
      auditEntries: auditEntries,
      ruleExplanationsJson: ruleExplanationsJson,
    );
  }

  Future<CdssArtifactWriteResult> _writeArtifactSet({
    required String artifactId,
    required String snapshotId,
    required String channel,
    required String distributionType,
    required Map<String, String> files,
    required Map<String, dynamic> manifest,
    required DateTime createdAt,
  }) async {
    final result = await artifactStore.writeArtifactSet(
      artifactId: artifactId,
      files: files,
      manifest: manifest,
    );
    await database.insertSnapshotDistribution(
      SnapshotDistributionRecord(
        distributionId:
            'dist_${distributionType}_${stableHash('$artifactId:$createdAt')}',
        snapshotId: snapshotId,
        channel: channel,
        distributionType: distributionType,
        status: result.durable ? 'completed' : 'completed_inline_fallback',
        artifactPath: result.artifactPath,
        manifestJson: jsonEncode({
          ...manifest,
          'artifact_path': result.artifactPath,
          'files': result.files,
          'durable': result.durable,
        }),
        errorMessage: null,
        createdAt: createdAt,
        completedAt: DateTime.now(),
      ),
    );
    return result;
  }

  Future<List<Map<String, dynamic>>> _auditImportConflicts({
    required String runId,
    required String snapshotId,
    required P0ImportBundle bundle,
    required DateTime createdAt,
    List<ResolvedFactRecord> additionalIncumbents = const [],
    Map<String, _ReviewedImportChoice> reviewedChoices = const {},
  }) async {
    final previousSourceRows = await database.queryTable('source_document');
    final previousScopeRows = await database.queryTable('variant_scope');
    final identityIssues = <Map<String, dynamic>>[];
    for (final doc in bundle.sourceDocuments) {
      for (final previous in previousSourceRows.where(
        (row) => row['source_doc_id'] == doc.sourceDocId,
      )) {
        final checksum = '${previous['checksum'] ?? ''}';
        if (checksum.isNotEmpty && checksum != doc.checksum) {
          identityIssues.add({
            'cluster_key': 'source_document:${doc.sourceDocId}',
            'status': 'source_identity_collision',
            'source_doc_refs': [doc.sourceDocId],
            'previous_checksum': checksum,
            'incoming_checksum': doc.checksum,
            'needs_human_review': true,
            'explanation':
                'Different source content requires a distinct immutable document identity.',
          });
        }
      }
    }
    final previousObservations = {
      for (final row in await database.queryTable('observation'))
        if ('${row['entity_key'] ?? ''}'.isNotEmpty)
          '${row['observation_id']}': _observationFromRow(row),
    };
    final previousFacts = [
      ...additionalIncumbents,
      for (final row in await database.queryTable('resolved_fact'))
        if ('${row['entity_key'] ?? ''}'.isNotEmpty) _factFromRow(row),
    ];
    final incomingById = {
      for (final row in bundle.observations) row.observationId: row,
    };
    if (incomingById.length != bundle.observations.length ||
        incomingById.keys.any((id) => id.trim().isEmpty)) {
      identityIssues.add({
        'cluster_key': 'observation_identity',
        'status': 'invalid_observation_identity',
        'needs_human_review': true,
        'source_doc_refs': <String>[],
        'explanation':
            'Incoming observation IDs must be non-empty and globally unique.',
      });
    }
    for (final fact in bundle.resolvedFacts) {
      final original =
          incomingById[fact.chosenObservationId] ??
          previousObservations[fact.chosenObservationId];
      if (original == null ||
          original.entityKey != fact.entityKey ||
          original.attributeCode != fact.attributeCode ||
          original.scopeHash != fact.scopeHash ||
          original.unit != fact.resolvedUnit ||
          jsonEncode(original.value.toJson()) !=
              jsonEncode(fact.resolvedValue.toJson())) {
        identityIssues.add({
          'cluster_key': 'resolved_fact:${fact.factId}',
          'status': 'candidate_fact_evidence_mismatch',
          'needs_human_review': true,
          'source_doc_refs': original == null
              ? <String>[]
              : [original.sourceDocId],
          'explanation':
              'A candidate fact must match its original observation, scope, quantity and unit.',
        });
      }
    }
    const scopeFields = [
      'jurisdiction',
      'brand',
      'dosage_form',
      'release_type',
      'salt_form',
      'route',
      'preparation_state',
      'cooking_state',
      'plant_part',
      'cultivar',
      'sampling_frame',
    ];
    for (final scope in bundle.variantScopes) {
      final incoming = {
        'jurisdiction': scope.jurisdiction,
        'brand': scope.brand,
        'dosage_form': scope.dosageForm,
        'release_type': scope.releaseType,
        'salt_form': scope.saltForm,
        'route': scope.route,
        'preparation_state': scope.preparationState,
        'cooking_state': scope.cookingState,
        'plant_part': scope.plantPart,
        'cultivar': scope.cultivar,
        'sampling_frame': scope.samplingFrame,
      };
      for (final previous in previousScopeRows.where(
        (row) =>
            row['scope_hash'] == scope.scopeHash &&
            row.containsKey('jurisdiction'),
      )) {
        if (scopeFields.any((field) => previous[field] != incoming[field])) {
          identityIssues.add({
            'cluster_key': 'variant_scope:${scope.scopeHash}',
            'status': 'scope_identity_collision',
            'needs_human_review': true,
            'source_doc_refs': <String>[],
            'explanation':
                'Different scope dimensions cannot replace an existing immutable scope hash.',
          });
        }
      }
    }
    final sourceById = <String, SourceDocumentRecord>{
      for (final row in previousSourceRows)
        '${row['source_doc_id']}': _sourceFromRow(row),
      for (final doc in bundle.sourceDocuments) doc.sourceDocId: doc,
    };
    final scopesByHash = <String, VariantScopeRecord>{
      for (final row in previousScopeRows)
        '${row['scope_hash']}': VariantScopeRecord(
          scopeHash: '${row['scope_hash']}',
          jurisdiction: '${row['jurisdiction'] ?? ''}',
          brand: row['brand']?.toString(),
          dosageForm: row['dosage_form']?.toString(),
          releaseType: row['release_type']?.toString(),
          saltForm: row['salt_form']?.toString(),
          route: row['route']?.toString(),
          preparationState: row['preparation_state']?.toString(),
          cookingState: row['cooking_state']?.toString(),
          plantPart: row['plant_part']?.toString(),
          cultivar: row['cultivar']?.toString(),
          samplingFrame: row['sampling_frame']?.toString(),
        ),
      for (final scope in bundle.variantScopes) scope.scopeHash: scope,
    };
    final grouped = <String, List<ObservationRecord>>{};
    for (final observation in bundle.observations) {
      // FDC labels are retained above as per-serving evidence, not promoted
      // per-100 g composition. Comparing the two bases in one numeric cluster
      // would hold an otherwise valid import without a comparable conflict.
      if (observation.domain == 'food' &&
          observation.basisType == 'per_serving_label' &&
          observation.methodCode == 'fdc:label_nutrients' &&
          sourceById[observation.sourceDocId]?.sourceFamily == 'FDC' &&
          !bundle.resolvedFacts.any(
            (fact) => fact.chosenObservationId == observation.observationId,
          )) {
        final historicalReferences = previousFacts
            .where(
              (fact) => fact.chosenObservationId == observation.observationId,
            )
            .toList(growable: false);
        if (historicalReferences.isEmpty) {
          continue;
        }
        // Evidence-only labels must not overwrite an adopted original. Check
        // its entity/attribute here, before grouping could hide that incumbent;
        // the complete original payload is checked by the conflict engine.
        if (historicalReferences.any(
          (fact) =>
              fact.entityKey != observation.entityKey ||
              fact.attributeCode != observation.attributeCode,
        )) {
          identityIssues.add({
            'cluster_key': 'observation:${observation.observationId}',
            'status': 'historical_observation_identity_collision',
            'source_doc_refs': [observation.sourceDocId],
            'needs_human_review': true,
            'explanation':
                'An adopted observation identity cannot be reassigned to a different entity or attribute.',
          });
          continue;
        }
      }
      final key = [
        observation.domain,
        observation.entityType,
        observation.entityKey,
        observation.attributeCode,
      ].join('|');
      grouped.putIfAbsent(key, () => <ObservationRecord>[]).add(observation);
    }

    final rationales = <Map<String, dynamic>>[...identityIssues];
    for (final payload in identityIssues) {
      await database.insertConflictAuditLog(
        ConflictAuditLogRecord(
          auditId:
              'source_identity_${stableHash('$runId:${payload['cluster_key']}')}',
          snapshotId: snapshotId,
          runId: runId,
          auditType: 'IMPORT_EVIDENCE_IDENTITY_HOLD',
          target: '${payload['cluster_key']}',
          decision: '${payload['status']}',
          winningRuleIdsJson: '[]',
          suppressedRuleIdsJson: '[]',
          sourceDocRefsJson: jsonEncode(payload['source_doc_refs']),
          inputHash: stableHash(jsonEncode(payload)),
          decisionReason: jsonEncode(payload),
          machineActionsJson: '[{"type":"open_manual_conflict_review"}]',
          humanMessage: '${payload['explanation']}',
          needsHumanReview: true,
          createdAt: createdAt,
        ),
      );
    }
    // Ranking under an ambiguous document/scope identity would fabricate
    // provenance. Retain the identity hold before constructing numeric edges.
    if (identityIssues.isNotEmpty) return rationales;
    for (final entry in grouped.entries) {
      final first = entry.value.first;
      final incumbents = previousFacts
          .where(
            (fact) =>
                fact.entityKey == first.entityKey &&
                fact.attributeCode == first.attributeCode,
          )
          .toList(growable: false);
      // A lone missing raw observation is retained as evidence, not promoted
      // as a resolved number. Other clusters and all incumbents are audited.
      if (entry.value.length == 1 &&
          incumbents.isEmpty &&
          !bundle.resolvedFacts.any(
            (fact) => fact.chosenObservationId == first.observationId,
          )) {
        continue;
      }
      final resolution = factConflictEngine.resolveCluster(
        observations: entry.value,
        existingFacts: incumbents,
        existingObservationsById: previousObservations,
        sourceDocumentsById: sourceById,
        scopesByHash: scopesByHash,
      );
      final accepted = resolution.chosenObservation;
      final payload = {
        'cluster_key': entry.key,
        'incumbent_fact_ids': incumbents.map((fact) => fact.factId).toList()
          ..sort(),
        'status': resolution.status,
        'accepted': accepted == null
            ? null
            : {
                'observation_id': accepted.observationId,
                'source_doc_id': accepted.sourceDocId,
                'entity_key': accepted.entityKey,
                'attribute_code': accepted.attributeCode,
                'scope_hash': accepted.scopeHash,
                'confidence': accepted.extractionConfidence,
                'rationale': resolution.acceptedRationale,
              },
        'rejected': resolution.rejectedRationales,
        'comparison_edges': resolution.comparisonEdges,
        'explanation': resolution.explanation,
        'needs_human_review': resolution.needsManualReview,
      };
      final review = reviewedChoices[entry.key];
      if (review != null) {
        if (!resolution.needsManualReview ||
            identifierFactory.inputDigest(
                  'reviewed-original-rationale',
                  payload,
                ) !=
                review.originalRationaleSha256) {
          throw StateError(
            'The original comparison changed before activation.',
          );
        }
        // Only this private path, built from current original decisions, can
        // derive a new choice. Preserve the entire original graph and hold.
        payload.addAll({
          'status': 'explicit_source_review_choice',
          'accepted': {
            'observation_id': review.observation.observationId,
            'source_doc_id': review.observation.sourceDocId,
            'entity_key': review.observation.entityKey,
            'attribute_code': review.observation.attributeCode,
            'scope_hash': review.observation.scopeHash,
            'rationale': 'explicit_local_source_review',
          },
          'needs_human_review': false,
          'original_rationale': review.originalRationale,
          'original_conflict_audit_id': review.originalAuditId,
          'review_decision_id': review.decisionId,
          'rejected': [
            for (final id
                in {
                      for (final edge in resolution.comparisonEdges) ...[
                        edge['left_observation_id'],
                        edge['right_observation_id'],
                      ],
                    }
                    .where((id) => id != review.observation.observationId)
                    .toList()
                  ..sort((a, b) => '$a'.compareTo('$b')))
              {
                'observation_id': id,
                'rationale': 'not_selected_in_explicit_source_review',
              },
          ],
          'explanation':
              'Explicit local source choice; original alternatives and comparison retained.',
          'clinical_approval': false,
        });
      }
      rationales.add(payload);
      await database.insertConflictAuditLog(
        ConflictAuditLogRecord(
          auditId: 'fact_cluster_${stableHash('$runId:${entry.key}')}',
          snapshotId: snapshotId,
          runId: runId,
          auditType: 'FACT_CLUSTER_RESOLUTION',
          target: entry.key,
          decision: '${payload['status']}',
          winningRuleIdsJson: jsonEncode(
            review != null
                ? [review.observation.observationId]
                : accepted == null
                ? const <String>[]
                : [accepted.observationId],
          ),
          suppressedRuleIdsJson: jsonEncode(
            (payload['rejected'] as List)
                .cast<Map>()
                .map((item) => item['observation_id'])
                .whereType<String>()
                .toList(growable: false),
          ),
          sourceDocRefsJson: jsonEncode(
            {
              ...entry.value.map((item) => item.sourceDocId),
              for (final fact in incumbents)
                if (previousObservations[fact.chosenObservationId] != null)
                  previousObservations[fact.chosenObservationId]!.sourceDocId,
            }.toList()..sort(),
          ),
          inputHash: stableHash(jsonEncode(payload)),
          decisionReason: jsonEncode(payload),
          machineActionsJson: jsonEncode([
            {
              'type': payload['needs_human_review'] == true
                  ? 'open_manual_conflict_review'
                  : review != null
                  ? 'accept_explicit_review_choice'
                  : 'accept_ranked_observation',
              'params': payload,
            },
          ]),
          humanMessage: '${payload['explanation']}',
          needsHumanReview: payload['needs_human_review'] == true,
          createdAt: createdAt,
        ),
      );
    }
    return rationales;
  }

  ObservationRecord _observationFromRow(Map<String, Object?> row) =>
      ObservationRecord(
        observationId: '${row['observation_id']}',
        domain: '${row['domain']}',
        entityType: '${row['entity_type']}',
        entityKey: '${row['entity_key']}',
        attributeCode: '${row['attribute_code']}',
        valueType: '${row['value_type']}',
        value: _valueFromRow(row),
        unit: '${row['unit']}',
        basisType: '${row['basis_type']}',
        basisAmount: (row['basis_amount'] as num?)?.toDouble(),
        scopeHash: '${row['scope_hash']}',
        sourceDocId: '${row['source_doc_id']}',
        recordLocator: '${row['record_locator']}',
        methodCode: row['method_code']?.toString(),
        extractionConfidence:
            (row['extraction_confidence'] as num?)?.toDouble() ?? 0,
      );

  QualifiedValue _valueFromRow(
    Map<String, Object?> row, {
    bool resolved = false,
  }) => QualifiedValue(
    rawValueText: '${row['raw_value_text'] ?? ''}',
    qualifierKind: _qualifierKindFromWireValue(
      '${row['qualifier_kind'] ?? 'missing'}',
    ),
    low: (row[resolved ? 'resolved_low' : 'low'] as num?)?.toDouble(),
    high: (row[resolved ? 'resolved_high' : 'high'] as num?)?.toDouble(),
    valueNum: (row['value_num'] as num?)?.toDouble(),
  );

  ResolvedFactRecord _factFromRow(Map<String, Object?> row) =>
      ResolvedFactRecord(
        factId: '${row['fact_id']}',
        entityKey: '${row['entity_key']}',
        attributeCode: '${row['attribute_code']}',
        scopeHash: '${row['scope_hash']}',
        resolutionStatus: '${row['resolution_status']}',
        chosenObservationId: '${row['chosen_observation_id']}',
        resolvedValue: _valueFromRow(row, resolved: true),
        resolvedUnit: '${row['resolved_unit']}',
        resolutionPolicyId: '${row['resolution_policy_id']}',
        snapshotId: '${row['snapshot_id']}',
        factVersion: '${row['fact_version']}',
        manualOverride:
            row['manual_override'] == true || row['manual_override'] == 1,
      );

  SourceDocumentRecord _sourceFromRow(Map<String, Object?> row) =>
      SourceDocumentRecord(
        sourceDocId: '${row['source_doc_id']}',
        sourceFamily: '${row['source_family']}',
        dataTier: '${row['data_tier'] ?? ''}',
        ingestionStrategy: '${row['ingestion_strategy'] ?? ''}',
        organization: '${row['organization'] ?? ''}',
        jurisdiction: '${row['jurisdiction'] ?? ''}',
        docType: '${row['doc_type'] ?? ''}',
        title: '${row['title'] ?? ''}',
        originUrl: '${row['origin_url'] ?? ''}',
        publishedAt: row['published_at'] is num
            ? DateTime.fromMillisecondsSinceEpoch(
                (row['published_at'] as num).toInt(),
              )
            : null,
        effectiveAt: row['effective_at'] is num
            ? DateTime.fromMillisecondsSinceEpoch(
                (row['effective_at'] as num).toInt(),
              )
            : null,
        language: '${row['language'] ?? ''}',
        licenseNote: '${row['license_note'] ?? ''}',
        checksum: '${row['checksum'] ?? ''}',
        sourceStatus: '${row['source_status'] ?? ''}',
        rawPayload: '${row['raw_payload'] ?? ''}',
      );

  Map<String, Object?> _sourceEvidencePayload(SourceDocumentRecord source) => {
    'source_doc_id': source.sourceDocId,
    'source_family': source.sourceFamily,
    'data_tier': source.dataTier,
    'ingestion_strategy': source.ingestionStrategy,
    'organization': source.organization,
    'jurisdiction': source.jurisdiction,
    'doc_type': source.docType,
    'title': source.title,
    'origin_url': source.originUrl,
    'published_at': source.publishedAt?.millisecondsSinceEpoch,
    'effective_at': source.effectiveAt?.millisecondsSinceEpoch,
    'language': source.language,
    'license_note': source.licenseNote,
    'checksum': source.checksum,
    'source_status': source.sourceStatus,
    'raw_payload': source.rawPayload,
  };

  // Rows not covered by the existing staging tables stay in the digest-bound
  // review packet. This preserves the original import; it does not activate it.
  Map<String, Object?> _retainedCatalogReviewRows(P0ImportBundle bundle) => {
    'country_diet_profile': [
      for (final row in bundle.countryDietProfiles)
        {
          'country_code': row.countryCode,
          'guideline_source': row.guidelineSource,
          'meal_pattern_json': row.mealPatternJson,
          'staple_foods_json': row.stapleFoodsJson,
          'preferred_protein_sources_json': row.preferredProteinSourcesJson,
          'avoidance_notes_json': row.avoidanceNotesJson,
        },
    ],
    'food_concept': [
      for (final row in bundle.foodConcepts)
        {
          'food_concept_id': row.foodConceptId,
          'canonical_name_en': row.canonicalNameEn,
          'canonical_name_zh': row.canonicalNameZh,
          'food_group': row.foodGroup,
        },
    ],
    'drug_concept': [
      for (final row in bundle.drugConcepts)
        {
          'drug_concept_id': row.drugConceptId,
          'generic_name': row.genericName,
          'atc_like_code': row.atcLikeCode,
        },
    ],
    'drug_label_section': [
      for (final row in bundle.drugLabelSections)
        {
          'section_id': row.sectionId,
          'drug_product_variant_id': row.drugProductVariantId,
          'source_doc_id': row.sourceDocId,
          'section_key': row.sectionKey,
          'section_title': row.sectionTitle,
          'section_text': row.sectionText,
        },
    ],
    'drug_product_code': [
      for (final row in bundle.drugProductCodes)
        {
          'product_code_id': row.productCodeId,
          'drug_product_variant_id': row.drugProductVariantId,
          'source_doc_id': row.sourceDocId,
          'code_system': row.codeSystem,
          'code_value': row.codeValue,
          'display_text': row.displayText,
        },
    ],
    'drug_product_packaging': [
      for (final row in bundle.drugProductPackagings)
        {
          'packaging_id': row.packagingId,
          'drug_product_variant_id': row.drugProductVariantId,
          'source_doc_id': row.sourceDocId,
          'package_code': row.packageCode,
          'description': row.description,
          'marketing_status': row.marketingStatus,
        },
    ],
    'drug_product_media': [
      for (final row in bundle.drugProductMedias)
        {
          'media_id': row.mediaId,
          'drug_product_variant_id': row.drugProductVariantId,
          'source_doc_id': row.sourceDocId,
          'media_type': row.mediaType,
          'media_url': row.mediaUrl,
          'caption': row.caption,
        },
    ],
    'projected_foods': [for (final row in bundle.projectedFoods) row.toJson()],
    'projected_drugs': [for (final row in bundle.projectedDrugs) row.toJson()],
  };

  static const _reviewStagingTables = [
    'staging_food_variant',
    'staging_drug_product_variant',
    'staging_variant_scope',
    'staging_observation',
    'staging_resolved_fact',
    'staging_rule_registry',
    'staging_runtime_event',
    'staging_concept_variant_crosswalk',
  ];

  List<Map<String, Object?>> _stableReviewRows(
    Iterable<Map<String, Object?>> rows,
  ) => rows.toList()
    ..sort(
      (a, b) => identifierFactory
          .inputDigest('import-review-row', a)
          .compareTo(identifierFactory.inputDigest('import-review-row', b)),
    );

  Future<Map<String, Object?>> _reviewStagingEvidence(String runId) async => {
    for (final table in _reviewStagingTables)
      table: _stableReviewRows(
        (await database.queryTable(
          table,
        )).where((row) => row['run_id'] == runId),
      ),
  };

  Future<Map<String, Object?>> _reviewIncumbentEvidence(
    List<Map<String, Object?>> incoming,
    List<Map<String, Object?>> incomingSources,
    List<Object?> reviewedScopeHashes,
  ) async {
    final keys = incoming
        .map((row) => '${row['entity_key']}|${row['attribute_code']}')
        .toSet();
    final facts = (await database.queryTable('resolved_fact'))
        .where(
          (row) =>
              keys.contains('${row['entity_key']}|${row['attribute_code']}'),
        )
        .toList();
    final observationIds = {
      ...incoming.map((row) => row['observation_id']),
      ...facts.map((row) => row['chosen_observation_id']),
    };
    final originals = (await database.queryTable(
      'observation',
    )).where((row) => observationIds.contains(row['observation_id'])).toList();
    final sourceIds = {
      ...incomingSources.map((row) => row['source_doc_id']),
      ...incoming.map((row) => row['source_doc_id']),
      ...originals.map((row) => row['source_doc_id']),
    };
    final scopeHashes = {
      ...reviewedScopeHashes,
      ...incoming.map((row) => row['scope_hash']),
      ...facts.map((row) => row['scope_hash']),
      ...originals.map((row) => row['scope_hash']),
    };
    return {
      'resolved_fact': _stableReviewRows(facts),
      'observation': _stableReviewRows(originals),
      'source_document': _stableReviewRows(
        (await database.queryTable(
          'source_document',
        )).where((row) => sourceIds.contains(row['source_doc_id'])),
      ),
      'variant_scope': _stableReviewRows(
        (await database.queryTable(
          'variant_scope',
        )).where((row) => scopeHashes.contains(row['scope_hash'])),
      ),
    };
  }

  /// Reads the complete held evidence from the existing ingestion backend.
  /// Inline sidecar URIs are not used as a persistence guarantee. A packet is
  /// usable only while staging, original audits and incumbent evidence match.
  Future<Map<String, dynamic>> loadHeldImportReviewEvidence({
    required String snapshotId,
  }) => _loadHeldImportReviewEvidence(snapshotId: snapshotId);

  /// Historical content remains readable after a derived activation or later
  /// source changes. This archive never satisfies the current activation gate.
  Future<Map<String, dynamic>> loadHeldImportReviewArchive({
    required String snapshotId,
  }) async => {
    'validation_scope': 'original_packet_identity_only',
    'current_activation_eligible': false,
    'evidence': await _loadHeldImportReviewEvidence(
      snapshotId: snapshotId,
      requireCurrentIncumbents: false,
    ),
  };

  Future<Map<String, dynamic>> _loadHeldImportReviewEvidence({
    required String snapshotId,
    bool requireCurrentIncumbents = true,
  }) async {
    await database.initialize();
    final rows = (await database.queryTable('ingestion_run'))
        .where(
          (row) =>
              row['snapshot_id'] == snapshotId &&
              row['status'] == 'held_for_conflict_review',
        )
        .toList();
    if (rows.length != 1) {
      throw StateError('Held import evidence is unavailable or ambiguous.');
    }
    final notes = jsonDecode(rows.single['notes_json'] as String) as Map;
    final evidence = Map<String, dynamic>.from(
      notes['review_evidence'] as Map? ?? {},
    );
    final payload = Map<String, dynamic>.from(
      evidence['payload'] as Map? ?? {},
    );
    final runId = payload['run_id'];
    final schema = evidence['schema'];
    final retained = payload['retained_catalog_rows'];
    final completeRetainedRows =
        retained is Map &&
        const [
          'country_diet_profile',
          'food_concept',
          'drug_concept',
          'drug_label_section',
          'drug_product_code',
          'drug_product_packaging',
          'drug_product_media',
          'projected_foods',
          'projected_drugs',
        ].every((key) => retained[key] is List);
    if (!const {
          'parkinsum.held-import-review-evidence/1',
          'parkinsum.held-import-review-evidence/2',
        }.contains(schema) ||
        (schema == 'parkinsum.held-import-review-evidence/2' &&
            !completeRetainedRows) ||
        payload['snapshot_id'] != snapshotId ||
        runId is! String ||
        rows.single['run_id'] != '${runId}_promote' ||
        evidence['input_sha256'] !=
            identifierFactory.inputDigest(
              'held-import-review-evidence',
              payload,
            )) {
      throw StateError('Held import evidence identity does not match.');
    }
    final snapshots = (await database.queryTable(
      'engine_snapshot',
    )).where((row) => row['snapshot_id'] == snapshotId).toList();
    if (snapshots.length != 1 ||
        snapshots.single['promoted_at'] != null ||
        snapshots.single['input_hash'] != payload['snapshot_input_hash']) {
      throw StateError('Held snapshot identity changed.');
    }
    final audits = _stableReviewRows(
      (await database.queryTable('conflict_audit_log')).where(
        (row) =>
            row['snapshot_id'] == snapshotId &&
            row['run_id'] == runId &&
            (row['audit_type'] == 'FACT_CLUSTER_RESOLUTION' ||
                row['audit_type'] == 'IMPORT_EVIDENCE_IDENTITY_HOLD'),
      ),
    );
    final incoming = (payload['observations'] as List)
        .map((row) => Map<String, Object?>.from(row as Map))
        .toList();
    final sources = (payload['source_documents'] as List)
        .map((row) => Map<String, Object?>.from(row as Map))
        .toList();
    final current = {
      'staging_rows': await _reviewStagingEvidence(runId),
      'conflict_audits': audits,
      if (requireCurrentIncumbents)
        'incumbent_evidence': await _reviewIncumbentEvidence(
          incoming,
          sources,
          (payload['scope_hashes'] as List).cast<Object?>(),
        ),
    };
    for (final entry in current.entries) {
      if (identifierFactory.inputDigest(
            'import-review-bound-state',
            entry.value,
          ) !=
          identifierFactory.inputDigest(
            'import-review-bound-state',
            payload[entry.key],
          )) {
        throw StateError('Held review evidence is stale: ${entry.key}.');
      }
    }
    return evidence;
  }

  Future<void> _holdImport({
    required String runId,
    required String snapshotId,
    required P0ImportBundle bundle,
    required List<Map<String, dynamic>> rationales,
    required DateTime createdAt,
    String? parentSnapshotId,
  }) async {
    final incoming = [
      for (final row in bundle.observations)
        <String, Object?>{
          'observation_id': row.observationId,
          'domain': row.domain,
          'entity_type': row.entityType,
          'entity_key': row.entityKey,
          'attribute_code': row.attributeCode,
          'value_type': row.valueType,
          'source_doc_id': row.sourceDocId,
          'record_locator': row.recordLocator,
          'scope_hash': row.scopeHash,
          'method_code': row.methodCode,
          'basis_type': row.basisType,
          'basis_amount': row.basisAmount,
          'unit': row.unit,
          'extraction_confidence': row.extractionConfidence,
          ...row.value.toJson(),
        },
    ];
    final sources = [
      for (final source in bundle.sourceDocuments)
        _sourceEvidencePayload(source),
    ];
    final snapshots = await database.queryTable('engine_snapshot');
    final scopeHashes =
        bundle.variantScopes.map((row) => row.scopeHash).toList()..sort();
    final payload = <String, Object?>{
      'snapshot_id': snapshotId,
      'run_id': runId,
      'snapshot_input_hash': snapshots.singleWhere(
        (row) => row['snapshot_id'] == snapshotId,
      )['input_hash'],
      'source_documents': sources,
      'retained_catalog_rows': _retainedCatalogReviewRows(bundle),
      'scope_hashes': scopeHashes,
      'observations': incoming,
      'conflict_rationales': rationales,
      'staging_rows': await _reviewStagingEvidence(runId),
      'conflict_audits': _stableReviewRows(
        (await database.queryTable('conflict_audit_log')).where(
          (row) =>
              row['snapshot_id'] == snapshotId &&
              row['run_id'] == runId &&
              (row['audit_type'] == 'FACT_CLUSTER_RESOLUTION' ||
                  row['audit_type'] == 'IMPORT_EVIDENCE_IDENTITY_HOLD'),
        ),
      ),
      'incumbent_evidence': await _reviewIncumbentEvidence(
        incoming,
        sources,
        scopeHashes,
      ),
    };
    final evidence = {
      'schema': 'parkinsum.held-import-review-evidence/2',
      'input_sha256': identifierFactory.inputDigest(
        'held-import-review-evidence',
        payload,
      ),
      'payload': payload,
    };
    Future<void> saveHold(Map<String, Object?> artifactNotes) =>
        database.insertIngestionRun(
          IngestionRunRecord(
            runId: '${runId}_promote',
            sourceFamily: _bundleSourceFamily(bundle),
            stage: 'promote',
            status: 'held_for_conflict_review',
            snapshotId: snapshotId,
            parentSnapshotId: parentSnapshotId,
            createdAt: createdAt,
            completedAt: DateTime.now(),
            notesJson: jsonEncode({
              'activated': false,
              'review_evidence': evidence,
              ...artifactNotes,
              'checkpoint': {
                'phase': 'conflict_review_required',
                'retained_staging_run_id': runId,
              },
            }),
          ),
        );
    // Persist the complete source packet before optional sidecar I/O.
    await saveHold({});
    await loadHeldImportReviewEvidence(snapshotId: snapshotId);
    try {
      final artifacts = await _writeArtifactSet(
        artifactId: 'held_import_$runId',
        snapshotId: snapshotId,
        channel: 'import_run',
        distributionType: 'import_artifacts',
        createdAt: createdAt,
        files: {
          'conflict_rationale.json': jsonEncode(rationales),
          'source_evidence.json': jsonEncode(evidence),
          'release_readiness.json': jsonEncode({
            'status': 'held_for_conflict_review',
            'staging_snapshot_id': snapshotId,
            'activated': false,
            'blocking_issues': [
              for (final row in rationales)
                if (row['needs_human_review'] == true)
                  'unresolved_conflict:${row['cluster_key']}',
            ],
          }),
        },
        manifest: {
          'kind': 'held_import',
          'run_id': runId,
          'snapshot_id': snapshotId,
          'activated': false,
        },
      );
      await saveHold({
        'artifact_path': artifacts.artifactPath,
        'artifact_files': artifacts.files,
      });
    } catch (_) {
      // The optional filesystem/inline attachment cannot discard the packet or
      // turn a known conflict into an ordinary retryable promote failure.
      await saveHold({'artifact_warning': 'sidecar_write_failed'});
    }
    await loadHeldImportReviewEvidence(snapshotId: snapshotId);
    // Counts only; raw source content remains in the review artifact.
    // ignore: avoid_print
    print(
      '[CDSS] import held for conflict review; clusters=${rationales.where((row) => row['needs_human_review'] == true).length}',
    );
  }

  List<Map<String, dynamic>> _ruleHitTrace({
    required List<RuleRegistryEntry> rules,
    required List<RuleEvaluationCandidate> candidates,
    required Map<String, List<RuleEvaluationCandidate>> groupedCandidates,
    required Map<String, SameBandEscalation> sameBandByTarget,
    required UnifiedRuntimeContext context,
    required List<String> jurisdictionChain,
    required String regionJurisdictionMapSource,
  }) {
    final candidateByRuleId = {
      for (final candidate in candidates) candidate.rule.ruleId: candidate,
    };
    final winnerByTarget = {
      for (final entry in groupedCandidates.entries)
        entry.key: entry.value.first,
    };
    final suppressedByTarget = {
      for (final entry in groupedCandidates.entries)
        entry.key: entry.value.skip(1).map((item) => item.rule.ruleId).toSet(),
    };
    return rules
        .map((rule) {
          final candidate = candidateByRuleId[rule.ruleId];
          final target = rule.target;
          final winner = winnerByTarget[target];
          final sameBand = sameBandByTarget[target];
          final missingFields = runtimeRuleSupport
              .missingFieldsForRule(context: context, rule: rule)
              .toList(growable: false);
          final jurisdictionMatched = runtimeRuleEngine.jurisdictionMatches(
            rule.jurisdictions,
            jurisdictionChain,
          );
          final jurisdictionSpecificity = _jurisdictionSpecificity(
            rule.jurisdictions,
            jurisdictionChain,
          );
          final suppressed =
              suppressedByTarget[target]?.contains(rule.ruleId) ?? false;
          final matched = candidate != null;
          String decision;
          if (!jurisdictionMatched) {
            decision = 'not_applicable_jurisdiction';
          } else if (!matched) {
            decision = 'not_matched';
          } else if (suppressed) {
            decision = 'suppressed';
          } else {
            decision = 'matched';
          }
          return {
            'rule_id': rule.ruleId,
            'rule_version': rule.version,
            'target': target,
            'decision': rule.thenClause.decision.wireValue,
            'trace_decision': decision,
            'matched': matched,
            'suppressed': suppressed,
            'winner': winner?.rule.ruleId == rule.ruleId,
            'priority_band': rule.priorityBand,
            'specificity_band': rule.specificityBand,
            'priority': rule.priorityBand,
            'specificity': rule.specificityBand,
            'evidence_level': rule.provenance.evidenceLevel,
            'source_status': rule.status,
            'source_authority': rule.sourceAuthority,
            'effective_from': rule.provenance.effectiveFrom?.toIso8601String(),
            'provenance_score': {
              'evidence_level': rule.provenance.evidenceLevel,
              'source_authority': rule.sourceAuthority,
              'source_status': rule.status,
              'effective_from': rule.provenance.effectiveFrom
                  ?.toIso8601String(),
              'recency':
                  rule.provenance.effectiveFrom?.millisecondsSinceEpoch ?? 0,
              'specificity_band': rule.specificityBand,
              'jurisdiction_specificity': jurisdictionSpecificity,
              'priority_band': rule.priorityBand,
            },
            'source_refs': rule.provenance.sourceRefs,
            'jurisdictions': rule.jurisdictions,
            'jurisdiction_chain': jurisdictionChain,
            'region_jurisdiction_source': regionJurisdictionMapSource,
            'jurisdiction_matched': jurisdictionMatched,
            'jurisdiction_specificity': jurisdictionSpecificity,
            'referenced_paths': runtimeRuleSupport
                .collectReferencedPaths(rule.conditions)
                .toList(growable: false),
            'missing_fields': missingFields,
            'missing_field_reason': missingFields.isEmpty
                ? null
                : 'missing_${missingFields.join("_")}',
            'tie_break_reason': matched ? sameBand?.reason : null,
            'suppressed_rule_ids': matched
                ? (sameBand?.suppressedRuleIds ?? const <String>[])
                : const <String>[],
            'explanation': candidate?.explanation,
            'evidence': candidate?.evidence ?? const <String, dynamic>{},
          };
        })
        .toList(growable: false);
  }

  int _jurisdictionSpecificity(
    List<String> ruleJurisdictions,
    List<String> jurisdictionChain,
  ) {
    if (ruleJurisdictions.contains('*')) return 0;
    var best = -1;
    for (final value in ruleJurisdictions) {
      final index = jurisdictionChain.indexOf(value.toUpperCase());
      if (index == -1) continue;
      if (best == -1 || index < best) best = index;
    }
    return best == -1 ? 0 : jurisdictionChain.length - best;
  }

  /// Selects the most appropriate display message for the current UI locale.
  ///
  /// Implementation now delegates to `RuleMessageSet.forLocale`, which checks
  /// (in order): exact `localeTag` → language family → `en` → `zh`. For
  /// language families with no rule-level translation yet (e.g. `fr`, `ja`,
  /// `ko`, `hi`, `es`, `vi`, `th`, `id`, `ru`, `pl`, `ar`), this still
  /// gracefully falls back to `en` then `zh` exactly like before.
  String _localizedRuleMessage(AppI18n i18n, RuleMessageSet messages) {
    return messages.forLocale(i18n.localeTag);
  }

  Future<List<EvidenceReferenceDetail>> _resolveEvidenceDetails(
    List<String> sourceRefs,
  ) async {
    if (sourceRefs.isEmpty) {
      return const <EvidenceReferenceDetail>[];
    }
    final rows = await database.queryTable('source_document');
    final byId = <String, Map<String, Object?>>{
      for (final row in rows) '${row['source_doc_id']}': row,
    };
    return sourceRefs
        .map((ref) {
          final row = byId[ref];
          if (row == null) {
            return EvidenceReferenceDetail(sourceRef: ref, title: ref);
          }
          final title = '${row['title'] ?? ref}';
          final originUrl = '${row['origin_url'] ?? ''}';
          final sourceFamily = row['source_family']?.toString();
          final rawPayload = row['raw_payload']?.toString() ?? '';
          String? pmid;
          String? doi;
          String? publication;
          String? evidenceKind;
          if (rawPayload.isNotEmpty) {
            try {
              final payload = jsonDecode(rawPayload);
              if (payload is Map<String, dynamic>) {
                pmid = payload['pmid']?.toString();
                doi = payload['doi']?.toString();
                publication = payload['publication']?.toString();
                evidenceKind = payload['evidence_kind']?.toString();
              }
            } catch (_) {
              // 老数据可能不是 JSON；此时回退到 title/origin_url 即可。
            }
          }
          return EvidenceReferenceDetail(
            sourceRef: ref,
            title: title,
            pmid: (pmid != null && pmid.isNotEmpty) ? pmid : null,
            doi: (doi != null && doi.isNotEmpty) ? doi : null,
            sourceUrl: originUrl.isNotEmpty ? originUrl : null,
            publication: (publication != null && publication.isNotEmpty)
                ? publication
                : null,
            evidenceKind: (evidenceKind != null && evidenceKind.isNotEmpty)
                ? evidenceKind
                : null,
            sourceFamily: (sourceFamily != null && sourceFamily.isNotEmpty)
                ? sourceFamily
                : null,
          );
        })
        .toList(growable: false);
  }

  String _formatEvidenceDetail(EvidenceReferenceDetail detail) {
    final parts = <String>[
      if (detail.publication != null && detail.publication!.isNotEmpty)
        detail.publication!,
      if (detail.evidenceKind != null && detail.evidenceKind!.isNotEmpty)
        detail.evidenceKind!,
      if (detail.pmid != null && detail.pmid!.isNotEmpty) 'PMID ${detail.pmid}',
      if (detail.doi != null && detail.doi!.isNotEmpty) 'DOI ${detail.doi}',
      if (detail.sourceUrl != null && detail.sourceUrl!.isNotEmpty)
        detail.sourceUrl!,
    ];
    return parts.isEmpty
        ? detail.title
        : '${detail.title} (${parts.join(' · ')})';
  }

  String _appendEvidenceDetails(
    String explanation,
    List<String> evidenceDetails,
  ) {
    if (evidenceDetails.isEmpty) {
      return explanation;
    }
    return '$explanation Evidence: ${evidenceDetails.join(' | ')}';
  }

  Future<void> writeRecommendationAudit({
    required UserProfileRuntimeContext userProfile,
    required String mealSlot,
    required String factsVersion,
    required String rulesVersion,
    required List<FoodRecommendation> recommendations,
  }) async {
    await database.initialize();
    // 推荐审计保留快照与 JSON 存档；更细的推荐拒绝分组仍由推荐服务自身演进。
    final jurisdictionChain = userProfile.contentJurisdictionOverride.isNotEmpty
        ? userProfile.contentJurisdictionOverride
        : runtimeRuleEngine.resolveJurisdictionChain(
            UnifiedRuntimeContext(
              userProfile: userProfile,
              drug: const DrugRuntimeContext(
                id: 'recommendation_context',
                genericName: 'none',
                brandName: null,
                activeIngredients: <String>[],
                substanceTags: <String>[],
                formulation: '',
                dosageForm: '',
                route: '',
                releaseType: '',
                dailyDoseMg: null,
                jurisdiction: null,
              ),
              meal: null,
              coevent: null,
              enteralFeed: null,
              timestamps: const TimestampRuntimeContext(
                drugTime: null,
                mealTime: null,
                coeventTime: null,
              ),
            ),
          );
    final inputHash = identifierFactory.inputDigest('recommendation-audit', {
      'patient_id': userProfile.patientId,
      'meal_slot': mealSlot,
      'facts_version': factsVersion,
      'rules_version': rulesVersion,
      'recommendations': recommendations.map((item) => item.food.id).toList(),
    });
    final snapshotId = identifierFactory.newId('recommendation_snapshot');
    await database.insertEngineSnapshot(
      EngineSnapshotRecord(
        snapshotId: snapshotId,
        factsVersion: factsVersion,
        rulesVersion: rulesVersion,
        createdAt: DateTime.now(),
        promotedAt: null,
        rollbackParent: null,
        inputHash: inputHash,
      ),
    );

    final accepted = recommendations
        .map(
          (item) => {
            'food_id': item.food.id,
            'decision': item.decision,
            'jurisdiction': item.jurisdiction,
            'fallback_used': item.fallbackUsed,
            'score': item.score,
            'reasons': item.reasons,
          },
        )
        .toList(growable: false);
    final rejected = recommendations
        .where((item) => item.decision == 'BLOCK')
        .map((item) => {'food_id': item.food.id, 'decision': item.decision})
        .toList(growable: false);
    final scoreBreakdown = {
      for (final item in recommendations) item.food.id: item.scoreBreakdown,
    };

    await database.insertRecommendationAuditLog(
      RecommendationAuditLogRecord(
        recAuditId: identifierFactory.newId('rec'),
        userId: userProfile.patientId,
        mealSlot: mealSlot,
        snapshotId: snapshotId,
        jurisdictionChainJson: jsonEncode(jurisdictionChain),
        mealCandidatesJson: jsonEncode(
          recommendations.map((item) => item.food.id).toList(growable: false),
        ),
        rejectedByRulesJson: jsonEncode(rejected),
        acceptedChoicesJson: jsonEncode(accepted),
        scoreBreakdownJson: jsonEncode(scoreBreakdown),
        fallbackUsed: recommendations.any((item) => item.fallbackUsed),
        createdAt: DateTime.now(),
      ),
    );
  }

  String _bundleSourceFamily(P0ImportBundle bundle) {
    if (bundle.sourceDocuments.isEmpty) return 'UNKNOWN';
    final families =
        bundle.sourceDocuments.map((item) => item.sourceFamily).toSet().toList()
          ..sort();
    return families.join('+');
  }

  ResolvedFactRecord _copyResolvedFactWithSnapshot(
    ResolvedFactRecord record, {
    required String snapshotId,
    required String factVersion,
  }) {
    return ResolvedFactRecord(
      factId: '${record.factId}_$snapshotId',
      entityKey: record.entityKey,
      attributeCode: record.attributeCode,
      scopeHash: record.scopeHash,
      resolutionStatus: record.resolutionStatus,
      chosenObservationId: record.chosenObservationId,
      resolvedValue: record.resolvedValue,
      resolvedUnit: record.resolvedUnit,
      resolutionPolicyId: record.resolutionPolicyId,
      snapshotId: snapshotId,
      factVersion: factVersion,
      manualOverride: record.manualOverride,
    );
  }

  Map<String, Object?> _resolvedFactPayload(ResolvedFactRecord record) {
    return {
      'fact_id': record.factId,
      'entity_key': record.entityKey,
      'attribute_code': record.attributeCode,
      'scope_hash': record.scopeHash,
      'resolution_status': record.resolutionStatus,
      'chosen_observation_id': record.chosenObservationId,
      'resolved_low': record.resolvedValue.low,
      'resolved_high': record.resolvedValue.high,
      'qualifier_kind': record.resolvedValue.qualifierKind.wireValue,
      'value_num': record.resolvedValue.valueNum,
      'raw_value_text': record.resolvedValue.rawValueText,
      'resolved_unit': record.resolvedUnit,
      'resolution_policy_id': record.resolutionPolicyId,
      'snapshot_id': record.snapshotId,
      'fact_version': record.factVersion,
      'manual_override': record.manualOverride,
    };
  }

  Map<String, Object?> _runtimeEventPayload(RuntimeEventRecord record) {
    return {
      'event_id': record.eventId,
      'patient_id': record.patientId,
      'event_type': record.eventType,
      'snapshot_id': record.snapshotId,
      'context_json': record.contextJson,
      'machine_readable_json': record.machineReadableJson,
      'human_readable_markdown': record.humanReadableMarkdown,
      'jurisdiction': record.jurisdiction,
      'timezone': record.timezone,
      'created_at': record.createdAt.millisecondsSinceEpoch,
    };
  }

  List<ConceptVariantCrosswalkRecord> _effectiveCrosswalks(
    P0ImportBundle bundle,
    String runId,
    DateTime createdAt,
  ) {
    if (bundle.conceptVariantCrosswalks.isNotEmpty) {
      return bundle.conceptVariantCrosswalks;
    }
    final records = <ConceptVariantCrosswalkRecord>[];
    final sourceDocByFamily = <String, SourceDocumentRecord>{
      for (final doc in bundle.sourceDocuments) doc.sourceFamily: doc,
    };
    for (final variant in bundle.foodVariants) {
      final sourceDoc = sourceDocByFamily[variant.sourceFamily];
      if ((variant.sourceFoodCode ?? '').trim().isEmpty || sourceDoc == null) {
        continue;
      }
      records.add(
        ConceptVariantCrosswalkRecord(
          crosswalkId:
              'xwalk_${stableHash('food:${variant.foodVariantId}:${variant.sourceFoodCode}')}',
          domain: 'food',
          appEntityId: variant.sourceFoodCode!,
          conceptId: variant.foodConceptId,
          variantId: variant.foodVariantId,
          externalIdSystem: variant.sourceFamily,
          externalIdValue: variant.sourceFoodCode!,
          jurisdiction: variant.jurisdiction,
          sourceDocId: sourceDoc.sourceDocId,
          importRunId: runId,
          confidence: variant.isAuthoritativeForRegion ? 1.0 : 0.75,
          status: 'active',
          mappingPayloadJson: jsonEncode({
            'source': 'generated_from_imported_food_variant',
            'display_name_local': variant.displayNameLocal,
          }),
          createdAt: createdAt,
        ),
      );
    }
    for (final variant in bundle.drugProductVariants) {
      final sourceDoc = sourceDocByFamily[variant.regulator];
      if (variant.externalProductCode.trim().isEmpty || sourceDoc == null) {
        continue;
      }
      records.add(
        ConceptVariantCrosswalkRecord(
          crosswalkId:
              'xwalk_${stableHash('drug:${variant.drugProductVariantId}:${variant.externalProductCode}')}',
          domain: 'drug',
          appEntityId: variant.externalProductCode,
          conceptId: variant.drugConceptId,
          variantId: variant.drugProductVariantId,
          externalIdSystem: _canonicalDrugCodeSystem(variant.regulator),
          externalIdValue: variant.externalProductCode,
          jurisdiction: variant.jurisdiction,
          sourceDocId: sourceDoc.sourceDocId,
          importRunId: runId,
          confidence: 0.95,
          status: 'active',
          mappingPayloadJson: jsonEncode({
            'source': 'generated_from_imported_drug_product_variant',
            'regulator': variant.regulator,
            'route': variant.route,
            'dosage_form': variant.dosageForm,
            'release_type': variant.releaseType,
          }),
          createdAt: createdAt,
        ),
      );
    }
    return records;
  }

  String _canonicalDrugCodeSystem(String regulator) {
    switch (regulator.toUpperCase()) {
      case 'DAILYMED':
      case 'NLM_DAILYMED':
        return 'DailyMed setid';
      case 'HEALTH_CANADA_DPD':
      case 'DPD':
        return 'Health Canada DIN';
      case 'EMA':
        return 'EMA product code';
      case 'PMDA':
        return 'PMDA code';
      default:
        return regulator;
    }
  }

  Map<String, Object?> _crosswalkPayload(ConceptVariantCrosswalkRecord record) {
    return {
      'crosswalk_id': record.crosswalkId,
      'domain': record.domain,
      'app_entity_id': record.appEntityId,
      'concept_id': record.conceptId,
      'variant_id': record.variantId,
      'external_id_system': record.externalIdSystem,
      'external_id_value': record.externalIdValue,
      'jurisdiction': record.jurisdiction,
      'source_doc_id': record.sourceDocId,
      'import_run_id': record.importRunId,
      'confidence': record.confidence,
      'status': record.status,
      'mapping_payload_json': record.mappingPayloadJson,
      'created_at': record.createdAt.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> _ruleJsonFromRegistryRow(Map<String, Object?> row) {
    final effect = _decodeRegistryMap('${row['effect_json'] ?? '{}'}');
    final provenance = _decodeRegistryMap('${row['provenance_json'] ?? '{}'}');
    return {
      'rule_id': '${row['rule_id'] ?? ''}',
      'version': '${row['rule_version'] ?? '1.0.0'}',
      'status': '${row['status'] ?? 'inactive'}',
      'rule_type': _ruleTypeWireValue('${row['rule_type'] ?? 'soft_rule'}'),
      'priority_band': (row['priority_band'] as num?)?.toInt() ?? 0,
      'specificity_band': (row['specificity_band'] as num?)?.toInt() ?? 0,
      'jurisdiction': _decodeRegistryList(
        '${row['jurisdiction_json'] ?? '[]'}',
      ),
      'applies_to': _decodeRegistryMap('${row['applies_to_json'] ?? '{}'}'),
      'when': _decodeRegistryMap('${row['predicate_json'] ?? '{}'}'),
      'then': {
        'decision': effect['decision'] ?? 'INFO',
        'severity': effect['severity'] ?? 'low',
        'messages': effect['messages'] ?? {'zh': '规则命中', 'en': 'Rule matched'},
        'actions': effect['actions'] ?? const <Map<String, dynamic>>[],
        'output_tags': effect['output_tags'] ?? const <String>[],
      },
      'provenance': {
        'evidence_level': provenance['evidence_level'] ?? 'unknown',
        'source_refs': provenance['source_refs'] ?? const <String>[],
        'effective_from': provenance['effective_from'],
        'effective_to': provenance['effective_to'],
      },
      if ((row['override_json'] ?? '').toString().trim().isNotEmpty)
        'override': _safeDecodeMap('${row['override_json']}'),
    };
  }

  Map<String, dynamic> _decodeRegistryMap(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw FormatException('Expected JSON object in rule registry row: $raw');
  }

  List<dynamic> _decodeRegistryList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded;
    throw FormatException('Expected JSON array in rule registry row: $raw');
  }

  String _ruleTypeWireValue(String value) {
    final normalized = value.trim();
    switch (normalized) {
      case 'hardConstraint':
        return 'hard_constraint';
      case 'softRule':
        return 'soft_rule';
      case 'temporalRule':
        return 'temporal_rule';
      case 'doseDependentRule':
        return 'dose_dependent_rule';
      case 'jurisdictionOverride':
        return 'jurisdiction_override';
      case 'sourceResolutionRule':
        return 'source_resolution_rule';
      case 'escalationRule':
        return 'escalation_rule';
      case 'hard_constraint':
      case 'soft_rule':
      case 'temporal_rule':
      case 'dose_dependent_rule':
      case 'jurisdiction_override':
      case 'source_resolution_rule':
      case 'escalation_rule':
        return normalized;
      default:
        return normalized.isEmpty ? 'soft_rule' : normalized;
    }
  }

  Map<String, dynamic> _safeDecodeMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{};
  }

  String _importHumanReadable({
    required String runId,
    required P0ImportBundle bundle,
    required String promotedSnapshotId,
  }) {
    final buffer = StringBuffer('# CDSS Import\n\n')
      ..writeln('- Run: $runId')
      ..writeln('- Snapshot: $promotedSnapshotId')
      ..writeln('- Source family: ${_bundleSourceFamily(bundle)}')
      ..writeln('- Source documents: ${bundle.sourceDocuments.length}')
      ..writeln('- Observations: ${bundle.observations.length}')
      ..writeln('- Resolved facts: ${bundle.resolvedFacts.length}')
      ..writeln(
        '- Crosswalk mappings: ${bundle.conceptVariantCrosswalks.length}',
      );
    return buffer.toString();
  }

  QualifierKind _qualifierKindFromWireValue(String value) {
    return QualifierKind.values.firstWhere(
      (item) => item.wireValue == value,
      orElse: () => QualifierKind.missing,
    );
  }
}

/// 单次 CDSS 导入报告：
/// - 让上层 UI 能按 source/run 展示 counts；
/// - 同时给失败重试和最近导入任务页面提供稳定的 run 标识。
class CdssImportHeldException implements Exception {
  final String runId;
  final String stagingSnapshotId;
  const CdssImportHeldException({
    required this.runId,
    required this.stagingSnapshotId,
  });
  @override
  String toString() =>
      'Import held for conflict review; retained staging run $runId.';
}

class CdssImportReport {
  final String runId;
  final String sourceFamily;
  final String stagingSnapshotId;
  final String promotedSnapshotId;
  final int sourceDocumentCount;
  final int foodCount;
  final int drugCount;
  final int observationCount;
  final int ruleRegistryCount;
  final int runtimeEventCount;
  final DateTime completedAt;

  const CdssImportReport({
    required this.runId,
    required this.sourceFamily,
    required this.stagingSnapshotId,
    required this.promotedSnapshotId,
    required this.sourceDocumentCount,
    required this.foodCount,
    required this.drugCount,
    required this.observationCount,
    required this.ruleRegistryCount,
    required this.runtimeEventCount,
    required this.completedAt,
  });
}

final class CdssReviewedImportPreview {
  const CdssReviewedImportPreview._({
    required this.heldSnapshotId,
    required this.evidenceSha256,
    required this.stateSha256,
    required this.decisionIds,
    required this.selectedObservations,
  });
  final String heldSnapshotId;
  final String evidenceSha256;
  final String stateSha256;
  final List<String> decisionIds;
  final List<Map<String, Object?>> selectedObservations;
  Map<String, Object?> toJson() => {
    'schema': 'parkinsum.reviewed-import-preview/1',
    'held_snapshot_id': heldSnapshotId,
    'evidence_sha256': evidenceSha256,
    'state_sha256': stateSha256,
    'decision_ids': decisionIds,
    'selected_observations': selectedObservations,
    'source_currency_inferred': false,
    'clinical_approval': false,
  };
}

final class _ReviewedImportChoice {
  const _ReviewedImportChoice({
    required this.decisionId,
    required this.originalAuditId,
    required this.originalRationale,
    required this.originalRationaleSha256,
    required this.observation,
  });
  final String decisionId;
  final String originalAuditId;
  final Map<String, Object?> originalRationale;
  final String originalRationaleSha256;
  final ObservationRecord observation;
}

final class _PreparedReviewedImport {
  const _PreparedReviewedImport(this.bundle, this.choices, this.evidenceSha256);
  final P0ImportBundle bundle;
  final Map<String, _ReviewedImportChoice> choices;
  final String evidenceSha256;
}
