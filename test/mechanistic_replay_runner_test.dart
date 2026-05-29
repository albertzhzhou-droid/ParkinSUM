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

  test('multi-dose scenario reports per-event count and user-entered dosage',
      () {
    final report = runner.run();
    final md =
        report.cases.firstWhere((c) => c.scenarioId == 's04b_multidose_ir');
    expect(md.perEventCount, 2);
    // The user-entered dose is surfaced exactly (100 mg), never a default.
    expect(md.userEnteredDosage, '100 mg');
    expect(md.dosageContextComplete, isTrue);
  });

  test('ambiguous/empty dosage scenarios report incomplete dose context', () {
    final report = runner.run();
    for (final c in report.cases.where((c) =>
        c.scenarioId.startsWith('s08') ||
        c.scenarioId.startsWith('s09') ||
        c.scenarioId.startsWith('s10'))) {
      // No private default dose may be injected: these stay incomplete.
      expect(c.dosageContextComplete, isFalse,
          reason: '${c.scenarioId} must not claim a complete dose context');
    }
  });

  test('actual amino-acid scenario surfaces absolute competing LNAA grams', () {
    final report = runner.run();
    final c = report.cases
        .firstWhere((c) => c.scenarioId == 's22_amino_acid_actual_fields_mode');
    expect(c.aminoAcidDataMode, 'actualAminoAcidFields');
    expect(c.competingLnaaGrams, isNotNull);
    expect(c.partialAminoAcidData, isFalse);
    // Candidate scoring ran → the active scoring weight set is recorded.
    expect(c.scoringParameterSetId, 'next_meal_scoring.v1');
  });

  test('partial amino-acid scenario flags partial data', () {
    final report = runner.run();
    final c = report.cases
        .firstWhere((c) => c.scenarioId == 's32_partial_amino_acid_profile');
    expect(c.partialAminoAcidData, isTrue);
  });

  test('high-calorie meal scenario widens gastric uncertainty', () {
    final report = runner.run();
    final c = report.cases
        .firstWhere((c) => c.scenarioId == 's33_high_calorie_high_fat_meal');
    expect(
      c.gastricEmptyingAssumptions
          .any((a) => a.contains('ge.highcal.uncertainty_boost')),
      isTrue,
    );
    expect(c.mealComponentCount, greaterThanOrEqualTo(1));
    // Absorption openness profile was produced for the dose.
    expect(c.absorptionOpennessSampleCount, greaterThan(0));
    expect(c.absorptionPeakOpenness, isNotNull);
  });

  test('explicit-dose + actual-AA meal exposes dose-relative LNAA proxy', () {
    final report = runner.run();
    final c = report.cases.firstWhere(
        (c) => c.scenarioId == 's34_explicit_dose_dose_relative_lnaa');
    expect(c.doseRelativeLnaaAvailable, isTrue);
    expect(c.doseRelativeLnaaRatio, isNotNull);
  });

  test('serialized report is valid JSON and contains no banned phrases', () {
    final report = runner.run();
    final encoded = encodeReplayReport(report);
    expect(encoded, contains('"scenario_id"'));
    expect(encoded, contains('"competing_lnaa_grams"'));
    expect(encoded, contains('"scoring_parameter_set_id"'));
    expect(findBannedSubstrings(encoded), isEmpty);
  });
}
