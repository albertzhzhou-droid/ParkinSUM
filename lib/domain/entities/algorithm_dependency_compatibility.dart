library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

const String algorithmDependencyCompatibilityReportSchema =
    'parkinsum.algorithm-dependency-compatibility-report/1';
const int algorithmDependencyCompatibilityReportSchemaVersion = 1;
const String algorithmDependencyAnalyzerVersion = '14.1.0';
const String algorithmDependencyAnalyzerArchiveSha256 =
    '62993bed6eadbe9596c5c20d5c167e7bc563c5fe266657a04ddeb93bdb84f4c9';
const String algorithmDependencyReviewedDartVersion = '3.13.0';
const String algorithmDependencyReviewedFlutterVersion = '3.47.0';
const String algorithmDependencyCompatibilityAccepted =
    'compatibility_accepted';
const String algorithmDependencyCompatibilityHeld = 'compatibility_held';
const String algorithmDependencyClosureHeld =
    'held_pending_full_result_dependency_closure';

/// Path-free result of resolving one stable algorithm root.
class AlgorithmRootResolutionObservation {
  final String algorithmId;
  final String logicalRootId;
  final String resultSinkId;
  final String canonicalPackageUri;
  final String resultVariant;
  final bool sessionConsistent;
  final bool isLibrary;
  final String? resolvedLibraryUri;
  final List<String> blockingDiagnosticCodes;

  AlgorithmRootResolutionObservation({
    required this.algorithmId,
    required this.logicalRootId,
    required this.resultSinkId,
    required this.canonicalPackageUri,
    required this.resultVariant,
    required this.sessionConsistent,
    required this.isLibrary,
    required this.resolvedLibraryUri,
    required Iterable<String> blockingDiagnosticCodes,
  }) : blockingDiagnosticCodes = List.unmodifiable(
         [...blockingDiagnosticCodes]..sort(),
       );

  bool get accepted =>
      resultVariant == 'ResolvedUnitResult' &&
      sessionConsistent &&
      isLibrary &&
      resolvedLibraryUri == canonicalPackageUri &&
      blockingDiagnosticCodes.isEmpty;

  List<String> get holdReasons => [
    if (resultVariant != 'ResolvedUnitResult')
      'non_success_result:$resultVariant',
    if (!sessionConsistent) 'inconsistent_analysis_session',
    if (!isLibrary) 'root_is_not_library',
    if (resolvedLibraryUri != canonicalPackageUri)
      'library_uri_mismatch:${resolvedLibraryUri ?? 'unavailable'}',
    for (final code in blockingDiagnosticCodes) 'blocking_diagnostic:$code',
  ];

  Map<String, dynamic> toJson() => {
    'algorithm_id': algorithmId,
    'logical_root_id': logicalRootId,
    'result_sink_id': resultSinkId,
    'canonical_package_uri': canonicalPackageUri,
    'result_variant': resultVariant,
    'session_consistent': sessionConsistent,
    'is_library': isLibrary,
    'resolved_library_uri': resolvedLibraryUri,
    'blocking_diagnostic_codes': blockingDiagnosticCodes,
    'accepted': accepted,
    'hold_reasons': holdReasons,
  };
}

/// Canonical evidence for the bounded analyzer compatibility/root-resolution
/// phase. A green report intentionally leaves the transitive closure held.
class AlgorithmDependencyCompatibilityReport {
  static const String claimBoundary =
      'Compatibility acceptance proves that the exact analyzer API resolves '
      'the reviewed conservative primary-library roots under one consistent '
      'session per analysis context. It does not derive result-dependency '
      'edges or prove transitive closure, runtime execution, exact data flow, '
      'scientific validity, clinical validity, or medication advice.';

  final String analyzerVersion;
  final String analyzerArchiveSha256;
  final String dartVersion;
  final String flutterVersion;
  final String rootManifestSha256;
  final String pubspecLockSha256;
  final String packageConfigSha256;
  final String analysisOptionsSha256;
  final int analysisContextCount;
  final List<String> environmentHoldReasons;
  final List<AlgorithmRootResolutionObservation> roots;

