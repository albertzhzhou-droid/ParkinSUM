/// P4 — EvidenceGraphBuilder.
///
/// Educational/research prototype only. Synthetic/demo artifacts only. Builds a
/// deterministic **local** evidence/provenance graph from already-produced
/// ParkinSUM artifacts. It is NOT a FHIR Provenance resource, NOT a W3C PROV
/// export, NOT a patient record, not clinically calibrated, and not medical
/// advice. Inputs are parsed artifact maps (file I/O stays in the tool wrapper);
/// a missing input becomes a `missing_artifact` node, never a fabricated success.
library;

import 'dart:convert';

import '../entities/evidence_graph.dart';
import '../entities/rule_explanation.dart';

class EvidenceGraphInputs {
  /// Parsed `build/mechanistic_replay/latest.json`.
  final Map<String, dynamic>? replayReport;

  /// Parsed `build/source_quality_perturbation/latest.json`.
  final Map<String, dynamic>? sourceQualityReport;

  /// Parsed `build/release_snapshot/latest.json`.
  final Map<String, dynamic>? releaseSnapshot;

  /// `EvidenceTraceBundle.toJson()` (a synthetic/demo sample is fine).
  final Map<String, dynamic>? evidenceBundle;

  /// Optional parsed `build/public_demo_walkthrough/latest.json`.
  final Map<String, dynamic>? publicDemoWalkthrough;

  const EvidenceGraphInputs({
    this.replayReport,
    this.sourceQualityReport,
    this.releaseSnapshot,
    this.evidenceBundle,
    this.publicDemoWalkthrough,
  });
}

class EvidenceGraphBuilder {
  const EvidenceGraphBuilder();

  static const List<String> _limitations = [
    'Local educational traceability artifact composed from synthetic/demo artifacts only.',
    'Not a FHIR Provenance resource and not a W3C PROV export.',
    'Not a patient record; no patient/subject/encounter linkage.',
    'Not clinical validation; the model is not clinically calibrated.',
    'Missing inputs are represented as missing_artifact nodes, never fabricated.',
  ];

