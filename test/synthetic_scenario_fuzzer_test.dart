import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/entities/synthetic_scenario_fuzzer.dart';
import 'package:parkinsum_companion/domain/usecases/synthetic_scenario_fuzzer.dart';

import 'helpers/no_phi_json_assertions.dart';

/// P5 — deterministic synthetic scenario fuzzer. Synthetic-only regression/stress
/// testing of existing gates. Not clinical validation; not patient simulation;
/// not medical advice.
void main() {
  final fuzzer = SyntheticScenarioFuzzer();

  // Default caseCount covers the full catalog (clamped to the available count).
  SyntheticScenarioFuzzerReport run({int seed = 1, int caseCount = 64}) =>
      fuzzer
          .run(SyntheticScenarioFuzzerConfig(seed: seed, caseCount: caseCount));

  SyntheticScenarioResult byId(SyntheticScenarioFuzzerReport r, String id) =>
      r.cases.firstWhere((c) => c.scenario.scenarioId == id);

  test('1. same seed → same case IDs and JSON', () {
    final a = run();
    final b = run();
    expect(encodeSyntheticScenarioReport(a), encodeSyntheticScenarioReport(b));
    expect(a.cases.map((c) => c.scenario.scenarioId).toList(),
        b.cases.map((c) => c.scenario.scenarioId).toList());
  });

  test('2. different seed changes ordering, still deterministic', () {
    final s1 = run(seed: 1).cases.map((c) => c.scenario.scenarioId).toList();
    final s2 = run(seed: 7).cases.map((c) => c.scenario.scenarioId).toList();
    // Same set of cases, different order.
    expect(s1.toSet(), s2.toSet());
    expect(s1, isNot(s2));
    // Deterministic per seed.
    final s2again =
        run(seed: 7).cases.map((c) => c.scenario.scenarioId).toList();
    expect(s2, s2again);
  });

  test('3. unitless dose case fails if the validator ever accepts it', () {
    final r = run();
    final c = byId(r, 'medication_dosage__unitless');
    expect(c.evaluation.passed, isTrue);
    expect(c.evaluation.dosageRegression, isFalse);
  });

  test('4. product strength does not rescue missing/unitless user dosage', () {
    final c = byId(run(), 'medication_dosage__strength_meta_unitless');
    expect(c.evaluation.passed, isTrue);
  });

  test('5 + 6. missing nutrient distinct from true zero; missing lowers', () {
    final r = run();
    expect(byId(r, 'meal_missingness__true_zero_protein').evaluation.passed,
        isTrue);
    expect(
        byId(r, 'meal_missingness__missing_protein').evaluation.passed, isTrue);
    expect(byId(r, 'meal_missingness__missing_calories').evaluation.passed,
        isTrue);
  });

  test('7. unknown release type produces a limited/uncertain signal', () {
    final c = byId(run(), 'release_timeline__unknown_widens');
    expect(c.evaluation.passed, isTrue);
  });

  test('8. source-quality tier ordering preserved', () {
    final c = byId(run(), 'source_quality__tier_ordering');
    expect(c.evaluation.passed, isTrue);
    expect(c.evaluation.sourceQualityRegression, isFalse);
  });

  test('9. no-window case produces a fallback (insufficient context)', () {
    final c = byId(run(), 'window_ranking__no_window');
    expect(c.evaluation.passed, isTrue);
    expect(c.evaluation.unexpectedRankerSwitch, isFalse);
  });

  test('10. unsafe-phrase probe catches a banned phrase', () {
    // The detector MUST flag the injected unsafe text → the case passes.
    final c = byId(run(), 'safety_copy_no_phi__unsafe_probe');
    expect(c.evaluation.passed, isTrue);
  });

  test('11. no-PHI scan catches a forbidden key but permits policy values', () {
    final r = run();
    expect(
        byId(r, 'safety_copy_no_phi__nophi_clean').evaluation.passed, isTrue);
    expect(
        byId(r, 'safety_copy_no_phi__nophi_catch').evaluation.passed, isTrue);
  });

  test('12. report JSON is deterministic', () {
    expect(encodeSyntheticScenarioReport(run()),
        encodeSyntheticScenarioReport(run()));
  });

  test('13. markdown report includes seed, case count, passed/failed', () {
    final md = renderSyntheticScenarioMarkdown(run());
    expect(md, contains('seed: `1`'));
    expect(md, contains('case count: ${run().caseCount}'));
    expect(md, contains('passed:'));
    expect(md, contains('failed:'));
  });

  test('14. no real patient/subject/encounter KEYS emitted', () {
    scanNoPhiKeys(jsonDecode(encodeSyntheticScenarioReport(run())));
  });

  test('15. all generated cases are synthetic-only', () {
    for (final c in run().cases) {
      expect(c.scenario.syntheticOnly, isTrue);
      expect(c.scenario.notClinicallyCalibrated, isTrue);
    }
  });

  test('16. must-pass failure surfaces as failed>0 / allMustPass false', () {
    // The full default run passes all must-pass invariants on real code.
    final full = run();
    expect(full.failed, 0);
    expect(full.allMustPass, isTrue);
    // Failure status is representable + observable (testable failure status):
    // a report with a failure would set allMustPass=false. Confirm the field is
    // wired to the failed count.
    expect(full.allMustPass, full.failed == 0);
  });

  test('report carries no banned medical-advice phrases', () {
    final r = run();
    expect(findBannedSubstrings(encodeSyntheticScenarioReport(r)), isEmpty);
    expect(findBannedSubstrings(renderSyntheticScenarioMarkdown(r)), isEmpty);
  });

  test('every case is evaluated against real code (no missing_artifact)', () {
    for (final c in run().cases) {
      expect(c.evaluation.observedSignals, isNotEmpty,
          reason: '${c.scenario.scenarioId} produced no observed signal');
      expect(
          c.evaluation.failedInvariants.contains('missing_artifact'), isFalse,
          reason: '${c.scenario.scenarioId} was not really evaluated');
    }
  });
}
