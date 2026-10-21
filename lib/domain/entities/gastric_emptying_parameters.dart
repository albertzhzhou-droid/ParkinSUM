/// Centralized gastric-emptying parameter set with provenance metadata.
///
/// Each parameter carries `sourceRefs` (mapped to entries in
/// `model_assumption_registry.dart` and `Bibliographies.md`), a confidence
/// level, and a limitation string. Numeric magnitudes that literature does
/// not anchor are explicitly tagged `prototype_heuristic`; their *direction*
/// is grounded in the cited reviews.
library;

import '../usecases/model_assumption_registry.dart';

/// Stable field identities for the complete reviewed gastric-emptying
/// configuration boundary.
///
/// The two structural records are emitted by the configuration provenance
/// manifest, while the trace-provider record is emitted from the algorithm
/// registry. Together with the fifteen numeric records they form the exact
/// declared field set used by the completeness witness.
abstract final class GastricEmptyingParameterIds {
  static const String solidLagMinutes = 'ge.solid.lag_minutes';
  static const String solidHalfMinutes = 'ge.solid.half_minutes';
  static const String liquidLagMinutes = 'ge.liquid.lag_minutes';
  static const String liquidHalfMinutes = 'ge.liquid.half_minutes';
  static const String liquidNutrientKcalPerMinute =
      'ge.liquid.nutrient_kcal_per_min';
  static const String referenceMealCalories = 'ge.size.reference_kcal';
  static const String fatSlowdownMultiplier = 'ge.fat.slowdown_multiplier';
  static const String fatFractionThreshold = 'ge.fat.fraction_threshold';
  static const String fiberSlowdownMultiplier = 'ge.fiber.slowdown_multiplier';
  static const String mixedMealUncertaintyBoost =
      'ge.mixed_meal.uncertainty_boost';
  static const String overlapUncertaintyBoost = 'ge.overlap.uncertainty_boost';
  static const String fatUncertaintyBoost = 'ge.fat.uncertainty_boost';
  static const String highCalorieUncertaintyBoost =
      'ge.highcal.uncertainty_boost';
  static const String highCalorieFractionThreshold =
      'ge.highcal.fraction_threshold';
  static const String timeScaleSensitivityFraction =
      'ge.population.time_scale_sensitivity_fraction';
  static const String generatorStructure = 'gastric.structure.generator';
  static const String outputIntegrityContract =
      'gastric.structure.output_integrity';
  static const String traceProvider = 'trace_provider.gastric_emptying';

  static const Set<String> numeric = <String>{
    solidLagMinutes,
    solidHalfMinutes,
    liquidLagMinutes,
    liquidHalfMinutes,
    liquidNutrientKcalPerMinute,
    referenceMealCalories,
    fatSlowdownMultiplier,
    fatFractionThreshold,
    fiberSlowdownMultiplier,
    mixedMealUncertaintyBoost,
    overlapUncertaintyBoost,
    fatUncertaintyBoost,
    highCalorieUncertaintyBoost,
    highCalorieFractionThreshold,
    timeScaleSensitivityFraction,
  };

  static const Set<String> completeCoverage = <String>{
    ...numeric,
    generatorStructure,
    outputIntegrityContract,
    traceProvider,
  };
}

final class GastricEmptyingParameter<T extends num> {
  final String id;
  final String label;
  final T value;
  final List<String> sourceRefs;
  final ModelEvidenceLevel confidence;
  final String limitation;

  /// Literature range the central [value] is checked against and reported
  /// with. It documents how far the selected value could plausibly move; it
  /// is not a confidence interval and does not change the central curve.
  final ({double low, double high})? sensitivityRange;

  GastricEmptyingParameter({
    required this.id,
    required this.label,
    required this.value,
    required List<String> sourceRefs,
    required this.confidence,
    required this.limitation,
    this.sensitivityRange,
  }) : sourceRefs = List<String>.unmodifiable(sourceRefs);

  bool get isPrototypeHeuristic =>
      confidence == ModelEvidenceLevel.prototypeHeuristic;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'value': value,
    'source_refs': sourceRefs,
    'confidence': confidence.name,
    'limitation': limitation,
    if (sensitivityRange case final range?)
      'sensitivity_range': {'low': range.low, 'high': range.high},
  };
}

final class GastricEmptyingParameterSet {
  static const String schema = 'parkinsum.gastric-parameter-set/1';
  static const String reviewedDefaultId =
      'gastric_emptying_population_sensitivity';
  static const String reviewedDefaultVersion = '2026.10.20-v4';

