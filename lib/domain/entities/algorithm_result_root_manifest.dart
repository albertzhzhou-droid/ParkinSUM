library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

const String algorithmResultRootManifestSchema =
    'parkinsum.algorithm-result-root-manifest/1';
const int algorithmResultRootManifestSchemaVersion = 1;
const String algorithmResultRootIdentityPolicy =
    'conservative_primary_library_v1';
const String algorithmResultRootEntryOrder = 'algorithm_id_ascending';
const String algorithmResultRootCompletenessState =
    'root_manifest_resolved_closure_held';

/// Stable, application-owned identity for one registered algorithm's broad
/// primary-library root.
///
/// This deliberately does not pretend that a library is the exact result
/// declaration. It is the conservative first-stage seed from which the
/// analyzer-backed edge generator must later derive a declaration closure.
class AlgorithmResultRootEntry {
  static const Set<String> jsonKeys = {
    'algorithm_id',
    'logical_root_id',
    'result_sink_id',
    'source_path',
    'canonical_package_uri',
    'library_uri',
    'declaration_kind',
    'enclosing_declaration',
    'declaration_name',
  };

  final String algorithmId;
  final String logicalRootId;
  final String resultSinkId;
  final String sourcePath;
  final String canonicalPackageUri;
  final String libraryUri;
  final String declarationKind;
  final String? enclosingDeclaration;
  final String? declarationName;

  const AlgorithmResultRootEntry({
    required this.algorithmId,
    required this.logicalRootId,
    required this.resultSinkId,
    required this.sourcePath,
    required this.canonicalPackageUri,
    required this.libraryUri,
    required this.declarationKind,
    required this.enclosingDeclaration,
    required this.declarationName,
  });

  factory AlgorithmResultRootEntry.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, jsonKeys, 'algorithm result-root entry');
    return AlgorithmResultRootEntry(
      algorithmId: _requireString(json, 'algorithm_id'),
      logicalRootId: _requireString(json, 'logical_root_id'),
      resultSinkId: _requireString(json, 'result_sink_id'),
      sourcePath: _requireString(json, 'source_path'),
      canonicalPackageUri: _requireString(json, 'canonical_package_uri'),
      libraryUri: _requireString(json, 'library_uri'),
      declarationKind: _requireString(json, 'declaration_kind'),
      enclosingDeclaration: _requireNullableString(
        json,
        'enclosing_declaration',
      ),
      declarationName: _requireNullableString(json, 'declaration_name'),
    );
  }

  Map<String, dynamic> toJson() => {
    'algorithm_id': algorithmId,
    'logical_root_id': logicalRootId,
    'result_sink_id': resultSinkId,
    'source_path': sourcePath,
    'canonical_package_uri': canonicalPackageUri,
    'library_uri': libraryUri,
    'declaration_kind': declarationKind,
    'enclosing_declaration': enclosingDeclaration,
    'declaration_name': declarationName,
  };
}

/// Strict, versioned 63-root contract used before transitive edge discovery.
class AlgorithmResultRootManifest {
  static const Set<String> jsonKeys = {
    r'$schema',
    'schema_version',
    'package_name',
    'root_identity_policy',
    'entry_order',
    'completeness_state',
    'claim_boundary',
    'entries',
  };

  static const String claimBoundary =
      'Each root is the registered algorithm primary library, selected as a '
      'deliberately broad conservative seed. Manifest acceptance proves stable '
      'root identity and exact Registry mapping only. Analyzer resolution is '
      'separate offline compatibility evidence and is not part of this '
      'manifest. It is not a transitive closure, runtime call graph, exact '
      'data-flow proof, scientific validation, clinical validation, or '
      'medication advice.';

  final String packageName;
  final List<AlgorithmResultRootEntry> entries;

  AlgorithmResultRootManifest({
    required this.packageName,
    required Iterable<AlgorithmResultRootEntry> entries,
  }) : entries = List.unmodifiable(entries) {
    _validateInternal();
  }

