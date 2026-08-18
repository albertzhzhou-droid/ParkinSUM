/// Auditable inventory entry for a result-affecting ParkinSUM algorithm.
///
/// The registry deliberately covers code that can change a user-visible
/// classification, score, rank, gate, fallback, identity, or explanation.
/// Import/export plumbing and diagnostics that only report existing state are
/// outside this contract.
library;

enum AlgorithmStage { normalize, model, decide, resolve, explain }

enum AlgorithmVisualization {
  liveCurve,
  liveTimeline,
  scoreBreakdown,
  decisionFlow,
  qualityMatrix,
  resolutionTable,
  provenanceGraph,
}

abstract final class AlgorithmTraceProviderIds {
  static const String productionObservatorySnapshot =
      'observatory.production-snapshot/1';
}

/// Executable declaration of a producer that binds production-derived trace
/// nodes to registered algorithm ids.
class AlgorithmTraceProviderContract {
  final String providerId;
  final List<String> algorithmIds;

  const AlgorithmTraceProviderContract({
    required this.providerId,
    required this.algorithmIds,
  });
}

/// Algorithm-specific static visual data rendered even when no provider trace
/// exists. The UI may choose icons/layout by [visualization], but these labels
/// and [contractId] are unique to the declared algorithm rather than a generic
/// icon being presented as live evidence.
class AlgorithmStaticVisual {
  final String contractId;
  final AlgorithmVisualization visualization;
  final String inputLabel;
  final String transformLabel;
  final String outputLabel;

  const AlgorithmStaticVisual({
    required this.contractId,
    required this.visualization,
    required this.inputLabel,
    required this.transformLabel,
    required this.outputLabel,
  });
}

class AlgorithmDescriptor {
  final String id;
  final String name;
  final AlgorithmStage stage;
  final AlgorithmVisualization visualization;
  final String sourcePath;
  final String userVisibleImpact;
  final String inputs;
  final String outputs;
  final bool hasLiveTrace;
  final String? traceProviderId;
  final String limitation;
  final List<String> additionalSourcePaths;

  const AlgorithmDescriptor({
    required this.id,
    required this.name,
    required this.stage,
    required this.visualization,
    required this.sourcePath,
    required this.userVisibleImpact,
    required this.inputs,
    required this.outputs,
    required this.hasLiveTrace,
    this.traceProviderId,
    required this.limitation,
    this.additionalSourcePaths = const [],
  }) : assert(
         hasLiveTrace == (traceProviderId != null),
         'Live trace declarations require exactly one provider identity.',
       );

  String get uiDescriptorId => 'algorithm-card-$id';

  List<String> get sourcePaths => [sourcePath, ...additionalSourcePaths];

  AlgorithmStaticVisual get staticVisual => AlgorithmStaticVisual(
    contractId: 'algorithm-static-visual/$id',
    visualization: visualization,
    inputLabel: inputs,
    transformLabel: name,
    outputLabel: outputs,
  );

  Map<String, dynamic> toManifestJson() => {
    'id': id,
    'name': name,
    'stage': stage.name,
    'visualization': visualization.name,
    'source_paths': sourcePaths,
    'ui_descriptor_id': uiDescriptorId,
    'static_visual_contract_id': staticVisual.contractId,
    'trace_provider_id': traceProviderId,
    'user_visible_impact': userVisibleImpact,
    'inputs': inputs,
    'outputs': outputs,
    'limitation': limitation,
  };
}
