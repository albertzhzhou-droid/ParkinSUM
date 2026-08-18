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
    test('HTTP error messages omit the query string', () async {
      final client = HttpSourceFetchClient(
        client: MockClient((_) async => http.Response('nope', 500)),
      );
      try {
        await client.getText('https://example.org/data?api_key=SECRET123&x=1');
        fail('expected a StateError');
      } on StateError catch (e) {
        expect(e.message, isNot(contains('SECRET123')));
        expect(e.message, contains('https://example.org/data'));
      }
    });

    test('non-HTTPS rejection message omits the query string', () async {
      final client = HttpSourceFetchClient(
        client: MockClient((_) async => http.Response('ok', 200)),
      );
      try {
        await client.getText('http://example.org/data?token=SECRET456');
        fail('expected a StateError');
      } on StateError catch (e) {
        expect(e.message, isNot(contains('SECRET456')));
      }
    });

    test('oversized responses fail without echoing the query', () async {
      final client = HttpSourceFetchClient(
        client: MockClient((_) async => http.Response('x' * 64, 200)),
        responseByteLimit: 16,
      );
      try {
        await client.getText('https://example.org/big?api_key=SECRET789');
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
