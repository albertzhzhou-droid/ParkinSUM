// Runs the local privacy preflight over the repository working tree and writes a
// report under build/local_privacy_preflight/.
//
// Usage:
//   dart run tool/run_local_privacy_preflight.dart [--strict]
//
// Repo-hygiene / privacy-risk scanning that COMPLEMENTS `npm run public:preflight`
// (it does not replace it). No network. Skips .git, node_modules, generated dirs,
// binary + very large files, and this tool's own detector-definition files (a
// linter does not lint its own rules; those are reported as INFO skips). Exits
// non-zero iff a BLOCKER finding exists. Not HIPAA/GDPR/PIPEDA compliance, not a
// legal certification, not clinical validation, and does not prove security.

import 'dart:io';

import 'package:parkinsum_companion/domain/entities/local_privacy_preflight.dart';
import 'package:parkinsum_companion/domain/usecases/local_privacy_preflight.dart';

const int _maxScanBytes = 1024 * 1024; // 1 MiB

// Directories never descended into.
const List<String> _skipDirs = [
  '.git',
  'node_modules',
  'build',
  '.dart_tool',
  'coverage',
  '.firebase',
  'macos/Pods',
  'ios/Pods',
  'android/.gradle',
];

// Generated/local dirs reported (WARN) when present at the top level.
const List<String> _generatedDirsToReport = [
  'build',
  '.dart_tool',
  'coverage',
  'node_modules',
  '.firebase',
];

// The privacy tool's own detector-definition + test + doc files, plus other
// detector/test files that legitimately CONTAIN the patterns as definitions.
// A linter does not lint its own rules; these are skipped with an INFO note.
const List<String> _detectorDefinitionFiles = [
  'lib/domain/entities/local_privacy_preflight.dart',
  'lib/domain/usecases/local_privacy_preflight.dart',
  'tool/run_local_privacy_preflight.dart',
  'docs/LOCAL_PRIVACY_PREFLIGHT.md',
  'lib/domain/usecases/localization_safety_lint.dart',
  'test/localization_safety_lint_test.dart',
  'lib/domain/usecases/synthetic_scenario_fuzzer.dart',
  'test/synthetic_scenario_fuzzer_test.dart',
  'test/local_privacy_preflight_test.dart',
  'test/helpers/no_phi_json_assertions.dart',
  // Sibling secret/privacy scanners whose source legitimately contains the
  // detector patterns (e.g. `PRIVATE KEY-----`) as rule definitions.
  'tool/public_repo_preflight.mjs',
  'tool/backend_security_gate.mjs',
  // Sibling detector/governance tests whose fixtures deliberately contain
  // PHI-like / secret patterns to exercise other checkers' rules.
  'test/contribution_safety_router_test.dart',
  'lib/domain/usecases/contribution_safety_router.dart',
];

final RegExp _textFile = RegExp(
    r'\.(dart|md|json|ya?ml|txt|html|css|js|mjs|ts|gradle|kts|plist|xml|properties|sh|cff|toml)$');

bool _looksBinary(String path) =>
    !_textFile.hasMatch(path) &&
    !path.endsWith('.gitignore') &&
    !path.endsWith('LICENSE');

/// Enumerates files to scan. Prefers `git ls-files` (only **tracked** files — the
/// files that would actually be published, so gitignored local artifacts such as
/// `android/local.properties` and Flutter ephemeral scripts are out of scope).
/// Falls back to a working-tree walk if git is unavailable.
List<String> _collectPaths() {
  try {
    final result = Process.runSync('git', ['ls-files', '-z']);
    if (result.exitCode == 0) {
      final out = (result.stdout as String);
      final paths = out
          .split(String.fromCharCode(0)) // NUL-delimited (git ls-files -z)
          .where((p) => p.isNotEmpty)
          .map((p) => p.replaceAll('\\', '/'))
          .toList();
      if (paths.isNotEmpty) return paths;
    }
  } catch (_) {
    // fall through to a tree walk
  }
  final paths = <String>[];
  for (final entity
      in Directory('.').listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    var rel =
        entity.path.startsWith('./') ? entity.path.substring(2) : entity.path;
    rel = rel.replaceAll('\\', '/');
    if (_skipDirs.any((d) => rel == d || rel.startsWith('$d/'))) continue;
    paths.add(rel);
  }
  return paths;
}

