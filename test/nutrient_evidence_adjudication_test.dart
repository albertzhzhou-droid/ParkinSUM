import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/baseline_cdss_rules.dart';
import 'package:parkinsum_companion/core/db/cdss_database_memory.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/data/datasources/remote/fdc_p0_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_fetch_client.dart';
import 'package:parkinsum_companion/domain/entities/runtime_context.dart';
import 'package:parkinsum_companion/domain/entities/rule_registry_models.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_catalog_projection_service.dart';
import 'package:parkinsum_companion/domain/usecases/clinical_decision_support_service.dart';
import 'package:parkinsum_companion/domain/usecases/database_backed_meal_check_usecase.dart';
import 'package:parkinsum_companion/domain/usecases/fact_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/qualified_nutrient_point_selection.dart';
import 'package:parkinsum_companion/domain/usecases/rule_registry_compiler.dart';
import 'package:parkinsum_companion/domain/usecases/runtime_rule_engine.dart';
import 'package:parkinsum_companion/domain/usecases/variant_resolver.dart';

// Expectations are authored from the provenance contract and W17 field table.
// This synthetic row is not a downloaded source response or a biological mean.
Map<String, Object?> _row(String id) => {
  'observation_id': id,
  'entity_key': 'v1',
  'domain': 'food',
  'entity_type': 'food_variant',
  'attribute_code': 'protein_g',
  'qualifier_kind': 'exact',
  'value_type': 'numeric_interval',
  'value_num': 20,
  'low': 20,
  'high': 20,
  'unit': 'g',
  'basis_type': 'per_100g_edible_part',
  'basis_amount': 100,
  'source_doc_id': 'doc',
  'scope_hash': 'scope',
  'method_code': 'synthetic_method',
  'record_locator': '123:protein_g:summary:food_nutrient:77',
  'raw_value_text': '20',
};

List<Map<String, Object?>> _observationRows(dynamic bundle) => [
  for (final observation in bundle.observations)
    {
      'observation_id': observation.observationId,
      'entity_key': observation.entityKey,
      'attribute_code': observation.attributeCode,
      'value_type': observation.valueType,
      'value_num': observation.value.valueNum,
      'low': observation.value.low,
      'high': observation.value.high,
      'qualifier_kind': observation.value.qualifierKind.wireValue,
      'raw_value_text': observation.value.rawValueText,
      'unit': observation.unit,
      'basis_type': observation.basisType,
      'basis_amount': observation.basisAmount,
      'source_doc_id': observation.sourceDocId,
      'scope_hash': observation.scopeHash,
      'method_code': observation.methodCode,
      'record_locator': observation.recordLocator,
    },
];

class _Database extends InMemoryCdssDatabase {
  _Database(this.rows);
  final List<Map<String, Object?>> rows;
  @override
  Future<List<Map<String, Object?>>> queryTable(String table) async =>
      switch (table) {
        'observation' => rows,
        'food_variant' => [
          {
            'food_variant_id': 'v1',
            'food_concept_id': 'c1',
            'jurisdiction': 'US',
            'source_family': 'USDA_FDC',
            'source_food_code': 'food_chicken_breast',
            'display_name_local': 'Synthetic evidence food',
            'is_authoritative_for_region': 1,
          },
        ],
        'food_concept' => [
          {
            'food_concept_id': 'c1',
            'canonical_name_en': 'Synthetic evidence food',
            'food_group': 'other',
          },
        ],
        'source_document' => [
          {
            'source_doc_id': 'doc',
            'source_name': 'synthetic_provenance_fixture',
            'source_version': '1',
            'raw_payload': '{}',
          },
        ],
        'variant_scope' => [
          {'scope_hash': 'scope', 'jurisdiction': 'US'},
        ],
        'drug_product_variant' => [
          {
            'drug_product_variant_id': 'drug_v',
            'drug_concept_id': 'drug_c',
            'jurisdiction': 'US',
            'regulator': 'DAILYMED',
            'external_product_code': 'drug_levodopa_carbidopa',
            'route': 'oral',
            'dosage_form': 'tablet',
            'release_type': 'immediate',
          },
        ],
        _ => [],
      };
}

