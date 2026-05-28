/// Explicit record of whether mechanistic-primary ranking was eligible and,
/// if not, why the legacy heuristic fallback was used. This makes it
/// impossible for the legacy `_levodopaWindowPenalty` to *silently* dominate:
/// whenever it determines order, `rankerUsed == heuristic_legacy_fallback`
/// and `fallbackReasons` is populated and surfaced in UI + replay.
library;

class RankerEligibility {
  final bool mechanisticPrimaryEligible;

  /// `mechanistic_primary` or `heuristic_legacy_fallback`.
  final String rankerUsed;

  /// Reasons the mechanistic-primary gate passed (when eligible).
  final List<String> rankerEligibilityReasons;

  /// Reasons the fallback was used (when not eligible). Empty when eligible.
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
