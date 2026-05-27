import 'dart:math' as math;

import 'time_axis_events.dart';

/// Uncertainty band used across the mechanistic model.
enum UncertaintyBand { narrow, moderate, wide, veryWide }

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
  final List<EmptyingComponentProfile> componentProfiles;
  final UncertaintyBand uncertaintyBand;
  final List<String> assumptions;
  final List<String> missingInputs;
  final List<String> sourceRefs;
  final double aggregateLagMinutes;
  final TimelineWindow peakEmptyingWindow;
  final TimelineWindow mostlyEmptiedWindow;

  const GastricEmptyingProfile({
    required this.mealId,
    required this.componentProfiles,
    required this.uncertaintyBand,
    required this.assumptions,
    required this.missingInputs,
    required this.sourceRefs,
    required this.aggregateLagMinutes,
    required this.peakEmptyingWindow,
    required this.mostlyEmptiedWindow,
  });

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

  /// Approximate instantaneous intestinal arrival *rate* at minute t, via
  /// central-difference of the emptied fraction. Deterministic.
  double intestinalArrivalRateAt(int minutesSinceMealStart) {
    const dt = 1;
    final leftT =
        minutesSinceMealStart - dt < 0 ? 0 : minutesSinceMealStart - dt;
    final right = emptiedFractionAt(minutesSinceMealStart + dt);
    final left = emptiedFractionAt(leftT);
    return ((right - left) / (2.0 * dt)).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'meal_id': mealId,
        'component_profiles':
            componentProfiles.map((e) => e.toJson()).toList(growable: false),
        'uncertainty_band': uncertaintyBand.name,
        'assumptions': assumptions,
        'missing_inputs': missingInputs,
        'source_refs': sourceRefs,
        'aggregate_lag_minutes': aggregateLagMinutes,
        'peak_emptying_window': peakEmptyingWindow.toJson(),
        'mostly_emptied_window': mostlyEmptiedWindow.toJson(),
      };
}
