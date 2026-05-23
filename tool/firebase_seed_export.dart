import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/core/analysis/food_repository.dart';
import 'package:parkinsum_companion/core/analysis/medication_repository.dart';
import 'package:parkinsum_companion/core/constants/baseline_cdss_rules.dart';
import 'package:parkinsum_companion/core/constants/clinical_evidence_source_seed.dart';
import 'package:parkinsum_companion/core/constants/p0_food_source_seed.dart';
import 'package:parkinsum_companion/core/constants/regional_master_data.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/data/models/interaction_rule_record.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';
import 'package:parkinsum_companion/domain/entities/rule_registry_models.dart';
import 'package:parkinsum_companion/domain/usecases/rule_registry_compiler.dart';

const _rulesVersion = 'baseline_cdss_rules_v1';
const _factsVersion = 'p0_food_knowledge_seed_v1';
const _snapshotId = 'firebase_seed_p0_core_v1';

void main(List<String> args) {
  final positionalArgs =
      args.where((arg) => !arg.startsWith('--')).toList(growable: false);
  final outputPath = positionalArgs.isEmpty
      ? 'build/firebase_seed/official_core_seed.json'
      : positionalArgs.first;
  final projectId = _argValue(args, '--project=') ??
      Platform.environment['PARKINSUM_FIREBASE_PROJECT_ID'] ??
      'parkinsum-companion';
  final databaseId = _argValue(args, '--database-id=') ?? '(default)';
  final userUid = _argValue(args, '--user-uid=') ??
      Platform.environment['PARKINSUM_FIREBASE_SEED_UID'];
  final docs = <Map<String, dynamic>>[];
  final counts = <String, int>{};

  void addDoc(String path, Map<String, dynamic> data) {
    final table = path.split('/').take(2).join('/');
    counts[table] = (counts[table] ?? 0) + 1;
    docs.add({
      'path': _safeDocumentPath(path),
      'data': {
        ...data,
        '_seed_snapshot_id': _snapshotId,
        '_seed_source': 'tool/firebase_seed_export.dart',
      },
    });
  }

  void addCdss(String table, String id, Map<String, dynamic> data) {
    if (userUid == null || userUid.trim().isEmpty) {
      throw ArgumentError(
        'CDSS Firestore seed export now requires --user-uid=<firebase uid> '
        'or PARKINSUM_FIREBASE_SEED_UID so cdss_tables are user-scoped.',
      );
    }
    addDoc(
      'users/${_safePathSegment(userUid)}/cdss_tables/$table/rows/$id',
      data,
    );
  }

  void addCatalog(String table, String id, Map<String, dynamic> data) {
    addDoc('app_catalog/$table/rows/$id', data);
  }

  final foodRepo = FoodRepository.createDefault();
  final medRepo = MedicationRepository.createDefault();
  final p0 = buildP0FoodKnowledgeBaseSeed();
  final compiledRules = RuleRegistryCompiler().compileJsonList(
    baselineCdssRules,
    rulesVersion: _rulesVersion,
  );

  for (final food in foodRepo.allFoods) {
    addCatalog('foods', food.id, food.toJson());
  }
  for (final drug in medRepo.allDrugs) {
    addCatalog('medications', drug.id, drug.toJson());
  }
  for (final rule in _defaultInteractionRules()) {
    addCatalog('interaction_rules', rule.id, rule.toJson());
  }

  final sourceDocs = <String, SourceDocumentRecord>{
    for (final source in p0.sourceDocuments) source.sourceDocId: source,
    for (final source in clinicalEvidenceSourceDocuments)
      source.sourceDocId: source,
  }.values;
  for (final record in sourceDocs) {
    addCdss('source_document', record.sourceDocId, _sourceDocument(record));
  }

  for (final record in regionalJurisdictionMapSeed) {
    addCdss('region_jurisdiction_map', record.regionCode, {
      'region_code': record.regionCode,
      'jurisdiction_chain_json': record.jurisdictionChainJson,
      'food_source_priority_json': record.foodSourcePriorityJson,
      'drug_source_priority_json': record.drugSourcePriorityJson,
      'diet_guideline_source': record.dietGuidelineSource,
    });
  }
  for (final record in localeResourceBundleSeed) {
    addCdss(
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
  for (final record in countryDietProfileSeed) {
    addCdss('country_diet_profile', record.countryCode, {
      'country_code': record.countryCode,
      'guideline_source': record.guidelineSource,
      'meal_pattern_json': record.mealPatternJson,
      'staple_foods_json': record.stapleFoodsJson,
      'preferred_protein_sources_json': record.preferredProteinSourcesJson,
      'avoidance_notes_json': record.avoidanceNotesJson,
    });
  }
  for (final record in mealTemplateSeed) {
    addCdss('meal_template', record.mealTemplateId, {
      'meal_template_id': record.mealTemplateId,
      'country_code': record.countryCode,
      'meal_slot': record.mealSlot,
      'template_json': record.templateJson,
      'texture_level': record.textureLevel,
    });
  }

  final foodConcepts = [
    ..._buildFoodConcepts(foodRepo.allFoods),
    ...p0.foodConcepts,
  ];
  final foodVariants = [
    ..._buildFoodVariants(foodRepo.allFoods),
    ...p0.foodVariants,
  ];
  for (final record in foodConcepts) {
    addCdss('food_concept', record.foodConceptId, {
      'food_concept_id': record.foodConceptId,
      'canonical_name_en': record.canonicalNameEn,
      'canonical_name_zh': record.canonicalNameZh,
      'food_group': record.foodGroup,
    });
  }
  for (final record in foodVariants) {
    addCdss('food_variant', record.foodVariantId, {
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

  for (final record in _buildDrugConcepts(medRepo.allDrugs)) {
    addCdss('drug_concept', record.drugConceptId, {
      'drug_concept_id': record.drugConceptId,
      'generic_name': record.genericName,
      'atc_like_code': record.atcLikeCode,
    });
  }
  for (final record in _buildDrugVariants(medRepo.allDrugs)) {
    addCdss('drug_product_variant', record.drugProductVariantId, {
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

  for (final record in p0.variantScopes) {
    addCdss('variant_scope', record.scopeHash, {
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
  for (final record in p0.observations) {
    final value = record.value;
    addCdss('observation', record.observationId, {
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
  for (final record in p0.resolvedFacts) {
    final value = record.resolvedValue;
    addCdss('resolved_fact', record.factId, {
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
    });
  }

  for (final rule in compiledRules) {
    addCdss('rule_registry', rule.ruleId, _ruleRegistryRow(rule));
  }

  final now = DateTime.now().toUtc();
  addCdss('engine_snapshot', _snapshotId, {
    'snapshot_id': _snapshotId,
    'facts_version': _factsVersion,
    'rules_version': _rulesVersion,
    'created_at': now.millisecondsSinceEpoch,
    'promoted_at': now.millisecondsSinceEpoch,
    'rollback_parent': null,
    'input_hash': base64Url.encode(utf8.encode(jsonEncode(counts))),
  });
  addCdss('ingestion_run', 'ingest_$_snapshotId', {
    'run_id': 'ingest_$_snapshotId',
    'source_family': 'P0_OFFICIAL_SEED',
    'stage': 'firebase_seed',
    'status': 'completed',
    'snapshot_id': _snapshotId,
    'parent_snapshot_id': null,
    'notes_json': jsonEncode({
      'purpose':
          'Seed default Firestore with updateable official catalog/CDSS rows.',
      'counts': counts,
    }),
    'created_at': now.millisecondsSinceEpoch,
    'completed_at': now.millisecondsSinceEpoch,
  });

  final output = File(outputPath);
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'projectId': projectId,
      'databaseId': databaseId,
      'snapshotId': _snapshotId,
      'generatedAt': now.toIso8601String(),
      'documentCount': docs.length,
      'counts': counts,
      'documents': docs,
    }),
  );

  stdout.writeln('Wrote $outputPath');
  stdout.writeln('documents=${docs.length}');
  stdout.writeln(jsonEncode(counts));
}

Map<String, dynamic> _sourceDocument(SourceDocumentRecord record) => {
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
    };

Map<String, dynamic> _ruleRegistryRow(RuleRegistryEntry rule) => {
      'rule_id': rule.ruleId,
      'rule_version': _rulesVersion,
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
      'updated_at': rule.provenance.effectiveFrom?.millisecondsSinceEpoch ?? 0,
    };

List<InteractionRuleRecord> _defaultInteractionRules() {
  return const [
    InteractionRuleRecord(
      id: 'rule_levodopa_protein',
      drugId: 'drug_levodopa_carbidopa',
      ruleType: 'protein_timing',
      target: 'protein',
      severity: 2,
      weight: 0.8,
      description: '高蛋白与左旋多巴同时段时可能影响吸收。',
    ),
    InteractionRuleRecord(
      id: 'rule_maoi_tyramine',
      drugId: 'drug_selegiline',
      ruleType: 'tyramine',
      target: 'high_tyramine',
      severity: 3,
      weight: 1.0,
      description: '高酪胺食物与 MAOI 同期需谨慎。',
    ),
    InteractionRuleRecord(
      id: 'rule_mineral_dairy',
      drugId: 'drug_iron',
      ruleType: 'mineral_timing',
      target: 'dairy',
      severity: 1,
      weight: 0.5,
      description: '矿物质补充剂与乳制品时间窗口需注意。',
    ),
  ];
}

List<FoodConceptRecord> _buildFoodConcepts(List<FoodItem> foods) {
  return foods
      .map(
        (food) => FoodConceptRecord(
          foodConceptId: 'FOOD_${food.id.toUpperCase()}',
          canonicalNameEn:
              food.aliases.isEmpty ? food.name : food.aliases.first,
          canonicalNameZh: food.name,
          foodGroup: food.category.name,
        ),
      )
      .toList(growable: false);
}

List<FoodVariantRecord> _buildFoodVariants(List<FoodItem> foods) {
  return foods
      .map(
        (food) => FoodVariantRecord(
          foodVariantId:
              'FOOD_${food.id.toUpperCase()}#${food.jurisdiction.toUpperCase()}#${food.sourceSystem.toUpperCase()}#${food.sourceFoodCode ?? food.id}',
          foodConceptId: 'FOOD_${food.id.toUpperCase()}',
          jurisdiction: food.jurisdiction,
          sourceFamily: food.sourceSystem,
          sourceFoodCode: food.sourceFoodCode ?? food.id,
          displayNameLocal: food.name,
          isAuthoritativeForRegion: food.sourceSystem != 'LOCAL_SEED',
          isAuthoritativeFallback: food.sourceSystem == 'LOCAL_SEED',
          status: 'seeded_catalog_variant',
          fallbackChainJson: jsonEncode([food.jurisdiction, 'GLOBAL']),
        ),
      )
      .toList(growable: false);
}

List<DrugConceptRecord> _buildDrugConcepts(List<DrugDefinition> drugs) {
  return drugs
      .map(
        (drug) => DrugConceptRecord(
          drugConceptId: 'DRUG_${drug.id.toUpperCase()}',
          genericName: drug.genericName,
          atcLikeCode: drug.tags.map((tag) => tag.name).join('_'),
        ),
      )
      .toList(growable: false);
}

List<DrugProductVariantRecord> _buildDrugVariants(List<DrugDefinition> drugs) {
  return drugs
      .map(
        (drug) => DrugProductVariantRecord(
          drugProductVariantId:
              'DRUG_${drug.id.toUpperCase()}#${drug.jurisdiction.toUpperCase()}#${drug.sourceSystem.toUpperCase()}#${drug.sourceProductCode ?? drug.id}',
          drugConceptId: 'DRUG_${drug.id.toUpperCase()}',
          jurisdiction: drug.jurisdiction,
          regulator: drug.sourceSystem,
          externalProductCode: drug.id,
          route: drug.route,
          dosageForm: drug.dosageForm,
          releaseType: drug.releaseType,
          labelVersion: 'seed_catalog_v2',
          sourceStatus: drug.sourceSystem == 'LOCAL_SEED'
              ? 'seeded_reference'
              : 'catalog_summary',
        ),
      )
      .toList(growable: false);
}

String? _argValue(List<String> args, String prefix) {
  for (final arg in args) {
    if (arg.startsWith(prefix)) return arg.substring(prefix.length);
  }
  return null;
}

String _safeDocumentPath(String path) {
  return path
      .split('/')
      .map((segment) => segment.replaceAll('/', '_').replaceAll(' ', '_'))
      .join('/');
}

String _safePathSegment(String path) {
  return path.replaceAll('/', '_').replaceAll(' ', '_');
}