  final String id;
  final String version;
  final String lastReviewed;
  final GastricEmptyingParameter<double> solidLagMinutes;
  final GastricEmptyingParameter<double> solidHalfMinutes;
  final GastricEmptyingParameter<double> liquidLagMinutes;
  final GastricEmptyingParameter<double> liquidHalfMinutes;
  final GastricEmptyingParameter<double> liquidNutrientKcalPerMinute;
  final GastricEmptyingParameter<double> referenceMealCalories;
  final GastricEmptyingParameter<double> fatSlowdownMultiplier;
  final GastricEmptyingParameter<double> fatFractionThreshold;
  final GastricEmptyingParameter<double> fiberSlowdownMultiplier;
  final GastricEmptyingParameter<int> mixedMealUncertaintyBoost;
  final GastricEmptyingParameter<int> overlapUncertaintyBoost;
  final GastricEmptyingParameter<int> fatUncertaintyBoost;
  final GastricEmptyingParameter<int> highCalorieUncertaintyBoost;
  final GastricEmptyingParameter<double> highCalorieFractionThreshold;
  final GastricEmptyingParameter<double> timeScaleSensitivityFraction;

  const GastricEmptyingParameterSet({
    required this.id,
    required this.version,
    required this.lastReviewed,
    required this.solidLagMinutes,
    required this.solidHalfMinutes,
    required this.liquidLagMinutes,
    required this.liquidHalfMinutes,
    required this.liquidNutrientKcalPerMinute,
    required this.referenceMealCalories,
    required this.fatSlowdownMultiplier,
    required this.fatFractionThreshold,
    required this.fiberSlowdownMultiplier,
    required this.mixedMealUncertaintyBoost,
    required this.overlapUncertaintyBoost,
    required this.fatUncertaintyBoost,
    required this.highCalorieUncertaintyBoost,
    required this.highCalorieFractionThreshold,
    required this.timeScaleSensitivityFraction,
  });

