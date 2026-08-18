import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/absorption_opportunity.dart';
import 'package:parkinsum_companion/domain/entities/gastric_emptying_profile.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_conflict_result.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_medication_applicability.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/medication_entry_validation.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';
import 'package:parkinsum_companion/domain/usecases/levodopa_absorption_opportunity_model.dart';
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

  NormalizedMedicationContext directMedicationContext({
    double strength = 100,
    String drugProductVariant = 'synthetic:demo',
    String jurisdiction = 'US',
    String sourceDocId = 'synthetic:demo',
    double? extractionConfidence = 0.9,
  }) => NormalizedMedicationContext(
    drugProductVariant: drugProductVariant,
    activeIngredients: const ['carbidopa', 'levodopa'],
    form: 'tablet',
    route: 'oral',
    releaseType: 'immediate',
    strength: strength,
    unit: 'mg',
    jurisdiction: jurisdiction,
    sourceDocId: sourceDocId,
    labelSection: null,
    extractionConfidence: extractionConfidence,
    limitationText: MedicationEntryValidator.defaultLimitationText,
  );

  MechanisticConflictResult evaluateDirectMedication(
    NormalizedMedicationContext medication,
  ) {
    final composition = normalizer.normalize(
      mealId: 'c1',
      components: const [highProtein],
    );
    final context = TimeAxisConflictContext(
      referenceMinute: 100,
      medicationEvents: [
        MedicationTimelineEvent(id: 'dose', minute: 120, context: medication),
      ],
      mealEvents: const [
        MealTimelineEvent(
          id: 'meal',
          minute: 100,
          compositionId: 'c1',
          physicalForm: MealPhysicalForm.solid,
        ),
      ],
    );
    return engine.evaluate(
      context: context,
      mealCompositionsById: {'c1': composition},
    );
  }

  test('insufficient medication context returns insufficient result', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final ctx = makeContext(
      now: now,
      medEntry: const RawMedicationEntry(freeText: '100'),
      medTakenAt: now,
      mealStartedAt: now,
    );
    final composition = normalizer.normalize(
      mealId: 'c1',
      components: const [highProtein],
    );
    final r = engine.evaluate(
      context: ctx,
      mealCompositionsById: {'c1': composition},
    );
    expect(
      r.interactionType,
      MechanisticInteractionType.insufficientMedicationContext,
    );
    expect(r.availability, MechanisticResultAvailability.insufficient);
    expect(r.confidenceBand, ConfidenceBand.insufficient);
    expect(r.toJson()['interaction_score'], isNull);
  });

  for (final fixture
      in <
        ({String label, NormalizedMedicationContext context, String reasonCode})
      >[
        (
          label: 'non-finite strength',
          context: directMedicationContext(strength: double.nan),
          reasonCode: 'non_finite_strength',
        ),
        (
          label: 'empty governed identity',
          context: directMedicationContext(
            drugProductVariant: '',
            jurisdiction: '',
            sourceDocId: '',
          ),
          reasonCode: 'missing_drug_product_variant',
        ),
        (
          label: 'out-of-range extraction confidence',
          context: directMedicationContext(extractionConfidence: 1.1),
          reasonCode: 'invalid_extraction_confidence',
        ),
      ]) {
    test('direct normalized context blocks ${fixture.label}', () {
      final result = evaluateDirectMedication(fixture.context);

      expect(
        result.availability,
        MechanisticResultAvailability.blockedIntegrity,
      );
      expect(result.hasModeledOutput, isFalse);
      expect(result.uncertaintyReasons.join(','), contains(fixture.reasonCode));
      expect(result.toJson()['interaction_score'], isNull);
      expect(result.toJson()['severity_band'], isNull);
      expect(result.toJson()['confidence_band'], isNull);
      expect(result.toJson()['modeled_timeline_windows'], isEmpty);
    });
  }

  test(
    'valid context + high protein near medication yields moderate severity',
    () {
      final now = DateTime.utc(2026, 1, 1, 8);
      final ctx = makeContext(
        now: now,
        medEntry: validLevodopa,
        medTakenAt: now.add(const Duration(minutes: 30)),
        mealStartedAt: now,
      );
      final composition = normalizer.normalize(
        mealId: 'c1',
        components: const [highProtein],
      );
      final r = engine.evaluate(
        context: ctx,
        mealCompositionsById: {'c1': composition},
      );
      expect(r.interactionScore, greaterThan(0.05));
      expect([
        SeverityBand.moderate,
        SeverityBand.high,
      ], contains(r.severityBand));
      expect(r.absorptionOpportunityWindow, isNotNull);
      expect(r.competitionTimeline, isNotNull);
    },
  );

  test(
    'no meal record returns insufficient context without a model window',
    () {
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
        MechanisticInteractionType.insufficientMealContext,
      );
      expect(r.availability, MechanisticResultAvailability.insufficient);
      expect(r.confidenceBand, ConfidenceBand.insufficient);
      expect(r.absorptionOpportunityWindow, isNull);
      expect(r.modeledTimelineWindows, isEmpty);
      expect(r.explanation.missingOrUncertainInputs, contains('meal_events'));
    },
  );

  test('valid dose plus silently dropped invalid dose fails closed', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final valid = validator.validate(validLevodopa);
    final invalid = validator.validate(
      const RawMedicationEntry(freeText: '100'),
    );
    final context = builder.build(
      now: now,
      medicationInputs: [
        MedicationTimelineInput(
          id: 'valid_dose',
          takenAt: now.add(const Duration(minutes: 20)),
          medicationContext: valid,
        ),
        MedicationTimelineInput(
          id: 'invalid_dose',
          takenAt: now.add(const Duration(minutes: 25)),
          medicationContext: invalid,
        ),
      ],
      mealInputs: [
        MealTimelineInput(id: 'meal', startedAt: now, compositionId: 'c1'),
      ],
    );
    final composition = normalizer.normalize(
      mealId: 'c1',
      components: const [highProtein],
    );

    final result = engine.evaluate(
      context: context,
      mealCompositionsById: {'c1': composition},
    );

    expect(result.availability, MechanisticResultAvailability.insufficient);
    expect(result.hasModeledOutput, isFalse);
    expect(
      result.uncertaintyReasons,
      contains('medication.invalid_context(invalid_dose)'),
    );
    expect(result.perEventTraces, isEmpty);
  });

  test('valid dose plus silently dropped missing-time dose fails closed', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final valid = validator.validate(validLevodopa);
    final context = builder.build(
      now: now,
      medicationInputs: [
        MedicationTimelineInput(
          id: 'valid_dose',
          takenAt: now.add(const Duration(minutes: 20)),
          medicationContext: valid,
        ),
        MedicationTimelineInput(
          id: 'missing_time_dose',
          takenAt: null,
          medicationContext: valid,
        ),
      ],
      mealInputs: [
        MealTimelineInput(id: 'meal', startedAt: now, compositionId: 'c1'),
      ],
    );
    final composition = normalizer.normalize(
      mealId: 'c1',
      components: const [highProtein],
    );

    final result = engine.evaluate(
      context: context,
      mealCompositionsById: {'c1': composition},
    );

    expect(result.availability, MechanisticResultAvailability.insufficient);
    expect(
      result.uncertaintyReasons,
      contains('medication.taken_at(missing_time_dose)'),
    );
    expect(result.toJson()['interaction_score'], isNull);
  });

  test('a silently dropped missing-time meal fails the whole timeline', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final valid = validator.validate(validLevodopa);
    final context = builder.build(
      now: now,
      medicationInputs: [
        MedicationTimelineInput(
          id: 'dose',
          takenAt: now.add(const Duration(minutes: 20)),
          medicationContext: valid,
        ),
      ],
      mealInputs: [
        MealTimelineInput(
          id: 'known_meal',
          startedAt: now,
          compositionId: 'c1',
        ),
        const MealTimelineInput(
          id: 'missing_time_meal',
          startedAt: null,
          compositionId: 'c1',
        ),
      ],
    );
    final composition = normalizer.normalize(
      mealId: 'c1',
      components: const [highProtein],
    );

    final result = engine.evaluate(
      context: context,
      mealCompositionsById: {'c1': composition},
    );

    expect(
      result.interactionType,
      MechanisticInteractionType.insufficientMealContext,
    );
    expect(result.availability, MechanisticResultAvailability.insufficient);
    expect(
      result.uncertaintyReasons,
      contains('meal.started_at(missing_time_meal)'),
    );
    expect(result.primaryEmptyingProfile, isNull);
  });

  test('empty medication and meal IDs produce a typed abstention', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final valid = validator.validate(validLevodopa);
    final context = builder.build(
      now: now,
      medicationInputs: [
        MedicationTimelineInput(
          id: '   ',
          takenAt: now,
          medicationContext: valid,
        ),
      ],
      mealInputs: [
        MealTimelineInput(id: '', startedAt: now, compositionId: 'c1'),
      ],
    );

    final result = engine.evaluate(
      context: context,
      mealCompositionsById: const {},
    );

    expect(result.availability, MechanisticResultAvailability.insufficient);
    expect(result.hasModeledOutput, isFalse);
    expect(
      result.uncertaintyReasons,
      containsAll(const [
        'medication.event_id_empty(index=0)',
        'meal.event_id_empty(index=0)',
      ]),
    );
    expect(result.toJson()['interaction_score'], isNull);
  });

  test('duplicate medication IDs are integrity-blocked', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final valid = validator.validate(validLevodopa);
    final composition = normalizer.normalize(
      mealId: 'c1',
      components: const [highProtein],
    );
    final context = builder.build(
      now: now,
      medicationInputs: [
        MedicationTimelineInput(
          id: 'dose',
          takenAt: now,
          medicationContext: valid,
        ),
        MedicationTimelineInput(
          id: ' dose ',
          takenAt: now.add(const Duration(minutes: 30)),
          medicationContext: valid,
        ),
      ],
      mealInputs: [
        MealTimelineInput(id: 'meal', startedAt: now, compositionId: 'c1'),
      ],
    );

    final result = engine.evaluate(
      context: context,
      mealCompositionsById: {'c1': composition},
    );

    expect(result.availability, MechanisticResultAvailability.blockedIntegrity);
    expect(result.hasModeledOutput, isFalse);
    expect(
      result.uncertaintyReasons,
      contains('medication.event_id_duplicate(dose)'),
    );
    expect(result.toJson()['interaction_score'], isNull);
  });

  test('duplicate meal IDs cannot erase a residual predecessor', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final valid = validator.validate(validLevodopa);
    final historical = normalizer.normalize(
      mealId: 'history_composition',
      components: const [highProtein],
    );
    final current = normalizer.normalize(
      mealId: 'current_composition',
      components: const [highProtein],
    );
    final context = builder.build(
      now: now,
      medicationInputs: [
        MedicationTimelineInput(
          id: 'dose',
          takenAt: now.add(const Duration(minutes: 30)),
          medicationContext: valid,
        ),
      ],
      mealInputs: [
        MealTimelineInput(
          id: 'meal',
          startedAt: now.subtract(const Duration(minutes: 60)),
          compositionId: historical.id,
        ),
        MealTimelineInput(
          id: ' meal ',
          startedAt: now,
          compositionId: current.id,
        ),
      ],
    );

    final result = engine.evaluate(
      context: context,
      mealCompositionsById: {historical.id: historical, current.id: current},
    );

    expect(result.availability, MechanisticResultAvailability.blockedIntegrity);
    expect(result.hasModeledOutput, isFalse);
    expect(
      result.uncertaintyReasons,
      contains('meal.event_id_duplicate(meal)'),
    );
    expect(result.primaryEmptyingProfile, isNull);
    expect(result.absorptionOpportunityWindow, isNull);
    expect(result.toJson()['interaction_score'], isNull);
  });

  test('empty meal composition abstains before any numerical model', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final context = makeContext(
      now: now,
      medEntry: validLevodopa,
      medTakenAt: now.add(const Duration(minutes: 20)),
      mealStartedAt: now,
    );
    final emptyComposition = normalizer.normalize(
      mealId: 'c1',
      components: const [],
    );

    final result = engine.evaluate(
      context: context,
      mealCompositionsById: {'c1': emptyComposition},
    );

    expect(
      result.interactionType,
      MechanisticInteractionType.insufficientMealContext,
    );
    expect(result.availability, MechanisticResultAvailability.insufficient);
    expect(result.hasModeledOutput, isFalse);
    expect(
      result.uncertaintyReasons,
      contains('meal_composition(c1).food_components'),
    );
    expect(
      result.uncertaintyReasons,
      contains('meal_composition(c1).composition_completeness'),
    );
    expect(result.toJson()['interaction_score'], isNull);
    expect(result.primaryEmptyingProfile, isNull);
    expect(result.competitionTimeline, isNull);
  });

  test('all-macros-missing meal never turns unknown competition into zero', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final context = makeContext(
      now: now,
      medEntry: validLevodopa,
      medTakenAt: now.add(const Duration(minutes: 20)),
      mealStartedAt: now,
    );
    final composition = normalizer.normalize(
      mealId: 'c1',
      components: const [
        FoodComponent(
          id: 'macro_unknown',
          name: 'macro unknown fixture',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: null,
          fatGrams: null,
          fiberGrams: null,
          carbohydrateGrams: null,
          calories: null,
          portionGrams: 100,
          sourceDocId: 'synthetic:missing-macros',
        ),
      ],
    );

    final result = engine.evaluate(
      context: context,
      mealCompositionsById: {'c1': composition},
    );
    final wire = result.toJson();

    expect(
      result.interactionType,
      MechanisticInteractionType.insufficientMealContext,
    );
    expect(result.availability, MechanisticResultAvailability.insufficient);
    expect(result.hasModeledOutput, isFalse);
    expect(
      result.uncertaintyReasons,
      contains('meal_composition(c1).protein_grams'),
    );
    expect(result.competitionTimeline, isNull);
    expect(result.modeledInteractionScore, isNull);
    expect(wire['interaction_score'], isNull);
    expect(wire['severity_band'], isNull);
    expect(wire['confidence_band'], isNull);
    expect(wire['competition_timeline'], isNull);
  });

  test(
    'insufficient final confidence abstains instead of emitting a score',
    () {
      final now = DateTime.utc(2026, 1, 1, 8);
      final context = makeContext(
        now: now,
        medEntry: validLevodopa,
        medTakenAt: now.add(const Duration(minutes: 20)),
        mealStartedAt: now,
      );
      final composition = normalizer.normalize(
        mealId: 'c1',
        components: const [
          FoodComponent(
            id: 'low_completeness',
            name: 'low completeness fixture',
            physicalForm: MealPhysicalForm.solid,
            proteinGrams: 10,
            fatGrams: null,
            fiberGrams: null,
            carbohydrateGrams: null,
            calories: null,
            portionGrams: null,
            sourceDocId: 'synthetic:low-completeness',
          ),
        ],
      );
      expect(composition.compositionCompleteness, lessThan(0.4));

      final result = engine.evaluate(
        context: context,
        mealCompositionsById: {'c1': composition},
      );

      expect(result.availability, MechanisticResultAvailability.insufficient);
      expect(result.hasModeledOutput, isFalse);
      expect(
        result.uncertaintyReasons,
        contains('model_confidence.insufficient'),
      );
      expect(result.toJson()['interaction_score'], isNull);
      expect(result.perEventTraces, isEmpty);
    },
  );

  test('one dose with a missing primary composition abstains all doses', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final referenceMinute = dateTimeToMinute(now);
    final medication = validator.validate(validLevodopa).normalized!;
    final knownComposition = normalizer.normalize(
      mealId: 'known_composition',
      components: const [highProtein],
    );
    final context = TimeAxisConflictContext(
      referenceMinute: referenceMinute,
      medicationEvents: [
        MedicationTimelineEvent(
          id: 'early_dose',
          minute: referenceMinute,
          context: medication,
        ),
        MedicationTimelineEvent(
          id: 'later_dose',
          minute: referenceMinute + 180,
          context: medication,
        ),
      ],
      mealEvents: [
        MealTimelineEvent(
          id: 'known_meal',
          minute: referenceMinute,
          compositionId: knownComposition.id,
        ),
        MealTimelineEvent(
          id: 'missing_meal',
          minute: referenceMinute + 300,
          compositionId: 'missing_composition',
        ),
      ],
    );

    final result = engine.evaluate(
      context: context,
      mealCompositionsById: {knownComposition.id: knownComposition},
    );

    expect(result.availability, MechanisticResultAvailability.insufficient);
    expect(result.hasModeledOutput, isFalse);
    expect(
      result.uncertaintyReasons,
      contains('meal_composition(missing_composition)'),
    );
    expect(result.perEventTraces, isEmpty);
  });

  test('missing historical residual composition is not treated as zero', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final referenceMinute = dateTimeToMinute(now);
    final medication = validator.validate(validLevodopa).normalized!;
    final knownComposition = normalizer.normalize(
      mealId: 'primary_composition',
      components: const [highProtein],
    );
    final context = TimeAxisConflictContext(
      referenceMinute: referenceMinute,
      medicationEvents: [
        MedicationTimelineEvent(
          id: 'dose',
          minute: referenceMinute + 60,
          context: medication,
        ),
      ],
      mealEvents: [
        MealTimelineEvent(
          id: 'historical_meal',
          minute: referenceMinute - 30,
          compositionId: 'missing_historical_composition',
        ),
        MealTimelineEvent(
          id: 'primary_meal',
          minute: referenceMinute,
          compositionId: knownComposition.id,
        ),
      ],
    );

    final result = engine.evaluate(
      context: context,
      mealCompositionsById: {knownComposition.id: knownComposition},
    );

    expect(result.availability, MechanisticResultAvailability.insufficient);
    expect(result.hasModeledOutput, isFalse);
    expect(
      result.uncertaintyReasons,
      contains('meal_composition(missing_historical_composition)'),
    );
    expect(result.toJson()['interaction_score'], isNull);
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
    // Two levodopa doses within the declared structural residence horizon: one
    // near the meal and one later with lower overlap.
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
          takenAt: now.add(const Duration(hours: 3)),
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
    final composition = normalizer.normalize(
      mealId: 'c1',
      components: const [highProtein],
    );
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

  test(
    'same-minute equal doses are deterministic across reversed input order',
    () {
      final now = DateTime.utc(2026, 1, 1, 8);
      final validated = validator.validate(validLevodopa);
      final composition = normalizer.normalize(
        mealId: 'c1',
        components: const [highProtein],
      );

      MechanisticConflictResult evaluateIds(List<String> ids) {
        final context = builder.build(
          now: now,
          medicationInputs: ids
              .map(
                (id) => MedicationTimelineInput(
                  id: id,
                  takenAt: now.add(const Duration(minutes: 30)),
                  medicationContext: validated,
                ),
              )
              .toList(growable: false),
          mealInputs: [
            MealTimelineInput(
              id: 'meal',
              startedAt: now,
              compositionId: 'c1',
              physicalForm: MealPhysicalForm.solid,
            ),
          ],
        );
        return engine.evaluate(
          context: context,
          mealCompositionsById: {'c1': composition},
          resultId: 'same-minute-equal-dose',
        );
      }

      final forward = evaluateIds(['dose_b', 'dose_a']);
      final reversed = evaluateIds(['dose_a', 'dose_b']);

      expect(
        forward.hasModeledOutput,
        isTrue,
        reason: forward.structuralIntegrityReasons.join(', '),
      );
      expect(forward.toJson(), equals(reversed.toJson()));
      expect(forward.perEventTraces.map((trace) => trace.medicationEventId), [
        'dose_a',
        'dose_b',
      ]);
      expect(
        forward.perEventTraces
            .where((trace) => trace.isPrimary)
            .single
            .medicationEventId,
        'dose_a',
      );
      expect(
        forward.perEventTraces.where((trace) => trace.isPrimary),
        hasLength(1),
      );
    },
  );

  test(
    'multi-dose: unverified non-target event blocks the modeled timeline',
    () {
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
      final composition = normalizer.normalize(
        mealId: 'c1',
        components: const [highProtein],
      );
      final r = engine.evaluate(
        context: ctx,
        mealCompositionsById: {'c1': composition},
      );
      expect(r.hasModeledOutput, isFalse);
      expect(r.availability, MechanisticResultAvailability.insufficient);
      expect(r.perEventCount, 0);
      expect(
        r.explanation.missingOrUncertainInputs,
        contains(
          MechanisticMedicationApplicabilityReason.activeIngredientNotLevodopa,
        ),
      );
    },
  );

  test('generic ER formulation makes the conflict engine abstain', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    TimeAxisConflictContext ctxFor(RawMedicationEntry e) => makeContext(
      now: now,
      medEntry: e,
      medTakenAt: now.add(const Duration(minutes: 20)),
      mealStartedAt: now,
    );
    final composition = normalizer.normalize(
      mealId: 'c1',
      components: const [highProtein],
    );
    final er = engine.evaluate(
      context: ctxFor(validLevodopaER),
      mealCompositionsById: {'c1': composition},
    );
    expect(
      er.interactionType,
      MechanisticInteractionType.insufficientMedicationContext,
    );
    expect(er.availability, MechanisticResultAvailability.notApplicable);
    expect(er.confidenceBand, ConfidenceBand.insufficient);
    expect(er.absorptionOpportunityWindow, isNull);
    expect(
      er.explanation.missingOrUncertainInputs,
      contains('mechanistic_applicability.release_type_not_supported'),
    );
  });

  test('applicability status maps conservatively to result availability', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final composition = normalizer.normalize(
      mealId: 'c1',
      components: const [highProtein],
    );
    RawMedicationEntry medication({
      List<String> ingredients = const ['carbidopa', 'levodopa'],
      String form = 'tablet',
      String releaseType = 'immediate',
    }) => RawMedicationEntry(
      activeIngredients: ingredients,
      drugProductVariant: 'synthetic:availability-map',
      strength: 100,
      unit: 'mg',
      form: form,
      route: 'oral',
      releaseType: releaseType,
      jurisdiction: 'US',
      sourceDocId: 'synthetic:availability-map',
    );

    final cases =
        <
          ({
            String label,
            RawMedicationEntry entry,
            MechanisticResultAvailability expected,
          })
        >[
          (
            label: 'unknown release',
            entry: medication(releaseType: 'banana'),
            expected: MechanisticResultAvailability.insufficient,
          ),
          (
            label: 'known extended release',
            entry: medication(releaseType: 'extended'),
            expected: MechanisticResultAvailability.notApplicable,
          ),
          (
            label: 'known capsule',
            entry: medication(form: 'capsule'),
            expected: MechanisticResultAvailability.notApplicable,
          ),
          (
            label: 'known triple product',
            entry: medication(
              ingredients: const ['carbidopa', 'levodopa', 'entacapone'],
            ),
            expected: MechanisticResultAvailability.notApplicable,
          ),
        ];

    for (final testCase in cases) {
      final result = engine.evaluate(
        context: makeContext(
          now: now,
          medEntry: testCase.entry,
          medTakenAt: now.add(const Duration(minutes: 20)),
          mealStartedAt: now,
        ),
        mealCompositionsById: {'c1': composition},
      );
      expect(result.availability, testCase.expected, reason: testCase.label);
      expect(result.hasModeledOutput, isFalse, reason: testCase.label);
      expect(
        result.toJson()['interaction_score'],
        isNull,
        reason: testCase.label,
      );
      expect(result.toJson()['severity_band'], isNull, reason: testCase.label);
    }
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
    final compA = normalizer.normalize(
      mealId: 'cA',
      components: const [lowProtein],
    );
    final compB = normalizer.normalize(
      mealId: 'cB',
      components: const [highProtein],
    );
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
    final historical = normalizer.normalize(
      mealId: 'historical',
      components: const [lowProtein],
    );
    final hypothetical = normalizer.normalize(
      mealId: 'hypothetical',
      components: const [highProtein],
    );
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

    final ordinary = engine.evaluate(
      context: ctx,
      mealCompositionsById: compositions,
    );
    final preferred = engine.evaluate(
      context: ctx,
      mealCompositionsById: compositions,
      preferredMealId: 'hypothetical_meal',
    );

    expect(ordinary.primaryEmptyingProfile?.mealId, 'historical_meal');
    expect(preferred.primaryEmptyingProfile?.mealId, 'hypothetical_meal');
  });

  test(
    'future candidate timing changes competition but never dose absorption',
    () {
      final now = DateTime.utc(2026, 1, 1, 8);
      final referenceMinute = dateTimeToMinute(now);
      final medication = MedicationTimelineEvent(
        id: 'dose',
        minute: referenceMinute,
        context: validator.validate(validLevodopa).normalized!,
      );
      final composition = normalizer.normalize(
        mealId: 'future_candidate_composition',
        components: const [highProtein],
      );
      final historicalComposition = normalizer.normalize(
        mealId: 'known_dose_time_composition',
        components: const [highProtein],
      );

      MechanisticConflictResult evaluateFuture(int offsetMinutes) {
        final mealId = 'future_meal_$offsetMinutes';
        return engine.evaluate(
          context: TimeAxisConflictContext(
            referenceMinute: referenceMinute,
            medicationEvents: [medication],
            mealEvents: [
              MealTimelineEvent(
                id: 'known_dose_time_meal',
                minute: referenceMinute - 300,
                compositionId: historicalComposition.id,
                physicalForm: MealPhysicalForm.solid,
              ),
              MealTimelineEvent(
                id: mealId,
                minute: referenceMinute + offsetMinutes,
                compositionId: composition.id,
                physicalForm: MealPhysicalForm.solid,
              ),
            ],
          ),
          mealCompositionsById: {
            historicalComposition.id: historicalComposition,
            composition.id: composition,
          },
          preferredMealId: mealId,
        );
      }

      final plus60 = evaluateFuture(60);
      final plus300 = evaluateFuture(300);
      final window60 = plus60.absorptionOpportunityWindow!;
      final window300 = plus300.absorptionOpportunityWindow!;

      expect(plus60.hasModeledOutput, isTrue);
      expect(plus300.hasModeledOutput, isTrue);
      expect(
        window60.window.startMinute,
        referenceMinute +
            LevodopaAbsorptionOpportunityModel.referenceIrLagMinutes,
      );
      expect(window300.window.startMinute, window60.window.startMinute);
      expect(window300.window.endMinute, window60.window.endMinute);
      expect(window300.peakMinute, window60.peakMinute);
      expect(
        window300.delayedArrivalLikelihood,
        window60.delayedArrivalLikelihood,
      );
      expect(window60.delayedArrivalLikelihood, DelayedArrivalLikelihood.low);
      expect(plus60.competitionTimeline, isNotNull);
      expect(plus300.competitionTimeline, isNotNull);
      expect(
        plus60.modeledInteractionScore!,
        greaterThan(plus300.modeledInteractionScore!),
      );
    },
  );

  test('confidence cannot be narrower than sparse dose-time gastric input', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final referenceMinute = dateTimeToMinute(now);
    final target = normalizer.normalize(
      mealId: 'complete_future_target',
      components: const [highProtein],
    );
    final sparseHistorical = normalizer.normalize(
      mealId: 'sparse_dose_time_meal',
      components: const [
        FoodComponent(
          id: 'sparse_dose_time_food',
          name: 'sparse dose-time fixture',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: 10,
          fatGrams: null,
          fiberGrams: null,
          carbohydrateGrams: null,
          calories: null,
          portionGrams: null,
          sourceDocId: 'synthetic:sparse-dose-time',
        ),
      ],
    );
    final result = engine.evaluate(
      context: TimeAxisConflictContext(
        referenceMinute: referenceMinute,
        medicationEvents: [
          MedicationTimelineEvent(
            id: 'dose',
            minute: referenceMinute,
            context: validator.validate(validLevodopa).normalized!,
          ),
        ],
        mealEvents: [
          MealTimelineEvent(
            id: 'sparse_historical_meal',
            minute: referenceMinute - 30,
            compositionId: sparseHistorical.id,
            physicalForm: MealPhysicalForm.solid,
          ),
          MealTimelineEvent(
            id: 'complete_future_meal',
            minute: referenceMinute + 60,
            compositionId: target.id,
            physicalForm: MealPhysicalForm.solid,
          ),
        ],
      ),
      mealCompositionsById: {
        sparseHistorical.id: sparseHistorical,
        target.id: target,
      },
      preferredMealId: 'complete_future_meal',
    );

    expect(result.hasModeledOutput, isTrue);
    expect(result.primaryEmptyingProfile?.mealId, 'complete_future_meal');
    expect(
      result.absorptionOpportunityWindow?.uncertaintyBand,
      UncertaintyBand.veryWide,
    );
    expect(result.confidenceBand, ConfidenceBand.low);
    expect(
      result.uncertaintyReasons,
      contains('absorption_uncertainty_veryWide'),
    );
  });

  test('future-only meal without fasting evidence abstains', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final referenceMinute = dateTimeToMinute(now);
    final composition = normalizer.normalize(
      mealId: 'future_only_composition',
      components: const [highProtein],
    );
    final result = engine.evaluate(
      context: TimeAxisConflictContext(
        referenceMinute: referenceMinute,
        medicationEvents: [
          MedicationTimelineEvent(
            id: 'dose',
            minute: referenceMinute,
            context: validator.validate(validLevodopa).normalized!,
          ),
        ],
        mealEvents: [
          MealTimelineEvent(
            id: 'future_only_meal',
            minute: referenceMinute + 60,
            compositionId: composition.id,
          ),
        ],
      ),
      mealCompositionsById: {composition.id: composition},
      preferredMealId: 'future_only_meal',
    );

    expect(result.availability, MechanisticResultAvailability.insufficient);
    expect(result.hasModeledOutput, isFalse);
    expect(result.uncertaintyReasons, contains('dose_time_meal_context(dose)'));
    expect(result.absorptionOpportunityWindow, isNull);
    expect(result.competitionTimeline, isNull);
    expect(result.toJson()['interaction_score'], isNull);
  });

  test('ancient last meal cannot unlock dose-time gastric context', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final referenceMinute = dateTimeToMinute(now);
    final historicalComposition = normalizer.normalize(
      mealId: 'ancient_history_composition',
      components: const [highProtein],
    );
    final targetComposition = normalizer.normalize(
      mealId: 'future_target_composition',
      components: const [highProtein],
    );
    final result = engine.evaluate(
      context: TimeAxisConflictContext(
        referenceMinute: referenceMinute,
        medicationEvents: [
          MedicationTimelineEvent(
            id: 'dose',
            minute: referenceMinute,
            context: validator.validate(validLevodopa).normalized!,
          ),
        ],
        mealEvents: [
          MealTimelineEvent(
            id: 'ancient_history',
            minute: referenceMinute - const Duration(hours: 24).inMinutes,
            compositionId: historicalComposition.id,
            physicalForm: MealPhysicalForm.solid,
          ),
          MealTimelineEvent(
            id: 'future_target',
            minute: referenceMinute + 60,
            compositionId: targetComposition.id,
            physicalForm: MealPhysicalForm.solid,
          ),
        ],
      ),
      mealCompositionsById: {
        historicalComposition.id: historicalComposition,
        targetComposition.id: targetComposition,
      },
      preferredMealId: 'future_target',
    );

    expect(result.availability, MechanisticResultAvailability.insufficient);
    expect(result.hasModeledOutput, isFalse);
    expect(
      result.uncertaintyReasons,
      contains('dose_time_meal_context_stale(dose,ancient_history)'),
    );
    expect(result.absorptionOpportunityWindow, isNull);
    expect(result.competitionTimeline, isNull);
    expect(result.toJson()['interaction_score'], isNull);
  });

  test('missing preferred meal returns insufficient meal context', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final ctx = makeContext(
      now: now,
      medEntry: validLevodopa,
      medTakenAt: now,
      mealStartedAt: now,
    );
    final composition = normalizer.normalize(
      mealId: 'c1',
      components: const [highProtein],
    );

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
    final composition = normalizer.normalize(
      mealId: 'c1',
      components: const [highProtein],
    );
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
