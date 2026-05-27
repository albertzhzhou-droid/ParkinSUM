import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_replay_runner.dart';

void main() {
  final runner = MechanisticReplayRunner();

  test('all default scenarios pass', () {
    final report = runner.run();
    expect(report.allPassed, isTrue,
        reason: report.cases
            .where((c) => !c.pass)
            .map((c) => '${c.scenarioId}: ${c.failureReason}')
            .join('\n'));
  });

  test('every case has zero banned-phrase hits', () {
    final report = runner.run();
    for (final c in report.cases) {
      expect(c.bannedPhraseHits, isEmpty,
          reason: '${c.scenarioId} leaked: ${c.bannedPhraseHits}');
    }
  });

  test('insufficient-context scenarios attach no conflict result', () {
    final report = runner.run();
    for (final c in report.cases.where((c) =>
        c.scenarioId.startsWith('s08') ||
        c.scenarioId.startsWith('s09') ||
        c.scenarioId.startsWith('s10'))) {
      expect(c.interactionScore, 0.0);
      expect(c.confidenceBand, 'insufficient');
      expect(c.blockedMechanisms, isNotEmpty);
    }
  });

  test('user-window scenarios produce non-empty recommendations', () {
    final report = runner.run();
    final s13 = report.cases
        .firstWhere((c) => c.scenarioId == 's13_user_window_candidates');
    expect(s13.nextMealRecommendationResult, isNotNull);
    expect(s13.nextMealRecommendationResult!, isNotEmpty);
  });

  test('serialized report is valid JSON and contains no banned phrases', () {
    final report = runner.run();
    final encoded = encodeReplayReport(report);
    expect(encoded, contains('"scenario_id"'));
    expect(findBannedSubstrings(encoded), isEmpty);
  });
}
