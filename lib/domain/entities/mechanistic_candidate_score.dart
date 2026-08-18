import 'mechanistic_conflict_result.dart';
import 'protein_distribution.dart';
import 'time_axis_events.dart';

/// One sample point inside the user-defined window. Multiple samples per
/// candidate let reviewers see how a candidate's modeled overlap varies
/// across the time window the user provided. The model does NOT use this
/// to recommend a specific eat-at time; the field exists for trace only.
class MechanisticCandidateSampleSummary {
  final int offsetMinutes;
  final double conflictOverlap;
  final String confidenceBand;

  const MechanisticCandidateSampleSummary({
    required this.offsetMinutes,
    required this.conflictOverlap,
    required this.confidenceBand,
  });

  Map<String, dynamic> toJson() => {
    'offset_minutes': offsetMinutes,
    'conflict_overlap': conflictOverlap,
    'confidence_band': confidenceBand,
  };
}

/// Score components for a single food candidate evaluated against a
/// user-defined next-meal time window.
class MechanisticCandidateScore {
  final String candidateFoodId;
  final String candidateName;
  final String regionalFoodLibraryRef;
  final UserDefinedMealWindow userDefinedWindow;
  final double modelCompatibilityScore;
  final double conflictOverlapScore;
  final double uncertaintyPenalty;
  final double nutritionDataCompleteness;
  final ConfidenceBand confidenceBand;
  final List<String> explanation;
  final List<String> sourceRefs;
  final String safetyBoundary;
  final String notAdviceText;
  final MechanisticConflictResult? upstreamResult;
  final MechanisticResultAvailability _declaredAvailability;

  /// Effective status after validating every result-bearing candidate field.
  /// A caller cannot make malformed numeric/sample data executable merely by
  /// using the public output constructor.
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
    final boundedScores = <String, double>{
      'model_compatibility_score': modelCompatibilityScore,
      'conflict_overlap_score': conflictOverlapScore,
      'uncertainty_penalty': uncertaintyPenalty,
      'nutrition_data_completeness': nutritionDataCompleteness,
      'worst_case_conflict_overlap_score': worstCaseConflictOverlapScore,
      'best_case_conflict_overlap_score': bestCaseConflictOverlapScore,
      'average_conflict_overlap_score': averageConflictOverlapScore,
      'selected_conservative_score': selectedConservativeScore,
      'protein_redistribution_score': proteinRedistributionScore,
      'nutrition_adequacy_contribution': nutritionAdequacyContribution,
      'metadata_completeness_score': metadataCompletenessScore,
      'source_authority_score': sourceAuthorityScore,
      'jurisdiction_match_score': jurisdictionMatchScore,
      'provenance_quality_score': provenanceQualityScore,
      'final_candidate_score': finalCandidateScore,
    };
    for (final entry in boundedScores.entries) {
      if (!entry.value.isFinite || entry.value < 0 || entry.value > 1) {
        reasons.add('mechanistic_candidate.${entry.key}_invalid');
      }
    }
    if (confidenceBand == ConfidenceBand.insufficient) {
      reasons.add('mechanistic_candidate.available_confidence_insufficient');
    }
    final windowDuration = userDefinedWindow.window.durationMinutes;
    if (windowDuration <= 0) {
      reasons.add('mechanistic_candidate.user_window_invalid');
    }
    if (sampleCount <= 0) {
      reasons.add('mechanistic_candidate.sample_count_invalid');
    }
    if (sampledWindowSummary.length != sampleCount) {
      reasons.add('mechanistic_candidate.sample_count_mismatch');
    }

