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

/// Whether the engine produced a modeled result that may be interpreted.
///
/// A zero interaction score is a valid result only when [available]. The
/// remaining states are typed abstentions and must never be serialized or
/// displayed as a zero score, a `none` severity, or a zero-width model curve.
enum MechanisticResultAvailability {
  available,
  notApplicable,
  insufficient,
  blockedIntegrity,
}

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
    'layer_traces': layerTraces.map((e) => e.toJson()).toList(growable: false),
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

  // Per-event medication provenance bridged from CDSS metadata (additive;
  // null/0 when no metadata was attached). Provenance only — never a dose.
  final String? releaseTypeSource;
  final String? doseForm;
  final String? route;
  final bool levodopaComponentPresent;
  final int combinationComponentCount;
  final int labelSectionRefCount;
  final String? medicationSourceSystem;
  final String? medicationSourceDocId;
  final String? medicationMetadataCompleteness;

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
    this.releaseTypeSource,
    this.doseForm,
    this.route,
    this.levodopaComponentPresent = false,
    this.combinationComponentCount = 0,
    this.labelSectionRefCount = 0,
    this.medicationSourceSystem,
    this.medicationSourceDocId,
    this.medicationMetadataCompleteness,
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
    'release_type_source': releaseTypeSource,
    'dose_form': doseForm,
    'route': route,
    'levodopa_component_present': levodopaComponentPresent,
    'combination_component_count': combinationComponentCount,
    'label_section_ref_count': labelSectionRefCount,
    'medication_source_system': medicationSourceSystem,
    'medication_source_doc_id': medicationSourceDocId,
    'medication_metadata_completeness': medicationMetadataCompleteness,
  };
}

/// Top-level result returned by `MechanisticConflictEngine`.
class MechanisticConflictResult {
  final String id;
  final MechanisticInteractionType interactionType;

  /// Explicit output/abstention contract. This field is additive so existing
  /// producers of real modeled results remain source-compatible.
  final MechanisticResultAvailability _declaredAvailability;

  /// Legacy in-memory value retained for source compatibility. Consumers that
  /// can encounter an abstention must use [modeledInteractionScore]; the wire
  /// representation is null whenever [hasModeledOutput] is false.
  final double interactionScore; // 0..1 educational proxy

