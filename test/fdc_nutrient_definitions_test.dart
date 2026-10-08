import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/data/datasources/remote/fdc_nutrient_definitions.dart';

import '../tool/reference_food_composition_codegen.dart' show parseCsv;

/// The importer's nutrient definitions must match the official FDC
/// `nutrient.csv` (release 2025-04-24) field for field, and the committed
/// FDC files must not drift from the bytes that were verified.
void main() {
  const dataDir = 'tool/data/fdc_2025-04-24';

  test('committed FDC files keep their verified bytes', () {
    const pinned = {
      'nutrient.csv':
          '226ba937d1a73e8c87bd7fdcdd577524699bef4025c9232ee474b7d3083498ff',
      'foundation_food.csv':
          '7ba5e10af3ce76fc7e3c604afd141255cef7ec301db5c42fdce2b00c3f65391a',
      'food_nutrient_conversion_factor.csv':
          'a04f1b78af0c2e9d3b9ebbae421cbb8ed57ab540ee54c8a1f6702945807bda0a',
      'food_protein_conversion_factor.csv':
          '8299823d83eaafd886f115e3d3764a03db3889d03187c76441973f1873453cbe',
      'food_calorie_conversion_factor_foundation_subset.csv':
          '0d5ec97d4295c32f6b2a4385aebd456541b9489021b5ca11328b277db5b53d61',
      'sr_legacy_food_reference_subset.csv':
          '41a8ba52763b5890e8fdf7350e6775b469d769a77e5482e0c0ce651a4389d20f',
    };
    for (final entry in pinned.entries) {
      final digest = sha256
          .convert(File('$dataDir/${entry.key}').readAsBytesSync())
          .toString();
      expect(digest, entry.value, reason: entry.key);
    }
  });

  test('every definition matches the official nutrient.csv row', () {
    final rows = parseCsv(File('$dataDir/nutrient.csv').readAsStringSync());
    expect(rows.first, ['id', 'name', 'unit_name', 'nutrient_nbr', 'rank']);
    expect(rows.length - 1, 477);
    final byId = {for (final row in rows.skip(1)) int.parse(row[0]): row};
    for (final definition in fdcNutrientDefinitions) {
      final row = byId[definition.id];
      expect(row, isNotNull, reason: '${definition.id}');
      expect(definition.name, row![1], reason: '${definition.id} name');
      expect(definition.unitName, row[2], reason: '${definition.id} unit');
      expect(definition.number, row[3], reason: '${definition.id} number');
    }
  });

  test('ids, numbers and attribute codes are unique', () {
    final ids = fdcNutrientDefinitions.map((d) => d.id).toList();
    final numbers = fdcNutrientDefinitions.map((d) => d.number).toList();
    final codes = fdcNutrientDefinitions.map((d) => d.attributeCode).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(numbers.toSet(), hasLength(numbers.length));
    expect(codes.toSet(), hasLength(codes.length));
    for (final definition in fdcNutrientDefinitions) {
      final suffix = switch (definition.canonicalUnit) {
        'kcal' => '_kcal',
        'kJ' => '_kj',
        'g' => '_g',
        'mg' => '_mg',
        'ug' => '_ug',
        _ => '?',
      };
      expect(
        definition.attributeCode.endsWith(suffix),
        isTrue,
        reason: '${definition.attributeCode} must carry its unit',
      );
    }
  });

  test('resolution uses id, then number, then exact name', () {
    expect(
      resolveFdcNutrient(id: 1050).definition!.attributeCode,
      'carbohydrate_g',
    );
    expect(
      resolveFdcNutrient(number: '205.2').definition!.attributeCode,
      'carbohydrate_g',
    );
    expect(
      resolveFdcNutrient(
        name: 'carbohydrate, by summation',
      ).definition!.attributeCode,
      'carbohydrate_g',
    );
    // "Energy" names two definitions; only the unit can decide.
    expect(resolveFdcNutrient(name: 'Energy').isMapped, isFalse);
    expect(
      resolveFdcNutrient(
        name: 'Energy',
        unitName: 'kcal',
      ).definition!.attributeCode,
      'energy_kcal',
    );
    expect(
      resolveFdcNutrient(
        name: 'Energy',
        unitName: 'kJ',
      ).definition!.attributeCode,
      'energy_kj',
    );
    // A fraction is never mapped as a total.
    expect(
      resolveFdcNutrient(number: '295', name: 'Fiber, soluble').isMapped,
      isFalse,
    );
  });

  test('a mismatched unit is rejected and micrograms are normalized', () {
    final mismatch = resolveFdcNutrient(id: 1008, unitName: 'kJ');
    expect(mismatch.status, FdcNutrientResolutionStatus.unitMismatch);
    expect(mismatch.isMapped, isFalse);
    for (final spelling in ['UG', 'ug', 'µg', 'μg', 'mcg']) {
      expect(
        resolveFdcNutrient(id: 1185, unitName: spelling).isMapped,
        isTrue,
        reason: spelling,
      );
    }
    expect(resolveFdcNutrient(id: 1185, unitName: 'mg').isMapped, isFalse);
  });
}
