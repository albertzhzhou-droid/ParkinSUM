import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/cdss_database.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';
import 'package:parkinsum_companion/domain/usecases/clinical_decision_support_service.dart';
import 'package:parkinsum_companion/domain/usecases/fact_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/knowledge_base_release_service.dart';
import 'package:parkinsum_companion/domain/usecases/runtime_rule_engine.dart';

class _BundleRecordingDb implements CdssDatabase {
  final Map<String, List<Map<String, Object?>>> tables = {
    'engine_snapshot': <Map<String, Object?>>[],
    'source_document': <Map<String, Object?>>[],
    'food_concept': <Map<String, Object?>>[],
    'food_variant': <Map<String, Object?>>[],
    'drug_concept': <Map<String, Object?>>[],
    'drug_product_variant': <Map<String, Object?>>[],
    'drug_label_section': <Map<String, Object?>>[],
    'drug_product_code': <Map<String, Object?>>[],
    'drug_product_packaging': <Map<String, Object?>>[],
    'drug_product_media': <Map<String, Object?>>[],
    'concept_variant_crosswalk': <Map<String, Object?>>[],
    'variant_scope': <Map<String, Object?>>[],
    'observation': <Map<String, Object?>>[],
    'resolved_fact': <Map<String, Object?>>[],
    'rule_registry': <Map<String, Object?>>[],
    'country_diet_profile': <Map<String, Object?>>[],
    'meal_template': <Map<String, Object?>>[],
    'ingestion_run': <Map<String, Object?>>[],
    'snapshot_distribution': <Map<String, Object?>>[],
    'conflict_audit_log': <Map<String, Object?>>[],
    'cdss_record_history': <Map<String, Object?>>[],
    'human_review_ticket': <Map<String, Object?>>[],
    'region_jurisdiction_map': <Map<String, Object?>>[],
  };

  @override
  Future<void> initialize() async {}

  void _add(String table, Map<String, Object?> row) {
    tables.putIfAbsent(table, () => <Map<String, Object?>>[]).add(row);
  }

  void _appendHistory({
    required String tableName,
    required String recordId,
    required String versionId,
    required Map<String, Object?> row,
    String? snapshotId,
    String? importRunId,
    int? effectiveAt,
  }) {
    final rows = tables['cdss_record_history']!;
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    final historyId = '$tableName:$recordId:$versionId:${rows.length + 1}';
    for (final existing in rows.where((item) =>
        item['table_name'] == tableName &&
        item['record_id'] == recordId &&
        item['retired_at'] == null)) {
      existing['superseded_by'] = historyId;
      existing['retired_at'] = createdAt;
    }
    rows.add({
      'history_id': historyId,
      'table_name': tableName,
      'record_id': recordId,
      'version_id': versionId,
      'payload_json': jsonEncode(row),
      'superseded_by': null,
      'effective_at': effectiveAt ?? createdAt,
      'retired_at': null,
      'import_run_id': importRunId,
      'snapshot_id': snapshotId ?? row['snapshot_id']?.toString(),
      'created_at': createdAt,
    });
  }

  @override
  Future<void> clearStagingRun(String runId) async {}

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
      'needs_human_review': record.needsHumanReview ? 1 : 0,
      'created_at': record.createdAt.millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> insertCountryDietProfile(CountryDietProfileRecord record) async {
    _add('country_diet_profile', {
      'country_code': record.countryCode,
      'guideline_source': record.guidelineSource,
      'meal_pattern_json': record.mealPatternJson,
      'staple_foods_json': record.stapleFoodsJson,
      'preferred_protein_sources_json': record.preferredProteinSourcesJson,
      'avoidance_notes_json': record.avoidanceNotesJson,
    });
  }

  @override
  Future<void> insertDrugConcept(DrugConceptRecord record) async {
    _add('drug_concept', {
      'drug_concept_id': record.drugConceptId,
      'generic_name': record.genericName,
      'atc_like_code': record.atcLikeCode,
    });
  }

  @override
  Future<void> insertDrugLabelSection(DrugLabelSectionRecord record) async {
    _add('drug_label_section', {
      'section_id': record.sectionId,
      'drug_product_variant_id': record.drugProductVariantId,
      'source_doc_id': record.sourceDocId,
      'section_key': record.sectionKey,
      'section_title': record.sectionTitle,
      'section_text': record.sectionText,
    });
  }

  @override
  Future<void> insertDrugProductCode(DrugProductCodeRecord record) async {
    _add('drug_product_code', {
      'product_code_id': record.productCodeId,
      'drug_product_variant_id': record.drugProductVariantId,
      'source_doc_id': record.sourceDocId,
      'code_system': record.codeSystem,
      'code_value': record.codeValue,
      'display_text': record.displayText,
    });
  }

  @override
  Future<void> insertDrugProductPackaging(
      DrugProductPackagingRecord record) async {
    _add('drug_product_packaging', {
      'packaging_id': record.packagingId,
      'drug_product_variant_id': record.drugProductVariantId,
      'source_doc_id': record.sourceDocId,
      'package_code': record.packageCode,
      'description': record.description,
      'marketing_status': record.marketingStatus,
    });
  }

  @override
  Future<void> insertDrugProductMedia(DrugProductMediaRecord record) async {
    _add('drug_product_media', {
      'media_id': record.mediaId,
      'drug_product_variant_id': record.drugProductVariantId,
      'source_doc_id': record.sourceDocId,
      'media_type': record.mediaType,
      'media_url': record.mediaUrl,
      'caption': record.caption,
    });
  }

