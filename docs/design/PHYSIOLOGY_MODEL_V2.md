# Physiology reference model v2 (prototype)

Status: research prototype in `tool/physiology_reference/` (Python standard
library), ported to Dart as a trace-only provider in Stage B (see "Path into
the app"). No score, rule outcome or recommendation order reads it.
Educational only: it simulates
population-typical curves for synthetic scenarios. It is not a prediction for
any person, not a clinical cutoff, and not dosing, timing or dietary advice.
Review any health decision with a qualified clinician.

## Why a second model

The mechanistic engine is carefully governed, but its checks confirm
provenance and arithmetic, not agreement with human measurements. Reproducing
its formulas (identity v78) exposed physics errors that no existing gate could
catch:

- *Fixed in identity v79 (`860f2ad`).* Protein-competition timing followed the
  meal's total mass, not its protein. For the Observatory's oatmeal-plus-water
  meal the modeled pressure peaked 5 minutes after eating, driven by water
  that carries no protein. The Dart fix now peaks at 20 min; this reference
  gives 25 min.
- *Fixed in identity v79.* Every liquid emptied with a 15-minute half-time, so
  a 300 kcal protein shake was 90% emptied in 45 minutes. The Dart fix now
  half-empties it at 70.4 min; this reference gives 74 min.
- *Open.* Competition at the blood-brain barrier, the mechanism Nutt et al.
  (1984) showed dominates protein's effect, is named but not quantified.
- *Open.* Outputs are unitless indices, so nothing can be compared with
  published data.

This prototype rebuilds the chain in physical units and tests it against
published human results before any of it reaches the app.

## Structure

| Stage | Representation | Output units |
| --- | --- | --- |
| Stomach, solids | Two grinding stages in series (lag), then the emptiable pool | kcal |
| Stomach, energy-containing liquids | Emptiable immediately | kcal |
| Emptying | Calorie-limited: `R = R_max * P / (P + E50)`, shared by components in proportion to their emptiable energy | kcal/min |
| Water and dissolved levodopa | First order, slowed by energy still in the stomach: `k = k_fast / (1 + F / F50)` | mL, mg |
| Levodopa | Tablet → dissolved → absorptive gut segment → one plasma compartment (apparent CL/F, V/F) | mg/L |
| Amino acids | Each component delivers its own amino acids as its energy empties; digestion/absorption first order; splanchnic first-pass fraction; one plasma pool per amino acid relaxing to fasting | µmol/L |
| Brain entry | Competitive Michaelis-Menten at the blood-brain barrier: `B = (1 + Σ Cb_i/Km_i) / (1 + Σ C_i/Km_i)`, the levodopa entry rate relative to the same plasma level when fasting | ratio |

Water no longer moves protein timing, because protein travels only with the
component that contains it. Phenylalanine and tryptophan weigh more than valine
in `B`, because affinity differs between amino acids.

Deliberately excluded:

- Intestinal transporter competition. Carter et al. (1989) found plasma
  levodopa unchanged across protein diets while plasma amino acids changed.
- A motor-response (pharmacodynamic) layer. Predicting ON/OFF states would
  move the model toward individualized clinical output.

## Parameters

`parameters.json` records value, unit, source and status for each parameter:

- **literature:** a published point value. This covers the 2.13 kcal/min
  energy delivery and the 30 L/h clearance.
- **calibrated:** fitted to one named target, which therefore does not
  validate it. There are three:
  - solid grinding rate, fitted to Tougas 2000;
  - fed-state liquid slowing, fitted to Nutt's 34-minute delay;
  - effective amino-acid volume, fitted to Carter's two evenly distributed
    diets.
- **heuristic:** a stated modeling choice. This includes the post-meal
  amino-acid relaxation half-time of 60 min, a prior set before fitting.
  Carter's daily means cannot identify it: any value from 45 to 180 min fits
  them equally well.
- **verify:** transcribed and still to be re-checked against the primary
  table. This covers the BBB Km set (Smith et al. 1987) and the fasting plasma
  amino-acid values.

Population variability (log-normal, seeded) is declared per parameter.
Clearance carries 38% and absorption 60%, from Simon et al. 2016. Energy
delivery carries 25%, matching healthy-volunteer spread.

## Reality checks

`python3 -I tool/physiology_reference/reality_checks.py` runs 15 checks. The
kinds are defined in the script: *calibrated* checks only show the fit held,
and *independent* checks are the real tests.

| Check | Kind | Result | Target |
| --- | --- | --- | --- |
| Glucose drink energy rate (Brener 1983) | structural | 2.02 kcal/min | 2.13 ± 10% |
| Solid retention 1/2/4 h (Tougas 2000) | calibrated | 67% / 25% / 1% | 69% / 24% / 1.2% |
| Fasting levodopa peak time | independent | 55 min | 30-60 min |
| Levodopa half-life with carbidopa | structural | 90 min | 80-100 min |
| Meal delay of the levodopa peak (Nutt 1984) | calibrated | 34 min | 34 ± 5 min |
| Meal reduction of the levodopa peak (Nutt 1984) | independent | 19% | 29% ± 12 points |
| Oral phenylalanine load with infused levodopa (Nutt 1984) | independent | brain-entry index 0.54; plasma unchanged | material drop; plasma flat |
| Oral leucine load with infused levodopa (Nutt 1984) | independent | 0.66; plasma unchanged | material drop; plasma flat |
| Glycine load (not a carrier substrate) | structural | 1.00 | no change |
| Daytime plasma LNAA, even diets (Carter 1989) | calibrated | 729 / 647 µmol/L | 732 / 640 |
| Daytime plasma LNAA, protein only at dinner (Carter 1989) | known gap | 609 µmol/L | 542 ± 5% |
| Plasma levodopa unchanged across diets (Carter 1989) | structural | 0% spread | < 10% |
| Whey vs casein (Boirie 1997) | independent | whey earlier and higher, casein longer | direction only |
| Water does not move protein timing | structural | identical peak | identical |
| 300 kcal shake half-emptying | structural | 74 min | 50-90 min |

What this does and does not show:

- The independent checks pass under the scenario assumptions written in
  `scenarios.py`. The abstracts do not report meal compositions, schedules or
  body weights, so those are assumed.
- The meal peak reduction lands at the low edge (19% against 29%). Gut
  transporter competition, which is not modeled, is a candidate for the
  difference.
- The Nutt and Boirie checks test direction and specificity only, because the
  abstracts give no effect sizes.
- **Known gap.** With protein restricted to dinner, Carter et al. measured a
  daytime mean of 542 µmol/L, essentially the fasting level, despite a 50 g
  protein dinner inside the sampling window. The model gives 609. A likely
  missing mechanism is carbohydrate-driven, insulin-mediated lowering of plasma
  branched-chain amino acids after the protein-free daytime meals, possibly
  together with fasting levels that adapt to habitual intake. The check stays
  in the suite as an expected failure. If it starts passing, the run fails and
  someone has to explain why.

## What-if prototype

`python3 -I tool/physiology_reference/whatif.py` runs a synthetic 100 mg
immediate-release dose with a ~600 kcal, 30 g protein meal at different
offsets. Each value is a median with its 5th-95th percentile from 200 seeded
draws. Areas cover 0-4 h after the dose, relative to the same draw with no meal.

| Scenario | Peak time (min) | Peak (mg/L) | Brain delivery area |
| --- | --- | --- | --- |
| No meal | 52 (35-82) | 1.14 (0.77-1.67) | reference |
| Meal 60 min before dose | 86 (56-144) | 0.93 (0.60-1.44) | 78% (65-86%) |
| Meal with dose | 94 (61-169) | 0.89 (0.58-1.40) | 80% (64-88%) |
| Meal 30 min after dose | 46 (32-82) | 1.07 (0.70-1.62) | 91% (80-95%) |
| Meal 60 min after dose | 52 (35-74) | 1.14 (0.77-1.67) | 95% (89-97%) |

![Modeled plasma levodopa and brain-entry index](assets/physiology-whatif.svg)

The direction of a meal relative to the dose matters, and the shipped
user-facing score cannot show it, because it treats both directions the same
(`database_backed_meal_check_usecase.dart`, `_proteinTimingPenalty`). The
window and meal are synthetic choices: the table is a comparison of modeled
curves, not a ranking or a recommended time.

## Path into the app

1. **Port the model (Stage B, done as a trace provider).** The whole
   reference, not only the stomach, now runs in Dart:
   - `lib/domain/entities/physiology_reference_parameters.dart` mirrors
     `parameters.json` value for value, with unit, status, source text and
     registered source ids; a test fails if the two drift apart. The Km set
     and the fasting amino-acid values keep the status "verify".
   - `lib/domain/usecases/physiology_reference_model.dart` integrates the same
     equations in the same operation order, and reproduces CPython's seeded
     random stream (MT19937 and `random.gauss`), so population bands match
     the reference draw for draw.
   - `lib/domain/usecases/physiology_reference_trace_provider.dart` builds the
     timing comparison: a synthetic 100 mg immediate-release dose at minute
     0, a meal at an offset, 0–4 h areas relative to the same draw with no
     meal, 100 seeded draws (seed 20261020). It is registered as
     `physiology_reference_model` with its own trace-provider contract. It
     changes no rule outcome and orders nothing; since step 4 its band
     median sets the meal check's protein-timing score term, and since step 5
     it feeds the Next-meal planner. A measured amino-acid profile with all
     eight competing amino acids now replaces the mixed-protein composition
     for that food (`physiologyComponentFromFood`).
   The v79 stomach in the shipped engine is unchanged; the two still agree on
   the regression checks (water does not move protein timing; the 300 kcal
   shake half-empties at 70.4 min there and 74 min here).
2. **Carry units in traces (done for the new provider).** Every series
   declares its unit (mg/L, µmol/L, kcal/min, kcal, mL, ratio). The
   Algorithm Observatory shows a new panel, "Physiology reference model
   (physical units)", with plasma levodopa, plasma LNAA and the brain-entry
   index for no meal and a meal 60 min before, with, and 60 min after the
   dose, a band table, and the light/dark palette of `whatif.py`. The scaled
   "×40" lines of the shipped gastric panel remain until that engine is
   replaced.
3. **Gate on reality (done).** `npm run physiology:reality` is a verify:all
   gate (`physiology_reality`), so CI enforces it:
   - `reality_checks.py` (15 checks; 14 pass, 1 known gap);
   - `agreement.py --check`, which recomputes
     `test/fixtures/physiology_reference_agreement.json` and fails when the
     committed fixture no longer matches the Python model;
   - `tool/run_physiology_reference_agreement.dart` and
     `test/physiology_reference_agreement_test.dart`, which require the Dart
     port to reproduce every fixture number within 1e-9 relative plus 1e-12
     absolute. The fixture covers a fasting dose, the meal with the dose, the
     meal 60 min before and after, the Tougas meal, the Brener drink, the three
     Carter diets, the Nutt phenylalanine, leucine and glycine loads, whey and
     casein, the 21 reality-check quantities derived from them, the
     Observatory rows with their bands, and six meal-timing effects:
     12,295 numbers. On the development machine (macOS, CPython 3.9) the
     largest difference is 0; CPython 3.12 sums floats with compensation, so
     CI may differ in the last digits, well inside the tolerance.
4. **Direction-aware timing (done).** For a logged meal and the nearest
   intake of an oral immediate-release levodopa-like medicine, the meal check
   adds one data note: "In this educational model, this meal timing lowers
   modeled brain entry of levodopa to about X% of no meal (population band
   a–b%, over the 4 hours after the dose)…". It reads the meal's energy,
   protein and physical form and the meal-to-dose offset, never the dose, and
   is omitted when an input is missing or the meal is more than 6 h before or
   4 h after the dose. The same comparison now sets the score's
   protein-timing term (`_proteinTimingPenalty`,
   `database_backed_meal_check_usecase.dart`), which was direction-blind:

       points = round(24 × clamp((1 − r) / 0.30, 0, 1))

   where r is the median of the seeded band of 0–4 h brain delivery relative
   to no meal. r ≥ 1 gives 0, r = 0.85 gives 12 and r ≤ 0.70 gives 24 (24 was
   the old table's maximum, so the term keeps its scale). The factor label
   names the modeled percentage. When the model does not apply (no intake,
   not oral immediate release, a missing meal input, offset out of range) the
   earlier distance table is the fallback: 10 without an intake, else
   24 / 16 / 8 / 0 for ≤ 60 / ≤ 120 / ≤ 180 / > 180 min. A meal 30 min before
   the dose now scores higher than the same meal 30 min after it
   (`test/database_backed_meal_check_usecase_test.dart`). The term only
   applies above the existing protein threshold, as before.
5. **Build the what-if view (done: Next-meal planner).** The Next-meal page
   is now a planner: the user picks a time with −15 / +15 buttons, a typed
   time or anchors taken from logged doses, browses foods at a reference
   serving as cards, builds a plate with serving steppers and sees plasma
   levodopa and the brain-entry index against no meal with population bands,
   updated live as the time moves. There is no ranking and no "best time";
   the list's order is the user's sort choice. `NextMealPlanner`
   (`lib/domain/usecases/next_meal_planner.dart`, registered as
   `next_meal_planner`) reads the provider through three entry points:
   `centralBrainDeliveryRelative` (one run, used for list sorting),
   `mealTimingComparison` (central plus band of brain delivery and plasma
   area, used for card chips and compare) and `compareCurves` (per-time
   5th–95th percentile curves on a 5-minute grid, used for the plate chart).
   Results are cached per food (or plate), servings and whole-minute offset.
   The modeled value requires an oral immediate-release levodopa intake with
   a confirmed dose bound to it; the ratios themselves do not depend on the
   dose. A dose logged with a product strength carries that product record's
   own form, route and release type (`withProductFormulation` in
   `intake_dose_context_builder.dart`): the openFDA SPL dosage-form term is
   stored as `spl:<TERM>` and mapped by an explicit table. A term with
   "EXTENDED RELEASE" or "DELAYED RELEASE" is modified release; TABLET,
   TABLET FILM COATED, TABLET COATED, TABLET CHEWABLE, TABLET ORALLY
   DISINTEGRATING and CAPSULE are conventional (immediate) release; any
   other term, or an intake saved before this, stays unspecified and the
   planner says so. Nothing is inferred from a medication or product name.
   When no logged dose is within the modeled window the planner says so and
   gives the nearest dose's distance in days and hours instead of comparing. A food whose physical form is not recorded (206 of 244 catalog foods
   today) is modeled twice, as solid and as liquid, and shown as the range
   between the two with the union of their bands, rather than guessed.
6. **Cover more formulations.** Levodopa/benserazide shares the same PK
   structure; its published concentration-effect C50 differs (Trocóniz et al.
   1998), which only matters for an excluded PD layer. Entacapone changes
   clearance and timing. Controlled- and extended-release forms need a release
   input model, and stay non-executable until then.

## Verification still needed

- BBB Km values against the Smith et al. 1987 table.
- Fasting plasma amino-acid reference values, from a cited reference-range
  source.
- Energy of the consensus scintigraphy meal (assumed 255 kcal).
- The Nutt 1984 meal composition, from the full text. The 34-minute
  calibration depends on it.
- Postprandial amino-acid time courses, from full-text figures (e.g. Boirie
  1997), to turn the direction-only check into a magnitude check.

## Sources

- Brener W et al. Gastroenterology 1983;85:76-82. PMID 6852464.
- Tougas G et al. Am J Gastroenterol 2000;95:1456-62. DOI 10.1111/j.1572-0241.2000.02076.x. PMID 10894578 (registered as `src.tougas.gastric.lowfat_controls.2000`; not the simplified-scintigraphy paper PMID 10638563).
- Abell TL et al. Am J Gastroenterol 2008;103:753-63. DOI 10.1111/j.1572-0241.2007.01636.x.
- Elashoff JD et al. Gastroenterology 1982;83:1306-12. PMID 7129034.
- Nutt JG et al. N Engl J Med 1984;310:483-8. DOI 10.1056/NEJM198402233100802.
- Carter JH et al. Neurology 1989;39:552-6. DOI 10.1212/wnl.39.4.552.
- Pincus JH, Barry KM. Arch Neurol 1987;44:1006-9. DOI 10.1001/archneur.1987.00520220012007.
- Boirie Y et al. PNAS 1997;94:14930-5. DOI 10.1073/pnas.94.26.14930.
- Smith QR et al. J Neurochem 1987;49:1651-8. DOI 10.1111/j.1471-4159.1987.tb01039.x.
- Pardridge WM, Choi TB. Fed Proc 1986;45:2073-8. PMID 3519291.
- Othman AA, Dutta S. Br J Clin Pharmacol 2014;78:94-105. DOI 10.1111/bcp.12324.
- Simon N et al. Eur J Clin Pharmacol 2016;72:423-30. DOI 10.1007/s00228-016-2034-0.
- Contin M, Martinelli P. J Neurol 2010;257 Suppl 2:S253-61. DOI 10.1007/s00415-010-5728-8.
- Trocóniz IF et al. Clin Pharmacol Ther 1998;64:106-16. DOI 10.1016/S0009-9236(98)90028-5.
