import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'context_of_use_requalification.dart';

/// Pinned identity of the chain at one identity bump: the ledger as it stood
/// before `v<beforeIdentityVersion>` was appended.
final class GovernanceLedgerCheckpointPin {
  /// The bump this checkpoint precedes; the snapshot is the ledger of the
  /// previous identity version.
  final int beforeIdentityVersion;

  /// Number of ledger records in the snapshot.
  final int recordCount;

  /// Digest of the snapshot's whole records and record digests.
  final String snapshotSha256;

  /// `entry_sha256` of the checkpoint line, which commits to the entire chain
  /// prefix up to and including it.
  final String entrySha256;

  /// The pinned historical configuration digest that the snapshot's last
  /// record must carry.
  final String lastConfigurationSha256;

  const GovernanceLedgerCheckpointPin({
    required this.beforeIdentityVersion,
    required this.recordCount,
    required this.snapshotSha256,
    required this.entrySha256,
    required this.lastConfigurationSha256,
  });
}

/// The ledger as it stood at one point of the chain.
final class GovernanceLedgerSnapshot {
  final int identityVersion;
  final List<Map<String, Object?>> records;

  GovernanceLedgerSnapshot._(
    this.identityVersion,
    List<Map<String, Object?>> records,
  ) : records = List.unmodifiable(records);

  List<String> get recordSha256s => [
    for (final record in records) record['record_sha256']! as String,
  ];

  String get sha256Digest => GovernanceLedgerChain.snapshotSha256(records);
}

/// Result of checking a chain against the production ledger and the pins.
final class GovernanceLedgerChainVerification {
  final List<String> reasons;
  final int entryCount;
  final int recordCount;
  final String headSha256;

  GovernanceLedgerChainVerification._({
    required List<String> reasons,
    required this.entryCount,
    required this.recordCount,
    required this.headSha256,
  }) : reasons = List.unmodifiable(reasons);

  bool get verified => reasons.isEmpty;

  Map<String, Object?> toJson() => {
    'schema': GovernanceLedgerChain.schema,
    'entry_count': entryCount,
    'record_count': recordCount,
    'head_sha256': headSha256,
    'verified': verified,
    'integrity_reasons': reasons,
  };
}

/// Append-only, hash-chained history of the context-of-use ledger.
///
/// One canonical JSON line per entry in [path]. A `record` entry carries one
/// whole ledger record and its digest; a `checkpoint` entry marks an identity
/// bump and names the snapshot of the ledger before it. Every entry links to
/// the previous entry's `entry_sha256`, so editing, re-hashing, reordering or
/// deleting any earlier line breaks every later link and the pinned head.
///
/// This is engineering change control over stored history. A verified chain
/// adds no evidence, review, validation or approval, and it does not defend
/// against an author who rewrites the chain and its pins in one reviewed
/// change; code review and git history remain that control.
final class GovernanceLedgerChain {
  static const String schema = 'parkinsum.governance-ledger-chain/1';
  static const int schemaVersion = 1;
  static const String path = 'config/governance_ledger.jsonl';
  static const String genesisSha256 =
      '0000000000000000000000000000000000000000000000000000000000000000';
  static const String recordKind = 'record';
  static const String checkpointKind = 'checkpoint';

