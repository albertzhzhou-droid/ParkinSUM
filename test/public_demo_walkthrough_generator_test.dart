import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/usecases/public_demo_walkthrough_generator.dart';
import 'package:parkinsum_companion/domain/usecases/release_snapshot_generator.dart'
    show kMissingArtifact;

import 'helpers/no_phi_json_assertions.dart';

/// P10 — PublicDemoWalkthroughGenerator. Pure transform over existing synthetic
/// artifact maps. Deterministic; missing artifacts surface `missing_artifact`;
/// the output carries the safety boundary and contains no advice phrasing and no
/// patient/subject/encounter KEYS.
void main() {
  const gen = PublicDemoWalkthroughGenerator();

  final replayFixture = {
    'passed': 41,
    'total': 41,
    'cases': [
      {'scenario_id': 's01', 'meal_context_completeness': 1.0},
      {'scenario_id': 's35', 'meal_context_completeness': 0.5},
    ],
  };
  final sourceQualityFixture = {
    'report_type': 'source_quality_perturbation',
    'rows': List.generate(13, (_) => {}),
  };
  final evidenceBundleFixture = {
    'bundle_type': 'parkinsum_local_evidence_trace_bundle',
    'conformance_status': 'local_not_fhir_bundle',
    'phi_policy': 'no_patient_no_subject_no_encounter',
  };

  PublicDemoWalkthroughInputs fullInputs() => PublicDemoWalkthroughInputs(
        replayReport: replayFixture,
        sourceQualityReport: sourceQualityFixture,
        evidenceBundle: evidenceBundleFixture,
        capabilityMatrixSummary: 'see docs/CAPABILITY_MATRIX.md',
      );

  test('markdown is deterministic for identical inputs', () {
    final a = gen.build(fullInputs()).toMarkdown();
    final b = gen.build(fullInputs()).toMarkdown();
    expect(a, b);
    final ja = encodePublicDemoWalkthrough(gen.build(fullInputs()));
    final jb = encodePublicDemoWalkthrough(gen.build(fullInputs()));
    expect(ja, jb);
  });

  test('walkthrough includes the safety boundary + not-calibrated section', () {
    final md = gen.build(fullInputs()).toMarkdown();
    expect(md, contains(RuleExplanation.defaultSafetyBoundary));
    expect(md, contains('Not clinically calibrated'));
    expect(md, contains('Not medical advice'));
    expect(md, contains('What this demo does NOT prove'));
  });

  test('walkthrough summarizes replay / source-quality / evidence bundle', () {
    final md = gen.build(fullInputs()).toMarkdown();
    expect(md, contains('41/41'));
    expect(md, contains('13 rows'));
    expect(md, contains('parkinsum_local_evidence_trace_bundle'));
    // Missingness summary counts reduced-completeness scenarios (1 of 2 here).
    expect(md, contains('1 of 2 replay scenarios'));
  });

  test('does not include unsafe advice phrases', () {
    final doc = gen.build(fullInputs());
    expect(findBannedSubstrings(doc.toMarkdown()), isEmpty);
    expect(findBannedSubstrings(jsonEncode(doc.toJson())), isEmpty);
  });

  test('does not contain PHI / patient / subject / encounter KEYS', () {
    // Key-level scan (the phi_policy VALUE may legitimately name what is omitted).
    scanNoPhiKeys(gen.build(fullInputs()).toJson());
  });

  test('missing artifacts surface missing_artifact, never fabricated', () {
    const empty = PublicDemoWalkthroughInputs();
    final doc = gen.build(empty);
    final json = doc.toJson();
    expect(json['source_quality_summary'], kMissingArtifact);
    expect(json['missingness_summary'], kMissingArtifact);
    expect(json['replay_summary'], kMissingArtifact);
    expect(json['evidence_bundle_summary'], kMissingArtifact);
    // Synthetic-input summary still renders, but with missing_artifact markers.
    expect(json['synthetic_input_summary'], contains(kMissingArtifact));
    // Still safe + boundary-bearing even when artifacts are absent.
    expect(json['not_clinically_calibrated'], isTrue);
    scanNoPhiKeys(json);
    expect(findBannedSubstrings(doc.toMarkdown()), isEmpty);
  });
}
