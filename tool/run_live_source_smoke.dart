// Opt-in live source-fetch smoke harness. DISABLED by default.
//
// Usage:
//   dart run tool/run_live_source_smoke.dart [--source=dailymed|fdc]
//
// Behavior:
// - Requires env PARKINSUM_ENABLE_LIVE_SOURCE_SMOKE=1. Without it, prints a
//   clear skip message and exits 0 (success). It performs NO network I/O.
// - Never requires secrets/API keys by default.
// - Only validates fetch *shape* + parser ability on a small known public
//   metadata query. It fetches official metadata only — never clinical advice.
// - Never writes raw payloads into the repo (prints a redacted shape summary).
//
// What it does NOT test: production ingestion, real-schema completeness,
// licensing/legal compliance, or clinical accuracy. Source-specific
// license/terms review remains required before any production use.

import 'dart:io';

import 'package:parkinsum_companion/data/datasources/remote/live_source_smoke.dart';

Future<void> main(List<String> args) async {
  final source = _argValue(args, '--source') ?? 'dailymed';
  final enabled =
      Platform.environment['PARKINSUM_ENABLE_LIVE_SOURCE_SMOKE'] == '1';

  if (!enabled) {
    stdout
      ..writeln('Live source smoke: SKIPPED (opt-in).')
      ..writeln('Set PARKINSUM_ENABLE_LIVE_SOURCE_SMOKE=1 to enable.')
      ..writeln('No network was contacted. Educational prototype; no clinical '
          'advice is ever fetched. Source license/terms review is still '
          'required before any production use.');
    exit(0);
  }

  // Enabled path: run the (network) smoke. Real transport lives here only.
  final summary = await runLiveSourceSmoke(
    source: source,
    enabled: true,
  );
  stdout.writeln(summary.toRedactedString());
  exit(summary.ok ? 0 : 1);
}

String? _argValue(List<String> args, String name) {
  for (final a in args) {
    if (a.startsWith('$name=')) return a.substring(name.length + 1);
  }
  return null;
}
