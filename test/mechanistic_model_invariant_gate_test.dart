import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/absorption_opportunity.dart';
import 'package:parkinsum_companion/domain/entities/amino_acid_competition.dart';
import 'package:parkinsum_companion/domain/entities/amino_acid_profile.dart';
import 'package:parkinsum_companion/domain/entities/gastric_emptying_parameters.dart';
import 'package:parkinsum_companion/domain/entities/gastric_emptying_profile.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/medication_entry_validation.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_conflict_result.dart';
import 'package:parkinsum_companion/domain/entities/protein_source.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/amino_acid_competition_model.dart';
import 'package:parkinsum_companion/domain/usecases/gastric_emptying_model.dart';
import 'package:parkinsum_companion/domain/usecases/levodopa_absorption_opportunity_model.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';
import 'package:parkinsum_companion/domain/usecases/next_meal_scoring_parameters.dart';

import 'helpers/mechanistic_model_invariant_verifier.dart';

void main() {
  final verifier = MechanisticModelInvariantVerifier();

  group('declared curve and structural envelope gate', () {
    test('production gastric curve passes all scoped invariants', () {
      final report = verifier.verifyGastricProfile(_productionProfile());

      expect(report.passed, isTrue, reason: _describe(report));
    });

    test(
      'empty gastric input abstains while partial-known input still models',
      () {
        final emptyComposition = MealCompositionNormalizer().normalize(
          mealId: 'synthetic:empty-meal',
          components: const [],
        );
        final abstention = GastricEmptyingModel().build(
          mealId: emptyComposition.id,
          mealStartMinute: 25,
          composition: emptyComposition,
        );
        final wire = abstention.toJson();

        expect(abstention.modelApplicable, isFalse);
        expect(
          abstention.applicabilityReasons,
          contains('gastric_emptying.meal_composition_absent'),
        );
        expect(wire['component_profiles'], isEmpty);
        expect(wire['aggregate_lag_minutes'], isNull);
        expect(wire['peak_emptying_window'], isNull);
        expect(wire['mostly_emptied_window'], isNull);
        expect(wire['time_scale_sensitivity_fraction'], isNull);
        expect(
          verifier.verifyGastricProfile(abstention).passed,
          isTrue,
          reason: _describe(verifier.verifyGastricProfile(abstention)),
        );

        final absorptionFromAbstainedGastric =
            LevodopaAbsorptionOpportunityModel().build(
              medication: _controlledMedication,
              overlappingMealProfile: abstention,
            );
        expect(absorptionFromAbstainedGastric.modelApplicable, isFalse);
        expect(
          absorptionFromAbstainedGastric.applicabilityReasons,
          contains('absorption.gastric_emptying_not_applicable'),
        );
        expect(absorptionFromAbstainedGastric.toJson()['window'], isNull);

        final applicableAbsorption = LevodopaAbsorptionOpportunityModel().build(
          medication: _controlledMedication,
          overlappingMealProfile: _productionProfile(),
        );
        expect(applicableAbsorption.modelApplicable, isTrue);
        final competitionFromAbstainedGastric = AminoAcidCompetitionModel()
            .build(
              mealComposition: _controlledComposition(proteinGrams: 20),
              mealEmptyingProfile: abstention,
              absorptionWindow: applicableAbsorption,
              mealStartMinute: 25,
            );
        expect(competitionFromAbstainedGastric.modelApplicable, isFalse);
        expect(
          competitionFromAbstainedGastric.applicabilityReasons,
          contains('competition.gastric_emptying_not_applicable'),
        );
        expect(
          competitionFromAbstainedGastric.toJson()['peak_pressure'],
          isNull,
        );
        expect(
          verifier
              .verifyCompetitionPressureCurve(competitionFromAbstainedGastric)
              .passed,
          isTrue,
        );

        const partialKnown = MealComposition(
          id: 'synthetic:partial-known-meal',
          totalCalories: 250,
          proteinGrams: null,
          fatGrams: null,
          fiberGrams: null,
          carbohydrateGrams: null,
          liquidFraction: null,
          mealPhysicalForm: MealPhysicalForm.solid,
          portionSizeBand: PortionSizeBand.medium,
          proteinAmountBand: AmountBand.unknown,
          fatAmountBand: AmountBand.unknown,
          fiberAmountBand: AmountBand.unknown,
          calorieBand: AmountBand.moderate,
          compositionCompleteness: 0.25,
          missingFields: [
            'protein_grams',
            'fat_grams',
            'fiber_grams',
            'carbohydrate_grams',
            'portion_grams',
            'liquid_fraction',
          ],
          foodComponents: [],
        );
        final partialProfile = GastricEmptyingModel().build(
          mealId: partialKnown.id,
          mealStartMinute: 25,
          composition: partialKnown,
        );
        expect(partialProfile.modelApplicable, isTrue);
        expect(partialProfile.componentProfiles, hasLength(1));
        expect(
          verifier.verifyGastricProfile(partialProfile).passed,
          isTrue,
          reason: _describe(verifier.verifyGastricProfile(partialProfile)),
        );
      },
    );

    test('production absorption and competition curves are bounded', () {
      final result = _evaluate(strength: 100, unit: 'mg', minute: 120);
      final absorption = verifier.verifyAbsorptionOpportunityCurve(
        result.absorptionOpportunityWindow!,
      );
      final competition = verifier.verifyCompetitionPressureCurve(
        result.competitionTimeline!,
      );

      expect(absorption.passed, isTrue, reason: _describe(absorption));
      expect(competition.passed, isTrue, reason: _describe(competition));
    });

    test('unknown, ER, CR, and DR releases never become an IR curve', () {
      final composition = _controlledComposition(proteinGrams: 20);
      for (final releaseType in const [
        'unknown',
        'extended',
        'extended_release',
        'controlled',
        'controlled_release',
        'delayed',
        'delayed_release',
      ]) {
        final medication = _controlledMedicationWithRelease(releaseType);
        final profile = _productionProfile();
        final absorption = LevodopaAbsorptionOpportunityModel().build(
          medication: medication,
          overlappingMealProfile: profile,
        );
        final curveReport = verifier.verifyAbsorptionOpportunityCurve(
          absorption,
        );
        final wire = absorption.toJson();

        expect(absorption.modelApplicable, isFalse, reason: releaseType);
        expect(absorption.window.durationMinutes, 0, reason: releaseType);
        expect(absorption.opennessProfile, isEmpty, reason: releaseType);
        expect(wire['window'], isNull, reason: releaseType);
        expect(wire['peak_minute'], isNull, reason: releaseType);
        expect(wire['peak_openness'], isNull, reason: releaseType);
        expect(wire['openness_profile'], isEmpty, reason: releaseType);
        expect(
          absorption.delayedArrivalLikelihood,
          DelayedArrivalLikelihood.unknown,
          reason: releaseType,
        );
        expect(
          absorption.applicabilityReasons,
          contains('mechanistic_applicability.release_type_not_supported'),
          reason: releaseType,
        );
        expect(
          curveReport.passed,
          isTrue,
          reason: '$releaseType\n${_describe(curveReport)}',
        );

        final competition = AminoAcidCompetitionModel().build(
          mealComposition: composition,
          mealEmptyingProfile: profile,
          absorptionWindow: absorption,
          mealStartMinute: 0,
        );
        final competitionWire = competition.toJson();
        final competitionReport = verifier.verifyCompetitionPressureCurve(
          competition,
        );
        expect(competition.modelApplicable, isFalse, reason: releaseType);
        expect(competition.applicabilityReasons, isNotEmpty);
        expect(competitionWire['samples'], isEmpty, reason: releaseType);
        expect(competitionWire['peak_minute'], isNull, reason: releaseType);
        expect(competitionWire['peak_pressure'], isNull, reason: releaseType);
        expect(
          competitionWire['overlap_with_absorption_window'],
          isNull,
          reason: releaseType,
        );
        expect(competitionWire['lnaa_summary'], isNull, reason: releaseType);
        expect(
          competitionReport.passed,
          isTrue,
          reason: '$releaseType\n${_describe(competitionReport)}',
        );

        final engineResult = MechanisticConflictEngine().evaluate(
          context: TimeAxisConflictContext(
            referenceMinute: 0,
            medicationEvents: [medication],
            mealEvents: [
              MealTimelineEvent(
                id: 'synthetic:$releaseType-meal',
                minute: 0,
                compositionId: composition.id,
                physicalForm: MealPhysicalForm.solid,
              ),
            ],
          ),
          mealCompositionsById: {composition.id: composition},
        );
        expect(
          engineResult.interactionType,
          MechanisticInteractionType.insufficientMedicationContext,
          reason: releaseType,
        );
        expect(
          engineResult.absorptionOpportunityWindow,
          isNull,
          reason: releaseType,
        );
      }
    });

    test(
      'mixed LNAA coverage is explicit hybrid and includes every protein gram',
      () {
        const completeProfile = AminoAcidProfile(
          leucine: 1.4,
          isoleucine: 0.8,
          valine: 0.8,
          phenylalanine: 0.6,
          tyrosine: 0.6,
          tryptophan: 0.3,
          basis: 'per_serving',
          nutrientIds: ['leu', 'ile', 'val', 'phe', 'tyr', 'trp'],
          sourceRefs: ['synthetic:complete-aa'],
        );
        const profiled = FoodComponent(
          id: 'profiled',
          name: 'profiled protein',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: 10,
          fatGrams: 2,
          fiberGrams: 1,
          carbohydrateGrams: 5,
          calories: 80,
          portionGrams: 100,
          sourceDocId: 'synthetic:hybrid',
          proteinSource: ProteinSourceType.soy,
          aminoAcidProfile: completeProfile,
        );
        const unprofiled = FoodComponent(
          id: 'unprofiled',
          name: 'unprofiled meat protein',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: 30,
          fatGrams: 4,
          fiberGrams: 0,
          carbohydrateGrams: 2,
          calories: 180,
          portionGrams: 150,
          sourceDocId: 'synthetic:hybrid',
          proteinSource: ProteinSourceType.meat,
        );
        const zeroProtein = FoodComponent(
          id: 'zero',
          name: 'zero-protein component',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: 0,
          fatGrams: 0,
          fiberGrams: 0,
          carbohydrateGrams: 5,
          calories: 20,
          portionGrams: 50,
          sourceDocId: 'synthetic:hybrid',
        );

        CompetitionPressureTimeline evaluateComponents(
          List<FoodComponent> components,
        ) {
          final composition = MealCompositionNormalizer().normalize(
            mealId: 'synthetic:hybrid-meal',
            components: components,
            declaredPhysicalForm: MealPhysicalForm.solid,
          );
          final emptying = GastricEmptyingModel().build(
            mealId: composition.id,
            mealStartMinute: 0,
            composition: composition,
          );
          final absorption = LevodopaAbsorptionOpportunityModel().build(
            medication: _controlledMedication,
            overlappingMealProfile: emptying,
          );
          return AminoAcidCompetitionModel().build(
            mealComposition: composition,
            mealEmptyingProfile: emptying,
            absorptionWindow: absorption,
            mealStartMinute: 0,
            levodopaDoseMg: 100,
          );
        }

        final hybrid = evaluateComponents([profiled, unprofiled, zeroProtein]);
        final hybridSummary = hybrid.lnaaSummary!;
        expect(
          hybridSummary.dataMode,
          AminoAcidDataMode.hybridActualAndProteinSourceProxy,
        );
        expect(hybridSummary.partialAminoAcidData, isTrue);
        expect(hybridSummary.uncertaintyWidened, isTrue);
        expect(
          hybridSummary.actualAminoAcidProteinCoverageFraction,
          closeTo(0.25, 1e-12),
        );
        expect(
          hybridSummary.effectiveLoadFactor,
          closeTo((10 * 1.0 + 30 * 1.15) / 40, 1e-12),
        );
        expect(hybridSummary.sourcesPresent, contains(ProteinSourceType.meat));
        expect(hybridSummary.aminoAcidNutrientIds, isNotEmpty);
        expect(hybridSummary.competingLnaaGrams, isNull);
        expect(hybridSummary.competingLnaaGramsPerServing, isNull);
        expect(hybridSummary.doseRelativeAvailable, isFalse);
        expect(hybridSummary.doseRelativeLnaaRatio, isNull);
        expect(
          (hybrid.toJson()['lnaa_summary']
              as Map<String, dynamic>)['data_mode'],
          'hybridActualAndProteinSourceProxy',
        );
        expect(
          hybrid.assumptions,
          contains(
            'aa.lnaa.hybrid_actual_and_protein_source_proxy (effective 1.11)',
          ),
        );

        final pureActualWithZero = evaluateComponents([
          profiled,
          zeroProtein,
        ]).lnaaSummary!;
        expect(
          pureActualWithZero.dataMode,
          AminoAcidDataMode.actualAminoAcidFields,
        );
        expect(pureActualWithZero.actualAminoAcidProteinCoverageFraction, 1);
        expect(pureActualWithZero.partialAminoAcidData, isFalse);
        expect(pureActualWithZero.competingLnaaGrams, closeTo(4.5, 1e-12));
      },
    );

    test(
      'missing protein makes the standalone competition provider abstain',
      () {
        final composition = MealCompositionNormalizer().normalize(
          mealId: 'synthetic:missing-protein',
          components: const [
            FoodComponent(
              id: 'missing-protein',
              name: 'missing protein fixture',
              physicalForm: MealPhysicalForm.solid,
              proteinGrams: null,
              fatGrams: 2,
              fiberGrams: 1,
              carbohydrateGrams: 20,
              calories: 120,
              portionGrams: 100,
              sourceDocId: 'synthetic:missing-protein',
            ),
          ],
          declaredPhysicalForm: MealPhysicalForm.solid,
        );
        final emptying = GastricEmptyingModel().build(
          mealId: composition.id,
          mealStartMinute: 0,
          composition: composition,
        );
        final absorption = LevodopaAbsorptionOpportunityModel().build(
          medication: _controlledMedication,
          overlappingMealProfile: emptying,
        );
        final competition = AminoAcidCompetitionModel().build(
          mealComposition: composition,
          mealEmptyingProfile: emptying,
          absorptionWindow: absorption,
          mealStartMinute: 0,
        );
        final wire = competition.toJson();

        expect(competition.modelApplicable, isFalse);
        expect(
          competition.availability,
          MechanisticProviderAvailability.insufficient,
        );
        expect(
          competition.applicabilityReasons,
          contains('competition.protein_grams_missing'),
        );
        expect(competition.competitionBand, CompetitionBand.unknown);
        expect(wire['samples'], isEmpty);
        expect(wire['result_availability'], 'insufficient');
        expect(wire['has_modeled_output'], isFalse);
        expect(wire['peak_minute'], isNull);
        expect(wire['peak_pressure'], isNull);
        expect(wire['overlap_with_absorption_window'], isNull);
        expect(
          verifier.verifyCompetitionPressureCurve(competition).passed,
          isTrue,
        );
      },
    );

    test('malformed downstream curves fail closed', () {
      const invalidAbsorption = AbsorptionOpportunityWindow(
        medicationEventId: 'synthetic:malformed-dose',
        window: TimelineWindow(startMinute: 0, endMinute: 90),
        peakMinute: 30,
        delayedArrivalLikelihood: DelayedArrivalLikelihood.low,
        uncertaintyBand: UncertaintyBand.narrow,
        assumptions: ['synthetic:malformed'],
        missingInputs: [],
        sourceRefs: ['synthetic:invariant-gate'],
        opennessProfile: [
          AbsorptionOpennessSample(minute: 0, openness: double.nan),
          AbsorptionOpennessSample(minute: 0, openness: 0.5),
          AbsorptionOpennessSample(minute: 100, openness: double.infinity),
        ],
      );
      const invalidCompetition = CompetitionPressureTimeline(
        samples: [
          CompetitionPressureSample(minute: 0, pressure: double.nan),
          CompetitionPressureSample(minute: 0, pressure: double.infinity),
        ],
        peakMinute: 0,
        peakPressure: double.infinity,
        overlapWithAbsorptionWindow: -0.1,
        competitionBand: CompetitionBand.unknown,
        uncertaintyBand: UncertaintyBand.veryWide,
        assumptions: ['synthetic:malformed'],
        sourceRefs: ['synthetic:invariant-gate'],
      );
      final absorption = verifier.verifyAbsorptionOpportunityCurve(
        invalidAbsorption,
      );
      final competition = verifier.verifyCompetitionPressureCurve(
        invalidCompetition,
      );

      expect(
        invalidAbsorption.structuralIntegrityReasons,
        containsAll({
          'absorption.profile_openness_nonfinite',
          'absorption.profile_sample_minute_duplicate',
          'absorption.profile_sample_outside_window',
          'absorption.profile_peak_inconsistent',
        }),
      );
      expect(
        invalidCompetition.structuralIntegrityReasons,
        containsAll({
          'competition.profile_peak_nonfinite',
          'competition.profile_overlap_out_of_range',
          'competition.profile_pressure_nonfinite',
          'competition.profile_sample_minute_duplicate',
          'competition.profile_peak_inconsistent',
        }),
      );
      expect(
        invalidAbsorption.availability,
        MechanisticProviderAvailability.blockedIntegrity,
      );
      expect(
        invalidCompetition.availability,
        MechanisticProviderAvailability.blockedIntegrity,
      );
      expect(absorption.passed, isTrue);
      expect(competition.passed, isTrue);
    });

    test('non-normalized and non-finite gastric structures fail closed', () {
      final valid = _productionProfile();
      final invalid = GastricEmptyingProfile(
        mealId: 'synthetic:invalid-structure',
        componentProfiles: const [
          EmptyingComponentProfile(
            componentId: 'a',
            physicalForm: MealPhysicalForm.solid,
            lagMinutes: 10,
            halfEmptyingMinutes: 90,
            fractionOfMeal: 0.8,
            appliedModifiers: [],
          ),
          EmptyingComponentProfile(
            componentId: 'b',
            physicalForm: MealPhysicalForm.liquid,
            lagMinutes: 0,
            halfEmptyingMinutes: double.infinity,
            fractionOfMeal: 0.8,
            appliedModifiers: [],
          ),
        ],
        uncertaintyBand: valid.uncertaintyBand,
        assumptions: const ['synthetic:deliberately-invalid'],
        missingInputs: const [],
        sourceRefs: const ['synthetic:test'],
        aggregateLagMinutes: 5,
        peakEmptyingWindow: const TimelineWindow(
          startMinute: 5,
          endMinute: 120,
        ),
        mostlyEmptiedWindow: const TimelineWindow(
          startMinute: 5,
          endMinute: 480,
        ),
        timeScaleSensitivityFraction: double.nan,
      );

      final report = verifier.verifyGastricProfile(invalid);

      expect(
        invalid.availability,
        MechanisticProviderAvailability.blockedIntegrity,
      );
      expect(
        invalid.structuralIntegrityReasons,
        containsAll({
          'gastric_emptying.profile_half_time_invalid',
          'gastric_emptying.profile_fraction_sum_invalid',
          'gastric_emptying.profile_sensitivity_invalid',
        }),
      );
      expect(report.passed, isTrue);
    });

    test('lower and upper curves cannot cross the central structure', () {
      final valid = MechanisticCurveFixture(
        structureId: 'synthetic:normalized-retention',
        observable: MechanisticCurveObservable.normalizedRemainingMass,
        dimension: MechanisticDimension.normalizedFraction,
        central: const [1.0, 0.8, 0.6, 0.3],
        lowerEnvelope: const [1.0, 0.7, 0.5, 0.2],
        upperEnvelope: const [1.0, 0.9, 0.7, 0.4],
      );
      final crossing = MechanisticCurveFixture(
        structureId: 'synthetic:crossing-envelope',
        observable: MechanisticCurveObservable.normalizedRemainingMass,
        dimension: MechanisticDimension.normalizedFraction,
        central: const [1.0, 0.8, 0.6, 0.3],
        lowerEnvelope: const [1.0, 0.81, 0.5, 0.2],
        upperEnvelope: const [1.0, 0.9, 0.59, 0.4],
      );

      expect(verifier.verifyCurveFixture(valid).passed, isTrue);
      expect(
        verifier.verifyCurveFixture(crossing).codes,
        contains('structural_envelope_order'),
      );
    });

    test('normalized structural envelopes are bounded and monotone', () {
      final outOfBounds = MechanisticCurveFixture(
        structureId: 'synthetic:envelope-out-of-bounds',
        observable: MechanisticCurveObservable.normalizedRemainingMass,
        dimension: MechanisticDimension.normalizedFraction,
        central: const [1.0, 0.8, 0.6],
        lowerEnvelope: const [0.9, 0.7, -0.1],
        upperEnvelope: const [1.1, 0.9, 0.7],
      );
      final risingEnvelope = MechanisticCurveFixture(
        structureId: 'synthetic:rising-envelope',
        observable: MechanisticCurveObservable.normalizedRemainingMass,
        dimension: MechanisticDimension.normalizedFraction,
        central: const [1.0, 0.8, 0.6],
        lowerEnvelope: const [0.7, 0.8, 0.5],
        upperEnvelope: const [1.0, 0.9, 0.7],
      );

      expect(
        verifier.verifyCurveFixture(outOfBounds).codes,
        contains('structural_envelope_bounds'),
      );
      expect(
        verifier.verifyCurveFixture(risingEnvelope).codes,
        contains('structural_envelope_monotonicity'),
      );
    });

    test(
      'absolute volume can rise without violating retention monotonicity',
      () {
        final absoluteVolume = MechanisticCurveFixture(
          structureId: 'synthetic:absolute-volume-with-secretion-rise',
          observable: MechanisticCurveObservable.absoluteVolume,
          dimension: MechanisticDimension.volume,
          central: const [100, 108, 105, 91],
          lowerEnvelope: const [95, 102, 99, 85],
          upperEnvelope: const [105, 114, 111, 97],
        );
        final wronglyScoped = MechanisticCurveFixture(
          structureId: 'synthetic:wrongly-normalized',
          observable: MechanisticCurveObservable.normalizedRemainingMass,
          dimension: MechanisticDimension.normalizedFraction,
          central: const [0.80, 0.86, 0.75],
        );

        expect(verifier.verifyCurveFixture(absoluteVolume).passed, isTrue);
        expect(
          verifier.verifyCurveFixture(wronglyScoped).codes,
          contains('normalized_curve_monotonicity'),
        );
      },
    );
  });

  group('dimensionally equivalent unit metamorphics', () {
    test('component permutation preserves production model outputs', () {
      const components = [
        FoodComponent(
          id: 'solid-a',
          name: 'solid A',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: 12,
          fatGrams: 4,
          fiberGrams: 3,
          carbohydrateGrams: 30,
          calories: 220,
          portionGrams: 120,
          sourceDocId: 'synthetic:invariant-gate',
        ),
        FoodComponent(
          id: 'liquid-b',
          name: 'liquid B',
          physicalForm: MealPhysicalForm.liquid,
          proteinGrams: 4,
          fatGrams: 1,
          fiberGrams: 0,
          carbohydrateGrams: 12,
          calories: 80,
          portionGrams: 240,
          sourceDocId: 'synthetic:invariant-gate',
        ),
        FoodComponent(
          id: 'solid-c',
          name: 'solid C',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: 6,
          fatGrams: 2,
          fiberGrams: 1,
          carbohydrateGrams: 20,
          calories: 130,
          portionGrams: 90,
          sourceDocId: 'synthetic:invariant-gate',
        ),
      ];
      final normalizer = MealCompositionNormalizer();
      final forward = _evaluateComposition(
        normalizer.normalize(
          mealId: 'synthetic:permutation-composition',
          components: components,
        ),
      );
      final reverse = _evaluateComposition(
        normalizer.normalize(
          mealId: 'synthetic:permutation-composition',
          components: components.reversed.toList(growable: false),
        ),
      );

      expect(
        reverse.interactionScore,
        closeTo(forward.interactionScore, 1e-12),
      );
      expect(reverse.severityBand, forward.severityBand);
      expect(
        reverse.competitionTimeline!.overlapWithAbsorptionWindow,
        closeTo(
          forward.competitionTimeline!.overlapWithAbsorptionWindow,
          1e-12,
        ),
      );
      for (var minute = 0; minute <= 720; minute += 5) {
        expect(
          reverse.primaryEmptyingProfile!.remainingFractionAt(minute),
          closeTo(
            forward.primaryEmptyingProfile!.remainingFractionAt(minute),
            1e-12,
          ),
          reason: 'minute=$minute',
        );
      }
    });

    test(
      'time, mass, fraction, rate, and volume pairs canonicalize equally',
      () {
        void equivalent(MechanisticQuantity left, MechanisticQuantity right) {
          final a = verifier.canonicalize(left);
          final b = verifier.canonicalize(right);
          expect(a.dimension, b.dimension);
          expect(a.unit, b.unit);
          expect(a.value, closeTo(b.value, 1e-12));
        }

        equivalent(
          const MechanisticQuantity(
            value: 120,
            unit: 'minute',
            dimension: MechanisticDimension.time,
          ),
          const MechanisticQuantity(
            value: 2,
            unit: 'hour',
            dimension: MechanisticDimension.time,
          ),
        );
        equivalent(
          const MechanisticQuantity(
            value: 100,
            unit: 'mg',
            dimension: MechanisticDimension.mass,
          ),
          const MechanisticQuantity(
            value: 0.1,
            unit: 'g',
            dimension: MechanisticDimension.mass,
          ),
        );
        equivalent(
          const MechanisticQuantity(
            value: 100,
            unit: 'mg',
            dimension: MechanisticDimension.mass,
          ),
          const MechanisticQuantity(
            value: 100000,
            unit: 'mcg',
            dimension: MechanisticDimension.mass,
          ),
        );
        equivalent(
          const MechanisticQuantity(
            value: 0.4,
            unit: 'fraction',
            dimension: MechanisticDimension.normalizedFraction,
          ),
          const MechanisticQuantity(
            value: 40,
            unit: '%',
            dimension: MechanisticDimension.normalizedFraction,
          ),
        );
        equivalent(
          const MechanisticQuantity(
            value: 0.6,
            unit: '1/min',
            dimension: MechanisticDimension.ratePerTime,
          ),
          const MechanisticQuantity(
            value: 36,
            unit: '1/h',
            dimension: MechanisticDimension.ratePerTime,
          ),
        );
        equivalent(
          const MechanisticQuantity(
            value: 500,
            unit: 'mL',
            dimension: MechanisticDimension.volume,
          ),
          const MechanisticQuantity(
            value: 0.5,
            unit: 'L',
            dimension: MechanisticDimension.volume,
          ),
        );
      },
    );

    test('equivalent dose and time units preserve production output', () {
      final minuteTime = verifier
          .canonicalize(
            const MechanisticQuantity(
              value: 120,
              unit: 'minute',
              dimension: MechanisticDimension.time,
            ),
          )
          .value
          .round();
      final hourTime = verifier
          .canonicalize(
            const MechanisticQuantity(
              value: 2,
              unit: 'hour',
              dimension: MechanisticDimension.time,
            ),
          )
          .value
          .round();
      final mg = _evaluate(strength: 100, unit: 'mg', minute: minuteTime);
      final grams = _evaluate(strength: 0.1, unit: 'g', minute: hourTime);
      final micrograms = _evaluate(
        strength: 100000,
        unit: 'mcg',
        minute: hourTime,
      );

      for (final equivalent in [grams, micrograms]) {
        expect(
          equivalent.interactionScore,
          closeTo(mg.interactionScore, 1e-12),
        );
        expect(equivalent.severityBand, mg.severityBand);
        expect(
          equivalent.absorptionOpportunityWindow?.delayedArrivalLikelihood,
          mg.absorptionOpportunityWindow?.delayedArrivalLikelihood,
        );
        expect(
          equivalent.competitionTimeline?.lnaaSummary?.doseRelativeLnaaRatio,
          closeTo(
            mg.competitionTimeline!.lnaaSummary!.doseRelativeLnaaRatio!,
            1e-12,
          ),
        );
      }
    });

    test('ambiguous, mismatched, non-finite, and negative quantities fail', () {
      void rejects(MechanisticQuantity quantity, String code) {
        expect(
          () => verifier.canonicalize(quantity),
          throwsA(
            isA<MechanisticUnitException>().having(
              (error) => error.code,
              'code',
              code,
            ),
          ),
        );
      }

      rejects(
        const MechanisticQuantity(
          value: 1,
          unit: 'm',
          dimension: MechanisticDimension.time,
        ),
        'unit_ambiguous',
      );
      rejects(
        const MechanisticQuantity(
          value: 1,
          unit: 'mg',
          dimension: MechanisticDimension.time,
        ),
        'unit_dimension_mismatch',
      );
      rejects(
        const MechanisticQuantity(
          value: double.nan,
          unit: 'mg',
          dimension: MechanisticDimension.mass,
        ),
        'quantity_nonfinite',
      );
      rejects(
        const MechanisticQuantity(
          value: double.infinity,
          unit: 'minute',
          dimension: MechanisticDimension.time,
        ),
        'quantity_nonfinite',
      );
      rejects(
        const MechanisticQuantity(
          value: -1,
          unit: 'minute',
          dimension: MechanisticDimension.time,
        ),
        'quantity_negative',
      );
    });
  });

  group('exact threshold neighborhoods', () {
    const epsilon = 1e-12;

    test('production engine obeys every interaction severity boundary', () {
      expect(
        verifier.classifySeverity(0, competition: CompetitionBand.none),
        SeverityBand.none,
      );
      expect(
        verifier.classifySeverity(epsilon, competition: CompetitionBand.low),
        SeverityBand.low,
      );
      final cases = <(double, SeverityBand)>[
        (
          MechanisticModelInvariantVerifier.severityModerateThreshold - epsilon,
          SeverityBand.low,
        ),
        (
          MechanisticModelInvariantVerifier.severityModerateThreshold,
          SeverityBand.moderate,
        ),
        (
          MechanisticModelInvariantVerifier.severityModerateThreshold + epsilon,
          SeverityBand.moderate,
        ),
        (
          MechanisticModelInvariantVerifier.severityHighThreshold - epsilon,
          SeverityBand.moderate,
        ),
        (
          MechanisticModelInvariantVerifier.severityHighThreshold,
          SeverityBand.high,
        ),
        (
          MechanisticModelInvariantVerifier.severityHighThreshold + epsilon,
          SeverityBand.high,
        ),
      ];
      for (final (score, expected) in cases) {
        final production = _evaluateControlledSeverity(score);

        expect(
          production.interactionScore,
          closeTo(score, 1e-14),
          reason: 'controlled production score=$score',
        );
        expect(
          verifier
              .verifySeverityObservation(
                score: production.interactionScore,
                competition: production.competitionTimeline!.competitionBand,
                observed: production.severityBand,
              )
              .passed,
          isTrue,
          reason: 'production score=$score observed=${production.severityBand}',
        );
        expect(production.severityBand, expected, reason: 'score=$score');
      }
      expect(
        verifier.classifySeverity(0.9, competition: CompetitionBand.unknown),
        SeverityBand.unknown,
      );
      final productionUnknown = _evaluateControlledSeverity(
        0.30,
        competitionBand: CompetitionBand.unknown,
      );
      expect(
        productionUnknown.availability,
        MechanisticResultAvailability.blockedIntegrity,
      );
      expect(productionUnknown.modeledInteractionScore, isNull);

      // Mutation probe: replaying the real threshold output at the point just
      // below it must be rejected. This kills an inclusive/exclusive or
      // off-by-one drift instead of merely exercising the copied oracle.
      final exactModerate = _evaluateControlledSeverity(
        MechanisticModelInvariantVerifier.severityModerateThreshold,
      );
      expect(
        verifier
            .verifySeverityObservation(
              score:
                  MechanisticModelInvariantVerifier.severityModerateThreshold -
                  epsilon,
              competition: exactModerate.competitionTimeline!.competitionBand,
              observed: exactModerate.severityBand,
            )
            .codes,
        contains('severity_threshold_mismatch'),
      );
    });

    test('production competition model obeys every band boundary', () {
      final cases = <(double, CompetitionBand)>[
        (0.0, CompetitionBand.none),
        (epsilon, CompetitionBand.low),
        (
          MechanisticModelInvariantVerifier.competitionModerateThreshold -
              epsilon,
          CompetitionBand.low,
        ),
        (
          MechanisticModelInvariantVerifier.competitionModerateThreshold,
          CompetitionBand.moderate,
        ),
        (
          MechanisticModelInvariantVerifier.competitionModerateThreshold +
              epsilon,
          CompetitionBand.moderate,
        ),
        (
          MechanisticModelInvariantVerifier.competitionHighThreshold - epsilon,
          CompetitionBand.moderate,
        ),
        (
          MechanisticModelInvariantVerifier.competitionHighThreshold,
          CompetitionBand.high,
        ),
        (
          MechanisticModelInvariantVerifier.competitionHighThreshold + epsilon,
          CompetitionBand.high,
        ),
      ];
      for (final (overlap, expected) in cases) {
        final production = _evaluateControlledCompetition(overlap);

        expect(
          production.overlapWithAbsorptionWindow,
          closeTo(overlap, 1e-14),
          reason: 'controlled production overlap=$overlap',
        );
        expect(
          verifier
              .verifyCompetitionObservation(
                overlap: production.overlapWithAbsorptionWindow,
                observed: production.competitionBand,
              )
              .passed,
          isTrue,
          reason:
              'production overlap=$overlap observed=${production.competitionBand}',
        );
        expect(
          production.competitionBand,
          expected,
          reason: 'overlap=$overlap',
        );
      }
    });

    test('production absorption model obeys every residual boundary', () {
      final cases = <(double, DelayedArrivalLikelihood)>[
        (
          MechanisticModelInvariantVerifier.delayedModerateResidualThreshold -
              epsilon,
          DelayedArrivalLikelihood.low,
        ),
        (
          MechanisticModelInvariantVerifier.delayedModerateResidualThreshold,
          DelayedArrivalLikelihood.low,
        ),
        (
          MechanisticModelInvariantVerifier.delayedModerateResidualThreshold +
              epsilon,
          DelayedArrivalLikelihood.moderate,
        ),
        (
          MechanisticModelInvariantVerifier.delayedHighResidualThreshold -
              epsilon,
          DelayedArrivalLikelihood.moderate,
        ),
        (
          MechanisticModelInvariantVerifier.delayedHighResidualThreshold,
          DelayedArrivalLikelihood.moderate,
        ),
        (
          MechanisticModelInvariantVerifier.delayedHighResidualThreshold +
              epsilon,
          DelayedArrivalLikelihood.high,
        ),
      ];
      for (final (residual, expected) in cases) {
        final production = _evaluateControlledDelayedArrival(residual);

        expect(
          verifier
              .verifyDelayedArrivalObservation(
                residual: residual,
                observed: production.delayedArrivalLikelihood,
              )
              .passed,
          isTrue,
          reason:
              'production residual=$residual observed=${production.delayedArrivalLikelihood}',
        );
        expect(
          production.delayedArrivalLikelihood,
          expected,
          reason: 'residual=$residual',
        );
      }
      expect(
        verifier.classifyDelayedArrival(0.9, mealProfileAvailable: false),
        DelayedArrivalLikelihood.unknown,
      );
      final productionNoMealProfile = LevodopaAbsorptionOpportunityModel()
          .build(medication: _controlledMedication);
      expect(
        productionNoMealProfile.delayedArrivalLikelihood,
        DelayedArrivalLikelihood.unknown,
      );
      expect(
        verifier
            .verifyDelayedArrivalObservation(
              residual: 0.9,
              observed: productionNoMealProfile.delayedArrivalLikelihood,
              mealProfileAvailable: false,
            )
            .passed,
        isTrue,
      );

      // Mutation probe: a production observation taken at the inclusive
      // moderate boundary cannot be replayed just above the boundary.
      final exactModerate = _evaluateControlledDelayedArrival(
        MechanisticModelInvariantVerifier.delayedModerateResidualThreshold,
      );
      expect(
        verifier
            .verifyDelayedArrivalObservation(
              residual:
                  MechanisticModelInvariantVerifier
                      .delayedModerateResidualThreshold +
                  epsilon,
              observed: exactModerate.delayedArrivalLikelihood,
            )
            .codes,
        contains('delayed_arrival_threshold_mismatch'),
      );
    });

    test('non-finite and out-of-domain threshold inputs fail closed', () {
      for (final value in [
        double.nan,
        double.infinity,
        -epsilon,
        1 + epsilon,
      ]) {
        expect(
          () => verifier.classifySeverity(
            value,
            competition: CompetitionBand.low,
          ),
          throwsA(isA<MechanisticUnitException>()),
        );
        expect(
          () => verifier.classifyCompetition(value),
          throwsA(isA<MechanisticUnitException>()),
        );
        expect(
          () => verifier.classifyDelayedArrival(value),
          throwsA(isA<MechanisticUnitException>()),
        );
      }
    });
  });

  group('parameter and invariant-preserving mutation rejection', () {
    test('default gastric and scoring configurations pass', () {
      final gastric = verifier.verifyGastricParameters(
        GastricEmptyingParameterSet.literatureInformedDefault(),
      );
      final scoring = NextMealScoringParameterSet.literatureInformedDefault();

      expect(gastric.passed, isTrue, reason: _describe(gastric));
      expect(
        verifier.verifyScoringParameters(scoring, expected: scoring).passed,
        isTrue,
      );
      expect(
        MechanisticModelInvariantVerifier.evidenceBoundary,
        contains('Engineering verification'),
      );
      expect(
        MechanisticModelInvariantVerifier.evidenceBoundary,
        contains('not biological, clinical, predictive, or patient-level'),
      );
    });

    test('NaN, infinity, negative signs, and non-normalized weights fail', () {
      final defaults = GastricEmptyingParameterSet.literatureInformedDefault();
      final badGastric = [
        _gastricWith(defaults, solidHalfMinutes: double.nan),
        _gastricWith(defaults, referenceMealCalories: double.infinity),
        _gastricWith(defaults, solidLagMinutes: -1),
        _gastricWith(defaults, overlapUncertaintyBoost: -1),
      ];
      for (final parameters in badGastric) {
        expect(
          verifier.verifyGastricParameters(parameters).passed,
          isFalse,
          reason: parameters.version,
        );
        expect(parameters.validationErrors, isNotEmpty);
        expect(
          () => GastricEmptyingModel(parameters: parameters),
          throwsArgumentError,
          reason: parameters.version,
        );
      }

      final scoring = NextMealScoringParameterSet.literatureInformedDefault();
      expect(
        verifier
            .verifyScoringParameters(
              _scoringWith(scoring, {'score.conflict_overlap': double.nan}),
            )
            .codes,
        contains('scoring_weight_nonfinite'),
      );
      expect(
        verifier
            .verifyScoringParameters(
              _scoringWith(scoring, {'score.source_authority': -0.05}),
            )
            .codes,
        contains('scoring_contribution_sign'),
      );
      expect(
        verifier
            .verifyScoringParameters(
              _scoringWith(scoring, {'score.nutrition_adequacy': 0.20}),
            )
            .codes,
        contains('scoring_weights_not_normalized'),
      );
    });

    test('six invariant-preserving mutation fixtures are rejected', () {
      final scoring = NextMealScoringParameterSet.literatureInformedDefault();
      final expectedTerms = verifier.scoringFormulaWitness(scoring);

      final reorderedTerms = [...expectedTerms];
      final first = reorderedTerms[0];
      reorderedTerms[0] = reorderedTerms[1];
      reorderedTerms[1] = first;

      final signFlippedTerms = [...expectedTerms];
      final penalty = signFlippedTerms.last;
      signFlippedTerms[signFlippedTerms.length -
          1] = MechanisticFormulaTermWitness(
        penalty.semanticId,
        -penalty.coefficient,
      );

      // Swapping two positive weights preserves normalization and broad bounds,
      // but changes the declared semantic coefficient mapping.
      final wrongButNormalized = _scoringWith(scoring, {
        'score.nutrition_adequacy': scoring.sourceAuthority.value,
        'score.source_authority': scoring.nutritionAdequacy.value,
      });

      final mutations = <String, MechanisticInvariantReport>{
        // A minute/hour scale defect keeps a curve finite and monotone while
        // moving every temporal feature by 60x.
        'minute_as_hour_scale': verifier.verifyCanonicalAnchor(
          quantity: const MechanisticQuantity(
            value: 90,
            unit: 'hour',
            dimension: MechanisticDimension.time,
          ),
          expectedCanonicalValue: 90,
        ),
        'wrong_but_normalized_weights': verifier.verifyScoringParameters(
          wrongButNormalized,
          expected: scoring,
        ),
        'semantic_term_reorder': verifier.verifyScoringFormula(
          reorderedTerms,
          expected: expectedTerms,
        ),
        'uncertainty_penalty_sign_flip': verifier.verifyScoringFormula(
          signFlippedTerms,
          expected: expectedTerms,
        ),
        'severity_off_by_one_branch': verifier.verifySeverityObservation(
          score:
              MechanisticModelInvariantVerifier.severityModerateThreshold -
              1e-12,
          competition: CompetitionBand.low,
          observed: SeverityBand.moderate,
        ),
        'delayed_arrival_off_by_one_branch': verifier
            .verifyDelayedArrivalObservation(
              residual: MechanisticModelInvariantVerifier
                  .delayedModerateResidualThreshold,
              observed: DelayedArrivalLikelihood.moderate,
            ),
      };

      expect(mutations, hasLength(greaterThanOrEqualTo(5)));
      for (final entry in mutations.entries) {
        expect(
          entry.value.passed,
          isFalse,
          reason: '${entry.key} escaped the invariant gate',
        );
      }
      expect(
        mutations['wrong_but_normalized_weights']!.codes,
        contains('scoring_weight_value_mismatch'),
      );
      expect(
        mutations['semantic_term_reorder']!.codes,
        contains('scoring_term_order_mismatch'),
      );
      expect(
        mutations['uncertainty_penalty_sign_flip']!.codes,
        contains('scoring_penalty_sign'),
      );
    });
  });
}

