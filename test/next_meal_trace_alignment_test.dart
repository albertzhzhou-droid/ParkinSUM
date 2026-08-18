import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_candidate_score.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_conflict_result.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/features/next_meal/next_meal_page.dart';

void main() {
  test(
    'candidate traces follow authoritative heuristic recommendation order',
    () {
      final alignment = alignMechanisticCandidateTraces(
        recommendationFoodIds: const ['b', 'a'],
        candidateScores: [_score('a'), _score('b')],
      );

      expect(alignment.alignedScores.map((score) => score.candidateFoodId), [
        'b',
        'a',
      ]);
      expect(alignment.complete, isTrue);
    },
  );

  test('missing recommendation trace is omitted without guessing a row', () {
    final alignment = alignMechanisticCandidateTraces(
      recommendationFoodIds: const ['b', 'missing', 'a'],
      candidateScores: [_score('a'), _score('b')],
    );

    expect(alignment.alignedScores.map((score) => score.candidateFoodId), [
      'b',
      'a',
    ]);
    expect(alignment.missingRecommendationIds, ['missing']);
    expect(alignment.complete, isFalse);
  });

  test(
    'duplicate and extra traces are withheld instead of position-matched',
    () {
      final alignment = alignMechanisticCandidateTraces(
        recommendationFoodIds: const ['a'],
        candidateScores: [_score('a'), _score('a'), _score('extra')],
      );

      expect(alignment.alignedScores, isEmpty);
      expect(alignment.missingRecommendationIds, ['a']);
      expect(alignment.withheldCandidateIds, ['a', 'extra']);
      expect(alignment.complete, isFalse);
    },
  );
}

MechanisticCandidateScore _score(String id) =>
    MechanisticCandidateScore.abstention(
      candidateFoodId: id,
      candidateName: id,
      regionalFoodLibraryRef: 'synthetic',
      userDefinedWindow: const UserDefinedMealWindow(
        window: TimelineWindow(startMinute: 10, endMinute: 20),
        source: 'test',
      ),
      availability: MechanisticResultAvailability.insufficient,
      explanation: const ['Alignment-only fixture; no modeled output.'],
      sourceRefs: const [],
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      notAdviceText: RuleExplanation.defaultNotAdvice,
    );
