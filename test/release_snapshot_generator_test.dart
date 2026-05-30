import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/usecases/release_snapshot_generator.dart';

import 'helpers/no_phi_json_assertions.dart';

/// P12 — ReleaseSnapshotGenerator. Pure transform over already-produced artifact
/// maps + injectable command results. Tests never run slow commands; they feed
/// fixture artifact JSON. Missing inputs must surface `missing_artifact`, never
/// fabricated success.
void main() {
  const gen = ReleaseSnapshotGenerator();

  // Minimal fixtures matching the real artifact shapes (no timestamps used).
  final replayFixture = {'passed': 41, 'total': 41, 'cases': []};
  final sourceQualityFixture = {
    'report_type': 'source_quality_perturbation',
    'rows': List.generate(13, (_) => {}),
  };
  final preflightFixture = {
    'counts': {'BLOCKER': 0, 'WARN': 23, 'INFO': 4},
    'pass': true,
  };

  ReleaseSnapshotInputs fullInputs() => ReleaseSnapshotInputs(
        analyzeStatus: 'clean',
        testCount: 460,
        testStatus: 'passed',
        replayReport: replayFixture,
        sourceQualityReport: sourceQualityFixture,
        preflightReport: preflightFixture,
        firestoreStatus: '13/13',
        capabilityMatrixSummary: 'see docs/CAPABILITY_MATRIX.md',
      );

  test('JSON is deterministic for identical inputs', () {
    final a = encodeReleaseSnapshot(gen.build(fullInputs()));
    final b = encodeReleaseSnapshot(gen.build(fullInputs()));
    expect(a, b);
  });

  test(
      'markdown includes test / replay / preflight / firestore / source-quality',
      () {
    final md = gen.build(fullInputs()).toMarkdown();
    expect(md, contains('passed (460 tests)'));
    expect(md, contains('passed (41/41 scenarios)'));
    expect(md, contains('pass (0 BLOCKER)'));
    expect(md, contains('13/13'));
    expect(md, contains('generated (13 rows)'));
  });

  test('snapshot carries the not-clinically-calibrated + synthetic statements',
      () {
    final json = gen.build(fullInputs()).toJson();
    expect(json['not_clinically_calibrated'], isTrue);
    expect(json['synthetic_demo_data_only'], isTrue);
    expect(json['no_medical_advice'], isTrue);
    expect(json['complete'], isTrue);
  });

  test('missing artifacts produce missing_artifact, not fabricated success',
      () {
    const empty = ReleaseSnapshotInputs();
    final snap = gen.build(empty);
    final json = snap.toJson();
    final checks = json['checks'] as Map;
    expect(checks['flutter_analyze'], kMissingArtifact);
    expect(checks['flutter_test'], kMissingArtifact);
    expect(checks['mechanistic_replay'], kMissingArtifact);
    expect(checks['source_quality_perturbation'], kMissingArtifact);
    expect(checks['public_preflight'], kMissingArtifact);
    expect(checks['firestore_rules_contract'], kMissingArtifact);
    // Live smoke is opt-in, not a missing failure.
    expect(checks['live_source_smoke'], 'skipped_opt_in');
    expect(snap.complete, isFalse);
  });

  test('malformed artifact (missing counts) does not fabricate success', () {
    final snap = gen.build(const ReleaseSnapshotInputs(
      preflightReport: {'pass': true}, // no counts → missing
      replayReport: {'passed': 'x'}, // wrong type → missing
    ));
    final checks = snap.toJson()['checks'] as Map;
    expect(checks['public_preflight'], kMissingArtifact);
    expect(checks['mechanistic_replay'], kMissingArtifact);
  });

  test('a failing preflight is reported as FAILED, not pass', () {
    final snap = gen.build(const ReleaseSnapshotInputs(
      preflightReport: {
        'counts': {'BLOCKER': 2}
      },
    ));
    expect((snap.toJson()['checks'] as Map)['public_preflight'],
        contains('FAILED'));
  });

  test('no banned medical-advice phrases; no-PHI key scan passes', () {
    final json = gen.build(fullInputs()).toJson();
    expect(findBannedSubstrings(jsonEncode(json)), isEmpty);
    expect(findBannedSubstrings(gen.build(fullInputs()).toMarkdown()), isEmpty);
    scanNoPhiKeys(json);
  });

  test('reuses shared safety copy', () {
    final json = gen.build(fullInputs()).toJson();
    expect(json['safety_boundary'], RuleExplanation.defaultSafetyBoundary);
    expect(json['not_advice_text'], RuleExplanation.defaultNotAdvice);
  });
}