String _describe(MechanisticInvariantReport report) => report.violations
    .map((violation) => '${violation.code}: ${violation.message}')
    .join('\n');

GastricEmptyingProfile _productionProfile() {
  final composition = MealCompositionNormalizer().normalize(
    mealId: 'synthetic:invariant-gate-meal',
    components: const [
      FoodComponent(
        id: 'solid',
        name: 'solid fixture',
        physicalForm: MealPhysicalForm.solid,
        proteinGrams: 12,
        fatGrams: 4,
        fiberGrams: 3,
        carbohydrateGrams: 30,
        calories: 220,
        portionGrams: 120,
        sourceDocId: 'synthetic:invariant-gate',
      ),
      FoodComponent(
        id: 'liquid',
        name: 'liquid fixture',
        physicalForm: MealPhysicalForm.liquid,
        proteinGrams: 4,
        fatGrams: 1,
        fiberGrams: 0,
        carbohydrateGrams: 12,
        calories: 80,
        portionGrams: 240,
        sourceDocId: 'synthetic:invariant-gate',
      ),
    ],
  );
  return GastricEmptyingModel().build(
    mealId: composition.id,
    mealStartMinute: 0,
    composition: composition,
  );
}

MechanisticConflictResult _evaluate({
  required double strength,
  required String unit,
  required int minute,
}) {
  final validation = MedicationEntryValidator().validate(
    RawMedicationEntry(
      activeIngredients: const ['carbidopa', 'levodopa'],
      drugProductVariant: 'synthetic:unit-metamorphic',
      strength: strength,
      unit: unit,
      form: 'tablet',
      route: 'oral',
      releaseType: 'immediate',
      jurisdiction: 'US',
      sourceDocId: 'synthetic:invariant-gate',
    ),
  );
  final composition = MealCompositionNormalizer().normalize(
    mealId: 'synthetic:unit-meal-composition',
    components: const [
      FoodComponent(
        id: 'actual-lnaa-fixture',
        name: 'actual LNAA fixture',
        physicalForm: MealPhysicalForm.solid,
        proteinGrams: 20,
        fatGrams: 5,
        fiberGrams: 3,
        carbohydrateGrams: 40,
        calories: 300,
        portionGrams: 200,
        sourceDocId: 'synthetic:invariant-gate',
        aminoAcidProfile: AminoAcidProfile(
          leucine: 2.0,
          isoleucine: 1.2,
          valine: 1.3,
          phenylalanine: 1.0,
          tyrosine: 0.8,
          tryptophan: 0.2,
          unit: 'g',
          basis: 'per_serving',
          nutrientIds: ['synthetic:lnaa'],
          sourceRefs: ['synthetic:invariant-gate'],
        ),
      ),
    ],
  );
  return MechanisticConflictEngine().evaluate(
    context: TimeAxisConflictContext(
      referenceMinute: 0,
      medicationEvents: [
        MedicationTimelineEvent(
          id: 'synthetic:unit-dose',
          minute: minute,
          context: validation.normalized!,
        ),
      ],
      mealEvents: const [
        MealTimelineEvent(
          id: 'synthetic:unit-meal',
          minute: 0,
          compositionId: 'synthetic:unit-meal-composition',
          physicalForm: MealPhysicalForm.solid,
        ),
      ],
    ),
    mealCompositionsById: {composition.id: composition},
  );
}

