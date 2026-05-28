import 'dart:convert';

import 'package:http/http.dart' as http;

/// 统一的抓取接口：
/// - 测试时可以替换成内存 fake；
/// - 生产时默认走 HTTP。
abstract class SourceFetchClient {
  Future<String> getText(String url, {Map<String, String>? headers});
  Future<List<int>> getBytes(String url, {Map<String, String>? headers});
  Future<Map<String, dynamic>> getJsonMap(
    String url, {
    Map<String, String>? headers,
  });
  Future<List<dynamic>> getJsonList(
    String url, {
    Map<String, String>? headers,
  });

  /// Optional cache-coordination metadata for the most recent fetch of [url].
  ///
  /// Importers/orchestrator persist this in resume notes so a future run can
  /// short-circuit re-fetching when the upstream resource has not changed.
  /// Implementations that don't support cache validators should return an
  /// empty map.
  Map<String, String> lastFetchMetadata(String url) => const <String, String>{};
}

class HttpSourceFetchClient implements SourceFetchClient {
  final http.Client _client;
  final Map<String, Map<String, String>> _lastMetadata =
      <String, Map<String, String>>{};

  HttpSourceFetchClient({http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<String> getText(String url, {Map<String, String>? headers}) async {
    final response = await _client.get(Uri.parse(url), headers: headers);
    _ensureSuccess(response, url);
    _captureMetadata(url, response);
    return response.body;
  }

  @override
  Future<List<int>> getBytes(String url, {Map<String, String>? headers}) async {
    final response = await _client.get(Uri.parse(url), headers: headers);
    _ensureSuccess(response, url);
    _captureMetadata(url, response);
    return response.bodyBytes;
  }

  void _captureMetadata(String url, http.Response response) {
    final metadata = <String, String>{};
    final etag = response.headers['etag'];
    final lastModified = response.headers['last-modified'];
    if (etag != null && etag.isNotEmpty) metadata['etag'] = etag;
    if (lastModified != null && lastModified.isNotEmpty) {
      metadata['last_modified'] = lastModified;
    }
    if (metadata.isNotEmpty) {
      _lastMetadata[url] = metadata;
    }
  }

  @override
  Map<String, String> lastFetchMetadata(String url) =>
      _lastMetadata[url] ?? const <String, String>{};

  @override
  Future<Map<String, dynamic>> getJsonMap(
    String url, {
    Map<String, String>? headers,
  }) async {
    final text = await getText(url, headers: headers);
    return jsonDecode(text) as Map<String, dynamic>;
  }

  @override
  Future<List<dynamic>> getJsonList(
    String url, {
    Map<String, String>? headers,
  }) async {
    final text = await getText(url, headers: headers);
    return jsonDecode(text) as List<dynamic>;
  }

  void _ensureSuccess(http.Response response, String url) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Failed to fetch $url: HTTP ${response.statusCode}',
      );
    }
  }
}

/// 测试用 fake client。
class FakeSourceFetchClient implements SourceFetchClient {
  final Map<String, String> textByUrl;
  final Map<String, Map<String, String>> metadataByUrl;

  const FakeSourceFetchClient({
    required this.textByUrl,
    this.metadataByUrl = const <String, Map<String, String>>{},
  });

  @override
  Map<String, String> lastFetchMetadata(String url) =>
      metadataByUrl[url] ?? const <String, String>{};

  @override
  Future<List<int>> getBytes(String url, {Map<String, String>? headers}) async {
    final text = textByUrl[url];
    if (text == null) {
      throw StateError('Missing fake payload for $url');
    }
    return utf8.encode(text);
  }

  @override
  Future<Map<String, dynamic>> getJsonMap(
    String url, {
    Map<String, String>? headers,
  }) async {
    final text = await getText(url, headers: headers);
    return jsonDecode(text) as Map<String, dynamic>;
  }

  @override
  Future<List<dynamic>> getJsonList(
    String url, {
    Map<String, String>? headers,
  }) async {
    final text = await getText(url, headers: headers);
    return jsonDecode(text) as List<dynamic>;
  }

  @override
  Future<String> getText(String url, {Map<String, String>? headers}) async {
    final text = textByUrl[url];
    if (text == null) {
      throw StateError('Missing fake payload for $url');
    }
    return text;
  }
}

/// Structured result of a source fetch, used by importer adapters that want
/// explicit success/failure metadata rather than thrown exceptions. A failed
/// fetch yields `ok == false` with `error` set and `rawPayload == null`, so
/// callers must NOT synthesize a parsed fact from a failure.
class SourceFetchResult {
  final String sourceSystem;
  final String requestedId;
  final DateTime fetchedAt;
  final int
      status; // HTTP-like status; 0 = not attempted, 200 = ok, 404 = missing
  final String? contentType;
  final String? rawPayload;
  final String? error;

