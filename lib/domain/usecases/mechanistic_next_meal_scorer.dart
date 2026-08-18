import 'dart:math' as math;

import '../entities/algorithm_component_identity_witness.dart';
import '../entities/mechanistic_candidate_score.dart';
import '../entities/mechanistic_conflict_result.dart';
import '../entities/mechanistic_medication_applicability.dart';
import '../entities/meal_composition.dart';
import '../entities/protein_distribution.dart';
import '../entities/rule_explanation.dart';
import '../entities/time_axis_events.dart';
import 'mechanistic_conflict_engine.dart';
import 'meal_composition_normalizer.dart';
import 'next_meal_scoring_parameters.dart';
import 'protein_distribution_model.dart';

/// Description of a candidate food the recommender may evaluate. The caller
/// (UI / orchestrator) is responsible for sourcing these from the regional
/// food library; the scorer does not pick foods for the user.
class CandidateFood {
  final String id;
  final String name;
  final String regionalFoodLibraryRef;
  final List<FoodComponent> components;
  final MealPhysicalForm declaredPhysicalForm;

  const CandidateFood({
    required this.id,
    required this.name,
    required this.regionalFoodLibraryRef,
    required this.components,
    this.declaredPhysicalForm = MealPhysicalForm.unknown,
  });
}

/// Optional provenance metadata for a candidate food, supplied by the
/// catalog projection. All scores are 0..1; defaults are neutral (0.5) when
/// metadata is unavailable so the scorer never fakes high confidence.
final class CandidateMetadata {
  final double completeness;
  final double authorityScore;
  final double jurisdictionMatchScore;
  final double provenanceQuality;
  final String jurisdiction;

  CandidateMetadata({
    required this.completeness,
    required this.authorityScore,
    required this.jurisdictionMatchScore,
    required this.provenanceQuality,
    required this.jurisdiction,
  }) {
    final values = <String, double>{
      'completeness': completeness,
      'authorityScore': authorityScore,
      'jurisdictionMatchScore': jurisdictionMatchScore,
      'provenanceQuality': provenanceQuality,
    };
    for (final entry in values.entries) {
      if (!entry.value.isFinite || entry.value < 0 || entry.value > 1) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'Candidate metadata scores must be finite and in [0, 1].',
        );
      }
    }
  }
}

/// Evaluates next-meal candidates inside a user-defined time window.
///
/// Critical contract: the scorer NEVER picks the window. If the window or
/// medication context is missing, every candidate returns
/// `insufficient_context`.
///
/// Sampling strategy: deterministic multi-point sampling across the user
/// window (`max(5, ceil(window_minutes / 15))`, capped at 12). For each
/// candidate the worst-case overlap across samples is used as the
/// conservative ranking score; best, average, and per-sample summaries are
/// surfaced for trace/UI only.
class MechanisticNextMealScorer with RegisteredAlgorithmComponentIdentity {
  static const MechanisticMedicationApplicabilityPolicy _applicabilityPolicy =
      MechanisticMedicationApplicabilityPolicy();

  final MechanisticConflictEngine engine;
  final MealCompositionNormalizer normalizer;
  final ProteinDistributionModel proteinDistributionModel;

  /// Provenance-tagged scoring weights (injectable; defaults to the
  /// literature-informed set). Surfaced in the candidate score for reporting.
  final NextMealScoringParameterSet scoringParameters;

  static const int minSampleCount = 5;
  static const int maxSampleCount = 12;
  static const int sampleStrideMinutes = 15;

  MechanisticNextMealScorer({
    MechanisticConflictEngine? engine,
    MealCompositionNormalizer? normalizer,
    ProteinDistributionModel? proteinDistributionModel,
    NextMealScoringParameterSet? scoringParameters,
  }) : engine = engine ?? MechanisticConflictEngine(),
       normalizer = normalizer ?? MealCompositionNormalizer(),
       proteinDistributionModel =
           proteinDistributionModel ?? ProteinDistributionModel(),
       scoringParameters =
           scoringParameters ??
           NextMealScoringParameterSet.literatureInformedDefault() {
    // Reject malformed custom parameter graphs before any candidate can be
    // scored. This is a production boundary, not only an invariant-test helper:
    // non-finite, negative, out-of-range, duplicate-id, non-normalized, or
    // non-dominant weights cannot become an `available` numeric result.
    final parameterErrors = this.scoringParameters.validationErrors;
    if (parameterErrors.isNotEmpty) {
      throw ArgumentError.value(
        this.scoringParameters.id,
        'scoringParameters',
        'Invalid next-meal scoring parameter set: '
            '${parameterErrors.join(', ')}.',
      );
    }
  }

