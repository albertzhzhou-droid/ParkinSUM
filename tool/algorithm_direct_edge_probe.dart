import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:crypto/crypto.dart';
import 'package:parkinsum_companion/domain/entities/algorithm_dependency_compatibility.dart';
import 'package:parkinsum_companion/domain/entities/algorithm_result_root_manifest.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_registry.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

const algorithmDirectEdgeProbeSchema =
    'parkinsum.algorithm-direct-edge-probe/14';
const algorithmDirectEdgeProbeGenerator =
    'parkinsum.algorithm-direct-edge-probe-generator/14';
const algorithmDirectEdgeProbeHeld = 'held_pending_full_dependency_closure';
const _maxRoots = 128;
const _maxEdges = 250000;
const _maxNamespaceEdges = 50000;
const _maxUnresolved = 50000;
const _maxReachabilityNodesPerRoot = 100000;
const _maxReachabilityEdgesPerRoot = 250000;
const _maxReachabilityDepthPerRoot = 4096;
const _maxReachabilitySourceUnitsPerRoot = 100000;
const _maxReverseReachabilityPairs = 1000000;

/// Resolved calls, references, properties, operators, indexed access, and
/// declared type relations from each discovered Dart unit under `lib/`.
///
/// This probe intentionally does not claim a complete declaration inventory
/// or transitive closure. Open-world dispatch, value calls, conditional and
/// deferred namespace selection, untracked inputs, non-`lib/` sources and
/// external bridges remain held.
Future<AlgorithmDirectEdgeProbeReport> runAlgorithmDirectEdgeProbe({
  String? repositoryRoot,
}) async {
  final root = path.normalize(
    path.absolute(repositoryRoot ?? Directory.current.path),
  );
  final libRoot = path.join(root, 'lib');
  final environmentHolds = <String>[];
  final manifest = AlgorithmResultRootManifest.decode(
    File(
      path.join(root, 'config', 'algorithm_result_root_manifest.json'),
    ).readAsStringSync(),
  );
  manifest.validateAgainstRegistry({
    for (final descriptor in AlgorithmRegistry.all)
      descriptor.id: descriptor.sourcePath,
  });
  if (manifest.entries.length > _maxRoots) {
    throw StateError('Result-root count exceeds the deterministic probe cap.');
  }

  final lockSource = File(path.join(root, 'pubspec.lock')).readAsStringSync();
  final packageConfigSource = File(
    path.join(root, '.dart_tool', 'package_config.json'),
  ).readAsStringSync();
  final packageJsonSource = File(
    path.join(root, 'package.json'),
  ).readAsStringSync();
  final packageJson = jsonDecode(packageJsonSource);
  if (packageJson is! Map<String, Object?> ||
      (packageJson['scripts'] as Map?)?['algorithm:direct-edge-probe'] !=
          'dart --packages=.dart_tool/package_config.json '
              'tool/run_algorithm_direct_edge_probe.dart') {
    environmentHolds.add('declared_probe_entrypoint_mismatch');
  }
  final generatorFile = File(
    path.join(root, 'tool', 'algorithm_direct_edge_probe.dart'),
  );
  final runnerFile = File(
    path.join(root, 'tool', 'run_algorithm_direct_edge_probe.dart'),
  );
  final testFile = File(
    path.join(root, 'test', 'algorithm_direct_edge_probe_test.dart'),
  );
  if (!generatorFile.existsSync()) {
    environmentHolds.add('probe_generator_source_missing');
  }
  if (!runnerFile.existsSync()) {
    environmentHolds.add('probe_runner_source_missing');
  }
  if (!testFile.existsSync()) {
    environmentHolds.add('probe_test_source_missing');
  }
  final analysisOptionsFile = File(path.join(root, 'analysis_options.yaml'));
  final analysisOptionsSource = analysisOptionsFile.existsSync()
      ? analysisOptionsFile.readAsStringSync()
      : '';
  final sourceDigests = <String, String>{};
  final libSourceDigests = <String, String>{};
  final libSourceFiles = <File>[];
  if (!Directory(libRoot).existsSync()) {
    environmentHolds.add('lib_source_root_missing');
  } else {
    final canonicalRoot = Directory(root).resolveSymbolicLinksSync();
    await for (final entity in Directory(
      libRoot,
    ).list(recursive: true, followLinks: false)) {
      if (entity is Link) {
        environmentHolds.add('lib_symlink_source_unreviewed');
        continue;
      }
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      try {
        final canonicalFile = entity.resolveSymbolicLinksSync();
        if (canonicalFile != canonicalRoot &&
            !path.isWithin(canonicalRoot, canonicalFile)) {
          environmentHolds.add('lib_source_outside_checkout');
          continue;
        }
        final sourcePath = path.normalize(entity.path);
        final relativePath = path
            .relative(sourcePath, from: root)
            .split(path.separator)
            .join('/');
        libSourceFiles.add(File(sourcePath));
        libSourceDigests[relativePath] = _sha256(entity.readAsBytesSync());
      } on FileSystemException {
        environmentHolds.add('lib_source_unreadable');
      }
    }
    libSourceFiles.sort((left, right) => left.path.compareTo(right.path));
  }
  for (final entry in manifest.entries) {
    final file = File(path.join(root, entry.sourcePath));
    if (!file.existsSync()) {
      environmentHolds.add('missing_root_source:${entry.algorithmId}');
      continue;
    }
    final canonicalRoot = Directory(root).resolveSymbolicLinksSync();
    final canonicalFile = file.resolveSymbolicLinksSync();
    if (canonicalFile != canonicalRoot &&
        !path.isWithin(canonicalRoot, canonicalFile)) {
      environmentHolds.add('root_source_outside_checkout:${entry.algorithmId}');
      continue;
    }
    sourceDigests[entry.sourcePath] = _sha256(file.readAsBytesSync());
  }
  _validateAnalyzerLock(
    lockSource: lockSource,
    packageConfigSource: packageConfigSource,
    holds: environmentHolds,
  );
  final dartVersion = Platform.version.split(' ').first;
  if (dartVersion != algorithmDependencyReviewedDartVersion) {
    environmentHolds.add('unreviewed_dart_version:$dartVersion');
  }
  if (!analysisOptionsFile.existsSync()) {
    environmentHolds.add('analysis_options_missing');
  }

  final edges = <AlgorithmDirectDependencyEdge>{};
  final declarationEdges = <AlgorithmDeclarationDependencyEdge>{};
  final namespaceEdges = <AlgorithmNamespaceDependencyEdge>{};
  final unresolved = <String, _UnresolvedEdgeCount>{};
  final sourceUnresolved = <String, _UnresolvedSourceEdgeCount>{};
  final rootObservations = <AlgorithmDirectEdgeRootObservation>[];
  final sourceUnits = <AlgorithmSourceUnitObservation>[];
  final elementOwners = <String, Element>{};
  final rootSourcePaths = <String>{
    for (final entry in manifest.entries)
      path.normalize(path.join(root, entry.sourcePath)),
  };
  AnalysisContextCollection? collection;
  var contextCount = 0;
  try {
    final sdkPath = algorithmAnalyzerSdkPathForCurrentRuntime();
    if (sdkPath == null) {
      environmentHolds.add('dart_sdk_path_unavailable');
    } else {
      collection = AnalysisContextCollection(
        includedPaths: [libRoot],
        sdkPath: sdkPath,
      );
      contextCount = collection.contexts.length;
      final sessions = <AnalysisContext, AnalysisSession>{};
      final unitCache = <String, SomeResolvedUnitResult>{};
      for (final entry in manifest.entries) {
        final sourcePath = path.normalize(path.join(root, entry.sourcePath));
        if (!sourceDigests.containsKey(entry.sourcePath)) {
          rootObservations.add(
            AlgorithmDirectEdgeRootObservation(
              algorithmId: entry.algorithmId,
              logicalRootId: entry.logicalRootId,
              canonicalPackageUri: entry.canonicalPackageUri,
              resultVariant: 'MissingOrOutsideCheckout',
              sessionConsistent: false,
              resolvedLibraryUri: null,
              blockingDiagnosticCodes: const [],
              edgeCount: 0,
              namespaceEdgeCount: 0,
              unresolvedCallCount: 1,
            ),
          );
          sourceUnits.add(
            AlgorithmSourceUnitObservation(
              sourcePackageUri: entry.canonicalPackageUri,
              unitKind: 'library',
              resultVariant: 'MissingOrOutsideCheckout',
              sessionConsistent: false,
              blockingDiagnosticCodes: const [],
              declarationEdgeCount: 0,
              namespaceEdgeCount: 0,
              unresolvedCallCount: 1,
            ),
          );
          _addUnresolved(
            unresolved,
            algorithmId: entry.algorithmId,
            rootId: entry.logicalRootId,
            edgeKind: 'root_library',
            reason: 'missing_or_outside_checkout',
          );
          continue;
        }
        final context = collection.contextFor(sourcePath);
        final session = sessions.putIfAbsent(
          context,
          () => context.currentSession,
        );
        final raw = unitCache[sourcePath] ??= await session.getResolvedUnit(
          sourcePath,
        );
        if (raw is! ResolvedUnitResult) {
          rootObservations.add(
            AlgorithmDirectEdgeRootObservation(
              algorithmId: entry.algorithmId,
              logicalRootId: entry.logicalRootId,
              canonicalPackageUri: entry.canonicalPackageUri,
              resultVariant: _resultVariant(raw),
              sessionConsistent: false,
              resolvedLibraryUri: null,
              blockingDiagnosticCodes: const [],
              edgeCount: 0,
              namespaceEdgeCount: 0,
              unresolvedCallCount: 1,
            ),
          );
          sourceUnits.add(
            AlgorithmSourceUnitObservation(
              sourcePackageUri: entry.canonicalPackageUri,
              unitKind: 'library',
              resultVariant: _resultVariant(raw),
              sessionConsistent: false,
              blockingDiagnosticCodes: const [],
              declarationEdgeCount: 0,
              namespaceEdgeCount: 0,
              unresolvedCallCount: 1,
            ),
          );
          _addUnresolved(
            unresolved,
            algorithmId: entry.algorithmId,
            rootId: entry.logicalRootId,
            edgeKind: 'root_library',
            reason: 'non_success_analysis_result',
          );
          continue;
        }
        final blockingCodes =
            raw.diagnostics
                .where((diagnostic) => diagnostic.severity == Severity.error)
                .map((diagnostic) => diagnostic.diagnosticCode.lowerCaseName)
                .toSet()
                .toList()
              ..sort();
        final resolvedUri = raw.libraryElement.uri.toString();
        final consistent = identical(raw.session, session);
        final uriMatches = resolvedUri == entry.libraryUri;
        if (!consistent ||
            !raw.isLibrary ||
            !uriMatches ||
            blockingCodes.isNotEmpty) {
          rootObservations.add(
            AlgorithmDirectEdgeRootObservation(
              algorithmId: entry.algorithmId,
              logicalRootId: entry.logicalRootId,
              canonicalPackageUri: entry.canonicalPackageUri,
              resultVariant: 'ResolvedUnitResultHeld',
              sessionConsistent: consistent,
              resolvedLibraryUri: resolvedUri,
              blockingDiagnosticCodes: blockingCodes,
              edgeCount: 0,
              namespaceEdgeCount: 0,
              unresolvedCallCount: 1,
            ),
          );
          sourceUnits.add(
            AlgorithmSourceUnitObservation(
              sourcePackageUri: entry.canonicalPackageUri,
              unitKind: raw.isLibrary ? 'library' : 'non_library_unit',
              resultVariant: 'ResolvedUnitResultHeld',
              sessionConsistent: consistent,
              blockingDiagnosticCodes: blockingCodes,
              declarationEdgeCount: 0,
              namespaceEdgeCount: 0,
              unresolvedCallCount: 1,
            ),
          );
          _addUnresolved(
            unresolved,
            algorithmId: entry.algorithmId,
            rootId: entry.logicalRootId,
            edgeKind: 'root_library',
            reason: !consistent
                ? 'inconsistent_analysis_session'
                : !raw.isLibrary
                ? 'root_is_not_library'
                : !uriMatches
                ? 'library_uri_mismatch'
                : 'blocking_analysis_diagnostic',
          );
          continue;
        }

        final collector = _RootCallEdgeCollector(
          algorithmId: entry.algorithmId,
          logicalRootId: entry.logicalRootId,
          sourcePackageUri: entry.canonicalPackageUri,
          repositoryRoot: root,
          packageName: manifest.packageName,
          elementOwners: elementOwners,
        )..collect(raw.unit);
        edges.addAll(collector.edges);
        declarationEdges.addAll(collector.declarationEdges);
        namespaceEdges.addAll(collector.namespaceEdges);
        for (final observation in collector.unresolved) {
          _addUnresolved(
            unresolved,
            algorithmId: entry.algorithmId,
            rootId: entry.logicalRootId,
            edgeKind: observation.edgeKind,
            reason: observation.reason,
          );
        }
        rootObservations.add(
          AlgorithmDirectEdgeRootObservation(
            algorithmId: entry.algorithmId,
            logicalRootId: entry.logicalRootId,
            canonicalPackageUri: entry.canonicalPackageUri,
            resultVariant: 'ResolvedUnitResult',
            sessionConsistent: consistent,
            resolvedLibraryUri: resolvedUri,
            blockingDiagnosticCodes: blockingCodes,
            edgeCount: collector.edges.length,
            namespaceEdgeCount: collector.namespaceEdges.length,
            unresolvedCallCount: collector.unresolved.length,
          ),
        );
        sourceUnits.add(
          AlgorithmSourceUnitObservation(
            sourcePackageUri: entry.canonicalPackageUri,
            containingLibraryPackageUri: resolvedUri,
            unitKind: 'library',
            resultVariant: 'ResolvedUnitResult',
            sessionConsistent: consistent,
            blockingDiagnosticCodes: blockingCodes,
            declarationEdgeCount: collector.declarationEdges.length,
            namespaceEdgeCount: collector.namespaceEdges.length,
            unresolvedCallCount: collector.unresolved.length,
          ),
        );
        if (edges.length > _maxEdges ||
            declarationEdges.length > _maxEdges ||
            namespaceEdges.length > _maxNamespaceEdges ||
            unresolved.length > _maxUnresolved ||
            sourceUnresolved.length > _maxUnresolved) {
          throw StateError(
            'Direct-edge probe exceeded a deterministic evidence budget.',
          );
        }
      }
      for (final file in libSourceFiles) {
        final sourcePath = path.normalize(file.path);
        if (rootSourcePaths.contains(sourcePath)) continue;
        final sourcePackageUri = _normalizeLibraryUri(
          Uri.file(sourcePath),
          repositoryRoot: root,
          packageName: manifest.packageName,
        );
        if (sourcePackageUri == null) {
          environmentHolds.add('lib_source_identity_not_path_free');
          continue;
        }
        final context = collection.contextFor(sourcePath);
        final session = sessions.putIfAbsent(
          context,
          () => context.currentSession,
        );
        final raw = unitCache[sourcePath] ??= await session.getResolvedUnit(
          sourcePath,
        );
        if (raw is! ResolvedUnitResult) {
          sourceUnits.add(
            AlgorithmSourceUnitObservation(
              sourcePackageUri: sourcePackageUri,
              unitKind: 'unknown',
              resultVariant: _resultVariant(raw),
              sessionConsistent: false,
              blockingDiagnosticCodes: const [],
              declarationEdgeCount: 0,
              namespaceEdgeCount: 0,
              unresolvedCallCount: 1,
            ),
          );
          _addSourceUnresolved(
            sourceUnresolved,
            sourcePackageUri: sourcePackageUri,
            edgeKind: 'source_unit',
            reason: 'non_success_analysis_result',
          );
          continue;
        }
        final blockingCodes =
            raw.diagnostics
                .where((diagnostic) => diagnostic.severity == Severity.error)
                .map((diagnostic) => diagnostic.diagnosticCode.lowerCaseName)
                .toSet()
                .toList()
              ..sort();
        final consistent = identical(raw.session, session);
        final isPart = raw.unit.directives.any(
          (directive) => directive is PartOfDirective,
        );
        final unitKind = raw.isLibrary
            ? 'library'
            : isPart
            ? 'part'
            : 'non_library_unit';
        final containingLibraryPackageUri = _normalizeLibraryUri(
          raw.libraryElement.uri,
          repositoryRoot: root,
          packageName: manifest.packageName,
        );
        final libraryBindingAccepted = unitKind == 'library'
            ? containingLibraryPackageUri == sourcePackageUri
            : unitKind == 'part' && containingLibraryPackageUri != null;
        if (!consistent ||
            blockingCodes.isNotEmpty ||
            unitKind == 'non_library_unit' ||
            !libraryBindingAccepted) {
          final reason = !consistent
              ? 'inconsistent_analysis_session'
              : blockingCodes.isNotEmpty
              ? 'blocking_analysis_diagnostic'
              : unitKind == 'non_library_unit'
              ? 'unrecognized_non_library_unit'
              : containingLibraryPackageUri == null
              ? 'containing_library_identity_unavailable'
              : 'source_unit_library_binding_mismatch';
          sourceUnits.add(
            AlgorithmSourceUnitObservation(
              sourcePackageUri: sourcePackageUri,
              containingLibraryPackageUri: containingLibraryPackageUri,
              unitKind: unitKind,
              resultVariant: 'ResolvedUnitResultHeld',
              sessionConsistent: consistent,
              blockingDiagnosticCodes: blockingCodes,
              declarationEdgeCount: 0,
              namespaceEdgeCount: 0,
              unresolvedCallCount: 1,
            ),
          );
          _addSourceUnresolved(
            sourceUnresolved,
            sourcePackageUri: sourcePackageUri,
            edgeKind: 'source_unit',
            reason: reason,
          );
          continue;
        }
        final collector = collectAlgorithmSourceUnitEdges(
          sourcePackageUri: sourcePackageUri,
          unit: raw,
          repositoryRoot: root,
          packageName: manifest.packageName,
          elementOwners: elementOwners,
        );
        declarationEdges.addAll(collector.declarationEdges);
        namespaceEdges.addAll(collector.namespaceEdges);
        for (final observation in collector.sourceUnresolved) {
          _addSourceUnresolved(
            sourceUnresolved,
            sourcePackageUri: observation.sourcePackageUri,
            edgeKind: observation.edgeKind,
            reason: observation.reason,
            count: observation.count,
          );
        }
        sourceUnits.add(
          AlgorithmSourceUnitObservation(
            sourcePackageUri: sourcePackageUri,
            containingLibraryPackageUri: containingLibraryPackageUri,
            unitKind: unitKind,
            resultVariant: 'ResolvedUnitResult',
            sessionConsistent: consistent,
            blockingDiagnosticCodes: blockingCodes,
            declarationEdgeCount: collector.declarationEdges.length,
            namespaceEdgeCount: collector.namespaceEdges.length,
            unresolvedCallCount: collector.sourceUnresolved.fold(
              0,
              (total, edge) => total + edge.count,
            ),
          ),
        );
        if (declarationEdges.length > _maxEdges ||
            namespaceEdges.length > _maxNamespaceEdges ||
            sourceUnresolved.length > _maxUnresolved) {
          throw StateError(
            'Local source graph exceeded a deterministic evidence budget.',
          );
        }
      }
    }
  } finally {
    await collection?.dispose();
  }

  final callReachability = computeAlgorithmSupportedCallReachability(
    roots: rootObservations,
    rootEdges: edges,
    declarationEdges: declarationEdges,
    namespaceEdges: namespaceEdges,
    rootUnresolved: unresolved.values.map((value) => value.toEdge()),
    sourceUnresolved: sourceUnresolved.values.map((value) => value.toEdge()),
    sourceUnits: sourceUnits,
  );
  return AlgorithmDirectEdgeProbeReport(
    analyzerVersion: algorithmDependencyAnalyzerVersion,
    analyzerArchiveSha256: algorithmDependencyAnalyzerArchiveSha256,
    dartVersion: dartVersion,
    rootManifestSha256: manifest.sha256Digest,
    lockfileSha256: _sha256(utf8.encode(lockSource)),
    packageConfigSha256: _sha256(utf8.encode(packageConfigSource)),
    packageJsonSha256: _sha256(utf8.encode(packageJsonSource)),
    analysisOptionsSha256: _sha256(utf8.encode(analysisOptionsSource)),
    generatorSourceSha256: generatorFile.existsSync()
        ? _sha256(generatorFile.readAsBytesSync())
        : 'unavailable',
    runnerSourceSha256: runnerFile.existsSync()
        ? _sha256(runnerFile.readAsBytesSync())
        : 'unavailable',
    testSourceSha256: testFile.existsSync()
        ? _sha256(testFile.readAsBytesSync())
        : 'unavailable',
    rootSourceSnapshotSha256: _digestStringMap(sourceDigests),
    libSourceSnapshotSha256: _digestStringMap(libSourceDigests),
    analysisContextCount: contextCount,
    sourceFileCount: libSourceDigests.length,
    roots: rootObservations,
    edges: edges,
    declarationEdges: declarationEdges,
    namespaceEdges: namespaceEdges,
    unresolved: unresolved.values.map((value) => value.toEdge()),
    sourceUnresolved: sourceUnresolved.values.map((value) => value.toEdge()),
    sourceUnits: sourceUnits,
    supportedCallReachability: callReachability.summaries,
    supportedCallReverseReachability: callReachability.reverseReachability,
    supportedCallReverseSourceOwnership:
        callReachability.reverseSourceOwnership,
    reachabilityHolds: callReachability.holds,
    environmentHoldReasons: environmentHolds,
  );
}

