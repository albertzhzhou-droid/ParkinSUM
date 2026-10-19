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

## 9. Iteration 3 (2026-10-15) — official full profiles and a fidelity audit

### 9.1 What was added

The SR Legacy values used so far came through a third-party pivot of SR
Legacy 2018 that carried only 19 nutrients. This iteration reads the
official FoodData Central full download (release 2025-04-24) directly.

- **Nutrient rows.** For all 280 SR Legacy foods the app uses (224 reference,
  116 seed, 60 shared), every `food_nutrient.csv` row is committed verbatim:
  26,995 rows covering 148 nutrients.
  - Each row keeps its amount, number of data points, derivation code and,
    where reported, min/max/median.
  - Coverage: 11,688 values have data points > 0, 6,882 carry a min/max
    range, and every food reports water.
  - 241 foods report amino acids, 229 of them all 18.
  - The generated table carries the 15,856 rows the app maps: the 59
    nutrient definitions plus 18 amino acids.
- **Portions.** 788 household-measure gram weights for 277 of the foods; the
  other 3 have none in the source.
- **Derivation codes.** The complete table, 80 rows.

### 9.2 Fidelity check of the earlier data

Every value already committed was compared with the official rows. That is
3,991 reference values and 2,042 seed values (6,033 in total):

- All 6,033 match exactly.
- Every blank corresponds to a nutrient the official record does not report.

The mirror introduced no transcription error. The check is now a test.

### 9.3 What the catalogs gain

Reference foods, and seed foods matched to SR Legacy, now carry:

- **Water** from the official row.
- **An amino-acid profile.** It is built by the same extractor the FDC
  importer uses and includes per-amino-acid derivation provenance, so the
  LNAA layer can use actual fields instead of the protein-source proxy for
  these foods.
- **Portion records,** as evidence only: a portion never selects a serving
  or rescales a value.

FNDDS-matched seed foods are unchanged.

### 9.4 Provenance-aware closure

With full profiles the composition identity audit ran 2,624 checks across the
280 foods. The first run raised 27 proximate-closure mismatches. 19 of them,
and 32 records overall, carry carbohydrate derivation `Z` ("Assumed zero").
USDA did not compute carbohydrate by difference for those animal foods, so
water + protein + fat + ash need not sum to 100 g.

The closure identity now runs only when carbohydrate is calculated by
difference (`NC`) or its derivation is unreported. Other codes record the
check as skipped with a reason, not as a finding. Across the 280 foods:

- the check ran 236 times;
- it was skipped 44 times (32 assumed zero, 12 imputed or other);
- 4 genuine mismatches remain.

The FDC importer now passes derivation codes to the audit, so imported
records are handled the same way.

### 9.5 Remaining findings: inconsistencies inside the source

Every value equals the official row, so these 14 findings describe the
records themselves. They are pinned in
`test/reference_food_nutrient_profile_test.dart` and are never corrected.

| Finding | Foods | Explanation |
| --- | --- | --- |
| Sugars exceed carbohydrate by difference | Whole, 2% and nonfat milk | The excess is about 5.3%, the mass ratio of lactose monohydrate to anhydrous lactose (360.3 / 342.3). This is consistent with sugars reported as the monohydrate. |
| Sugars + starch + fibre exceed carbohydrate by difference | Brown rice (cooked), cashews, oats (cooked), blackberries | Independent analyses whose sum exceeds the difference value. |
| Closure mismatch with calculated carbohydrate | Coconut oil, turkey liver, unsalted butter, fish roe | Components disagree with the stored carbohydrate by 0.6–1.7 g. |
| Energy residual | Cider vinegar | About 5 g of acetic acid is outside the proximates (Section 2). |
| RAE below its components | Pork loin, raw | RAE 0 while β-carotene is reported. |
| Fatty-acid classes exceed total lipid | Navy beans, cooked | 0.73 g vs 0.62 g. |

### 9.6 Amino acids versus protein

Across 185 foods with all 18 amino acids and at least 1 g protein, the amino
acid sum ranges from 0.43 to 1.21 times protein (median 0.96). Low ratios
come from low-protein plant foods with non-protein nitrogen. The spread is
too wide for an identity, so no check is added. Protein is never derived
from amino acids or the other way round.

