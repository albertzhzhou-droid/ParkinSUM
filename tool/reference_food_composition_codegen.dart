// Code generator for lib/core/constants/reference_food_composition_table.dart.
//
// Inputs (both committed):
// - tool/data/usda_sr_legacy_reference_subset_2018.csv: verbatim USDA SR
//   Legacy (April 2018) rows, per 100 g edible portion, retrieved through the
//   Hugging Face mirror ULM-DS-Lab/food-composition-matrix
//   (usda_sr_legacy_2018_wide.csv), which pivots FDC food_nutrient.csv
//   without imputation.
// - tool/data/reference_food_curation.json: names, group, state, texture.
//
// The generator never edits a nutrient value.
// test/reference_food_composition_table_test.dart re-parses both inputs and
// fails if any generated field differs from the published value.

import 'dart:convert';

const referenceSubsetCsvPath =
    'tool/data/usda_sr_legacy_reference_subset_2018.csv';
const referenceCurationJsonPath = 'tool/data/reference_food_curation.json';
const referenceTableDartPath =
    'lib/core/constants/reference_food_composition_table.dart';

const _expectedHeader = <String>[
  'fdc_id',
  'description',
  'Energy',
  'Protein',
  'Fat',
  'Carbohydrate',
  'Fiber',
  'Calcium',
  'Phosphorus',
  'Iron',
  'Sodium',
  'Potassium',
  'Copper',
  'Zinc',
  'Retinol',
  'Beta_Carotene',
  'Thiamine',
  'Riboflavin',
  'Niacin',
  'Vitamin_C',
];

const _numericFields = <String, String>{
  'Energy': 'energyKcal',
  'Protein': 'proteinG',
  'Fat': 'fatG',
  'Carbohydrate': 'carbohydrateByDifferenceG',
  'Fiber': 'fiberG',
  'Calcium': 'calciumMg',
  'Phosphorus': 'phosphorusMg',
  'Iron': 'ironMg',
  'Sodium': 'sodiumMg',
  'Potassium': 'potassiumMg',
  'Copper': 'copperMg',
  'Zinc': 'zincMg',
  'Retinol': 'retinolUg',
  'Beta_Carotene': 'betaCaroteneUg',
  'Thiamine': 'thiaminMg',
  'Riboflavin': 'riboflavinMg',
  'Niacin': 'niacinMg',
  'Vitamin_C': 'vitaminCMg',
};

const _groupWireToDart = <String, String>{
  'fruit': 'fruit',
  'vegetable': 'vegetable',
  'legume': 'legume',
  'grain': 'grain',
  'dairy': 'dairy',
  'egg': 'egg',
  'meat': 'meat',
  'poultry': 'poultry',
  'fish_seafood': 'fishSeafood',
  'nut_seed': 'nutSeed',
  'fat_oil': 'fatOil',
  'beverage': 'beverage',
  'alcoholic_beverage': 'alcoholicBeverage',
  'sweetener_confection': 'sweetenerConfection',
  'condiment': 'condiment',
  'protein_supplement': 'proteinSupplement',
};

