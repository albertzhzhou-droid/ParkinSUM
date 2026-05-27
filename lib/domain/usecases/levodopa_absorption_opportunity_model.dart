import '../entities/absorption_opportunity.dart';
import '../entities/gastric_emptying_profile.dart';
import '../entities/time_axis_events.dart';

/// Estimates a window in which levodopa could become available for
/// small-intestinal absorption, given a medication event and any overlapping
/// meal's gastric emptying profile.
///
/// Educational simulation only. Does NOT predict blood concentration.
class LevodopaAbsorptionOpportunityModel {
  /// Reference parameters for immediate-release formulations.
  static const int referenceIrLagMinutes = 5;
  static const int referenceIrDurationMinutes = 90;

  /// Extended-release shifts and widens the opportunity window.
  static const int referenceErLagMinutes = 30;
  static const int referenceErDurationMinutes = 240;

  static const List<String> _baseSourceRefs = [
    'src.dailymed.sinemet.label',
    'src.dailymed.sinemet.extended.label',
    'src.contin.levodopa.pk.2010',
    'src.internal.prototype.heuristic',
  ];

  AbsorptionOpportunityWindow build({
    required MedicationTimelineEvent medication,
    GastricEmptyingProfile? overlappingMealProfile,
  }) {
    if (!medication.isLevodopaContext) {
      return AbsorptionOpportunityWindow(
        medicationEventId: medication.id,
        window: TimelineWindow(
          startMinute: medication.minute,
          endMinute: medication.minute,
        ),
        peakMinute: medication.minute,
        delayedArrivalLikelihood: DelayedArrivalLikelihood.unknown,
        uncertaintyBand: UncertaintyBand.wide,
        assumptions: const ['ldopa.absorption.non_levodopa_passthrough'],
        missingInputs: const ['active_ingredient_is_levodopa'],
        sourceRefs: _baseSourceRefs,
      );
    }

    final isExtended = medication.releaseType.toLowerCase().contains('extend');
    final isControlled =
        medication.releaseType.toLowerCase().contains('control');
    final lag = (isExtended || isControlled)
        ? referenceErLagMinutes
        : referenceIrLagMinutes;
    final duration = (isExtended || isControlled)
        ? referenceErDurationMinutes
        : referenceIrDurationMinutes;

    final assumptions = <String>[
      'ldopa.absorption.small_intestine',
      if (isExtended || isControlled)
        'ldopa.release_type.extended_widens_window',
    ];

    var startMinute = medication.minute + lag;
    var endMinute = medication.minute + lag + duration;
    var peakMinute = medication.minute + lag + (duration ~/ 3);

    DelayedArrivalLikelihood delayLikelihood = DelayedArrivalLikelihood.low;
    var uncertainty = UncertaintyBand.narrow;

    if (overlappingMealProfile != null) {
      // Estimate residual stomach load at medication time.
      final tSinceMealStart = medication.minute -
          overlappingMealProfile.peakEmptyingWindow.startMinute +
          overlappingMealProfile.aggregateLagMinutes.round();
      final residual = overlappingMealProfile
          .remainingFractionAt(tSinceMealStart < 0 ? 0 : tSinceMealStart);

      if (residual > 0.7) {
        startMinute += 30;
        endMinute += 60;
        peakMinute += 30;
        delayLikelihood = DelayedArrivalLikelihood.high;
        assumptions
            .add('ldopa.absorption.delayed_by_high_residual_stomach_load');
      } else if (residual > 0.4) {
        startMinute += 15;
        endMinute += 30;
        peakMinute += 15;
        delayLikelihood = DelayedArrivalLikelihood.moderate;
        assumptions
            .add('ldopa.absorption.shifted_by_moderate_residual_stomach_load');
      } else {
        delayLikelihood = DelayedArrivalLikelihood.low;
      }

      uncertainty = _combineUncertainty(
          uncertainty, overlappingMealProfile.uncertaintyBand);
    } else {
      delayLikelihood = DelayedArrivalLikelihood.unknown;
      assumptions.add('ldopa.absorption.no_overlapping_meal_profile');
    }

    return AbsorptionOpportunityWindow(
      medicationEventId: medication.id,
      window: TimelineWindow(startMinute: startMinute, endMinute: endMinute),
      peakMinute: peakMinute,
      delayedArrivalLikelihood: delayLikelihood,
      uncertaintyBand: uncertainty,
      assumptions: List.unmodifiable(assumptions),
      missingInputs: overlappingMealProfile == null
          ? const ['overlapping_meal_profile']
          : const [],
      sourceRefs: _baseSourceRefs,
    );
  }

  UncertaintyBand _combineUncertainty(UncertaintyBand a, UncertaintyBand b) {
    final order = [
      UncertaintyBand.narrow,
      UncertaintyBand.moderate,
      UncertaintyBand.wide,
      UncertaintyBand.veryWide,
    ];
    final idx = (order.indexOf(a) + order.indexOf(b)) ~/ 2 +
        ((order.indexOf(a) + order.indexOf(b)) % 2);
    return order[idx.clamp(0, order.length - 1)];
  }
}
