import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_conflict_result.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_medication_applicability.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/levodopa_absorption_opportunity_model.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_next_meal_scorer.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';
import 'package:parkinsum_companion/domain/usecases/time_axis_builder.dart';

void main() {
  final validator = MedicationEntryValidator();
  const policy = MechanisticMedicationApplicabilityPolicy();

  MedicationTimelineEvent event({
    List<String> ingredients = const ['carbidopa', 'levodopa'],
    String route = 'oral',
    String form = 'tablet',
    String releaseType = 'immediate',
  }) {
    final validation = validator.validate(
      RawMedicationEntry(
        activeIngredients: ingredients,
        drugProductVariant: 'synthetic:test',
        strength: 100,
        unit: 'mg',
        form: form,
        route: route,
        releaseType: releaseType,
        jurisdiction: 'US',
        sourceDocId: 'synthetic:test',
      ),
    );
    expect(validation.eligibleForRuleEvaluation, isTrue);
    return MedicationTimelineEvent(
      id: 'med',
      minute: 100,
      context: validation.normalized!,
    );
  }

  test(
    'ingredient tokenizer splits governed combination delimiters and case',
    () {
      final tokens = CanonicalMedicationIngredientTokenizer.tokenize(const [
        ' CARBIDOPA / LeVoDoPa+Entacapone, LEVODOPA ',
      ]);

      expect(tokens, const ['carbidopa', 'levodopa', 'entacapone']);
      expect(
        CanonicalMedicationIngredientTokenizer.containsExact(const [
          'not-levodopa-like',
        ], 'levodopa'),
        isFalse,
      );
    },
  );

  test('default immediate_release oral tablet context is applicable', () {
    final applicability = policy.evaluate(
      event(
        ingredients: const ['Levodopa/Carbidopa'],
        releaseType: 'immediate_release',
      ).context,
    );

    expect(applicability.applicable, isTrue);
    expect(
      applicability.status,
      MechanisticMedicationApplicabilityStatus.applicable,
    );
    expect(applicability.toJson()['status'], 'applicable');
    expect(applicability.releaseProfile, MechanisticReleaseProfile.immediate);
  });

  test('non-levodopa and fake substrings fail exact ingredient identity', () {
    for (final ingredients in const [
      ['ferrous sulfate'],
      ['levodopa-like'],
      ['notlevodopa'],
    ]) {
      final applicability = policy.evaluate(
        event(ingredients: ingredients).context,
      );
      expect(applicability.applicable, isFalse, reason: '$ingredients');
      expect(
        applicability.status,
        MechanisticMedicationApplicabilityStatus.insufficient,
        reason: '$ingredients',
      );
      expect(
        applicability.reasonCodes,
        contains(
          MechanisticMedicationApplicabilityReason.activeIngredientNotLevodopa,
        ),
      );
    }
  });

  test('levodopa without exact carbidopa is outside the v1 model domain', () {
    final applicability = policy.evaluate(
      event(ingredients: const ['levodopa']).context,
    );

    expect(applicability.applicable, isFalse);
    expect(
      applicability.status,
      MechanisticMedicationApplicabilityStatus.insufficient,
    );
    expect(
      applicability.reasonCodes,
      contains(
        MechanisticMedicationApplicabilityReason.carbidopaComponentRequired,
      ),
    );
  });

  test('exact triple product is known outside the v1 combination domain', () {
    final applicability = policy.evaluate(
      event(ingredients: const ['levodopa/carbidopa/entacapone']).context,
    );

    expect(
      applicability.status,
      MechanisticMedicationApplicabilityStatus.notApplicable,
    );
    expect(
      applicability.reasonCodes,
      contains(
        MechanisticMedicationApplicabilityReason
            .activeIngredientCombinationNotSupported,
      ),
    );
  });

  test('unknown evidence outranks known-out evidence in one context', () {
    final applicability = policy.evaluate(
      event(
        ingredients: const ['levodopa', 'carbidopa', 'entacapone'],
        releaseType: 'unrecognized-release-typo',
      ).context,
    );

    expect(
      applicability.status,
      MechanisticMedicationApplicabilityStatus.insufficient,
    );
    expect(
      applicability.reasonCodes,
      contains(
        MechanisticMedicationApplicabilityReason
            .activeIngredientCombinationNotSupported,
      ),
    );
    expect(
      applicability.reasonCodes,
      contains(
        MechanisticMedicationApplicabilityReason.releaseTypeNotSupported,
      ),
    );
  });

  test(
    'duplicate tokens, order, and case do not change exact set identity',
    () {
      final applicability = policy.evaluate(
        event(
          ingredients: const ['LEVODOPA', 'carbidopa', 'levodopa', 'CARBIDOPA'],
        ).context,
      );

      expect(
        applicability.status,
        MechanisticMedicationApplicabilityStatus.applicable,
      );
      expect(applicability.reasonCodes, isEmpty);
    },
  );

  test('one unsupported levodopa event makes the mixed timeline abstain', () {
    final applicability = policy.evaluateContexts([
      event().context,
      event(route: 'transdermal').context,
    ]);

    expect(applicability.applicable, isFalse);
    expect(
      applicability.status,
      MechanisticMedicationApplicabilityStatus.notApplicable,
    );
    expect(
      applicability.reasonCodes,
      contains(MechanisticMedicationApplicabilityReason.routeNotSupported),
    );
  });

  test('a triple product makes the whole mixed timeline abstain', () {
    final applicability = policy.evaluateContexts([
      event().context,
      event(ingredients: const ['carbidopa', 'levodopa', 'entacapone']).context,
    ]);

    expect(
      applicability.status,
      MechanisticMedicationApplicabilityStatus.notApplicable,
    );
    expect(
      applicability.reasonCodes,
      contains(
        MechanisticMedicationApplicabilityReason
            .activeIngredientCombinationNotSupported,
      ),
    );
  });

  test('unverified non-target medication blocks a mixed timeline', () {
    final applicability = policy.evaluateContexts([
      event(ingredients: const ['ferrous sulfate']).context,
      event().context,
    ]);

    expect(
      applicability.status,
      MechanisticMedicationApplicabilityStatus.insufficient,
    );
    expect(
      applicability.reasonCodes,
      contains(
        MechanisticMedicationApplicabilityReason.activeIngredientNotLevodopa,
      ),
    );
  });

  test(
    'unknown context outranks a known-out context in either input order',
    () {
      final knownOut = event(route: 'transdermal').context;
      final unknown = event(ingredients: const ['ferrous sulfate']).context;

      for (final contexts in [
        [knownOut, unknown],
        [unknown, knownOut],
      ]) {
        final applicability = policy.evaluateContexts(contexts);
        expect(
          applicability.status,
          MechanisticMedicationApplicabilityStatus.insufficient,
        );
        expect(
          applicability.reasonCodes,
          contains(MechanisticMedicationApplicabilityReason.routeNotSupported),
        );
        expect(
          applicability.reasonCodes,
          contains(
            MechanisticMedicationApplicabilityReason
                .activeIngredientNotLevodopa,
          ),
        );
      }
    },
  );

  for (final boundary
      in <
        ({
          String label,
          String route,
          String form,
          String releaseType,
          String reason,
          MechanisticMedicationApplicabilityStatus expectedStatus,
        })
      >[
        (
          label: 'route',
          route: 'transdermal',
          form: 'tablet',
          releaseType: 'immediate',
          reason: MechanisticMedicationApplicabilityReason.routeNotSupported,
          expectedStatus:
              MechanisticMedicationApplicabilityStatus.notApplicable,
        ),
        (
          label: 'dosage form',
          route: 'oral',
          form: 'patch',
          releaseType: 'immediate',
          reason:
              MechanisticMedicationApplicabilityReason.dosageFormNotSupported,
          expectedStatus:
              MechanisticMedicationApplicabilityStatus.notApplicable,
        ),
        (
          label: 'capsule formulation',
          route: 'oral',
          form: 'capsule',
          releaseType: 'immediate',
          reason:
              MechanisticMedicationApplicabilityReason.dosageFormNotSupported,
          expectedStatus:
              MechanisticMedicationApplicabilityStatus.notApplicable,
        ),
        (
          label: 'release type',
          route: 'oral',
          form: 'tablet',
          releaseType: 'immediate_or_extended_release',
          reason:
              MechanisticMedicationApplicabilityReason.releaseTypeNotSupported,
          expectedStatus: MechanisticMedicationApplicabilityStatus.insufficient,
        ),
        (
          label: 'extended release',
          route: 'oral',
          form: 'tablet',
          releaseType: 'extended',
          reason:
              MechanisticMedicationApplicabilityReason.releaseTypeNotSupported,
          expectedStatus:
              MechanisticMedicationApplicabilityStatus.notApplicable,
        ),
        (
          label: 'controlled release',
          route: 'oral',
          form: 'tablet',
          releaseType: 'controlled',
          reason:
              MechanisticMedicationApplicabilityReason.releaseTypeNotSupported,
          expectedStatus:
              MechanisticMedicationApplicabilityStatus.notApplicable,
        ),
        (
          label: 'delayed release',
          route: 'oral',
          form: 'tablet',
          releaseType: 'delayed_release',
          reason:
              MechanisticMedicationApplicabilityReason.releaseTypeNotSupported,
          expectedStatus:
              MechanisticMedicationApplicabilityStatus.notApplicable,
        ),
        (
          label: 'arbitrary release type',
          route: 'oral',
          form: 'tablet',
          releaseType: 'banana',
          reason:
              MechanisticMedicationApplicabilityReason.releaseTypeNotSupported,
          expectedStatus: MechanisticMedicationApplicabilityStatus.insufficient,
        ),
      ]) {
    test('unsupported ${boundary.label} abstains without an IR curve', () {
      final medication = event(
        route: boundary.route,
        form: boundary.form,
        releaseType: boundary.releaseType,
      );
      final applicability = policy.evaluate(medication.context);
      final absorption = LevodopaAbsorptionOpportunityModel().build(
        medication: medication,
      );

      expect(applicability.applicable, isFalse);
      expect(applicability.status, boundary.expectedStatus);
      expect(applicability.reasonCodes, contains(boundary.reason));
      expect(absorption.window.durationMinutes, 0);
      expect(absorption.opennessProfile, isEmpty);
      expect(absorption.modelApplicable, isFalse);
      expect(absorption.applicabilityReasons, contains(boundary.reason));
      expect(absorption.missingInputs, contains(boundary.reason));
      expect(absorption.toJson()['model_applicable'], isFalse);
      expect(
        absorption.toJson()['applicability_reasons'],
        contains(boundary.reason),
      );
    });
  }

  test(
    'conflict engine does not fall back to the first non-levodopa event',
    () {
      final iron = event(ingredients: const ['ferrous sulfate']);
      final context = TimeAxisConflictContext(
        referenceMinute: 100,
        medicationEvents: [iron],
        mealEvents: const [],
      );

      final result = MechanisticConflictEngine().evaluate(
        context: context,
        mealCompositionsById: const {},
      );

      expect(
        result.interactionType,
        MechanisticInteractionType.insufficientMedicationContext,
      );
      expect(result.confidenceBand, ConfidenceBand.insufficient);
      expect(result.absorptionOpportunityWindow, isNull);
      expect(
        result.explanation.missingOrUncertainInputs,
        contains(
          MechanisticMedicationApplicabilityReason.activeIngredientNotLevodopa,
        ),
      );
    },
  );

  test('candidate scorer abstains when no exact levodopa event exists', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final ironValidation = validator.validate(
      const RawMedicationEntry(
        activeIngredients: ['ferrous sulfate'],
        drugProductVariant: 'synthetic:iron',
        strength: 65,
        unit: 'mg',
        form: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        jurisdiction: 'US',
        sourceDocId: 'synthetic:iron',
      ),
    );
    final context = TimeAxisBuilder().build(
      now: now,
      medicationInputs: [
        MedicationTimelineInput(
          id: 'iron',
          takenAt: now,
          medicationContext: ironValidation,
        ),
      ],
      mealInputs: const [],
      userDefinedWindow: UserDefinedMealWindow(
        window: TimelineWindow(
          startMinute: dateTimeToMinute(now) + 30,
          endMinute: dateTimeToMinute(now) + 60,
        ),
        source: 'test',
      ),
    );
    final scores = MechanisticNextMealScorer().score(
      baseContext: context,
      baseMealCompositionsById: const {},
      candidates: const [
        CandidateFood(
          id: 'candidate',
          name: 'Candidate',
          regionalFoodLibraryRef: 'synthetic:test',
          components: [],
        ),
      ],
    );

    expect(scores.single.insufficientContext, isTrue);
    expect(
      scores.single.explanation.join(' '),
      contains(
        MechanisticMedicationApplicabilityReason.activeIngredientNotLevodopa,
      ),
    );
  });

  test('validator rejects NaN and infinite strength before normalization', () {
    for (final strength in <double>[
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      final validation = validator.validate(
        RawMedicationEntry(
          activeIngredients: const ['levodopa'],
          drugProductVariant: 'synthetic:test',
          strength: strength,
          unit: 'mg',
          form: 'tablet',
          route: 'oral',
          releaseType: 'immediate',
          jurisdiction: 'US',
          sourceDocId: 'synthetic:test',
        ),
      );

      expect(validation.eligibleForRuleEvaluation, isFalse);
      expect(validation.normalized, isNull);
      expect(
        validation.issues.map((issue) => issue.code),
        contains('NON_FINITE_STRENGTH'),
      );
    }
  });
}
