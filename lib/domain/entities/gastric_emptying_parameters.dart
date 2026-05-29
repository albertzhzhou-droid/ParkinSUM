/// Centralized gastric-emptying parameter set with provenance metadata.
///
/// Each parameter carries `sourceRefs` (mapped to entries in
/// `model_assumption_registry.dart` and `Bibliographies.md`), a confidence
/// level, and a limitation string. Numeric magnitudes that literature does
/// not anchor are explicitly tagged `prototype_heuristic`; their *direction*
/// is grounded in the cited reviews.
library;

import '../usecases/model_assumption_registry.dart';

class GastricEmptyingParameter<T> {
  final String id;
  final String label;
  final T value;
  final List<String> sourceRefs;
  final ModelEvidenceLevel confidence;
  final String limitation;

  const GastricEmptyingParameter({
    required this.id,
    required this.label,
    required this.value,
    required this.sourceRefs,
    required this.confidence,
    required this.limitation,
  });

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

class GastricEmptyingParameterSet {
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

  const GastricEmptyingParameterSet({
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
  });

  /// Default literature-informed parameter set. Magnitudes follow the
  /// ranges in the cited gastric-emptying reviews; exact values are
  /// labeled `prototype_heuristic` because the literature reports ranges
  /// with substantial inter-subject variance, not single fitted constants.
  factory GastricEmptyingParameterSet.literatureInformedDefault() {
    return const GastricEmptyingParameterSet(
      solidLagMinutes: GastricEmptyingParameter<double>(
        id: 'ge.solid.lag_minutes',
        label: 'Solid meal lag (minutes before linear emptying begins)',
        value: 20.0,
        sourceRefs: [
          'src.camilleri.ge.halftime.2009',
          'src.hens.foodphysical.2024',
        ],
        confidence: ModelEvidenceLevel.mechanism,
        limitation:
            'Reviews report a 10–30 min lag with substantial inter-subject '
            'variance; chosen value is a midrange illustrative anchor.',
      ),
      solidHalfMinutes: GastricEmptyingParameter<double>(
        id: 'ge.solid.half_minutes',
        label: 'Solid meal half-emptying time (minutes)',
        value: 90.0,
        sourceRefs: [
          'src.camilleri.ge.halftime.2009',
          'src.hens.foodphysical.2024',
        ],
        confidence: ModelEvidenceLevel.mechanism,
        limitation:
            'Reviews report ~60–120 min with ~24% coefficient of variation; '
            'chosen value is a midrange illustrative anchor.',
      ),
      liquidLagMinutes: GastricEmptyingParameter<double>(
        id: 'ge.liquid.lag_minutes',
        label: 'Liquid meal lag (minutes)',
        value: 0.0,
        sourceRefs: [
          'src.camilleri.ge.halftime.2009',
          'src.hens.foodphysical.2024',
        ],
        confidence: ModelEvidenceLevel.mechanism,
        limitation: 'Liquids generally show no meaningful lag.',
      ),
      liquidHalfMinutes: GastricEmptyingParameter<double>(
        id: 'ge.liquid.half_minutes',
        label: 'Liquid meal half-emptying time (minutes)',
        value: 15.0,
        sourceRefs: [
          'src.camilleri.ge.halftime.2009',
          'src.hens.foodphysical.2024',
        ],
        confidence: ModelEvidenceLevel.mechanism,
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
    );
  }

  List<GastricEmptyingParameter<Object>> get all => [
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
      ];

  /// Union of every parameter's `sourceRefs`. Used by
  /// `GastricEmptyingProfile.sourceRefs` so reviewers can trace back any
  /// modeled value.
  List<String> get unionSourceRefs {
    final set = <String>{};
    for (final p in all) {
      set.addAll(p.sourceRefs);
    }
    return set.toList(growable: false);
  }

  Map<String, dynamic> toJson() => {
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
      };
}