MechanisticConflictResult _evaluateControlledSeverity(
  double targetScore, {
  CompetitionBand? competitionBand,
}) {
  const availableLowDelayContribution = 0.4 * 0.05;
  final overlap = (targetScore - availableLowDelayContribution) / 0.6;
  final composition = _controlledComposition(proteinGrams: 20);
  final engine = MechanisticConflictEngine(
    absorptionModel: _FixedAbsorptionModel(),
    competitionModel: _FixedCompetitionModel(
      overlap,
      competitionBand: competitionBand,
    ),
  );
  return engine.evaluate(
    context: TimeAxisConflictContext(
      referenceMinute: 0,
      medicationEvents: const [_controlledMedication],
      mealEvents: const [
        MealTimelineEvent(
          id: 'synthetic:threshold-meal',
          minute: 0,
          compositionId: 'synthetic:threshold-composition',
          physicalForm: MealPhysicalForm.solid,
        ),
      ],
    ),
    mealCompositionsById: {composition.id: composition},
    resultId: 'synthetic:severity-threshold',
  );
}

MechanisticConflictResult _evaluateComposition(MealComposition composition) =>
    MechanisticConflictEngine().evaluate(
      context: TimeAxisConflictContext(
        referenceMinute: 0,
        medicationEvents: const [_controlledMedication],
        mealEvents: [
          MealTimelineEvent(
            id: 'synthetic:permutation-meal',
            minute: 0,
            compositionId: composition.id,
            physicalForm: MealPhysicalForm.mixed,
          ),
        ],
      ),
      mealCompositionsById: {composition.id: composition},
      resultId: 'synthetic:permutation-result',
    );

