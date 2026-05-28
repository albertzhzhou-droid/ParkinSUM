import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/data/datasources/remote/live_source_smoke.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_fetch_client.dart';

void main() {
  group('LiveSourceFetchClient', () {
    test('disabled by default → skipped result, no network', () async {
      final client = LiveSourceFetchClient(
        sourceSystem: 'DailyMed',
        enabled: false,
        fetcher: (url, {timeout = const Duration(seconds: 15)}) async {
          fail('fetcher must not be called when disabled');
        },
      );
      final r = await client.fetch('https://example.invalid/meta');
      expect(r.ok, isFalse);
      expect(r.status, 0);
      expect(r.rawPayload, isNull);
      expect(r.error, 'live_fetch_disabled');
    });

    test('enabled + injected fake success → SourceFetchResult ok', () async {
      final client = LiveSourceFetchClient(
        sourceSystem: 'DailyMed',
        enabled: true,
        fetcher: (url, {timeout = const Duration(seconds: 15)}) async =>
            (status: 200, contentType: 'application/json', payload: '{"a":1}'),
      );
      final r = await client.fetch('https://example.invalid/meta');
      expect(r.ok, isTrue);
      expect(r.status, 200);
      expect(r.rawPayload, '{"a":1}');
    });

    test('non-200 → failure result, no fake fact', () async {
      final client = LiveSourceFetchClient(
        sourceSystem: 'DailyMed',
        enabled: true,
        fetcher: (url, {timeout = const Duration(seconds: 15)}) async =>
            (status: 503, contentType: null, payload: null),
      );
      final r = await client.fetch('https://example.invalid/meta');
      expect(r.ok, isFalse);
      expect(r.rawPayload, isNull);
      expect(r.error, contains('non_success_status'));
    });

    test('transport error → failure result, no exception escapes', () async {
      final client = LiveSourceFetchClient(
        sourceSystem: 'DailyMed',
        enabled: true,
        fetcher: (url, {timeout = const Duration(seconds: 15)}) async =>
            throw StateError('boom'),
      );
      final r = await client.fetch('https://example.invalid/meta');
      expect(r.ok, isFalse);
      expect(r.error, 'transport_error');
    });

    test('envEnabled reads the opt-in flag', () {
      expect(
          LiveSourceFetchClient.envEnabled(
              {'PARKINSUM_ENABLE_LIVE_SOURCE_SMOKE': '1'}),
          isTrue);
      expect(LiveSourceFetchClient.envEnabled(const {}), isFalse);
    });
  });

  group('runLiveSourceSmoke', () {
    test('disabled → skipped summary, no network', () async {
      final s = await runLiveSourceSmoke(source: 'dailymed', enabled: false);
      expect(s.enabled, isFalse);
      expect(s.ok, isTrue); // skip is a success
      expect(s.toRedactedString(), contains('SKIPPED'));
    });

    test('fdc enabled requires api key → reports, no secret embedded',
        () async {
      final s = await runLiveSourceSmoke(source: 'fdc', enabled: true);
      expect(s.error, 'requires_api_key_not_supplied');
    });

    test('enabled with injected fake client → shape summary, no raw payload',
        () async {
      final s = await runLiveSourceSmoke(
        source: 'dailymed',
        enabled: true,
        client: const FakeSourceFetchClient(
          textByUrl: {
            'https://dailymed.nlm.nih.gov/dailymed/services/v2/spls.json?pagesize=1':
                '{"data":[]}'
          },
        ),
      );
      expect(s.status, 200);
      expect(s.parseShapeOk, isTrue);
      // Redacted summary must not contain the raw payload body.
      expect(s.toRedactedString(), isNot(contains('"data"')));
    });
  });
}
