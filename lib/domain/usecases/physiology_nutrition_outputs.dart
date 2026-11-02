/// Nutrition-only outputs of the physiology reference model (v3).
///
/// For a serving or a plate: the competing large-neutral-amino-acid load
/// (from composition alone), and the modeled plasma LNAA rise and amino-acid
/// appearance timing after eating it, with seeded population bands. Mirrors
/// `competing_lnaa_load` and `meal_response` in
/// `tool/physiology_reference/model.py`; the agreement fixture checks every
/// number. Nothing here reads a medicine or a dose.
///
/// Educational research prototype: population-typical values for synthetic
/// scenarios, not a prediction for any person and not dietary advice.
library;

import '../entities/physiology_reference_parameters.dart';
import 'physiology_reference_model.dart';

/// Modeled response window after the meal (min).
const double physiologyNutritionHorizonMin = 240.0;

/// Competing LNAAs of one component, in µmol.
final class PhysiologyComponentLnaaLoad {
  final String name;
  final double ingestedUmol;

  /// Ingested × the protein type's true ileal digestibility.
  final double digestibleUmol;
  final PhysiologyProfileBasis profileBasis;

  const PhysiologyComponentLnaaLoad({
    required this.name,
    required this.ingestedUmol,
    required this.digestibleUmol,
    required this.profileBasis,
  });
}

/// The six competing LNAAs (leucine, isoleucine, valine, phenylalanine,
/// tyrosine, tryptophan) in a serving or plate, in µmol.
final class PhysiologyCompetingLnaaLoad {
  final double ingestedUmol;
  final double digestibleUmol;
  final List<PhysiologyComponentLnaaLoad> components;

  const PhysiologyCompetingLnaaLoad({
    required this.ingestedUmol,
    required this.digestibleUmol,
    required this.components,
  });
}

/// Competing-LNAA load from composition alone (no simulation). Water-only
/// components carry none.
PhysiologyCompetingLnaaLoad physiologyCompetingLnaaLoad(
  List<PhysiologyComponent> meal,
  PhysiologyParameterValues v,
) {
  final tid = v.map('aa.true_ileal_digestibility_by_protein_type');
  final rows = <PhysiologyComponentLnaaLoad>[];
  var total = 0.0;
  var digestible = 0.0;
  for (final c in meal) {
    if (c.form == PhysiologyComponentForm.water) continue;
    final grams = c.aminoAcidGrams(v);
    var umol = 0.0;
    for (final a in physiologyLnaaSix) {
      umol += grams[a]! / physiologyAminoAcidMolecularWeights[a]! * 1e6;
    }
    final d = umol * tid[c.proteinType]!;
    total += umol;
    digestible += d;
    rows.add(
      PhysiologyComponentLnaaLoad(
        name: c.name,
        ingestedUmol: umol,
        digestibleUmol: d,
        profileBasis: c.profileBasis,
      ),
    );
  }
  return PhysiologyCompetingLnaaLoad(
    ingestedUmol: total,
    digestibleUmol: digestible,
    components: List.unmodifiable(rows),
  );
}

/// Plasma LNAA rise and amino-acid appearance timing after a meal. Times are
/// minutes after the meal.
final class PhysiologyMealResponse {
  static const List<String> keys = [
    'lnaa6_pre_umol_per_l',
    'lnaa6_peak_rise_umol_per_l',
    'lnaa6_peak_time_min',
    'lnaa6_rise_area_umol_min_per_l',
    'appearance_umol',
    'appearance_half_time_min',
    'appearance_peak_time_min',
  ];

  final double lnaa6PreUmolPerL;
  final double lnaa6PeakRiseUmolPerL;
  final double lnaa6PeakTimeMin;

  /// Area of the LNAA rise above the pre-meal level (µmol·min/L); negative
  /// when carbohydrate lowers plasma LNAA more than the meal's protein adds.
  final double lnaa6RiseAreaUmolMinPerL;

  /// Competing LNAAs reaching plasma within the window (µmol).
  final double appearanceUmol;

  /// Time by which half of [appearanceUmol] has appeared (min).
  final double appearanceHalfTimeMin;
  final double appearancePeakTimeMin;

  const PhysiologyMealResponse({
    required this.lnaa6PreUmolPerL,
    required this.lnaa6PeakRiseUmolPerL,
    required this.lnaa6PeakTimeMin,
    required this.lnaa6RiseAreaUmolMinPerL,
    required this.appearanceUmol,
    required this.appearanceHalfTimeMin,
    required this.appearancePeakTimeMin,
  });

  double operator [](String key) => switch (key) {
    'lnaa6_pre_umol_per_l' => lnaa6PreUmolPerL,
    'lnaa6_peak_rise_umol_per_l' => lnaa6PeakRiseUmolPerL,
    'lnaa6_peak_time_min' => lnaa6PeakTimeMin,
    'lnaa6_rise_area_umol_min_per_l' => lnaa6RiseAreaUmolMinPerL,
    'appearance_umol' => appearanceUmol,
    'appearance_half_time_min' => appearanceHalfTimeMin,
    'appearance_peak_time_min' => appearancePeakTimeMin,
    _ => throw ArgumentError.value(key, 'key'),
  };
}