  EvidenceGraph build(
    EvidenceGraphInputs inputs, {
    String graphId = 'parkinsum-evidence-graph',
    String createdAt = 'synthetic-demo',
  }) {
    final nodes = <EvidenceGraphNode>[];
    final edges = <EvidenceGraphEdge>[];

    // --- Artifact-backed nodes (deterministic order) -----------------------
    final replay = _replayNode(inputs.replayReport);
    final sourceQuality = _sourceQualityNode(inputs.sourceQualityReport);
    final releaseSnapshot = _releaseSnapshotNode(inputs.releaseSnapshot);
    final bundle = _evidenceBundleNode(inputs.evidenceBundle);

    // --- Derived / structural nodes (always present) -----------------------
    const mechanisticLayer = EvidenceGraphNode(
      id: 'mechanistic_layer',
      type: 'mechanistic_layer',
      label: 'Mechanistic layer',
      summary: 'Deterministic, literature-informed educational conflict '
          'simulation (not clinically calibrated; no PK/PD prediction).',
      status: 'present',
    );
    const metadataGate = EvidenceGraphNode(
      id: 'metadata_completeness_gate',
      type: 'metadata_completeness_gate',
      label: 'Metadata completeness gate',
      summary: 'Grades completeness; widens uncertainty rather than faking '
          'precision. Missing is recorded, never coerced to zero.',
      status: 'present',
    );
    const authorityGate = EvidenceGraphNode(
      id: 'source_authority_gate',
      type: 'source_authority_gate',
      label: 'Source authority gate',
      summary: 'Official-in-jurisdiction outranks synthetic/seed; seed never '
          'overrides official. Source-quality signal only.',
      status: 'present',
    );
    const safetyBoundary = EvidenceGraphNode(
      id: 'safety_boundary',
      type: 'safety_boundary',
      label: 'Safety boundary',
      summary: RuleExplanation.defaultSafetyBoundary,
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      status: 'present',
    );
    const limitation = EvidenceGraphNode(
      id: 'limitation',
      type: 'limitation',
      label: 'Limitations',
      summary: 'Local evidence graph; synthetic/demo only; not FHIR/PROV '
          'conformant; not clinical validation; not clinically calibrated.',
      status: 'present',
    );

    // Optional walkthrough node (only when provided).
    final walkthrough = _walkthroughNode(inputs.publicDemoWalkthrough);

    nodes.addAll([
      replay,
      sourceQuality,
      releaseSnapshot,
      bundle,
      mechanisticLayer,
      metadataGate,
      authorityGate,
      if (walkthrough != null) walkthrough,
      safetyBoundary,
      limitation,
    ]);

    // --- Edges (deterministic order) ---------------------------------------
    var n = 0;
    EvidenceGraphEdge edge(String from, String to, String type, String label) =>
        EvidenceGraphEdge(
            id: 'e${(++n).toString().padLeft(2, '0')}',
            from: from,
            to: to,
            type: type,
            label: label);

    edges.addAll([
      // source-quality report → the two gates it exercises.
      edge('source_quality_report', 'source_authority_gate', 'checks',
          'perturbs source authority'),
      edge('source_quality_report', 'metadata_completeness_gate', 'checks',
          'perturbs metadata completeness'),
      // replay report → mechanistic layer.
      edge('replay_report', 'mechanistic_layer', 'reports',
          'deterministic replay of the engine'),
      // evidence bundle → mechanistic layer (pairs the inspired views).
      edge('evidence_trace_bundle', 'mechanistic_layer', 'links_to',
          'pairs inspired views over the same context'),
      // release snapshot → summarizes the reports + reports the boundary.
      edge('release_snapshot', 'replay_report', 'summarizes',
          'counts replay status'),
      edge('release_snapshot', 'source_quality_report', 'summarizes',
          'counts source-quality rows'),
      edge('release_snapshot', 'safety_boundary', 'reports',
          'carries the safety boundary'),
      if (walkthrough != null)
        edge('public_demo_walkthrough', 'release_snapshot', 'summarizes',
            'narrates the snapshot'),
    ]);

    // safety_boundary limits every major artifact (fixed order).
    for (final target in const [
      'replay_report',
      'source_quality_report',
      'release_snapshot',
      'evidence_trace_bundle',
      'mechanistic_layer',
    ]) {
      edges.add(edge('safety_boundary', target, 'limits',
          'non-prescriptive educational boundary'));
    }
    // limitation limits the reports (fixed order).
    for (final target in const [
      'replay_report',
      'source_quality_report',
      'release_snapshot',
    ]) {
      edges.add(edge('limitation', target, 'limits', 'recorded limitation'));
    }

    // Graph-level sourceRefs: union of node sourceRefs (sorted, deduped).
    final sourceRefs = <String>{
      for (final node in nodes) ...node.sourceRefs,
    }.toList(growable: false)
      ..sort();

    return EvidenceGraph(
      graphId: graphId,
      createdAt: createdAt,
      nodes: List.unmodifiable(nodes),
      edges: List.unmodifiable(edges),
      sourceRefs: sourceRefs,
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      notAdviceText: RuleExplanation.defaultNotAdvice,
      notClinicallyCalibrated: true,
      limitations: _limitations,
    );
  }

  EvidenceGraphNode _replayNode(Map<String, dynamic>? report) {
    if (report == null) {
      return const EvidenceGraphNode(
        id: 'replay_report',
        type: 'replay_report',
        label: 'Mechanistic replay report',
        summary:
            'missing_artifact: build/mechanistic_replay/latest.json not found.',
        missingness: {'artifact_present': false},
        status: kEvidenceGraphMissingArtifact,
      );
    }
    final passed = report['passed'];
    final total = report['total'];
    final cases = report['cases'];
    if (passed is! int || total is! int || cases is! List) {
      return const EvidenceGraphNode(
        id: 'replay_report',
        type: 'replay_report',
        label: 'Mechanistic replay report',
        summary: 'missing_artifact: malformed replay report.',
        missingness: {'artifact_present': false},
        status: kEvidenceGraphMissingArtifact,
      );
    }
    final refs = <String>{
      for (final c in cases)
        if (c is Map && c['source_refs'] is List)
          ...(c['source_refs'] as List).whereType<String>(),
    }.toList(growable: false)
      ..sort();
    return EvidenceGraphNode(
      id: 'replay_report',
      type: 'replay_report',
      label: 'Mechanistic replay report',
      summary: '$passed/$total deterministic synthetic scenarios passed '
          '(banned-phrase scanned).',
      sourceRefs: refs,
      metadata: {'passed': passed, 'total': total, 'scenarios': cases.length},
      status: 'present',
    );
  }