CompetitionPressureTimeline _evaluateControlledCompetition(double overlap) {
  final composition = _controlledComposition(proteinGrams: overlap * 40.0);
  return AminoAcidCompetitionModel().build(
    mealComposition: composition,
    mealEmptyingProfile: const _ControlledGastricProfile(
      residual: 0.5,
      arrivalRate: 1.0,
    ),
    absorptionWindow: const AbsorptionOpportunityWindow(
      medicationEventId: 'synthetic:threshold-dose',
      window: TimelineWindow(startMinute: 0, endMinute: 10),
      peakMinute: 5,
      delayedArrivalLikelihood: DelayedArrivalLikelihood.low,
      uncertaintyBand: UncertaintyBand.narrow,
      assumptions: ['synthetic:controlled-window'],
      missingInputs: [],
      sourceRefs: ['synthetic:invariant-gate'],
      opennessProfile: [
        AbsorptionOpennessSample(minute: 0, openness: 1),
        AbsorptionOpennessSample(minute: 5, openness: 1),
        AbsorptionOpennessSample(minute: 10, openness: 1),
      ],
    ),
    mealStartMinute: 0,
  );
}

AbsorptionOpportunityWindow _evaluateControlledDelayedArrival(
  double residual,
) => LevodopaAbsorptionOpportunityModel().build(
  medication: _controlledMedication,
  overlappingMealProfile: _ControlledGastricProfile(
    residual: residual,
    arrivalRate: 1.0,
  ),
);

