import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/cdss_records.dart';
import '../services/auth_service.dart';
import '../services/firebase_backend.dart';
import '../services/firebase_user_data_paths.dart';
import 'cdss_database.dart';

/// Firestore implementation of the CDSS database seam.
///
/// Layout:
/// users/{uid}/cdss_tables/{table}/rows/{primary_key}
///
/// This deliberately mirrors the local table names instead of inventing a new
/// domain API while keeping every user's remote CDSS knowledge/audit copy
/// isolated under their Firebase Auth uid.
class FirestoreCdssDatabase implements CdssDatabase {
  final AuthService authService;
  final FirebaseFirestore? _providedFirestore;
  final bool allowWrites;

  FirestoreCdssDatabase({
    required this.authService,
    FirebaseFirestore? firestore,
    this.allowWrites = false,
  }) : _providedFirestore = firestore;

  FirebaseFirestore get firestore =>
      _providedFirestore ?? FirebaseFirestore.instance;

  Future<CollectionReference<Map<String, dynamic>>> _rows(String table) async {
    await FirebaseBackend.ensureInitialized();
    final uid = authService.currentUserId;
    if (uid == null) {
      throw StateError('Firebase user is not signed in.');
    }
    return firestore.collection(FirebaseUserDataPaths(uid).cdssRowsCollection(
      table,
    ));
  }