  factory AlgorithmResultRootManifest.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, jsonKeys, 'algorithm result-root manifest');
    if (json[r'$schema'] != algorithmResultRootManifestSchema ||
        json['schema_version'] != algorithmResultRootManifestSchemaVersion ||
        json['root_identity_policy'] != algorithmResultRootIdentityPolicy ||
        json['entry_order'] != algorithmResultRootEntryOrder ||
        json['completeness_state'] != algorithmResultRootCompletenessState ||
        json['claim_boundary'] != claimBoundary) {
      throw const FormatException(
        'Unsupported algorithm result-root manifest contract.',
      );
    }
    final rawEntries = json['entries'];
    if (rawEntries is! List) {
      throw const FormatException('entries must be a JSON array.');
    }
    return AlgorithmResultRootManifest(
      packageName: _requireString(json, 'package_name'),
      entries: rawEntries.map((raw) {
        if (raw is! Map) {
          throw const FormatException('Every root entry must be an object.');
        }
        return AlgorithmResultRootEntry.fromJson(
          raw.map((key, value) => MapEntry(key.toString(), value)),
        );
      }),
    );
  }

  factory AlgorithmResultRootManifest.decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Root manifest must be a JSON object.');
    }
    return AlgorithmResultRootManifest.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Map<String, dynamic> get canonicalPayload => {
    r'$schema': algorithmResultRootManifestSchema,
    'schema_version': algorithmResultRootManifestSchemaVersion,
    'package_name': packageName,
    'root_identity_policy': algorithmResultRootIdentityPolicy,
    'entry_order': algorithmResultRootEntryOrder,
    'completeness_state': algorithmResultRootCompletenessState,
    'claim_boundary': claimBoundary,
    'entries': entries.map((entry) => entry.toJson()).toList()
      ..sort(
        (left, right) => (left['algorithm_id'] as String).compareTo(
          right['algorithm_id'] as String,
        ),
      ),
  };

  String get canonicalJson => jsonEncode(_canonicalize(canonicalPayload));

  String get sha256Digest =>
      sha256.convert(utf8.encode(canonicalJson)).toString();

  Map<String, dynamic> toJson() => canonicalPayload;

  /// Proves an exact two-way mapping to the independent registry declaration.
  ///
  /// The registry is passed in instead of imported so neither side can silently
  /// manufacture the other's truth.
  void validateAgainstRegistry(Map<String, String> primarySourcesByAlgorithm) {
    final manifestIds = entries.map((entry) => entry.algorithmId).toSet();
    final registryIds = primarySourcesByAlgorithm.keys.toSet();
    final missing = registryIds.difference(manifestIds).toList()..sort();
    final stale = manifestIds.difference(registryIds).toList()..sort();
    if (missing.isNotEmpty || stale.isNotEmpty) {
      throw StateError(
        'Root manifest registry mismatch: missing=$missing stale=$stale.',
      );
    }
    for (final entry in entries) {
      final registeredPath = primarySourcesByAlgorithm[entry.algorithmId];
      if (registeredPath != entry.sourcePath) {
        throw StateError(
          '${entry.algorithmId} primary path mismatch: manifest='
          '${entry.sourcePath} registry=$registeredPath.',
        );
      }
    }
  }

  void _validateInternal() {
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(packageName)) {
      throw StateError('Invalid manifest package name: $packageName.');
    }
    if (entries.isEmpty) {
      throw StateError('Algorithm result-root manifest cannot be empty.');
    }

    final algorithmIds = <String>{};
    final logicalRootIds = <String>{};
    final resultSinkIds = <String>{};
    final sourcePaths = <String>{};
    final packageUris = <String>{};
    for (final entry in entries) {
      if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(entry.algorithmId)) {
        throw StateError('Invalid algorithm id: ${entry.algorithmId}.');
      }
      _requireUnique(algorithmIds, entry.algorithmId, 'algorithm id');
      _requireUnique(logicalRootIds, entry.logicalRootId, 'logical root id');
      _requireUnique(resultSinkIds, entry.resultSinkId, 'result sink id');
      _requireUnique(sourcePaths, entry.sourcePath, 'primary source path');
      _requireUnique(packageUris, entry.canonicalPackageUri, 'package URI');

      final expectedRoot = 'algorithm-root/${entry.algorithmId}';
      final expectedSink = 'algorithm-result-sink/${entry.algorithmId}';
      if (entry.logicalRootId != expectedRoot ||
          entry.resultSinkId != expectedSink) {
        throw StateError(
          '${entry.algorithmId} has non-canonical application-owned IDs.',
        );
      }
      _validateRelativeDartPath(entry.sourcePath, entry.algorithmId);
      final expectedUri =
          'package:$packageName/${entry.sourcePath.substring(4)}';
      if (entry.canonicalPackageUri != expectedUri ||
          entry.libraryUri != expectedUri) {
        throw StateError(
          '${entry.algorithmId} package/library URI differs from $expectedUri.',
        );
      }
      if (entry.declarationKind != 'library' ||
          entry.enclosingDeclaration != null ||
          entry.declarationName != null) {
        throw StateError(
          '${entry.algorithmId} must be a library root with explicit null '
          'enclosing declaration and name.',
        );
      }
    }
  }
}

void _validateRelativeDartPath(String value, String owner) {
  final segments = value.split('/');
  if (!value.startsWith('lib/') ||
      !value.endsWith('.dart') ||
      value.contains(r'\') ||
      value.startsWith('/') ||
      Uri.tryParse(value)?.hasScheme == true ||
      segments.any(
        (segment) => segment.isEmpty || segment == '.' || segment == '..',
      )) {
    throw StateError('$owner has unsafe or non-library source path: $value.');
  }
}

void _requireUnique(Set<String> values, String value, String label) {
  if (!values.add(value)) {
    throw StateError('Duplicate $label: $value.');
  }
}

void _requireExactKeys(
  Map<String, dynamic> json,
  Set<String> expected,
  String label,
) {
  final actual = json.keys.toSet();
  final missing = expected.difference(actual).toList()..sort();
  final unknown = actual.difference(expected).toList()..sort();
  if (missing.isNotEmpty || unknown.isNotEmpty) {
    throw FormatException(
      '$label keys mismatch: missing=$missing unknown=$unknown.',
    );
  }
}

String _requireString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

String? _requireNullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value != null && value is! String) {
    throw FormatException('$key must be a string or null.');
  }
  return value as String?;
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
