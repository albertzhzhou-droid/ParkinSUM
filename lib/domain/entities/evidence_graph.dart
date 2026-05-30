/// P4 — local ParkinSUM **evidence graph** entities.
///
/// Educational/research prototype only. Synthetic/demo artifacts only. This is a
/// **local evidence graph**, **not a patient record**, **not** a FHIR
/// `Provenance` resource, and **not** a W3C PROV export. It carries no
/// clinical-validation claim, is not clinically calibrated, and is not medical
/// advice. It emits **no** patient / subject / encounter semantics.
///
/// Provenance concepts (FHIR Provenance, W3C PROV entities/activities/agents,
/// and FAIR traceability for tools/workflows) are used only as **inspiration**
/// for local educational traceability.
library;

/// Sentinel recorded when an expected artifact is absent (mirrors the snapshot
/// generator). A missing artifact becomes a node with this `status` — never a
/// fabricated success.
const String kEvidenceGraphMissingArtifact = 'missing_artifact';

/// Allowed node types (closed set).
const Set<String> kEvidenceGraphNodeTypes = {
  'source_document',
  'observation',
  'resolved_fact',
  'food_variant',
  'drug_variant',
  'metadata_completeness_gate',
  'source_authority_gate',
  'mechanistic_layer',
  'replay_report',
  'source_quality_report',
  'release_snapshot',
  'evidence_trace_bundle',
  'public_demo_walkthrough',
  'safety_boundary',
  'limitation',
};

/// Allowed edge types (closed set).
const Set<String> kEvidenceGraphEdgeTypes = {
  'derived_from',
  'uses',
  'summarizes',
  'explains',
  'checks',
  'limits',
  'reports',
  'links_to',
};

class EvidenceGraphNode {
  final String id;
  final String type;
  final String label;
  final String summary;
  final List<String> sourceRefs;
  final Map<String, dynamic> metadata;

  /// Missingness flags (e.g. `{'artifact_present': false}`). Missing is
  /// recorded, never coerced into a fabricated success.
  final Map<String, dynamic> missingness;

  /// Optional safety-boundary note attached to the node.
  final String? safetyBoundary;

  /// Optional status, e.g. `missing_artifact` / `present`.
  final String? status;

  const EvidenceGraphNode({
    required this.id,
    required this.type,
    required this.label,
    required this.summary,
    this.sourceRefs = const [],
    this.metadata = const {},
    this.missingness = const {},
    this.safetyBoundary,
    this.status,
  });

  bool get isMissing => status == kEvidenceGraphMissingArtifact;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'label': label,
        'summary': summary,
        'source_refs': sourceRefs,
        'metadata': metadata,
        'missingness': missingness,
        'safety_boundary': safetyBoundary,
        'status': status,
      };
}

class EvidenceGraphEdge {
  final String id;
  final String from;
  final String to;
  final String type;
  final String label;
  final List<String> sourceRefs;
  final Map<String, dynamic> metadata;

  const EvidenceGraphEdge({
    required this.id,
    required this.from,
    required this.to,
    required this.type,
    required this.label,
    this.sourceRefs = const [],
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'from': from,
        'to': to,
        'type': type,
        'label': label,
        'source_refs': sourceRefs,
        'metadata': metadata,
      };
}

/// A local ParkinSUM evidence graph. Deterministic JSON; no patient linkage.
class EvidenceGraph {
  static const String kGraphType = 'parkinsum_local_evidence_graph';
  static const String kConformanceStatus =
      'local_not_fhir_provenance_not_w3c_prov';
  static const String kPhiPolicy = 'no_patient_no_subject_no_encounter';

  final String graphId;

  /// Caller-supplied creation marker (deterministic in tests/tools; never a real
  /// patient timeline).
  final String createdAt;

  final List<EvidenceGraphNode> nodes;
  final List<EvidenceGraphEdge> edges;
  final List<String> sourceRefs;
  final String safetyBoundary;
  final String notAdviceText;
  final bool notClinicallyCalibrated;
  final List<String> limitations;

  const EvidenceGraph({
    required this.graphId,
    required this.createdAt,
    required this.nodes,
    required this.edges,
    required this.sourceRefs,
    required this.safetyBoundary,
    required this.notAdviceText,
    required this.notClinicallyCalibrated,
    required this.limitations,
  });

  Map<String, dynamic> toJson() => {
        'graph_type': kGraphType,
        'conformance_status': kConformanceStatus,
        'phi_policy': kPhiPolicy,
        'graph_id': graphId,
        'created_at': createdAt,
        'not_clinically_calibrated': notClinicallyCalibrated,
        'nodes': nodes.map((n) => n.toJson()).toList(growable: false),
        'edges': edges.map((e) => e.toJson()).toList(growable: false),
        'source_refs': sourceRefs,
        'safety_boundary': safetyBoundary,
        'not_advice_text': notAdviceText,
        'limitations': limitations,
      };
}
