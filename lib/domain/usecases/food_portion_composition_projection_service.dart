import 'dart:convert';

import '../../core/models/food_item.dart';
import '../entities/food_composition_candidate_set_snapshot.dart';
import '../entities/food_portion_composition_projection.dart';

/// Computes an opt-in preview only when one FDC Foundation nutrient and one
/// portion are bound to the same source food and source document.
class FoodPortionCompositionProjectionService {
  const FoodPortionCompositionProjectionService();

  static const Map<String, _FoodNutrientProjection> _supportedNutrients =
      <String, _FoodNutrientProjection>{
        'protein_g': _FoodNutrientProjection('proteinG', 'g'),
        'carbohydrate_g': _FoodNutrientProjection('carbsG', 'g'),
        'fat_g': _FoodNutrientProjection('fatG', 'g'),
        'fiber_g': _FoodNutrientProjection('fiberG', 'g'),
        'sodium_mg': _FoodNutrientProjection('sodiumMg', 'mg'),
        'energy_kcal': _FoodNutrientProjection('energyKcal', 'kcal'),
        'water_g': _FoodNutrientProjection('waterG', 'g'),
      };

  FoodPortionCompositionProjection calculatePreview({
    required FoodCompositionCandidateSetSnapshot candidateSetSnapshot,
    required FoodItem food,
    required String portionRecordLocator,
    required String nutrientAttributeCode,
  }) {
    final item = _supportedNutrients[nutrientAttributeCode];
    final sourceFoodId = food.sourceFoodCode ?? '';
    final portionMatches = food.foodPortionEvidence
        .where((record) => record.recordLocator == portionRecordLocator)
        .toList(growable: false);
    final portion = portionMatches.length == 1 ? portionMatches.single : null;

    FoodPortionCompositionProjection held(String reason) =>
        FoodPortionCompositionProjection.held(
          reason: reason,
          candidateSnapshotSha256: candidateSetSnapshot.sha256Digest,
          foodId: food.id,
          sourceFoodId: sourceFoodId,
          portionSourceFoodId: portion?.sourceFoodId,
          sourceDocId: portion?.sourceDocId ?? '',
          portionRecordLocator: portionRecordLocator,
          portionGramWeight: portion?.gramWeight?.isFinite == true
              ? portion!.gramWeight
              : null,
          sourceDataType: food.sourceSystem,
          nutrientAttributeCode: nutrientAttributeCode,
          nutrientUnit: '',
        );

    if (!_snapshotContainsExactFood(candidateSetSnapshot, food)) {
      return held('candidate_snapshot_food_identity_mismatch');
    }
    if (item == null) return held('nutrient_attribute_not_supported');
    if (food.sourceSystem.trim().toLowerCase() != 'foundation') {
      return held('source_data_type_not_foundation');
    }
    if (portionMatches.length != 1) {
      return held('portion_record_locator_not_unique');
    }
    if (sourceFoodId.isEmpty || sourceFoodId.trim() != sourceFoodId) {
      return held('source_food_identity_missing_or_malformed');
    }
    if (portion!.sourceFoodId != sourceFoodId) {
      return held('portion_source_food_mismatch');
    }
    if (portion.sourceDocId == null || portion.sourceDocId!.trim().isEmpty) {
      return held('portion_source_document_missing');
    }
    if (!_hasResolvedUsdaFdcSourceDocument(food, portion.sourceDocId!)) {
      return held('source_document_not_resolved_usda_fdc');
    }
    if (portion.recordLocator == null ||
        !portion.recordLocator!.startsWith('$sourceFoodId:foodPortions:')) {
      return held('portion_record_identity_invalid');
    }
    final weight = portion.gramWeight;
    if (weight == null || !weight.isFinite || weight <= 0) {
      return held('portion_gram_weight_not_positive_finite');
    }

    final exactRows = food.nutrientObservationEvidence
        .where(
          (row) =>
              row.attributeCode == nutrientAttributeCode &&
              row.selectedForLegacyPointProjection,
        )
        .toList(growable: false);
    if (exactRows.length != 1) {
      return held('exact_nutrient_evidence_not_unique');
    }
    final exact = exactRows.single;
    if (!_isBoundObservation(
      food: food,
      portion: portion,
      observation: exact,
      item: item,
    )) {
      return held('exact_nutrient_evidence_not_bound');
    }
    final value = exact.valueNum!;
    if (exact.low != value || exact.high != value) {
      return held('exact_nutrient_interval_inconsistent');
    }
    if (food.isNutrientMissing(item.foodItemField) ||
        _foodItemNutrientValue(food, item.foodItemField) != value) {
      return held('exact_nutrient_value_differs_from_candidate_projection');
    }

    final rangeRows = food.nutrientObservationEvidence
        .where(
          (row) =>
              row.attributeCode == nutrientAttributeCode &&
              row.entityKey == exact.entityKey &&
              row.qualifierKind == 'range',
        )
        .toList(growable: false);
    NutrientObservationEvidence? range;
    if (rangeRows.isNotEmpty) {
      final compatible = rangeRows
          .where(
            (row) =>
                row.domain == exact.domain &&
                row.entityType == exact.entityType &&
                row.sourceDocId == exact.sourceDocId &&
                row.scopeHash == exact.scopeHash &&
                row.unit == exact.unit &&
                row.basisType == exact.basisType &&
                row.basisAmount == exact.basisAmount &&
                row.methodCode == exact.methodCode &&
                row.valueType == 'numeric_interval' &&
                row.recordLocator ==
                    '$sourceFoodId:$nutrientAttributeCode:sample_range',
          )
          .toList(growable: false);
      if (compatible.length != 1) {
        return held('sample_range_evidence_not_uniquely_bound');
      }
      range = compatible.single;
      final low = range.low;
      final high = range.high;
      if (low == null ||
          high == null ||
          !low.isFinite ||
          !high.isFinite ||
          low < 0 ||
          high < low ||
          value < low ||
          value > high) {
        return held('sample_range_bounds_invalid_or_exclude_point');
      }
    }

    final ratio = weight / 100;
    final perPortion = value * ratio;
    final lowPerPortion = range == null ? null : range.low! * ratio;
    final highPerPortion = range == null ? null : range.high! * ratio;
    if (!ratio.isFinite ||
        !perPortion.isFinite ||
        (lowPerPortion != null && !lowPerPortion.isFinite) ||
        (highPerPortion != null && !highPerPortion.isFinite)) {
      return held('portion_composition_result_not_finite');
    }

    return FoodPortionCompositionProjection.preview(
      candidateSnapshotSha256: candidateSetSnapshot.sha256Digest,
      foodId: food.id,
      sourceFoodId: sourceFoodId,
      portionSourceFoodId: portion.sourceFoodId!,
      sourceDocId: portion.sourceDocId!,
      portionRecordLocator: portion.recordLocator!,
      portionGramWeight: weight,
      sourceDataType: food.sourceSystem,
      nutrientAttributeCode: nutrientAttributeCode,
      nutrientUnit: exact.unit!,
      nutrientObservationRecordLocator: exact.recordLocator!,
      nutrientScopeHash: exact.scopeHash!,
      nutrientMethodCode: exact.methodCode,
      sampleRangeRecordLocator: range?.recordLocator,
      per100gValue: value,
      perPortionValue: perPortion,
      sourceSampleMinimumPer100g: range?.low,
      sourceSampleMaximumPer100g: range?.high,
      sourceSampleMinimumPerPortion: lowPerPortion,
      sourceSampleMaximumPerPortion: highPerPortion,
    );
  }

