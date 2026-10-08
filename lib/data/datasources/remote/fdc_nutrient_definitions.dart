/// USDA FoodData Central nutrient definitions used by the FDC importer.
///
/// Every row is copied from the official FDC `nutrient.csv` (full download,
/// release 2025-04-24, committed verbatim as
/// `tool/data/fdc_2025-04-24/nutrient.csv`) and is checked field-by-field in
/// `test/fdc_nutrient_definitions_test.dart`.
///
/// FDC identifies a nutrient two ways: the database `id` (for example 1050)
/// and the legacy nutrient *number* (for example "205.2"). JSON downloads
/// carry both (`nutrient.id`, `nutrient.number`); the CSV download carries
/// `nutrient_id` in `food_nutrient.csv` and `nutrient_nbr` in `nutrient.csv`.
/// Matching only one of them silently drops values, so resolution tries the
/// id, then the number, then an exact (case-insensitive) name.
///
/// A value is mapped only when its unit equals the definition's unit. Energy
/// in kJ is never stored as kcal, and microgram values are never stored as
/// milligrams.
library;

class FdcNutrientDefinition {
  /// FDC nutrient id (`nutrient.csv` column `id`).
  final int id;

  /// Legacy nutrient number (`nutrient.csv` column `nutrient_nbr`).
  final String number;

  /// FDC nutrient name, verbatim.
  final String name;

  /// FDC unit name, verbatim (`KCAL`, `kJ`, `G`, `MG`, `UG`).
  final String unitName;

  /// Local attribute code. Distinct FDC definitions keep distinct codes so
  /// that, for example, carbohydrate by difference and by summation, or
  /// total dietary fibre by AOAC 985.29-family methods and by AOAC 2011.25,
  /// never overwrite each other.
  final String attributeCode;

  const FdcNutrientDefinition({
    required this.id,
    required this.number,
    required this.name,
    required this.unitName,
    required this.attributeCode,
  });

  /// Canonical unit used for the observation record.
  String get canonicalUnit => switch (unitName.toUpperCase()) {
    'KCAL' => 'kcal',
    'KJ' => 'kJ',
    'G' => 'g',
    'MG' => 'mg',
    'UG' => 'ug',
    _ => unitName,
  };
}

/// Release the definitions were taken from.
const String fdcNutrientDefinitionsRelease = '2025-04-24';

