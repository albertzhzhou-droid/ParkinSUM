import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_conflict_result.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_next_meal_scorer.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_replay_runner.dart';
import 'package:parkinsum_companion/domain/usecases/time_axis_builder.dart';
import 'package:parkinsum_companion/domain/usecases/model_assumption_registry.dart';

void main() {
  test('mechanistic default copy strings contain no banned substrings', () {
    expect(findBannedSubstrings(MechanisticExplanation.defaultLimitation),
        isEmpty);
  });

  test('every model assumption citation copy is free of banned substrings', () {
    for (final a in ModelAssumptionRegistry.all) {
      final joined = [
        a.title,
        a.mechanismSupported,
        a.limitation,
        a.citationText,
      ].join(' ');
      expect(findBannedSubstrings(joined), isEmpty,
          reason: 'assumption ${a.sourceId} leaked banned phrase');
    }
  });

  test(
      'mechanistic engine output for a high-protein scenario stays '
      'non-prescriptive', () {
    final validator = MedicationEntryValidator();
    final normalizer = MealCompositionNormalizer();
    final builder = TimeAxisBuilder();
    final engine = MechanisticConflictEngine();

    final v = validator.validate(const RawMedicationEntry(
      activeIngredients: ['carbidopa', 'levodopa'],
      drugProductVariant: 'synthetic:demo',
      strength: 100,
      unit: 'mg',
      form: 'tablet',
      route: 'oral',
      releaseType: 'immediate',
      jurisdiction: 'US',
      sourceDocId: 'synthetic:demo',
    ));
    final composition = normalizer.normalize(
      mealId: 'c',
      components: const [
        FoodComponent(
          id: 'protein',
          name: 'protein',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: 35,
          fatGrams: 5,
          fiberGrams: 0,
          carbohydrateGrams: 5,
          calories: 200,
          portionGrams: 200,
          sourceDocId: 'synthetic:demo',
        ),
      ],
    );
    final now = DateTime.utc(2026, 1, 1, 8);
    final ctx = builder.build(
      now: now,
      medicationInputs: [
        MedicationTimelineInput(
          id: 'm',
          takenAt: now.add(const Duration(minutes: 30)),
          medicationContext: v,
        ),
      ],
      mealInputs: [
        MealTimelineInput(
          id: 'meal',
          startedAt: now,
          compositionId: composition.id,
          physicalForm: MealPhysicalForm.solid,
        ),
      ],
    );
    final r = engine.evaluate(
      context: ctx,
      mealCompositionsById: {composition.id: composition},
    );
    final allCopy = [
      r.limitationText,
      r.safetyBoundary,
      r.notAdviceText,
      ...r.explanation.layerTraces.map((t) => t.description),
      ...r.explanation.layerTraces.expand((t) => t.assumptionsApplied),
    ].join(' ');
    expect(findBannedSubstrings(allCopy), isEmpty);
  });

  test('candidate-scorer copy stays non-prescriptive', () {
    final scorer = MechanisticNextMealScorer();
    final validator = MedicationEntryValidator();
    final builder = TimeAxisBuilder();
    final now = DateTime.utc(2026, 1, 1, 8);
    final v = validator.validate(const RawMedicationEntry(
      activeIngredients: ['carbidopa', 'levodopa'],
      drugProductVariant: 'synthetic:demo',
      strength: 100,
      unit: 'mg',
      form: 'tablet',
      route: 'oral',
      releaseType: 'immediate',
      jurisdiction: 'US',
      sourceDocId: 'synthetic:demo',
    ));
    final ctx = builder.build(
      now: now,
      medicationInputs: [
        MedicationTimelineInput(
          id: 'm',
          takenAt: now.subtract(const Duration(hours: 4)),
          medicationContext: v,
        ),
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
      candidates: const [
        CandidateFood(
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
        ),
      ],
    );
    for (final s in scores) {
      expect(findBannedSubstrings(s.explanation.join(' ')), isEmpty);
    }
  });

  test('every replay scenario\'s serialized JSON is free of banned phrases',
      () {
    final runner = MechanisticReplayRunner();
    final report = runner.run();
    final encoded = encodeReplayReport(report);
    expect(findBannedSubstrings(encoded), isEmpty);
  });
}
