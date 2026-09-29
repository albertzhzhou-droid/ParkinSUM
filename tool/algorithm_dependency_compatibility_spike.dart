import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:crypto/crypto.dart';
import 'package:parkinsum_companion/domain/entities/algorithm_dependency_compatibility.dart';
import 'package:parkinsum_companion/domain/entities/algorithm_result_root_manifest.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_registry.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

/// Executes the bounded, public-API-only analyzer compatibility spike.
///
/// Absolute paths are necessary API inputs but are never copied into the
/// returned durable evidence.
Future<AlgorithmDependencyCompatibilityReport>
runAlgorithmDependencyCompatibilitySpike({String? repositoryRoot}) async {
  final root = path.normalize(
    path.absolute(repositoryRoot ?? Directory.current.path),
  );
  final environmentHolds = <String>[];

  final manifestFile = File(
    path.join(root, 'config', 'algorithm_result_root_manifest.json'),
  );
  final manifest = AlgorithmResultRootManifest.decode(
    manifestFile.readAsStringSync(),
  );
  manifest.validateAgainstRegistry({
    for (final descriptor in AlgorithmRegistry.all)
      descriptor.id: descriptor.sourcePath,
  });

  final pubspecFile = File(path.join(root, 'pubspec.yaml'));
  final lockFile = File(path.join(root, 'pubspec.lock'));
  final packageConfigFile = File(
    path.join(root, '.dart_tool', 'package_config.json'),
  );
  final analysisOptionsFile = File(path.join(root, 'analysis_options.yaml'));

  final pubspecSource = pubspecFile.readAsStringSync();
  final lockSource = lockFile.readAsStringSync();
  final packageConfigSource = packageConfigFile.readAsStringSync();
  final analysisOptionsSource = analysisOptionsFile.existsSync()
      ? analysisOptionsFile.readAsStringSync()
      : '';
  if (!analysisOptionsFile.existsSync()) {
    environmentHolds.add('analysis_options_missing');
  }

  _validateDependencyLock(
    pubspecSource: pubspecSource,
    lockSource: lockSource,
    packageConfigSource: packageConfigSource,
    holds: environmentHolds,
  );

  final runtime = _readFlutterRuntimeEvidence(environmentHolds);
  final dartVersion = Platform.version.split(' ').first;
  if (dartVersion != algorithmDependencyReviewedDartVersion) {
    environmentHolds.add('unreviewed_dart_version:$dartVersion');
  }
  if (runtime.flutterVersion != algorithmDependencyReviewedFlutterVersion) {
    environmentHolds.add(
      'unreviewed_flutter_version:${runtime.flutterVersion}',
    );
  }
  if (runtime.dartVersion != dartVersion) {
    environmentHolds.add(
      'flutter_runtime_dart_mismatch:${runtime.dartVersion}:$dartVersion',
    );
  }

  final observations = <AlgorithmRootResolutionObservation>[];
  AnalysisContextCollection? collection;
  var contextCount = 0;
  try {
    collection = AnalysisContextCollection(
      includedPaths: [path.join(root, 'lib')],
      sdkPath: runtime.dartSdkPath,
    );
    contextCount = collection.contexts.length;
    final sessions = <AnalysisContext, AnalysisSession>{};
    final canonicalRoot = Directory(root).resolveSymbolicLinksSync();
    for (final entry in manifest.entries) {
      final absoluteSourcePath = path.normalize(
        path.join(root, entry.sourcePath),
      );
      final sourceFile = File(absoluteSourcePath);
      if (!sourceFile.existsSync()) {
        observations.add(_unavailableObservation(entry, 'MissingSourceFile'));
        continue;
      }
      final resolvedSourcePath = sourceFile.resolveSymbolicLinksSync();
      if (resolvedSourcePath != canonicalRoot &&
          !path.isWithin(canonicalRoot, resolvedSourcePath)) {
        observations.add(
          _unavailableObservation(entry, 'SourceOutsideRepository'),
        );
        continue;
      }

      try {
        final context = collection.contextFor(absoluteSourcePath);
        final session = sessions.putIfAbsent(
          context,
          () => context.currentSession,
        );
        final raw = await session.getResolvedUnit(absoluteSourcePath);
        if (raw is! ResolvedUnitResult) {
          observations.add(_unavailableObservation(entry, _resultVariant(raw)));
          continue;
        }
        final blockingCodes =
            raw.diagnostics
                .where((diagnostic) => diagnostic.severity == Severity.error)
                .map((diagnostic) => diagnostic.diagnosticCode.lowerCaseName)
                .toSet()
                .toList()
              ..sort();
        observations.add(
          AlgorithmRootResolutionObservation(
            algorithmId: entry.algorithmId,
            logicalRootId: entry.logicalRootId,
            resultSinkId: entry.resultSinkId,
            canonicalPackageUri: entry.canonicalPackageUri,
            resultVariant: 'ResolvedUnitResult',
            sessionConsistent: identical(raw.session, session),
            isLibrary: raw.isLibrary,
            resolvedLibraryUri: raw.libraryElement.uri.toString(),
            blockingDiagnosticCodes: blockingCodes,
          ),
        );
      } on InconsistentAnalysisException {
        observations.add(
          _unavailableObservation(entry, 'InconsistentAnalysisSession'),
        );
      } on Object catch (error) {
        observations.add(
          _unavailableObservation(
            entry,
            'AnalysisFailure:${error.runtimeType}',
          ),
        );
      }
    }
  } finally {
    await collection?.dispose();
  }

  return AlgorithmDependencyCompatibilityReport(
    analyzerVersion: algorithmDependencyAnalyzerVersion,
    analyzerArchiveSha256: algorithmDependencyAnalyzerArchiveSha256,
    dartVersion: dartVersion,
    flutterVersion: runtime.flutterVersion,
    rootManifestSha256: manifest.sha256Digest,
    pubspecLockSha256: _sha256(lockSource),
    packageConfigSha256: _sha256(packageConfigSource),
    analysisOptionsSha256: _sha256(analysisOptionsSource),
    analysisContextCount: contextCount,
    environmentHoldReasons: environmentHolds,
    roots: observations,
  );
}