const List<FdcNutrientDefinition> fdcNutrientDefinitions = [
  // Energy. 1008 is the classic SR Legacy/Survey/Branded energy value.
  // Foundation Foods report 2047 (general Atwater factors) and 2048
  // (food-specific Atwater factors) instead.
  FdcNutrientDefinition(
    id: 2047,
    number: '957',
    name: 'Energy (Atwater General Factors)',
    unitName: 'KCAL',
    attributeCode: 'energy_atwater_general_kcal',
  ),
  FdcNutrientDefinition(
    id: 2048,
    number: '958',
    name: 'Energy (Atwater Specific Factors)',
    unitName: 'KCAL',
    attributeCode: 'energy_atwater_specific_kcal',
  ),
  FdcNutrientDefinition(
    id: 1008,
    number: '208',
    name: 'Energy',
    unitName: 'KCAL',
    attributeCode: 'energy_kcal',
  ),
  FdcNutrientDefinition(
    id: 1062,
    number: '268',
    name: 'Energy',
    unitName: 'kJ',
    attributeCode: 'energy_kj',
  ),
  // Proximates.
  FdcNutrientDefinition(
    id: 1051,
    number: '255',
    name: 'Water',
    unitName: 'G',
    attributeCode: 'water_g',
  ),
  FdcNutrientDefinition(
    id: 1002,
    number: '202',
    name: 'Nitrogen',
    unitName: 'G',
    attributeCode: 'nitrogen_g',
  ),
  FdcNutrientDefinition(
    id: 1003,
    number: '203',
    name: 'Protein',
    unitName: 'G',
    attributeCode: 'protein_g',
  ),
  FdcNutrientDefinition(
    id: 1004,
    number: '204',
    name: 'Total lipid (fat)',
    unitName: 'G',
    attributeCode: 'fat_g',
  ),
  FdcNutrientDefinition(
    id: 1085,
    number: '298',
    name: 'Total fat (NLEA)',
    unitName: 'G',
    attributeCode: 'fat_nlea_g',
  ),
  FdcNutrientDefinition(
    id: 1007,
    number: '207',
    name: 'Ash',
    unitName: 'G',
    attributeCode: 'ash_g',
  ),
  FdcNutrientDefinition(
    id: 1005,
    number: '205',
    name: 'Carbohydrate, by difference',
    unitName: 'G',
    attributeCode: 'carbohydrate_by_difference_g',
  ),
  FdcNutrientDefinition(
    id: 1050,
    number: '205.2',
    name: 'Carbohydrate, by summation',
    unitName: 'G',
    attributeCode: 'carbohydrate_g',
  ),
  FdcNutrientDefinition(
    id: 1079,
    number: '291',
    name: 'Fiber, total dietary',
    unitName: 'G',
    attributeCode: 'fiber_g',
  ),
  FdcNutrientDefinition(
    id: 2033,
    number: '293',
    name: 'Total dietary fiber (AOAC 2011.25)',
    unitName: 'G',
    attributeCode: 'fiber_aoac_2011_25_g',
  ),
  FdcNutrientDefinition(
    id: 2000,
    number: '269',
    name: 'Total Sugars',
    unitName: 'G',
    attributeCode: 'sugars_total_g',
  ),
  FdcNutrientDefinition(
    id: 1063,
    number: '269.3',
    name: 'Sugars, Total',
    unitName: 'G',
    attributeCode: 'sugars_total_by_summation_g',
  ),
  FdcNutrientDefinition(
    id: 1235,
    number: '539',
    name: 'Sugars, added',
    unitName: 'G',
    attributeCode: 'sugars_added_g',
  ),
  FdcNutrientDefinition(
    id: 1009,
    number: '209',
    name: 'Starch',
    unitName: 'G',
    attributeCode: 'starch_g',
  ),
  FdcNutrientDefinition(
    id: 1018,
    number: '221',
    name: 'Alcohol, ethyl',
    unitName: 'G',
    attributeCode: 'alcohol_g',
  ),
  FdcNutrientDefinition(
    id: 1025,
    number: '229',
    name: 'Organic acids',
    unitName: 'G',
    attributeCode: 'organic_acids_g',
  ),
  FdcNutrientDefinition(
    id: 1026,
    number: '230',
    name: 'Acetic acid',
    unitName: 'MG',
    attributeCode: 'acetic_acid_mg',
  ),
  FdcNutrientDefinition(
    id: 1041,
    number: '245',
    name: 'Oxalic acid',
    unitName: 'MG',
    attributeCode: 'oxalic_acid_mg',
  ),
  FdcNutrientDefinition(
    id: 1042,
    number: '246',
    name: 'Phytic acid',
    unitName: 'MG',
    attributeCode: 'phytic_acid_mg',
  ),
  FdcNutrientDefinition(
    id: 1057,
    number: '262',
    name: 'Caffeine',
    unitName: 'MG',
    attributeCode: 'caffeine_mg',
  ),
  FdcNutrientDefinition(
    id: 1058,
    number: '263',
    name: 'Theobromine',
    unitName: 'MG',
    attributeCode: 'theobromine_mg',
  ),
  // Minerals.
  FdcNutrientDefinition(
    id: 1087,
    number: '301',
    name: 'Calcium, Ca',
    unitName: 'MG',
    attributeCode: 'calcium_mg',
  ),
  FdcNutrientDefinition(
    id: 1089,
    number: '303',
    name: 'Iron, Fe',
    unitName: 'MG',
    attributeCode: 'iron_mg',
  ),
  FdcNutrientDefinition(
    id: 1141,
    number: '364',
    name: 'Iron, heme',
    unitName: 'MG',
    attributeCode: 'iron_heme_mg',
  ),
  FdcNutrientDefinition(
    id: 1142,
    number: '365',
    name: 'Iron, non-heme',
    unitName: 'MG',
    attributeCode: 'iron_non_heme_mg',
  ),
  FdcNutrientDefinition(
    id: 1090,
    number: '304',
    name: 'Magnesium, Mg',
    unitName: 'MG',
    attributeCode: 'magnesium_mg',
  ),
  FdcNutrientDefinition(
    id: 1091,
    number: '305',
    name: 'Phosphorus, P',
    unitName: 'MG',
    attributeCode: 'phosphorus_mg',
  ),
  FdcNutrientDefinition(
    id: 1092,
    number: '306',
    name: 'Potassium, K',
    unitName: 'MG',
    attributeCode: 'potassium_mg',
  ),
  FdcNutrientDefinition(
    id: 1093,
    number: '307',
    name: 'Sodium, Na',
    unitName: 'MG',
    attributeCode: 'sodium_mg',
  ),
  FdcNutrientDefinition(
    id: 1095,
    number: '309',
    name: 'Zinc, Zn',
    unitName: 'MG',
    attributeCode: 'zinc_mg',
  ),
  FdcNutrientDefinition(
    id: 1098,
    number: '312',
    name: 'Copper, Cu',
    unitName: 'MG',
    attributeCode: 'copper_mg',
  ),
  FdcNutrientDefinition(
    id: 1100,
    number: '314',
    name: 'Iodine, I',
    unitName: 'UG',
    attributeCode: 'iodine_ug',
  ),
  FdcNutrientDefinition(
    id: 1101,
    number: '315',
    name: 'Manganese, Mn',
    unitName: 'MG',
    attributeCode: 'manganese_mg',
  ),
  FdcNutrientDefinition(
    id: 1103,
    number: '317',
    name: 'Selenium, Se',
    unitName: 'UG',
    attributeCode: 'selenium_ug',
  ),
  // Vitamins.
  FdcNutrientDefinition(
    id: 1105,
    number: '319',
    name: 'Retinol',
    unitName: 'UG',
    attributeCode: 'retinol_ug',
  ),
  FdcNutrientDefinition(
    id: 1106,
    number: '320',
    name: 'Vitamin A, RAE',
    unitName: 'UG',
    attributeCode: 'vitamin_a_rae_ug',
  ),
  FdcNutrientDefinition(
    id: 1107,
    number: '321',
    name: 'Carotene, beta',
    unitName: 'UG',
    attributeCode: 'beta_carotene_ug',
  ),
  FdcNutrientDefinition(
    id: 1109,
    number: '323',
    name: 'Vitamin E (alpha-tocopherol)',
    unitName: 'MG',
    attributeCode: 'vitamin_e_mg',
  ),
  FdcNutrientDefinition(
    id: 1114,
    number: '328',
    name: 'Vitamin D (D2 + D3)',
    unitName: 'UG',
    attributeCode: 'vitamin_d_ug',
  ),
  FdcNutrientDefinition(
    id: 1162,
    number: '401',
    name: 'Vitamin C, total ascorbic acid',
    unitName: 'MG',
    attributeCode: 'vitamin_c_mg',
  ),
  FdcNutrientDefinition(
    id: 1165,
    number: '404',
    name: 'Thiamin',
    unitName: 'MG',
    attributeCode: 'thiamin_mg',
  ),
  FdcNutrientDefinition(
    id: 1166,
    number: '405',
    name: 'Riboflavin',
    unitName: 'MG',
    attributeCode: 'riboflavin_mg',
  ),
  FdcNutrientDefinition(
    id: 1167,
    number: '406',
    name: 'Niacin',
    unitName: 'MG',
    attributeCode: 'niacin_mg',
  ),
  FdcNutrientDefinition(
    id: 1170,
    number: '410',
    name: 'Pantothenic acid',
    unitName: 'MG',
    attributeCode: 'pantothenic_acid_mg',
  ),
  FdcNutrientDefinition(
    id: 1175,
    number: '415',
    name: 'Vitamin B-6',
    unitName: 'MG',
    attributeCode: 'vitamin_b6_mg',
  ),
  FdcNutrientDefinition(
    id: 1177,
    number: '417',
    name: 'Folate, total',
    unitName: 'UG',
    attributeCode: 'folate_total_ug',
  ),
  FdcNutrientDefinition(
    id: 1178,
    number: '418',
    name: 'Vitamin B-12',
    unitName: 'UG',
    attributeCode: 'vitamin_b12_ug',
  ),
  FdcNutrientDefinition(
    id: 1180,
    number: '421',
    name: 'Choline, total',
    unitName: 'MG',
    attributeCode: 'choline_mg',
  ),
  FdcNutrientDefinition(
    id: 1185,
    number: '430',
    name: 'Vitamin K (phylloquinone)',
    unitName: 'UG',
    attributeCode: 'vitamin_k1_ug',
  ),
  FdcNutrientDefinition(
    id: 1190,
    number: '435',
    name: 'Folate, DFE',
    unitName: 'UG',
    attributeCode: 'folate_dfe_ug',
  ),
  // Lipid classes. Fatty-acid sums are expressed as fatty acids, so their
  // sum can never exceed total lipid.
  FdcNutrientDefinition(
    id: 1253,
    number: '601',
    name: 'Cholesterol',
    unitName: 'MG',
    attributeCode: 'cholesterol_mg',
  ),
  FdcNutrientDefinition(
    id: 1257,
    number: '605',
    name: 'Fatty acids, total trans',
    unitName: 'G',
    attributeCode: 'fatty_acids_trans_g',
  ),
  FdcNutrientDefinition(
    id: 1258,
    number: '606',
    name: 'Fatty acids, total saturated',
    unitName: 'G',
    attributeCode: 'fatty_acids_saturated_g',
  ),
  FdcNutrientDefinition(
    id: 1292,
    number: '645',
    name: 'Fatty acids, total monounsaturated',
    unitName: 'G',
    attributeCode: 'fatty_acids_monounsaturated_g',
  ),
  FdcNutrientDefinition(
    id: 1293,
    number: '646',
    name: 'Fatty acids, total polyunsaturated',
    unitName: 'G',
    attributeCode: 'fatty_acids_polyunsaturated_g',
  ),
];

