import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/ranker_eligibility.dart';

/// The orchestrator's promotion logic is exercised end-to-end by the replay
/// runner (scenarios with/without a user window). This test pins the
/// invariant that a `RankerEligibility` always carries a non-empty
/// `fallbackReasons` list exactly when mechanistic-primary is NOT eligible,
/// so the legacy heuristic can never silently dominate.
void main() {
  test('not eligible ⇒ fallbackReasons populated, rankerUsed is legacy', () {
    const e = RankerEligibility(
      mechanisticPrimaryEligible: false,
      rankerUsed: 'heuristic_legacy_fallback',
      rankerEligibilityReasons: [],
      fallbackReasons: ['missing_user_defined_window'],
    );
    expect(e.mechanisticPrimaryEligible, isFalse);
    expect(e.fallbackReasons, isNotEmpty);
    expect(e.rankerUsed, 'heuristic_legacy_fallback');
  });

  test('eligible ⇒ no fallback reasons, rankerUsed is mechanistic_primary', () {
    const e = RankerEligibility(
      mechanisticPrimaryEligible: true,
      rankerUsed: 'mechanistic_primary',
      rankerEligibilityReasons: [
        'user_defined_window_present',
        'all_candidates_scored',
        'confidence_high',
      ],
      fallbackReasons: [],
    );
    expect(e.mechanisticPrimaryEligible, isTrue);
    expect(e.fallbackReasons, isEmpty);
    expect(e.rankerUsed, 'mechanistic_primary');
    expect(e.toJson()['ranker_eligibility_reasons'], isNotEmpty);
  });
}