  /// Legacy in-memory value retained for source compatibility. Consumers that
  /// can encounter an abstention must use [modeledSeverityBand].
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
  }) : _declaredAvailability = MechanisticResultAvailability.available;

  /// The only construction path for abstentions. Output-bearing fields are
  /// fixed here rather than guarded by debug-only assertions, so a release
  /// build cannot fabricate an abstention that also carries model output.
  const MechanisticConflictResult._abstentionResult({
    required this.id,
    required this.interactionType,
    required MechanisticResultAvailability availability,
    required this.uncertaintyReasons,
    required this.sourceRefs,
    required this.limitationText,
    required this.safetyBoundary,
    required this.notAdviceText,
    required this.explanation,
  }) : assert(availability != MechanisticResultAvailability.available),
       _declaredAvailability = availability,
       interactionScore = 0.0,
       severityBand = SeverityBand.unknown,
       confidenceBand = ConfidenceBand.insufficient,
       primaryDrivers = const [],
       modeledTimelineWindows = const [],
       primaryEmptyingProfile = null,
       absorptionOpportunityWindow = null,
       competitionTimeline = null,
       perEventTraces = const [];

  /// Effective availability after enforcing the public result boundary.
  ///
  /// The public constructor remains source-compatible for modeled results,
  /// but a caller cannot make a malformed result executable merely by using
  /// that constructor. Invalid score/band/window or nested-provider structure
  /// is converted to an integrity block in release builds as well as tests.
  MechanisticResultAvailability get availability {
    if (_declaredAvailability == MechanisticResultAvailability.available &&
        structuralIntegrityReasons.isNotEmpty) {
      return MechanisticResultAvailability.blockedIntegrity;
    }
    return _declaredAvailability;
  }

  List<String> get structuralIntegrityReasons {
    if (_declaredAvailability != MechanisticResultAvailability.available) {
      return const [];
    }
    final reasons = <String>{};
    if (id.trim().isEmpty || id != id.trim()) {
      reasons.add('mechanistic_result.id_invalid');
    }
    if (!interactionScore.isFinite ||
        interactionScore < 0 ||
        interactionScore > 1) {
      reasons.add('mechanistic_result.interaction_score_invalid');
    } else if (_severityForScore(interactionScore) != severityBand) {
      reasons.add('mechanistic_result.severity_score_mismatch');
    }
    if (confidenceBand == ConfidenceBand.insufficient) {
      reasons.add('mechanistic_result.available_confidence_insufficient');
    }
    if (interactionType ==
            MechanisticInteractionType.insufficientMedicationContext ||
        interactionType == MechanisticInteractionType.insufficientMealContext) {
      reasons.add('mechanistic_result.available_interaction_type_invalid');
    }
    if (explanation.resultId != id) {
      reasons.add('mechanistic_result.explanation_result_id_mismatch');
    }
    if (modeledTimelineWindows.isEmpty) {
      reasons.add('mechanistic_result.modeled_windows_empty');
    } else if (modeledTimelineWindows.any(
      (window) => window.durationMinutes <= 0,
    )) {
      reasons.add('mechanistic_result.modeled_window_invalid');
    }
    if (primaryEmptyingProfile == null ||
        !primaryEmptyingProfile!.hasModeledOutput) {
      reasons.add('mechanistic_result.gastric_profile_unavailable');
    }
    if (absorptionOpportunityWindow == null ||
        !_validAbsorptionWindow(absorptionOpportunityWindow!)) {
      reasons.add('mechanistic_result.absorption_window_invalid');
    }
    if (competitionTimeline == null ||
        !_validCompetitionTimeline(competitionTimeline!)) {
      reasons.add('mechanistic_result.competition_timeline_invalid');
    }
    if (perEventTraces.isEmpty) {
      reasons.add('mechanistic_result.per_event_traces_empty');
    } else {
      final eventIds = <String>{};
      final primaryEvents = <MechanisticPerEventTrace>[];
      final validScores = <double>[];
      for (final trace in perEventTraces) {
        final eventId = trace.medicationEventId.trim();
        if (eventId.isEmpty) {
          reasons.add('mechanistic_result.per_event_id_empty');
        } else if (eventId != trace.medicationEventId) {
          reasons.add('mechanistic_result.per_event_id_not_canonical');
        } else if (!eventIds.add(eventId)) {
          reasons.add('mechanistic_result.per_event_id_duplicate');
        }
        if (!trace.interactionScore.isFinite ||
            trace.interactionScore < 0 ||
            trace.interactionScore > 1) {
          reasons.add('mechanistic_result.per_event_score_invalid');
        } else {
          validScores.add(trace.interactionScore);
        }
        final competitionBandIsValid = CompetitionBand.values.any(
          (value) =>
              value.name == trace.competitionBand &&
              value != CompetitionBand.unknown,
        );
        final delayedArrivalIsValid = DelayedArrivalLikelihood.values.any(
          (value) =>
              value.name == trace.delayedArrivalLikelihood &&
              value != DelayedArrivalLikelihood.unknown,
        );
        if (!trace.isLevodopa ||
            !const {
              'immediate',
              'immediate_release',
            }.contains(trace.releaseType) ||
            !competitionBandIsValid ||
            !delayedArrivalIsValid) {
          reasons.add('mechanistic_result.per_event_structure_invalid');
        }
        if (trace.combinationComponentCount < 0 ||
            trace.labelSectionRefCount < 0) {
          reasons.add('mechanistic_result.per_event_provenance_count_invalid');
        }
        if (trace.isPrimary) primaryEvents.add(trace);
      }
      if (primaryEvents.length != 1) {
        reasons.add('mechanistic_result.primary_event_count_invalid');
      }
      if (primaryEvents.length == 1 &&
          validScores.length == perEventTraces.length) {
        final primary = primaryEvents.single;
        final maximum = validScores.reduce((a, b) => a > b ? a : b);
        if (!_close(primary.interactionScore, maximum) ||
            !_close(interactionScore, primary.interactionScore)) {
          reasons.add('mechanistic_result.primary_event_score_mismatch');
        }
        if (absorptionOpportunityWindow != null &&
            absorptionOpportunityWindow!.medicationEventId !=
                primary.medicationEventId) {
          reasons.add(
            'mechanistic_result.absorption_primary_event_id_mismatch',
          );
        }
      }
    }
    return List.unmodifiable(reasons);
  }

  static bool _close(double left, double right) =>
      left.isFinite && right.isFinite && (left - right).abs() <= 1e-9;

  static SeverityBand _severityForScore(double score) {
    if (score >= 0.35) return SeverityBand.high;
    if (score >= 0.15) return SeverityBand.moderate;
    if (score > 0) return SeverityBand.low;
    return SeverityBand.none;
  }

  static bool _validAbsorptionWindow(AbsorptionOpportunityWindow window) {
    if (!window.hasModeledOutput ||
        window.window.durationMinutes <= 0 ||
        window.peakMinute < window.window.startMinute ||
        window.peakMinute > window.window.endMinute ||
        window.opennessProfile.isEmpty) {
      return false;
    }
    var previousMinute = window.opennessProfile.first.minute - 1;
    for (final sample in window.opennessProfile) {
      if (sample.minute <= previousMinute ||
          !sample.openness.isFinite ||
          sample.openness < 0 ||
          sample.openness > 1) {
        return false;
      }
      previousMinute = sample.minute;
    }
    return true;
  }

  static bool _validCompetitionTimeline(CompetitionPressureTimeline timeline) {
    if (!timeline.hasModeledOutput ||
        timeline.samples.isEmpty ||
        !timeline.peakPressure.isFinite ||
        timeline.peakPressure < 0 ||
        timeline.peakPressure > 1 ||
        !timeline.overlapWithAbsorptionWindow.isFinite ||
        timeline.overlapWithAbsorptionWindow < 0 ||
        timeline.overlapWithAbsorptionWindow > 1 ||
        timeline.competitionBand == CompetitionBand.unknown) {
      return false;
    }
    var previousMinute = timeline.samples.first.minute - 1;
    for (final sample in timeline.samples) {
      if (sample.minute <= previousMinute ||
          !sample.pressure.isFinite ||
          sample.pressure < 0 ||
          sample.pressure > 1) {
        return false;
      }
      previousMinute = sample.minute;
    }
    return true;
  }

  bool get hasModeledOutput =>
      availability == MechanisticResultAvailability.available;

  bool get isAbstention => !hasModeledOutput;

  /// Null is the only truthful numeric representation for an abstention.
  double? get modeledInteractionScore =>
      hasModeledOutput ? interactionScore : null;

  /// Null is the only truthful severity representation for an abstention.
  SeverityBand? get modeledSeverityBand =>
      hasModeledOutput ? severityBand : null;

  ConfidenceBand? get modeledConfidenceBand =>
      hasModeledOutput ? confidenceBand : null;

  /// Number of medication doses evaluated on the time axis.
  int get perEventCount => perEventTraces.length;

  /// Convenience constructor for insufficient-context results.
  factory MechanisticConflictResult.insufficientContext({
    required String id,
    required MechanisticInteractionType reason,
    required List<String> missingInputs,
    required List<String> sourceRefs,
  }) {
    return _abstention(
      id: id,
      reason: reason,
      reasons: missingInputs,
      sourceRefs: sourceRefs,
      availability: MechanisticResultAvailability.insufficient,
    );
  }

  /// The inputs are sufficiently identified to prove that they lie outside
  /// the currently supported model domain.
  factory MechanisticConflictResult.notApplicable({
    required String id,
    required MechanisticInteractionType reason,
    required List<String> reasonCodes,
    required List<String> sourceRefs,
  }) {
    return _abstention(
      id: id,
      reason: reason,
      reasons: reasonCodes,
      sourceRefs: sourceRefs,
      availability: MechanisticResultAvailability.notApplicable,
    );
  }

  /// The model was prevented from running because an integrity invariant or
  /// provenance contract failed. This is distinct from missing input and from
  /// a known out-of-domain input.
  factory MechanisticConflictResult.blockedIntegrity({
    required String id,
    required MechanisticInteractionType reason,
    required List<String> integrityReasons,
    required List<String> sourceRefs,
  }) {
    return _abstention(
      id: id,
      reason: reason,
      reasons: integrityReasons,
      sourceRefs: sourceRefs,
      availability: MechanisticResultAvailability.blockedIntegrity,
    );
  }

  static MechanisticConflictResult _abstention({
    required String id,
    required MechanisticInteractionType reason,
    required List<String> reasons,
    required List<String> sourceRefs,
    required MechanisticResultAvailability availability,
  }) {
    assert(availability != MechanisticResultAvailability.available);
    final explanation = MechanisticExplanation(
      resultId: id,
      layerTraces: const [],
      inputFieldsUsed: const [],
      missingOrUncertainInputs: reasons,
      sourceRefs: sourceRefs,
      limitationText: MechanisticExplanation.defaultLimitation,
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      notAdviceText: RuleExplanation.defaultNotAdvice,
    );
    return MechanisticConflictResult._abstentionResult(
      id: id,
      interactionType: reason,
      availability: availability,
      uncertaintyReasons: reasons,
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
    'result_availability': availability.name,
    'has_modeled_output': hasModeledOutput,
    'interaction_score': modeledInteractionScore,
    'severity_band': modeledSeverityBand?.name,
    'confidence_band': modeledConfidenceBand?.name,
    'primary_drivers': hasModeledOutput ? primaryDrivers : const <String>[],
    'modeled_timeline_windows':
        (hasModeledOutput ? modeledTimelineWindows : const <TimelineWindow>[])
            .map((e) => e.toJson())
            .toList(growable: false),
    'uncertainty_reasons': uncertaintyReasons,
    'abstention_reasons': isAbstention ? uncertaintyReasons : const <String>[],
    'source_refs': sourceRefs,
    'limitation_text': limitationText,
    'safety_boundary': safetyBoundary,
    'not_advice_text': notAdviceText,
    'explanation': explanation.toJson(),
    'primary_emptying_profile': hasModeledOutput
        ? primaryEmptyingProfile?.toJson()
        : null,
    'absorption_opportunity_window': hasModeledOutput
        ? absorptionOpportunityWindow?.toJson()
        : null,
    'competition_timeline': hasModeledOutput
        ? competitionTimeline?.toJson()
        : null,
    'per_event_count': hasModeledOutput ? perEventCount : 0,
    'per_event_traces':
        (hasModeledOutput ? perEventTraces : const <MechanisticPerEventTrace>[])
            .map((e) => e.toJson())
            .toList(growable: false),
  };
}
