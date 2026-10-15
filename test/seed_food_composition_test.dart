import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/seed_food_composition_table.dart';
import 'package:parkinsum_companion/data/datasources/remote/regional_seed_catalog_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/seed_catalog_importer.dart';
import 'package:parkinsum_companion/domain/entities/seed_food_composition.dart';
import 'package:parkinsum_companion/domain/usecases/food_composition_interdependency_model.dart';

import '../tool/seed_food_composition_codegen.dart';

/// Seed catalog foods carry USDA FoodData Central values verbatim, or no
/// values at all. Educational prototype; values describe foods, not people.
void main() {
  final sr = parseSrSubset(File(seedSrSubsetPath).readAsStringSync());
  final fndds = parseFnddsSubset(
    File(seedFnddsFoodPath).readAsStringSync(),
    File(seedFnddsNutrientPath).readAsStringSync(),
  );
  final mapping =
      (jsonDecode(File(seedSourcesJsonPath).readAsStringSync())
              as Map<String, dynamic>)['foods']
          as Map<String, dynamic>;
  final seedFoods = [
    ...const SeedCatalogImporter().importSeedCatalog().projectedFoods,
    ...const RegionalSeedCatalogImporter()
        .importRegionalSeedCatalog()
        .projectedFoods,
  ];

  test('committed source subsets keep their verified bytes', () {
    const pinned = {
      seedSrSubsetPath:
          'eeb1319acc3818398a48a8bc2b028a67b619b1aee2ea16652659d97011ce5db5',
      seedFnddsFoodPath:
          'e850979e87dc44c79665dbf3bc06df36d26d53d8ee78eb30e66c7a3fbc8d0fce',
      seedFnddsNutrientPath:
          '2e828290a36f70c058b403f98ad92355ebdf66fbe996d56f3bb47d1c549fbd1d',
    };
    for (final entry in pinned.entries) {
      expect(
        sha256.convert(File(entry.key).readAsBytesSync()).toString(),
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('every generated value equals its source record', () {
    expect(seedFoodCompositions, hasLength(142));
    expect(seedFoodUnmatchedReasons, hasLength(44));
    for (final entry in seedFoodCompositions.entries) {
      final composition = entry.value;
      final record = composition.source == SeedCompositionSource.srLegacy2018
          ? sr[composition.fdcId]
          : fndds[composition.fdcId];
      expect(record, isNotNull, reason: entry.key);
      expect(composition.sourceDescription, record!.description);
      expect(composition.energyKcal, record.values['energyKcal']);
      expect(composition.proteinG, record.values['proteinG']);
      expect(composition.fatG, record.values['fatG']);
      expect(
        composition.carbohydrateByDifferenceG,
        record.values['carbohydrateByDifferenceG'],
      );
      expect(composition.fiberG, record.values['fiberG']);
      expect(composition.sodiumMg, record.values['sodiumMg']);
      expect(composition.waterG, record.values['waterG']);
      final spec = mapping[entry.key] as Map<String, dynamic>;
      expect(composition.fdcId, spec['fdc_id']);
      expect(composition.match.name, spec['match']);
    }
  });

  test('every seed food is mapped or explicitly unknown', () {
    final ids = seedFoods.map((f) => f.id).toSet();
    expect(ids, hasLength(186));
    expect(mapping.keys.toSet(), ids);
    for (final food in seedFoods) {
      final composition = seedFoodCompositions[food.id];
      if (composition == null) {
        expect(seedFoodUnmatchedReasons[food.id], isNotEmpty, reason: food.id);
        expect(
          food.missingNutrientFields,
          containsAll(['proteinG', 'carbsG', 'fatG', 'fiberG', 'sodiumMg']),
          reason: food.id,
        );
        continue;
      }
      expect(food.description, contains('${composition.fdcId}'));
      if (composition.proteinG != null) {
        expect(food.proteinG, composition.proteinG, reason: food.id);
      }
      final available = composition.availableCarbohydrateG;
      if (available == null) {
        expect(food.missingNutrientFields, contains('carbsG'));
      } else {
        expect(food.carbsG, closeTo(available, 1e-9), reason: food.id);
      }
      expect(food.energyKcal, composition.energyKcal);
    }
  });

  test('a seed food reads its USDA values, not an estimate', () {
    final banana = seedFoods.singleWhere((f) => f.id == 'seed_banana');
    expect(banana.proteinG, 1.09);
    expect(banana.carbsG, closeTo(20.24, 1e-9));
    expect(banana.energyKcal, 89.0);
    final pho = seedFoods.singleWhere((f) => f.id == 'seed_sea_pho');
    expect(pho.description, contains('FNDDS 2017-2018'));
    expect(pho.waterG, isNotNull);
    final tremella = seedFoods.singleWhere(
      (f) => f.id == 'seed_cn_white_fungus',
    );
    expect(tremella.energyKcal, isNull);
  });

  test('matched records satisfy the general energy identity', () {
    final inconsistent = <String>[];
    for (final entry in seedFoodCompositions.entries) {
      final c = entry.value;
      final audit = auditCompositionIdentities(
        FoodCompositionIdentityInput(
          recordId: entry.key,
          description: c.sourceDescription,
          values: {
            'energy_kcal': ?c.energyKcal,
            'protein_g': ?c.proteinG,
            'fat_g': ?c.fatG,
            'carbohydrate_by_difference_g': ?c.carbohydrateByDifferenceG,
            'fiber_g': ?c.fiberG,
            'water_g': ?c.waterG,
          },
        ),
      );
      if (!audit.isConsistent) {
        inconsistent.add(
          '${entry.key} ${c.sourceDescription}: '
          '${audit.findings.map((f) => f.detail).join('; ')}',
        );
      }
    }
    expect(inconsistent, isEmpty, reason: inconsistent.join('\n'));
  });
}