  List<MechanisticCandidateScore> score({
    required TimeAxisConflictContext baseContext,
    required Map<String, MealComposition> baseMealCompositionsById,
    required List<CandidateFood> candidates,
    UserDefinedMealWindow? userDefinedWindow,
    Map<String, CandidateMetadata>? candidateMetadata,
  }) {
    final window = userDefinedWindow ?? baseContext.userDefinedWindow;
    if (window == null) {
      return candidates
          .map(
            (c) => _insufficient(
              c,
              window: _placeholderWindow(),
              reason: 'user_defined_window_missing',
            ),
          )
          .toList(growable: false);
    }
    if (baseContext.medicationEvents.isEmpty) {
      return candidates
          .map(
            (c) => _insufficient(
              c,
              window: window,
              reason: 'medication_context_invalid',
            ),
          )
          .toList(growable: false);
    }
    final medicationApplicability = _applicabilityPolicy.evaluateContexts(
      baseContext.medicationEvents.map((event) => event.context),
    );
    if (!medicationApplicability.applicable) {
      final reason = medicationApplicability.reasonCodes.join(',');
      final availability =
          medicationApplicability.status ==
              MechanisticMedicationApplicabilityStatus.notApplicable
          ? MechanisticResultAvailability.notApplicable
          : MechanisticResultAvailability.insufficient;
      return candidates
          .map(
            (candidate) => _insufficient(
              candidate,
              window: window,
              reason: reason,
              availability: availability,
            ),
          )
          .toList(growable: false);
    }

    final sampleOffsets = _sampleOffsets(window);
    final scores = <MechanisticCandidateScore>[];
    for (final candidate in candidates) {
      scores.add(
        _scoreOne(
          candidate: candidate,
          baseContext: baseContext,
          baseMealCompositionsById: baseMealCompositionsById,
          userDefinedWindow: window,
          sampleOffsets: sampleOffsets,
          candidateMetadata: candidateMetadata,
        ),
      );
    }

    // Rank only candidates that produced modeled output. Abstentions retain
    // caller order after the ranked results and are never compared through
    // their legacy in-memory sentinel fields.
    final availableScores = scores
        .where((score) => !score.insufficientContext)
        .toList(growable: false);
    final abstainedScores = scores
        .where((score) => score.insufficientContext)
        .toList(growable: false);
    availableScores.sort((a, b) {
      final byFinal = b.finalCandidateScore.compareTo(a.finalCandidateScore);
      if (byFinal != 0) return byFinal;
      final byCompleteness = b.nutritionDataCompleteness.compareTo(
        a.nutritionDataCompleteness,
      );
      if (byCompleteness != 0) return byCompleteness;
      return a.candidateFoodId.compareTo(b.candidateFoodId);
    });
    return List.unmodifiable([...availableScores, ...abstainedScores]);
  }

  List<int> _sampleOffsets(UserDefinedMealWindow window) {
    final durationMinutes = window.window.endMinute - window.window.startMinute;
    if (durationMinutes <= 0) {
      return [window.window.startMinute];
    }
    var count = math.max(
      minSampleCount,
      (durationMinutes / sampleStrideMinutes).ceil(),
    );
    count = math.min(count, maxSampleCount);
    if (count < 2) return [window.window.startMinute];
    final step = durationMinutes / (count - 1);
    return List<int>.generate(
      count,
      (i) => window.window.startMinute + (i * step).round(),
      growable: false,
    );
  }