/// Collects only resolved method, function-expression, and constructor calls
/// from a root compilation unit. The deliberately small surface is explicit in
/// the report's permanent hold list.
AlgorithmRootCallEdgeCollection collectAlgorithmRootCallEdges({
  required String algorithmId,
  required String logicalRootId,
  required String sourcePackageUri,
  required ResolvedUnitResult unit,
  required String repositoryRoot,
  required String packageName,
}) {
  final visitor = _RootCallEdgeCollector(
    algorithmId: algorithmId,
    logicalRootId: logicalRootId,
    sourcePackageUri: sourcePackageUri,
    repositoryRoot: repositoryRoot,
    packageName: packageName,
    elementOwners: <String, Element>{},
  )..collect(unit.unit);
  return AlgorithmRootCallEdgeCollection(
    edges: visitor.edges,
    declarationEdges: visitor.declarationEdges,
    namespaceEdges: visitor.namespaceEdges,
    unresolved: visitor.unresolved,
    sourceUnresolved: visitor.sourceUnresolved,
  );
}

/// Collects source-local edges without guessing which registered algorithm
/// owns this unit. This is used for helpers and parts outside the manifest roots.
AlgorithmRootCallEdgeCollection collectAlgorithmSourceUnitEdges({
  required String sourcePackageUri,
  required ResolvedUnitResult unit,
  required String repositoryRoot,
  required String packageName,
  Map<String, Element>? elementOwners,
}) {
  final visitor = _RootCallEdgeCollector(
    algorithmId: null,
    logicalRootId: null,
    sourcePackageUri: sourcePackageUri,
    repositoryRoot: repositoryRoot,
    packageName: packageName,
    elementOwners: elementOwners ?? <String, Element>{},
  )..collect(unit.unit);
  return AlgorithmRootCallEdgeCollection(
    edges: visitor.edges,
    declarationEdges: visitor.declarationEdges,
    namespaceEdges: visitor.namespaceEdges,
    unresolved: visitor.unresolved,
    sourceUnresolved: visitor.sourceUnresolved,
  );
}

class AlgorithmRootCallEdgeCollection {
  final List<AlgorithmDirectDependencyEdge> edges;
  final List<AlgorithmDeclarationDependencyEdge> declarationEdges;
  final List<AlgorithmNamespaceDependencyEdge> namespaceEdges;
  final List<AlgorithmUnresolvedDirectEdge> unresolved;
  final List<AlgorithmUnresolvedSourceEdge> sourceUnresolved;

  AlgorithmRootCallEdgeCollection({
    required Iterable<AlgorithmDirectDependencyEdge> edges,
    required Iterable<AlgorithmDeclarationDependencyEdge> declarationEdges,
    required Iterable<AlgorithmNamespaceDependencyEdge> namespaceEdges,
    required Iterable<AlgorithmUnresolvedDirectEdge> unresolved,
    required Iterable<AlgorithmUnresolvedSourceEdge> sourceUnresolved,
  }) : edges = List.unmodifiable(edges),
       declarationEdges = List.unmodifiable(declarationEdges),
       namespaceEdges = List.unmodifiable(namespaceEdges),
       unresolved = List.unmodifiable(unresolved),
       sourceUnresolved = List.unmodifiable(sourceUnresolved);
}

class AlgorithmDirectDependencyEdge {
  final String algorithmId;
  final String logicalRootId;
  final String sourcePackageUri;
  final String sourceDeclarationIdentity;
  final String targetIdentity;
  final String targetLibraryUri;
  final String edgeKind;
  final String targetScope;

  const AlgorithmDirectDependencyEdge({
    required this.algorithmId,
    required this.logicalRootId,
    required this.sourcePackageUri,
    required this.sourceDeclarationIdentity,
    required this.targetIdentity,
    required this.targetLibraryUri,
    required this.edgeKind,
    required this.targetScope,
  });

  Map<String, Object?> toJson() => {
    'algorithm_id': algorithmId,
    'logical_root_id': logicalRootId,
    'source_package_uri': sourcePackageUri,
    'source_declaration_identity': sourceDeclarationIdentity,
    'target_identity': targetIdentity,
    'target_library_uri': targetLibraryUri,
    'edge_kind': edgeKind,
    'target_scope': targetScope,
  };
}

/// An AST-preserving import, export, part, or part-of directive branch.
/// Namespace edges remain separate from result-dependency call edges.
/// A repository-local call edge without inferred algorithm ownership.
class AlgorithmDeclarationDependencyEdge {
  final String sourcePackageUri;
  final String sourceDeclarationIdentity;
  final String targetIdentity;
  final String targetLibraryUri;
  final String edgeKind;
  final String targetScope;

  const AlgorithmDeclarationDependencyEdge({
    required this.sourcePackageUri,
    required this.sourceDeclarationIdentity,
    required this.targetIdentity,
    required this.targetLibraryUri,
    required this.edgeKind,
    required this.targetScope,
  });

  Map<String, Object?> toJson() => {
    'source_package_uri': sourcePackageUri,
    'source_declaration_identity': sourceDeclarationIdentity,
    'target_identity': targetIdentity,
    'target_library_uri': targetLibraryUri,
    'edge_kind': edgeKind,
    'target_scope': targetScope,
  };
}

class AlgorithmNamespaceDependencyEdge {
  final String? algorithmId;
  final String? logicalRootId;
  final String sourcePackageUri;
  final int directiveIndex;
  final int branchIndex;
  final String directiveKind;
  final String uriLiteral;
  final String? targetPackageUri;
  final String? symbolicTarget;
  final String? conditionName;
  final String? conditionValue;
  final String? prefix;
  final bool deferred;
  final List<Map<String, Object?>> combinators;

  AlgorithmNamespaceDependencyEdge({
    required this.algorithmId,
    required this.logicalRootId,
    required this.sourcePackageUri,
    required this.directiveIndex,
    required this.branchIndex,
    required this.directiveKind,
    required this.uriLiteral,
    required this.targetPackageUri,
    required this.symbolicTarget,
    required this.conditionName,
    required this.conditionValue,
    required this.prefix,
    required this.deferred,
    required Iterable<Map<String, Object?>> combinators,
  }) : combinators = List.unmodifiable(
         combinators.map(Map<String, Object?>.unmodifiable),
       );

  Map<String, Object?> toJson() => {
    'algorithm_id': algorithmId,
    'logical_root_id': logicalRootId,
    'source_package_uri': sourcePackageUri,
    'directive_index': directiveIndex,
    'branch_index': branchIndex,
    'directive_kind': directiveKind,
    'uri_literal': uriLiteral,
    'target_package_uri': targetPackageUri,
    'symbolic_target': symbolicTarget,
    'condition_name': conditionName,
    'condition_value': conditionValue,
    'prefix': prefix,
    'deferred': deferred,
    'combinators': combinators,
  };
}

class AlgorithmUnresolvedDirectEdge {
  final String algorithmId;
  final String logicalRootId;
  final String edgeKind;
  final String reason;
  final int count;

  const AlgorithmUnresolvedDirectEdge({
    required this.algorithmId,
    required this.logicalRootId,
    required this.edgeKind,
    required this.reason,
    required this.count,
  });

  Map<String, Object?> toJson() => {
    'algorithm_id': algorithmId,
    'logical_root_id': logicalRootId,
    'edge_kind': edgeKind,
    'reason': reason,
    'count': count,
  };
}

class AlgorithmUnresolvedSourceEdge {
  final String sourcePackageUri;
  final String edgeKind;
  final String reason;
  final int count;

  const AlgorithmUnresolvedSourceEdge({
    required this.sourcePackageUri,
    required this.edgeKind,
    required this.reason,
    required this.count,
  });

  Map<String, Object?> toJson() => {
    'source_package_uri': sourcePackageUri,
    'edge_kind': edgeKind,
    'reason': reason,
    'count': count,
  };
}

class AlgorithmSourceUnitObservation {
  final String sourcePackageUri;
  final String? containingLibraryPackageUri;
  final String unitKind;
  final String resultVariant;
  final bool sessionConsistent;
  final List<String> blockingDiagnosticCodes;
  final int declarationEdgeCount;
  final int namespaceEdgeCount;
  final int unresolvedCallCount;

  AlgorithmSourceUnitObservation({
    required this.sourcePackageUri,
    this.containingLibraryPackageUri,
    required this.unitKind,
    required this.resultVariant,
    required this.sessionConsistent,
    required Iterable<String> blockingDiagnosticCodes,
    required this.declarationEdgeCount,
    required this.namespaceEdgeCount,
    required this.unresolvedCallCount,
  }) : blockingDiagnosticCodes = List.unmodifiable(
         [...blockingDiagnosticCodes]..sort(),
       );

  bool get accepted =>
      resultVariant == 'ResolvedUnitResult' &&
      sessionConsistent &&
      blockingDiagnosticCodes.isEmpty &&
      ((unitKind == 'library' &&
              (containingLibraryPackageUri == null ||
                  containingLibraryPackageUri == sourcePackageUri)) ||
          (unitKind == 'part' && containingLibraryPackageUri != null));