  Future<void> _upsert(
    String table,
    String id,
    Map<String, Object?> row,
  ) async {
    if (!allowWrites) return;
    await (await _rows(table)).doc(id).set({
      ...row,
      '_synced_at': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> initialize() => FirebaseBackend.ensureInitialized();

  @override
  Future<void> clearStagingRun(String runId) async {
    if (!allowWrites) return;
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
      final rows = await _rows(table);
      final snapshot = await rows.where('run_id', isEqualTo: runId).get();
      final batch = firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  @override
  Future<void> insertConflictAuditLog(ConflictAuditLogRecord record) {
    return _upsert('conflict_audit_log', record.auditId, {
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

  Future<void> insertHumanReviewTicket(HumanReviewTicketRecord record) {
    return _upsert('human_review_ticket', record.ticketId, {
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
  }

  @override
  Future<void> insertCountryDietProfile(CountryDietProfileRecord record) {
    return _upsert('country_diet_profile', record.countryCode, {
      'country_code': record.countryCode,
      'guideline_source': record.guidelineSource,
      'meal_pattern_json': record.mealPatternJson,
      'staple_foods_json': record.stapleFoodsJson,
      'preferred_protein_sources_json': record.preferredProteinSourcesJson,
      'avoidance_notes_json': record.avoidanceNotesJson,
    });
  }

  @override
  Future<void> insertDrugConcept(DrugConceptRecord record) {
    return _upsert('drug_concept', record.drugConceptId, {
      'drug_concept_id': record.drugConceptId,
      'generic_name': record.genericName,
      'atc_like_code': record.atcLikeCode,
    });
  }

  @override
  Future<void> insertDrugLabelSection(DrugLabelSectionRecord record) {
    return _upsert('drug_label_section', record.sectionId, {
      'section_id': record.sectionId,
      'drug_product_variant_id': record.drugProductVariantId,
      'source_doc_id': record.sourceDocId,
      'section_key': record.sectionKey,
      'section_title': record.sectionTitle,
      'section_text': record.sectionText,
    });
  }

  @override
  Future<void> insertDrugProductCode(DrugProductCodeRecord record) {
    return _upsert('drug_product_code', record.productCodeId, {
      'product_code_id': record.productCodeId,
      'drug_product_variant_id': record.drugProductVariantId,
      'source_doc_id': record.sourceDocId,
      'code_system': record.codeSystem,
      'code_value': record.codeValue,
      'display_text': record.displayText,
    });
  }

  @override
  Future<void> insertDrugProductMedia(DrugProductMediaRecord record) {
    return _upsert('drug_product_media', record.mediaId, {
      'media_id': record.mediaId,
      'drug_product_variant_id': record.drugProductVariantId,
      'source_doc_id': record.sourceDocId,
      'media_type': record.mediaType,
      'media_url': record.mediaUrl,
      'caption': record.caption,
    });
  }

  @override
  Future<void> insertDrugProductPackaging(
    DrugProductPackagingRecord record,
  ) {
    return _upsert('drug_product_packaging', record.packagingId, {
      'packaging_id': record.packagingId,
      'drug_product_variant_id': record.drugProductVariantId,
      'source_doc_id': record.sourceDocId,
      'package_code': record.packageCode,
      'description': record.description,
      'marketing_status': record.marketingStatus,
    });
  }

  @override
  Future<void> insertDrugProductVariant(DrugProductVariantRecord record) {
    return _upsert('drug_product_variant', record.drugProductVariantId, {
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
  Future<void> insertEngineSnapshot(EngineSnapshotRecord record) {
    return _upsert('engine_snapshot', record.snapshotId, {
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
  Future<void> insertFoodConcept(FoodConceptRecord record) {
    return _upsert('food_concept', record.foodConceptId, {
      'food_concept_id': record.foodConceptId,
      'canonical_name_en': record.canonicalNameEn,
      'canonical_name_zh': record.canonicalNameZh,
      'food_group': record.foodGroup,
    });
  }

  @override
  Future<void> insertFoodVariant(FoodVariantRecord record) {
    return _upsert('food_variant', record.foodVariantId, {
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
  }

  @override
  Future<void> insertIngestionRun(IngestionRunRecord record) {
    return _upsert('ingestion_run', record.runId, {
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
  Future<void> insertLocaleResourceBundle(LocaleResourceBundleRecord record) {
    return _upsert(
      'locale_resource_bundle',
      '${record.localeTag}_${record.namespace}_${record.key}',
      {
        'locale_tag': record.localeTag,
        'namespace': record.namespace,
        'key': record.key,
        'text': record.text,
        'plural_rule': record.pluralRule,
      },
    );
  }

  @override
  Future<void> insertMealTemplate(MealTemplateRecord record) {
    return _upsert('meal_template', record.mealTemplateId, {
      'meal_template_id': record.mealTemplateId,
      'country_code': record.countryCode,
      'meal_slot': record.mealSlot,
      'template_json': record.templateJson,
      'texture_level': record.textureLevel,
    });
  }

  @override
  Future<void> insertObservation(ObservationRecord record) {
    final value = record.value;
    return _upsert('observation', record.observationId, {
      'observation_id': record.observationId,
      'domain': record.domain,
      'entity_type': record.entityType,
      'entity_key': record.entityKey,
      'attribute_code': record.attributeCode,
      'value_type': record.valueType,
      'qualifier_kind': value.qualifierKind.wireValue,
      'low': value.low,
      'high': value.high,
      'value_num': value.valueNum,
      'raw_value_text': value.rawValueText,
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
    RecommendationAuditLogRecord record,
  ) {
    return _upsert('recommendation_audit_log', record.recAuditId, {
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
  }

  @override
  Future<void> insertRegionJurisdictionMap(
    RegionJurisdictionMapRecord record,
  ) {
    return _upsert('region_jurisdiction_map', record.regionCode, {
      'region_code': record.regionCode,
      'jurisdiction_chain_json': record.jurisdictionChainJson,
      'food_source_priority_json': record.foodSourcePriorityJson,
      'drug_source_priority_json': record.drugSourcePriorityJson,
      'diet_guideline_source': record.dietGuidelineSource,
    });
  }

  @override
  Future<void> insertResolvedFact(ResolvedFactRecord record) async {
    final value = record.resolvedValue;
    final row = {
      'fact_id': record.factId,
      'entity_key': record.entityKey,
      'attribute_code': record.attributeCode,
      'scope_hash': record.scopeHash,
      'resolution_status': record.resolutionStatus,
      'chosen_observation_id': record.chosenObservationId,
      'qualifier_kind': value.qualifierKind.wireValue,
      'resolved_low': value.low,
      'resolved_high': value.high,
      'value_num': value.valueNum,
      'raw_value_text': value.rawValueText,
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
    return _upsert('resolved_fact', record.factId, row);
  }

  @override
  Future<void> insertRuleRegistry(Map<String, dynamic> row) async {
    final recordId =
        '${row['rule_id'] ?? row['compiled_hash'] ?? jsonEncode(row).hashCode}';
    await _appendHistory(
      tableName: 'rule_registry',
      recordId: recordId,
      versionId:
          '${row['rule_version'] ?? row['compiled_hash'] ?? DateTime.now().microsecondsSinceEpoch}',
      row: row,
      importRunId: row['import_run_id']?.toString(),
      effectiveAt: (row['updated_at'] as num?)?.toInt(),
    );
    return _upsert('rule_registry', recordId, row);
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
    await _appendHistory(
      tableName: 'runtime_event',
      recordId: record.eventId,
      versionId: '${record.createdAt.microsecondsSinceEpoch}',
      row: row,
      snapshotId: record.snapshotId,
    );
    return _upsert('runtime_event', record.eventId, row);
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
    await _appendHistory(
      tableName: 'snapshot_distribution',
      recordId: record.distributionId,
      versionId: '${record.createdAt.microsecondsSinceEpoch}',
      row: row,
      snapshotId: record.snapshotId,
    );
    return _upsert('snapshot_distribution', record.distributionId, row);
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
    final now = DateTime.now().millisecondsSinceEpoch;
    final historyId = '$tableName:$recordId:$versionId:$now';
    final historyRows = await _rows('cdss_record_history');
    final activeHistory = await historyRows
        .where('table_name', isEqualTo: tableName)
        .where('record_id', isEqualTo: recordId)
        .where('retired_at', isNull: true)
        .get();
    final batch = firestore.batch();
    for (final doc in activeHistory.docs) {
      batch.update(doc.reference, {
        'superseded_by': historyId,
        'retired_at': now,
        '_synced_at': FieldValue.serverTimestamp(),
      });
    }
    if (activeHistory.docs.isNotEmpty) {
      await batch.commit();
    }
    await _upsert('cdss_record_history', historyId, {
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
  }

  @override
  Future<void> insertSourceDocument(SourceDocumentRecord record) {
    return _upsert('source_document', record.sourceDocId, {
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
  }

  @override
  Future<void> insertStagingRow(String table, Map<String, Object?> row) {
    final id = row['staging_id'] ??
        row['fact_id'] ??
        row['observation_id'] ??
        row['rule_id'] ??
        row['event_id'] ??
        row['ticket_id'];
    return _upsert(table, '$id', row);
  }

  @override
  Future<void> insertVariantScope(VariantScopeRecord record) {
    return _upsert('variant_scope', record.scopeHash, {
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
  Future<List<Map<String, Object?>>> queryTable(String table) async {
    final snapshot = await (await _rows(table)).get();
    return snapshot.docs
        .map((doc) => Map<String, Object?>.from(doc.data()))
        .toList(growable: false);
  }
}