  const SourceFetchResult({
    required this.sourceSystem,
    required this.requestedId,
    required this.fetchedAt,
    required this.status,
    required this.contentType,
    required this.rawPayload,
    required this.error,
  });

  bool get ok => error == null && rawPayload != null && status == 200;

  Map<String, dynamic> toJson() => {
        'source_system': sourceSystem,
        'requested_id': requestedId,
        'fetched_at': fetchedAt.toIso8601String(),
        'status': status,
        'content_type': contentType,
        'raw_payload': rawPayload,
        'error': error,
      };
}

/// Deterministic, offline fixture fetch client. Resolves an in-memory map of
/// id -> payload string and returns a [SourceFetchResult]. A missing id
/// produces an explicit failure result (no exception, no fake payload). Used
/// by unit tests; never performs network I/O.
class FixtureSourceFetchClient {
  final String sourceSystem;
  final Map<String, String> payloadsById;
  final String contentType;
  final DateTime Function() clock;

  FixtureSourceFetchClient({
    required this.sourceSystem,
    required this.payloadsById,
    this.contentType = 'application/json',
    DateTime Function()? clock,
  }) : clock = clock ?? (() => DateTime.utc(2026, 1, 1));

  SourceFetchResult fetch(String requestedId) {
    final payload = payloadsById[requestedId];
    if (payload == null) {
      return SourceFetchResult(
        sourceSystem: sourceSystem,
        requestedId: requestedId,
        fetchedAt: clock(),
        status: 404,
        contentType: null,
        rawPayload: null,
        error: 'fixture_not_found:$requestedId',
      );
    }
    return SourceFetchResult(
      sourceSystem: sourceSystem,
      requestedId: requestedId,
      fetchedAt: clock(),
      status: 200,
      contentType: contentType,
      rawPayload: payload,
      error: null,
    );
  }
}

/// Optional live fetch client. DISABLED by default. It does NOT perform any
/// network I/O unless `enabled` is true, and it is never enabled in unit
/// tests. It returns a [SourceFetchResult] and only retrieves official
/// metadata payloads — never clinical advice. Non-200 responses and network
/// errors become explicit failure results; they never synthesize a fact.
///
/// The actual transport is injected as `fetcher` so tests can exercise the
/// success/failure/skip paths with a fake (no real network). In production a
/// caller may pass a function that delegates to `HttpSourceFetchClient`.
class LiveSourceFetchClient {
  final String sourceSystem;
  final bool enabled;
  final Duration timeout;

  /// Returns a `(status, contentType, payload)` tuple for [url], or throws to
  /// signal a transport error. Injected so tests never touch the network.
  final Future<({int status, String? contentType, String? payload})> Function(
    String url, {
    Duration timeout,
  }) fetcher;

  final DateTime Function() clock;

  LiveSourceFetchClient({
    required this.sourceSystem,
    required this.enabled,
    required this.fetcher,
    this.timeout = const Duration(seconds: 15),
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  /// Whether the opt-in env var is set. Used by the smoke tool; the client
  /// itself takes `enabled` explicitly so tests stay deterministic.
  static bool envEnabled(Map<String, String> environment) =>
      environment['PARKINSUM_ENABLE_LIVE_SOURCE_SMOKE'] == '1';

  Future<SourceFetchResult> fetch(String url) async {
    final now = clock();
    if (!enabled) {
      return SourceFetchResult(
        sourceSystem: sourceSystem,
        requestedId: url,
        fetchedAt: now,
        status: 0, // 0 = not attempted (live fetch disabled)
        contentType: null,
        rawPayload: null,
        error: 'live_fetch_disabled',
      );
    }
    try {
      final r = await fetcher(url, timeout: timeout);
      if (r.status != 200 || r.payload == null) {
        return SourceFetchResult(
          sourceSystem: sourceSystem,
          requestedId: url,
          fetchedAt: clock(),
          status: r.status,
          contentType: r.contentType,
          rawPayload: null,
          error: 'non_success_status:${r.status}',
        );
      }
      return SourceFetchResult(
        sourceSystem: sourceSystem,
        requestedId: url,
        fetchedAt: clock(),
        status: 200,
        contentType: r.contentType,
        rawPayload: r.payload,
        error: null,
      );
    } catch (e) {
      return SourceFetchResult(
        sourceSystem: sourceSystem,
        requestedId: url,
        fetchedAt: clock(),
        status: -1,
        contentType: null,
        rawPayload: null,
        error: 'transport_error',
      );
    }
  }
}
