import 'mechanistic_conflict_result.dart';
import 'time_axis_events.dart';

/// Score components for a single food candidate evaluated against a
/// user-defined next-meal time window.
class MechanisticCandidateScore {
  final String candidateFoodId;
  final String candidateName;
  final String regionalFoodLibraryRef;
  final UserDefinedMealWindow userDefinedWindow;
  final double modelCompatibilityScore; // 0..1, higher = lower modeled overlap
  final double conflictOverlapScore; // 0..1, higher = more modeled overlap
  final double uncertaintyPenalty; // 0..1
  final double nutritionDataCompleteness; // 0..1
  final ConfidenceBand confidenceBand;
  final List<String> explanation;
  final List<String> sourceRefs;
  final String safetyBoundary;
  final String notAdviceText;
  final MechanisticConflictResult? upstreamResult;
  final bool insufficientContext;

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
      };
}
