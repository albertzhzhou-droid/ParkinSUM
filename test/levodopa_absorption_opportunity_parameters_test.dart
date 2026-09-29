import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/algorithm_sdk/parkinsum_algorithm_sdk.dart';
import 'package:parkinsum_companion/domain/entities/absorption_opportunity.dart';
import 'package:parkinsum_companion/domain/entities/gastric_emptying_profile.dart';
import 'package:parkinsum_companion/domain/entities/medication_entry_validation.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/levodopa_absorption_opportunity_model.dart';

void main() {
  test('default parameter set is exact, finite, and immutable', () {
    final parameters =
        LevodopaAbsorptionOpportunityParameterSet.prototypeDefault();

    expect(parameters.validationErrors, isEmpty);
    expect(
      parameters.numericValues.keys.toSet(),
      LevodopaAbsorptionOpportunityParameterIds.numeric,
    );
    expect(
      () =>
          parameters.numericValues[LevodopaAbsorptionOpportunityParameterIds
                  .irTailOpenness] =
              0.5,
      throwsUnsupportedError,
    );
    expect(
      parameters.toJson(),
      containsPair(
        r'$schema',
        LevodopaAbsorptionOpportunityParameterSet.schema,
      ),
    );
  });

  test('invalid bounds, ordering, divisors, and identity fail before use', () {
    final defaults =
        LevodopaAbsorptionOpportunityParameterSet.prototypeDefault();
    final invalidFactories = <Object? Function()>[
      () => defaults.copyWith(highResidualThreshold: double.nan),
      () => defaults.copyWith(moderateResidualThreshold: 0.7),
      () => defaults.copyWith(referenceIrDurationMinutes: 0),
      () => defaults.copyWith(opennessSampleStrideMinutes: 0),
      () => defaults.copyWith(moderateResidualShiftDivisor: 0),
      () => defaults.copyWith(peakOffsetDurationDivisor: 0),
      () => defaults.copyWith(irPeakOpenness: 0.1, irTailOpenness: 0.2),
      () => defaults.copyWith(id: 'unsafe identity'),
      () => defaults.copyWith(lastReviewed: '2026-02-31'),
    ];

    for (final factory in invalidFactories) {
      expect(factory, throwsArgumentError);
    }
  });

  test('every numeric leaf changes canonical configuration identity', () {
    final defaults =
        LevodopaAbsorptionOpportunityParameterSet.prototypeDefault();
    final baseline = AlgorithmConfigurationIdentity.defaults(
      absorptionParameters: defaults,
    ).sha256Digest;
    final mutations = <String, LevodopaAbsorptionOpportunityParameterSet>{
      LevodopaAbsorptionOpportunityParameterIds.referenceIrLagMinutes: defaults
          .copyWith(referenceIrLagMinutes: 6),
      LevodopaAbsorptionOpportunityParameterIds.referenceIrDurationMinutes:
          defaults.copyWith(referenceIrDurationMinutes: 91),
      LevodopaAbsorptionOpportunityParameterIds.illustrativeMealDelayMinutes:
          defaults.copyWith(illustrativeMealDelayMinutes: 35),
      LevodopaAbsorptionOpportunityParameterIds.highResidualThreshold: defaults
          .copyWith(highResidualThreshold: 0.75),
      LevodopaAbsorptionOpportunityParameterIds.moderateResidualThreshold:
          defaults.copyWith(moderateResidualThreshold: 0.35),
      LevodopaAbsorptionOpportunityParameterIds.highResidualEndDelayMultiplier:
          defaults.copyWith(highResidualEndDelayMultiplier: 3),
      LevodopaAbsorptionOpportunityParameterIds.moderateResidualShiftDivisor:
          defaults.copyWith(moderateResidualShiftDivisor: 3),
      LevodopaAbsorptionOpportunityParameterIds.peakOffsetDurationDivisor:
          defaults.copyWith(peakOffsetDurationDivisor: 4),
      LevodopaAbsorptionOpportunityParameterIds.opennessSampleStrideMinutes:
          defaults.copyWith(opennessSampleStrideMinutes: 7),
      LevodopaAbsorptionOpportunityParameterIds.irPeakOpenness: defaults
          .copyWith(irPeakOpenness: 0.9),
      LevodopaAbsorptionOpportunityParameterIds.irTailOpenness: defaults
          .copyWith(irTailOpenness: 0.2),
    };

    expect(
      mutations.keys.toSet(),
      LevodopaAbsorptionOpportunityParameterIds.numeric,
    );
    for (final mutation in mutations.entries) {
      expect(
        AlgorithmConfigurationIdentity.defaults(
          absorptionParameters: mutation.value,
        ).sha256Digest,
        isNot(baseline),
        reason: mutation.key,
      );
    }
  });

  test(
    'custom absorption values do not inherit the reviewed default witness',
    () {
      final defaults =
          LevodopaAbsorptionOpportunityParameterSet.prototypeDefault();
      final defaultCoverage = AlgorithmConfigurationIdentity.defaults()
          .configurationCoverageManifest
          .entryFor('levodopa_absorption_opportunity');
      final customCoverage =
          AlgorithmConfigurationIdentity.defaults(
            absorptionParameters: defaults.copyWith(
              version: 'test-tail-openness-v1',
              irTailOpenness: 0.2,
            ),
          ).configurationCoverageManifest.entryFor(
            'levodopa_absorption_opportunity',
          );

      expect(defaultCoverage.completePerFieldCoverageProven, isTrue);
      expect(customCoverage.hasExplicitFieldRecords, isTrue);
      expect(customCoverage.completePerFieldCoverageProven, isFalse);
      expect(customCoverage.completenessWitness, isNull);
      expect(customCoverage.limitation, contains('not proof of complete'));
    },
  );

  test('default branch outputs remain bit-for-bit compatible', () {
    final model = LevodopaAbsorptionOpportunityModel();
    final medication = _medication();

    final high = model.build(
      medication: medication,
      overlappingMealProfile: _profileWithResidual(0.8),
    );
    expect(high.window.startMinute, 99);
    expect(high.window.endMinute, 223);
    expect(high.peakMinute, 129);
    expect(high.delayedArrivalLikelihood, DelayedArrivalLikelihood.high);

    final moderate = model.build(
      medication: medication,
      overlappingMealProfile: _profileWithResidual(0.6),
    );
    expect(moderate.window.startMinute, 82);
    expect(moderate.window.endMinute, 189);
    expect(moderate.peakMinute, 112);
    expect(
      moderate.delayedArrivalLikelihood,
      DelayedArrivalLikelihood.moderate,
    );

    final low = model.build(
      medication: medication,
      overlappingMealProfile: _profileWithResidual(0.2),
    );
    expect(low.window.startMinute, 65);
    expect(low.window.endMinute, 155);
    expect(low.peakMinute, 95);
    expect(low.delayedArrivalLikelihood, DelayedArrivalLikelihood.low);
  });

  test('custom values are consumed and a non-dividing stride retains peak', () {
    final parameters =
        LevodopaAbsorptionOpportunityParameterSet.prototypeDefault().copyWith(
          referenceIrLagMinutes: 6,
          referenceIrDurationMinutes: 91,
          illustrativeMealDelayMinutes: 35,
          highResidualThreshold: 0.65,
          moderateResidualThreshold: 0.3,
          highResidualEndDelayMultiplier: 3,
          moderateResidualShiftDivisor: 3,
          peakOffsetDurationDivisor: 4,
          opennessSampleStrideMinutes: 7,
          irPeakOpenness: 0.9,
          irTailOpenness: 0.2,
        );
    final result = LevodopaAbsorptionOpportunityModel(parameters: parameters)
        .build(
          medication: _medication(),
          overlappingMealProfile: _profileWithResidual(0.8),
        );

    expect(result.availability, MechanisticProviderAvailability.available);
    expect(result.window.startMinute, 101);
    expect(result.window.endMinute, 262);
    expect(result.peakMinute, 123);
    expect(
      result.opennessProfile
          .singleWhere((sample) => sample.minute == 123)
          .openness,
      0.9,
    );
    expect(result.opennessProfile.first.openness, 0);
    expect(result.opennessProfile.last.minute, 262);
    expect(result.opennessProfile.last.openness, closeTo(0.2, 1e-12));
  });
}

