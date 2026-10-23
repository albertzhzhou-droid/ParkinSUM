/// Trace provider for the physiology reference model (Stage B).
///
/// Compares a synthetic immediate-release levodopa dose with and without a
/// meal at a given offset, in physical units, with seeded population bands.
/// It is trace-only: nothing here feeds a score, a rule outcome or a
/// recommendation order. Educational research prototype; the curves are
/// population-typical and not a prediction for any person or advice about
/// timing, dosing or diet.
library;

import 'dart:math' as math;

import '../entities/algorithm_descriptor.dart';
import '../entities/meal_composition.dart';
import '../entities/physiology_reference_parameters.dart';
import '../entities/time_axis_events.dart';
import 'physiology_reference_model.dart';

/// Synthetic dose. Relative areas do not depend on it: plasma levodopa is
/// linear in dose and the brain-entry index does not depend on levodopa.
const double physiologyReferenceDoseMg = 100.0;

/// Areas cover 0–240 min after the dose.
const double physiologyComparisonWindowEndMin = 240.0;

const int physiologyPopulationSeed = 20261020;
const int physiologyPopulationDraws = 100;

/// Offsets (meal start minus dose time, min) shown in the Observatory; null
/// is the no-meal reference.
const List<double?> physiologyObservatoryOffsets = [null, -60.0, 0.0, 60.0];

/// Synthetic ~600 kcal mixed meal with 30 g protein (the reference's
/// what-if meal).
const List<PhysiologyComponent> physiologyObservatoryMeal = [
  PhysiologyComponent(
    'mixed meal',
    PhysiologyComponentForm.solid,
    kcal: 520.0,
    proteinG: 27.0,
  ),
  PhysiologyComponent(
    'drink',
    PhysiologyComponentForm.liquid,
    kcal: 80.0,
    proteinG: 3.0,
    waterMl: 250.0,
  ),
  PhysiologyComponent('water', PhysiologyComponentForm.water, waterMl: 250.0),
];

/// Units of every recorded series.
const Map<String, String> physiologySeriesUnits = {
  't': 'min',
  'stomach_kcal': 'kcal',
  'stomach_retention_solid': 'fraction',
  'energy_out_kcal_per_min': 'kcal/min',
  'water_ml': 'mL',
  'levodopa_mg_per_l': 'mg/L',
  'lnaa6_umol_per_l': 'µmol/L',
  'brain_entry_index': 'ratio',
  'brain_delivery_index': 'mg/L',
  'leu_umol_per_l': 'µmol/L',
  'phe_umol_per_l': 'µmol/L',
};

/// Dose time in the simulation: late enough that a meal up to [offset]
/// minutes earlier still starts at or after zero.
double physiologyDoseTimeFor(double? mealOffsetMin) =>
    mealOffsetMin == null ? 150.0 : math.max(150.0, -mealOffsetMin);

/// The comparison scenario shared with `tool/physiology_reference/agreement.py`.
PhysiologyScenario physiologyTimingScenario(
  List<PhysiologyComponent> meal,
  double? mealOffsetMin, {
  double horizonMin = 360.0,
}) {
  final t0 = physiologyDoseTimeFor(mealOffsetMin);
  return PhysiologyScenario(
    meals: mealOffsetMin == null
        ? const []
        : [PhysiologyMeal(t0 + mealOffsetMin, meal)],
    doses: [PhysiologyDose(t0, physiologyReferenceDoseMg)],
    tEndMin: t0 + horizonMin,
  );
}

/// Summary of one simulated dose, times relative to the dose.
final class PhysiologyTimingSummary {
  final double tmaxMin;
  final double cmaxMgPerL;
  final double brainEntryIndexMin;

  /// Area of plasma levodopa × brain-entry index over the window (mg·min/L).
  final double brainDeliveryArea;

  /// Area of plasma levodopa over the window (mg·min/L).
  final double plasmaArea;
  final double peakEnergyOutKcalPerMin;

  /// Relative to the same parameters with no meal; null for the reference.
  final double? brainDeliveryRelative;
  final double? plasmaRelative;
  final PhysiologySeries series;

