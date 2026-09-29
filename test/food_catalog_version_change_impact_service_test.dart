import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/domain/entities/catalog_version_change_diff.dart';
import 'package:parkinsum_companion/domain/usecases/catalog_version_change_diff_service.dart';
import 'package:parkinsum_companion/domain/usecases/food_catalog_version_change_impact_service.dart';

void main() {
  test(
    'counts exact food catalog and meal-line references without exposing rows',
    () {
      final changedFood = _food('food-old', sourceFoodCode: 'OLD_A');
      final unchangedFood = _food('food-same', sourceFoodCode: 'SAME');
      final foods = <FoodItem>[
        changedFood,
        unchangedFood,
        _food(
          'food-wrong-source',
          sourceSystem: 'OTHER_FOOD',
          sourceFoodCode: 'OLD_A',
        ),
        _food(
          'food-wrong-jurisdiction',
          jurisdiction: 'CA',
          sourceFoodCode: 'OLD_A',
        ),
        _food('food-placeholder', sourceFoodCode: 'UNSPECIFIED_TEST_CODE'),
        _food('food-no-code'),
        _food('food-duplicate', sourceFoodCode: 'OLD_A'),
        _food('food-duplicate', sourceFoodCode: 'OLD_B'),
      ];
      final meals = <Meal>[
        _meal('meal-changed-and-stable', [
          MealItem.fromFood(food: changedFood, quantityFactor: 4),
          MealItem.fromFood(food: unchangedFood, quantityFactor: 1),
        ]),
        _meal('meal-nonmatching', [
          MealItem.fromFood(food: foods[2], quantityFactor: 1),
          _line('orphan-food-id'),
        ]),
        _meal('meal-duplicate-food-id', [_line('food-duplicate')]),
      ];

      final preview = const FoodCatalogVersionChangeImpactService().preview(
        diff: _foodDiff(),
        foods: foods,
        meals: meals,
      );

      expect(preview.foodCatalogEntryCount, 8);
      expect(preview.foodEntriesWithComparableSourceIdentity, 2);
      expect(preview.foodEntriesWithPotentialChangedCodeMatch, 1);
      expect(preview.foodMatchesByKind[CatalogVersionChangeKind.unresolved], 1);
      expect(preview.foodEntriesWithoutComparableSourceIdentity, 6);
      expect(preview.mealCount, 3);
      expect(preview.mealLineCount, 5);
      expect(preview.mealLinesWithComparableFoodIdentity, 2);
      expect(preview.mealLinesWithPotentialChangedCodeMatch, 1);
      expect(preview.mealsWithPotentialChangedCodeMatch, 1);
      expect(
        preview.mealLineMatchesByKind[CatalogVersionChangeKind.unresolved],
        1,
      );
      expect(preview.mealLinesWithoutComparableFoodIdentity, 3);
      expect(preview.sourceReleaseBindingAvailable, isFalse);
      expect(preview.toString(), isNot(contains('food-old')));
    },
  );

  test('holds oversized aggregate scans before inspecting rows', () {
    final foods = List<FoodItem>.filled(
      FoodCatalogVersionChangeImpactService.maxFoodEntries + 1,
      _food('fixture'),
      growable: false,
    );

    expect(
      () => const FoodCatalogVersionChangeImpactService().preview(
        diff: _foodDiff(),
        foods: foods,
        meals: const <Meal>[],
      ),
      throwsArgumentError,
    );
  });
}

CatalogVersionChangeDiff _foodDiff() {
  final previous = CatalogReleaseSnapshot(
    catalogId: 'synthetic_food_catalog',
    sourceSystem: 'TEST_FOOD',
    jurisdiction: 'US',
    releaseId: 'old',
    releaseSequence: 1,
    concepts: <CatalogConceptIdentity>[
      _concept('old', 'OLD_A'),
      _concept('old', 'OLD_B'),
      _concept('old', 'SAME'),
    ],
  );
  final current = CatalogReleaseSnapshot(
    catalogId: 'synthetic_food_catalog',
    sourceSystem: 'TEST_FOOD',
    jurisdiction: 'US',
    releaseId: 'new',
    releaseSequence: 2,
    concepts: <CatalogConceptIdentity>[
      _concept('new', 'NEW_A'),
      _concept('new', 'NEW_B'),
      _concept('new', 'SAME'),
    ],
  );
  return const CatalogVersionChangeDiffService().compare(
    previous: previous,
    current: current,
    mappingEvidence: <CatalogMappingEvidence>[],
  );
}

CatalogConceptIdentity _concept(String release, String code) =>
    CatalogConceptIdentity(
      sourceSystem: 'TEST_FOOD',
      jurisdiction: 'US',
      releaseId: release,
      code: code,
      display: '$code display',
    );

FoodItem _food(
  String id, {
  String sourceSystem = 'TEST_FOOD',
  String jurisdiction = 'US',
  String? sourceFoodCode,
}) => FoodItem(
  id: id,
  name: 'Synthetic food $id',
  category: FoodCategory.other,
  sourceSystem: sourceSystem,
  sourceFoodCode: sourceFoodCode,
  jurisdiction: jurisdiction,
  proteinG: 0,
  carbsG: 0,
  fatG: 0,
  fiberG: 0,
  sodiumMg: 0,
);

Meal _meal(String id, List<MealItem> items) => Meal(
  id: id,
  eatenAt: DateTime.utc(2026),
  title: 'Synthetic meal',
  items: items,
);

MealItem _line(String foodId) => MealItem(
  foodId: foodId,
  foodName: 'Synthetic food',
  foodCategory: FoodCategory.other,
  quantityFactor: 1,
  foodTags: const <String>[],
  proteinPer100g: 0,
  carbsPer100g: 0,
  fatPer100g: 0,
  fiberPer100g: 0,
  sodiumPer100g: 0,
);