MedicationTimelineEvent _medication() => MedicationTimelineEvent(
  id: 'dose',
  minute: 60,
  context: const NormalizedMedicationContext(
    drugProductVariant: 'synthetic:ir',
    activeIngredients: ['carbidopa', 'levodopa'],
    strength: 100,
    unit: 'mg',
    form: 'tablet',
    route: 'oral',
    releaseType: 'immediate',
    jurisdiction: 'US',
    sourceDocId: 'synthetic:parameter-contract',
    labelSection: 'clinical_pharmacology',
    extractionConfidence: 1,
    limitationText: 'Synthetic engineering fixture only.',
  ),
);

GastricEmptyingProfile _profileWithResidual(double residual) =>
    GastricEmptyingProfile(
      mealId: 'meal',
      componentProfiles: [_FixedResidualComponent(residual)],
      uncertaintyBand: UncertaintyBand.narrow,
      assumptions: const ['synthetic:fixed-residual'],
      missingInputs: const [],
      sourceRefs: const ['src.internal.prototype.heuristic'],
      aggregateLagMinutes: 0,
      peakEmptyingWindow: const TimelineWindow(startMinute: 0, endMinute: 90),
      mostlyEmptiedWindow: const TimelineWindow(startMinute: 0, endMinute: 240),
      timeScaleSensitivityFraction: 0.2,
    );

final class _FixedResidualComponent extends EmptyingComponentProfile {
  final double residual;

  _FixedResidualComponent(this.residual)
    : super(
        componentId: 'component',
        physicalForm: MealPhysicalForm.solid,
        lagMinutes: 0,
        halfEmptyingMinutes: 60,
        fractionOfMeal: 1,
        appliedModifiers: const [],
      );

  @override
  double remainingFractionAt(int minutesSinceMealStart) => residual;
}
