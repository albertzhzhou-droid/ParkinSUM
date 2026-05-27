// Runs the mechanistic conflict / next-meal scenarios and writes a
// machine-readable report under build/mechanistic_replay/.
//
// Usage:
//   dart run tool/run_mechanistic_replay.dart
//
// Exits 0 iff every scenario passes. Educational simulation; not medical
// advice.

import 'dart:io';

import 'package:parkinsum_companion/domain/usecases/mechanistic_replay_runner.dart';

Future<void> main(List<String> args) async {
  final runner = MechanisticReplayRunner();
  final report = runner.run();
  final outDir = Directory('build/mechanistic_replay');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }
  final jsonFile = File('${outDir.path}/latest.json');
  final mdFile = File('${outDir.path}/latest.md');
  jsonFile.writeAsStringSync(encodeReplayReport(report));
  mdFile.writeAsStringSync(report.toMarkdown());
  stdout
    ..writeln('Mechanistic replay: ${report.passedCount}/${report.totalCount} '
        'scenarios passed.')
    ..writeln('Report: ${jsonFile.path}')
    ..writeln('Report: ${mdFile.path}');
  exit(report.allPassed ? 0 : 1);
}
