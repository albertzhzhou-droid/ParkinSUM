// Code generator for lib/core/constants/reference_food_nutrient_profile_table.dart.
//
// Inputs (committed, verbatim from the USDA FoodData Central full download of
// 2025-04-24, read through the Hugging Face mirror
// yvfu/FoodData_Central_csv_2025-04-24):
// - tool/data/fdc_2025-04-24/food_nutrient_sr_legacy_subset.csv: every
//   food_nutrient.csv row of the SR Legacy reference and seed foods, copied
//   as whole lines in source order.
// - tool/data/fdc_2025-04-24/food_portion_sr_legacy_subset.csv: their
//   food_portion.csv rows.
// - tool/data/fdc_2025-04-24/food_nutrient_derivation.csv: the complete
//   derivation code table.
//
// The generator keeps nutrient rows the app maps (the FDC nutrient
// definitions plus the 18 amino acids) and never edits a field.
// test/reference_food_nutrient_profile_test.dart re-parses the inputs and
// fails if any generated field differs.

import 'package:parkinsum_companion/data/datasources/remote/fdc_nutrient_definitions.dart';

import 'reference_food_composition_codegen.dart' show parseCsv;

const fdcDataDir = 'tool/data/fdc_2025-04-24';
const srNutrientSubsetPath = '$fdcDataDir/food_nutrient_sr_legacy_subset.csv';
const srPortionSubsetPath = '$fdcDataDir/food_portion_sr_legacy_subset.csv';
const fdcDerivationPath = '$fdcDataDir/food_nutrient_derivation.csv';
const referenceNutrientProfileTablePath =
    'lib/core/constants/reference_food_nutrient_profile_table.dart';

/// FDC nutrient ids of the 18 amino acids (legacy numbers 501-518).
const aminoAcidNutrientIds = <int>{
  1210, 1211, 1212, 1213, 1214, 1215, 1216, 1217, 1218, //
  1219, 1220, 1221, 1222, 1223, 1224, 1225, 1226, 1227,
};

/// Nutrient ids carried into the generated table.
Set<int> mappedNutrientIds() => {
  for (final definition in fdcNutrientDefinitions) definition.id,
  ...aminoAcidNutrientIds,
};

const _nutrientHeader = <String>[
  'id',
  'fdc_id',
  'nutrient_id',
  'amount',
  'data_points',
  'derivation_id',
  'min',
  'max',
  'median',
  'loq',
  'footnote',
  'min_year_acquired',
  'percent_daily_value',
];

const _portionHeader = <String>[
  'id',
  'fdc_id',
  'seq_num',
  'amount',
  'measure_unit_id',
  'portion_description',
  'modifier',
  'gram_weight',
  'data_points',
  'footnote',
  'min_year_acquired',
];

final RegExp _decimal = RegExp(r'^-?\d+(\.\d+)?$');
final RegExp _integer = RegExp(r'^\d+$');

/// One parsed nutrient row, as text, exactly as published.
class NutrientCsvRow {
  final List<String> fields;
  const NutrientCsvRow(this.fields);
  String get id => fields[0];
  String get fdcId => fields[1];
  String get nutrientId => fields[2];
  String get amount => fields[3];
  String get dataPoints => fields[4];
  String get derivationId => fields[5];
  String get min => fields[6];
  String get max => fields[7];
  String get median => fields[8];
  String get minYearAcquired => fields[11];
}

List<NutrientCsvRow> parseNutrientSubset(String text) {
  final rows = parseCsv(text);
  if (rows.isEmpty || rows.first.join(',') != _nutrientHeader.join(',')) {
    throw const FormatException('Unexpected food_nutrient.csv header');
  }
  final parsed = <NutrientCsvRow>[];
  for (final row in rows.skip(1)) {
    if (row.length == 1 && row.first.isEmpty) continue;
    if (row.length != _nutrientHeader.length) {
      throw FormatException('Row has ${row.length} fields', row.join(','));
    }
    if (!_decimal.hasMatch(row[3])) {
      throw FormatException('Non-numeric amount', row.join(','));
    }
    if (row[9].isNotEmpty || row[10].isNotEmpty || row[12].isNotEmpty) {
      // SR Legacy rows carry no LOQ, footnote or %DV; the table would drop
      // them silently, so refuse instead.
      throw FormatException('Unexpected loq/footnote/%DV', row.join(','));
    }
    parsed.add(NutrientCsvRow(row));
  }
  return parsed;
}

