import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parkinsum_companion/core/services/smart_sandbox_discovery_client.dart';

const _metadata = <String, Object?>{
  'authorization_endpoint':
      'https://launch.smarthealthit.org/v/r4/auth/authorize',
  'token_endpoint': 'https://launch.smarthealthit.org/v/r4/auth/token',
  'grant_types_supported': ['authorization_code'],
  'response_types_supported': ['code'],
  'capabilities': [
    'launch-standalone',
    'client-public',
    'context-standalone-patient',
    'permission-patient',
    'permission-v2',
  ],
  'code_challenge_methods_supported': ['S256'],
  'scopes_supported': ['launch/patient', 'patient/Observation.rs'],
  'sensitive_vendor_extension': 'must-not-escape-the-parser',
};

void main() {
  test(
    'sends one bounded bodyless request to the fixed discovery URL',
    () async {
      var requests = 0;
      final client = SmartSandboxDiscoveryClient(
        client: MockClient((request) async {
          requests++;
          expect(request.method, 'GET');
          expect(
            request.url.toString(),
            SmartSandboxDiscoveryClient.discoveryUrl,
          );
          expect(request.followRedirects, isFalse);
          expect(request.maxRedirects, 0);
          expect(request.headers, {'Accept': 'application/json'});
          expect(request.body, isEmpty);
          return http.Response(
            jsonEncode(_metadata),
            200,
            headers: {'content-type': 'Application/JSON; charset=utf-8'},
          );
        }),
      );

      final report = await client.discover();

      expect(requests, 1);
      expect(report.status200, isTrue);
      expect(report.jsonContentType, isTrue);
      expect(report.authorizationEndpointOnSandbox, isTrue);
      expect(report.tokenEndpointOnSandbox, isTrue);
      expect(report.standaloneLaunchAdvertised, isTrue);
      expect(report.publicClientAdvertised, isTrue);
      expect(report.pkceS256Advertised, isTrue);
      expect(report.pkcePlainAdvertised, isFalse);
      expect(report.observationReadScopeAdvertised, isTrue);
      expect(report.authorizationCodeGrantAdvertised, isTrue);
      expect(report.authorizationCodeResponseTypeAdvertised, isTrue);
      expect(report.standalonePatientContextAdvertised, isTrue);
      expect(report.patientPermissionAdvertised, isTrue);
      expect(report.permissionV2Advertised, isTrue);
      expect(report.toString(), isNot(contains('launch.smarthealthit.org')));
      expect(report.toString(), isNot(contains('must-not-escape')));
    },
  );

  test(
    'rejects non-200, redirects, and non-JSON responses without parsing bodies',
    () async {
      for (final response in [
        http.Response(
          'sensitive body',
          302,
          headers: {'location': 'https://other.test'},
        ),
        http.Response('sensitive body', 503),
        http.Response('{}', 200, headers: {'content-type': 'text/plain'}),
      ]) {
        final client = SmartSandboxDiscoveryClient(
          client: MockClient((_) async => response),
        );
        await expectLater(
          client.discover(),
          throwsA(isA<SmartSandboxDiscoveryException>()),
        );
      }
    },
  );

  test('rejects malformed, oversized, and non-object metadata', () async {
    for (final response in [
      http.Response('{', 200, headers: {'content-type': 'application/json'}),
      http.Response('[]', 200, headers: {'content-type': 'application/json'}),
      http.Response(
        'x' * (SmartSandboxDiscoveryClient.maxResponseBytes + 1),
        200,
        headers: {'content-type': 'application/json'},
      ),
    ]) {
      final client = SmartSandboxDiscoveryClient(
        client: MockClient((_) async => response),
      );
      await expectLater(
        client.discover(),
        throwsA(isA<SmartSandboxDiscoveryException>()),
      );
    }
  });

  test(
    'rejects discovered OAuth endpoints outside the fixed sandbox host',
    () async {
      final changed = Map<String, Object?>.of(_metadata)
        ..['token_endpoint'] = 'https://attacker.example/token';
      final client = SmartSandboxDiscoveryClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(changed),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      await expectLater(
        client.discover(),
        throwsA(
          isA<SmartSandboxDiscoveryException>().having(
            (error) => error.code,
            'code',
            'endpoint_outside_sandbox',
          ),
        ),
      );
    },
  );

  test(
    'reports missing optional read scope without promoting it to present',
    () async {
      final changed = Map<String, Object?>.of(_metadata)
        ..remove('scopes_supported');
      final client = SmartSandboxDiscoveryClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(changed),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      final report = await client.discover();
      expect(report.observationReadScopeAdvertised, isFalse);
      expect(report.authorizationCodeGrantAdvertised, isTrue);
    },
  );

  test(
    'requires the SMART discovery grant, capability, and PKCE arrays',
    () async {
      for (final field in [
        'grant_types_supported',
        'capabilities',
        'code_challenge_methods_supported',
      ]) {
        final changed = Map<String, Object?>.of(_metadata)..remove(field);
        final client = SmartSandboxDiscoveryClient(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode(changed),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        await expectLater(
          client.discover(),
          throwsA(
            isA<SmartSandboxDiscoveryException>().having(
              (error) => error.code,
              'code',
              'metadata_field_invalid_$field',
            ),
          ),
        );
      }
    },
  );

  test(
    'reports a nonconforming PKCE plain advertisement without hiding it',
    () async {
      final changed = Map<String, Object?>.of(_metadata)
        ..['code_challenge_methods_supported'] = ['S256', 'plain'];
      final client = SmartSandboxDiscoveryClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(changed),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      final report = await client.discover();
      expect(report.pkceS256Advertised, isTrue);
      expect(report.pkcePlainAdvertised, isTrue);
    },
  );

  test(
    'treats response types as optional but validates them when present',
    () async {
      final missing = Map<String, Object?>.of(_metadata)
        ..remove('response_types_supported');
      final absentClient = SmartSandboxDiscoveryClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(missing),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      expect(
        (await absentClient.discover()).authorizationCodeResponseTypeAdvertised,
        isNull,
      );

      final unsupported = Map<String, Object?>.of(_metadata)
        ..['response_types_supported'] = ['id_token'];
      final unsupportedClient = SmartSandboxDiscoveryClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(unsupported),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      expect(
        (await unsupportedClient.discover())
            .authorizationCodeResponseTypeAdvertised,
        isFalse,
      );

      final malformed = Map<String, Object?>.of(_metadata)
        ..['response_types_supported'] = ['code', 'code'];
      final malformedClient = SmartSandboxDiscoveryClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(malformed),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      await expectLater(
        malformedClient.discover(),
        throwsA(
          isA<SmartSandboxDiscoveryException>().having(
            (error) => error.code,
            'code',
            'metadata_field_duplicate_response_types_supported',
          ),
        ),
      );

      final explicitNull = Map<String, Object?>.of(_metadata)
        ..['response_types_supported'] = null;
      final nullClient = SmartSandboxDiscoveryClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(explicitNull),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      await expectLater(
        nullClient.discover(),
        throwsA(
          isA<SmartSandboxDiscoveryException>().having(
            (error) => error.code,
            'code',
            'metadata_field_invalid_response_types_supported',
          ),
        ),
      );
    },
  );

  test(
    'requires authorization endpoint only when authorization launch is supported',
    () async {
      final noAuthorization = Map<String, Object?>.of(_metadata)
        ..remove('authorization_endpoint')
        ..['grant_types_supported'] = ['client_credentials']
        ..['capabilities'] = ['client-public'];
      final client = SmartSandboxDiscoveryClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(noAuthorization),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      final report = await client.discover();
      expect(report.authorizationEndpointOnSandbox, isFalse);
      expect(report.authorizationCodeGrantAdvertised, isFalse);
      expect(report.standaloneLaunchAdvertised, isFalse);

      noAuthorization['authorization_endpoint'] = null;
      final nullEndpointClient = SmartSandboxDiscoveryClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(noAuthorization),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      await expectLater(
        nullEndpointClient.discover(),
        throwsA(
          isA<SmartSandboxDiscoveryException>().having(
            (error) => error.code,
            'code',
            'endpoint_invalid',
          ),
        ),
      );
    },
  );

  test(
    'requires an authorization endpoint for the standalone code flow',
    () async {
      final missing = Map<String, Object?>.of(_metadata)
        ..remove('authorization_endpoint');
      final client = SmartSandboxDiscoveryClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(missing),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      await expectLater(
        client.discover(),
        throwsA(
          isA<SmartSandboxDiscoveryException>().having(
            (error) => error.code,
            'code',
            'endpoint_invalid',
          ),
        ),
      );
    },
  );
}