final Map<int, FdcNutrientDefinition> _definitionsById = {
  for (final definition in fdcNutrientDefinitions) definition.id: definition,
};

final Map<String, FdcNutrientDefinition> _definitionsByNumber = {
  for (final definition in fdcNutrientDefinitions)
    definition.number: definition,
};

/// Names shared by more than one definition (the two "Energy" rows) cannot be
/// resolved by name alone; the unit decides between them.
final Map<String, List<FdcNutrientDefinition>> _definitionsByName = () {
  final byName = <String, List<FdcNutrientDefinition>>{};
  for (final definition in fdcNutrientDefinitions) {
    byName.putIfAbsent(definition.name.toLowerCase(), () => []).add(definition);
  }
  return byName;
}();

/// Normalizes FDC unit spellings (`KCAL`/`kcal`, `G`/`g`, `UG`/`µg`/`mcg`).
String? normalizeFdcUnit(String? unit) {
  final text = (unit ?? '').trim();
  if (text.isEmpty) return null;
  final lower = text.toLowerCase();
  return switch (lower) {
    'kcal' => 'KCAL',
    'kj' => 'KJ',
    'g' => 'G',
    'mg' => 'MG',
    'ug' || 'µg' || 'μg' || 'mcg' => 'UG',
    _ => text.toUpperCase(),
  };
}

