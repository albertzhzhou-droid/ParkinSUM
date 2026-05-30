// Runs the source-quality perturbation analysis and writes a machine-readable
// report under build/source_quality_perturbation/.
//
// Usage:
//   dart run tool/run_source_quality_perturbation_report.dart
//
// Deterministic educational analysis over synthetic inputs. Shows how candidate
// scoring moves when ONLY source/provenance quality changes, holding the
// meal/conflict/model input constant. Not a clinical dashboard; no medical
// advice. Exits non-zero only if a banned prescriptive substring leaks.

import 'dart:io';

import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/usecases/source_quality_perturbation_report.dart';

Future<void> main(List<String> args) async {
  final runner = SourceQualityPerturbationReportRunner();
  final report = runner.run();

  final outDir = Directory('build/source_quality_perturbation');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }
  final jsonStr = encodeSourceQualityReport(report);
  final mdStr = report.toMarkdown();
  File('${outDir.path}/latest.json').writeAsStringSync(jsonStr);
  File('${outDir.path}/latest.md').writeAsStringSync(mdStr);

  // Safety gate: the report's copy must stay non-prescriptive.
  final banned = findBannedSubstrings('$jsonStr\n$mdStr');

  stdout
    ..writeln('Source-quality perturbation report: ${report.rows.length} rows.')
    ..writeln('Report: ${outDir.path}/latest.json')
    ..writeln('Report: ${outDir.path}/latest.md');
  if (banned.isNotEmpty) {
    stderr.writeln('Banned prescriptive substrings leaked: $banned');
    exit(1);
  }
  exit(0);
}