  Map<String, Object?> toJson() => {
    'source_package_uri': sourcePackageUri,
    'containing_library_package_uri': containingLibraryPackageUri,
    'unit_kind': unitKind,
    'result_variant': resultVariant,
    'session_consistent': sessionConsistent,
    'blocking_diagnostic_codes': blockingDiagnosticCodes,
    'accepted': accepted,
    'declaration_edge_count': declarationEdgeCount,
    'namespace_edge_count': namespaceEdgeCount,
    'unresolved_call_count': unresolvedCallCount,
  };
}

/// A bounded forward-reachability summary over supported direct edges and
/// conservatively included local namespace targets. This is never a
/// closure-complete result.
class AlgorithmSupportedCallReachability {
  final String algorithmId;
  final String logicalRootId;
  final String rootPackageUri;
  final int seedDeclarationCount;
  final int reachableDeclarationCount;
  final int reachableEdgeCount;
  final int reachableSourceUnitCount;
  final int reachableNamespaceBranchCount;
  final List<String> reachableSourcePackageUris;
  final int externalEdgeCount;
  final int maximumDepth;
  final int rootUnresolvedGroupCount;
  final int rootUnresolvedOccurrenceCount;
  final int sourceUnresolvedGroupCount;
  final int sourceUnresolvedOccurrenceCount;
  final int blockerGroupCount;
  final int blockerOccurrenceCount;
  final bool budgetExceeded;
  final String reachableGraphSha256;
  final List<String> reachableDeclarationIdentities;
  final List<AlgorithmSupportedCallCycle> cyclicComponents;

  AlgorithmSupportedCallReachability({
    required this.algorithmId,
    required this.logicalRootId,
    required this.rootPackageUri,
    required this.seedDeclarationCount,
    required this.reachableDeclarationCount,
    required this.reachableEdgeCount,
    required this.reachableSourceUnitCount,
    required this.reachableNamespaceBranchCount,
    required Iterable<String> reachableSourcePackageUris,
    required this.externalEdgeCount,
    required this.maximumDepth,
    required this.rootUnresolvedGroupCount,
    required this.rootUnresolvedOccurrenceCount,
    required this.sourceUnresolvedGroupCount,
    required this.sourceUnresolvedOccurrenceCount,
    required this.blockerGroupCount,
    required this.blockerOccurrenceCount,
    required this.budgetExceeded,
    required this.reachableGraphSha256,
    required Iterable<String> reachableDeclarationIdentities,
    required Iterable<AlgorithmSupportedCallCycle> cyclicComponents,
  }) : reachableDeclarationIdentities = List.unmodifiable(
         reachableDeclarationIdentities.toSet().toList()..sort(),
       ),
       reachableSourcePackageUris = List.unmodifiable(
         reachableSourcePackageUris.toSet().toList()..sort(),
       ),
       cyclicComponents = List.unmodifiable(
         [...cyclicComponents]..sort(
           (left, right) => left.cycleSha256.compareTo(right.cycleSha256),
         ),
       );

  Map<String, Object?> toJson() => {
    'algorithm_id': algorithmId,
    'logical_root_id': logicalRootId,
    'root_package_uri': rootPackageUri,
    'seed_declaration_count': seedDeclarationCount,
    'reachable_declaration_count': reachableDeclarationCount,
    'reachable_edge_count': reachableEdgeCount,
    'reachable_source_unit_count': reachableSourceUnitCount,
    'reachable_namespace_branch_count': reachableNamespaceBranchCount,
    'reachable_source_package_uris': reachableSourcePackageUris,
    'external_edge_count': externalEdgeCount,
    'maximum_depth': maximumDepth,
    'root_unresolved_group_count': rootUnresolvedGroupCount,
    'root_unresolved_occurrence_count': rootUnresolvedOccurrenceCount,
    'source_unresolved_group_count': sourceUnresolvedGroupCount,
    'source_unresolved_occurrence_count': sourceUnresolvedOccurrenceCount,
    'blocker_group_count': blockerGroupCount,
    'blocker_occurrence_count': blockerOccurrenceCount,
    'budget_exceeded': budgetExceeded,
    'reachable_graph_sha256': reachableGraphSha256,
    'reachable_declaration_identities': reachableDeclarationIdentities,
    'cyclic_components': cyclicComponents
        .map((component) => component.toJson())
        .toList(),
    'closure_complete': false,
  };
}

/// One cycle found inside the bounded, accepted local subgraph for a root.
/// This does not imply that unresolved or open-world dependencies are closed.
class AlgorithmSupportedCallCycle {
  final String cycleSha256;
  final List<String> declarationIdentities;

  AlgorithmSupportedCallCycle({
    required this.cycleSha256,
    required Iterable<String> declarationIdentities,
  }) : declarationIdentities = List.unmodifiable(
         declarationIdentities.toSet().toList()..sort(),
       );

  Map<String, Object?> toJson() => {
    'cycle_sha256': cycleSha256,
    'declaration_count': declarationIdentities.length,
    'declaration_identities': declarationIdentities,
    'cycle_detection_scope': 'bounded_supported_local_reachability_subgraph',
    'closure_complete': false,
  };
}

/// Inverted ownership of one declaration in the existing root-seeded preview.
/// The algorithm IDs are candidate source-impact owners, not exact result sinks.
class AlgorithmSupportedCallReverseReachability {
  final String declarationIdentity;
  final List<String> algorithmIds;

  AlgorithmSupportedCallReverseReachability({
    required this.declarationIdentity,
    required Iterable<String> algorithmIds,
  }) : algorithmIds = List.unmodifiable(algorithmIds.toSet().toList()..sort());

  Map<String, Object?> toJson() => {
    'declaration_identity': declarationIdentity,
    'algorithm_ids': algorithmIds,
    'algorithm_count': algorithmIds.length,
    'scope': 'root_seeded_supported_call_ownership_preview',
    'exact_result_impact': false,
    'closure_complete': false,
  };
}

/// Candidate algorithm owners of one accepted local source unit reached
/// through direct dependencies or conservative import/export traversal.
class AlgorithmSupportedCallReverseSourceOwnership {
  final String sourcePackageUri;
  final List<String> algorithmIds;

  AlgorithmSupportedCallReverseSourceOwnership({
    required this.sourcePackageUri,
    required Iterable<String> algorithmIds,
  }) : algorithmIds = List.unmodifiable(algorithmIds.toSet().toList()..sort());

  Map<String, Object?> toJson() => {
    'source_package_uri': sourcePackageUri,
    'algorithm_ids': algorithmIds,
    'algorithm_count': algorithmIds.length,
    'scope': 'root_seeded_direct_and_conservative_namespace_source_ownership',
    'exact_result_impact': false,
    'closure_complete': false,
  };
}

class AlgorithmCallReachabilityHold {
  final String algorithmId;
  final String logicalRootId;
  final String sourcePackageUri;
  final String edgeKind;
  final String reason;
  final int count;

  const AlgorithmCallReachabilityHold({
    required this.algorithmId,
    required this.logicalRootId,
    required this.sourcePackageUri,
    required this.edgeKind,
    required this.reason,
    required this.count,
  });

  Map<String, Object?> toJson() => {
    'algorithm_id': algorithmId,
    'logical_root_id': logicalRootId,
    'source_package_uri': sourcePackageUri,
    'edge_kind': edgeKind,
    'reason': reason,
    'count': count,
  };
}

class AlgorithmCallReachabilityResult {
  final List<AlgorithmSupportedCallReachability> summaries;
  final List<AlgorithmCallReachabilityHold> holds;
  final List<AlgorithmSupportedCallReverseReachability> reverseReachability;
  final List<AlgorithmSupportedCallReverseSourceOwnership>
  reverseSourceOwnership;

  AlgorithmCallReachabilityResult({
    required Iterable<AlgorithmSupportedCallReachability> summaries,
    required Iterable<AlgorithmCallReachabilityHold> holds,
    required Iterable<AlgorithmSupportedCallReverseReachability>
    reverseReachability,
    required Iterable<AlgorithmSupportedCallReverseSourceOwnership>
    reverseSourceOwnership,
  }) : summaries = List.unmodifiable(
         [...summaries]..sort((a, b) => a.algorithmId.compareTo(b.algorithmId)),
       ),
       holds = List.unmodifiable(
         [...holds]..sort(
           (a, b) => _reachabilityHoldKey(a).compareTo(_reachabilityHoldKey(b)),
         ),
       ),
       reverseReachability = List.unmodifiable(
         [...reverseReachability]..sort(
           (left, right) =>
               left.declarationIdentity.compareTo(right.declarationIdentity),
         ),
       ),
       reverseSourceOwnership = List.unmodifiable(
         [...reverseSourceOwnership]..sort(
           (left, right) =>
               left.sourcePackageUri.compareTo(right.sourcePackageUri),
         ),
       );
}

List<Map<String, Object?>> _buildPartOwnershipRows({
  required Iterable<AlgorithmSourceUnitObservation> sourceUnits,
  required Iterable<AlgorithmNamespaceDependencyEdge> namespaceEdges,
}) {
  final unitsByUri = {
    for (final unit in sourceUnits) unit.sourcePackageUri: unit,
  };
  final rows = <Map<String, Object?>>[];
  final parts = sourceUnits.where((unit) => unit.unitKind == 'part').toList()
    ..sort(
      (left, right) => left.sourcePackageUri.compareTo(right.sourcePackageUri),
    );
  for (final part in parts) {
    final libraryUri = part.containingLibraryPackageUri;
    final library = libraryUri == null ? null : unitsByUri[libraryUri];
    final partBranches = {
      for (final edge in namespaceEdges)
        if (edge.sourcePackageUri == libraryUri &&
            edge.directiveKind == 'part' &&
            edge.targetPackageUri == part.sourcePackageUri)
          '${edge.directiveIndex}\u0000${edge.branchIndex}\u0000${edge.targetPackageUri}',
    };
    final accepted =
        part.accepted &&
        part.sourcePackageUri.startsWith('package:') &&
        libraryUri != null &&
        libraryUri.startsWith('package:') &&
        library != null &&
        library.unitKind == 'library' &&
        library.accepted &&
        partBranches.length == 1;
    final holdReason = accepted
        ? null
        : libraryUri == null
        ? 'containing_library_identity_unavailable'
        : library == null || library.unitKind != 'library' || !library.accepted
        ? 'containing_library_unit_not_accepted'
        : partBranches.length != 1
        ? 'declaring_part_directive_not_unique'
        : 'part_source_unit_not_accepted';
    rows.add({
      'part_package_uri': part.sourcePackageUri,
      'containing_library_package_uri': libraryUri,
      'part_directive_branch_count': partBranches.length,
      'ownership_state': accepted ? 'accepted' : 'held',
      'hold_reason': holdReason,
      'ownership_basis':
          'analyzer_containing_library_uri_and_ast_part_directive',
      'closure_complete': false,
    });
  }
  return List.unmodifiable(rows);
}

class AlgorithmDirectEdgeRootObservation {
  final String algorithmId;
  final String logicalRootId;
  final String canonicalPackageUri;
  final String resultVariant;
  final bool sessionConsistent;
  final String? resolvedLibraryUri;
  final List<String> blockingDiagnosticCodes;
  final int edgeCount;
  final int namespaceEdgeCount;
  final int unresolvedCallCount;

  AlgorithmDirectEdgeRootObservation({
    required this.algorithmId,
    required this.logicalRootId,
    required this.canonicalPackageUri,
    required this.resultVariant,
    required this.sessionConsistent,
    required this.resolvedLibraryUri,
    required Iterable<String> blockingDiagnosticCodes,
    required this.edgeCount,
    required this.namespaceEdgeCount,
    required this.unresolvedCallCount,
  }) : blockingDiagnosticCodes = List.unmodifiable(
         [...blockingDiagnosticCodes]..sort(),
       );

  bool get accepted =>
      resultVariant == 'ResolvedUnitResult' &&
      sessionConsistent &&
      resolvedLibraryUri == canonicalPackageUri &&
      blockingDiagnosticCodes.isEmpty;

  Map<String, Object?> toJson() => {
    'algorithm_id': algorithmId,
    'logical_root_id': logicalRootId,
    'canonical_package_uri': canonicalPackageUri,
    'result_variant': resultVariant,
    'session_consistent': sessionConsistent,
    'resolved_library_uri': resolvedLibraryUri,
    'blocking_diagnostic_codes': blockingDiagnosticCodes,
    'accepted': accepted,
    'edge_count': edgeCount,
    'namespace_edge_count': namespaceEdgeCount,
    'unresolved_call_count': unresolvedCallCount,
  };
}

class AlgorithmDirectEdgeProbeReport {
  static const uncoveredEdgeClasses = <String>[
    'conditional_deferred_selection_and_external_namespace_semantics',
    'complete_declaration_inventory_and_transitive_edges',
    'supported_dependency_reachability_is_not_complete_transitive_closure',
    'getters_setters_fields_constants_and_initializers',
    'generic_dispatch_and_complete_operator_target_sets',
    'function_value_flow_and_callback_target_closure',
    'override_dispatch_and_complete_extension_target_sets',
    'generated_sources_manual_bridges_platform_channels_and_ffi',
    'untracked_gitignore_and_non_lib_source_snapshot',
    'exact_result_sink_binding_and_result_impact_closure',
  ];

  final String analyzerVersion;
  final String analyzerArchiveSha256;
  final String dartVersion;
  final String rootManifestSha256;
  final String lockfileSha256;
  final String packageConfigSha256;
  final String packageJsonSha256;
  final String analysisOptionsSha256;
  final String generatorSourceSha256;
  final String runnerSourceSha256;
  final String testSourceSha256;
  final String rootSourceSnapshotSha256;
  final String libSourceSnapshotSha256;
  final int analysisContextCount;
  final int sourceFileCount;
  final List<AlgorithmDirectEdgeRootObservation> roots;
  final List<AlgorithmDirectDependencyEdge> edges;
  final List<AlgorithmDeclarationDependencyEdge> declarationEdges;
  final List<AlgorithmNamespaceDependencyEdge> namespaceEdges;
  final List<AlgorithmUnresolvedDirectEdge> unresolved;
  final List<AlgorithmUnresolvedSourceEdge> sourceUnresolved;
  final List<AlgorithmSourceUnitObservation> sourceUnits;
  final List<AlgorithmSupportedCallReachability> supportedCallReachability;
  final List<AlgorithmSupportedCallReverseReachability>
  supportedCallReverseReachability;
  final List<AlgorithmSupportedCallReverseSourceOwnership>
  supportedCallReverseSourceOwnership;
  final List<AlgorithmCallReachabilityHold> reachabilityHolds;
  final List<String> environmentHoldReasons;

