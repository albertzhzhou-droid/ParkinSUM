import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/utils/qualified_value_parser.dart';
import 'package:parkinsum_companion/data/datasources/remote/fdc_p0_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/p0_import_models.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_fetch_client.dart';

/// Current FoodData Central releases (checked against the 2025-04-24 full
/// download). Values marked "verbatim" come from committed source files;
/// values marked "synthetic" exist only to exercise a branch. Educational
/// prototype; nothing here is dietary advice.
void main() {
  const importer = FdcP0Importer(
    fetchClient: FakeSourceFetchClient(textByUrl: {}),
  );

  Map<String, dynamic> payload(P0ImportBundle bundle) =>
      jsonDecode(bundle.sourceDocuments.single.rawPayload)
          as Map<String, dynamic>;

  Map<String, Object?> nutrient(
    int id,
    String number,
    String name,
    String unit,
    num amount,
  ) => {
    'amount': amount,
    'nutrient': {'id': id, 'number': number, 'name': name, 'unitName': unit},
  };

  test('Foundation record: ids resolve, 2048 energy and factors are kept', () {
    // Verbatim: SR Legacy bananas (fdc 173944) protein/fat/carbohydrate/
    // fibre/energy, and the food-specific factors of the Foundation bananas
    // record sharing NDB 9040 (fdc 1105314, factor id 22733: 3.36/8.37/3.6).
    final bundle = importer.importFoods([
      {
        'fdcId': 1105314,
        'description': 'Bananas, ripe and slightly ripe, raw',
        'dataType': 'Foundation',
        'foodCategory': 'Fruits and Fruit Juices',
        'nutrientConversionFactors': [
          {
            'type': '.CalorieConversionFactor',
            'proteinValue': 3.36,
            'fatValue': 8.37,
            'carbohydrateValue': 3.6,
          },
        ],
        'foodNutrients': [
          {
            'amount': 1.09,
            'nutrient': {'id': 1003, 'name': 'Protein', 'unitName': 'g'},
          },
          {
            'amount': 0.33,
            'nutrient': {
              'id': 1004,
              'name': 'Total lipid (fat)',
              'unitName': 'g',
            },
          },
          {
            'amount': 22.84,
            'nutrient': {
              'id': 1005,
              'name': 'Carbohydrate, by difference',
              'unitName': 'g',
            },
          },
          {
            'amount': 2.6,
            'nutrient': {
              'id': 1079,
              'name': 'Fiber, total dietary',
              'unitName': 'g',
            },
          },
          {
            'amount': 89,
            'nutrient': {
              'id': 2048,
              'name': 'Energy (Atwater Specific Factors)',
              'unitName': 'kcal',
            },
          },
        ],
      },
    ], sourceLabel: 'foundation_fixture');

    final food = bundle.projectedFoods.single;
    expect(food.proteinG, 1.09);
    expect(food.carbsG, closeTo(20.24, 1e-9));
    expect(food.energyKcal, 89);
    expect(food.missingNutrientFields, isNot(contains('energyKcal')));
    expect(food.missingNutrientFields, contains('waterG'));

    final energy = bundle.observations.singleWhere(
      (o) => o.attributeCode == 'energy_kcal',
    );
    expect(
      energy.methodCode,
      FdcP0Importer.derivedEnergyFromSpecificMethodCode,
    );
    expect(energy.unit, 'kcal');
    expect(
      bundle.observations
          .where((o) => o.basisType == 'food_specific_conversion_factor')
          .map((o) => o.attributeCode),
      containsAll([
        'calorie_factor_protein_kcal_per_g',
        'calorie_factor_fat_kcal_per_g',
        'calorie_factor_carbohydrate_kcal_per_g',
      ]),
    );

    final audit =
        (payload(bundle)['composition_identity_audit'] as List).single
            as Map<String, dynamic>;
    expect(
      audit['checks_run'],
      containsAll([
        'energy_general_factors',
        'energy_specific_factors',
        'fiber_within_carbohydrate',
      ]),
    );
    // 3.36 × 1.09 + 8.37 × 0.33 + 3.6 × 22.84 = 88.65 kcal; reported 89.
    expect(audit['findings'], isEmpty);
  });

  test('a corrupted energy value is reported, never corrected', () {
    // Synthetic: the banana record with energy mistyped as 98 kcal.
    final bundle = importer.importFoods([
      {
        'fdcId': 9,
        'description': 'Synthetic banana with mistyped energy',
        'dataType': 'SR Legacy',
        'nutrientConversionFactors': [
          {
            'type': '.CalorieConversionFactor',
            'proteinValue': '3.36',
            'fatValue': '8.37',
            'carbohydrateValue': '3.6',
          },
        ],
        'foodNutrients': [
          nutrient(1003, '203', 'Protein', 'G', 1.09),
          nutrient(1004, '204', 'Total lipid (fat)', 'G', 0.33),
          nutrient(1005, '205', 'Carbohydrate, by difference', 'G', 22.84),
          nutrient(1008, '208', 'Energy', 'KCAL', 98),
        ],
      },
    ], sourceLabel: 'corrupted_fixture');
    final audit =
        (payload(bundle)['composition_identity_audit'] as List).single
            as Map<String, dynamic>;
    final codes = [
      for (final finding in audit['findings'] as List) finding['code'],
    ];
    expect(codes, contains('energy_specific_factor_residual'));
    expect(bundle.projectedFoods.single.energyKcal, 98);
  });

  test('a value in the wrong unit is rejected, not converted', () {
    final bundle = importer.importFoods([
      {
        'fdcId': 10,
        'description': 'Synthetic unit mismatch',
        'dataType': 'Foundation',
        'foodNutrients': [
          // Energy id 1008 is kcal; a kJ amount under it must not be used.
          nutrient(1008, '208', 'Energy', 'kJ', 372),
          nutrient(1062, '268', 'Energy', 'kJ', 372),
          // Microgram spelled with the micro sign is still micrograms.
          nutrient(1106, '320', 'Vitamin A, RAE', 'µg', 3),
        ],
      },
    ], sourceLabel: 'unit_fixture');
    final codes = bundle.observations.map((o) => o.attributeCode).toList();
    expect(codes, isNot(contains('energy_kcal')));
    expect(codes, containsAll(['energy_kj', 'vitamin_a_rae_ug']));
    final mismatch =
        (payload(bundle)['unit_mismatch_audit'] as List).single
            as Map<String, dynamic>;
    expect(mismatch['nutrient_id'], 1008);
    expect(mismatch['observed_unit'], 'KJ');
    expect(bundle.projectedFoods.single.energyKcal, isNull);
  });

  test('AOAC 2011.25 fibre stands in only when no 291 total exists', () {
    final bundle = importer.importFoods([
      {
        'fdcId': 11,
        'description': 'Synthetic AOAC 2011.25 fibre record',
        'dataType': 'Foundation',
        'foodNutrients': [
          nutrient(2033, '293', 'Total dietary fiber (AOAC 2011.25)', 'G', 3.1),
        ],
      },
    ], sourceLabel: 'aoac_fixture');
    final fiber = bundle.observations.singleWhere(
      (o) => o.attributeCode == 'fiber_g',
    );
    expect(fiber.value.valueNum, 3.1);
    expect(
      fiber.methodCode,
      FdcP0Importer.derivedFiberFromAoac201125MethodCode,
    );
  });

  test('Branded label nutrients stay per-serving evidence', () {
    final bundle = importer.importFoods([
      {
        'fdcId': 12,
        'description': 'SYNTHETIC BEAN DIP',
        'dataType': 'Branded',
        'gtinUpc': '00000000000000',
        'brandOwner': 'Synthetic Foods Co.',
        'ingredients': 'COOKED FAVA BEANS, WATER, OLIVE OIL, SALT.',
        'servingSize': 30.0,
        'servingSizeUnit': 'g',
        'brandedFoodCategory': 'Dips & Salsa',
        'labelNutrients': {
          'protein': {'value': 2.0},
          'sodium': {'value': 120.0},
        },
        'foodNutrients': [
          nutrient(1003, '203', 'Protein', 'G', 6.67),
          nutrient(1093, '307', 'Sodium, Na', 'MG', 400),
        ],
      },
    ], sourceLabel: 'branded_fixture');

    final labelObservations = bundle.observations
        .where((o) => o.basisType == 'per_serving_label')
        .toList();
    expect(labelObservations.map((o) => o.attributeCode).toSet(), {
      'protein_g',
      'sodium_mg',
    });
    expect(labelObservations.every((o) => o.basisAmount == 30.0), isTrue);
    // Label rows never become resolved per-100 g facts.
    final labelIds = labelObservations.map((o) => o.observationId).toSet();
    expect(
      bundle.resolvedFacts.where(
        (f) => labelIds.contains(f.chosenObservationId),
      ),
      isEmpty,
    );
    expect(bundle.projectedFoods.single.proteinG, 6.67);
    expect(bundle.projectedFoods.single.sodiumMg, 400);

    final gtin = bundle.conceptVariantCrosswalks.singleWhere(
      (c) => c.externalIdSystem == 'GTIN/UPC',
    );
    expect(gtin.externalIdValue, '00000000000000');

    final ldopa =
        (payload(bundle)['intrinsic_levodopa_ingredient_audit'] as List).single
            as Map<String, dynamic>;
    expect(ldopa['intrinsic_levodopa_source_ids'], ['vicia_faba']);
  });

  test('official CSV archive: exact file names, metadata and exclusions', () {
    // Map order puts the look-alike files first: branded_food.csv must not be
    // read as food.csv, nor food_nutrient.csv as nutrient.csv.
    final bundle = importer.importCsvArchive({
      'FoodData_Central_csv/branded_food.csv':
          '"fdc_id","brand_owner","brand_name","gtin_upc","ingredients",'
          '"serving_size","serving_size_unit","branded_food_category"\n'
          '"500","Synthetic Owner","Synthetic","00012345678905",'
          '"OATS","40.0","g","Cereal"',
      'FoodData_Central_csv/food_nutrient.csv':
          '"id","fdc_id","nutrient_id","amount"\n'
          '"1","500","1003","13.0"\n'
          '"2","600","1003","12.0"\n'
          '"3","700","1003","11.0"',
      'FoodData_Central_csv/food.csv':
          '"fdc_id","data_type","description","food_category_id"\n'
          '"500","branded_food","SYNTHETIC OATS","Cereal"\n'
          '"600","survey_fndds_food","Synthetic survey food",""\n'
          '"700","sub_sample_food","Synthetic sub-sample",""',
      'FoodData_Central_csv/nutrient.csv':
          '"id","name","unit_name","nutrient_nbr","rank"\n'
          '"1003","Protein","G","203","600.0"',
      'FoodData_Central_csv/survey_fndds_food.csv':
          '"fdc_id","food_code","wweia_category_code"\n'
          '"600","11111000","1002"',
      'FoodData_Central_csv/wweia_food_category.csv':
          '"wweia_food_category","wweia_food_category_description"\n'
          '"1002","Milk, whole"',
    }, sourceLabel: 'official_csv_fixture');

    expect(bundle.projectedFoods.map((f) => f.sourceFoodCode).toSet(), {
      '500',
      '600',
    });
    final branded = bundle.projectedFoods.singleWhere(
      (f) => f.sourceFoodCode == '500',
    );
    expect(branded.sourceSystem, 'Branded');
    expect(branded.proteinG, 13.0);
    expect(
      bundle.conceptVariantCrosswalks
          .where((c) => c.externalIdSystem == 'GTIN/UPC')
          .single
          .externalIdValue,
      '00012345678905',
    );
    expect(
      bundle.conceptVariantCrosswalks
          .where((c) => c.externalIdSystem == 'USDA WWEIA food category')
          .single
          .externalIdValue,
      '1002',
    );
    expect(
      bundle.conceptVariantCrosswalks
          .where((c) => c.externalIdSystem == 'USDA Survey food code')
          .single
          .externalIdValue,
      '11111000',
    );
    final excluded =
        (payload(bundle)['excluded_non_food_records'] as List).single
            as Map<String, dynamic>;
    expect(excluded['fdc_id'], '700');
    expect(excluded['data_type'], 'sub_sample_food');
  });

  test('CSV conversion-factor tables reach the identity audit', () {
    final bundle = importer.importCsvArchive({
      'food.csv':
          '"fdc_id","data_type","description","food_category_id"\n'
          '"321358","foundation_food","Synthetic factor fixture",""',
      'nutrient.csv':
          '"id","name","unit_name","nutrient_nbr","rank"\n'
          '"1002","Nitrogen","G","202","500.0"\n'
          '"1003","Protein","G","203","600.0"',
      'food_nutrient.csv':
          '"id","fdc_id","nutrient_id","amount"\n'
          '"1","321358","1002","1.20"\n'
          '"2","321358","1003","7.50"',
      // Verbatim ids/values: factor 22504 belongs to fdc 321358 (6.25);
      // 22509 is a published 0.0 placeholder and must be ignored.
      'food_nutrient_conversion_factor.csv':
          '"id","fdc_id"\n"22504","321358"\n"22509","321358"',
      'food_protein_conversion_factor.csv':
          '"food_nutrient_conversion_factor_id","value"\n'
          '"22504","6.25"\n"22509","0.0"',
    }, sourceLabel: 'factor_csv_fixture');
    final factor = bundle.observations.singleWhere(
      (o) => o.attributeCode == 'nitrogen_to_protein_factor',
    );
    expect(factor.value.valueNum, 6.25);
    expect(factor.value.qualifierKind, QualifierKind.exact);
    final p = payload(bundle);
    expect((p['conversion_factor_audit'] as List).single['value'], 0.0);
    final audit = (p['composition_identity_audit'] as List).single as Map;
    // 1.20 g N × 6.25 = 7.50 g protein.
    expect(audit['checks_run'], contains('nitrogen_protein_factor'));
    expect(audit['findings'], isEmpty);
  });
}
