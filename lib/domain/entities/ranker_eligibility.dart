/// Explicit record of the recommendation-ranking boundary.
///
/// The current mechanistic model is trace-only, so it never changes production
/// ordering and [fallbackReasons] includes the stable trace-only reason. The
/// actual final order may still come from a separately consented local-AI
/// safe-whitelist rerank. Keeping the older eligibility field is wire-compatible
/// while making the mechanistic non-influence decision inspectable.
library;

class RankerEligibility {
  final bool mechanisticPrimaryEligible;

  /// Actual final-order producer: conservative heuristic or consented local AI.
  final String rankerUsed;

  /// Predicates that were sufficient to generate an educational trace.
  final List<String> rankerEligibilityReasons;

  /// Reasons the model did not affect recommendation order or abstained.
  final List<String> fallbackReasons;

  const RankerEligibility({
    required this.mechanisticPrimaryEligible,
    required this.rankerUsed,
    required this.rankerEligibilityReasons,
    required this.fallbackReasons,
  });

  Map<String, dynamic> toJson() => {
    'mechanistic_primary_eligible': mechanisticPrimaryEligible,
    'ranker_used': rankerUsed,
    'ranker_eligibility_reasons': rankerEligibilityReasons,
    'fallback_reasons': fallbackReasons,
  };
}
