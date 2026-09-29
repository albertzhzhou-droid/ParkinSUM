import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/operational_observability.dart';
import 'package:parkinsum_companion/features/diagnostics/operational_observability_page.dart';

import 'helpers/page_test_harness.dart';

void main() {
  final now = DateTime.utc(2026, 8, 18, 12);

  test('duration mapping is coarse, bounded, and rejects negative values', () {
    expect(
      operationalDurationBucket(const Duration(milliseconds: 249)),
      OperationalDurationBucket.under250Ms,
    );
    expect(
      operationalDurationBucket(const Duration(milliseconds: 250)),
      OperationalDurationBucket.from250To999Ms,
    );
    expect(
      operationalDurationBucket(const Duration(seconds: 1)),
      OperationalDurationBucket.from1To4S,
    );
    expect(
      operationalDurationBucket(const Duration(seconds: 5)),
      OperationalDurationBucket.atLeast5S,
    );
    expect(
      () => operationalDurationBucket(const Duration(milliseconds: -1)),
      throwsFormatException,
    );
  });

  test('local ledger aggregates without exposing exact timestamps', () {
    final ledger = OperationalObservabilityLedger();
    ledger.record(_startupSuccess, now: now);
    ledger.record(_startupSuccess, now: now.add(const Duration(minutes: 1)));
    final snapshot = ledger.snapshot(now: now.add(const Duration(minutes: 2)));
    expect(snapshot.totalCount, 2);
    expect(snapshot.aggregates, hasLength(1));
    expect(snapshot.aggregates.single.count, 2);
    expect(snapshot.windowMinutes, 1440);
    expect(
      jsonEncode(snapshot.aggregates.single.toJson()),
      isNot(contains('2026')),
    );
  });

  test('local retention expires old observations and disabling clears', () {
    final ledger = OperationalObservabilityLedger();
    ledger.record(_startupSuccess, now: now);
    expect(
      ledger.snapshot(now: now.add(const Duration(hours: 24))).totalCount,
      1,
    );
    expect(
      ledger
          .snapshot(now: now.add(const Duration(hours: 24, seconds: 1)))
          .totalCount,
      0,
    );
    ledger.record(_startupSuccess, now: now.add(const Duration(days: 2)));
    ledger.setCollectionEnabled(false);
    expect(
      ledger.snapshot(now: now.add(const Duration(days: 2))).totalCount,
      0,
    );
    ledger.record(_startupSuccess, now: now.add(const Duration(days: 2)));
    expect(
      ledger.snapshot(now: now.add(const Duration(days: 2))).totalCount,
      0,
    );
  });

  test('cardinality overflow stays visible and makes export fail closed', () {
    final ledger = _overflowedLedger(now);
    final snapshot = ledger.snapshot(now: now);
    expect(
      snapshot.aggregates,
      hasLength(operationalObservabilityMaxAggregateCells),
    );
    expect(snapshot.droppedObservationCount, 1);
    expect(snapshot.overflowed, isTrue);
    expect(
      () => const OperationalObservabilityEnvelopeService().create(
        snapshot: snapshot,
        release: _release,
        policy: const OperationalExportPolicy(
          offDeviceEnabled: true,
          emergencyDisabled: false,
          samplingPermille: 100,
        ),
        authorization: _authorization,
      ),
      throwsFormatException,
    );
    ledger.clear();
    expect(ledger.snapshot(now: now).overflowed, isFalse);
  });

  test('off-device export is disabled by default and emergency kill wins', () {
    const service = OperationalObservabilityEnvelopeService();
    final snapshot = _snapshot(now);
    expect(
      () => service.create(
        snapshot: snapshot,
        release: _release,
        policy: const OperationalExportPolicy(),
        authorization: _authorization,
      ),
      throwsFormatException,
    );
    expect(
      () => service.create(
        snapshot: snapshot,
        release: _release,
        policy: const OperationalExportPolicy(
          offDeviceEnabled: true,
          samplingPermille: 100,
        ),
        authorization: _authorization,
      ),
      throwsFormatException,
    );
  });

  test('stale or malformed purpose authorization fails closed', () {
    const service = OperationalObservabilityEnvelopeService();
    const policy = OperationalExportPolicy(
      offDeviceEnabled: true,
      emergencyDisabled: false,
      samplingPermille: 100,
    );
    for (final authorization in <OperationalExportAuthorization>[
      OperationalExportAuthorization(
        current: false,
        noticeVersion: operationalObservabilityNoticeVersion,
        noticeSha256: OperationalObservabilityNotice.sha256Digest,
        receiptSha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
      OperationalExportAuthorization(
        current: true,
        noticeVersion: operationalObservabilityNoticeVersion + 1,
        noticeSha256: OperationalObservabilityNotice.sha256Digest,
        receiptSha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
      const OperationalExportAuthorization(
        current: true,
        noticeVersion: operationalObservabilityNoticeVersion,
        noticeSha256: 'badhash',
        receiptSha256: 'a',
      ),
    ]) {
      expect(
        () => service.create(
          snapshot: _snapshot(now),
          release: _release,
          policy: policy,
          authorization: authorization,
        ),
        throwsFormatException,
      );
    }
  });

  test('reviewed aggregate envelope is deterministic and identifier-free', () {
    const service = OperationalObservabilityEnvelopeService();
    const policy = OperationalExportPolicy(
      offDeviceEnabled: true,
      emergencyDisabled: false,
      samplingPermille: 100,
    );
    final first = service.create(
      snapshot: _snapshot(now),
      release: _release,
      policy: policy,
      authorization: _authorization,
    );
    final second = service.create(
      snapshot: _snapshot(now),
      release: _release,
      policy: policy,
      authorization: _authorization,
    );
    expect(first.canonicalJson, second.canonicalJson);
    expect(first.envelopeSha256, second.envelopeSha256);
    expect(first.canonicalJson, isNot(contains('patient')));
    expect(first.canonicalJson, isNot(contains('email')));
    expect(first.canonicalJson, isNot(contains('uid')));
    expect(first.canonicalJson, isNot(contains('timestamp')));
    expect(first.canonicalJson, isNot(contains(_authorization.receiptSha256)));
    service.validateSerializedEnvelope(first.canonicalJson);
  });

  test('unknown sensitive fields and future schema are rejected', () {
    const service = OperationalObservabilityEnvelopeService();
    final valid = service.create(
      snapshot: _snapshot(now),
      release: _release,
      policy: const OperationalExportPolicy(
        offDeviceEnabled: true,
        emergencyDisabled: false,
        samplingPermille: 100,
      ),
      authorization: _authorization,
    );
    final decoded = jsonDecode(valid.canonicalJson) as Map<String, dynamic>;
    decoded['raw_exception'] = 'levodopa meal user@example.test token';
    expect(
      () => service.validateSerializedEnvelope(jsonEncode(decoded)),
      throwsFormatException,
    );
    decoded.remove('raw_exception');
    decoded['schema_version'] = 2;
    expect(
      () => service.validateSerializedEnvelope(jsonEncode(decoded)),
      throwsFormatException,
    );
  });

  test('tampering with a reviewed envelope breaks its content identity', () {
    const service = OperationalObservabilityEnvelopeService();
    final valid = service.create(
      snapshot: _snapshot(now),
      release: _release,
      policy: const OperationalExportPolicy(
        offDeviceEnabled: true,
        emergencyDisabled: false,
        samplingPermille: 100,
      ),
      authorization: _authorization,
    );
    final decoded = jsonDecode(valid.canonicalJson) as Map<String, dynamic>;
    final aggregates = decoded['aggregates'] as List<dynamic>;
    (aggregates.single as Map<String, dynamic>)['count'] = 999;
    expect(
      () => service.validateSerializedEnvelope(jsonEncode(decoded)),
      throwsFormatException,
    );
  });

  testWidgets('UI exposes categories, export-off status, and immediate clear', (
    tester,
  ) async {
    final ledger = OperationalObservabilityLedger()
      ..record(_startupSuccess, now: now);
    await pumpFeaturePage(
      tester,
      OperationalObservabilityPage(ledger: ledger, now: () => now),
      surfaceSize: const Size(1000, 2200),
    );
    expectNoWidgetErrors(reason: 'operational observability page failed');
    expect(find.text('Privacy-bounded operations'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('operational-observability-export-disabled')),
      findsOneWidget,
    );
    expect(find.textContaining('startup · success'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('operational-observability-local-toggle')),
    );
    await tester.pump();
    expect(ledger.collectionEnabled, isFalse);
    expect(ledger.snapshot(now: now).totalCount, 0);
    expect(
      find.text('No aggregate events are currently retained.'),
      findsOneWidget,
    );
  });

  testWidgets('UI reports cardinality overflow without crashing', (
    tester,
  ) async {
    final ledger = _overflowedLedger(now);
    await pumpFeaturePage(
      tester,
      OperationalObservabilityPage(ledger: ledger, now: () => now),
      surfaceSize: const Size(1000, 2600),
    );
    expectNoWidgetErrors(
      reason: 'observability overflow should remain visible',
    );
    expect(
      find.byKey(const ValueKey('operational-observability-overflow')),
      findsOneWidget,
    );
    expect(find.textContaining('Dropped event count: 1'), findsOneWidget);
  });
}

const _startupSuccess = OperationalObservation(
  category: OperationalSignalCategory.startup,
  outcome: OperationalOutcome.success,
  duration: OperationalDurationBucket.from250To999Ms,
  capability: OperationalCapabilityState.supported,
);

const _release = OperationalReleaseIdentity(
  appVersion: '0.2.0',
  buildNumber: '2',
  buildCommitSha256: 'unavailable',
  platformFamily: 'android',
  backendMode: 'local',
  environment: 'dev',
  algorithmConfigurationSha256:
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  algorithmSourceBundleSha256:
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
);

final _authorization = OperationalExportAuthorization(
  current: true,
  noticeVersion: operationalObservabilityNoticeVersion,
  noticeSha256: OperationalObservabilityNotice.sha256Digest,
  receiptSha256:
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
);

OperationalLocalSnapshot _snapshot(DateTime now) {
  final ledger = OperationalObservabilityLedger()
    ..record(_startupSuccess, now: now);
  return ledger.snapshot(now: now);
}

OperationalObservabilityLedger _overflowedLedger(DateTime now) {
  final ledger = OperationalObservabilityLedger();
  var recorded = 0;
  outer:
  for (final category in OperationalSignalCategory.values) {
    for (final outcome in OperationalOutcome.values) {
      for (final duration in OperationalDurationBucket.values) {
        for (final capability in OperationalCapabilityState.values) {
          ledger.record(
            OperationalObservation(
              category: category,
              outcome: outcome,
              duration: duration,
              capability: capability,
            ),
            now: now,
          );
          recorded += 1;
          if (recorded == operationalObservabilityMaxAggregateCells + 1) {
            break outer;
          }
        }
      }
    }
  }
  return ledger;
}
