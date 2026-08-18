/// A serializable explanation tree node for one result-affecting algorithm.
///
/// Nodes carry the values consumed, the value emitted, evidence references,
/// and an adjacent interpretation boundary. This lets the UI explain a result
/// as a composed decision rather than as one opaque score.
class AlgorithmTraceNode {
  final String id;
  final String? algorithmId;
  final String? providerId;
  final String label;
  final List<String> inputs;
  final String output;
  final List<String> sourceRefs;
  final String limitation;
  final List<AlgorithmTraceNode> children;

  const AlgorithmTraceNode({
    required this.id,
    this.algorithmId,
    this.providerId,
    required this.label,
    required this.inputs,
    required this.output,
    required this.sourceRefs,
    required this.limitation,
    this.children = const [],
  }) : assert(
         (algorithmId == null) == (providerId == null),
         'Algorithm-bound trace nodes require a provider identity.',
       );

  int get nodeCount =>
      1 + children.fold<int>(0, (count, child) => count + child.nodeCount);

  Map<String, dynamic> toJson() => {
    'id': id,
    'algorithm_id': algorithmId,
    'provider_id': providerId,
    'label': label,
    'inputs': inputs,
    'output': output,
    'source_refs': sourceRefs,
    'limitation': limitation,
    'children': children.map((child) => child.toJson()).toList(growable: false),
  };
}
