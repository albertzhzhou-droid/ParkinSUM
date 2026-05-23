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