    final validSamples = <MechanisticCandidateSampleSummary>[];
    for (final sample in sampledWindowSummary) {
      ConfidenceBand? parsedConfidence;
      for (final value in ConfidenceBand.values) {
        if (value.name == sample.confidenceBand) {
          parsedConfidence = value;
          break;
        }
      }
      if (!sample.conflictOverlap.isFinite ||
          sample.conflictOverlap < 0 ||
          sample.conflictOverlap > 1 ||
          sample.offsetMinutes < 0 ||
          sample.offsetMinutes > windowDuration ||
          parsedConfidence == null ||
          parsedConfidence == ConfidenceBand.insufficient) {
        reasons.add('mechanistic_candidate.sample_invalid');
      } else {
        validSamples.add(sample);
      }
    }
    if (validSamples.length == sampleCount && validSamples.isNotEmpty) {
      final overlaps = validSamples
          .map((sample) => sample.conflictOverlap)
          .toList(growable: false);
      final worst = overlaps.reduce((a, b) => a > b ? a : b);
      final best = overlaps.reduce((a, b) => a < b ? a : b);
      final average = overlaps.reduce((a, b) => a + b) / overlaps.length;
      bool close(double left, double right) =>
          left.isFinite && right.isFinite && (left - right).abs() <= 1e-9;
      if (!close(worstCaseConflictOverlapScore, worst) ||
          !close(bestCaseConflictOverlapScore, best) ||
          !close(averageConflictOverlapScore, average) ||
          !close(selectedConservativeScore, worst) ||
          !close(conflictOverlapScore, worst)) {
        reasons.add('mechanistic_candidate.sample_summary_mismatch');
      }
      final bestOffsetMatches = validSamples.any(
        (sample) =>
            sample.offsetMinutes == bestSampledOffsetMinutes &&
            close(sample.conflictOverlap, best),
      );
      if (!bestOffsetMatches) {
        reasons.add('mechanistic_candidate.best_sample_offset_mismatch');
      }
    }