  EvidenceGraphNode _sourceQualityNode(Map<String, dynamic>? report) {
    if (report == null) {
      return const EvidenceGraphNode(
        id: 'source_quality_report',
        type: 'source_quality_report',
        label: 'Source-quality perturbation report',
        summary:
            'missing_artifact: build/source_quality_perturbation/latest.json not found.',
        missingness: {'artifact_present': false},
        status: kEvidenceGraphMissingArtifact,
      );
    }
    final rows = report['rows'];
    if (rows is! List) {
      return const EvidenceGraphNode(
        id: 'source_quality_report',
        type: 'source_quality_report',
        label: 'Source-quality perturbation report',
        summary: 'missing_artifact: malformed source-quality report.',
        missingness: {'artifact_present': false},
        status: kEvidenceGraphMissingArtifact,
      );
    }
    final systems = <String>{
      for (final r in rows)
        if (r is Map && r['source_system'] is String)
          r['source_system'] as String,
    }.toList(growable: false)
      ..sort();
    return EvidenceGraphNode(
      id: 'source_quality_report',
      type: 'source_quality_report',
      label: 'Source-quality perturbation report',
      summary: '${rows.length} rows: how scoring moves when only '
          'source/provenance quality changes (conflict overlap stays dominant).',
      metadata: {'rows': rows.length, 'source_systems': systems},
      status: 'present',
    );
  }

  EvidenceGraphNode _releaseSnapshotNode(Map<String, dynamic>? report) {
    if (report == null) {
      return const EvidenceGraphNode(
        id: 'release_snapshot',
        type: 'release_snapshot',
        label: 'Release snapshot',
        summary:
            'missing_artifact: build/release_snapshot/latest.json not found.',
        missingness: {'artifact_present': false},
        status: kEvidenceGraphMissingArtifact,
      );
    }
    final checks = report['checks'];
    final complete = report['complete'];
    return EvidenceGraphNode(
      id: 'release_snapshot',
      type: 'release_snapshot',
      label: 'Release snapshot',
      summary: 'Composed verification evidence '
          '(${complete == true ? 'all required checks resolved' : 'incomplete / missing_artifact present'}).',
      metadata: {
        if (checks is Map) 'checks': checks,
        'complete': complete == true,
      },
      status: 'present',
    );
  }

  EvidenceGraphNode _evidenceBundleNode(Map<String, dynamic>? bundle) {
    if (bundle == null) {
      return const EvidenceGraphNode(
        id: 'evidence_trace_bundle',
        type: 'evidence_trace_bundle',
        label: 'Evidence trace bundle',
        summary: 'missing_artifact: no EvidenceTraceBundle provided.',
        missingness: {'artifact_present': false},
        status: kEvidenceGraphMissingArtifact,
      );
    }
    final refs = (bundle['source_refs'] is List)
        ? (bundle['source_refs'] as List).whereType<String>().toList()
        : const <String>[];
    return EvidenceGraphNode(
      id: 'evidence_trace_bundle',
      type: 'evidence_trace_bundle',
      label: 'Evidence trace bundle',
      summary: 'Local, non-FHIR bundle pairing the inspired views (synthetic/'
          'demo; no patient/subject/encounter linkage).',
      sourceRefs: refs,
      metadata: {
        'bundle_type': bundle['bundle_type'],
        'conformance_status': bundle['conformance_status'],
        'phi_policy': bundle['phi_policy'],
      },
      status: 'present',
    );
  }

  EvidenceGraphNode? _walkthroughNode(Map<String, dynamic>? report) {
    if (report == null) return null;
    return EvidenceGraphNode(
      id: 'public_demo_walkthrough',
      type: 'public_demo_walkthrough',
      label: 'Public demo walkthrough',
      summary: 'Synthetic reviewer walkthrough composed from the other '
          'artifacts (no advice; no PHI).',
      metadata: {'doc_type': report['doc_type']},
      status: 'present',
    );
  }
}

/// Deterministic JSON encoder (stable key order via the model's `toJson`).
String encodeEvidenceGraph(EvidenceGraph graph) =>
    const JsonEncoder.withIndent('  ').convert(graph.toJson());
