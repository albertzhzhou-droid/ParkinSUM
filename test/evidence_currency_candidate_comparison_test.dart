import 'dart:convert';
import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:parkinsum_companion/core/services/origin_storage_coordination.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parkinsum_companion/domain/entities/evidence_currency.dart';
import 'package:parkinsum_companion/domain/usecases/evidence_currency_candidate_comparison.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final asOf = DateTime.utc(2026, 8, 19);
  final baseline = EvidenceCurrencyRegistry.current;
  const service = EvidenceCurrencyCandidateComparisonService();

  EvidenceCurrencyRegistry candidate(EvidenceCurrencyStatus status) =>
      EvidenceCurrencyRegistry(
        records: [
          baseline.records.first.copyWith(
            status: status,
            updateNoticeId: 'synthetic_status_notice',
          ),
          ...baseline.records.skip(1),
        ],
      );

  test(
    'production receipt mutation waits on the shared whole-document lock',
    () async {
      SharedPreferences.setMockInitialValues({});
      const owner = 'synthetic_w26_process_lock';
      final key =
          'parkinsum.evidence_currency_comparison.v1.${sha256.convert(utf8.encode(jsonEncode(owner)))}';
      final entered = Completer<void>(), release = Completer<void>();
      final held = withOriginStorageLock(key, () async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      var accepted = false;
      final store = LocalEvidenceCurrencyComparisonReceiptStore(ownerId: owner);
      final receipt = service.compare(
        baseline: baseline,
        candidate: baseline,
        asOfUtc: asOf,
      );
      final pending = store.retain(receipt).then((_) => accepted = true);
      await Future<void>.delayed(Duration.zero);
      expect(accepted, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(key), isNull);
      release.complete();
      await held;
      await pending;
      expect(accepted, isTrue);
      expect((await store.load()).single.toJson(), receipt.toJson());
    },
  );

  test(
    'a revoked queued mutation fails and does not poison the lock for a later lease',
    () async {
      SharedPreferences.setMockInitialValues({});
      const owner = 'synthetic_w26_revoked_queued';
      final key =
          'parkinsum.evidence_currency_comparison.v1.${sha256.convert(utf8.encode(jsonEncode(owner)))}';
      final entered = Completer<void>(), release = Completer<void>();
      final held = withOriginStorageLock(key, () async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      var authorized = true;
      final store = LocalEvidenceCurrencyComparisonReceiptStore(ownerId: owner);
      final receipt = service.compare(
        baseline: baseline,
        candidate: baseline,
        asOfUtc: asOf,
      );
      final pending = store.retain(receipt, authorize: () => authorized);
      final rejected = expectLater(pending, throwsStateError);
      authorized = false;
      release.complete();
      await held;
      await rejected;
      expect(await store.load(), isEmpty);
      authorized = true;
      await store.retain(receipt, authorize: () => authorized);
      expect((await store.load()).single.toJson(), receipt.toJson());
    },
  );

  test('invalid owner scopes cannot address or modify an archive', () {
    for (final owner in [' ', 'x' * 513, 'control\u0000owner']) {
      expect(
        () => LocalEvidenceCurrencyComparisonReceiptStore(ownerId: owner),
        throwsArgumentError,
      );
    }
  });
  test(
    'preference persistence checks a revoked lease before committing and reading',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = LocalEvidenceCurrencyComparisonReceiptStore(
        ownerId: 'synthetic_owner_lease',
      );
      var authorized = true;
      final receipt = service.compare(
        baseline: baseline,
        candidate: baseline,
        asOfUtc: asOf,
      );
      final pending = store.retain(receipt, authorize: () => authorized);
      authorized = false;
      await expectLater(pending, throwsStateError);
      await expectLater(
        store.load(authorize: () => authorized),
        throwsStateError,
      );
      authorized = true;
      expect(await store.load(authorize: () => authorized), isEmpty);
    },
  );

  test(
    'offline changed status uses the original gate and cannot activate itself',
    () {
      final receipt = service.compare(
        baseline: baseline,
        candidate: candidate(EvidenceCurrencyStatus.retracted),
        asOfUtc: asOf,
      );
      final json = receipt.toJson();
      expect(json['runtime_activation_authorized'], isFalse);
      final changes = json['claim_changes'] as List;
      expect(changes, hasLength(1));
      expect(changes.single['before_effective_status'], 'current');
      expect(changes.single['candidate_effective_status'], 'retracted');
      final affected = baseline.records.first.providerIds;
      for (final disposition in json['provider_dispositions'] as List) {
        if (!affected.contains(disposition['provider_id'])) continue;
        expect(disposition['baseline'], 'allowResearchTraceOnly');
        expect(disposition['candidate'], 'blockAffectedProviders');
      }
      expect(baseline.assess(asOfUtc: asOf).blockedRecords, isEmpty);
      final restored = EvidenceCurrencyComparisonReceipt.fromJson(
        Map<String, dynamic>.from(json),
      );
      expect(restored.toJson(), json);
    },
  );

  test(
    'removed coverage and duplicate claim identity fail the existing integrity gate',
    () {
      for (final records in [
        <EvidenceCurrencyRecord>[],
        [...baseline.records, baseline.records.first],
      ]) {
        final receipt = service.compare(
          baseline: baseline,
          candidate: EvidenceCurrencyRegistry(records: records),
          asOfUtc: asOf,
        );
        final json = receipt.toJson();
        final snapshot = json['candidate_snapshot'] as Map;
        expect(snapshot['integrity_reasons'], isNotEmpty);
        expect(
          (json['provider_dispositions'] as List).every(
            (row) => row['candidate'] == 'blockRegistryIntegrity',
          ),
          isTrue,
        );
      }
    },
  );

  test(
    'receipt captures clock-specific expiry separately from changed records',
    () {
      final receipt = service.compare(
        baseline: baseline,
        candidate: baseline,
        asOfUtc: DateTime.utc(2030),
      );
      final json = receipt.toJson();
      expect(json['claim_changes'], isEmpty);
      expect(
        (json['baseline_snapshot'] as Map)['blocked_claim_ids'],
        isNotEmpty,
      );
      expect(
        (json['provider_dispositions'] as List).every(
          (row) => row['baseline'] == row['candidate'],
        ),
        isTrue,
      );
      expect(
        () => service.compare(
          baseline: baseline,
          candidate: baseline,
          asOfUtc: DateTime(2026),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'receipt tampering, unknown schema and activation authorization fail closed',
    () {
      final receipt = service.compare(
        baseline: baseline,
        candidate: baseline,
        asOfUtc: asOf,
      );
      final mutations = [
        {...receipt.toJson(), 'baseline_snapshot': <String, Object?>{}},
        {...receipt.toJson(), 'as_of_utc': '2026-08-20T00:00:00.000Z'},
        {
          ...receipt.toJson(),
          'schema': 'parkinsum.evidence-currency-candidate-comparison/2',
        },
        {...receipt.toJson(), 'runtime_activation_authorized': true},
        {...receipt.toJson(), 'future': true},
      ];
      for (final mutation in mutations) {
        expect(
          () => EvidenceCurrencyComparisonReceipt.fromJson(
            Map<String, dynamic>.from(mutation),
          ),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'new owner-scoped store instances retain complete historical snapshots idempotently',
    () async {
      SharedPreferences.setMockInitialValues({});
      final first = service.compare(
        baseline: baseline,
        candidate: candidate(EvidenceCurrencyStatus.corrected),
        asOfUtc: asOf,
      );
      final second = service.compare(
        baseline: baseline,
        candidate: candidate(EvidenceCurrencyStatus.retracted),
        asOfUtc: asOf,
      );
      final store = LocalEvidenceCurrencyComparisonReceiptStore(
        ownerId: 'synthetic_owner_a',
      );
      await Future.wait([
        store.retain(first),
        store.retain(second),
        store.retain(first),
      ]);
      final reloaded = await LocalEvidenceCurrencyComparisonReceiptStore(
        ownerId: 'synthetic_owner_a',
      ).load();
      expect(reloaded, hasLength(2));
      expect(jsonEncode(reloaded.first.toJson()), jsonEncode(first.toJson()));
      expect(
        (reloaded.first.toJson()['candidate_snapshot']
            as Map)['held_claim_ids'],
        contains(baseline.records.first.claimId),
      );
      expect(
        (reloaded.last.toJson()['candidate_snapshot']
            as Map)['blocked_claim_ids'],
        contains(baseline.records.first.claimId),
      );
      expect(
        await LocalEvidenceCurrencyComparisonReceiptStore(
          ownerId: 'synthetic_owner_b',
        ).load(),
        isEmpty,
      );
      expect(
        () => LocalEvidenceCurrencyComparisonReceiptStore(ownerId: ''),
        throwsArgumentError,
      );
    },
  );

  test(
    'capacity rejects the next receipt without eviction or partial replacement',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = LocalEvidenceCurrencyComparisonReceiptStore(
        ownerId: 'synthetic_w26_capacity',
      );
      final expected = <EvidenceCurrencyComparisonReceipt>[];
      for (var i = 0; i < 128; i++) {
        final receipt = service.compare(
          baseline: baseline,
          candidate: baseline,
          asOfUtc: asOf.add(Duration(minutes: i)),
        );
        expected.add(receipt);
        await store.retain(receipt);
      }
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getKeys().single;
      final before = prefs.getString(key);
      final extra = service.compare(
        baseline: baseline,
        candidate: baseline,
        asOfUtc: asOf.add(const Duration(minutes: 128)),
      );
      await expectLater(store.retain(extra), throwsStateError);
      await prefs.reload();
      expect(prefs.getString(key), before);
      expect(
        (await store.load()).map((r) => r.toJson()).toList(),
        expected.map((r) => r.toJson()).toList(),
      );
      await store.retain(expected.first);
      expect((await store.load()).length, 128);
    },
  );

  test(
    'a corrupted local archive rejects later writes without silently replacing history',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = LocalEvidenceCurrencyComparisonReceiptStore(
        ownerId: 'synthetic_corrupt_owner',
      );
      final receipt = service.compare(
        baseline: baseline,
        candidate: baseline,
        asOfUtc: asOf,
      );
      await store.retain(receipt);
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getKeys().singleWhere(
        (key) => key.startsWith('parkinsum.evidence_currency_comparison.v1.'),
      );
      await prefs.setString(key, '{"schema_version":2,"receipts":[]}');
      await expectLater(store.load(), throwsFormatException);
      await expectLater(store.retain(receipt), throwsFormatException);
      expect(prefs.getString(key), '{"schema_version":2,"receipts":[]}');
    },
  );
}