### 9.7 Retrieval

All files come from the Hugging Face mirror
`yvfu/FoodData_Central_csv_2025-04-24`.

- `food_nutrient.csv` (1.77 GB) was read in 55 KB windows. A food's rows were
  kept only when its whole block lay inside one window with another food on
  both sides.
- The 47 foods that appeared in two windows had byte-identical copies.
- The portion rows come from one contiguous byte range covering the entire
  SR Legacy portion block (14,449 rows).

## 10. Iteration 4 (2026-10-15) — LNAA calibration from official amino acids

### 10.1 The miscalibration

The competition model normalised an actual amino-acid profile by a competing
LNAA fraction of 0.45 g per g protein. No food in the reference set comes
close: across the 140 SR Legacy reference records with at least 2 g protein
and all six competing amino acids, the fraction runs from 0.12 (prunes) to
0.39 (Swiss cheese), with a median of 0.27. With 0.45 as the reference,
every real profile read as a low-load food. The protein-source proxy factors
(meat 1.15, dairy 1.10, grain 0.85) were illustrative and ranked meat above
dairy and grain well below meat. The official rows rank them differently.

### 10.2 Method

- Fraction = (Leu + Ile + Val + Phe + Tyr + Trp) / protein, from the
  published values of the same record.
- Eligible: reference records with protein ≥ 2 g per 100 g and all six
  amino acids reported. Raw Brussels sprouts (no tyrosine row) are excluded,
  as the competition model also refuses a five-of-six sum.
- Each record gets the protein source the app gives it at runtime, so a
  type is calibrated on exactly the foods that carry it.
- Two records share a pattern when, for all six amino acids, the intervals
  of amino acid / protein implied by the rounding of the published values
  overlap. Patterns are the connected components of that relation. 140
  records form 109 patterns.
- Statistics are taken over patterns (one value per pattern, the median of
  its members), with type-7 quantiles.

### 10.3 Results

| Source | Records | Patterns | Median fraction | Factor |
| --- | --- | --- | --- | --- |
| all | 140 | 109 | 0.2667 | 1 |
| dairy | 21 | 15 | 0.3381 | 1.268 |
| egg | 6 | 5 | 0.3154 | 1.183 |
| meat | 13 | 9 | 0.2643 | 0.991 |
| fish | 18 | 7 | 0.2637 | 0.989 |
| grain | 27 | 24 | 0.2634 | 0.987 |
| soy | 14 | 14 | 0.2566 | 0.962 |
| legume | 13 | 10 | 0.2484 | 0.931 |

Shared patterns reveal how the source tables were built. Twelve finfish
records (carp, cod, herring, mackerel, salmon, pollock, sardine, tuna) carry
one pattern scaled to their protein. Roquefort and feta carry the sheep-milk
pattern. Raw and cooked forms of rice, couscous, lentils, black beans,
broad beans, peas, spinach, turkey and lamb share theirs. Of the 140
records, 48 have all six amino-acid rows coded analytical; 83 have at least
one row whose derivation is unknown to the app (no code, or a code such as
`JA` or `O` that it does not classify).

### 10.4 What changed in the model

- The reference fraction is the all-food median (0.2667).
- Proxy factors are the type medians over it. Mixed and unknown stay at 1.
- The summary reports the reference fraction, a protein-weighted
  interquartile envelope of the factor, and whether a factor was clamped to
  the 0.5–1.5 domain. A clamp widens uncertainty.
- Catalog foods take their protein source from the curated group. Free-text
  inference now matches English whole words and Chinese food words. Before,
  every catalog food (Chinese display names) inferred `unknown` or `mixed`,
  and substring matches read eggplant as egg and oat milk as dairy.

The factors describe food composition. The mapping from load to competition
pressure remains a prototype heuristic and says nothing about a person, a
dose or a timing choice.

## 11. Iteration 5 (2026-10-19) — every official nutrient, more identities

### 11.1 Every nutrient in the official rows is mapped