void main(List<String> args) {
  final strict = args.contains('--strict');
  final targets = <LocalPrivacyScanTarget>[];

  // Report top-level generated/local dirs (WARN) if present (informational).
  for (final d in _generatedDirsToReport) {
    if (Directory(d).existsSync()) {
      targets.add(LocalPrivacyScanTarget(
        path: '$d/',
        kind: 'directory',
        sizeBytes: 0,
        included: false,
        skipReason: 'generated_or_local_dir',
      ));
    }
  }

  for (final rel in _collectPaths()) {
    if (_skipDirs.any((d) => rel == d || rel.startsWith('$d/'))) continue;
    final file = File(rel);
    if (!file.existsSync()) continue;
    final size = file.lengthSync();
    if (_detectorDefinitionFiles.contains(rel)) {
      targets.add(LocalPrivacyScanTarget(
        path: rel,
        kind: 'file',
        sizeBytes: size,
        included: false,
        skipReason: 'detector_definition_or_test_fixture',
      ));
      continue;
    }
    if (_looksBinary(rel)) {
      targets.add(LocalPrivacyScanTarget(
        path: rel,
        kind: 'binary',
        sizeBytes: size,
        included: false,
        skipReason: 'binary_or_non_text',
      ));
      continue;
    }
    if (size > _maxScanBytes) {
      targets.add(LocalPrivacyScanTarget(
        path: rel,
        kind: 'file',
        sizeBytes: size,
        included: false,
        skipReason: 'too_large',
      ));
      continue;
    }
    String content;
    try {
      content = file.readAsStringSync();
    } catch (_) {
      targets.add(LocalPrivacyScanTarget(
        path: rel,
        kind: 'binary',
        sizeBytes: size,
        included: false,
        skipReason: 'unreadable_as_text',
      ));
      continue;
    }
    targets.add(LocalPrivacyScanTarget(
      path: rel,
      kind: 'file',
      sizeBytes: size,
      included: true,
      content: content,
    ));
  }

  // Deterministic ordering by path.
  targets.sort((a, b) => a.path.compareTo(b.path));

  final report = const LocalPrivacyPreflight().scan(
    targets,
    LocalPrivacyPreflightConfig(rootPath: '.', strictMode: strict),
  );

  final outDir = Directory('build/local_privacy_preflight');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  File('${outDir.path}/latest.json')
      .writeAsStringSync(encodeLocalPrivacyReport(report));
  File('${outDir.path}/latest.md')
      .writeAsStringSync(renderLocalPrivacyMarkdown(report));

  stdout
    ..writeln('Local privacy preflight: ${report.scannedFiles} scanned, '
        '${report.skippedFiles} skipped — '
        'info=${report.counts['info'] ?? 0} '
        'warn=${report.counts['warn'] ?? 0} '
        'blocker=${report.blockerCount} (pass=${report.pass}).')
    ..writeln('Report: ${outDir.path}/latest.json')
    ..writeln('Report: ${outDir.path}/latest.md');
  // Print the blocker lines for quick triage.
  if (!report.pass) {
    stderr.writeln('BLOCKER findings:');
    for (final fnd in report.findings
        .where((x) => x.severity == LocalPrivacySeverity.blocker)) {
      stderr.writeln('  - ${fnd.findingType} @ ${fnd.file}:${fnd.line} '
          '(${fnd.matchedText})');
    }
  }
  exitCode = report.pass ? 0 : 1;
}
