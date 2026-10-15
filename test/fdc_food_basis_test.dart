import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:parkinsum_companion/core/db/cdss_database_memory.dart';
import 'package:parkinsum_companion/core/db/cdss_database_web.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/data/datasources/remote/fdc_p0_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/p0_import_support.dart';
import 'package:parkinsum_companion/domain/entities/amino_acid_profile.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_fetch_client.dart';
import 'package:parkinsum_companion/domain/usecases/catalog_food_to_candidate.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_artifact_store_stub.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_catalog_projection_service.dart';
import 'package:parkinsum_companion/domain/usecases/clinical_decision_support_service.dart';
import 'package:parkinsum_companion/domain/usecases/fact_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/runtime_rule_engine.dart';

const importer = FdcP0Importer(
  fetchClient: FakeSourceFetchClient(textByUrl: {}),
);

// The old database rows are specified independently of the new importer.
class _LegacyDatabase extends InMemoryCdssDatabase {
  _LegacyDatabase(this.description, this.family, this.payloads);
  final String description;
  final String family;
  final List<Map<String, Object?>> payloads;
  @override
  Future<List<Map<String, Object?>>> queryTable(String table) async =>
      switch (table) {
        'food_variant' => [
          {
            'food_variant_id': 'legacy_variant',
            'food_concept_id': 'legacy_concept',
            'source_family': family,
            'source_food_code': '747430',
            'display_name_local': description,
          },
        ],
        'food_concept' => [
          {
            'food_concept_id': 'legacy_concept',
            'canonical_name_en': description,
          },
        ],
        'source_document' => [
          for (var i = 0; i < payloads.length; i++)
            {
              'source_doc_id': 'legacy_source_$i',
              'raw_payload': jsonEncode(payloads[i]),
            },
        ],
        'observation' => [
          for (var i = 0; i < payloads.length; i++)
            {
              'observation_id': 'legacy_observation_$i',
              'entity_key': 'legacy_variant',
              'attribute_code': 'protein_g',
              'qualifier_kind': 'exact',
              'value_num': 20.0,
              'unit': 'g',
              'basis_type': 'per_100g_edible_part',
              'basis_amount': 100,
              'source_doc_id': 'legacy_source_$i',
            },
        ],
        _ => [],
      };
}

