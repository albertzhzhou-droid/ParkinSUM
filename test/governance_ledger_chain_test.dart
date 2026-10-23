import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/entities/context_of_use_requalification.dart';
import 'package:parkinsum_companion/domain/entities/governance_ledger_chain.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_medication_applicability.dart';

void main() {
  final ledger = ContextOfUseRequalificationLedger.current(
    manifest: MechanisticApplicabilityManifest.current,
    configurationSha256: AlgorithmConfigurationIdentity.defaults().sha256Digest,
    evidenceAsOfUtc: DateTime.parse('2026-08-19T00:00:00Z'),
  );
  final records = ledger.records;
  final text = File(GovernanceLedgerChain.path).readAsStringSync();
  final chain = GovernanceLedgerChain.parse(text);
  final lines = text.split('\n')..removeLast();

  List<String> reasonsFor(String mutated) =>
      GovernanceLedgerChain.parse(mutated).verify(records).reasons;
  String joined(List<String> lines) => '${lines.join('\n')}\n';
  Map<String, Object?> decode(String line) =>
      Map<String, Object?>.from(jsonDecode(line) as Map);
  // Re-seals edited bodies into a fully consistent chain, as an author who
  // rewrote history and recomputed every digest would.
  String resealed(Iterable<Map<String, Object?>> entries) =>
      GovernanceLedgerChain.seal(entries).encode();

  group('the committed chain', () {
    test('verifies against the production ledger and every pin', () {
      final result = chain.verify(records);

      expect(result.reasons, isEmpty);
      expect(result.verified, isTrue);
      expect(result.entryCount, GovernanceLedgerChain.expectedEntryCount);
      expect(result.headSha256, GovernanceLedgerChain.expectedHeadSha256);
      expect(result.recordCount, records.length);
      expect(chain.parseReasons, isEmpty);
    });

    test('every record line equals the whole ledger record and its digest', () {
      final entries = chain.recordEntries.toList();
      expect(entries, hasLength(records.length));
      for (var index = 0; index < records.length; index++) {
        expect(entries[index]['record'], records[index].toJson());
        expect(entries[index]['record_sha256'], records[index].recordSha256);
        expect(entries[index]['sequence'], index + 1);
      }
      expect(entries.last['record'], ledger.latest.toJson());
    });

    test('every line is canonical JSON sealed with the shared digest', () {
      var previous = GovernanceLedgerChain.genesisSha256;
      for (final line in lines) {
        final entry = decode(line);
        expect(GovernanceLedgerChain.canonicalJson(entry), line);
        expect(entry['previous_entry_sha256'], previous);
        final body = Map<String, Object?>.from(entry)..remove('entry_sha256');
        expect(
          entry['entry_sha256'],
          AlgorithmConfigurationIdentity.digestConfiguration(body),
        );
        previous = entry['entry_sha256']! as String;
      }
      expect(previous, GovernanceLedgerChain.expectedHeadSha256);
    });

    test('each bump since v62 is marked by one pinned checkpoint', () {
      final current = int.parse(
        AlgorithmConfigurationIdentity.defaultVersion.split('-v').last,
      );
      final versions = [
        for (final entry in chain.checkpointEntries)
          entry['before_identity_version'],
      ];
      expect(versions, [for (var v = 62; v <= current; v++) v]);
      expect(
        GovernanceLedgerChain.checkpointPins.map(
          (pin) => pin.beforeIdentityVersion,
        ),
        versions,
      );
      expect(chain.recordEntries.last['identity_version'], current);
    });

    test(
      'the ledger before each bump is reconstructed to its pinned digest',
      () {
        for (final pin in GovernanceLedgerChain.checkpointPins) {
          final snapshot = chain.snapshotBefore(pin.beforeIdentityVersion);
          final prefix = records.take(pin.recordCount).toList();

          expect(snapshot.records, hasLength(pin.recordCount));
          expect(snapshot.records, [for (final r in prefix) r.toJson()]);
          expect(snapshot.recordSha256s, [
            for (final r in prefix) r.recordSha256,
          ]);
          expect(snapshot.sha256Digest, pin.snapshotSha256);
          expect(
            chain.checkpointEntries.firstWhere(
              (entry) =>
                  entry['before_identity_version'] == pin.beforeIdentityVersion,
            )['entry_sha256'],
            pin.entrySha256,
          );
        }
      },
    );

    test('the ledger as of any identity version is a named prefix', () {
      final first = chain.recordEntries.first['identity_version']! as int;
      final last = chain.recordEntries.last['identity_version']! as int;
      expect(first, 52);
      for (var version = first; version <= last; version++) {
        final snapshot = chain.snapshotAt(version);
        expect(snapshot.records, hasLength(version - first + 1));
        expect(snapshot.records.last['sequence'], version - first + 1);
      }
      expect(chain.snapshotAt(last).records, [
        for (final record in records) record.toJson(),
      ]);
    });

    test('the last record before each bump links to the pinned digest', () {
      for (final pin in GovernanceLedgerChain.checkpointPins) {
        final before = pin.beforeIdentityVersion;
        expect(
          records[pin.recordCount - 1].currentConfigurationSha256,
          pin.lastConfigurationSha256,
          reason: 'v$before checkpoint',
        );
        expect(
          records[pin.recordCount].previousConfigurationSha256,
          pin.lastConfigurationSha256,
        );
      }
      expect(
        GovernanceLedgerChain.checkpointPins.first.lastConfigurationSha256,
        ContextOfUseRequalificationLedger.historicalV61ConfigurationSha256,
      );
    });
  });

  group('tampering fails closed', () {
    test('editing a record without re-hashing breaks that line', () {
      final edited = [...lines];
      edited[2] = edited[2].replaceFirst('"author":"', '"author":"forged-');
      final reasons = reasonsFor(joined(edited));

      expect(reasons, contains('chain.entry_digest_mismatch@3'));
      expect(reasons, contains('chain.record_digest_mismatch@3'));
      expect(reasons, contains('chain.record_differs_from_ledger@3'));
    });

    test('re-hashing an edited line breaks the link of the next line', () {
      final entries = [for (final line in lines) decode(line)];
      final record = Map<String, Object?>.from(entries[2]['record']! as Map)
        ..['decision_boundary'] = 'A rewritten historical boundary.';
      final body = Map<String, Object?>.from(entries[2])
        ..['record'] = record
        ..remove('entry_sha256');
      entries[2] = {
        ...body,
        'entry_sha256': AlgorithmConfigurationIdentity.digestConfiguration(
          body,
        ),
      };
      final reasons = reasonsFor(
        joined([
          for (final e in entries) GovernanceLedgerChain.canonicalJson(e),
        ]),
      );

      expect(reasons, isNot(contains('chain.entry_digest_mismatch@3')));
      expect(reasons, contains('chain.previous_link_broken@4'));
      expect(reasons, contains('chain.record_differs_from_ledger@3'));
    });

    test('a fully re-sealed rewrite still fails the ledger and every pin', () {
      final entries = [for (final line in lines) decode(line)];
      entries[2]['record'] = Map<String, Object?>.from(
        entries[2]['record']! as Map,
      )..['release_artifact'] = 'forged-artifact';
      final reasons = reasonsFor(resealed(entries));

      expect(reasons, contains('chain.record_differs_from_ledger@3'));
      expect(reasons, contains('chain.record_digest_mismatch@3'));
      expect(reasons, contains('chain.checkpoint_snapshot_mismatch@11'));
      expect(reasons, contains('chain.checkpoint_pin_mismatch@11'));
      expect(reasons, contains('chain.head_mismatch'));
    });

    test('reordering two lines fails, re-sealed or not', () {
      final swapped = [...lines];
      final line = swapped[4];
      swapped[4] = swapped[5];
      swapped[5] = line;
      expect(
        reasonsFor(joined(swapped)),
        containsAll(const [
          'chain.entry_index_noncontiguous@5',
          'chain.previous_link_broken@5',
        ]),
      );

      final entries = [for (final line in swapped) decode(line)];
      expect(
        reasonsFor(resealed(entries)),
        containsAll(const [
          'chain.record_sequence_noncontiguous@5',
          'chain.record_differs_from_ledger@5',
          'chain.head_mismatch',
        ]),
      );
    });

    test('deleting a record or a checkpoint fails, re-sealed or not', () {
      final withoutRecord = [...lines]..removeAt(19);
      expect(
        reasonsFor(joined(withoutRecord)),
        containsAll(const [
          'chain.entry_index_noncontiguous@20',
          'chain.previous_link_broken@20',
          'chain.length_mismatch',
        ]),
      );
      expect(
        reasonsFor(resealed([for (final line in withoutRecord) decode(line)])),
        containsAll(const [
          'chain.record_count_mismatch',
          'chain.length_mismatch',
          'chain.head_mismatch',
        ]),
      );

      final checkpointLine = lines.indexWhere(
        (line) => decode(line)['before_identity_version'] == 70,
      );
      final withoutCheckpoint = [...lines]..removeAt(checkpointLine);
      expect(
        reasonsFor(
          resealed([for (final line in withoutCheckpoint) decode(line)]),
        ),
        containsAll(const [
          'chain.checkpoint_missing:v70',
          'chain.head_mismatch',
        ]),
      );
    });

    test('dropping the newest line fails the pins and the record count', () {
      expect(
        reasonsFor(joined(lines.take(lines.length - 1).toList())),
        containsAll(const [
          'chain.record_count_mismatch',
          'chain.ends_without_record',
          'chain.length_mismatch',
          'chain.head_mismatch',
        ]),
      );
    });

    test('a broken link is reported where it breaks', () {
      final broken = [...lines];
      broken[29] = broken[29].replaceFirst(
        RegExp(r'"previous_entry_sha256":"[0-9a-f]{64}"'),
        '"previous_entry_sha256":"${'1' * 64}"',
      );
      final reasons = reasonsFor(joined(broken));

      expect(reasons, contains('chain.previous_link_broken@30'));
      expect(reasons, contains('chain.entry_digest_mismatch@30'));
      expect(
        reasons.where((reason) => reason.startsWith('chain.previous_link')),
        ['chain.previous_link_broken@30'],
      );
    });

    test('non-canonical, unterminated or unknown lines fail', () {
      final spaced = [...lines]..[0] = lines[0].replaceFirst(':', ': ');
      expect(
        reasonsFor(joined(spaced)),
        contains('chain.line_not_canonical@1'),
      );
      expect(
        reasonsFor(lines.join('\n')),
        contains('chain.final_newline_missing'),
      );
      expect(reasonsFor(''), contains('chain.empty'));
      final garbage = [...lines]..insert(3, '{not json');
      expect(
        reasonsFor(joined(garbage)),
        contains('chain.line_invalid_json@4'),
      );
      final entries = [for (final line in lines) decode(line)];
      entries[7]['entry_kind'] = 'annotation';
      expect(
        reasonsFor(resealed(entries)),
        contains('chain.entry_kind_unknown@8'),
      );
    });

    test('a checkpoint that does not link to its pinned digest fails', () {
      final pins = [
        for (final pin in GovernanceLedgerChain.checkpointPins)
          pin.beforeIdentityVersion == 75
              ? GovernanceLedgerCheckpointPin(
                  beforeIdentityVersion: pin.beforeIdentityVersion,
                  recordCount: pin.recordCount,
                  snapshotSha256: pin.snapshotSha256,
                  entrySha256: pin.entrySha256,
                  lastConfigurationSha256: ContextOfUseRequalificationLedger
                      .historicalV75ConfigurationSha256,
                )
              : pin,
      ];
      final at =
          lines.indexWhere(
            (line) => decode(line)['before_identity_version'] == 75,
          ) +
          1;
      expect(chain.verify(records, checkpointPins: pins).reasons, [
        'chain.checkpoint_linkage_mismatch@$at',
      ]);

      final entries = [for (final line in lines) decode(line)];
      entries[at - 1]['provenance'] = {
        ...entries[at - 1]['provenance']! as Map<String, Object?>,
        'source_configuration_sha256':
            ContextOfUseRequalificationLedger.historicalV75ConfigurationSha256,
      };
      expect(
        GovernanceLedgerChain.parse(
          resealed(entries),
        ).verify(records, pinned: false).reasons,
        ['chain.checkpoint_linkage_mismatch@$at'],
      );
    });

    test('a duplicated or misplaced checkpoint fails', () {
      final entries = [for (final line in lines) decode(line)];
      final checkpoint = entries.indexWhere(
        (entry) => entry['entry_kind'] == GovernanceLedgerChain.checkpointKind,
      );
      entries.insert(checkpoint + 1, Map.of(entries[checkpoint]));
      final reasons = GovernanceLedgerChain.parse(
        resealed(entries),
      ).verify(records, pinned: false).reasons;
      expect(reasons, contains('chain.checkpoint_duplicate@${checkpoint + 2}'));
      expect(
        reasons,
        contains('chain.checkpoint_boundary_invalid@${checkpoint + 2}'),
      );
    });
  });

  group('appending through production code', () {
    final lastCheckpoint = lines.lastIndexWhere(
      (line) =>
          decode(line)['entry_kind'] == GovernanceLedgerChain.checkpointKind,
    );
    final beforeLast = GovernanceLedgerChain.parse(
      joined(lines.take(lastCheckpoint).toList()),
    );
    final latestBump =
        decode(lines[lastCheckpoint])['before_identity_version']! as int;

    test(
      'a checkpoint and a synced record extend the chain without rewriting',
      () {
        final provenance = {
          'boundary': 'Synthetic test bump; no evidence is asserted.',
          'rebind_title': 'test bump',
          'rebind_reason': 'binds nothing',
        };
        final marked = beforeLast.withCheckpoint(
          records.take(records.length - 1).toList(),
          beforeIdentityVersion: latestBump,
          provenance: provenance,
        );
        final extended = marked.syncedTo(records);
        final extendedLines = extended.encode().split('\n')..removeLast();

        expect(extendedLines.take(lastCheckpoint), lines.take(lastCheckpoint));
        expect(extendedLines, hasLength(lines.length));
        expect(extendedLines.last, isNot(lines.last), reason: 'new provenance');
        expect(extended.recordEntries.last['record'], ledger.latest.toJson());
        expect(extended.verify(records, pinned: false).reasons, isEmpty);
        expect(
          extended.verify(records).reasons,
          containsAll([
            'chain.checkpoint_pin_mismatch@${lastCheckpoint + 1}',
            'chain.head_mismatch',
          ]),
        );
        expect(extended.syncedTo(records).encode(), extended.encode());
      },
    );

    test(
      'appending refuses a wrong boundary or a rewritten earlier record',
      () {
        expect(
          () => beforeLast.withCheckpoint(
            records.take(records.length - 1).toList(),
            beforeIdentityVersion: latestBump + 1,
            provenance: const {},
          ),
          throwsStateError,
        );
        expect(
          () => chain.withCheckpoint(
            records.take(records.length - 1).toList(),
            beforeIdentityVersion: latestBump + 1,
            provenance: const {},
          ),
          throwsStateError,
          reason: 'the chain holds a record the ledger lacks',
        );
        expect(
          () => chain.syncedTo(records.take(5).toList()),
          throwsStateError,
        );
        final entries = [for (final line in lines) decode(line)];
        entries[0]['record'] = Map<String, Object?>.from(
          entries[0]['record']! as Map,
        )..['author'] = 'forged';
        expect(
          () => GovernanceLedgerChain.seal(entries).syncedTo(records),
          throwsStateError,
        );
      },
    );
  });

  group('migration from the frozen fixtures', () {
    final migrated = [
      for (final entry in chain.checkpointEntries)
        if (entry['migrated_fixture'] != null) entry,
    ];

    test('the 22 frozen fixtures v62 to v83 each became one checkpoint', () {
      expect(migrated.map((entry) => entry['before_identity_version']), [
        for (var v = 62; v <= 83; v++) v,
      ]);
      final shapes = {
        for (final entry in migrated)
          [
            for (final pair
                in (entry['migrated_fixture']! as Map)['layout'] as List)
              (pair as List).first,
          ].join(','),
      };
      expect(shapes, hasLength(10), reason: 'ten historical header shapes');
    });

    test('every fixture is reproduced byte for byte from the chain', () {
      for (final entry in migrated) {
        final fixture = entry['migrated_fixture']! as Map<String, Object?>;
        final rebuilt = utf8.encode(_rebuildFixture(chain, entry, records));

        expect(rebuilt.length, fixture['bytes'], reason: '${fixture['path']}');
        expect(sha256.convert(rebuilt).toString(), fixture['sha256']);
        final file = File(fixture['path']! as String);
        expect(file.readAsBytesSync(), rebuilt, reason: file.path);
      }
    });

    test('every record and digest of every fixture equals the chain', () {
      final fixtures = Directory('test/fixtures')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('governance_history_before_v'))
          .toList();
      expect(fixtures, hasLength(migrated.length));
      for (final file in fixtures) {
        final version = int.parse(
          RegExp(r'before_v(\d+)\.json$').firstMatch(file.path)!.group(1)!,
        );
        final frozen = jsonDecode(file.readAsStringSync()) as Map;
        final snapshot = chain.snapshotBefore(version);
        expect(
          frozen['records'] ?? frozen['ledger_records'],
          snapshot.records,
          reason: file.path,
        );
        expect(
          frozen['record_sha256'] ??
              frozen['ledger_record_sha256'] ??
              frozen['record_sha256s'],
          snapshot.recordSha256s,
          reason: file.path,
        );
      }
    });
  });
}

