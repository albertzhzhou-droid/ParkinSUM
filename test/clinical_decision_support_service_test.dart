import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/baseline_cdss_rules.dart';
import 'package:parkinsum_companion/core/constants/clinical_evidence_source_seed.dart';
import 'package:parkinsum_companion/core/constants/p0_food_source_seed.dart';
import 'package:parkinsum_companion/core/constants/regional_master_data.dart';
import 'package:parkinsum_companion/core/db/cdss_database.dart';
import 'package:parkinsum_companion/core/utils/qualified_value_parser.dart';
import 'package:parkinsum_companion/domain/entities/cdss_runtime.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';
import 'package:parkinsum_companion/domain/entities/runtime_context.dart';
import 'package:parkinsum_companion/domain/usecases/clinical_decision_support_service.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_catalog_projection_service.dart';
import 'package:parkinsum_companion/domain/usecases/fact_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/get_food_recommendations_usecase.dart';
import 'package:parkinsum_companion/domain/usecases/imported_label_rule_provider.dart';
import 'package:parkinsum_companion/domain/usecases/rule_registry_compiler.dart';
import 'package:parkinsum_companion/domain/usecases/runtime_rule_engine.dart';
import 'package:parkinsum_companion/domain/usecases/variant_resolver.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/data/datasources/remote/p0_import_models.dart';

class RecordingCdssDatabase implements CdssDatabase {
  final Map<String, List<Map<String, Object?>>> tables = {
    'recommendation_audit_log': <Map<String, Object?>>[],
    'region_jurisdiction_map': <Map<String, Object?>>[],
    'country_diet_profile': <Map<String, Object?>>[],
    'meal_template': <Map<String, Object?>>[],
    'source_document': <Map<String, Object?>>[],
    'variant_scope': <Map<String, Object?>>[],
    'observation': <Map<String, Object?>>[],
    'resolved_fact': <Map<String, Object?>>[],
    'food_concept': <Map<String, Object?>>[],
    'food_variant': <Map<String, Object?>>[],
    'drug_concept': <Map<String, Object?>>[],
    'drug_product_variant': <Map<String, Object?>>[],
    'concept_variant_crosswalk': <Map<String, Object?>>[],
    'engine_snapshot': <Map<String, Object?>>[],
    'ingestion_run': <Map<String, Object?>>[],
    'snapshot_distribution': <Map<String, Object?>>[],
    'conflict_audit_log': <Map<String, Object?>>[],
    'rule_registry': <Map<String, Object?>>[],
    'runtime_event': <Map<String, Object?>>[],
    'staging_food_variant': <Map<String, Object?>>[],
    'staging_drug_product_variant': <Map<String, Object?>>[],
    'staging_variant_scope': <Map<String, Object?>>[],
    'staging_observation': <Map<String, Object?>>[],
    'staging_resolved_fact': <Map<String, Object?>>[],
    'staging_rule_registry': <Map<String, Object?>>[],
    'staging_runtime_event': <Map<String, Object?>>[],
  };

  @override
  Future<void> initialize() async {}

  void _add(String table, Map<String, Object?> row) {
    tables.putIfAbsent(table, () => <Map<String, Object?>>[]).add(row);
  }

