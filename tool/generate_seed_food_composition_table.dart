// Regenerates lib/core/constants/seed_food_composition_table.dart.
//
// Usage (from the repository root):
//   dart run tool/generate_seed_food_composition_table.dart

import 'dart:io';

import 'seed_food_composition_codegen.dart';

void main() {
  final rendered = renderSeedTable(
    sourcesJson: File(seedSourcesJsonPath).readAsStringSync(),
    srCsv: File(seedSrSubsetPath).readAsStringSync(),
    fnddsFoodCsv: File(seedFnddsFoodPath).readAsStringSync(),
    fnddsNutrientCsv: File(seedFnddsNutrientPath).readAsStringSync(),
  );
  File(seedTableDartPath).writeAsStringSync(rendered);
  final format = Process.runSync('dart', ['format', seedTableDartPath]);
  if (format.exitCode != 0) {
    stderr.writeln(format.stderr);
    exitCode = format.exitCode;
    return;
  }
  stdout.writeln('Wrote $seedTableDartPath');
}