    final proteinTrace = proteinDistribution;
    if (proteinTrace != null &&
        (!proteinTrace.optimizationActive ||
            !_isBounded(proteinTrace.redistributionScore) ||
            !_isBounded(proteinTrace.nutritionAdequacyContribution) ||
            !_close(
              proteinTrace.redistributionScore,
              proteinRedistributionScore,
            ) ||
            !_close(
              proteinTrace.nutritionAdequacyContribution,
              nutritionAdequacyContribution,
            ))) {
      reasons.add('mechanistic_candidate.protein_distribution_invalid');
    }
    final upstream = upstreamResult;
    if (upstream == null) {
      reasons.add('mechanistic_candidate.upstream_result_missing');
    } else if (!upstream.hasModeledOutput ||
        !_close(upstream.interactionScore, conflictOverlapScore) ||
        upstream.confidenceBand != confidenceBand) {
      reasons.add('mechanistic_candidate.upstream_result_mismatch');
    }
    if (upstream != null &&
        !upstream.id.startsWith('cand_${candidateFoodId}_')) {
      reasons.add('mechanistic_candidate.upstream_result_id_mismatch');
    }
    return List.unmodifiable(reasons);
  }

  static bool _isBounded(double value) =>
      value.isFinite && value >= 0 && value <= 1;

  static bool _close(double left, double right) =>
      left.isFinite && right.isFinite && (left - right).abs() <= 1e-9;

  bool get hasModeledOutput =>
      availability == MechanisticResultAvailability.available;

  bool get insufficientContext => !hasModeledOutput;

  double? get modeledModelCompatibilityScore =>
      hasModeledOutput ? modelCompatibilityScore : null;
  double? get modeledConflictOverlapScore =>
      hasModeledOutput ? conflictOverlapScore : null;
  double? get modeledUncertaintyPenalty =>
      hasModeledOutput ? uncertaintyPenalty : null;
  double? get modeledNutritionDataCompleteness =>
      hasModeledOutput ? nutritionDataCompleteness : null;
  ConfidenceBand? get modeledConfidenceBand =>
      hasModeledOutput ? confidenceBand : null;
  int? get modeledSampleCount => hasModeledOutput ? sampleCount : null;
  int? get modeledBestSampledOffsetMinutes =>
      hasModeledOutput ? bestSampledOffsetMinutes : null;
  double? get modeledWorstCaseConflictOverlapScore =>
      hasModeledOutput ? worstCaseConflictOverlapScore : null;
  double? get modeledBestCaseConflictOverlapScore =>
      hasModeledOutput ? bestCaseConflictOverlapScore : null;
  double? get modeledAverageConflictOverlapScore =>
      hasModeledOutput ? averageConflictOverlapScore : null;
  double? get modeledSelectedConservativeScore =>
      hasModeledOutput ? selectedConservativeScore : null;
  ProteinDistributionTrace? get modeledProteinDistribution =>
      hasModeledOutput ? proteinDistribution : null;
  double? get modeledProteinRedistributionScore =>
      hasModeledOutput ? proteinRedistributionScore : null;
  double? get modeledNutritionAdequacyContribution =>
      hasModeledOutput ? nutritionAdequacyContribution : null;
  double? get modeledMetadataCompletenessScore =>
      hasModeledOutput ? metadataCompletenessScore : null;
  double? get modeledSourceAuthorityScore =>
      hasModeledOutput ? sourceAuthorityScore : null;
  double? get modeledJurisdictionMatchScore =>
      hasModeledOutput ? jurisdictionMatchScore : null;
  double? get modeledProvenanceQualityScore =>
      hasModeledOutput ? provenanceQualityScore : null;
  double? get modeledFinalCandidateScore =>
      hasModeledOutput ? finalCandidateScore : null;

  // ---------------------------------------------------------------------------
  // Multi-point sampling fields (additive). Educational trace only — the
  // scorer never picks the user's meal time. `selectedConservativeScore`
  // equals `conflictOverlapScore` and is the value used for ranking.
  // ---------------------------------------------------------------------------
  final int sampleCount;
  final int bestSampledOffsetMinutes;
  final double worstCaseConflictOverlapScore;
  final double bestCaseConflictOverlapScore;
  final double averageConflictOverlapScore;
  final double selectedConservativeScore;
  final List<MechanisticCandidateSampleSummary> sampledWindowSummary;

  // Protein-redistribution + provenance scoring (additive).
  final ProteinDistributionTrace? proteinDistribution;
  final double proteinRedistributionScore;
  final double nutritionAdequacyContribution;
  final double metadataCompletenessScore; // 0..1
  final double sourceAuthorityScore; // 0..1
  final double jurisdictionMatchScore; // 0..1
  final double provenanceQualityScore; // 0..1
  final double finalCandidateScore; // 0..1, higher = better match
  final String sourceSystem;
  final String jurisdiction;

  /// Id of the scoring weight set that produced `finalCandidateScore`.
  /// Additive; enables replay reports to record which weights were active.
  final String scoringParameterSetId;

  MechanisticCandidateScore({
    required this.candidateFoodId,
    required this.candidateName,
    required this.regionalFoodLibraryRef,
    required this.userDefinedWindow,
    required this.modelCompatibilityScore,
    required this.conflictOverlapScore,
    required this.uncertaintyPenalty,
    required this.nutritionDataCompleteness,
    required this.confidenceBand,
    required this.explanation,
    required this.sourceRefs,
    required this.safetyBoundary,
    required this.notAdviceText,
    this.upstreamResult,
    this.sampleCount = 0,
    this.bestSampledOffsetMinutes = 0,
    this.worstCaseConflictOverlapScore = 0,
    this.bestCaseConflictOverlapScore = 0,
    this.averageConflictOverlapScore = 0,
    this.selectedConservativeScore = 0,
    this.sampledWindowSummary = const [],
    this.proteinDistribution,
    this.proteinRedistributionScore = 0,
    this.nutritionAdequacyContribution = 0,
    this.metadataCompletenessScore = 0,
    this.sourceAuthorityScore = 0,
    this.jurisdictionMatchScore = 0,
    this.provenanceQualityScore = 0,
    this.finalCandidateScore = 0,
    this.sourceSystem = 'unknown',
    this.jurisdiction = 'unknown',
    this.scoringParameterSetId = 'none',
  }) : _declaredAvailability = MechanisticResultAvailability.available;

  const MechanisticCandidateScore._abstention({
    required this.candidateFoodId,
    required this.candidateName,
    required this.regionalFoodLibraryRef,
    required this.userDefinedWindow,
    required MechanisticResultAvailability availability,
    required this.explanation,
    required this.sourceRefs,
    required this.safetyBoundary,
    required this.notAdviceText,
    this.upstreamResult,
    this.sourceSystem = 'unknown',
    this.jurisdiction = 'unknown',
    this.scoringParameterSetId = 'none',
  }) : _declaredAvailability = availability,
       modelCompatibilityScore = 0,
       conflictOverlapScore = 0,
       uncertaintyPenalty = 0,
       nutritionDataCompleteness = 0,
       confidenceBand = ConfidenceBand.insufficient,
       sampleCount = 0,
       bestSampledOffsetMinutes = 0,
       worstCaseConflictOverlapScore = 0,
       bestCaseConflictOverlapScore = 0,
       averageConflictOverlapScore = 0,
       selectedConservativeScore = 0,
       sampledWindowSummary = const [],
       proteinDistribution = null,
       proteinRedistributionScore = 0,
       nutritionAdequacyContribution = 0,
       metadataCompletenessScore = 0,
       sourceAuthorityScore = 0,
       jurisdictionMatchScore = 0,
       provenanceQualityScore = 0,
       finalCandidateScore = 0;

  factory MechanisticCandidateScore.abstention({
    required String candidateFoodId,
    required String candidateName,
    required String regionalFoodLibraryRef,
    required UserDefinedMealWindow userDefinedWindow,
    required MechanisticResultAvailability availability,
    required List<String> explanation,
    required List<String> sourceRefs,
    required String safetyBoundary,
    required String notAdviceText,
    MechanisticConflictResult? upstreamResult,
    String sourceSystem = 'unknown',
    String jurisdiction = 'unknown',
    String scoringParameterSetId = 'none',
  }) {
    if (availability == MechanisticResultAvailability.available) {
      throw ArgumentError.value(
        availability,
        'availability',
        'Use the output-bearing constructor for an available score.',
      );
    }
    if (upstreamResult != null &&
        (upstreamResult.hasModeledOutput ||
            upstreamResult.availability != availability)) {
      throw ArgumentError.value(
        upstreamResult.availability,
        'upstreamResult',
        'An abstained candidate may contain only an upstream abstention with '
            'the same availability.',
      );
    }
    return MechanisticCandidateScore._abstention(
      candidateFoodId: candidateFoodId,
      candidateName: candidateName,
      regionalFoodLibraryRef: regionalFoodLibraryRef,
      userDefinedWindow: userDefinedWindow,
      availability: availability,
      explanation: List.unmodifiable(explanation),
      sourceRefs: List.unmodifiable(sourceRefs),
      safetyBoundary: safetyBoundary,
      notAdviceText: notAdviceText,
      upstreamResult: upstreamResult,
      sourceSystem: sourceSystem,
      jurisdiction: jurisdiction,
      scoringParameterSetId: scoringParameterSetId,
    );
  }

  Map<String, dynamic> toJson() => {
    'candidate_food_id': candidateFoodId,
    'candidate_name': candidateName,
    'regional_food_library_ref': regionalFoodLibraryRef,
    'user_defined_window': userDefinedWindow.toJson(),
    'result_availability': availability.name,
    'has_modeled_output': hasModeledOutput,
    'model_compatibility_score': modeledModelCompatibilityScore,
    'conflict_overlap_score': modeledConflictOverlapScore,
    'uncertainty_penalty': modeledUncertaintyPenalty,
    'nutrition_data_completeness': modeledNutritionDataCompleteness,
    'confidence_band': modeledConfidenceBand?.name,
    'explanation': explanation,
    'source_refs': sourceRefs,
    'safety_boundary': safetyBoundary,
    'not_advice_text': notAdviceText,
    'insufficient_context': insufficientContext,
    // Defense in depth: constructors enforce this invariant at runtime, while
    // the wire boundary independently refuses to expose a contradictory nested
    // result if an object is ever produced through an unsafe migration path.
    'upstream_result': _consistentUpstreamResult?.toJson(),
    'sample_count': modeledSampleCount,
    'best_sampled_offset_minutes': modeledBestSampledOffsetMinutes,
    'worst_case_conflict_overlap_score': modeledWorstCaseConflictOverlapScore,
    'best_case_conflict_overlap_score': modeledBestCaseConflictOverlapScore,
    'average_conflict_overlap_score': modeledAverageConflictOverlapScore,
    'selected_conservative_score': modeledSelectedConservativeScore,
    'sampled_window_summary':
        (insufficientContext
                ? const <MechanisticCandidateSampleSummary>[]
                : sampledWindowSummary)
            .map((s) => s.toJson())
            .toList(growable: false),
    'protein_distribution': modeledProteinDistribution?.toJson(),
    'protein_redistribution_score': modeledProteinRedistributionScore,
    'nutrition_adequacy_contribution': modeledNutritionAdequacyContribution,
    'metadata_completeness_score': modeledMetadataCompletenessScore,
    'source_authority_score': modeledSourceAuthorityScore,
    'jurisdiction_match_score': modeledJurisdictionMatchScore,
    'provenance_quality_score': modeledProvenanceQualityScore,
    'final_candidate_score': modeledFinalCandidateScore,
    'source_system': sourceSystem,
    'jurisdiction': jurisdiction,
    'scoring_parameter_set_id': scoringParameterSetId,
  };

  MechanisticConflictResult? get _consistentUpstreamResult {
    final upstream = upstreamResult;
    if (upstream == null) return null;
    if (hasModeledOutput) {
      return upstream.hasModeledOutput ? upstream : null;
    }
    return !upstream.hasModeledOutput && upstream.availability == availability
        ? upstream
        : null;
  }
}
