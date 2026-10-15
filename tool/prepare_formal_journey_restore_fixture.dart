// Fixed-path, opt-in synthetic UI journey fixture preparation only.
// No repository, owner capability, restore coordinator or persistence API is
// invoked here. The formal UI must independently inspect and confirm the file.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:parkinsum_companion/core/models/portable_data_restore.dart';

const _inputPath = 'build/mega_upgrade/formal_synthetic_export.json';
const _outputPath = 'build/mega_upgrade/formal_synthetic_incoming.json';
const _receiptPath =
    'build/mega_upgrade/formal_synthetic_incoming.receipt.json';
const _incomingMealId = 'mega_w31_incoming';
const _filePaths = <String>[
  'profile.json',
  'preferences.json',
  'medication_selections.json',
  'intakes.json',
  'meals.json',
  'reminders.json',
  'audit_links.json',
  'observations.json',
];

class _FixtureRejected implements Exception {
  const _FixtureRejected(this.code);
  final String code;
}

Map<String, Object?> _map(Object? value, String code) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw _FixtureRejected(code);
  }
  return Map<String, Object?>.from(value);
}

List<Object?> _list(Object? value, String code) {
  if (value is! List) throw _FixtureRejected(code);
  return List<Object?>.from(value);
}

void _require(bool condition, String code) {
  if (!condition) throw _FixtureRejected(code);
}

int _recordCount(Object? value) {
  if (value is List) return value.length;
  if (value is Map) {
    final records = value['records'];
    if (records is List) return records.length;
    final links = value['links'];
    return links is List ? links.length : 1;
  }
  return 0;
}

String _packageId(String owner, String content) =>
    portableRestoreBytesDigest('parkinsum-portable-package-v4|$owner|$content');

/// Reject the wrong fixed fixture slice and corrupt original integrity before
/// changing anything. Payload timestamps, profile and evidence are untouched.
Map<String, Object?> prepareSyntheticIncoming(Map<String, Object?> original) {
  _require(
    original['format'] == 'parkinsum_user_portable_data_package' &&
        original['schemaVersion'] == 4,
    'expected_exact_v4_package',
  );
  _require(
    original.keys.toSet().length == 4 &&
        original.keys.toSet().containsAll(const {
          'format',
          'schemaVersion',
          'manifest',
          'files',
        }),
    'unexpected_package_envelope',
  );
  final files = _map(original['files'], 'invalid_files');
  _require(
    files.keys.toSet().length == _filePaths.length &&
        files.keys.toSet().containsAll(_filePaths),
    'unexpected_file_inventory',
  );
  final meals = _list(files['meals.json'], 'invalid_meals');
  _require(meals.length == 1, 'expected_exactly_one_meal');
  _require(
    _list(files['intakes.json'], 'invalid_intakes').isEmpty &&
        _list(files['reminders.json'], 'invalid_reminders').isEmpty,
    'intakes_and_reminders_must_be_empty',
  );
  final observations = _map(files['observations.json'], 'invalid_observations');
  _require(
    _list(observations['records'], 'invalid_observation_records').isEmpty,
    'observations_must_be_empty',
  );
  final meal = _map(meals.single, 'invalid_meal');
  final originalId = meal['id'];
  _require(
    originalId is String &&
        originalId.isNotEmpty &&
        originalId != _incomingMealId,
    'meal_id_missing_or_already_transformed',
  );
  final audit = _map(files['audit_links.json'], 'invalid_audit_links');
  final links = _list(audit['links'], 'invalid_audit_link_rows');
  final mappedLinks = <Map<String, Object?>>[
    for (final link in links) _map(link, 'invalid_audit_link_row'),
  ];
  _require(
    mappedLinks.every(
      (link) => link['recordType'] == 'meal' && link['recordId'] == originalId,
    ),
    'audit_links_must_reference_the_single_meal',
  );
  final manifest = _map(original['manifest'], 'invalid_manifest');
  final owner = _map(manifest['ownerScope'], 'invalid_owner_binding');
  final ownerBinding = owner['bindingSha256'];
  _require(
    ownerBinding is String && RegExp(r'^[a-f0-9]{64}$').hasMatch(ownerBinding),
    'invalid_owner_binding_sha256',
  );
  final ownerSha256 = ownerBinding as String;
  final integrity = _map(manifest['integrity'], 'invalid_integrity');
  _require(
    integrity['algorithm'] == 'SHA-256' &&
        integrity['canonicalization'] == 'sorted-key-json-v1' &&
        integrity['contentSha256'] == portableRestoreDigest(files) &&
        manifest['packageId'] ==
            _packageId(ownerSha256, portableRestoreDigest(files)),
    'original_package_integrity_mismatch',
  );
  final fileManifest = _list(manifest['files'], 'invalid_manifest_inventory');
  final byPath = <String, Map<String, Object?>>{};
  for (final raw in fileManifest) {
    final row = _map(raw, 'invalid_manifest_file_row');
    final path = row['path'];
    _require(
      path is String && _filePaths.contains(path) && !byPath.containsKey(path),
      'invalid_or_duplicate_manifest_path',
    );
    _require(
      row['sha256'] == portableRestoreDigest(files[path]) &&
          row['recordCount'] == _recordCount(files[path]),
      'original_file_integrity_mismatch',
    );
    byPath[path as String] = row;
  }
  _require(byPath.length == _filePaths.length, 'incomplete_manifest_inventory');

  // Copy every affected container. Unknown nested evidence is retained verbatim
  // as JSON values; only meal ID and its exact relationship record IDs change.
  final incomingMeal = <String, Object?>{...meal, 'id': _incomingMealId};
  final incomingLinks = <Object?>[
    for (final link in mappedLinks)
      <String, Object?>{...link, 'recordId': _incomingMealId},
  ];
  final incomingFiles = <String, Object?>{
    ...files,
    'meals.json': <Object?>[incomingMeal],
    'audit_links.json': <String, Object?>{...audit, 'links': incomingLinks},
  };
  final contentSha256 = portableRestoreDigest(incomingFiles);
  final incomingManifest = <String, Object?>{
    ...manifest,
    'packageId': _packageId(ownerSha256, contentSha256),
    'integrity': <String, Object?>{
      ...integrity,
      'contentSha256': contentSha256,
    },
    'files': <Object?>[
      for (final raw in fileManifest)
        <String, Object?>{
          ..._map(raw, 'invalid_manifest_file_row'),
          'sha256': portableRestoreDigest(incomingFiles[(raw as Map)['path']]),
        },
    ],
  };
  return <String, Object?>{
    ...original,
    'manifest': incomingManifest,
    'files': incomingFiles,
  };
}

