import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/lnaa_protein_fraction_calibration_table.dart';
import 'package:parkinsum_companion/core/constants/reference_food_nutrient_profiles.dart';
import 'package:parkinsum_companion/domain/entities/amino_acid_competition.dart';
import 'package:parkinsum_companion/domain/entities/amino_acid_profile.dart';
import 'package:parkinsum_companion/domain/entities/lnaa_protein_fraction_calibration.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/protein_source.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/amino_acid_competition_model.dart';
import 'package:parkinsum_companion/domain/usecases/gastric_emptying_model.dart';
import 'package:parkinsum_companion/domain/usecases/levodopa_absorption_opportunity_model.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';

import '../tool/lnaa_protein_fraction_calibration_codegen.dart';
import '../tool/reference_food_composition_codegen.dart';
import '../tool/reference_food_nutrient_profile_codegen.dart';

/// Competing-LNAA fraction of protein, calibrated on the official FoodData
/// Central 2025-04-24 SR Legacy records. Educational prototype; the values
/// describe food composition, not people, doses or timing.
void main() {
  final computed = computeLnaaCalibration(
    nutrientCsvText: File(srNutrientSubsetPath).readAsStringSync(),
    derivationCsvText: File(fdcDerivationPath).readAsStringSync(),
    referenceCsvText: File(referenceSubsetCsvPath).readAsStringSync(),
    curationJsonText: File(referenceCurationJsonPath).readAsStringSync(),
  );
  final reference = lnaaFractionOverall.median;
  final foodsById = {for (final food in lnaaCalibrationFoods) food.fdcId: food};

  void expectSameStatistics(
    LnaaFractionStatistics generated,
    LnaaStatisticsResult source,
    String label,
  ) {
    expect(generated.foodCount, source.foodCount, reason: label);
    expect(
      generated.independentPatternCount,
      source.independentPatternCount,
      reason: label,
    );
    expect(generated.median, source.median, reason: label);
    expect(generated.lowerQuartile, source.lowerQuartile, reason: label);
    expect(generated.upperQuartile, source.upperQuartile, reason: label);
    expect(generated.minimum, source.minimum, reason: label);
    expect(generated.maximum, source.maximum, reason: label);
    expect(
      generated.weakestTierCounts,
      source.weakestTierCounts,
      reason: label,
    );
  }

  test('generated table equals a recomputation from the source files', () {
    expect(lnaaCalibrationRelease, '2025-04-24');
    expect(lnaaCalibrationMinimumProteinG, calibrationMinimumProteinG);
    expect(lnaaCalibrationFoods, hasLength(computed.foods.length));
    for (var i = 0; i < computed.foods.length; i++) {
      final source = computed.foods[i];
      final food = lnaaCalibrationFoods[i];
      expect(food.fdcId, source.fdcId);
      expect(food.curatedGroup, source.curatedGroup);
      expect(food.proteinSource?.name, source.proteinSource);
      expect(food.proteinG, source.proteinG);
      expect(food.competingLnaaG, source.competingLnaaG);
      expect(food.patternId, source.patternId);
      expect(food.weakestTier, source.weakestTier);
    }
    expectSameStatistics(lnaaFractionOverall, computed.overall, 'overall');
    expect(
      lnaaFractionBySource.keys.map((type) => type.name).toList(),
      computed.bySource.keys.toList(),
    );
    for (final entry in lnaaFractionBySource.entries) {
      expectSameStatistics(
        entry.value,
        computed.bySource[entry.key.name]!,
        entry.key.name,
      );
    }
  });

  test('calibration admits exactly the eligible reference foods', () {
    final eligible = <int>{};
    for (final row in parseSubsetRows(
      File(referenceSubsetCsvPath).readAsStringSync(),
    )) {
      final values = referenceAttributeValues(row.fdcId);
      final protein = values['protein_g'];
      final profile = referenceAminoAcidProfile(row.fdcId);
      final six = [
        profile?.leucine,
        profile?.isoleucine,
        profile?.valine,
        profile?.phenylalanine,
        profile?.tyrosine,
        profile?.tryptophan,
      ];
      if (protein != null &&
          protein >= lnaaCalibrationMinimumProteinG &&
          profile != null &&
          !profile.partial &&
          six.every((value) => value != null)) {
        eligible.add(row.fdcId);
      }
    }
    expect(foodsById.keys.toSet(), eligible);
    expect(eligible, hasLength(140));
    // Raw Brussels sprouts (3.38 g protein) publish five of the six: the
    // official record has no tyrosine row, so it stays out of the
    // calibration, as the competition model also refuses a five-of-six sum.
    final sprouts = referenceAminoAcidProfile(170383)!;
    expect(sprouts.tyrosine, isNull);
    expect(sprouts.leucine, 0.152);
    expect(foodsById.containsKey(170383), isFalse);
  });

  test('every competing total equals the extractor the model uses', () {
    // The calibration sums the same six amino acids the competition model
    // reads from AminoAcidProfile.competingLnaaGrams.
    for (final food in lnaaCalibrationFoods) {
      final profile = referenceAminoAcidProfile(food.fdcId)!;
      expect(
        food.competingLnaaG,
        closeTo(profile.competingLnaaGrams!, 1e-12),
        reason: '${food.fdcId}',
      );
      expect(
        food.proteinG,
        referenceAttributeValues(food.fdcId)['protein_g'],
        reason: '${food.fdcId}',
      );
    }
  });

  test('type-7 quantiles match the textbook definition', () {
    expect(quantileType7([1, 2, 3, 4], 0.25), 1.75);
    expect(quantileType7([1, 2, 3, 4], 0.5), 2.5);
    expect(quantileType7([1, 2, 3, 4], 0.75), 3.25);
    expect(quantileType7([5], 0.5), 5);
  });

  test('shared amino-acid patterns are found within published rounding', () {
    List<int> members(int patternId) => [
      for (final food in lnaaCalibrationFoods)
        if (food.patternId == patternId) food.fdcId,
    ];
    // Twelve finfish records carry one amino-acid pattern scaled to their
    // protein: carp, cod (raw, cooked), kippered herring, Pacific mackerel,
    // wild and farmed cooked Atlantic salmon, smoked chinook, pollock,
    // canned sardine, skipjack and canned white tuna.
    expect(members(171952), [
      171952,
      171955,
      171956,
      173668,
      173672,
      173686,
      173687,
      175129,
      175139,
      175156,
      175158,
      175168,
    ]);
    // Roquefort and feta share the sheep-milk pattern.
    expect(members(170882), [170882, 171250, 173420]);
    // Raw and cooked forms share a pattern.
    expect(members(169753), [169753, 169756, 169757]);
    expect(members(172420), [172420, 172421]);
    expect(lnaaFractionBySource[ProteinSourceType.fish]!.foodCount, 18);
    expect(
      lnaaFractionBySource[ProteinSourceType.fish]!.independentPatternCount,
      7,
    );
    expect(lnaaFractionOverall.independentPatternCount, 109);
    // Pattern members agree to about four decimals of the fraction.
    final byPattern = <int, List<double>>{};
    for (final food in lnaaCalibrationFoods) {
      byPattern.putIfAbsent(food.patternId, () => []).add(food.fraction);
    }
    for (final fractions in byPattern.values) {
      fractions.sort();
      expect(fractions.last - fractions.first, lessThan(0.001));
    }
  });

  test('official composition orders the protein sources', () {
    double factor(ProteinSourceType type) =>
        ProteinSourceLnaaRegistry.factorFor(type).loadFactor;
    expect(reference, closeTo(0.2667, 0.0001));
    expect(AminoAcidCompetitionModel.referenceLnaaFractionOfProtein, reference);
    for (final type in lnaaFractionBySource.keys) {
      final stats = lnaaFractionBySource[type]!;
      final loadFactor = ProteinSourceLnaaRegistry.factorFor(type);
      expect(loadFactor.loadFactor, stats.median / reference);
      expect(
        loadFactor.interquartileLowFactor,
        stats.lowerQuartile / reference,
      );
      expect(
        loadFactor.interquartileHighFactor,
        stats.upperQuartile / reference,
      );
      expect(loadFactor.isPrototypeHeuristic, isFalse);
      expect(
        loadFactor.sourceRefs,
        contains(ProteinSourceLnaaRegistry.calibrationSourceId),
      );
      expect(loadFactor.limitation, contains('${stats.foodCount} official'));
    }
    // Dairy and egg protein carry the most competing LNAA per gram.
    expect(factor(ProteinSourceType.dairy), closeTo(1.268, 0.001));
    expect(factor(ProteinSourceType.egg), closeTo(1.183, 0.001));
    // Meat, fish and grain protein sit within 1.5% of the median.
    for (final type in const [
      ProteinSourceType.meat,
      ProteinSourceType.fish,
      ProteinSourceType.grain,
    ]) {
      expect(factor(type), closeTo(1.0, 0.015), reason: type.name);
    }
    // Soy (including soymilk, miso, soy sauces and soy protein) and other
    // legume protein sit below them.
    expect(factor(ProteinSourceType.soy), closeTo(0.962, 0.001));
    expect(factor(ProteinSourceType.legume), closeTo(0.931, 0.001));
    expect(
      factor(ProteinSourceType.soy),
      lessThan(factor(ProteinSourceType.grain)),
    );
    expect(lnaaFractionBySource[ProteinSourceType.soy]!.foodCount, 14);
    for (final type in const [
      ProteinSourceType.mixed,
      ProteinSourceType.unknown,
    ]) {
      final neutral = ProteinSourceLnaaRegistry.factorFor(type);
      expect(neutral.loadFactor, 1.0);
      expect(neutral.isPrototypeHeuristic, isTrue);
      expect(neutral.calibration, same(lnaaFractionOverall));
    }
  });

  test('envelopes bracket the factor and stay inside the clamp', () {
    for (final factor in ProteinSourceLnaaRegistry.all()) {
      expect(
        factor.interquartileLowFactor,
        lessThanOrEqualTo(factor.loadFactor),
      );
      expect(
        factor.interquartileHighFactor,
        greaterThanOrEqualTo(factor.loadFactor),
      );
      expect(
        factor.interquartileLowFactor,
        greaterThanOrEqualTo(AminoAcidCompetitionModel.loadFactorDomainMinimum),
      );
      expect(
        factor.interquartileHighFactor,
        lessThanOrEqualTo(AminoAcidCompetitionModel.loadFactorDomainMaximum),
      );
    }
  });

  test('only two low-protein calibration foods fall outside the clamp', () {
    final outside = {
      for (final food in lnaaCalibrationFoods)
        if (food.fraction / reference <
                AminoAcidCompetitionModel.loadFactorDomainMinimum ||
            food.fraction / reference >
                AminoAcidCompetitionModel.loadFactorDomainMaximum)
          food.fdcId,
    };
    // Dried plums (prunes) and unsalted tomato paste.
    expect(outside, {168162, 170459});
  });

  group('competition model with an official profile', () {
    final validator = MedicationEntryValidator();
    final medication = MedicationTimelineEvent(
      id: 'm',
      minute: 15,
      context: validator
          .validate(
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
          )
          .normalized!,
    );

    CompetitionLnaaSummary evaluate(int fdcId, double grams) {
      final profile = referenceAminoAcidProfile(fdcId)!;
      final protein = referenceAttributeValues(fdcId)['protein_g']!;
      final composition = MealCompositionNormalizer().normalize(
        mealId: 'synthetic:$fdcId',
        components: [
          FoodComponent(
            id: '$fdcId',
            name: 'official $fdcId',
            physicalForm: MealPhysicalForm.solid,
            proteinGrams: protein * grams / 100,
            fatGrams: 1,
            fiberGrams: 0,
            carbohydrateGrams: 1,
            calories: 100,
            portionGrams: grams,
            sourceDocId: 'synthetic',
            proteinSource: ProteinSourceType.unknown,
            aminoAcidProfile: profile,
          ),
        ],
        declaredPhysicalForm: MealPhysicalForm.solid,
      );
      final emptying = GastricEmptyingModel().build(
        mealId: composition.id,
        mealStartMinute: 0,
        composition: composition,
      );
      final window = LevodopaAbsorptionOpportunityModel().build(
        medication: medication,
        overlappingMealProfile: emptying,
      );
      final timeline = AminoAcidCompetitionModel().build(
        mealComposition: composition,
        mealEmptyingProfile: emptying,
        absorptionWindow: window,
        mealStartMinute: 0,
      );
      return timeline.lnaaSummary!;
    }

    test('cheddar uses its own fraction over the all-food median', () {
      final summary = evaluate(173414, 30);
      final food = foodsById[173414]!;
      expect(summary.dataMode, AminoAcidDataMode.actualAminoAcidFields);
      expect(
        summary.effectiveLoadFactor,
        closeTo(food.fraction / reference, 1e-9),
      );
      expect(summary.loadFactorClamped, isFalse);
      expect(summary.loadFactorInterquartileLow, summary.effectiveLoadFactor);
      expect(summary.referenceLnaaFractionOfProtein, reference);
      expect(
        summary.sourceRefs,
        contains(ProteinSourceLnaaRegistry.calibrationSourceId),
      );
      expect(summary.structuralIntegrityReasons, isEmpty);
    });

    test('a profile below the supported domain is clamped and widened', () {
      final summary = evaluate(168162, 100);
      expect(summary.effectiveLoadFactor, 0.5);
      expect(summary.loadFactorClamped, isTrue);
      expect(summary.uncertaintyWidened, isTrue);
      expect(summary.structuralIntegrityReasons, isEmpty);
    });
  });
}
