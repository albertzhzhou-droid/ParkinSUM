/// Auditable inventory entry for a result-affecting ParkinSUM algorithm.
///
/// The registry deliberately covers code that can change a user-visible
/// classification, score, rank, gate, fallback, identity, or explanation.
/// Import/export plumbing and diagnostics that only report existing state are
/// outside this contract.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

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
  final String fixtureSchema;
  final String fixtureRevision;
  final String lifecycle;
  final String routeId;
  final String routeSourcePath;
  final String providerSourcePath;
  final Map<String, String> uiSurfaceKeysByAlgorithm;
  final List<String> executableTestPaths;

  const AlgorithmTraceProviderContract({
    required this.providerId,
    required this.algorithmIds,
    required this.fixtureSchema,
    required this.fixtureRevision,
    required this.lifecycle,
    required this.routeId,
    required this.routeSourcePath,
    required this.providerSourcePath,
    required this.uiSurfaceKeysByAlgorithm,
    required this.executableTestPaths,
  });

  Map<String, dynamic> toManifestJson() => {
    'provider_id': providerId,
    'algorithm_ids': [...algorithmIds]..sort(),
    'fixture_schema': fixtureSchema,
    'fixture_revision': fixtureRevision,
    'lifecycle': lifecycle,
    'route_id': routeId,
    'route_source_path': routeSourcePath,
    'provider_source_path': providerSourcePath,
    'ui_surface_keys_by_algorithm': Map.fromEntries(
      uiSurfaceKeysByAlgorithm.entries.toList()
        ..sort((left, right) => left.key.compareTo(right.key)),
    ),
    'executable_test_paths': [...executableTestPaths]..sort(),
  };
}

enum AlgorithmTraceSurfaceDisposition { productionTrace, staticContractOnly }

/// Versioned, content-addressed inventory of the UI trace surface.
///
/// A production trace means that a fixed synthetic fixture executes the real
/// application engine and emits an algorithm-bound trace node. It does not
/// imply clinical calibration. Every other registered algorithm remains
/// explicitly classified as a static audit contract rather than being
/// silently counted as live.
class AlgorithmTraceSurfaceManifest {
  static const String schema = 'parkinsum.algorithm-trace-surface-manifest/1';
  static const int schemaVersion = 1;

  final List<AlgorithmDescriptor> algorithms;
  final List<AlgorithmTraceProviderContract> providers;

  AlgorithmTraceSurfaceManifest({
    required Iterable<AlgorithmDescriptor> algorithms,
    required Iterable<AlgorithmTraceProviderContract> providers,
  }) : algorithms = List.unmodifiable(algorithms),
       providers = List.unmodifiable(providers) {
    _validate();
  }

  Set<String> get liveAlgorithmIds =>
      providers.expand((provider) => provider.algorithmIds).toSet();

  int get liveCount => liveAlgorithmIds.length;

  int get staticOnlyCount => algorithms.length - liveCount;

  AlgorithmTraceSurfaceDisposition dispositionFor(String algorithmId) =>
      liveAlgorithmIds.contains(algorithmId)
      ? AlgorithmTraceSurfaceDisposition.productionTrace
      : AlgorithmTraceSurfaceDisposition.staticContractOnly;

  Map<String, dynamic> get registrySurfacePayload => {
    'algorithms':
        algorithms
            .map(
              (algorithm) => {
                'algorithm_id': algorithm.id,
                'disposition': dispositionFor(algorithm.id).name,
                'trace_provider_id': algorithm.traceProviderId,
                'ui_descriptor_id': algorithm.uiDescriptorId,
                'static_visual_contract_id': algorithm.staticVisual.contractId,
                'source_paths': [...algorithm.sourcePaths]..sort(),
              },
            )
            .toList()
          ..sort(
            (left, right) => (left['algorithm_id'] as String).compareTo(
              right['algorithm_id'] as String,
            ),
          ),
  };

  String get registrySurfaceSha256 => _sha256Canonical(registrySurfacePayload);

  Map<String, dynamic> get canonicalPayload => {
    r'$schema': schema,
    'schema_version': schemaVersion,
    'classification_boundary':
        'production_trace means a fixed synthetic fixture executed the real '
        'application engine and emitted an algorithm-bound trace node; it is '
        'not clinical calibration, patient evidence, benefit, safety, or '
        'medical advice. static_contract_only means a visible, source-linked '
        'audit representation exists but no production scenario trace is '
        'claimed.',
    'algorithm_count': algorithms.length,
    'production_trace_count': liveCount,
    'static_contract_only_count': staticOnlyCount,
    'registry_surface_sha256': registrySurfaceSha256,
    'providers': providers.map((provider) => provider.toManifestJson()).toList()
      ..sort(
        (left, right) => (left['provider_id'] as String).compareTo(
          right['provider_id'] as String,
        ),
      ),
    'production_trace_algorithm_ids': [...liveAlgorithmIds]..sort(),
    'static_contract_only_algorithm_ids':
        algorithms
            .where((algorithm) => !liveAlgorithmIds.contains(algorithm.id))
            .map((algorithm) => algorithm.id)
            .toList()
          ..sort(),
  };

  String get canonicalJson => jsonEncode(_canonicalize(canonicalPayload));

  String get sha256Digest =>
      sha256.convert(utf8.encode(canonicalJson)).toString();

  Map<String, dynamic> toJson() => {
    ...canonicalPayload,
    'manifest_sha256': sha256Digest,
  };

  void _validate() {
    final registeredIds = algorithms.map((entry) => entry.id).toSet();
    if (registeredIds.length != algorithms.length) {
      throw StateError('Algorithm trace manifest contains duplicate ids.');
    }
    final claimedIds = <String>{};
    for (final provider in providers) {
      if (provider.algorithmIds.isEmpty ||
          provider.fixtureSchema.trim().isEmpty ||
          provider.fixtureRevision.trim().isEmpty ||
          provider.lifecycle.trim().isEmpty ||
          provider.routeId.trim().isEmpty) {
        throw StateError(
          '${provider.providerId} has incomplete lifecycle metadata.',
        );
      }
      final uiBoundIds = provider.uiSurfaceKeysByAlgorithm.keys.toSet();
      final providerIds = provider.algorithmIds.toSet();
      if (uiBoundIds.length != providerIds.length ||
          !uiBoundIds.containsAll(providerIds)) {
        throw StateError(
          '${provider.providerId} UI bindings do not match its algorithms.',
        );
      }
      for (final algorithmId in provider.algorithmIds) {
        if (!registeredIds.contains(algorithmId)) {
          throw StateError(
            '${provider.providerId} claims unknown $algorithmId.',
          );
        }
        if (!claimedIds.add(algorithmId)) {
          throw StateError(
            '$algorithmId is claimed by multiple trace providers.',
          );
        }
      }
    }
    for (final algorithm in algorithms) {
      final claimed = claimedIds.contains(algorithm.id);
      if (algorithm.hasLiveTrace != claimed) {
        throw StateError(
          '${algorithm.id} live flag differs from provider ownership.',
        );
      }
      if (claimed &&
          !providers.any(
            (provider) =>
                provider.providerId == algorithm.traceProviderId &&
                provider.algorithmIds.contains(algorithm.id),
          )) {
        throw StateError('${algorithm.id} points to the wrong trace provider.');
      }
    }
  }
}

String _sha256Canonical(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(_canonicalize(value)))).toString();

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is Iterable) return value.map(_canonicalize).toList();
  return value;
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