  /// Default literature-informed parameter set. Magnitudes follow the
  /// ranges in the cited gastric-emptying reviews; exact values are
  /// labeled `prototype_heuristic` because the literature reports ranges
  /// with substantial inter-subject variance, not single fitted constants.
  factory GastricEmptyingParameterSet.literatureInformedDefault() {
    return GastricEmptyingParameterSet(
      id: reviewedDefaultId,
      version: reviewedDefaultVersion,
      lastReviewed: '2026-10-20',
      solidLagMinutes: GastricEmptyingParameter<double>(
        id: GastricEmptyingParameterIds.solidLagMinutes,
        label: 'Solid meal lag (minutes before linear emptying begins)',
        value: 20.0,
        sourceRefs: [
          'src.zinsmeister.ge.halftime.2012',
          'src.abell.ges.consensus.2008',
          'src.hardoff.ge.pd.2001',
          'src.hens.foodphysical.2024',
          'src.internal.prototype.heuristic',
        ],
        confidence: ModelEvidenceLevel.prototypeHeuristic,
        limitation:
            'Reviews report a 10–30 min lag with substantial inter-subject '
            'variance; chosen value is a midrange illustrative anchor.',
      ),
      solidHalfMinutes: GastricEmptyingParameter<double>(
        id: GastricEmptyingParameterIds.solidHalfMinutes,
        label: 'Solid meal half-emptying time (minutes)',
        value: 90.0,
        sourceRefs: [
          'src.zinsmeister.ge.halftime.2012',
          'src.abell.ges.consensus.2008',
          'src.hardoff.ge.pd.2001',
          'src.hens.foodphysical.2024',
          'src.internal.prototype.heuristic',
        ],
        confidence: ModelEvidenceLevel.prototypeHeuristic,
        limitation:
            'Literature and consensus sources establish measurement methods '
            'and broad population ranges; 90 minutes is an illustrative anchor.',
      ),
      liquidLagMinutes: GastricEmptyingParameter<double>(
        id: GastricEmptyingParameterIds.liquidLagMinutes,
        label: 'Liquid meal lag (minutes)',
        value: 0.0,
        sourceRefs: [
          'src.hens.foodphysical.2024',
          'src.internal.prototype.heuristic',
        ],
        confidence: ModelEvidenceLevel.prototypeHeuristic,
        limitation:
            'The faster liquid-emptying direction is literature-informed; '
            'zero minutes is an illustrative selected value.',
      ),
      liquidHalfMinutes: GastricEmptyingParameter<double>(
        id: GastricEmptyingParameterIds.liquidHalfMinutes,
        label: 'Liquid meal half-emptying time (minutes)',
        value: 15.0,
        sourceRefs: [
          'src.hens.foodphysical.2024',
          'src.internal.prototype.heuristic',
        ],
        confidence: ModelEvidenceLevel.prototypeHeuristic,
        limitation:
            'Liquids empty faster than solids; chosen value is a midrange '
            'illustrative anchor in the 10–20 min direction. It sets the '
            'whole curve of an energy-free liquid and only the volume-driven '
            'bound of an energy-containing one.',
      ),
      liquidNutrientKcalPerMinute: GastricEmptyingParameter<double>(
        id: GastricEmptyingParameterIds.liquidNutrientKcalPerMinute,
        label:
            'Energy delivery rate of an energy-containing liquid (kcal per '
            'minute)',
        value: 2.13,
        sourceRefs: [
          'src.brener.glucose_emptying.1983',
          'src.hunt_stubbs.energy_density.1975',
          'src.marathe.ge_kcal_range.2013',
        ],
        confidence: ModelEvidenceLevel.mechanism,
        limitation:
            'Brener et al. measured 2.13 kcal/min for glucose solutions of '
            'three concentrations in adults, while saline emptied '
            'exponentially; the rate is applied to every energy-containing '
            'liquid. The studies pooled by Hunt and Stubbs fit equal slowing '
            'by isocaloric fat, protein and carbohydrate, but delivered '
            'energy still rose with energy density, so the rate is not '
            'strictly constant. Reported healthy rates span 1–4 kcal/min '
            '(the sensitivity range). Viscosity, osmolality, specific '
            'macronutrients and Parkinson disease are not modeled.',
        sensitivityRange: (low: 1.0, high: 4.0),
      ),
      referenceMealCalories: GastricEmptyingParameter<double>(
        id: GastricEmptyingParameterIds.referenceMealCalories,
        label: 'Reference meal calories used for the size multiplier',
        value: 400.0,
        sourceRefs: ['src.internal.prototype.heuristic'],
        confidence: ModelEvidenceLevel.prototypeHeuristic,
        limitation:
            'Reference is illustrative; meal-size effect is non-linear in '
            'reality but treated as monotonic here.',
      ),
      fatSlowdownMultiplier: GastricEmptyingParameter<double>(
        id: GastricEmptyingParameterIds.fatSlowdownMultiplier,
        label:
            'Multiplier applied to half-emptying when fat ≥ threshold fraction',
        value: 1.5,
        sourceRefs: [
          'src.hens.foodphysical.2024',
          'src.dailymed.sinemet.label',
          'src.internal.prototype.heuristic',
        ],
        confidence: ModelEvidenceLevel.prototypeHeuristic,
        limitation:
            'Direction (high fat slows gastric emptying) is well-supported; '
            'exact multiplier is illustrative.',
      ),
      fatFractionThreshold: GastricEmptyingParameter<double>(
        id: GastricEmptyingParameterIds.fatFractionThreshold,
        label:
            'Fraction of total kcal from fat above which the multiplier applies',
        value: 0.3,
        sourceRefs: ['src.internal.prototype.heuristic'],
        confidence: ModelEvidenceLevel.prototypeHeuristic,
        limitation: 'Threshold is illustrative.',
      ),
      fiberSlowdownMultiplier: GastricEmptyingParameter<double>(
        id: GastricEmptyingParameterIds.fiberSlowdownMultiplier,
        label: 'Multiplier applied to half-emptying for high-fiber meals',
        value: 1.1,
        sourceRefs: [
          'src.hens.foodphysical.2024',
          'src.internal.prototype.heuristic',
        ],
        confidence: ModelEvidenceLevel.prototypeHeuristic,
        limitation:
            'High fiber widens uncertainty more than it slows emptying; '
            'multiplier is small and illustrative.',
      ),
      mixedMealUncertaintyBoost: GastricEmptyingParameter<int>(
        id: GastricEmptyingParameterIds.mixedMealUncertaintyBoost,
        label:
            'Integer increment added to the uncertainty score when fiber is high',
        value: 1,
        sourceRefs: ['src.internal.prototype.heuristic'],
        confidence: ModelEvidenceLevel.prototypeHeuristic,
        limitation: 'Integer step is illustrative.',
      ),
      overlapUncertaintyBoost: GastricEmptyingParameter<int>(
        id: GastricEmptyingParameterIds.overlapUncertaintyBoost,
        label:
            'Integer increment added to the uncertainty score for overlapping meals',
        value: 1,
        sourceRefs: ['src.internal.prototype.heuristic'],
        confidence: ModelEvidenceLevel.prototypeHeuristic,
        limitation:
            'Cumulative stomach load adds a deterministic integer step to '
            'uncertainty; magnitude is illustrative.',
      ),
      fatUncertaintyBoost: GastricEmptyingParameter<int>(
        id: GastricEmptyingParameterIds.fatUncertaintyBoost,
        label:
            'Integer increment added to the uncertainty score when fat ≥ threshold',
        value: 1,
        sourceRefs: [
          'src.hens.foodphysical.2024',
          'src.internal.prototype.heuristic',
        ],
        confidence: ModelEvidenceLevel.prototypeHeuristic,
        limitation:
            'High-fat meals slow and disperse emptying with wide inter-subject '
            'variance; the model widens uncertainty by a deterministic integer '
            'step. Magnitude is illustrative.',
      ),
      highCalorieUncertaintyBoost: GastricEmptyingParameter<int>(
        id: GastricEmptyingParameterIds.highCalorieUncertaintyBoost,
        label:
            'Integer increment added to the uncertainty score for high-calorie meals',
        value: 1,
        sourceRefs: [
          'src.hens.foodphysical.2024',
          'src.internal.prototype.heuristic',
        ],
        confidence: ModelEvidenceLevel.prototypeHeuristic,
        limitation:
            'Large caloric loads slow emptying non-linearly with substantial '
            'variance; the model widens uncertainty by a deterministic integer '
            'step. Magnitude is illustrative.',
      ),
      highCalorieFractionThreshold: GastricEmptyingParameter<double>(
        id: GastricEmptyingParameterIds.highCalorieFractionThreshold,
        label:
            'Multiple of the reference meal calories above which a meal is "high calorie"',
        value: 1.5,
        sourceRefs: ['src.internal.prototype.heuristic'],
        confidence: ModelEvidenceLevel.prototypeHeuristic,
        limitation: 'Threshold (×reference kcal) is illustrative.',
      ),
      timeScaleSensitivityFraction: GastricEmptyingParameter<double>(
        id: GastricEmptyingParameterIds.timeScaleSensitivityFraction,
        label: 'One-way time-scale sensitivity fraction',
        value: 0.24,
        sourceRefs: [
          'src.camilleri.ge.variation.2012',
          'src.hardoff.ge.pd.2001',
          'src.siebner.ge.earlypd.2022',
          'src.internal.prototype.heuristic',
        ],
        confidence: ModelEvidenceLevel.prototypeHeuristic,
        limitation:
            'Healthy-participant scintigraphy reported 24.5% between-person '
            'variation in measured half-time. Applying ±24% symmetrically is '
            'an illustrative one-way transform, not a confidence interval.',
      ),
    );
  }

