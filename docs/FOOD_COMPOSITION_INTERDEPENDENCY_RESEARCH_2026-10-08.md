# Food Composition Data and Interdependency Research — 2026-10-08

Educational and research prototype only. Nothing in this document or in the
code it describes is a diet, medication, timing, or treatment recommendation.
All examples are synthetic. Review any health decision with a qualified
clinician.

## 1. What changed and why

The local food catalog had 19 curated CIQUAL-labelled seed foods. Their values
were copied by hand, sodium and energy were stored as `0` instead of unknown,
one value was physically implausible, and the conflict engine treated every
food value as an independent number. This iteration:

1. Adds a **verbatim USDA FoodData Central SR Legacy (April 2018) subset of
   224 foods** spanning all 16 food groups the catalog uses, with a provenance
   file, a code generator, and a test that fails if any generated value
   differs from the published value.
2. Adds a deterministic **food-composition interdependency model**
   (`lib/domain/usecases/food_composition_interdependency_model.dart`) that
   encodes how food values depend on each other.
3. Integrates that model into the **mechanistic conflict engine** as a fifth
   traced layer. It can add drivers and uncertainty reasons and lower
   confidence; it never changes the interaction score.
4. Fixes data defects found while cross-checking (Section 6).

"Every food a human could eat" is not a finite list; no composition table is
complete. The subset is chosen to cover each food group with common staples,
paired raw/cooked records, part/whole records and fermented or processed
forms needed by the interdependency checks. New foods are added by appending
verbatim rows and curation metadata, then regenerating.

## 2. Data provenance and verification

| Item | Detail |
| --- | --- |
| Source | USDA ARS, FoodData Central, SR Legacy (April 2018). Public domain. |
| Retrieval path | Hugging Face dataset `ULM-DS-Lab/food-composition-matrix`, file `usda_sr_legacy_2018_wide.csv` (a no-imputation pivot of FDC `food.csv` + `food_nutrient.csv`), read through the Hugging Face connector because direct access to `fdc.nal.usda.gov` is blocked by this environment's network policy. |
| Committed copy | `tool/data/usda_sr_legacy_reference_subset_2018.csv` — rows copied byte-for-byte, keyed by FDC id. |
| Curation | `tool/data/reference_food_curation.json` — English/Chinese names, food group, preparation state, texture. Never edits a nutrient value. |
| Generated table | `lib/core/constants/reference_food_composition_table.dart` via `dart run tool/generate_reference_food_composition_table.dart`. |
| Columns | Energy (kcal), protein, fat, carbohydrate by difference, total dietary fibre (g); calcium, phosphorus, iron, sodium, potassium, copper, zinc (mg); retinol, beta-carotene (µg); thiamin, riboflavin, niacin, vitamin C (mg). All per 100 g edible portion. Empty source cells stay `null`. |

### Independent verification

The mirror is a third party, so the subset was checked independently of it:

- **Energy identity.** For every row, reported energy was reconciled with
  FAO Food and Nutrition Paper 77 general factors (protein 4, fat 9,
  carbohydrate 4, fibre 2 kcal/g) within max(15 kcal, 12%). All 218 rows
  without alcohol or acetic acid reconcile. The six that do not are fully
  explained by non-macronutrient energy: table wines (implied ethanol
  10.3–10.6 g/100 g ≈ 13% v/v), dessert wine (14.9 g), regular beer
  (3.9 g ≈ 5% v/v),
  80-proof spirits (33.0 g ≈ 40% v/v) and cider vinegar (≈5.8 g organic acid,
  consistent with ~5% acetic acid). A transcription error in protein, fat,
  carbohydrate or energy would break this identity.
- **Proximate closure** (protein + fat + carbohydrate ≤ 100 g) and **fibre ≤
  carbohydrate by difference** hold for every row.
- **Cross-record derivations** (Section 3.2) hold for 23 encoded pairs.
- `test/reference_food_composition_table_test.dart` locks all of the above.

### Coverage

