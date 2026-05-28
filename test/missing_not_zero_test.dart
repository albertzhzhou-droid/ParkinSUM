import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/domain/entities/amino_acid_profile.dart';
import 'package:parkinsum_companion/domain/usecases/catalog_food_to_candidate.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';

/// Guards Obj 2/3/8: missing source data must stay MISSING (unknown), never be
/// flattened into a fabricated true 0 g. A FoodItem that declares a nutrient
/// field as missing must pass null (not 0) into the FoodComponent, which the
/// normalizer must then record in `missingFields` and reflect in a lowered
/// `compositionCompleteness`.
void main() {
  final normalizer = MealCompositionNormalizer();

  FoodItem itemWith({
    Set<String> missing = const <String>{},
    double? energyKcal,
    AminoAcidProfile? aa,
  }) =>
      FoodItem(
        id: 'f1',
        name: 'projected food',
        category: FoodCategory.protein,
        proteinG: 0, // legacy non-nullable default — must NOT leak as a true 0
        carbsG: 0,
        fatG: 0,
        fiberG: 0,
        sodiumMg: 0,
        missingNutrientFields: missing,
        energyKcal: energyKcal,
        aminoAcidProfile: aa,
      );

  test('missing protein -> component protein is null (not 0)', () {
    final candidate = foodItemToCandidateFood(
      itemWith(missing: {'proteinG', 'fatG', 'fiberG', 'carbsG', 'energyKcal'}),
    );
    final c = candidate.components.single;
    expect(c.proteinGrams, isNull);
    expect(c.fatGrams, isNull);
    expect(c.fiberGrams, isNull);
    expect(c.carbohydrateGrams, isNull);
    expect(c.calories, isNull);
  });

  test('present field with real 0 stays 0 (true zero preserved)', () {
    // protein NOT in missing set -> the actual stored value (0) is a real 0.
    final candidate = foodItemToCandidateFood(
      itemWith(missing: {'fatG', 'fiberG', 'carbsG', 'energyKcal'}),
    );
    expect(candidate.components.single.proteinGrams, 0);
  });

  test(
      'missing fields flow to MealComposition.missingFields + lower completeness',
      () {
    final candidate = foodItemToCandidateFood(
      itemWith(missing: {'proteinG', 'fatG', 'fiberG', 'carbsG', 'energyKcal'}),
    );
    final comp = normalizer.normalize(
      mealId: 'm',
      components: candidate.components,
      declaredPhysicalForm: candidate.declaredPhysicalForm,
    );
    expect(comp.missingFields, contains('protein_grams'));
    expect(comp.missingFields, contains('total_calories'));
    expect(comp.compositionCompleteness, lessThan(1.0));
    expect(comp.proteinGrams, isNull);
    expect(comp.totalCalories, isNull);
  });

  test('energyKcal carried through to component calories when present', () {
    final candidate = foodItemToCandidateFood(
      itemWith(missing: {'fatG', 'fiberG', 'carbsG'}, energyKcal: 180),
    );
    expect(candidate.components.single.calories, 180);
  });

  test('aminoAcidProfile is attached to the component when present', () {
    const aa = AminoAcidProfile(leucine: 2.1, valine: 1.3);
    final candidate = foodItemToCandidateFood(itemWith(aa: aa));
    expect(candidate.components.single.aminoAcidProfile, same(aa));
  });

  test('FoodItem JSON round-trip preserves missingNutrientFields (not 0)', () {
    final item = itemWith(
      missing: {'proteinG', 'energyKcal'},
      energyKcal: null,
      aa: const AminoAcidProfile(leucine: 2.1),
    );
    final restored = FoodItem.fromJson(item.toJson());
    expect(restored.missingNutrientFields, contains('proteinG'));
    expect(restored.missingNutrientFields, contains('energyKcal'));
    expect(restored.aminoAcidProfile, isNotNull);
    expect(restored.aminoAcidProfile!.leucine, 2.1);
  });
}
