import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../domain/entities/cdss_records.dart';
import 'cdss_database.dart';

/// Native SQLite-backed implementation used by mobile/desktop runtimes.
///
/// 当前状态说明：
/// - 结构上已经覆盖 source / observation / resolved fact / rule / snapshot / audit。
/// - 但 schema 仍是当前 Flutter 侧的第一版实现，不等于设计书最终数据库。
/// - onUpgrade 覆盖当前增量表；更复杂的数据迁移仍应按版本继续追加。
class NativeCdssDatabase implements CdssDatabase {
  Database? _db;
  static const _schemaVersion = 9;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final base = await getDatabasesPath();
    final path = p.join(base, 'parkinsum_cdss.db');
    _db = await openDatabase(
      path,
      version: _schemaVersion,
      onCreate: (db, version) async {
        // source_document: 保存原始来源元数据，供审计与回放使用。
        await db.execute(
          'CREATE TABLE source_document (source_doc_id TEXT PRIMARY KEY, source_family TEXT NOT NULL, data_tier TEXT NOT NULL, ingestion_strategy TEXT NOT NULL, organization TEXT NOT NULL, jurisdiction TEXT NOT NULL, doc_type TEXT NOT NULL, title TEXT NOT NULL, origin_url TEXT NOT NULL, published_at INTEGER, effective_at INTEGER, language TEXT NOT NULL, license_note TEXT NOT NULL, checksum TEXT NOT NULL, source_status TEXT NOT NULL, raw_payload TEXT NOT NULL)',
        );
        // food/drug concept + variant: 允许同一概念在多辖区、多来源下并存。
        await db.execute(
          'CREATE TABLE food_concept (food_concept_id TEXT PRIMARY KEY, canonical_name_en TEXT NOT NULL, canonical_name_zh TEXT NOT NULL, food_group TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE food_variant (food_variant_id TEXT PRIMARY KEY, food_concept_id TEXT NOT NULL, jurisdiction TEXT NOT NULL, source_family TEXT NOT NULL, source_food_code TEXT, display_name_local TEXT NOT NULL, is_authoritative_for_region INTEGER NOT NULL, is_authoritative_fallback INTEGER NOT NULL, status TEXT NOT NULL, fallback_chain_json TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE drug_concept (drug_concept_id TEXT PRIMARY KEY, generic_name TEXT NOT NULL, atc_like_code TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE drug_product_variant (drug_product_variant_id TEXT PRIMARY KEY, drug_concept_id TEXT NOT NULL, jurisdiction TEXT NOT NULL, regulator TEXT NOT NULL, external_product_code TEXT NOT NULL, route TEXT NOT NULL, dosage_form TEXT NOT NULL, release_type TEXT NOT NULL, label_version TEXT NOT NULL, source_status TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE drug_label_section (section_id TEXT PRIMARY KEY, drug_product_variant_id TEXT NOT NULL, source_doc_id TEXT NOT NULL, section_key TEXT NOT NULL, section_title TEXT NOT NULL, section_text TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE drug_product_code (product_code_id TEXT PRIMARY KEY, drug_product_variant_id TEXT NOT NULL, source_doc_id TEXT NOT NULL, code_system TEXT NOT NULL, code_value TEXT NOT NULL, display_text TEXT)',
        );
        await db.execute(
          'CREATE TABLE drug_product_packaging (packaging_id TEXT PRIMARY KEY, drug_product_variant_id TEXT NOT NULL, source_doc_id TEXT NOT NULL, package_code TEXT, description TEXT NOT NULL, marketing_status TEXT)',
        );
        await db.execute(
          'CREATE TABLE drug_product_media (media_id TEXT PRIMARY KEY, drug_product_variant_id TEXT NOT NULL, source_doc_id TEXT NOT NULL, media_type TEXT NOT NULL, media_url TEXT NOT NULL, caption TEXT)',
        );
        await db.execute(
          'CREATE TABLE concept_variant_crosswalk (crosswalk_id TEXT PRIMARY KEY, domain TEXT NOT NULL, app_entity_id TEXT NOT NULL, concept_id TEXT NOT NULL, variant_id TEXT NOT NULL, external_id_system TEXT NOT NULL, external_id_value TEXT NOT NULL, jurisdiction TEXT NOT NULL, source_doc_id TEXT NOT NULL, import_run_id TEXT, confidence REAL NOT NULL, status TEXT NOT NULL, mapping_payload_json TEXT NOT NULL, created_at INTEGER NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE observation (observation_id TEXT PRIMARY KEY, domain TEXT NOT NULL, entity_type TEXT NOT NULL, entity_key TEXT NOT NULL, attribute_code TEXT NOT NULL, value_type TEXT NOT NULL, value_num REAL, low REAL, high REAL, qualifier_kind TEXT NOT NULL, raw_value_text TEXT NOT NULL, unit TEXT NOT NULL, basis_type TEXT NOT NULL, basis_amount REAL, scope_hash TEXT NOT NULL, source_doc_id TEXT NOT NULL, record_locator TEXT NOT NULL, method_code TEXT, extraction_confidence REAL NOT NULL)',
        );
        // variant_scope / resolved_fact 是 observation 之上的解析层；原始 observation 永不覆盖为单值事实。
        await db.execute(
          'CREATE TABLE variant_scope (scope_hash TEXT PRIMARY KEY, jurisdiction TEXT NOT NULL, brand TEXT, dosage_form TEXT, release_type TEXT, salt_form TEXT, route TEXT, preparation_state TEXT, cooking_state TEXT, plant_part TEXT, cultivar TEXT, sampling_frame TEXT)',
        );
        await db.execute(
          'CREATE TABLE resolved_fact (fact_id TEXT PRIMARY KEY, entity_key TEXT NOT NULL, attribute_code TEXT NOT NULL, scope_hash TEXT NOT NULL, resolution_status TEXT NOT NULL, chosen_observation_id TEXT NOT NULL, resolved_low REAL, resolved_high REAL, qualifier_kind TEXT NOT NULL, value_num REAL, raw_value_text TEXT NOT NULL, resolved_unit TEXT NOT NULL, resolution_policy_id TEXT NOT NULL, snapshot_id TEXT NOT NULL, fact_version TEXT NOT NULL, manual_override INTEGER NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE rule_registry (rule_id TEXT PRIMARY KEY, rule_version TEXT NOT NULL, status TEXT NOT NULL, rule_type TEXT NOT NULL, priority_band INTEGER NOT NULL, specificity_band INTEGER NOT NULL, jurisdiction_json TEXT NOT NULL, applies_to_json TEXT NOT NULL, predicate_json TEXT NOT NULL, effect_json TEXT NOT NULL, provenance_json TEXT NOT NULL, override_json TEXT, compiled_hash TEXT NOT NULL, updated_at INTEGER NOT NULL)',
        );
        // runtime_event / conflict_audit_log / engine_snapshot 用于回放每次执行的输入、输出与采用的快照。
        await db.execute(
          'CREATE TABLE runtime_event (event_id TEXT PRIMARY KEY, patient_id TEXT NOT NULL, event_type TEXT NOT NULL, snapshot_id TEXT NOT NULL, context_json TEXT NOT NULL, machine_readable_json TEXT NOT NULL, human_readable_markdown TEXT NOT NULL, jurisdiction TEXT NOT NULL, timezone TEXT NOT NULL, created_at INTEGER NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE conflict_audit_log (audit_id TEXT PRIMARY KEY, snapshot_id TEXT NOT NULL, run_id TEXT NOT NULL, audit_type TEXT NOT NULL, target TEXT NOT NULL, decision TEXT NOT NULL, winning_rule_ids_json TEXT NOT NULL, suppressed_rule_ids_json TEXT NOT NULL, source_doc_refs_json TEXT NOT NULL, input_hash TEXT NOT NULL, decision_reason TEXT NOT NULL, machine_actions_json TEXT NOT NULL, human_message TEXT NOT NULL, needs_human_review INTEGER NOT NULL, created_at INTEGER NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE human_review_ticket (ticket_id TEXT PRIMARY KEY, reason_code TEXT NOT NULL, severity TEXT NOT NULL, target_type TEXT NOT NULL, target_id TEXT NOT NULL, snapshot_id TEXT NOT NULL, run_id TEXT, source_doc_refs_json TEXT NOT NULL, suggested_action TEXT NOT NULL, status TEXT NOT NULL, created_at INTEGER NOT NULL, resolved_at INTEGER)',
        );
        await db.execute(
          'CREATE TABLE engine_snapshot (snapshot_id TEXT PRIMARY KEY, facts_version TEXT NOT NULL, rules_version TEXT NOT NULL, created_at INTEGER NOT NULL, promoted_at INTEGER, rollback_parent TEXT, input_hash TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE user_profile (user_id TEXT PRIMARY KEY, registration_region TEXT NOT NULL, display_locale TEXT NOT NULL, content_jurisdiction_override_json TEXT NOT NULL, diet_profile_region TEXT, timezone TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE region_jurisdiction_map (region_code TEXT PRIMARY KEY, jurisdiction_chain_json TEXT NOT NULL, food_source_priority_json TEXT NOT NULL, drug_source_priority_json TEXT NOT NULL, diet_guideline_source TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE locale_resource_bundle (locale_tag TEXT NOT NULL, namespace TEXT NOT NULL, key TEXT NOT NULL, text TEXT NOT NULL, plural_rule TEXT, PRIMARY KEY (locale_tag, namespace, key))',
        );
        await db.execute(
          'CREATE TABLE country_diet_profile (country_code TEXT PRIMARY KEY, guideline_source TEXT NOT NULL, meal_pattern_json TEXT NOT NULL, staple_foods_json TEXT NOT NULL, preferred_protein_sources_json TEXT NOT NULL, avoidance_notes_json TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE meal_template (meal_template_id TEXT PRIMARY KEY, country_code TEXT NOT NULL, meal_slot TEXT NOT NULL, template_json TEXT NOT NULL, texture_level TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE recommendation_audit_log (rec_audit_id TEXT PRIMARY KEY, user_id TEXT NOT NULL, meal_slot TEXT NOT NULL, snapshot_id TEXT NOT NULL, jurisdiction_chain_json TEXT NOT NULL, meal_candidates_json TEXT NOT NULL, rejected_by_rules_json TEXT NOT NULL, accepted_choices_json TEXT NOT NULL, score_breakdown_json TEXT NOT NULL, fallback_used INTEGER NOT NULL, created_at INTEGER NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE ingestion_run (run_id TEXT PRIMARY KEY, source_family TEXT NOT NULL, stage TEXT NOT NULL, status TEXT NOT NULL, snapshot_id TEXT NOT NULL, parent_snapshot_id TEXT, notes_json TEXT NOT NULL, created_at INTEGER NOT NULL, completed_at INTEGER)',
        );
        await db.execute(
          'CREATE TABLE snapshot_distribution (distribution_id TEXT PRIMARY KEY, snapshot_id TEXT NOT NULL, channel TEXT NOT NULL, distribution_type TEXT NOT NULL, status TEXT NOT NULL, artifact_path TEXT, manifest_json TEXT NOT NULL, error_message TEXT, created_at INTEGER NOT NULL, completed_at INTEGER)',
        );
        await db.execute(
          'CREATE TABLE cdss_record_history (history_id TEXT PRIMARY KEY, table_name TEXT NOT NULL, record_id TEXT NOT NULL, version_id TEXT NOT NULL, payload_json TEXT NOT NULL, superseded_by TEXT, effective_at INTEGER, retired_at INTEGER, import_run_id TEXT, snapshot_id TEXT, created_at INTEGER NOT NULL)',
        );
        // staging_*：把批量导入的变体、观测和解析事实先写入物理 staging 分区，
        // 再由 promote 步骤复制到正式表，避免“导入即发布”。
        await db.execute(
          'CREATE TABLE staging_food_variant (staging_id TEXT PRIMARY KEY, run_id TEXT NOT NULL, food_variant_id TEXT NOT NULL, payload_json TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE staging_drug_product_variant (staging_id TEXT PRIMARY KEY, run_id TEXT NOT NULL, drug_product_variant_id TEXT NOT NULL, payload_json TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE staging_variant_scope (staging_id TEXT PRIMARY KEY, run_id TEXT NOT NULL, scope_hash TEXT NOT NULL, payload_json TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE staging_observation (staging_id TEXT PRIMARY KEY, run_id TEXT NOT NULL, observation_id TEXT NOT NULL, payload_json TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE staging_resolved_fact (staging_id TEXT PRIMARY KEY, run_id TEXT NOT NULL, fact_id TEXT NOT NULL, payload_json TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE staging_rule_registry (staging_id TEXT PRIMARY KEY, run_id TEXT NOT NULL, rule_id TEXT NOT NULL, payload_json TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE staging_runtime_event (staging_id TEXT PRIMARY KEY, run_id TEXT NOT NULL, event_id TEXT NOT NULL, payload_json TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE staging_concept_variant_crosswalk (staging_id TEXT PRIMARY KEY, run_id TEXT NOT NULL, crosswalk_id TEXT NOT NULL, payload_json TEXT NOT NULL)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // 二期补齐药品子表与导入会话审计，避免旧库停留在“只有主表”的状态。
          await db.execute(
            'CREATE TABLE IF NOT EXISTS drug_label_section (section_id TEXT PRIMARY KEY, drug_product_variant_id TEXT NOT NULL, source_doc_id TEXT NOT NULL, section_key TEXT NOT NULL, section_title TEXT NOT NULL, section_text TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE IF NOT EXISTS drug_product_code (product_code_id TEXT PRIMARY KEY, drug_product_variant_id TEXT NOT NULL, source_doc_id TEXT NOT NULL, code_system TEXT NOT NULL, code_value TEXT NOT NULL, display_text TEXT)',
          );
          await db.execute(
            'CREATE TABLE IF NOT EXISTS drug_product_packaging (packaging_id TEXT PRIMARY KEY, drug_product_variant_id TEXT NOT NULL, source_doc_id TEXT NOT NULL, package_code TEXT, description TEXT NOT NULL, marketing_status TEXT)',
          );
          await db.execute(
            'CREATE TABLE IF NOT EXISTS drug_product_media (media_id TEXT PRIMARY KEY, drug_product_variant_id TEXT NOT NULL, source_doc_id TEXT NOT NULL, media_type TEXT NOT NULL, media_url TEXT NOT NULL, caption TEXT)',
          );
          await db.execute(
            'CREATE TABLE IF NOT EXISTS ingestion_run (run_id TEXT PRIMARY KEY, source_family TEXT NOT NULL, stage TEXT NOT NULL, status TEXT NOT NULL, snapshot_id TEXT NOT NULL, parent_snapshot_id TEXT, notes_json TEXT NOT NULL, created_at INTEGER NOT NULL, completed_at INTEGER)',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS staging_food_variant (staging_id TEXT PRIMARY KEY, run_id TEXT NOT NULL, food_variant_id TEXT NOT NULL, payload_json TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE IF NOT EXISTS staging_drug_product_variant (staging_id TEXT PRIMARY KEY, run_id TEXT NOT NULL, drug_product_variant_id TEXT NOT NULL, payload_json TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE IF NOT EXISTS staging_variant_scope (staging_id TEXT PRIMARY KEY, run_id TEXT NOT NULL, scope_hash TEXT NOT NULL, payload_json TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE IF NOT EXISTS staging_observation (staging_id TEXT PRIMARY KEY, run_id TEXT NOT NULL, observation_id TEXT NOT NULL, payload_json TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE IF NOT EXISTS staging_resolved_fact (staging_id TEXT PRIMARY KEY, run_id TEXT NOT NULL, fact_id TEXT NOT NULL, payload_json TEXT NOT NULL)',
          );
        }
        if (oldVersion < 4) {
          await db.execute(
            "ALTER TABLE source_document ADD COLUMN data_tier TEXT NOT NULL DEFAULT 'P0'",
          );
          await db.execute(
            "ALTER TABLE source_document ADD COLUMN ingestion_strategy TEXT NOT NULL DEFAULT 'authoritative_direct'",
          );
        }
        if (oldVersion < 5) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS snapshot_distribution (distribution_id TEXT PRIMARY KEY, snapshot_id TEXT NOT NULL, channel TEXT NOT NULL, distribution_type TEXT NOT NULL, status TEXT NOT NULL, artifact_path TEXT, manifest_json TEXT NOT NULL, error_message TEXT, created_at INTEGER NOT NULL, completed_at INTEGER)',
          );
        }
        if (oldVersion < 6) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS staging_rule_registry (staging_id TEXT PRIMARY KEY, run_id TEXT NOT NULL, rule_id TEXT NOT NULL, payload_json TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE IF NOT EXISTS staging_runtime_event (staging_id TEXT PRIMARY KEY, run_id TEXT NOT NULL, event_id TEXT NOT NULL, payload_json TEXT NOT NULL)',
          );
        }
        if (oldVersion < 7) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS concept_variant_crosswalk (crosswalk_id TEXT PRIMARY KEY, domain TEXT NOT NULL, app_entity_id TEXT NOT NULL, concept_id TEXT NOT NULL, variant_id TEXT NOT NULL, external_id_system TEXT NOT NULL, external_id_value TEXT NOT NULL, jurisdiction TEXT NOT NULL, source_doc_id TEXT NOT NULL, import_run_id TEXT, confidence REAL NOT NULL, status TEXT NOT NULL, mapping_payload_json TEXT NOT NULL, created_at INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE IF NOT EXISTS staging_concept_variant_crosswalk (staging_id TEXT PRIMARY KEY, run_id TEXT NOT NULL, crosswalk_id TEXT NOT NULL, payload_json TEXT NOT NULL)',
          );
        }
        if (oldVersion < 8) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS cdss_record_history (history_id TEXT PRIMARY KEY, table_name TEXT NOT NULL, record_id TEXT NOT NULL, version_id TEXT NOT NULL, payload_json TEXT NOT NULL, superseded_by TEXT, effective_at INTEGER, retired_at INTEGER, import_run_id TEXT, snapshot_id TEXT, created_at INTEGER NOT NULL)',
          );
        }
        if (oldVersion < 9) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS human_review_ticket (ticket_id TEXT PRIMARY KEY, reason_code TEXT NOT NULL, severity TEXT NOT NULL, target_type TEXT NOT NULL, target_id TEXT NOT NULL, snapshot_id TEXT NOT NULL, run_id TEXT, source_doc_refs_json TEXT NOT NULL, suggested_action TEXT NOT NULL, status TEXT NOT NULL, created_at INTEGER NOT NULL, resolved_at INTEGER)',
          );
        }
      },
    );
    return _db!;
  }

  @override
  Future<void> initialize() => _open();

  @override
  Future<void> insertSourceDocument(SourceDocumentRecord record) async {
    final db = await _open();
    await db.insert(
      'source_document',
      {
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
      },
      // source_document 仍是当前投影；版本化治理集中在 resolved/rule/runtime/distribution。
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertFoodConcept(FoodConceptRecord record) async {
    final db = await _open();
    await db.insert(
      'food_concept',
      {
        'food_concept_id': record.foodConceptId,
        'canonical_name_en': record.canonicalNameEn,
        'canonical_name_zh': record.canonicalNameZh,
        'food_group': record.foodGroup,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertFoodVariant(FoodVariantRecord record) async {
    final db = await _open();
    await db.insert(
      'food_variant',
      {
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
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertDrugConcept(DrugConceptRecord record) async {
    final db = await _open();
    await db.insert(
      'drug_concept',
      {
        'drug_concept_id': record.drugConceptId,
        'generic_name': record.genericName,
        'atc_like_code': record.atcLikeCode,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertDrugProductVariant(DrugProductVariantRecord record) async {
    final db = await _open();
    await db.insert(
      'drug_product_variant',
      {
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
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertDrugLabelSection(DrugLabelSectionRecord record) async {
    final db = await _open();
    await db.insert(
      'drug_label_section',
      {
        'section_id': record.sectionId,
        'drug_product_variant_id': record.drugProductVariantId,
        'source_doc_id': record.sourceDocId,
        'section_key': record.sectionKey,
        'section_title': record.sectionTitle,
        'section_text': record.sectionText,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertDrugProductCode(DrugProductCodeRecord record) async {
    final db = await _open();
    await db.insert(
      'drug_product_code',
      {
        'product_code_id': record.productCodeId,
        'drug_product_variant_id': record.drugProductVariantId,
        'source_doc_id': record.sourceDocId,
        'code_system': record.codeSystem,
        'code_value': record.codeValue,
        'display_text': record.displayText,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertDrugProductPackaging(
      DrugProductPackagingRecord record) async {
    final db = await _open();
    await db.insert(
      'drug_product_packaging',
      {
        'packaging_id': record.packagingId,
        'drug_product_variant_id': record.drugProductVariantId,
        'source_doc_id': record.sourceDocId,
        'package_code': record.packageCode,
        'description': record.description,
        'marketing_status': record.marketingStatus,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertDrugProductMedia(DrugProductMediaRecord record) async {
    final db = await _open();
    await db.insert(
      'drug_product_media',
      {
        'media_id': record.mediaId,
        'drug_product_variant_id': record.drugProductVariantId,
        'source_doc_id': record.sourceDocId,
        'media_type': record.mediaType,
        'media_url': record.mediaUrl,
        'caption': record.caption,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertObservation(ObservationRecord record) async {
    final db = await _open();
    final value = record.value;
    await db.insert(
      'observation',
      {
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
      },
      // 当前仍允许用相同主键替换，便于测试和重复初始化。
      // 这不代表 observation 语义上可变；真正不可变性要靠 observation_id/versioning 设计保证。
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertVariantScope(VariantScopeRecord record) async {
    final db = await _open();
    await db.insert(
      'variant_scope',
      {
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
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertRegionJurisdictionMap(
      RegionJurisdictionMapRecord record) async {
    final db = await _open();
    await db.insert(
      'region_jurisdiction_map',
      {
        'region_code': record.regionCode,
        'jurisdiction_chain_json': record.jurisdictionChainJson,
        'food_source_priority_json': record.foodSourcePriorityJson,
        'drug_source_priority_json': record.drugSourcePriorityJson,
        'diet_guideline_source': record.dietGuidelineSource,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertLocaleResourceBundle(
      LocaleResourceBundleRecord record) async {
    final db = await _open();
    await db.insert(
      'locale_resource_bundle',
      {
        'locale_tag': record.localeTag,
        'namespace': record.namespace,
        'key': record.key,
        'text': record.text,
        'plural_rule': record.pluralRule,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertCountryDietProfile(CountryDietProfileRecord record) async {
    final db = await _open();
    await db.insert(
      'country_diet_profile',
      {
        'country_code': record.countryCode,
        'guideline_source': record.guidelineSource,
        'meal_pattern_json': record.mealPatternJson,
        'staple_foods_json': record.stapleFoodsJson,
        'preferred_protein_sources_json': record.preferredProteinSourcesJson,
        'avoidance_notes_json': record.avoidanceNotesJson,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertMealTemplate(MealTemplateRecord record) async {
    final db = await _open();
    await db.insert(
      'meal_template',
      {
        'meal_template_id': record.mealTemplateId,
        'country_code': record.countryCode,
        'meal_slot': record.mealSlot,
        'template_json': record.templateJson,
        'texture_level': record.textureLevel,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertResolvedFact(ResolvedFactRecord record) async {
    final db = await _open();
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
      'manual_override': record.manualOverride ? 1 : 0,
    };
    await _insertVersionHistory(
      db,
      tableName: 'resolved_fact',
      recordId: record.factId,
      versionId: record.factVersion,
      row: row,
      snapshotId: record.snapshotId,
      effectiveAt: DateTime.now().millisecondsSinceEpoch,
    );
    await db.insert(
      'resolved_fact',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertRuleRegistry(Map<String, dynamic> row) async {
    final db = await _open();
    final ruleId = '${row['rule_id'] ?? row['compiled_hash'] ?? row.hashCode}';
    final version = '${row['rule_version'] ?? row['compiled_hash'] ?? ''}';
    await _insertVersionHistory(
      db,
      tableName: 'rule_registry',
      recordId: ruleId,
      versionId: version.isEmpty
          ? '${DateTime.now().microsecondsSinceEpoch}'
          : version,
      row: row,
      importRunId: row['import_run_id']?.toString(),
      effectiveAt: (row['updated_at'] as num?)?.toInt(),
    );
    await db.insert('rule_registry', row,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> insertEngineSnapshot(EngineSnapshotRecord record) async {
    final db = await _open();
    await db.insert('engine_snapshot', {
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
  Future<void> insertRuntimeEvent(RuntimeEventRecord record) async {
    final db = await _open();
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
    await _insertVersionHistory(
      db,
      tableName: 'runtime_event',
      recordId: record.eventId,
      versionId: '${record.createdAt.microsecondsSinceEpoch}',
      row: row,
      snapshotId: record.snapshotId,
      effectiveAt: record.createdAt.millisecondsSinceEpoch,
    );
    await db.insert('runtime_event', row);
  }

  @override
  Future<void> insertConflictAuditLog(ConflictAuditLogRecord record) async {
    final db = await _open();
    await db.insert('conflict_audit_log', {
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

  Future<void> insertHumanReviewTicket(HumanReviewTicketRecord record) async {
    final db = await _open();
    await db.insert(
      'human_review_ticket',
      {
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
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertRecommendationAuditLog(
      RecommendationAuditLogRecord record) async {
    final db = await _open();
    await db.insert(
      'recommendation_audit_log',
      {
        'rec_audit_id': record.recAuditId,
        'user_id': record.userId,
        'meal_slot': record.mealSlot,
        'snapshot_id': record.snapshotId,
        'jurisdiction_chain_json': record.jurisdictionChainJson,
        'meal_candidates_json': record.mealCandidatesJson,
        'rejected_by_rules_json': record.rejectedByRulesJson,
        'accepted_choices_json': record.acceptedChoicesJson,
        'score_breakdown_json': record.scoreBreakdownJson,
        'fallback_used': record.fallbackUsed ? 1 : 0,
        'created_at': record.createdAt.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertIngestionRun(IngestionRunRecord record) async {
    final db = await _open();
    await db.insert(
      'ingestion_run',
      {
        'run_id': record.runId,
        'source_family': record.sourceFamily,
        'stage': record.stage,
        'status': record.status,
        'snapshot_id': record.snapshotId,
        'parent_snapshot_id': record.parentSnapshotId,
        'notes_json': record.notesJson,
        'created_at': record.createdAt.millisecondsSinceEpoch,
        'completed_at': record.completedAt?.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertSnapshotDistribution(
      SnapshotDistributionRecord record) async {
    final db = await _open();
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
    await _insertVersionHistory(
      db,
      tableName: 'snapshot_distribution',
      recordId: record.distributionId,
      versionId: '${record.createdAt.microsecondsSinceEpoch}',
      row: row,
      snapshotId: record.snapshotId,
      effectiveAt: record.createdAt.millisecondsSinceEpoch,
    );
    await db.insert(
      'snapshot_distribution',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _insertVersionHistory(
    Database db, {
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
    await db.update(
      'cdss_record_history',
      {'superseded_by': historyId, 'retired_at': now},
      where: 'table_name = ? AND record_id = ? AND retired_at IS NULL',
      whereArgs: [tableName, recordId],
    );
    await db.insert(
      'cdss_record_history',
      {
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
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertStagingRow(String table, Map<String, Object?> row) async {
    final db = await _open();
    await db.insert(
      table,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> clearStagingRun(String runId) async {
    final db = await _open();
    await db.delete('staging_food_variant',
        where: 'run_id = ?', whereArgs: [runId]);
    await db.delete('staging_drug_product_variant',
        where: 'run_id = ?', whereArgs: [runId]);
    await db.delete('staging_variant_scope',
        where: 'run_id = ?', whereArgs: [runId]);
    await db
        .delete('staging_observation', where: 'run_id = ?', whereArgs: [runId]);
    await db.delete('staging_resolved_fact',
        where: 'run_id = ?', whereArgs: [runId]);
    await db.delete('staging_rule_registry',
        where: 'run_id = ?', whereArgs: [runId]);
    await db.delete('staging_runtime_event',
        where: 'run_id = ?', whereArgs: [runId]);
    await db.delete('staging_concept_variant_crosswalk',
        where: 'run_id = ?', whereArgs: [runId]);
  }

  @override
  Future<List<Map<String, Object?>>> queryTable(String table) async {
    final db = await _open();
    return db.query(table);
  }
}

CdssDatabase createCdssDatabaseImpl() => NativeCdssDatabase();
