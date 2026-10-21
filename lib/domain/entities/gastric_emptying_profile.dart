import 'dart:math' as math;

import 'time_axis_events.dart';

/// Uncertainty band used across the mechanistic model.
enum UncertaintyBand { narrow, moderate, wide, veryWide }

/// Whether an individual mechanistic provider emitted interpretable output.
///
/// This mirrors the stack-level four-state contract without importing the
/// composite conflict-result entity back into lower model layers. A zero is a
/// modeled value only in [available]; every other state is an abstention.
enum MechanisticProviderAvailability {
  available,
  notApplicable,
  insufficient,
  blockedIntegrity,
}

/// Engineering tolerance used only to compare deterministic derived values
/// that were computed from the same finite component inputs.
const double gastricDerivedCoherenceTolerance =
    GastricEmptyingOutputContract.derivedCoherenceTolerance;

/// Versioned structural contract for derived gastric curves and their
/// persisted/public projection.
///
/// These are engineering semantics shared by the generator and the output
/// validator. Keeping the constants here prevents a configuration witness from
/// describing a window or curve policy different from the one actually
/// executed.
abstract final class GastricEmptyingOutputContract {
  static const String schema = 'parkinsum.gastric-emptying-output-contract/2';
  static const double derivedCoherenceTolerance = 1e-9;
  static const double fractionSumTolerance = 1e-9;
  static const double peakWindowHalfTimeMultiplier = 1.5;
  static const double mostlyEmptiedHalfTimeMultiplier = 4.0;
  static const double timeScaleClampMinimum = 0.05;
  static const double timeScaleClampMaximum = 10.0;
  static const int arrivalRateCentralDifferenceMinutes = 1;

  static const Map<String, Object> integrityConfiguration = <String, Object>{
    r'$schema': schema,
    'availability_states': <String>[
      'available',
      'notApplicable',
      'insufficient',
      'blockedIntegrity',
    ],
    'available_requires_structural_integrity': true,
    'identity_constraints': <String, Object>{
      'meal_id': 'nonempty',
      'component_id': 'nonempty_and_unique',
    },
    'component_numeric_constraints': <String, Object>{
      'lag_minutes': 'finite_and_greater_than_or_equal_to_zero',
      'half_emptying_minutes': 'finite_and_strictly_greater_than_zero',
      'fraction_of_meal': 'finite_and_in_[0,1]',
      'volume_half_emptying_minutes':
          'present_only_for_calorie_regulated_then_finite_and_strictly_greater_than_zero',
      'calorie_delivery_minutes':
          'present_only_for_calorie_regulated_then_finite_and_strictly_greater_than_zero',
      'calorie_regulated_physical_form': 'liquid',
    },
    'fraction_bounds': <String, Object>{
      'minimum_inclusive': 0.0,
      'maximum_inclusive': 1.0,
      'sum_target': 1.0,
      'sum_tolerance': fractionSumTolerance,
    },
    'residence_curve': <String, Object>{
      'formula': 'exp(-ln(2) * (t - lag) / half_time)',
      'calorie_regulated_formula':
          'max(exp(-ln(2) * (t - lag) / volume_half_time), '
          '1 - (t - lag) / calorie_delivery_minutes)',
      'calorie_regulated_half_time':
          'max(volume_half_time, calorie_delivery_minutes / 2)',
      'before_or_at_lag_remaining': 1.0,
      'emptied_fraction_formula': '1 - remaining_fraction',
      'output_clamp': <double>[0.0, 1.0],
    },
    'window_derivation': <String, Object>{
      'rounding': 'nearest_integer_minutes',
      'peak_half_time_multiplier': peakWindowHalfTimeMultiplier,
      'mostly_emptied_half_time_multiplier': mostlyEmptiedHalfTimeMultiplier,
      'shared_window_origin': true,
      'peak_duration_strictly_positive': true,
      'mostly_emptied_contains_peak_window': true,
    },
    'aggregate_coherence': <String, Object>{
      'lag_formula': 'sum(component_fraction * component_lag)',
      'lag_finite_and_greater_than_or_equal_to_zero': true,
      'tolerance': derivedCoherenceTolerance,
    },
    'sensitivity_envelope': <String, Object>{
      'symmetric_fraction': true,
      'fraction_domain': '[0,1)',
      'time_scale_clamp': <double>[
        timeScaleClampMinimum,
        timeScaleClampMaximum,
      ],
      'scaled_terms': <String>[
        'lag',
        'half_time',
        'volume_half_time',
        'calorie_delivery_minutes',
      ],
    },
    'arrival_rate': <String, Object>{
      'method': 'central_difference_of_emptied_fraction',
      'step_minutes': arrivalRateCentralDifferenceMinutes,
      'left_boundary_clamp_minutes': 0,
      'output_clamp': <double>[0.0, 1.0],
      'meal_mass_weighting': 'fraction_of_meal',
      'tracked_quantity_weighting':
          'sum(w_i * component_arrival_i) / sum(w_i) over finite w_i > 0',
      'tracked_quantity_without_positive_weight': 0.0,
    },
    'empty_component_query_policy': <String, Object>{
      'remaining_fraction': 1.0,
      'sensitivity_remaining': 1.0,
    },
    'wire_policy': <String, Object>{
      'unavailable_numeric_outputs': 'null',
      'unavailable_component_profiles': 'empty',
      'integrity_failures_added_to_effective_reasons_when_declared_available':
          true,
      'available_with_integrity_failure_becomes': 'blockedIntegrity',
      'has_modeled_output_only_when_available': true,
    },
  };
}

