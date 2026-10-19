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
    'IU' => 'IU',
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
  // Individual sugars. Their sum stays within total sugars (2000).
  FdcNutrientDefinition(
    id: 1010,
    number: '210',
    name: 'Sucrose',
    unitName: 'G',
    attributeCode: 'sucrose_g',
  ),
  FdcNutrientDefinition(
    id: 1011,
    number: '211',
    name: 'Glucose',
    unitName: 'G',
    attributeCode: 'glucose_g',
  ),
  FdcNutrientDefinition(
    id: 1012,
    number: '212',
    name: 'Fructose',
    unitName: 'G',
    attributeCode: 'fructose_g',
  ),
  FdcNutrientDefinition(
    id: 1013,
    number: '213',
    name: 'Lactose',
    unitName: 'G',
    attributeCode: 'lactose_g',
  ),
  FdcNutrientDefinition(
    id: 1014,
    number: '214',
    name: 'Maltose',
    unitName: 'G',
    attributeCode: 'maltose_g',
  ),
  FdcNutrientDefinition(
    id: 1075,
    number: '287',
    name: 'Galactose',
    unitName: 'G',
    attributeCode: 'galactose_g',
  ),
  // Minerals and other constituents.
  FdcNutrientDefinition(
    id: 1099,
    number: '313',
    name: 'Fluoride, F',
    unitName: 'UG',
    attributeCode: 'fluoride_ug',
  ),
  FdcNutrientDefinition(
    id: 1198,
    number: '454',
    name: 'Betaine',
    unitName: 'MG',
    attributeCode: 'betaine_mg',
  ),
  // Folate forms. Total folate = food folate + folic acid; DFE = food folate
  // + 1.7 × folic acid (Institute of Medicine 1998).
  FdcNutrientDefinition(
    id: 1186,
    number: '431',
    name: 'Folic acid',
    unitName: 'UG',
    attributeCode: 'folic_acid_ug',
  ),
  FdcNutrientDefinition(
    id: 1187,
    number: '432',
    name: 'Folate, food',
    unitName: 'UG',
    attributeCode: 'folate_food_ug',
  ),
  // Vitamin B-12 and vitamin E added during fortification are parts of the
  // totals.
  FdcNutrientDefinition(
    id: 1246,
    number: '578',
    name: 'Vitamin B-12, added',
    unitName: 'UG',
    attributeCode: 'vitamin_b12_added_ug',
  ),
  FdcNutrientDefinition(
    id: 1242,
    number: '573',
    name: 'Vitamin E, added',
    unitName: 'MG',
    attributeCode: 'vitamin_e_added_mg',
  ),
  // Provitamin A and other carotenoids. RAE = retinol + β-carotene/12 +
  // (α-carotene + β-cryptoxanthin)/24 (Institute of Medicine 2001); vitamin A
  // IU = retinol/0.3 + β-carotene/0.6 + (α-carotene + β-cryptoxanthin)/1.2.
  FdcNutrientDefinition(
    id: 1108,
    number: '322',
    name: 'Carotene, alpha',
    unitName: 'UG',
    attributeCode: 'alpha_carotene_ug',
  ),
  FdcNutrientDefinition(
    id: 1120,
    number: '334',
    name: 'Cryptoxanthin, beta',
    unitName: 'UG',
    attributeCode: 'beta_cryptoxanthin_ug',
  ),
  FdcNutrientDefinition(
    id: 1104,
    number: '318',
    name: 'Vitamin A, IU',
    unitName: 'IU',
    attributeCode: 'vitamin_a_iu',
  ),
  FdcNutrientDefinition(
    id: 1122,
    number: '337',
    name: 'Lycopene',
    unitName: 'UG',
    attributeCode: 'lycopene_ug',
  ),
  FdcNutrientDefinition(
    id: 1123,
    number: '338',
    name: 'Lutein + zeaxanthin',
    unitName: 'UG',
    attributeCode: 'lutein_zeaxanthin_ug',
  ),
  // Tocopherol and tocotrienol isomers besides α-tocopherol.
  FdcNutrientDefinition(
    id: 1125,
    number: '341',
    name: 'Tocopherol, beta',
    unitName: 'MG',
    attributeCode: 'tocopherol_beta_mg',
  ),
  FdcNutrientDefinition(
    id: 1126,
    number: '342',
    name: 'Tocopherol, gamma',
    unitName: 'MG',
    attributeCode: 'tocopherol_gamma_mg',
  ),
  FdcNutrientDefinition(
    id: 1127,
    number: '343',
    name: 'Tocopherol, delta',
    unitName: 'MG',
    attributeCode: 'tocopherol_delta_mg',
  ),
  FdcNutrientDefinition(
    id: 1128,
    number: '344',
    name: 'Tocotrienol, alpha',
    unitName: 'MG',
    attributeCode: 'tocotrienol_alpha_mg',
  ),
  FdcNutrientDefinition(
    id: 1129,
    number: '345',
    name: 'Tocotrienol, beta',
    unitName: 'MG',
    attributeCode: 'tocotrienol_beta_mg',
  ),
  FdcNutrientDefinition(
    id: 1130,
    number: '346',
    name: 'Tocotrienol, gamma',
    unitName: 'MG',
    attributeCode: 'tocotrienol_gamma_mg',
  ),
  FdcNutrientDefinition(
    id: 1131,
    number: '347',
    name: 'Tocotrienol, delta',
    unitName: 'MG',
    attributeCode: 'tocotrienol_delta_mg',
  ),
  // Vitamin D forms: D (µg) = D2 + D3; IU = 40 × µg.
  FdcNutrientDefinition(
    id: 1110,
    number: '324',
    name: 'Vitamin D (D2 + D3), International Units',
    unitName: 'IU',
    attributeCode: 'vitamin_d_iu',
  ),
  FdcNutrientDefinition(
    id: 1111,
    number: '325',
    name: 'Vitamin D2 (ergocalciferol)',
    unitName: 'UG',
    attributeCode: 'vitamin_d2_ug',
  ),
  FdcNutrientDefinition(
    id: 1112,
    number: '326',
    name: 'Vitamin D3 (cholecalciferol)',
    unitName: 'UG',
    attributeCode: 'vitamin_d3_ug',
  ),
  // Vitamin K forms besides phylloquinone.
  FdcNutrientDefinition(
    id: 1184,
    number: '429',
    name: 'Vitamin K (Dihydrophylloquinone)',
    unitName: 'UG',
    attributeCode: 'vitamin_k_dihydrophylloquinone_ug',
  ),
  FdcNutrientDefinition(
    id: 1183,
    number: '428',
    name: 'Vitamin K (Menaquinone-4)',
    unitName: 'UG',
    attributeCode: 'vitamin_k_menaquinone4_ug',
  ),
  // Saturated fatty acids by chain length. The listed acids sum to no more
  // than total saturated fatty acids, which also counts minor acids.
  FdcNutrientDefinition(
    id: 1259,
    number: '607',
    name: 'SFA 4:0',
    unitName: 'G',
    attributeCode: 'sfa_4_0_g',
  ),
  FdcNutrientDefinition(
    id: 1260,
    number: '608',
    name: 'SFA 6:0',
    unitName: 'G',
    attributeCode: 'sfa_6_0_g',
  ),
  FdcNutrientDefinition(
    id: 1261,
    number: '609',
    name: 'SFA 8:0',
    unitName: 'G',
    attributeCode: 'sfa_8_0_g',
  ),
  FdcNutrientDefinition(
    id: 1262,
    number: '610',
    name: 'SFA 10:0',
    unitName: 'G',
    attributeCode: 'sfa_10_0_g',
  ),
  FdcNutrientDefinition(
    id: 1263,
    number: '611',
    name: 'SFA 12:0',
    unitName: 'G',
    attributeCode: 'sfa_12_0_g',
  ),
  FdcNutrientDefinition(
    id: 1332,
    number: '696',
    name: 'SFA 13:0',
    unitName: 'G',
    attributeCode: 'sfa_13_0_g',
  ),
  FdcNutrientDefinition(
    id: 1264,
    number: '612',
    name: 'SFA 14:0',
    unitName: 'G',
    attributeCode: 'sfa_14_0_g',
  ),
  FdcNutrientDefinition(
    id: 1299,
    number: '652',
    name: 'SFA 15:0',
    unitName: 'G',
    attributeCode: 'sfa_15_0_g',
  ),
  FdcNutrientDefinition(
    id: 1265,
    number: '613',
    name: 'SFA 16:0',
    unitName: 'G',
    attributeCode: 'sfa_16_0_g',
  ),
  FdcNutrientDefinition(
    id: 1300,
    number: '653',
    name: 'SFA 17:0',
    unitName: 'G',
    attributeCode: 'sfa_17_0_g',
  ),
  FdcNutrientDefinition(
    id: 1266,
    number: '614',
    name: 'SFA 18:0',
    unitName: 'G',
    attributeCode: 'sfa_18_0_g',
  ),
  FdcNutrientDefinition(
    id: 1267,
    number: '615',
    name: 'SFA 20:0',
    unitName: 'G',
    attributeCode: 'sfa_20_0_g',
  ),
  FdcNutrientDefinition(
    id: 1273,
    number: '624',
    name: 'SFA 22:0',
    unitName: 'G',
    attributeCode: 'sfa_22_0_g',
  ),
  FdcNutrientDefinition(
    id: 1301,
    number: '654',
    name: 'SFA 24:0',
    unitName: 'G',
    attributeCode: 'sfa_24_0_g',
  ),
  // Monounsaturated fatty acids. "c" rows are the cis part of the row with
  // the same chain length.
  FdcNutrientDefinition(
    id: 1274,
    number: '625',
    name: 'MUFA 14:1',
    unitName: 'G',
    attributeCode: 'mufa_14_1_g',
  ),
  FdcNutrientDefinition(
    id: 1333,
    number: '697',
    name: 'MUFA 15:1',
    unitName: 'G',
    attributeCode: 'mufa_15_1_g',
  ),
  FdcNutrientDefinition(
    id: 1275,
    number: '626',
    name: 'MUFA 16:1',
    unitName: 'G',
    attributeCode: 'mufa_16_1_g',
  ),
  FdcNutrientDefinition(
    id: 1314,
    number: '673',
    name: 'MUFA 16:1 c',
    unitName: 'G',
    attributeCode: 'mufa_16_1_c_g',
  ),
  FdcNutrientDefinition(
    id: 1323,
    number: '687',
    name: 'MUFA 17:1',
    unitName: 'G',
    attributeCode: 'mufa_17_1_g',
  ),
  FdcNutrientDefinition(
    id: 1268,
    number: '617',
    name: 'MUFA 18:1',
    unitName: 'G',
    attributeCode: 'mufa_18_1_g',
  ),
  FdcNutrientDefinition(
    id: 1315,
    number: '674',
    name: 'MUFA 18:1 c',
    unitName: 'G',
    attributeCode: 'mufa_18_1_c_g',
  ),
  FdcNutrientDefinition(
    id: 1277,
    number: '628',
    name: 'MUFA 20:1',
    unitName: 'G',
    attributeCode: 'mufa_20_1_g',
  ),
  FdcNutrientDefinition(
    id: 1279,
    number: '630',
    name: 'MUFA 22:1',
    unitName: 'G',
    attributeCode: 'mufa_22_1_g',
  ),
  FdcNutrientDefinition(
    id: 1317,
    number: '676',
    name: 'MUFA 22:1 c',
    unitName: 'G',
    attributeCode: 'mufa_22_1_c_g',
  ),
  FdcNutrientDefinition(
    id: 1312,
    number: '671',
    name: 'MUFA 24:1 c',
    unitName: 'G',
    attributeCode: 'mufa_24_1_c_g',
  ),
  // Polyunsaturated fatty acids. n-3 / n-6, cis, conjugated (CLA) and
  // isomer rows are parts of the row with the same chain length.
  FdcNutrientDefinition(
    id: 1269,
    number: '618',
    name: 'PUFA 18:2',
    unitName: 'G',
    attributeCode: 'pufa_18_2_g',
  ),
  FdcNutrientDefinition(
    id: 1316,
    number: '675',
    name: 'PUFA 18:2 n-6 c,c',
    unitName: 'G',
    attributeCode: 'pufa_18_2_n6_cc_g',
  ),
  FdcNutrientDefinition(
    id: 1311,
    number: '670',
    name: 'PUFA 18:2 CLAs',
    unitName: 'G',
    attributeCode: 'pufa_18_2_clas_g',
  ),
  FdcNutrientDefinition(
    id: 1307,
    number: '666',
    name: 'PUFA 18:2 i',
    unitName: 'G',
    attributeCode: 'pufa_18_2_i_g',
  ),
  FdcNutrientDefinition(
    id: 1270,
    number: '619',
    name: 'PUFA 18:3',
    unitName: 'G',
    attributeCode: 'pufa_18_3_g',
  ),
  FdcNutrientDefinition(
    id: 1404,
    number: '851',
    name: 'PUFA 18:3 n-3 c,c,c (ALA)',
    unitName: 'G',
    attributeCode: 'pufa_18_3_n3_ccc_ala_g',
  ),
  FdcNutrientDefinition(
    id: 1321,
    number: '685',
    name: 'PUFA 18:3 n-6 c,c,c',
    unitName: 'G',
    attributeCode: 'pufa_18_3_n6_ccc_g',
  ),
  FdcNutrientDefinition(
    id: 1409,
    number: '856',
    name: 'PUFA 18:3i',
    unitName: 'G',
    attributeCode: 'pufa_18_3i_g',
  ),
  FdcNutrientDefinition(
    id: 1276,
    number: '627',
    name: 'PUFA 18:4',
    unitName: 'G',
    attributeCode: 'pufa_18_4_g',
  ),
  FdcNutrientDefinition(
    id: 1313,
    number: '672',
    name: 'PUFA 20:2 n-6 c,c',
    unitName: 'G',
    attributeCode: 'pufa_20_2_n6_cc_g',
  ),
  FdcNutrientDefinition(
    id: 1325,
    number: '689',
    name: 'PUFA 20:3',
    unitName: 'G',
    attributeCode: 'pufa_20_3_g',
  ),
  FdcNutrientDefinition(
    id: 1405,
    number: '852',
    name: 'PUFA 20:3 n-3',
    unitName: 'G',
    attributeCode: 'pufa_20_3_n3_g',
  ),
  FdcNutrientDefinition(
    id: 1406,
    number: '853',
    name: 'PUFA 20:3 n-6',
    unitName: 'G',
    attributeCode: 'pufa_20_3_n6_g',
  ),
  FdcNutrientDefinition(
    id: 1271,
    number: '620',
    name: 'PUFA 20:4',
    unitName: 'G',
    attributeCode: 'pufa_20_4_g',
  ),
  FdcNutrientDefinition(
    id: 1408,
    number: '855',
    name: 'PUFA 20:4 n-6',
    unitName: 'G',
    attributeCode: 'pufa_20_4_n6_g',
  ),
  FdcNutrientDefinition(
    id: 1278,
    number: '629',
    name: 'PUFA 20:5 n-3 (EPA)',
    unitName: 'G',
    attributeCode: 'pufa_20_5_n3_epa_g',
  ),
  FdcNutrientDefinition(
    id: 1410,
    number: '857',
    name: 'PUFA 21:5',
    unitName: 'G',
    attributeCode: 'pufa_21_5_g',
  ),
  FdcNutrientDefinition(
    id: 1411,
    number: '858',
    name: 'PUFA 22:4',
    unitName: 'G',
    attributeCode: 'pufa_22_4_g',
  ),
  FdcNutrientDefinition(
    id: 1280,
    number: '631',
    name: 'PUFA 22:5 n-3 (DPA)',
    unitName: 'G',
    attributeCode: 'pufa_22_5_n3_dpa_g',
  ),
  FdcNutrientDefinition(
    id: 1272,
    number: '621',
    name: 'PUFA 22:6 n-3 (DHA)',
    unitName: 'G',
    attributeCode: 'pufa_22_6_n3_dha_g',
  ),
  // Trans fatty acids: total trans = trans-monoenoic + trans-polyenoic.
  FdcNutrientDefinition(
    id: 1329,
    number: '693',
    name: 'Fatty acids, total trans-monoenoic',
    unitName: 'G',
    attributeCode: 'fatty_acids_trans_monoenoic_g',
  ),
  FdcNutrientDefinition(
    id: 1303,
    number: '662',
    name: 'TFA 16:1 t',
    unitName: 'G',
    attributeCode: 'tfa_16_1_t_g',
  ),
  FdcNutrientDefinition(
    id: 1304,
    number: '663',
    name: 'TFA 18:1 t',
    unitName: 'G',
    attributeCode: 'tfa_18_1_t_g',
  ),
  FdcNutrientDefinition(
    id: 1305,
    number: '664',
    name: 'TFA 22:1 t',
    unitName: 'G',
    attributeCode: 'tfa_22_1_t_g',
  ),
  FdcNutrientDefinition(
    id: 1331,
    number: '695',
    name: 'Fatty acids, total trans-polyenoic',
    unitName: 'G',
    attributeCode: 'fatty_acids_trans_polyenoic_g',
  ),
  FdcNutrientDefinition(
    id: 1306,
    number: '665',
    name: 'TFA 18:2 t not further defined',
    unitName: 'G',
    attributeCode: 'tfa_18_2_t_nfd_g',
  ),
  FdcNutrientDefinition(
    id: 1310,
    number: '669',
    name: 'TFA 18:2 t,t',
    unitName: 'G',
    attributeCode: 'tfa_18_2_tt_g',
  ),
  // Phytosterols and the individual sterols.
  FdcNutrientDefinition(
    id: 1283,
    number: '636',
    name: 'Phytosterols',
    unitName: 'MG',
    attributeCode: 'phytosterols_mg',
  ),
  FdcNutrientDefinition(
    id: 1285,
    number: '638',
    name: 'Stigmasterol',
    unitName: 'MG',
    attributeCode: 'stigmasterol_mg',
  ),
  FdcNutrientDefinition(
    id: 1286,
    number: '639',
    name: 'Campesterol',
    unitName: 'MG',
    attributeCode: 'campesterol_mg',
  ),
  FdcNutrientDefinition(
    id: 1288,
    number: '641',
    name: 'Beta-sitosterol',
    unitName: 'MG',
    attributeCode: 'beta_sitosterol_mg',
  ),
  // Hydroxyproline, an amino acid of collagen (not one of the 18 profile
  // amino acids).
  FdcNutrientDefinition(
    id: 1228,
    number: '521',
    name: 'Hydroxyproline',
    unitName: 'G',
    attributeCode: 'hydroxyproline_g',
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
