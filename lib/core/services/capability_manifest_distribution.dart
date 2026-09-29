import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'runtime_network_egress_policy.dart';

const capabilityManifestDistributionMaxBytes = 64 * 1024;

enum CapabilityManifestFetchStatus {
  configured,
  fetched,
  notModified,
  unconfigured,
  invalidConfiguration,
  redirectRejected,
  httpRejected,
  contentTypeRejected,
  responseTooLarge,
  protocolRejected,
  timeout,
  transportFailed,
}

final class CapabilityManifestDistributionPolicy {
  CapabilityManifestDistributionPolicy._({
    required this.endpoint,
    required this.allowedHosts,
    required this.configurationStatus,
    required this.configurationReason,
    required this.timeout,
    required this.maxResponseBytes,
  });

  final Uri? endpoint;
  final Set<String> allowedHosts;
  final CapabilityManifestFetchStatus configurationStatus;
  final String configurationReason;
  final Duration timeout;
  final int maxResponseBytes;

  bool get isConfigured =>
      configurationStatus == CapabilityManifestFetchStatus.configured &&
      endpoint != null;

  String? get safeEndpointLabel {
    final value = endpoint;
    if (value == null) return null;
    return '${value.scheme}://${value.host}${value.path}';
  }

  factory CapabilityManifestDistributionPolicy.fromConfiguration({
    required String endpointUrl,
    required String allowedHostsCsv,
    Uri? runtimeOrigin,
    Duration timeout = const Duration(seconds: 10),
    int maxResponseBytes = capabilityManifestDistributionMaxBytes,
  }) {
    if (timeout <= Duration.zero ||
        maxResponseBytes <= 0 ||
        maxResponseBytes > capabilityManifestDistributionMaxBytes) {
      return CapabilityManifestDistributionPolicy._(
        endpoint: null,
        allowedHosts: const <String>{},
        configurationStatus: CapabilityManifestFetchStatus.invalidConfiguration,
        configurationReason: 'distribution_limits_invalid',
        timeout: timeout,
        maxResponseBytes: maxResponseBytes,
      );
    }
    final rawEndpoint = endpointUrl.trim();
    final rawAllowedHosts = allowedHostsCsv.trim();
    if (rawEndpoint.isEmpty && rawAllowedHosts.isEmpty) {
      return CapabilityManifestDistributionPolicy._(
        endpoint: null,
        allowedHosts: const <String>{},
        configurationStatus: CapabilityManifestFetchStatus.unconfigured,
        configurationReason: 'distribution_endpoint_not_configured',
        timeout: timeout,
        maxResponseBytes: maxResponseBytes,
      );
    }
    final allowedHosts = rawAllowedHosts
        .split(',')
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    final endpoint = Uri.tryParse(rawEndpoint);
    if (endpoint == null ||
        !_isSafeEndpoint(endpoint) ||
        allowedHosts.length != 1 ||
        allowedHosts.any((host) => !_isSafePublicDnsName(host)) ||
        !allowedHosts.contains(endpoint.host.toLowerCase()) ||
        _isSameWebOriginHost(endpoint, runtimeOrigin)) {
      return CapabilityManifestDistributionPolicy._(
        endpoint: null,
        allowedHosts: Set<String>.unmodifiable(allowedHosts),
        configurationStatus: CapabilityManifestFetchStatus.invalidConfiguration,
        configurationReason: 'distribution_endpoint_or_allowlist_invalid',
        timeout: timeout,
        maxResponseBytes: maxResponseBytes,
      );
    }
    return CapabilityManifestDistributionPolicy._(
      endpoint: endpoint,
      allowedHosts: Set<String>.unmodifiable(allowedHosts),
      configurationStatus: CapabilityManifestFetchStatus.configured,
      configurationReason: 'distribution_endpoint_configured',
      timeout: timeout,
      maxResponseBytes: maxResponseBytes,
    );
  }
}

bool _isSameWebOriginHost(Uri endpoint, Uri? runtimeOrigin) {
  if (runtimeOrigin == null ||
      (runtimeOrigin.scheme != 'http' && runtimeOrigin.scheme != 'https')) {
    return false;
  }
  return runtimeOrigin.host.toLowerCase() == endpoint.host.toLowerCase();
}

final class CapabilityManifestFetchResult {
  const CapabilityManifestFetchResult({
    required this.status,
    required this.reason,
    required this.endpointLabel,
    this.body,
    this.etag,
    this.httpStatus,
    this.byteCount,
  });

