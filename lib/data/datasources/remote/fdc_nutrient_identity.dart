export '../../../core/models/food_item.dart' show FdcFoodBasis;

/// USDA source nutrient identities. Distinct methods, vitamin forms, energy
/// units and source sugar quantities are never merged by similar names.
/// IDs/numbers were independently inspected in the complete April 2026
/// Foundation Foods archive. This inventory is not a clinical rule threshold.
const fdcNutrientIdentities = <(String, String, String, String)>[
  ("1003", "203", "protein_g", "Protein"),
  ("1004", "204", "fat_g", "Total lipid (fat)"),
  ("1005", "205", "carbohydrate_g", "Carbohydrate, by difference"),
  (
    "1050",
    "205.2",
    "carbohydrate_by_summation_g",
    "Carbohydrate, by summation",
  ),
  ("1079", "291", "fiber_g", "Fiber, total dietary"),
  ("2033", "293", "fiber_aoac_2011_25_g", "Total dietary fiber (AOAC 2011.25)"),
  ("1093", "307", "sodium_mg", "Sodium, Na"),
  ("1089", "303", "iron_mg", "Iron, Fe"),
  ("1092", "306", "potassium_mg", "Potassium, K"),
  ("1008", "208", "energy_kcal", "Energy"),
  ("1051", "255", "water_g", "Water"),
  (
    "2047",
    "957",
    "energy_atwater_general_kcal",
    "Energy (Atwater General Factors)",
  ),
  (
    "2048",
    "958",
    "energy_atwater_specific_kcal",
    "Energy (Atwater Specific Factors)",
  ),
  ("1087", "301", "calcium_mg", "Calcium, Ca"),
  ("1090", "304", "magnesium_mg", "Magnesium, Mg"),
  ("1091", "305", "phosphorus_mg", "Phosphorus, P"),
  ("1095", "309", "zinc_mg", "Zinc, Zn"),
  ("1098", "312", "copper_mg", "Copper, Cu"),
  ("1101", "315", "manganese_mg", "Manganese, Mn"),
  ("1103", "317", "selenium_ug", "Selenium, Se"),
  ("1100", "314", "iodine_ug", "Iodine, I"),
  ("1162", "401", "vitamin_c_mg", "Vitamin C, total ascorbic acid"),
  ("1165", "404", "thiamin_mg", "Thiamin"),
  ("1166", "405", "riboflavin_mg", "Riboflavin"),
  ("1167", "406", "niacin_mg", "Niacin"),
  ("1170", "410", "pantothenic_acid_mg", "Pantothenic acid"),
  ("1175", "415", "vitamin_b6_mg", "Vitamin B-6"),
  ("1178", "418", "vitamin_b12_ug", "Vitamin B-12"),
  ("1177", "417", "folate_total_ug", "Folate, total"),
  ("1106", "320", "vitamin_a_rae_ug", "Vitamin A, RAE"),
  ("1105", "319", "retinol_ug", "Retinol"),
  (
    "1109",
    "323",
    "vitamin_e_alpha_tocopherol_mg",
    "Vitamin E (alpha-tocopherol)",
  ),
  ("1111", "325", "vitamin_d2_ug", "Vitamin D2 (ergocalciferol)"),
  ("1112", "326", "vitamin_d3_ug", "Vitamin D3 (cholecalciferol)"),
  ("1114", "328", "vitamin_d_total_ug", "Vitamin D (D2 + D3)"),
  (
    "1110",
    "324",
    "vitamin_d_total_iu",
    "Vitamin D (D2 + D3), International Units",
  ),
  ("1185", "430", "vitamin_k_phylloquinone_ug", "Vitamin K (phylloquinone)"),
  ("1183", "428", "vitamin_k_menaquinone4_ug", "Vitamin K (Menaquinone-4)"),
  (
    "1184",
    "429",
    "vitamin_k_dihydrophylloquinone_ug",
    "Vitamin K (Dihydrophylloquinone)",
  ),
  ("1180", "421", "choline_total_mg", "Choline, total"),
  ("1253", "601", "cholesterol_mg", "Cholesterol"),
  ("1258", "606", "fatty_acids_saturated_g", "Fatty acids, total saturated"),
  (
    "1292",
    "645",
    "fatty_acids_monounsaturated_g",
    "Fatty acids, total monounsaturated",
  ),
  (
    "1293",
    "646",
    "fatty_acids_polyunsaturated_g",
    "Fatty acids, total polyunsaturated",
  ),
  ("1257", "605", "fatty_acids_trans_g", "Fatty acids, total trans"),
  ("1009", "209", "starch_g", "Starch"),
  ("1010", "210", "sucrose_g", "Sucrose"),
  ("1011", "211", "glucose_g", "Glucose"),
  ("1012", "212", "fructose_g", "Fructose"),
  ("1013", "213", "lactose_g", "Lactose"),
  ("1014", "214", "maltose_g", "Maltose"),
  ("1075", "287", "galactose_g", "Galactose"),
  ("1063", "269.3", "sugars_total_1063_g", "Sugars, Total"),
  ("2000", "269", "sugars_total_2000_g", "Total Sugars"),
  ("1082", "295", "fiber_soluble_g", "Fiber, soluble"),
  ("1084", "297", "fiber_insoluble_g", "Fiber, insoluble"),
  ("1062", "268", "energy_kj", "Energy"),
  ("1007", "207", "ash_g", "Ash"),
  ("1002", "202", "nitrogen_g", "Nitrogen"),
  ("1404", "851", "ala_n3_g", "PUFA 18:3 n-3 c,c,c (ALA)"),
  ("1278", "629", "epa_n3_g", "PUFA 20:5 n-3 (EPA)"),
  ("1272", "621", "dha_n3_g", "PUFA 22:6 n-3 (DHA)"),
];

String? fdcNutrientAttributeCode({
  Object? nutrientId,
  required String nutrientNumber,
  required String nutrientName,
}) {
  final id = nutrientId == null ? '' : nutrientId.toString().trim();
  final number = nutrientNumber.trim();
  final candidates = fdcNutrientIdentities
      .where(
        (item) =>
            (id.isNotEmpty && id == item.$1) ||
            (number.isNotEmpty && number == item.$2),
      )
      .toList(growable: false);
  if (id.isNotEmpty || number.isNotEmpty) {
    if (candidates.length != 1) return null;
    final found = candidates.single;
    return (id.isEmpty || id == found.$1) &&
            (number.isEmpty || number == found.$2)
        ? found.$3
        : null;
  }
  // Preserve exact-name legacy records only when the quantity is unique.
  // Names cannot repair supplied contradictory or unknown identifiers.
  const legacyNameQuantities = {
    'protein_g',
    'fat_g',
    'carbohydrate_g',
    'carbohydrate_by_summation_g',
    'fiber_g',
    'fiber_aoac_2011_25_g',
    'sodium_mg',
    'iron_mg',
    'potassium_mg',
    'water_g',
  };
  final names = fdcNutrientIdentities
      .where(
        (item) =>
            legacyNameQuantities.contains(item.$3) &&
            item.$4.toLowerCase() == nutrientName.trim().toLowerCase(),
      )
      .toList(growable: false);
  return names.length == 1 ? names.single.$3 : null;
}

/// Unit spelling only: no numeric conversion, IU equivalence or density is
/// inferred. Original unit spelling remains in source_nutrient_summaries.
String canonicalFdcNutrientUnit(String unit) {
  final normalized = unit.trim().toLowerCase();
  if (normalized == '\u00b5g' || normalized == '\u03bcg') return 'ug';
  return normalized;
}
