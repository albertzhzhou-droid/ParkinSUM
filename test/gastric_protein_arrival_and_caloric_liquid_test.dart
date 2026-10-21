import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/amino_acid_profile.dart';
import 'package:parkinsum_companion/domain/entities/gastric_emptying_parameters.dart';
import 'package:parkinsum_companion/domain/entities/gastric_emptying_profile.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/protein_source.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/amino_acid_competition_model.dart';
import 'package:parkinsum_companion/domain/usecases/gastric_emptying_model.dart';
import 'package:parkinsum_companion/domain/usecases/levodopa_absorption_opportunity_model.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';
import 'package:parkinsum_companion/domain/usecases/model_assumption_registry.dart';

/// Two physics corrections in the mechanistic model, checked against the
/// behaviour they are meant to produce:
///
/// 1. Protein reaches the intestine with the components that carry it, so the
///    competition layer's arrival curve is protein-weighted and a glass of
///    water cannot move it.
/// 2. Liquids that carry energy are delivered at a calorie-regulated rate
///    (Brener et al. 1983), while energy-free liquids keep the fast
///    exponential.
///
/// Synthetic inputs only. Educational prototype; not medical advice.
void main() {
  final normalizer = MealCompositionNormalizer();
  final gastric = GastricEmptyingModel();
  final absorption = LevodopaAbsorptionOpportunityModel();
  final competition = AminoAcidCompetitionModel();
  final defaults = GastricEmptyingParameterSet.literatureInformedDefault();

  const oatmeal = FoodComponent(
    id: 'oatmeal',
    name: 'Oatmeal (synthetic)',
    physicalForm: MealPhysicalForm.solid,
    proteinGrams: 8,
    fatGrams: 5,
    fiberGrams: 6,
    carbohydrateGrams: 42,
    calories: 250,
    portionGrams: 240,
    sourceDocId: 'synthetic:test',
    proteinSource: ProteinSourceType.grain,
  );
  const water = FoodComponent(
    id: 'water',
    name: 'Water (synthetic)',
    physicalForm: MealPhysicalForm.liquid,
    proteinGrams: 0,
    fatGrams: 0,
    fiberGrams: 0,
    carbohydrateGrams: 0,
    calories: 0,
    portionGrams: 240,
    sourceDocId: 'synthetic:test',
  );
  FoodComponent shake({double? calories = 300, String id = 'shake'}) =>
      FoodComponent(
        id: id,
        name: 'Protein shake (synthetic)',
        physicalForm: MealPhysicalForm.liquid,
        proteinGrams: 25,
        fatGrams: 8,
        fiberGrams: 0,
        carbohydrateGrams: 32,
        calories: calories,
        portionGrams: 330,
        sourceDocId: 'synthetic:test',
        proteinSource: ProteinSourceType.dairy,
      );

  MedicationTimelineEvent levodopa({int minute = 30}) {
    final validated = MedicationEntryValidator().validate(
      const RawMedicationEntry(
        activeIngredients: ['carbidopa', 'levodopa'],
        drugProductVariant: 'synthetic:demo',
        strength: 100,
        unit: 'mg',
        form: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        jurisdiction: 'US',
        sourceDocId: 'synthetic:demo',
      ),
    );
    return MedicationTimelineEvent(
      id: 'dose',
      minute: minute,
      context: validated.normalized!,
    );
  }

  ({MealComposition composition, GastricEmptyingProfile profile}) meal(
    List<FoodComponent> components, {
    GastricEmptyingModel? model,
  }) {
    final composition = normalizer.normalize(
      mealId: 'meal',
      components: components,
    );
    final profile = (model ?? gastric).build(
      mealId: 'meal',
      mealStartMinute: 0,
      composition: composition,
    );
    return (composition: composition, profile: profile);
  }

  int firstMinuteAtOrBelow(GastricEmptyingProfile profile, double remaining) {
    for (var minute = 0; minute <= 2880; minute++) {
      if (profile.remainingFractionAt(minute) <= remaining) return minute;
    }
    fail('profile never reached $remaining remaining');
  }

  GastricEmptyingModel modelWithRate(double kcalPerMinute) {
    final rate = defaults.liquidNutrientKcalPerMinute;
    return GastricEmptyingModel(
      parameters: GastricEmptyingParameterSet(
        id: defaults.id,
        version: 'test-rate-$kcalPerMinute',
        lastReviewed: defaults.lastReviewed,
        solidLagMinutes: defaults.solidLagMinutes,
        solidHalfMinutes: defaults.solidHalfMinutes,
        liquidLagMinutes: defaults.liquidLagMinutes,
        liquidHalfMinutes: defaults.liquidHalfMinutes,
        liquidNutrientKcalPerMinute: GastricEmptyingParameter<double>(
          id: rate.id,
          label: rate.label,
          value: kcalPerMinute,
          sourceRefs: rate.sourceRefs,
          confidence: rate.confidence,
          limitation: rate.limitation,
          sensitivityRange: rate.sensitivityRange,
        ),
        referenceMealCalories: defaults.referenceMealCalories,
        fatSlowdownMultiplier: defaults.fatSlowdownMultiplier,
        fatFractionThreshold: defaults.fatFractionThreshold,
        fiberSlowdownMultiplier: defaults.fiberSlowdownMultiplier,
        mixedMealUncertaintyBoost: defaults.mixedMealUncertaintyBoost,
        overlapUncertaintyBoost: defaults.overlapUncertaintyBoost,
        fatUncertaintyBoost: defaults.fatUncertaintyBoost,
        highCalorieUncertaintyBoost: defaults.highCalorieUncertaintyBoost,
        highCalorieFractionThreshold: defaults.highCalorieFractionThreshold,
        timeScaleSensitivityFraction: defaults.timeScaleSensitivityFraction,
      ),
    );
  }

  group('protein-weighted arrival', () {
    test('adding a water component does not move the protein-arrival curve '
        'or its peak', () {
      final alone = meal(const [oatmeal]);
      final withWater = meal(const [oatmeal, water]);
      const proteinWeights = {'oatmeal': 8.0};

      var aloneArgMax = 0;
      var withWaterArgMax = 0;
      for (var minute = 0; minute <= 400; minute++) {
        final a = alone.profile.weightedIntestinalArrivalRateAt(
          minute,
          proteinWeights,
        );
        final b = withWater.profile.weightedIntestinalArrivalRateAt(
          minute,
          proteinWeights,
        );
        expect(b, a, reason: 'protein arrival at minute $minute');
        if (a >
            alone.profile.weightedIntestinalArrivalRateAt(
              aloneArgMax,
              proteinWeights,
            )) {
          aloneArgMax = minute;
        }
        if (b >
            withWater.profile.weightedIntestinalArrivalRateAt(
              withWaterArgMax,
              proteinWeights,
            )) {
          withWaterArgMax = minute;
        }
      }
      expect(withWaterArgMax, aloneArgMax);
      // The protein curve rises only after the 17-minute oat lag.
      final oatLag = alone.profile.componentProfiles.single.lagMinutes;
      expect(oatLag, closeTo(17, 1e-9));
      expect(aloneArgMax, greaterThan(oatLag));

      // The meal-mass curve is not protected: water drags its peak forward.
      var massArgMax = 0;
      for (var minute = 0; minute <= 400; minute++) {
        if (withWater.profile.intestinalArrivalRateAt(minute) >
            withWater.profile.intestinalArrivalRateAt(massArgMax)) {
          massArgMax = minute;
        }
      }
      expect(massArgMax, lessThan(oatLag));
    });

    test('adding water leaves the competition timeline unchanged for a fixed '
        'absorption window', () {
      final alone = meal(const [oatmeal]);
      // One window for both meals: water may still shift the dose-time
      // absorption window through the mass-weighted residual, by design.
      final window = absorption.build(
        medication: levodopa(),
        overlappingMealProfile: alone.profile,
      );
      expect(window.modelApplicable, isTrue);
      final withWater = meal(const [oatmeal, water]);
      final aloneTimeline = competition.build(
        mealComposition: alone.composition,
        mealEmptyingProfile: alone.profile,
        absorptionWindow: window,
        mealStartMinute: 0,
      );
      final withWaterTimeline = competition.build(
        mealComposition: withWater.composition,
        mealEmptyingProfile: withWater.profile,
        absorptionWindow: window,
        mealStartMinute: 0,
      );

      expect(withWaterTimeline.peakMinute, aloneTimeline.peakMinute);
      // First five-minute sample after the 17-minute oat lag.
      expect(aloneTimeline.peakMinute, 20);
      expect(
        withWaterTimeline.samples.map((s) => (s.minute, s.pressure)).toList(),
        aloneTimeline.samples.map((s) => (s.minute, s.pressure)).toList(),
      );
      expect(
        withWaterTimeline.overlapWithAbsorptionWindow,
        aloneTimeline.overlapWithAbsorptionWindow,
      );
      expect(
        withWaterTimeline.assumptions,
        containsAll(const [
          'aa.competition.arrival_weighting.protein_grams',
          'aa.competition.support_weighted_mostly_emptied',
        ]),
      );
      // The pressure support follows the protein-bearing oatmeal (lag plus
      // four half-times), not the shorter mass-weighted window.
      expect(
        withWaterTimeline.samples.last.minute,
        greaterThan(withWater.profile.mostlyEmptiedWindow.endMinute),
      );
    });

    test('complete amino-acid profiles weight arrival by competing LNAA '
        'grams', () {
      const steak = FoodComponent(
        id: 'steak',
        name: 'Steak (synthetic)',
        physicalForm: MealPhysicalForm.solid,
        proteinGrams: 20,
        fatGrams: 6,
        fiberGrams: 0,
        carbohydrateGrams: 0,
        calories: 140,
        portionGrams: 100,
        sourceDocId: 'synthetic:test',
        proteinSource: ProteinSourceType.meat,
        aminoAcidProfile: AminoAcidProfile(
          leucine: 1.6,
          isoleucine: 0.9,
          valine: 1.0,
          phenylalanine: 0.8,
          tyrosine: 0.7,
          tryptophan: 0.2,
          basis: 'per_serving',
        ),
      );
      const milk = FoodComponent(
        id: 'milk',
        name: 'Milk (synthetic)',
        physicalForm: MealPhysicalForm.liquid,
        proteinGrams: 8,
        fatGrams: 8,
        fiberGrams: 0,
        carbohydrateGrams: 12,
        calories: 150,
        portionGrams: 244,
        sourceDocId: 'synthetic:test',
        proteinSource: ProteinSourceType.dairy,
        aminoAcidProfile: AminoAcidProfile(
          leucine: 0.8,
          isoleucine: 0.5,
          valine: 0.5,
          phenylalanine: 0.4,
          tyrosine: 0.4,
          tryptophan: 0.1,
          basis: 'per_serving',
        ),
      );
      final built = meal(const [steak, milk]);
      final basis = competition.arrivalBasisFor(
        mealComposition: built.composition,
        mealEmptyingProfile: built.profile,
      );
      expect(basis.weighting, CompetitionArrivalWeighting.competingLnaaGrams);
      expect(basis.weightsByComponentId['steak'], closeTo(5.2, 1e-9));
      expect(basis.weightsByComponentId['milk'], closeTo(2.7, 1e-9));

      final timeline = competition.build(
        mealComposition: built.composition,
        mealEmptyingProfile: built.profile,
        absorptionWindow: absorption.build(
          medication: levodopa(),
          overlappingMealProfile: built.profile,
        ),
        mealStartMinute: 0,
      );
      expect(
        timeline.assumptions,
        contains('aa.competition.arrival_weighting.competing_lnaa_grams'),
      );

      // Without amino-acid profiles the same meal falls back to protein
      // grams.
      final proxy = meal([
        FoodComponent(
          id: steak.id,
          name: steak.name,
          physicalForm: steak.physicalForm,
          proteinGrams: steak.proteinGrams,
          fatGrams: steak.fatGrams,
          fiberGrams: steak.fiberGrams,
          carbohydrateGrams: steak.carbohydrateGrams,
          calories: steak.calories,
          portionGrams: steak.portionGrams,
          sourceDocId: steak.sourceDocId,
          proteinSource: steak.proteinSource,
        ),
        FoodComponent(
          id: milk.id,
          name: milk.name,
          physicalForm: milk.physicalForm,
          proteinGrams: milk.proteinGrams,
          fatGrams: milk.fatGrams,
          fiberGrams: milk.fiberGrams,
          carbohydrateGrams: milk.carbohydrateGrams,
          calories: milk.calories,
          portionGrams: milk.portionGrams,
          sourceDocId: milk.sourceDocId,
          proteinSource: milk.proteinSource,
        ),
      ]);
      final proxyBasis = competition.arrivalBasisFor(
        mealComposition: proxy.composition,
        mealEmptyingProfile: proxy.profile,
      );
      expect(proxyBasis.weighting, CompetitionArrivalWeighting.proteinGrams);
      expect(proxyBasis.weightsByComponentId, {'steak': 20.0, 'milk': 8.0});
    });

    test('a meal without protein keeps the meal-mass shape at zero '
        'pressure', () {
      final built = meal(const [water]);
      final basis = competition.arrivalBasisFor(
        mealComposition: built.composition,
        mealEmptyingProfile: built.profile,
      );
      expect(basis.weighting, CompetitionArrivalWeighting.mealMass);
      final timeline = competition.build(
        mealComposition: built.composition,
        mealEmptyingProfile: built.profile,
        absorptionWindow: absorption.build(
          medication: levodopa(),
          overlappingMealProfile: built.profile,
        ),
        mealStartMinute: 0,
      );
      expect(timeline.peakPressure, 0);
      expect(
        timeline.assumptions,
        contains(
          'aa.competition.arrival_weighting.meal_mass_no_protein_component',
        ),
      );
    });

    test('protein the gastric profile cannot place blocks the timeline', () {
      final eaten = meal(const [oatmeal]);
      final mismatched = meal(const [water]);
      final timeline = competition.build(
        mealComposition: eaten.composition,
        mealEmptyingProfile: mismatched.profile,
        absorptionWindow: absorption.build(
          medication: levodopa(),
          overlappingMealProfile: eaten.profile,
        ),
        mealStartMinute: 0,
      );
      expect(
        timeline.availability,
        MechanisticProviderAvailability.blockedIntegrity,
      );
      expect(
        timeline.effectiveApplicabilityReasons,
        contains('competition.protein_component_missing_from_gastric_profile'),
      );
      expect(timeline.samples, isEmpty);
    });

    test('weighted arrival ignores components without a positive weight and '
        'integrates to the weighted emptied fraction', () {
      final built = meal(const [oatmeal, water]);
      expect(built.profile.weightedIntestinalArrivalRateAt(30, const {}), 0);
      expect(
        built.profile.weightedIntestinalArrivalRateAt(30, const {
          'water': 0,
          'oatmeal': double.nan,
        }),
        0,
      );
      expect(built.profile.weightedProfileShape(const {}), isNull);
      var integrated = 0.0;
      for (var minute = 0; minute <= 1440; minute++) {
        integrated += built.profile.weightedIntestinalArrivalRateAt(
          minute,
          const {'oatmeal': 8},
        );
      }
      final oat = built.profile.componentProfiles.firstWhere(
        (component) => component.componentId == 'oatmeal',
      );
      expect(
        integrated,
        closeTo(oat.emptiedFractionAt(1440) - oat.emptiedFractionAt(0), 0.01),
      );
    });
  });

  group('calorie-regulated liquids', () {
    test('a 300 kcal nutrient liquid half-empties within the calorie-rate '
        'range', () {
      final built = meal([shake()]);
      final component = built.profile.componentProfiles.single;
      final rate = defaults.liquidNutrientKcalPerMinute;
      final range = rate.sensitivityRange!;

      expect(rate.id, 'ge.liquid.nutrient_kcal_per_min');
      expect(rate.value, 2.13);
      expect(range.low, 1.0);
      expect(range.high, 4.0);
      expect(component.isCalorieRegulated, isTrue);
      expect(component.calorieDeliveryMinutes, closeTo(300 / 2.13, 1e-9));
      expect(component.halfEmptyingMinutes, closeTo(150 / 2.13, 1e-9));
      expect(
        component.appliedModifiers,
        contains('calorie_regulated_delivery'),
      );

      final halfMinute = firstMinuteAtOrBelow(built.profile, 0.5);
      // 150 kcal of the 300 kcal pool, delivered at 1–4 kcal/min.
      expect(
        halfMinute,
        inInclusiveRange((150 / range.high).floor(), (150 / range.low).ceil()),
      );
      // At 2–3 kcal/min, 300 kcal half-empties in 50–75 minutes.
      expect(halfMinute, inInclusiveRange(50, 75));
      expect(built.profile.remainingFractionAt(45), greaterThan(0.6));
      expect(
        built.profile.assumptions,
        contains(startsWith('ge.liquid.nutrient_kcal_per_min')),
      );

      // The ends of the sensitivity range bracket the central half-time.
      final fast = meal([shake()], model: modelWithRate(range.high));
      final slow = meal([shake()], model: modelWithRate(range.low));
      expect(
        fast.profile.componentProfiles.single.halfEmptyingMinutes,
        closeTo(150 / range.high, 1e-9),
      );
      expect(
        slow.profile.componentProfiles.single.halfEmptyingMinutes,
        closeTo(150 / range.low, 1e-9),
      );
      expect(firstMinuteAtOrBelow(fast.profile, 0.5), lessThan(halfMinute));
      expect(firstMinuteAtOrBelow(slow.profile, 0.5), greaterThan(halfMinute));
    });

    test('a zero-kcal liquid keeps the fast exponential', () {
      final built = meal(const [water]);
      final component = built.profile.componentProfiles.single;
      expect(component.isCalorieRegulated, isFalse);
      expect(component.volumeHalfEmptyingMinutes, isNull);
      expect(component.calorieDeliveryMinutes, isNull);
      // 0 kcal gives the smallest size multiplier (0.6) on the 15-min anchor.
      expect(component.halfEmptyingMinutes, closeTo(15 * 0.6, 1e-9));
      for (var minute = 1; minute <= 120; minute++) {
        expect(
          built.profile.remainingFractionAt(minute),
          closeTo(
            math.exp(-math.ln2 * minute / component.halfEmptyingMinutes),
            1e-12,
          ),
        );
      }
      expect(firstMinuteAtOrBelow(built.profile, 0.5), lessThanOrEqualTo(10));
      expect(
        built.profile.assumptions,
        contains(startsWith('ge.liquid.energy_free_exponential')),
      );
      expect(
        built.profile.toJson()['component_profiles'].single,
        isNot(contains('emptying_kinetics')),
      );
    });

    test('a nearly energy-free liquid stays on the volume-driven curve', () {
      final built = meal([
        const FoodComponent(
          id: 'black_coffee',
          name: 'Black coffee (synthetic)',
          physicalForm: MealPhysicalForm.liquid,
          proteinGrams: 0,
          fatGrams: 0,
          fiberGrams: 0,
          carbohydrateGrams: 0,
          calories: 2,
          portionGrams: 240,
          sourceDocId: 'synthetic:test',
        ),
      ]);
      final component = built.profile.componentProfiles.single;
      expect(component.isCalorieRegulated, isTrue);
      expect(
        component.halfEmptyingMinutes,
        component.volumeHalfEmptyingMinutes,
      );
      for (var minute = 1; minute <= 120; minute++) {
        expect(
          built.profile.remainingFractionAt(minute),
          closeTo(
            math.exp(-math.ln2 * minute / component.volumeHalfEmptyingMinutes!),
            1e-12,
          ),
        );
      }
    });

    test('energy-containing liquids in one meal share one calorie pool', () {
      final built = meal([
        shake(calories: 150, id: 'shake_a'),
        shake(calories: 150, id: 'shake_b'),
      ]);
      for (final component in built.profile.componentProfiles) {
        expect(component.calorieDeliveryMinutes, closeTo(300 / 2.13, 1e-9));
      }
    });

    test('an unknown-energy liquid is drawn on the fast bound, records the '
        'missing input and widens uncertainty', () {
      MealComposition composition(double? liquidCalories) => MealComposition(
        id: 'meal',
        totalCalories: 200,
        proteinGrams: 25,
        fatGrams: 8,
        fiberGrams: 0,
        carbohydrateGrams: 32,
        liquidFraction: 1,
        mealPhysicalForm: MealPhysicalForm.liquid,
        portionSizeBand: PortionSizeBand.small,
        proteinAmountBand: AmountBand.high,
        fatAmountBand: AmountBand.moderate,
        fiberAmountBand: AmountBand.none,
        calorieBand: AmountBand.moderate,
        compositionCompleteness: 1,
        missingFields: const [],
        foodComponents: [shake(calories: liquidCalories)],
      );
      final known = gastric.build(
        mealId: 'meal',
        mealStartMinute: 0,
        composition: composition(0),
      );
      final unknown = gastric.build(
        mealId: 'meal',
        mealStartMinute: 0,
        composition: composition(null),
      );

      expect(unknown.componentProfiles.single.isCalorieRegulated, isFalse);
      expect(
        unknown.componentProfiles.single.halfEmptyingMinutes,
        known.componentProfiles.single.halfEmptyingMinutes,
      );
      expect(unknown.missingInputs, contains('liquid_component_calories'));
      expect(known.missingInputs, isNot(contains('liquid_component_calories')));
      expect(
        unknown.assumptions,
        contains(startsWith('ge.liquid.energy_unknown_fast_bound')),
      );
      expect(
        UncertaintyBand.values.indexOf(unknown.uncertaintyBand),
        UncertaintyBand.values.indexOf(known.uncertaintyBand) +
            GastricEmptyingModel.unknownEnergyLiquidUncertaintyIncrement,
      );
    });

    test('profile integrity rejects inconsistent calorie regulation', () {
      GastricEmptyingProfile profileWith(EmptyingComponentProfile component) =>
          GastricEmptyingProfile(
            mealId: 'meal',
            componentProfiles: [component],
            uncertaintyBand: UncertaintyBand.narrow,
            assumptions: const [],
            missingInputs: const [],
            sourceRefs: const ['src.internal.prototype.heuristic'],
            aggregateLagMinutes: 0,
            peakEmptyingWindow: TimelineWindow(
              startMinute: 0,
              endMinute: (component.halfEmptyingMinutes * 1.5).round(),
            ),
            mostlyEmptiedWindow: TimelineWindow(
              startMinute: 0,
              endMinute: (component.halfEmptyingMinutes * 4).round(),
            ),
            timeScaleSensitivityFraction: 0.24,
          );
      EmptyingComponentProfile component({
        MealPhysicalForm form = MealPhysicalForm.liquid,
        double half = 60,
        double? volumeHalf = 9,
        double? delivery = 120,
      }) => EmptyingComponentProfile(
        componentId: 'shake',
        physicalForm: form,
        lagMinutes: 0,
        halfEmptyingMinutes: half,
        fractionOfMeal: 1,
        appliedModifiers: const [],
        volumeHalfEmptyingMinutes: volumeHalf,
        calorieDeliveryMinutes: delivery,
      );

      expect(profileWith(component()).structuralIntegrityReasons, isEmpty);
      expect(
        profileWith(component(delivery: null)).structuralIntegrityReasons,
        contains('gastric_emptying.profile_calorie_regulation_incomplete'),
      );
      expect(
        profileWith(
          component(form: MealPhysicalForm.solid),
        ).structuralIntegrityReasons,
        contains('gastric_emptying.profile_calorie_regulation_form_invalid'),
      );
      expect(
        profileWith(component(half: 50)).structuralIntegrityReasons,
        contains(
          'gastric_emptying.profile_calorie_regulation_half_time_inconsistent',
        ),
      );
      expect(
        profileWith(
          component(delivery: -1, half: 9),
        ).structuralIntegrityReasons,
        contains('gastric_emptying.profile_calorie_regulation_invalid'),
      );
    });

    test('the sensitivity envelope scales the calorie-regulated delivery', () {
      final built = meal([shake()]);
      for (var minute = 0; minute <= 400; minute += 5) {
        final central = built.profile.remainingFractionAt(minute);
        final envelope = built.profile.sensitivityEnvelopeAt(minute);
        expect(envelope.fasterRemaining, lessThanOrEqualTo(central + 1e-12));
        expect(envelope.slowerRemaining, greaterThanOrEqualTo(central - 1e-12));
      }
    });
  });

  group('provenance and copy', () {
    test('the delivery rate is literature-derived, sourced and bounded', () {
      final rate = defaults.liquidNutrientKcalPerMinute;
      expect(rate.confidence, ModelEvidenceLevel.mechanism);
      expect(rate.sourceRefs, [
        'src.brener.glucose_emptying.1983',
        'src.hunt_stubbs.energy_density.1975',
        'src.marathe.ge_kcal_range.2013',
      ]);
      for (final sourceId in rate.sourceRefs) {
        final source = ModelAssumptionRegistry.byId(sourceId);
        expect(source, isNotNull, reason: sourceId);
        expect(source!.citationText, isNotEmpty);
        expect(source.limitation, isNotEmpty);
      }
      expect(rate.limitation, contains('1–4 kcal/min'));
      expect(defaults.validationErrors, isEmpty);
      expect(defaults.toJson()['liquid_nutrient_kcal_per_min'], {
        'id': 'ge.liquid.nutrient_kcal_per_min',
        'label': rate.label,
        'value': 2.13,
        'source_refs': rate.sourceRefs,
        'confidence': 'mechanism',
        'limitation': rate.limitation,
        'sensitivity_range': {'low': 1.0, 'high': 4.0},
      });

      final outside = GastricEmptyingParameterSet(
        id: defaults.id,
        version: 'rate-outside-range',
        lastReviewed: defaults.lastReviewed,
        solidLagMinutes: defaults.solidLagMinutes,
        solidHalfMinutes: defaults.solidHalfMinutes,
        liquidLagMinutes: defaults.liquidLagMinutes,
        liquidHalfMinutes: defaults.liquidHalfMinutes,
        liquidNutrientKcalPerMinute: GastricEmptyingParameter<double>(
          id: rate.id,
          label: rate.label,
          value: 5,
          sourceRefs: rate.sourceRefs,
          confidence: rate.confidence,
          limitation: rate.limitation,
          sensitivityRange: rate.sensitivityRange,
        ),
        referenceMealCalories: defaults.referenceMealCalories,
        fatSlowdownMultiplier: defaults.fatSlowdownMultiplier,
        fatFractionThreshold: defaults.fatFractionThreshold,
        fiberSlowdownMultiplier: defaults.fiberSlowdownMultiplier,
        mixedMealUncertaintyBoost: defaults.mixedMealUncertaintyBoost,
        overlapUncertaintyBoost: defaults.overlapUncertaintyBoost,
        fatUncertaintyBoost: defaults.fatUncertaintyBoost,
        highCalorieUncertaintyBoost: defaults.highCalorieUncertaintyBoost,
        highCalorieFractionThreshold: defaults.highCalorieFractionThreshold,
        timeScaleSensitivityFraction: defaults.timeScaleSensitivityFraction,
      );
      expect(
        outside.validationErrors,
        contains(
          'parameter_sensitivity_range_invalid:ge.liquid.nutrient_kcal_per_min',
        ),
      );
    });

    test('new trace and provenance copy passes the banned-phrase scan', () {
      final unknownEnergy = normalizer.normalize(
        mealId: 'meal',
        components: [shake(calories: null)],
      );
      final texts = <String>[
        ...meal([shake()]).profile.assumptions,
        ...meal(const [oatmeal, water]).profile.assumptions,
        ...gastric
            .build(
              mealId: 'meal',
              mealStartMinute: 0,
              composition: unknownEnergy,
            )
            .assumptions,
        ...competition
            .build(
              mealComposition: meal(const [oatmeal, water]).composition,
              mealEmptyingProfile: meal(const [oatmeal, water]).profile,
              absorptionWindow: absorption.build(
                medication: levodopa(),
                overlappingMealProfile: meal(const [oatmeal, water]).profile,
              ),
              mealStartMinute: 0,
            )
            .assumptions,
        defaults.liquidNutrientKcalPerMinute.label,
        defaults.liquidNutrientKcalPerMinute.limitation,
        defaults.liquidHalfMinutes.limitation,
        for (final id in defaults.liquidNutrientKcalPerMinute.sourceRefs) ...[
          ModelAssumptionRegistry.byId(id)!.mechanismSupported,
          ModelAssumptionRegistry.byId(id)!.limitation,
        ],
      ];
      expect(findBannedSubstrings(texts.join(' ')), isEmpty);
    });
  });
}
