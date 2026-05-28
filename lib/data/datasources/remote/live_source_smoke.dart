import 'source_fetch_client.dart';

/// Redacted, shape-only result of a live source smoke run. Never contains raw
/// payloads — only status, content type, byte length, and a parse-shape flag.
class LiveSmokeSummary {
  final String source;
  final bool enabled;
  final int status;
  final String? contentType;
  final int payloadBytes;
  final bool parseShapeOk;
  final String? error;

  const LiveSmokeSummary({
    required this.source,
    required this.enabled,
    required this.status,
    required this.contentType,
    required this.payloadBytes,
    required this.parseShapeOk,
    required this.error,
  });

  bool get ok => !enabled || (status == 200 && parseShapeOk && error == null);

  /// Skipped (opt-in not enabled) summary. No network.
  factory LiveSmokeSummary.skipped(String source) => LiveSmokeSummary(
        source: source,
        enabled: false,
        status: 0,
        contentType: null,
        payloadBytes: 0,
        parseShapeOk: false,
        error: 'live_smoke_disabled',
      );

  String toRedactedString() {
    if (!enabled) {
      return 'Live source smoke ($source): SKIPPED (opt-in disabled). '
          'No network contacted.';
    }
    return 'Live source smoke ($source): status=$status '
        'contentType=$contentType bytes=$payloadBytes parseShapeOk=$parseShapeOk '
        '${error == null ? 'ok' : 'error=$error'}. '
        'Shape-only summary; raw payload not stored. Official metadata only — '
        'no clinical advice fetched.';
  }
}

/// Known small public *metadata* endpoints per source. Official metadata only.
/// These are not invoked unless the smoke is explicitly enabled at runtime.
const Map<String, String> liveSmokeMetadataUrls = {
  // DailyMed SPL service base (metadata listing endpoint).
  'dailymed':
      'https://dailymed.nlm.nih.gov/dailymed/services/v2/spls.json?pagesize=1',
  // USDA FoodData Central requires an API key; without one the smoke must
  // skip rather than embed a secret.
  'fdc': 'https://api.nal.usda.gov/fdc/v1/foods/list',
};

/// Runs the live smoke. When `enabled` is false, returns a skipped summary
/// and performs NO network I/O. When enabled, uses [client] (defaults to the
/// real HTTP client) to fetch a small official metadata payload and reports a
/// redacted shape summary. Never writes payloads anywhere.
Future<LiveSmokeSummary> runLiveSourceSmoke({
  required String source,
  required bool enabled,
  SourceFetchClient? client,
}) async {
  if (!enabled) return LiveSmokeSummary.skipped(source);

  final url = liveSmokeMetadataUrls[source];
  if (url == null) {
    return LiveSmokeSummary(
      source: source,
      enabled: true,
      status: -1,
      contentType: null,
      payloadBytes: 0,
      parseShapeOk: false,
      error: 'unknown_source:$source',
    );
  }
  // FDC needs an API key; refuse to proceed without one rather than embed a
  // secret. This keeps the smoke secret-free by default.
  if (source == 'fdc') {
    return LiveSmokeSummary(
      source: source,
      enabled: true,
      status: 0,
      contentType: null,
      payloadBytes: 0,
      parseShapeOk: false,
      error: 'requires_api_key_not_supplied',
    );
  }

  final fetch = client ?? HttpSourceFetchClient();
  try {
    final text = await fetch.getText(url);
    return LiveSmokeSummary(
      source: source,
      enabled: true,
      status: 200,
      contentType: 'application/json',
      payloadBytes: text.length,
      parseShapeOk:
          text.trimLeft().startsWith('{') || text.trimLeft().startsWith('['),
      error: null,
    );
  } catch (_) {
    return const LiveSmokeSummary(
      source: 'dailymed',
      enabled: true,
      status: -1,
      contentType: null,
      payloadBytes: 0,
      parseShapeOk: false,
      error: 'transport_error',
    );
  }
}