AlgorithmRootResolutionObservation _unavailableObservation(
  AlgorithmResultRootEntry entry,
  String resultVariant,
) => AlgorithmRootResolutionObservation(
  algorithmId: entry.algorithmId,
  logicalRootId: entry.logicalRootId,
  resultSinkId: entry.resultSinkId,
  canonicalPackageUri: entry.canonicalPackageUri,
  resultVariant: resultVariant,
  sessionConsistent: false,
  isLibrary: false,
  resolvedLibraryUri: null,
  blockingDiagnosticCodes: const [],
);

String _resultVariant(SomeResolvedUnitResult result) {
  if (result is InvalidPathResult) return 'InvalidPathResult';
  if (result is DisposedAnalysisContextResult) {
    return 'DisposedAnalysisContextResult';
  }
  if (result is MissingSdkLibraryResult) return 'MissingSdkLibraryResult';
  if (result is NotPathOfUriResult) return 'NotPathOfUriResult';
  return 'UnsupportedSomeResolvedUnitResult';
}

void _validateDependencyLock({
  required String pubspecSource,
  required String lockSource,
  required String packageConfigSource,
  required List<String> holds,
}) {
  final pubspec = loadYaml(pubspecSource);
  final devDependencies = pubspec is YamlMap
      ? pubspec['dev_dependencies']
      : null;
  if (devDependencies is! YamlMap ||
      devDependencies['analyzer']?.toString() !=
          algorithmDependencyAnalyzerVersion) {
    holds.add('pubspec_analyzer_not_exactly_locked');
  }

  final lock = loadYaml(lockSource);
  final packages = lock is YamlMap ? lock['packages'] : null;
  final analyzer = packages is YamlMap ? packages['analyzer'] : null;
  if (analyzer is! YamlMap ||
      analyzer['dependency']?.toString() != 'direct dev' ||
      analyzer['version']?.toString() != algorithmDependencyAnalyzerVersion) {
    holds.add('pubspec_lock_analyzer_identity_mismatch');
  } else {
    final description = analyzer['description'];
    if (description is! YamlMap ||
        description['sha256']?.toString() !=
            algorithmDependencyAnalyzerArchiveSha256) {
      holds.add('pubspec_lock_analyzer_archive_mismatch');
    }
  }

  final packageConfig = jsonDecode(packageConfigSource);
  final configuredPackages = packageConfig is Map
      ? packageConfig['packages']
      : null;
  Map<Object?, Object?>? analyzerPackage;
  if (configuredPackages is List) {
    for (final package in configuredPackages) {
      if (package is Map && package['name'] == 'analyzer') {
        analyzerPackage = package;
        break;
      }
    }
  }
  final analyzerRootUri = analyzerPackage?['rootUri']?.toString();
  final analyzerRootSegments = analyzerRootUri == null
      ? const <String>[]
      : Uri.parse(analyzerRootUri).pathSegments;
  if (analyzerPackage == null ||
      !analyzerRootSegments.contains(
        'analyzer-$algorithmDependencyAnalyzerVersion',
      ) ||
      analyzerPackage['languageVersion']?.toString() != '3.11') {
    holds.add('package_config_analyzer_identity_mismatch');
  }
}

_FlutterRuntimeEvidence _readFlutterRuntimeEvidence(List<String> holds) {
  var cursor = Directory(path.dirname(Platform.resolvedExecutable));
  File? versionFile;
  for (var depth = 0; depth < 8; depth += 1) {
    final candidate = File(
      path.join(cursor.path, 'bin', 'cache', 'flutter.version.json'),
    );
    if (candidate.existsSync()) {
      versionFile = candidate;
      break;
    }
    final parent = cursor.parent;
    if (parent.path == cursor.path) break;
    cursor = parent;
  }
  if (versionFile == null) {
    holds.add('flutter_version_evidence_missing');
    return _FlutterRuntimeEvidence(
      flutterVersion: 'unavailable',
      dartVersion: 'unavailable',
      dartSdkPath: null,
    );
  }
  final decoded = jsonDecode(versionFile.readAsStringSync());
  if (decoded is! Map) {
    holds.add('flutter_version_evidence_invalid');
    return _FlutterRuntimeEvidence(
      flutterVersion: 'unavailable',
      dartVersion: 'unavailable',
      dartSdkPath: null,
    );
  }
  final flutterRoot = versionFile.parent.parent.parent.path;
  return _FlutterRuntimeEvidence(
    flutterVersion: decoded['flutterVersion']?.toString() ?? 'unavailable',
    dartVersion: decoded['dartSdkVersion']?.toString() ?? 'unavailable',
    dartSdkPath: path.join(flutterRoot, 'bin', 'cache', 'dart-sdk'),
  );
}

class _FlutterRuntimeEvidence {
  final String flutterVersion;
  final String dartVersion;
  final String? dartSdkPath;

  const _FlutterRuntimeEvidence({
    required this.flutterVersion,
    required this.dartVersion,
    required this.dartSdkPath,
  });
}

String _sha256(String source) => sha256.convert(utf8.encode(source)).toString();
