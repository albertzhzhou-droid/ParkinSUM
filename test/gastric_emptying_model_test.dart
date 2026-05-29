import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/gastric_emptying_profile.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/gastric_emptying_model.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';

/// Guards #2: the component-level gastric model distinguishes liquid vs solid
/// emptying and widens uncertainty for high-fat and high-calorie meals (in
/// addition to the existing fiber/overlap boosts). Magnitudes are prototype
/// heuristics; only direction + uncertainty behavior are asserted.
void main() {
  final normalizer = MealCompositionNormalizer();
  final model = GastricEmptyingModel();

  const order = [
    UncertaintyBand.narrow,
    UncertaintyBand.moderate,
    UncertaintyBand.wide,
    UncertaintyBand.veryWide,
  ];
  int bandIndex(UncertaintyBand b) => order.indexOf(b);

  FoodComponent component({
    required String id,
    required MealPhysicalForm form,
    required double protein,
    required double fat,
    required double fiber,
    required double carbs,
    required double calories,
    required double portion,
  }) =>
      FoodComponent(
        id: id,
        name: id,
        physicalForm: form,
        proteinGrams: protein,
        fatGrams: fat,
        fiberGrams: fiber,
        carbohydrateGrams: carbs,
        calories: calories,
        portionGrams: portion,
        sourceDocId: 'synthetic',
      );

  GastricEmptyingProfile profileFor(List<FoodComponent> components) {
    final comp = normalizer.normalize(mealId: 'm', components: components);
    return model.build(mealId: 'm', mealStartMinute: 0, composition: comp);
  }

  test('liquid empties faster than solid (shorter lag + half)', () {
    final liquid = profileFor([
      component(
          id: 'juice',
          form: MealPhysicalForm.liquid,
          protein: 1,
          fat: 0,
          fiber: 0,
          carbs: 20,
          calories: 90,
          portion: 250),
    ]);
    final solid = profileFor([
      component(
          id: 'steak',
          form: MealPhysicalForm.solid,
          protein: 20,
          fat: 5,
          fiber: 0,
          carbs: 0,
          calories: 200,
          portion: 150),
    ]);
    expect(liquid.aggregateLagMinutes, lessThan(solid.aggregateLagMinutes));
    // Liquid mostly-emptied window ends sooner than the solid's.
    expect(liquid.mostlyEmptiedWindow.endMinute,
        lessThan(solid.mostlyEmptiedWindow.endMinute));
  });

  test('high-fat meal widens uncertainty vs a low-fat meal of equal data', () {
    // Low fat: fat fraction well below 0.3.
    final lowFat = profileFor([
      component(
          id: 'lowfat',
          form: MealPhysicalForm.solid,
          protein: 10,
          fat: 2,
          fiber: 0,
          carbs: 40,
          calories: 250,
          portion: 200),
    ]);
    // High fat: ~ (20g*9)/250 = 0.72 fraction → high fat.
    final highFat = profileFor([
      component(
          id: 'highfat',
          form: MealPhysicalForm.solid,
          protein: 10,
          fat: 20,
          fiber: 0,
          carbs: 10,
          calories: 250,
          portion: 200),
    ]);
    expect(bandIndex(highFat.uncertaintyBand),
        greaterThan(bandIndex(lowFat.uncertaintyBand)));
    expect(
      highFat.assumptions.any((a) => a.contains('ge.fat.uncertainty_boost')),
      isTrue,
    );
  });

  test('high-calorie meal widens uncertainty vs a normal-size meal', () {
    final normalCal = profileFor([
      component(
          id: 'normal',
          form: MealPhysicalForm.solid,
          protein: 10,
          fat: 3,
          fiber: 0,
          carbs: 40,
          calories: 300,
          portion: 250),
    ]);
    // 700 kcal ≥ 400 * 1.5 = 600 → high calorie. Fat fraction kept low.
    final highCal = profileFor([
      component(
          id: 'big',
          form: MealPhysicalForm.solid,
          protein: 25,
          fat: 8,
          fiber: 0,
          carbs: 110,
          calories: 700,
          portion: 500),
    ]);
    expect(bandIndex(highCal.uncertaintyBand),
        greaterThan(bandIndex(normalCal.uncertaintyBand)));
    expect(
      highCal.assumptions
          .any((a) => a.contains('ge.highcal.uncertainty_boost')),
      isTrue,
    );
  });

  test('mixed meal aggregates both components into the profile', () {
    final mixed = profileFor([
      component(
          id: 'coffee',
          form: MealPhysicalForm.liquid,
          protein: 0,
          fat: 0,
          fiber: 0,
          carbs: 2,
          calories: 10,
          portion: 200),
      component(
          id: 'toast',
          form: MealPhysicalForm.solid,
          protein: 6,
          fat: 4,
          fiber: 3,
          carbs: 30,
          calories: 200,
          portion: 80),
    ]);
    expect(mixed.componentProfiles.length, 2);
    // Mass-weighted aggregate lag lies strictly between pure-liquid (0) and
    // pure-solid lag → both components contributed.
    expect(mixed.aggregateLagMinutes, greaterThan(0));
  });
}
