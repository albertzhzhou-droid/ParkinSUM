import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/domain/entities/amino_acid_profile.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/catalog_food_to_candidate.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';

/// Guards #1: historical meals are componentized (one FoodComponent per
/// MealItem) and enriched from catalog FoodItem data — instead of collapsing
/// into a single `unknown` aggregate with null calories/portion. Missing
/// catalog data stays null (never silently 0).
void main() {
  final normalizer = MealCompositionNormalizer();

  MealItem item(String foodId, String name, FoodCategory cat, double qf,
          {double protein = 0,
          double fat = 0,
          double fiber = 0,
          double carbs = 0}) =>
      MealItem(
        foodId: foodId,
        foodName: name,
        foodCategory: cat,
        quantityFactor: qf,
        foodTags: const [],
        proteinPer100g: protein,
        carbsPer100g: carbs,
        fatPer100g: fat,
        fiberPer100g: fiber,
        sodiumPer100g: 0,
      );

  FoodItem catalogFood(
    String id,
    String name, {
    String? texture,
    double? energyKcal,
    AminoAcidProfile? aa,
    String sourceSystem = 'USDA_FDC',
  }) =>
      FoodItem(
        id: id,
        name: name,
        category: FoodCategory.protein,
        sourceSystem: sourceSystem,
        textureClass: texture,
        energyKcal: energyKcal,
        aminoAcidProfile: aa,
        proteinG: 0,
        carbsG: 0,
        fatG: 0,
        fiberG: 0,
        sodiumMg: 0,
      );

  test('catalog-backed item recovers physical form, scaled calories + AA', () {
    final catalog = catalogFood(
      'f_chicken',
      'chicken breast',
      texture: 'solid',
      energyKcal: 165, // per 100g
      aa: const AminoAcidProfile(leucine: 2.0, valine: 1.0, basis: 'per_100g'),
    );
    final c = mealItemToFoodComponent(
      item('f_chicken', 'chicken breast', FoodCategory.protein, 1.5,
          protein: 31),
      componentId: 'mi_0',
      catalogMatch: catalog,
    );
    expect(c.physicalForm, MealPhysicalForm.solid);
    expect(c.portionGrams, 150); // 1.5 * 100
    expect(c.proteinGrams, closeTo(46.5, 1e-9)); // 31 * 1.5
    expect(c.calories, closeTo(247.5, 1e-9)); // 165 * 1.5
    // Amino-acid profile scaled to the 150 g serving (per_100g → per_serving).
    expect(c.aminoAcidProfile, isNotNull);
    expect(c.aminoAcidProfile!.basis, 'per_serving');
    expect(c.aminoAcidProfile!.leucine, closeTo(3.0, 1e-9)); // 2.0 * 1.5
    expect(c.sourceDocId, 'USDA_FDC');
  });

  test('no catalog match keeps form unknown + calories null (not 0)', () {
    final c = mealItemToFoodComponent(
      item('f_unknown', 'mystery dish', FoodCategory.other, 1.0, protein: 5),
      componentId: 'mi_x',
      catalogMatch: null,
    );
    expect(c.physicalForm, MealPhysicalForm.unknown);
    expect(c.calories, isNull); // missing ≠ zero
    expect(c.aminoAcidProfile, isNull);
    expect(c.portionGrams, 100);
    expect(c.proteinGrams, 5);
    expect(c.sourceDocId, 'meal_history');
  });

  test('catalog match without energy leaves calories null', () {
    final c = mealItemToFoodComponent(
      item('f_noenergy', 'soup', FoodCategory.other, 2.0),
      componentId: 'mi_1',
      catalogMatch: catalogFood('f_noenergy', 'soup', texture: 'liquid'),
    );
    expect(c.physicalForm, MealPhysicalForm.liquid);
    expect(c.calories, isNull); // catalog lacked energyKcal → unknown, not 0
  });

  test('multi-item meal → mixed composition, not a single unknown aggregate',
      () {
    final liquid = mealItemToFoodComponent(
      item('f_juice', 'orange juice', FoodCategory.beverage, 2.0, carbs: 10),
      componentId: 'mi_a',
      catalogMatch: catalogFood('f_juice', 'orange juice',
          texture: 'liquid', energyKcal: 45),
    );
    final solid = mealItemToFoodComponent(
      item('f_steak', 'steak', FoodCategory.protein, 1.5, protein: 26, fat: 15),
      componentId: 'mi_b',
      catalogMatch:
          catalogFood('f_steak', 'steak', texture: 'solid', energyKcal: 271),
    );
    final comp = normalizer.normalize(
      mealId: 'comp_meal1',
      components: [liquid, solid],
    );
    expect(comp.foodComponents.length, 2); // componentized, NOT aggregated
    expect(comp.mealPhysicalForm, MealPhysicalForm.mixed);
    // Calories aggregate across both items (catalog-derived, present).
    expect(comp.totalCalories, isNotNull);
    expect(comp.liquidFraction, isNotNull);
    // Liquid fraction by mass: 200 g juice / (200 + 150) g.
    expect(comp.liquidFraction, closeTo(200 / 350, 1e-9));
    expect(comp.missingFields, isNot(contains('total_calories')));
  });
}