  @override
  Future<void> insertDrugProductVariant(DrugProductVariantRecord record) async {
    _add('drug_product_variant', {
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
    });
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
    _add('food_concept', {
      'food_concept_id': record.foodConceptId,
      'canonical_name_en': record.canonicalNameEn,
      'canonical_name_zh': record.canonicalNameZh,
      'food_group': record.foodGroup,
    });
  }

  @override
  Future<void> insertFoodVariant(FoodVariantRecord record) async {
    _add('food_variant', {
      'food_variant_id': record.foodVariantId,
      'food_concept_id': record.foodConceptId,
      'jurisdiction': record.jurisdiction,
      'source_family': record.sourceFamily,
      'source_food_code': record.sourceFoodCode,
      'display_name_local': record.displayNameLocal,
      'is_authoritative_for_region': record.isAuthoritativeForRegion ? 1 : 0,
      'is_authoritative_fallback': record.isAuthoritativeFallback ? 1 : 0,
      'status': record.status,
      'fallback_chain_json': record.fallbackChainJson,
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
  Future<void> insertLocaleResourceBundle(
      LocaleResourceBundleRecord record) async {}

  @override
  Future<void> insertMealTemplate(MealTemplateRecord record) async {
    _add('meal_template', {
      'meal_template_id': record.mealTemplateId,
      'country_code': record.countryCode,
      'meal_slot': record.mealSlot,
      'template_json': record.templateJson,
      'texture_level': record.textureLevel,
    });
  }

  @override
  Future<void> insertObservation(ObservationRecord record) async {
    _add('observation', {
      'observation_id': record.observationId,
      'domain': record.domain,
      'entity_type': record.entityType,
      'entity_key': record.entityKey,
      'attribute_code': record.attributeCode,
      'value_type': record.valueType,
      'qualifier_kind': record.value.qualifierKind.wireValue,
      'low': record.value.low,
      'high': record.value.high,
      'value_num': record.value.valueNum,
      'raw_value_text': record.value.rawValueText,
      'unit': record.unit,
      'basis_type': record.basisType,
      'basis_amount': record.basisAmount,
      'scope_hash': record.scopeHash,
      'source_doc_id': record.sourceDocId,
      'record_locator': record.recordLocator,
      'method_code': record.methodCode,
      'extraction_confidence': record.extractionConfidence,
    });
  }

  @override
  Future<void> insertRecommendationAuditLog(
      RecommendationAuditLogRecord record) async {}

  @override
  Future<void> insertRegionJurisdictionMap(
      RegionJurisdictionMapRecord record) async {
    _add('region_jurisdiction_map', {
      'region_code': record.regionCode,
      'jurisdiction_chain_json': record.jurisdictionChainJson,
      'food_source_priority_json': record.foodSourcePriorityJson,
      'drug_source_priority_json': record.drugSourcePriorityJson,
      'diet_guideline_source': record.dietGuidelineSource,
    });
  }

  @override
  Future<void> insertResolvedFact(ResolvedFactRecord record) async {
    final row = {
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
      'manual_override': record.manualOverride ? 1 : 0,
    };
    tables['resolved_fact']!
        .removeWhere((existing) => existing['fact_id'] == record.factId);
    _appendHistory(
      tableName: 'resolved_fact',
      recordId: record.factId,
      versionId: record.factVersion,
      row: row,
      snapshotId: record.snapshotId,
    );
    _add('resolved_fact', row);
  }

  @override
  Future<void> insertRuleRegistry(Map<String, dynamic> row) async {
    final record = Map<String, Object?>.from(row);
    final recordId = '${record['rule_id'] ?? record['compiled_hash']}';
    tables['rule_registry']!
        .removeWhere((existing) => existing['rule_id'] == record['rule_id']);
    _appendHistory(
      tableName: 'rule_registry',
      recordId: recordId,
      versionId: '${record['rule_version'] ?? record['compiled_hash']}',
      row: record,
      snapshotId: record['snapshot_id']?.toString(),
      importRunId: record['import_run_id']?.toString(),
      effectiveAt: (record['updated_at'] as num?)?.toInt(),
    );
    _add('rule_registry', record);
  }

  @override
  Future<void> insertRuntimeEvent(RuntimeEventRecord record) async {
    final row = {
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
    _appendHistory(
      tableName: 'runtime_event',
      recordId: record.eventId,
      versionId: '${record.createdAt.microsecondsSinceEpoch}',
      row: row,
      snapshotId: record.snapshotId,
      effectiveAt: record.createdAt.millisecondsSinceEpoch,
    );
    _add('runtime_event', row);
  }

  @override
  Future<void> insertSnapshotDistribution(
      SnapshotDistributionRecord record) async {
    final row = {
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
    };
    _appendHistory(
      tableName: 'snapshot_distribution',
      recordId: record.distributionId,
      versionId: '${record.createdAt.microsecondsSinceEpoch}',
      row: row,
      snapshotId: record.snapshotId,
      effectiveAt: record.createdAt.millisecondsSinceEpoch,
    );
    _add('snapshot_distribution', row);
  }

  @override
  Future<void> insertSourceDocument(SourceDocumentRecord record) async {
    _add('source_document', {
      'source_doc_id': record.sourceDocId,
      'source_family': record.sourceFamily,
      'data_tier': record.dataTier,
      'ingestion_strategy': record.ingestionStrategy,
      'organization': record.organization,
      'jurisdiction': record.jurisdiction,
      'doc_type': record.docType,
      'title': record.title,
      'origin_url': record.originUrl,
      'published_at': record.publishedAt?.millisecondsSinceEpoch,
      'effective_at': record.effectiveAt?.millisecondsSinceEpoch,
      'language': record.language,
      'license_note': record.licenseNote,
      'checksum': record.checksum,
      'source_status': record.sourceStatus,
      'raw_payload': record.rawPayload,
    });
  }

  @override
  Future<void> insertStagingRow(String table, Map<String, Object?> row) async {
    if (table == 'human_review_ticket') {
      tables.putIfAbsent(table, () => <Map<String, Object?>>[]);
      tables[table]!
          .removeWhere((existing) => existing['ticket_id'] == row['ticket_id']);
    }
    _add(table, row);
  }

  @override
  Future<void> insertVariantScope(VariantScopeRecord record) async {
    _add('variant_scope', {
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
    });
  }

  @override
  Future<List<Map<String, Object?>>> queryTable(String table) async =>
      tables[table] ?? const <Map<String, Object?>>[];
}

void main() {
  test('snapshot bundle import materializes core records and distribution log',
      () async {
    final db = _BundleRecordingDb();
    final service = KnowledgeBaseReleaseService(
      database: db,
      cdssService: ClinicalDecisionSupportService(
        database: db,
        factConflictEngine: FactConflictEngine(),
        runtimeRuleEngine: RuntimeRuleEngine(),
      ),
    );

    final tempDir = await Directory.systemTemp.createTemp('parkinsum_bundle_');
    final bundleFile = File('${tempDir.path}/snapshot.bundle.json');
    await bundleFile.writeAsString(
      jsonEncode({
        'manifest': {
          'snapshot_id': 'snap_1',
          'rules_version': 'rules_v1',
          'facts_version': 'snap_1',
        },
        'snapshot': {
          'snapshot_id': 'snap_1',
          'facts_version': 'snap_1',
          'rules_version': 'rules_v1',
          'created_at': 1000,
          'promoted_at': 2000,
          'rollback_parent': null,
          'input_hash': 'hash_1',
        },
        'source_document': [
          {
            'source_doc_id': 'doc_1',
            'source_family': 'DAILYMED',
            'data_tier': KnowledgeDataTier.p0,
            'ingestion_strategy': SourceIngestionStrategy.authoritativeDirect,
            'organization': 'NLM',
            'jurisdiction': 'US',
            'doc_type': 'spl_xml',
            'title': 'Example label',
            'origin_url': 'https://example.test/doc_1',
            'published_at': 1000,
            'effective_at': 1000,
            'language': 'en',
            'license_note': 'unspecified',
            'checksum': 'sum_1',
            'source_status': 'active',
            'raw_payload': '{}',
          }
        ],
        'food_concept': [
          {
            'food_concept_id': 'FOOD_RICE',
            'canonical_name_en': 'rice',
            'canonical_name_zh': '米饭',
            'food_group': 'grain',
          }
        ],
        'food_variant': [
          {
            'food_variant_id': 'FOOD_RICE#CN#OFFICIAL#001',
            'food_concept_id': 'FOOD_RICE',
            'jurisdiction': 'CN',
            'source_family': 'CHINA_OFFICIAL',
            'source_food_code': '001',
            'display_name_local': '米饭',
            'is_authoritative_for_region': 1,
            'is_authoritative_fallback': 0,
            'status': 'active',
            'fallback_chain_json': '[]',
          }
        ],
        'drug_concept': const <Map<String, Object?>>[],
        'drug_product_variant': const <Map<String, Object?>>[],
        'drug_label_section': const <Map<String, Object?>>[],
        'drug_product_code': const <Map<String, Object?>>[],
        'drug_product_packaging': const <Map<String, Object?>>[],
        'drug_product_media': const <Map<String, Object?>>[],
        'concept_variant_crosswalk': [
          {
            'crosswalk_id': 'xwalk_1',
            'domain': 'food',
            'app_entity_id': 'rice',
            'concept_id': 'FOOD_RICE',
            'variant_id': 'FOOD_RICE#CN#OFFICIAL#001',
            'external_id_system': 'CHINA_OFFICIAL',
            'external_id_value': '001',
            'jurisdiction': 'CN',
            'source_doc_id': 'doc_1',
            'import_run_id': 'bundle_import',
            'confidence': 1.0,
            'status': 'active',
            'mapping_payload_json': '{}',
            'created_at': 1000,
          }
        ],
        'variant_scope': [
          {
            'scope_hash': 'scope_1',
            'jurisdiction': 'CN',
            'brand': null,
            'dosage_form': null,
            'release_type': null,
            'salt_form': null,
            'route': null,
            'preparation_state': 'cooked',
            'cooking_state': 'steamed',
            'plant_part': null,
            'cultivar': null,
            'sampling_frame': null,
          }
        ],
        'observation': [
          {
            'observation_id': 'obs_1',
            'domain': 'food',
            'entity_type': 'food_variant',
            'entity_key': 'FOOD_RICE#CN#OFFICIAL#001',
            'attribute_code': 'protein_g',
            'value_type': 'numeric',
            'qualifier_kind': 'exact',
            'low': 2.6,
            'high': 2.6,
            'value_num': 2.6,
            'raw_value_text': '2.6',
            'unit': 'g',
            'basis_type': 'per_100g_edible_part',
            'basis_amount': 100.0,
            'scope_hash': 'scope_1',
            'source_doc_id': 'doc_1',
            'record_locator': 'rice_protein',
            'method_code': null,
            'extraction_confidence': 1.0,
          }
        ],
        'resolved_fact': [
          {
            'fact_id': 'fact_1',
            'entity_key': 'FOOD_RICE#CN#OFFICIAL#001',
            'attribute_code': 'protein_g',
            'scope_hash': 'scope_1',
            'resolution_status': 'resolved',
            'chosen_observation_id': 'obs_1',
            'qualifier_kind': 'exact',
            'resolved_low': 2.6,
            'resolved_high': 2.6,
            'value_num': 2.6,
            'raw_value_text': '2.6',
            'resolved_unit': 'g',
            'resolution_policy_id': 'policy_1',
            'snapshot_id': 'snap_1',
            'fact_version': 'snap_1',
            'manual_override': 0,
          }
        ],
        'rule_registry': [
          {
            'rule_id': 'rule_1',
            'rule_version': '1.0.0',
            'status': 'active',
            'rule_type': 'soft_rule',
            'priority_band': 1,
            'specificity_band': 1,
            'jurisdiction_json': '["GLOBAL"]',
            'applies_to_json': '{"target":"patient"}',
            'predicate_json': '{"exists":{"path":"drug.id"}}',
            'effect_json':
                '{"decision":"INFO","severity":"low","messages":{"zh":"提示","en":"Info"},"actions":[],"output_tags":[]}',
            'provenance_json':
                '{"evidence_level":"label","source_refs":["doc_1"],"effective_from":"2026-01-01T00:00:00Z"}',
          }
        ],
        'country_diet_profile': [
          {
            'country_code': 'CN',
            'guideline_source': 'Official guideline',
            'meal_pattern_json': '{"slots":["breakfast"]}',
            'staple_foods_json': '["rice"]',
            'preferred_protein_sources_json': '["soy"]',
            'avoidance_notes_json': '["reduce_salt"]',
          }
        ],
        'meal_template': [
          {
            'meal_template_id': 'tpl_1',
            'country_code': 'CN',
            'meal_slot': 'breakfast',
            'template_json': '{"foods":["FOOD_RICE#CN#OFFICIAL#001"]}',
            'texture_level': 'soft',
          }
        ],
      }),
    );

    final record =
        await service.importSnapshotBundle(filePath: bundleFile.path);

    expect(record.snapshotId, 'snap_1');
    expect(record.distributionType, 'import_bundle');
    expect((await db.queryTable('engine_snapshot')), hasLength(1));
    expect((await db.queryTable('food_variant')), hasLength(1));
    expect((await db.queryTable('observation')), hasLength(1));
    expect((await db.queryTable('resolved_fact')), hasLength(1));
    expect((await db.queryTable('concept_variant_crosswalk')), hasLength(1));
    expect((await db.queryTable('snapshot_distribution')), hasLength(1));
    expect((await db.queryTable('ingestion_run')).single['stage'],
        'bundle_import');

    final readiness = await service.validateReleaseCandidate('snap_1');
    expect(readiness.isReady, isTrue);
    expect(readiness.readinessProfile, 'production_candidate');
    expect(readiness.orphanResolvedFactCount, 0);

    await db.insertEngineSnapshot(
      EngineSnapshotRecord(
        snapshotId: 'snap_0',
        factsVersion: 'snap_0',
        rulesVersion: 'rules_v1',
        createdAt: DateTime.fromMillisecondsSinceEpoch(500),
        promotedAt: DateTime.fromMillisecondsSinceEpoch(500),
        rollbackParent: null,
        inputHash: 'hash_0',
      ),
    );
    await db.insertStagingRow('cdss_record_history', {
      'history_id': 'hist_fact_1_v0',
      'table_name': 'resolved_fact',
      'record_id': 'fact_1',
      'version_id': 'snap_0',
      'payload_json': '{"fact_id":"fact_1","value_num":1.0}',
      'superseded_by': 'hist_fact_1_v1',
      'effective_at': 500,
      'retired_at': 1000,
      'import_run_id': 'bundle_import_0',
      'snapshot_id': 'snap_0',
      'created_at': 500,
    });
    await db.insertStagingRow('cdss_record_history', {
      'history_id': 'hist_fact_1_v1',
      'table_name': 'resolved_fact',
      'record_id': 'fact_1',
      'version_id': 'snap_1',
      'payload_json': '{"fact_id":"fact_1","value_num":2.6}',
      'superseded_by': null,
      'effective_at': 1000,
      'retired_at': null,
      'import_run_id': 'bundle_import',
      'snapshot_id': 'snap_1',
      'created_at': 1000,
    });
    final publishRecord = await service.publishSnapshot(snapshotId: 'snap_1');
    expect(publishRecord.distributionType, 'publish');
    final manifest =
        jsonDecode(publishRecord.manifestJson) as Map<String, dynamic>;
    final readinessPayload =
        manifest['release_readiness'] as Map<String, dynamic>;
    expect(readinessPayload['is_ready'], isTrue);
    final versionDiff = manifest['version_diff'] as Map<String, dynamic>;
    expect(versionDiff['base_snapshot_id'], 'snap_0');
    expect(versionDiff['changed'], isNotEmpty);
    expect(versionDiff['active'], isNotEmpty);
    expect((versionDiff['by_table'] as Map<String, dynamic>)['resolved_fact'],
        isNotNull);
    expect(
      ((versionDiff['facts'] as Map<String, dynamic>)['changed']
              as List<dynamic>)
          .single['history_status'],
      'active',
    );
    final activeFactRows = ((versionDiff['facts']
        as Map<String, dynamic>)['active'] as List<dynamic>);
    final activeFact = activeFactRows
        .cast<Map<String, dynamic>>()
        .firstWhere((row) => row['record_id'] == 'fact_1');
    expect(activeFact['status'], 'active');
    expect(activeFact['snapshot_id'], 'snap_1');
    final rollbackSummary =
        versionDiff['rollback_summary'] as Map<String, dynamic>;
    expect(rollbackSummary['rollback_parent'], isNull);
    expect(rollbackSummary['restored_fact_count'], greaterThan(0));
    expect(rollbackSummary['retired_record_count'], 0);
    expect(
      rollbackSummary['active_record_count_after_rollback'],
      greaterThanOrEqualTo(rollbackSummary['restored_fact_count'] as int),
    );
    final artifactFiles = manifest['artifact_files'] as Map<String, dynamic>;
    expect(artifactFiles.keys, contains('release_readiness.json'));
    expect(artifactFiles.keys, contains('conflict_rationale.json'));
    expect(artifactFiles.keys, contains('rule_trace.json'));
    expect(artifactFiles.keys, contains('version_diff.json'));
    expect(artifactFiles.keys, contains('snapshot_manifest.json'));
    expect((await db.queryTable('snapshot_distribution')), hasLength(2));

    await db.insertStagingRow('human_review_ticket', {
      'ticket_id': 'ticket_ops_block',
      'reason_code': 'manual_review_required',
      'severity': 'high',
      'target_type': 'snapshot',
      'target_id': 'snap_1',
      'snapshot_id': 'snap_1',
      'run_id': null,
      'source_doc_refs_json': '["doc_1"]',
      'suggested_action': 'Operator review before production publish.',
      'status': 'open',
      'created_at': 2500,
      'resolved_at': null,
    });
    final blockedByTicket = await service.runReleaseReadinessDrill(
      snapshotId: 'snap_1',
    );
    expect(blockedByTicket.productionCandidateReady, isFalse);
    expect(blockedByTicket.publishWouldBeBlocked, isTrue);
    expect(blockedByTicket.openHighSeverityReviewTicketCount, 1);
    expect(blockedByTicket.sampleReviewTicketIds, contains('ticket_ops_block'));
    expect(blockedByTicket.humanReadableSummary,
        contains('Review tickets: open 1, high 1'));
    await service.updateReviewTicketStatus(
      ticketId: 'ticket_ops_block',
      status: 'ignored',
      resolvedAt: DateTime.fromMillisecondsSinceEpoch(2600),
    );
    final afterTicketIgnored = await service.runReleaseReadinessDrill(
      snapshotId: 'snap_1',
    );
    expect(afterTicketIgnored.productionCandidateReady, isTrue);
    expect(afterTicketIgnored.publishWouldBeBlocked, isFalse);
    final republishedAfterTicket = await service.publishSnapshot(
      snapshotId: 'snap_1',
    );
    expect(republishedAfterTicket.status, 'completed');

    await tempDir.delete(recursive: true);
  });

  test('versioned writes retire prior history while keeping current projection',
      () async {
    final db = _BundleRecordingDb();
    await db.insertRuleRegistry({
      'rule_id': 'rule_versioned',
      'rule_version': 'rules_v1',
      'status': 'active',
      'rule_type': 'soft_rule',
      'priority_band': 1,
      'specificity_band': 1,
      'jurisdiction_json': '["GLOBAL"]',
      'applies_to_json': '{"subject_types":["drug"]}',
      'predicate_json': '{"exists":{"path":"drug.id"}}',
      'effect_json':
          '{"decision":"INFO","severity":"low","messages":{"zh":"v1"},"actions":[],"output_tags":[]}',
      'provenance_json':
          '{"evidence_level":"official_label","source_refs":["doc_1"]}',
      'updated_at': 1000,
    });
    await db.insertRuleRegistry({
      'rule_id': 'rule_versioned',
      'rule_version': 'rules_v2',
      'status': 'active',
      'rule_type': 'soft_rule',
      'priority_band': 1,
      'specificity_band': 1,
      'jurisdiction_json': '["GLOBAL"]',
      'applies_to_json': '{"subject_types":["drug"]}',
      'predicate_json': '{"exists":{"path":"drug.id"}}',
      'effect_json':
          '{"decision":"WARN","severity":"medium","messages":{"zh":"v2"},"actions":[],"output_tags":[]}',
      'provenance_json':
          '{"evidence_level":"official_label","source_refs":["doc_2"]}',
      'updated_at': 2000,
    });

    final currentRules = await db.queryTable('rule_registry');
    expect(currentRules, hasLength(1));
    expect(currentRules.single['rule_version'], 'rules_v2');

    final history = await db.queryTable('cdss_record_history');
    final ruleHistory = history
        .where((row) => row['record_id'] == 'rule_versioned')
        .toList(growable: false);
    expect(ruleHistory, hasLength(2));
    expect(ruleHistory.first['effective_at'], 1000);
    expect(ruleHistory.first['retired_at'], isNotNull);
    expect(ruleHistory.first['superseded_by'], ruleHistory.last['history_id']);
    expect(ruleHistory.last['effective_at'], 2000);
    expect(ruleHistory.last['retired_at'], isNull);
  });

  test('release validation blocks snapshots without core provenance', () async {
    final db = _BundleRecordingDb();
    final service = KnowledgeBaseReleaseService(
      database: db,
      cdssService: ClinicalDecisionSupportService(
        database: db,
        factConflictEngine: FactConflictEngine(),
        runtimeRuleEngine: RuntimeRuleEngine(),
      ),
    );
    await db.insertEngineSnapshot(
      EngineSnapshotRecord(
        snapshotId: 'snap_empty',
        factsVersion: 'facts_empty',
        rulesVersion: 'rules_empty',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
        promotedAt: null,
        rollbackParent: null,
        inputHash: 'hash_empty',
      ),
    );

    final readiness = await service.validateReleaseCandidate('snap_empty');
    expect(readiness.isReady, isFalse);
    expect(readiness.blockingIssues, contains('missing_source_documents'));
    expect(readiness.blockingIssues, contains('missing_resolved_facts'));
    expect(readiness.blockingIssues, contains('missing_rule_registry'));
    final drill = await service.runReleaseReadinessDrill(
      snapshotId: 'snap_empty',
    );
    expect(drill.productionCandidateReady, isFalse);
    expect(drill.publishWouldBeBlocked, isTrue);
    expect(drill.overrideWouldAllowPublish, isFalse);
    expect(drill.blockingReasonSummary, contains('missing_source_documents'));
    expect(drill.artifactDurabilityStatus, 'missing');
    expect(drill.rollbackTarget, isNull);
    expect(drill.humanReadableSummary, contains('Release readiness drill'));
    expect(drill.humanReadableSummary, contains('Publish guard: blocked'));
    expect(
        drill.humanReadableSummary, contains('Artifact durability: missing'));
    expect(drill.warningCount, readiness.warnings.length);
    await expectLater(
      service.publishSnapshot(snapshotId: 'snap_empty'),
      throwsStateError,
    );
    final failedDistribution =
        (await db.queryTable('snapshot_distribution')).single;
    expect(failedDistribution['status'], 'failed');
    expect(failedDistribution['error_message'], contains('not release-ready'));
  });

  test('release readiness reports invalid rule registry rows', () async {
    final db = _BundleRecordingDb();
    final service = KnowledgeBaseReleaseService(
      database: db,
      cdssService: ClinicalDecisionSupportService(
        database: db,
        factConflictEngine: FactConflictEngine(),
        runtimeRuleEngine: RuntimeRuleEngine(),
      ),
    );
    await db.insertEngineSnapshot(
      EngineSnapshotRecord(
        snapshotId: 'snap_invalid_rule',
        factsVersion: 'facts_v1',
        rulesVersion: 'rules_bad',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
        promotedAt: DateTime.fromMillisecondsSinceEpoch(1000),
        rollbackParent: null,
        inputHash: 'hash_bad_rule',
      ),
    );
    await db.insertRuleRegistry({
      'rule_id': 'rule_bad',
      'rule_version': 'rules_bad',
      'status': 'active',
      'rule_type': 'unsupported',
      'priority_band': 1,
      'specificity_band': 1,
      'jurisdiction_json': '["GLOBAL"]',
      'applies_to_json': '{}',
      'predicate_json': '{}',
      'effect_json': '{}',
      'provenance_json': '{}',
    });

    final readiness =
        await service.validateReleaseCandidate('snap_invalid_rule');
    expect(readiness.invalidRuleCount, 1);
    expect(readiness.blockingIssues, contains('invalid_rule_registry_rows'));
    expect(readiness.openReviewTicketCount, 1);
    expect(readiness.highSeverityReviewTicketCount, 1);
    expect(readiness.blockingReasonSummary,
        contains('invalid_rule_registry_rows'));
    expect(readiness.sampleReviewTicketIds.single, startsWith('review_'));
    expect(readiness.blockingIssues,
        contains('open_high_severity_review_tickets'));
    final tickets = await db.queryTable('human_review_ticket');
    expect(tickets.single['reason_code'], 'invalid_rule_registry_row');
    expect(tickets.single['status'], 'open');

    final resolved = await service.updateReviewTicketStatus(
      ticketId: '${tickets.single['ticket_id']}',
      status: 'resolved',
      resolvedAt: DateTime.fromMillisecondsSinceEpoch(2000),
    );
    expect(resolved.status, 'resolved');
    expect(resolved.resolvedAt?.millisecondsSinceEpoch, 2000);
    final afterResolve =
        await service.validateReleaseCandidate('snap_invalid_rule');
    expect(afterResolve.openReviewTicketCount, 0);
    expect(afterResolve.highSeverityReviewTicketCount, 0);
    expect(afterResolve.blockingIssues,
        isNot(contains('open_high_severity_review_tickets')));
    final ignored = await service.updateReviewTicketStatus(
      ticketId: '${tickets.single['ticket_id']}',
      status: 'ignored',
      resolvedAt: DateTime.fromMillisecondsSinceEpoch(3000),
    );
    expect(ignored.status, 'ignored');
  });

  test('publish override records reason in distribution manifest', () async {
    final db = _BundleRecordingDb();
    final service = KnowledgeBaseReleaseService(
      database: db,
      cdssService: ClinicalDecisionSupportService(
        database: db,
        factConflictEngine: FactConflictEngine(),
        runtimeRuleEngine: RuntimeRuleEngine(),
      ),
    );
    await db.insertEngineSnapshot(
      EngineSnapshotRecord(
        snapshotId: 'snap_override',
        factsVersion: 'facts_missing',
        rulesVersion: 'rules_missing',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
        promotedAt: DateTime.fromMillisecondsSinceEpoch(1000),
        rollbackParent: null,
        inputHash: 'hash_override',
      ),
    );

    final record = await service.publishSnapshot(
      snapshotId: 'snap_override',
      overrideReason: 'ops director accepted temporary gap',
    );

    expect(record.status, 'completed');
    final manifest = jsonDecode(record.manifestJson) as Map<String, dynamic>;
    expect((manifest['publish_guard'] as Map)['override_used'], isTrue);
    expect((manifest['publish_guard'] as Map)['override_reason'],
        'ops director accepted temporary gap');
    final drill = await service.runReleaseReadinessDrill(
      snapshotId: 'snap_override',
      overrideReason: 'ops director accepted temporary gap',
    );
    expect(drill.productionCandidateReady, isFalse);
    expect(drill.publishWouldBeBlocked, isFalse);
    expect(drill.overrideWouldAllowPublish, isTrue);
    expect(drill.overrideReason, 'ops director accepted temporary gap');
    expect(drill.humanReadableSummary,
        contains('Override reason: ops director accepted temporary gap'));
  });

  test(
      'release readiness reports missing crosswalk samples and web backend warning',
      () async {
    final db = _BundleRecordingDb();
    final service = KnowledgeBaseReleaseService(
      database: db,
      cdssService: ClinicalDecisionSupportService(
        database: db,
        factConflictEngine: FactConflictEngine(),
        runtimeRuleEngine: RuntimeRuleEngine(),
      ),
    );
    await db.insertEngineSnapshot(
      EngineSnapshotRecord(
        snapshotId: 'snap_backend_warning',
        factsVersion: 'facts_v1',
        rulesVersion: 'rules_v1',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
        promotedAt: DateTime.fromMillisecondsSinceEpoch(1000),
        rollbackParent: null,
        inputHash: 'hash_backend',
      ),
    );
    await db.insertFoodVariant(
      const FoodVariantRecord(
        foodVariantId: 'food_without_crosswalk',
        foodConceptId: 'FOOD_TEST',
        jurisdiction: 'US',
        sourceFamily: 'FDC',
        sourceFoodCode: '123',
        displayNameLocal: 'Food without crosswalk',
        isAuthoritativeForRegion: true,
        isAuthoritativeFallback: false,
        status: 'active',
        fallbackChainJson: '[]',
      ),
    );
    await db.insertSnapshotDistribution(
      SnapshotDistributionRecord(
        distributionId: 'dist_web',
        snapshotId: 'snap_backend_warning',
        channel: 'web',
        distributionType: 'publish',
        status: 'completed_inline_fallback',
        artifactPath: 'inline://dist_web',
        manifestJson: jsonEncode({
          'durable': false,
          'backend_capabilities': {
            'backend': 'shared_preferences_web',
            'transactional': false,
          },
        }),
        errorMessage: null,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1100),
        completedAt: DateTime.fromMillisecondsSinceEpoch(1200),
      ),
    );

    final readiness =
        await service.validateReleaseCandidate('snap_backend_warning');
    expect(readiness.missingCrosswalkCount, 1);
    expect(readiness.issueCounts['missing_crosswalk_for_active_variants'], 1);
    expect(readiness.fallbackVariantResolutionWarningCount, 1);
    expect(readiness.missingCrosswalkSampleIds,
        contains('food_without_crosswalk'));
    expect(readiness.openReviewTicketCount, 1);
    expect(readiness.reviewTicketSummaries.single['reason_code'],
        'missing_crosswalk_for_active_variant');
    expect(readiness.blockingReasonSummary,
        contains('missing_crosswalk_for_active_variants'));
    expect(readiness.blockingReasonSummary,
        contains('open_high_severity_review_tickets'));
    expect(readiness.warnings,
        contains('legacy_variant_string_fallback_required'));
    expect(readiness.warnings, contains('backend_non_transactional_history'));
    expect(readiness.warnings, contains('backend_lightweight_web_storage'));
    expect(readiness.warnings, contains('fallback_region_jurisdiction_map'));
    expect(
        readiness.warningSummary, contains('backend_lightweight_web_storage'));
    expect(readiness.artifactDurabilityStatus, 'non_durable_fallback');
    expect(readiness.issueCounts['fallback_region_jurisdiction_map'], 1);
    expect(readiness.backendCapabilityWarnings,
        contains('backend_non_transactional_history'));
    final drill = await service.runReleaseReadinessDrill(
      snapshotId: 'snap_backend_warning',
      overrideReason: 'operator accepted web fallback for smoke drill',
    );
    expect(drill.openReviewTicketCount, 1);
    expect(drill.openHighSeverityReviewTicketCount, 1);
    expect(drill.sampleReviewTicketIds, isNotEmpty);
    expect(drill.warningSummary, contains('backend_lightweight_web_storage'));
    expect(drill.artifactDurabilityStatus, 'non_durable_fallback');
    expect(drill.toJson()['blocking_reason_summary'],
        contains('missing_crosswalk_for_active_variants'));
    expect(drill.toJson()['warning_summary'],
        contains('backend_lightweight_web_storage'));
    expect(drill.humanReadableSummary,
        contains('Artifact durability: non_durable_fallback'));
    expect(
        drill.humanReadableSummary,
        contains(
            'Override reason: operator accepted web fallback for smoke drill'));
  });

  test('production candidate readiness reports stale rule versions', () async {
    final db = _BundleRecordingDb();
    final service = KnowledgeBaseReleaseService(
      database: db,
      cdssService: ClinicalDecisionSupportService(
        database: db,
        factConflictEngine: FactConflictEngine(),
        runtimeRuleEngine: RuntimeRuleEngine(),
      ),
    );
    await db.insertEngineSnapshot(
      EngineSnapshotRecord(
        snapshotId: 'snap_stale_rules',
        factsVersion: 'facts_v1',
        rulesVersion: 'rules_v2',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
        promotedAt: DateTime.fromMillisecondsSinceEpoch(1000),
        rollbackParent: null,
        inputHash: 'hash_stale',
      ),
    );
    await db.insertRuleRegistry({
      'rule_id': 'rule_stale',
      'rule_version': 'rules_v1',
      'status': 'active',
      'rule_type': 'soft_rule',
      'priority_band': 1,
      'specificity_band': 1,
      'jurisdiction_json': '["GLOBAL"]',
      'applies_to_json': '{"subject_types":["drug"]}',
      'predicate_json': '{"exists":{"path":"drug.id"}}',
      'effect_json':
          '{"decision":"INFO","severity":"low","messages":{"zh":"v1"},"actions":[],"output_tags":[]}',
      'provenance_json':
          '{"evidence_level":"official_label","source_refs":["doc_1"]}',
      'updated_at': 1000,
    });

    final readiness =
        await service.validateReleaseCandidate('snap_stale_rules');
    expect(readiness.readinessProfile, 'production_candidate');
    expect(readiness.staleRuleVersionCount, 1);
    expect(readiness.warnings, contains('stale_rule_versions'));
    expect(readiness.issueCounts['stale_rule_versions'], 1);
  });

  test('production candidate readiness creates review tickets for conflicts',
      () async {
    final db = _BundleRecordingDb();
    final service = KnowledgeBaseReleaseService(
      database: db,
      cdssService: ClinicalDecisionSupportService(
        database: db,
        factConflictEngine: FactConflictEngine(),
        runtimeRuleEngine: RuntimeRuleEngine(),
      ),
    );
    await db.insertEngineSnapshot(
      EngineSnapshotRecord(
        snapshotId: 'snap_conflict',
        factsVersion: 'facts_v1',
        rulesVersion: 'rules_v1',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
        promotedAt: DateTime.fromMillisecondsSinceEpoch(1000),
        rollbackParent: null,
        inputHash: 'hash_conflict',
      ),
    );
    await db.insertConflictAuditLog(
      ConflictAuditLogRecord(
        auditId: 'audit_conflict',
        snapshotId: 'snap_conflict',
        runId: 'run_conflict',
        auditType: 'FACT_CLUSTER_RESOLUTION',
        target: 'food|banana|protein_g',
        decision: 'auto_resolved',
        winningRuleIdsJson: '["obs_1"]',
        suppressedRuleIdsJson: '["obs_2"]',
        sourceDocRefsJson: '["doc_1","doc_2"]',
        inputHash: 'hash',
        decisionReason: '{"needs_human_review":true}',
        machineActionsJson: '[]',
        humanMessage: 'Conflict requires review',
        needsHumanReview: true,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1100),
      ),
    );

    final readiness = await service.validateReleaseCandidate('snap_conflict');

    expect(readiness.blockingIssues, contains('unresolved_conflicts'));
    expect(readiness.blockingIssues,
        contains('open_high_severity_review_tickets'));
    expect(readiness.openReviewTicketCount, 1);
    expect(readiness.reviewTicketSummaries.single['target_type'],
        'FACT_CLUSTER_RESOLUTION');
    final ticket = (await db.queryTable('human_review_ticket')).single;
    expect(ticket['reason_code'], 'unresolved_conflict');
    expect(ticket['source_doc_refs_json'], contains('doc_1'));
  });

  test(
      'snapshot bundle import rejects invalid backend bundle before materialize',
      () async {
    final db = _BundleRecordingDb();
    final service = KnowledgeBaseReleaseService(
      database: db,
      cdssService: ClinicalDecisionSupportService(
        database: db,
        factConflictEngine: FactConflictEngine(),
        runtimeRuleEngine: RuntimeRuleEngine(),
      ),
    );

    final tempDir =
        await Directory.systemTemp.createTemp('parkinsum_bad_bundle_');
    final bundleFile = File('${tempDir.path}/bad.snapshot.bundle.json');
    await bundleFile.writeAsString(
      jsonEncode({
        'manifest': {
          'snapshot_id': 'snap_bad',
          'rules_version': 'rules_v1',
          'facts_version': 'snap_bad',
          'fact_count': 1,
          'source_document_count': 1,
          'rule_count': 1,
          'release_readiness': {
            'is_ready': true,
            'blocking_issues': const <String>[],
          },
        },
        'snapshot': {
          'snapshot_id': 'snap_bad',
          'facts_version': 'snap_bad',
          'rules_version': 'rules_v1',
          'created_at': 1000,
          'promoted_at': null,
          'rollback_parent': null,
          'input_hash': 'hash_bad',
        },
        'source_document': const <Map<String, Object?>>[],
        'observation': const <Map<String, Object?>>[],
        'resolved_fact': [
          {
            'fact_id': 'fact_bad',
            'entity_key': 'FOOD_BAD',
            'attribute_code': 'protein_g',
            'scope_hash': 'scope_bad',
            'resolution_status': 'resolved',
            'chosen_observation_id': 'obs_missing',
            'qualifier_kind': 'exact',
            'resolved_low': 1.0,
            'resolved_high': 1.0,
            'value_num': 1.0,
            'raw_value_text': '1.0',
            'resolved_unit': 'g',
            'resolution_policy_id': 'policy_1',
            'snapshot_id': 'snap_bad',
            'fact_version': 'snap_bad',
            'manual_override': 0,
          }
        ],
        'rule_registry': [
          {
            'rule_id': 'rule_1',
            'rule_version': '1.0.0',
            'status': 'active',
          }
        ],
      }),
    );

    await expectLater(
      service.importSnapshotBundle(filePath: bundleFile.path),
      throwsStateError,
    );
    expect(await db.queryTable('engine_snapshot'), isEmpty);
    expect(await db.queryTable('resolved_fact'), isEmpty);

    final runs = await db.queryTable('ingestion_run');
    expect(runs, hasLength(1));
    expect(runs.single['status'], 'failed');
    expect(
        '${runs.single['notes_json']}', contains('missing_source_documents'));

    final distributions = await db.queryTable('snapshot_distribution');
    expect(distributions, hasLength(1));
    expect(distributions.single['status'], 'failed');
    expect('${distributions.single['manifest_json']}',
        contains('missing_source_documents'));

    await tempDir.delete(recursive: true);
  });
}
