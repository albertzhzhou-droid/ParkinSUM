import 'absorption_opportunity.dart';
import 'amino_acid_competition.dart';
import 'gastric_emptying_profile.dart';
import 'rule_explanation.dart';
import 'time_axis_events.dart';

enum MechanisticInteractionType {
  foodLevodopaTimingOverlap,
  aminoAcidCompetitionProxy,
  delayedGastricArrival,
  insufficientMedicationContext,
  insufficientMealContext,
  noModeledInteraction,
}

enum SeverityBand { none, low, moderate, high, unknown }

enum ConfidenceBand { high, medium, low, insufficient }

/// Layer-by-layer trace recorded by the engine for the explainability output.
class MechanisticLayerTrace {
  final String layer;
  final List<String> inputsUsed;
  final List<String> assumptionsApplied;
  final String uncertaintyContribution;
  final String description;

  const MechanisticLayerTrace({
    required this.layer,
    required this.inputsUsed,
    required this.assumptionsApplied,
    required this.uncertaintyContribution,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
        'layer': layer,
        'inputs_used': inputsUsed,
        'assumptions_applied': assumptionsApplied,
        'uncertainty_contribution': uncertaintyContribution,
        'description': description,
      };
}

/// Structured, serializable explanation for the mechanistic engine result.
class MechanisticExplanation {
  final String resultId;
  final List<MechanisticLayerTrace> layerTraces;
  final List<String> inputFieldsUsed;
  final List<String> missingOrUncertainInputs;
  final List<String> sourceRefs;
  final String limitationText;
  final String safetyBoundary;
  final String notAdviceText;

  const MechanisticExplanation({
    required this.resultId,
    required this.layerTraces,
    required this.inputFieldsUsed,
    required this.missingOrUncertainInputs,
    required this.sourceRefs,
    required this.limitationText,
    required this.safetyBoundary,
    required this.notAdviceText,
  });

  static const String defaultLimitation =
      'Educational simulation. Individual gastrointestinal physiology, '
      'medication response, and dietary patterns vary. The model does not '
      'infer real pharmacokinetics for any person.';

  Map<String, dynamic> toJson() => {
        'result_id': resultId,
        'layer_traces':
            layerTraces.map((e) => e.toJson()).toList(growable: false),
        'input_fields_used': inputFieldsUsed,
        'missing_or_uncertain_inputs': missingOrUncertainInputs,
        'source_refs': sourceRefs,
        'limitation_text': limitationText,
        'safety_boundary': safetyBoundary,
        'not_advice_text': notAdviceText,
      };
}

/// Per-medication-event trace for the multi-dose time axis.
///
/// The engine evaluates EACH levodopa dose independently against the meal
/// timeline and aggregates with deterministic max-overlap (the highest-overlap
/// dose drives the primary score; a high-overlap dose is never averaged away).
/// Non-levodopa events are excluded from levodopa-specific scoring. These
/// traces keep every evaluated dose inspectable, with its own source refs and
/// uncertainty so nothing is collapsed into an opaque single number.
class MechanisticPerEventTrace {
  final String medicationEventId;
  final int medicationMinute;
  final bool isLevodopa;
  final String releaseType;

  /// The per-event interaction score (0..1 educational proxy).
  final double interactionScore;
  final String competitionBand;
  final String delayedArrivalLikelihood;

  /// True for the event selected as primary (max overlap).
  final bool isPrimary;
  final List<String> sourceRefs;
  final List<String> uncertaintyReasons;

  const MechanisticPerEventTrace({
    required this.medicationEventId,
    required this.medicationMinute,
    required this.isLevodopa,
    required this.releaseType,
    required this.interactionScore,
    required this.competitionBand,
    required this.delayedArrivalLikelihood,
    required this.isPrimary,
    required this.sourceRefs,
    required this.uncertaintyReasons,
  });

