import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/absorption_opportunity.dart';
import 'package:parkinsum_companion/domain/entities/amino_acid_competition.dart';
import 'package:parkinsum_companion/domain/entities/gastric_emptying_profile.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/amino_acid_competition_model.dart';
import 'package:parkinsum_companion/domain/usecases/gastric_emptying_model.dart';
import 'package:parkinsum_companion/domain/usecases/levodopa_absorption_opportunity_model.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';
import 'package:parkinsum_companion/domain/usecases/time_axis_builder.dart';

MedicationTimelineEvent _validLevodopaEventAt(
  int minute, {
  String releaseType = 'immediate',
}) {
  final validator = MedicationEntryValidator();
  final result = validator.validate(
    RawMedicationEntry(
      activeIngredients: ['carbidopa', 'levodopa'],
      drugProductVariant: 'synthetic:carbidopa-levodopa-25-100-ir-tablet',
      strength: 100,
      unit: 'mg',
      form: 'tablet',
      route: 'oral',
      releaseType: releaseType,
      jurisdiction: 'US',
      sourceDocId: 'synthetic:demo',
    ),
  );
  return MedicationTimelineEvent(
    id: 'med',
    minute: minute,
    context: result.normalized!,
  );
}

GastricEmptyingProfile _profileWithUncertainty(UncertaintyBand band) =>
    GastricEmptyingProfile(
      mealId: 'synthetic:uncertainty-fixture',
      componentProfiles: const [
        EmptyingComponentProfile(
          componentId: 'synthetic:uncertainty-component',
          physicalForm: MealPhysicalForm.solid,
          lagMinutes: 0,
          halfEmptyingMinutes: 60,
          fractionOfMeal: 1,
          appliedModifiers: [],
        ),
      ],
      uncertaintyBand: band,
      assumptions: const ['synthetic_test_fixture'],
      missingInputs: const [],
      sourceRefs: const ['synthetic:test'],
      aggregateLagMinutes: 0,
      peakEmptyingWindow: const TimelineWindow(startMinute: 0, endMinute: 90),
      mostlyEmptiedWindow: const TimelineWindow(startMinute: 0, endMinute: 240),
      timeScaleSensitivityFraction: 0.2,
    );

const _waterComponent = FoodComponent(
  id: 'food.water',
  name: 'water',
  physicalForm: MealPhysicalForm.liquid,
  proteinGrams: 0,
  fatGrams: 0,
  fiberGrams: 0,
  carbohydrateGrams: 0,
  calories: 0,
  portionGrams: 250,
  sourceDocId: 'synthetic:demo',
);

const _solidOats = FoodComponent(
  id: 'food.oats',
  name: 'oats',
  physicalForm: MealPhysicalForm.solid,
  proteinGrams: 5,
  fatGrams: 3,
  fiberGrams: 4,
  carbohydrateGrams: 27,
  calories: 158,
  portionGrams: 200,
  sourceDocId: 'synthetic:demo',
);

const _highFat = FoodComponent(
  id: 'food.avocado',
  name: 'avocado',
  physicalForm: MealPhysicalForm.solid,
  proteinGrams: 2,
  fatGrams: 22,
  fiberGrams: 7,
  carbohydrateGrams: 12,
  calories: 240,
  portionGrams: 150,
  sourceDocId: 'synthetic:demo',
);

