import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/physiology_reference_parameters.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/model_assumption_registry.dart';
import 'package:parkinsum_companion/domain/usecases/physiology_reference_model.dart';
import 'package:parkinsum_companion/domain/usecases/physiology_reference_trace_provider.dart';

void main() {
  group('parameter set', () {
    final reference =
        jsonDecode(
              File(
                'tool/physiology_reference/parameters.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;

    test('mirrors parameters.json value, unit, status and source', () {
      expect(
        PhysiologyReferenceParameterSet.parameterSetId,
        reference['parameter_set_id'],
      );
      expect(
        PhysiologyReferenceParameterSet.parameterSetVersion,
        reference['parameter_set_version'],
      );
      expect(PhysiologyReferenceParameterSet.boundary, reference['boundary']);
      final entries = reference['parameters'] as List;
      expect(
        PhysiologyReferenceParameterSet.parameters.map((p) => p.id).toList(),
        [for (final entry in entries) entry['id']],
        reason: 'order drives the seeded draws',
      );
      for (var i = 0; i < entries.length; i++) {
        expect(
          jsonDecode(
            jsonEncode(
              PhysiologyReferenceParameterSet.parameters[i].toReferenceJson(),
            ),
          ),
          entries[i],
        );
      }
    });

    test('keeps the unverified tables honest', () {
      for (final id in ['bbb.km_umol_per_l', 'aa.fasting_plasma_umol_per_l']) {
        expect(
          PhysiologyReferenceParameterSet.byId(id).status,
          PhysiologyParameterStatus.verify,
        );
      }
      final calibrated = PhysiologyReferenceParameterSet.parameters
          .where((p) => p.status == PhysiologyParameterStatus.calibrated)
          .map((p) => p.id)
          .toSet();
      expect(calibrated, {
        'stomach.solid_trituration_rate_per_min',
        'stomach.fed_liquid_slowing_half_kcal',
        'aa.plasma_distribution_volume_l',
      });
    });

    test('cites only registered model-assumption sources', () {
      for (final parameter in PhysiologyReferenceParameterSet.parameters) {
        if (parameter.status == PhysiologyParameterStatus.literature ||
            parameter.status == PhysiologyParameterStatus.calibrated) {
          expect(parameter.sourceIds, isNotEmpty, reason: parameter.id);
        }
        for (final sourceId in parameter.sourceIds) {
          expect(
            ModelAssumptionRegistry.byId(sourceId),
            isNotNull,
            reason: '${parameter.id} cites $sourceId',
          );
        }
      }
      final registry =
          jsonDecode(
                File('config/source_access_registry.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final registered = {
        for (final source in registry['sources'] as List) source['source_id'],
      };
      final bibliography = File('Bibliographies.md').readAsStringSync();
      for (final sourceId in PhysiologyReferenceParameterSet.parameters.expand(
        (p) => p.sourceIds,
      )) {
        expect(registered, contains(sourceId));
        expect(bibliography, contains('`$sourceId`'));
      }
    });
  });

  group('model', () {
    test('Python-compatible random stream matches CPython random.Random', () {
      // Values printed by CPython 3.9 for random.Random(20261020).
      final rng = PythonCompatibleRandom(20261020);
      expect(
        [rng.random(), rng.random(), rng.random()],
        [0.7742395360746822, 0.7451511446523444, 0.81803534413668],
      );
      expect(
        [rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1)],
        [0.08349881036859233, 0.3490197750125643, 0.7414666778120685],
      );
    });

    test('is deterministic, and seeded draws are reproducible', () {
      const scenario = PhysiologyScenario(
        meals: [
          PhysiologyMeal(0, [
            PhysiologyComponent(
              'meal',
              PhysiologyComponentForm.solid,
              kcal: 400,
              proteinG: 20,
            ),
          ]),
        ],
        doses: [PhysiologyDose(30, 100)],
      );
      final central = PhysiologyParameterValues.central();
      expect(
        simulatePhysiology(scenario, central).values,
        simulatePhysiology(scenario, central).values,
      );
      final a = samplePhysiologyPopulation(5, 7);
      final b = samplePhysiologyPopulation(5, 7);
      for (var i = 0; i < 5; i++) {
        expect(a[i].scalars, b[i].scalars);
        expect(a[i].perAminoAcid, b[i].perAminoAcid);
      }
      expect(
        samplePhysiologyPopulation(1, 8).single.scalars,
        isNot(a.first.scalars),
      );
    });

    test('a fasting dose returns to baseline amino acids and index 1', () {
      final s = simulatePhysiology(
        const PhysiologyScenario(doses: [PhysiologyDose(0, 100)]),
        PhysiologyParameterValues.central(),
      );
      expect(s['brain_entry_index'].every((b) => b == 1.0), isTrue);
      expect(s['lnaa6_umol_per_l'].toSet(), {565.0});
      final (tmax, cmax) = s.peak('levodopa_mg_per_l');
      expect(tmax, inInclusiveRange(30, 60));
      expect(cmax, greaterThan(0));
    });

    test('water alone does not move the plasma LNAA peak', () {
      const oat = PhysiologyComponent(
        'oatmeal',
        PhysiologyComponentForm.solid,
        kcal: 250,
        proteinG: 8,
      );
      double peakTime(List<PhysiologyComponent> meal) => simulatePhysiology(
        PhysiologyScenario(meals: [PhysiologyMeal(0, meal)]),
        PhysiologyParameterValues.central(),
      ).peak('lnaa6_umol_per_l').$1;
      expect(
        peakTime([
          oat,
          const PhysiologyComponent(
            'water',
            PhysiologyComponentForm.water,
            waterMl: 240,
          ),
        ]),
        peakTime([oat]),
      );
    });

    test('every recorded series declares its unit', () {
      expect(physiologySeriesUnits.keys.toSet(), PhysiologySeries.keys.toSet());
      expect(physiologySeriesUnits['levodopa_mg_per_l'], 'mg/L');
      expect(physiologySeriesUnits['lnaa6_umol_per_l'], 'µmol/L');
      expect(physiologySeriesUnits['energy_out_kcal_per_min'], 'kcal/min');
    });
  });

  group('trace provider', () {
    final provider = PhysiologyReferenceTraceProvider(draws: 20);

    test('timing effect is direction-aware and banded', () {
      const shake = [
        PhysiologyComponent(
          'shake',
          PhysiologyComponentForm.liquid,
          kcal: 300,
          proteinG: 25,
          waterMl: 300,
        ),
      ];
      final before = provider.mealTimingEffect(shake, -30)!;
      final after = provider.mealTimingEffect(shake, 30)!;
      expect(before.central, lessThan(after.central));
      for (final effect in [before, after]) {
        expect(effect.band.p05, lessThanOrEqualTo(effect.band.p50));
        expect(effect.band.p50, lessThanOrEqualTo(effect.band.p95));
        expect(effect.band.p95, lessThanOrEqualTo(1.0));
      }
      expect(provider.mealTimingEffect(shake, 240), isNull);
      expect(provider.mealTimingEffect(shake, -400), isNull);
      expect(provider.mealTimingEffect(const [], 0), isNull);
    });

    test('Observatory trace carries units, bands and the boundary', () {
      final trace = provider.observatoryTraceJson();
      expect(trace['units'], physiologySeriesUnits);
      final rows = trace['rows'] as List;
      expect(rows.map((row) => row['scenario']), [
        'no meal',
        'meal 60 min before dose',
        'meal with dose',
        'meal 60 min after dose',
      ]);
      expect(
        (rows[2]['bands_p05_p50_p95'] as Map).keys,
        contains('brain_delivery_area_vs_no_meal'),
      );
      expect(
        trace['boundary'],
        contains('not patient estimates, clinical cutoffs'),
      );
    });

    test('meal conversion holds missing inputs instead of guessing', () {
      FoodComponent food({
        MealPhysicalForm form = MealPhysicalForm.solid,
        double? protein = 10,
        double? kcal = 300,
        double? portion = 200,
      }) => FoodComponent(
        id: 'f',
        name: 'food',
        physicalForm: form,
        proteinGrams: protein,
        fatGrams: null,
        fiberGrams: null,
        carbohydrateGrams: null,
        calories: kcal,
        portionGrams: portion,
        sourceDocId: null,
      );
      MealComposition meal(List<FoodComponent> foods) => MealComposition(
        id: 'm',
        totalCalories: null,
        proteinGrams: null,
        fatGrams: null,
        fiberGrams: null,
        carbohydrateGrams: null,
        liquidFraction: null,
        mealPhysicalForm: MealPhysicalForm.mixed,
        portionSizeBand: PortionSizeBand.unknown,
        proteinAmountBand: AmountBand.unknown,
        fatAmountBand: AmountBand.unknown,
        fiberAmountBand: AmountBand.unknown,
        calorieBand: AmountBand.unknown,
        compositionCompleteness: 1,
        missingFields: const [],
        foodComponents: foods,
      );

      final converted = physiologyComponentsFromMeal(
        meal([
          food(),
          food(form: MealPhysicalForm.liquid, protein: 0, kcal: 0),
          food(form: MealPhysicalForm.liquid, protein: 5, kcal: 120),
        ]),
      )!;
      expect(converted.map((c) => c.form), [
        PhysiologyComponentForm.solid,
        PhysiologyComponentForm.water,
        PhysiologyComponentForm.liquid,
      ]);
      expect(converted[1].waterMl, 200);
      expect(physiologyComponentsFromMeal(meal([food(kcal: null)])), isNull);
      expect(physiologyComponentsFromMeal(meal([food(protein: null)])), isNull);
      expect(
        physiologyComponentsFromMeal(
          meal([food(form: MealPhysicalForm.unknown)]),
        ),
        isNull,
      );
    });
  });

  test('the lean brain-delivery area equals the full summary exactly', () {
    const meal = [
      PhysiologyComponent(
        'synthetic',
        PhysiologyComponentForm.solid,
        kcal: 420,
        proteinG: 28,
      ),
      PhysiologyComponent(
        'drink',
        PhysiologyComponentForm.liquid,
        kcal: 90,
        proteinG: 4,
        waterMl: 200,
      ),
    ];
    final values = [
      PhysiologyParameterValues.central(),
      ...samplePhysiologyPopulation(3, 7),
    ];
    for (final v in values) {
      for (final offset in [-300.0, -45.5, 0.0, 30.0, 239.0]) {
        final full = summarizePhysiologyTiming(
          v,
          meal,
          offset,
          horizonMin: physiologyComparisonWindowEndMin,
        );
        expect(
          physiologyBrainDeliveryArea(
            v,
            meal,
            offset,
            horizonMin: physiologyComparisonWindowEndMin,
          ),
          full.brainDeliveryArea,
          reason: 'offset $offset',
        );
      }
    }
  });
}
