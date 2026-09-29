import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/domain/usecases/algorithm_executable_contract_gate.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_registry.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_model_verification_gate.dart';

Future<void> main() async {
  final executableReport = await const AlgorithmExecutableContractGate().run();
  final mathematicalReport = const MechanisticModelVerificationGate().run();
  final registeredIds = AlgorithmRegistry.all.map((entry) => entry.id).toSet();
  final combinedCoveredIds = <String>{
    ...mathematicalReport.coveredAlgorithmIds,
    ...executableReport.coveredAlgorithmIds,
  };
  final mathematicalUncoveredIds = registeredIds.difference(
    mathematicalReport.coveredAlgorithmIds,
  );
  final uncoveredIds = registeredIds.difference(combinedCoveredIds).toList()
    ..sort();
  final output = <String, Object?>{
    ...executableReport.toJson(registeredIds),
    'coverage': <String, Object?>{
      'executable_contract_covered':
          executableReport.coveredAlgorithmIds.length,
      'mathematical_gate_covered':
          mathematicalReport.coveredAlgorithmIds.length,
      'combined_covered': combinedCoveredIds.length,
      'registered_total': registeredIds.length,
      'uncovered_count': uncoveredIds.length,
      'uncovered_algorithm_ids': uncoveredIds,
    },
  };
  final directory = Directory('build/algorithm_executable_contract');
  directory.createSync(recursive: true);
  const path = 'build/algorithm_executable_contract/latest.json';
  File(path).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(output)}\n',
  );

  final coveragePassed =
      registeredIds.length == 65 &&
      mathematicalReport.checks.length == 23 &&
      mathematicalReport.coveredAlgorithmIds.length == 22 &&
      mathematicalUncoveredIds.length == 43 &&
      executableReport.coveredAlgorithmIds.length == 8 &&
      combinedCoveredIds.length == 30 &&
      uncoveredIds.length == 35;
  stdout.writeln(
    'Algorithm executable contracts: '
    '${executableReport.passedCheckCount}/${executableReport.checks.length} checks; '
    '${executableReport.coveredAlgorithmIds.length}/${registeredIds.length} direct; '
    '${combinedCoveredIds.length}/${registeredIds.length} combined; '
    '${uncoveredIds.length} uncovered; artifact=$path',
  );
  if (!executableReport.passed || !coveragePassed) {
    for (final failure in executableReport.integrityFailureCodes) {
      stderr.writeln(failure);
    }
    for (final check in executableReport.checks.where(
      (entry) => entry.status != AlgorithmExecutableContractStatus.passed,
    )) {
      stderr.writeln('${check.spec.id}: ${check.failureCodes.join(', ')}');
    }
    if (!coveragePassed) {
      stderr.writeln(
        'contract.coverage_drift: registered=${registeredIds.length}, '
        'mathematical_checks=${mathematicalReport.checks.length}, '
        'mathematical=${mathematicalReport.coveredAlgorithmIds.length}, '
        'mathematical_uncovered=${mathematicalUncoveredIds.length}, '
        'direct=${executableReport.coveredAlgorithmIds.length}, '
        'combined=${combinedCoveredIds.length}, uncovered=${uncoveredIds.length}',
      );
    }
    exitCode = 1;
  }
}
