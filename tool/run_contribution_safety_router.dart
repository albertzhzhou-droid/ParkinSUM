// Classifies a pull-request / working-tree diff into review-risk categories
// using the ContributionSafetyRouter, writing a report under
// build/contribution_safety_router/.
//
// Usage:
//   dart run tool/run_contribution_safety_router.dart [--base <ref> --head <ref>] [--strict]
//
// Default: classifies working-tree changes vs HEAD (plus untracked files);
// falls back to staged changes. No network. Deterministic. This is a repository
// governance helper — NOT AI code review, NOT a medical/legal reviewer, and it
// does NOT replace human review.

import 'dart:io';

import 'package:parkinsum_companion/domain/entities/contribution_safety_router.dart';
import 'package:parkinsum_companion/domain/usecases/contribution_safety_router.dart';

const int _maxScanBytes = 512 * 1024;

const List<String> _skipPrefixes = [
  '.git/',
  '.dart_tool/',
  'node_modules/',
];

// Detector / scanner / governance files that legitimately CONTAIN the patterns
// the router defines, plus this PR's own governance doc. Keyword findings on
// these are downgraded to INFO (a scanner does not flag its own rules).
const List<String> _allowlistedPaths = [
  'lib/domain/entities/contribution_safety_router.dart',
  'lib/domain/usecases/contribution_safety_router.dart',
  'tool/run_contribution_safety_router.dart',
  'test/contribution_safety_router_test.dart',
  'docs/CONTRIBUTION_SAFETY_ROUTER.md',
  'lib/domain/entities/local_privacy_preflight.dart',
  'lib/domain/usecases/local_privacy_preflight.dart',
  'tool/run_local_privacy_preflight.dart',
  'test/local_privacy_preflight_test.dart',
  'tool/public_repo_preflight.mjs',
  'tool/backend_security_gate.mjs',
  'lib/domain/usecases/localization_safety_lint.dart',
  'test/localization_safety_lint_test.dart',
  'lib/domain/entities/source_access_contract.dart',
  'lib/domain/usecases/source_access_contract_checker.dart',
  'test/source_access_contract_checker_test.dart',
  'tool/run_source_access_contract_check.dart',
  'lib/domain/entities/source_version_drift.dart',
  'lib/domain/usecases/source_version_drift_checker.dart',
  'test/source_version_drift_checker_test.dart',
  'tool/run_source_version_drift_check.dart',
  'test/helpers/no_phi_json_assertions.dart',
  'lib/domain/entities/explanation_copy.dart',
  'lib/domain/usecases/explanation_copy_compiler.dart',
  'lib/domain/usecases/explanation_copy_service.dart',
  'test/explanation_copy_compiler_test.dart',
  'test/explanation_copy_service_test.dart',
  'docs/EXPLANATION_COPY_COMPILER.md',
  '.github/PULL_REQUEST_TEMPLATE.md',
  '.github/pull_request_template.md',
];

final RegExp _docExt = RegExp(r'\.(md|markdown)$');
final RegExp _srcId = RegExp(r'src\.[a-zA-Z0-9_.]+');

void main(List<String> args) {
  final strict = args.contains('--strict');
  final base = _arg(args, '--base');
  final head = _arg(args, '--head');

  final paths = _changedPaths(base, head);
  final changes = <ContributionChange>[];
  for (final path in paths) {
    if (_skipPrefixes.any((p) => path.startsWith(p))) continue;
    final added = _addedContent(path, base, head);
    changes.add(ContributionChange(
      path: path,
      changeType: 'modified',
      addedLines: added.split('\n').where((l) => l.isNotEmpty).length,
      addedContent: added,
      sourceRefs:
          _srcId.allMatches(added).map((m) => m.group(0)!).toSet().toList()
            ..sort(),
      isGenerated: path.startsWith('build/'),
      isDocs: path == 'README.md' ||
          path == 'Bibliographies.md' ||
          path.startsWith('docs/') ||
          path.startsWith('.github/') ||
          _docExt.hasMatch(path),
      isTest: path.startsWith('test/'),
      allowlisted: _allowlistedPaths.contains(path),
    ));
  }

  final report = const ContributionSafetyRouter().route(
    changes,
    ContributionSafetyRouterConfig(strictMode: strict),
  );

  final outDir = Directory('build/contribution_safety_router');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  File('${outDir.path}/latest.json')
      .writeAsStringSync(encodeContributionSafetyReport(report));
  File('${outDir.path}/latest.md')
      .writeAsStringSync(renderContributionSafetyMarkdown(report));

  stdout
    ..writeln('Contribution safety router: ${report.changeCount} changed files '
        '— risk=${report.riskLevel} '
        'info=${report.counts['info'] ?? 0} '
        'warn=${report.counts['warn'] ?? 0} '
        'blocker=${report.blockerCount} (pass=${report.pass}).')
    ..writeln('Categories: ${report.categories.join(', ')}')
    ..writeln('Suggested labels: ${report.suggestedLabels.join(', ')}')
    ..writeln('Report: ${outDir.path}/latest.json')
    ..writeln('Report: ${outDir.path}/latest.md');
  if (!report.pass) {
    stderr.writeln('BLOCKER findings:');
    for (final f in report.findings
        .where((x) => x.severity == ContributionRiskSeverity.blocker)) {
      stderr.writeln('  - ${f.category} @ ${f.path} (${f.matchedText})');
    }
  }
  exitCode = report.pass ? 0 : 1;
}

/// Changed file paths. Prefers an explicit base...head range; otherwise
/// working-tree changes vs HEAD plus untracked files; falls back to staged.
List<String> _changedPaths(String? base, String? head) {
  final result = <String>{};
  if (base != null && head != null) {
    result.addAll(_gitLines(['diff', '--name-only', '$base...$head']));
    if (result.isNotEmpty) return result.toList()..sort();
  }
  result
    ..addAll(_gitLines(['diff', '--name-only', 'HEAD']))
    ..addAll(_gitLines(['ls-files', '--others', '--exclude-standard']));
  if (result.isEmpty) {
    result.addAll(_gitLines(['diff', '--name-only', '--cached']));
  }
  return result.toList()..sort();
}

String _addedContent(String path, String? base, String? head) {
  // Untracked file → whole content is "added".
  final tracked = _gitLines(['ls-files', '--', path]).isNotEmpty;
  if (!tracked) {
    final f = File(path);
    if (f.existsSync() && f.lengthSync() <= _maxScanBytes) {
      try {
        return f.readAsStringSync();
      } catch (_) {
        return '';
      }
    }
    return '';
  }
  final range = (base != null && head != null) ? '$base...$head' : 'HEAD';
  final diff = _gitOutput(['diff', '--unified=0', range, '--', path]);
  final buf = StringBuffer();
  for (final line in diff.split('\n')) {
    if (line.startsWith('+') && !line.startsWith('+++')) {
      buf.writeln(line.substring(1));
    }
  }
  return buf.toString();
}

List<String> _gitLines(List<String> args) => _gitOutput(args)
    .split('\n')
    .map((l) => l.trim())
    .where((l) => l.isNotEmpty)
    .toList();

String _gitOutput(List<String> args) {
  try {
    final r = Process.runSync('git', args);
    if (r.exitCode != 0) return '';
    return (r.stdout as String);
  } catch (_) {
    return '';
  }
}

String? _arg(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i >= 0 && i + 1 < args.length) return args[i + 1];
  return null;
}