/// RFC 4180 parser for the subset file (quoted fields, doubled quotes, CRLF
/// or LF line endings). Throws on malformed input instead of guessing.
List<List<String>> parseCsv(String text) {
  final rows = <List<String>>[];
  var field = StringBuffer();
  var row = <String>[];
  var inQuotes = false;
  var i = 0;
  void endField() {
    row.add(field.toString());
    field = StringBuffer();
  }

  void endRow() {
    endField();
    rows.add(row);
    row = <String>[];
  }

  while (i < text.length) {
    final ch = text[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
        i++;
        continue;
      }
      field.write(ch);
      i++;
      continue;
    }
    if (ch == '"') {
      if (field.isNotEmpty) {
        throw FormatException('Quote inside unquoted field', text, i);
      }
      inQuotes = true;
    } else if (ch == ',') {
      endField();
    } else if (ch == '\r') {
      // Tolerate CRLF; a bare CR is treated as a line break too.
      endRow();
      if (i + 1 < text.length && text[i + 1] == '\n') i++;
    } else if (ch == '\n') {
      endRow();
    } else {
      field.write(ch);
    }
    i++;
  }
  if (inQuotes) throw const FormatException('Unterminated quoted field');
  if (field.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

/// Parsed, validated subset row (strings preserved exactly as published).
class SubsetRow {
  final int fdcId;
  final String description;
  final Map<String, String> rawNumbers;

  const SubsetRow(this.fdcId, this.description, this.rawNumbers);

  double? number(String column) {
    final raw = rawNumbers[column]!;
    if (raw.isEmpty) return null;
    return double.parse(raw);
  }
}

List<SubsetRow> parseSubsetRows(String csvText) {
  final table = parseCsv(csvText);
  if (table.isEmpty) throw const FormatException('Empty subset file');
  final header = table.first;
  if (header.join(',') != _expectedHeader.join(',')) {
    throw FormatException('Unexpected header: ${header.join(',')}');
  }
  final seen = <int>{};
  final rows = <SubsetRow>[];
  for (final cells in table.skip(1)) {
    if (cells.length == 1 && cells.single.isEmpty) continue;
    if (cells.length != header.length) {
      throw FormatException('Row has ${cells.length} cells: ${cells.first}');
    }
    final fdcId = int.parse(cells[0]);
    if (!seen.add(fdcId)) throw FormatException('Duplicate fdc_id $fdcId');
    final numbers = <String, String>{};
    for (var c = 2; c < header.length; c++) {
      final raw = cells[c].trim();
      if (raw.isNotEmpty) {
        final value = double.parse(raw);
        if (!value.isFinite || value < 0) {
          throw FormatException('Invalid ${header[c]} for $fdcId: $raw');
        }
      }
      numbers[header[c]] = raw;
    }
    rows.add(SubsetRow(fdcId, cells[1], numbers));
  }
  return rows;
}

String _dartString(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$');
  return "'$escaped'";
}

String _dartNumber(String raw) {
  if (raw.isEmpty) return 'null';
  final value = double.parse(raw);
  // Shortest round-trip representation of the published decimal.
  final text = value.toString();
  return text.contains('.') || text.contains('e') ? text : '$text.0';
}

/// Renders the generated Dart table. Output is deterministic (CSV order).
String renderReferenceTable({
  required String csvText,
  required String curationJsonText,
}) {
  final rows = parseSubsetRows(csvText);
  final curation =
      (jsonDecode(curationJsonText) as Map<String, dynamic>)['foods']
          as Map<String, dynamic>;
  final missing = rows
      .where((row) => !curation.containsKey('${row.fdcId}'))
      .map((row) => row.fdcId)
      .toList();
  if (missing.isNotEmpty) {
    throw FormatException('Curation missing for fdc_id(s): $missing');
  }
  final extra = curation.keys
      .where((key) => !rows.any((row) => '${row.fdcId}' == key))
      .toList();
  if (extra.isNotEmpty) {
    throw FormatException('Curation has unknown fdc_id(s): $extra');
  }

  final out = StringBuffer()
    ..writeln('// GENERATED FILE — DO NOT EDIT BY HAND.')
    ..writeln('// Source: $referenceSubsetCsvPath')
    ..writeln('// Curation: $referenceCurationJsonPath')
    ..writeln(
      '// Regenerate: dart run tool/generate_reference_food_composition_table.dart',
    )
    ..writeln('//')
    ..writeln(
      '// USDA ARS, FoodData Central, SR Legacy (April 2018); public domain.',
    )
    ..writeln(
      '// Values are per 100 g edible portion and reproduced verbatim; null',
    )
    ..writeln('// means the source reported no value (never an assumed zero).')
    ..writeln()
    ..writeln("import '../../domain/entities/reference_food_composition.dart';")
    ..writeln()
    ..writeln(
      'const String referenceFoodCompositionSourceTitle =\n'
      "    'USDA FoodData Central SR Legacy (April 2018), verbatim subset';",
    )
    ..writeln()
    ..writeln(
      'const List<ReferenceFoodCompositionRow> referenceFoodCompositionRows =',
    )
    ..writeln('    <ReferenceFoodCompositionRow>[');
  for (final row in rows) {
    final meta = curation['${row.fdcId}'] as Map<String, dynamic>;
    final group = _groupWireToDart[meta['group']];
    if (group == null) {
      throw FormatException('Unknown group ${meta['group']} (${row.fdcId})');
    }
    final texture = meta['texture'] as String?;
    if (texture != null && texture != 'liquid' && texture != 'soft') {
      throw FormatException('Unknown texture $texture (${row.fdcId})');
    }
    out
      ..writeln('      ReferenceFoodCompositionRow(')
      ..writeln('        fdcId: ${row.fdcId},')
      ..writeln('        sourceDescription: ${_dartString(row.description)},')
      ..writeln('        nameEn: ${_dartString(meta['en'] as String)},')
      ..writeln('        nameZh: ${_dartString(meta['zh'] as String)},')
      ..writeln('        group: ReferenceFoodGroup.$group,')
      ..writeln(
        '        preparationState: ${_dartString(meta['state'] as String)},',
      )
      ..writeln(
        '        textureClass: ${texture == null ? 'null' : _dartString(texture)},',
      );
    for (final entry in _numericFields.entries) {
      out.writeln(
        '        ${entry.value}: ${_dartNumber(row.rawNumbers[entry.key]!)},',
      );
    }
    out.writeln('      ),');
  }
  out.writeln('    ];');
  return out.toString();
}