MealComposition _controlledComposition({
  required double proteinGrams,
}) => MealComposition(
  id: 'synthetic:threshold-composition',
  totalCalories: 300,
  proteinGrams: proteinGrams,
  fatGrams: 4,
  fiberGrams: 3,
  carbohydrateGrams: 40,
  liquidFraction: 0,
  mealPhysicalForm: MealPhysicalForm.solid,
  portionSizeBand: PortionSizeBand.medium,
  proteinAmountBand: proteinGrams <= 0
      ? AmountBand.none
      : proteinGrams < 7
      ? AmountBand.low
      : proteinGrams < 20
      ? AmountBand.moderate
      : AmountBand.high,
  fatAmountBand: AmountBand.low,
  fiberAmountBand: AmountBand.moderate,
  calorieBand: AmountBand.moderate,
  compositionCompleteness: 1,
  missingFields: const [],
  // An explicit component with an unknown protein source selects the
  // production model's declared neutral LNAA factor (1.0), leaving
  // protein/40 as the controlled overlap without using an empty-meal sentinel.
  foodComponents: [
    FoodComponent(
      id: 'synthetic:threshold-component',
      name: 'controlled threshold component',
      physicalForm: MealPhysicalForm.solid,
      proteinGrams: proteinGrams,
      fatGrams: 4,
      fiberGrams: 3,
      carbohydrateGrams: 40,
      calories: 300,
      portionGrams: 200,
      sourceDocId: 'synthetic:invariant-gate',
    ),
  ],
);

