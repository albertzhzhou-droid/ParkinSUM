import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/absorption_opportunity.dart';
import 'package:parkinsum_companion/domain/entities/amino_acid_competition.dart';
import 'package:parkinsum_companion/domain/entities/amino_acid_profile.dart';
import 'package:parkinsum_companion/domain/entities/gastric_emptying_profile.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/protein_source.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/amino_acid_competition_model.dart';
import 'package:parkinsum_companion/domain/usecases/gastric_emptying_model.dart';
import 'package:parkinsum_companion/domain/usecases/levodopa_absorption_opportunity_model.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';

/// Guards #3: levodopa absorption is a sampled openness curve (not only a flat
/// window). The current production context of use is carbidopa + levodopa,
/// oral whole tablet, immediate release; other formulations abstain. Candidate
/// competition overlap is openness-weighted. Educational only — not blood
/// concentration, not PK/PD calibration.
void main() {
  final validator = MedicationEntryValidator();
  final absorption = LevodopaAbsorptionOpportunityModel();
  final normalizer = MealCompositionNormalizer();
  final emptying = GastricEmptyingModel();
  final competition = AminoAcidCompetitionModel();

  MedicationTimelineEvent medEvent(String releaseType) {
    final v = validator.validate(
      RawMedicationEntry(
        activeIngredients: const ['carbidopa', 'levodopa'],
        drugProductVariant: 'synthetic:demo',
        strength: 100,
        unit: 'mg',
        form: 'tablet',
        route: 'oral',
        releaseType: releaseType,
        jurisdiction: 'US',
        sourceDocId: 'synthetic:demo',
      ),
    );
    return MedicationTimelineEvent(id: 'm', minute: 60, context: v.normalized!);
  }

  GastricEmptyingProfile mealProfile() {
    final composition = normalizer.normalize(
      mealId: 'synthetic:profile-meal',
      components: const [
        FoodComponent(
          id: 'synthetic:profile-food',
          name: 'profile fixture',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: 10,
          fatGrams: 5,
          fiberGrams: 2,
          carbohydrateGrams: 30,
          calories: 205,
          portionGrams: 150,
          sourceDocId: 'synthetic:profile-food',
        ),
      ],
    );
    return emptying.build(
      mealId: composition.id,
      mealStartMinute: 0,
      composition: composition,
    );
  }

  test('supported IR emits a non-empty openness profile (in toJson)', () {
    final ir = absorption.build(
      medication: medEvent('immediate'),
      overlappingMealProfile: mealProfile(),
    );
    expect(ir.opennessProfile, isNotEmpty);
    expect(ir.toJson()['openness_profile'], isNotEmpty);
    expect(ir.toJson().containsKey('peak_openness'), isTrue);
    expect(ir.toJson()['result_availability'], 'available');
    expect(ir.toJson()['has_modeled_output'], isTrue);
  });

  test('missing gastric context is insufficient and emits no curve', () {
    final result = absorption.build(medication: medEvent('immediate'));
    final wire = result.toJson();
    expect(result.modelApplicable, isFalse);
    expect(result.availability, MechanisticProviderAvailability.insufficient);
    expect(
      result.applicabilityReasons,
      contains('absorption.overlapping_meal_profile_missing'),
    );
    expect(wire['result_availability'], 'insufficient');
    expect(wire['has_modeled_output'], isFalse);
    expect(wire['window'], isNull);
    expect(wire['peak_minute'], isNull);
    expect(wire['peak_openness'], isNull);
    expect(wire['openness_profile'], isEmpty);
  });

  test('generic ER/controlled values abstain instead of sharing one curve', () {
    for (final releaseType in const ['extended', 'controlled']) {
      final result = absorption.build(
        medication: medEvent(releaseType),
        overlappingMealProfile: mealProfile(),
      );
      expect(result.modelApplicable, isFalse, reason: releaseType);
      expect(
        result.availability,
        MechanisticProviderAvailability.notApplicable,
        reason: releaseType,
      );
      expect(result.window.durationMinutes, 0, reason: releaseType);
      expect(result.opennessProfile, isEmpty, reason: releaseType);
    }
  });

  test('available absorption without an openness curve is blocked', () {
    // High-protein solid meal starting at minute 0; dose at +30 min.
    final comp = normalizer.normalize(
      mealId: 'c',
      components: const [
        FoodComponent(
          id: 'p',
          name: 'protein',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: 30,
          fatGrams: 5,
          fiberGrams: 0,
          carbohydrateGrams: 0,
          calories: 200,
          portionGrams: 180,
          sourceDocId: 'synthetic',
        ),
      ],
    );
    final profile = emptying.build(
      mealId: 'c',
      mealStartMinute: 0,
      composition: comp,
    );
    final med = MedicationTimelineEvent(
      id: 'm',
      minute: 30,
      context: medEvent('immediate').context,
    );
    final window = absorption.build(
      medication: med,
      overlappingMealProfile: profile,
    );
    expect(window.opennessProfile, isNotEmpty);

    final weighted = competition.build(
      mealComposition: comp,
      mealEmptyingProfile: profile,
      absorptionWindow: window,
      mealStartMinute: 0,
    );

    // Same inputs, but strip the openness profile. An available upstream
    // result that omits its result-affecting curve is structurally
    // contradictory and must never be replaced with invented flat weights.
    final flatWindow = AbsorptionOpportunityWindow(
      medicationEventId: window.medicationEventId,
      window: window.window,
      peakMinute: window.peakMinute,
      delayedArrivalLikelihood: window.delayedArrivalLikelihood,
      uncertaintyBand: window.uncertaintyBand,
      assumptions: window.assumptions,
      missingInputs: window.missingInputs,
      sourceRefs: window.sourceRefs,
      // opennessProfile defaults to empty.
    );
    final blocked = competition.build(
      mealComposition: comp,
      mealEmptyingProfile: profile,
      absorptionWindow: flatWindow,
      mealStartMinute: 0,
    );

    expect(weighted.hasModeledOutput, isTrue);
    expect(
      weighted.assumptions.any((a) => a.contains('openness_weighted_overlap')),
      isTrue,
    );
    expect(
      blocked.availability,
      MechanisticProviderAvailability.blockedIntegrity,
    );
    expect(
      blocked.applicabilityReasons,
      contains('absorption.profile_samples_empty'),
    );
    final upstreamWire = flatWindow.toJson();
    expect(
      upstreamWire['result_availability'],
      MechanisticProviderAvailability.blockedIntegrity.name,
    );
    expect(upstreamWire['window'], isNull);
    expect(upstreamWire['peak_minute'], isNull);
    expect(upstreamWire['peak_openness'], isNull);
    expect(upstreamWire['openness_profile'], isEmpty);
    expect(() => jsonEncode(upstreamWire), returnsNormally);
    final wire = blocked.toJson();
    expect(wire['has_modeled_output'], isFalse);
    expect(wire['samples'], isEmpty);
    expect(wire['peak_minute'], isNull);
    expect(wire['peak_pressure'], isNull);
    expect(wire['overlap_with_absorption_window'], isNull);
    expect(wire['lnaa_summary'], isNull);
  });

  test('malformed available openness curves are blocked without numerics', () {
    final composition = normalizer.normalize(
      mealId: 'synthetic:malformed-openness-meal',
      components: const [
        FoodComponent(
          id: 'synthetic:malformed-openness-food',
          name: 'protein fixture',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: 20,
          fatGrams: 0,
          fiberGrams: 0,
          carbohydrateGrams: 0,
          calories: 80,
          portionGrams: 100,
          sourceDocId: 'synthetic:malformed-openness-food',
        ),
      ],
    );
    final profile = emptying.build(
      mealId: composition.id,
      mealStartMinute: 0,
      composition: composition,
    );

    final fixtures = <String, List<AbsorptionOpennessSample>>{
      'nonfinite': const [
        AbsorptionOpennessSample(minute: 0, openness: double.nan),
        AbsorptionOpennessSample(minute: 45, openness: double.infinity),
        AbsorptionOpennessSample(minute: 90, openness: 0.2),
      ],
      'duplicate': const [
        AbsorptionOpennessSample(minute: 0, openness: 0.1),
        AbsorptionOpennessSample(minute: 0, openness: 0.2),
        AbsorptionOpennessSample(minute: 90, openness: 0.2),
      ],
      'non-monotonic-time': const [
        AbsorptionOpennessSample(minute: 0, openness: 0.1),
        AbsorptionOpennessSample(minute: 60, openness: 1),
        AbsorptionOpennessSample(minute: 50, openness: 0.8),
        AbsorptionOpennessSample(minute: 90, openness: 0.2),
      ],
      'out-of-range': const [
        AbsorptionOpennessSample(minute: 0, openness: -0.1),
        AbsorptionOpennessSample(minute: 30, openness: 1.1),
        AbsorptionOpennessSample(minute: 90, openness: 0.2),
      ],
      'all-zero': const [
        AbsorptionOpennessSample(minute: 0, openness: 0),
        AbsorptionOpennessSample(minute: 30, openness: 0),
        AbsorptionOpennessSample(minute: 90, openness: 0),
      ],
      'inconsistent-peak': const [
        AbsorptionOpennessSample(minute: 0, openness: 0.1),
        AbsorptionOpennessSample(minute: 30, openness: 0.5),
        AbsorptionOpennessSample(minute: 60, openness: 1),
        AbsorptionOpennessSample(minute: 90, openness: 0.2),
      ],
    };

    for (final fixture in fixtures.entries) {
      final absorptionWindow = AbsorptionOpportunityWindow(
        medicationEventId: 'synthetic:${fixture.key}',
        window: const TimelineWindow(startMinute: 0, endMinute: 90),
        peakMinute: 30,
        delayedArrivalLikelihood: DelayedArrivalLikelihood.low,
        uncertaintyBand: UncertaintyBand.narrow,
        assumptions: const ['synthetic:malformed-openness'],
        missingInputs: const [],
        sourceRefs: const ['synthetic:malformed-openness'],
        opennessProfile: fixture.value,
      );
      expect(
        absorptionWindow.availability,
        MechanisticProviderAvailability.blockedIntegrity,
        reason: fixture.key,
      );
      final upstreamWire = absorptionWindow.toJson();
      expect(upstreamWire['has_modeled_output'], isFalse, reason: fixture.key);
      expect(upstreamWire['window'], isNull, reason: fixture.key);
      expect(upstreamWire['peak_minute'], isNull, reason: fixture.key);
      expect(upstreamWire['peak_openness'], isNull, reason: fixture.key);
      expect(upstreamWire['openness_profile'], isEmpty, reason: fixture.key);
      expect(
        () => jsonEncode(upstreamWire),
        returnsNormally,
        reason: fixture.key,
      );

      final result = competition.build(
        mealComposition: composition,
        mealEmptyingProfile: profile,
        absorptionWindow: absorptionWindow,
        mealStartMinute: 0,
      );

      expect(
        result.availability,
        MechanisticProviderAvailability.blockedIntegrity,
        reason: fixture.key,
      );
      expect(result.hasModeledOutput, isFalse, reason: fixture.key);
      final wire = result.toJson();
      expect(wire['samples'], isEmpty, reason: fixture.key);
      expect(wire['peak_minute'], isNull, reason: fixture.key);
      expect(wire['peak_pressure'], isNull, reason: fixture.key);
      expect(
        wire['overlap_with_absorption_window'],
        isNull,
        reason: fixture.key,
      );
    }
  });

  test('malformed available competition entities serialize null safely', () {
    const summary = CompetitionLnaaSummary(
      effectiveLoadFactor: 1,
      sourcesPresent: [ProteinSourceType.unknown],
      isPrototypeHeuristic: true,
      uncertaintyWidened: true,
      sourceRefs: ['synthetic:competition-entity'],
      dataMode: AminoAcidDataMode.proteinSourceProxy,
      actualAminoAcidProteinCoverageFraction: 0,
    );
    final fixtures = <String, CompetitionPressureTimeline>{
      'empty': const CompetitionPressureTimeline(
        samples: [],
        peakMinute: 0,
        peakPressure: 0,
        overlapWithAbsorptionWindow: 0,
        competitionBand: CompetitionBand.none,
        uncertaintyBand: UncertaintyBand.narrow,
        assumptions: ['synthetic:empty'],
        sourceRefs: ['synthetic:competition-entity'],
        lnaaSummary: summary,
      ),
      'nonfinite': const CompetitionPressureTimeline(
        samples: [
          CompetitionPressureSample(minute: 0, pressure: double.nan),
          CompetitionPressureSample(minute: 5, pressure: double.infinity),
        ],
        peakMinute: 0,
        peakPressure: double.infinity,
        overlapWithAbsorptionWindow: double.nan,
        competitionBand: CompetitionBand.unknown,
        uncertaintyBand: UncertaintyBand.veryWide,
        assumptions: ['synthetic:nonfinite'],
        sourceRefs: ['synthetic:competition-entity'],
        lnaaSummary: summary,
      ),
      'duplicate': const CompetitionPressureTimeline(
        samples: [
          CompetitionPressureSample(minute: 0, pressure: 0.2),
          CompetitionPressureSample(minute: 0, pressure: 0.3),
        ],
        peakMinute: 0,
        peakPressure: 0.3,
        overlapWithAbsorptionWindow: 0.2,
        competitionBand: CompetitionBand.moderate,
        uncertaintyBand: UncertaintyBand.narrow,
        assumptions: ['synthetic:duplicate'],
        sourceRefs: ['synthetic:competition-entity'],
        lnaaSummary: summary,
      ),
      'nonmonotonic': const CompetitionPressureTimeline(
        samples: [
          CompetitionPressureSample(minute: 0, pressure: 0.2),
          CompetitionPressureSample(minute: 10, pressure: 0.5),
          CompetitionPressureSample(minute: 5, pressure: 0.4),
        ],
        peakMinute: 10,
        peakPressure: 0.5,
        overlapWithAbsorptionWindow: 0.2,
        competitionBand: CompetitionBand.moderate,
        uncertaintyBand: UncertaintyBand.narrow,
        assumptions: ['synthetic:nonmonotonic'],
        sourceRefs: ['synthetic:competition-entity'],
        lnaaSummary: summary,
      ),
      'out-of-range': const CompetitionPressureTimeline(
        samples: [
          CompetitionPressureSample(minute: 0, pressure: -0.1),
          CompetitionPressureSample(minute: 5, pressure: 1.1),
        ],
        peakMinute: 5,
        peakPressure: 1.1,
        overlapWithAbsorptionWindow: -0.1,
        competitionBand: CompetitionBand.unknown,
        uncertaintyBand: UncertaintyBand.veryWide,
        assumptions: ['synthetic:out-of-range'],
        sourceRefs: ['synthetic:competition-entity'],
        lnaaSummary: summary,
      ),
      'inconsistent-peak': const CompetitionPressureTimeline(
        samples: [
          CompetitionPressureSample(minute: 0, pressure: 0.2),
          CompetitionPressureSample(minute: 5, pressure: 0.8),
        ],
        peakMinute: 0,
        peakPressure: 0.2,
        overlapWithAbsorptionWindow: 0.2,
        competitionBand: CompetitionBand.moderate,
        uncertaintyBand: UncertaintyBand.narrow,
        assumptions: ['synthetic:inconsistent-peak'],
        sourceRefs: ['synthetic:competition-entity'],
        lnaaSummary: summary,
      ),
      'inconsistent-band': const CompetitionPressureTimeline(
        samples: [
          CompetitionPressureSample(minute: 0, pressure: 0.2),
          CompetitionPressureSample(minute: 5, pressure: 0.8),
        ],
        peakMinute: 5,
        peakPressure: 0.8,
        overlapWithAbsorptionWindow: 0.8,
        competitionBand: CompetitionBand.none,
        uncertaintyBand: UncertaintyBand.veryWide,
        assumptions: ['synthetic:inconsistent-band'],
        sourceRefs: ['synthetic:competition-entity'],
        lnaaSummary: summary,
      ),
    };

    for (final fixture in fixtures.entries) {
      final timeline = fixture.value;
      expect(
        timeline.availability,
        MechanisticProviderAvailability.blockedIntegrity,
        reason: fixture.key,
      );
      final wire = timeline.toJson();
      expect(wire['has_modeled_output'], isFalse, reason: fixture.key);
      expect(wire['samples'], isEmpty, reason: fixture.key);
      expect(wire['peak_minute'], isNull, reason: fixture.key);
      expect(wire['peak_pressure'], isNull, reason: fixture.key);
      expect(
        wire['overlap_with_absorption_window'],
        isNull,
        reason: fixture.key,
      );
      expect(wire['lnaa_summary'], isNull, reason: fixture.key);
      expect(
        () => jsonDecode(jsonEncode(wire)),
        returnsNormally,
        reason: fixture.key,
      );
    }
  });

  test('available competition enforces nested LNAA data-mode semantics', () {
    const invalidSummaries = <String, CompetitionLnaaSummary>{
      'factor-out-of-domain': CompetitionLnaaSummary(
        effectiveLoadFactor: 1.5001,
        sourcesPresent: [ProteinSourceType.unknown],
        isPrototypeHeuristic: true,
        uncertaintyWidened: false,
        sourceRefs: ['synthetic:lnaa-integrity'],
        dataMode: AminoAcidDataMode.proteinSourceProxy,
        actualAminoAcidProteinCoverageFraction: 0,
      ),
      'actual-missing-total': CompetitionLnaaSummary(
        effectiveLoadFactor: 1,
        sourcesPresent: [],
        isPrototypeHeuristic: true,
        uncertaintyWidened: false,
        sourceRefs: ['synthetic:lnaa-integrity'],
        dataMode: AminoAcidDataMode.actualAminoAcidFields,
        partialAminoAcidData: true,
      ),
      'hybrid-pseudo-absolute': CompetitionLnaaSummary(
        effectiveLoadFactor: 1,
        sourcesPresent: [ProteinSourceType.meat],
        isPrototypeHeuristic: true,
        uncertaintyWidened: false,
        sourceRefs: ['synthetic:lnaa-integrity'],
        dataMode: AminoAcidDataMode.hybridActualAndProteinSourceProxy,
        competingLnaaGrams: 3,
        partialAminoAcidData: false,
        actualAminoAcidProteinCoverageFraction: 1,
      ),
      'proxy-claims-actual-coverage': CompetitionLnaaSummary(
        effectiveLoadFactor: 1,
        sourcesPresent: [ProteinSourceType.meat],
        isPrototypeHeuristic: true,
        uncertaintyWidened: false,
        sourceRefs: ['synthetic:lnaa-integrity'],
        dataMode: AminoAcidDataMode.proteinSourceProxy,
        competingLnaaGrams: 3,
        actualAminoAcidProteinCoverageFraction: 1,
      ),
      'unknown-claims-nonzero-factor': CompetitionLnaaSummary(
        effectiveLoadFactor: 1.1,
        sourcesPresent: [ProteinSourceType.unknown],
        isPrototypeHeuristic: true,
        uncertaintyWidened: true,
        sourceRefs: ['synthetic:lnaa-integrity'],
        dataMode: AminoAcidDataMode.unknown,
      ),
    };

    for (final fixture in invalidSummaries.entries) {
      final timeline = CompetitionPressureTimeline(
        samples: const [
          CompetitionPressureSample(minute: 0, pressure: 0.1),
          CompetitionPressureSample(minute: 5, pressure: 0.2),
        ],
        peakMinute: 5,
        peakPressure: 0.2,
        overlapWithAbsorptionWindow: 0.2,
        competitionBand: CompetitionBand.moderate,
        uncertaintyBand: UncertaintyBand.veryWide,
        assumptions: const ['synthetic:lnaa-integrity'],
        sourceRefs: const ['synthetic:lnaa-integrity'],
        lnaaSummary: fixture.value,
      );
      expect(
        timeline.availability,
        MechanisticProviderAvailability.blockedIntegrity,
        reason: fixture.key,
      );
      final wire = timeline.toJson();
      expect(wire['has_modeled_output'], isFalse, reason: fixture.key);
      expect(wire['samples'], isEmpty, reason: fixture.key);
      expect(wire['peak_pressure'], isNull, reason: fixture.key);
      expect(
        wire['overlap_with_absorption_window'],
        isNull,
        reason: fixture.key,
      );
      expect(wire['lnaa_summary'], isNull, reason: fixture.key);
      expect(
        () => jsonDecode(jsonEncode(wire)),
        returnsNormally,
        reason: fixture.key,
      );
    }

    const exactUnknownZero = CompetitionPressureTimeline(
      samples: [
        CompetitionPressureSample(minute: 0, pressure: 0),
        CompetitionPressureSample(minute: 5, pressure: 0),
      ],
      peakMinute: 0,
      peakPressure: 0,
      overlapWithAbsorptionWindow: 0,
      competitionBand: CompetitionBand.none,
      uncertaintyBand: UncertaintyBand.veryWide,
      assumptions: ['synthetic:known-zero-protein'],
      sourceRefs: ['synthetic:lnaa-integrity'],
      lnaaSummary: CompetitionLnaaSummary(
        effectiveLoadFactor: 1,
        sourcesPresent: [ProteinSourceType.unknown],
        isPrototypeHeuristic: true,
        uncertaintyWidened: true,
        sourceRefs: ['synthetic:lnaa-integrity'],
        dataMode: AminoAcidDataMode.unknown,
      ),
    );
    expect(
      exactUnknownZero.availability,
      MechanisticProviderAvailability.available,
    );
    expect(exactUnknownZero.toJson()['peak_pressure'], 0);
  });

  test(
    'same pressure peak scores lower when overlap covers less of window',
    () {
      final composition = normalizer.normalize(
        mealId: 'synthetic:pulse-meal',
        components: const [
          FoodComponent(
            id: 'synthetic:pulse-protein',
            name: 'pulse protein',
            physicalForm: MealPhysicalForm.solid,
            proteinGrams: 20,
            fatGrams: 0,
            fiberGrams: 0,
            carbohydrateGrams: 0,
            calories: 80,
            portionGrams: 100,
            sourceDocId: 'synthetic:pulse-protein',
          ),
        ],
      );
      const pressure = _PulseGastricProfile();

      CompetitionPressureTimeline evaluate(TimelineWindow window) =>
          competition.build(
            mealComposition: composition,
            mealEmptyingProfile: pressure,
            absorptionWindow: AbsorptionOpportunityWindow(
              medicationEventId: 'synthetic:pulse-dose',
              window: window,
              peakMinute: window.startMinute,
              delayedArrivalLikelihood: DelayedArrivalLikelihood.low,
              uncertaintyBand: UncertaintyBand.narrow,
              assumptions: const ['synthetic:constant-openness'],
              missingInputs: const [],
              sourceRefs: const ['synthetic:pulse'],
              opennessProfile: [
                AbsorptionOpennessSample(
                  minute: window.startMinute,
                  openness: 1,
                ),
                AbsorptionOpennessSample(minute: window.endMinute, openness: 1),
              ],
            ),
            mealStartMinute: 0,
          );

      final fullOverlap = evaluate(
        const TimelineWindow(startMinute: 0, endMinute: 20),
      );
      final shortIntersection = evaluate(
        const TimelineWindow(startMinute: -20, endMinute: 60),
      );

      expect(shortIntersection.peakPressure, fullOverlap.peakPressure);
      expect(
        shortIntersection.overlapWithAbsorptionWindow,
        lessThan(fullOverlap.overlapWithAbsorptionWindow),
      );
      expect(
        shortIntersection.assumptions,
        contains('aa.competition.outside_pressure_support_zero'),
      );
    },
  );
}

final class _PulseGastricProfile extends GastricEmptyingProfile {
  const _PulseGastricProfile()
    : super(
        mealId: 'synthetic:pulse-meal',
        componentProfiles: const [
          EmptyingComponentProfile(
            componentId: 'synthetic:pulse-component',
            physicalForm: MealPhysicalForm.solid,
            lagMinutes: 0,
            halfEmptyingMinutes: 10,
            fractionOfMeal: 1,
            appliedModifiers: [],
          ),
        ],
        uncertaintyBand: UncertaintyBand.narrow,
        assumptions: const ['synthetic:pulse'],
        missingInputs: const [],
        sourceRefs: const ['synthetic:pulse'],
        aggregateLagMinutes: 0,
        peakEmptyingWindow: const TimelineWindow(startMinute: 0, endMinute: 15),
        mostlyEmptiedWindow: const TimelineWindow(
          startMinute: 0,
          endMinute: 40,
        ),
        timeScaleSensitivityFraction: 0.2,
      );

  @override
  double intestinalArrivalRateAt(int minutesSinceMealStart) =>
      minutesSinceMealStart >= 0 && minutesSinceMealStart <= 20 ? 1 : 0;
}