typedef GastricComponentKinetics = ({
  double fractionOfMeal,
  double lagMinutes,
  double halfEmptyingMinutes,
});

typedef GastricDerivedProfileShape = ({
  double aggregateLagMinutes,
  double aggregateHalfEmptyingMinutes,
  int? peakWindowDurationMinutes,
  int? mostlyEmptiedWindowDurationMinutes,
});

/// Recomputes the exact deterministic aggregate and window widths emitted by
/// [GastricEmptyingModel] without importing that use case into persisted-wire
/// validators. This is formula-coherence verification, not clinical validity.
GastricDerivedProfileShape deriveGastricProfileShape(
  Iterable<GastricComponentKinetics> components,
) {
  var aggregateLag = 0.0;
  var aggregateHalf = 0.0;
  for (final component in components) {
    aggregateLag += component.fractionOfMeal * component.lagMinutes;
    aggregateHalf += component.fractionOfMeal * component.halfEmptyingMinutes;
  }
  final peakDuration =
      aggregateHalf *
      GastricEmptyingOutputContract.peakWindowHalfTimeMultiplier;
  final mostlyEmptiedDuration =
      aggregateHalf *
      GastricEmptyingOutputContract.mostlyEmptiedHalfTimeMultiplier;
  return (
    aggregateLagMinutes: aggregateLag,
    aggregateHalfEmptyingMinutes: aggregateHalf,
    peakWindowDurationMinutes: peakDuration.isFinite
        ? peakDuration.round()
        : null,
    mostlyEmptiedWindowDurationMinutes: mostlyEmptiedDuration.isFinite
        ? mostlyEmptiedDuration.round()
        : null,
  );
}

/// Per-component residence curve. Each component (e.g. solid toast vs liquid
/// coffee within the same meal) carries its own lag and half-emptying so that
/// mixed meals model component-specific kinetics.
///
/// Most components follow a lag-shifted exponential. A liquid that carries
/// energy is calorie-regulated instead: its delivery is limited to a roughly
/// constant number of kcal per minute (Brener et al. 1983), so it follows the
/// slower of two curves — the volume-driven exponential that an energy-free
/// liquid would follow ([volumeHalfEmptyingMinutes]) and a linear delivery
/// that empties the liquid energy over [calorieDeliveryMinutes]. For such a
/// component [halfEmptyingMinutes] is the time from the lag to half emptied,
/// `max(volume half-time, delivery / 2)`.
class EmptyingComponentProfile {
  final String componentId;
  final MealPhysicalForm physicalForm;
  final double lagMinutes;
  final double halfEmptyingMinutes;
  final double fractionOfMeal; // 0..1
  final List<String> appliedModifiers;