const _controlledMedication = MedicationTimelineEvent(
  id: 'synthetic:threshold-dose',
  minute: 0,
  context: NormalizedMedicationContext(
    drugProductVariant: 'synthetic:threshold-levodopa',
    activeIngredients: ['carbidopa', 'levodopa'],
    form: 'tablet',
    route: 'oral',
    releaseType: 'immediate',
    strength: 100,
    unit: 'mg',
    jurisdiction: 'synthetic',
    sourceDocId: 'synthetic:invariant-gate',
    labelSection: null,
    extractionConfidence: 1,
    limitationText: 'Synthetic engineering fixture; not clinical validation.',
  ),
);

MedicationTimelineEvent _controlledMedicationWithRelease(String releaseType) =>
    MedicationTimelineEvent(
      id: 'synthetic:controlled-$releaseType-dose',
      minute: 0,
      context: NormalizedMedicationContext(
        drugProductVariant: 'synthetic:controlled-$releaseType-levodopa',
        activeIngredients: const ['carbidopa', 'levodopa'],
        form: 'tablet',
        route: 'oral',
        releaseType: releaseType,
        strength: 100,
        unit: 'mg',
        jurisdiction: 'synthetic',
        sourceDocId: 'synthetic:invariant-gate',
        labelSection: null,
        extractionConfidence: 1,
        limitationText:
            'Synthetic engineering fixture; not clinical validation.',
      ),
    );

