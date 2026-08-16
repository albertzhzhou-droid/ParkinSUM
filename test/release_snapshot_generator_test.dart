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
  // Mirrors build/recommendation_scenario_replay/latest.json (synthetic only).
  final recommendationScenarioFixture = {
    'report_type': 'recommendation_scenario_replay',
    'dataset_version': 'local-ai-replay.2026-06.v1',
    'no_medical_advice': true,
    'cases': [
      {
        'case_id': 'replay_low_risk_next_meal',
        'decision_path': 'hybrid_local_ai',
        'gate_reasons': <String>[],
        'ai_preserved_candidate_set': true,
      },
      {
        'case_id': 'replay_safety_gate_blocks_local_ai',
        'decision_path': 'conservative_safety_gate',
        'gate_reasons': ['low-quality meal time'],
        'ai_preserved_candidate_set': true,
      },
    ],
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
    recommendationScenarioReport: recommendationScenarioFixture,
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
    },
  );

  test(
    'snapshot carries the not-clinically-calibrated + synthetic statements',
    () {
      final json = gen.build(fullInputs()).toJson();
      expect(json['not_clinically_calibrated'], isTrue);
      expect(json['synthetic_demo_data_only'], isTrue);
      expect(json['no_medical_advice'], isTrue);
      expect(json['complete'], isTrue);
    },
  );

  test('reviewer-facing Markdown uses real-care calibration wording', () {
    final md = gen.build(fullInputs()).toMarkdown();
    expect(md, contains('not calibrated for real care'));
    expect(md.toLowerCase(), isNot(contains('not clinically calibrated')));
    // The machine-readable compatibility key remains in JSON.
    expect(
      gen.build(fullInputs()).toJson()['not_clinically_calibrated'],
      isTrue,
    );
  });

  test(
    'missing artifacts produce missing_artifact, not fabricated success',
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
      expect(checks['recommendation_scenario_replay'], kMissingArtifact);
      expect(
        snap.toJson().containsKey('recommendation_scenario_replay_detail'),
        isFalse,
      );
      // Live smoke is opt-in, not a missing failure.
      expect(checks['live_source_smoke'], 'skipped_opt_in');
      expect(snap.complete, isFalse);
    },
  );

  test(
    'local AI scenario replay artifact is surfaced with invariant detail',
    () {
      final json = gen.build(fullInputs()).toJson();
      final checks = json['checks'] as Map;
      expect(
        checks['recommendation_scenario_replay'],
        'passed (2 cases, candidate-set invariant held)',
      );
      final detail = json['recommendation_scenario_replay_detail'] as Map;
      expect(
        detail['artifact_path'],
        'build/recommendation_scenario_replay/latest.json',
      );
      expect(detail['dataset_version'], 'local-ai-replay.2026-06.v1');
      expect(detail['case_count'], 2);
      expect(detail['all_preserved_candidate_set'], isTrue);
      expect(detail['blocked_cases_have_gate_reasons'], isTrue);
      expect(detail['declares_synthetic_scope'], isTrue);
    },
  );

  test('scenario replay invariant violation is reported as FAILED', () {
    final violated = {
      'dataset_version': 'v',
      'no_medical_advice': true,
      'cases': [
        {
          'case_id': 'c1',
          'decision_path': 'hybrid_local_ai',
          'gate_reasons': <String>[],
          'ai_preserved_candidate_set': false,
        },
      ],
    };
    final snap = gen.build(
      ReleaseSnapshotInputs(recommendationScenarioReport: violated),
    );
    final json = snap.toJson();
    expect(
      (json['checks'] as Map)['recommendation_scenario_replay'],
      contains('FAILED'),
    );
    expect(
      (json['recommendation_scenario_replay_detail']
          as Map)['all_preserved_candidate_set'],
      isFalse,
    );
  });

  test('blocked scenario without gate reasons is flagged in the detail', () {
    final silentBlock = {
      'dataset_version': 'v',
      'no_medical_advice': true,
      'cases': [
        {
          'case_id': 'c1',
          'decision_path': 'conservative_safety_gate',
          'gate_reasons': <String>[],
          'ai_preserved_candidate_set': true,
        },
      ],
    };
    final json = gen
        .build(ReleaseSnapshotInputs(recommendationScenarioReport: silentBlock))
        .toJson();
    expect(
      (json['recommendation_scenario_replay_detail']
          as Map)['blocked_cases_have_gate_reasons'],
      isFalse,
    );
  });

  test('malformed scenario replay artifact does not fabricate success', () {
    final snap = gen.build(
      const ReleaseSnapshotInputs(
        recommendationScenarioReport: {'dataset_version': 7, 'cases': 'x'},
      ),
    );
    expect(
      (snap.toJson()['checks'] as Map)['recommendation_scenario_replay'],
      kMissingArtifact,
    );
  });

  test('malformed artifact (missing counts) does not fabricate success', () {
    final snap = gen.build(
      const ReleaseSnapshotInputs(
        preflightReport: {'pass': true}, // no counts → missing
        replayReport: {'passed': 'x'}, // wrong type → missing
      ),
    );
    final checks = snap.toJson()['checks'] as Map;
    expect(checks['public_preflight'], kMissingArtifact);
    expect(checks['mechanistic_replay'], kMissingArtifact);
  });

  test('a failing preflight is reported as FAILED, not pass', () {
    final snap = gen.build(
      const ReleaseSnapshotInputs(
        preflightReport: {
          'counts': {'BLOCKER': 2},
        },
      ),
    );
    expect(
      (snap.toJson()['checks'] as Map)['public_preflight'],
      contains('FAILED'),
    );
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
