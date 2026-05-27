import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/gastric_emptying_parameters.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/gastric_emptying_model.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';

void main() {
  test('default parameter set loads with sourceRefs for every parameter', () {
    final ps = GastricEmptyingParameterSet.literatureInformedDefault();
    for (final p in ps.all) {
      expect(p.sourceRefs, isNotEmpty,
          reason: 'parameter ${p.id} missing sourceRefs');
    }
    expect(ps.unionSourceRefs, isNotEmpty);
  });

  test('toJson includes prototype_heuristic flags where appropriate', () {
    final ps = GastricEmptyingParameterSet.literatureInformedDefault();
    final json = ps.toJson();
    final fatSlowdown = json['fat_slowdown_multiplier'] as Map<String, dynamic>;
    expect(fatSlowdown['confidence'], 'prototypeHeuristic');
    final solidHalf = json['solid_half_minutes'] as Map<String, dynamic>;
    expect(solidHalf['confidence'], 'mechanism');
  });

  test(
      'swapping in a parameter set with double the half-time extends the '
      'mostly-emptied window', () {
    final defaultPs = GastricEmptyingParameterSet.literatureInformedDefault();
    final doubledPs = GastricEmptyingParameterSet(
      solidLagMinutes: defaultPs.solidLagMinutes,
      solidHalfMinutes: GastricEmptyingParameter<double>(
        id: defaultPs.solidHalfMinutes.id,
        label: defaultPs.solidHalfMinutes.label,
        value: defaultPs.solidHalfMinutes.value * 2,
        sourceRefs: defaultPs.solidHalfMinutes.sourceRefs,
        confidence: defaultPs.solidHalfMinutes.confidence,
        limitation: defaultPs.solidHalfMinutes.limitation,
      ),
      liquidLagMinutes: defaultPs.liquidLagMinutes,
      liquidHalfMinutes: defaultPs.liquidHalfMinutes,
      referenceMealCalories: defaultPs.referenceMealCalories,
      fatSlowdownMultiplier: defaultPs.fatSlowdownMultiplier,
      fatFractionThreshold: defaultPs.fatFractionThreshold,
      fiberSlowdownMultiplier: defaultPs.fiberSlowdownMultiplier,
      mixedMealUncertaintyBoost: defaultPs.mixedMealUncertaintyBoost,
      overlapUncertaintyBoost: defaultPs.overlapUncertaintyBoost,
    );

    final normalizer = MealCompositionNormalizer();
    final composition = normalizer.normalize(
      mealId: 'm',
      components: const [
        FoodComponent(
          id: 'oats',
          name: 'oats',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: 5,
          fatGrams: 3,
          fiberGrams: 4,
          carbohydrateGrams: 27,
          calories: 158,
          portionGrams: 200,
          sourceDocId: 'synthetic',
        ),
      ],
      declaredPhysicalForm: MealPhysicalForm.solid,
    );

    final defaultModel = GastricEmptyingModel(parameters: defaultPs);
    final doubledModel = GastricEmptyingModel(parameters: doubledPs);
    final defaultProfile = defaultModel.build(
        mealId: 'm', mealStartMinute: 0, composition: composition);
    final doubledProfile = doubledModel.build(
        mealId: 'm', mealStartMinute: 0, composition: composition);
    expect(
      doubledProfile.mostlyEmptiedWindow.endMinute -
          doubledProfile.mostlyEmptiedWindow.startMinute,
      greaterThan(defaultProfile.mostlyEmptiedWindow.endMinute -
          defaultProfile.mostlyEmptiedWindow.startMinute),
    );
  });
}
