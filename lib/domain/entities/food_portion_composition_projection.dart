import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// A non-persisted, source-bound preview of a nutrient amount for one
/// explicitly named source portion. It is not a selected user serving and
/// never changes a FoodItem or production ranking input.
class FoodPortionCompositionProjection {
  static const String schemaId =
      'parkinsum.food-portion-composition-projection/1';

  final String status;
  final String? holdReason;
  final String candidateSnapshotSha256;
  final String foodId;
  final String sourceFoodId;
  final String? portionSourceFoodId;
  final String sourceDocId;
  final String portionRecordLocator;
  final double? portionGramWeight;
  final String? sourceDataType;
  final String nutrientAttributeCode;
  final String nutrientUnit;
  final String? nutrientObservationRecordLocator;
  final String? nutrientScopeHash;
  final String? nutrientMethodCode;
  final String? sampleRangeRecordLocator;
  final String? basisType;
  final double? basisAmount;
  final double? per100gValue;
  final double? perPortionValue;
  final double? sourceSampleMinimumPer100g;
  final double? sourceSampleMaximumPer100g;
  final double? sourceSampleMinimumPerPortion;
  final double? sourceSampleMaximumPerPortion;
  final String? rangeInterpretation;
  final String portionWeightUncertainty;

  const FoodPortionCompositionProjection._({
    required this.status,
    required this.holdReason,
    required this.candidateSnapshotSha256,
    required this.foodId,
    required this.sourceFoodId,
    required this.portionSourceFoodId,
    required this.sourceDocId,
    required this.portionRecordLocator,
    required this.portionGramWeight,
    required this.sourceDataType,
    required this.nutrientAttributeCode,
    required this.nutrientUnit,
    required this.nutrientObservationRecordLocator,
    required this.nutrientScopeHash,
    required this.nutrientMethodCode,
    required this.sampleRangeRecordLocator,
    required this.basisType,
    required this.basisAmount,
    required this.per100gValue,
    required this.perPortionValue,
    required this.sourceSampleMinimumPer100g,
    required this.sourceSampleMaximumPer100g,
    required this.sourceSampleMinimumPerPortion,
    required this.sourceSampleMaximumPerPortion,
    required this.rangeInterpretation,
    required this.portionWeightUncertainty,
  });

  factory FoodPortionCompositionProjection.held({
    required String reason,
    required String candidateSnapshotSha256,
    required String foodId,
    required String sourceFoodId,
    String? portionSourceFoodId,
    required String sourceDocId,
    required String portionRecordLocator,
    required double? portionGramWeight,
    String? sourceDataType,
    required String nutrientAttributeCode,
    required String nutrientUnit,
  }) => FoodPortionCompositionProjection._(
    status: 'held',
    holdReason: reason,
    candidateSnapshotSha256: candidateSnapshotSha256,
    foodId: foodId,
    sourceFoodId: sourceFoodId,
    portionSourceFoodId: portionSourceFoodId,
    sourceDocId: sourceDocId,
    portionRecordLocator: portionRecordLocator,
    portionGramWeight: portionGramWeight,
    sourceDataType: sourceDataType,
    nutrientAttributeCode: nutrientAttributeCode,
    nutrientUnit: nutrientUnit,
    nutrientObservationRecordLocator: null,
    nutrientScopeHash: null,
    nutrientMethodCode: null,
    sampleRangeRecordLocator: null,
    basisType: null,
    basisAmount: null,
    per100gValue: null,
    perPortionValue: null,
    sourceSampleMinimumPer100g: null,
    sourceSampleMaximumPer100g: null,
    sourceSampleMinimumPerPortion: null,
    sourceSampleMaximumPerPortion: null,
    rangeInterpretation: null,
    portionWeightUncertainty: 'not_quantified_by_source',
  );

