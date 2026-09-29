import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/domain/entities/food_composition_candidate_set_snapshot.dart';
import 'package:parkinsum_companion/domain/entities/food_portion_composition_projection.dart';
import 'package:parkinsum_companion/domain/usecases/food_portion_composition_projection_service.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/fdc_portion_composition_vectors.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final vectors = (fixture['cases'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  const service = FoodPortionCompositionProjectionService();

  FoodItem foodFrom(
    Map<String, dynamic> vector, {
    String? name,
    double? secondPortionGrams,
  }) {
    final portionJson = vector['portion'] as Map<String, dynamic>;
    final exactJson = vector['exact'] as Map<String, dynamic>;
    final rangeJson = vector['range'] as Map<String, dynamic>?;
    final value = (exactJson['valueNum'] as num?)?.toDouble() ?? 0;
    NutrientObservationEvidence observation(
      Map<String, dynamic> row, {
      required String? qualifier,
      required bool selected,
    }) => NutrientObservationEvidence(
      observationId: '${vector['id']}_${qualifier ?? 'exact'}',
      domain: row['domain'] as String?,
      entityType: row['entityType'] as String?,
      entityKey: row['entityKey'] as String?,
      attributeCode: row['attributeCode'] as String?,
      valueType: row['valueType'] as String?,
      valueNum: (row['valueNum'] as num?)?.toDouble(),
      low: (row['low'] as num?)?.toDouble(),
      high: (row['high'] as num?)?.toDouble(),
      qualifierKind: qualifier,
      rawValueText: '$value',
      unit: row['unit'] as String?,
      basisType: row['basisType'] as String?,
      basisAmount: (row['basisAmount'] as num?)?.toDouble(),
      scopeHash: row['scopeHash'] as String?,
      sourceDocId: row['sourceDocId'] as String?,
      recordLocator: row['recordLocator'] as String?,
      methodCode: row['methodCode'] as String?,
      extractionConfidence: 1,
      selectedForLegacyPointProjection: selected,
    );

    final evidence = <NutrientObservationEvidence>[
      observation(
        exactJson,
        qualifier: exactJson['qualifierKind'] as String?,
        selected: exactJson['selected'] == true,
      ),
      if (rangeJson != null)
        observation(
          rangeJson,
          qualifier: rangeJson['qualifierKind'] as String?,
          selected: rangeJson['selected'] == true,
        ),
    ];
    FoodPortionEvidence portionRecord({
      required String recordLocator,
      required double gramWeight,
    }) => FoodPortionEvidence(
      sourceDocId: portionJson['sourceDocId'] as String?,
      sourceFoodId: portionJson['sourceFoodId'] as String?,
      recordLocator: recordLocator,
      sequenceNumber: 1,
      amount: (portionJson['amount'] as num?)?.toDouble(),
      measureUnitId: (portionJson['measureUnitId'] as num?)?.toInt(),
      measureUnitName: portionJson['measureUnitName'] as String?,
      measureUnitAbbreviation: null,
      portionDescription: null,
      modifier: null,
      gramWeight: gramWeight,
      dataPoints: 4,
      footnote: null,
      minYearAcquired: null,
      sourceFields: <String, Object?>{
        ...Map<String, Object?>.from(portionJson),
        'gramWeight': gramWeight,
      },
    );
    final portionLocator = portionJson['recordLocator'] as String;
    final portionWeight = (portionJson['gramWeight'] as num).toDouble();
    final portions = <FoodPortionEvidence>[
      portionRecord(recordLocator: portionLocator, gramWeight: portionWeight),
      if (secondPortionGrams != null)
        portionRecord(
          recordLocator: portionLocator.replaceFirst(RegExp(r':\d+$'), ':1'),
          gramWeight: secondPortionGrams,
        ),
    ];
    return FoodItem(
      id: 'food_${vector['id']}',
      name: name ?? '${vector['id']}',
      category: FoodCategory.other,
      sourceSystem: vector['sourceSystem'] as String,
      sourceFoodCode: vector['sourceFoodCode'] as String,
      jurisdiction: 'US',
      proteinG: value,
      carbsG: 0,
      fatG: 0,
      fiberG: 0,
      sodiumMg: 0,
      nutrientObservationEvidence: evidence,
      foodPortionEvidence: portions,
      catalogProvenanceEvidence: FoodCatalogProvenanceEvidence.fromJson(
        <String, dynamic>{
          'source_documents': <Map<String, Object?>>[
            <String, Object?>{
              'source_doc_id': portionJson['sourceDocId'],
              'source_family': fixture['sourceDocument']['sourceFamily'],
              'organization': fixture['sourceDocument']['organization'],
              'jurisdiction': fixture['sourceDocument']['jurisdiction'],
              'resolution_status':
                  fixture['sourceDocument']['resolutionStatus'],
              'stored_payload_present':
                  fixture['sourceDocument']['storedPayloadPresent'],
              'payload_sha256': fixture['sourceDocument']['payloadSha256'],
            },
          ],
        },
      ),
    );
  }

  FoodCompositionCandidateSetSnapshot snapshot(FoodItem food) =>
      FoodCompositionCandidateSetSnapshot.capture(
        callerCandidateFoods: <FoodItem>[food],
        fallbackCandidateFoods: const <FoodItem>[],
        projectedFoods: const <FoodItem>[],
        mergedCandidates: <FoodItem>[food],
        projectionQueryAudit: const <String, Object?>{
          'schema_id': 'test.synthetic-projection-query-audit/1',
        },
        builtInP0FallbackUsed: false,
        contentJurisdictionOverride: const <String>[],
        registrationRegion: 'US',
        dietProfileRegion: 'US',
        tieBreakPolicy: 'score_desc_food_id_asc',
      );

  test(
    'shared vectors produce only bounded, non-persisted previews or holds',
    () {
      expect(
        fixture['schema_id'],
        'parkinsum.fdc-portion-composition-vectors/1',
      );
      for (final vector in vectors) {
        final food = foodFrom(vector);
        final result = service.calculatePreview(
          candidateSetSnapshot: snapshot(food),
          food: food,
          portionRecordLocator:
              (vector['portion'] as Map<String, dynamic>)['recordLocator']
                  as String,
          nutrientAttributeCode: 'protein_g',
        );
        final expected = vector['expected'] as Map<String, dynamic>;
        expect(
          result.status,
          expected['status'],
          reason: vector['id'] as String,
        );
        if (expected['holdReason'] != null) {
          expect(
            result.holdReason,
            expected['holdReason'],
            reason: vector['id'] as String,
          );
        }
        for (final key in <String>[
          'perPortionValue',
          'sourceSampleMinimumPerPortion',
          'sourceSampleMaximumPerPortion',
        ]) {
          final expectedValue = expected[key] as num?;
          if (expectedValue != null) {
            final actualValue = result.toJson()[_wireKey(key)] as num;
            expect(
              (actualValue.toDouble() - expectedValue.toDouble()).abs(),
              lessThan(1e-12),
              reason: '${vector['id']}: $key',
            );
          }
        }
        expect(result.toJson()['persisted'], isFalse);
        expect(
          result.toJson()['schema_id'],
          FoodPortionCompositionProjection.schemaId,
        );
        expect(result.toJson()['ranking_effect'], 'none_preview_only');
        expect(result.portionWeightUncertainty, 'not_quantified_by_source');
        expect(() => jsonEncode(result.toJson()), returnsNormally);
      }
    },
  );

  test('source extrema remain extrema and do not become confidence limits', () {
    final vector = vectors.first;
    final food = foodFrom(vector);
    final result = service.calculatePreview(
      candidateSetSnapshot: snapshot(food),
      food: food,
      portionRecordLocator: '123:foodPortions:0',
      nutrientAttributeCode: 'protein_g',
    );
    expect(result.status, 'calculated_preview');
    expect(
      result.rangeInterpretation,
      'observed_source_extrema_not_confidence_or_probability_limits',
    );
    expect(
      result.toJson()['portion_selection'],
      contains('suitability_not_established'),
    );
  });

  test('candidate content must match the candidate-set snapshot exactly', () {
    final vector = vectors.first;
    final snapshottedFood = foodFrom(vector);
    final changedFood = foodFrom(vector, name: 'changed outside snapshot');
    final result = service.calculatePreview(
      candidateSetSnapshot: snapshot(snapshottedFood),
      food: changedFood,
      portionRecordLocator: '123:foodPortions:0',
      nutrientAttributeCode: 'protein_g',
    );
    expect(result.status, 'held');
    expect(result.holdReason, 'candidate_snapshot_food_identity_mismatch');
  });

  test('report digest binds the explicit portion selection and snapshot', () {
    final vector = vectors.first;
    final food = foodFrom(vector, secondPortionGrams: 50);
    final candidateSnapshot = snapshot(food);
    FoodPortionCompositionProjection calculate(String locator) =>
        service.calculatePreview(
          candidateSetSnapshot: candidateSnapshot,
          food: food,
          portionRecordLocator: locator,
          nutrientAttributeCode: 'protein_g',
        );

    final first = calculate('123:foodPortions:0');
    final repeated = calculate('123:foodPortions:0');
    final second = calculate('123:foodPortions:1');
    final firstJson = first.toJson();
    final repeatedJson = repeated.toJson();
    final secondJson = second.toJson();
    final digest = firstJson.remove('sha256_digest') as String;
    expect(
      firstJson['candidate_snapshot_sha256'],
      candidateSnapshot.sha256Digest,
    );
    expect(
      firstJson['canonicalization_policy'],
      'sorted_json_object_keys_tagged_binary64_sha256_v1',
    );
    expect(digest, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(
      sha256.convert(utf8.encode(_canonicalJson(firstJson))).toString(),
      digest,
    );
    expect(digest, repeatedJson['sha256_digest']);
    expect(
      firstJson['candidate_snapshot_sha256'],
      secondJson['candidate_snapshot_sha256'],
    );
    expect(digest, isNot(secondJson['sha256_digest']));
    expect(
      firstJson['per_portion_value'],
      isNot(secondJson['per_portion_value']),
    );
  });

  test('Dart report matches the shared binary64 digest vector', () {
    final digestVector =
        jsonDecode(
              File(
                'test/fixtures/fdc_portion_projection_digest_v1.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final payload = Map<String, Object?>.from(
      digestVector['payload'] as Map<String, dynamic>,
    );
    double number(String key) => (payload[key] as num).toDouble();
    final projection = FoodPortionCompositionProjection.preview(
      candidateSnapshotSha256: payload['candidate_snapshot_sha256'] as String,
      foodId: payload['food_id'] as String,
      sourceFoodId: payload['source_food_id'] as String,
      portionSourceFoodId: payload['portion_source_food_id'] as String,
      sourceDocId: payload['source_doc_id'] as String,
      portionRecordLocator: payload['portion_record_locator'] as String,
      portionGramWeight: number('portion_gram_weight'),
      sourceDataType: payload['source_data_type'] as String,
      nutrientAttributeCode: payload['nutrient_attribute_code'] as String,
      nutrientUnit: payload['nutrient_unit'] as String,
      nutrientObservationRecordLocator:
          payload['nutrient_observation_record_locator'] as String,
      nutrientScopeHash: payload['nutrient_scope_hash'] as String,
      nutrientMethodCode: payload['nutrient_method_code'] as String?,
      sampleRangeRecordLocator:
          payload['sample_range_record_locator'] as String?,
      per100gValue: number('per_100g_value'),
      perPortionValue: number('per_portion_value'),
      sourceSampleMinimumPer100g: number('source_sample_minimum_per_100g'),
      sourceSampleMaximumPer100g: number('source_sample_maximum_per_100g'),
      sourceSampleMinimumPerPortion: number(
        'source_sample_minimum_per_portion',
      ),
      sourceSampleMaximumPerPortion: number(
        'source_sample_maximum_per_portion',
      ),
    );
    final actual = projection.toJson();
    final actualDigest = actual.remove('sha256_digest');
    expect(actual, payload);
    expect(
      actual['canonicalization_policy'],
      'sorted_json_object_keys_tagged_binary64_sha256_v1',
    );
    expect(actualDigest, digestVector['sha256_digest']);
  });
}

String _wireKey(String dartKey) => switch (dartKey) {
  'perPortionValue' => 'per_portion_value',
  'sourceSampleMinimumPerPortion' => 'source_sample_minimum_per_portion',
  'sourceSampleMaximumPerPortion' => 'source_sample_maximum_per_portion',
  _ => dartKey,
};

String _canonicalJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',')}}';
  }
  if (value is List) return '[${value.map(_canonicalJson).join(',')}]';
  if (value is num) return jsonEncode('f64:${_binary64Hex(value.toDouble())}');
  return jsonEncode(value);
}

String _binary64Hex(double value) {
  final data = ByteData(8)..setFloat64(0, value, Endian.big);
  return List<String>.generate(
    8,
    (index) => data.getUint8(index).toRadixString(16).padLeft(2, '0'),
    growable: false,
  ).join();
}