  /// Half-time of the volume-driven exponential bound. Present only for a
  /// calorie-regulated component.
  final double? volumeHalfEmptyingMinutes;

  /// Minutes the calorie-regulated linear delivery needs to empty the liquid
  /// energy. Present only for a calorie-regulated component.
  final double? calorieDeliveryMinutes;

  const EmptyingComponentProfile({
    required this.componentId,
    required this.physicalForm,
    required this.lagMinutes,
    required this.halfEmptyingMinutes,
    required this.fractionOfMeal,
    required this.appliedModifiers,
    this.volumeHalfEmptyingMinutes,
    this.calorieDeliveryMinutes,
  });

  bool get isCalorieRegulated => calorieDeliveryMinutes != null;

  double remainingFractionAt(int minutesSinceMealStart) =>
      remainingFractionAtTimeScale(minutesSinceMealStart, 1.0);

  /// Residence curve with lag and half-time scaled together. Used only for a
  /// visible one-way sensitivity analysis, never as a confidence interval.
  /// A calorie-regulated component scales its volume half-time and delivery
  /// time by the same factor.
  double remainingFractionAtTimeScale(
    int minutesSinceMealStart,
    double timeScale,
  ) {
    final safeScale = timeScale.clamp(
      GastricEmptyingOutputContract.timeScaleClampMinimum,
      GastricEmptyingOutputContract.timeScaleClampMaximum,
    );
    final scaledLag = lagMinutes * safeScale;
    if (minutesSinceMealStart <= scaledLag) return 1.0;
    final tEff = minutesSinceMealStart - scaledLag;
    final delivery = calorieDeliveryMinutes;
    if (delivery == null) {
      final k = math.ln2 / (halfEmptyingMinutes * safeScale);
      return math.exp(-k * tEff).clamp(0.0, 1.0);
    }
    final volumeHalf = volumeHalfEmptyingMinutes ?? halfEmptyingMinutes;
    final volumeBound = math.exp(-math.ln2 / (volumeHalf * safeScale) * tEff);
    final calorieBound = 1.0 - tEff / (delivery * safeScale);
    return math.max(volumeBound, calorieBound).clamp(0.0, 1.0);
  }

  double emptiedFractionAt(int minutesSinceMealStart) =>
      1.0 - remainingFractionAt(minutesSinceMealStart);

  /// This component's own arrival rate (fraction of the component per
  /// minute), with the same central difference as the meal-level rate.
  double intestinalArrivalRateAt(int minutesSinceMealStart) {
    const dt =
        GastricEmptyingOutputContract.arrivalRateCentralDifferenceMinutes;
    final leftT = minutesSinceMealStart - dt < 0
        ? 0
        : minutesSinceMealStart - dt;
    final right = emptiedFractionAt(minutesSinceMealStart + dt);
    final left = emptiedFractionAt(leftT);
    return ((right - left) / (2.0 * dt)).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
    'component_id': componentId,
    'physical_form': physicalForm.name,
    'lag_minutes': lagMinutes,
    'half_emptying_minutes': halfEmptyingMinutes,
    'fraction_of_meal': fractionOfMeal,
    'applied_modifiers': appliedModifiers,
    if (isCalorieRegulated) ...{
      'emptying_kinetics': 'calorie_regulated',
      'volume_half_emptying_minutes': volumeHalfEmptyingMinutes,
      'calorie_delivery_minutes': calorieDeliveryMinutes,
    },
  };
}

/// A complete meal-level gastric emptying profile. Combines per-component
/// curves; exposes meal-level convenience queries.
class GastricEmptyingProfile {
  final String mealId;

  /// Explicit four-state provider output contract.
  final MechanisticProviderAvailability _declaredAvailability;
  final List<String> applicabilityReasons;
  final List<EmptyingComponentProfile> componentProfiles;
  final UncertaintyBand uncertaintyBand;
  final List<String> assumptions;
  final List<String> missingInputs;
  final List<String> sourceRefs;
  final double aggregateLagMinutes;
  final TimelineWindow peakEmptyingWindow;
  final TimelineWindow mostlyEmptiedWindow;
  final double timeScaleSensitivityFraction;

