// P9 source-access contract CLI. No network. Deterministic output.
//
// Usage:
//   dart run tool/run_source_access_contract_check.dart [--strict]

import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/domain/entities/source_access_contract.dart';
import 'package:parkinsum_companion/domain/usecases/source_access_contract_checker.dart';

const _registryPath = 'config/source_access_registry.json';
const _scanRoots = ['lib', 'test', 'docs', 'tool'];
const _artifactPaths = [
  'build/mechanistic_replay/latest.json',
  'build/source_quality_perturbation/latest.json',
  'build/evidence_graph/latest.json',
  'build/public_demo_walkthrough/latest.json',
];
const _collectorFixtureFiles = {
  'test/source_access_contract_checker_test.dart',
  // Sibling detector tests whose synthetic `src.*` fixtures are not real
  // observed source references (they exercise other checkers' logic).
  'test/source_version_drift_checker_test.dart',
};

final _quotedSourceId =
    RegExp(r'''["'](src\.[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)*)["']''');
final _sourceSystem = RegExp(
    r'''sourceSystem\s*:\s*["']([A-Za-z0-9_]+)["']|["']source_system["']\s*:\s*["']([A-Za-z0-9_]+)["']''');

const _sourceSystemRefs = {
  'DailyMed': 'src.dailymed.spl.webservices.v2',
  'HealthCanadaDPD': 'src.healthcanada.dpd',
  'EMA': 'src.ema.epi.fhir',
  'EU_National_Register': 'src.ema.national_registers',
  'NHS_DMD': 'src.nhs.dmd',
  'PMDA': 'src.pmda.package_insert',
  'NMPA': 'src.nmpa.database',
  'USDA_FDC': 'src.usda.fdc.api',
  'CIQUAL': 'src.ciqual',
  'China_Food_Composition': 'src.chinacdc.food',
  'synthetic_demo': 'src.internal.prototype.heuristic',
  'app_seed': 'src.internal.prototype.heuristic',
};

String _usageType(String path) {
  if (path.startsWith('docs/') || path == 'Bibliographies.md') {
    return SourceUsageType.documentation;
  }
  if (path.contains('model_assumption_registry.dart')) {
    return SourceUsageType.modelAssumption;
  }
  if (path.contains('source_quality')) return SourceUsageType.sourceQuality;
  if (path.startsWith('test/') || path.contains('fixture')) {
    return SourceUsageType.fixture;
  }
  return SourceUsageType.unknown;
}

List<String> _trackedPaths() {
  final result = Process.runSync('git', ['ls-files', '-z']);
  if (result.exitCode != 0) {
    throw StateError('git ls-files failed: ${result.stderr}');
  }
  return (result.stdout as String)
      .split(String.fromCharCode(0))
      .where((path) => path.isNotEmpty)
      .where((path) =>
          path == 'Bibliographies.md' ||
          _scanRoots.any((root) => path.startsWith('$root/')))
      .where((path) => !_collectorFixtureFiles.contains(path))
      .toList(growable: false);
}

List<ObservedSourceRef> collectObservedSourceRefs() {
  final paths = <String>{
    ..._trackedPaths(),
    for (final path in _artifactPaths)
      if (File(path).existsSync()) path,
  }.toList()
    ..sort();
  final refs = <ObservedSourceRef>[];
  final seen = <String>{};

  void add(String sourceId, String path, String role) {
    final key = '$sourceId|$path|$role';
    if (!seen.add(key)) return;
    refs.add(ObservedSourceRef(
      sourceId: sourceId,
      file: path,
      role: role,
      usageType: _usageType(path),
    ));
  }

  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) continue;
    String content;
    try {
      content = file.readAsStringSync();
    } catch (_) {
      continue;
    }
    for (final match in _quotedSourceId.allMatches(content)) {
      add(match.group(1)!, path, 'source_ref');
    }
    for (final match in _sourceSystem.allMatches(content)) {
      final system = match.group(1) ?? match.group(2);
      final sourceId = _sourceSystemRefs[system];
      if (sourceId != null) add(sourceId, path, 'source_system:$system');
    }
  }
  refs.sort((a, b) {
    final bySource = a.sourceId.compareTo(b.sourceId);
    if (bySource != 0) return bySource;
    final byFile = a.file.compareTo(b.file);
    if (byFile != 0) return byFile;
    return a.role.compareTo(b.role);
  });
  return refs;
}

void main(List<String> args) {
  final strict = args.contains('--strict');
  final registryJson = jsonDecode(File(_registryPath).readAsStringSync())
      as Map<String, dynamic>;
  final contract = SourceAccessContract.fromJson(registryJson);
  final references = collectObservedSourceRefs();
  final report = const SourceAccessContractChecker().check(
    contract: contract,
    references: references,
    strictMode: strict,
  );
  final out = Directory('build/source_access_contract')
    ..createSync(recursive: true);
  File('${out.path}/latest.json')
      .writeAsStringSync(encodeSourceAccessReport(report));
  File('${out.path}/latest.md')
      .writeAsStringSync(renderSourceAccessMarkdown(report));
  stdout
    ..writeln('Source access contract: ${report.sourceCount} sources, '
        '${report.referenceCount} observed references — '
        'info=${report.counts['info'] ?? 0} '
        'warn=${report.counts['warn'] ?? 0} '
        'blocker=${report.blockerCount} (pass=${report.pass}).')
    ..writeln('Report: ${out.path}/latest.json')
    ..writeln('Report: ${out.path}/latest.md');
  exitCode = report.pass ? 0 : 1;
}