class _CaptureRuntime extends RuntimeRuleEngine {
  final contexts = <UnifiedRuntimeContext>[];
  @override
  List<RuleEvaluationCandidate> evaluateCandidates({
    required UnifiedRuntimeContext context,
    required List<RuleRegistryEntry> rules,
    List<Map<String, Object?>> regionJurisdictionRows = const [],
  }) {
    contexts.add(context);
    return super.evaluateCandidates(
      context: context,
      rules: rules,
      regionJurisdictionRows: regionJurisdictionRows,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const importer = FdcP0Importer(
    fetchClient: FakeSourceFetchClient(textByUrl: {}),
  );
  Map<String, dynamic> food(List<Map<String, dynamic>> rows, {int id = 123}) =>
      {
        'fdcId': id,
        'description': 'Synthetic adjudication fixture',
        'dataType': 'Foundation',
        'foodNutrients': rows,
      };
  Map<String, dynamic> nutrient() => {
    'id': 77,
    'amount': 20,
    'foodNutrientDerivation': {'code': 'synthetic_method'},
    'nutrient': {
      'id': 1003,
      'number': '203',
      'name': 'Protein',
      'unitName': 'g',
    },
  };
  Map<String, dynamic> sourcePayload(dynamic bundle) =>
      jsonDecode(bundle.sourceDocuments.single.rawPayload)
          as Map<String, dynamic>;

  test('proven duplicate retains occurrences and stable representative', () {
    final a = _row('a');
    final z = _row('z');
    for (final rows in [
      [a, z],
      [z, a],
    ]) {
      final selected = selectQualifiedNutrientPoints(
        rows,
      ).points['v1']!['protein_g']!;
      expect(selected.value, 20);
      expect(selected.supportingRowIndexes, hasLength(2));
      expect(rows[selected.rowIndex]['observation_id'], 'a');
    }
  });

  test('explicit sample equality is required even with a summary locator', () {
    final a = _row('a')..['sample_id'] = 'sample_a';
    final b = _row('b')..['sample_id'] = 'sample_b';
    expect(selectQualifiedNutrientPoints([a, b]).points, isEmpty);
    b['sample_id'] = 'sample_a';
    expect(
      selectQualifiedNutrientPoints([b, a]).points['v1']!['protein_g']!.value,
      20,
    );
    b.remove('sample_id');
    expect(selectQualifiedNutrientPoints([a, b]).points, isEmpty);
  });

  for (final field in [
    'source_doc_id',
    'scope_hash',
    'method_code',
    'record_locator',
    'unit',
    'basis_type',
    'basis_amount',
    'value_num',
    'low',
    'high',
    'value_type',
  ]) {
    test('incompatible $field cannot consolidate duplicate points', () {
      final a = _row('a');
      final b = _row('b')
        ..[field] = field == 'value_num' || field == 'low' || field == 'high'
            ? 21
            : field == 'basis_amount'
            ? 99
            : 'different';
      for (final rows in [
        [a, b],
        [b, a],
      ]) {
        expect(selectQualifiedNutrientPoints(rows).points, isEmpty);
      }
    });
  }

  test('missing proof does not consolidate ordinary legacy duplicates', () {
    for (final field in [
      'method_code',
      'record_locator',
      'scope_hash',
      'unit',
      'basis_type',
    ]) {
      final a = _row('a')..remove(field);
      final b = _row('b')..remove(field);
      expect(selectQualifiedNutrientPoints([a, b]).points, isEmpty);
      expect(
        selectQualifiedNutrientPoints([a]).points['v1']!['protein_g']!.value,
        20,
      );
    }
  });

  test(
    'primary censored or missing evidence still competes with exact duplicates',
    () {
      for (final qualifier in ['lt', 'gt', 'missing', 'range']) {
        final primary = _row('c')
          ..addAll({'qualifier_kind': qualifier, 'value_num': null});
        final rows = [_row('a'), _row('b'), primary];
        for (final order in [rows, rows.reversed.toList()]) {
          expect(selectQualifiedNutrientPoints(order).points, isEmpty);
        }
      }
    },
  );

  test(
    'proven repeated FDC summary maps to one fact and retains both origins',
    () {
      final row = nutrient();
      final bundle = importer.importFoods([
        food([row, Map<String, dynamic>.from(row)]),
      ], sourceLabel: 'synthetic_proven_duplicate');
      expect(bundle.observations, hasLength(2));
      expect(
        bundle.observations.map((o) => o.observationId).toSet(),
        hasLength(2),
      );
      expect(bundle.resolvedFacts, hasLength(1));
      expect(bundle.projectedFoods.single.proteinG, 20);
      final selected = selectQualifiedNutrientPoints(_observationRows(bundle));
      expect(selected.points.values.single['protein_g']!.value, 20);
      expect(
        selected.points.values.single['protein_g']!.supportingRowIndexes,
        hasLength(2),
      );
    },
  );

  test('FDC row IDs, methods, sample details and statistics must match', () {
    final mutations = <void Function(Map<String, dynamic>)>[
      (r) => r['id'] = 78,
      (r) => r.remove('id'),
      (r) => r['foodNutrientDerivation'] = {'code': 'different'},
      (r) => r['nutrientAnalysisDetails'] = [
        {'subSampleId': 999},
      ],
      (r) => r['median'] = 19,
      (r) => r['amount'] = 21,
      (r) => r['amount'] = null,
      (r) => r['amount'] = -1,
      (r) => r['amount'] = 'NaN',
      (r) => (r['nutrient'] as Map)['unitName'] = 'mg',
    ];
    for (final mutate in mutations) {
      final a = nutrient();
      final b = nutrient();
      mutate(b);
      for (final rows in [
        [a, b],
        [b, a],
      ]) {
        final bundle = importer.importFoods([
          food(rows),
        ], sourceLabel: 'synthetic_conflict');
        expect(
          bundle.projectedFoods.single.isNutrientMissing('proteinG'),
          isTrue,
        );
        expect(bundle.resolvedFacts, isEmpty);
        expect(
          selectQualifiedNutrientPoints(_observationRows(bundle)).points,
          isEmpty,
          reason:
              'Per-row equal scalar values cannot erase unresolved source samples/statistics.',
        );
      }
    }
  });

  test(
    'one surviving unresolved observation stays held in actual catalog projection',
    () async {
      final a = nutrient();
      final invalidPeer = nutrient()..['amount'] = -1;
      final bundle = importer.importFoods([
        food([a, invalidPeer]),
      ], sourceLabel: 'synthetic_invalid_duplicate_peer');
      expect(bundle.observations, hasLength(1));
      expect(bundle.resolvedFacts, isEmpty);
      final observation = _observationRows(bundle).single;
      expect(
        observation['record_locator'],
        contains(':unresolved:food_nutrient:'),
      );
      expect(selectQualifiedNutrientPoints([observation]).points, isEmpty);
      final catalogRow = {...observation, 'entity_key': 'v1'};
      final projected = await CdssCatalogProjectionService(
        database: _Database([catalogRow]),
      ).projectFoods();
      expect(projected.single.isNutrientMissing('proteinG'), isTrue);
      expect(
        projected
            .single
            .nutrientObservationEvidence
            .single
            .selectedForLegacyPointProjection,
        isFalse,
      );
      final audit = sourcePayload(bundle)['nutrient_value_audit'] as List;
      expect(
        audit.any((row) => row['reason'] == 'invalid_nutrient_value'),
        isTrue,
      );
      expect(
        audit.any((row) => row['reason'] == 'duplicate_nutrient_attribute'),
        isTrue,
      );
    },
  );

  test(
    'real extracted below-LOQ summaries preserve unverified scope and original values',
    () {
      final corpus =
          jsonDecode(
                File(
                  'test/fixtures/public_source_small_corpus/extracted_fields.json',
                ).readAsStringSync(),
              )
              as Map;
      final cases = corpus['cases'] as List;
      final f07 =
          (cases.singleWhere((c) => c['case_id'] == 'F07') as Map)['excerpt']
              as Map;
      final f09 =
          ((cases.singleWhere((c) => c['case_id'] == 'F09') as Map)['excerpt']
                  as Map)['gamma_summary']
              as Map;
      for (final excerpt in [f07, f09]) {
        // Reconstruct only verified fields. No fabricated method or missing samples.
        final bundle = importer.importFoods([
          food([
            {
              'id': excerpt['foodNutrientId'],
              'amount': excerpt['amount'],
              'loq': excerpt['loq'],
              'nutrient': {
                'id': excerpt['nutrientId'],
                'unitName': excerpt['unit'],
              },
            },
          ]),
        ], sourceLabel: 'reconstructed_public_field_excerpt');
        final summary =
            (sourcePayload(bundle)['source_nutrient_summaries'] as List).single
                as Map;
        expect(summary['reported_amount'], excerpt['amount']);
        expect(summary['reported_loq'], excerpt['loq']);
        expect(
          summary['quantification_status'],
          'point_held_quantification_scope_unverified',
        );
        expect(summary['complete_sample_mean_verified'], isFalse);
        expect(summary['sample_fields'], isEmpty);
        expect(bundle.resolvedFacts, isEmpty);
      }
    },
  );

  test(
    'summary and explicit sample amounts, LOQs and method remain separate',
    () {
      final bundle = importer.importFoods([
        food([
          {
            'id': 27793959,
            'amount': '3.619',
            'loq': '2.49',
            'median': '0',
            'dataPoints': 8,
            'nutrient': {
              'id': 1093,
              'number': '307',
              'name': 'Sodium, Na',
              'unitName': 'mg',
            },
            'nutrientAnalysisDetails': [
              {
                'subSampleId': 2261492,
                'nutrientId': 1093,
                'amount': '0',
                'loq': '2.47',
                'labMethodTechnique': 'ICP',
                'labMethodDescription': 'AOAC 985.01 + 984.27',
              },
            ],
          },
        ], id: 2261421),
      ], sourceLabel: 'reconstructed_public_field_excerpt');
      final summary =
          (sourcePayload(bundle)['source_nutrient_summaries'] as List).single
              as Map;
      expect(summary['reported_amount'], '3.619');
      expect(summary['reported_loq'], '2.49');
      final sample = (summary['sample_fields'] as List).single as Map;
      expect(sample['subSampleId'], 2261492);
      expect(sample['amount'], '0');
      expect(sample['loq'], '2.47');
      expect(sample['labMethodDescription'], 'AOAC 985.01 + 984.27');
      expect(bundle.projectedFoods.single.sodiumMg, 3.619);
    },
  );

  test('reported zero keeps precision unknown in retained provenance', () {
    final bundle = importer.importFoods([
      food([nutrient()..['amount'] = 0]),
    ], sourceLabel: 'synthetic_reported_zero');
    final summary =
        (sourcePayload(bundle)['source_nutrient_summaries'] as List).single
            as Map;
    expect(
      summary['quantification_status'],
      'reported_zero_precision_unverified',
    );
    expect(summary['complete_sample_mean_verified'], isFalse);
    expect(bundle.projectedFoods.single.proteinG, 0);
  });

  test(
    'actual catalog projection selects proven point and preserves all evidence',
    () async {
      for (final rows in [
        [_row('z'), _row('a')],
        [_row('a'), _row('z')],
      ]) {
        final result = await CdssCatalogProjectionService(
          database: _Database(rows),
        ).projectFoods();
        expect(result.single.proteinG, 20);
        expect(result.single.isNutrientMissing('proteinG'), isFalse);
        expect(result.single.nutrientObservationEvidence, hasLength(2));
        expect(
          result.single.nutrientObservationEvidence
              .where((e) => e.selectedForLegacyPointProjection)
              .single
              .observationId,
          'a',
        );
      }
    },
  );

  test(
    'actual meal checker consumes the same point and withholds incompatible evidence',
    () async {
      final at = DateTime.utc(2026, 1, 1, 9);
      for (final scenario in [
        'proven',
        'incompatible_method',
        'surviving_unresolved',
      ]) {
        final incompatible = scenario != 'proven';
        final a = _row('a');
        final b = _row('b');
        if (incompatible) b['method_code'] = 'other_method';
        if (scenario == 'surviving_unresolved') {
          a['record_locator'] = '123:protein_g:unresolved:food_nutrient:77';
        }
        for (final ordering in [
          if (scenario == 'surviving_unresolved') [a] else [a, b],
          if (scenario == 'surviving_unresolved') [a] else [b, a],
        ]) {
          final db = _Database(ordering);
          final runtime = _CaptureRuntime();
          final checker = DatabaseBackedMealCheckUseCase(
            variantResolver: VariantResolver(database: db),
            clinicalDecisionSupportService: ClinicalDecisionSupportService(
              database: db,
              factConflictEngine: FactConflictEngine(),
              runtimeRuleEngine: runtime,
            ),
            compiledRules: RuleRegistryCompiler().compileJsonList(
              baselineCdssRules,
              rulesVersion: 'synthetic_adjudication',
            ),
          );
          final result = await checker(
            meal: Meal(
              id: 'meal',
              title: 'Synthetic meal',
              eatenAt: at,
              items: [
                MealItem(
                  foodId: 'food_chicken_breast',
                  foodName: 'Synthetic food',
                  foodCategory: FoodCategory.protein,
                  quantityFactor: 1,
                  foodTags: const [],
                  proteinPer100g: 99,
                  carbsPer100g: 0,
                  fatPer100g: 0,
                  fiberPer100g: 0,
                  sodiumPer100g: 0,
                ),
              ],
            ),
            activeDrugs: [
              DrugDefinition(
                id: 'drug_levodopa_carbidopa',
                genericName: 'Levodopa/Carbidopa',
                brandNames: [],
                tags: [DrugTag.levodopaLike],
                notes: '',
              ),
            ],
            intakes: [
              Intake(
                id: 'dose',
                drugId: 'drug_levodopa_carbidopa',
                takenAt: at.subtract(const Duration(minutes: 20)),
                dosageNote: '',
              ),
            ],
            userProfile: UserProfile.defaults().copyWith(
              displayLocale: 'en-US',
            ),
            now: at,
          );
          expect(
            runtime.contexts.single.meal!.totalProteinG,
            incompatible ? 0 : 20,
          );
          expect(
            runtime.contexts.single.meal!.proteinEvidenceMissing,
            incompatible,
          );
          expect(
            result.scoreFactors
                .map((f) => f.code)
                .contains('protein_timing_penalty'),
            !incompatible,
          );
          if (incompatible) {
            expect(
              result.keyFindings.any((i) => i.startsWith('Require review')),
              isTrue,
            );
          }
        }
      }
    },
  );
}