| Group | Rows | Group | Rows |
| --- | --- | --- | --- |
| Vegetables | 40 | Poultry | 7 |
| Grains and cereal products | 33 | Meat (beef, pork, lamb, ham) | 7 |
| Fruits | 26 | Eggs and egg parts | 6 |
| Dairy (milks, yogurts, 13 cheeses) | 22 | Sweeteners and confections | 6 |
| Legumes and soy foods | 21 | Fats and oils | 5 |
| Fish and seafood | 19 | Alcoholic beverages | 5 |
| Nuts and seeds | 10 | Protein supplements | 2 |
| Non-alcoholic beverages | 8 | Condiments (miso, soy sauces, salt, vinegar…) | 7 |

## 3. Interdependencies encoded

### 3.1 Definitional identities inside one record

| Identity | Rule | Source |
| --- | --- | --- |
| Energy from macronutrients | 4P + 9F + 4C (+2·fibre variant); residual explained only by alcohol (7 kcal/g) or organic acids (~3 kcal/g) | `src.fao.food_energy.2003` |
| Carbohydrate convention | USDA "by difference" **includes** fibre; CIQUAL "Glucides" and FDC 1050 "by summation" are **available** carbohydrate. Convert only when fibre is reported; otherwise abstain. | `src.usda.sr_legacy.2018` |
| Salt from sodium | salt = Na × 2.5 (EU labelling factor; NaCl/Na mass ratio is 2.54) | `src.eu.reg1169.salt_factor` |
| Protein is nitrogen × factor | Cross-source protein differences can be definitional | `src.mariotti.nitrogen_protein.2008` |
| Closure | P + F + C_by-difference ≤ 100; fibre ≤ C_by-difference | data identity |

### 3.2 Derivations between foods (protein as conserved tracer)

Child mass per unit parent mass is inferred as parent protein ÷ child
protein. Values below are computed from the committed data.

| Edge | Kind | Implied mass ratio | Tested nutrients |
| --- | --- | --- | --- |
| White rice dry → cooked | hydration | 2.65 | energy, carbohydrate (±20%) |
| Brown rice dry → cooked | hydration | 2.75 | energy, carbohydrate |
| Pasta dry → cooked | hydration | 2.25 | energy, carbohydrate |
| Lentils dry → boiled | hydration | 2.73 | energy, carbohydrate |
| Split peas dry → boiled | hydration | 2.77 | energy, carbohydrate |
| Black beans dry → boiled | hydration | 2.44 | energy, carbohydrate |
| Soybeans dry → boiled | hydration | 2.00 | energy only (±35%); carbohydrate does not follow the tracer (≈1.8×) |
| Oats dry → cooked with water | hydration | 5.18 | energy, carbohydrate |
| Spelt, couscous, rice noodles | hydration | 2.65 / 3.37 / 3.32 | energy, carbohydrate |
| Cod raw → cooked | moisture loss | 0.78 | energy, fat |
| Salmon (farmed), turkey, pork loin | moisture loss | 0.92 / 0.78 / 0.77 | energy (pork also fat) |
| Chicken dark meat, lamb | moisture loss | 0.73 / 0.69 | direction only (fat does not follow) |
| Spinach, green peas, immature broad beans raw → boiled | vegetable boiling | 0.96 / 1.01 / 1.17 | energy, carbohydrate |
| Grapes → raisins | dehydration | 0.22 (≈4.6× concentration) | energy, carbohydrate (±15%) |
| Orange → juice | extraction | — | fibre retained per kcal ≈ 0.09 (most fibre stays in pulp) |
| Cooked rice → cooked rice with salt | salt addition | 1.00 | macros unchanged; implied added salt 0.95 g/100 g |
| Whole egg = white + yolk | part–whole | yolk fraction 0.335 | energy (−0.4%) and fat (−5.4%) close; **iron does not** (SR whole-egg 1.75 mg vs 0.97 mg reconstructed from its own parts — a source-internal inconsistency, reported, not corrected) |

### 3.3 Meal-level interdependencies

