// Runs the deterministic synthetic scenario fuzzer and writes a report under
// build/synthetic_scenario_fuzzer/.
//
// Usage:
//   dart run tool/run_synthetic_scenario_fuzzer.dart [--seed=1] [--case-count=24]
//     [--family=medication_dosage,source_quality]
//
// Deterministic; no network; synthetic data only. It stress-tests EXISTING gates
// (validator, completeness gate, source-authority scorer, absorption model,
// next-meal scorer, safety-copy + no-PHI scans) with boundary inputs. Exits
// non-zero iff a must-pass invariant fails. Not clinical validation; not medical
// advice; not clinically calibrated.

import 'dart:io';

import 'package:parkinsum_companion/domain/entities/synthetic_scenario_fuzzer.dart';
import 'package:parkinsum_companion/domain/usecases/synthetic_scenario_fuzzer.dart';

String? _flag(List<String> args, String name) {
  final prefix = '--$name=';
  for (final a in args) {
    if (a.startsWith(prefix)) return a.substring(prefix.length);
  }
  return null;
}

Set<SyntheticScenarioFamily> _families(String? csv) {
  if (csv == null || csv.trim().isEmpty) {
    return const {
      SyntheticScenarioFamily.medicationDosage,
      SyntheticScenarioFamily.mealMissingness,
      SyntheticScenarioFamily.releaseTimeline,
      SyntheticScenarioFamily.sourceQuality,
      SyntheticScenarioFamily.windowRanking,
      SyntheticScenarioFamily.safetyCopyNoPhi,
    };
  }
  final wanted = csv.split(',').map((s) => s.trim()).toSet();
  return SyntheticScenarioFamily.values
      .where((f) => wanted.contains(f.id))
      .toSet();
}

Future<void> main(List<String> args) async {
  final seed = int.tryParse(_flag(args, 'seed') ?? '1') ?? 1;
  // Default covers the full catalog (clamped to the available count).
  final caseCount = int.tryParse(_flag(args, 'case-count') ?? '64') ?? 64;
  final config = SyntheticScenarioFuzzerConfig(
    seed: seed,
    caseCount: caseCount,
    enabledFamilies: _families(_flag(args, 'family')),
  );

  final report = SyntheticScenarioFuzzer().run(config);

  final outDir = Directory('build/synthetic_scenario_fuzzer');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  File('${outDir.path}/latest.json')
      .writeAsStringSync(encodeSyntheticScenarioReport(report));
  File('${outDir.path}/latest.md')
      .writeAsStringSync(renderSyntheticScenarioMarkdown(report));

  stdout
    ..writeln('Synthetic scenario fuzzer: '
        '${report.passed}/${report.caseCount} cases passed '
        '(seed=${report.seed}).')
    ..writeln('Report: ${outDir.path}/latest.json')
    ..writeln('Report: ${outDir.path}/latest.md');
  if (!report.allMustPass) {
    stderr.writeln('Must-pass invariant failures: ${report.failed}.');
    exit(1);
  }
  exit(0);
}
