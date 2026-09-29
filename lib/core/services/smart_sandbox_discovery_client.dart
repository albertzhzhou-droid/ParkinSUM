import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'runtime_network_egress_policy.dart';

/// Bounded result from one live SMART discovery response.
/// Endpoint values and unrecognized server metadata are never retained.
final class SmartSandboxDiscoveryReport {
  const SmartSandboxDiscoveryReport({
    required this.status200,
    required this.jsonContentType,
    required this.authorizationEndpointOnSandbox,
    required this.tokenEndpointOnSandbox,
    required this.standaloneLaunchAdvertised,
    required this.publicClientAdvertised,
    required this.pkceS256Advertised,
    required this.pkcePlainAdvertised,
    required this.observationReadScopeAdvertised,
    required this.authorizationCodeGrantAdvertised,
    required this.authorizationCodeResponseTypeAdvertised,
    required this.standalonePatientContextAdvertised,
    required this.patientPermissionAdvertised,
    required this.permissionV2Advertised,
  });

  final bool status200;
  final bool jsonContentType;
  final bool authorizationEndpointOnSandbox;
  final bool tokenEndpointOnSandbox;
  final bool standaloneLaunchAdvertised;
  final bool publicClientAdvertised;
  final bool pkceS256Advertised;
  final bool pkcePlainAdvertised;
  final bool observationReadScopeAdvertised;
  final bool authorizationCodeGrantAdvertised;
  final bool? authorizationCodeResponseTypeAdvertised;
  final bool standalonePatientContextAdvertised;
  final bool patientPermissionAdvertised;
  final bool permissionV2Advertised;
}

final class SmartSandboxDiscoveryException implements Exception {
  const SmartSandboxDiscoveryException(this.code);

  final String code;

  @override
  String toString() => 'SmartSandboxDiscoveryException($code)';
}

