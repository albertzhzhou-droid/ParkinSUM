import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parkinsum_companion/core/db/cdss_database.dart';
import 'package:parkinsum_companion/data/datasources/remote/fdc_p0_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_fetch_client.dart';

/// Security-hardening regression tests.
///
/// Pins the fixes from the security scan:
///  - CDSS table identifiers are validated before reaching dynamic identifier
///    sinks (SQL table names, Firestore path segments, storage keys).
///  - Fetch-client error messages never echo URL query strings (which may
///    carry credentials).
///  - The FDC API key travels in the `X-Api-Key` header, never in the URL.
///
/// Educational prototype only; synthetic fixtures; no real credentials.
void main() {
  group('CDSS table-name guard', () {
    test('accepts plain snake_case identifiers', () {
      for (final ok in ['ingestion_run', 'staging_resolved_fact', 'a1_b2']) {
        expect(requireValidCdssTableName(ok), ok);
      }
    });

    test('rejects path/SQL-shaping values', () {
      for (final bad in [
        '',
        'users/other_uid',
        'a b',
        'A_Upper',
        'rows; DROP TABLE x',
        '../escape',
        'name#frag',
      ]) {
        expect(
          () => requireValidCdssTableName(bad),
          throwsArgumentError,
          reason: '"$bad" must be rejected',
        );
      }
    });
  });

  group('fetch-client URL hygiene', () {
    test(
      'unknown destinations and credential queries are blocked pre-transport',
      () async {
        var sends = 0;
        final client = HttpSourceFetchClient(
          client: MockClient((_) async {
            sends++;
            return http.Response('unexpected', 200);
          }),
        );

        for (final url in [
          'https://api.nal.usda.gov.attacker.test/fdc/v1/food/12345?token=SECRET',
          'https://api.nal.usda.gov/fdc/v1/food/12345?api_key=SECRET',
        ]) {
          try {
            await client.getText(url);
            fail('expected a StateError');
          } on StateError catch (e) {
            expect(e.message, contains('network_egress_denied'));
            expect(e.message, isNot(contains('SECRET')));
          }
        }

        expect(sends, 0);
      },
    );

    test('HTTP error messages omit the query string', () async {
      final client = HttpSourceFetchClient(
        client: MockClient((_) async => http.Response('nope', 500)),
      );
      try {
        await client.getText(
          'https://dailymed.nlm.nih.gov/dailymed/services/v2/spls.json?pagesize=1&x=SECRET123',
        );
        fail('expected a StateError');
      } on StateError catch (e) {
        expect(e.message, isNot(contains('SECRET123')));
        expect(
          e.message,
          contains(
            'https://dailymed.nlm.nih.gov/dailymed/services/v2/spls.json',
          ),
        );
      }
    });

    test('non-HTTPS rejection message omits the query string', () async {
      final client = HttpSourceFetchClient(
        client: MockClient((_) async => http.Response('ok', 200)),
      );
      try {
        await client.getText(
          'http://api.nal.usda.gov/fdc/v1/food/12345?token=SECRET456',
        );
        fail('expected a StateError');
      } on StateError catch (e) {
        expect(e.message, isNot(contains('SECRET456')));
        expect(e.message, contains('network_egress_denied'));
      }
    });

    test('oversized responses fail without echoing the query', () async {
      final client = HttpSourceFetchClient(
        client: MockClient((_) async => http.Response('x' * 64, 200)),
        responseByteLimit: 16,
      );
      try {
        await client.getText(
          'https://dailymed.nlm.nih.gov/dailymed/services/v2/spls.json?pagesize=1&x=SECRET789',
        );
        fail('expected a StateError');
      } on StateError catch (e) {
        expect(e.message, isNot(contains('SECRET789')));
      }
    });
  });

  group('FDC API key handling', () {
    test('key is sent as X-Api-Key header, never in the URL', () async {
      Uri? seenUri;
      Map<String, String>? seenHeaders;
      final client = HttpSourceFetchClient(
        client: MockClient((request) async {
          seenUri = request.url;
          seenHeaders = request.headers;
          return http.Response('{"fdcId": 1, "description": "demo"}', 200);
        }),
      );
      final importer = FdcP0Importer(fetchClient: client);
      await importer.fetchFoodDetail(apiKey: 'DEMO_KEY_NOT_REAL', fdcId: 12345);

      expect(seenUri, isNotNull);
      expect(seenUri!.toString(), isNot(contains('DEMO_KEY_NOT_REAL')));
      expect(seenUri!.query, isEmpty);
      expect(seenHeaders!['X-Api-Key'], 'DEMO_KEY_NOT_REAL');
    });
  });
}
