import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
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
        id: 'b',
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

  TimeAxisConflictContext makeCtx(DateTime now, UserDefinedMealWindow? window) {
    final v = validator.validate(validLevodopa);
    return builder.build(
      now: now,
      medicationInputs: [
        MedicationTimelineInput(
          id: 'm',
          takenAt: now.add(const Duration(minutes: -5)),
          medicationContext: v,
        ),
      ],
      mealInputs: const [],
      userDefinedWindow: window,
    );
  }

  test('user window required → insufficient context for every candidate', () {
    final ctx = makeCtx(DateTime.utc(2026, 1, 1, 8), null);
    final scores = scorer.score(
      baseContext: ctx,
      baseMealCompositionsById: const {},
      candidates: const [banana],
    );
    expect(scores.single.insufficientContext, isTrue);
  });

  test('sample count is deterministic for a given window size', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final window = UserDefinedMealWindow(
      window: TimelineWindow(
        startMinute: dateTimeToMinute(now) + 0,
        endMinute: dateTimeToMinute(now) + 120,
      ),
      source: 'test',
    );
    final ctx = makeCtx(now, window);
    final a = scorer.score(
        baseContext: ctx,
        baseMealCompositionsById: const {},
        candidates: const [banana]);
    final b = scorer.score(
        baseContext: ctx,
        baseMealCompositionsById: const {},
        candidates: const [banana]);
    expect(a.single.sampleCount, b.single.sampleCount);
    expect(a.single.sampleCount, greaterThanOrEqualTo(5));
    expect(a.single.sampleCount, lessThanOrEqualTo(12));
  });

  test('worst-case overlap is ≥ best-case overlap across samples', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final window = UserDefinedMealWindow(
      window: TimelineWindow(
        startMinute: dateTimeToMinute(now),
        endMinute: dateTimeToMinute(now) + 180,
      ),
      source: 'test',
    );
    final ctx = makeCtx(now, window);
    final s = scorer.score(
        baseContext: ctx,
        baseMealCompositionsById: const {},
        candidates: const [banana]).single;
    expect(s.worstCaseConflictOverlapScore,
        greaterThanOrEqualTo(s.bestCaseConflictOverlapScore));
    expect(s.averageConflictOverlapScore,
        lessThanOrEqualTo(s.worstCaseConflictOverlapScore));
    expect(s.sampleCount, s.sampledWindowSummary.length);
  });

  test('candidate explanation never says "eat at this time" or similar', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final window = UserDefinedMealWindow(
      window: TimelineWindow(
        startMinute: dateTimeToMinute(now),
        endMinute: dateTimeToMinute(now) + 120,
      ),
      source: 'test',
    );
    final ctx = makeCtx(now, window);
    final s = scorer.score(
      baseContext: ctx,
      baseMealCompositionsById: const {},
      candidates: const [banana],
    ).single;
    final blob = s.explanation.join(' ').toLowerCase();
    expect(blob.contains('eat at'), isFalse);
    expect(blob.contains('you should'), isFalse);
    expect(findBannedSubstrings(blob), isEmpty);
  });
}
