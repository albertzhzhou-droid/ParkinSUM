// Regenerates lib/core/constants/lnaa_protein_fraction_calibration_table.dart
// from the committed FoodData Central 2025-04-24 rows and reference curation.
//
// Usage (from the repository root):
//   dart run tool/generate_lnaa_protein_fraction_calibration_table.dart

import 'dart:io';

import 'lnaa_protein_fraction_calibration_codegen.dart';
import 'reference_food_composition_codegen.dart';
import 'reference_food_nutrient_profile_codegen.dart';

void main() {
  final result = computeLnaaCalibration(
    nutrientCsvText: File(srNutrientSubsetPath).readAsStringSync(),
    derivationCsvText: File(fdcDerivationPath).readAsStringSync(),
    referenceCsvText: File(referenceSubsetCsvPath).readAsStringSync(),
    curationJsonText: File(referenceCurationJsonPath).readAsStringSync(),
  );
  File(
    lnaaCalibrationTablePath,
  ).writeAsStringSync(renderLnaaCalibrationTable(result));
  final format = Process.runSync('dart', ['format', lnaaCalibrationTablePath]);
  if (format.exitCode != 0) {
    stderr.writeln(format.stderr);
    exitCode = format.exitCode;
    return;
  }
  stdout.writeln(
    'Wrote $lnaaCalibrationTablePath: ${result.foods.length} foods, '
    'median ${result.overall.median}',
  );
}
