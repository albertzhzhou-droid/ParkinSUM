// Regenerates lib/core/constants/reference_food_nutrient_profile_table.dart
// from the committed FoodData Central 2025-04-24 subsets.
//
// Usage (from the repository root):
//   dart run tool/generate_reference_food_nutrient_profile_table.dart

import 'dart:io';

import 'reference_food_nutrient_profile_codegen.dart';

void main() {
  final rendered = renderReferenceNutrientProfileTable(
    nutrientCsvText: File(srNutrientSubsetPath).readAsStringSync(),
    portionCsvText: File(srPortionSubsetPath).readAsStringSync(),
    derivationCsvText: File(fdcDerivationPath).readAsStringSync(),
  );
  File(referenceNutrientProfileTablePath).writeAsStringSync(rendered);
  final format = Process.runSync('dart', [
    'format',
    referenceNutrientProfileTablePath,
  ]);
  if (format.exitCode != 0) {
    stderr.writeln(format.stderr);
    exitCode = format.exitCode;
    return;
  }
  stdout.writeln('Wrote $referenceNutrientProfileTablePath');
}
