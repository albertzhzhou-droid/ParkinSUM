// Composes existing verification artifacts into a single release-evidence
// snapshot under build/release_snapshot/.
//
// Usage:
//   dart run tool/run_release_snapshot.dart \
//     [--analyze=clean] [--test-count=460] [--test-status=passed] \
//     [--firestore=13/13] [--live-smoke=skipped_opt_in]
//
// It PARSES already-produced report artifacts (it does not run slow commands):
//   build/mechanistic_replay/latest.json
//   build/source_quality_perturbation/latest.json
//   build/public_release_preflight/latest.json
// Checks without a JSON artifact (analyze/test/firestore) may be injected via
// flags; absent inputs are recorded as `missing_artifact` — never fabricated.
//
// Educational/research prototype. Synthetic data only. Not medical advice.

import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/domain/usecases/release_snapshot_generator.dart';

Map<String, dynamic>? _readJson(String path) {
  final f = File(path);
  if (!f.existsSync()) return null;
  try {
    final decoded = jsonDecode(f.readAsStringSync());
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

String? _flag(List<String> args, String name) {
  final prefix = '--$name=';
  for (final a in args) {
    if (a.startsWith(prefix)) return a.substring(prefix.length);
  }
  return null;
}

Future<void> main(List<String> args) async {
  final testCountStr = _flag(args, 'test-count');
  final inputs = ReleaseSnapshotInputs(
    analyzeStatus: _flag(args, 'analyze'),
    testCount: testCountStr == null ? null : int.tryParse(testCountStr),
    testStatus: _flag(args, 'test-status'),
    replayReport: _readJson('build/mechanistic_replay/latest.json'),
    sourceQualityReport:
        _readJson('build/source_quality_perturbation/latest.json'),
    preflightReport: _readJson('build/public_release_preflight/latest.json'),
    firestoreStatus: _flag(args, 'firestore'),
    liveSmokeStatus: _flag(args, 'live-smoke'),
    capabilityMatrixSummary: File('docs/CAPABILITY_MATRIX.md').existsSync()
        ? 'see docs/CAPABILITY_MATRIX.md (implemented / fixture-tested / '
            'deterministic-report / documentation-only / future-work rows)'
        : null,
  );

  final snapshot = const ReleaseSnapshotGenerator().build(inputs);

  final outDir = Directory('build/release_snapshot');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  File('${outDir.path}/latest.json')
      .writeAsStringSync(encodeReleaseSnapshot(snapshot));
  File('${outDir.path}/latest.md').writeAsStringSync(snapshot.toMarkdown());

  stdout
    ..writeln('Release snapshot written '
        '(${snapshot.complete ? 'all required checks resolved' : 'incomplete: missing_artifact present'}).')
    ..writeln('Report: ${outDir.path}/latest.json')
    ..writeln('Report: ${outDir.path}/latest.md');
  // Always exit 0: this is an evidence summary, not a gate. Missing inputs are
  // reported in-band as `missing_artifact`.
  exit(0);
}
