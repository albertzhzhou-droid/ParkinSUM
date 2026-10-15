# USDA FoodData Central — full CSV download, release 2025-04-24

Public domain (CC0 1.0), U.S. Department of Agriculture, Agricultural Research
Service. Retrieved through the Hugging Face dataset mirror
`yvfu/FoodData_Central_csv_2025-04-24`, because the environment's network
policy blocks `fdc.nal.usda.gov`.

| File | Content | Copy |
| --- | --- | --- |
| `nutrient.csv` | Nutrient id, name, unit and legacy number (all 477 rows) | Complete, byte-for-byte |
| `foundation_food.csv` | Foundation Foods fdc_id → NDB number | Complete, byte-for-byte |
| `food_nutrient_conversion_factor.csv` | Conversion-factor id → fdc_id | Complete, byte-for-byte |
| `food_protein_conversion_factor.csv` | Nitrogen-to-protein factors | Complete, byte-for-byte |
| `food_calorie_conversion_factor_foundation_subset.csv` | Food-specific Atwater factors | Verbatim lines whose id appears in `food_nutrient_conversion_factor.csv` |
| `sr_legacy_food_reference_subset.csv` | SR Legacy fdc_id → NDB number | Verbatim lines for the 224 foods in `../usda_sr_legacy_reference_subset_2018.csv` |

Complete files were checked against the mirror's published byte sizes; the
subsets are filters of verbatim lines. `test/fdc_nutrient_definitions_test.dart`
and `test/food_composition_interdependency_model_test.dart` read these files
directly. SHA-256 digests are pinned in
`test/fdc_nutrient_definitions_test.dart`.
