import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/algorithm_result_root_manifest.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_registry.dart';

void main() {
  Map<String, dynamic> decodedManifest() =>
      jsonDecode(
            File(
              'config/algorithm_result_root_manifest.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  Map<String, String> registrySources() => {
    for (final descriptor in AlgorithmRegistry.all)
      descriptor.id: descriptor.sourcePath,
  };

  AlgorithmResultRootManifest current() =>
      AlgorithmResultRootManifest.fromJson(decodedManifest());

  test('reviewed manifest is an exact stable map for all 65 algorithms', () {
    final manifest = current();
    manifest.validateAgainstRegistry(registrySources());

    expect(manifest.entries, hasLength(65));
    expect(manifest.packageName, 'parkinsum_companion');
    expect(
      manifest.sha256Digest,
      'acb11f12efbceece79108e40e5529236bad6de989c6862130ee70a842a0a415e',
    );
    expect(manifest.toJson(), decodedManifest());
    expect(manifest.canonicalJson, isNot(contains(Directory.current.path)));
    expect(manifest.canonicalJson, isNot(contains('file:')));
    expect(manifest.canonicalJson, isNot(contains('element_id')));
    expect(manifest.canonicalJson, isNot(contains('session_id')));
    expect(manifest.canonicalJson, isNot(contains('offset')));

    for (final entry in manifest.entries) {
      expect(
        File(entry.sourcePath).existsSync(),
        isTrue,
        reason: entry.algorithmId,
      );
      expect(entry.declarationKind, 'library');
      expect(entry.enclosingDeclaration, isNull);
      expect(entry.declarationName, isNull);
    }
  });

  test('entry order does not change canonical bytes or digest', () {
    final baseline = current();
    final permuted = decodedManifest();
    final entries = (permuted['entries'] as List).reversed.toList();
    permuted['entries'] = entries;
    final reordered = AlgorithmResultRootManifest.fromJson(permuted);

    expect(reordered.canonicalJson, baseline.canonicalJson);
    expect(reordered.sha256Digest, baseline.sha256Digest);
  });

  test('missing, stale, swapped and duplicate identities fail closed', () {
    final missingJson = decodedManifest();
    (missingJson['entries'] as List).removeLast();
    final missing = AlgorithmResultRootManifest.fromJson(missingJson);
    expect(
      () => missing.validateAgainstRegistry(registrySources()),
      throwsStateError,
    );

    final staleJson = decodedManifest();
    final staleEntry = (staleJson['entries'] as List).first as Map;
    staleEntry['algorithm_id'] = 'stale_algorithm';
    staleEntry['logical_root_id'] = 'algorithm-root/stale_algorithm';
    staleEntry['result_sink_id'] = 'algorithm-result-sink/stale_algorithm';
    final stale = AlgorithmResultRootManifest.fromJson(staleJson);
    expect(
      () => stale.validateAgainstRegistry(registrySources()),
      throwsStateError,
    );

    final swappedJson = decodedManifest();
    final swappedEntries = swappedJson['entries'] as List;
    final first = swappedEntries[0] as Map;
    final second = swappedEntries[1] as Map;
    final firstPath = first['source_path'];
    final firstUri = first['canonical_package_uri'];
    first['source_path'] = second['source_path'];
    first['canonical_package_uri'] = second['canonical_package_uri'];
    first['library_uri'] = second['library_uri'];
    second['source_path'] = firstPath;
    second['canonical_package_uri'] = firstUri;
    second['library_uri'] = firstUri;
    final swapped = AlgorithmResultRootManifest.fromJson(swappedJson);
    expect(
      () => swapped.validateAgainstRegistry(registrySources()),
      throwsStateError,
    );

    final duplicateJson = decodedManifest();
    final duplicateEntries = duplicateJson['entries'] as List;
    (duplicateEntries[1] as Map)['logical_root_id'] =
        (duplicateEntries[0] as Map)['logical_root_id'];
    expect(
      () => AlgorithmResultRootManifest.fromJson(duplicateJson),
      throwsStateError,
    );
  });

  test('unsafe paths, URI aliases and analyzer-owned IDs fail closed', () {
    final absolutePathJson = decodedManifest();
    final absoluteEntry = (absolutePathJson['entries'] as List).first as Map;
    absoluteEntry['source_path'] = '/tmp/result.dart';
    absoluteEntry['canonical_package_uri'] = 'file:///tmp/result.dart';
    absoluteEntry['library_uri'] = 'file:///tmp/result.dart';
    expect(
      () => AlgorithmResultRootManifest.fromJson(absolutePathJson),
      throwsStateError,
    );

    final wrongPackageJson = decodedManifest();
    final wrongPackageEntry =
        (wrongPackageJson['entries'] as List).first as Map;
    wrongPackageEntry['canonical_package_uri'] =
        'package:another_package/root.dart';
    wrongPackageEntry['library_uri'] = 'package:another_package/root.dart';
    expect(
      () => AlgorithmResultRootManifest.fromJson(wrongPackageJson),
      throwsStateError,
    );

    final analyzerIdentityJson = decodedManifest();
    final analyzerEntry =
        (analyzerIdentityJson['entries'] as List).first as Map;
    analyzerEntry['element_id'] = 'unstable-analyzer-id';
    expect(
      () => AlgorithmResultRootManifest.fromJson(analyzerIdentityJson),
      throwsFormatException,
    );
  });
}
