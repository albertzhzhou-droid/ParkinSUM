// Cross-runtime agreement gate for the Dart physiology reference port.
//
//   dart run tool/run_physiology_reference_agreement.dart
//
// Writes build/physiology_reference/agreement.json and exits non-zero when
// any number differs from the Python fixture beyond the stated tolerance.
import 'dart:convert';
import 'dart:io';

import 'physiology_reference_agreement.dart';

void main() {
  final fixture =
      jsonDecode(File(physiologyAgreementFixturePath).readAsStringSync())
          as Map<String, dynamic>;
  final report = comparePhysiologyAgreement(fixture);
  final output = File('build/physiology_reference/agreement.json');
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report.toJson())}\n',
  );
  stdout.writeln(
    'physiology reference agreement: ${report.pass ? 'pass' : 'FAIL'}; '
    '${report.comparedValuesBySection.values.fold(0, (a, b) => a + b)} '
    'values; max relative difference '
    '${report.maxRelativeDifference.toStringAsExponential(2)} '
    '(tolerance ${report.relativeTolerance} relative + '
    '${report.absoluteTolerance} absolute)',
  );
  for (final entry in report.maxRelativeDifferenceBySection.entries) {
    stdout.writeln(
      '  ${entry.key}: ${report.comparedValuesBySection[entry.key]} values, '
      'max relative ${entry.value.toStringAsExponential(2)}',
    );
  }
  for (final failure in report.failures.take(20)) {
    stdout.writeln('  FAIL $failure');
  }
  exitCode = report.pass ? 0 : 1;
}