  MechanisticCandidateScore _scoreOne({
    required CandidateFood candidate,
    required TimeAxisConflictContext baseContext,
    required Map<String, MealComposition> baseMealCompositionsById,
    required UserDefinedMealWindow userDefinedWindow,
    required List<int> sampleOffsets,
    Map<String, CandidateMetadata>? candidateMetadata,
  }) {
    final candidateCompositionId = 'candidate_${candidate.id}';
    final collidesWithBaseComposition =
        baseMealCompositionsById.containsKey(candidateCompositionId) ||
        baseContext.mealEvents.any(
          (meal) => meal.compositionId == candidateCompositionId,
        );
    if (collidesWithBaseComposition) {
      return _insufficient(
        candidate,
        window: userDefinedWindow,
        availability: MechanisticResultAvailability.blockedIntegrity,
        reason: 'candidate_composition_id_collision($candidateCompositionId)',
      );
    }
    final composition = normalizer.normalize(
      mealId: candidateCompositionId,
      components: candidate.components,
      declaredPhysicalForm: candidate.declaredPhysicalForm,
    );

    final mergedCompositions = <String, MealComposition>{
      ...baseMealCompositionsById,
      composition.id: composition,
    };

    final samples = <MechanisticCandidateSampleSummary>[];
    final perSampleResults = <MechanisticConflictResult>[];
    for (final offset in sampleOffsets) {
      final candidateMealId = 'hypothetical_${candidate.id}_$offset';
      final ctx = _hypotheticalContext(
        baseContext: baseContext,
        candidate: candidate,
        compositionId: composition.id,
        candidateMinute: offset,
        candidateMealId: candidateMealId,
      );
      final result = engine.evaluate(
        context: ctx,
        mealCompositionsById: mergedCompositions,
        resultId: 'cand_${candidate.id}_$offset',
        preferredMealId: candidateMealId,
      );
      if (!result.hasModeledOutput) {
        return _insufficient(
          candidate,
          window: userDefinedWindow,
          availability: result.availability,
          reason: result.uncertaintyReasons.isEmpty
              ? 'upstream_${result.availability.name}'
              : result.uncertaintyReasons.join(','),
          upstreamResult: result,
        );
      }
      final modeledScore = result.modeledInteractionScore!;
      final modeledConfidence = result.modeledConfidenceBand!;
      perSampleResults.add(result);
      samples.add(
        MechanisticCandidateSampleSummary(
          offsetMinutes: offset - userDefinedWindow.window.startMinute,
          conflictOverlap: modeledScore,
          confidenceBand: modeledConfidence.name,
        ),
      );
    }

    // Conservative selection: pick the WORST-overlap sample as the ranking
    // score; capture best/average for trace.
    var worstIdx = 0;
    for (var i = 1; i < perSampleResults.length; i++) {
      if (perSampleResults[i].modeledInteractionScore! >
          perSampleResults[worstIdx].modeledInteractionScore!) {
        worstIdx = i;
      }
    }
    var bestIdx = 0;
    for (var i = 1; i < perSampleResults.length; i++) {
      if (perSampleResults[i].modeledInteractionScore! <
          perSampleResults[bestIdx].modeledInteractionScore!) {
        bestIdx = i;
      }
    }
    final worst = perSampleResults[worstIdx];
    final best = perSampleResults[bestIdx];

    final overlap = worst.modeledInteractionScore!;
    final bestOverlap = best.modeledInteractionScore!;
    final avgOverlap =
        perSampleResults
            .map((r) => r.modeledInteractionScore!)
            .fold<double>(0, (a, b) => a + b) /
        perSampleResults.length;

    final uncertaintyPenalty = switch (worst.modeledConfidenceBand!) {
      ConfidenceBand.high => 0.0,
      ConfidenceBand.medium => 0.1,
      ConfidenceBand.low => 0.25,
      ConfidenceBand.insufficient => 0.5,
    };
    final compatibility = (1.0 - overlap - 0.2 * uncertaintyPenalty).clamp(
      0.0,
      1.0,
    );

    // Protein-redistribution objective (NOT global protein minimization).
    final localHourHint = minuteToDateTime(
      userDefinedWindow.midpointMinute,
    ).toUtc().hour;
    final proteinScore = proteinDistributionModel.evaluate(
      ProteinDistributionContext(
        modeledOverlap: overlap,
        localHourHint: localHourHint,
        medicationContextValid: baseContext.medicationEvents.isNotEmpty,
        candidateProteinGrams: composition.proteinGrams,
      ),
    );
    final proteinTrace = proteinDistributionModel.toTrace(proteinScore);

    // Provenance / authority scores from candidate metadata (best-effort;
    // default to neutral when not provided).
    final meta = candidateMetadata?[candidate.id];
    final metadataCompleteness = meta?.completeness ?? 0.5;
    final sourceAuthority = meta?.authorityScore ?? 0.5;
    final jurisdictionMatch = meta?.jurisdictionMatchScore ?? 0.5;
    final provenanceQuality = meta?.provenanceQuality ?? 0.5;

    // Compose the final candidate score from the provenance-tagged weight set.
    // Conflict overlap dominates by design (see
    // `NextMealScoringParameterSet.conflictRemainsDominant`); redistribution,
    // adequacy, and provenance refine. Deterministic.
    final w = scoringParameters;
    final finalScore =
        (w.conflictOverlap.value * (1.0 - overlap) +
                w.proteinRedistribution.value *
                    proteinScore.redistributionScore +
                w.nutritionAdequacy.value * proteinScore.adequacy.contribution +
                w.metadataCompleteness.value * metadataCompleteness +
                w.sourceAuthority.value * sourceAuthority +
                w.jurisdictionMatch.value * jurisdictionMatch +
                w.provenanceQuality.value * provenanceQuality -
                w.uncertaintyPenalty.value * uncertaintyPenalty)
            .clamp(0.0, 1.0);

    final explanation = <String>[
      'Within the time window you provided, this candidate has a worst-case '
          'modeled overlap of ${(overlap * 100).toStringAsFixed(0)}% with '
          'the levodopa absorption opportunity (best-case '
          '${(bestOverlap * 100).toStringAsFixed(0)}%, average '
          '${(avgOverlap * 100).toStringAsFixed(0)}%) across '
          '${perSampleResults.length} sample points in the educational '
          'simulation.',
      'Modeled meal physical form: ${composition.mealPhysicalForm.name}.',
      'Composition completeness: '
          '${(composition.compositionCompleteness * 100).toStringAsFixed(0)}%.',
      if (worst.primaryDrivers.isNotEmpty)
        'Primary modeled drivers: ${worst.primaryDrivers.join(', ')}.',
      'Protein window role: ${proteinScore.windowRole.name} '
          '(redistribution score ${(proteinScore.redistributionScore * 100).toStringAsFixed(0)}%). '
          'This prototype models protein redistribution, not global protein '
          'minimization.',
      'Model sampling inside the user-provided window does not choose a '
          'meal time or provide dietary advice.',
    ];

    return MechanisticCandidateScore(
      candidateFoodId: candidate.id,
      candidateName: candidate.name,
      regionalFoodLibraryRef: candidate.regionalFoodLibraryRef,
      userDefinedWindow: userDefinedWindow,
      modelCompatibilityScore: compatibility,
      conflictOverlapScore: overlap,
      uncertaintyPenalty: uncertaintyPenalty,
      nutritionDataCompleteness: composition.compositionCompleteness,
      confidenceBand: worst.modeledConfidenceBand!,
      explanation: List.unmodifiable(explanation),
      sourceRefs: worst.sourceRefs,
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      notAdviceText: RuleExplanation.defaultNotAdvice,
      upstreamResult: worst,
      sampleCount: perSampleResults.length,
      bestSampledOffsetMinutes:
          sampleOffsets[bestIdx] - userDefinedWindow.window.startMinute,
      worstCaseConflictOverlapScore: overlap,
      bestCaseConflictOverlapScore: bestOverlap,
      averageConflictOverlapScore: avgOverlap,
      selectedConservativeScore: overlap,
      sampledWindowSummary: List.unmodifiable(samples),
      proteinDistribution: proteinTrace,
      proteinRedistributionScore: proteinScore.redistributionScore,
      nutritionAdequacyContribution: proteinScore.adequacy.contribution,
      metadataCompletenessScore: metadataCompleteness,
      sourceAuthorityScore: sourceAuthority,
      jurisdictionMatchScore: jurisdictionMatch,
      provenanceQualityScore: provenanceQuality,
      finalCandidateScore: finalScore,
      sourceSystem: candidate.regionalFoodLibraryRef,
      jurisdiction: meta?.jurisdiction ?? 'unknown',
      scoringParameterSetId: scoringParameters.id,
    );
  }