List<List<String>> parsePortionSubset(String text) {
  final rows = parseCsv(text);
  if (rows.isEmpty || rows.first.join(',') != _portionHeader.join(',')) {
    throw const FormatException('Unexpected food_portion.csv header');
  }
  final parsed = <List<String>>[];
  for (final row in rows.skip(1)) {
    if (row.length == 1 && row.first.isEmpty) continue;
    if (row.length != _portionHeader.length) {
      throw FormatException('Row has ${row.length} fields', row.join(','));
    }
    if (row[9].isNotEmpty) {
      throw FormatException('Unexpected portion footnote', row.join(','));
    }
    parsed.add(row);
  }
  return parsed;
}

List<List<String>> parseDerivations(String text) {
  final rows = parseCsv(text);
  if (rows.isEmpty || rows.first.join(',') != 'id,code,description') {
    throw const FormatException('Unexpected derivation header');
  }
  return [
    for (final row in rows.skip(1))
      if (!(row.length == 1 && row.first.isEmpty)) row,
  ];
}

String _num(String value) {
  if (value.isEmpty) return 'null';
  if (!_decimal.hasMatch(value)) {
    throw FormatException('Not a plain decimal', value);
  }
  return value;
}

String _int(String value) {
  if (value.isEmpty) return 'null';
  if (!_integer.hasMatch(value)) {
    throw FormatException('Not an integer', value);
  }
  return value;
}

String _dartString(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$');
  return "'$escaped'";
}

String _args(List<String> required, List<String> optional) {
  final trimmed = [...optional];
  while (trimmed.isNotEmpty && trimmed.last == 'null') {
    trimmed.removeLast();
  }
  return [...required, ...trimmed].join(', ');
}

String renderReferenceNutrientProfileTable({
  required String nutrientCsvText,
  required String portionCsvText,
  required String derivationCsvText,
}) {
  final mapped = mappedNutrientIds();
  final nutrients = parseNutrientSubset(
    nutrientCsvText,
  ).where((row) => mapped.contains(int.parse(row.nutrientId)));
  final portions = parsePortionSubset(portionCsvText);
  final derivations = parseDerivations(derivationCsvText);

  final out = StringBuffer()
    ..writeln(
      '// GENERATED by tool/generate_reference_food_nutrient_profile_table.dart.',
    )
    ..writeln('// Do not edit by hand. Source: USDA FoodData Central full')
    ..writeln('// download, release 2025-04-24 (public domain), files in')
    ..writeln('// tool/data/fdc_2025-04-24/. Values are per 100 g edible')
    ..writeln('// portion and are copied without change.')
    ..writeln()
    ..writeln(
      "import '../../domain/entities/reference_food_nutrient_profile.dart';",
    )
    ..writeln()
    ..writeln("const referenceNutrientRelease = '2025-04-24';")
    ..writeln()
    ..writeln('const List<FdcDerivationCode> fdcDerivationCodes = [');
  for (final row in derivations) {
    out.writeln(
      '  FdcDerivationCode(${_int(row[0])}, ${_dartString(row[1])}, '
      '${_dartString(row[2])}),',
    );
  }
  out
    ..writeln('];')
    ..writeln()
    ..writeln(
      'const List<ReferenceNutrientRecord> referenceNutrientRecords = [',
    );
  for (final row in nutrients) {
    out.writeln(
      '  ReferenceNutrientRecord(${_args([_int(row.id), _int(row.fdcId), _int(row.nutrientId), _num(row.amount)], [_int(row.dataPoints), _int(row.derivationId), _num(row.min), _num(row.max), _num(row.median), _int(row.minYearAcquired)])}),',
    );
  }
  out
    ..writeln('];')
    ..writeln()
    ..writeln('const List<ReferencePortionRecord> referencePortionRecords = [');
  for (final row in portions) {
    out.writeln(
      '  ReferencePortionRecord(${_args([_int(row[0]), _int(row[1]), _int(row[2]), _num(row[3]), _int(row[4]), _dartString(row[5]), _dartString(row[6]), _num(row[7])], [_int(row[8]), _int(row[10])])}),',
    );
  }
  out.writeln('];');
  return out.toString();
}
