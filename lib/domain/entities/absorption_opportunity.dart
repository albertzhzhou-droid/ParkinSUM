import 'gastric_emptying_profile.dart' show UncertaintyBand;
import 'time_axis_events.dart';

enum DelayedArrivalLikelihood { low, moderate, high, unknown }

/// A single point on the deterministic absorption-opportunity openness curve.
/// `openness` (0..1) is a unitless educational weight for how "open" the
/// small-intestinal absorption opportunity is at `minute` — NOT a fraction of
/// an absorbed dose and NOT a blood concentration.
class AbsorptionOpennessSample {
  final int minute;
  final double openness; // 0..1

  const AbsorptionOpennessSample(
      {required this.minute, required this.openness});

  Map<String, dynamic> toJson() => {'minute': minute, 'openness': openness};
}

/// Estimated window in which a levodopa dose could become available for
/// small-intestinal absorption. This is an educational simulation — it does
/// not predict blood concentration or patient-specific response.
class AbsorptionOpportunityWindow {
  final String medicationEventId;
  final TimelineWindow window;
  final int peakMinute;
  final DelayedArrivalLikelihood delayedArrivalLikelihood;
  final UncertaintyBand uncertaintyBand;
  final List<String> assumptions;
  final List<String> missingInputs;
  final List<String> sourceRefs;

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
    this.opennessProfile = const [],
  });

  /// Peak openness across the profile (0 when no profile).
  double get peakOpenness => opennessProfile.isEmpty
      ? 0.0
      : opennessProfile.map((s) => s.openness).reduce((a, b) => a > b ? a : b);

  /// Openness weight at [minute], linearly interpolated between the bracketing
  /// samples. Returns 0 outside the sampled range (or when no profile exists),
  /// so an openness-weighted overlap naturally restricts to the window.
  double opennessAt(int minute) {
    if (opennessProfile.isEmpty) return 0.0;
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
        'window': window.toJson(),
        'peak_minute': peakMinute,
        'delayed_arrival_likelihood': delayedArrivalLikelihood.name,
        'uncertainty_band': uncertaintyBand.name,
        'assumptions': assumptions,
        'missing_inputs': missingInputs,
        'source_refs': sourceRefs,
        'openness_profile':
            opennessProfile.map((s) => s.toJson()).toList(growable: false),
        'peak_openness': peakOpenness,
      };
}
