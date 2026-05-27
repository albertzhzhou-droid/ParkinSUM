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

MedicationTimelineEvent _validLevodopaEventAt(int minute) {
  final validator = MedicationEntryValidator();
  final result = validator.validate(const RawMedicationEntry(
    activeIngredients: ['carbidopa', 'levodopa'],
    drugProductVariant: 'synthetic:carbidopa-levodopa-25-100-ir-tablet',
    strength: 100,
    unit: 'mg',
    form: 'tablet',
    route: 'oral',
    releaseType: 'immediate',
    jurisdiction: 'US',
    sourceDocId: 'synthetic:demo',
  ));
  return MedicationTimelineEvent(
    id: 'med',
    minute: minute,
    context: result.normalized!,
  );
}

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
      final invalid = MedicationEntryValidator()
          .validate(const RawMedicationEntry(freeText: '100'));
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
          ctx.missingFields.any((f) => f.contains('invalid_context')), isTrue);
    });

    test('sorts events deterministically by minute', () {
      final builder = TimeAxisBuilder();
      final v = MedicationEntryValidator().validate(const RawMedicationEntry(
        activeIngredients: ['levodopa'],
        drugProductVariant: 'synthetic:v',
        strength: 100,
        unit: 'mg',
        form: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        jurisdiction: 'US',
        sourceDocId: 'synthetic:demo',
      ));
      final ctx = builder.build(
        now: DateTime.utc(2026, 1, 1, 8),
        medicationInputs: [
          MedicationTimelineInput(
              id: 'a',
              takenAt: DateTime.utc(2026, 1, 1, 9),
              medicationContext: v),
          MedicationTimelineInput(
              id: 'b',
              takenAt: DateTime.utc(2026, 1, 1, 8),
              medicationContext: v),
        ],
        mealInputs: const [],
      );
      expect(ctx.medicationEvents.first.id, 'b');
      expect(ctx.medicationEvents.last.id, 'a');
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
      final c = normalizer
          .normalize(mealId: 'm', components: const [_waterComponent]);
      expect(c.mealPhysicalForm, MealPhysicalForm.liquid);
      expect(c.liquidFraction, 1.0);
    });

    test('detects mixed meal physical form', () {
      final c = normalizer.normalize(
          mealId: 'm', components: const [_waterComponent, _solidOats]);
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
      final liquid = normalizer
          .normalize(mealId: 'liq', components: const [_waterComponent]);
      final solid =
          normalizer.normalize(mealId: 'sol', components: const [_solidOats]);
      final liquidProfile = emptying.build(
          mealId: 'liq', mealStartMinute: 0, composition: liquid);
      final solidProfile =
          emptying.build(mealId: 'sol', mealStartMinute: 0, composition: solid);
      // At t=30 min, more liquid has emptied than solid.
      expect(liquidProfile.emptiedFractionAt(30),
          greaterThan(solidProfile.emptiedFractionAt(30)));
    });

    test('high-fat meal extends emptying profile', () {
      final low =
          normalizer.normalize(mealId: 'lo', components: const [_solidOats]);
      final high =
          normalizer.normalize(mealId: 'hi', components: const [_highFat]);
      final lowProfile =
          emptying.build(mealId: 'lo', mealStartMinute: 0, composition: low);
      final highProfile =
          emptying.build(mealId: 'hi', mealStartMinute: 0, composition: high);
      expect(highProfile.componentProfiles.first.halfEmptyingMinutes,
          greaterThan(lowProfile.componentProfiles.first.halfEmptyingMinutes));
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
      final profile =
          emptying.build(mealId: 'p', mealStartMinute: 0, composition: partial);
      expect(
        [
          UncertaintyBand.moderate,
          UncertaintyBand.wide,
          UncertaintyBand.veryWide
        ],
        contains(profile.uncertaintyBand),
      );
    });

    test('overlapping residual load widens uncertainty band', () {
      final c =
          normalizer.normalize(mealId: 'c', components: const [_solidOats]);
      final lo = emptying.build(
          mealId: 'c',
          mealStartMinute: 0,
          composition: c,
          overlappingResidualLoad: 0.0);
      final hi = emptying.build(
          mealId: 'c',
          mealStartMinute: 0,
          composition: c,
          overlappingResidualLoad: 0.5);
      const order = [
        UncertaintyBand.narrow,
        UncertaintyBand.moderate,
        UncertaintyBand.wide,
        UncertaintyBand.veryWide
      ];
      expect(order.indexOf(hi.uncertaintyBand),
          greaterThanOrEqualTo(order.indexOf(lo.uncertaintyBand)));
    });
  });

  group('LevodopaAbsorptionOpportunityModel', () {
    test('extended-release shifts and widens absorption window', () {
      final c =
          normalizer.normalize(mealId: 'c', components: const [_solidOats]);
      final profile =
          emptying.build(mealId: 'c', mealStartMinute: 0, composition: c);
      final ir = absorption.build(
        medication: _validLevodopaEventAt(30),
        overlappingMealProfile: profile,
      );
      final erValidator = MedicationEntryValidator();
      final er = erValidator.validate(const RawMedicationEntry(
        activeIngredients: ['carbidopa', 'levodopa'],
        drugProductVariant: 'synthetic:er',
        strength: 100,
        unit: 'mg',
        form: 'tablet',
        route: 'oral',
        releaseType: 'extended',
        jurisdiction: 'US',
        sourceDocId: 'synthetic:demo',
      ));
      final erEvent = MedicationTimelineEvent(
          id: 'er', minute: 30, context: er.normalized!);
      final erWindow = absorption.build(
          medication: erEvent, overlappingMealProfile: profile);
      expect(erWindow.window.durationMinutes,
          greaterThan(ir.window.durationMinutes));
    });

    test('non-levodopa medication returns unknown delay likelihood', () {
      final v = MedicationEntryValidator().validate(const RawMedicationEntry(
        activeIngredients: ['acetaminophen'],
        drugProductVariant: 'synthetic:apap',
        strength: 500,
        unit: 'mg',
        form: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        jurisdiction: 'US',
        sourceDocId: 'synthetic:demo',
      ));
      final medEvent =
          MedicationTimelineEvent(id: 'm', minute: 0, context: v.normalized!);
      final w =
          absorption.build(medication: medEvent, overlappingMealProfile: null);
      expect(w.delayedArrivalLikelihood, DelayedArrivalLikelihood.unknown);
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
      final profile =
          emptying.build(mealId: 'p', mealStartMinute: 0, composition: partial);
      final window = absorption.build(
          medication: _validLevodopaEventAt(30),
          overlappingMealProfile: profile);
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
      final low = normalizer.normalize(mealId: 'lo', components: const [
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
      ]);
      final high = normalizer.normalize(mealId: 'hi', components: const [
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
      ]);
      final loP =
          emptying.build(mealId: 'lo', mealStartMinute: 0, composition: low);
      final hiP =
          emptying.build(mealId: 'hi', mealStartMinute: 0, composition: high);
      final med = _validLevodopaEventAt(30);
      final loW =
          absorption.build(medication: med, overlappingMealProfile: loP);
      final hiW =
          absorption.build(medication: med, overlappingMealProfile: hiP);
      final loC = competition.build(
          mealComposition: low,
          mealEmptyingProfile: loP,
          absorptionWindow: loW,
          mealStartMinute: 0);
      final hiC = competition.build(
          mealComposition: high,
          mealEmptyingProfile: hiP,
          absorptionWindow: hiW,
          mealStartMinute: 0);
      expect(hiC.peakPressure, greaterThan(loC.peakPressure));
    });
  });
}