  const GastricEmptyingProfile({
    required this.mealId,
    MechanisticProviderAvailability availability =
        MechanisticProviderAvailability.available,
    this.applicabilityReasons = const [],
    required this.componentProfiles,
    required this.uncertaintyBand,
    required this.assumptions,
    required this.missingInputs,
    required this.sourceRefs,
    required this.aggregateLagMinutes,
    required this.peakEmptyingWindow,
    required this.mostlyEmptiedWindow,
    required this.timeScaleSensitivityFraction,
  }) : _declaredAvailability = availability;

  /// An available profile is executable only when its result-bearing curve
  /// structure is internally coherent. A caller cannot turn absent or invalid
  /// component kinetics into an available modeled zero by setting the enum.
  MechanisticProviderAvailability get availability {
    if (_declaredAvailability == MechanisticProviderAvailability.available &&
        structuralIntegrityReasons.isNotEmpty) {
      return MechanisticProviderAvailability.blockedIntegrity;
    }
    return _declaredAvailability;
  }

  List<String> get effectiveApplicabilityReasons => List.unmodifiable({
    ...applicabilityReasons,
    if (_declaredAvailability == MechanisticProviderAvailability.available)
      ...structuralIntegrityReasons,
  });

  /// Deterministic structural checks for the public profile boundary. These
  /// validate executable shape, not clinical or biological validity.
  List<String> get structuralIntegrityReasons {
    final reasons = <String>{};
    if (mealId.trim().isEmpty) {
      reasons.add('gastric_emptying.profile_meal_id_empty');
    }
    if (componentProfiles.isEmpty) {
      reasons.add('gastric_emptying.profile_components_empty');
    }

    final componentIds = <String>{};
    var fractionSum = 0.0;
    for (final component in componentProfiles) {
      final canonicalComponentId = component.componentId.trim();
      if (canonicalComponentId.isEmpty) {
        reasons.add('gastric_emptying.profile_component_id_empty');
      } else if (!componentIds.add(canonicalComponentId)) {
        reasons.add('gastric_emptying.profile_component_id_duplicate');
      }
      if (!component.lagMinutes.isFinite || component.lagMinutes < 0) {
        reasons.add('gastric_emptying.profile_lag_invalid');
      }
      if (!component.halfEmptyingMinutes.isFinite ||
          component.halfEmptyingMinutes <= 0) {
        reasons.add('gastric_emptying.profile_half_time_invalid');
      }
      if (!component.fractionOfMeal.isFinite ||
          component.fractionOfMeal < 0 ||
          component.fractionOfMeal > 1) {
        reasons.add('gastric_emptying.profile_fraction_invalid');
      }
      fractionSum += component.fractionOfMeal;
      final volumeHalf = component.volumeHalfEmptyingMinutes;
      final delivery = component.calorieDeliveryMinutes;
      if ((volumeHalf == null) != (delivery == null)) {
        reasons.add('gastric_emptying.profile_calorie_regulation_incomplete');
      } else if (volumeHalf != null && delivery != null) {
        if (component.physicalForm != MealPhysicalForm.liquid) {
          reasons.add(
            'gastric_emptying.profile_calorie_regulation_form_invalid',
          );
        }
        if (!volumeHalf.isFinite ||
            volumeHalf <= 0 ||
            !delivery.isFinite ||
            delivery <= 0) {
          reasons.add('gastric_emptying.profile_calorie_regulation_invalid');
        } else if ((component.halfEmptyingMinutes -
                    math.max(volumeHalf, delivery / 2))
                .abs() >
            gastricDerivedCoherenceTolerance) {
          reasons.add(
            'gastric_emptying.profile_calorie_regulation_half_time_inconsistent',
          );
        }
      }
    }
    if (!fractionSum.isFinite ||
        (fractionSum - 1).abs() >
            GastricEmptyingOutputContract.fractionSumTolerance) {
      reasons.add('gastric_emptying.profile_fraction_sum_invalid');
    }
    final derived = deriveGastricProfileShape(
      componentProfiles.map(
        (component) => (
          fractionOfMeal: component.fractionOfMeal,
          lagMinutes: component.lagMinutes,
          halfEmptyingMinutes: component.halfEmptyingMinutes,
        ),
      ),
    );
    if (!aggregateLagMinutes.isFinite || aggregateLagMinutes < 0) {
      reasons.add('gastric_emptying.profile_aggregate_lag_invalid');
    } else if (!derived.aggregateLagMinutes.isFinite ||
        (aggregateLagMinutes - derived.aggregateLagMinutes).abs() >
            gastricDerivedCoherenceTolerance) {
      reasons.add('gastric_emptying.profile_aggregate_lag_inconsistent');
    }
    if (peakEmptyingWindow.durationMinutes <= 0) {
      reasons.add('gastric_emptying.profile_peak_window_invalid');
    }
    if (mostlyEmptiedWindow.durationMinutes <= 0 ||
        mostlyEmptiedWindow.startMinute > peakEmptyingWindow.startMinute ||
        mostlyEmptiedWindow.endMinute < peakEmptyingWindow.endMinute) {
      reasons.add('gastric_emptying.profile_window_order_invalid');
    }
    if (peakEmptyingWindow.startMinute != mostlyEmptiedWindow.startMinute) {
      reasons.add('gastric_emptying.profile_window_origin_inconsistent');
    }
    if (peakEmptyingWindow.durationMinutes !=
        derived.peakWindowDurationMinutes) {
      reasons.add('gastric_emptying.profile_peak_window_derived_inconsistent');
    }
    if (mostlyEmptiedWindow.durationMinutes !=
        derived.mostlyEmptiedWindowDurationMinutes) {
      reasons.add(
        'gastric_emptying.profile_mostly_emptied_window_derived_inconsistent',
      );
    }
    if (!timeScaleSensitivityFraction.isFinite ||
        timeScaleSensitivityFraction < 0 ||
        timeScaleSensitivityFraction >= 1) {
      reasons.add('gastric_emptying.profile_sensitivity_invalid');
    }
    return List.unmodifiable(reasons);
  }

