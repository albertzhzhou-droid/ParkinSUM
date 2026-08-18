/// Centralized gastric-emptying parameter set with provenance metadata.
///
/// Each parameter carries `sourceRefs` (mapped to entries in
/// `model_assumption_registry.dart` and `Bibliographies.md`), a confidence
/// level, and a limitation string. Numeric magnitudes that literature does
/// not anchor are explicitly tagged `prototype_heuristic`; their *direction*
/// is grounded in the cited reviews.
library;

import '../usecases/model_assumption_registry.dart';

final class GastricEmptyingParameter<T extends num> {
  final String id;
  final String label;
  final T value;
  final List<String> sourceRefs;
  final ModelEvidenceLevel confidence;
  final String limitation;

  GastricEmptyingParameter({
    required this.id,
    required this.label,
    required this.value,
    required List<String> sourceRefs,
    required this.confidence,
    required this.limitation,
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
  };
}

final class GastricEmptyingParameterSet {
  final String id;
  final String version;
  final String lastReviewed;
  final GastricEmptyingParameter<double> solidLagMinutes;
  final GastricEmptyingParameter<double> solidHalfMinutes;
  final GastricEmptyingParameter<double> liquidLagMinutes;
  final GastricEmptyingParameter<double> liquidHalfMinutes;
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
      id: 'gastric_emptying_population_sensitivity',
      version: '2026.08.17-v2',
      lastReviewed: '2026-08-17',
      solidLagMinutes: GastricEmptyingParameter<double>(
        id: 'ge.solid.lag_minutes',
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
        id: 'ge.solid.half_minutes',
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
        id: 'ge.liquid.lag_minutes',
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
        id: 'ge.liquid.half_minutes',
        label: 'Liquid meal half-emptying time (minutes)',
        value: 15.0,
        sourceRefs: [
          'src.hens.foodphysical.2024',
          'src.internal.prototype.heuristic',
        ],
        confidence: ModelEvidenceLevel.prototypeHeuristic,
        limitation:
            'Liquids empty faster than solids; chosen value is a midrange '
            'illustrative anchor in the 10–20 min direction.',
      ),
      referenceMealCalories: GastricEmptyingParameter<double>(
        id: 'ge.size.reference_kcal',
        label: 'Reference meal calories used for the size multiplier',
        value: 400.0,
        sourceRefs: ['src.internal.prototype.heuristic'],
        confidence: ModelEvidenceLevel.prototypeHeuristic,
        limitation:
            'Reference is illustrative; meal-size effect is non-linear in '
            'reality but treated as monotonic here.',
      ),
      fatSlowdownMultiplier: GastricEmptyingParameter<double>(
        id: 'ge.fat.slowdown_multiplier',
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
        id: 'ge.fat.fraction_threshold',
        label:
            'Fraction of total kcal from fat above which the multiplier applies',
        value: 0.3,
        sourceRefs: ['src.internal.prototype.heuristic'],
        confidence: ModelEvidenceLevel.prototypeHeuristic,
        limitation: 'Threshold is illustrative.',
      ),
      fiberSlowdownMultiplier: GastricEmptyingParameter<double>(
        id: 'ge.fiber.slowdown_multiplier',
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
        id: 'ge.mixed_meal.uncertainty_boost',
        label:
            'Integer increment added to the uncertainty score when fiber is high',
        value: 1,
        sourceRefs: ['src.internal.prototype.heuristic'],
        confidence: ModelEvidenceLevel.prototypeHeuristic,
        limitation: 'Integer step is illustrative.',
      ),
      overlapUncertaintyBoost: GastricEmptyingParameter<int>(
        id: 'ge.overlap.uncertainty_boost',
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
        id: 'ge.fat.uncertainty_boost',
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
        id: 'ge.highcal.uncertainty_boost',
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
        id: 'ge.highcal.fraction_threshold',
        label:
            'Multiple of the reference meal calories above which a meal is "high calorie"',
        value: 1.5,
        sourceRefs: ['src.internal.prototype.heuristic'],
        confidence: ModelEvidenceLevel.prototypeHeuristic,
        limitation: 'Threshold (×reference kcal) is illustrative.',
      ),
      timeScaleSensitivityFraction: GastricEmptyingParameter<double>(
        id: 'ge.population.time_scale_sensitivity_fraction',
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
          parameter.sourceRefs.any((source) => source.trim().isEmpty)) {
        errors.add('parameter_source_refs_invalid:${parameter.id}');
      }
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
    'parameter_set_id': id,
    'parameter_set_version': version,
    'last_reviewed': lastReviewed,
    'solid_lag_minutes': solidLagMinutes.toJson(),
    'solid_half_minutes': solidHalfMinutes.toJson(),
    'liquid_lag_minutes': liquidLagMinutes.toJson(),
    'liquid_half_minutes': liquidHalfMinutes.toJson(),
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