  AlgorithmDependencyCompatibilityReport({
    required this.analyzerVersion,
    required this.analyzerArchiveSha256,
    required this.dartVersion,
    required this.flutterVersion,
    required this.rootManifestSha256,
    required this.pubspecLockSha256,
    required this.packageConfigSha256,
    required this.analysisOptionsSha256,
    required this.analysisContextCount,
    required Iterable<String> environmentHoldReasons,
    required Iterable<AlgorithmRootResolutionObservation> roots,
  }) : environmentHoldReasons = List.unmodifiable(
         [...environmentHoldReasons]..sort(),
       ),
       roots = List.unmodifiable(
         [...roots]..sort(
           (left, right) => left.algorithmId.compareTo(right.algorithmId),
         ),
       ) {
    if (analysisContextCount < 0) {
      throw ArgumentError.value(
        analysisContextCount,
        'analysisContextCount',
        'must be non-negative',
      );
    }
    _requireSha256(rootManifestSha256, 'rootManifestSha256');
    _requireSha256(pubspecLockSha256, 'pubspecLockSha256');
    _requireSha256(packageConfigSha256, 'packageConfigSha256');
    _requireSha256(analysisOptionsSha256, 'analysisOptionsSha256');
    final ids = <String>{};
    for (final root in this.roots) {
      if (!ids.add(root.algorithmId)) {
        throw StateError('Duplicate root observation: ${root.algorithmId}.');
      }
    }
  }

  bool get compatibilityAccepted =>
      analyzerVersion == algorithmDependencyAnalyzerVersion &&
      analyzerArchiveSha256 == algorithmDependencyAnalyzerArchiveSha256 &&
      dartVersion == algorithmDependencyReviewedDartVersion &&
      flutterVersion == algorithmDependencyReviewedFlutterVersion &&
      analysisContextCount > 0 &&
      roots.isNotEmpty &&
      environmentHoldReasons.isEmpty &&
      roots.every((root) => root.accepted);

  String get compatibilityState => compatibilityAccepted
      ? algorithmDependencyCompatibilityAccepted
      : algorithmDependencyCompatibilityHeld;

  int get acceptedRootCount => roots.where((root) => root.accepted).length;

  List<String> get heldAlgorithmIds => roots
      .where((root) => !root.accepted)
      .map((root) => root.algorithmId)
      .toList();

  Map<String, dynamic> get canonicalPayload => {
    r'$schema': algorithmDependencyCompatibilityReportSchema,
    'schema_version': algorithmDependencyCompatibilityReportSchemaVersion,
    'compatibility_state': compatibilityState,
    'closure_state': algorithmDependencyClosureHeld,
    'claim_boundary': claimBoundary,
    'toolchain': {
      'dart_version': dartVersion,
      'flutter_version': flutterVersion,
      'analyzer_version': analyzerVersion,
      'analyzer_archive_sha256': analyzerArchiveSha256,
    },
    'input_identities': {
      'root_manifest_sha256': rootManifestSha256,
      'pubspec_lock_sha256': pubspecLockSha256,
      'package_config_sha256': packageConfigSha256,
      'analysis_options_sha256': analysisOptionsSha256,
    },
    'api_contract': {
      'collection': 'AnalysisContextCollection',
      'context_selection': 'contextFor(absolute_normalized_path)',
      'session_policy': 'each_context_current_session_only',
      'result_success_type': 'ResolvedUnitResult',
      'blocking_diagnostic_severity': 'error',
      'durable_identity_policy': 'application_owned_ids_and_package_uris_only',
      'public_analyzer_imports_only': true,
    },
    'analysis_context_count': analysisContextCount,
    'root_count': roots.length,
    'accepted_root_count': acceptedRootCount,
    'held_algorithm_ids': heldAlgorithmIds,
    'environment_hold_reasons': environmentHoldReasons,
    'roots': roots.map((root) => root.toJson()).toList(),
    'api_evidence_urls': const [
      'https://pub.dev/packages/analyzer/versions/14.1.0',
      'https://pub.dev/documentation/analyzer/14.1.0/dart_analysis_analysis_context_collection/AnalysisContextCollection-class.html',
      'https://pub.dev/documentation/analyzer/14.1.0/dart_analysis_session/AnalysisSession-class.html',
      'https://pub.dev/documentation/analyzer/14.1.0/dart_analysis_results/ResolvedUnitResult-class.html',
    ],
  };

  String get canonicalJson => jsonEncode(_canonicalize(canonicalPayload));

  String get sha256Digest =>
      sha256.convert(utf8.encode(canonicalJson)).toString();

  Map<String, dynamic> toJson() => {
    ...canonicalPayload,
    'report_sha256': sha256Digest,
  };
}

void _requireSha256(String value, String label) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw ArgumentError.value(value, label, 'must be lowercase SHA-256');
  }
}

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