  AlgorithmDirectEdgeProbeReport({
    required this.analyzerVersion,
    required this.analyzerArchiveSha256,
    required this.dartVersion,
    required this.rootManifestSha256,
    required this.lockfileSha256,
    required this.packageConfigSha256,
    required this.packageJsonSha256,
    required this.analysisOptionsSha256,
    required this.generatorSourceSha256,
    required this.runnerSourceSha256,
    required this.testSourceSha256,
    required this.rootSourceSnapshotSha256,
    required this.libSourceSnapshotSha256,
    required this.analysisContextCount,
    required this.sourceFileCount,
    required Iterable<AlgorithmDirectEdgeRootObservation> roots,
    required Iterable<AlgorithmDirectDependencyEdge> edges,
    required Iterable<AlgorithmDeclarationDependencyEdge> declarationEdges,
    required Iterable<AlgorithmNamespaceDependencyEdge> namespaceEdges,
    required Iterable<AlgorithmUnresolvedDirectEdge> unresolved,
    required Iterable<AlgorithmUnresolvedSourceEdge> sourceUnresolved,
    required Iterable<AlgorithmSourceUnitObservation> sourceUnits,
    required Iterable<AlgorithmSupportedCallReachability>
    supportedCallReachability,
    required Iterable<AlgorithmSupportedCallReverseReachability>
    supportedCallReverseReachability,
    required Iterable<AlgorithmSupportedCallReverseSourceOwnership>
    supportedCallReverseSourceOwnership,
    required Iterable<AlgorithmCallReachabilityHold> reachabilityHolds,
    required Iterable<String> environmentHoldReasons,
  }) : roots = List.unmodifiable(
         [...roots]..sort((a, b) => a.algorithmId.compareTo(b.algorithmId)),
       ),
       edges = List.unmodifiable(
         [...edges]..sort((a, b) {
           final left =
               '${a.algorithmId}\u0000${a.logicalRootId}\u0000${a.sourceDeclarationIdentity}\u0000${a.edgeKind}\u0000${a.targetIdentity}';
           final right =
               '${b.algorithmId}\u0000${b.logicalRootId}\u0000${b.sourceDeclarationIdentity}\u0000${b.edgeKind}\u0000${b.targetIdentity}';
           return left.compareTo(right);
         }),
       ),
       declarationEdges = List.unmodifiable(
         [...declarationEdges]..sort((a, b) {
           final left =
               '${a.sourcePackageUri}\u0000${a.sourceDeclarationIdentity}\u0000${a.edgeKind}\u0000${a.targetIdentity}';
           final right =
               '${b.sourcePackageUri}\u0000${b.sourceDeclarationIdentity}\u0000${b.edgeKind}\u0000${b.targetIdentity}';
           return left.compareTo(right);
         }),
       ),
       namespaceEdges = List.unmodifiable(
         [...namespaceEdges]..sort((a, b) {
           final left =
               '${a.algorithmId}\u0000${a.logicalRootId}\u0000${a.sourcePackageUri}\u0000${a.directiveIndex.toString().padLeft(8, '0')}\u0000${a.branchIndex.toString().padLeft(8, '0')}';
           final right =
               '${b.algorithmId}\u0000${b.logicalRootId}\u0000${b.sourcePackageUri}\u0000${b.directiveIndex.toString().padLeft(8, '0')}\u0000${b.branchIndex.toString().padLeft(8, '0')}';
           return left.compareTo(right);
         }),
       ),
       unresolved = List.unmodifiable(
         [...unresolved]..sort((a, b) {
           final left =
               '${a.algorithmId}\u0000${a.logicalRootId}\u0000${a.edgeKind}\u0000${a.reason}';
           final right =
               '${b.algorithmId}\u0000${b.logicalRootId}\u0000${b.edgeKind}\u0000${b.reason}';
           return left.compareTo(right);
         }),
       ),
       sourceUnresolved = List.unmodifiable(
         [...sourceUnresolved]..sort((a, b) {
           final left =
               '${a.sourcePackageUri}\u0000${a.edgeKind}\u0000${a.reason}';
           final right =
               '${b.sourcePackageUri}\u0000${b.edgeKind}\u0000${b.reason}';
           return left.compareTo(right);
         }),
       ),
       sourceUnits = List.unmodifiable(
         [...sourceUnits]
           ..sort((a, b) => a.sourcePackageUri.compareTo(b.sourcePackageUri)),
       ),
       supportedCallReachability = List.unmodifiable(
         [...supportedCallReachability]
           ..sort((a, b) => a.algorithmId.compareTo(b.algorithmId)),
       ),
       supportedCallReverseReachability = List.unmodifiable(
         [...supportedCallReverseReachability]..sort(
           (left, right) =>
               left.declarationIdentity.compareTo(right.declarationIdentity),
         ),
       ),
       supportedCallReverseSourceOwnership = List.unmodifiable(
         [...supportedCallReverseSourceOwnership]..sort(
           (left, right) =>
               left.sourcePackageUri.compareTo(right.sourcePackageUri),
         ),
       ),
       reachabilityHolds = List.unmodifiable(
         [...reachabilityHolds]..sort(
           (a, b) => _reachabilityHoldKey(a).compareTo(_reachabilityHoldKey(b)),
         ),
       ),
       environmentHoldReasons = List.unmodifiable(
         environmentHoldReasons.toSet().toList()..sort(),
       );

  bool get compatibilityAccepted =>
      roots.length == 63 &&
      roots.every((root) => root.accepted) &&
      environmentHoldReasons.isEmpty;

  /// This phase can never state closure, even when every registered root
  /// resolves and every collected call has a stable direct target.
  bool get closureComplete => false;

  int get acceptedRootCount => roots.where((root) => root.accepted).length;

  int get acceptedSourceUnitCount =>
      sourceUnits.where((unit) => unit.accepted).length;

  bool get sourceInventoryReconciled =>
      sourceUnits.length == sourceFileCount &&
      sourceUnits.map((unit) => unit.sourcePackageUri).toSet().length ==
          sourceFileCount;

  Map<String, Object?> get canonicalPayload =>
      _canonicalize({
            r'$schema': algorithmDirectEdgeProbeSchema,
            'schema_version': 14,
            'generator': algorithmDirectEdgeProbeGenerator,
            'probe_state': algorithmDirectEdgeProbeHeld,
            'closure_complete': closureComplete,
            'claim_boundary':
                'Supported calls and executable references, property '
                'read/write references, resolved operator and indexed-access '
                'references, runtime type tests, casts and type literals, '
                'declared inheritance, mixin, extension and extension-type '
                'representation relations, resolved non-generic named type-alias '
                'targets, constructor field initialization, '
                'redirection and resolved super-constructor references, and AST '
                'namespace edges from every '
                'discovered regular Dart source under lib, with unit-level '
                'accepted/held observations, Analyzer-validated declared part '
                'ownership, conservative local import/export candidate '
                'traversal, algorithm-owned bounded forward reachability, '
                'inverted declaration and source-unit ownership, bounded '
                'cycle previews, and explicit unresolved blockers. '
                'This is not a complete declaration inventory or transitive closure, '
                'runtime execution, exact data flow, external-system coverage, '
                'scientific evidence, or clinical validation.',
            'analyzer_version': analyzerVersion,
            'analyzer_archive_sha256': analyzerArchiveSha256,
            'dart_version': dartVersion,
            'root_manifest_sha256': rootManifestSha256,
            'lockfile_sha256': lockfileSha256,
            'package_config_sha256': packageConfigSha256,
            'package_json_sha256': packageJsonSha256,
            'analysis_options_sha256': analysisOptionsSha256,
            'generator_source_sha256': generatorSourceSha256,
            'runner_source_sha256': runnerSourceSha256,
            'test_source_sha256': testSourceSha256,
            'declared_entrypoint':
                'npm run --silent algorithm:direct-edge-probe',
            'root_source_snapshot_sha256': rootSourceSnapshotSha256,
            'lib_source_snapshot_sha256': libSourceSnapshotSha256,
            'analysis_context_count': analysisContextCount,
            'source_file_count': sourceFileCount,
            'expected_root_count': 63,
            'accepted_root_count': acceptedRootCount,
            'accepted_source_unit_count': acceptedSourceUnitCount,
            'source_inventory_reconciled': sourceInventoryReconciled,
            'reachability_budgets': {
              'max_nodes_per_root': _maxReachabilityNodesPerRoot,
              'max_edges_per_root': _maxReachabilityEdgesPerRoot,
              'max_depth_per_root': _maxReachabilityDepthPerRoot,
              'max_source_units_per_root': _maxReachabilitySourceUnitsPerRoot,
            },
            'compatibility_accepted': compatibilityAccepted,
            'environment_hold_reasons': environmentHoldReasons,
            'uncovered_edge_classes': uncoveredEdgeClasses,
            'roots': roots.map((root) => root.toJson()).toList(),
            'edges': edges.map((edge) => edge.toJson()).toList(),
            'declaration_edges': declarationEdges
                .map((edge) => edge.toJson())
                .toList(),
            'namespace_edges': namespaceEdges
                .map((edge) => edge.toJson())
                .toList(),
            'unresolved': unresolved.map((edge) => edge.toJson()).toList(),
            'source_unresolved': sourceUnresolved
                .map((edge) => edge.toJson())
                .toList(),
            'source_units': sourceUnits.map((unit) => unit.toJson()).toList(),
            'part_ownership': _buildPartOwnershipRows(
              sourceUnits: sourceUnits,
              namespaceEdges: namespaceEdges,
            ),
            'supported_call_reachability': supportedCallReachability
                .map((summary) => summary.toJson())
                .toList(),
            'supported_call_reverse_ownership': supportedCallReverseReachability
                .map((summary) => summary.toJson())
                .toList(),
            'supported_call_reverse_source_ownership':
                supportedCallReverseSourceOwnership
                    .map((summary) => summary.toJson())
                    .toList(),
            'reachability_holds': reachabilityHolds
                .map((hold) => hold.toJson())
                .toList(),
          })
          as Map<String, Object?>;

  String get canonicalJson => jsonEncode(canonicalPayload);

  String get sha256Digest => _sha256(utf8.encode(canonicalJson));

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'sha256': sha256Digest,
  };
}

