// Reads and appends config/governance_ledger.jsonl through production code
// (lib/domain/entities/governance_ledger_chain.dart). Used by
// tool/identity_rebind.mjs; every digest comes from the production chain.
//
//   verify                       check the chain against the ledger and pins
//   print-pins                   print the pins the chain currently implies
//   checkpoint --before-version N --provenance '<json object>'
//                                append the checkpoint that marks the bump to vN
//   sync                         rewrite the entries after the last checkpoint
//                                so the chain holds exactly the ledger records
//   migrate                      one-off: build the chain from the frozen
//                                test/fixtures/governance_history_before_v*.json
//
// The last stdout line is one JSON object.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/entities/context_of_use_requalification.dart';
import 'package:parkinsum_companion/domain/entities/governance_ledger_chain.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_medication_applicability.dart';

List<ContextOfUseRequalificationRecord> _ledgerRecords() =>
    ContextOfUseRequalificationLedger.current(
      manifest: MechanisticApplicabilityManifest.current,
      configurationSha256:
          AlgorithmConfigurationIdentity.defaults().sha256Digest,
      // Same construction as test/context_of_use_requalification_test.dart.
      evidenceAsOfUtc: DateTime.parse('2026-08-19T00:00:00Z'),
    ).records;

GovernanceLedgerChain _readChain() => GovernanceLedgerChain.parse(
  File(GovernanceLedgerChain.path).readAsStringSync(),
);

void _writeChain(GovernanceLedgerChain chain) =>
    File(GovernanceLedgerChain.path).writeAsStringSync(chain.encode());

Map<String, Object?> _pins(GovernanceLedgerChain chain) => {
  'entry_count': chain.entries.length,
  'record_count': chain.recordEntries.length,
  'head_sha256': chain.headSha256,
  'checkpoints': [
    for (final entry in chain.checkpointEntries)
      {
        'before_identity_version': entry['before_identity_version'],
        'record_count': entry['record_count'],
        'snapshot_sha256': entry['snapshot_sha256'],
        'entry_sha256': entry['entry_sha256'],
      },
  ],
};

String? _option(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index < 0 || index + 1 >= arguments.length) return null;
  return arguments[index + 1];
}

void main(List<String> arguments) {
  final command = arguments.isEmpty ? 'verify' : arguments.first;
  switch (command) {
    case 'verify':
      final result = _readChain().verify(_ledgerRecords());
      stdout.writeln(jsonEncode(result.toJson()));
      if (!result.verified) exitCode = 1;
    case 'print-pins':
      stdout.writeln(jsonEncode(_pins(_readChain())));
    case 'checkpoint':
      final version = int.tryParse(
        _option(arguments, '--before-version') ?? '',
      );
      final provenance = jsonDecode(_option(arguments, '--provenance') ?? '');
      if (version == null || provenance is! Map<String, dynamic>) {
        stderr.writeln('checkpoint needs --before-version N --provenance {..}');
        exit(2);
      }
      final chain = _readChain().withCheckpoint(
        _ledgerRecords(),
        beforeIdentityVersion: version,
        provenance: provenance,
      );
      _writeChain(chain);
      stdout.writeln(jsonEncode(_pins(chain)));
    case 'sync':
      final chain = _readChain().syncedTo(_ledgerRecords());
      _writeChain(chain);
      stdout.writeln(jsonEncode(_pins(chain)));
    case 'migrate':
      final chain = _migrateFixtures(_ledgerRecords());
      _writeChain(chain);
      stdout.writeln(jsonEncode(_pins(chain)));
    default:
      stderr.writeln('Unknown command $command');
      exit(2);
  }
}

// ---- One-off migration of the frozen fixtures ----