Map<String, Object?> _basisPayload(String unit) => {
  'food_basis_evidence': [
    {
      'fdc_id': 747430,
      // The projection must recompute source fields, not trust this declaration.
      'basis_type': 'per_100g_edible_part',
      'source_fields': {
        'fdcId': 747430,
        'description': 'Synthetic branded source',
        'dataType': 'Branded',
        'servingSizeUnit': unit,
      },
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/importers/fdc_dry_matter_source_vectors_2026_04.json',
            ).readAsStringSync(),
          )
          as Map;
  final foods = (fixture['records'] as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();

  test(
    'explicit source moisture basis has no word-dry or zero-water heuristic',
    () {
      for (final description in [
        'Dry beans, raw',
        'Cooked beans',
        'Water-free oil',
      ]) {
        expect(
          FdcFoodBasis.inspect({
            'dataType': 'Foundation',
            'description': description,
            'foodNutrients': [
              {
                'nutrient': {'id': 1051},
                'amount': 0,
              },
            ],
          }).basisType,
          'per_100g_edible_part',
        );
      }
      expect(
        FdcFoodBasis.inspect({
          'dataType': 'Foundation',
          'description': 'Beans (12% moisture)',
        }).basisType,
        'per_100g_moisture_standardized',
      );
      expect(
        FdcFoodBasis.inspect({
          'dataType': 'Foundation',
          'description': 'Beans (0.0% moisture)',
        }).basisType,
        'per_100g_dry_matter',
      );
      expect(
        FdcFoodBasis.inspect({
          'dataType': 'Branded',
          'servingSizeUnit': ' g ',
        }).supportsEdibleMassPoint,
        isTrue,
      );
    },
  );

  test(
    'basis repair uses a new parse identity while ordinary source identity stays compatible',
    () {
      for (final rows in [
        foods,
        [
          <String, dynamic>{
            'fdcId': 1,
            'description': 'Synthetic ordinary food',
            'dataType': 'Foundation',
            'foodNutrients': <Object?>[],
          },
        ],
      ]) {
        final oldIdentity = sourceDocumentId(
          sourceSystem: 'FDC',
          externalKey:
              'same_label:${sha256.convert(utf8.encode(jsonEncode(rows)))}',
        );
        final bundle = importer.importFoods(rows, sourceLabel: 'same_label');
        if (identical(rows, foods)) {
          expect(bundle.sourceDocuments.single.sourceDocId, isNot(oldIdentity));
        } else {
          expect(bundle.sourceDocuments.single.sourceDocId, oldIdentity);
          expect(
            jsonDecode(bundle.sourceDocuments.single.rawPayload),
            isNot(contains('food_basis_evidence')),
          );
        }
      }
    },
  );

  test(
    'legacy wrong mass rows retain raw evidence but explicit moisture and unproven branded bases withhold',
    () async {
      for (final database in [
        _LegacyDatabase('Beans (0% moisture)', 'Foundation', [{}]),
        _LegacyDatabase('Beans (12% moisture)', 'Foundation', [{}]),
        _LegacyDatabase('Synthetic branded source', 'Branded', [{}]),
        _LegacyDatabase('Synthetic branded source', 'Branded', [
          _basisPayload('mL'),
        ]),
      ]) {
        final before = await database.queryTable('observation');
        final projection = await CdssCatalogProjectionService(
          database: database,
        ).projectFoodsWithAudit();
        final food = projection.foods.single;
        expect(food.isNutrientMissing('proteinG'), isTrue);
        expect(food.supportsEdibleMassPoint, isFalse);
        expect(food.nutrientObservationEvidence.single.valueNum, 20);
        expect(
          food
              .nutrientObservationEvidence
              .single
              .selectedForLegacyPointProjection,
          isFalse,
        );
        expect(await database.queryTable('observation'), before);
      }
    },
  );

  test(
    'linked source units are qualified from matching raw identity; unrelated fields cannot authorize grams',
    () async {
      final unrelated = _basisPayload('g');
      ((unrelated['food_basis_evidence'] as List).single['source_fields']
              as Map)['fdcId'] =
          99;
      final rejected = await CdssCatalogProjectionService(
        database: _LegacyDatabase('Synthetic branded source', 'Branded', [
          unrelated,
        ]),
      ).projectFoods();
      expect(rejected.single.isNutrientMissing('proteinG'), isTrue);
      final qualified = await CdssCatalogProjectionService(
        database: _LegacyDatabase('Synthetic branded source', 'Branded', [
          _basisPayload('g'),
        ]),
      ).projectFoods();
      expect(qualified.single.proteinG, 20);
      expect(qualified.single.isNutrientMissing('proteinG'), isFalse);
      final ambiguous = await CdssCatalogProjectionService(
        database: _LegacyDatabase('Synthetic branded source', 'Branded', [
          _basisPayload('g'),
          _basisPayload('mL'),
        ]),
      ).projectFoodsWithAudit();
      expect(ambiguous.foods.single.basisType, 'source_basis_unqualified');
      expect(
        jsonEncode(ambiguous.queryAudit),
        contains('competing_source_bases'),
      );
    },
  );

  test(
    'persisted unsupported basis cannot supply cached macros or amino acids to a new meal',
    () {
      for (final basis in [
        'per_100g_dry_matter',
        'per_100g_moisture_standardized',
        'per_100ml_product',
        'source_basis_unqualified',
      ]) {
        final cached = FoodItem.fromJson(
          FoodItem(
            id: 'cached',
            name: 'Cached source food',
            category: FoodCategory.other,
            proteinG: 20,
            carbsG: 30,
            fatG: 2,
            fiberG: 4,
            sodiumMg: 7,
            energyKcal: 210,
            waterG: 10,
            basisType: basis,
            aminoAcidProfile: const AminoAcidProfile(leucine: 5),
          ).toJson()..['missingNutrientFields'] = <String>[],
        );
        expect(cached.proteinG, 20); // Original number is retained.
        expect(cached.aminoAcidProfile!.leucine, 5);
        final candidate = foodItemToCandidateFood(cached).components.single;
        expect(candidate.proteinGrams, isNull);
        expect(candidate.calories, isNull);
        expect(candidate.aminoAcidProfile, isNull);
        final component = mealItemToFoodComponent(
          MealItem.fromFood(food: cached, quantityFactor: 2),
          componentId: 'saved',
          catalogMatch: cached,
        );
        expect(component.proteinGrams, isNull);
        expect(component.calories, isNull);
        expect(component.aminoAcidProfile, isNull);
      }
    },
  );

  test(
    '17 explicitly dry-matter source records retain their declared basis',
    () {
      final bundle = importer.importFoods(
        foods,
        sourceLabel: 'official_dry_matter_source_fields',
      );
      expect(bundle.projectedFoods, hasLength(17));
      expect(bundle.observations, isNotEmpty);
      for (final row in bundle.observations) {
        expect(row.basisType, 'per_100g_dry_matter');
        expect(row.basisAmount, 100);
      }
    },
  );

  test(
    'a dry-matter catalogue number cannot become a mass-based meal input',
    () {
      final bundle = importer.importFoods(
        foods,
        sourceLabel: 'official_dry_matter_source_fields',
      );
      for (final food in bundle.projectedFoods) {
        expect(food.isNutrientMissing('proteinG'), isTrue);
        expect(
          foodItemToCandidateFood(food).components.single.proteinGrams,
          isNull,
        );
        final logged = MealItem.fromFood(food: food, quantityFactor: 1);
        expect(logged.isNutrientMissing('proteinG'), isTrue);
        expect(
          mealItemToFoodComponent(
            logged,
            componentId: 'meal-component',
            catalogMatch: food,
          ).proteinGrams,
          isNull,
        );
      }
    },
  );

  test(
    'actual import and a fresh DB projection retain evidence without a false edible point',
    () async {
      final bundle = importer.importFoods(
        foods,
        sourceLabel: 'official_dry_matter_source_fields',
      );
      final database = WebCdssDatabase();
      await ClinicalDecisionSupportService(
        database: database,
        factConflictEngine: FactConflictEngine(),
        runtimeRuleEngine: RuntimeRuleEngine(),
        artifactStore: InlineCdssArtifactStore(),
      ).importBundle(bundle);
      final projected = await CdssCatalogProjectionService(
        database: WebCdssDatabase(),
      ).projectFoods();
      expect(projected, hasLength(17));
      for (final food in projected) {
        expect(food.isNutrientMissing('proteinG'), isTrue);
        expect(food.basisType, 'per_100g_dry_matter');
        expect(food.nutrientObservationEvidence, isNotEmpty);
        expect(
          food.nutrientObservationEvidence.every(
            (row) => !row.selectedForLegacyPointProjection,
          ),
          isTrue,
        );
      }
    },
  );

  test(
    'branded mL, missing-unit and unrecognized-unit values are not edible-gram points',
    () {
      for (final unit in ['mL', '', 'fl oz']) {
        final bundle = importer.importFoods([
          {
            'fdcId': 999,
            'description': 'Synthetic branded source',
            'dataType': 'Branded',
            'servingSize': 30,
            'servingSizeUnit': unit,
            'foodNutrients': [
              {
                'id': 1,
                'amount': 5,
                'nutrient': {
                  'id': 1003,
                  'number': '203',
                  'name': 'Protein',
                  'unitName': 'g',
                },
              },
            ],
          },
        ], sourceLabel: 'synthetic_branded_basis');
        expect(
          bundle.projectedFoods.single.isNutrientMissing('proteinG'),
          isTrue,
        );
        expect(bundle.observations.single.value.valueNum, 5);
      }
    },
  );
}
