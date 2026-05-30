/// Deterministic Mermaid renderer for the local ParkinSUM evidence graph.
///
/// Educational/research prototype only. Renders a simple, readable `flowchart`
/// from an `EvidenceGraph`. It emits no raw JSON dump, no PHI, and no
/// patient/subject/encounter or clinical-care fields — only the graph's node ids
/// + sanitized labels + edge relations.
library;

import '../entities/evidence_graph.dart';

class EvidenceGraphMermaidRenderer {
  const EvidenceGraphMermaidRenderer();

  /// Renders the graph to deterministic Mermaid `flowchart TD` text. Node order
  /// follows the graph's node order; edge order follows the graph's edge order.
  String render(EvidenceGraph graph) {
    final b = StringBuffer()
      ..writeln('%% ParkinSUM local evidence graph (synthetic/demo).')
      ..writeln(
          '%% Not a FHIR Provenance resource, not W3C PROV, not a patient '
          'record, not clinical validation.')
      ..writeln('flowchart TD');

    // Node declarations: `id["label (type)"]`, sanitized + deterministic.
    for (final node in graph.nodes) {
      final missing = node.isMissing ? ' [missing_artifact]' : '';
      b.writeln('  ${node.id}["${_sanitize(node.label)} '
          '(${_sanitize(node.type)})$missing"]');
    }

    // Edges: `from -->|type| to` in graph order.
    for (final edge in graph.edges) {
      b.writeln('  ${edge.from} -->|${_sanitize(edge.type)}| ${edge.to}');
    }

    return b.toString();
  }

  /// Strips characters that would break Mermaid or leak raw structure: quotes,
  /// brackets, pipes, and newlines collapse to safe single-space text.
  String _sanitize(String raw) {
    return raw
        .replaceAll(RegExp(r'[\r\n]+'), ' ')
        .replaceAll(RegExp(r'["\[\]\|{}<>]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