  MechanisticCandidateScore _insufficient(
    CandidateFood candidate, {
    required UserDefinedMealWindow window,
    required String reason,
    MechanisticResultAvailability availability =
        MechanisticResultAvailability.insufficient,
    MechanisticConflictResult? upstreamResult,
  }) {
    return MechanisticCandidateScore.abstention(
      candidateFoodId: candidate.id,
      candidateName: candidate.name,
      regionalFoodLibraryRef: candidate.regionalFoodLibraryRef,
      userDefinedWindow: window,
      availability: availability,
      explanation: [
        'The next-meal recommender does not produce a score for this '
            'candidate because: $reason.',
        'Upstream model status: ${availability.name}.',
        'This is not dietary or clinical advice.',
      ],
      sourceRefs:
          upstreamResult?.sourceRefs ??
          const ['src.dailymed.sinemet.label', 'src.fda.cds.guidance.2022'],
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      notAdviceText: RuleExplanation.defaultNotAdvice,
      upstreamResult: upstreamResult,
    );
  }

  UserDefinedMealWindow _placeholderWindow() => const UserDefinedMealWindow(
    window: TimelineWindow(startMinute: 0, endMinute: 0),
    source: 'placeholder_no_user_window',
  );

  TimeAxisConflictContext _hypotheticalContext({
    required TimeAxisConflictContext baseContext,
    required CandidateFood candidate,
    required String compositionId,
    required int candidateMinute,
    required String candidateMealId,
  }) {
    final mealEvents = [
      ...baseContext.mealEvents,
      MealTimelineEvent(
        id: candidateMealId,
        minute: candidateMinute,
        compositionId: compositionId,
        physicalForm: candidate.declaredPhysicalForm,
      ),
    ];
    return TimeAxisConflictContext(
      referenceMinute: baseContext.referenceMinute,
      medicationEvents: baseContext.medicationEvents,
      mealEvents: mealEvents,
      foodComponentEvents: baseContext.foodComponentEvents,
      userDefinedWindow: baseContext.userDefinedWindow,
      missingFields: baseContext.missingFields,
    );
  }
}