| Interaction | What the model does | Evidence (PubMed) |
| --- | --- | --- |
| **Food-borne L-dopa (Vicia faba, Mucuna pruriens)** | Detects broad bean / fava / 蚕豆 / fève and Mucuna foods. Adds driver `food_intrinsic_levodopa_source_present`, an uncertainty reason, and caps confidence at medium. Never converts food L-dopa into a dose. | Faba seeds 0.10–0.15 mg/g dry weight (one accession; stable under 1 h heat), leaves 18.13–24.44 mg/g raw and 8.52–10.88 after steaming — Duan et al. 2021, PMID 34439455, [doi:10.3390/antiox10081207](https://doi.org/10.3390/antiox10081207). Pod valves 28.65 vs seeds 0.76 mg/g dry weight — Tesoro et al. 2024, PMID 39203021, [doi:10.3390/molecules29163943](https://doi.org/10.3390/molecules29163943). Mucuna 1–7% — Aureli et al. 2025, PMID 41169659, [doi:10.3389/fchem.2025.1597784](https://doi.org/10.3389/fchem.2025.1597784). Mucuna L-dopa bioavailability far lower than formulated levodopa without a decarboxylase inhibitor — Contin et al. 2015, PMID 26366963, [doi:10.1097/WNF.0000000000000098](https://doi.org/10.1097/WNF.0000000000000098). Published values span >280× across tissues, so a per-serving number would be false precision. |
| **Dry vs cooked state** | Names like "rice", "大米", "lentils", "oatmeal" without a state make protein per 100 g ambiguous by the implied mass ratio (2.0–5.2×). When the serving's own protein density is within 35% of the dry or cooked reference, the data resolve the state and nothing is flagged; otherwise adds `food_preparation_state_ambiguous(...:protein_x2.65)` and caps confidence at medium for scored meals. | Ratios from the SR pairs above. LNAA competition depends on protein grams — Nutt et al. 1984, PMID 6694694, [doi:10.1056/NEJM198402233100802](https://doi.org/10.1056/NEJM198402233100802). |
| **Energy–macronutrient mismatch in a logged serving** | Flags `food_component_energy_inconsistent(...)` when catalog energy and logged macros disagree beyond tolerance (alcohol/vinegar explained). | FAO 77. |
| **Non-heme iron co-consumption** (`assessIronCoConsumption`, context only, not wired into scoring) | Reports calcium ≥165 mg, coffee/tea, vitamin C and heme sources present in a meal; quantifies only when portion and reference row are known. | 165 mg calcium reduced single-meal iron absorption 50–60% — Hallberg et al. 1991, PMID 1984335, [doi:10.1093/ajcn/53.1.112](https://doi.org/10.1093/ajcn/53.1.112). Tea/coffee polyphenols, phytate, calcium inhibit; ascorbic acid and meat/fish/poultry enhance — Zijp et al. 2000, PMID 11029010, [doi:10.1080/10408690091189194](https://doi.org/10.1080/10408690091189194). Complete-diet vitamin C effect not significant — Cook & Reddy 2001, PMID 11124756, [doi:10.1093/ajcn/73.1.93](https://doi.org/10.1093/ajcn/73.1.93). |

Evidence registered but deliberately **not** turned into a scoring rule:

- Ferrous sulfate 325 mg lowered levodopa Cmax 55% and AUC 51% in healthy
  volunteers (Campbell & Hasinoff 1989, PMID 2920496,
  [doi:10.1038/clpt.1989.21](https://doi.org/10.1038/clpt.1989.21)). This is an
  iron-salt tablet; it is not extrapolated to iron naturally present in food.
- Ascorbic acid 200 mg raised levodopa AUC only in a low-bioavailability
  subgroup (Nagayama et al. 2004, PMID 15613930,
  [doi:10.1097/01.wnf.0000150865.21759.bc](https://doi.org/10.1097/01.wnf.0000150865.21759.bc)).
- Tyramine challenge 50–75 mg produced no clinically significant pressor
  reaction with rasagiline 0.5–2 mg/day (deMarcaida et al. 2006, PMID 16856145,
  [doi:10.1002/mds.21048](https://doi.org/10.1002/mds.21048)); soy-product
  tyramine is highly variable and storage-dependent (Shulman & Walker 1999,
  PMID 10192596). Per-food tyramine values are therefore not added.
- Insoluble-fibre diet associated with higher early plasma L-dopa in
  constipated patients (Astarloa et al. 1992, PMID 1330307,
  [doi:10.1097/00002826-199210000-00004](https://doi.org/10.1097/00002826-199210000-00004)).

All 16 sources are registered in `ModelAssumptionRegistry`,
`config/source_access_registry.json` and `Bibliographies.md`.

## 4. Conflict engine behaviour

`MechanisticConflictEngine.evaluate` now assesses every relevant meal
composition with `FoodCompositionInterdependencyModel.assessMeal` and:

- appends a `food_composition_interdependency` layer trace (inputs,
  assumptions, `findings=<n>`, narrow/wide uncertainty);
- adds `food_intrinsic_levodopa_source_present` to `primaryDrivers` when any
  relevant meal contains a food-borne L-dopa source;
- adds machine-readable uncertainty reasons for each finding;
- caps a `high` confidence at `medium` when food-borne L-dopa is present or
  the scored meal has a dry/cooked ambiguity;
- adds the matching source refs only when a finding exists;
- **leaves `interactionScore`, `severityBand` and `interactionType`
  unchanged** — the score is a reduced-absorption-opportunity proxy, and an
  additional precursor exposure is a different direction that the model does
  not quantify.

Algorithm configuration advances to `2026.10.08-v53`; the engine and the new
model file are fingerprint-pinned in `AlgorithmConfigurationIdentity`.

## 5. Cross-source check of the existing CIQUAL-labelled seed

Definition-aware comparison (USDA carbohydrate converted to available
carbohydrate first; floor 0.5 g, expected variation 15%, material > 35%).
Different cultivars, samples and preparations legitimately differ; "material"
marks a value to re-verify against the official CIQUAL file, not a proven
error.

| P0 food (CIQUAL seed) | FDC | protein P0/USDA | available carbohydrate P0/USDA | fat P0/USDA | fibre P0/USDA | verdict |
| --- | --- | --- | --- | --- | --- | --- |
| banana | 173944 | 1.06 / 1.09 | 19.7 / 20.24 | 0.5 / 0.33 | 2.7 / 2.6 | agree |
| spinach | 168462 | 2.62 / 2.86 | 2.25 / 1.43 | 0.5 / 0.39 | 2.37 / 2.2 | material: carbohydrate |
| tofu (firm) | 172475 | 14.1 / 17.27 | 1.2 / 0.48 | 8.7 / 8.72 | 2.3 / 2.3 | material: carbohydrate |
| milk semi-skimmed vs 2% | 171267 | 3.24 / 3.3 | 4.85 / 4.80 | 1.57 / 1.98 | 0 / 0 | agree |
| chicken breast cooked | 171477 | 30.1 / 31.02 | 0 / 0.00 | 2 / 3.57 | 0 / 0 | material: fat |
| apple with skin | 171688 | 0.25 / 0.26 | 11.6 / 11.41 | 0.25 / 0.17 | 1.4 / 2.4 | material: fibre |
| blueberry | 171711 | 0.87 / 0.74 | 10.6 / 12.09 | 0.33 / 0.33 | 2.4 / 2.4 | agree |
| tomato | 170457 | 0.86 / 0.88 | 2.49 / 2.69 | 0.26 / 0.2 | 1.2 / 1.2 | agree |
| broccoli | 170379 | 3.95 / 2.82 | 1.7 / 4.04 | 0.48 / 0.37 | 2.9 / 2.6 | material: carbohydrate |
| rolled oats | 173904 | 13.1 / 13.15 | 56.2 / 57.60 | 7.09 / 6.52 | 10.2 / 10.1 | agree |
| brown rice cooked | 169704 | 2.73 / 2.74 | 29.9 / 23.98 | 0.98 / 0.97 | 1.6 / 1.6 | within variation |
| salmon farmed cooked | 175168 | 22.1 / 22.1 | 0 / 0.00 | 13.5 / 12.35 | 0 / 0 | agree |
| fava fresh | 170377 | 6.88 / 5.6 | 8.58 / 7.50 | 0.5 / 0.6 | 5.7 / 4.2 | within variation |
| potato boiled | 170440 | 1.6 / 1.71 | 17 / 18.21 | 0.1 / 0.1 | 1.3 / 1.8 | agree |
| walnuts | 170187 | 13.3 / 15.23 | 7.01 / 7.01 | 67.4 / 65.21 | 6.7 / 6.7 | agree |
| olive oil | 171413 | 0 / 0 | 0 / 0.00 | 99 / 100 | 0 / 0 | agree |
| cheddar | 173414 | 24 / 22.87 | 0 / 3.37 | 33.8 / 33.31 | 0 / 0 | material: carbohydrate |
| egg boiled | 173424 | 13.5 / 12.58 | 0.52 / 1.12 | 8.62 / 10.61 | 0 / 0 | material: carbohydrate |
| coffee brewed | 171890 | 0.5 / 0.12 | 1.35 / 0.00 | 0.018 / 0.02 | 0 / 0 | material: carbohydrate |

Notes: several "material" carbohydrate rows are small absolute amounts where
USDA by-difference carbohydrate also absorbs analytical residue (cheddar,
egg). The P0 cooked brown rice (2.73 g protein, 29.9 g available
carbohydrate) implies ≈142 kcal/100 g, above the 112–123 kcal typical of
cooked brown rice records; it should be re-verified against the official
file. Values were not silently overwritten.

## 6. Defects found and fixed

| Defect | Fix |
| --- | --- |
| FDC importer mapped "Carbohydrate, by difference" (includes fibre) and any other "carbohydrate" to the same `carbohydrate_g` code that CIQUAL uses for available carbohydrate — fibre was double-counted when sources mixed. | By-difference now keeps `carbohydrate_by_difference_g`; FDC 1050 "by summation" maps to `carbohydrate_g`; other definitions stay unmapped. Available carbohydrate is derived only from exact by-difference and total-fibre values, with method code `derived:carbohydrate_by_difference_minus_total_fiber`. |
| FDC importer took any nutrient whose name contained "fiber", so "Fiber, soluble" could overwrite total fibre. | Only total dietary fibre (291 / "Fiber, total dietary" / AOAC total) maps; first total wins. |
| FDC-projected and P0 seed foods stored absent sodium, energy and macros as `0`. | Absent fields are listed in `missingNutrientFields` (unknown, not zero). |
| P0 brewed coffee vitamin B6 0.73 mg/100 g. | Withheld as `UNSPECIFIED`: brewed coffee has ~0.6–1.5 g dissolved solids per 100 g, so the value would imply ~50–120 mg B6 per 100 g of solids. |
| Reference subset row 170459 (tomato paste) lost its last cell, vitamin C 21.9 mg, when it was first copied. | The subset was regenerated from raw mirror lines; every one of the 224 rows now matches the mirror byte for byte, which the test checks. |
| `_loadCsvRows` matched files by suffix, so `food.csv` also matched `branded_food.csv` and `nutrient.csv` matched `food_nutrient.csv`. | Exact basename matching. |
| The CSV importer took the nutrient number from a column named `number`; the official file names it `nutrient_nbr`, so legacy numbers were never read. | Reads `nutrient_nbr`. When an id and a number disagree, the number decides and the record is audited. |
| Seed and regional catalog foods carried hand-entered protein, carbohydrate, fat, fibre and sodium (930 lines). | Replaced with verbatim USDA values or explicit "unknown" (Section 8.3). |
| 20 catalog medications carried placeholder `UNSPECIFIED_DAILYMED_SETID_*` codes. | Twelve now carry verified RxNorm ingredient identities; nine stay explicitly unverified with a reason (Section 8.4). |

## 7. Boundaries and open items

- The subset has no water, ash, sugars, vitamin B6, folate, vitamin B12,
  vitamin D/E/K, or amino acids: the mirror omits them. LNAA scoring still
  uses the existing protein-source proxy unless an FDC amino-acid import is
  available.
- Processed meats (salami, bacon), shellfish beyond crab/crayfish, and
  regional dishes are thin. Composite dishes are not decomposed into recipes.
- Tyramine and food L-dopa are presence/variability context only; no
  per-food amounts are claimed.
- The China CDC importer's carbohydrate convention is unverified and is not
  converted.
- The new evidence claims are not yet in `EvidenceCurrencyRegistry`.
  Records observed on 2026-10-08 would read as `unknown` for any evaluation
  clock before that date and block the `mechanistic_conflict` provider, so
  they need a reviewed rollout with fixture clocks.
- No clinical, nutrition-science, or regulatory review is claimed.

## 8. Iteration 2 — product-level reference data

The app as a whole stays a fixture-level educational prototype. The food and
medication **reference data** is now held to a product-level standard: every
value is a verbatim copy of a named official release, pinned by SHA-256, and
regenerated by a script. No value is typed by hand. A food or medicine that
could not be verified is marked unknown or unverified, with a reason, and is
never estimated.

### 8.1 FoodData Central importer for the 2025 release

- **Nutrient definitions.** `lib/data/datasources/remote/fdc_nutrient_definitions.dart`
  holds 59 definitions. Each one is checked field by field (id, name, unit and
  legacy number) against the official `nutrient.csv` of release 2025-04-24
  (477 rows, committed verbatim in `tool/data/fdc_2025-04-24/`). Resolution
  goes by id, then legacy number, then exact name. The importer:
  - uses the unit to tell apart duplicate names (two nutrients are called
    "Energy");
  - rejects a value whose unit does not match the definition;
  - never maps a fraction, such as soluble fibre, as a total.
- **Data types.** The importer now handles Foundation, SR Legacy, FNDDS Survey
  and Branded records.
  - Analytical sample records (sample, sub-sample, agricultural and market
    acquisition) are excluded, and each exclusion is audited.
  - Branded label nutrients stay per serving and are compared with the
    per-100 g values.
  - Branded GTIN/UPC codes and the WWEIA category become crosswalks.
  - Branded ingredient lists are scanned for food-borne L-dopa sources.
- **Derived values.**
  - Energy comes from the FDC Atwater-specific energy (2048), or else the
    Atwater-general energy (2047), when no measured `energy_kcal` exists.
  - Fibre comes from AOAC 2011.25 when total fibre is absent.
  - Food-specific nitrogen-to-protein and calorie factors are imported as
    observations.
  - Every derived value carries a `derived:` method code.

### 8.2 Composition identity audit

`auditCompositionIdentities` checks each imported record against identities
that hold by definition. Each check runs only when its inputs are present:

| Check | Identity | Tolerance |
| --- | --- | --- |
| General energy | 4/9/4 + 2 × fibre, plus alcohol | as in Section 2 |
| Food-specific energy | protein, fat and carbohydrate × the record's own calorie factors, plus 6.93 kcal/g alcohol (Handbook 74) | max(2 kcal, 2%) |
| kJ ↔ kcal | kJ = 4.184 × kcal | max(3 kJ, 0.5%) |
| Nitrogen → protein | protein = N × the record's factor | max(0.05 g, 1.5%) |
| Proximate closure | water + protein + fat + carbohydrate + ash + alcohol ≈ 100 g | ±0.6 g |
| Part within whole | fibre, sugars and starch ≤ carbohydrate; added ≤ total sugars; NLEA fat ≤ total lipid; fatty-acid classes ≤ total lipid | none |
| Iron | heme + non-heme = total | — |
| Lower bounds | RAE ≥ retinol + β-carotene/12; DFE ≥ total folate | — |

**Real-data verification.** The SR Legacy reference subset was joined
through `sr_legacy_food.csv` and `foundation_food.csv` (NDB numbers) to the
Foundation calorie conversion factors. That gives 65 food/factor pairs, and
64 reproduce their published energy within max(2 kcal, 2%). The exception is
coconut oil (SR 171412). Its Foundation record (330458) carries a fat factor
of 8.37 kcal/g, but the SR Legacy energy of 892 kcal implies about 9.0. This
is a documented difference between releases, not a transcription error, and
the test pins it.

### 8.3 Seed and regional catalog foods

The 186 seed and regional catalog foods no longer carry hand-entered
nutrients. `tool/data/seed_food_sources.json` maps each one:

| Source | Equivalent | Proxy | Total |
| --- | --- | --- | --- |
| SR Legacy 2018 (`tool/data/usda_sr_legacy_seed_subset_2018.csv`, 116 rows) | 113 | 4 | 117 |
| FNDDS 2017-2018 (`tool/data/fndds_2017_2018/`, 25 foods) | 22 | 3 | 25 |
| No verified record | — | — | 44 |

- Proxy matches carry a note that explains the difference.
- Every matched value equals its source cell, and all 142 matched records
  pass the general energy identity.
- The 44 foods without a verified record show every nutrient as unknown, each
  with a reason. Examples:
  - FNDDS "rice cake" is the puffed snack, not tteok.
  - The FNDDS meat dumpling is fried, so it is not used for jiaozi or
    pelmeni.

### 8.4 Medication identities from NLM RxNorm

- **Source.** `tool/data/rxnorm_2024-12-02/RXNCONSO_parkinson_reference_subset.RRF`
  holds 212 atoms from the RxNorm release of 2 December 2024. They form
  complete concept blocks, extracted by a script.
  - 25 ingredients, each with its FDA UNII.
  - 7 clinical drugs, each with its linked NDC products.
- **Verified identities.** Eighteen catalog medications carry verified
  ingredient identities, with codes such as `RXCUI_IN:2019+6375`. Opicapone
  keeps its DailyMed set id as the product code, and its ingredient identity
  is verified separately.
- **Clinical-drug entries.** Five carbidopa/levodopa clinical drugs become
  catalog entries:
  - 10/100, 25/100 and 25/250 mg tablets;
  - 25/100 and 50/200 mg extended-release tablets.

  Their release type is read from the RxNorm dose form, so the existing
  applicability policy still holds back extended-release forms.
- **Unverified.** Three medications stay unverified, each with a reason:
  - Safinamide: no concept was found in the reviewed release windows,
    including those around its March 2017 U.S. approval.
  - "Iron supplement": a generic class with no single salt.
  - Levodopa/benserazide: not marketed in the United States and outside
    RxNorm prescribable content.
- **Scope.** This is identity data only. No dose, schedule or recommendation
  is derived from it.
- **How the six later identities were located.** Pramipexole, rotigotine,
  droxidopa, pimavanserin, istradefylline and opicapone were added in a
  follow-up pass. The file is sorted by RxCUI, so small probes mapped byte
  offsets to RxCUIs. For newer drugs, brand-name atoms with known U.S.
  approval dates narrowed the search (for example, Nourianz sits next to
  istradefylline and Ongentys next to opicapone). Each identity was accepted
  only from its `RXNORM|IN` atom in a complete block. Two remembered RxCUIs
  (for safinamide and pimavanserin) were wrong and were rejected by this
  check.

### 8.5 Retrieval path

This environment's network policy blocks `fdc.nal.usda.gov`,
`download.nlm.nih.gov`, `rxnav.nlm.nih.gov` and `api.fda.gov`. Every file was
read through the Hugging Face connector from these public mirrors:

- `yvfu/FoodData_Central_csv_2025-04-24`
- `tramzel/fndds`
- `ULM-DS-Lab/food-composition-matrix`
- `OnDeviceMedNotes/nih-rxnorm-dec-2-2024`

The checks above detect transcription and join errors. They cannot detect an
upstream value that is wrong but internally consistent. Re-verify against
the official distributions before any use beyond this prototype.
