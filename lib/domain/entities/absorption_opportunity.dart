import 'gastric_emptying_profile.dart' show UncertaintyBand;
import 'time_axis_events.dart';

enum DelayedArrivalLikelihood { low, moderate, high, unknown }

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

  const AbsorptionOpportunityWindow({
    required this.medicationEventId,
    required this.window,
    required this.peakMinute,
    required this.delayedArrivalLikelihood,
    required this.uncertaintyBand,
    required this.assumptions,
    required this.missingInputs,
    required this.sourceRefs,
  });

  Map<String, dynamic> toJson() => {
        'medication_event_id': medicationEventId,
        'window': window.toJson(),
        'peak_minute': peakMinute,
        'delayed_arrival_likelihood': delayedArrivalLikelihood.name,
        'uncertainty_band': uncertaintyBand.name,
        'assumptions': assumptions,
        'missing_inputs': missingInputs,
        'source_refs': sourceRefs,
      };
}