  final CapabilityManifestFetchStatus status;
  final String reason;
  final String? endpointLabel;
  final String? body;
  final String? etag;
  final int? httpStatus;
  final int? byteCount;

  bool get hasCandidate =>
      status == CapabilityManifestFetchStatus.fetched && body != null;
}

final class CapabilityManifestDistributionClient {
  CapabilityManifestDistributionClient({
    required this.policy,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final CapabilityManifestDistributionPolicy policy;
  final http.Client _client;
  String? _acceptedEtag;

  String? get acceptedEtag => _acceptedEtag;

  bool restoreAcceptedValidator({
    required String endpointLabel,
    required String etag,
  }) {
    _acceptedEtag = null;
    if (endpointLabel != policy.safeEndpointLabel ||
        !isCapabilityManifestContentEtag(etag)) {
      return false;
    }
    _acceptedEtag = etag;
    return true;
  }

  void commitFetchedValidator(CapabilityManifestFetchResult result) {
    final etag = result.etag;
    if (result.status != CapabilityManifestFetchStatus.fetched ||
        result.endpointLabel != policy.safeEndpointLabel ||
        etag == null ||
        !isCapabilityManifestContentEtag(etag)) {
      throw StateError('distribution_validator_not_verified');
    }
    _acceptedEtag = etag;
  }

  void clearAcceptedValidator() => _acceptedEtag = null;

  Future<CapabilityManifestFetchResult> fetch() async {
    if (!policy.isConfigured) {
      return CapabilityManifestFetchResult(
        status: policy.configurationStatus,
        reason: policy.configurationReason,
        endpointLabel: policy.safeEndpointLabel,
      );
    }
    final endpoint = policy.endpoint!;
    final request = http.Request('GET', endpoint)
      ..followRedirects = false
      ..maxRedirects = 0
      ..headers['accept'] = 'application/json';
    final etag = _acceptedEtag;
    if (etag != null) request.headers['if-none-match'] = etag;
    final egressPolicy = RuntimeNetworkEgressPolicy.capabilityManifestEndpoint(
      endpoint: endpoint,
      allowedHosts: policy.allowedHosts,
    );
    final egressDecision = egressPolicy.evaluate(
      uri: endpoint,
      method: request.method,
      purpose: RuntimeNetworkEgressPurpose.signedCapabilityManifestFetch,
      dataClasses: const {RuntimeNetworkDataClass.publicCapabilityValidator},
      headers: request.headers,
      requestBodyBytes: request.bodyBytes.length,
      followsRedirects: request.followRedirects,
    );
    if (!egressDecision.allowed) {
      return _failure(
        CapabilityManifestFetchStatus.protocolRejected,
        'distribution_egress_denied_${egressDecision.reasonCode}',
      );
    }

    final elapsed = Stopwatch()..start();
    try {
      final response = await _client
          .send(request)
          .timeout(_remaining(policy.timeout, elapsed));
      if (response.statusCode == 304) {
        await _cancel(response.stream);
        final responseEtag = response.headers['etag'];
        if (etag == null ||
            (responseEtag != null &&
                (!_isSafeEtag(responseEtag) || responseEtag != etag))) {
          return _failure(
            CapabilityManifestFetchStatus.protocolRejected,
            'distribution_304_without_matching_etag',
            httpStatus: response.statusCode,
          );
        }
        return CapabilityManifestFetchResult(
          status: CapabilityManifestFetchStatus.notModified,
          reason: 'distribution_not_modified',
          endpointLabel: policy.safeEndpointLabel,
          etag: etag,
          httpStatus: response.statusCode,
          byteCount: 0,
        );
      }
      if (response.statusCode >= 300 && response.statusCode < 400) {
        await _cancel(response.stream);
        return _failure(
          CapabilityManifestFetchStatus.redirectRejected,
          'distribution_redirect_rejected',
          httpStatus: response.statusCode,
        );
      }
      if (response.statusCode != 200) {
        await _cancel(response.stream);
        return _failure(
          CapabilityManifestFetchStatus.httpRejected,
          'distribution_http_status_rejected',
          httpStatus: response.statusCode,
        );
      }
      final contentType = response.headers['content-type'];
      if (!_isJsonContentType(contentType)) {
        await _cancel(response.stream);
        return _failure(
          CapabilityManifestFetchStatus.contentTypeRejected,
          'distribution_content_type_rejected',
          httpStatus: response.statusCode,
        );
      }
      final declaredLength = response.contentLength;
      if (declaredLength != null && declaredLength > policy.maxResponseBytes) {
        await _cancel(response.stream);
        return _failure(
          CapabilityManifestFetchStatus.responseTooLarge,
          'distribution_declared_length_exceeded',
          httpStatus: response.statusCode,
        );
      }
      final bytes = await _readBounded(
        response.stream,
        timeout: _remaining(policy.timeout, elapsed),
      );
      final responseEtag = response.headers['etag'];
      final contentDigest = sha256.convert(bytes).toString();
      final expectedEtag = '"$contentDigest"';
      if (responseEtag == null ||
          !isCapabilityManifestContentEtag(responseEtag) ||
          responseEtag != expectedEtag) {
        return _failure(
          CapabilityManifestFetchStatus.protocolRejected,
          'distribution_content_etag_mismatch',
          httpStatus: response.statusCode,
        );
      }
      final body = utf8.decode(bytes, allowMalformed: false);
      return CapabilityManifestFetchResult(
        status: CapabilityManifestFetchStatus.fetched,
        reason: 'distribution_candidate_fetched',
        endpointLabel: policy.safeEndpointLabel,
        body: body,
        etag: responseEtag,
        httpStatus: response.statusCode,
        byteCount: bytes.length,
      );
    } on TimeoutException {
      return _failure(
        CapabilityManifestFetchStatus.timeout,
        'distribution_timeout',
      );
    } on _CapabilityDistributionException catch (error) {
      return _failure(error.status, error.reason);
    } on FormatException {
      return _failure(
        CapabilityManifestFetchStatus.protocolRejected,
        'distribution_utf8_invalid',
      );
    } catch (_) {
      return _failure(
        CapabilityManifestFetchStatus.transportFailed,
        'distribution_transport_failed',
      );
    }
  }

  Future<List<int>> _readBounded(
    Stream<List<int>> stream, {
    required Duration timeout,
  }) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream.timeout(timeout)) {
      if (bytes.length + chunk.length > policy.maxResponseBytes) {
        throw const _CapabilityDistributionException(
          CapabilityManifestFetchStatus.responseTooLarge,
          'distribution_stream_length_exceeded',
        );
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  CapabilityManifestFetchResult _failure(
    CapabilityManifestFetchStatus status,
    String reason, {
    int? httpStatus,
  }) => CapabilityManifestFetchResult(
    status: status,
    reason: reason,
    endpointLabel: policy.safeEndpointLabel,
    etag: _acceptedEtag,
    httpStatus: httpStatus,
  );
}

final class _CapabilityDistributionException implements Exception {
  const _CapabilityDistributionException(this.status, this.reason);

  final CapabilityManifestFetchStatus status;
  final String reason;
}

bool _isSafeEndpoint(Uri value) =>
    value.scheme == 'https' &&
    value.host.isNotEmpty &&
    value.port == 443 &&
    value.userInfo.isEmpty &&
    !value.hasQuery &&
    !value.hasFragment &&
    value.path.startsWith('/') &&
    _isSafePublicDnsName(value.host.toLowerCase());

bool _isSafePublicDnsName(String value) {
  if (value.length > 253 ||
      value == 'localhost' ||
      value.endsWith('.local') ||
      value.contains(':') ||
      RegExp(r'^\d+(?:\.\d+){3}$').hasMatch(value)) {
    return false;
  }
  return RegExp(
    r'^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$',
  ).hasMatch(value);
}

bool _isJsonContentType(String? value) {
  if (value == null) return false;
  final mediaType = value.split(';').first.trim().toLowerCase();
  return mediaType == 'application/json' ||
      (mediaType.startsWith('application/') && mediaType.endsWith('+json'));
}

bool _isSafeEtag(String value) =>
    value.length <= 256 && RegExp(r'^(?:W/)?"[!#-~]*"$').hasMatch(value);

bool isCapabilityManifestContentEtag(String value) =>
    RegExp(r'^"[a-f0-9]{64}"$').hasMatch(value);

Future<void> _cancel(Stream<List<int>> stream) async {
  final subscription = stream.listen(null);
  await subscription.cancel();
}

Duration _remaining(Duration budget, Stopwatch elapsed) {
  final remaining = budget - elapsed.elapsed;
  if (remaining <= Duration.zero) throw TimeoutException('time_budget_spent');
  return remaining;
}