/// Why a source nutrient row was not mapped.
enum FdcNutrientResolutionStatus { mapped, unknownNutrient, unitMismatch }

class FdcNutrientResolution {
  final FdcNutrientResolutionStatus status;
  final FdcNutrientDefinition? definition;
  final String? observedUnit;

  const FdcNutrientResolution._(
    this.status, {
    this.definition,
    this.observedUnit,
  });

  bool get isMapped => status == FdcNutrientResolutionStatus.mapped;
}

/// Resolves one FDC nutrient reference to a definition.
///
/// [id] is the FDC nutrient id, [number] the legacy nutrient number and
/// [name] the nutrient name; any may be absent. When [unitName] is present
/// it must match the definition, otherwise the row is rejected rather than
/// converted or guessed.
FdcNutrientResolution resolveFdcNutrient({
  int? id,
  String? number,
  String? name,
  String? unitName,
}) {
  final observedUnit = normalizeFdcUnit(unitName);
  FdcNutrientDefinition? definition = id == null ? null : _definitionsById[id];
  final trimmedNumber = (number ?? '').trim();
  if (definition == null && trimmedNumber.isNotEmpty) {
    definition = _definitionsByNumber[trimmedNumber];
  }
  if (definition == null) {
    final candidates =
        _definitionsByName[(name ?? '').trim().toLowerCase()] ?? const [];
    if (candidates.length == 1) {
      definition = candidates.single;
    } else if (candidates.length > 1 && observedUnit != null) {
      for (final candidate in candidates) {
        if (normalizeFdcUnit(candidate.unitName) == observedUnit) {
          definition = candidate;
          break;
        }
      }
    }
  }
  if (definition == null) {
    return FdcNutrientResolution._(
      FdcNutrientResolutionStatus.unknownNutrient,
      observedUnit: observedUnit,
    );
  }
  if (observedUnit != null &&
      observedUnit != normalizeFdcUnit(definition.unitName)) {
    return FdcNutrientResolution._(
      FdcNutrientResolutionStatus.unitMismatch,
      definition: definition,
      observedUnit: observedUnit,
    );
  }
  return FdcNutrientResolution._(
    FdcNutrientResolutionStatus.mapped,
    definition: definition,
    observedUnit: observedUnit,
  );
}