  const PhysiologyTimingSummary({
    required this.tmaxMin,
    required this.cmaxMgPerL,
    required this.brainEntryIndexMin,
    required this.brainDeliveryArea,
    required this.plasmaArea,
    required this.peakEnergyOutKcalPerMin,
    required this.brainDeliveryRelative,
    required this.plasmaRelative,
    required this.series,
  });
}

PhysiologyTimingSummary summarizePhysiologyTiming(
  PhysiologyParameterValues values,
  List<PhysiologyComponent> meal,
  double? mealOffsetMin, {
  PhysiologyTimingSummary? reference,
  double horizonMin = 360.0,
}) {
  final scenario = physiologyTimingScenario(
    meal,
    mealOffsetMin,
    horizonMin: horizonMin,
  );
  final series = simulatePhysiology(
    scenario,
    values,
  ).shifted(physiologyDoseTimeFor(mealOffsetMin));
  const window = physiologyComparisonWindowEndMin;
  final (tmax, cmax) = series.peak('levodopa_mg_per_l', 0, 360);
  final (_, bmin) = series.trough('brain_entry_index', 0, window);
  final (_, energyPeak) = series.peak(
    'energy_out_kcal_per_min',
    double.negativeInfinity,
  );
  final delivery = series.area('brain_delivery_index', 0, window);
  final plasma = series.area('levodopa_mg_per_l', 0, window);
  return PhysiologyTimingSummary(
    tmaxMin: tmax,
    cmaxMgPerL: cmax,
    brainEntryIndexMin: bmin,
    brainDeliveryArea: delivery,
    plasmaArea: plasma,
    peakEnergyOutKcalPerMin: energyPeak,
    brainDeliveryRelative: reference == null
        ? null
        : delivery / reference.brainDeliveryArea,
    plasmaRelative: reference == null ? null : plasma / reference.plasmaArea,
    series: series,
  );
}

/// 5th, 50th and 95th percentile of the seeded draws.
final class PhysiologyBand {
  final double p05;
  final double p50;
  final double p95;
  const PhysiologyBand(this.p05, this.p50, this.p95);

  factory PhysiologyBand.of(List<double> xs) => PhysiologyBand(
    physiologyPercentile(xs, 0.05),
    physiologyPercentile(xs, 0.5),
    physiologyPercentile(xs, 0.95),
  );

  List<double> toList() => [p05, p50, p95];
}

/// One meal timing compared with no meal: central curves plus bands.
final class PhysiologyTimingRow {
  final double? mealOffsetMin;
  final PhysiologyTimingSummary central;
  final Map<String, PhysiologyBand> bands;

  const PhysiologyTimingRow({
    required this.mealOffsetMin,
    required this.central,
    required this.bands,
  });

  String get label {
    final offset = mealOffsetMin;
    if (offset == null) return 'no meal';
    if (offset == 0) return 'meal with dose';
    final minutes = offset.abs().round();
    return 'meal $minutes min ${offset < 0 ? 'before' : 'after'} dose';
  }
}

/// Modeled brain delivery of a meal timing relative to no meal.
final class PhysiologyMealTimingEffect {
  final double mealOffsetMin;

  /// Central-parameter ratio and the population band (fractions, 1 = same as
  /// no meal) of the 0–4 h brain-delivery area.
  final double central;
  final PhysiologyBand band;
  final int draws;
  final int seed;

  const PhysiologyMealTimingEffect({
    required this.mealOffsetMin,
    required this.central,
    required this.band,
    required this.draws,
    required this.seed,
  });

  Map<String, Object?> toJson() => {
    'schema': PhysiologyReferenceTraceProvider.fixtureSchema,
    'parameter_set_version':
        PhysiologyReferenceParameterSet.parameterSetVersion,
    'meal_offset_min': mealOffsetMin,
    'window_min': [0, physiologyComparisonWindowEndMin],
    'brain_delivery_area_vs_no_meal': {
      'unit': 'ratio',
      'central': central,
      'p05': band.p05,
      'p50': band.p50,
      'p95': band.p95,
    },
    'draws': draws,
    'seed': seed,
    'boundary': PhysiologyReferenceParameterSet.boundary,
  };
}