final class _FixedCompetitionModel extends AminoAcidCompetitionModel {
  final double overlap;
  final CompetitionBand? competitionBand;

  _FixedCompetitionModel(this.overlap, {this.competitionBand});

  @override
  CompetitionPressureTimeline build({
    required MealComposition mealComposition,
    required GastricEmptyingProfile mealEmptyingProfile,
    required AbsorptionOpportunityWindow absorptionWindow,
    required int mealStartMinute,
    double? levodopaDoseMg,
  }) => CompetitionPressureTimeline(
    samples: [
      CompetitionPressureSample(minute: mealStartMinute, pressure: overlap),
    ],
    peakMinute: mealStartMinute,
    peakPressure: overlap,
    overlapWithAbsorptionWindow: overlap,
    competitionBand: competitionBand ?? competitionBandForOverlap(overlap),
    uncertaintyBand: UncertaintyBand.narrow,
    assumptions: const ['synthetic:controlled-overlap'],
    sourceRefs: const ['synthetic:invariant-gate'],
    lnaaSummary: const CompetitionLnaaSummary(
      effectiveLoadFactor: 1,
      sourcesPresent: [ProteinSourceType.unknown],
      isPrototypeHeuristic: true,
      uncertaintyWidened: true,
      sourceRefs: ['synthetic:invariant-gate'],
      dataMode: AminoAcidDataMode.proteinSourceProxy,
      actualAminoAcidProteinCoverageFraction: 0,
    ),
  );
}