  Map<String, dynamic> toJson() => {
        'medication_event_id': medicationEventId,
        'medication_minute': medicationMinute,
        'is_levodopa': isLevodopa,
        'release_type': releaseType,
        'interaction_score': interactionScore,
        'competition_band': competitionBand,
        'delayed_arrival_likelihood': delayedArrivalLikelihood,
        'is_primary': isPrimary,
        'source_refs': sourceRefs,
        'uncertainty_reasons': uncertaintyReasons,
      };
}

/// Top-level result returned by `MechanisticConflictEngine`.
class MechanisticConflictResult {
  final String id;
  final MechanisticInteractionType interactionType;
  final double interactionScore; // 0..1 educational proxy
  final SeverityBand severityBand;
  final ConfidenceBand confidenceBand;
  final List<String> primaryDrivers;
  final List<TimelineWindow> modeledTimelineWindows;
  final List<String> uncertaintyReasons;
  final List<String> sourceRefs;
  final String limitationText;
  final String safetyBoundary;
  final String notAdviceText;
  final MechanisticExplanation explanation;
  final GastricEmptyingProfile? primaryEmptyingProfile;
  final AbsorptionOpportunityWindow? absorptionOpportunityWindow;
  final CompetitionPressureTimeline? competitionTimeline;

  /// Per-dose traces for the multi-dose time axis. Empty for insufficient
  /// results. Additive — existing consumers are unaffected.
  final List<MechanisticPerEventTrace> perEventTraces;

  const MechanisticConflictResult({
    required this.id,
    required this.interactionType,
    required this.interactionScore,
    required this.severityBand,
    required this.confidenceBand,
    required this.primaryDrivers,
    required this.modeledTimelineWindows,
    required this.uncertaintyReasons,
    required this.sourceRefs,
    required this.limitationText,
    required this.safetyBoundary,
    required this.notAdviceText,
    required this.explanation,
    this.primaryEmptyingProfile,
    this.absorptionOpportunityWindow,
    this.competitionTimeline,
    this.perEventTraces = const [],
  });

  /// Number of medication doses evaluated on the time axis.
  int get perEventCount => perEventTraces.length;

  /// Convenience constructor for insufficient-context results.
  factory MechanisticConflictResult.insufficientContext({
    required String id,
    required MechanisticInteractionType reason,
    required List<String> missingInputs,
    required List<String> sourceRefs,
  }) {
    final explanation = MechanisticExplanation(
      resultId: id,
      layerTraces: const [],
      inputFieldsUsed: const [],
      missingOrUncertainInputs: missingInputs,
      sourceRefs: sourceRefs,
      limitationText: MechanisticExplanation.defaultLimitation,
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      notAdviceText: RuleExplanation.defaultNotAdvice,
    );
    return MechanisticConflictResult(
      id: id,
      interactionType: reason,
      interactionScore: 0.0,
      severityBand: SeverityBand.unknown,
      confidenceBand: ConfidenceBand.insufficient,
      primaryDrivers: const [],
      modeledTimelineWindows: const [],
      uncertaintyReasons: missingInputs,
      sourceRefs: sourceRefs,
      limitationText: MechanisticExplanation.defaultLimitation,
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      notAdviceText: RuleExplanation.defaultNotAdvice,
      explanation: explanation,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'interaction_type': interactionType.name,
        'interaction_score': interactionScore,
        'severity_band': severityBand.name,
        'confidence_band': confidenceBand.name,
        'primary_drivers': primaryDrivers,
        'modeled_timeline_windows': modeledTimelineWindows
            .map((e) => e.toJson())
            .toList(growable: false),
        'uncertainty_reasons': uncertaintyReasons,
        'source_refs': sourceRefs,
        'limitation_text': limitationText,
        'safety_boundary': safetyBoundary,
        'not_advice_text': notAdviceText,
        'explanation': explanation.toJson(),
        'primary_emptying_profile': primaryEmptyingProfile?.toJson(),
        'absorption_opportunity_window': absorptionOpportunityWindow?.toJson(),
        'competition_timeline': competitionTimeline?.toJson(),
        'per_event_count': perEventCount,
        'per_event_traces':
            perEventTraces.map((e) => e.toJson()).toList(growable: false),
      };
}