/// Reference-model components for a normalized meal, or null when an input
/// the model needs (energy, protein or physical form) is missing. Amino-acid
/// profiles are not used: every component takes the reference's mixed-protein
/// composition, as the reference model does by default.
List<PhysiologyComponent>? physiologyComponentsFromMeal(
  MealComposition composition,
) {
  final components = <PhysiologyComponent>[];
  for (final food in composition.foodComponents) {
    final protein = food.proteinGrams;
    final kcal =
        food.calories ??
        (food.proteinGrams != null &&
                food.carbohydrateGrams != null &&
                food.fatGrams != null
            ? 4 * food.proteinGrams! +
                  4 * food.carbohydrateGrams! +
                  9 * food.fatGrams!
            : null);
    if (protein == null || kcal == null) return null;
    final form = switch (food.physicalForm) {
      MealPhysicalForm.solid ||
      MealPhysicalForm.mixed => PhysiologyComponentForm.solid,
      MealPhysicalForm.liquid =>
        kcal > 0
            ? PhysiologyComponentForm.liquid
            : PhysiologyComponentForm.water,
      MealPhysicalForm.unknown => null,
    };
    if (form == null) return null;
    final waterMl = form == PhysiologyComponentForm.solid
        ? 0.0
        : (food.portionGrams ?? 0.0);
    components.add(
      PhysiologyComponent(
        food.name,
        form,
        kcal: kcal,
        proteinG: protein,
        waterMl: waterMl,
      ),
    );
  }
  return components.isEmpty ? null : components;
}

/// Lazily builds and memoizes reference traces. Deterministic for a given
/// seed and number of draws.
final class PhysiologyReferenceTraceProvider {
  static const String fixtureSchema = 'parkinsum.physiology-reference-trace/1';

  static const AlgorithmTraceProviderContract
  traceProviderContract = AlgorithmTraceProviderContract(
    providerId: AlgorithmTraceProviderIds.physiologyReferenceTimingComparison,
    algorithmIds: ['physiology_reference_model'],
    fixtureSchema: fixtureSchema,
    fixtureRevision: 'synthetic-physiology-reference-v1',
    lifecycle:
        'lazy_memoized_trace_on_first_panel_build;dispose_immutable_value_not_applicable',
    routeId: 'app-tools.observatory',
    routeSourcePath: 'lib/features/main_shell/app_destinations.dart',
    providerSourcePath:
        'lib/domain/usecases/physiology_reference_trace_provider.dart',
    uiSurfaceKeysByAlgorithm: {
      'physiology_reference_model': 'chart-panel-physiology-reference',
    },
    executableTestPaths: [
      'test/physiology_reference_model_test.dart',
      'test/physiology_reference_agreement_test.dart',
      'test/physiology_reference_panel_test.dart',
      'test/algorithm_observatory_page_test.dart',
    ],
  );

  static final PhysiologyReferenceTraceProvider shared =
      PhysiologyReferenceTraceProvider();

  final int draws;
  final int seed;

  PhysiologyReferenceTraceProvider({
    this.draws = physiologyPopulationDraws,
    this.seed = physiologyPopulationSeed,
  });

  late final PhysiologyParameterValues _central =
      PhysiologyParameterValues.central();
  late final List<PhysiologyParameterValues> _population =
      samplePhysiologyPopulation(draws, seed);
  late final PhysiologyTimingSummary _centralReference =
      summarizePhysiologyTiming(_central, const [], null);
  late final List<PhysiologyTimingSummary> _populationReference = [
    for (final v in _population) summarizePhysiologyTiming(v, const [], null),
  ];
  List<PhysiologyTimingRow>? _observatoryRows;

  /// The Observatory comparison: the synthetic meal at each of
  /// [physiologyObservatoryOffsets], memoized.
  List<PhysiologyTimingRow> get observatoryRows => _observatoryRows ??= [
    for (final offset in physiologyObservatoryOffsets)
      compare(physiologyObservatoryMeal, offset),
  ];

