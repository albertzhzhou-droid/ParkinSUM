import 'dart:convert';

import '../../../core/models/drug_definition.dart';
import '../../../core/models/food_item.dart';
import '../../../core/utils/qualified_value_parser.dart';
import '../../../domain/entities/cdss_records.dart';

String stableSlug(String input) {
  final upper = input.trim().toUpperCase();
  final normalized = upper.replaceAll(RegExp(r'[^A-Z0-9]+'), '_');
  return normalized
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

String stableHash(String input) {
  // FNV-1a 32-bit：足够做本地 ETL 记录的稳定短 hash。
  var hash = 0x811c9dc5;
  for (final codeUnit in input.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

String sourceDocumentId({
  required String sourceSystem,
  required String externalKey,
}) {
  return '${stableSlug(sourceSystem)}_${stableSlug(externalKey)}';
}

String buildFoodConceptId(String canonicalName) {
  return 'FOOD_${stableSlug(canonicalName)}';
}

String buildFoodVariantId({
  required String conceptId,
  required String jurisdiction,
  required String sourceSystem,
  required String sourceFoodCode,
}) {
  return '$conceptId#${stableSlug(jurisdiction)}#${stableSlug(sourceSystem)}#$sourceFoodCode';
}

String buildDrugConceptId(String genericName) {
  return 'DRUG_${stableSlug(genericName)}';
}

String buildDrugVariantId({
  required String conceptId,
  required String jurisdiction,
  required String sourceSystem,
  required String externalProductCode,
}) {
  return '$conceptId#${stableSlug(jurisdiction)}#${stableSlug(sourceSystem)}#$externalProductCode';
}

String buildScopeHash(String seed) => 'scope_${stableHash(seed)}';

String unitForAttributeCode(String attributeCode) {
  if (attributeCode.endsWith('_mg')) return 'mg';
  if (attributeCode.endsWith('_ug')) return 'ug';
  return 'g';
}

FoodCategory inferFoodCategory(String foodGroup) {
  switch (foodGroup.toLowerCase()) {
    case 'protein':
    case 'meat':
    case 'fish':
    case 'legume':
      return FoodCategory.protein;
    case 'carbs':
    case 'grain':
    case 'cereal':
    case 'starch':
      return FoodCategory.carbs;
    case 'vegetable':
      return FoodCategory.vegetable;
    case 'fruit':
      return FoodCategory.fruit;
    case 'dairy':
      return FoodCategory.dairy;
    case 'fat':
    case 'oil':
      return FoodCategory.fat;
    case 'beverage':
      return FoodCategory.beverage;
    default:
      return FoodCategory.other;
  }
}

double displayValueFromRaw(String raw) {
  final qualified = parseQualifiedValue(raw);
  return qualified.valueNum ?? qualified.high ?? 0;
}

DrugTag? inferDrugTag(String genericName) {
  final lower = genericName.toLowerCase();
  if (lower.contains('levodopa')) return DrugTag.levodopaLike;
  if (lower.contains('entacapone') ||
      lower.contains('tolcapone') ||
      lower.contains('opicapone')) {
    return DrugTag.comtInhibitor;
  }
  if (lower.contains('rasagiline') ||
      lower.contains('selegiline') ||
      lower.contains('safinamide')) {
    return DrugTag.maoi;
  }
  if (lower.contains('pramipexole') ||
      lower.contains('ropinirole') ||
      lower.contains('rotigotine') ||
      lower.contains('apomorphine')) {
    return DrugTag.dopamineAgonist;
  }
  if (lower.contains('istradefylline')) return DrugTag.adenosineA2aAntagonist;
  if (lower.contains('amantadine')) return DrugTag.amantadineLike;
  if (lower.contains('rivastigmine')) return DrugTag.cholinesteraseInhibitor;
  if (lower.contains('droxidopa') || lower.contains('midodrine')) {
    return DrugTag.pressorAgent;
  }
  if (lower.contains('peg')) return DrugTag.laxative;
  if (lower.contains('iron')) return DrugTag.mineralSupplement;
  return null;
}

ResolvedFactRecord resolvedFactFromObservation({
  required ObservationRecord observation,
  required String policyId,
  required String snapshotId,
}) {
  return ResolvedFactRecord(
    factId: 'fact_${observation.observationId}',
    entityKey: observation.entityKey,
    attributeCode: observation.attributeCode,
    scopeHash: observation.scopeHash,
    resolutionStatus:
        observation.value.qualifierKind == QualifierKind.parsingUncertainty
            ? 'PARSING_UNCERTAINTY'
            : 'SOURCE_ACCEPTED',
    chosenObservationId: observation.observationId,
    resolvedValue: observation.value,
    resolvedUnit: observation.unit,
    resolutionPolicyId: policyId,
    snapshotId: snapshotId,
    factVersion: snapshotId,
    manualOverride: false,
  );
}

SourceDocumentRecord buildSourceDocumentRecord({
  required String sourceDocId,
  required String sourceFamily,
  required String organization,
  required String jurisdiction,
  required String docType,
  required String title,
  required String originUrl,
  required String licenseNote,
  required String rawPayload,
  DateTime? publishedAt,
  DateTime? effectiveAt,
  String language = 'und',
  String sourceStatus = 'active',
  String dataTier = KnowledgeDataTier.p0,
  String ingestionStrategy = SourceIngestionStrategy.authoritativeDirect,
}) {
  return SourceDocumentRecord(
    sourceDocId: sourceDocId,
    sourceFamily: sourceFamily,
    dataTier: dataTier,
    ingestionStrategy: ingestionStrategy,
    organization: organization,
    jurisdiction: jurisdiction,
    docType: docType,
    title: title,
    originUrl: originUrl,
    publishedAt: publishedAt,
    effectiveAt: effectiveAt,
    language: language,
    licenseNote: licenseNote,
    checksum: stableHash(rawPayload),
    sourceStatus: sourceStatus,
    rawPayload: rawPayload,
  );
}

String stringifyPayload(Object payload) {
  return const JsonEncoder.withIndent('  ').convert(payload);
}
