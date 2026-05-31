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

  const validIron = RawMedicationEntry(
    activeIngredients: ['ferrous sulfate'],
    drugProductVariant: 'synthetic:iron',
    strength: 65,
    unit: 'mg',
    form: 'tablet',
    route: 'oral',
    releaseType: 'immediate',
    jurisdiction: 'US',
    sourceDocId: 'synthetic:iron',
  );

  const validLevodopaER = RawMedicationEntry(
    activeIngredients: ['carbidopa', 'levodopa'],
    drugProductVariant: 'synthetic:er',
    strength: 200,
    unit: 'mg',
    form: 'tablet',
    route: 'oral',
    releaseType: 'extended',
    jurisdiction: 'US',
    sourceDocId: 'synthetic:er',
  );

  test('multi-dose: the high-overlap dose drives the primary score', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    // Two levodopa doses: one taken right at the high-protein meal (high
    // overlap) and one taken 6 hours later (no nearby meal → low overlap).
    final v = validator.validate(validLevodopa);
    final ctx = builder.build(
      now: now,
      medicationInputs: [
        MedicationTimelineInput(
          id: 'dose_overlap',
          takenAt: now.add(const Duration(minutes: 20)),
          medicationContext: v,
        ),
        MedicationTimelineInput(
          id: 'dose_far',
          takenAt: now.add(const Duration(hours: 6)),
          medicationContext: v,
        ),
      ],
      mealInputs: [
        MealTimelineInput(
          id: 'meal',
          startedAt: now,
          compositionId: 'c1',
          physicalForm: MealPhysicalForm.solid,
        ),
      ],
    );
    final composition =
        normalizer.normalize(mealId: 'c1', components: const [highProtein]);
    final r = engine.evaluate(
      context: ctx,
      mealCompositionsById: {'c1': composition},
    );
    expect(r.perEventCount, 2);
    final primary = r.perEventTraces.firstWhere((e) => e.isPrimary);
    expect(primary.medicationEventId, 'dose_overlap');
    // The aggregate score equals the highest per-event score (max-overlap),
    // not an average that would dilute the high-overlap dose.
    final maxPerEvent = r.perEventTraces
        .map((e) => e.interactionScore)
        .reduce((a, b) => a > b ? a : b);
    expect(r.interactionScore, closeTo(maxPerEvent, 1e-9));
  });

  test('multi-dose: non-levodopa events are excluded from scoring', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final levo = validator.validate(validLevodopa);
    final iron = validator.validate(validIron);
    final ctx = builder.build(
      now: now,
      medicationInputs: [
        MedicationTimelineInput(
          id: 'levo',
          takenAt: now.add(const Duration(minutes: 20)),
          medicationContext: levo,
        ),
        MedicationTimelineInput(
          id: 'iron',
          takenAt: now.add(const Duration(minutes: 25)),
          medicationContext: iron,
        ),
      ],
      mealInputs: [
        MealTimelineInput(
          id: 'meal',
          startedAt: now,
          compositionId: 'c1',
          physicalForm: MealPhysicalForm.solid,
        ),
      ],
    );
    final composition =
        normalizer.normalize(mealId: 'c1', components: const [highProtein]);
    final r = engine.evaluate(
      context: ctx,
      mealCompositionsById: {'c1': composition},
    );
    // Only the levodopa dose is scored; the iron dose is not a per-event trace.
    expect(r.perEventCount, 1);
    expect(r.perEventTraces.single.medicationEventId, 'levo');
    expect(r.perEventTraces.single.isLevodopa, isTrue);
  });

  test('ER formulation widens the absorption window vs immediate release', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    TimeAxisConflictContext ctxFor(RawMedicationEntry e) => makeContext(
          now: now,
          medEntry: e,
          medTakenAt: now.add(const Duration(minutes: 20)),
          mealStartedAt: now,
        );
    final composition =
        normalizer.normalize(mealId: 'c1', components: const [highProtein]);
    final ir = engine.evaluate(
      context: ctxFor(validLevodopa),
      mealCompositionsById: {'c1': composition},
    );
    final er = engine.evaluate(
      context: ctxFor(validLevodopaER),
      mealCompositionsById: {'c1': composition},
    );
    final irWin = ir.absorptionOpportunityWindow!.window;
    final erWin = er.absorptionOpportunityWindow!.window;
    expect(
      erWin.endMinute - erWin.startMinute,
      greaterThan(irWin.endMinute - irWin.startMinute),
    );
  });

  test('primary meal selection is independent of meal-event input order', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final refMinute = dateTimeToMinute(now);
    final medContext = validator.validate(validLevodopa).normalized!;
    final med = MedicationTimelineEvent(
      id: 'med',
      minute: refMinute + 30,
      context: medContext,
    );

    // Two meals at the SAME minute with different compositions. Selection must
    // be deterministic (tie-broken by id) regardless of list order.
    const lowProtein = FoodComponent(
      id: 'lp',
      name: 'low protein',
      physicalForm: MealPhysicalForm.solid,
      proteinGrams: 1,
      fatGrams: 0,
      fiberGrams: 0,
      carbohydrateGrams: 30,
      calories: 130,
      portionGrams: 150,
      sourceDocId: 'synthetic:demo',
    );
    final compA =
        normalizer.normalize(mealId: 'cA', components: const [lowProtein]);
    final compB =
        normalizer.normalize(mealId: 'cB', components: const [highProtein]);
    final mealA = MealTimelineEvent(
      id: 'a_meal',
      minute: refMinute,
      compositionId: 'cA',
      physicalForm: MealPhysicalForm.solid,
    );
    final mealB = MealTimelineEvent(
      id: 'b_meal',
      minute: refMinute,
      compositionId: 'cB',
      physicalForm: MealPhysicalForm.solid,
    );
    final compositions = {'cA': compA, 'cB': compB};

    MechanisticConflictResult evalWith(List<MealTimelineEvent> meals) =>
        engine.evaluate(
          context: TimeAxisConflictContext(
            referenceMinute: refMinute,
            medicationEvents: [med],
            mealEvents: meals,
          ),
          mealCompositionsById: compositions,
        );

    final ordered = evalWith([mealA, mealB]);
    final reversed = evalWith([mealB, mealA]);

    // Same primary meal → identical modeled output regardless of input order.
    expect(reversed.interactionScore, ordered.interactionScore);
    expect(reversed.severityBand, ordered.severityBand);
    expect(reversed.confidenceBand, ordered.confidenceBand);
    expect(
      reversed.primaryEmptyingProfile?.aggregateLagMinutes,
      ordered.primaryEmptyingProfile?.aggregateLagMinutes,
    );
  });

  test('preferred meal overrides ordinary lookahead selection', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final refMinute = dateTimeToMinute(now);
    final med = MedicationTimelineEvent(
      id: 'med',
      minute: refMinute,
      context: validator.validate(validLevodopa).normalized!,
    );
    const lowProtein = FoodComponent(
      id: 'lp',
      name: 'low protein',
      physicalForm: MealPhysicalForm.solid,
      proteinGrams: 1,
      fatGrams: 0,
      fiberGrams: 0,
      carbohydrateGrams: 30,
      calories: 130,
      portionGrams: 150,
      sourceDocId: 'synthetic:demo',
    );
    final historical = normalizer
        .normalize(mealId: 'historical', components: const [lowProtein]);
    final hypothetical = normalizer
        .normalize(mealId: 'hypothetical', components: const [highProtein]);
    final ctx = TimeAxisConflictContext(
      referenceMinute: refMinute,
      medicationEvents: [med],
      mealEvents: [
        MealTimelineEvent(
          id: 'historical_meal',
          minute: refMinute - 30,
          compositionId: historical.id,
          physicalForm: MealPhysicalForm.solid,
        ),
        MealTimelineEvent(
          id: 'hypothetical_meal',
          minute: refMinute + 300,
          compositionId: hypothetical.id,
          physicalForm: MealPhysicalForm.solid,
        ),
      ],
    );
    final compositions = {
      historical.id: historical,
      hypothetical.id: hypothetical,
    };

    final ordinary =
        engine.evaluate(context: ctx, mealCompositionsById: compositions);
    final preferred = engine.evaluate(
      context: ctx,
      mealCompositionsById: compositions,
      preferredMealId: 'hypothetical_meal',
    );

    expect(ordinary.primaryEmptyingProfile?.mealId, 'historical_meal');
    expect(preferred.primaryEmptyingProfile?.mealId, 'hypothetical_meal');
  });

  test('missing preferred meal returns insufficient meal context', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final ctx = makeContext(
      now: now,
      medEntry: validLevodopa,
      medTakenAt: now,
      mealStartedAt: now,
    );
    final composition =
        normalizer.normalize(mealId: 'c1', components: const [highProtein]);

    final result = engine.evaluate(
      context: ctx,
      mealCompositionsById: {'c1': composition},
      preferredMealId: 'missing_meal',
    );

    expect(
      result.interactionType,
      MechanisticInteractionType.insufficientMealContext,
    );
    expect(
      result.explanation.missingOrUncertainInputs,
      contains('meal_event(missing_meal)'),
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
