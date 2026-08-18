import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Committed expected-output goldens for the deterministic report generators.
///
/// Every determinism guard in this repo used to build an artifact **twice in
/// the same process** and compare the two strings. That proves self-
/// consistency, not stability: a change that alters every emitted row
/// identically passes all of them. And because `build/` is gitignored, nothing
/// in the repository recorded what the output *should* be — so the reviewer
/// artifact's own instruction to "diff against the committed report" named a
/// baseline that did not exist.
///
/// These goldens are that baseline. They live under `test/goldens/` and are
/// committed, so a behaviour change at commit N shows up as a reviewable diff
/// against commit N-1.
///
/// Refresh them deliberately, never casually:
///
/// ```bash
/// UPDATE_GOLDENS=1 flutter test test/goldens_test.dart
/// ```
///
/// Then read the resulting diff before committing it. A golden diff is the
/// signal; silently regenerating one discards exactly the information it
/// exists to preserve.
const String goldenDirPath = 'test/goldens';

/// True when goldens should be rewritten instead of asserted.
bool get updatingGoldens {
  final flag = Platform.environment['UPDATE_GOLDENS'];
  return flag == '1' || flag == 'true';
}

/// Asserts [actual] matches the committed golden named [name], or rewrites the
/// golden when `UPDATE_GOLDENS=1`.
///
/// A missing golden fails rather than being created silently — an absent
/// baseline must never read as a pass.
void expectGolden(String name, String actual) {
  final file = File('$goldenDirPath/$name');

  if (updatingGoldens) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(actual);
    return;
  }

  if (!file.existsSync()) {
    fail(
      'Missing golden `$goldenDirPath/$name`.\n'
      'An absent baseline is not a pass. Create it with:\n'
      '  UPDATE_GOLDENS=1 flutter test test/goldens_test.dart',
    );
  }

  final expected = file.readAsStringSync();
  if (expected == actual) return;

  fail(
    'Golden drift in `$goldenDirPath/$name`.\n'
    '${_describeFirstDifference(expected, actual)}\n'
    'This means generator, engine, gate, or scenario behaviour changed since '
    'the golden was committed. If the change is intended, review the diff and '
    'refresh with:\n'
    '  UPDATE_GOLDENS=1 flutter test test/goldens_test.dart',
  );
}

/// Points at the first differing line so a failure is actionable without
/// dumping an entire multi-kilobyte artifact into the test log.
String _describeFirstDifference(String expected, String actual) {
  final expectedLines = expected.split('\n');
  final actualLines = actual.split('\n');
  final shared = expectedLines.length < actualLines.length
      ? expectedLines.length
      : actualLines.length;

  for (var i = 0; i < shared; i++) {
    if (expectedLines[i] == actualLines[i]) continue;
    return 'First difference at line ${i + 1}:\n'
        '  committed: ${_truncate(expectedLines[i])}\n'
        '  generated: ${_truncate(actualLines[i])}';
  }
  return 'Line counts differ: committed ${expectedLines.length}, '
      'generated ${actualLines.length}.';
}

String _truncate(String value) =>
    value.length <= 160 ? value : '${value.substring(0, 160)}…';

/// Deterministic 32-bit FNV-1a digest, rendered as 8 lowercase hex chars.
///
/// Used where the full artifact is too large to commit as a readable diff (the
/// mechanistic replay JSON is ~900 KB). Hand-rolled rather than pulling in a
/// hashing package: FNV-1a is five lines, has no dependency, and — unlike
/// Dart's `Object.hashAll` — is stable across processes and SDK versions,
/// which is the whole requirement for a committed baseline.
///
/// This detects drift; it is not a security primitive and must never be used
/// as one.
String fnv1aHex(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    // 16777619, kept inside 32 bits.
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// Renders a per-row digest table for an artifact too large to golden whole.
///
/// Emitting one line per row rather than a single hash over everything is
/// deliberate: a drift diff then names the exact row that changed instead of
/// flipping one opaque value.
String digestTable({
  required List<Map<String, dynamic>> rows,
  required String Function(Map<String, dynamic> row) idOf,
  required String Function(Map<String, dynamic> row) canonicalOf,
}) {
  final buffer = StringBuffer()
    ..writeln('# Per-row digest (FNV-1a/32). Drift detection only.')
    ..writeln('# row_id\tdigest');
  for (final row in rows) {
    buffer.writeln('${idOf(row)}\t${fnv1aHex(canonicalOf(row))}');
  }
  buffer.writeln('# rows\t${rows.length}');
  return buffer.toString();
}
