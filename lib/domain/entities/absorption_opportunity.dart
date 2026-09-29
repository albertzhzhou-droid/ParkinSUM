import 'gastric_emptying_profile.dart'
    show MechanisticProviderAvailability, UncertaintyBand;
import 'time_axis_events.dart';

enum DelayedArrivalLikelihood { low, moderate, high, unknown }

/// A single point on the deterministic absorption-opportunity openness curve.
/// `openness` (0..1) is a unitless educational weight for how "open" the
/// small-intestinal absorption opportunity is at `minute` — NOT a fraction of
/// an absorbed dose and NOT a blood concentration.
class AbsorptionOpennessSample {
  final int minute;
  final double openness; // 0..1

  const AbsorptionOpennessSample({
    required this.minute,
    required this.openness,
  });

  Map<String, dynamic> toJson() => {'minute': minute, 'openness': openness};
}

/// Estimated window in which a levodopa dose could become available for
/// small-intestinal absorption. This is an educational simulation — it does
/// not predict blood concentration or patient-specific response.
class AbsorptionOpportunityWindow {
  static const double peakConsistencyTolerance = 1e-12;

  /// Canonical declaration of the result-affecting output-integrity and wire
  /// policies owned by this type. The declaration is shown in Algorithm
  /// Observatory and bound to the exact source digest; it is not evidence of
  /// pharmacokinetic or clinical validity.
  static Map<String, dynamic> get integrityConfiguration => const {
    r'$schema': 'parkinsum.absorption-opportunity-output-contract/1',
    'available_integrity_rules': {
      'medication_event_id': 'trimmed_non_empty',
      'window_duration': 'strictly_positive',
      'peak_position': 'inside_closed_window',
      'delay_likelihood': 'must_not_be_unknown',
      'samples': 'non_empty',
      'sample_openness': 'finite_and_inside_closed_0_1',
      'sample_minutes': 'inside_window_strictly_increasing_unique',
      'endpoint_coverage': 'first_equals_start_and_last_equals_end',
      'peak_sample': 'equals_finite_global_maximum_within_tolerance',
      'maximum_openness': 'strictly_positive',
      'peak_consistency_tolerance': peakConsistencyTolerance,
    },
    'availability_resolution':
        'declared_available_with_integrity_reason_becomes_blockedIntegrity',
    'effective_reason_policy': 'stable_set_union_declared_then_integrity',
    'interpolation': {
      'method': 'piecewise_linear_between_bracketing_samples',
      'exact_endpoints': 'return_endpoint_sample',
      'outside_window': 0.0,
      'unavailable_or_empty': 0.0,
    },
    'peak_openness': 'finite_maximum_or_zero_when_unavailable_or_empty',
    'wire_abstention': {
      'window': null,
      'peak_minute': null,
      'peak_openness': null,
      'openness_profile': <Map<String, dynamic>>[],
    },
    'integrity_reason_codes': [
      'absorption.profile_medication_event_id_empty',
      'absorption.profile_window_invalid',
      'absorption.profile_peak_outside_window',
      'absorption.profile_delay_likelihood_unknown',
      'absorption.profile_samples_empty',
      'absorption.profile_openness_nonfinite',
      'absorption.profile_openness_out_of_range',
      'absorption.profile_sample_outside_window',
      'absorption.profile_sample_minute_duplicate',
      'absorption.profile_sample_minutes_nonmonotonic',
      'absorption.profile_window_coverage_incomplete',
      'absorption.profile_peak_inconsistent',
      'absorption.profile_openness_mass_empty',
    ],
  };

  final String medicationEventId;
  final TimelineWindow window;
  final int peakMinute;
  final DelayedArrivalLikelihood delayedArrivalLikelihood;
  final UncertaintyBand uncertaintyBand;
  final List<String> assumptions;
  final List<String> missingInputs;
  final List<String> sourceRefs;

  /// Explicit four-state provider output contract. Consumers must not
  /// interpret the zero-width compatibility window or empty curve as a
  /// modeled zero when this is not [MechanisticProviderAvailability.available].
  final MechanisticProviderAvailability _declaredAvailability;
  final List<String> applicabilityReasons;

  /// Sampled openness curve over the window (additive; the flat `window`
  /// fields stay for compatibility). Deterministic shape from release type +
  /// gastric delay; empty when not computed.
  final List<AbsorptionOpennessSample> opennessProfile;

  const AbsorptionOpportunityWindow({
    required this.medicationEventId,
    required this.window,
    required this.peakMinute,
    required this.delayedArrivalLikelihood,
    required this.uncertaintyBand,
    required this.assumptions,
    required this.missingInputs,
    required this.sourceRefs,
    MechanisticProviderAvailability availability =
        MechanisticProviderAvailability.available,
    this.applicabilityReasons = const [],
    this.opennessProfile = const [],
  }) : _declaredAvailability = availability;

  /// Resolves a caller-declared available state against the executable curve
  /// structure. This is an engineering integrity gate, not a validity claim.
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

