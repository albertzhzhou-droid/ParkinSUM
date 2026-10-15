// Code generator for lib/core/constants/seed_food_composition_table.dart.
//
// Inputs (all committed):
// - tool/data/seed_food_sources.json: seed id -> FDC record (or a reason).
// - tool/data/usda_sr_legacy_seed_subset_2018.csv: verbatim SR Legacy rows.
// - tool/data/fndds_2017_2018/food_seed_subset.csv and
//   food_nutrient_seed_subset.csv: verbatim FNDDS 2017-2018 rows.
//
// The generator never edits a value. test/seed_food_composition_test.dart
// re-parses the inputs and fails if any generated field differs.

import 'dart:convert';

import 'reference_food_composition_codegen.dart' show parseCsv;

const seedSourcesJsonPath = 'tool/data/seed_food_sources.json';
const seedSrSubsetPath = 'tool/data/usda_sr_legacy_seed_subset_2018.csv';
const seedFnddsFoodPath = 'tool/data/fndds_2017_2018/food_seed_subset.csv';
const seedFnddsNutrientPath =
    'tool/data/fndds_2017_2018/food_nutrient_seed_subset.csv';
const seedTableDartPath = 'lib/core/constants/seed_food_composition_table.dart';

/// FNDDS nutrient ids for the composition fields.
const fnddsNutrientIds = <String, String>{
  'energyKcal': '1008',
  'proteinG': '1003',
  'fatG': '1004',
  'carbohydrateByDifferenceG': '1005',
  'fiberG': '1079',
  'sodiumMg': '1093',
  'waterG': '1051',
};

/// SR Legacy extract columns for the composition fields.
const srColumns = <String, String>{
  'energyKcal': 'Energy',
  'proteinG': 'Protein',
  'fatG': 'Fat',
  'carbohydrateByDifferenceG': 'Carbohydrate',
  'fiberG': 'Fiber',
  'sodiumMg': 'Sodium',
};

class SeedSourceRecord {
  final String source;
  final int fdcId;
  final String description;
  final Map<String, double?> values;

  const SeedSourceRecord(
    this.source,
    this.fdcId,
    this.description,
    this.values,
  );
}

double? _number(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  return double.parse(trimmed);
}

Map<int, SeedSourceRecord> parseSrSubset(String csvText) {
  final table = parseCsv(csvText);
  final header = table.first;
  final records = <int, SeedSourceRecord>{};
  for (final row in table.skip(1)) {
    final fdcId = int.parse(row[0]);
    records[fdcId] = SeedSourceRecord('SR', fdcId, row[1], {
      for (final entry in srColumns.entries)
        entry.key: _number(row[header.indexOf(entry.value)]),
      'waterG': null,
    });
  }
  return records;
}

Map<int, SeedSourceRecord> parseFnddsSubset(
  String foodCsv,
  String nutrientCsv,
) {
  final descriptions = {
    for (final row in parseCsv(foodCsv).skip(1)) int.parse(row[0]): row[2],
  };
  final amounts = <int, Map<String, String>>{};
  for (final row in parseCsv(nutrientCsv).skip(1)) {
    amounts.putIfAbsent(int.parse(row[1]), () => {})[row[2]] = row[3];
  }
  return {
    for (final entry in descriptions.entries)
      entry.key: SeedSourceRecord('FNDDS', entry.key, entry.value, {
        for (final field in fnddsNutrientIds.entries)
          field.key: _number(amounts[entry.key]?[field.value] ?? ''),
      }),
  };
}

String _dartString(String value) =>
    "'${value.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$')}'";

String _dartDouble(double? value) => value == null ? 'null' : '$value';

String renderSeedTable({
  required String sourcesJson,
  required String srCsv,
  required String fnddsFoodCsv,
  required String fnddsNutrientCsv,
}) {
  final foods =
      (jsonDecode(sourcesJson) as Map<String, dynamic>)['foods']
          as Map<String, dynamic>;
  final sr = parseSrSubset(srCsv);
  final fndds = parseFnddsSubset(fnddsFoodCsv, fnddsNutrientCsv);
  final matched = StringBuffer();
  final unmatched = StringBuffer();
  for (final entry in foods.entries) {
    final spec = entry.value as Map<String, dynamic>;
    final source = spec['source'] as String?;
    if (source == null) {
      unmatched.writeln(
        '  ${_dartString(entry.key)}: ${_dartString(spec['reason'] as String)},',
      );
      continue;
    }
    final fdcId = spec['fdc_id'] as int;
    final record = (source == 'SR' ? sr : fndds)[fdcId];
    if (record == null) {
      throw StateError('${entry.key}: $source $fdcId not in subset');
    }
    final note = spec['note'] as String?;
    matched
      ..writeln('  ${_dartString(entry.key)}: SeedFoodComposition(')
      ..writeln(
        '    source: SeedCompositionSource.'
        '${source == 'SR' ? 'srLegacy2018' : 'fndds20172018'},',
      )
      ..writeln('    fdcId: $fdcId,')
      ..writeln('    sourceDescription: ${_dartString(record.description)},')
      ..writeln('    match: SeedCompositionMatch.${spec['match']},')
      ..writeln('    note: ${note == null ? 'null' : _dartString(note)},');
    for (final field in fnddsNutrientIds.keys) {
      matched.writeln('    $field: ${_dartDouble(record.values[field])},');
    }
    matched.writeln('  ),');
  }
  return '''
// GENERATED FILE - DO NOT EDIT BY HAND.
// Sources: $seedSourcesJsonPath, $seedSrSubsetPath,
//   $seedFnddsFoodPath, $seedFnddsNutrientPath
// Regenerate: dart run tool/generate_seed_food_composition_table.dart

import '../../domain/entities/seed_food_composition.dart';

/// Per-100 g composition of seed catalog foods, copied from USDA FDC.
const Map<String, SeedFoodComposition> seedFoodCompositions = {
$matched};

/// Seed catalog foods with no defensible authoritative record; their
/// nutrient values are unknown.
const Map<String, String> seedFoodUnmatchedReasons = {
$unmatched};
''';
}
