import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/cdss_records.dart';
import 'cdss_database.dart';

/// Web fallback database backed by SharedPreferences.
///
/// 当前状态说明：
/// - 这是为了 Flutter Web 先跑起来的兼容层，不是最终推荐的数据库实现。
/// - 它缺少 SQLite/Drift 的查询能力、约束能力和真正事务。
/// - resolved/rule/runtime/distribution 仍会写 cdss_record_history，
///   但这是轻量 JSON 阵列语义，不等价于 SQLite 事务。
/// - 因此更适合作为 demo / lightweight test backend，而不是最终生产持久层。
class WebCdssDatabase implements CdssDatabase {
  SharedPreferences? _prefs;
  static const _tables = [
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
    'staging_food_variant',
    'staging_drug_product_variant',
    'staging_variant_scope',
    'staging_observation',
    'staging_resolved_fact',
    'staging_rule_registry',
    'staging_runtime_event',
    'staging_concept_variant_crosswalk',
  ];

  Future<SharedPreferences> _ensure() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  String _key(String table) => 'cdss.$table';

  Future<List<Map<String, dynamic>>> _load(String table) async {
    final prefs = await _ensure();
    final raw = prefs.getString(_key(table));
    if (raw == null) return <Map<String, dynamic>>[];
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> _save(String table, List<Map<String, dynamic>> rows) async {
    final prefs = await _ensure();
    await prefs.setString(_key(table), jsonEncode(rows));
  }

  @override
  Future<void> initialize() async {
    final prefs = await _ensure();
    for (final table in _tables) {
      // 每张“表”都以 JSON 数组字符串存一份，便于在 Web 端维持统一接口。
      prefs.getString(_key(table)) ?? await prefs.setString(_key(table), '[]');
    }
  }

  @override
  Future<void> insertSourceDocument(SourceDocumentRecord record) async {
    final rows = await _load('source_document');
    // 通过 remove + add 模拟 replace/upsert；不具备数据库层事务与唯一约束语义。
    rows.removeWhere(
      (existing) => existing['source_doc_id'] == record.sourceDocId,
    );
    rows.add({
      'source_doc_id': record.sourceDocId,
      'source_family': record.sourceFamily,
      'data_tier': record.dataTier,
      'ingestion_strategy': record.ingestionStrategy,
      'organization': record.organization,
      'doc_type': record.docType,
      'title': record.title,
      'jurisdiction': record.jurisdiction,
      'origin_url': record.originUrl,
      'published_at': record.publishedAt?.millisecondsSinceEpoch,
      'effective_at': record.effectiveAt?.millisecondsSinceEpoch,
      'language': record.language,
      'license_note': record.licenseNote,
      'checksum': record.checksum,
      'source_status': record.sourceStatus,
      'raw_payload': record.rawPayload,
    });
    await _save('source_document', rows);
  }

  @override
  Future<void> insertFoodConcept(FoodConceptRecord record) async {
    final rows = await _load('food_concept');
    rows.removeWhere(
      (existing) => existing['food_concept_id'] == record.foodConceptId,
    );
    rows.add({
      'food_concept_id': record.foodConceptId,
      'canonical_name_en': record.canonicalNameEn,
      'canonical_name_zh': record.canonicalNameZh,
      'food_group': record.foodGroup,
    });
    await _save('food_concept', rows);
  }

  @override
  Future<void> insertFoodVariant(FoodVariantRecord record) async {
    final rows = await _load('food_variant');
    rows.removeWhere(
      (existing) => existing['food_variant_id'] == record.foodVariantId,
    );
    rows.add({
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
    });
    await _save('food_variant', rows);
  }

  @override
  Future<void> insertDrugConcept(DrugConceptRecord record) async {
    final rows = await _load('drug_concept');
    rows.removeWhere(
      (existing) => existing['drug_concept_id'] == record.drugConceptId,
    );
    rows.add({
      'drug_concept_id': record.drugConceptId,
      'generic_name': record.genericName,
      'atc_like_code': record.atcLikeCode,
    });
    await _save('drug_concept', rows);
  }

  @override
  Future<void> insertDrugProductVariant(DrugProductVariantRecord record) async {
    final rows = await _load('drug_product_variant');
    rows.removeWhere(
      (existing) =>
          existing['drug_product_variant_id'] == record.drugProductVariantId,
    );
    rows.add({
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
    await _save('drug_product_variant', rows);
  }

  @override
  Future<void> insertDrugLabelSection(DrugLabelSectionRecord record) async {
    final rows = await _load('drug_label_section');
    rows.removeWhere((existing) => existing['section_id'] == record.sectionId);
    rows.add({
      'section_id': record.sectionId,
      'drug_product_variant_id': record.drugProductVariantId,
      'source_doc_id': record.sourceDocId,
      'section_key': record.sectionKey,
      'section_title': record.sectionTitle,
      'section_text': record.sectionText,
    });
    await _save('drug_label_section', rows);
  }

  @override
  Future<void> insertDrugProductCode(DrugProductCodeRecord record) async {
    final rows = await _load('drug_product_code');
    rows.removeWhere(
      (existing) => existing['product_code_id'] == record.productCodeId,
    );
    rows.add({
      'product_code_id': record.productCodeId,
      'drug_product_variant_id': record.drugProductVariantId,
      'source_doc_id': record.sourceDocId,
      'code_system': record.codeSystem,
      'code_value': record.codeValue,
      'display_text': record.displayText,
    });
    await _save('drug_product_code', rows);
  }

  @override
  Future<void> insertDrugProductPackaging(
      DrugProductPackagingRecord record) async {
    final rows = await _load('drug_product_packaging');
    rows.removeWhere(
        (existing) => existing['packaging_id'] == record.packagingId);
    rows.add({
      'packaging_id': record.packagingId,
      'drug_product_variant_id': record.drugProductVariantId,
      'source_doc_id': record.sourceDocId,
      'package_code': record.packageCode,
      'description': record.description,
      'marketing_status': record.marketingStatus,
    });
    await _save('drug_product_packaging', rows);
  }

  @override
  Future<void> insertDrugProductMedia(DrugProductMediaRecord record) async {
    final rows = await _load('drug_product_media');
    rows.removeWhere((existing) => existing['media_id'] == record.mediaId);
    rows.add({
      'media_id': record.mediaId,
      'drug_product_variant_id': record.drugProductVariantId,
      'source_doc_id': record.sourceDocId,
      'media_type': record.mediaType,
      'media_url': record.mediaUrl,
      'caption': record.caption,
    });
    await _save('drug_product_media', rows);
  }

  @override
  Future<void> insertObservation(ObservationRecord record) async {
    final rows = await _load('observation');
    // Web 端仍然保留 interval/qualifier 字段，避免把限定语降级成纯浮点数。
    rows.removeWhere(
      (existing) => existing['observation_id'] == record.observationId,
    );
    rows.add({
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
    await _save('observation', rows);
  }

  @override
  Future<void> insertVariantScope(VariantScopeRecord record) async {
    final rows = await _load('variant_scope');
    rows.removeWhere(
      (existing) => existing['scope_hash'] == record.scopeHash,
    );
    rows.add({
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
    await _save('variant_scope', rows);
  }

  @override
  Future<void> insertRegionJurisdictionMap(
      RegionJurisdictionMapRecord record) async {
    final rows = await _load('region_jurisdiction_map');
    rows.removeWhere(
        (existing) => existing['region_code'] == record.regionCode);
    rows.add({
      'region_code': record.regionCode,
      'jurisdiction_chain_json': record.jurisdictionChainJson,
      'food_source_priority_json': record.foodSourcePriorityJson,
      'drug_source_priority_json': record.drugSourcePriorityJson,
      'diet_guideline_source': record.dietGuidelineSource,
    });
    await _save('region_jurisdiction_map', rows);
  }

  @override
  Future<void> insertLocaleResourceBundle(
      LocaleResourceBundleRecord record) async {
    final rows = await _load('locale_resource_bundle');
    rows.removeWhere(
      (existing) =>
          existing['locale_tag'] == record.localeTag &&
          existing['namespace'] == record.namespace &&
          existing['key'] == record.key,
    );
    rows.add({
      'locale_tag': record.localeTag,
      'namespace': record.namespace,
      'key': record.key,
      'text': record.text,
      'plural_rule': record.pluralRule,
    });
    await _save('locale_resource_bundle', rows);
  }

  @override
  Future<void> insertCountryDietProfile(CountryDietProfileRecord record) async {
    final rows = await _load('country_diet_profile');
    rows.removeWhere(
      (existing) => existing['country_code'] == record.countryCode,
    );
    rows.add({
      'country_code': record.countryCode,
      'guideline_source': record.guidelineSource,
      'meal_pattern_json': record.mealPatternJson,
      'staple_foods_json': record.stapleFoodsJson,
      'preferred_protein_sources_json': record.preferredProteinSourcesJson,
      'avoidance_notes_json': record.avoidanceNotesJson,
    });
    await _save('country_diet_profile', rows);
  }

  @override
  Future<void> insertMealTemplate(MealTemplateRecord record) async {
    final rows = await _load('meal_template');
    rows.removeWhere(
      (existing) => existing['meal_template_id'] == record.mealTemplateId,
    );
    rows.add({
      'meal_template_id': record.mealTemplateId,
      'country_code': record.countryCode,
      'meal_slot': record.mealSlot,
      'template_json': record.templateJson,
      'texture_level': record.textureLevel,
    });
    await _save('meal_template', rows);
  }

  @override
  Future<void> insertResolvedFact(ResolvedFactRecord record) async {
    final rows = await _load('resolved_fact');
    rows.removeWhere(
      (existing) => existing['fact_id'] == record.factId,
    );
    final row = {
      'fact_id': record.factId,
      'entity_key': record.entityKey,
      'attribute_code': record.attributeCode,
      'scope_hash': record.scopeHash,
      'resolution_status': record.resolutionStatus,
      'chosen_observation_id': record.chosenObservationId,
      'qualifier_kind': record.resolvedValue.qualifierKind.wireValue,
      'resolved_low': record.resolvedValue.low,
      'resolved_high': record.resolvedValue.high,
      'value_num': record.resolvedValue.valueNum,
      'raw_value_text': record.resolvedValue.rawValueText,
      'resolved_unit': record.resolvedUnit,
      'resolution_policy_id': record.resolutionPolicyId,
      'snapshot_id': record.snapshotId,
      'fact_version': record.factVersion,
      'manual_override': record.manualOverride,
    };
    await _appendHistory(
      tableName: 'resolved_fact',
      recordId: record.factId,
      versionId: record.factVersion,
      row: row,
      snapshotId: record.snapshotId,
    );
    rows.add(row);
    await _save('resolved_fact', rows);
  }

  @override
  Future<void> insertRuleRegistry(Map<String, dynamic> row) async {
    final rows = await _load('rule_registry');
    rows.removeWhere((existing) => existing['rule_id'] == row['rule_id']);
    await _appendHistory(
      tableName: 'rule_registry',
      recordId: '${row['rule_id'] ?? row['compiled_hash'] ?? row.hashCode}',
      versionId:
          '${row['rule_version'] ?? row['compiled_hash'] ?? DateTime.now().microsecondsSinceEpoch}',
      row: row,
      importRunId: row['import_run_id']?.toString(),
      effectiveAt: (row['updated_at'] as num?)?.toInt(),
    );
    rows.add(row);
    await _save('rule_registry', rows);
  }

  @override
  Future<void> insertEngineSnapshot(EngineSnapshotRecord record) async {
    final rows = await _load('engine_snapshot');
    rows.add({
      'snapshot_id': record.snapshotId,
      'facts_version': record.factsVersion,
      'rules_version': record.rulesVersion,
      'created_at': record.createdAt.millisecondsSinceEpoch,
      'promoted_at': record.promotedAt?.millisecondsSinceEpoch,
      'rollback_parent': record.rollbackParent,
      'input_hash': record.inputHash,
    });
    await _save('engine_snapshot', rows);
  }

  @override
  Future<void> insertRuntimeEvent(RuntimeEventRecord record) async {
    final rows = await _load('runtime_event');
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
    await _appendHistory(
      tableName: 'runtime_event',
      recordId: record.eventId,
      versionId: '${record.createdAt.microsecondsSinceEpoch}',
      row: row,
      snapshotId: record.snapshotId,
    );
    rows.add(row);
    await _save('runtime_event', rows);
  }

  @override
  Future<void> insertConflictAuditLog(ConflictAuditLogRecord record) async {
    final rows = await _load('conflict_audit_log');
    rows.add({
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
    await _save('conflict_audit_log', rows);
  }

  Future<void> insertHumanReviewTicket(HumanReviewTicketRecord record) async {
    final rows = await _load('human_review_ticket');
    rows.removeWhere((existing) => existing['ticket_id'] == record.ticketId);
    rows.add({
      'ticket_id': record.ticketId,
      'reason_code': record.reasonCode,
      'severity': record.severity,
      'target_type': record.targetType,
      'target_id': record.targetId,
      'snapshot_id': record.snapshotId,
      'run_id': record.runId,
      'source_doc_refs_json': record.sourceDocRefsJson,
      'suggested_action': record.suggestedAction,
      'status': record.status,
      'created_at': record.createdAt.millisecondsSinceEpoch,
      'resolved_at': record.resolvedAt?.millisecondsSinceEpoch,
    });
    await _save('human_review_ticket', rows);
  }

  @override
  Future<void> insertRecommendationAuditLog(
      RecommendationAuditLogRecord record) async {
    final rows = await _load('recommendation_audit_log');
    rows.removeWhere(
      (existing) => existing['rec_audit_id'] == record.recAuditId,
    );
    rows.add({
      'rec_audit_id': record.recAuditId,
      'user_id': record.userId,
      'meal_slot': record.mealSlot,
      'snapshot_id': record.snapshotId,
      'jurisdiction_chain_json': record.jurisdictionChainJson,
      'meal_candidates_json': record.mealCandidatesJson,
      'rejected_by_rules_json': record.rejectedByRulesJson,
      'accepted_choices_json': record.acceptedChoicesJson,
      'score_breakdown_json': record.scoreBreakdownJson,
      'fallback_used': record.fallbackUsed,
      'created_at': record.createdAt.millisecondsSinceEpoch,
    });
    await _save('recommendation_audit_log', rows);
  }

  @override
  Future<void> insertIngestionRun(IngestionRunRecord record) async {
    final rows = await _load('ingestion_run');
    rows.removeWhere((existing) => existing['run_id'] == record.runId);
    rows.add({
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
    await _save('ingestion_run', rows);
  }

  @override
  Future<void> insertSnapshotDistribution(
      SnapshotDistributionRecord record) async {
    final rows = await _load('snapshot_distribution');
    rows.removeWhere(
        (existing) => existing['distribution_id'] == record.distributionId);
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
    await _appendHistory(
      tableName: 'snapshot_distribution',
      recordId: record.distributionId,
      versionId: '${record.createdAt.microsecondsSinceEpoch}',
      row: row,
      snapshotId: record.snapshotId,
    );
    rows.add(row);
    await _save('snapshot_distribution', rows);
  }

  Future<void> _appendHistory({
    required String tableName,
    required String recordId,
    required String versionId,
    required Map<String, Object?> row,
    String? importRunId,
    String? snapshotId,
    int? effectiveAt,
  }) async {
    final rows = await _load('cdss_record_history');
    final now = DateTime.now().millisecondsSinceEpoch;
    final historyId = '$tableName:$recordId:$versionId:$now';
    for (final existing in rows.where((item) =>
        item['table_name'] == tableName &&
        item['record_id'] == recordId &&
        item['retired_at'] == null)) {
      existing['superseded_by'] = historyId;
      existing['retired_at'] = now;
    }
    rows.add({
      'history_id': historyId,
      'table_name': tableName,
      'record_id': recordId,
      'version_id': versionId,
      'payload_json': jsonEncode(row),
      'superseded_by': null,
      'effective_at': effectiveAt ?? now,
      'retired_at': null,
      'import_run_id': importRunId,
      'snapshot_id': snapshotId ?? row['snapshot_id']?.toString(),
      'created_at': now,
    });
    await _save('cdss_record_history', rows);
  }

  @override
  Future<void> insertStagingRow(String table, Map<String, Object?> row) async {
    final rows = await _load(table);
    final idKey = row.keys.firstWhere(
      (key) => key.endsWith('_id'),
      orElse: () => 'staging_id',
    );
    rows.removeWhere((existing) => existing[idKey] == row[idKey]);
    rows.add(Map<String, dynamic>.from(row));
    await _save(table, rows);
  }

  @override
  Future<void> clearStagingRun(String runId) async {
    for (final table in const [
      'staging_food_variant',
      'staging_drug_product_variant',
      'staging_variant_scope',
      'staging_observation',
      'staging_resolved_fact',
      'staging_rule_registry',
      'staging_runtime_event',
      'staging_concept_variant_crosswalk',
    ]) {
      final rows = await _load(table);
      rows.removeWhere((row) => row['run_id'] == runId);
      await _save(table, rows);
    }
  }

  @override
  Future<List<Map<String, Object?>>> queryTable(String table) async {
    final rows = await _load(table);
    return rows.cast<Map<String, Object?>>();
  }
}

CdssDatabase createCdssDatabaseImpl() => WebCdssDatabase();
