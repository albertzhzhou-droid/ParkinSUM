import 'dart:convert';

import '../../core/db/cdss_database.dart';
import '../../core/i18n/app_i18n.dart';
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
import 'rule_registry_compiler.dart';
import 'runtime_rule_engine.dart';
import 'runtime_rule_support.dart';

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

  ClinicalDecisionSupportService({
    required this.database,
    required this.factConflictEngine,
    required this.runtimeRuleEngine,
    RuntimeRuleSupport? runtimeRuleSupport,
    CdssArtifactStore? artifactStore,
    RuleRegistryCompiler? ruleRegistryCompiler,
  })  : runtimeRuleSupport = runtimeRuleSupport ?? const RuntimeRuleSupport(),
        artifactStore = artifactStore ?? createCdssArtifactStore(),
        ruleRegistryCompiler = ruleRegistryCompiler ?? RuleRegistryCompiler();

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
  Future<CdssImportReport> importBundle(P0ImportBundle bundle) async {
    await database.initialize();
    final createdAt = DateTime.now();
    final baseHash = base64.encode(
      utf8.encode(
        jsonEncode({
          'source_documents':
              bundle.sourceDocuments.map((e) => e.sourceDocId).toList(),
          'country_diet_profiles':
              bundle.countryDietProfiles.map((e) => e.countryCode).toList(),
          'food_variants':
              bundle.foodVariants.map((e) => e.foodVariantId).toList(),
          'drug_variants': bundle.drugProductVariants
              .map((e) => e.drugProductVariantId)
              .toList(),
          'observations':
              bundle.observations.map((e) => e.observationId).toList(),
          'rule_registry':
              bundle.ruleRegistryRows.map((e) => e['rule_id']).toList(),
          'runtime_events': bundle.runtimeEvents.map((e) => e.eventId).toList(),
        }),
      ),
    );
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

    for (final record in bundle.sourceDocuments) {
      await database.insertSourceDocument(record);
    }
    for (final record in bundle.countryDietProfiles) {
      await database.insertCountryDietProfile(record);
    }
    for (final record in bundle.foodConcepts) {
      await database.insertFoodConcept(record);
    }
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
    for (final record in bundle.drugConcepts) {
      await database.insertDrugConcept(record);
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

    // promote: 从 staging 表读取经过落盘的结果，再写正式表，确保导入链可回放。
    final stagedFoodVariants =
        await database.queryTable('staging_food_variant');
    for (final row
        in stagedFoodVariants.where((row) => row['run_id'] == runId)) {
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
    final stagedDrugVariants =
        await database.queryTable('staging_drug_product_variant');
    for (final row
        in stagedDrugVariants.where((row) => row['run_id'] == runId)) {
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
    for (final row
        in stagedObservations.where((row) => row['run_id'] == runId)) {
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
            qualifierKind:
                _qualifierKindFromWireValue('${payload['qualifier_kind']}'),
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
            qualifierKind:
                _qualifierKindFromWireValue('${payload['qualifier_kind']}'),
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
    final stagedRuntimeEvents =
        await database.queryTable('staging_runtime_event');
    for (final row
        in stagedRuntimeEvents.where((row) => row['run_id'] == runId)) {
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
    final stagedCrosswalks =
        await database.queryTable('staging_concept_variant_crosswalk');
    for (final row in stagedCrosswalks.where((row) => row['run_id'] == runId)) {
      final payload =
          jsonDecode('${row['payload_json']}') as Map<String, dynamic>;
      await database.insertStagingRow('concept_variant_crosswalk', payload);
    }
    final conflictRationales = await _auditImportConflicts(
      runId: runId,
      snapshotId: promotedSnapshotId,
      bundle: bundle,
      createdAt: createdAt,
    );
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
        'conflict_rationale.json':
            const JsonEncoder.withIndent('  ').convert(conflictRationales),
      },
      manifest: {
        'kind': 'import',
        'run_id': runId,
        'snapshot_id': promotedSnapshotId,
        'fallback': 'inline storage is used on backends without a filesystem',
      },
      createdAt: createdAt,
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

  Future<List<RuleRegistryEntry>> loadCompiledRulesFromRegistry({
    String? rulesVersion,
  }) async {
    await database.initialize();
    final rows = await database.queryTable('rule_registry');
    final allActiveRows =
        rows.where((row) => '${row['status'] ?? ''}' == 'active').toList();
    final resolvedRulesVersion = await _resolveRuntimeRulesVersion(
      requestedRulesVersion: rulesVersion,
      activeRuleRows: allActiveRows,
    );
    final versionRows = resolvedRulesVersion == null
        ? allActiveRows
        : allActiveRows
            .where(
                (row) => '${row['rule_version'] ?? ''}' == resolvedRulesVersion)
            .toList(growable: false);
    final candidateRows = versionRows.isNotEmpty || resolvedRulesVersion == null
        ? versionRows
        : allActiveRows;
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
              {'type': 'block_rule_from_runtime'}
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
    final snapshots = await database.queryTable('engine_snapshot');
    final promoted = snapshots
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
    if (requested != null &&
        requested.isNotEmpty &&
        requested != 'latest_promoted') {
      return requested;
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
    final sourceFacts =
        facts.where((row) => '${row['snapshot_id']}' == snapshotId).toList();
    if (sourceFacts.isEmpty) {
      throw StateError(
          'Snapshot $snapshotId has no resolved facts to rollback.');
    }
    final targetSnapshot = snapshots.firstWhere(
      (row) => '${row['snapshot_id']}' == snapshotId,
      orElse: () => <String, Object?>{},
    );
    final rollbackSnapshotId =
        'rollback_${DateTime.now().microsecondsSinceEpoch}';
    await database.insertEngineSnapshot(
      EngineSnapshotRecord(
        snapshotId: rollbackSnapshotId,
        factsVersion: rollbackSnapshotId,
        rulesVersion:
            '${targetSnapshot['rules_version'] ?? 'baseline_cdss_rules_v1'}',
        createdAt: DateTime.now(),
        promotedAt: DateTime.now(),
        rollbackParent: snapshotId,
        inputHash: base64.encode(utf8.encode(reason)),
      ),
    );
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
              '${row['qualifier_kind'] ?? 'missing'}'),
          low: (row['resolved_low'] as num?)?.toDouble(),
          high: (row['resolved_high'] as num?)?.toDouble(),
          valueNum: (row['value_num'] as num?)?.toDouble(),
        ),
        resolvedUnit: '${row['resolved_unit']}',
        resolutionPolicyId: '${row['resolution_policy_id']}',
        snapshotId: rollbackSnapshotId,
        factVersion: rollbackSnapshotId,
        manualOverride: (row['manual_override'] as num?) == 1,
      );
      await database.insertResolvedFact(record);
    }
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
            (a, b) => ((b['promoted_at'] as num?)?.toInt() ?? 0)
                .compareTo((a['promoted_at'] as num?)?.toInt() ?? 0),
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
              (row['promoted_at'] as num).toInt()),
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
    // 单条 observation 的最小写入链路：
    // source document -> observation -> variant scope -> conflict classify -> resolved fact
    // 未完成：cluster 级别的批量 ingest / auto-resolve / human review ticket 还没有接上。
    await database.insertSourceDocument(sourceDocument);
    await database.insertObservation(observation);
    await database.insertVariantScope(variantScope);
    final result = factConflictEngine.classify(
      observation: observation,
      existingFacts: existingFacts,
    );
    await database.insertResolvedFact(resolvedFact);
    return result;
  }

  Future<EngineRunOutput> run({
    required UnifiedRuntimeContext context,
    required List<RuleRegistryEntry> rules,
    required String factsVersion,
    required String rulesVersion,
  }) async {
    await database.initialize();

    final regionRows = await database.queryTable('region_jurisdiction_map');
    final jurisdictionChain = runtimeRuleEngine.resolveJurisdictionChain(
      context,
      regionJurisdictionRows: regionRows,
    );
    final regionJurisdictionMapSource =
        runtimeRuleEngine.regionJurisdictionMapSource(
      context,
      regionJurisdictionRows: regionRows,
    );
    final i18n = AppI18n.fromLocaleTag(context.userProfile.displayLocale);

    final inputHash = base64.encode(utf8.encode(jsonEncode(context.toJson())));
    final snapshot = EngineSnapshotRecord(
      snapshotId: 'snapshot_$inputHash',
      factsVersion: factsVersion,
      rulesVersion: rulesVersion,
      createdAt: DateTime.now(),
      promotedAt: null,
      rollbackParent: null,
      inputHash: inputHash,
    );
    await database.insertEngineSnapshot(snapshot);

    final registryRules =
        await loadCompiledRulesFromRegistry(rulesVersion: rulesVersion);
    final registryRuleIds = registryRules.map((rule) => rule.ruleId).toSet();
    final effectiveRules = [
      ...registryRules,
      ...rules.where((rule) => !registryRuleIds.contains(rule.ruleId)),
    ];
    final candidates = runtimeRuleEngine.evaluateCandidates(
      context: context,
      rules: effectiveRules,
      regionJurisdictionRows: regionRows,
    );
    final sortedCandidates = runtimeRuleEngine.resolveByPriority(
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

    for (final entry in grouped.entries) {
      final bucket = entry.value;
      final winner = bucket.first;
      final sameBandEscalation = sameBandByTarget[entry.key] ??
          runtimeRuleSupport.evaluateSameBandEscalation(bucket);
      final sameBandConflict = sameBandEscalation.requiresReview;
      final missingFields = runtimeRuleSupport
          .collectRelevantMissingFields(
            context: context,
            rules: bucket.map((item) => item.rule).toList(growable: false),
          )
          .toList(growable: false);
      final localizedMissingFields =
          missingFields.map(i18n.missingFieldLabel).toList(growable: false);

      var decision = winner.rule.thenClause.decision;
      var explanation = _localizedRuleMessage(
        i18n,
        winner.rule.thenClause.messages,
      );
      if (sameBandConflict || missingFields.isNotEmpty) {
        decision = RuntimeDecisionType.requireReview;
        explanation = sameBandConflict
            ? i18n.tr('runtime.same_band_conflict')
            : i18n.tr(
                'runtime.missing_fields',
                {'fields': localizedMissingFields.join(', ')},
              );
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
      final evidenceRecords =
          await _resolveEvidenceDetails(winner.rule.provenance.sourceRefs);
      final evidenceDetails =
          evidenceRecords.map(_formatEvidenceDetail).toList(growable: false);
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
          ruleIds:
              bucket.map((item) => item.rule.ruleId).toList(growable: false),
        ),
      );

      auditEntries.add(
        RuntimeAuditEntry(
          target: entry.key,
          decision: decision,
          winningRuleIds: [winner.rule.ruleId],
          suppressedRuleIds:
              bucket.skip(1).map((item) => item.rule.ruleId).toList(),
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

    if (alerts.isEmpty) {
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
          : i18n.tr(
              'runtime.missing_fields',
              {'fields': localizedMissingFields.join(', ')},
            );

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

    final ruleHitTrace = _ruleHitTrace(
      rules: effectiveRules,
      candidates: sortedCandidates,
      groupedCandidates: grouped,
      sameBandByTarget: sameBandByTarget,
      context: context,
      jurisdictionChain: jurisdictionChain,
      regionJurisdictionMapSource: regionJurisdictionMapSource,
    );
    final alertsJson = {
      'alerts': alerts.map((alert) => alert.toJson()).toList(growable: false),
      'jurisdiction_chain': jurisdictionChain,
      'snapshot': {
        'facts_version': factsVersion,
        'rules_version': rulesVersion,
      },
      'compiled_rule_source': registryRules.isEmpty
          ? 'caller_supplied_rules'
          : 'database_rule_registry_snapshot',
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
        humanReadable
            .writeln('  Evidence: ${alert.evidenceDetails.join(' | ')}');
      }
    }

    final auditJsonl = [
      ...auditEntries.map((entry) => entry.toJson()),
      ...ruleHitTrace.map((entry) => {
            'event_type': 'rule_trace',
            ...entry,
          }),
    ].map(toJsonLine).join();

    final runtimeEvent = RuntimeEventRecord(
      eventId: 'runtime_$inputHash',
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
          'needs_human_review':
              auditEntries.any((entry) => entry.needsHumanReview),
        }),
        'rule_trace.json':
            const JsonEncoder.withIndent('  ').convert(ruleHitTrace),
        'conflict_rationale.json': const JsonEncoder.withIndent('  ').convert({
          'rule_hit_trace': ruleHitTrace,
          'audit_entries': auditEntries.map((entry) => entry.toJson()).toList(),
        }),
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
  }) async {
    final sourceById = <String, SourceDocumentRecord>{
      for (final doc in bundle.sourceDocuments) doc.sourceDocId: doc,
    };
    final scopesByHash = <String, VariantScopeRecord>{
      for (final scope in bundle.variantScopes) scope.scopeHash: scope,
    };
    final grouped = <String, List<ObservationRecord>>{};
    for (final observation in bundle.observations) {
      final key = [
        observation.domain,
        observation.entityType,
        observation.entityKey,
        observation.attributeCode,
        observation.scopeHash,
        observation.unit,
        observation.basisType,
      ].join('|');
      grouped.putIfAbsent(key, () => <ObservationRecord>[]).add(observation);
    }

    final rationales = <Map<String, dynamic>>[];
    for (final entry
        in grouped.entries.where((entry) => entry.value.length > 1)) {
      final resolution = factConflictEngine.resolveCluster(
        observations: entry.value,
        existingFacts: const <ResolvedFactRecord>[],
        sourceDocumentsById: sourceById,
        scopesByHash: scopesByHash,
      );
      final accepted = resolution.chosenObservation;
      final payload = {
        'cluster_key': entry.key,
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
        'explanation': resolution.explanation,
        'needs_human_review': resolution.needsManualReview,
      };
      rationales.add(payload);
      await database.insertConflictAuditLog(
        ConflictAuditLogRecord(
          auditId: 'fact_cluster_${stableHash('$runId:${entry.key}')}',
          snapshotId: snapshotId,
          runId: runId,
          auditType: 'FACT_CLUSTER_RESOLUTION',
          target: entry.key,
          decision: resolution.status,
          winningRuleIdsJson: jsonEncode(
            accepted == null ? const <String>[] : [accepted.observationId],
          ),
          suppressedRuleIdsJson: jsonEncode(
            resolution.rejectedRationales
                .map((item) => item['observation_id'])
                .whereType<String>()
                .toList(growable: false),
          ),
          sourceDocRefsJson: jsonEncode(
            entry.value.map((item) => item.sourceDocId).toSet().toList(),
          ),
          inputHash: stableHash(jsonEncode(payload)),
          decisionReason: jsonEncode(payload),
          machineActionsJson: jsonEncode([
            {
              'type': resolution.needsManualReview
                  ? 'open_manual_conflict_review'
                  : 'accept_ranked_observation',
              'params': payload,
            }
          ]),
          humanMessage: resolution.explanation,
          needsHumanReview: resolution.needsManualReview,
          createdAt: createdAt,
        ),
      );
    }
    return rationales;
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
    return rules.map((rule) {
      final candidate = candidateByRuleId[rule.ruleId];
      final target = rule.target;
      final winner = winnerByTarget[target];
      final sameBand = sameBandByTarget[target];
      final missingFields = runtimeRuleSupport
          .missingFieldsForRule(context: context, rule: rule)
          .toList(growable: false);
      final jurisdictionMatched = runtimeRuleEngine.jurisdictionMatches(
          rule.jurisdictions, jurisdictionChain);
      final jurisdictionSpecificity =
          _jurisdictionSpecificity(rule.jurisdictions, jurisdictionChain);
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
          'effective_from': rule.provenance.effectiveFrom?.toIso8601String(),
          'recency': rule.provenance.effectiveFrom?.millisecondsSinceEpoch ?? 0,
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
        'missing_field_reason':
            missingFields.isEmpty ? null : 'missing_${missingFields.join("_")}',
        'tie_break_reason': matched ? sameBand?.reason : null,
        'suppressed_rule_ids': matched
            ? (sameBand?.suppressedRuleIds ?? const <String>[])
            : const <String>[],
        'explanation': candidate?.explanation,
        'evidence': candidate?.evidence ?? const <String, dynamic>{},
      };
    }).toList(growable: false);
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
    return sourceRefs.map((ref) {
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
    }).toList(growable: false);
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
    final inputHash = base64.encode(
      utf8.encode(
        jsonEncode(
          {
            'patient_id': userProfile.patientId,
            'meal_slot': mealSlot,
            'facts_version': factsVersion,
            'rules_version': rulesVersion,
            'recommendations':
                recommendations.map((item) => item.food.id).toList(),
          },
        ),
      ),
    );
    final snapshotId = 'recommendation_snapshot_$inputHash';
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
        recAuditId: 'rec_$inputHash',
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
    final families = bundle.sourceDocuments
        .map((item) => item.sourceFamily)
        .toSet()
        .toList()
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
      'jurisdiction':
          _decodeRegistryList('${row['jurisdiction_json'] ?? '[]'}'),
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
