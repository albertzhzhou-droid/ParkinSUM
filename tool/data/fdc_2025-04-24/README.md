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
| `food_nutrient_sr_legacy_subset.csv` | Every nutrient row (amount, data points, derivation, min/max/median) of the 280 SR Legacy reference and seed foods | Whole lines in source order; 26,995 rows, 148 nutrients |
| `food_portion_sr_legacy_subset.csv` | Household-measure gram weights of the same foods | Whole lines in source order; 788 rows (3 foods have none) |
| `food_nutrient_derivation.csv` | Derivation code table (A analytical, NC calculated, Z assumed zero, …) | Complete, byte-for-byte (8,294 bytes) |

Complete files were checked against the mirror's published byte sizes; the
subsets are filters of verbatim lines. `food_nutrient.csv` (1.77 GB) was read
in 55 KB windows; a food's rows were kept only when its whole block lay inside
one window with a different food on both sides, and the 47 foods that appeared
in two windows had byte-identical copies. The portion rows come from one
contiguous byte range covering the whole SR Legacy portion block. `test/fdc_nutrient_definitions_test.dart`
and `test/food_composition_interdependency_model_test.dart` read these files
directly. SHA-256 digests are pinned in
`test/fdc_nutrient_definitions_test.dart`.