  List<GastricEmptyingParameter<num>> get all =>
      List<GastricEmptyingParameter<num>>.unmodifiable([
        solidLagMinutes,
        solidHalfMinutes,
        liquidLagMinutes,
        liquidHalfMinutes,
        liquidNutrientKcalPerMinute,
        referenceMealCalories,
        fatSlowdownMultiplier,
        fatFractionThreshold,
        fiberSlowdownMultiplier,
        mixedMealUncertaintyBoost,
        overlapUncertaintyBoost,
        fatUncertaintyBoost,
        highCalorieUncertaintyBoost,
        highCalorieFractionThreshold,
        timeScaleSensitivityFraction,
      ]);

  /// Complete execution-domain validation. The immutable value object can be
  /// constructed by an independent mutation verifier, but
  /// `GastricEmptyingModel` refuses every invalid set before evaluating a
  /// curve.
  List<String> get validationErrors {
    final errors = <String>[];
    if (id.trim().isEmpty) errors.add('parameter_set_id_empty');
    if (version.trim().isEmpty) errors.add('parameter_set_version_empty');
    if (lastReviewed.trim().isEmpty) errors.add('last_reviewed_empty');
    final semanticIds = <String>{};
    for (final parameter in all) {
      if (parameter.id.trim().isEmpty || !semanticIds.add(parameter.id)) {
        errors.add('parameter_id_empty_or_duplicate:${parameter.id}');
      }
      if (!parameter.value.toDouble().isFinite) {
        errors.add('parameter_nonfinite:${parameter.id}');
      }
      if (parameter.label.trim().isEmpty) {
        errors.add('parameter_label_empty:${parameter.id}');
      }
      if (parameter.limitation.trim().isEmpty) {
        errors.add('parameter_limitation_empty:${parameter.id}');
      }
      if (parameter.sourceRefs.isEmpty ||
          parameter.sourceRefs.any((source) => source.trim().isEmpty) ||
          parameter.sourceRefs.toSet().length != parameter.sourceRefs.length) {
        errors.add('parameter_source_refs_invalid:${parameter.id}');
      }
      final range = parameter.sensitivityRange;
      if (range != null) {
        final value = parameter.value.toDouble();
        if (!range.low.isFinite ||
            !range.high.isFinite ||
            range.low <= 0 ||
            range.low > value ||
            value > range.high) {
          errors.add('parameter_sensitivity_range_invalid:${parameter.id}');
        }
      }
    }
    if (semanticIds.length != GastricEmptyingParameterIds.numeric.length ||
        !semanticIds.containsAll(GastricEmptyingParameterIds.numeric)) {
      errors.add('parameter_id_set_incomplete_or_unsupported');
    }

    void bounded(
      GastricEmptyingParameter<num> parameter,
      double minimum,
      double maximum, {
      bool includeMinimum = true,
      bool includeMaximum = true,
    }) {
      final value = parameter.value.toDouble();
      if (!value.isFinite) return;
      final below = includeMinimum ? value < minimum : value <= minimum;
      final above = includeMaximum ? value > maximum : value >= maximum;
      if (below || above) {
        errors.add('parameter_out_of_range:${parameter.id}');
      }
    }

    bounded(solidLagMinutes, 0, 1440);
    bounded(liquidLagMinutes, 0, 1440);
    bounded(solidHalfMinutes, 0.001, 2880);
    bounded(liquidHalfMinutes, 0.001, 2880);
    bounded(liquidNutrientKcalPerMinute, 0.1, 20);
    bounded(referenceMealCalories, 0.001, 10000);
    bounded(fatSlowdownMultiplier, 1, 10);
    bounded(fiberSlowdownMultiplier, 1, 10);
    bounded(fatFractionThreshold, 0, 1);
    bounded(mixedMealUncertaintyBoost, 0, 4);
    bounded(overlapUncertaintyBoost, 0, 4);
    bounded(fatUncertaintyBoost, 0, 4);
    bounded(highCalorieUncertaintyBoost, 0, 4);
    bounded(highCalorieFractionThreshold, 0, 10, includeMinimum: false);
    bounded(timeScaleSensitivityFraction, 0, 1, includeMaximum: false);
    return List.unmodifiable(errors);
  }