/// Computes a bounded forward-reachability preview over supported direct-call
/// edges. Every unsupported or out-of-scope condition remains an explicit
/// blocker; this function never reports complete closure.
AlgorithmCallReachabilityResult computeAlgorithmSupportedCallReachability({
  required Iterable<AlgorithmDirectEdgeRootObservation> roots,
  required Iterable<AlgorithmDirectDependencyEdge> rootEdges,
  required Iterable<AlgorithmDeclarationDependencyEdge> declarationEdges,
  required Iterable<AlgorithmNamespaceDependencyEdge> namespaceEdges,
  required Iterable<AlgorithmUnresolvedDirectEdge> rootUnresolved,
  required Iterable<AlgorithmUnresolvedSourceEdge> sourceUnresolved,
  required Iterable<AlgorithmSourceUnitObservation> sourceUnits,
  int maxNodesPerRoot = _maxReachabilityNodesPerRoot,
  int maxEdgesPerRoot = _maxReachabilityEdgesPerRoot,
  int maxDepthPerRoot = _maxReachabilityDepthPerRoot,
  int maxSourceUnitsPerRoot = _maxReachabilitySourceUnitsPerRoot,
}) {
  if (maxNodesPerRoot < 1 ||
      maxEdgesPerRoot < 1 ||
      maxDepthPerRoot < 1 ||
      maxSourceUnitsPerRoot < 1) {
    throw ArgumentError('Reachability budgets must be positive integers.');
  }
  final sortedRoots = [...roots]
    ..sort((left, right) => left.algorithmId.compareTo(right.algorithmId));
  final edgesByAlgorithm = <String, List<AlgorithmDirectDependencyEdge>>{};
  for (final edge in rootEdges) {
    edgesByAlgorithm.putIfAbsent(edge.algorithmId, () => []).add(edge);
  }
  final declarationsByCaller =
      <String, List<AlgorithmDeclarationDependencyEdge>>{};
  final declarationKeys = <String>{};
  for (final edge in declarationEdges) {
    declarationsByCaller
        .putIfAbsent(edge.sourceDeclarationIdentity, () => [])
        .add(edge);
    declarationKeys.add(_declarationEdgeKey(edge));
  }
  for (final edges in declarationsByCaller.values) {
    edges.sort(
      (left, right) => _declarationEdgeOrderKey(
        left,
      ).compareTo(_declarationEdgeOrderKey(right)),
    );
  }

  final unitsByUri = {
    for (final unit in sourceUnits) unit.sourcePackageUri: unit,
  };
  final acceptedPartOwners = <String, String>{
    for (final row in _buildPartOwnershipRows(
      sourceUnits: sourceUnits,
      namespaceEdges: namespaceEdges,
    ))
      if (row['ownership_state'] == 'accepted' &&
          row['part_package_uri'] is String &&
          row['containing_library_package_uri'] is String)
        row['part_package_uri'] as String:
            row['containing_library_package_uri'] as String,
  };
  final sourceHoldsByUri = <String, List<AlgorithmUnresolvedSourceEdge>>{};
  for (final hold in sourceUnresolved) {
    sourceHoldsByUri.putIfAbsent(hold.sourcePackageUri, () => []).add(hold);
  }
  final rootHoldsByAlgorithm = <String, List<AlgorithmUnresolvedDirectEdge>>{};
  for (final hold in rootUnresolved) {
    rootHoldsByAlgorithm.putIfAbsent(hold.algorithmId, () => []).add(hold);
  }
  final rootsByUri = <String, List<AlgorithmDirectEdgeRootObservation>>{};
  for (final root in sortedRoots) {
    rootsByUri.putIfAbsent(root.canonicalPackageUri, () => []).add(root);
  }
  final namespaceByUri = <String, List<AlgorithmNamespaceDependencyEdge>>{};
  for (final edge in namespaceEdges) {
    namespaceByUri.putIfAbsent(edge.sourcePackageUri, () => []).add(edge);
  }
  for (final edges in namespaceByUri.values) {
    edges.sort((left, right) {
      final leftKey =
          '${_namespaceBranchKey(left)}\u0000${_namespaceBranchSemanticKey(left)}';
      final rightKey =
          '${_namespaceBranchKey(right)}\u0000${_namespaceBranchSemanticKey(right)}';
      return leftKey.compareTo(rightKey);
    });
  }

  final holdCounts = <String, _ReachabilityHoldCount>{};
  void addHold({
    required AlgorithmDirectEdgeRootObservation root,
    required String sourcePackageUri,
    required String edgeKind,
    required String reason,
    int count = 1,
  }) {
    if (count <= 0) return;
    final hold = _ReachabilityHoldCount(
      algorithmId: root.algorithmId,
      logicalRootId: root.logicalRootId,
      sourcePackageUri: sourcePackageUri,
      edgeKind: edgeKind,
      reason: reason,
    );
    final existing = holdCounts.putIfAbsent(hold.key, () => hold);
    existing.count += count;
  }

  final summaries = <AlgorithmSupportedCallReachability>[];
  for (final root in sortedRoots) {
    final algorithmEdges = [...?edgesByAlgorithm[root.algorithmId]]
      ..sort((left, right) {
        final leftKey = _directEdgeOrderKey(left);
        final rightKey = _directEdgeOrderKey(right);
        return leftKey.compareTo(rightKey);
      });
    final rootGroups = <String, int>{};
    final sourceGroups = <String, int>{};
    final reachedDeclarations = <String>{};
    final reachedEdges = <AlgorithmDeclarationDependencyEdge>[];
    final visitedSources = <String>{};
    final reachedNamespaceBranchSemantics = <String, Set<String>>{};
    final visitedRootUris = <String>{root.canonicalPackageUri};
    final queueDeclarations = <String>[];
    final queueDepths = <int>[];
    final queuedDeclarations = <String>{};
    final acceptedSeeds = <String>{};
    var budgetExceeded = false;
    var stopTraversal = false;
    var externalEdgeCount = 0;
    var maximumDepth = 0;

    void recordRootHold(String sourceUri, AlgorithmUnresolvedDirectEdge hold) {
      final key = '$sourceUri\u0000${hold.edgeKind}\u0000${hold.reason}';
      rootGroups.update(
        key,
        (value) => value + hold.count,
        ifAbsent: () => hold.count,
      );
      addHold(
        root: root,
        sourcePackageUri: sourceUri,
        edgeKind: hold.edgeKind,
        reason: hold.reason,
        count: hold.count,
      );
    }

    void recordSourceHold(AlgorithmUnresolvedSourceEdge hold) {
      final key =
          '${hold.sourcePackageUri}\u0000${hold.edgeKind}\u0000${hold.reason}';
      sourceGroups.update(
        key,
        (value) => value + hold.count,
        ifAbsent: () => hold.count,
      );
      addHold(
        root: root,
        sourcePackageUri: hold.sourcePackageUri,
        edgeKind: hold.edgeKind,
        reason: hold.reason,
        count: hold.count,
      );
    }

    for (final hold in rootHoldsByAlgorithm[root.algorithmId] ?? const []) {
      recordRootHold(root.canonicalPackageUri, hold);
    }
    for (final edge in algorithmEdges) {
      final callerUri = _libraryUriForDeclarationIdentity(
        edge.sourceDeclarationIdentity,
      );
      if (callerUri != root.canonicalPackageUri) {
        addHold(
          root: root,
          sourcePackageUri: edge.sourcePackageUri,
          edgeKind: 'root_seed',
          reason: 'registered_root_caller_library_mismatch',
        );
        continue;
      }
      if (!declarationKeys.contains(_declarationEdgeKeyFromRoot(edge))) {
        addHold(
          root: root,
          sourcePackageUri: edge.sourcePackageUri,
          edgeKind: edge.edgeKind,
          reason: 'root_edge_missing_from_source_graph',
        );
      }
      acceptedSeeds.add(edge.sourceDeclarationIdentity);
    }

    if (acceptedSeeds.length > maxNodesPerRoot) {
      final omitted = acceptedSeeds.length - maxNodesPerRoot;
      acceptedSeeds.removeAll(
        (acceptedSeeds.toList()..sort()).skip(maxNodesPerRoot),
      );
      budgetExceeded = true;
      addHold(
        root: root,
        sourcePackageUri: root.canonicalPackageUri,
        edgeKind: 'reachability_budget',
        reason: 'node_budget_exceeded',
        count: omitted,
      );
    }

    void visitLibraryScope(String packageUri) {
      if (visitedSources.contains(packageUri)) return;
      if (visitedSources.length >= maxSourceUnitsPerRoot) {
        budgetExceeded = true;
        addHold(
          root: root,
          sourcePackageUri: packageUri,
          edgeKind: 'reachability_budget',
          reason: 'source_unit_budget_exceeded',
        );
        return;
      }
      visitedSources.add(packageUri);
      final unit = unitsByUri[packageUri];
      if (unit == null) {
        addHold(
          root: root,
          sourcePackageUri: packageUri,
          edgeKind: 'source_unit',
          reason: 'reachable_library_not_in_source_inventory',
        );
      } else if (!unit.accepted) {
        addHold(
          root: root,
          sourcePackageUri: packageUri,
          edgeKind: 'source_unit',
          reason: 'reachable_library_unit_not_accepted',
        );
      }
      for (final hold in sourceHoldsByUri[packageUri] ?? const []) {
        recordSourceHold(hold);
      }
      if (visitedRootUris.add(packageUri)) {
        for (final registeredRoot in rootsByUri[packageUri] ?? const []) {
          for (final hold
              in rootHoldsByAlgorithm[registeredRoot.algorithmId] ?? const []) {
            recordRootHold(packageUri, hold);
          }
        }
      }
      for (final namespace in namespaceByUri[packageUri] ?? const []) {
        final branchKey = _namespaceBranchKey(namespace);
        final semanticKey = _namespaceBranchSemanticKey(namespace);
        final semanticVariants = reachedNamespaceBranchSemantics.putIfAbsent(
          branchKey,
          () => <String>{},
        );
        if (!semanticVariants.add(semanticKey)) continue;
        if (semanticVariants.length > 1) {
          addHold(
            root: root,
            sourcePackageUri: packageUri,
            edgeKind: namespace.directiveKind,
            reason: 'namespace_branch_semantics_conflict',
          );
        }
        if (namespace.directiveKind == 'part') {
          final partUri = namespace.targetPackageUri;
          if (partUri != null) {
            if (acceptedPartOwners[partUri] == packageUri) {
              visitLibraryScope(partUri);
            } else {
              addHold(
                root: root,
                sourcePackageUri: partUri,
                edgeKind: 'part_directive',
                reason: 'part_ownership_not_analyzer_validated',
              );
              for (final hold in sourceHoldsByUri[partUri] ?? const []) {
                recordSourceHold(hold);
              }
            }
          } else {
            addHold(
              root: root,
              sourcePackageUri: packageUri,
              edgeKind: 'part_directive',
              reason: 'part_target_unresolved',
            );
          }
        }
        if (namespace.directiveKind == 'import' ||
            namespace.directiveKind == 'export') {
          final targetUri = namespace.targetPackageUri;
          if (targetUri == null) {
            addHold(
              root: root,
              sourcePackageUri: packageUri,
              edgeKind: namespace.directiveKind,
              reason: 'namespace_target_unresolved',
            );
          } else {
            final targetUnit = unitsByUri[targetUri];
            if (targetUnit == null) {
              addHold(
                root: root,
                sourcePackageUri: packageUri,
                edgeKind: namespace.directiveKind,
                reason: 'namespace_target_outside_lib_source_inventory',
              );
            } else if (!targetUnit.accepted) {
              addHold(
                root: root,
                sourcePackageUri: packageUri,
                edgeKind: namespace.directiveKind,
                reason: 'namespace_target_source_unit_not_accepted',
              );
            } else {
              visitLibraryScope(targetUri);
            }
          }
        }
        if (namespace.conditionName != null ||
            namespace.conditionValue != null) {
          addHold(
            root: root,
            sourcePackageUri: packageUri,
            edgeKind: namespace.directiveKind,
            reason: 'conditional_namespace_selection_semantics_unmodeled',
          );
        }
        if (namespace.deferred) {
          addHold(
            root: root,
            sourcePackageUri: packageUri,
            edgeKind: namespace.directiveKind,
            reason: 'deferred_namespace_load_not_modeled',
          );
        }
      }
    }

    for (final seed in acceptedSeeds.toList()..sort()) {
      reachedDeclarations.add(seed);
      queueDeclarations.add(seed);
      queueDepths.add(0);
      queuedDeclarations.add(seed);
    }
    visitLibraryScope(root.canonicalPackageUri);

    var cursor = 0;
    while (cursor < queueDeclarations.length && !stopTraversal) {
      final sourceIdentity = queueDeclarations[cursor];
      final depth = queueDepths[cursor];
      cursor += 1;
      final sourceUri = _libraryUriForDeclarationIdentity(sourceIdentity);
      if (sourceUri == null) {
        addHold(
          root: root,
          sourcePackageUri: root.canonicalPackageUri,
          edgeKind: 'source_declaration',
          reason: 'reachable_declaration_identity_malformed',
        );
        continue;
      }
      visitLibraryScope(sourceUri);
      if (!visitedSources.contains(sourceUri)) continue;
      final unit = unitsByUri[sourceUri];
      if (unit == null || !unit.accepted) continue;
      for (final edge in declarationsByCaller[sourceIdentity] ?? const []) {
        final edgeSourceJoined =
            edge.sourcePackageUri == sourceUri ||
            (acceptedPartOwners[edge.sourcePackageUri] == sourceUri &&
                visitedSources.contains(edge.sourcePackageUri));
        if (!edgeSourceJoined) {
          addHold(
            root: root,
            sourcePackageUri: edge.sourcePackageUri,
            edgeKind: edge.edgeKind,
            reason: 'part_or_augment_source_ownership_not_joined',
          );
          continue;
        }
        final targetUri = _libraryUriForDeclarationIdentity(
          edge.targetIdentity,
        );
        if (targetUri == null || targetUri != edge.targetLibraryUri) {
          addHold(
            root: root,
            sourcePackageUri: sourceUri,
            edgeKind: edge.edgeKind,
            reason: 'target_identity_library_mismatch',
          );
          continue;
        }
        if (reachedEdges.length >= maxEdgesPerRoot) {
          budgetExceeded = true;
          stopTraversal = true;
          addHold(
            root: root,
            sourcePackageUri: sourceUri,
            edgeKind: 'reachability_budget',
            reason: 'edge_budget_exceeded',
          );
          break;
        }
        reachedEdges.add(edge);
        final targetDepth = depth + 1;
        if (targetDepth > maximumDepth) maximumDepth = targetDepth;
        if (!reachedDeclarations.contains(edge.targetIdentity) &&
            reachedDeclarations.length >= maxNodesPerRoot) {
          budgetExceeded = true;
          addHold(
            root: root,
            sourcePackageUri: sourceUri,
            edgeKind: 'reachability_budget',
            reason: 'node_budget_exceeded',
          );
          continue;
        }
        reachedDeclarations.add(edge.targetIdentity);
        if (edge.targetScope == 'local_package') {
          final targetUnit = unitsByUri[targetUri];
          if (targetUnit == null) {
            addHold(
              root: root,
              sourcePackageUri: sourceUri,
              edgeKind: edge.edgeKind,
              reason: 'local_target_not_in_source_inventory',
            );
            continue;
          }
          if (!targetUnit.accepted) {
            addHold(
              root: root,
              sourcePackageUri: targetUri,
              edgeKind: edge.edgeKind,
              reason: 'local_target_source_unit_not_accepted',
            );
            continue;
          }
          if (targetDepth > maxDepthPerRoot) {
            budgetExceeded = true;
            addHold(
              root: root,
              sourcePackageUri: sourceUri,
              edgeKind: 'reachability_budget',
              reason: 'depth_budget_exceeded',
            );
            continue;
          }
          if (queuedDeclarations.add(edge.targetIdentity)) {
            queueDeclarations.add(edge.targetIdentity);
            queueDepths.add(targetDepth);
          }
        } else if (edge.targetScope == 'external_or_sdk') {
          externalEdgeCount += 1;
          addHold(
            root: root,
            sourcePackageUri: sourceUri,
            edgeKind: edge.edgeKind,
            reason: 'external_target_not_traversed',
          );
        } else {
          addHold(
            root: root,
            sourcePackageUri: sourceUri,
            edgeKind: edge.edgeKind,
            reason: 'target_scope_unrecognized',
          );
        }
      }
    }

    if (reachedDeclarations.length > maxNodesPerRoot) {
      throw StateError('Reachability node budget accounting exceeded.');
    }
    final cyclicComponents = _findReachableStronglyConnectedComponents(
      declarations: reachedDeclarations,
      edges: reachedEdges,
      unitsByUri: unitsByUri,
      maxNodes: maxNodesPerRoot,
      maxEdges: maxEdgesPerRoot,
    );
    final currentHolds =
        holdCounts.values
            .where((hold) => hold.algorithmId == root.algorithmId)
            .toList()
          ..sort((left, right) => left.key.compareTo(right.key));
    final reachedEdgeJson = reachedEdges.map((edge) => edge.toJson()).toList()
      ..sort((left, right) {
        final leftKey = _declarationEdgeOrderKeyFromJson(left);
        final rightKey = _declarationEdgeOrderKeyFromJson(right);
        return leftKey.compareTo(rightKey);
      });
    final reachableNamespaceRows =
        reachedNamespaceBranchSemantics.entries
            .map(
              (entry) => <String, Object?>{
                'branch_key': entry.key,
                'semantic_variants': entry.value.toList()..sort(),
              },
            )
            .toList()
          ..sort(
            (left, right) => (left['branch_key'] as String).compareTo(
              right['branch_key'] as String,
            ),
          );
    final reachableSourceUris = visitedSources.toList()..sort();
    final graphDigest = _sha256(
      utf8.encode(
        jsonEncode(
          _canonicalize({
            'algorithm_id': root.algorithmId,
            'logical_root_id': root.logicalRootId,
            'root_package_uri': root.canonicalPackageUri,
            'seed_declarations': acceptedSeeds.toList()..sort(),
            'reachable_declarations': reachedDeclarations.toList()..sort(),
            'reachable_edges': reachedEdgeJson,
            'reachable_source_units': reachableSourceUris,
            'reachable_namespace_branches': reachableNamespaceRows,
            'cyclic_components': cyclicComponents
                .map((component) => component.toJson())
                .toList(),
            'reachability_holds': currentHolds
                .map((hold) => hold.toEdge().toJson())
                .toList(),
            'budget_exceeded': budgetExceeded,
          }),
        ),
      ),
    );
    final totalRootHoldCount = rootGroups.values.fold<int>(
      0,
      (total, count) => total + count,
    );
    final totalSourceHoldCount = sourceGroups.values.fold<int>(
      0,
      (total, count) => total + count,
    );
    final totalBlockerCount = currentHolds.fold<int>(
      0,
      (total, hold) => total + hold.count,
    );
    summaries.add(
      AlgorithmSupportedCallReachability(
        algorithmId: root.algorithmId,
        logicalRootId: root.logicalRootId,
        rootPackageUri: root.canonicalPackageUri,
        seedDeclarationCount: acceptedSeeds.length,
        reachableDeclarationCount: reachedDeclarations.length,
        reachableEdgeCount: reachedEdges.length,
        reachableSourceUnitCount: visitedSources.length,
        reachableNamespaceBranchCount: reachedNamespaceBranchSemantics.length,
        reachableSourcePackageUris: visitedSources.where(
          (uri) => unitsByUri[uri]?.accepted ?? false,
        ),
        externalEdgeCount: externalEdgeCount,
        maximumDepth: maximumDepth,
        rootUnresolvedGroupCount: rootGroups.length,
        rootUnresolvedOccurrenceCount: totalRootHoldCount,
        sourceUnresolvedGroupCount: sourceGroups.length,
        sourceUnresolvedOccurrenceCount: totalSourceHoldCount,
        blockerGroupCount: currentHolds.length,
        blockerOccurrenceCount: totalBlockerCount,
        budgetExceeded: budgetExceeded,
        reachableGraphSha256: graphDigest,
        reachableDeclarationIdentities: reachedDeclarations,
        cyclicComponents: cyclicComponents,
      ),
    );
  }

  if (holdCounts.length > _maxUnresolved) {
    throw StateError(
      'Reachability blocker set exceeded its deterministic cap.',
    );
  }
  final reverseOwners = <String, Set<String>>{};
  var reverseOwnershipPairCount = 0;
  for (final summary in summaries) {
    for (final declarationIdentity in summary.reachableDeclarationIdentities) {
      final owners = reverseOwners.putIfAbsent(
        declarationIdentity,
        () => <String>{},
      );
      if (owners.add(summary.algorithmId)) {
        reverseOwnershipPairCount += 1;
        if (reverseOwnershipPairCount > _maxReverseReachabilityPairs) {
          throw StateError(
            'Reverse reachability ownership exceeded its deterministic cap.',
          );
        }
      }
    }
  }
  final reverseSourceOwners = <String, Set<String>>{};
  var reverseSourceOwnershipPairCount = 0;
  for (final summary in summaries) {
    for (final sourcePackageUri in summary.reachableSourcePackageUris) {
      final owners = reverseSourceOwners.putIfAbsent(
        sourcePackageUri,
        () => <String>{},
      );
      if (owners.add(summary.algorithmId)) {
        reverseSourceOwnershipPairCount += 1;
        if (reverseSourceOwnershipPairCount > _maxReverseReachabilityPairs) {
          throw StateError(
            'Reverse source ownership exceeded its deterministic cap.',
          );
        }
      }
    }
  }
  return AlgorithmCallReachabilityResult(
    summaries: summaries,
    holds: holdCounts.values.map((hold) => hold.toEdge()),
    reverseReachability: [
      for (final entry in reverseOwners.entries)
        AlgorithmSupportedCallReverseReachability(
          declarationIdentity: entry.key,
          algorithmIds: entry.value,
        ),
    ],
    reverseSourceOwnership: [
      for (final entry in reverseSourceOwners.entries)
        AlgorithmSupportedCallReverseSourceOwnership(
          sourcePackageUri: entry.key,
          algorithmIds: entry.value,
        ),
    ],
  );
}