/// Where each historical fixture key lives in a normalized checkpoint.
const _fixtureKeyMap = <String, String>{
  'records': 'records',
  'ledger_records': 'records',
  'record_sha256': 'record_sha256s',
  'ledger_record_sha256': 'record_sha256s',
  'record_sha256s': 'record_sha256s',
  'source_commit': 'provenance.source_commit',
  'source_configuration_version': 'provenance.source_configuration_version',
  'configuration_version': 'provenance.source_configuration_version',
  'source_configuration_sha256': 'provenance.source_configuration_sha256',
  'frozen_source_configuration_sha256':
      'provenance.source_configuration_sha256',
  'configuration_sha256': 'provenance.source_configuration_sha256',
  'source_observed_at_utc': 'provenance.source_observed_at_utc',
  'schema': 'provenance.fixture_schema',
  'boundary': 'provenance.boundary',
  'origin': 'provenance.boundary',
  'method': 'provenance.boundary',
  'source_artifact': 'provenance.source_artifact.path',
  'source_artifact_bytes': 'provenance.source_artifact.bytes',
  'source_artifact_sha256': 'provenance.source_artifact.sha256',
  'source_ledger_path': 'provenance.source_ledger.path',
  'source_ledger_sha256': 'provenance.source_ledger.sha256',
};

String _fixturePath(int version) =>
    'test/fixtures/governance_history_before_v$version.json';

GovernanceLedgerChain _migrateFixtures(
  List<ContextOfUseRequalificationRecord> records,
) {
  // Record n was appended for identity v(51 + n): record 1 is the v52
  // baseline and every later record is one rebind.
  const firstIdentity = 52;
  final bodies = <Map<String, Object?>>[];
  for (final record in records) {
    final identity = firstIdentity + record.sequence - 1;
    final file = File(_fixturePath(identity));
    if (file.existsSync()) {
      bodies.add(_checkpointFromFixture(file, identity, records));
    }
    bodies.add(
      GovernanceLedgerChain.recordBody(record, identityVersion: identity),
    );
  }
  return GovernanceLedgerChain.seal(bodies);
}

Map<String, Object?> _checkpointFromFixture(
  File file,
  int beforeIdentity,
  List<ContextOfUseRequalificationRecord> records,
) {
  final bytes = file.readAsBytesSync();
  final fixture = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  final provenance = <String, Object?>{};
  final layout = <List<String>>[];
  List<Object?>? fixtureRecords;
  List<Object?>? fixtureDigests;
  for (final MapEntry(:key, :value) in fixture.entries) {
    final target = _fixtureKeyMap[key];
    if (target == null) throw StateError('${file.path}: unmapped key $key');
    layout.add([key, target]);
    if (target == 'records') {
      fixtureRecords = value as List<Object?>;
    } else if (target == 'record_sha256s') {
      fixtureDigests = value as List<Object?>;
    } else {
      final path = target.split('.').skip(1).toList();
      var node = provenance;
      for (final part in path.take(path.length - 1)) {
        node = (node[part] ??= <String, Object?>{}) as Map<String, Object?>;
      }
      if (node.containsKey(path.last)) {
        throw StateError('${file.path}: two keys map to $target');
      }
      node[path.last] = value;
    }
  }
  final count = beforeIdentity - 52;
  final snapshot = [for (final r in records.take(count)) r.toJson()];
  final canonical = GovernanceLedgerChain.canonicalJson;
  if (fixtureRecords == null ||
      fixtureDigests == null ||
      canonical(fixtureRecords) != canonical(snapshot) ||
      canonical(fixtureDigests) !=
          canonical([for (final r in records.take(count)) r.recordSha256])) {
    throw StateError('${file.path} is not the ledger prefix of $count records');
  }
  return GovernanceLedgerChain.checkpointBody(
    beforeIdentityVersion: beforeIdentity,
    snapshotRecords: snapshot,
    provenance: provenance,
    migratedFixture: {
      'path': file.path,
      'bytes': bytes.length,
      'sha256': sha256.convert(bytes).toString(),
      'layout': layout,
    },
  );
}