  PhysiologyTimingRow compare(
    List<PhysiologyComponent> meal,
    double? mealOffsetMin,
  ) {
    final central = mealOffsetMin == null
        ? _centralReference
        : summarizePhysiologyTiming(
            _central,
            meal,
            mealOffsetMin,
            reference: _centralReference,
          );
    final perDraw = [
      for (var i = 0; i < _population.length; i++)
        mealOffsetMin == null
            ? _populationReference[i]
            : summarizePhysiologyTiming(
                _population[i],
                meal,
                mealOffsetMin,
                reference: _populationReference[i],
              ),
    ];
    PhysiologyBand band(double Function(PhysiologyTimingSummary) pick) =>
        PhysiologyBand.of([for (final s in perDraw) pick(s)]);
    return PhysiologyTimingRow(
      mealOffsetMin: mealOffsetMin,
      central: central,
      bands: {
        'tmax_min': band((s) => s.tmaxMin),
        'cmax_mg_per_l': band((s) => s.cmaxMgPerL),
        'brain_entry_index_min_0_4h': band((s) => s.brainEntryIndexMin),
        if (mealOffsetMin != null) ...{
          'plasma_area_vs_no_meal': band((s) => s.plasmaRelative!),
          'brain_delivery_area_vs_no_meal': band(
            (s) => s.brainDeliveryRelative!,
          ),
        },
      },
    );
  }

  /// Brain delivery of [meal] at [mealOffsetMin] relative to no meal, or null
  /// outside the modeled range (meal more than 6 h before or 4 h after the
  /// dose, where the comparison window no longer sees it).
  PhysiologyMealTimingEffect? mealTimingEffect(
    List<PhysiologyComponent> meal,
    double mealOffsetMin,
  ) {
    if (mealOffsetMin < -360 ||
        mealOffsetMin >= physiologyComparisonWindowEndMin ||
        meal.isEmpty) {
      return null;
    }
    double ratio(PhysiologyParameterValues v, PhysiologyTimingSummary ref) =>
        summarizePhysiologyTiming(
          v,
          meal,
          mealOffsetMin,
          reference: ref,
          horizonMin: physiologyComparisonWindowEndMin,
        ).brainDeliveryRelative!;
    return PhysiologyMealTimingEffect(
      mealOffsetMin: mealOffsetMin,
      central: ratio(_central, _centralReference),
      band: PhysiologyBand.of([
        for (var i = 0; i < _population.length; i++)
          ratio(_population[i], _populationReference[i]),
      ]),
      draws: draws,
      seed: seed,
    );
  }

  /// Unit-bearing trace of the Observatory comparison.
  Map<String, Object?> observatoryTraceJson() => {
    'schema': fixtureSchema,
    'parameter_set_id': PhysiologyReferenceParameterSet.parameterSetId,
    'parameter_set_version':
        PhysiologyReferenceParameterSet.parameterSetVersion,
    'dose': {'levodopa_mg': physiologyReferenceDoseMg, 'release': 'ir'},
    'window_min': [0, physiologyComparisonWindowEndMin],
    'draws': draws,
    'seed': seed,
    'units': physiologySeriesUnits,
    'rows': [
      for (final row in observatoryRows)
        {
          'scenario': row.label,
          'meal_offset_min': row.mealOffsetMin,
          'central': {
            'tmax_min': row.central.tmaxMin,
            'cmax_mg_per_l': row.central.cmaxMgPerL,
            'brain_entry_index_min_0_4h': row.central.brainEntryIndexMin,
            'peak_energy_out_kcal_per_min': row.central.peakEnergyOutKcalPerMin,
            if (row.mealOffsetMin != null) ...{
              'plasma_area_vs_no_meal': row.central.plasmaRelative,
              'brain_delivery_area_vs_no_meal':
                  row.central.brainDeliveryRelative,
            },
          },
          'bands_p05_p50_p95': {
            for (final entry in row.bands.entries)
              entry.key: entry.value.toList(),
          },
        },
    ],
    'boundary': PhysiologyReferenceParameterSet.boundary,
  };
}
