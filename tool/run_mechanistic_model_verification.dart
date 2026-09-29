import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/domain/usecases/algorithm_registry.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_model_verification_gate.dart';

void main() {
  final report = const MechanisticModelVerificationGate().run();
  final registeredIds = AlgorithmRegistry.all.map((entry) => entry.id);
  final output = report.toJson(registeredIds);
  final directory = Directory('build/mechanistic_model_verification');
  directory.createSync(recursive: true);
  const path = 'build/mechanistic_model_verification/latest.json';
  File(path).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(output)}\n',
  );

  final total = AlgorithmRegistry.all.length;
  final covered = report.coveredAlgorithmIds.length;
  stdout.writeln(
    'Mechanistic model verification: '
    '${report.passedCheckCount}/${report.checks.length} checks; '
    '$covered/$total algorithms covered; artifact=$path',
  );
  if (!report.passed) {
    for (final check in report.checks.where((entry) => !entry.passed)) {
      stderr.writeln('${check.spec.id}: ${check.failureCodes.join(', ')}');
    }
    exitCode = 1;
  }
}
