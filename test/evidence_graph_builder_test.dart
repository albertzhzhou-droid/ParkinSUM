import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/evidence_graph.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/usecases/evidence_graph_builder.dart';
import 'package:parkinsum_companion/domain/usecases/evidence_graph_mermaid_renderer.dart';

import 'helpers/no_phi_json_assertions.dart';

/// P4 — local EvidenceGraphBuilder. Deterministic graph composed from existing
/// synthetic artifacts. Local evidence graph only — not a FHIR Provenance
/// resource, not W3C PROV, not a patient record, not clinical validation.
void main() {
  const builder = EvidenceGraphBuilder();
  const renderer = EvidenceGraphMermaidRenderer();

  final replayFixture = {
    'passed': 41,
    'total': 41,
    'cases': [
      {
        'scenario_id': 's01',
        'source_refs': ['src.nutt.lnaa.1989', 'src.dailymed.sinemet.label'],
      },
      {
        'scenario_id': 's02',
        'source_refs': ['src.contin.levodopa.pk.2010'],
      },
    ],
  };
  final sourceQualityFixture = {
    'report_type': 'source_quality_perturbation',
    'rows': List.generate(
      13,
      (i) => {'case_id': 'c$i', 'source_system': 'synthetic_demo'},
    ),
  };
  final releaseSnapshotFixture = {
    'snapshot_type': 'parkinsum_release_snapshot',
    'complete': true,
    'checks': {'mechanistic_replay': 'passed (41/41 scenarios)'},
  };
  final evidenceBundleFixture = {
    'bundle_type': 'parkinsum_local_evidence_trace_bundle',
    'conformance_status': 'local_not_fhir_bundle',
    'phi_policy': 'no_patient_no_subject_no_encounter',
    'source_refs': ['src.spl.identity'],
  };
  // Mirrors build/recommendation_scenario_replay/latest.json (synthetic only).
  final recommendationScenarioFixture = {
    'report_type': 'recommendation_scenario_replay',
    'dataset_version': 'local-ai-replay.2026-06.v1',
    'no_medical_advice': true,
    'cases': [
      {'case_id': 'c1', 'ai_preserved_candidate_set': true},
      {'case_id': 'c2', 'ai_preserved_candidate_set': true},
    ],
  };

  EvidenceGraphInputs fullInputs() => EvidenceGraphInputs(
    replayReport: replayFixture,
    sourceQualityReport: sourceQualityFixture,
    releaseSnapshot: releaseSnapshotFixture,
    evidenceBundle: evidenceBundleFixture,
    recommendationScenarioReport: recommendationScenarioFixture,
  );

  EvidenceGraphNode nodeById(EvidenceGraph g, String id) =>
      g.nodes.firstWhere((n) => n.id == id);

  bool hasEdge(EvidenceGraph g, String from, String to) =>
      g.edges.any((e) => e.from == from && e.to == to);

  test('1. builds a deterministic graph from all artifacts', () {
    final a = encodeEvidenceGraph(builder.build(fullInputs()));
    final b = encodeEvidenceGraph(builder.build(fullInputs()));
    expect(a, b);
    final g = builder.build(fullInputs());
    // All required node types present (none missing) when all artifacts exist.
    for (final id in const [
      'replay_report',
      'source_quality_report',
      'release_snapshot',
      'recommendation_scenario_replay',
      'evidence_trace_bundle',
      'mechanistic_layer',
      'metadata_completeness_gate',
      'source_authority_gate',
      'safety_boundary',
      'limitation',
    ]) {
      expect(
        nodeById(g, id).isMissing,
        isFalse,
        reason: '$id should be present',
      );
    }
  });

  test('Local-AI scenario replay node carries the invariant metadata', () {
    final g = builder.build(fullInputs());
    final node = nodeById(g, 'recommendation_scenario_replay');
    expect(node.metadata['dataset_version'], 'local-ai-replay.2026-06.v1');
    expect(node.metadata['cases'], 2);
    expect(node.metadata['all_preserved_candidate_set'], isTrue);
    expect(node.metadata['scope'], 'synthetic_local_ai_replay');
    // Edges: summarized by the release snapshot; supports AI-boundary review;
    // limited by the safety boundary.
    expect(
      hasEdge(g, 'release_snapshot', 'recommendation_scenario_replay'),
      isTrue,
    );
    expect(
      hasEdge(g, 'recommendation_scenario_replay', 'mechanistic_layer'),
      isTrue,
    );
    expect(
      hasEdge(g, 'safety_boundary', 'recommendation_scenario_replay'),
      isTrue,
    );
  });

  test('missing Local-AI scenario replay artifact creates a missing node', () {
    final g = builder.build(
      EvidenceGraphInputs(
        replayReport: replayFixture,
        sourceQualityReport: sourceQualityFixture,
        releaseSnapshot: releaseSnapshotFixture,
        evidenceBundle: evidenceBundleFixture,
      ),
    );
    final node = nodeById(g, 'recommendation_scenario_replay');
    expect(node.status, kEvidenceGraphMissingArtifact);
    expect(node.missingness['artifact_present'], isFalse);
  });

  test('2. missing replay artifact creates a missing_artifact node', () {
    final g = builder.build(
      EvidenceGraphInputs(
        sourceQualityReport: sourceQualityFixture,
        releaseSnapshot: releaseSnapshotFixture,
        evidenceBundle: evidenceBundleFixture,
      ),
    );
    final node = nodeById(g, 'replay_report');
    expect(node.status, kEvidenceGraphMissingArtifact);
    expect(node.missingness['artifact_present'], isFalse);
  });

  test(
    '3. missing source-quality artifact creates a missing_artifact node',
    () {
      final g = builder.build(
        EvidenceGraphInputs(
          replayReport: replayFixture,
          releaseSnapshot: releaseSnapshotFixture,
          evidenceBundle: evidenceBundleFixture,
        ),
      );
      expect(
        nodeById(g, 'source_quality_report').status,
        kEvidenceGraphMissingArtifact,
      );
    },
  );

  test('4. missing release snapshot creates a missing_artifact node', () {
    final g = builder.build(
      EvidenceGraphInputs(
        replayReport: replayFixture,
        sourceQualityReport: sourceQualityFixture,
        evidenceBundle: evidenceBundleFixture,
      ),
    );
    expect(
      nodeById(g, 'release_snapshot').status,
      kEvidenceGraphMissingArtifact,
    );
  });

  test('5. graph preserves sourceRefs (replay + bundle unioned)', () {
    final g = builder.build(fullInputs());
    expect(
      nodeById(g, 'replay_report').sourceRefs,
      containsAll(['src.nutt.lnaa.1989', 'src.contin.levodopa.pk.2010']),
    );
    expect(g.sourceRefs, contains('src.spl.identity'));
    expect(g.sourceRefs, contains('src.nutt.lnaa.1989'));
    // Deterministic (sorted) ordering.
    final sorted = [...g.sourceRefs]..sort();
    expect(g.sourceRefs, sorted);
  });

  test('6. graph includes safety boundary + limitation nodes', () {
    final g = builder.build(fullInputs());
    expect(
      nodeById(g, 'safety_boundary').safetyBoundary,
      RuleExplanation.defaultSafetyBoundary,
    );
    expect(nodeById(g, 'limitation').type, 'limitation');
    expect(g.limitations, isNotEmpty);
  });

  test('human-facing summaries use real-care calibration wording', () {
    final g = builder.build(fullInputs());
    final humanText = [
      for (final node in g.nodes) node.summary,
      ...g.limitations,
    ].join('\n').toLowerCase();
    expect(humanText, contains('not calibrated for real care'));
    expect(humanText, isNot(contains('not clinically calibrated')));
    // The machine-readable compatibility field remains in JSON.
    expect(g.toJson()['not_clinically_calibrated'], isTrue);
  });

  test('7. no patient / subject / encounter / clinical-workflow KEYS', () {
    // Recursive key-level scan (phi_policy VALUE may name what is omitted).
    scanNoPhiKeys(builder.build(fullInputs()).toJson());
  });

  test('8. does not claim FHIR Provenance or W3C PROV conformance', () {
    final json = builder.build(fullInputs()).toJson();
    expect(json['graph_type'], 'parkinsum_local_evidence_graph');
    expect(
      json['conformance_status'],
      'local_not_fhir_provenance_not_w3c_prov',
    );
    final encoded = jsonEncode(json);
    expect(encoded.contains('"resourceType"'), isFalse);
    expect(encoded.toLowerCase().contains('"resourcetype"'), isFalse);
  });

  test('9. Mermaid renderer is deterministic', () {
    final g = builder.build(fullInputs());
    expect(renderer.render(g), renderer.render(g));
  });

  test('10. Mermaid output contains no unsafe medical-advice phrases', () {
    final mmd = renderer.render(builder.build(fullInputs()));
    expect(findBannedSubstrings(mmd), isEmpty);
    expect(mmd, contains('flowchart TD'));
    // No raw JSON dump leaked into the diagram.
    expect(mmd.contains('{'), isFalse);
  });

  test('11. JSON output is deterministic', () {
    expect(
      encodeEvidenceGraph(builder.build(fullInputs())),
      encodeEvidenceGraph(builder.build(fullInputs())),
    );
  });

  test('12. links source-quality report to both gates', () {
    final g = builder.build(fullInputs());
    expect(
      hasEdge(g, 'source_quality_report', 'source_authority_gate'),
      isTrue,
    );
    expect(
      hasEdge(g, 'source_quality_report', 'metadata_completeness_gate'),
      isTrue,
    );
  });

  test('13. links replay report to the mechanistic layer', () {
    final g = builder.build(fullInputs());
    expect(hasEdge(g, 'replay_report', 'mechanistic_layer'), isTrue);
  });

  test('14. links release snapshot to verification + safety boundary', () {
    final g = builder.build(fullInputs());
    expect(hasEdge(g, 'release_snapshot', 'replay_report'), isTrue);
    expect(hasEdge(g, 'release_snapshot', 'safety_boundary'), isTrue);
  });

  test('all edges reference declared node ids (no dangling edges)', () {
    final g = builder.build(fullInputs());
    final ids = g.nodes.map((n) => n.id).toSet();
    for (final e in g.edges) {
      expect(ids.contains(e.from), isTrue, reason: 'dangling from: ${e.from}');
      expect(ids.contains(e.to), isTrue, reason: 'dangling to: ${e.to}');
      expect(kEvidenceGraphEdgeTypes.contains(e.type), isTrue);
    }
    for (final node in g.nodes) {
      expect(kEvidenceGraphNodeTypes.contains(node.type), isTrue);
    }
  });

  test('no banned phrases in the full serialized graph', () {
    expect(
      findBannedSubstrings(encodeEvidenceGraph(builder.build(fullInputs()))),
      isEmpty,
    );
  });
}