  factory FoodPortionCompositionProjection.preview({
    required String candidateSnapshotSha256,
    required String foodId,
    required String sourceFoodId,
    required String portionSourceFoodId,
    required String sourceDocId,
    required String portionRecordLocator,
    required double portionGramWeight,
    required String sourceDataType,
    required String nutrientAttributeCode,
    required String nutrientUnit,
    required String nutrientObservationRecordLocator,
    required String nutrientScopeHash,
    required String? nutrientMethodCode,
    required String? sampleRangeRecordLocator,
    required double per100gValue,
    required double perPortionValue,
    double? sourceSampleMinimumPer100g,
    double? sourceSampleMaximumPer100g,
    double? sourceSampleMinimumPerPortion,
    double? sourceSampleMaximumPerPortion,
  }) => FoodPortionCompositionProjection._(
    status: 'calculated_preview',
    holdReason: null,
    candidateSnapshotSha256: candidateSnapshotSha256,
    foodId: foodId,
    sourceFoodId: sourceFoodId,
    portionSourceFoodId: portionSourceFoodId,
    sourceDocId: sourceDocId,
    portionRecordLocator: portionRecordLocator,
    portionGramWeight: portionGramWeight,
    sourceDataType: sourceDataType,
    nutrientAttributeCode: nutrientAttributeCode,
    nutrientUnit: nutrientUnit,
    nutrientObservationRecordLocator: nutrientObservationRecordLocator,
    nutrientScopeHash: nutrientScopeHash,
    nutrientMethodCode: nutrientMethodCode,
    sampleRangeRecordLocator: sampleRangeRecordLocator,
    basisType: 'per_100g_edible_part',
    basisAmount: 100,
    per100gValue: per100gValue,
    perPortionValue: perPortionValue,
    sourceSampleMinimumPer100g: sourceSampleMinimumPer100g,
    sourceSampleMaximumPer100g: sourceSampleMaximumPer100g,
    sourceSampleMinimumPerPortion: sourceSampleMinimumPerPortion,
    sourceSampleMaximumPerPortion: sourceSampleMaximumPerPortion,
    rangeInterpretation: sourceSampleMinimumPer100g == null
        ? null
        : 'observed_source_extrema_not_confidence_or_probability_limits',
    portionWeightUncertainty: 'not_quantified_by_source',
  );

  Map<String, Object?> toJson() {
    final payload = <String, Object?>{
      'schema_id': schemaId,
      'canonicalization_policy':
          'sorted_json_object_keys_tagged_binary64_sha256_v1',
      'status': status,
      'hold_reason': holdReason,
      'candidate_snapshot_sha256': candidateSnapshotSha256,
      'food_id': foodId,
      'source_food_id': sourceFoodId,
      'portion_source_food_id': portionSourceFoodId,
      'source_doc_id': sourceDocId,
      'portion_record_locator': portionRecordLocator,
      'portion_gram_weight': portionGramWeight,
      'portion_selection':
          'explicit_record_locator_input;_suitability_not_established',
      'source_data_type': sourceDataType,
      'nutrient_attribute_code': nutrientAttributeCode,
      'nutrient_unit': nutrientUnit,
      'nutrient_observation_record_locator': nutrientObservationRecordLocator,
      'nutrient_scope_hash': nutrientScopeHash,
      'nutrient_method_code': nutrientMethodCode,
      'sample_range_record_locator': sampleRangeRecordLocator,
      'basis_type': basisType,
      'basis_amount': basisAmount,
      'conversion_formula': 'per_100g_value * portion_gram_weight / 100',
      'per_100g_value': per100gValue,
      'per_portion_value': perPortionValue,
      'source_sample_minimum_per_100g': sourceSampleMinimumPer100g,
      'source_sample_maximum_per_100g': sourceSampleMaximumPer100g,
      'source_sample_minimum_per_portion': sourceSampleMinimumPerPortion,
      'source_sample_maximum_per_portion': sourceSampleMaximumPerPortion,
      'range_interpretation': rangeInterpretation,
      'portion_weight_uncertainty': portionWeightUncertainty,
      'ranking_effect': 'none_preview_only',
      'persisted': false,
    };
    return <String, Object?>{
      ...payload,
      'sha256_digest': sha256
          .convert(utf8.encode(_canonicalJson(payload)))
          .toString(),
    };
  }

  static String _canonicalJson(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return '{${keys.map((key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',')}}';
    }
    if (value is List) {
      return '[${value.map(_canonicalJson).join(',')}]';
    }
    if (value is num) {
      return jsonEncode('f64:${_binary64Hex(value.toDouble())}');
    }
    return jsonEncode(value);
  }

  static String _binary64Hex(double value) {
    final data = ByteData(8)..setFloat64(0, value, Endian.big);
    return List<String>.generate(
      8,
      (index) => data.getUint8(index).toRadixString(16).padLeft(2, '0'),
      growable: false,
    ).join();
  }
}
