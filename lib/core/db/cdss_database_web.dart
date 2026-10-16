import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/cdss_records.dart';
import 'cdss_database.dart';
import 'cdss_catalog_snapshot_reader.dart';
import '../services/origin_storage_coordination.dart';

/// Local Web catalogue state is committed as one storage document. Participating
/// writers hold an origin lock across reload, validation and the single write.
/// This is not SQLite, cloud synchronization or a clinical data backend.
class WebCdssDatabase
    implements CdssDatabase, CdssAtomicWriter, CdssCatalogSnapshotReader {
  WebCdssDatabase({this.stateWriter});

  /// Fault injection for rejected writes and lost acknowledgments.
  final Future<bool> Function(SharedPreferences, String, String)? stateWriter;
  SharedPreferences? _prefs;
  static const stateKey = 'cdss.atomic_state.v1';
  static const stateSchema = 'parkinsum.cdss-web-state/1';
  static final Object _writeZoneKey = Object();
  static Future<void>? _writeTail;

  Future<T> _serializeWrite<T>(Future<T> Function() action) async {
    final previous = _writeTail;
    final operation = previous == null
        ? Future<T>.sync(action)
        : previous.then((_) => action());
    final tail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _writeTail = tail;
    try {
      return await operation;
    } finally {
      // Retain the queue only while a participating write is still pending.
      if (identical(_writeTail, tail)) _writeTail = null;
    }
  }

  _WebCdssWrite? get _writeScope {
    final scope = Zone.current[_writeZoneKey];
    if (scope is! _WebCdssWrite || !identical(scope.owner, this)) return null;
    if (!scope.open) throw StateError('Catalogue transaction is closed.');
    return scope;
  }

  @override
  Future<T> runAtomicWrite<T>(Future<T> Function() action) async {
    final nested = _writeScope;
    if (nested != null) {
      try {
        return await action();
      } catch (_) {
        nested.aborted = true;
        rethrow;
      }
    }
    if (Zone.current[_writeZoneKey] is _WebCdssWrite) {
      throw StateError('A different catalogue backend owns this transaction.');
    }
    return _serializeWrite(
      () => withOriginStorageLock('cdss.catalogue', () async {
        final prefs = await _ensure();
        await prefs.reload();
        final before = prefs.getString(stateKey);
        final legacyBefore = before == null ? _legacyState(prefs) : null;
        final document = _decodeState(prefs, before);
        final scope = _WebCdssWrite(this, document);
        late T result;
        try {
          result = await runZoned(action, zoneValues: {_writeZoneKey: scope});
          if (scope.aborted) throw StateError('Catalogue transaction aborted.');
        } finally {
          scope.open = false;
        }
        if (!scope.changed) return result;
        document['revision'] = (document['revision'] as int) + 1;
        final candidate = jsonEncode(document);
        await prefs.reload();
        if (prefs.getString(stateKey) != before) {
          throw StateError('Catalogue changed before commit.');
        }
        if (legacyBefore != null && _legacyState(prefs) != legacyBefore) {
          throw StateError('Legacy catalogue changed before migration.');
        }
        try {
          final saved = await (stateWriter == null
              ? prefs.setString(stateKey, candidate)
              : stateWriter!(prefs, stateKey, candidate));
          if (!saved) throw StateError('Catalogue storage rejected the write.');
        } catch (error, trace) {
          // The platform may commit and then lose its acknowledgment. Verify the
          // exact complete document before reporting success or allowing a retry.
          await prefs.reload();
          if (prefs.getString(stateKey) != candidate) {
            Error.throwWithStackTrace(error, trace);
          }
        }
        return result;
      }),
    );
  }

  Map<String, dynamic> _decodeState(SharedPreferences prefs, String? raw) {
    if (raw == null) {
      return {
        'schema': stateSchema,
        'revision': 0,
        'tables': <String, dynamic>{
          for (final table in {..._tables, ..._legacyTables(prefs)})
            table: _decodeRows(prefs.getString(_key(table))),
        },
      };
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map ||
        decoded['schema'] != stateSchema ||
        decoded['revision'] is! int ||
        (decoded['revision'] as int) < 0 ||
        decoded['tables'] is! Map) {
      throw const FormatException('Invalid catalogue state.');
    }
    final document = Map<String, dynamic>.from(decoded);
    final tables = Map<String, dynamic>.from(document['tables'] as Map);
    for (final entry in tables.entries) {
      requireValidCdssTableName(entry.key);
      if (entry.value is! List || (entry.value as List).any((r) => r is! Map)) {
        throw const FormatException('Invalid catalogue table.');
      }
    }
    if (!_tables.every(tables.containsKey)) {
      throw const FormatException('Incomplete catalogue state.');
    }
    document['tables'] = tables;
    return document;
  }

  Iterable<String> _legacyTables(SharedPreferences prefs) sync* {
    for (final key in prefs.getKeys()) {
      if (!key.startsWith('cdss.') || key == stateKey) continue;
      final table = key.substring(5);
      try {
        requireValidCdssTableName(table);
        yield table;
      } on ArgumentError {
        // Non-table metadata remains at its original key and is not deleted.
      }
    }
  }

  String _legacyState(SharedPreferences prefs) {
    final tables = _legacyTables(prefs).toList()..sort();
    return jsonEncode({
      for (final table in tables) table: prefs.getString(_key(table)),
    });
  }

  List<Map<String, dynamic>> _decodeRows(String? raw) => raw == null
      ? <Map<String, dynamic>>[]
      : (jsonDecode(raw) as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();

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
    final scope = _writeScope;
    Map<String, dynamic> document;
    if (scope != null) {
      document = scope.document;
    } else {
      final prefs = await _ensure();
      await prefs.reload();
      document = _decodeState(prefs, prefs.getString(stateKey));
    }
    final rows = (document['tables'] as Map)[table] as List? ?? const [];
    // No caller receives mutable references into the pending or committed state.
    return (jsonDecode(jsonEncode(rows)) as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  Future<void> _save(String table, List<Map<String, dynamic>> rows) async {
    final scope = _writeScope;
    if (scope == null) throw StateError('Catalogue write needs a transaction.');
    (scope.document['tables'] as Map)[table] = jsonDecode(jsonEncode(rows));
    scope.changed = true;
  }

  @override
  Future<CdssCatalogTableSnapshot> readFoodCatalogSnapshot() async {
    final scope = _writeScope;
    Map<String, dynamic> document;
    if (scope != null) {
      document = scope.document;
    } else {
      final prefs = await _ensure();
      await prefs.reload();
      final raw = prefs.getString(stateKey);
      // A legacy set of independent keys cannot prove a common read boundary.
      if (raw == null) {
        throw StateError('Atomic catalogue migration is required.');
      }
      document = _decodeState(prefs, raw);
    }
    final tables = document['tables'] as Map;
    return CdssCatalogTableSnapshot(
      rows: {
        for (final table in CdssCatalogTableSnapshot.tables)
          table: (tables[table] as List)
              .map((r) => Map<String, Object?>.from(r as Map))
              .toList(),
      },
      consistency: 'web_single_document',
    );
  }

  @override
  Future<void> initialize() async => _ensure();

  @override
  Future<void> insertSourceDocument(SourceDocumentRecord record) =>
      runAtomicWrite(() async {
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
      });

  @override
  Future<void> insertFoodConcept(FoodConceptRecord record) =>
      runAtomicWrite(() async {
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
      });

  @override
  Future<void> insertFoodVariant(FoodVariantRecord record) =>
      runAtomicWrite(() async {
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
      });

  @override
  Future<void> insertDrugConcept(DrugConceptRecord record) =>
      runAtomicWrite(() async {
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
      });

  @override
  Future<void> insertDrugProductVariant(DrugProductVariantRecord record) =>
      runAtomicWrite(() async {
        final rows = await _load('drug_product_variant');
        rows.removeWhere(
          (existing) =>
              existing['drug_product_variant_id'] ==
              record.drugProductVariantId,
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
      });

  @override
  Future<void> insertDrugLabelSection(DrugLabelSectionRecord record) =>
      runAtomicWrite(() async {
        final rows = await _load('drug_label_section');
        rows.removeWhere(
          (existing) => existing['section_id'] == record.sectionId,
        );
        rows.add({
          'section_id': record.sectionId,
          'drug_product_variant_id': record.drugProductVariantId,
          'source_doc_id': record.sourceDocId,
          'section_key': record.sectionKey,
          'section_title': record.sectionTitle,
          'section_text': record.sectionText,
        });
        await _save('drug_label_section', rows);
      });

  @override
  Future<void> insertDrugProductCode(DrugProductCodeRecord record) =>
      runAtomicWrite(() async {
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
      });

  @override
  Future<void> insertDrugProductPackaging(DrugProductPackagingRecord record) =>
      runAtomicWrite(() async {
        final rows = await _load('drug_product_packaging');
        rows.removeWhere(
          (existing) => existing['packaging_id'] == record.packagingId,
        );
        rows.add({
          'packaging_id': record.packagingId,
          'drug_product_variant_id': record.drugProductVariantId,
          'source_doc_id': record.sourceDocId,
          'package_code': record.packageCode,
          'description': record.description,
          'marketing_status': record.marketingStatus,
        });
        await _save('drug_product_packaging', rows);
      });

  @override
  Future<void> insertDrugProductMedia(DrugProductMediaRecord record) =>
      runAtomicWrite(() async {
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
      });

  @override
  Future<void> insertObservation(ObservationRecord record) =>
      runAtomicWrite(() async {
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
      });

  @override
  Future<void> insertVariantScope(VariantScopeRecord record) =>
      runAtomicWrite(() async {
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
      });

  @override
  Future<void> insertRegionJurisdictionMap(
    RegionJurisdictionMapRecord record,
  ) => runAtomicWrite(() async {
    final rows = await _load('region_jurisdiction_map');
    rows.removeWhere(
      (existing) => existing['region_code'] == record.regionCode,
    );
    rows.add({
      'region_code': record.regionCode,
      'jurisdiction_chain_json': record.jurisdictionChainJson,
      'food_source_priority_json': record.foodSourcePriorityJson,
      'drug_source_priority_json': record.drugSourcePriorityJson,
      'diet_guideline_source': record.dietGuidelineSource,
    });
    await _save('region_jurisdiction_map', rows);
  });

  @override
  Future<void> insertLocaleResourceBundle(LocaleResourceBundleRecord record) =>
      runAtomicWrite(() async {
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
      });

  @override
  Future<void> insertCountryDietProfile(CountryDietProfileRecord record) =>
      runAtomicWrite(() async {
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
      });

  @override
  Future<void> insertMealTemplate(MealTemplateRecord record) =>
      runAtomicWrite(() async {
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
      });

  @override
  Future<void> insertResolvedFact(ResolvedFactRecord record) =>
      runAtomicWrite(() async {
        final rows = await _load('resolved_fact');
        rows.removeWhere((existing) => existing['fact_id'] == record.factId);
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
      });

  @override
  Future<void> insertRuleRegistry(
    Map<String, dynamic> row,
  ) => runAtomicWrite(() async {
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
  });

  @override
  Future<void> insertEngineSnapshot(EngineSnapshotRecord record) =>
      runAtomicWrite(() async {
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
      });

  @override
  Future<void> insertRuntimeEvent(RuntimeEventRecord record) =>
      runAtomicWrite(() async {
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
      });

  @override
  Future<void> insertConflictAuditLog(ConflictAuditLogRecord record) =>
      runAtomicWrite(() async {
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
      });

  Future<void> insertHumanReviewTicket(HumanReviewTicketRecord record) =>
      runAtomicWrite(() async {
        final rows = await _load('human_review_ticket');
        rows.removeWhere(
          (existing) => existing['ticket_id'] == record.ticketId,
        );
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
      });

  @override
  Future<void> insertRecommendationAuditLog(
    RecommendationAuditLogRecord record,
  ) => runAtomicWrite(() async {
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
  });

  @override
  Future<void> insertIngestionRun(IngestionRunRecord record) =>
      runAtomicWrite(() async {
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
      });

  @override
  Future<void> insertSnapshotDistribution(SnapshotDistributionRecord record) =>
      runAtomicWrite(() async {
        final rows = await _load('snapshot_distribution');
        rows.removeWhere(
          (existing) => existing['distribution_id'] == record.distributionId,
        );
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
      });

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
    final effectiveSnapshot = snapshotId ?? row['snapshot_id']?.toString();
    final active = rows
        .where(
          (item) =>
              item['table_name'] == tableName &&
              item['record_id'] == recordId &&
              item['retired_at'] == null,
        )
        .toList();
    // A restart is not a source revision. Preserve existing history verbatim
    // when both content and its explicitly supplied provenance are unchanged.
    if (active.length == 1) {
      final existing = active.single;
      final oldPayload = jsonDecode(existing['payload_json'] as String);
      if (existing['version_id'] == versionId &&
          existing['import_run_id'] == importRunId &&
          existing['snapshot_id'] == effectiveSnapshot &&
          (effectiveAt == null || existing['effective_at'] == effectiveAt) &&
          _orderedPayload(oldPayload as Map) == _orderedPayload(row)) {
        return;
      }
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final baseId = '$tableName:$recordId:$versionId:$now';
    var historyId = baseId;
    var collision = 0;
    while (rows.any((item) => item['history_id'] == historyId)) {
      historyId = '$baseId:${++collision}';
    }
    for (final existing in rows.where(
      (item) =>
          item['table_name'] == tableName &&
          item['record_id'] == recordId &&
          item['retired_at'] == null,
    )) {
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
      'snapshot_id': effectiveSnapshot,
      'created_at': now,
    });
    await _save('cdss_record_history', rows);
  }

  String _orderedPayload(Map row) {
    final keys = row.keys.cast<String>().toList()..sort();
    return jsonEncode({for (final key in keys) key: row[key]});
  }

  @override
  Future<void> insertStagingRow(String table, Map<String, Object?> row) =>
      runAtomicWrite(() async {
        requireValidCdssTableName(table);
        final rows = await _load(table);
        final idKey = row.keys.firstWhere(
          (key) => key.endsWith('_id'),
          orElse: () => 'staging_id',
        );
        rows.removeWhere((existing) => existing[idKey] == row[idKey]);
        rows.add(Map<String, dynamic>.from(row));
        await _save(table, rows);
      });

  @override
  Future<void> clearStagingRun(String runId) => runAtomicWrite(() async {
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
  });

  @override
  Future<List<Map<String, Object?>>> queryTable(String table) async {
    requireValidCdssTableName(table);
    final rows = await _load(table);
    return rows.cast<Map<String, Object?>>();
  }
}

final class _WebCdssWrite {
  _WebCdssWrite(this.owner, this.document);
  final WebCdssDatabase owner;
  final Map<String, dynamic> document;
  bool open = true;
  bool changed = false;
  bool aborted = false;
}

CdssDatabase createCdssDatabaseImpl() => WebCdssDatabase();
