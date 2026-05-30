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

  /// Openness-curve shape constants (prototype heuristic; unitless 0..1
  /// educational weights, NOT an absorbed fraction or blood concentration).
  /// IR rises sharply to a full-openness peak then decays to a low tail; ER /
  /// controlled release is flatter and longer (lower peak, higher sustained
  /// tail), reflecting the prolonged release profile.
  static const int _opennessSampleStrideMinutes = 10;
  static const double _irPeakOpenness = 1.0;
  static const double _irTailOpenness = 0.15;
  static const double _erPeakOpenness = 0.85;
  static const double _erTailOpenness = 0.5;

  /// Multiplier applied to the whole curve when the meal context is incomplete
  /// (no overlapping meal profile) — the opportunity shape is less certain, so
  /// it is flattened rather than asserted sharply.
  static const double _incompleteContextOpennessScale = 0.85;

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

    final releaseTypeRaw = medication.releaseType.toLowerCase().trim();
    final isExtended = releaseTypeRaw.contains('extend');
    final isControlled = releaseTypeRaw.contains('control');
    final isDelayed = releaseTypeRaw.contains('delay');
    // Extended / controlled / delayed release all widen the opportunity window.
    final isWideRelease = isExtended || isControlled || isDelayed;
    // Unknown/unspecified/empty → release-specific interpretation is limited;
    // we keep a default (IR-shaped) window but widen uncertainty and never
    // assert ER/IR specifics. Release type is NEVER inferred from dose.
    final releaseTypeUnknown = releaseTypeRaw.isEmpty ||
        releaseTypeRaw == 'unknown' ||
        releaseTypeRaw == 'unspecified';
    final lag = isWideRelease ? referenceErLagMinutes : referenceIrLagMinutes;
    final duration =
        isWideRelease ? referenceErDurationMinutes : referenceIrDurationMinutes;

    final assumptions = <String>[
      'ldopa.absorption.small_intestine',
      if (isWideRelease) 'ldopa.release_type.extended_widens_window',
      if (releaseTypeUnknown) 'ldopa.absorption.release_type_unknown_limited',
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

    // Unknown release type widens uncertainty by one step (release-specific
    // interpretation is limited).
    if (releaseTypeUnknown) {
      uncertainty = _combineUncertainty(uncertainty, UncertaintyBand.wide);
    }

    final incompleteContext = overlappingMealProfile == null;
    final opennessProfile = _buildOpennessProfile(
      startMinute: startMinute,
      endMinute: endMinute,
      peakMinute: peakMinute,
      extended: isWideRelease,
      incompleteContext: incompleteContext,
    );
    assumptions.add(isWideRelease
        ? 'ldopa.absorption.openness_profile_extended_flatter_longer'
        : 'ldopa.absorption.openness_profile_immediate_sharper');
    if (incompleteContext) {
      assumptions
          .add('ldopa.absorption.openness_flattened_incomplete_meal_context');
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
      opennessProfile: opennessProfile,
    );
  }

  /// Deterministic sampled openness curve over [startMinute, endMinute] with a
  /// rise to [peakMinute] then a decay to a release-type-specific tail.
  /// Educational shape only — not blood concentration, not PK/PD calibration.
  List<AbsorptionOpennessSample> _buildOpennessProfile({
    required int startMinute,
    required int endMinute,
    required int peakMinute,
    required bool extended,
    required bool incompleteContext,
  }) {
    if (endMinute <= startMinute) return const [];
    final peakOpenness = extended ? _erPeakOpenness : _irPeakOpenness;
    final tailOpenness = extended ? _erTailOpenness : _irTailOpenness;
    final scale = incompleteContext ? _incompleteContextOpennessScale : 1.0;
    final peak = peakMinute.clamp(startMinute, endMinute);

    final samples = <AbsorptionOpennessSample>[];
    for (var t = startMinute;
        t <= endMinute;
        t += _opennessSampleStrideMinutes) {
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
      samples.add(AbsorptionOpennessSample(
        minute: t,
        openness: (o * scale).clamp(0.0, 1.0),
      ));
    }
    // Ensure the window end is represented as a sample.
    if (samples.isEmpty || samples.last.minute != endMinute) {
      samples.add(AbsorptionOpennessSample(
        minute: endMinute,
        openness: (tailOpenness * scale).clamp(0.0, 1.0),
      ));
    }
    return List.unmodifiable(samples);
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
