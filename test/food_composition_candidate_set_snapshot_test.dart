import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/domain/entities/food_composition_candidate_set_snapshot.dart';

void main() {
  FoodItem food(
    String id, {
    String? name,
    double protein = 0,
    Set<String> missing = const <String>{},
    List<NutrientObservationEvidence> evidence =
        const <NutrientObservationEvidence>[],
    List<FoodPortionEvidence> portions = const <FoodPortionEvidence>[],
  }) => FoodItem(
    id: id,
    name: name ?? id,
    category: FoodCategory.other,
    sourceSystem: 'TEST_FIXTURE',
    jurisdiction: 'US',
    proteinG: protein,
    carbsG: 0,
    fatG: 0,
    fiberG: 0,
    sodiumMg: 0,
    missingNutrientFields: missing,
    nutrientObservationEvidence: evidence,
    foodPortionEvidence: portions,
  );

  FoodPortionEvidence portion(double gramWeight) => FoodPortionEvidence(
    sourceDocId: 'fdc-import-a',
    sourceFoodId: '123',
    recordLocator: '123:foodPortions:0',
    sequenceNumber: 1,
    amount: 1,
    measureUnitId: 99,
    measureUnitName: 'cup',
    measureUnitAbbreviation: 'c',
    portionDescription: 'chopped',
    modifier: null,
    gramWeight: gramWeight,
    dataPoints: 4,
    footnote: null,
    minYearAcquired: 2020,
    sourceFields: <String, Object?>{'gramWeight': gramWeight},
  );

  NutrientObservationEvidence observation({
    required String sourceDocId,
    String rawValue = '12',
  }) => NutrientObservationEvidence(
    observationId: 'obs_protein',
    domain: 'food',
    entityType: 'food_variant',
    entityKey: 'variant_1',
    attributeCode: 'protein_g',
    valueType: 'numeric_interval',
    valueNum: 12,
    low: 12,
    high: 12,
    qualifierKind: 'exact',
    rawValueText: rawValue,
    unit: 'g',
    basisType: 'per_100g_edible_part',
    basisAmount: 100,
    scopeHash: 'scope_1',
    sourceDocId: sourceDocId,
    recordLocator: '123:protein_g',
    methodCode: null,
    extractionConfidence: 1,
    selectedForLegacyPointProjection: true,
  );

  FoodCompositionCandidateSetSnapshot snapshot({
    required List<FoodItem> caller,
    List<FoodItem> fallback = const <FoodItem>[],
    List<FoodItem> projected = const <FoodItem>[],
    required List<FoodItem> merged,
    Map<String, Object?> projectionQueryAudit = const <String, Object?>{
      'schema_id': 'test.synthetic-projection-query-audit/1',
      'capture_status': 'synthetic_fixture',
    },
    bool usedFallback = false,
  }) => FoodCompositionCandidateSetSnapshot.capture(
    callerCandidateFoods: caller,
    fallbackCandidateFoods: fallback,
    projectedFoods: projected,
    mergedCandidates: merged,
    projectionQueryAudit: projectionQueryAudit,
    builtInP0FallbackUsed: usedFallback,
    contentJurisdictionOverride: const <String>[],
    registrationRegion: 'US',
    dietProfileRegion: 'US',
    tieBreakPolicy: 'score_desc_food_id_asc',
  );

  test(
    'canonical digest is stable and records sorted content plus live order',
    () {
      final first = snapshot(
        caller: <FoodItem>[
          food('food_z', missing: <String>{'proteinG', 'fatG'}),
          food('food_a'),
        ],
        merged: <FoodItem>[
          food('food_z', missing: <String>{'proteinG', 'fatG'}),
          food('food_a'),
        ],
      );
      final sameDataWithDifferentSetInsertionOrder = snapshot(
        caller: <FoodItem>[
          food('food_z', missing: <String>{'fatG', 'proteinG'}),
          food('food_a'),
        ],
        merged: <FoodItem>[
          food('food_z', missing: <String>{'fatG', 'proteinG'}),
          food('food_a'),
        ],
      );

      expect(first.sha256Digest, hasLength(64));
      expect(
        first.sha256Digest,
        sameDataWithDifferentSetInsertionOrder.sha256Digest,
      );
      expect(first.orderedCandidateIds, <String>['food_z', 'food_a']);
      expect(
        first.mergedCandidateRecords.map((record) => record['id']),
        <String>['food_a', 'food_z'],
      );
      expect(
        first.mergedCandidateRecords.last['missingNutrientFields'],
        <String>['fatG', 'proteinG'],
      );
      expect(
        () => first.mergedCandidateRecords.first['name'] = 'mutated',
        throwsUnsupportedError,
      );
    },
  );

  test('content and missing-versus-zero state both change the digest', () {
    final measuredZero = snapshot(
      caller: <FoodItem>[food('food_zero')],
      merged: <FoodItem>[food('food_zero')],
    );
    final unknownProtein = snapshot(
      caller: <FoodItem>[
        food('food_zero', missing: <String>{'proteinG'}),
      ],
      merged: <FoodItem>[
        food('food_zero', missing: <String>{'proteinG'}),
      ],
    );
    final changedContent = snapshot(
      caller: <FoodItem>[food('food_zero', protein: 1)],
      merged: <FoodItem>[food('food_zero', protein: 1)],
    );

    expect(measuredZero.sha256Digest, isNot(unknownProtein.sha256Digest));
    expect(measuredZero.sha256Digest, isNot(changedContent.sha256Digest));
  });

  test('FDC portion evidence is round-trippable and changes the digest', () {
    final oneReportedWeight = snapshot(
      caller: <FoodItem>[
        food('food_portion', portions: <FoodPortionEvidence>[portion(91)]),
      ],
      merged: <FoodItem>[
        food('food_portion', portions: <FoodPortionEvidence>[portion(91)]),
      ],
    );
    final revisedReportedWeight = snapshot(
      caller: <FoodItem>[
        food('food_portion', portions: <FoodPortionEvidence>[portion(92)]),
      ],
      merged: <FoodItem>[
        food('food_portion', portions: <FoodPortionEvidence>[portion(92)]),
      ],
    );
    final record =
        (oneReportedWeight.toJson()['merged_candidate_records'] as List).single
            as Map<String, dynamic>;

    expect(
      oneReportedWeight.sha256Digest,
      isNot(revisedReportedWeight.sha256Digest),
    );
    expect(
      oneReportedWeight.toJson()['schema_id'],
      'parkinsum.food-composition-candidate-set-snapshot/5',
    );
    expect((record['foodPortionEvidence'] as List).single['gram_weight'], 91.0);
  });

  test('projection query rows and returned order are digest-bound', () {
    final first = snapshot(
      caller: <FoodItem>[food('food_a')],
      merged: <FoodItem>[food('food_a')],
      projectionQueryAudit: const <String, Object?>{
        'schema_id': 'parkinsum.cdss-food-projection-query-audit/1',
        'table_reads': <Object?>[
          <String, Object?>{
            'table': 'food_variant',
            'ordered_record_ids': <String>['variant_a', 'variant_b'],
            'rows_sha256': 'rows-ab',
          },
        ],
      },
    );
    final changedRow = snapshot(
      caller: <FoodItem>[food('food_a')],
      merged: <FoodItem>[food('food_a')],
      projectionQueryAudit: const <String, Object?>{
        'schema_id': 'parkinsum.cdss-food-projection-query-audit/1',
        'table_reads': <Object?>[
          <String, Object?>{
            'table': 'food_variant',
            'ordered_record_ids': <String>['variant_a', 'variant_b'],
            'rows_sha256': 'rows-changed',
          },
        ],
      },
    );
    final changedOrder = snapshot(
      caller: <FoodItem>[food('food_a')],
      merged: <FoodItem>[food('food_a')],
      projectionQueryAudit: const <String, Object?>{
        'schema_id': 'parkinsum.cdss-food-projection-query-audit/1',
        'table_reads': <Object?>[
          <String, Object?>{
            'table': 'food_variant',
            'ordered_record_ids': <String>['variant_b', 'variant_a'],
            'rows_sha256': 'rows-ab',
          },
        ],
      },
    );

    expect(first.sha256Digest, isNot(changedRow.sha256Digest));
    expect(first.sha256Digest, isNot(changedOrder.sha256Digest));
  });

  test(
    'per-nutrient source evidence changes the candidate snapshot digest',
    () {
      final firstEvidence = observation(sourceDocId: 'doc_release_a');
      final changedEvidence = observation(sourceDocId: 'doc_release_b');
      final first = snapshot(
        caller: <FoodItem>[
          food(
            'food_evidence',
            evidence: <NutrientObservationEvidence>[firstEvidence],
          ),
        ],
        merged: <FoodItem>[
          food(
            'food_evidence',
            evidence: <NutrientObservationEvidence>[firstEvidence],
          ),
        ],
      );
      final changedSource = snapshot(
        caller: <FoodItem>[
          food(
            'food_evidence',
            evidence: <NutrientObservationEvidence>[changedEvidence],
          ),
        ],
        merged: <FoodItem>[
          food(
            'food_evidence',
            evidence: <NutrientObservationEvidence>[changedEvidence],
          ),
        ],
      );

      expect(first.sha256Digest, isNot(changedSource.sha256Digest));
      expect(
        (first.toJson()['merged_candidate_records'] as List)
            .single['nutrientObservationEvidence'],
        <Map<String, dynamic>>[firstEvidence.toJson()],
      );
    },
  );

  test('projected override and unsupported upstream metadata are explicit', () {
    final result = snapshot(
      caller: <FoodItem>[food('food_shared', name: 'caller record')],
      projected: <FoodItem>[food('food_shared', name: 'projected record')],
      merged: <FoodItem>[food('food_shared', name: 'projected record')],
    );
    final changedShadowedCallerRecord = snapshot(
      caller: <FoodItem>[food('food_shared', name: 'revised caller record')],
      projected: <FoodItem>[food('food_shared', name: 'projected record')],
      merged: <FoodItem>[food('food_shared', name: 'projected record')],
    );
    final json = result.toJson();

    expect(result.callerCandidateCount, 1);
    expect(result.projectedCandidateCount, 1);
    expect(result.mergedCandidateCount, 1);
    expect(result.mergedCandidateRecords.single['name'], 'projected record');
    expect(json['projected_override_ids'], <String>['food_shared']);
    expect(
      (json['upstream_scope']
          as Map<String, Object?>)['catalog_query_captured'],
      isFalse,
    );
    expect(
      (json['unsupported_metadata'] as Map<String, Object?>)['brand'],
      'linked_variant_scope_brand_retained_when_present',
    );
    expect(
      (json['unsupported_metadata']
          as Map<String, Object?>)['catalog_release_or_snapshot'],
      contains('payload_sha256_identifies_only_persisted_raw_payload_text'),
    );
    expect(
      (json['unsupported_metadata']
          as Map<String, Object?>)['food_match_quality'],
      contains('not_validated_match_accuracy'),
    );
    expect(
      (json['unsupported_metadata']
          as Map<
            String,
            Object?
          >)['per_nutrient_original_unit_and_denominator'],
      contains('source_unit_and_basis_retained'),
    );
    expect(
      (json['unsupported_metadata']
          as Map<String, Object?>)['quantitative_measurement_uncertainty'],
      'not_represented_by_food_item',
    );
    expect(
      result.sha256Digest,
      isNot(changedShadowedCallerRecord.sha256Digest),
    );
  });

  test(
    'built-in fallback source is identified separately from caller input',
    () {
      final fallbackFood = food('food_seed');
      final result = snapshot(
        caller: const <FoodItem>[],
        fallback: <FoodItem>[fallbackFood],
        merged: <FoodItem>[fallbackFood],
        usedFallback: true,
      );

      expect(result.callerCandidateCount, 0);
      expect(result.builtInP0FallbackUsed, isTrue);
      expect(result.toJson()['fallback_candidate_ids'], <String>['food_seed']);
      expect(result.orderedCandidateIds, <String>['food_seed']);
    },
  );

  test('duplicate merged IDs and non-finite composition fail closed', () {
    final duplicate = food('food_duplicate');
    expect(
      () => snapshot(
        caller: <FoodItem>[duplicate, duplicate],
        merged: <FoodItem>[duplicate, duplicate],
      ),
      throwsFormatException,
    );

    final nonFinite = food('food_non_finite', protein: double.nan);
    expect(
      () => snapshot(
        caller: <FoodItem>[nonFinite],
        merged: <FoodItem>[nonFinite],
      ),
      throwsFormatException,
    );
  });
}
