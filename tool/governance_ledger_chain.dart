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
//
// The chain was first built from the 22 frozen governance_history_before_v*.json
// fixtures by a one-off `migrate` command, kept in the commit that added this
// file (`git log --diff-filter=A -- tool/governance_ledger_chain.dart`). Each
// migrated checkpoint records that fixture's path, size, sha256 and key layout.
//
// The last stdout line is one JSON object.
import 'dart:convert';
import 'dart:io';

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
    default:
      stderr.writeln('Unknown command $command');
      exit(2);
  }
}
