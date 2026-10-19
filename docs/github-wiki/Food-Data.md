# Food data

<p align="center"><img src="https://raw.githubusercontent.com/albertzhzhou-droid/ParkinSUM/main/docs/github-wiki/assets/provenance.svg" width="960" alt="Official FoodData Central CSV pinned by SHA-256, a generator, a generated table of 26,995 rows for 280 foods, and tests that compare every value with the source."></p>

## Provenance in one line

The data comes from the official FoodData Central 2025-04-24 CSVs, committed and pinned by SHA-256. A generator writes the Dart table, and tests re-read the CSV and compare every value and derivation code. **Values are never retyped and never "corrected".**

- **Coverage:** 280 SR Legacy foods, 148 distinct nutrients. The 18 amino acids go through the amino-acid extractor; the other 130 have official definitions (id, number, name, unit).
- **Detail:** individual sugars, carotenoids, tocopherol isomers, vitamin D2/D3, folate forms, and 33 fatty-acid chain lengths with their cis, n-3/n-6 and trans rows.
- **Portions:** official gram weights per household measure.

## Identities, not typical values

The audit checks only relations that follow from definitions: energy from macronutrients, proximate closure, parts within a whole (sugars, starch and fibre within carbohydrate; chains within their class; individual sugars within total sugars), vitamin A RAE and IU, vitamin D µg↔IU, folate and DFE, and fortification amounts within totals. **25 findings** across the 280 records are inconsistencies inside the source. They are pinned in tests and kept as published.

## LNAA calibration

<p align="center"><img src="https://raw.githubusercontent.com/albertzhzhou-droid/ParkinSUM/main/docs/github-wiki/assets/lnaa-calibration.svg" width="960" alt="Median competing-LNAA fraction of protein per protein source: dairy 0.338, egg 0.315, meat 0.264, fish 0.264, grain 0.263, soy 0.257, legume 0.248. The reference line moves from the old value 0.45 to the all-food median 0.2667."></p>

The old reference fraction of 0.45 g competing LNAA per g protein matched no real food. Across 140 SR Legacy records (109 shared amino-acid patterns), the fraction runs 0.12–0.39 with a median of **0.2667**. Each protein source's factor is its median over that value. The calibration set is a convenience sample of catalog foods, not a dietary-intake weighting.

Read more: [research note](https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/FOOD_COMPOSITION_INTERDEPENDENCY_RESEARCH_2026-10-08.md) · [known risks R14](https://github.com/albertzhzhou-droid/ParkinSUM/blob/main/docs/known_risks.md)