List<AlgorithmSupportedCallCycle> _findReachableStronglyConnectedComponents({
  required Set<String> declarations,
  required List<AlgorithmDeclarationDependencyEdge> edges,
  required Map<String, AlgorithmSourceUnitObservation> unitsByUri,
  required int maxNodes,
  required int maxEdges,
}) {
  if (declarations.length > maxNodes || edges.length > maxEdges) {
    throw StateError('SCC input exceeded a deterministic reachability budget.');
  }
  final acceptedLocalDeclarations = declarations.where((identity) {
    final uri = _libraryUriForDeclarationIdentity(identity);
    return uri != null &&
        uri.startsWith('package:') &&
        (unitsByUri[uri]?.accepted ?? false);
  }).toList()..sort();
  final adjacency = <String, Set<String>>{
    for (final identity in acceptedLocalDeclarations) identity: <String>{},
  };
  for (final edge in edges) {
    if (edge.targetScope != 'local_package' ||
        !adjacency.containsKey(edge.sourceDeclarationIdentity) ||
        !adjacency.containsKey(edge.targetIdentity)) {
      continue;
    }
    adjacency[edge.sourceDeclarationIdentity]!.add(edge.targetIdentity);
  }
  final sortedAdjacency = <String, List<String>>{
    for (final entry in adjacency.entries)
      entry.key: entry.value.toList()..sort(),
  };

  final visited = <String>{};
  final finishingOrder = <String>[];
  for (final start in acceptedLocalDeclarations) {
    if (!visited.add(start)) continue;
    final stack = <_GraphDfsFrame>[_GraphDfsFrame(start)];
    while (stack.isNotEmpty) {
      final frame = stack.last;
      final neighbors = sortedAdjacency[frame.node]!;
      if (frame.nextNeighborIndex < neighbors.length) {
        final neighbor = neighbors[frame.nextNeighborIndex++];
        if (visited.add(neighbor)) stack.add(_GraphDfsFrame(neighbor));
      } else {
        finishingOrder.add(frame.node);
        stack.removeLast();
      }
    }
  }

  final reverseAdjacency = <String, List<String>>{
    for (final identity in acceptedLocalDeclarations) identity: <String>[],
  };
  for (final entry in sortedAdjacency.entries) {
    for (final target in entry.value) {
      reverseAdjacency[target]!.add(entry.key);
    }
  }
  for (final neighbors in reverseAdjacency.values) {
    neighbors.sort();
  }

  final assigned = <String>{};
  final cycles = <AlgorithmSupportedCallCycle>[];
  for (final start in finishingOrder.reversed) {
    if (!assigned.add(start)) continue;
    final component = <String>[];
    final stack = <String>[start];
    while (stack.isNotEmpty) {
      final node = stack.removeLast();
      component.add(node);
      for (final neighbor in reverseAdjacency[node]!.reversed) {
        if (assigned.add(neighbor)) stack.add(neighbor);
      }
    }
    component.sort();
    final hasSelfLoop =
        component.length == 1 &&
        sortedAdjacency[component.single]!.contains(component.single);
    if (component.length < 2 && !hasSelfLoop) continue;
    final digest = _sha256(utf8.encode(jsonEncode(component)));
    cycles.add(
      AlgorithmSupportedCallCycle(
        cycleSha256: digest,
        declarationIdentities: component,
      ),
    );
  }
  cycles.sort((left, right) => left.cycleSha256.compareTo(right.cycleSha256));
  return List.unmodifiable(cycles);
}

class _GraphDfsFrame {
  final String node;
  int nextNeighborIndex = 0;

  _GraphDfsFrame(this.node);
}

String? _libraryUriForDeclarationIdentity(String identity) {
  final separator = identity.indexOf('#');
  if (separator <= 0) return null;
  final libraryUri = identity.substring(0, separator);
  if (!libraryUri.startsWith('package:') && !libraryUri.startsWith('dart:')) {
    return null;
  }
  return libraryUri;
}

String _declarationEdgeKey(AlgorithmDeclarationDependencyEdge edge) =>
    '${edge.sourcePackageUri}\u0000${edge.sourceDeclarationIdentity}\u0000${edge.targetIdentity}\u0000${edge.targetLibraryUri}\u0000${edge.edgeKind}\u0000${edge.targetScope}';

String _declarationEdgeKeyFromRoot(AlgorithmDirectDependencyEdge edge) =>
    '${edge.sourcePackageUri}\u0000${edge.sourceDeclarationIdentity}\u0000${edge.targetIdentity}\u0000${edge.targetLibraryUri}\u0000${edge.edgeKind}\u0000${edge.targetScope}';

String _namespaceBranchKey(AlgorithmNamespaceDependencyEdge edge) =>
    '${edge.sourcePackageUri}\u0000${edge.directiveIndex.toString().padLeft(8, '0')}\u0000${edge.branchIndex.toString().padLeft(8, '0')}';

String _namespaceBranchSemanticKey(AlgorithmNamespaceDependencyEdge edge) =>
    jsonEncode(
      _canonicalize({
        'source_package_uri': edge.sourcePackageUri,
        'directive_index': edge.directiveIndex,
        'branch_index': edge.branchIndex,
        'directive_kind': edge.directiveKind,
        'uri_literal': edge.uriLiteral,
        'target_package_uri': edge.targetPackageUri,
        'symbolic_target': edge.symbolicTarget,
        'condition_name': edge.conditionName,
        'condition_value': edge.conditionValue,
        'prefix': edge.prefix,
        'deferred': edge.deferred,
        'combinators': edge.combinators,
      }),
    );

String _declarationEdgeOrderKey(AlgorithmDeclarationDependencyEdge edge) =>
    _declarationEdgeKey(edge);

String _declarationEdgeOrderKeyFromJson(Map<String, Object?> edge) =>
    '${edge['source_package_uri']}\u0000${edge['source_declaration_identity']}\u0000${edge['target_identity']}\u0000${edge['target_library_uri']}\u0000${edge['edge_kind']}\u0000${edge['target_scope']}';

String _directEdgeOrderKey(AlgorithmDirectDependencyEdge edge) =>
    '${edge.sourceDeclarationIdentity}\u0000${edge.edgeKind}\u0000${edge.targetIdentity}\u0000${edge.targetLibraryUri}';

String _reachabilityHoldKey(AlgorithmCallReachabilityHold hold) =>
    '${hold.algorithmId}\u0000${hold.logicalRootId}\u0000${hold.sourcePackageUri}\u0000${hold.edgeKind}\u0000${hold.reason}';

class _ReachabilityHoldCount {
  final String algorithmId;
  final String logicalRootId;
  final String sourcePackageUri;
  final String edgeKind;
  final String reason;
  int count = 0;

  _ReachabilityHoldCount({
    required this.algorithmId,
    required this.logicalRootId,
    required this.sourcePackageUri,
    required this.edgeKind,
    required this.reason,
  });

  String get key =>
      '$algorithmId\u0000$logicalRootId\u0000$sourcePackageUri\u0000$edgeKind\u0000$reason';

  AlgorithmCallReachabilityHold toEdge() => AlgorithmCallReachabilityHold(
    algorithmId: algorithmId,
    logicalRootId: logicalRootId,
    sourcePackageUri: sourcePackageUri,
    edgeKind: edgeKind,
    reason: reason,
    count: count,
  );
}

class _RootCallEdgeCollector extends RecursiveAstVisitor<void> {
  final String? algorithmId;
  final String? logicalRootId;
  final String sourcePackageUri;
  final String repositoryRoot;
  final String packageName;
  final Map<String, Element> elementOwners;
  final Set<AlgorithmDirectDependencyEdge> edges = {};
  final Set<AlgorithmDeclarationDependencyEdge> declarationEdges = {};
  final Set<AlgorithmNamespaceDependencyEdge> namespaceEdges = {};
  final List<AlgorithmUnresolvedDirectEdge> unresolved = [];
  final List<AlgorithmUnresolvedSourceEdge> sourceUnresolved = [];
  String? _currentCallerIdentity;

  _RootCallEdgeCollector({
    required this.algorithmId,
    required this.logicalRootId,
    required this.sourcePackageUri,
    required this.repositoryRoot,
    required this.packageName,
    required this.elementOwners,
  });

  void collect(CompilationUnit unit) {
    _collectNamespaceEdges(unit);
    visitCompilationUnit(unit);
  }

  @override
  void visitFunctionTypeAlias(FunctionTypeAlias node) {
    final element = node.declaredFragment?.element;
    _recordTypeAliasDeclaration(element);
    super.visitFunctionTypeAlias(node);
  }