  @override
  Future<void> insertConflictAuditLog(ConflictAuditLogRecord record) async {
    _add('conflict_audit_log', {
      'audit_id': record.auditId,
      'snapshot_id': record.snapshotId,
      'run_id': record.runId,
      'audit_type': record.auditType,
      'target': record.target,
      'decision': record.decision,
      'winning_rule_ids_json': record.winningRuleIdsJson,
      'suppressed_rule_ids_json': record.suppressedRuleIdsJson,
      'source_doc_refs_json': record.sourceDocRefsJson,
      'input_hash': record.inputHash,
      'decision_reason': record.decisionReason,
      'machine_actions_json': record.machineActionsJson,
      'human_message': record.humanMessage,
      'needs_human_review': record.needsHumanReview,
      'created_at': record.createdAt.millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> insertCountryDietProfile(CountryDietProfileRecord record) async {
    _add('country_diet_profile', {'country_code': record.countryCode});
  }

  @override
  Future<void> insertDrugConcept(DrugConceptRecord record) async {
    _add('drug_concept', {'drug_concept_id': record.drugConceptId});
  }

  @override
  Future<void> insertDrugLabelSection(DrugLabelSectionRecord record) async {}

  @override
  Future<void> insertDrugProductCode(DrugProductCodeRecord record) async {}

  @override
  Future<void> insertDrugProductPackaging(
      DrugProductPackagingRecord record) async {}

  @override
  Future<void> insertDrugProductMedia(DrugProductMediaRecord record) async {}

  @override
  Future<void> insertDrugProductVariant(DrugProductVariantRecord record) async {
    _add('drug_product_variant',
        {'drug_product_variant_id': record.drugProductVariantId});
  }

  @override
  Future<void> insertEngineSnapshot(EngineSnapshotRecord record) async {
    _add('engine_snapshot', {
      'snapshot_id': record.snapshotId,
      'facts_version': record.factsVersion,
      'rules_version': record.rulesVersion,
      'created_at': record.createdAt.millisecondsSinceEpoch,
      'promoted_at': record.promotedAt?.millisecondsSinceEpoch,
      'rollback_parent': record.rollbackParent,
      'input_hash': record.inputHash,
    });
  }

  @override
  Future<void> insertFoodConcept(FoodConceptRecord record) async {
    _add('food_concept', {'food_concept_id': record.foodConceptId});
  }

  @override
  Future<void> insertFoodVariant(FoodVariantRecord record) async {
    _add('food_variant', {'food_variant_id': record.foodVariantId});
  }

  @override
  Future<void> insertLocaleResourceBundle(
      LocaleResourceBundleRecord record) async {}

  @override
  Future<void> insertMealTemplate(MealTemplateRecord record) async {
    _add('meal_template', {'meal_template_id': record.mealTemplateId});
  }

  @override
  Future<void> insertObservation(ObservationRecord record) async {
    _add('observation', {'observation_id': record.observationId});
  }

  @override
  Future<void> insertRecommendationAuditLog(
      RecommendationAuditLogRecord record) async {
    _add('recommendation_audit_log', {
      'rec_audit_id': record.recAuditId,
      'fallback_used': record.fallbackUsed,
      'meal_slot': record.mealSlot,
    });
  }

  @override
  Future<void> insertRegionJurisdictionMap(
      RegionJurisdictionMapRecord record) async {
    _add('region_jurisdiction_map', {'region_code': record.regionCode});
  }

  @override
  Future<void> insertResolvedFact(ResolvedFactRecord record) async {
    _add('resolved_fact', {'fact_id': record.factId});
  }

  @override
  Future<void> insertRuleRegistry(Map<String, dynamic> row) async {
    _add('rule_registry', Map<String, Object?>.from(row));
  }

  @override
  Future<void> insertRuntimeEvent(RuntimeEventRecord record) async {
    _add('runtime_event', {
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
    });
  }

  @override
  Future<void> insertIngestionRun(IngestionRunRecord record) async {
    _add('ingestion_run', {
      'run_id': record.runId,
      'source_family': record.sourceFamily,
      'stage': record.stage,
      'status': record.status,
      'snapshot_id': record.snapshotId,
      'parent_snapshot_id': record.parentSnapshotId,
      'notes_json': record.notesJson,
      'created_at': record.createdAt.millisecondsSinceEpoch,
      'completed_at': record.completedAt?.millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> insertSnapshotDistribution(
      SnapshotDistributionRecord record) async {
    _add('snapshot_distribution', {
      'distribution_id': record.distributionId,
      'snapshot_id': record.snapshotId,
      'channel': record.channel,
      'distribution_type': record.distributionType,
      'status': record.status,
      'artifact_path': record.artifactPath,
      'manifest_json': record.manifestJson,
      'error_message': record.errorMessage,
      'created_at': record.createdAt.millisecondsSinceEpoch,
      'completed_at': record.completedAt?.millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> insertStagingRow(String table, Map<String, Object?> row) async {
    _add(table, row);
  }

  @override
  Future<void> clearStagingRun(String runId) async {
    for (final rows in tables.entries
        .where((entry) => entry.key.startsWith('staging_'))
        .map((entry) => entry.value)) {
      rows.removeWhere((row) => row['run_id'] == runId);
    }
  }

  @override
  Future<void> insertSourceDocument(SourceDocumentRecord record) async {
    _add('source_document', {
      'source_doc_id': record.sourceDocId,
      'title': record.title,
      'origin_url': record.originUrl,
      'raw_payload': record.rawPayload,
    });
  }

  @override
  Future<void> insertVariantScope(VariantScopeRecord record) async {
    _add('variant_scope', {'scope_hash': record.scopeHash});
  }

  @override
  Future<List<Map<String, Object?>>> queryTable(String table) async =>
      tables[table] ?? const <Map<String, Object?>>[];
}

void main() {
  test(
      'engine does not escalate when missing dose is irrelevant to matched levodopa protein rule',
      () async {
    final compiler = RuleRegistryCompiler();
    final db = RecordingCdssDatabase();
    final service = ClinicalDecisionSupportService(
      database: db,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );
    await service.initializeKnowledgeBase(
      sourceDocuments: clinicalEvidenceSourceDocuments,
      variantScopes: const <VariantScopeRecord>[],
      observations: const <ObservationRecord>[],
      resolvedFacts: const <ResolvedFactRecord>[],
    );

    final output = await service.run(
      context: UnifiedRuntimeContext(
        userProfile: const UserProfileRuntimeContext(
          patientId: 'patient_1',
          registrationRegion: 'US',
          displayLocale: 'en-US',
          contentJurisdictionOverride: [],
          dietProfileRegion: 'US',
          timezone: 'America/Toronto',
        ),
        drug: const DrugRuntimeContext(
          id: 'drug_1',
          genericName: 'carbidopa/levodopa',
          brandName: 'Sinemet',
          activeIngredients: ['carbidopa', 'levodopa'],
          substanceTags: ['levodopa'],
          formulation: 'tablet',
          dosageForm: 'tablet',
          route: 'oral',
          releaseType: 'immediate',
          dailyDoseMg: null,
          jurisdiction: 'US',
        ),
        meal: const MealRuntimeContext(
          id: 'meal_1',
          totalProteinG: 25,
          tyramineMgEstimate: 0,
          highFatHighCalorie: false,
          itemIds: ['food_1'],
        ),
        coevent: null,
        enteralFeed: null,
        timestamps: TimestampRuntimeContext(
          drugTime: DateTime.utc(2026, 1, 1, 8),
          mealTime: DateTime.utc(2026, 1, 1, 9),
          coeventTime: null,
        ),
      ),
      rules: compiler.compileJsonList(
        baselineCdssRules,
        rulesVersion: 'test_rules',
      ),
      factsVersion: 'facts_v1',
      rulesVersion: 'rules_v1',
    );

    expect(
      output.alerts.any(
        (alert) => alert.decision == RuntimeDecisionType.warn,
      ),
      isTrue,
    );
    expect(
      output.alerts.any(
        (alert) => alert.decision == RuntimeDecisionType.requireReview,
      ),
      isFalse,
    );
    expect(output.alertsJson['jurisdiction_chain'], isNotNull);
    expect(output.humanReadableMarkdown, contains('Runtime Decision'));
    expect(output.humanReadableMarkdown,
        contains('Dhivy label food effect reference'));
    expect(output.auditLogJsonl, contains('needs_human_review'));
    expect(output.auditLogJsonl, contains('evidence_details'));
  });

  test(
      'engine escalates to REQUIRE_REVIEW when a dose-dependent rule lacks dose',
      () async {
    final compiler = RuleRegistryCompiler();
    final db = RecordingCdssDatabase();
    final service = ClinicalDecisionSupportService(
      database: db,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );
    await service.initializeKnowledgeBase(
      sourceDocuments: clinicalEvidenceSourceDocuments,
      variantScopes: const <VariantScopeRecord>[],
      observations: const <ObservationRecord>[],
      resolvedFacts: const <ResolvedFactRecord>[],
    );

    final output = await service.run(
      context: UnifiedRuntimeContext(
        userProfile: const UserProfileRuntimeContext(
          patientId: 'patient_2',
          registrationRegion: 'US',
          displayLocale: 'en-US',
          contentJurisdictionOverride: [],
          dietProfileRegion: 'US',
          timezone: 'America/Toronto',
        ),
        drug: const DrugRuntimeContext(
          id: 'drug_2',
          genericName: 'rasagiline',
          brandName: 'Azilect',
          activeIngredients: ['rasagiline'],
          substanceTags: ['maob_inhibitor'],
          formulation: 'tablet',
          dosageForm: 'tablet',
          route: 'oral',
          releaseType: 'immediate',
          dailyDoseMg: null,
          jurisdiction: 'US',
        ),
        meal: const MealRuntimeContext(
          id: 'meal_2',
          totalProteinG: 10,
          tyramineMgEstimate: 180,
          highFatHighCalorie: false,
          itemIds: ['food_2'],
        ),
        coevent: null,
        enteralFeed: null,
        timestamps: TimestampRuntimeContext(
          drugTime: DateTime.utc(2026, 1, 1, 8),
          mealTime: DateTime.utc(2026, 1, 1, 9),
          coeventTime: null,
        ),
      ),
      rules: compiler.compileJsonList(
        baselineCdssRules,
        rulesVersion: 'test_rules',
      ),
      factsVersion: 'facts_v1',
      rulesVersion: 'rules_v1',
    );

    expect(
      output.alerts.any(
        (alert) => alert.decision == RuntimeDecisionType.requireReview,
      ),
      isTrue,
    );
    expect(output.humanReadableMarkdown, contains('dose'));
  });

  test('blocked PEG combinations keep machine actions structured', () async {
    final compiler = RuleRegistryCompiler();
    final db = RecordingCdssDatabase();
    final service = ClinicalDecisionSupportService(
      database: db,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );

    final output = await service.run(
      context: const UnifiedRuntimeContext(
        userProfile: UserProfileRuntimeContext(
          patientId: 'patient_1',
          registrationRegion: 'US',
          displayLocale: 'en-US',
          contentJurisdictionOverride: [],
          dietProfileRegion: 'US',
          timezone: 'America/Toronto',
        ),
        drug: DrugRuntimeContext(
          id: 'drug_3',
          genericName: 'peg 3350',
          brandName: null,
          activeIngredients: ['peg_3350'],
          substanceTags: ['peg_3350'],
          formulation: 'solution',
          dosageForm: 'powder',
          route: 'oral',
          releaseType: 'immediate',
          dailyDoseMg: 17,
          jurisdiction: 'US',
        ),
        meal: null,
        coevent: CoeventRuntimeContext(
          substanceTags: ['hydration'],
          supplements: {},
          thickenerType: 'starch_based',
        ),
        enteralFeed: null,
        timestamps: TimestampRuntimeContext(
          drugTime: null,
          mealTime: null,
          coeventTime: null,
        ),
      ),
      rules: compiler.compileJsonList(
        baselineCdssRules,
        rulesVersion: 'test_rules',
      ),
      factsVersion: 'facts_v1',
      rulesVersion: 'rules_v1',
    );

    expect(
      output.alerts.any((alert) => alert.decision == RuntimeDecisionType.block),
      isTrue,
    );
    expect(output.alerts.first.actions.first['type'], isNotEmpty);
  });

  test('info-level administration rules surface richer evidence metadata',
      () async {
    final compiler = RuleRegistryCompiler();
    final db = RecordingCdssDatabase();
    final service = ClinicalDecisionSupportService(
      database: db,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );
    await service.initializeKnowledgeBase(
      sourceDocuments: clinicalEvidenceSourceDocuments,
      variantScopes: const <VariantScopeRecord>[],
      observations: const <ObservationRecord>[],
      resolvedFacts: const <ResolvedFactRecord>[],
    );

    final output = await service.run(
      context: UnifiedRuntimeContext(
        userProfile: const UserProfileRuntimeContext(
          patientId: 'patient_3',
          registrationRegion: 'US',
          displayLocale: 'en-US',
          contentJurisdictionOverride: [],
          dietProfileRegion: 'US',
          timezone: 'America/Toronto',
        ),
        drug: const DrugRuntimeContext(
          id: 'drug_4',
          genericName: 'pramipexole',
          brandName: 'Mirapex',
          activeIngredients: ['pramipexole'],
          substanceTags: ['dopamine_agonist'],
          formulation: 'tablet',
          dosageForm: 'tablet',
          route: 'oral',
          releaseType: 'immediate',
          dailyDoseMg: 1.5,
          jurisdiction: 'US',
        ),
        meal: const MealRuntimeContext(
          id: 'meal_3',
          totalProteinG: 12,
          tyramineMgEstimate: 0,
          highFatHighCalorie: false,
          itemIds: ['food_3'],
        ),
        coevent: null,
        enteralFeed: null,
        timestamps: TimestampRuntimeContext(
          drugTime: DateTime.utc(2026, 1, 1, 8),
          mealTime: DateTime.utc(2026, 1, 1, 8, 30),
          coeventTime: null,
        ),
      ),
      rules: compiler.compileJsonList(
        baselineCdssRules,
        rulesVersion: 'test_rules',
      ),
      factsVersion: 'facts_v1',
      rulesVersion: 'rules_v1',
    );

    expect(
      output.alerts.any((alert) => alert.decision == RuntimeDecisionType.info),
      isTrue,
    );
    expect(
      output.humanReadableMarkdown,
      contains('Pramipexole food administration label reference'),
    );
    expect(output.humanReadableMarkdown, contains('official_label'));
  });

  test('regional master data seed writes modular tables', () async {
    final db = RecordingCdssDatabase();
    final service = ClinicalDecisionSupportService(
      database: db,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );

    await service.initializeRegionalMasterData(
      regionMaps: regionalJurisdictionMapSeed,
      localeBundles: localeResourceBundleSeed,
      dietProfiles: countryDietProfileSeed,
      mealTemplates: mealTemplateSeed,
      foodConcepts: const [
        FoodConceptRecord(
          foodConceptId: 'FOOD_APPLE',
          canonicalNameEn: 'Apple',
          canonicalNameZh: '苹果',
          foodGroup: 'fruit',
        ),
      ],
      foodVariants: const [
        FoodVariantRecord(
          foodVariantId: 'FOOD_APPLE#GLOBAL#LOCAL#apple',
          foodConceptId: 'FOOD_APPLE',
          jurisdiction: 'GLOBAL',
          sourceFamily: 'LOCAL_SEED',
          sourceFoodCode: 'apple',
          displayNameLocal: 'Apple',
          isAuthoritativeForRegion: false,
          isAuthoritativeFallback: true,
          status: 'seeded',
          fallbackChainJson: '["GLOBAL"]',
        ),
      ],
      drugConcepts: const [
        DrugConceptRecord(
          drugConceptId: 'DRUG_LDOPA',
          genericName: 'levodopa',
          atcLikeCode: 'levodopa_like',
        ),
      ],
      drugProductVariants: const [
        DrugProductVariantRecord(
          drugProductVariantId: 'DRUG_LDOPA#GLOBAL#LOCAL#ldopa',
          drugConceptId: 'DRUG_LDOPA',
          jurisdiction: 'GLOBAL',
          regulator: 'LOCAL_SEED',
          externalProductCode: 'ldopa',
          route: 'oral',
          dosageForm: 'tablet',
          releaseType: 'immediate',
          labelVersion: 'seed_v1',
          sourceStatus: 'seeded_reference',
        ),
      ],
    );

    expect((await db.queryTable('region_jurisdiction_map')).isNotEmpty, isTrue);
    expect((await db.queryTable('country_diet_profile')).isNotEmpty, isTrue);
    expect((await db.queryTable('meal_template')).isNotEmpty, isTrue);
    expect((await db.queryTable('food_concept')).single['food_concept_id'],
        'FOOD_APPLE');
    expect((await db.queryTable('drug_concept')).single['drug_concept_id'],
        'DRUG_LDOPA');
  });

  test('P0 food source seed writes source documents and resolved food facts',
      () async {
    final db = RecordingCdssDatabase();
    final service = ClinicalDecisionSupportService(
      database: db,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );
    final seed = buildP0FoodKnowledgeBaseSeed();

    await service.initializeKnowledgeBase(
      sourceDocuments: seed.sourceDocuments,
      variantScopes: seed.variantScopes,
      observations: seed.observations,
      resolvedFacts: seed.resolvedFacts,
    );

    expect((await db.queryTable('source_document')).isNotEmpty, isTrue);
    expect((await db.queryTable('variant_scope')).isNotEmpty, isTrue);
    expect((await db.queryTable('observation')).isNotEmpty, isTrue);
    expect((await db.queryTable('resolved_fact')).isNotEmpty, isTrue);
  });

  test('official import stages and promotes rule registry and runtime events',
      () async {
    final db = RecordingCdssDatabase();
    final service = ClinicalDecisionSupportService(
      database: db,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );

    final report = await service.importBundle(
      P0ImportBundle(
        sourceDocuments: [
          const SourceDocumentRecord(
            sourceDocId: 'doc_rule_runtime',
            sourceFamily: 'DAILYMED',
            organization: 'Regulator',
            docType: 'official_label',
            title: 'Official rule source',
            jurisdiction: 'US',
            originUrl: 'https://example.test/rule',
            publishedAt: null,
            effectiveAt: null,
            language: 'en',
            licenseNote: 'test',
            checksum: 'checksum_rule_runtime',
            sourceStatus: 'active',
            rawPayload: '{}',
          ),
        ],
        drugConcepts: const [
          DrugConceptRecord(
            drugConceptId: 'DRUG_LDOPA',
            genericName: 'levodopa',
            atcLikeCode: 'levodopa_like',
          ),
        ],
        drugProductVariants: const [
          DrugProductVariantRecord(
            drugProductVariantId: 'DRUG_LDOPA#US#DAILYMED#setid_1',
            drugConceptId: 'DRUG_LDOPA',
            jurisdiction: 'US',
            regulator: 'DAILYMED',
            externalProductCode: 'setid_1',
            route: 'oral',
            dosageForm: 'tablet',
            releaseType: 'immediate',
            labelVersion: 'v1',
            sourceStatus: 'active',
          ),
        ],
        ruleRegistryRows: [
          {
            'rule_id': 'official_rule_1',
            'rule_version': '2026.04',
            'status': 'active',
            'rule_type': 'official_label',
            'priority_band': 10,
            'specificity_band': 5,
            'jurisdiction_json': '["US"]',
            'applies_to_json': '{"drug":"levodopa"}',
            'predicate_json': '{"meal_protein_g":{">":30}}',
            'effect_json': '{"decision":"warn"}',
            'provenance_json': '{"source_refs":["doc_rule_runtime"]}',
            'override_json': '{}',
            'compiled_hash': 'official_rule_1_2026_04',
            'updated_at': 1777334400000,
          },
        ],
        runtimeEvents: [
          RuntimeEventRecord(
            eventId: 'import_runtime_event_1',
            patientId: 'import_audit',
            eventType: 'official_import_validation',
            snapshotId: 'pre_promote_snapshot',
            contextJson: '{"source":"OFFICIAL_TEST"}',
            machineReadableJson: '{"status":"validated"}',
            humanReadableMarkdown: 'Official import validation passed.',
            jurisdiction: 'US',
            timezone: 'America/Toronto',
            createdAt: DateTime.fromMillisecondsSinceEpoch(1777334400000),
          ),
        ],
      ),
    );

    expect(report.ruleRegistryCount, 1);
    expect(report.runtimeEventCount, 1);
    expect((await db.queryTable('rule_registry')).single['rule_id'],
        'official_rule_1');
    expect((await db.queryTable('runtime_event')).single['event_id'],
        'import_runtime_event_1');
    final crosswalks = await db.queryTable('concept_variant_crosswalk');
    expect(crosswalks.single['external_id_system'], 'DailyMed setid');
    expect(crosswalks.single['source_doc_id'], 'doc_rule_runtime');
    final distributions = await db.queryTable('snapshot_distribution');
    expect(
      distributions
          .any((row) => row['distribution_type'] == 'import_artifacts'),
      isTrue,
    );
    expect(await db.queryTable('staging_rule_registry'), isEmpty);
    expect(await db.queryTable('staging_runtime_event'), isEmpty);

    final promoteRun = (await db.queryTable('ingestion_run')).last;
    expect(promoteRun['stage'], 'promote');
    expect('${promoteRun['notes_json']}', contains('rule_registry_count'));
    expect('${promoteRun['notes_json']}', contains('runtime_event_count'));
  });

  test('opicapone meal-window rule warns when meal is too close to dose',
      () async {
    final compiler = RuleRegistryCompiler();
    final db = RecordingCdssDatabase();
    final service = ClinicalDecisionSupportService(
      database: db,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );
    await service.initializeKnowledgeBase(
      sourceDocuments: clinicalEvidenceSourceDocuments,
      variantScopes: const <VariantScopeRecord>[],
      observations: const <ObservationRecord>[],
      resolvedFacts: const <ResolvedFactRecord>[],
    );

    final output = await service.run(
      context: UnifiedRuntimeContext(
        userProfile: const UserProfileRuntimeContext(
          patientId: 'patient_opicapone',
          registrationRegion: 'US',
          displayLocale: 'en-US',
          contentJurisdictionOverride: [],
          dietProfileRegion: 'US',
          timezone: 'America/Toronto',
        ),
        drug: const DrugRuntimeContext(
          id: 'drug_ongentys',
          genericName: 'opicapone',
          brandName: 'ONGENTYS',
          activeIngredients: ['opicapone'],
          substanceTags: ['comt_inhibitor'],
          formulation: 'capsule',
          dosageForm: 'capsule',
          route: 'oral',
          releaseType: 'immediate',
          dailyDoseMg: 50,
          jurisdiction: 'US',
        ),
        meal: const MealRuntimeContext(
          id: 'meal_close',
          totalProteinG: 8,
          tyramineMgEstimate: 0,
          highFatHighCalorie: false,
          itemIds: ['food_1'],
        ),
        coevent: null,
        enteralFeed: null,
        timestamps: TimestampRuntimeContext(
          drugTime: DateTime.utc(2026, 1, 1, 22, 0),
          mealTime: DateTime.utc(2026, 1, 1, 21, 30),
          coeventTime: null,
        ),
      ),
      rules: compiler.compileJsonList(
        baselineCdssRules,
        rulesVersion: 'test_rules',
      ),
      factsVersion: 'facts_v1',
      rulesVersion: 'rules_v1',
    );

    expect(
      output.alerts.any(
        (alert) =>
            alert.ruleIds.contains('pd.opicapone.meal.window.v1') &&
            alert.decision == RuntimeDecisionType.warn,
      ),
      isTrue,
    );
    expect(output.humanReadableMarkdown, contains('ONGENTYS food timing'));
  });

  test('rotigotine meal-independent rule emits low-risk info', () async {
    final compiler = RuleRegistryCompiler();
    final db = RecordingCdssDatabase();
    final service = ClinicalDecisionSupportService(
      database: db,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );
    await service.initializeKnowledgeBase(
      sourceDocuments: clinicalEvidenceSourceDocuments,
      variantScopes: const <VariantScopeRecord>[],
      observations: const <ObservationRecord>[],
      resolvedFacts: const <ResolvedFactRecord>[],
    );

    final output = await service.run(
      context: UnifiedRuntimeContext(
        userProfile: const UserProfileRuntimeContext(
          patientId: 'patient_rotigotine',
          registrationRegion: 'US',
          displayLocale: 'en-US',
          contentJurisdictionOverride: [],
          dietProfileRegion: 'US',
          timezone: 'America/Toronto',
        ),
        drug: const DrugRuntimeContext(
          id: 'drug_neupro',
          genericName: 'rotigotine',
          brandName: 'NEUPRO',
          activeIngredients: ['rotigotine'],
          substanceTags: ['dopamine_agonist'],
          formulation: 'patch',
          dosageForm: 'patch',
          route: 'transdermal',
          releaseType: 'extended_release',
          dailyDoseMg: null,
          jurisdiction: 'US',
        ),
        meal: const MealRuntimeContext(
          id: 'meal_patch',
          totalProteinG: 15,
          tyramineMgEstimate: 0,
          highFatHighCalorie: false,
          itemIds: ['food_1'],
        ),
        coevent: null,
        enteralFeed: null,
        timestamps: TimestampRuntimeContext(
          drugTime: DateTime.utc(2026, 1, 1, 8, 0),
          mealTime: DateTime.utc(2026, 1, 1, 8, 10),
          coeventTime: null,
        ),
      ),
      rules: compiler.compileJsonList(
        baselineCdssRules,
        rulesVersion: 'test_rules',
      ),
      factsVersion: 'facts_v1',
      rulesVersion: 'rules_v1',
    );

    expect(
      output.alerts.any(
        (alert) =>
            alert.ruleIds.contains('pd.rotigotine.food.independent.info.v1') &&
            alert.decision == RuntimeDecisionType.info,
      ),
      isTrue,
    );
    expect(output.humanReadableMarkdown, contains('NEUPRO meal-independent'));
  });

  test('imported label tyramine threshold fact emits warn alert', () async {
    final compiler = RuleRegistryCompiler();
    final db = RecordingCdssDatabase();
    db.tables['drug_label_section'] = [
      {
        'drug_product_variant_id': 'DRUG_RASA#US#DAILYMED#drug_rasagiline',
        'source_doc_id': 'doc_rasa',
        'section_key': 'warnings',
        'section_title': 'Warnings',
        'section_text': 'Very high tyramine intake should be avoided.',
      },
    ];
    db.tables['source_document'] = [
      {
        'source_doc_id': 'doc_rasa',
        'title': 'Imported rasagiline label fact',
        'raw_payload': '''
{"label_facts":[{"fact_type":"tyramine_threshold","label":"Very high tyramine threshold warning","value_text":"150 mg tyramine threshold","payload":{"threshold_mg":150}}]}
''',
      },
    ];
    final provider =
        ImportedLabelRuleProvider(database: db, compiler: compiler);
    final rules = await provider.loadRules();
    final service = ClinicalDecisionSupportService(
      database: db,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );

    final output = await service.run(
      context: const UnifiedRuntimeContext(
        userProfile: UserProfileRuntimeContext(
          patientId: 'patient_rasa',
          registrationRegion: 'US',
          displayLocale: 'en-US',
          contentJurisdictionOverride: [],
          dietProfileRegion: 'US',
          timezone: 'America/Toronto',
        ),
        drug: DrugRuntimeContext(
          id: 'DRUG_RASA#US#DAILYMED#drug_rasagiline',
          genericName: 'rasagiline',
          brandName: 'AZILECT',
          activeIngredients: ['rasagiline'],
          substanceTags: ['maob_inhibitor'],
          formulation: 'tablet',
          dosageForm: 'tablet',
          route: 'oral',
          releaseType: 'immediate',
          dailyDoseMg: 1.0,
          jurisdiction: 'US',
        ),
        meal: MealRuntimeContext(
          id: 'meal_tyramine',
          totalProteinG: 8,
          tyramineMgEstimate: 180,
          highFatHighCalorie: false,
          itemIds: ['food_1'],
        ),
        coevent: null,
        enteralFeed: null,
        timestamps: TimestampRuntimeContext(
          drugTime: null,
          mealTime: null,
          coeventTime: null,
        ),
      ),
      rules: rules,
      factsVersion: 'facts_v1',
      rulesVersion: 'imported_label_rules_v1',
    );

    expect(
      output.alerts.any(
        (alert) =>
            alert.ruleIds.any((id) => id.endsWith('.tyramine_threshold')) &&
            alert.decision == RuntimeDecisionType.warn,
      ),
      isTrue,
    );
  });

  test('imported label iron interaction fact emits warn alert', () async {
    final compiler = RuleRegistryCompiler();
    final db = RecordingCdssDatabase();
    db.tables['drug_label_section'] = [
      {
        'drug_product_variant_id': 'DRUG_LDOPA#US#DAILYMED#drug_ldopa',
        'source_doc_id': 'doc_ldopa_iron',
        'section_key': 'drug_interactions',
        'section_title': 'Drug Interactions',
        'section_text':
            'Iron salts or multivitamins containing iron may reduce bioavailability.',
      },
    ];
    db.tables['source_document'] = [
      {
        'source_doc_id': 'doc_ldopa_iron',
        'title': 'Imported levodopa iron label fact',
        'raw_payload': '''
{"label_facts":[{"fact_type":"iron_interaction_warning","label":"Iron-containing products may interfere with absorption","payload":{}}]}
''',
      },
    ];
    final provider =
        ImportedLabelRuleProvider(database: db, compiler: compiler);
    final rules = await provider.loadRules();
    final service = ClinicalDecisionSupportService(
      database: db,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );

    final output = await service.run(
      context: const UnifiedRuntimeContext(
        userProfile: UserProfileRuntimeContext(
          patientId: 'patient_ldopa_iron',
          registrationRegion: 'US',
          displayLocale: 'en-US',
          contentJurisdictionOverride: [],
          dietProfileRegion: 'US',
          timezone: 'America/Toronto',
        ),
        drug: DrugRuntimeContext(
          id: 'DRUG_LDOPA#US#DAILYMED#drug_ldopa',
          genericName: 'carbidopa/levodopa',
          brandName: null,
          activeIngredients: ['carbidopa', 'levodopa'],
          substanceTags: ['levodopa'],
          formulation: 'tablet',
          dosageForm: 'tablet',
          route: 'oral',
          releaseType: 'immediate',
          dailyDoseMg: null,
          jurisdiction: 'US',
        ),
        meal: null,
        coevent: CoeventRuntimeContext(
          substanceTags: ['iron_salt'],
          supplements: {},
          thickenerType: null,
        ),
        enteralFeed: null,
        timestamps: TimestampRuntimeContext(
          drugTime: null,
          mealTime: null,
          coeventTime: null,
        ),
      ),
      rules: rules,
      factsVersion: 'facts_v1',
      rulesVersion: 'imported_label_rules_v1',
    );

    expect(
      output.alerts.any(
        (alert) =>
            alert.ruleIds.any((id) => id.endsWith('.iron_interaction')) &&
            alert.decision == RuntimeDecisionType.warn,
      ),
      isTrue,
    );
  });

  test('imported label thickener incompatibility fact emits block alert',
      () async {
    final compiler = RuleRegistryCompiler();
    final db = RecordingCdssDatabase();
    db.tables['drug_label_section'] = [
      {
        'drug_product_variant_id': 'DRUG_PEG#US#DAILYMED#drug_peg',
        'source_doc_id': 'doc_peg',
        'section_key': 'administration',
        'section_title': 'Administration',
        'section_text': 'Do not mix with starch-based thickener.',
      },
    ];
    db.tables['source_document'] = [
      {
        'source_doc_id': 'doc_peg',
        'title': 'Imported PEG label fact',
        'raw_payload': '''
{"label_facts":[{"fact_type":"starch_thickener_incompatibility","label":"Do not mix with starch-based thickener","payload":{}}]}
''',
      },
    ];
    final provider =
        ImportedLabelRuleProvider(database: db, compiler: compiler);
    final rules = await provider.loadRules();
    final service = ClinicalDecisionSupportService(
      database: db,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );

    final output = await service.run(
      context: const UnifiedRuntimeContext(
        userProfile: UserProfileRuntimeContext(
          patientId: 'patient_peg',
          registrationRegion: 'US',
          displayLocale: 'en-US',
          contentJurisdictionOverride: [],
          dietProfileRegion: 'US',
          timezone: 'America/Toronto',
        ),
        drug: DrugRuntimeContext(
          id: 'DRUG_PEG#US#DAILYMED#drug_peg',
          genericName: 'peg 3350',
          brandName: null,
          activeIngredients: ['peg_3350'],
          substanceTags: ['peg_3350'],
          formulation: 'solution',
          dosageForm: 'powder',
          route: 'oral',
          releaseType: 'immediate',
          dailyDoseMg: 17,
          jurisdiction: 'US',
        ),
        meal: null,
        coevent: CoeventRuntimeContext(
          substanceTags: ['hydration'],
          supplements: {},
          thickenerType: 'starch_based',
        ),
        enteralFeed: null,
        timestamps: TimestampRuntimeContext(
          drugTime: null,
          mealTime: null,
          coeventTime: null,
        ),
      ),
      rules: rules,
      factsVersion: 'facts_v1',
      rulesVersion: 'imported_label_rules_v1',
    );

    expect(
      output.alerts.any(
        (alert) =>
            alert.ruleIds.any(
              (id) => id.endsWith('.starch_thickener_incompatibility'),
            ) &&
            alert.decision == RuntimeDecisionType.block,
      ),
      isTrue,
    );
  });

  test('imported label enteral feeding fact emits require-review alert',
      () async {
    final compiler = RuleRegistryCompiler();
    final db = RecordingCdssDatabase();
    db.tables['drug_label_section'] = [
      {
        'drug_product_variant_id': 'DRUG_LDOPA#US#DAILYMED#drug_ldopa',
        'source_doc_id': 'doc_ldopa_enteral',
        'section_key': 'warnings',
        'section_title': 'Warnings',
        'section_text': 'Enteral feeding requires review.',
      },
    ];
    db.tables['source_document'] = [
      {
        'source_doc_id': 'doc_ldopa_enteral',
        'title': 'Imported levodopa enteral label fact',
        'raw_payload': '''
{"label_facts":[{"fact_type":"enteral_feed_review","label":"Enteral feeding requires review","payload":{}}]}
''',
      },
    ];
    final provider =
        ImportedLabelRuleProvider(database: db, compiler: compiler);
    final rules = await provider.loadRules();
    final service = ClinicalDecisionSupportService(
      database: db,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );

    final output = await service.run(
      context: const UnifiedRuntimeContext(
        userProfile: UserProfileRuntimeContext(
          patientId: 'patient_enteral',
          registrationRegion: 'US',
          displayLocale: 'en-US',
          contentJurisdictionOverride: [],
          dietProfileRegion: 'US',
          timezone: 'America/Toronto',
        ),
        drug: DrugRuntimeContext(
          id: 'DRUG_LDOPA#US#DAILYMED#drug_ldopa',
          genericName: 'carbidopa/levodopa',
          brandName: null,
          activeIngredients: ['carbidopa', 'levodopa'],
          substanceTags: ['levodopa'],
          formulation: 'tablet',
          dosageForm: 'tablet',
          route: 'oral',
          releaseType: 'immediate',
          dailyDoseMg: 300,
          jurisdiction: 'US',
        ),
        meal: null,
        coevent: null,
        enteralFeed: EnteralFeedRuntimeContext(
          mode: 'continuous',
          formula: 'standard_feed',
          proteinGPerDay: 80,
        ),
        timestamps: TimestampRuntimeContext(
          drugTime: null,
          mealTime: null,
          coeventTime: null,
        ),
      ),
      rules: rules,
      factsVersion: 'facts_v1',
      rulesVersion: 'imported_label_rules_v1',
    );

    expect(
      output.alerts.any(
        (alert) =>
            alert.ruleIds.any((id) => id.endsWith('.enteral_feed_review')) &&
            alert.decision == RuntimeDecisionType.requireReview,
      ),
      isTrue,
    );
  });

  test('recommendation audit is written for regional recommendations',
      () async {
    final db = RecordingCdssDatabase();
    final service = ClinicalDecisionSupportService(
      database: db,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );
    final recommendations = GetFoodRecommendationsUseCase().call(
      history: const [],
      drugs: const [],
      allFoods: [
        FoodItem(
          id: 'banana',
          name: '香蕉',
          category: FoodCategory.fruit,
          proteinG: 1.0,
          carbsG: 20,
          fatG: 0.3,
          fiberG: 2.0,
          sodiumMg: 1.0,
        ),
      ],
      userProfile: UserProfile.defaults().copyWith(
        registrationRegion: 'JP',
        displayLocale: 'ja-JP',
        dietProfileRegion: 'JP',
      ),
    );

    await service.writeRecommendationAudit(
      userProfile: const UserProfileRuntimeContext(
        patientId: 'patient_1',
        registrationRegion: 'JP',
        displayLocale: 'ja-JP',
        contentJurisdictionOverride: [],
        dietProfileRegion: 'JP',
        timezone: 'America/Toronto',
      ),
      mealSlot: 'dashboard',
      factsVersion: 'facts_v1',
      rulesVersion: 'rules_v1',
      recommendations: recommendations,
    );

    final rows = await db.queryTable('recommendation_audit_log');
    expect(rows, hasLength(1));
    expect(rows.single['meal_slot'], 'dashboard');
    expect(rows.single['fallback_used'], isTrue);
  });

  test('official import writes cluster conflict rationale artifacts', () async {
    final db = RecordingCdssDatabase();
    final service = ClinicalDecisionSupportService(
      database: db,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );

    await service.importBundle(
      const P0ImportBundle(
        sourceDocuments: [
          SourceDocumentRecord(
            sourceDocId: 'doc_fdc_high',
            sourceFamily: 'FDC',
            organization: 'USDA',
            docType: 'food_nutrient',
            title: 'FDC high confidence',
            jurisdiction: 'US',
            originUrl: 'https://example.test/fdc',
            publishedAt: null,
            effectiveAt: null,
            language: 'en',
            licenseNote: 'test',
            checksum: 'fdc',
            sourceStatus: 'active',
            rawPayload: '{}',
          ),
          SourceDocumentRecord(
            sourceDocId: 'doc_ciqual_low',
            sourceFamily: 'CIQUAL',
            organization: 'ANSES',
            docType: 'food_nutrient',
            title: 'Ciqual lower confidence',
            jurisdiction: 'FR',
            originUrl: 'https://example.test/ciqual',
            publishedAt: null,
            effectiveAt: null,
            language: 'fr',
            licenseNote: 'test',
            checksum: 'ciqual',
            sourceStatus: 'active',
            rawPayload: '{}',
          ),
        ],
        observations: [
          ObservationRecord(
            observationId: 'obs_protein_fdc',
            domain: 'food',
            entityType: 'food_variant',
            entityKey: 'FOOD_TEST#US#FDC#1',
            attributeCode: 'protein_g',
            valueType: 'numeric',
            value: QualifiedValue(
              rawValueText: '10',
              qualifierKind: QualifierKind.exact,
              valueNum: 10,
              low: 10,
              high: 10,
            ),
            unit: 'g',
            basisType: 'per_100g',
            basisAmount: 100,
            scopeHash: 'scope_food_us',
            sourceDocId: 'doc_fdc_high',
            recordLocator: 'protein',
            methodCode: null,
            extractionConfidence: 0.98,
          ),
          ObservationRecord(
            observationId: 'obs_protein_ciqual',
            domain: 'food',
            entityType: 'food_variant',
            entityKey: 'FOOD_TEST#US#FDC#1',
            attributeCode: 'protein_g',
            valueType: 'numeric',
            value: QualifiedValue(
              rawValueText: '2',
              qualifierKind: QualifierKind.exact,
              valueNum: 2,
              low: 2,
              high: 2,
            ),
            unit: 'g',
            basisType: 'per_100g',
            basisAmount: 100,
            scopeHash: 'scope_food_us',
            sourceDocId: 'doc_ciqual_low',
            recordLocator: 'protein',
            methodCode: null,
            extractionConfidence: 0.75,
          ),
        ],
      ),
    );

    final audits = await db.queryTable('conflict_audit_log');
    expect(audits.single['audit_type'], 'FACT_CLUSTER_RESOLUTION');
    expect('${audits.single['decision_reason']}', contains('accepted'));
    expect('${audits.single['decision_reason']}', contains('rejected'));
    expect('${audits.single['decision_reason']}',
        contains('accepted_highest_ranked_candidate'));
    expect('${audits.single['decision_reason']}', contains('out_of_tolerance'));
    expect('${audits.single['decision_reason']}',
        contains('cross_source_contradiction'));
    expect(
        '${audits.single['decision_reason']}', contains('ranking_explanation'));

    final distributions = await db.queryTable('snapshot_distribution');
    final importArtifact = distributions.firstWhere(
      (row) => row['distribution_type'] == 'import_artifacts',
    );
    expect(
        '${importArtifact['manifest_json']}', contains('conflict_rationale'));
  });

  test('runtime loads matching database rule version before caller seed rules',
      () async {
    final db = RecordingCdssDatabase();
    final service = ClinicalDecisionSupportService(
      database: db,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );
    await db.insertRuleRegistry(_runtimeRuleRow(
      ruleId: 'db.rule.versioned',
      version: 'db_rules_v2',
      decision: 'INFO',
    ));

    final output = await service.run(
      context: _runtimeContextForDbRule(),
      rules: const [],
      factsVersion: 'facts_v1',
      rulesVersion: 'db_rules_v2',
    );

    expect(output.alertsJson['compiled_rule_source'],
        'database_rule_registry_snapshot');
    expect(output.alerts.map((alert) => alert.ruleIds).expand((ids) => ids),
        contains('db.rule.versioned'));
    expect(output.alertsJson['rule_hit_trace'], isNotEmpty);
    final runtimeEvent = (await db.queryTable('runtime_event')).single;
    expect('${runtimeEvent['machine_readable_json']}',
        contains('db.rule.versioned'));
  });

  test('database rule version switch changes runtime result', () async {
    final db = RecordingCdssDatabase();
    final service = ClinicalDecisionSupportService(
      database: db,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );
    await db.insertRuleRegistry(_runtimeRuleRow(
      ruleId: 'db.rule.switch',
      version: 'db_rules_v1',
      decision: 'INFO',
    ));
    await db.insertRuleRegistry(_runtimeRuleRow(
      ruleId: 'db.rule.switch',
      version: 'db_rules_v2',
      decision: 'WARN',
    ));

    final v1 = await service.run(
      context: _runtimeContextForDbRule(),
      rules: const [],
      factsVersion: 'facts_v1',
      rulesVersion: 'db_rules_v1',
    );
    final v2 = await service.run(
      context: _runtimeContextForDbRule(),
      rules: const [],
      factsVersion: 'facts_v1',
      rulesVersion: 'db_rules_v2',
    );

    expect(v1.alerts.single.decision, RuntimeDecisionType.info);
    expect(v2.alerts.single.decision, RuntimeDecisionType.warn);
  });

  test('runtime trace includes matched suppressed and missing-field reasons',
      () async {
    final compiler = RuleRegistryCompiler();
    final db = RecordingCdssDatabase();
    final service = ClinicalDecisionSupportService(
      database: db,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );
    final output = await service.run(
      context: _runtimeContextForDbRule(dailyDoseMg: null),
      rules: compiler.compileJsonList([
        _runtimeRuleJson(
          ruleId: 'trace.warn',
          decision: 'WARN',
          priorityBand: 5,
        ),
        _runtimeRuleJson(
          ruleId: 'trace.info',
          decision: 'INFO',
          priorityBand: 5,
        ),
        _runtimeRuleJson(
          ruleId: 'trace.missing.dose',
          decision: 'WARN',
          priorityBand: 4,
          when: {
            'dose_band': {
              'path': 'drug.daily_dose_mg',
              'threshold': 200,
              'op': 'gte',
            }
          },
        ),
      ], rulesVersion: 'trace_rules'),
      factsVersion: 'facts_v1',
      rulesVersion: 'trace_rules',
    );

    final trace =
        (output.alertsJson['rule_hit_trace'] as List<dynamic>).cast<Map>();
    final suppressed =
        trace.firstWhere((row) => row['rule_id'] == 'trace.info');
    final missing =
        trace.firstWhere((row) => row['rule_id'] == 'trace.missing.dose');
    expect(suppressed['matched'], isTrue);
    expect(suppressed['suppressed'], isTrue);
    expect(
        suppressed['tie_break_reason'], 'same_band_warn_permissive_conflict');
    final provenanceScore = suppressed['provenance_score'] as Map;
    expect(provenanceScore['source_authority'], 100);
    expect(provenanceScore['source_status'], 'active');
    expect(provenanceScore['jurisdiction_specificity'], greaterThan(0));
    expect(suppressed['source_refs'], isNotEmpty);
    expect(suppressed['priority'], suppressed['priority_band']);
    expect(suppressed['specificity'], suppressed['specificity_band']);
    expect(missing['matched'], isFalse);
    expect(missing['missing_field_reason'], 'missing_dose');
    final traceMetadata = output.alertsJson['trace_metadata'] as Map;
    expect(traceMetadata['region_jurisdiction_source'], 'runtime_static_map');
    expect((traceMetadata['warnings'] as List),
        contains('region_jurisdiction_map_static_fallback_possible'));
    expect(output.auditLogJsonl, contains('"event_type":"rule_trace"'));
  });

  test('invalid database rule is audited and skipped without crashing',
      () async {
    final db = RecordingCdssDatabase();
    final service = ClinicalDecisionSupportService(
      database: db,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );
    await db.insertRuleRegistry({
      'rule_id': 'db.rule.invalid',
      'rule_version': 'db_rules_v2',
      'status': 'active',
      'rule_type': 'soft_rule',
      'priority_band': 1,
      'specificity_band': 1,
      'jurisdiction_json': '["GLOBAL"]',
      'applies_to_json': '{"subject_types":["drug"]}',
      'predicate_json': '{bad json',
      'effect_json': '{}',
      'provenance_json': '{}',
    });

    final output = await service.run(
      context: _runtimeContextForDbRule(),
      rules: const [],
      factsVersion: 'facts_v1',
      rulesVersion: 'db_rules_v2',
    );

    expect(output.alertsJson['compiled_rule_source'], isNotNull);
    final audits = await db.queryTable('conflict_audit_log');
    expect(audits.map((row) => row['audit_type']),
        contains('RULE_COMPILE_FAILURE'));
  });

  test('variant resolver prefers concept crosswalk over legacy food code',
      () async {
    final db = RecordingCdssDatabase();
    await db.insertStagingRow('food_variant', {
      'food_variant_id': 'variant_crosswalk',
      'food_concept_id': 'FOOD_CANONICAL',
      'jurisdiction': 'US',
      'source_family': 'FDC',
      'source_food_code': 'official_123',
      'display_name_local': 'Crosswalk food',
      'is_authoritative_for_region': 1,
      'is_authoritative_fallback': 0,
      'status': 'active',
      'fallback_chain_json': '[]',
    });
    await db.insertStagingRow('food_variant', {
      'food_variant_id': 'variant_legacy',
      'food_concept_id': 'FOOD_LEGACY',
      'jurisdiction': 'US',
      'source_family': 'LEGACY',
      'source_food_code': 'banana',
      'display_name_local': 'Legacy banana',
      'is_authoritative_for_region': 1,
      'is_authoritative_fallback': 0,
      'status': 'active',
      'fallback_chain_json': '[]',
    });
    await db.insertStagingRow('concept_variant_crosswalk', {
      'crosswalk_id': 'xwalk_banana',
      'domain': 'food',
      'app_entity_id': 'banana',
      'concept_id': 'FOOD_CANONICAL',
      'variant_id': 'variant_crosswalk',
      'external_id_system': 'FDC id',
      'external_id_value': 'official_123',
      'jurisdiction': 'US',
      'source_doc_id': 'doc_fdc',
      'import_run_id': 'run_fdc',
      'confidence': 0.99,
      'status': 'active',
      'mapping_payload_json': '{}',
      'created_at': 1000,
    });

    final resolver = VariantResolver(database: db);
    final resolved = await resolver.resolveFoodVariant(
      foodId: 'banana',
      userProfile: const UserProfileRuntimeContext(
        patientId: 'patient_1',
        registrationRegion: 'US',
        displayLocale: 'en-US',
        contentJurisdictionOverride: [],
        dietProfileRegion: 'US',
        timezone: 'America/Toronto',
      ),
    );

    expect(resolved.selectedVariantId, 'variant_crosswalk');
    expect(resolved.conceptId, 'FOOD_CANONICAL');
  });

  test('catalog projection marks legacy id fallback when crosswalk is missing',
      () async {
    final db = RecordingCdssDatabase();
    await db.insertFoodConcept(
      const FoodConceptRecord(
        foodConceptId: 'FOOD_LEGACY',
        canonicalNameEn: 'legacy food',
        canonicalNameZh: '旧食品',
        foodGroup: 'grain',
      ),
    );
    await db.insertFoodVariant(
      const FoodVariantRecord(
        foodVariantId: 'FOOD_LEGACY#US#LEGACY#001',
        foodConceptId: 'FOOD_LEGACY',
        jurisdiction: 'US',
        sourceFamily: 'LEGACY',
        sourceFoodCode: '001',
        displayNameLocal: 'Legacy food',
        isAuthoritativeForRegion: true,
        isAuthoritativeFallback: false,
        status: 'active',
        fallbackChainJson: '[]',
      ),
    );

    final projected =
        await CdssCatalogProjectionService(database: db).projectFoods();

    expect(projected.single.id, startsWith('food_projected_'));
    expect(projected.single.description,
        contains('missing_concept_variant_crosswalk'));
    expect(
        projected.single.description, contains('legacy_variant_id_projection'));
  });

  test('fact conflict rationale reports tolerance and scope mismatch', () {
    final engine = FactConflictEngine();
    final resolution = engine.resolveCluster(
      observations: [
        _testObservation(
          id: 'obs_official',
          value: 10,
          sourceDocId: 'doc_p0',
          scopeHash: 'scope_us_tablet',
          confidence: 0.99,
        ),
        _testObservation(
          id: 'obs_old_scope',
          value: 8,
          sourceDocId: 'doc_p1_old',
          scopeHash: 'scope_ca_capsule',
          confidence: 0.70,
        ),
      ],
      existingFacts: const [],
      sourceDocumentsById: {
        'doc_p0': _testSourceDocument(
          id: 'doc_p0',
          tier: KnowledgeDataTier.p0,
          effectiveAt: DateTime.utc(2026),
        ),
        'doc_p1_old': _testSourceDocument(
          id: 'doc_p1_old',
          tier: KnowledgeDataTier.p1,
          effectiveAt: DateTime.utc(2020),
        ),
      },
      scopesByHash: {
        'scope_us_tablet': const VariantScopeRecord(
          scopeHash: 'scope_us_tablet',
          jurisdiction: 'US',
          brand: null,
          dosageForm: 'tablet',
          releaseType: 'immediate',
          saltForm: null,
          route: 'oral',
          preparationState: null,
          cookingState: null,
          plantPart: null,
          cultivar: null,
          samplingFrame: 'adult_label',
        ),
        'scope_ca_capsule': const VariantScopeRecord(
          scopeHash: 'scope_ca_capsule',
          jurisdiction: 'CA',
          brand: null,
          dosageForm: 'capsule',
          releaseType: 'extended',
          saltForm: null,
          route: 'oral',
          preparationState: null,
          cookingState: null,
          plantPart: null,
          cultivar: null,
          samplingFrame: 'market_sample',
        ),
      },
    );

    expect(resolution.chosenObservation?.observationId, 'obs_official');
    final rejected = resolution.rejectedRationales.single;
    expect(rejected['rationale'], 'scope_mismatch');
    expect((rejected['scope_mismatch_dimensions'] as List),
        containsAll(['jurisdiction', 'dosage_form', 'release_type']));
    expect(rejected['scope_match_details'], isA<Map>());
    expect(rejected['numeric_overlap_result'], isA<Map>());
    expect((rejected['tolerance_result'] as Map)['result'], 'out_of_tolerance');
    expect(rejected['source_authority'], 90);
    expect(rejected['freshness'], greaterThan(0));
    expect(rejected['extraction_confidence'], 0.70);
    expect((rejected['tolerance'] as Map)['out_of_tolerance'], isTrue);
    expect('${rejected['ranking_explanation']}', contains('scope_mismatch'));
  });
}

Map<String, dynamic> _runtimeRuleRow({
  required String ruleId,
  required String version,
  required String decision,
}) =>
    {
      'rule_id': ruleId,
      'rule_version': version,
      'status': 'active',
      'rule_type': 'soft_rule',
      'priority_band': 9,
      'specificity_band': 9,
      'jurisdiction_json': jsonEncode(['GLOBAL']),
      'applies_to_json': jsonEncode({
        'subject_types': ['drug'],
      }),
      'predicate_json': jsonEncode({
        'exists': {'path': 'drug.id'},
      }),
      'effect_json': jsonEncode({
        'decision': decision,
        'severity': 'low',
        'messages': {'zh': '数据库规则命中', 'en': 'DB rule matched'},
        'actions': [],
        'output_tags': ['db_rule'],
      }),
      'provenance_json': jsonEncode({
        'evidence_level': 'official_label',
        'source_refs': ['doc_db_rule'],
        'effective_from': '2026-01-01T00:00:00Z',
      }),
    };

ObservationRecord _testObservation({
  required String id,
  required double value,
  required String sourceDocId,
  required String scopeHash,
  required double confidence,
}) =>
    ObservationRecord(
      observationId: id,
      domain: 'drug',
      entityType: 'drug_product_variant',
      entityKey: 'drug_variant_1',
      attributeCode: 'dose_mg',
      valueType: 'numeric',
      value: QualifiedValue(
        rawValueText: '$value',
        qualifierKind: QualifierKind.exact,
        low: value,
        high: value,
        valueNum: value,
      ),
      unit: 'mg',
      basisType: 'per_dose',
      basisAmount: null,
      scopeHash: scopeHash,
      sourceDocId: sourceDocId,
      recordLocator: id,
      methodCode: null,
      extractionConfidence: confidence,
    );

SourceDocumentRecord _testSourceDocument({
  required String id,
  required String tier,
  required DateTime effectiveAt,
}) =>
    SourceDocumentRecord(
      sourceDocId: id,
      sourceFamily: 'TEST',
      dataTier: tier,
      ingestionStrategy: SourceIngestionStrategy.authoritativeDirect,
      organization: 'Test Org',
      docType: 'label',
      title: id,
      jurisdiction: 'US',
      originUrl: 'https://example.test/$id',
      publishedAt: effectiveAt,
      effectiveAt: effectiveAt,
      language: 'en',
      licenseNote: 'test',
      checksum: id,
      sourceStatus: 'active',
      rawPayload: '{}',
    );

UnifiedRuntimeContext _runtimeContextForDbRule({double? dailyDoseMg = 100}) =>
    UnifiedRuntimeContext(
      userProfile: const UserProfileRuntimeContext(
        patientId: 'patient_db_rule',
        registrationRegion: 'US',
        displayLocale: 'en-US',
        contentJurisdictionOverride: [],
        dietProfileRegion: 'US',
        timezone: 'America/Toronto',
      ),
      drug: DrugRuntimeContext(
        id: 'drug_db',
        genericName: 'levodopa',
        brandName: null,
        activeIngredients: ['levodopa'],
        substanceTags: ['levodopa'],
        formulation: 'tablet',
        dosageForm: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        dailyDoseMg: dailyDoseMg,
        jurisdiction: 'US',
      ),
      meal: null,
      coevent: null,
      enteralFeed: null,
      timestamps: const TimestampRuntimeContext(
        drugTime: null,
        mealTime: null,
        coeventTime: null,
      ),
    );

Map<String, dynamic> _runtimeRuleJson({
  required String ruleId,
  required String decision,
  int priorityBand = 9,
  Map<String, dynamic>? when,
}) =>
    {
      'rule_id': ruleId,
      'version': '1.0.0',
      'status': 'active',
      'rule_type': 'soft_rule',
      'priority_band': priorityBand,
      'specificity_band': priorityBand,
      'jurisdiction': ['GLOBAL'],
      'applies_to': {
        'subject_types': ['drug'],
      },
      'when': when ??
          {
            'exists': {'path': 'drug.id'},
          },
      'then': {
        'decision': decision,
        'severity': 'low',
        'messages': {'zh': 'trace rule'},
        'actions': [],
        'output_tags': [],
      },
      'provenance': {
        'evidence_level': 'official_label',
        'source_refs': ['doc_$ruleId'],
      },
    };