  // Pins written by `npm run identity:rebind`; see docs/IDENTITY_REBIND.md.
  static const int expectedEntryCount = 54;
  static const String expectedHeadSha256 =
      'a588f80c17fa7b2119889e69151091c965089940266096550ba68bbd53fff498';
  static const List<GovernanceLedgerCheckpointPin> checkpointPins = [
    GovernanceLedgerCheckpointPin(
      beforeIdentityVersion: 62,
      recordCount: 10,
      snapshotSha256:
          '25a2698445732fed2defa2b39e16ef511496ed05a91468c7fc85b62774b4498e',
      entrySha256:
          '06d13a1f48efdca489a0f4e23cd3c0524abd98886f99a844a59fa07c7d990206',
      lastConfigurationSha256:
          ContextOfUseRequalificationLedger.historicalV61ConfigurationSha256,
    ),
    GovernanceLedgerCheckpointPin(
      beforeIdentityVersion: 63,
      recordCount: 11,
      snapshotSha256:
          'd2ce1eaa0a80d8f849ab6ad5bf8a65fd9e8efcd6473cca887113d3991c77dbeb',
      entrySha256:
          '903d17b07254a9f0cdad290e45ee7bb0e7656246a6e52854f015f74e3d728f6c',
      lastConfigurationSha256:
          ContextOfUseRequalificationLedger.historicalV62ConfigurationSha256,
    ),
    GovernanceLedgerCheckpointPin(
      beforeIdentityVersion: 64,
      recordCount: 12,
      snapshotSha256:
          'c2b4db9b2155e7b18594240f93314ba79d238b92d5f4ae46a34d74cc6c63e068',
      entrySha256:
          'fd9d08d4aad30845a7c7999fb73d748f4e90ef2a7859f4523cdc53e98a69bea7',
      lastConfigurationSha256:
          ContextOfUseRequalificationLedger.historicalV63ConfigurationSha256,
    ),
    GovernanceLedgerCheckpointPin(
      beforeIdentityVersion: 65,
      recordCount: 13,
      snapshotSha256:
          'a09d70cc7067b92fa503a86ad950ec4e5af9400ba3ecc1dc5ee95aab1d24698e',
      entrySha256:
          'dfa15b6af4da8f139023d418404fe61ec8efb216b1d0550a2bc5e67742258c1d',
      lastConfigurationSha256:
          ContextOfUseRequalificationLedger.historicalV64ConfigurationSha256,
    ),
    GovernanceLedgerCheckpointPin(
      beforeIdentityVersion: 66,
      recordCount: 14,
      snapshotSha256:
          '4e1e311520291dd746b1976cc74f75584862d69f88103dcdf42cf4494c686d67',
      entrySha256:
          '3f8d6dc510a76a3c5be5da79e80e542cc61a6623f0750af8d2832eef4fc76914',
      lastConfigurationSha256:
          ContextOfUseRequalificationLedger.historicalV65ConfigurationSha256,
    ),
    GovernanceLedgerCheckpointPin(
      beforeIdentityVersion: 67,
      recordCount: 15,
      snapshotSha256:
          'eed1fa3ccb94df6cb077ed08b7fd4f281cf01c0891811f23e608469c1b51181a',
      entrySha256:
          '440c6b9a2c42d893602231762d9816c314965024ef7ba711ed537db69a5f37f9',
      lastConfigurationSha256:
          ContextOfUseRequalificationLedger.historicalV66ConfigurationSha256,
    ),
    GovernanceLedgerCheckpointPin(
      beforeIdentityVersion: 68,
      recordCount: 16,
      snapshotSha256:
          '62955d9c1a60e0c1e05d268e751bdd88615112d6bfd92ad4959b1887928be2b2',
      entrySha256:
          'f75734378112aec7572cafe71db631382da875fdf62af5a7300cf104ce594319',
      lastConfigurationSha256:
          ContextOfUseRequalificationLedger.historicalV67ConfigurationSha256,
    ),
    GovernanceLedgerCheckpointPin(
      beforeIdentityVersion: 69,
      recordCount: 17,
      snapshotSha256:
          '30096d6c135fab4be1ddffb6446e9a8d644af460c7cb8ee506fedc615de1fe14',
      entrySha256:
          'fbcde2f9b5033cdb56b48bd1f9668b143ecb7ec811321a3b37027cedc52f2f4a',
      lastConfigurationSha256:
          ContextOfUseRequalificationLedger.historicalV68ConfigurationSha256,
    ),
    GovernanceLedgerCheckpointPin(
      beforeIdentityVersion: 70,
      recordCount: 18,
      snapshotSha256:
          '324f1b272409563d6c21b8f3988e471e71fd704f83a0c000c7d0fc60898288ba',
      entrySha256:
          '8850d7b02dc8b7d39f5f638fe5916600d97b36ba6c7a20ea597168837e927890',
      lastConfigurationSha256:
          ContextOfUseRequalificationLedger.historicalV69ConfigurationSha256,
    ),
    GovernanceLedgerCheckpointPin(
      beforeIdentityVersion: 71,
      recordCount: 19,
      snapshotSha256:
          'b422380dac3505108522d5eebdaed284a2c43056025b1ea6d43cfb2f98fe5bd8',
      entrySha256:
          '5d1b2f95ca158eb96dd0d14941869e7b7fb2cb59c507b4f46eaa525789a38b36',
      lastConfigurationSha256:
          ContextOfUseRequalificationLedger.historicalV70ConfigurationSha256,
    ),
    GovernanceLedgerCheckpointPin(
      beforeIdentityVersion: 72,
      recordCount: 20,
      snapshotSha256:
          '2259bd03ba82695b11f4658b9168be7e1da69a47839e5c2d472c58994b76886d',
      entrySha256:
          'e86950d5d44087951891a56b9ffd222e8eed3be1224decb2fb8a31f9fa26f579',
      lastConfigurationSha256:
          ContextOfUseRequalificationLedger.historicalV71ConfigurationSha256,
    ),
    GovernanceLedgerCheckpointPin(
      beforeIdentityVersion: 73,
      recordCount: 21,
      snapshotSha256:
          'c0a56c388c304010067a503fb9c42a36d2df7d768dce0446f3d58b258b094ee0',
      entrySha256:
          'd177c3f078c3d8e394a78f2241c30baf798467b5469825d4fe62fa7151b05dd1',
      lastConfigurationSha256:
          ContextOfUseRequalificationLedger.historicalV72ConfigurationSha256,
    ),
    GovernanceLedgerCheckpointPin(
      beforeIdentityVersion: 74,
      recordCount: 22,
      snapshotSha256:
          'e29ed0448a04b6ca683fc72f8feb63dbe73fb8641d959f33436bf2cac6a69c7b',
      entrySha256:
          'a664912f4ff54ed0597c9b0403be8c8dbaf69aebbb406bed65617bc2eb556632',
      lastConfigurationSha256:
          ContextOfUseRequalificationLedger.historicalV73ConfigurationSha256,
    ),
    GovernanceLedgerCheckpointPin(
      beforeIdentityVersion: 75,
      recordCount: 23,
      snapshotSha256:
          'e11b89b466e0c01044489911cc8bb297308c71416d9fe1975a58979d80b492bb',
      entrySha256:
          '750f0c82dc1674533386eeb3bc8f3e8a99dd510ba8e9752a126b4bda816e5f4e',
      lastConfigurationSha256:
          ContextOfUseRequalificationLedger.historicalV74ConfigurationSha256,
    ),
    GovernanceLedgerCheckpointPin(
      beforeIdentityVersion: 76,
      recordCount: 24,
      snapshotSha256:
          'de38e45b4b5f27def34365e83ee5b0960a8f0eec3102d3a7bc6b0e0c288ac966',
      entrySha256:
          '530e16fb50005e9aef9f54df47cc60e73b1e2c9fbd6e777099614e31b7daa9e9',
      lastConfigurationSha256:
          ContextOfUseRequalificationLedger.historicalV75ConfigurationSha256,
    ),
    GovernanceLedgerCheckpointPin(
      beforeIdentityVersion: 77,
      recordCount: 25,
      snapshotSha256:
          '7272a29d909e662bcaaaaed256f67b1283ba95d887b4e27f284e928c1951df5c',
      entrySha256:
          '70e918e1d5f5fb246c2c055c9f76886c5a6ccd2d147348998161fc19236c7900',
      lastConfigurationSha256:
          ContextOfUseRequalificationLedger.historicalV76ConfigurationSha256,
    ),
    GovernanceLedgerCheckpointPin(
      beforeIdentityVersion: 78,
      recordCount: 26,
      snapshotSha256:
          'b66b14ca12007ba4e0b2ef37652ab3a2dd2de2bc0785d43adc3ca7f524b45bb8',
      entrySha256:
          '984489a4825abfe6715d1caa8947825ff7b9475aa72af19bde44047900ebf661',
      lastConfigurationSha256:
          ContextOfUseRequalificationLedger.historicalV77ConfigurationSha256,
    ),
    GovernanceLedgerCheckpointPin(
      beforeIdentityVersion: 79,
      recordCount: 27,
      snapshotSha256:
          'fbefbae4ab04d72fce336c68536512785673d64bd663f585652a265285d3763c',
      entrySha256:
          '3415c522a514f3f4a55774782ab4f75a1e9cb5ffc8ac9fca820d8995fd47d4fe',
      lastConfigurationSha256:
          ContextOfUseRequalificationLedger.historicalV78ConfigurationSha256,
    ),
    GovernanceLedgerCheckpointPin(
      beforeIdentityVersion: 80,
      recordCount: 28,
      snapshotSha256:
          'b2f8f604229b023caa5be1cff1c389b6f229218446d3b592bc18c68bfe39cf0b',
      entrySha256:
          '21e05aac9953412d04585efc585b45bb8c70f175ecbfdefc9f64df203f467c76',
      lastConfigurationSha256:
          ContextOfUseRequalificationLedger.historicalV79ConfigurationSha256,
    ),
    GovernanceLedgerCheckpointPin(
      beforeIdentityVersion: 81,
      recordCount: 29,
      snapshotSha256:
          '45fb963ea5c93b66a6072d07b3687aeabae73d3d230a1b50f4a9f472e5c2ca0c',
      entrySha256:
          '6dbb5754ad5ec13ac957fd2e2a34cc3ef7fddfa995b5c77c5f972c5a20cf2c12',
      lastConfigurationSha256:
          ContextOfUseRequalificationLedger.historicalV80ConfigurationSha256,
    ),
    GovernanceLedgerCheckpointPin(
      beforeIdentityVersion: 82,
      recordCount: 30,
      snapshotSha256:
          '5efece6429fe656023126bfc721ec546b3287de5d4e105cedd175b1ee36a1934',
      entrySha256:
          '6168113bc129b6b4ac969a08bd1e80f19917b8c33078eaf5c36ae6e0b62c48ed',
      lastConfigurationSha256:
          ContextOfUseRequalificationLedger.historicalV81ConfigurationSha256,
    ),
    GovernanceLedgerCheckpointPin(
      beforeIdentityVersion: 83,
      recordCount: 31,
      snapshotSha256:
          '14ba81ed2bf5620d672490f278b84a846522fa4b9cf5dd11c946e0766a2bd023',
      entrySha256:
          '687d203b1c65d437f84bc196b1be1a5be2e958cc203753ffc03dc971a59bd729',
      lastConfigurationSha256:
          ContextOfUseRequalificationLedger.historicalV82ConfigurationSha256,
    ),
  ];