final class _FixedAbsorptionModel extends LevodopaAbsorptionOpportunityModel {
  @override
  AbsorptionOpportunityWindow build({
    required MedicationTimelineEvent medication,
    GastricEmptyingProfile? overlappingMealProfile,
  }) => AbsorptionOpportunityWindow(
    medicationEventId: medication.id,
    window: TimelineWindow(
      startMinute: medication.minute,
      endMinute: medication.minute + 90,
    ),
    peakMinute: medication.minute + 30,
    delayedArrivalLikelihood: DelayedArrivalLikelihood.low,
    uncertaintyBand: UncertaintyBand.narrow,
    assumptions: const ['synthetic:controlled-delay-unknown'],
    missingInputs: const [],
    sourceRefs: const ['synthetic:invariant-gate'],
    opennessProfile: [
      AbsorptionOpennessSample(minute: medication.minute, openness: 1),
      AbsorptionOpennessSample(minute: medication.minute + 30, openness: 1),
      AbsorptionOpennessSample(minute: medication.minute + 90, openness: 1),
    ],
  );
}

final class _ControlledGastricProfile extends GastricEmptyingProfile {
  final double residual;
  final double arrivalRate;

  const _ControlledGastricProfile({
    required this.residual,
    required this.arrivalRate,
  }) : super(
         mealId: 'synthetic:controlled-gastric-profile',
         componentProfiles: const [
           EmptyingComponentProfile(
             componentId: 'synthetic:controlled-component',
             physicalForm: MealPhysicalForm.solid,
             lagMinutes: 0,
             halfEmptyingMinutes: 60,
             fractionOfMeal: 1,
             appliedModifiers: [],
           ),
         ],
         uncertaintyBand: UncertaintyBand.narrow,
         assumptions: const ['synthetic:controlled-profile'],
         missingInputs: const [],
         sourceRefs: const ['synthetic:invariant-gate'],
         aggregateLagMinutes: 0,
         peakEmptyingWindow: const TimelineWindow(
           startMinute: 0,
           endMinute: 90,
         ),
         mostlyEmptiedWindow: const TimelineWindow(
           startMinute: 0,
           endMinute: 240,
         ),
         timeScaleSensitivityFraction: 0.2,
       );

  @override
  double remainingFractionAt(int minutesSinceMealStart) => residual;

  @override
  double emptiedFractionAt(int minutesSinceMealStart) => 1.0 - residual;

  @override
  double intestinalArrivalRateAt(int minutesSinceMealStart) => arrivalRate;
}

GastricEmptyingParameter<double> _doubleParameter(
  GastricEmptyingParameter<double> original,
  double value,
) => GastricEmptyingParameter<double>(
  id: original.id,
  label: original.label,
  value: value,
  sourceRefs: original.sourceRefs,
  confidence: original.confidence,
  limitation: original.limitation,
);

GastricEmptyingParameter<int> _intParameter(
  GastricEmptyingParameter<int> original,
  int value,
) => GastricEmptyingParameter<int>(
  id: original.id,
  label: original.label,
  value: value,
  sourceRefs: original.sourceRefs,
  confidence: original.confidence,
  limitation: original.limitation,
);

GastricEmptyingParameterSet _gastricWith(
  GastricEmptyingParameterSet defaults, {
  double? solidLagMinutes,
  double? solidHalfMinutes,
  double? referenceMealCalories,
  int? overlapUncertaintyBoost,
}) => GastricEmptyingParameterSet(
  id: defaults.id,
  version: 'synthetic:invalid-parameter-injection',
  lastReviewed: defaults.lastReviewed,
  solidLagMinutes: _doubleParameter(
    defaults.solidLagMinutes,
    solidLagMinutes ?? defaults.solidLagMinutes.value,
  ),
  solidHalfMinutes: _doubleParameter(
    defaults.solidHalfMinutes,
    solidHalfMinutes ?? defaults.solidHalfMinutes.value,
  ),
  liquidLagMinutes: defaults.liquidLagMinutes,
  liquidHalfMinutes: defaults.liquidHalfMinutes,
  referenceMealCalories: _doubleParameter(
    defaults.referenceMealCalories,
    referenceMealCalories ?? defaults.referenceMealCalories.value,
  ),
  fatSlowdownMultiplier: defaults.fatSlowdownMultiplier,
  fatFractionThreshold: defaults.fatFractionThreshold,
  fiberSlowdownMultiplier: defaults.fiberSlowdownMultiplier,
  mixedMealUncertaintyBoost: defaults.mixedMealUncertaintyBoost,
  overlapUncertaintyBoost: _intParameter(
    defaults.overlapUncertaintyBoost,
    overlapUncertaintyBoost ?? defaults.overlapUncertaintyBoost.value,
  ),
  fatUncertaintyBoost: defaults.fatUncertaintyBoost,
  highCalorieUncertaintyBoost: defaults.highCalorieUncertaintyBoost,
  highCalorieFractionThreshold: defaults.highCalorieFractionThreshold,
  timeScaleSensitivityFraction: defaults.timeScaleSensitivityFraction,
);

ScoringWeight _scoringWeight(ScoringWeight original, double value) =>
    ScoringWeight(
      id: original.id,
      label: original.label,
      value: value,
      sourceRefs: original.sourceRefs,
      evidenceLevel: original.evidenceLevel,
      limitation: original.limitation,
    );

NextMealScoringParameterSet _scoringWith(
  NextMealScoringParameterSet defaults,
  Map<String, double> values,
) {
  ScoringWeight replace(ScoringWeight original) =>
      _scoringWeight(original, values[original.id] ?? original.value);

  return NextMealScoringParameterSet(
    id: '${defaults.id}.synthetic-mutation',
    conflictOverlap: replace(defaults.conflictOverlap),
    proteinRedistribution: replace(defaults.proteinRedistribution),
    nutritionAdequacy: replace(defaults.nutritionAdequacy),
    metadataCompleteness: replace(defaults.metadataCompleteness),
    sourceAuthority: replace(defaults.sourceAuthority),
    jurisdictionMatch: replace(defaults.jurisdictionMatch),
    provenanceQuality: replace(defaults.provenanceQuality),
    uncertaintyPenalty: replace(defaults.uncertaintyPenalty),
  );
}
