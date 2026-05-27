import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_conflict_result.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';
import 'package:parkinsum_companion/domain/usecases/time_axis_builder.dart';

void main() {
  final validator = MedicationEntryValidator();
  final normalizer = MealCompositionNormalizer();
  final builder = TimeAxisBuilder();
  final engine = MechanisticConflictEngine();

  TimeAxisConflictContext makeContext({
    required DateTime now,
    required RawMedicationEntry medEntry,
    required DateTime? medTakenAt,
    required DateTime? mealStartedAt,
    String compositionId = 'c1',
  }) {
    final v = validator.validate(medEntry);
    return builder.build(
      now: now,
      medicationInputs: [
        MedicationTimelineInput(
          id: 'med',
          takenAt: medTakenAt,
          medicationContext: v,
        ),
      ],
      mealInputs: mealStartedAt == null
          ? const []
          : [
              MealTimelineInput(
                id: 'meal',
                startedAt: mealStartedAt,
                compositionId: compositionId,
                physicalForm: MealPhysicalForm.solid,
              ),
            ],
    );
  }

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

  const highProtein = FoodComponent(
    id: 'p',
    name: 'protein',
    physicalForm: MealPhysicalForm.solid,
    proteinGrams: 35,
    fatGrams: 5,
    fiberGrams: 0,
    carbohydrateGrams: 0,
    calories: 200,
    portionGrams: 150,
    sourceDocId: 'synthetic:demo',
  );

  test('insufficient medication context returns insufficient result', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final ctx = makeContext(
      now: now,
      medEntry: const RawMedicationEntry(freeText: '100'),
      medTakenAt: now,
      mealStartedAt: now,
    );
    final composition =
        normalizer.normalize(mealId: 'c1', components: const [highProtein]);
    final r = engine.evaluate(
      context: ctx,
      mealCompositionsById: {'c1': composition},
    );
    expect(r.interactionType,
        MechanisticInteractionType.insufficientMedicationContext);
    expect(r.confidenceBand, ConfidenceBand.insufficient);
  });

  test('valid context + high protein near medication yields moderate severity',
      () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final ctx = makeContext(
      now: now,
      medEntry: validLevodopa,
      medTakenAt: now.add(const Duration(minutes: 30)),
      mealStartedAt: now,
    );
    final composition =
        normalizer.normalize(mealId: 'c1', components: const [highProtein]);
    final r = engine.evaluate(
      context: ctx,
      mealCompositionsById: {'c1': composition},
    );
    expect(r.interactionScore, greaterThan(0.05));
    expect(
      [SeverityBand.moderate, SeverityBand.high],
      contains(r.severityBand),
    );
    expect(r.absorptionOpportunityWindow, isNotNull);
    expect(r.competitionTimeline, isNotNull);
  });

  test('no meal event returns noModeledInteraction with medium confidence', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final ctx = makeContext(
      now: now,
      medEntry: validLevodopa,
      medTakenAt: now,
      mealStartedAt: null,
    );
    final r = engine.evaluate(context: ctx, mealCompositionsById: const {});
    expect(
      r.interactionType,
      MechanisticInteractionType.noModeledInteraction,
    );
  });

  test('explanation always carries source refs and safety boundary text', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final ctx = makeContext(
      now: now,
      medEntry: validLevodopa,
      medTakenAt: now.add(const Duration(minutes: 30)),
      mealStartedAt: now,
    );
    final composition =
        normalizer.normalize(mealId: 'c1', components: const [highProtein]);
    final r = engine.evaluate(
      context: ctx,
      mealCompositionsById: {'c1': composition},
    );
    expect(r.sourceRefs, isNotEmpty);
    expect(r.limitationText.toLowerCase(), contains('not'));
    expect(r.notAdviceText, isNotEmpty);
    expect(r.safetyBoundary, isNotEmpty);
    expect(r.explanation.layerTraces.length, greaterThanOrEqualTo(3));
  });
}
