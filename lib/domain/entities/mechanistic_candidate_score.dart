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
  final bool insufficientContext;

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

  const MechanisticCandidateScore({
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
    required this.insufficientContext,
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
  });

  Map<String, dynamic> toJson() => {
        'candidate_food_id': candidateFoodId,
        'candidate_name': candidateName,
        'regional_food_library_ref': regionalFoodLibraryRef,
        'user_defined_window': userDefinedWindow.toJson(),
        'model_compatibility_score': modelCompatibilityScore,
        'conflict_overlap_score': conflictOverlapScore,
        'uncertainty_penalty': uncertaintyPenalty,
        'nutrition_data_completeness': nutritionDataCompleteness,
        'confidence_band': confidenceBand.name,
        'explanation': explanation,
        'source_refs': sourceRefs,
        'safety_boundary': safetyBoundary,
        'not_advice_text': notAdviceText,
        'insufficient_context': insufficientContext,
        'upstream_result': upstreamResult?.toJson(),
        'sample_count': sampleCount,
        'best_sampled_offset_minutes': bestSampledOffsetMinutes,
        'worst_case_conflict_overlap_score': worstCaseConflictOverlapScore,
        'best_case_conflict_overlap_score': bestCaseConflictOverlapScore,
        'average_conflict_overlap_score': averageConflictOverlapScore,
        'selected_conservative_score': selectedConservativeScore,
        'sampled_window_summary':
            sampledWindowSummary.map((s) => s.toJson()).toList(growable: false),
        'protein_distribution': proteinDistribution?.toJson(),
        'protein_redistribution_score': proteinRedistributionScore,
        'nutrition_adequacy_contribution': nutritionAdequacyContribution,
        'metadata_completeness_score': metadataCompletenessScore,
        'source_authority_score': sourceAuthorityScore,
        'jurisdiction_match_score': jurisdictionMatchScore,
        'provenance_quality_score': provenanceQualityScore,
        'final_candidate_score': finalCandidateScore,
        'source_system': sourceSystem,
        'jurisdiction': jurisdiction,
      };
}
