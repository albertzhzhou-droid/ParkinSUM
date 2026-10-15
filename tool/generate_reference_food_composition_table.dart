// Regenerates lib/core/constants/reference_food_composition_table.dart from
// the committed USDA SR Legacy subset and curation files.
//
// Usage (from the repository root):
//   dart run tool/generate_reference_food_composition_table.dart

import 'dart:io';

import 'reference_food_composition_codegen.dart';

void main() {
  final rendered = renderReferenceTable(
    csvText: File(referenceSubsetCsvPath).readAsStringSync(),
    curationJsonText: File(referenceCurationJsonPath).readAsStringSync(),
  );
  File(referenceTableDartPath).writeAsStringSync(rendered);
  final format = Process.runSync('dart', ['format', referenceTableDartPath]);
  if (format.exitCode != 0) {
    stderr.writeln(format.stderr);
    exitCode = format.exitCode;
    return;
  }
  stdout.writeln('Wrote $referenceTableDartPath');
}
