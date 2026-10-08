import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_conflict_result.dart';
import 'package:parkinsum_companion/domain/entities/reference_food_composition.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/food_composition_interdependency_model.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';
import 'package:parkinsum_companion/domain/usecases/model_assumption_registry.dart';
import 'package:parkinsum_companion/domain/usecases/time_axis_builder.dart';

/// Food-composition interdependencies and their conflict-engine integration.
/// Educational prototype; synthetic meals only.
void main() {
  group('carbohydrate conventions and salt', () {
    test('by-difference and available conventions convert through fibre', () {
      expect(
        convertCarbohydrate(
          value: 22.84,
          fiberG: 2.6,
          from: CarbohydrateConvention.byDifferenceIncludingFiber,
          to: CarbohydrateConvention.availableExcludingFiber,
        ),
        closeTo(20.24, 1e-9),
      );
      expect(
        convertCarbohydrate(
          value: 19.7,
          fiberG: 2.7,
          from: CarbohydrateConvention.availableExcludingFiber,
          to: CarbohydrateConvention.byDifferenceIncludingFiber,
        ),
        closeTo(22.4, 1e-9),
      );
    });

    test('conversion abstains instead of assuming zero fibre', () {
      expect(
        convertCarbohydrate(
          value: 10,
          fiberG: null,
          from: CarbohydrateConvention.byDifferenceIncludingFiber,
          to: CarbohydrateConvention.availableExcludingFiber,
        ),
        isNull,
      );
      expect(
        convertCarbohydrate(
          value: 10,
          fiberG: 1,
          from: CarbohydrateConvention.unverified,
          to: CarbohydrateConvention.availableExcludingFiber,
        ),
        isNull,
      );
      // Fibre larger than carbohydrate by difference is inconsistent data.
      expect(
        convertCarbohydrate(
          value: 2,
          fiberG: 5,
          from: CarbohydrateConvention.byDifferenceIncludingFiber,
          to: CarbohydrateConvention.availableExcludingFiber,
        ),
        isNull,
      );
    });

    test('salt equivalent uses the EU 2.5 factor and rejects bad input', () {
      expect(saltEquivalentFromSodiumMg(400), closeTo(1.0, 1e-12));
      expect(saltEquivalentFromSodiumMg(null), isNull);
      expect(saltEquivalentFromSodiumMg(-1), isNull);
    });
  });

  group('derivations between foods', () {
    test('every encoded derivation edge is coherent with the data', () {
      for (final edge in foodDerivationEdges) {
        final check = checkDerivationEdge(edge);
        expect(
          check.findings,
          isEmpty,
          reason: '${edge.id}: ${check.findings}',
        );
      }
    });

    test('protein tracer recovers water uptake and loss', () {
      final rice = checkDerivationEdge(
        foodDerivationEdges.firstWhere(
          (e) => e.id == 'white_rice_long_grain.dry_to_cooked',
        ),
      );
      expect(rice.impliedMassRatio, closeTo(2.65, 0.01));
      final oats = checkDerivationEdge(
        foodDerivationEdges.firstWhere(
          (e) => e.id == 'oats.dry_to_cooked_with_water',
        ),
      );
      expect(oats.impliedMassRatio, closeTo(5.18, 0.01));
      final cod = checkDerivationEdge(
        foodDerivationEdges.firstWhere(
          (e) => e.id == 'cod_atlantic.raw_to_cooked',
        ),
      );
      expect(cod.impliedMassRatio, closeTo(0.78, 0.01));
    });

    test('juice keeps a small fraction of the fruit fibre per unit energy', () {
      final juice = checkDerivationEdge(
        foodDerivationEdges.firstWhere(
          (e) => e.id == 'orange_to_juice.extraction',
        ),
      );
      expect(juice.fiberRetainedPerEnergy, lessThan(0.10));
    });

    test('salt-only edge recovers the added salt from sodium', () {
      final salted = checkDerivationEdge(
        foodDerivationEdges.firstWhere(
          (e) => e.id == 'white_rice_cooked.salt_addition',
        ),
      );
      expect(salted.impliedAddedSaltGPer100g, closeTo(0.9525, 1e-9));
    });

    test('a corrupted record is detected as incoherent', () {
      final rows = Map.of(referenceRowsByFdcId);
      final cooked = rows[169757]!;
      rows[169757] = ReferenceFoodCompositionRow(
        fdcId: cooked.fdcId,
        sourceDescription: cooked.sourceDescription,
        nameEn: cooked.nameEn,
        nameZh: cooked.nameZh,
        group: cooked.group,
        preparationState: cooked.preparationState,
        textureClass: cooked.textureClass,
        // Energy of the dry grain pasted into the cooked record.
        energyKcal: 365,
        proteinG: cooked.proteinG,
        fatG: cooked.fatG,
        carbohydrateByDifferenceG: cooked.carbohydrateByDifferenceG,
        fiberG: cooked.fiberG,
        calciumMg: cooked.calciumMg,
        phosphorusMg: cooked.phosphorusMg,
        ironMg: cooked.ironMg,
        sodiumMg: cooked.sodiumMg,
        potassiumMg: cooked.potassiumMg,
        copperMg: cooked.copperMg,
        zincMg: cooked.zincMg,
        retinolUg: cooked.retinolUg,
        betaCaroteneUg: cooked.betaCaroteneUg,
        thiaminMg: cooked.thiaminMg,
        riboflavinMg: cooked.riboflavinMg,
        niacinMg: cooked.niacinMg,
        vitaminCMg: cooked.vitaminCMg,
      );
      final check = checkDerivationEdge(
        foodDerivationEdges.firstWhere(
          (e) => e.id == 'white_rice_long_grain.dry_to_cooked',
        ),
        rowsById: rows,
      );
      expect(check.coherent, isFalse);
      expect(check.incoherentNutrients, contains('energy'));
      expect(auditReferenceRow(rows[169757]!).isConsistent, isFalse);
    });

    test('whole egg = white + yolk on energy and fat; iron does not close', () {
      final egg = checkEggPartWhole();
      expect(egg.secondPartFraction, closeTo(0.335, 0.001));
      expect(egg.incoherentNutrients, isEmpty);
      expect(egg.deviations['energy']!.abs(), lessThan(0.01));
      // SR Legacy whole-egg iron (1.75 mg) is not reproduced by its own
      // white and yolk records (≈0.97 mg): a documented source-internal gap.
      expect(egg.deviations['iron'], lessThan(-0.4));
    });
  });

  group('food-borne L-dopa sources', () {
    test('matches broad bean names across languages and reference ids', () {
      for (final name in [
        'Fava beans',
        'broad bean salad',
        '鲜蚕豆',
        '胡豆',
        'Fèves au beurre',
      ]) {
        expect(
          matchIntrinsicLevodopaSource(name: name)?.source.id,
          'vicia_faba',
          reason: name,
        );
      }
      expect(
        matchIntrinsicLevodopaSource(
          name: 'anything',
          reference: referenceRowsByFdcId[175205],
        )?.matchedBy,
        'reference_fdc_id:175205',
      );
      expect(
        matchIntrinsicLevodopaSource(name: 'Mucuna pruriens powder')?.source.id,
        'mucuna_pruriens',
      );
    });

    test('does not match look-alike words', () {
      for (final name in [
        'favorite pasta',
        'kale',
        'fabulous salad',
        'green beans',
        'soybeans',
      ]) {
        expect(matchIntrinsicLevodopaSource(name: name), isNull, reason: name);
      }
    });

    test(
      'published L-dopa content spans more than two orders of magnitude',
      () {
        expect(viciaFabaLevodopaSource.quantifiedForEdibleServing, isFalse);
        expect(
          viciaFabaLevodopaSource.publishedRangeSpanFactor,
          greaterThan(100),
        );
        for (final source in intrinsicLevodopaSources) {
          for (final ref in source.sourceRefs) {
            expect(ModelAssumptionRegistry.byId(ref), isNotNull, reason: ref);
          }
        }
      },
    );
  });

  group('dry versus cooked ambiguity', () {
    test('flags foods whose state is not stated', () {
      final rice = detectPreparationStateAmbiguity('rice');
      expect(rice?.family.id, 'white_rice');
      expect(rice!.proteinAmbiguityFactor, closeTo(2.65, 0.01));
      expect(detectPreparationStateAmbiguity('大米')?.family.id, 'white_rice');
      expect(
        detectPreparationStateAmbiguity('brown rice')?.family.id,
        'brown_rice',
      );
      expect(
        detectPreparationStateAmbiguity('rice noodles')?.family.id,
        'rice_noodles',
      );
      expect(detectPreparationStateAmbiguity('oatmeal')?.family.id, 'oats');
      expect(detectPreparationStateAmbiguity('lentils')?.family.id, 'lentils');
    });

    test('does not flag stated states or different products', () {
      for (final name in [
        'cooked rice',
        '糙米饭',
        'boiled lentils',
        'rice flour',
        'soy sauce',
        'soy milk',
        'oat milk',
        '小米',
        '玉米',
        'tofu',
        'green soybeans',
        'rolled oats, dry',
      ]) {
        expect(detectPreparationStateAmbiguity(name), isNull, reason: name);
      }
    });
  });

  group('energy reconciliation', () {
    test('accepts consistent servings and flags inconsistent ones', () {
      final ok = reconcileEnergy(
        reportedKcal: 200,
        proteinG: 35,
        fatG: 5,
        carbohydrateG: 5,
        fiberG: 0,
        convention: CarbohydrateConvention.availableExcludingFiber,
        scaleGrams: 200,
      );
      expect(ok.status, EnergyReconciliationStatus.consistent);
      final bad = reconcileEnergy(
        reportedKcal: 900,
        proteinG: 10,
        fatG: 2,
        carbohydrateG: 20,
        fiberG: 1,
        convention: CarbohydrateConvention.availableExcludingFiber,
        scaleGrams: 150,
      );
      expect(bad.status, EnergyReconciliationStatus.inconsistent);
    });

    test('alcohol hint explains a positive residual for drinks', () {
      final wine = reconcileEnergy(
        reportedKcal: 125,
        proteinG: 0.1,
        fatG: 0,
        carbohydrateG: 4,
        fiberG: 0,
        convention: CarbohydrateConvention.availableExcludingFiber,
        nonMacronutrientEnergyHint: nonMacronutrientEnergyHintFor('red wine'),
        scaleGrams: 150,
      );
      expect(wine.status, EnergyReconciliationStatus.explainedByAlcohol);
      expect(
        nonMacronutrientEnergyHintFor('red wine vinegar'),
        NonMacronutrientEnergyHint.organicAcids,
      );
      expect(
        nonMacronutrientEnergyHintFor('ginger tea'),
        NonMacronutrientEnergyHint.none,
      );
    });
  });

  group('non-heme iron co-consumption context', () {
    test('quantifies studied modulators only when portions are known', () {
      final context = assessIronCoConsumption([
        MealItemReference(
          componentId: 'milk',
          name: 'milk, whole',
          portionGrams: 200,
          reference: referenceRowsByFdcId[171265],
        ),
        MealItemReference(
          componentId: 'spinach',
          name: 'spinach, raw',
          portionGrams: 100,
          reference: referenceRowsByFdcId[168462],
        ),
        MealItemReference(
          componentId: 'coffee',
          name: 'coffee, brewed',
          portionGrams: 240,
          reference: referenceRowsByFdcId[171890],
        ),
        const MealItemReference(
          componentId: 'mystery',
          name: 'homemade stew',
          portionGrams: 300,
          reference: null,
        ),
      ]);
      expect(context.quantifiedCalciumMg, closeTo(226 + 99 + 4.8, 1e-9));
      expect(
        context.factors,
        containsAll([
          IronCoConsumptionFactor.calciumAtOrAboveStudiedAmount,
          IronCoConsumptionFactor.polyphenolBeverage,
          IronCoConsumptionFactor.ascorbicAcidSource,
        ]),
      );
      expect(
        context.factors,
        isNot(contains(IronCoConsumptionFactor.hemeIronSource)),
      );
      expect(context.unquantifiedComponentIds, ['mystery']);
      expect(findBannedSubstrings(context.limitation), isEmpty);
    });
  });

  group('cross-source comparison', () {
    test('separates expected variation from material differences', () {
      expect(
        compareCrossSource(
          nutrient: 'protein',
          left: 1.06,
          right: 1.09,
        ).agreement,
        CrossSourceAgreement.agree,
      );
      expect(
        compareCrossSource(
          nutrient: 'protein',
          left: 14.1,
          right: 17.27,
        ).agreement,
        CrossSourceAgreement.differWithinExpectedVariation,
      );
      expect(
        compareCrossSource(
          nutrient: 'carbohydrate',
          left: 1.7,
          right: 4.04,
        ).agreement,
        CrossSourceAgreement.materialDifference,
      );
      expect(
        compareCrossSource(nutrient: 'sodium', left: null, right: 4).agreement,
        CrossSourceAgreement.notComparable,
      );
    });
  });

  group('conflict engine integration', () {
    final validator = MedicationEntryValidator();
    final normalizer = MealCompositionNormalizer();
    final builder = TimeAxisBuilder();
    final engine = MechanisticConflictEngine();

    MechanisticConflictResult run(
      String foodName, {
      double protein = 20,
      double calories = 253,
    }) {
      final v = validator.validate(
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
      final composition = normalizer.normalize(
        mealId: 'c',
        components: [
          FoodComponent(
            id: 'food',
            name: foodName,
            physicalForm: MealPhysicalForm.solid,
            proteinGrams: protein,
            fatGrams: 5,
            fiberGrams: 4,
            carbohydrateGrams: 30,
            calories: calories,
            portionGrams: 250,
            sourceDocId: 'synthetic:demo',
          ),
        ],
      );
      final now = DateTime.utc(2026, 1, 1, 8);
      final ctx = builder.build(
        now: now,
        medicationInputs: [
          MedicationTimelineInput(
            id: 'm',
            takenAt: now.add(const Duration(minutes: 30)),
            medicationContext: v,
          ),
        ],
        mealInputs: [
          MealTimelineInput(
            id: 'meal',
            startedAt: now,
            compositionId: composition.id,
            physicalForm: MealPhysicalForm.solid,
          ),
        ],
      );
      return engine.evaluate(
        context: ctx,
        mealCompositionsById: {composition.id: composition},
      );
    }

    test('food-borne L-dopa is surfaced without changing the score', () {
      final baseline = run('green peas, boiled');
      final fava = run('broad beans, boiled');
      expect(baseline.hasModeledOutput, isTrue);
      expect(fava.hasModeledOutput, isTrue);
      expect(fava.interactionScore, baseline.interactionScore);
      expect(fava.severityBand, baseline.severityBand);
      expect(
        fava.primaryDrivers,
        contains('food_intrinsic_levodopa_source_present'),
      );
      expect(
        baseline.primaryDrivers,
        isNot(contains('food_intrinsic_levodopa_source_present')),
      );
      expect(
        fava.uncertaintyReasons,
        contains('food_intrinsic_levodopa_unquantified(c:food:vicia_faba)'),
      );
      expect(fava.sourceRefs, contains('src.duan.faba_ldopa_thermal.2021'));
      expect(fava.confidenceBand, isNot(ConfidenceBand.high));
      if (baseline.confidenceBand == ConfidenceBand.high) {
        expect(fava.confidenceBand, ConfidenceBand.medium);
      }
    });

    test('unstated dry/cooked state widens uncertainty only', () {
      // 10.5 g protein in 250 g = 4.2 g/100 g: not within 35% of cooked
      // (2.69) or dry (7.13) white rice, so the state stays open.
      final stated = run('cooked rice', protein: 10.5, calories: 215);
      final unstated = run('rice', protein: 10.5, calories: 215);
      expect(unstated.interactionScore, stated.interactionScore);
      expect(
        unstated.uncertaintyReasons.any(
          (r) => r.startsWith('food_preparation_state_ambiguous(c:food:'),
        ),
        isTrue,
      );
      expect(
        stated.uncertaintyReasons.any(
          (r) => r.startsWith('food_preparation_state_ambiguous'),
        ),
        isFalse,
      );
      expect(unstated.confidenceBand, isNot(ConfidenceBand.high));
    });

    test('a serving whose protein density fixes the state is not flagged', () {
      // 7 g protein in 260 g ≈ 2.7 g/100 g matches cooked oats (2.54).
      final model = const FoodCompositionInterdependencyModel();
      final assessment = model.assessMeal(
        MealCompositionNormalizer().normalize(
          mealId: 'm',
          components: const [
            FoodComponent(
              id: 'oats_component',
              name: 'Oats and fruit',
              physicalForm: MealPhysicalForm.solid,
              proteinGrams: 7,
              fatGrams: 4,
              fiberGrams: 7,
              carbohydrateGrams: 48,
              calories: 270,
              portionGrams: 260,
              sourceDocId: 'synthetic',
            ),
          ],
        ),
      );
      expect(assessment.preparationStateAmbiguities, isEmpty);
      expect(assessment.hasFindings, isFalse);
    });

    test('every emitted interdependency ref resolves and copy stays safe', () {
      final result = run('broad beans');
      for (final ref in result.sourceRefs) {
        expect(ModelAssumptionRegistry.byId(ref), isNotNull, reason: ref);
      }
      final trace = result.explanation.layerTraces.firstWhere(
        (t) => t.layer == 'food_composition_interdependency',
      );
      expect(
        findBannedSubstrings(
          [trace.description, ...trace.assumptionsApplied].join(' '),
        ),
        isEmpty,
      );
      expect(trace.uncertaintyContribution, 'wide');
    });
  });
}
