import 'dart:convert';
import 'dart:io';

import 'algorithm_dependency_compatibility_spike.dart';

Future<void> main() async {
  try {
    final report = await runAlgorithmDependencyCompatibilitySpike();
    final output = File('build/algorithm_dependency_compatibility/latest.json');
    output.parent.createSync(recursive: true);
    output.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(report.toJson())}\n',
    );
    stdout.writeln(
      'Algorithm dependency compatibility: '
      '${report.compatibilityAccepted ? 'PASS' : 'HOLD'} '
      '(${report.acceptedRootCount}/${report.roots.length} roots; '
      '${report.canonicalPayload['closure_state']}; '
      '${report.sha256Digest})',
    );
    stdout.writeln(output.path);
    if (!report.compatibilityAccepted) exitCode = 1;
  } on Object catch (error, stackTrace) {
    stderr.writeln('Algorithm dependency compatibility spike failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}