  List<String> get structuralIntegrityReasons {
    final reasons = <String>{};
    if (medicationEventId.trim().isEmpty) {
      reasons.add('absorption.profile_medication_event_id_empty');
    }
    if (window.durationMinutes <= 0) {
      reasons.add('absorption.profile_window_invalid');
    }
    if (peakMinute < window.startMinute || peakMinute > window.endMinute) {
      reasons.add('absorption.profile_peak_outside_window');
    }
    if (delayedArrivalLikelihood == DelayedArrivalLikelihood.unknown) {
      reasons.add('absorption.profile_delay_likelihood_unknown');
    }
    if (opennessProfile.isEmpty) {
      reasons.add('absorption.profile_samples_empty');
      return List.unmodifiable(reasons);
    }

    int? previousMinute;
    var maximumOpenness = double.negativeInfinity;
    for (final sample in opennessProfile) {
      if (!sample.openness.isFinite) {
        reasons.add('absorption.profile_openness_nonfinite');
      } else {
        if (sample.openness < 0 || sample.openness > 1) {
          reasons.add('absorption.profile_openness_out_of_range');
        }
        if (sample.openness > maximumOpenness) {
          maximumOpenness = sample.openness;
        }
      }
      if (sample.minute < window.startMinute ||
          sample.minute > window.endMinute) {
        reasons.add('absorption.profile_sample_outside_window');
      }
      if (previousMinute != null) {
        if (sample.minute == previousMinute) {
          reasons.add('absorption.profile_sample_minute_duplicate');
        } else if (sample.minute < previousMinute) {
          reasons.add('absorption.profile_sample_minutes_nonmonotonic');
        }
      }
      previousMinute = sample.minute;
    }
    if (opennessProfile.first.minute != window.startMinute ||
        opennessProfile.last.minute != window.endMinute) {
      reasons.add('absorption.profile_window_coverage_incomplete');
    }
    if (!maximumOpenness.isFinite ||
        !opennessProfile.any(
          (sample) =>
              sample.minute == peakMinute &&
              sample.openness.isFinite &&
              (sample.openness - maximumOpenness).abs() <=
                  peakConsistencyTolerance,
        )) {
      reasons.add('absorption.profile_peak_inconsistent');
    }
    if (maximumOpenness.isFinite && maximumOpenness <= 0) {
      reasons.add('absorption.profile_openness_mass_empty');
    }
    return List.unmodifiable(reasons);
  }

  bool get modelApplicable =>
      availability == MechanisticProviderAvailability.available;

  bool get hasModeledOutput => modelApplicable;

  /// Peak openness across the profile (0 when no profile).
  double get peakOpenness => !modelApplicable || opennessProfile.isEmpty
      ? 0.0
      : opennessProfile.map((s) => s.openness).reduce((a, b) => a > b ? a : b);

  /// Openness weight at [minute], linearly interpolated between the bracketing
  /// samples. Returns 0 outside the sampled range (or when no profile exists),
  /// so an openness-weighted overlap naturally restricts to the window.
  double opennessAt(int minute) {
    if (!modelApplicable || opennessProfile.isEmpty) return 0.0;
    if (minute <= opennessProfile.first.minute) {
      return minute == opennessProfile.first.minute
          ? opennessProfile.first.openness
          : 0.0;
    }
    if (minute >= opennessProfile.last.minute) {
      return minute == opennessProfile.last.minute
          ? opennessProfile.last.openness
          : 0.0;
    }
    for (var i = 0; i < opennessProfile.length - 1; i++) {
      final a = opennessProfile[i];
      final b = opennessProfile[i + 1];
      if (minute >= a.minute && minute <= b.minute) {
        if (b.minute == a.minute) return a.openness;
        final t = (minute - a.minute) / (b.minute - a.minute);
        return a.openness + t * (b.openness - a.openness);
      }
    }
    return 0.0;
  }

  Map<String, dynamic> toJson() => {
    'medication_event_id': medicationEventId,
    // The in-memory zero-width values are compatibility sentinels only. On
    // the wire, null is the sole truthful representation of no modeled
    // timeline/peak; otherwise callers could mistake abstention for a zero
    // result at the dose minute.
    'window': modelApplicable ? window.toJson() : null,
    'peak_minute': modelApplicable ? peakMinute : null,
    'delayed_arrival_likelihood': delayedArrivalLikelihood.name,
    'uncertainty_band': uncertaintyBand.name,
    'assumptions': assumptions,
    'missing_inputs': missingInputs,
    'source_refs': sourceRefs,
    'result_availability': availability.name,
    'has_modeled_output': hasModeledOutput,
    'model_applicable': modelApplicable,
    'applicability_reasons': effectiveApplicabilityReasons,
    'openness_profile': modelApplicable
        ? opennessProfile.map((s) => s.toJson()).toList(growable: false)
        : const <Map<String, dynamic>>[],
    'peak_openness': modelApplicable ? peakOpenness : null,
  };
}