void _requireFixedLocalPaths() {
  final root = Directory.current.resolveSymbolicLinksSync();
  final parent = Directory('build/mega_upgrade').resolveSymbolicLinksSync();
  _require(
    parent.startsWith('$root${Platform.pathSeparator}'),
    'unsafe_fixture_directory',
  );
  for (final path in [_inputPath, _outputPath, _receiptPath]) {
    _require(!FileSystemEntity.isLinkSync(path), 'fixture_symlink_refused');
  }
}

void _atomicWrite(String path, String content) {
  final temporary = File(
    '$path.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp',
  );
  try {
    temporary.writeAsStringSync(content, flush: true);
    temporary.renameSync(path);
  } finally {
    if (temporary.existsSync()) temporary.deleteSync();
  }
}

void main(List<String> args) {
  try {
    _require(
      args.length == 1 && args.single == '--synthetic-qa',
      'explicit_synthetic_qa_opt_in_required',
    );
    _requireFixedLocalPaths();
    final input = File(_inputPath);
    _require(
      input.lengthSync() <= 32 * 1024 * 1024,
      'fixture_exceeds_byte_budget',
    );
    final bytes = input.readAsBytesSync();
    Map<String, Object?> original;
    try {
      original = _map(jsonDecode(utf8.decode(bytes)), 'invalid_package_json');
    } on _FixtureRejected {
      rethrow;
    } catch (_) {
      throw const _FixtureRejected('malformed_package_json');
    }
    final incoming = prepareSyntheticIncoming(original);
    final output = '${portableRestoreCanonicalJson(incoming)}\n';
    final originalMeal = (original['files'] as Map)['meals.json'] as List;
    final receipt = <String, Object?>{
      'kind': 'synthetic_qa_id_transform_only',
      'syntheticQaOnly': true,
      'inputPath': _inputPath,
      'outputPath': _outputPath,
      'originalMealId': (originalMeal.single as Map)['id'],
      'incomingMealId': _incomingMealId,
      'inputSha256': sha256.convert(bytes).toString(),
      'outputSha256': portableRestoreBytesDigest(output),
      'preparedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'boundary':
          'Isolated synthetic formal-UI journey fixture only. This is not production expected output, a restore approval or evidence of persistence. UI inspection and explicit confirmation remain required. No original package payload is printed.',
    };
    _atomicWrite(_outputPath, output);
    _atomicWrite(_receiptPath, '${portableRestoreCanonicalJson(receipt)}\n');
    stdout.writeln(jsonEncode(receipt));
  } on _FixtureRejected catch (error) {
    stderr.writeln('Synthetic QA fixture rejected: ${error.code}.');
    exitCode = 1;
  } catch (_) {
    // Parsing / I/O exceptions can contain source excerpts or metadata. Keep
    // those out of the console and never print a personal package payload.
    stderr.writeln(
      'Synthetic QA fixture rejected: unavailable_or_invalid_input.',
    );
    exitCode = 1;
  }
}