/// Meal response over [mealTime, mealTime + horizon] of [series]; the series
/// must start at or before the meal.
PhysiologyMealResponse physiologyMealResponse(
  PhysiologySeries series,
  double mealTime, [
  double horizon = physiologyNutritionHorizonMin,
]) {
  final ts = series.t;
  final lnaa = series['lnaa6_umol_per_l'];
  final appear = series['lnaa6_appearance_umol_per_min'];
  final pre = series.at('lnaa6_umol_per_l', mealTime);
  final t1 = mealTime + horizon;
  var bestT = mealTime;
  var best = double.negativeInfinity;
  var peakT = mealTime;
  var peakA = double.negativeInfinity;
  for (var i = 0; i < ts.length; i++) {
    if (mealTime <= ts[i] && ts[i] <= t1) {
      if (lnaa[i] > best) {
        bestT = ts[i];
        best = lnaa[i];
      }
      if (appear[i] > peakA) {
        peakT = ts[i];
        peakA = appear[i];
      }
    }
  }
  var riseArea = 0.0;
  final cum = <double>[0.0];
  for (var i = 1; i < ts.length; i++) {
    final a = ts[i - 1] > mealTime ? ts[i - 1] : mealTime;
    final b = ts[i] < t1 ? ts[i] : t1;
    var step = 0.0;
    if (b > a) {
      riseArea += 0.5 * (lnaa[i - 1] + lnaa[i] - 2.0 * pre) * (b - a);
      step = 0.5 * (appear[i - 1] + appear[i]) * (b - a);
    }
    cum.add(cum.last + step);
  }
  final total = cum.last;
  var halfT = double.nan;
  if (total > 0) {
    for (var i = 0; i < ts.length; i++) {
      if (cum[i] >= total / 2) {
        halfT = ts[i] - mealTime;
        break;
      }
    }
  }
  return PhysiologyMealResponse(
    lnaa6PreUmolPerL: pre,
    lnaa6PeakRiseUmolPerL: best - pre,
    lnaa6PeakTimeMin: bestT - mealTime,
    lnaa6RiseAreaUmolMinPerL: riseArea,
    appearanceUmol: total,
    appearanceHalfTimeMin: halfT,
    appearancePeakTimeMin: peakT - mealTime,
  );
}

/// Load, central response and 5th/50th/95th percentile bands of one meal.
final class PhysiologyNutritionSummary {
  final PhysiologyCompetingLnaaLoad load;
  final PhysiologyMealResponse central;

  /// Keyed like [PhysiologyMealResponse.keys]; each list is p05, p50, p95.
  final Map<String, List<double>> bands;
  final int draws;
  final int seed;

  const PhysiologyNutritionSummary({
    required this.load,
    required this.central,
    required this.bands,
    required this.draws,
    required this.seed,
  });
}

/// Builds nutrition summaries with seeded population bands; the population
/// is sampled once, lazily. Deterministic for a given seed and number of
/// draws.
final class PhysiologyNutritionProvider {
  final int draws;
  final int seed;

  PhysiologyNutritionProvider({this.draws = 100, this.seed = 20261020});

  late final PhysiologyParameterValues _central =
      PhysiologyParameterValues.central();
  late final List<PhysiologyParameterValues> _population =
      samplePhysiologyPopulation(draws, seed);

  /// The meal eaten at time zero, simulated over the response window.
  static PhysiologyMealResponse respond(
    PhysiologyParameterValues v,
    List<PhysiologyComponent> meal,
  ) => physiologyMealResponse(
    simulatePhysiology(
      PhysiologyScenario(
        meals: [PhysiologyMeal(0.0, meal)],
        tEndMin: physiologyNutritionHorizonMin,
      ),
      v,
    ),
    0.0,
  );

  /// Central load and response only: one simulation, for lists of foods.
  (PhysiologyCompetingLnaaLoad, PhysiologyMealResponse) central(
    List<PhysiologyComponent> meal,
  ) => (physiologyCompetingLnaaLoad(meal, _central), respond(_central, meal));

  PhysiologyNutritionSummary summarize(List<PhysiologyComponent> meal) {
    final central = respond(_central, meal);
    final perDraw = [for (final v in _population) respond(v, meal)];
    return PhysiologyNutritionSummary(
      load: physiologyCompetingLnaaLoad(meal, _central),
      central: central,
      bands: {
        for (final key in PhysiologyMealResponse.keys)
          key: [
            for (final q in const [0.05, 0.5, 0.95])
              physiologyPercentile([for (final r in perDraw) r[key]], q),
          ],
      },
      draws: draws,
      seed: seed,
    );
  }

  Map<String, Object?> toJson(PhysiologyNutritionSummary summary) => {
    'parameter_set_version':
        PhysiologyReferenceParameterSet.parameterSetVersion,
    'window_min': [0, physiologyNutritionHorizonMin],
    'competing_lnaa_load_umol': {
      'ingested': summary.load.ingestedUmol,
      'digestible': summary.load.digestibleUmol,
    },
    'central': {
      for (final key in PhysiologyMealResponse.keys) key: summary.central[key],
    },
    'bands_p05_p50_p95': summary.bands,
    'draws': summary.draws,
    'seed': summary.seed,
    'boundary': PhysiologyReferenceParameterSet.boundary,
  };
}