  bool _isBoundObservation({
    required FoodItem food,
    required FoodPortionEvidence portion,
    required NutrientObservationEvidence observation,
    required _FoodNutrientProjection item,
  }) {
    final value = observation.valueNum;
    final sourceFoodId = food.sourceFoodCode;
    return observation.domain == 'food' &&
        observation.entityType == 'food_variant' &&
        (observation.entityKey ?? '').trim().isNotEmpty &&
        observation.attributeCode != null &&
        observation.qualifierKind == 'exact' &&
        (observation.valueType == 'numeric_interval' ||
            observation.valueType == 'numeric') &&
        value != null &&
        value.isFinite &&
        value >= 0 &&
        observation.sourceDocId != null &&
        observation.sourceDocId == portion.sourceDocId &&
        observation.scopeHash != null &&
        observation.scopeHash!.trim().isNotEmpty &&
        observation.recordLocator != null &&
        observation.recordLocator!.startsWith('$sourceFoodId:') &&
        observation.basisType == 'per_100g_edible_part' &&
        observation.basisAmount == 100 &&
        observation.unit != null &&
        _normalizedUnit(observation.unit!) == item.expectedUnit;
  }

  double _foodItemNutrientValue(FoodItem food, String field) => switch (field) {
    'proteinG' => food.proteinG,
    'carbsG' => food.carbsG,
    'fatG' => food.fatG,
    'fiberG' => food.fiberG,
    'sodiumMg' => food.sodiumMg,
    'energyKcal' => food.energyKcal ?? double.nan,
    'waterG' => food.waterG ?? double.nan,
    _ => double.nan,
  };

  bool _snapshotContainsExactFood(
    FoodCompositionCandidateSetSnapshot snapshot,
    FoodItem food,
  ) {
    final expectedFields = Map<String, Object?>.from(food.toJson());
    final missing = expectedFields['missingNutrientFields'];
    if (missing is List) {
      expectedFields['missingNutrientFields'] = List<String>.from(missing)
        ..sort();
    }
    final expected = _canonicalJson(expectedFields);
    return snapshot.mergedCandidateRecords.any(
      (record) => record['id'] == food.id && _canonicalJson(record) == expected,
    );
  }

  bool _hasResolvedUsdaFdcSourceDocument(FoodItem food, String sourceDocId) {
    final matchingDocuments =
        food.catalogProvenanceEvidence?.sourceDocuments
            .where((document) => document.sourceDocId == sourceDocId)
            .toList(growable: false) ??
        const <FoodSourceDocumentEvidence>[];
    if (matchingDocuments.length != 1) return false;
    final document = matchingDocuments.single;
    return document.resolutionStatus == 'resolved' &&
        document.sourceFamily?.trim().toUpperCase() == 'FDC' &&
        document.organization?.trim().toLowerCase() == 'usda' &&
        document.jurisdiction?.trim().toUpperCase() == 'US' &&
        document.storedPayloadPresent &&
        RegExp(
          r'^[0-9a-f]{64}$',
        ).hasMatch((document.payloadSha256 ?? '').trim());
  }

  String _normalizedUnit(String unit) => unit.trim().toLowerCase();

  String _canonicalJson(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return '{${keys.map((key) => '${_canonicalJson(key)}:${_canonicalJson(value[key])}').join(',')}}';
    }
    if (value is List) {
      return '[${value.map(_canonicalJson).join(',')}]';
    }
    if (value == null) return 'null';
    if (value is String) return jsonEncode(value);
    if (value is bool) return value ? 'true' : 'false';
    if (value is num) return value.toString();
    throw FormatException('Unsupported candidate snapshot JSON value: $value');
  }
}

class _FoodNutrientProjection {
  final String foodItemField;
  final String expectedUnit;

  const _FoodNutrientProjection(this.foodItemField, this.expectedUnit);
}