  /// Sealed entries, each including `entry_sha256`.
  final List<Map<String, Object?>> entries;

  /// Problems found while reading the text; see [verify].
  final List<String> parseReasons;

  GovernanceLedgerChain._(
    List<Map<String, Object?>> entries,
    List<String> parseReasons,
  ) : entries = List.unmodifiable(entries),
      parseReasons = List.unmodifiable(parseReasons);

  /// Reads the JSON Lines text. Malformed lines are reported in
  /// [parseReasons] and left out of [entries].
  factory GovernanceLedgerChain.parse(String text) {
    final reasons = <String>[];
    final entries = <Map<String, Object?>>[];
    if (text.isEmpty) return GovernanceLedgerChain._(entries, ['chain.empty']);
    if (!text.endsWith('\n')) reasons.add('chain.final_newline_missing');
    final lines = text.split('\n');
    if (lines.last.isEmpty) lines.removeLast();
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final position = index + 1;
      Object? decoded;
      try {
        decoded = jsonDecode(line);
      } on FormatException {
        reasons.add('chain.line_invalid_json@$position');
        continue;
      }
      if (decoded is! Map<String, dynamic>) {
        reasons.add('chain.line_not_object@$position');
        continue;
      }
      if (canonicalJson(decoded) != line) {
        reasons.add('chain.line_not_canonical@$position');
      }
      entries.add(Map<String, Object?>.from(decoded));
    }
    return GovernanceLedgerChain._(entries, reasons);
  }

  /// Seals unsealed entry bodies into a chain starting at the genesis link.
  factory GovernanceLedgerChain.seal(Iterable<Map<String, Object?>> bodies) {
    final sealed = <Map<String, Object?>>[];
    for (final body in bodies) {
      sealed.add(
        _sealEntry(
          body,
          index: sealed.length + 1,
          previous: sealed.isEmpty
              ? genesisSha256
              : sealed.last['entry_sha256']! as String,
        ),
      );
    }
    return GovernanceLedgerChain._(sealed, const []);
  }

  /// The unsealed body of a record entry for one production ledger record.
  static Map<String, Object?> recordBody(
    ContextOfUseRequalificationRecord record, {
    required int identityVersion,
  }) => {
    'entry_kind': recordKind,
    'identity_version': identityVersion,
    'sequence': record.sequence,
    'record': record.toJson(),
    'record_sha256': record.recordSha256,
  };

  /// The unsealed body of a checkpoint entry before `v<beforeIdentityVersion>`.
  static Map<String, Object?> checkpointBody({
    required int beforeIdentityVersion,
    required List<Map<String, Object?>> snapshotRecords,
    required Map<String, Object?> provenance,
    Map<String, Object?>? migratedFixture,
  }) => {
    'entry_kind': checkpointKind,
    'before_identity_version': beforeIdentityVersion,
    'record_count': snapshotRecords.length,
    'snapshot_sha256': snapshotSha256(snapshotRecords),
    'provenance': provenance,
    'migrated_fixture': ?migratedFixture,
  };

  /// Digest of a ledger snapshot: its whole records and record digests.
  static String snapshotSha256(List<Map<String, Object?>> records) => _sha256({
    'records': records,
    'record_sha256s': [for (final record in records) record['record_sha256']],
  });

  /// Canonical JSON: object keys sorted at every level, no whitespace. The
  /// same encoding as `AlgorithmConfigurationIdentity.digestConfiguration`
  /// and the ledger's own record digests.
  static String canonicalJson(Object? value) =>
      jsonEncode(_canonicalize(value));

  /// The chain as JSON Lines text.
  String encode() => entries.map((entry) => '${canonicalJson(entry)}\n').join();

  String get headSha256 => entries.isEmpty
      ? genesisSha256
      : (entries.last['entry_sha256'] as String? ?? '');

  Iterable<Map<String, Object?>> get recordEntries =>
      entries.where((entry) => entry['entry_kind'] == recordKind);

  Iterable<Map<String, Object?>> get checkpointEntries =>
      entries.where((entry) => entry['entry_kind'] == checkpointKind);

  /// The ledger as of `v<identityVersion>`: every record appended up to and
  /// including that identity.
  GovernanceLedgerSnapshot snapshotAt(int identityVersion) {
    final records = <Map<String, Object?>>[
      for (final entry in recordEntries)
        if ((entry['identity_version'] as int?)! <= identityVersion)
          Map<String, Object?>.from(entry['record']! as Map),
    ];
    return GovernanceLedgerSnapshot._(identityVersion, records);
  }

  /// The ledger that existed before the bump to `v<beforeIdentityVersion>`,
  /// as named by that bump's checkpoint.
  GovernanceLedgerSnapshot snapshotBefore(int beforeIdentityVersion) =>
      snapshotAt(beforeIdentityVersion - 1);

  /// Checks the chain line by line against the production ledger [records]
  /// and, unless [pinned] is false, against the pinned head, length and
  /// checkpoints. Reasons name the first offending line as `@<line>`.
  GovernanceLedgerChainVerification verify(
    List<ContextOfUseRequalificationRecord> records, {
    bool pinned = true,
    int expectedEntryCount = GovernanceLedgerChain.expectedEntryCount,
    String expectedHeadSha256 = GovernanceLedgerChain.expectedHeadSha256,
    List<GovernanceLedgerCheckpointPin> checkpointPins =
        GovernanceLedgerChain.checkpointPins,
  }) {
    final reasons = <String>[...parseReasons];
    final pins = {
      for (final pin in checkpointPins) pin.beforeIdentityVersion: pin,
    };
    final snapshot = <Map<String, Object?>>[];
    final seenCheckpoints = <int>{};
    var previous = genesisSha256;
    int? lastIdentity;
    Map<String, Object?>? lastEntry;
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      final at = '@${index + 1}';
      if (entry['schema'] != schema) reasons.add('chain.schema_unsupported$at');
      if (entry['entry_index'] != index + 1) {
        reasons.add('chain.entry_index_noncontiguous$at');
      }
      if (entry['previous_entry_sha256'] != previous) {
        reasons.add('chain.previous_link_broken$at');
      }
      final stated = entry['entry_sha256'];
      final body = Map<String, Object?>.from(entry)..remove('entry_sha256');
      if (stated is! String || stated != _sha256(body)) {
        reasons.add('chain.entry_digest_mismatch$at');
      }
      previous = stated is String ? stated : '';
      switch (entry['entry_kind']) {
        case recordKind:
          final record = entry['record'];
          final identity = entry['identity_version'];
          if (record is! Map || identity is! int) {
            reasons.add('chain.record_entry_malformed$at');
            break;
          }
          final recordJson = Map<String, Object?>.from(record);
          final payload = Map<String, Object?>.from(recordJson)
            ..remove('record_sha256');
          if (entry['record_sha256'] != recordJson['record_sha256'] ||
              recordJson['record_sha256'] != _sha256(payload)) {
            reasons.add('chain.record_digest_mismatch$at');
          }
          final sequence = snapshot.length + 1;
          if (entry['sequence'] != sequence ||
              recordJson['sequence'] != sequence) {
            reasons.add('chain.record_sequence_noncontiguous$at');
          }
          final expectedIdentity = lastEntry?['entry_kind'] == checkpointKind
              ? lastEntry!['before_identity_version']
              : (lastIdentity == null ? identity : lastIdentity + 1);
          if (identity != expectedIdentity) {
            reasons.add('chain.identity_version_noncontiguous$at');
          }
          lastIdentity = identity;
          if (sequence > records.length ||
              canonicalJson(records[sequence - 1].toJson()) !=
                  canonicalJson(recordJson)) {
            reasons.add('chain.record_differs_from_ledger$at');
          }
          snapshot.add(recordJson);
        case checkpointKind:
          final before = entry['before_identity_version'];
          if (before is! int) {
            reasons.add('chain.checkpoint_entry_malformed$at');
            break;
          }
          if (lastIdentity == null ||
              before != lastIdentity + 1 ||
              lastEntry?['entry_kind'] != recordKind) {
            reasons.add('chain.checkpoint_boundary_invalid$at');
          }
          if (!seenCheckpoints.add(before)) {
            reasons.add('chain.checkpoint_duplicate$at');
          }
          if (entry['record_count'] != snapshot.length) {
            reasons.add('chain.checkpoint_record_count_mismatch$at');
          }
          final snapshotDigest = snapshotSha256(snapshot);
          if (entry['snapshot_sha256'] != snapshotDigest) {
            reasons.add('chain.checkpoint_snapshot_mismatch$at');
          }
          final lastConfiguration = snapshot.isEmpty
              ? null
              : snapshot.last['current_configuration_sha256'];
          final provenance = entry['provenance'];
          if (provenance is! Map) {
            reasons.add('chain.checkpoint_entry_malformed$at');
          } else if (provenance.containsKey('source_configuration_sha256') &&
              provenance['source_configuration_sha256'] != lastConfiguration) {
            reasons.add('chain.checkpoint_linkage_mismatch$at');
          }
          if (!pinned) break;
          final pin = pins[before];
          if (pin == null) {
            reasons.add('chain.checkpoint_unpinned$at');
            break;
          }
          if (pin.recordCount != snapshot.length ||
              pin.snapshotSha256 != snapshotDigest ||
              pin.entrySha256 != stated) {
            reasons.add('chain.checkpoint_pin_mismatch$at');
          }
          if (pin.lastConfigurationSha256 != lastConfiguration) {
            reasons.add('chain.checkpoint_linkage_mismatch$at');
          }
        default:
          reasons.add('chain.entry_kind_unknown$at');
      }
      lastEntry = entry;
    }
    if (entries.isNotEmpty && lastEntry?['entry_kind'] != recordKind) {
      reasons.add('chain.ends_without_record');
    }
    if (snapshot.length != records.length) {
      reasons.add('chain.record_count_mismatch');
    }
    if (pinned) {
      for (final version in pins.keys) {
        if (!seenCheckpoints.contains(version)) {
          reasons.add('chain.checkpoint_missing:v$version');
        }
      }
      if (entries.length != expectedEntryCount) {
        reasons.add('chain.length_mismatch');
      }
      if (headSha256 != expectedHeadSha256) reasons.add('chain.head_mismatch');
    }
    return GovernanceLedgerChainVerification._(
      reasons: reasons.toSet().toList(),
      entryCount: entries.length,
      recordCount: snapshot.length,
      headSha256: headSha256,
    );
  }

  /// Appends the checkpoint that marks the bump to `v<beforeIdentityVersion>`.
  /// The chain must already hold every production ledger record.
  GovernanceLedgerChain withCheckpoint(
    List<ContextOfUseRequalificationRecord> records, {
    required int beforeIdentityVersion,
    required Map<String, Object?> provenance,
  }) {
    _requireStructurallyVerified(records);
    final next = GovernanceLedgerChain._([
      ...entries,
      _sealEntry(
        checkpointBody(
          beforeIdentityVersion: beforeIdentityVersion,
          snapshotRecords: snapshotAt(beforeIdentityVersion - 1).records,
          provenance: provenance,
        ),
        index: entries.length + 1,
        previous: headSha256,
      ),
    ], const []);
    final problems = next
        .verify(records, pinned: false)
        .reasons
        .where((reason) => reason != 'chain.ends_without_record');
    if (problems.isNotEmpty) {
      throw StateError(
        'checkpoint before v$beforeIdentityVersion does not fit the chain: '
        '${problems.join(', ')}',
      );
    }
    return next;
  }

  /// Rewrites the entries after the last checkpoint so that the chain holds
  /// exactly the production ledger [records]. Everything up to and including
  /// the last checkpoint must already match and is never rewritten.
  GovernanceLedgerChain syncedTo(
    List<ContextOfUseRequalificationRecord> records,
  ) {
    final cut = entries.lastIndexWhere(
      (entry) => entry['entry_kind'] == checkpointKind,
    );
    if (cut < 0) throw StateError('chain has no checkpoint to append after');
    final kept = GovernanceLedgerChain._(entries.take(cut + 1).toList(), []);
    final checkpoint = entries[cut];
    final frozenCount = checkpoint['record_count']! as int;
    final identity = checkpoint['before_identity_version']! as int;
    if (records.length != frozenCount + 1) {
      throw StateError(
        'expected exactly one ledger record after the v$identity checkpoint, '
        'found ${records.length - frozenCount}',
      );
    }
    final frozen = kept.verify(
      records.take(frozenCount).toList(),
      pinned: false,
    );
    final structural = frozen.reasons.where(
      (reason) => reason != 'chain.ends_without_record',
    );
    if (structural.isNotEmpty) {
      throw StateError(
        'chain up to the v$identity checkpoint does not match the ledger: '
        '${structural.join(', ')}',
      );
    }
    final appended = _sealEntry(
      recordBody(records.last, identityVersion: identity),
      index: kept.entries.length + 1,
      previous: kept.headSha256,
    );
    return GovernanceLedgerChain._([...kept.entries, appended], const []);
  }

  void _requireStructurallyVerified(
    List<ContextOfUseRequalificationRecord> records,
  ) {
    final result = verify(records, pinned: false);
    if (!result.verified) {
      throw StateError(
        'chain does not match the ledger: ${result.reasons.join(', ')}',
      );
    }
  }

  static Map<String, Object?> _sealEntry(
    Map<String, Object?> body, {
    required int index,
    required String previous,
  }) {
    final unsealed = <String, Object?>{
      ...body,
      'schema': schema,
      'entry_index': index,
      'previous_entry_sha256': previous,
    }..remove('entry_sha256');
    return {...unsealed, 'entry_sha256': _sha256(unsealed)};
  }
}

String _sha256(Object? value) => sha256
    .convert(utf8.encode(GovernanceLedgerChain.canonicalJson(value)))
    .toString();

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => '$key').toList(growable: false)
      ..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is List) return value.map(_canonicalize).toList(growable: false);
  if (value == null || value is String || value is bool || value is int) {
    return value;
  }
  throw ArgumentError.value(value, 'value', 'must be JSON without fractions');
}
