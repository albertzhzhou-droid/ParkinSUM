import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/ranker_eligibility.dart';

/// Pins the production decision-influence boundary: mechanistic output is an
/// inspectable trace and never silently changes recommendation order.
void main() {
  test('not eligible ⇒ fallbackReasons populated, rankerUsed is legacy', () {
    const e = RankerEligibility(
      mechanisticPrimaryEligible: false,
      rankerUsed: 'heuristic_legacy_fallback',
      rankerEligibilityReasons: [],
      fallbackReasons: [
        'missing_user_defined_window',
        'mechanistic_trace_only_not_validated_for_ranking',
      ],
    );
    expect(e.mechanisticPrimaryEligible, isFalse);
    expect(e.fallbackReasons, isNotEmpty);
    expect(e.rankerUsed, 'heuristic_legacy_fallback');
  });

  test('trace-ready still records the non-ranking boundary', () {
    const e = RankerEligibility(
      mechanisticPrimaryEligible: false,
      rankerUsed: 'heuristic_legacy_fallback',
      rankerEligibilityReasons: [
        'user_defined_window_present',
        'all_candidates_scored',
        'confidence_high',
      ],
      fallbackReasons: ['mechanistic_trace_only_not_validated_for_ranking'],
    );
    expect(e.mechanisticPrimaryEligible, isFalse);
    expect(
      e.fallbackReasons,
      contains('mechanistic_trace_only_not_validated_for_ranking'),
    );
    expect(e.rankerUsed, 'heuristic_legacy_fallback');
    expect(e.toJson()['ranker_eligibility_reasons'], isNotEmpty);
  });
}
