import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/reference_food_nutrient_profile_table.dart';
import 'package:parkinsum_companion/core/constants/reference_food_nutrient_profiles.dart';
import 'package:parkinsum_companion/data/datasources/remote/regional_seed_catalog_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/seed_catalog_importer.dart';
import 'package:parkinsum_companion/domain/usecases/food_composition_interdependency_model.dart';

import '../tool/reference_food_composition_codegen.dart' show parseCsv;
import '../tool/reference_food_nutrient_profile_codegen.dart';

/// The official FoodData Central 2025-04-24 rows of the SR Legacy reference
/// and seed foods. Educational prototype; values describe foods, not people.
void main() {
  final nutrientRows = parseNutrientSubset(
    File(srNutrientSubsetPath).readAsStringSync(),
  );
  final portionRows = parsePortionSubset(
    File(srPortionSubsetPath).readAsStringSync(),
  );
  final official = <int, Map<int, NutrientCsvRow>>{};
  for (final row in nutrientRows) {
    official.putIfAbsent(
      int.parse(row.fdcId),
      () => {},
    )[int.parse(row.nutrientId)] = row;
  }

  test('committed FDC files keep their verified bytes', () {
    const pinned = {
      srNutrientSubsetPath:
          '7e6251bea3ae947a0646ec4bf77abdc25b315fc53807ed5a53a0e1653d1d2a84',
      srPortionSubsetPath:
          '8fc0c5aa22fbbb02a8147a159ee783b942996b819b32ac9ba13fd7d580c21ddd',
      fdcDerivationPath:
          '5b6d38163f2dcf1e808181405e1e96dc20a1deaaa74ce915737745f1ccce6673',
    };
    for (final entry in pinned.entries) {
      expect(
        sha256.convert(File(entry.key).readAsBytesSync()).toString(),
        entry.value,
        reason: entry.key,
      );
    }
    // The derivation table is complete: the mirror publishes 8,294 bytes.
    expect(File(fdcDerivationPath).lengthSync(), 8294);
  });

  test('subset covers every SR Legacy reference and seed food', () {
    final targets = <int>{
      for (final file in [
        'tool/data/usda_sr_legacy_reference_subset_2018.csv',
        'tool/data/usda_sr_legacy_seed_subset_2018.csv',
      ])
        for (final row in parseCsv(File(file).readAsStringSync()).skip(1))
          if (row.first.isNotEmpty) int.parse(row.first),
    };
    expect(targets, hasLength(280));
    expect(official.keys.toSet(), targets);
    expect(nutrientRows, hasLength(26995));
    // Three foods have no portion record in the source.
    final withPortions = {for (final row in portionRows) int.parse(row[1])};
    expect(targets.difference(withPortions), {168147, 168152, 170378});
    expect(portionRows, hasLength(788));
  });

  test('generated table reproduces every mapped source row exactly', () {
    final mapped = mappedNutrientIds();
    final expected = [
      for (final row in nutrientRows)
        if (mapped.contains(int.parse(row.nutrientId))) row,
    ];
    expect(referenceNutrientRecords, hasLength(expected.length));
    double? number(String text) => text.isEmpty ? null : double.parse(text);
    int? integer(String text) => text.isEmpty ? null : int.parse(text);
    for (var i = 0; i < expected.length; i++) {
      final source = expected[i];
      final record = referenceNutrientRecords[i];
      expect(record.rowId, int.parse(source.id));
      expect(record.fdcId, int.parse(source.fdcId));
      expect(record.nutrientId, int.parse(source.nutrientId));
      expect(record.amount, double.parse(source.amount));
      expect(record.dataPoints, integer(source.dataPoints));
      expect(record.derivationId, integer(source.derivationId));
      expect(record.min, number(source.min));
      expect(record.max, number(source.max));
      expect(record.median, number(source.median));
      expect(record.minYearAcquired, integer(source.minYearAcquired));
    }
    expect(referencePortionRecords, hasLength(portionRows.length));
    for (var i = 0; i < portionRows.length; i++) {
      final source = portionRows[i];
      final record = referencePortionRecords[i];
      expect(record.rowId, int.parse(source[0]));
      expect(record.fdcId, int.parse(source[1]));
      expect(record.sequenceNumber, integer(source[2]));
      expect(record.amount, number(source[3]));
      expect(record.measureUnitId, integer(source[4]));
      expect(record.portionDescription, source[5]);
      expect(record.modifier, source[6]);
      expect(record.gramWeight, number(source[7]));
      expect(record.dataPoints, integer(source[8]));
      expect(record.minYearAcquired, integer(source[10]));
    }
    final derivations = parseDerivations(
      File(fdcDerivationPath).readAsStringSync(),
    );
    expect(fdcDerivationCodes, hasLength(derivations.length));
    for (var i = 0; i < derivations.length; i++) {
      expect(fdcDerivationCodes[i].id, int.parse(derivations[i][0]));
      expect(fdcDerivationCodes[i].code, derivations[i][1]);
      expect(fdcDerivationCodes[i].description, derivations[i][2]);
    }
  });

  test('values copied through the mirror equal the official rows', () {
    // The reference and seed subsets were read through a third-party mirror
    // of SR Legacy 2018. Every value they carry must equal the official FDC
    // 2025 row, and every blank must be a nutrient the source omits.
    const columns = {
      'Energy': 1008,
      'Protein': 1003,
      'Fat': 1004,
      'Carbohydrate': 1005,
      'Fiber': 1079,
      'Calcium': 1087,
      'Phosphorus': 1091,
      'Iron': 1089,
      'Sodium': 1093,
      'Potassium': 1092,
      'Copper': 1098,
      'Zinc': 1095,
      'Retinol': 1105,
      'Beta_Carotene': 1107,
      'Thiamine': 1165,
      'Riboflavin': 1166,
      'Niacin': 1167,
      'Vitamin_C': 1162,
    };
    var compared = 0;
    for (final file in [
      'tool/data/usda_sr_legacy_reference_subset_2018.csv',
      'tool/data/usda_sr_legacy_seed_subset_2018.csv',
    ]) {
      final rows = parseCsv(File(file).readAsStringSync());
      final header = rows.first;
      for (final row in rows.skip(1)) {
        if (row.first.isEmpty) continue;
        final fdcId = int.parse(row.first);
        for (final entry in columns.entries) {
          final value = row[header.indexOf(entry.key)];
          final source = official[fdcId]![entry.value];
          if (value.isEmpty) {
            expect(source, isNull, reason: '$fdcId ${entry.key}');
            continue;
          }
          compared++;
          expect(source, isNotNull, reason: '$fdcId ${entry.key}');
          expect(
            double.parse(value),
            double.parse(source!.amount),
            reason: '$fdcId ${entry.key}',
          );
        }
      }
    }
    expect(compared, 6033);
  });

  test('amino-acid numbers and names match the official nutrient file', () {
    final nutrients = {
      for (final row in parseCsv(
        File('$fdcDataDir/nutrient.csv').readAsStringSync(),
      ).skip(1))
        if (row.first.isNotEmpty) int.parse(row[0]): row,
    };
    for (final id in aminoAcidNutrientIds) {
      final row = nutrients[id]!;
      expect(row[2], 'G', reason: '$id unit');
      final number = int.parse(row[3]);
      expect(number, inInclusiveRange(501, 518), reason: '$id');
    }
    // The extractor sees the number and name the source publishes.
    final banana = referenceAminoAcidProfile(173944)!;
    expect(banana.nutrientIds, contains('504'));
    expect(banana.leucine, 0.068);
    expect(banana.fdcDataType, 'SR Legacy');
  });

  test('composition identities hold except where the source disagrees', () {
    // Every value equals the official row, so a finding here is an
    // inconsistency inside the source record, not a transcription error.
    // Closure is only tested when carbohydrate was calculated by difference
    // (derivation NC or unreported); 44 records assume zero or impute it.
    const expectedFindings = {
      // Total RAE 0 while beta-carotene is reported.
      '167889:vitamin_a_rae_below_components',
      // Analytical sugars + starch + fibre exceed carbohydrate by difference.
      '169704:carbohydrate_fractions_within_total_exceeded',
      '170162:carbohydrate_fractions_within_total_exceeded',
      '173905:carbohydrate_fractions_within_total_exceeded',
      '173946:carbohydrate_fractions_within_total_exceeded',
      // Milk sugars exceed carbohydrate by about 5.3%, the mass ratio of
      // lactose monohydrate to anhydrous lactose (360.3 / 342.3).
      '171265:sugars_within_carbohydrate_exceeded',
      '171267:sugars_within_carbohydrate_exceeded',
      '171269:sugars_within_carbohydrate_exceeded',
      // Calculated carbohydrate that no longer closes the proximates.
      '171412:proximate_closure_mismatch',
      '171486:proximate_closure_mismatch',
      '173430:proximate_closure_mismatch',
      '175132:proximate_closure_mismatch',
      // Cider vinegar: acetic acid energy outside the proximates.
      '173469:energy_general_factor_residual',
      // Fatty-acid classes exceed a 0.62 g total lipid.
      '173746:fatty_acids_within_total_lipid_exceeded',
    };
    final findings = <String>{};
    var closureRun = 0;
    final skipped = <String, int>{};
    for (final fdcId in referenceNutrientProfileFoods) {
      final audit = auditCompositionIdentities(
        FoodCompositionIdentityInput(
          recordId: '$fdcId',
          description: '$fdcId',
          values: referenceAttributeValues(fdcId),
          derivationCodes: referenceAttributeDerivationCodes(fdcId),
        ),
      );
      for (final finding in audit.findings) {
        findings.add('$fdcId:${finding.code}');
      }
      if (audit.checksRun.contains('proximate_closure')) closureRun++;
      for (final reason in audit.checksSkipped.values) {
        skipped[reason] = (skipped[reason] ?? 0) + 1;
      }
    }
    expect(findings, expectedFindings);
    expect(closureRun, 236);
    expect(skipped['carbohydrate_assumed_zero'], 32);
    expect(skipped.values.fold<int>(0, (a, b) => a + b), 44);
  });

  test('closure applies to calculated carbohydrate only', () {
    const values = {
      'water_g': 70.0,
      'protein_g': 20.0,
      'fat_g': 5.0,
      'ash_g': 1.0,
      'carbohydrate_by_difference_g': 0.0,
    };
    final assumed = auditCompositionIdentities(
      const FoodCompositionIdentityInput(
        recordId: 'synthetic',
        description: 'synthetic fish',
        values: values,
        derivationCodes: {'carbohydrate_by_difference_g': 'Z'},
      ),
    );
    expect(assumed.checksRun, isNot(contains('proximate_closure')));
    expect(
      assumed.checksSkipped['proximate_closure'],
      'carbohydrate_assumed_zero',
    );
    expect(assumed.findings, isEmpty);
    final calculated = auditCompositionIdentities(
      const FoodCompositionIdentityInput(
        recordId: 'synthetic',
        description: 'synthetic fish',
        values: values,
        derivationCodes: {'carbohydrate_by_difference_g': 'NC'},
      ),
    );
    expect(calculated.findings.single.code, 'proximate_closure_mismatch');
  });

  test('SR Legacy seed foods carry official water, amino acids, portions', () {
    final seedFoods = [
      ...const SeedCatalogImporter().importSeedCatalog().projectedFoods,
      ...const RegionalSeedCatalogImporter()
          .importRegionalSeedCatalog()
          .projectedFoods,
    ];
    final withProfile = seedFoods.where((f) => f.aminoAcidProfile != null);
    expect(withProfile, isNotEmpty);
    for (final food in withProfile) {
      expect(food.aminoAcidProfile!.sourceRefs, [referenceNutrientSourceDocId]);
      expect(food.description, isNot(contains('FNDDS')), reason: food.id);
    }
    for (final food in seedFoods) {
      for (final portion in food.foodPortionEvidence) {
        expect(portion.sourceDocId, referenceNutrientSourceDocId);
        expect(portion.gramWeight, isNotNull);
      }
    }
  });
}