  bool get isValidForExecution => validationErrors.isEmpty;

  /// Union of every parameter's `sourceRefs`. Used by
  /// `GastricEmptyingProfile.sourceRefs` so reviewers can trace back any
  /// modeled value.
  List<String> get unionSourceRefs {
    final set = <String>{};
    for (final p in all) {
      set.addAll(p.sourceRefs);
    }
    return List<String>.unmodifiable(set);
  }

  Map<String, dynamic> toJson() => {
    r'$schema': schema,
    'parameter_set_id': id,
    'parameter_set_version': version,
    'last_reviewed': lastReviewed,
    'solid_lag_minutes': solidLagMinutes.toJson(),
    'solid_half_minutes': solidHalfMinutes.toJson(),
    'liquid_lag_minutes': liquidLagMinutes.toJson(),
    'liquid_half_minutes': liquidHalfMinutes.toJson(),
    'liquid_nutrient_kcal_per_min': liquidNutrientKcalPerMinute.toJson(),
    'reference_meal_calories': referenceMealCalories.toJson(),
    'fat_slowdown_multiplier': fatSlowdownMultiplier.toJson(),
    'fat_fraction_threshold': fatFractionThreshold.toJson(),
    'fiber_slowdown_multiplier': fiberSlowdownMultiplier.toJson(),
    'mixed_meal_uncertainty_boost': mixedMealUncertaintyBoost.toJson(),
    'overlap_uncertainty_boost': overlapUncertaintyBoost.toJson(),
    'fat_uncertainty_boost': fatUncertaintyBoost.toJson(),
    'high_calorie_uncertainty_boost': highCalorieUncertaintyBoost.toJson(),
    'high_calorie_fraction_threshold': highCalorieFractionThreshold.toJson(),
    'time_scale_sensitivity_fraction': timeScaleSensitivityFraction.toJson(),
  };
}