/// Reads only the fixed public SMART Health IT FHIR R4 discovery endpoint.
/// This client does not authorize, navigate to OAuth, or fetch FHIR resources.
final class SmartSandboxDiscoveryClient {
  SmartSandboxDiscoveryClient({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  static const fhirBaseUrl = 'https://launch.smarthealthit.org/v/r4/fhir';
  static const discoveryUrl = '$fhirBaseUrl/.well-known/smart-configuration';
  static const maxResponseBytes = 64 * 1024;
  static const _requestTimeout = Duration(seconds: 8);

  final http.Client _client;
  final bool _ownsClient;

  Future<SmartSandboxDiscoveryReport> discover() async {
    if (!kDebugMode) {
      throw const SmartSandboxDiscoveryException('debug_build_required');
    }
    final uri = Uri.parse(discoveryUrl);
    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..maxRedirects = 0
      ..headers['Accept'] = 'application/json';
    final decision = RuntimeNetworkEgressPolicy.smartSandboxDiscovery.evaluate(
      uri: uri,
      method: request.method,
      purpose: RuntimeNetworkEgressPurpose.smartSandboxDiscovery,
      dataClasses: const {RuntimeNetworkDataClass.publicSandboxMetadata},
      headers: request.headers,
      requestBodyBytes: request.bodyBytes.length,
      followsRedirects: request.followRedirects,
    );
    if (!decision.allowed) {
      throw SmartSandboxDiscoveryException(decision.reasonCode);
    }

    late final http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(_requestTimeout);
    } on TimeoutException {
      throw const SmartSandboxDiscoveryException('request_timeout');
    } on Object {
      throw const SmartSandboxDiscoveryException('request_failed');
    }
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw const SmartSandboxDiscoveryException('http_status_rejected');
    }
    final contentType = response.headers['content-type'];
    if (contentType == null || !_isJsonContentType(contentType)) {
      await response.stream.drain<void>();
      throw const SmartSandboxDiscoveryException('content_type_rejected');
    }

    final bytes = BytesBuilder(copy: false);
    try {
      await for (final chunk in response.stream.timeout(_requestTimeout)) {
        if (bytes.length + chunk.length > maxResponseBytes) {
          throw const SmartSandboxDiscoveryException('response_too_large');
        }
        bytes.add(chunk);
      }
    } on TimeoutException {
      throw const SmartSandboxDiscoveryException('response_timeout');
    } on SmartSandboxDiscoveryException {
      rethrow;
    } on Object {
      throw const SmartSandboxDiscoveryException('response_read_failed');
    }

    late final Object? decoded;
    try {
      decoded = jsonDecode(
        utf8.decode(bytes.takeBytes(), allowMalformed: false),
      );
    } on Object {
      throw const SmartSandboxDiscoveryException('invalid_json');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const SmartSandboxDiscoveryException('metadata_not_object');
    }

    final capabilities = _stringSet(decoded['capabilities'], 'capabilities');
    final grants = _stringSet(
      decoded['grant_types_supported'],
      'grant_types_supported',
    );
    final authorizationEndpoint = _sandboxEndpoint(
      decoded['authorization_endpoint'],
      present: decoded.containsKey('authorization_endpoint'),
      required:
          grants.contains('authorization_code') ||
          capabilities.contains('launch-ehr') ||
          capabilities.contains('launch-standalone'),
    );
    final tokenEndpoint = _sandboxEndpoint(decoded['token_endpoint']);
    final pkceMethods = _stringSet(
      decoded['code_challenge_methods_supported'],
      'code_challenge_methods_supported',
    );
    final scopes = _optionalStringSet(decoded, 'scopes_supported');
    final responseTypes = _optionalStringSet(
      decoded,
      'response_types_supported',
    );

    return SmartSandboxDiscoveryReport(
      status200: true,
      jsonContentType: true,
      authorizationEndpointOnSandbox: authorizationEndpoint,
      tokenEndpointOnSandbox: tokenEndpoint,
      standaloneLaunchAdvertised: capabilities.contains('launch-standalone'),
      publicClientAdvertised: capabilities.contains('client-public'),
      pkceS256Advertised: pkceMethods.contains('S256'),
      pkcePlainAdvertised: pkceMethods.contains('plain'),
      observationReadScopeAdvertised:
          scopes?.contains('patient/Observation.rs') ?? false,
      authorizationCodeGrantAdvertised: grants.contains('authorization_code'),
      authorizationCodeResponseTypeAdvertised: responseTypes?.contains('code'),
      standalonePatientContextAdvertised: capabilities.contains(
        'context-standalone-patient',
      ),
      patientPermissionAdvertised: capabilities.contains('permission-patient'),
      permissionV2Advertised: capabilities.contains('permission-v2'),
    );
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  static bool _isJsonContentType(String value) =>
      value.split(';').first.trim().toLowerCase() == 'application/json';

  static bool _sandboxEndpoint(
    Object? value, {
    bool required = true,
    bool present = true,
  }) {
    if (!present && !required) return false;
    if (value is! String || value.length > 2048) {
      throw const SmartSandboxDiscoveryException('endpoint_invalid');
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'launch.smarthealthit.org' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path.isEmpty ||
        uri.normalizePath().path != uri.path) {
      throw const SmartSandboxDiscoveryException('endpoint_outside_sandbox');
    }
    return true;
  }

  static Set<String> _stringSet(Object? value, String field) {
    if (value is! List<dynamic> ||
        value.length > 256 ||
        value.any(
          (entry) =>
              entry is! String ||
              entry.isEmpty ||
              entry.length > 512 ||
              entry.trim() != entry,
        )) {
      throw SmartSandboxDiscoveryException('metadata_field_invalid_$field');
    }
    final values = value.cast<String>();
    if (values.toSet().length != values.length) {
      throw SmartSandboxDiscoveryException('metadata_field_duplicate_$field');
    }
    return values.toSet();
  }

  static Set<String>? _optionalStringSet(
    Map<String, dynamic> metadata,
    String field,
  ) {
    if (!metadata.containsKey(field)) return null;
    return _stringSet(metadata[field], field);
  }
}
