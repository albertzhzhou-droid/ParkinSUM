import '../entities/algorithm_component_identity_witness.dart';
import '../entities/absorption_opportunity.dart';
import '../entities/gastric_emptying_profile.dart';
import '../entities/mechanistic_medication_applicability.dart';
import '../entities/time_axis_events.dart';

/// Estimates a window in which levodopa could become available for
/// small-intestinal absorption, given a medication event and any overlapping
/// meal's gastric emptying profile.
///
/// Educational simulation only. Does NOT predict blood concentration.
class LevodopaAbsorptionOpportunityModel
    with RegisteredAlgorithmComponentIdentity {
  static const MechanisticMedicationApplicabilityPolicy _applicabilityPolicy =
      MechanisticMedicationApplicabilityPolicy();

  /// Reference parameters for immediate-release formulations.
  static const int referenceIrLagMinutes = 5;
  static const int referenceIrDurationMinutes = 90;

  /// Mean meal-associated absorption delay reported for nine selected
  /// participants in Nutt et al. (1984). Mapping this group mean onto the
  /// residual-load thresholds below is a prototype heuristic: it is an
  /// illustrative central shift, never an individual or formulation estimate.
  static const int illustrativeMealDelayMinutes = 34;

  /// Openness-curve shape constants (prototype heuristic; unitless 0..1
  /// educational weights, NOT an absorbed fraction or blood concentration).
  /// The supported IR tablet trace rises to a full-openness peak then decays to
  /// a low tail.
  static const int opennessSampleStrideMinutes = 10;
  static const double irPeakOpenness = 1.0;
  static const double irTailOpenness = 0.15;

  static const List<String> _baseSourceRefs = [
    'src.dailymed.sinemet.label',
    'src.nutt.onoff.1984',
    'src.doi.ge.levodopa.2012',
    'src.internal.prototype.heuristic',
  ];

  AbsorptionOpportunityWindow build({
    required MedicationTimelineEvent medication,
    GastricEmptyingProfile? overlappingMealProfile,
  }) {
    final applicability = _applicabilityPolicy.evaluate(medication.context);
    if (!applicability.applicable) {
      return _abstainedWindow(
        medication: medication,
        availability:
            applicability.status ==
                MechanisticMedicationApplicabilityStatus.notApplicable
            ? MechanisticProviderAvailability.notApplicable
            : MechanisticProviderAvailability.insufficient,
        reasonCodes: applicability.reasonCodes,
      );
    }
    if (overlappingMealProfile == null) {
      return _abstainedWindow(
        medication: medication,
        availability: MechanisticProviderAvailability.insufficient,
        reasonCodes: const ['absorption.overlapping_meal_profile_missing'],
      );
    }
    if (!overlappingMealProfile.modelApplicable) {
      return _abstainedWindow(
        medication: medication,
        availability: overlappingMealProfile.availability,
        reasonCodes: [
          'absorption.gastric_emptying_not_applicable',
          ...overlappingMealProfile.effectiveApplicabilityReasons,
        ],
      );
    }

    // The v1 applicability policy admits only the IR whole-tablet context.
    // Arbitrary non-empty strings and other formulations never default to IR.
    final lag = referenceIrLagMinutes;
    final duration = referenceIrDurationMinutes;

    final assumptions = <String>['ldopa.absorption.small_intestine'];

    var startMinute = medication.minute + lag;
    var endMinute = medication.minute + lag + duration;
    var peakMinute = medication.minute + lag + (duration ~/ 3);

    DelayedArrivalLikelihood delayLikelihood = DelayedArrivalLikelihood.low;
    var uncertainty = UncertaintyBand.narrow;

    // Estimate residual stomach load at medication time.
    final tSinceMealStart =
        medication.minute -
        overlappingMealProfile.peakEmptyingWindow.startMinute +
        overlappingMealProfile.aggregateLagMinutes.round();
    final residual = overlappingMealProfile.remainingFractionAt(
      tSinceMealStart < 0 ? 0 : tSinceMealStart,
    );

    if (residual > 0.7) {
      startMinute += illustrativeMealDelayMinutes;
      endMinute += illustrativeMealDelayMinutes * 2;
      peakMinute += illustrativeMealDelayMinutes;
      delayLikelihood = DelayedArrivalLikelihood.high;
      assumptions.add(
        'ldopa.absorption.high_residual_group_mean_shift_prototype_heuristic',
      );
    } else if (residual > 0.4) {
      final moderateShift = illustrativeMealDelayMinutes ~/ 2;
      startMinute += moderateShift;
      endMinute += illustrativeMealDelayMinutes;
      peakMinute += moderateShift;
      delayLikelihood = DelayedArrivalLikelihood.moderate;
      assumptions.add(
        'ldopa.absorption.moderate_residual_half_shift_prototype_heuristic',
      );
    } else {
      delayLikelihood = DelayedArrivalLikelihood.low;
    }

    // Downstream uncertainty cannot be narrower than the meal model that
    // supplies its gastric-arrival input.
    uncertainty = _inheritUncertainty(
      uncertainty,
      overlappingMealProfile.uncertaintyBand,
    );

    final opennessProfile = _buildOpennessProfile(
      startMinute: startMinute,
      endMinute: endMinute,
      peakMinute: peakMinute,
    );
    assumptions.add('ldopa.absorption.openness_profile_immediate_sharper');

    return AbsorptionOpportunityWindow(
      medicationEventId: medication.id,
      window: TimelineWindow(startMinute: startMinute, endMinute: endMinute),
      peakMinute: peakMinute,
      delayedArrivalLikelihood: delayLikelihood,
      uncertaintyBand: uncertainty,
      assumptions: List.unmodifiable(assumptions),
      missingInputs: const [],
      sourceRefs: _baseSourceRefs,
      opennessProfile: opennessProfile,
    );
  }

  AbsorptionOpportunityWindow _abstainedWindow({
    required MedicationTimelineEvent medication,
    required MechanisticProviderAvailability availability,
    required List<String> reasonCodes,
  }) {
    return AbsorptionOpportunityWindow(
      medicationEventId: medication.id,
      window: TimelineWindow(
        startMinute: medication.minute,
        endMinute: medication.minute,
      ),
      peakMinute: medication.minute,
      delayedArrivalLikelihood: DelayedArrivalLikelihood.unknown,
      uncertaintyBand: UncertaintyBand.veryWide,
      assumptions: const ['ldopa.absorption.model_not_applicable'],
      missingInputs: List.unmodifiable(reasonCodes),
      sourceRefs: _baseSourceRefs,
      availability: availability,
      applicabilityReasons: List.unmodifiable(reasonCodes),
      opennessProfile: const [],
    );
  }

  /// Deterministic sampled openness curve over [startMinute, endMinute] with a
  /// rise to [peakMinute] then a decay to the supported IR tail.
  /// Educational shape only — not blood concentration, not PK/PD calibration.
  List<AbsorptionOpennessSample> _buildOpennessProfile({
    required int startMinute,
    required int endMinute,
    required int peakMinute,
  }) {
    if (endMinute <= startMinute) return const [];
    const peakOpenness = irPeakOpenness;
    const tailOpenness = irTailOpenness;
    final peak = peakMinute.clamp(startMinute, endMinute);

    final samples = <AbsorptionOpennessSample>[];
    for (
      var t = startMinute;
      t <= endMinute;
      t += opennessSampleStrideMinutes
    ) {
      double o;
      if (t <= peak) {
        final rise = peak == startMinute
            ? 1.0
            : (t - startMinute) / (peak - startMinute);
        o = rise * peakOpenness;
      } else {
        final decay = endMinute == peak ? 0.0 : (t - peak) / (endMinute - peak);
        o = peakOpenness - decay * (peakOpenness - tailOpenness);
      }
      samples.add(
        AbsorptionOpennessSample(minute: t, openness: o.clamp(0.0, 1.0)),
      );
    }
    // Ensure the window end is represented as a sample.
    if (samples.isEmpty || samples.last.minute != endMinute) {
      samples.add(
        AbsorptionOpennessSample(minute: endMinute, openness: tailOpenness),
      );
    }
    return List.unmodifiable(samples);
  }

  UncertaintyBand _inheritUncertainty(
    UncertaintyBand current,
    UncertaintyBand upstream,
  ) =>
      UncertaintyBand.values[current.index > upstream.index
          ? current.index
          : upstream.index];
}