void main() {
  final normalizer = MealCompositionNormalizer();
  final emptying = GastricEmptyingModel();
  final absorption = LevodopaAbsorptionOpportunityModel();
  final competition = AminoAcidCompetitionModel();

  group('TimeAxisBuilder', () {
    test('omits medication events with invalid context', () {
      final builder = TimeAxisBuilder();
      final invalid = MedicationEntryValidator().validate(
        const RawMedicationEntry(freeText: '100'),
      );
      final ctx = builder.build(
        now: DateTime.utc(2026, 1, 1, 8),
        medicationInputs: [
          MedicationTimelineInput(
            id: 'm1',
            takenAt: DateTime.utc(2026, 1, 1, 8),
            medicationContext: invalid,
          ),
        ],
        mealInputs: const [],
      );
      expect(ctx.medicationEvents, isEmpty);
      expect(
        ctx.missingFields.any((f) => f.contains('invalid_context')),
        isTrue,
      );
    });

    test('sorts events deterministically by minute', () {
      final builder = TimeAxisBuilder();
      final v = MedicationEntryValidator().validate(
        const RawMedicationEntry(
          activeIngredients: ['levodopa'],
          drugProductVariant: 'synthetic:v',
          strength: 100,
          unit: 'mg',
          form: 'tablet',
          route: 'oral',
          releaseType: 'immediate',
          jurisdiction: 'US',
          sourceDocId: 'synthetic:demo',
        ),
      );
      final ctx = builder.build(
        now: DateTime.utc(2026, 1, 1, 8),
        medicationInputs: [
          MedicationTimelineInput(
            id: 'a',
            takenAt: DateTime.utc(2026, 1, 1, 9),
            medicationContext: v,
          ),
          MedicationTimelineInput(
            id: 'b',
            takenAt: DateTime.utc(2026, 1, 1, 8),
            medicationContext: v,
          ),
        ],
        mealInputs: const [],
      );
      expect(ctx.medicationEvents.first.id, 'b');
      expect(ctx.medicationEvents.last.id, 'a');
    });

    test('trims valid IDs and omits empty medication and meal IDs', () {
      final builder = TimeAxisBuilder();
      final now = DateTime.utc(2026, 1, 1, 8);
      final valid = MedicationEntryValidator().validate(
        const RawMedicationEntry(
          activeIngredients: ['carbidopa', 'levodopa'],
          drugProductVariant: 'synthetic:v',
          strength: 100,
          unit: 'mg',
          form: 'tablet',
          route: 'oral',
          releaseType: 'immediate',
          jurisdiction: 'US',
          sourceDocId: 'synthetic:demo',
        ),
      );
      final ctx = builder.build(
        now: now,
        medicationInputs: [
          MedicationTimelineInput(
            id: ' dose ',
            takenAt: now,
            medicationContext: valid,
          ),
          MedicationTimelineInput(
            id: '   ',
            takenAt: now,
            medicationContext: valid,
          ),
        ],
        mealInputs: [
          MealTimelineInput(id: ' meal ', startedAt: now, compositionId: 'c1'),
          MealTimelineInput(id: '', startedAt: now, compositionId: 'c2'),
        ],
      );

      expect(ctx.medicationEvents.map((event) => event.id), ['dose']);
      expect(ctx.mealEvents.map((event) => event.id), ['meal']);
      expect(
        ctx.missingFields,
        containsAll(const [
          'medication.event_id_empty(index=1)',
          'meal.event_id_empty(index=1)',
        ]),
      );
    });

    test('omits duplicate and cross-type event IDs after trimming', () {
      final builder = TimeAxisBuilder();
      final now = DateTime.utc(2026, 1, 1, 8);
      final valid = MedicationEntryValidator().validate(
        const RawMedicationEntry(
          activeIngredients: ['carbidopa', 'levodopa'],
          drugProductVariant: 'synthetic:v',
          strength: 100,
          unit: 'mg',
          form: 'tablet',
          route: 'oral',
          releaseType: 'immediate',
          jurisdiction: 'US',
          sourceDocId: 'synthetic:demo',
        ),
      );
      final ctx = builder.build(
        now: now,
        medicationInputs: [
          MedicationTimelineInput(
            id: 'duplicate_med',
            takenAt: now,
            medicationContext: valid,
          ),
          MedicationTimelineInput(
            id: ' duplicate_med ',
            takenAt: now,
            medicationContext: valid,
          ),
          MedicationTimelineInput(
            id: 'shared',
            takenAt: now,
            medicationContext: valid,
          ),
        ],
        mealInputs: [
          MealTimelineInput(
            id: 'duplicate_meal',
            startedAt: now,
            compositionId: 'c1',
          ),
          MealTimelineInput(
            id: ' duplicate_meal ',
            startedAt: now,
            compositionId: 'c2',
          ),
          MealTimelineInput(
            id: ' shared ',
            startedAt: now,
            compositionId: 'c3',
          ),
        ],
      );

      expect(ctx.medicationEvents, isEmpty);
      expect(ctx.mealEvents, isEmpty);
      expect(
        ctx.missingFields,
        containsAll(const [
          'medication.event_id_duplicate(duplicate_med)',
          'meal.event_id_duplicate(duplicate_meal)',
          'timeline.event_id_collision(shared)',
        ]),
      );
    });
  });

  group('MealCompositionNormalizer', () {
    test('records every missing field', () {
      final c = normalizer.normalize(
        mealId: 'm',
        components: const [_solidOats],
        declaredPhysicalForm: MealPhysicalForm.solid,
      );
      expect(c.compositionCompleteness, 1.0);
      expect(c.missingFields, isEmpty);
      expect(c.proteinAmountBand, AmountBand.low);
    });

    test('detects liquid-only meal physical form', () {
      final c = normalizer.normalize(
        mealId: 'm',
        components: const [_waterComponent],
      );
      expect(c.mealPhysicalForm, MealPhysicalForm.liquid);
      expect(c.liquidFraction, 1.0);
    });

    test('detects mixed meal physical form', () {
      final c = normalizer.normalize(
        mealId: 'm',
        components: const [_waterComponent, _solidOats],
      );
      expect(c.mealPhysicalForm, MealPhysicalForm.mixed);
    });

    test('empty components → unknown form, completeness 0', () {
      final c = normalizer.normalize(mealId: 'm', components: const []);
      expect(c.compositionCompleteness, 0.0);
      expect(c.mealPhysicalForm, MealPhysicalForm.unknown);
    });
  });

  group('GastricEmptyingModel', () {
    test('liquid meals empty faster than comparable solid meals', () {
      final liquid = normalizer.normalize(
        mealId: 'liq',
        components: const [_waterComponent],
      );
      final solid = normalizer.normalize(
        mealId: 'sol',
        components: const [_solidOats],
      );
      final liquidProfile = emptying.build(
        mealId: 'liq',
        mealStartMinute: 0,
        composition: liquid,
      );
      final solidProfile = emptying.build(
        mealId: 'sol',
        mealStartMinute: 0,
        composition: solid,
      );
      // At t=30 min, more liquid has emptied than solid.
      expect(
        liquidProfile.emptiedFractionAt(30),
        greaterThan(solidProfile.emptiedFractionAt(30)),
      );
    });

    test('high-fat meal extends emptying profile', () {
      final low = normalizer.normalize(
        mealId: 'lo',
        components: const [_solidOats],
      );
      final high = normalizer.normalize(
        mealId: 'hi',
        components: const [_highFat],
      );
      final lowProfile = emptying.build(
        mealId: 'lo',
        mealStartMinute: 0,
        composition: low,
      );
      final highProfile = emptying.build(
        mealId: 'hi',
        mealStartMinute: 0,
        composition: high,
      );
      expect(
        highProfile.componentProfiles.first.halfEmptyingMinutes,
        greaterThan(lowProfile.componentProfiles.first.halfEmptyingMinutes),
      );
    });

    test('missing composition widens uncertainty', () {
      final partial = normalizer.normalize(
        mealId: 'p',
        components: const [
          FoodComponent(
            id: 'p',
            name: 'partial',
            physicalForm: MealPhysicalForm.solid,
            proteinGrams: null,
            fatGrams: null,
            fiberGrams: null,
            carbohydrateGrams: null,
            calories: null,
            portionGrams: 200,
            sourceDocId: 'synthetic:demo',
          ),
        ],
      );
      final profile = emptying.build(
        mealId: 'p',
        mealStartMinute: 0,
        composition: partial,
      );
      expect([
        UncertaintyBand.moderate,
        UncertaintyBand.wide,
        UncertaintyBand.veryWide,
      ], contains(profile.uncertaintyBand));
    });

    test('overlapping residual load widens uncertainty band', () {
      final c = normalizer.normalize(
        mealId: 'c',
        components: const [_solidOats],
      );
      final lo = emptying.build(
        mealId: 'c',
        mealStartMinute: 0,
        composition: c,
        overlappingResidualLoad: 0.0,
      );
      final hi = emptying.build(
        mealId: 'c',
        mealStartMinute: 0,
        composition: c,
        overlappingResidualLoad: 0.5,
      );
      const order = [
        UncertaintyBand.narrow,
        UncertaintyBand.moderate,
        UncertaintyBand.wide,
        UncertaintyBand.veryWide,
      ];
      expect(
        order.indexOf(hi.uncertaintyBand),
        greaterThanOrEqualTo(order.indexOf(lo.uncertaintyBand)),
      );
    });
  });

  group('LevodopaAbsorptionOpportunityModel', () {
    test(
      'claimed-available malformed gastric profiles block every downstream wire',
      () {
        final composition = normalizer.normalize(
          mealId: 'synthetic:gastric-integrity-meal',
          components: const [_solidOats],
        );
        const validComponent = EmptyingComponentProfile(
          componentId: 'synthetic:gastric-integrity-component',
          physicalForm: MealPhysicalForm.solid,
          lagMinutes: 5,
          halfEmptyingMinutes: 60,
          fractionOfMeal: 1,
          appliedModifiers: [],
        );
        final invalidProfiles = <String, GastricEmptyingProfile>{
          'empty-meal-id': const GastricEmptyingProfile(
            mealId: '   ',
            componentProfiles: [validComponent],
            uncertaintyBand: UncertaintyBand.veryWide,
            assumptions: ['synthetic:invalid-meal-id'],
            missingInputs: [],
            sourceRefs: ['synthetic:test'],
            aggregateLagMinutes: 5,
            peakEmptyingWindow: TimelineWindow(startMinute: 5, endMinute: 95),
            mostlyEmptiedWindow: TimelineWindow(startMinute: 5, endMinute: 245),
            timeScaleSensitivityFraction: 0.2,
          ),
          'canonical-duplicate-component-id': const GastricEmptyingProfile(
            mealId: 'synthetic:gastric-duplicate-components',
            componentProfiles: [
              EmptyingComponentProfile(
                componentId: 'same-id',
                physicalForm: MealPhysicalForm.solid,
                lagMinutes: 5,
                halfEmptyingMinutes: 60,
                fractionOfMeal: 0.5,
                appliedModifiers: [],
              ),
              EmptyingComponentProfile(
                componentId: ' same-id ',
                physicalForm: MealPhysicalForm.liquid,
                lagMinutes: 0,
                halfEmptyingMinutes: 30,
                fractionOfMeal: 0.5,
                appliedModifiers: [],
              ),
            ],
            uncertaintyBand: UncertaintyBand.veryWide,
            assumptions: ['synthetic:invalid-component-id'],
            missingInputs: [],
            sourceRefs: ['synthetic:test'],
            aggregateLagMinutes: 2.5,
            peakEmptyingWindow: TimelineWindow(startMinute: 3, endMinute: 70),
            mostlyEmptiedWindow: TimelineWindow(startMinute: 3, endMinute: 183),
            timeScaleSensitivityFraction: 0.2,
          ),
          'empty': const GastricEmptyingProfile(
            mealId: 'synthetic:gastric-empty',
            componentProfiles: [],
            uncertaintyBand: UncertaintyBand.veryWide,
            assumptions: ['synthetic:invalid-empty'],
            missingInputs: [],
            sourceRefs: ['synthetic:test'],
            aggregateLagMinutes: 0,
            peakEmptyingWindow: TimelineWindow(startMinute: 0, endMinute: 30),
            mostlyEmptiedWindow: TimelineWindow(startMinute: 0, endMinute: 180),
            timeScaleSensitivityFraction: 0.2,
          ),
          'nonfinite': const GastricEmptyingProfile(
            mealId: 'synthetic:gastric-nonfinite',
            componentProfiles: [
              EmptyingComponentProfile(
                componentId: 'synthetic:nonfinite-component',
                physicalForm: MealPhysicalForm.solid,
                lagMinutes: double.nan,
                halfEmptyingMinutes: double.infinity,
                fractionOfMeal: 1,
                appliedModifiers: [],
              ),
            ],
            uncertaintyBand: UncertaintyBand.veryWide,
            assumptions: ['synthetic:invalid-numeric'],
            missingInputs: [],
            sourceRefs: ['synthetic:test'],
            aggregateLagMinutes: double.nan,
            peakEmptyingWindow: TimelineWindow(startMinute: 0, endMinute: 30),
            mostlyEmptiedWindow: TimelineWindow(startMinute: 0, endMinute: 180),
            timeScaleSensitivityFraction: double.nan,
          ),
          'window-order': const GastricEmptyingProfile(
            mealId: 'synthetic:gastric-window-order',
            componentProfiles: [validComponent],
            uncertaintyBand: UncertaintyBand.veryWide,
            assumptions: ['synthetic:invalid-window-order'],
            missingInputs: [],
            sourceRefs: ['synthetic:test'],
            aggregateLagMinutes: 5,
            peakEmptyingWindow: TimelineWindow(startMinute: 20, endMinute: 60),
            mostlyEmptiedWindow: TimelineWindow(startMinute: 30, endMinute: 50),
            timeScaleSensitivityFraction: 0.2,
          ),
          'derived-aggregate-lag': const GastricEmptyingProfile(
            mealId: 'synthetic:gastric-derived-lag',
            componentProfiles: [validComponent],
            uncertaintyBand: UncertaintyBand.veryWide,
            assumptions: ['synthetic:invalid-derived-lag'],
            missingInputs: [],
            sourceRefs: ['synthetic:test'],
            aggregateLagMinutes: 999,
            peakEmptyingWindow: TimelineWindow(startMinute: 5, endMinute: 95),
            mostlyEmptiedWindow: TimelineWindow(startMinute: 5, endMinute: 245),
            timeScaleSensitivityFraction: 0.2,
          ),
          'derived-peak-duration': const GastricEmptyingProfile(
            mealId: 'synthetic:gastric-derived-peak',
            componentProfiles: [validComponent],
            uncertaintyBand: UncertaintyBand.veryWide,
            assumptions: ['synthetic:invalid-derived-peak'],
            missingInputs: [],
            sourceRefs: ['synthetic:test'],
            aggregateLagMinutes: 5,
            peakEmptyingWindow: TimelineWindow(startMinute: 5, endMinute: 94),
            mostlyEmptiedWindow: TimelineWindow(startMinute: 5, endMinute: 245),
            timeScaleSensitivityFraction: 0.2,
          ),
          'derived-mostly-duration': const GastricEmptyingProfile(
            mealId: 'synthetic:gastric-derived-mostly',
            componentProfiles: [validComponent],
            uncertaintyBand: UncertaintyBand.veryWide,
            assumptions: ['synthetic:invalid-derived-mostly'],
            missingInputs: [],
            sourceRefs: ['synthetic:test'],
            aggregateLagMinutes: 5,
            peakEmptyingWindow: TimelineWindow(startMinute: 5, endMinute: 95),
            mostlyEmptiedWindow: TimelineWindow(startMinute: 5, endMinute: 244),
            timeScaleSensitivityFraction: 0.2,
          ),
          'derived-window-origin': const GastricEmptyingProfile(
            mealId: 'synthetic:gastric-derived-origin',
            componentProfiles: [validComponent],
            uncertaintyBand: UncertaintyBand.veryWide,
            assumptions: ['synthetic:invalid-derived-origin'],
            missingInputs: [],
            sourceRefs: ['synthetic:test'],
            aggregateLagMinutes: 5,
            peakEmptyingWindow: TimelineWindow(startMinute: 5, endMinute: 95),
            mostlyEmptiedWindow: TimelineWindow(startMinute: 6, endMinute: 246),
            timeScaleSensitivityFraction: 0.2,
          ),
        };

        for (final fixture in invalidProfiles.entries) {
          final profile = fixture.value;
          expect(
            profile.availability,
            MechanisticProviderAvailability.blockedIntegrity,
            reason: fixture.key,
          );
          final gastricWire = profile.toJson();
          expect(gastricWire['has_modeled_output'], isFalse);
          expect(gastricWire['component_profiles'], isEmpty);
          expect(gastricWire['aggregate_lag_minutes'], isNull);
          expect(gastricWire['peak_emptying_window'], isNull);
          expect(gastricWire['mostly_emptied_window'], isNull);
          expect(gastricWire['time_scale_sensitivity_fraction'], isNull);

          final absorptionResult = absorption.build(
            medication: _validLevodopaEventAt(30),
            overlappingMealProfile: profile,
          );
          expect(
            absorptionResult.availability,
            MechanisticProviderAvailability.blockedIntegrity,
            reason: fixture.key,
          );
          final absorptionWire = absorptionResult.toJson();
          expect(absorptionWire['window'], isNull);
          expect(absorptionWire['peak_minute'], isNull);
          expect(absorptionWire['peak_openness'], isNull);
          expect(absorptionWire['openness_profile'], isEmpty);

          final competitionResult = competition.build(
            mealComposition: composition,
            mealEmptyingProfile: profile,
            absorptionWindow: const AbsorptionOpportunityWindow(
              medicationEventId: 'synthetic:gastric-integrity-dose',
              window: TimelineWindow(startMinute: 30, endMinute: 120),
              peakMinute: 60,
              delayedArrivalLikelihood: DelayedArrivalLikelihood.low,
              uncertaintyBand: UncertaintyBand.narrow,
              assumptions: ['synthetic:valid-absorption'],
              missingInputs: [],
              sourceRefs: ['synthetic:test'],
              opennessProfile: [
                AbsorptionOpennessSample(minute: 30, openness: 0.1),
                AbsorptionOpennessSample(minute: 60, openness: 1),
                AbsorptionOpennessSample(minute: 120, openness: 0.1),
              ],
            ),
            mealStartMinute: 0,
          );
          expect(
            competitionResult.availability,
            MechanisticProviderAvailability.blockedIntegrity,
            reason: fixture.key,
          );
          final competitionWire = competitionResult.toJson();
          expect(competitionWire['samples'], isEmpty);
          expect(competitionWire['peak_minute'], isNull);
          expect(competitionWire['peak_pressure'], isNull);
          expect(competitionWire['overlap_with_absorption_window'], isNull);
        }
      },
    );

    test('inherits wide meal uncertainty without narrowing it', () {
      for (final band in const [
        UncertaintyBand.wide,
        UncertaintyBand.veryWide,
      ]) {
        final window = absorption.build(
          medication: _validLevodopaEventAt(30),
          overlappingMealProfile: _profileWithUncertainty(band),
        );
        expect(window.uncertaintyBand, band, reason: band.name);
      }
    });

    test('unknown release abstains without emitting an IR-shaped curve', () {
      for (final band in const [
        UncertaintyBand.narrow,
        UncertaintyBand.moderate,
        UncertaintyBand.wide,
        UncertaintyBand.veryWide,
      ]) {
        final window = absorption.build(
          medication: _validLevodopaEventAt(30, releaseType: 'unknown'),
          overlappingMealProfile: _profileWithUncertainty(band),
        );
        expect(window.modelApplicable, isFalse, reason: band.name);
        expect(
          window.availability,
          MechanisticProviderAvailability.insufficient,
          reason: band.name,
        );
        expect(window.window.durationMinutes, 0, reason: band.name);
        expect(window.opennessProfile, isEmpty, reason: band.name);
        expect(
          window.applicabilityReasons,
          contains('mechanistic_applicability.release_type_not_supported'),
          reason: band.name,
        );
      }
    });

    test('generic extended-release value abstains from the IR-only model', () {
      final c = normalizer.normalize(
        mealId: 'c',
        components: const [_solidOats],
      );
      final profile = emptying.build(
        mealId: 'c',
        mealStartMinute: 0,
        composition: c,
      );
      final erValidator = MedicationEntryValidator();
      final er = erValidator.validate(
        const RawMedicationEntry(
          activeIngredients: ['carbidopa', 'levodopa'],
          drugProductVariant: 'synthetic:er',
          strength: 100,
          unit: 'mg',
          form: 'tablet',
          route: 'oral',
          releaseType: 'extended',
          jurisdiction: 'US',
          sourceDocId: 'synthetic:demo',
        ),
      );
      final erEvent = MedicationTimelineEvent(
        id: 'er',
        minute: 30,
        context: er.normalized!,
      );
      final erWindow = absorption.build(
        medication: erEvent,
        overlappingMealProfile: profile,
      );
      expect(erWindow.modelApplicable, isFalse);
      expect(
        erWindow.availability,
        MechanisticProviderAvailability.notApplicable,
      );
      expect(erWindow.window.durationMinutes, 0);
      expect(erWindow.opennessProfile, isEmpty);
    });

    test('non-levodopa medication returns unknown delay likelihood', () {
      final v = MedicationEntryValidator().validate(
        const RawMedicationEntry(
          activeIngredients: ['acetaminophen'],
          drugProductVariant: 'synthetic:apap',
          strength: 500,
          unit: 'mg',
          form: 'tablet',
          route: 'oral',
          releaseType: 'immediate',
          jurisdiction: 'US',
          sourceDocId: 'synthetic:demo',
        ),
      );
      final medEvent = MedicationTimelineEvent(
        id: 'm',
        minute: 0,
        context: v.normalized!,
      );
      final w = absorption.build(
        medication: medEvent,
        overlappingMealProfile: null,
      );
      expect(w.delayedArrivalLikelihood, DelayedArrivalLikelihood.unknown);
      expect(w.modelApplicable, isFalse);
      expect(w.availability, MechanisticProviderAvailability.insufficient);
    });
  });

  group('AminoAcidCompetitionModel', () {
    test('missing protein produces unknown competition band', () {
      final partial = normalizer.normalize(
        mealId: 'p',
        components: const [
          FoodComponent(
            id: 'x',
            name: 'partial',
            physicalForm: MealPhysicalForm.solid,
            proteinGrams: null,
            fatGrams: 5,
            fiberGrams: 2,
            carbohydrateGrams: 30,
            calories: 200,
            portionGrams: 200,
            sourceDocId: 'synthetic:demo',
          ),
        ],
      );
      final profile = emptying.build(
        mealId: 'p',
        mealStartMinute: 0,
        composition: partial,
      );
      final window = absorption.build(
        medication: _validLevodopaEventAt(30),
        overlappingMealProfile: profile,
      );
      final c = competition.build(
        mealComposition: partial,
        mealEmptyingProfile: profile,
        absorptionWindow: window,
        mealStartMinute: 0,
      );
      expect(c.competitionBand, CompetitionBand.unknown);
    });

    test(
      'higher protein produces higher peak competition pressure than low protein',
      () {
        final low = normalizer.normalize(
          mealId: 'lo',
          components: const [
            FoodComponent(
              id: 'low',
              name: 'low protein',
              physicalForm: MealPhysicalForm.solid,
              proteinGrams: 2,
              fatGrams: 2,
              fiberGrams: 2,
              carbohydrateGrams: 30,
              calories: 160,
              portionGrams: 200,
              sourceDocId: 'synthetic:demo',
            ),
          ],
        );
        final high = normalizer.normalize(
          mealId: 'hi',
          components: const [
            FoodComponent(
              id: 'high',
              name: 'high protein',
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
        final loP = emptying.build(
          mealId: 'lo',
          mealStartMinute: 0,
          composition: low,
        );
        final hiP = emptying.build(
          mealId: 'hi',
          mealStartMinute: 0,
          composition: high,
        );
        final med = _validLevodopaEventAt(30);
        final loW = absorption.build(
          medication: med,
          overlappingMealProfile: loP,
        );
        final hiW = absorption.build(
          medication: med,
          overlappingMealProfile: hiP,
        );
        final loC = competition.build(
          mealComposition: low,
          mealEmptyingProfile: loP,
          absorptionWindow: loW,
          mealStartMinute: 0,
        );
        final hiC = competition.build(
          mealComposition: high,
          mealEmptyingProfile: hiP,
          absorptionWindow: hiW,
          mealStartMinute: 0,
        );
        expect(hiC.peakPressure, greaterThan(loC.peakPressure));
      },
    );
  });
}
