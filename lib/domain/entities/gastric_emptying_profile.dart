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
const double gastricDerivedCoherenceTolerance = 1e-9;

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
  final peakDuration = aggregateHalf * 1.5;
  final mostlyEmptiedDuration = aggregateHalf * 4;
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
class EmptyingComponentProfile {
  final String componentId;
  final MealPhysicalForm physicalForm;
  final double lagMinutes;
  final double halfEmptyingMinutes;
  final double fractionOfMeal; // 0..1
  final List<String> appliedModifiers;

  const EmptyingComponentProfile({
    required this.componentId,
    required this.physicalForm,
    required this.lagMinutes,
    required this.halfEmptyingMinutes,
    required this.fractionOfMeal,
    required this.appliedModifiers,
  });

  double remainingFractionAt(int minutesSinceMealStart) {
    if (minutesSinceMealStart <= lagMinutes) return 1.0;
    final tEff = minutesSinceMealStart - lagMinutes;
    final k = math.ln2 / halfEmptyingMinutes;
    final remaining = math.exp(-k * tEff);
    return remaining.clamp(0.0, 1.0);
  }

  /// Residence curve with lag and half-time scaled together. Used only for a
  /// visible one-way sensitivity analysis, never as a confidence interval.
  double remainingFractionAtTimeScale(
    int minutesSinceMealStart,
    double timeScale,
  ) {
    final safeScale = timeScale.clamp(0.05, 10.0);
    final scaledLag = lagMinutes * safeScale;
    final scaledHalf = halfEmptyingMinutes * safeScale;
    if (minutesSinceMealStart <= scaledLag) return 1.0;
    final tEff = minutesSinceMealStart - scaledLag;
    final k = math.ln2 / scaledHalf;
    return math.exp(-k * tEff).clamp(0.0, 1.0);
  }

  double emptiedFractionAt(int minutesSinceMealStart) =>
      1.0 - remainingFractionAt(minutesSinceMealStart);

  Map<String, dynamic> toJson() => {
    'component_id': componentId,
    'physical_form': physicalForm.name,
    'lag_minutes': lagMinutes,
    'half_emptying_minutes': halfEmptyingMinutes,
    'fraction_of_meal': fractionOfMeal,
    'applied_modifiers': appliedModifiers,
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
          component.fractionOfMeal <= 0 ||
          component.fractionOfMeal > 1) {
        reasons.add('gastric_emptying.profile_fraction_invalid');
      }
      fractionSum += component.fractionOfMeal;
    }
    if (!fractionSum.isFinite || (fractionSum - 1).abs() > 1e-9) {
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

  /// Approximate instantaneous intestinal arrival *rate* at minute t, via
  /// central-difference of the emptied fraction. Deterministic.
  double intestinalArrivalRateAt(int minutesSinceMealStart) {
    const dt = 1;
    final leftT = minutesSinceMealStart - dt < 0
        ? 0
        : minutesSinceMealStart - dt;
    final right = emptiedFractionAt(minutesSinceMealStart + dt);
    final left = emptiedFractionAt(leftT);
    return ((right - left) / (2.0 * dt)).clamp(0.0, 1.0);
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