  bool get modelApplicable =>
      availability == MechanisticProviderAvailability.available;

  bool get hasModeledOutput => modelApplicable;

  double remainingFractionAt(int minutesSinceMealStart) {
    if (componentProfiles.isEmpty) return 1.0;
    var total = 0.0;
    for (final c in componentProfiles) {
      total += c.fractionOfMeal * c.remainingFractionAt(minutesSinceMealStart);
    }
    return total.clamp(0.0, 1.0);
  }

  double emptiedFractionAt(int minutesSinceMealStart) =>
      1.0 - remainingFractionAt(minutesSinceMealStart);

  /// Faster/slower deterministic time-scale envelope. This is deliberately a
  /// sensitivity range, not a probability interval or patient prediction.
  ({double fasterRemaining, double slowerRemaining}) sensitivityEnvelopeAt(
    int minutesSinceMealStart,
  ) {
    if (componentProfiles.isEmpty) {
      return (fasterRemaining: 1.0, slowerRemaining: 1.0);
    }
    final fasterScale = 1.0 - timeScaleSensitivityFraction;
    final slowerScale = 1.0 + timeScaleSensitivityFraction;
    var faster = 0.0;
    var slower = 0.0;
    for (final component in componentProfiles) {
      faster +=
          component.fractionOfMeal *
          component.remainingFractionAtTimeScale(
            minutesSinceMealStart,
            fasterScale,
          );
      slower +=
          component.fractionOfMeal *
          component.remainingFractionAtTimeScale(
            minutesSinceMealStart,
            slowerScale,
          );
    }
    return (
      fasterRemaining: faster.clamp(0.0, 1.0),
      slowerRemaining: slower.clamp(0.0, 1.0),
    );
  }

