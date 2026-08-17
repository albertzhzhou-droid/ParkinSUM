import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/mechanistic_replay_scenarios.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_replay_runner.dart';
import 'package:parkinsum_companion/domain/usecases/model_assumption_registry.dart';
import 'package:parkinsum_companion/domain/usecases/safe_copy_template_registry.dart';
import 'package:parkinsum_companion/domain/usecases/source_quality_perturbation_report.dart';

/// W3 — Documentation ↔ runtime consistency.
///
/// `docs/PUBLIC_VERIFICATION.md` tells reviewers the exact output to expect
/// ("41/41 scenarios passed", "13 rows"). Those numbers lived in prose only:
/// nothing compared them to what the code actually produces, and the matching
/// strings inside the composer tests are hand-fed *fixture inputs*, not
/// observed results. So adding a scenario would have silently invalidated the
/// published guide with every check still green.
///
/// These tests parse the numbers back out of the document and compare them to
/// live runtime values. The point is the ratchet, not the current values: if
/// you add a scenario, this fails until the guide is updated to match.
///
/// Educational prototype only; synthetic/demo data only.
void main() {
  const docPath = 'docs/PUBLIC_VERIFICATION.md';

  late String doc;

  setUpAll(() {
    final file = File(docPath);
    // A missing document is a failure, not a skip — the guide is the artifact
    // under test.
    expect(
      file.existsSync(),
      isTrue,
      reason: '$docPath is missing; the verification guide is required.',
    );
    doc = file.readAsStringSync();
  });

  /// Extracts the single capture group of [pattern], failing with context when
  /// the claim is absent so a silently-reworded doc cannot pass by vanishing.
  int claimedNumber(String label, RegExp pattern) {
    final match = pattern.firstMatch(doc);
    expect(
      match,
      isNotNull,
      reason:
          'Could not find the "$label" claim in $docPath (pattern: '
          '${pattern.pattern}). If the wording changed, update this test so '
          'the claim stays machine-checked rather than dropping the check.',
    );
    return int.parse(match!.group(1)!);
  }

  test('documented mechanistic replay scenario count matches runtime', () {
    final documentedProse = claimedNumber(
      'N synthetic scenarios',
      RegExp(r'replay suite \((\d+) synthetic'),
    );
    final documentedExpected = claimedNumber(
      'Mechanistic replay: N/N scenarios passed',
      RegExp(r'Mechanistic replay: (\d+)/\d+ scenarios passed'),
    );
    final actual = mechanisticReplayScenarios.length;

    expect(
      documentedProse,
      actual,
      reason:
          '$docPath says the suite holds $documentedProse scenarios, but '
          'mechanisticReplayScenarios holds $actual.',
    );
    expect(
      documentedExpected,
      actual,
      reason:
          '$docPath promises reviewers "$documentedExpected/$documentedExpected '
          'scenarios passed", but $actual scenarios ship.',
    );
  });

  test('the replay actually runs and passes every documented scenario', () {
    // Guards the other half: the doc could match the registry while the run
    // itself fails or skips cases.
    final report = MechanisticReplayRunner().run();
    expect(report.totalCount, mechanisticReplayScenarios.length);
    expect(
      report.passedCount,
      report.totalCount,
      reason: 'The guide promises every scenario passes.',
    );
  });

  test('documented source-quality row count matches runtime', () {
    final documented = claimedNumber(
      'Source-quality perturbation report: N rows',
      RegExp(r'Source-quality perturbation report: (\d+) rows'),
    );
    final actual = SourceQualityPerturbationReportRunner().run().rows.length;
    expect(
      documented,
      actual,
      reason:
          '$docPath promises $documented rows; the runner produced $actual.',
    );
  });

  test('documented verify:all gate count matches the gate inventory', () {
    final documented = claimedNumber(
      'All N gates passed',
      RegExp(r'All (\d+) gates passed'),
    );
    // Parsed from the composer itself rather than restated, so the two cannot
    // drift apart.
    final source = File('tool/run_verify_all.mjs').readAsStringSync();
    final gateEntries = RegExp(
      r"\{ id: '[a-z_]+', script:",
    ).allMatches(source).length;
    // +1 for the golden gate, which is declared separately from the list.
    expect(
      documented,
      gateEntries + 1,
      reason:
          '$docPath promises $documented gates; run_verify_all.mjs declares '
          '${gateEntries + 1}.',
    );
  });

  test('registry inventory counts stated in docs match runtime', () {
    // These registries are quoted in several documents; pin them so a change
    // surfaces as a test failure rather than as stale prose.
    expect(
      const SafeCopyTemplateRegistry().templates.length,
      greaterThan(0),
      reason: 'An empty copy registry would make the copy gate vacuous.',
    );
    expect(
      ModelAssumptionRegistry.all.length,
      greaterThan(0),
      reason: 'An empty assumption registry would make provenance vacuous.',
    );
    // Every assumption must carry the limitation text that makes it safe to
    // surface; an assumption without one must not reach a user surface.
    for (final assumption in ModelAssumptionRegistry.all) {
      expect(
        assumption.limitation.trim(),
        isNotEmpty,
        reason: 'Assumption ${assumption.sourceId} has no limitation text.',
      );
      expect(
        assumption.citationText.trim(),
        isNotEmpty,
        reason: 'Assumption ${assumption.sourceId} has no citation text.',
      );
    }
  });
}
