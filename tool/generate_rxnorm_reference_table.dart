// Regenerates lib/core/constants/rxnorm_reference_table.dart from the
// committed verbatim RxNorm subset.
//
// Usage (from the repository root):
//   dart run tool/generate_rxnorm_reference_table.dart

import 'dart:io';

import 'rxnorm_reference_codegen.dart';

void main() {
  final rendered = renderRxnormTable(File(rxnormSubsetPath).readAsStringSync());
  File(rxnormTableDartPath).writeAsStringSync(rendered);
  final format = Process.runSync('dart', ['format', rxnormTableDartPath]);
  if (format.exitCode != 0) {
    stderr.writeln(format.stderr);
    exitCode = format.exitCode;
    return;
  }
  stdout.writeln('Wrote $rxnormTableDartPath');
}