/// Rebuilds a migrated fixture from its checkpoint: the chain's records in the
/// production record key order, every header value from the normalized
/// provenance, laid out under the fixture's own key names and order.
String _rebuildFixture(
  GovernanceLedgerChain chain,
  Map<String, Object?> checkpoint,
  List<ContextOfUseRequalificationRecord> ledgerRecords,
) {
  final fixture = checkpoint['migrated_fixture']! as Map<String, Object?>;
  final snapshot = chain.snapshotBefore(
    checkpoint['before_identity_version']! as int,
  );
  final provenance = checkpoint['provenance']! as Map<String, Object?>;
  final rebuilt = <String, Object?>{};
  for (final pair in fixture['layout']! as List) {
    final [key as String, target as String] = pair as List;
    rebuilt[key] = switch (target) {
      'records' => [
        for (var i = 0; i < snapshot.records.length; i++)
          _orderedLike(snapshot.records[i], ledgerRecords[i].toJson()),
      ],
      'record_sha256s' => snapshot.recordSha256s,
      _ =>
        target
            .split('.')
            .skip(1)
            .fold<Object?>(provenance, (node, part) => (node! as Map)[part]),
    };
  }
  return '${const JsonEncoder.withIndent('  ').convert(rebuilt)}\n';
}

/// [value] with its map keys in the order [template] uses.
Object? _orderedLike(Object? value, Object? template) {
  if (value is Map && template is Map) {
    return {
      for (final key in [
        ...template.keys.where(value.containsKey),
        ...value.keys.where((key) => !template.containsKey(key)),
      ])
        key: _orderedLike(value[key], template[key]),
    };
  }
  if (value is List && template is List) {
    return [
      for (var i = 0; i < value.length; i++)
        _orderedLike(value[i], i < template.length ? template[i] : null),
    ];
  }
  return value;
}