  @override
  void visitGenericTypeAlias(GenericTypeAlias node) {
    final element = node.declaredFragment?.element;
    _recordTypeAliasDeclaration(element);
    super.visitGenericTypeAlias(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _withCaller(node.declaredFragment?.element, () {
      final extendsClause = node.extendsClause;
      if (extendsClause != null) {
        _recordNamedTypeRelation(
          extendsClause.superclass,
          'inheritance_extends',
        );
      }
      for (final mixin in node.withClause?.mixinTypes ?? const <NamedType>[]) {
        _recordNamedTypeRelation(mixin, 'inheritance_mixin');
      }
      for (final type
          in node.implementsClause?.interfaces ?? const <NamedType>[]) {
        _recordNamedTypeRelation(type, 'inheritance_implements');
      }
    });
    super.visitClassDeclaration(node);
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    _withCaller(node.declaredFragment?.element, () {
      for (final mixin in node.withClause?.mixinTypes ?? const <NamedType>[]) {
        _recordNamedTypeRelation(mixin, 'inheritance_mixin');
      }
      for (final type
          in node.implementsClause?.interfaces ?? const <NamedType>[]) {
        _recordNamedTypeRelation(type, 'inheritance_implements');
      }
    });
    super.visitEnumDeclaration(node);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    _withCaller(node.declaredFragment?.element, () {
      for (final type
          in node.onClause?.superclassConstraints ?? const <NamedType>[]) {
        _recordNamedTypeRelation(type, 'mixin_on_constraint');
      }
      for (final type
          in node.implementsClause?.interfaces ?? const <NamedType>[]) {
        _recordNamedTypeRelation(type, 'inheritance_implements');
      }
    });
    super.visitMixinDeclaration(node);
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    _withCaller(node.declaredFragment?.element, () {
      final onClause = node.onClause;
      if (onClause != null) {
        _recordTypeAnnotationRelation(
          onClause.extendedType,
          'extension_on_type',
        );
      }
    });
    super.visitExtensionDeclaration(node);
  }

  @override
  void visitExtensionTypeDeclaration(ExtensionTypeDeclaration node) {
    _withCaller(node.declaredFragment?.element, () {
      for (final type
          in node.implementsClause?.interfaces ?? const <NamedType>[]) {
        _recordNamedTypeRelation(type, 'extension_type_implements');
      }
      final element = node.declaredFragment?.element;
      if (element is ExtensionTypeElement) {
        _recordResolvedTypeRelation(
          element.representation.type,
          'extension_type_representation',
        );
      } else {
        _hold(
          'extension_type_representation',
          'extension_type_representation_element_unavailable',
        );
      }
    });
    super.visitExtensionTypeDeclaration(node);
  }

  @override
  void visitIsExpression(IsExpression node) {
    _recordTypeAnnotationRelation(node.type, 'type_test');
    super.visitIsExpression(node);
  }

  @override
  void visitAsExpression(AsExpression node) {
    _recordTypeAnnotationRelation(node.type, 'type_cast');
    super.visitAsExpression(node);
  }

  @override
  void visitTypeLiteral(TypeLiteral node) {
    _recordNamedTypeRelation(node.type, 'type_literal');
    super.visitTypeLiteral(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final local = node.parent is FunctionDeclarationStatement;
    _withCaller(
      node.declaredFragment?.element,
      () => super.visitFunctionDeclaration(node),
      preserveParentWhenUnavailable: local,
    );
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _withCaller(
      node.declaredFragment?.element,
      () => super.visitMethodDeclaration(node),
    );
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    _withCaller(node.declaredFragment?.element, () {
      _recordConstructorDependencies(node.declaredFragment?.element);
      super.visitConstructorDeclaration(node);
    });
  }

  @override
  void visitPrimaryConstructorDeclaration(PrimaryConstructorDeclaration node) {
    _withCaller(node.declaredFragment?.element, () {
      _recordConstructorDependencies(node.declaredFragment?.element);
      super.visitPrimaryConstructorDeclaration(node);
    });
  }

  @override
  void visitConstructorFieldInitializer(ConstructorFieldInitializer node) {
    final element = node.fieldName.element;
    if (element == null) {
      _hold(
        'constructor_field_initialization',
        'constructor_field_target_unresolved',
      );
    } else {
      _record(element, 'constructor_field_initialization');
    }
    super.visitConstructorFieldInitializer(node);
  }

  @override
  void visitFieldFormalParameter(FieldFormalParameter node) {
    final element = node.declaredFragment?.element;
    if (element is! FieldFormalParameterElement) {
      _hold(
        'constructor_field_initialization',
        'field_formal_parameter_target_unresolved',
      );
    } else {
      final field = element.field;
      if (field == null) {
        _hold(
          'constructor_field_initialization',
          'field_formal_parameter_field_unresolved',
        );
      } else {
        _record(field, 'constructor_field_initialization');
      }
    }
    super.visitFieldFormalParameter(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (_currentCallerIdentity != null) {
      super.visitVariableDeclaration(node);
      return;
    }
    _withCaller(
      node.declaredFragment?.element,
      () => super.visitVariableDeclaration(node),
    );
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final parent = node.parent;
    if (parent is PrefixedIdentifier && parent.identifier == node ||
        parent is PropertyAccess && parent.propertyName == node ||
        parent is MethodInvocation && parent.methodName == node ||
        parent is AssignmentExpression && parent.leftHandSide == node ||
        parent is PostfixExpression &&
            parent.operand == node &&
            _isIncrementOperator(parent.operator.lexeme) ||
        parent is PrefixExpression &&
            parent.operand == node &&
            _isIncrementOperator(parent.operator.lexeme) ||
        parent is FunctionReference) {
      super.visitSimpleIdentifier(node);
      return;
    }
    _recordExecutableReference(node.element, 'function_value_reference');
    _recordPropertyTarget(node.element, 'property_read');
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.parent is FunctionReference ||
        node.parent is MethodInvocation &&
            identical((node.parent as MethodInvocation).methodName, node)) {
      super.visitPrefixedIdentifier(node);
      return;
    }
    _recordExecutableReference(node.element, 'function_value_reference');
    if (!_isWriteTarget(node)) {
      _recordPropertyTarget(node.element, 'property_read');
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (node.parent is FunctionReference ||
        node.parent is MethodInvocation &&
            identical((node.parent as MethodInvocation).methodName, node)) {
      super.visitPropertyAccess(node);
      return;
    }
    _recordExecutableReference(
      node.propertyName.element,
      'function_value_reference',
    );
    if (!_isWriteTarget(node)) {
      _recordPropertyTarget(node.propertyName.element, 'property_read');
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitFunctionReference(FunctionReference node) {
    _recordExecutableReference(
      _referencedExecutableElement(node.function),
      'function_value_reference',
      holdUnsupportedTarget: true,
    );
    super.visitFunctionReference(node);
  }

  @override
  void visitConstructorReference(ConstructorReference node) {
    _recordExecutableReference(
      node.constructorName.element,
      'constructor_tear_off',
      holdUnsupportedTarget: true,
    );
    super.visitConstructorReference(node);
  }

  @override
  void visitDotShorthandPropertyAccess(DotShorthandPropertyAccess node) {
    if (node.parent is! FunctionReference) {
      _recordExecutableReference(
        node.propertyName.element,
        'function_value_reference',
      );
    }
    super.visitDotShorthandPropertyAccess(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    _recordPropertyTarget(node.readElement, 'property_read');
    _recordPropertyTarget(node.writeElement, 'property_write');
    final left = node.leftHandSide;
    final isDynamicTarget = left is IndexExpression
        ? node.readType is DynamicType || _isDynamicExpression(left.realTarget)
        : _isDynamicExpression(left);
    if (left is IndexExpression) {
      _recordOperatorTarget(
        node.writeElement ?? left.element,
        'index_write',
        dynamicTargetPossible: _isDynamicExpression(left.realTarget),
      );
    }
    if (_isOverloadableCompoundAssignment(node.operator.lexeme)) {
      _recordOperatorTarget(
        node.element,
        'compound_assignment_operator',
        dynamicTargetPossible: isDynamicTarget,
      );
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    if (_isOverloadableOperator(node.operator.lexeme)) {
      _recordOperatorTarget(
        node.element,
        'binary_operator',
        dynamicTargetPossible: _isDynamicExpression(node.leftOperand),
      );
    }
    super.visitBinaryExpression(node);
  }

  @override
  void visitIndexExpression(IndexExpression node) {
    if (node.inGetterContext()) {
      final parent = node.parent;
      final readTarget = parent is CompoundAssignmentExpression
          ? parent.readElement ?? node.element
          : node.element;
      _recordOperatorTarget(
        readTarget,
        'index_read',
        dynamicTargetPossible:
            _isDynamicExpression(node.realTarget) ||
            (parent is CompoundAssignmentExpression &&
                parent.readType is DynamicType),
      );
    }
    super.visitIndexExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    if (_isIncrementOperator(node.operator.lexeme)) {
      _recordPropertyTarget(node.readElement, 'property_read');
      _recordPropertyTarget(node.writeElement, 'property_write');
    }
    if (_isOverloadablePrefixOperator(node.operator.lexeme) ||
        _isIncrementOperator(node.operator.lexeme)) {
      _recordOperatorTarget(
        node.element,
        'prefix_operator',
        dynamicTargetPossible: _isDynamicExpression(node.operand),
      );
      if (node.operand is IndexExpression &&
          _isIncrementOperator(node.operator.lexeme)) {
        _recordOperatorTarget(
          node.writeElement,
          'index_write',
          dynamicTargetPossible: _isDynamicExpression(
            (node.operand as IndexExpression).realTarget,
          ),
        );
      }
    }
    super.visitPrefixExpression(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    _recordPropertyTarget(node.readElement, 'property_read');
    _recordPropertyTarget(node.writeElement, 'property_write');
    if (_isIncrementOperator(node.operator.lexeme)) {
      _recordOperatorTarget(
        node.element,
        'postfix_operator',
        dynamicTargetPossible: _isDynamicExpression(node.operand),
      );
      if (node.operand is IndexExpression) {
        _recordOperatorTarget(
          node.writeElement,
          'index_write',
          dynamicTargetPossible: _isDynamicExpression(
            (node.operand as IndexExpression).realTarget,
          ),
        );
      }
    }
    super.visitPostfixExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final element = node.methodName.element;
    if (element is! ExecutableElement) {
      _hold('method_invocation', 'unresolved_static_target');
    } else {
      _record(element, 'method_invocation');
      if (element is MethodElement &&
          !element.isStatic &&
          element.enclosingElement is! ExtensionElement &&
          !element.isExtensionTypeMember) {
        _hold(
          'method_invocation',
          'possible_polymorphic_dispatch_target_set_unclosed',
        );
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final element = node.element;
    if (element == null) {
      _hold(
        'function_expression_invocation',
        'function_value_target_unresolved',
      );
    } else {
      _recordExecutableReference(
        element,
        'function_expression_invocation',
        holdUnsupportedTarget: true,
      );
      _hold(
        'function_expression_invocation',
        'function_value_target_set_unreviewed',
      );
    }
    super.visitFunctionExpressionInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final element = node.constructorName.element;
    if (element == null) {
      _hold('constructor_call', 'unresolved_constructor_target');
    } else {
      _record(element, 'constructor_call');
      if (element.isOriginImplicitDefault ||
          element.isOriginMixinApplication ||
          element.isOriginExtensionTypeRecovery) {
        _hold(
          'constructor_body',
          'implicit_or_generated_constructor_body_unreviewed',
        );
      }
    }
    super.visitInstanceCreationExpression(node);
  }

  void _recordConstructorDependencies(ConstructorElement? element) {
    if (element == null) {
      _hold('constructor_dependency', 'constructor_element_unresolved');
      return;
    }
    final redirectedConstructor = element.redirectedConstructor;
    if (redirectedConstructor != null) {
      _record(redirectedConstructor, 'constructor_redirection');
    }
    if (element.isGenerative) {
      final superConstructor = element.superConstructor;
      if (superConstructor == null) {
        _hold('super_constructor_call', 'super_constructor_target_unresolved');
      } else {
        _record(superConstructor, 'super_constructor_call');
      }
    }
  }

  void _record(Element element, String edgeKind) {
    final sourceDeclarationIdentity = _currentCallerIdentity;
    if (sourceDeclarationIdentity == null) {
      _hold(edgeKind, 'source_declaration_identity_unavailable');
      return;
    }
    final libraryUri = element.library?.uri;
    if (libraryUri == null) {
      _hold(edgeKind, 'target_library_identity_unavailable');
      return;
    }
    final normalizedLibraryUri = _normalizeLibraryUri(
      libraryUri,
      repositoryRoot: repositoryRoot,
      packageName: packageName,
    );
    if (normalizedLibraryUri == null) {
      _hold(edgeKind, 'target_library_identity_not_path_free');
      return;
    }
    final targetIdentity = _stableElementIdentity(
      element,
      libraryUri: normalizedLibraryUri,
    );
    if (targetIdentity == null) {
      _hold(edgeKind, 'target_declaration_identity_unavailable');
      return;
    }
    final previous = elementOwners[targetIdentity];
    final baseElement = element.baseElement;
    if (previous != null && !identical(previous.baseElement, baseElement)) {
      _hold(
        'stable_declaration_identity',
        'stable_declaration_identity_collision',
      );
      return;
    }
    elementOwners[targetIdentity] = baseElement;
    final targetScope = normalizedLibraryUri.startsWith('package:$packageName/')
        ? 'local_package'
        : 'external_or_sdk';
    declarationEdges.add(
      AlgorithmDeclarationDependencyEdge(
        sourcePackageUri: sourcePackageUri,
        sourceDeclarationIdentity: sourceDeclarationIdentity,
        targetIdentity: targetIdentity,
        targetLibraryUri: normalizedLibraryUri,
        edgeKind: edgeKind,
        targetScope: targetScope,
      ),
    );
    if (algorithmId != null && logicalRootId != null) {
      edges.add(
        AlgorithmDirectDependencyEdge(
          algorithmId: algorithmId!,
          logicalRootId: logicalRootId!,
          sourcePackageUri: sourcePackageUri,
          sourceDeclarationIdentity: sourceDeclarationIdentity,
          targetIdentity: targetIdentity,
          targetLibraryUri: normalizedLibraryUri,
          edgeKind: edgeKind,
          targetScope: targetScope,
        ),
      );
    }
  }

  void _recordNamedTypeRelation(NamedType node, String edgeKind) {
    final element = node.element;
    if (element == null) {
      _hold(edgeKind, 'declared_type_target_unresolved');
      return;
    }
    _record(element, edgeKind);
    if (element is TypeAliasElement && !_hasSupportedTypeAliasTarget(element)) {
      _hold(edgeKind, 'type_alias_target_shape_unclosed');
    }
    if (node.typeArguments?.arguments.isNotEmpty ?? false) {
      _hold(edgeKind, 'generic_type_arguments_unreviewed');
    }
  }

  void _recordTypeAliasDeclaration(Element? element) {
    _withCaller(element, () {
      if (element is TypeAliasElement) {
        _recordTypeAliasTarget(element);
      } else {
        _hold('type_alias_target', 'type_alias_element_unavailable');
      }
    });
  }

  bool _hasSupportedTypeAliasTarget(TypeAliasElement element) {
    final aliasedType = element.aliasedType;
    return element.typeParameters.isEmpty &&
        aliasedType is InterfaceType &&
        aliasedType.alias == null &&
        aliasedType.typeArguments.isEmpty;
  }

  void _recordTypeAliasTarget(TypeAliasElement element) {
    final aliasedType = element.aliasedType;
    if (aliasedType is! InterfaceType) {
      _hold('type_alias_target', 'type_alias_target_shape_unclosed');
      return;
    }
    _record(aliasedType.element, 'type_alias_target');
    if (element.typeParameters.isNotEmpty ||
        aliasedType.typeArguments.isNotEmpty) {
      _hold('type_alias_target', 'generic_type_arguments_unreviewed');
    }
    if (aliasedType.alias != null) {
      _hold('type_alias_target', 'type_alias_target_shape_unclosed');
    }
  }

  void _recordTypeAnnotationRelation(TypeAnnotation node, String edgeKind) {
    if (node is NamedType) {
      _recordNamedTypeRelation(node, edgeKind);
      return;
    }
    _hold(edgeKind, 'declared_type_annotation_shape_unreviewed');
  }

  void _recordResolvedTypeRelation(DartType? type, String edgeKind) {
    if (type is InterfaceType) {
      _record(type.element, edgeKind);
      if (type.typeArguments.isNotEmpty) {
        _hold(edgeKind, 'generic_type_arguments_unreviewed');
      }
      return;
    }
    if (type is TypeParameterType) {
      _record(type.element, edgeKind);
      return;
    }
    _hold(
      edgeKind,
      type == null
          ? 'declared_type_target_unresolved'
          : 'declared_type_annotation_shape_unreviewed',
    );
  }

  void _recordPropertyTarget(Element? element, String edgeKind) {
    if (element == null) return;
    if (element is PropertyAccessorElement) {
      _record(element.isOriginVariable ? element.variable : element, edgeKind);
      if (!element.isStatic &&
          element.enclosingElement is! ExtensionElement &&
          !element.isExtensionTypeMember) {
        _hold(edgeKind, 'possible_polymorphic_dispatch_target_set_unclosed');
      }
      return;
    }
    if (element is PropertyInducingElement) {
      _record(element, edgeKind);
      if (element is FieldElement && !element.isStatic) {
        _hold(edgeKind, 'possible_polymorphic_dispatch_target_set_unclosed');
      }
    }
  }

  void _recordOperatorTarget(
    Element? element,
    String edgeKind, {
    bool dynamicTargetPossible = false,
  }) {
    if (element == null) {
      if (dynamicTargetPossible) {
        _hold(edgeKind, 'dynamic_operator_target_unresolved');
      }
      return;
    }
    if (element is! MethodElement) {
      _hold(edgeKind, 'resolved_operator_target_not_method');
      return;
    }
    _record(element, edgeKind);
    if (dynamicTargetPossible) {
      _hold(edgeKind, 'dynamic_operator_target_set_unclosed');
    }
    if (!element.isStatic &&
        element.enclosingElement is! ExtensionElement &&
        !element.isExtensionTypeMember) {
      _hold(edgeKind, 'possible_polymorphic_dispatch_target_set_unclosed');
    }
  }

  void _recordExecutableReference(
    Element? element,
    String edgeKind, {
    bool holdUnsupportedTarget = false,
  }) {
    if (element == null) {
      if (holdUnsupportedTarget) {
        _hold(edgeKind, 'function_value_target_unresolved');
      }
      return;
    }
    if (element is! TopLevelFunctionElement &&
        element is! MethodElement &&
        element is! ConstructorElement) {
      if (holdUnsupportedTarget) {
        _hold(edgeKind, 'function_value_target_not_callable_declaration');
      }
      return;
    }
    _record(element, edgeKind);
    if (element is MethodElement &&
        !element.isStatic &&
        element.enclosingElement is! ExtensionElement &&
        !element.isExtensionTypeMember) {
      _hold(edgeKind, 'possible_polymorphic_dispatch_target_set_unclosed');
    }
  }

  Element? _referencedExecutableElement(Expression expression) {
    if (expression is SimpleIdentifier) return expression.element;
    if (expression is PrefixedIdentifier) return expression.element;
    if (expression is PropertyAccess) return expression.propertyName.element;
    if (expression is DotShorthandPropertyAccess) {
      return expression.propertyName.element;
    }
    if (expression is ParenthesizedExpression) {
      return _referencedExecutableElement(expression.expression);
    }
    return null;
  }

  bool _isDynamicExpression(Expression expression) =>
      expression.staticType is DynamicType;

  bool _isOverloadableOperator(String operator) => const {
    '+',
    '-',
    '*',
    '/',
    '~/',
    '%',
    '<',
    '>',
    '<=',
    '>=',
    '==',
    '<<',
    '>>',
    '>>>',
    '&',
    '^',
    '|',
  }.contains(operator);

  bool _isOverloadableCompoundAssignment(String operator) =>
      operator.endsWith('=') &&
      operator != '==' &&
      _isOverloadableOperator(operator.substring(0, operator.length - 1));

  bool _isOverloadablePrefixOperator(String operator) =>
      operator == '-' || operator == '~';

  bool _isWriteTarget(Expression node) {
    final parent = node.parent;
    if (parent is AssignmentExpression && parent.leftHandSide == node) {
      return true;
    }
    if (parent is PostfixExpression &&
        parent.operand == node &&
        _isIncrementOperator(parent.operator.lexeme)) {
      return true;
    }
    if (parent is PrefixExpression &&
        parent.operand == node &&
        _isIncrementOperator(parent.operator.lexeme)) {
      return true;
    }
    return false;
  }

  bool _isIncrementOperator(String operator) =>
      operator == '++' || operator == '--';

  void _withCaller(
    Element? element,
    void Function() visit, {
    bool preserveParentWhenUnavailable = false,
  }) {
    final previous = _currentCallerIdentity;
    final identity = element == null
        ? null
        : _stableDeclarationIdentity(element);
    if (identity != null) {
      _currentCallerIdentity = identity;
    } else if (!preserveParentWhenUnavailable) {
      _currentCallerIdentity = null;
    }
    try {
      visit();
    } finally {
      _currentCallerIdentity = previous;
    }
  }

  String? _stableDeclarationIdentity(Element element) {
    final libraryUri = element.library?.uri;
    if (libraryUri == null) {
      _hold('source_declaration', 'source_library_identity_unavailable');
      return null;
    }
    final normalizedLibraryUri = _normalizeLibraryUri(
      libraryUri,
      repositoryRoot: repositoryRoot,
      packageName: packageName,
    );
    if (normalizedLibraryUri == null) {
      _hold('source_declaration', 'source_library_identity_not_path_free');
      return null;
    }
    final identity = _stableElementIdentity(
      element,
      libraryUri: normalizedLibraryUri,
    );
    if (identity == null) {
      _hold('source_declaration', 'source_declaration_identity_unavailable');
      return null;
    }
    final baseElement = element.baseElement;
    final previous = elementOwners[identity];
    if (previous != null && !identical(previous.baseElement, baseElement)) {
      _hold('source_declaration', 'stable_declaration_identity_collision');
      return null;
    }
    elementOwners[identity] = baseElement;
    return identity;
  }

  void _collectNamespaceEdges(CompilationUnit unit) {
    for (final (index, directive) in unit.directives.indexed) {
      if (directive is ImportDirective) {
        _recordNamespaceBranches(
          directiveKind: 'import',
          directiveIndex: index,
          uri: directive.uri,
          configurations: directive.configurations,
          combinators: directive.combinators,
          prefix: directive.prefix?.name,
          deferred: directive.deferredKeyword != null,
        );
      } else if (directive is ExportDirective) {
        _recordNamespaceBranches(
          directiveKind: 'export',
          directiveIndex: index,
          uri: directive.uri,
          configurations: directive.configurations,
          combinators: directive.combinators,
        );
      } else if (directive is PartDirective) {
        _recordNamespaceBranches(
          directiveKind: 'part',
          directiveIndex: index,
          uri: directive.uri,
          configurations: const [],
          combinators: const [],
        );
      } else if (directive is PartOfDirective) {
        final uriNode = directive.uri;
        final uri = uriNode?.stringValue;
        final libraryName = directive.libraryName?.tokens
            .map((token) => token.lexeme)
            .join();
        if (uri != null && uriNode != null) {
          _recordNamespaceBranch(
            directiveKind: 'part_of',
            directiveIndex: index,
            branchIndex: 0,
            uri: uriNode,
          );
        } else if (libraryName != null && libraryName.isNotEmpty) {
          namespaceEdges.add(
            AlgorithmNamespaceDependencyEdge(
              algorithmId: algorithmId,
              logicalRootId: logicalRootId,
              sourcePackageUri: sourcePackageUri,
              directiveIndex: index,
              branchIndex: 0,
              directiveKind: 'part_of',
              uriLiteral: '',
              targetPackageUri: null,
              symbolicTarget: libraryName,
              conditionName: null,
              conditionValue: null,
              prefix: null,
              deferred: false,
              combinators: const [],
            ),
          );
          _hold('part_of_directive', 'library_name_binding_unresolved');
        } else {
          _hold('part_of_directive', 'part_of_target_unresolved');
        }
      }
    }
  }

  void _recordNamespaceBranches({
    required String directiveKind,
    required int directiveIndex,
    required StringLiteral uri,
    required Iterable<Configuration> configurations,
    required Iterable<Combinator> combinators,
    String? prefix,
    bool deferred = false,
  }) {
    final combinatorSnapshots = <Map<String, Object?>>[];
    for (final combinator in combinators) {
      if (combinator is ShowCombinator) {
        combinatorSnapshots.add({
          'kind': 'show',
          'names': combinator.shownNames.map((name) => name.name).toList(),
        });
      } else if (combinator is HideCombinator) {
        combinatorSnapshots.add({
          'kind': 'hide',
          'names': combinator.hiddenNames.map((name) => name.name).toList(),
        });
      } else {
        _hold('namespace_combinator', 'unsupported_combinator_kind');
      }
    }
    _recordNamespaceBranch(
      directiveKind: directiveKind,
      directiveIndex: directiveIndex,
      branchIndex: 0,
      uri: uri,
      prefix: prefix,
      deferred: deferred,
      combinators: combinatorSnapshots,
    );
    var branchIndex = 1;
    for (final configuration in configurations) {
      final configurationValue = configuration.value?.stringValue;
      if (configuration.value != null && configurationValue == null) {
        _hold(
          'namespace_configuration',
          'configuration_value_not_a_stable_literal',
        );
        branchIndex += 1;
        continue;
      }
      _recordNamespaceBranch(
        directiveKind: directiveKind,
        directiveIndex: directiveIndex,
        branchIndex: branchIndex,
        uri: configuration.uri,
        prefix: prefix,
        deferred: deferred,
        combinators: combinatorSnapshots,
        conditionName: configuration.name.tokens
            .map((token) => token.lexeme)
            .join(),
        conditionValue: configurationValue,
      );
      branchIndex += 1;
    }
  }

  void _recordNamespaceBranch({
    required String directiveKind,
    required int directiveIndex,
    required int branchIndex,
    required StringLiteral uri,
    String? prefix,
    bool deferred = false,
    Iterable<Map<String, Object?>> combinators = const [],
    String? conditionName,
    String? conditionValue,
  }) {
    final literal = uri.stringValue;
    final target = _normalizeDirectiveUri(
      literal,
      sourcePackageUri: sourcePackageUri,
      packageName: packageName,
    );
    if (literal == null || target == null) {
      _hold(directiveKind, 'namespace_target_identity_not_path_free');
      return;
    }
    namespaceEdges.add(
      AlgorithmNamespaceDependencyEdge(
        algorithmId: algorithmId,
        logicalRootId: logicalRootId,
        sourcePackageUri: sourcePackageUri,
        directiveIndex: directiveIndex,
        branchIndex: branchIndex,
        directiveKind: directiveKind,
        uriLiteral: literal,
        targetPackageUri: target,
        symbolicTarget: null,
        conditionName: conditionName,
        conditionValue: conditionValue,
        prefix: prefix,
        deferred: deferred,
        combinators: combinators,
      ),
    );
  }

  void _hold(String edgeKind, String reason) {
    if (algorithmId != null && logicalRootId != null) {
      unresolved.add(
        AlgorithmUnresolvedDirectEdge(
          algorithmId: algorithmId!,
          logicalRootId: logicalRootId!,
          edgeKind: edgeKind,
          reason: reason,
          count: 1,
        ),
      );
    } else {
      sourceUnresolved.add(
        AlgorithmUnresolvedSourceEdge(
          sourcePackageUri: sourcePackageUri,
          edgeKind: edgeKind,
          reason: reason,
          count: 1,
        ),
      );
    }
  }
}

class _UnresolvedEdgeCount {
  final String algorithmId;
  final String logicalRootId;
  final String edgeKind;
  final String reason;
  int count = 0;

  _UnresolvedEdgeCount({
    required this.algorithmId,
    required this.logicalRootId,
    required this.edgeKind,
    required this.reason,
  });

  String get key =>
      '$algorithmId\u0000$logicalRootId\u0000$edgeKind\u0000$reason';

  AlgorithmUnresolvedDirectEdge toEdge() => AlgorithmUnresolvedDirectEdge(
    algorithmId: algorithmId,
    logicalRootId: logicalRootId,
    edgeKind: edgeKind,
    reason: reason,
    count: count,
  );
}

class _UnresolvedSourceEdgeCount {
  final String sourcePackageUri;
  final String edgeKind;
  final String reason;
  int count = 0;

  _UnresolvedSourceEdgeCount({
    required this.sourcePackageUri,
    required this.edgeKind,
    required this.reason,
  });

  String get key => '$sourcePackageUri\u0000$edgeKind\u0000$reason';

  AlgorithmUnresolvedSourceEdge toEdge() => AlgorithmUnresolvedSourceEdge(
    sourcePackageUri: sourcePackageUri,
    edgeKind: edgeKind,
    reason: reason,
    count: count,
  );
}

void _addUnresolved(
  Map<String, _UnresolvedEdgeCount> target, {
  required String algorithmId,
  required String rootId,
  required String edgeKind,
  required String reason,
}) {
  final value = _UnresolvedEdgeCount(
    algorithmId: algorithmId,
    logicalRootId: rootId,
    edgeKind: edgeKind,
    reason: reason,
  );
  final existing = target.putIfAbsent(value.key, () => value);
  existing.count += 1;
}

void _addSourceUnresolved(
  Map<String, _UnresolvedSourceEdgeCount> target, {
  required String sourcePackageUri,
  required String edgeKind,
  required String reason,
  int count = 1,
}) {
  final value = _UnresolvedSourceEdgeCount(
    sourcePackageUri: sourcePackageUri,
    edgeKind: edgeKind,
    reason: reason,
  );
  final existing = target.putIfAbsent(value.key, () => value);
  existing.count += count;
}

String? _stableElementIdentity(Element element, {required String libraryUri}) {
  final parts = <String>[];
  Element? current = element;
  while (current != null && current is! LibraryElement) {
    final declaredName = current.name;
    final name =
        current is ConstructorElement &&
            (declaredName == null || declaredName.isEmpty)
        ? '<unnamed>'
        : declaredName;
    if (name == null || name.isEmpty) return null;
    parts.add('${current.kind.name}:${Uri.encodeComponent(name)}');
    current = current.enclosingElement;
  }
  if (current == null || parts.isEmpty) return null;
  return '$libraryUri#${parts.reversed.join('/')}';
}

String? _normalizeLibraryUri(
  Uri uri, {
  required String repositoryRoot,
  required String packageName,
}) {
  if (uri.scheme == 'package' || uri.scheme == 'dart') return uri.toString();
  if (uri.scheme != 'file') return null;
  final filePath = path.normalize(uri.toFilePath());
  final libRoot = path.normalize(path.join(repositoryRoot, 'lib'));
  if (!path.isWithin(libRoot, filePath)) return null;
  final relative = path.relative(filePath, from: libRoot).split(path.separator)
    ..removeWhere((segment) => segment.isEmpty || segment == '.');
  if (relative.isEmpty || relative.any((segment) => segment == '..')) {
    return null;
  }
  return 'package:$packageName/${relative.join('/')}';
}

String? _normalizeDirectiveUri(
  String? literal, {
  required String sourcePackageUri,
  required String packageName,
}) {
  if (literal == null ||
      literal.isEmpty ||
      literal.contains('\\') ||
      literal.startsWith('/') ||
      literal.startsWith('//')) {
    return null;
  }
  final parsed = Uri.tryParse(literal);
  if (parsed == null || parsed.hasAuthority) return null;
  if (parsed.scheme == 'dart') return parsed.toString();
  if (parsed.scheme == 'package') {
    final normalized = parsed.normalizePath();
    if (normalized.pathSegments.length < 2 ||
        normalized.pathSegments.any((segment) => segment == '..')) {
      return null;
    }
    return normalized.toString();
  }
  if (parsed.hasScheme) return null;
  final source = Uri.tryParse(sourcePackageUri);
  if (source == null ||
      source.scheme != 'package' ||
      source.pathSegments.isEmpty ||
      source.pathSegments.first != packageName) {
    return null;
  }
  final normalized = source.resolveUri(parsed).normalizePath();
  if (normalized.scheme != 'package' ||
      normalized.pathSegments.length < 2 ||
      normalized.pathSegments.first != packageName ||
      normalized.pathSegments.any((segment) => segment == '..')) {
    return null;
  }
  return normalized.toString();
}

String? algorithmAnalyzerSdkPathForCurrentRuntime() {
  var cursor = Directory(path.dirname(Platform.resolvedExecutable));
  for (var depth = 0; depth < 12; depth += 1) {
    final versionFile = File(
      path.join(cursor.path, 'bin', 'cache', 'flutter.version.json'),
    );
    if (versionFile.existsSync()) {
      final flutterRoot = versionFile.parent.parent.parent.path;
      final sdkPath = path.join(flutterRoot, 'bin', 'cache', 'dart-sdk');
      return Directory(path.join(sdkPath, 'lib', 'core')).existsSync()
          ? sdkPath
          : null;
    }
    final parent = cursor.parent;
    if (parent.path == cursor.path) break;
    cursor = parent;
  }
  return null;
}

void _validateAnalyzerLock({
  required String lockSource,
  required String packageConfigSource,
  required List<String> holds,
}) {
  final lock = loadYaml(lockSource);
  final packages = lock is YamlMap ? lock['packages'] : null;
  final analyzer = packages is YamlMap ? packages['analyzer'] : null;
  final description = analyzer is YamlMap ? analyzer['description'] : null;
  if (analyzer is! YamlMap ||
      analyzer['version']?.toString() != algorithmDependencyAnalyzerVersion ||
      description is! YamlMap ||
      description['sha256']?.toString() !=
          algorithmDependencyAnalyzerArchiveSha256) {
    holds.add('analyzer_lock_identity_mismatch');
  }

  final decoded = jsonDecode(packageConfigSource);
  final configuredPackages = decoded is Map ? decoded['packages'] : null;
  final analyzerPackage = configuredPackages is List
      ? configuredPackages.whereType<Map>().where((item) {
          return item['name'] == 'analyzer';
        }).firstOrNull
      : null;
  final analyzerRootUri = analyzerPackage?['rootUri']?.toString();
  if (analyzerRootUri == null ||
      !Uri.parse(
        analyzerRootUri,
      ).pathSegments.contains('analyzer-$algorithmDependencyAnalyzerVersion') ||
      analyzerPackage?['languageVersion']?.toString() != '3.11') {
    holds.add('analyzer_package_config_identity_mismatch');
  }
}

String _resultVariant(SomeResolvedUnitResult result) {
  if (result is InvalidPathResult) return 'InvalidPathResult';
  if (result is DisposedAnalysisContextResult) {
    return 'DisposedAnalysisContextResult';
  }
  if (result is MissingSdkLibraryResult) return 'MissingSdkLibraryResult';
  if (result is NotPathOfUriResult) return 'NotPathOfUriResult';
  return 'UnsupportedSomeResolvedUnitResult';
}

String _digestStringMap(Map<String, String> values) {
  final entries = values.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  return _sha256(
    utf8.encode(
      jsonEncode([
        for (final entry in entries) [entry.key, entry.value],
      ]),
    ),
  );
}

String _sha256(List<int> bytes) => sha256.convert(bytes).toString();

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