The committed FoodData Central 2025-04-24 rows for the 280 SR Legacy foods
carry 148 distinct nutrients: 18 amino acids, which the amino-acid extractor
reads, and 130 others. All 130 now have a nutrient definition. The 86 new
definitions use the official name, number and unit from `nutrient.csv`: individual sugars, fluoride and betaine, food folate and
folic acid, added vitamin B-12 and vitamin E, the carotenoids and vitamin A
in IU, tocopherol and tocotrienol isomers, vitamin D in IU and as D2 and D3,
menaquinone-4 and dihydrophylloquinone, 14 saturated, 8 monounsaturated and
11 polyunsaturated chain lengths with their cis, n-3 / n-6 and isomer rows,
trans fatty acids, phytosterols and hydroxyproline. The generated profile
table now holds all 26,995 official rows, and a test checks each value
against the source CSV.

### 11.2 More definitional identities

Each identity follows from how the values are defined, so a violation is an
inconsistency inside the record:

- Listed fatty acids by chain length sum to no more than their class total.
  The class totals also include minor acids that are not listed, so only
  this direction is an identity.
- A cis, n-3 / n-6 or isomer row stays within its chain-length row, and
  total trans equals trans-monoenoic plus trans-polyenoic.
- Individual sugars sum to no more than total sugars.
- Vitamin A: RAE = retinol + β-carotene/12 + (α-carotene +
  β-cryptoxanthin)/24, and IU = retinol/0.3 + β-carotene/0.6 + (α-carotene
  + β-cryptoxanthin)/1.2 (Institute of Medicine, *Dietary Reference Intakes
  for Vitamin A …*, 2001).
- Vitamin D (µg) = D2 + D3, and IU = 40 × µg.
- Total folate = food folate + folic acid, and DFE = food folate + 1.7 ×
  folic acid (Institute of Medicine, *Dietary Reference Intakes for …
  Folate …*, 1998).
- Added vitamin B-12 stays within total B-12, and added vitamin E within
  α-tocopherol. Individual sterols stay within total phytosterols.

Across the 280 records the audit finds 11 new inconsistencies, pinned in
`test/reference_food_nutrient_profile_test.dart` and never corrected: listed
chains above their class total in ground beef (MUFA), cheddar (PUFA, 1.42 vs
0.94 g) and an almond beverage (SFA and PUFA); cis 18:1 of 0.015 g in three
brewed coffees whose 18:1 row is 0; 18:2 n-6 cis,cis (2.17 g) above 18:2
(1.83 g) in unsalted butter; and vitamin A IU disagreeing with its
components in blue cheese (721 vs 763 IU) and in two black-bean records that
report IU but no retinol or carotenoids. The RAE, folate, DFE and vitamin D
identities hold everywhere else.

### 11.3 What the conflict engine reads

When a meal component resolves to a reference food, the meal assessment
reads the findings of that food's official record that touch a value the
engine uses: general- and food-specific-factor energy, proximate closure,
carbohydrate fractions, sugars, fibre and starch within carbohydrate,
fatty-acid classes within total lipid, and protein from nitrogen. Thirteen
official records carry one, and twelve of them are catalog reference foods a
meal component can resolve to (unsalted butter is profiled but not in the
catalog). Micronutrient and single-chain findings stay in
the record audit.

Such a finding adds the uncertainty reason
`food_reference_record_identity_finding(<meal>:<component>:fdc_<id>:<code>)`,
counts in the interdependency trace, and, when the component's meal is
scored, caps high confidence at medium
(`confidence_capped:scored_reference_record_inconsistent`). The score,
severity and drivers do not change.

### 11.4 LNAA trace detail

When actual amino-acid fields cover the whole meal, the LNAA summary also
reports, for the trace only:

- each component's competing-LNAA grams and its share of the meal total;
- an extended sum that adds methionine and histidine, which also use the
  L-type amino-acid transporter, when every profile reports both;
- with an explicit logged levodopa amount, the molar ratio of the six
  competing LNAAs to levodopa, from molecular weights computed from the
  molecular formulas and IUPAC standard atomic weights (levodopa 197.19
  g/mol).

None of these feeds the load factor, the pressure curve or the score. Hybrid,
proxy and unknown modes carry none of them, and a persisted wire that has
them in another mode, or a molar ratio without an explicit amount, is
rejected as incoherent. A molar ratio describes the logged inputs; it is not
a threshold and says nothing about a person, a dose or a timing choice.
