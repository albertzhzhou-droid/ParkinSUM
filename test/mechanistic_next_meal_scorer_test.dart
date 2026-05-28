import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_conflict_result.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_next_meal_scorer.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';
import 'package:parkinsum_companion/domain/usecases/time_axis_builder.dart';

void main() {
  final validator = MedicationEntryValidator();
  final builder = TimeAxisBuilder();
  final scorer = MechanisticNextMealScorer();

  const validLevodopa = RawMedicationEntry(
    activeIngredients: ['carbidopa', 'levodopa'],
    drugProductVariant: 'synthetic:demo',
    strength: 100,
    unit: 'mg',
    form: 'tablet',
    route: 'oral',
    releaseType: 'immediate',
    jurisdiction: 'US',
    sourceDocId: 'synthetic:demo',
  );

  const banana = CandidateFood(
    id: 'banana',
    name: 'banana',
    regionalFoodLibraryRef: 'synthetic',
    declaredPhysicalForm: MealPhysicalForm.solid,
    components: [
      FoodComponent(
        id: 'banana',
        name: 'banana',
        physicalForm: MealPhysicalForm.solid,
        proteinGrams: 1,
        fatGrams: 0,
        fiberGrams: 3,
        carbohydrateGrams: 27,
        calories: 105,
        portionGrams: 120,
        sourceDocId: 'synthetic',
      ),
    ],
  );

  const proteinShake = CandidateFood(
    id: 'shake',
    name: 'shake',
    regionalFoodLibraryRef: 'synthetic',
    declaredPhysicalForm: MealPhysicalForm.liquid,
    components: [
      FoodComponent(
        id: 'shake',
        name: 'shake',
        physicalForm: MealPhysicalForm.liquid,
        proteinGrams: 25,
        fatGrams: 3,
        fiberGrams: 1,
        carbohydrateGrams: 20,
        calories: 220,
        portionGrams: 300,
        sourceDocId: 'synthetic',
      ),
    ],
  );

  const unknownNutrients = CandidateFood(
    id: 'unknown',
    name: 'unknown',
    regionalFoodLibraryRef: 'synthetic',
    declaredPhysicalForm: MealPhysicalForm.unknown,
    components: [
      FoodComponent(
        id: 'unknown',
        name: 'unknown',
        physicalForm: MealPhysicalForm.unknown,
        proteinGrams: null,
        fatGrams: null,
        fiberGrams: null,
        carbohydrateGrams: null,
        calories: null,
        portionGrams: null,
        sourceDocId: 'synthetic',
      ),
    ],
  );

  test('missing window → every candidate is insufficient_context', () {
    final v = validator.validate(validLevodopa);
    final ctx = builder.build(
      now: DateTime.utc(2026, 1, 1, 8),
      medicationInputs: [
        MedicationTimelineInput(
          id: 'm',
          takenAt: DateTime.utc(2026, 1, 1, 8),
          medicationContext: v,
        ),
      ],
      mealInputs: const [],
    );
    final scores = scorer.score(
      baseContext: ctx,
      baseMealCompositionsById: const {},
      candidates: const [banana, proteinShake],
    );
    expect(scores.length, 2);
    expect(scores.every((s) => s.insufficientContext), isTrue);
  });

  test('invalid medication context → every candidate is insufficient_context',
      () {
    final invalid =
        validator.validate(const RawMedicationEntry(freeText: '100'));
    final now = DateTime.utc(2026, 1, 1, 8);
    final ctx = builder.build(
      now: now,
      medicationInputs: [
        MedicationTimelineInput(
            id: 'm', takenAt: now, medicationContext: invalid)
      ],
      mealInputs: const [],
      userDefinedWindow: UserDefinedMealWindow(
        window: TimelineWindow(
          startMinute: dateTimeToMinute(now) + 60,
          endMinute: dateTimeToMinute(now) + 120,
        ),
        source: 'test',
      ),
    );
    final scores = scorer.score(
      baseContext: ctx,
      baseMealCompositionsById: const {},
      candidates: const [banana],
    );
    expect(scores.single.insufficientContext, isTrue);
  });

  test(
      'protein redistribution: high-protein candidate carries higher overlap '
      'penalty and lower redistribution score than low-protein in the same '
      'window (NOT global minimization)', () {
    final v = validator.validate(validLevodopa);
    final now = DateTime.utc(2026, 1, 1, 8);
    final ctx = builder.build(
      now: now,
      medicationInputs: [
        MedicationTimelineInput(
            id: 'm',
            takenAt: now.add(const Duration(minutes: 30)),
            medicationContext: v),
      ],
      mealInputs: const [],
      userDefinedWindow: UserDefinedMealWindow(
        window: TimelineWindow(
          startMinute: dateTimeToMinute(now) + 60,
          endMinute: dateTimeToMinute(now) + 120,
        ),
        source: 'test',
      ),
    );
    final scores = scorer.score(
      baseContext: ctx,
      baseMealCompositionsById: const {},
      candidates: const [proteinShake, banana],
    );
    final bananaScore = scores.firstWhere((s) => s.candidateFoodId == 'banana');
    final shakeScore = scores.firstWhere((s) => s.candidateFoodId == 'shake');
    // The mechanism, not a naive "low protein always wins": the high-protein
    // candidate models at least as much conflict overlap and gets no higher
    // redistribution score than the low-protein candidate in this window.
    expect(shakeScore.conflictOverlapScore,
        greaterThanOrEqualTo(bananaScore.conflictOverlapScore));
    expect(bananaScore.proteinRedistributionScore,
        greaterThanOrEqualTo(shakeScore.proteinRedistributionScore));
    // Both candidates carry a protein-distribution trace and a final score.
    expect(bananaScore.proteinDistribution, isNotNull);
    expect(shakeScore.proteinDistribution, isNotNull);
  });

  test('candidate with missing nutrients has lower confidence', () {
    final v = validator.validate(validLevodopa);
    final now = DateTime.utc(2026, 1, 1, 8);
    final ctx = builder.build(
      now: now,
      medicationInputs: [
        MedicationTimelineInput(
            id: 'm',
            takenAt: now.add(const Duration(minutes: 30)),
            medicationContext: v),
      ],
      mealInputs: const [],
      userDefinedWindow: UserDefinedMealWindow(
        window: TimelineWindow(
          startMinute: dateTimeToMinute(now) + 60,
          endMinute: dateTimeToMinute(now) + 120,
        ),
        source: 'test',
      ),
    );
    final scores = scorer.score(
      baseContext: ctx,
      baseMealCompositionsById: const {},
      candidates: const [banana, unknownNutrients],
    );
    final unknownScore =
        scores.firstWhere((s) => s.candidateFoodId == 'unknown');
    expect(unknownScore.nutritionDataCompleteness, 0.0);
    expect(
      [ConfidenceBand.low, ConfidenceBand.insufficient],
      contains(unknownScore.confidenceBand),
    );
  });
}