  /// Approximate instantaneous intestinal arrival *rate* of meal mass at
  /// minute t, via central-difference of the mass-weighted emptied fraction.
  /// Deterministic. Every component counts by its share of the meal mass, so
  /// a glass of water shapes this curve as much as the food it is served with.
  double intestinalArrivalRateAt(int minutesSinceMealStart) {
    const dt =
        GastricEmptyingOutputContract.arrivalRateCentralDifferenceMinutes;
    final leftT = minutesSinceMealStart - dt < 0
        ? 0
        : minutesSinceMealStart - dt;
    final right = emptiedFractionAt(minutesSinceMealStart + dt);
    final left = emptiedFractionAt(leftT);
    return ((right - left) / (2.0 * dt)).clamp(0.0, 1.0);
  }

  /// Arrival rate of a quantity the components carry (for example grams of
  /// protein): `Σ w_i · d emptied_i/dt / Σ w_i`, using the same central
  /// difference as [intestinalArrivalRateAt]. A component without a finite
  /// positive weight carries none of the quantity and contributes nothing, so
  /// adding a zero-protein drink cannot move a protein-arrival curve. Returns
  /// 0 when no component carries a positive weight.
  double weightedIntestinalArrivalRateAt(
    int minutesSinceMealStart,
    Map<String, double> weightsByComponentId,
  ) {
    final shares = _positiveWeightShares(weightsByComponentId);
    if (shares.isEmpty) return 0.0;
    var rate = 0.0;
    for (final (:component, :share) in shares) {
      rate += share * component.intestinalArrivalRateAt(minutesSinceMealStart);
    }
    return rate.clamp(0.0, 1.0);
  }

  /// Aggregate lag and window widths derived exactly like the mass-weighted
  /// profile, but with each component weighted by the tracked quantity it
  /// carries. Null when no component carries a positive weight.
  GastricDerivedProfileShape? weightedProfileShape(
    Map<String, double> weightsByComponentId,
  ) {
    final shares = _positiveWeightShares(weightsByComponentId);
    if (shares.isEmpty) return null;
    return deriveGastricProfileShape([
      for (final (:component, :share) in shares)
        (
          fractionOfMeal: share,
          lagMinutes: component.lagMinutes,
          halfEmptyingMinutes: component.halfEmptyingMinutes,
        ),
    ]);
  }

  /// Components with a finite positive weight and their share of the total
  /// weight. Shares are taken before any curve is evaluated, so a single
  /// weighted component reproduces its own curve exactly.
  List<({EmptyingComponentProfile component, double share})>
  _positiveWeightShares(Map<String, double> weightsByComponentId) {
    var totalWeight = 0.0;
    final weighted = <({EmptyingComponentProfile component, double weight})>[];
    for (final component in componentProfiles) {
      final weight = weightsByComponentId[component.componentId];
      if (weight == null || !weight.isFinite || weight <= 0) continue;
      totalWeight += weight;
      weighted.add((component: component, weight: weight));
    }
    if (weighted.isEmpty || !totalWeight.isFinite) return const [];
    return [
      for (final entry in weighted)
        (component: entry.component, share: entry.weight / totalWeight),
    ];
  }

  Map<String, dynamic> toJson() => {
    'meal_id': mealId,
    'result_availability': availability.name,
    'has_modeled_output': hasModeledOutput,
    'model_applicable': modelApplicable,
    'applicability_reasons': effectiveApplicabilityReasons,
    'component_profiles': modelApplicable
        ? componentProfiles.map((e) => e.toJson()).toList(growable: false)
        : const <Map<String, dynamic>>[],
    'uncertainty_band': uncertaintyBand.name,
    'assumptions': assumptions,
    'missing_inputs': missingInputs,
    'source_refs': sourceRefs,
    'aggregate_lag_minutes': modelApplicable ? aggregateLagMinutes : null,
    'peak_emptying_window': modelApplicable
        ? peakEmptyingWindow.toJson()
        : null,
    'mostly_emptied_window': modelApplicable
        ? mostlyEmptiedWindow.toJson()
        : null,
    'time_scale_sensitivity_fraction': modelApplicable
        ? timeScaleSensitivityFraction
        : null,
  };
}
