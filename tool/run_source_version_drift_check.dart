// Collects source/version metadata records from local ParkinSUM files and build
// artifacts and runs the SourceVersionDriftChecker, writing a report under
// build/source_version_drift/.
//
// Usage:
//   dart run tool/run_source_version_drift_check.dart [--strict] [--now=ISO] [--staleness-days=N]
//
// Educational/research prototype. Provenance / release-hygiene drift checking
// only. It does NOT fetch or update live sources, is NOT legal/license
// clearance, NOT clinical validation or calibration, and does NOT prove medical
// correctness. No network. Deterministic by default (staleness is only computed
// when --now is supplied).

import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/domain/entities/source_version_drift.dart';
import 'package:parkinsum_companion/domain/usecases/source_version_drift_checker.dart';

const String _registryPath = 'config/source_access_registry.json';
const String _bibliographyPath = 'Bibliographies.md';
const String _modelAssumptionsPath =
    'lib/domain/usecases/model_assumption_registry.dart';
const String _sourceAdapterPath =
    'lib/data/datasources/remote/source_adapter_registry.dart';

// Build artifacts considered (all optional; absent → WARN, never fabricated).
const List<String> _artifactPaths = [
  'build/mechanistic_replay/latest.json',
  'build/source_quality_perturbation/latest.json',
  'build/evidence_graph/latest.json',
  'build/release_snapshot/latest.json',
  'build/public_demo_walkthrough/latest.json',
  'build/synthetic_scenario_fuzzer/latest.json',
  'build/localization_safety_lint/latest.json',
  'build/local_privacy_preflight/latest.json',
  'build/source_access_contract/latest.json',
  'build/input_quality/latest.json',
  'build/catalog_resolution/latest.json',
];

final RegExp _srcId = RegExp(r'src\.[a-zA-Z0-9_.]+');
final RegExp _assumptionSourceId =
    RegExp(r"sourceId:\s*'(src\.[a-zA-Z0-9_.]+)'");
final RegExp _adapterSourceRefs = RegExp(r"sourceRefs:\s*\[([^\]]*)\]");

void main(List<String> args) {
  final strict = args.contains('--strict');
  final nowArg = _arg(args, '--now=');
  final staleArg = _arg(args, '--staleness-days=');

  final records = <SourceVersionRecord>[];

  // 1) Bibliography source ids.
  final bibliographyIds = <String>{};
  final bibFile = File(_bibliographyPath);
  if (bibFile.existsSync()) {
    for (final m in _srcId.allMatches(bibFile.readAsStringSync())) {
      bibliographyIds.add(m.group(0)!);
    }
  }
  for (final id in bibliographyIds.toList()..sort()) {
    records.add(SourceVersionRecord(
      recordId: 'bib:$id',
      sourceId: id,
      recordType: SourceVersionRecordType.bibliographyEntry,
      file: _bibliographyPath,
    ));
  }

  // 2) Source-access registry.
  final regFile = File(_registryPath);
  if (regFile.existsSync()) {
    final doc = jsonDecode(regFile.readAsStringSync()) as Map<String, dynamic>;
    final sources = (doc['sources'] as List?) ?? const [];
    for (final s in sources) {
      final m = s as Map<String, dynamic>;
      records.add(SourceVersionRecord(
        recordId: 'reg:${m['source_id']}',
        sourceId: (m['source_id'] ?? '').toString(),
        sourceFamily: (m['source_family'] ?? '').toString(),
        recordType: SourceVersionRecordType.sourceAccessRegistry,
        file: _registryPath,
        lastPolicyReviewed: (m['last_policy_reviewed'] ?? '').toString(),
        implementationStatus: (m['implementation_status'] ?? '').toString(),
        bibliographyRefs: _strList(m['bibliography_refs']),
        documentationRefs: _strList(m['documentation_refs']),
        limitations: _strList(m['known_limitations']),
      ));
    }
  }

  // 3) Model assumptions.
  final asmFile = File(_modelAssumptionsPath);
  if (asmFile.existsSync()) {
    final content = asmFile.readAsStringSync();
    var i = 0;
    for (final m in _assumptionSourceId.allMatches(content)) {
      final id = m.group(1)!;
      records.add(SourceVersionRecord(
        recordId: 'assumption:${i++}:$id',
        sourceId: id,
        recordType: SourceVersionRecordType.modelAssumption,
        file: _modelAssumptionsPath,
        sourceRefs: [id],
        metadata: const {'mechanism_role': 'true'},
      ));
    }
  }

  // 4) Source adapters.
  final adapterFile = File(_sourceAdapterPath);
  if (adapterFile.existsSync()) {
    final content = adapterFile.readAsStringSync();
    var i = 0;
    for (final m in _adapterSourceRefs.allMatches(content)) {
      for (final idMatch in _srcId.allMatches(m.group(1) ?? '')) {
        final id = idMatch.group(0)!;
        records.add(SourceVersionRecord(
          recordId: 'adapter:${i++}:$id',
          sourceId: id,
          recordType: SourceVersionRecordType.sourceAdapter,
          file: _sourceAdapterPath,
          sourceRefs: [id],
        ));
      }
    }
  }

  // 5) Generated artifacts.
  for (final path in _artifactPaths) {
    final file = File(path);
    final exists = file.existsSync();
    var generatedAt = '';
    if (exists) {
      try {
        final doc = jsonDecode(file.readAsStringSync());
        if (doc is Map<String, dynamic>) {
          generatedAt =
              (doc['generated_at'] ?? doc['generatedAt'] ?? '').toString();
        }
      } catch (_) {
        // leave generatedAt empty; checker flags it.
      }
    }
    records.add(SourceVersionRecord(
      recordId: 'artifact:$path',
      recordType: SourceVersionRecordType.generatedArtifact,
      file: path,
      generatedAt: generatedAt,
      metadata: {
        'exists': exists ? 'true' : 'false',
        'expected': 'true',
        'optional': 'true',
      },
    ));
  }

  final config = SourceVersionDriftConfig(
    referenceTimestamp: nowArg ?? '',
    stalenessThresholdDays:
        staleArg == null ? 180 : int.tryParse(staleArg) ?? 180,
    strictMode: strict,
  );

  final report = const SourceVersionDriftChecker().check(records, config);

  final outDir = Directory('build/source_version_drift');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  File('${outDir.path}/latest.json')
      .writeAsStringSync(encodeSourceVersionDrift(report));
  File('${outDir.path}/latest.md')
      .writeAsStringSync(renderSourceVersionDriftMarkdown(report));

  stdout
    ..writeln('Source version drift: ${report.recordCount} records — '
        'info=${report.findingCounts['info'] ?? 0} '
        'warn=${report.findingCounts['warn'] ?? 0} '
        'blocker=${report.blockerCount} (pass=${report.pass}).')
    ..writeln('Report: ${outDir.path}/latest.json')
    ..writeln('Report: ${outDir.path}/latest.md');
  if (!report.pass) {
    stderr.writeln('BLOCKER findings:');
    for (final fnd in report.findings
        .where((x) => x.severity == SourceVersionDriftSeverity.blocker)) {
      stderr.writeln('  - ${fnd.findingType} @ ${fnd.file} (${fnd.sourceId})');
    }
  }
  exitCode = report.pass ? 0 : 1;
}

String? _arg(List<String> args, String prefix) {
  for (final a in args) {
    if (a.startsWith(prefix)) return a.substring(prefix.length);
  }
  return null;
}

List<String> _strList(dynamic v) =>
    (v as List?)?.map((e) => e.toString()).toList(growable: false) ?? const [];
