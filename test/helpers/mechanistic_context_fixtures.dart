import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/time_axis_builder.dart';

const String fixtureDoseTimeCompositionId =
    'fixture:dose-time-history-composition';

const MealComposition fixtureDoseTimeMealComposition = MealComposition(
  id: fixtureDoseTimeCompositionId,
  totalCalories: 180,
  proteinGrams: 4,
  fatGrams: 3,
  fiberGrams: 2,
  carbohydrateGrams: 30,
  liquidFraction: 0,
  mealPhysicalForm: MealPhysicalForm.solid,
  portionSizeBand: PortionSizeBand.small,
  proteinAmountBand: AmountBand.low,
  // 3 g fat contributes exactly 15% of 180 kcal, the canonical boundary for
  // the moderate band.
  fatAmountBand: AmountBand.moderate,
  fiberAmountBand: AmountBand.low,
  calorieBand: AmountBand.low,
  compositionCompleteness: 1,
  missingFields: [],
  foodComponents: [
    FoodComponent(
      id: 'fixture:dose-time-history-component',
      name: 'Synthetic history component',
      physicalForm: MealPhysicalForm.solid,
      proteinGrams: 4,
      fatGrams: 3,
      fiberGrams: 2,
      carbohydrateGrams: 30,
      calories: 180,
      portionGrams: 150,
      sourceDocId: 'synthetic:test-only',
    ),
  ],
);

MealTimelineInput fixtureDoseTimeMealInput(DateTime startedAt) =>
    MealTimelineInput(
      id: 'fixture:dose-time-history-meal',
      startedAt: startedAt,
      compositionId: fixtureDoseTimeCompositionId,
      physicalForm: MealPhysicalForm.solid,
    );

const Map<String, MealComposition> fixtureDoseTimeCompositions = {
  fixtureDoseTimeCompositionId: fixtureDoseTimeMealComposition,
};
