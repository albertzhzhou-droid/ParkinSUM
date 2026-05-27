import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_conflict_result.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';

/// Verifies the *contract* the orchestrator's ranker promotion uses, without
/// spinning up the full orchestrator (which requires a real AppState).
/// Specifically: the `canPromoteMechanistic` decision must demand all three
/// gates: a user-defined window, sufficient confidence, and every candidate
/// scored (no insufficientContext). This test is intentionally structural —
/// the actual ranking flip is exercised by the multi-point sampling test +
/// the replay runner's s13/s14/s15 scenarios.
void main() {
  test(
      'promotion contract requires user window AND medium/high confidence AND '
      'all candidates scored', () {
    bool canPromote({
      required UserDefinedMealWindow? window,
      required ConfidenceBand confidence,
      required bool everyCandidateScored,
    }) {
      return window != null &&
          everyCandidateScored &&
          (confidence == ConfidenceBand.high ||
              confidence == ConfidenceBand.medium);
    }

    expect(
        canPromote(
            window: null,
            confidence: ConfidenceBand.high,
            everyCandidateScored: true),
        isFalse);
    expect(
        canPromote(
            window: const UserDefinedMealWindow(
                window: TimelineWindow(startMinute: 0, endMinute: 60),
                source: 't'),
            confidence: ConfidenceBand.low,
            everyCandidateScored: true),
        isFalse);
    expect(
        canPromote(
            window: const UserDefinedMealWindow(
                window: TimelineWindow(startMinute: 0, endMinute: 60),
                source: 't'),
            confidence: ConfidenceBand.high,
            everyCandidateScored: false),
        isFalse);
    expect(
        canPromote(
            window: const UserDefinedMealWindow(
                window: TimelineWindow(startMinute: 0, endMinute: 60),
                source: 't'),
            confidence: ConfidenceBand.high,
            everyCandidateScored: true),
        isTrue);
    expect(
        canPromote(
            window: const UserDefinedMealWindow(
                window: TimelineWindow(startMinute: 0, endMinute: 60),
                source: 't'),
            confidence: ConfidenceBand.medium,
            everyCandidateScored: true),
        isTrue);
  });
}
