# Physiology reference model v2/v3 (prototype)

Status: research prototype in `tool/physiology_reference/` (Python standard
library), ported to Dart as a trace-only provider in Stage B (see "Path into
the app"). v3 (2026-10-23) extends the nutrition side only: protein-type
amino-acid profiles and digestibility, splanchnic first pass, insulin action
and habitual-intake disposal, with nutrition-only outputs for the planner. No score, rule outcome or recommendation order reads it.
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

v3 (2026-10-23) extends the nutrition side only. The levodopa chain, its
parameters and its outputs are unchanged from v2: every levodopa curve, peak
time, peak and plasma area in the agreement fixture is bit-identical to the
v2 fixture.

| Stage | Representation | Output units |
| --- | --- | --- |
| Stomach, solids | Two grinding stages in series (lag), then the emptiable pool | kcal |
| Stomach, energy-containing liquids | Emptiable immediately | kcal |
| Emptying | Calorie-limited: `R = R_max * P / (P + E50)`, shared by components in proportion to their emptiable energy. Fat, protein and carbohydrate act through their energy (Hunt & Stubbs 1975) | kcal/min |
| Water and dissolved levodopa | First order, slowed by energy still in the stomach: `k = k_fast / (1 + F / F50)` | mL, mg |
| Levodopa (unchanged) | Tablet → dissolved → absorptive gut segment → one plasma compartment (apparent CL/F, V/F) | mg/L |
| Amino-acid source (v3) | Measured profile, else the protein type's USDA FDC profile (whey, casein, soy, meat, egg, cereal), else the mixed default | g |
| Digestion (v3) | The truly ileal-digestible fraction of each protein type (human 15N studies) is absorbed first order at that type's rate; the rest never reaches plasma | µmol/min |
| Splanchnic first pass (v3) | Leucine 0.80 and phenylalanine 0.70 reach plasma (Matthews 1993); others assumed | fraction |
| Insulin action (v3) | Carbohydrate leaving with each component is absorbed first order; insulin action follows with a delay; `E = I / (I + I50)` lowers the plasma relaxation target, `dC/dt = f*A/V - k_out * (C - Cb * (1 - s * Emax * E))`, fully for branched-chain amino acids and half for the others | µmol/L |
| Habitual-intake disposal (v3) | When a scenario states a habitual protein intake, `k_out` scales with Price 1994's fasting nitrogen loss at that intake relative to 1.0 g/kg/day | 1/min |
| Brain entry | Competitive Michaelis-Menten at the blood-brain barrier: `B = (1 + Σ Cb_i/Km_i) / (1 + Σ C_i/Km_i)` (formula and Km unchanged) | ratio |

Water does not move protein timing, because protein travels only with the
component that contains it. Missing is not zero: an omitted amino-acid
profile falls back to the protein type's table (or the mixed default), and
omitted carbohydrate to a stated share of non-protein energy (or, with fat
grams, to the energy left after protein and fat).

Deliberately excluded:

- **Drug-side extensions.** The v3 brief first planned two-compartment
  levodopa disposition, formulation and decarboxylase-inhibitor inputs, COMT
  inhibition, intestinal levodopa competition, motor-complex effects on drug
  emptying and body-weight scaling of drug pharmacokinetics. The scope was
  narrowed to the nutrition side ("we should never predict user on the drug
  side"), so none of these were added and the levodopa parameters stayed at
  their v2 values.
- **Intestinal transporter competition.** Carter et al. (1989) found plasma
  levodopa unchanged across protein diets while plasma amino acids changed.
- **Any motor-response, ON/OFF or symptom layer.** Predicting motor states
  would turn population curves into individualized clinical output.
- **Viscous fibre.** Guar slows emptying only at high concentrations (36 g/L:
  115 vs 73 min; 22.5 and 5 g/L: no change), food data report total, not
  viscous, fibre, and fibre is not a model input; kept as a known gap.

## Parameters

`parameters.json` records value, unit, source and status for each of its 26
parameters:

- **literature:** a published point value: the 2.13 kcal/min energy delivery,
  the 30 L/h levodopa clearance, the FDC protein-type amino-acid profiles, the
  human true ileal digestibilities (milk 94.6%, soy 91%, cooked egg 90.9%,
  meat 92.1%, wheat 90.3%) and Price 1994's fasting nitrogen losses.
- **calibrated:** fitted to one named target, which therefore does not
  validate it. There are four:
  - solid grinding rate, fitted to Tougas 2000 (0.0312/min, unchanged);
  - fed-state liquid slowing, fitted to Nutt's 34-minute delay (231.4 kcal,
    unchanged: the fit reproduces v2's value exactly);
  - maximal insulin lowering, fitted to Shaham 2008's 33% leucine/isoleucine
    fall 2 h after 75 g glucose (0.8895);
  - effective amino-acid volume, fitted to Carter's two evenly distributed
    diets (29.3 L; v2 73.9 L). It is smaller because insulin action now lowers
    the daytime baseline, so the same daily means need larger meal rises.
- **heuristic:** a stated modeling choice: the 60 min amino-acid relaxation
  half-time, the protein-type digestion half-times (whey 15, soy 20, egg,
  mixed and casein 30, cereal 35, meat 40 min; the order follows Boirie 1997,
  Bos 2003, Tang 2009 and Pennings 2013, the magnitudes do not), the insulin
  delays and half-effect, the 0.55 default carbohydrate share, and the
  splanchnic fractions other than leucine and phenylalanine.
- **verify:** transcribed and still to be re-checked against the primary
  table: the BBB Km set (Smith et al. 1987) and the fasting plasma amino-acid
  values.

Population variability (log-normal, seeded) is declared per parameter.
Clearance carries 38% and absorption 60%, from Simon et al. 2016. Energy
delivery carries 25%, matching healthy-volunteer spread; maximal insulin
lowering carries an illustrative 30%.

## Reality checks

`python3 -I tool/physiology_reference/reality_checks.py` runs 28 checks (v2:
15). The kinds are defined in the script: *calibrated* checks only show the
fit held, and *independent* checks are the real tests. v3 counts: 11
structural, 4 calibrated, 9 independent, 4 known gaps; none fail.

| Check | Kind | v2 result | v3 result | Target |
| --- | --- | --- | --- | --- |
| Glucose drink energy rate (Brener 1983) | structural | 2.02 kcal/min | 2.02 kcal/min | 2.13 ± 10% |
| Solid retention 1/2/4 h (Tougas 2000) | calibrated | 67% / 25% / 1% | 67% / 25% / 1% | 69% / 24% / 1.2% |
| Fasting levodopa peak time | independent | 55 min | 55 min | 30-60 min |
| Levodopa half-life with carbidopa | structural | 90 min | 90 min | 80-100 min |
| Meal delay of the levodopa peak (Nutt 1984) | calibrated | 34 min | 34 min | 34 ± 5 min |
| Meal reduction of the levodopa peak (Nutt 1984) | independent | 19% | 19% | 29% ± 12 points |
| Oral phenylalanine load with infused levodopa (Nutt 1984) | independent | index 0.54; plasma unchanged | index 0.30; plasma unchanged | material drop; plasma flat |
| Oral leucine load with infused levodopa (Nutt 1984) | independent | 0.66; plasma unchanged | 0.45; plasma unchanged | material drop; plasma flat |
| Glycine load (not a carrier substrate) | structural | 1.00 | 1.00 | no change |
| Daytime plasma LNAA, even diets (Carter 1989) | calibrated | 729 / 647 µmol/L | 729 / 645 µmol/L | 732 / 640 |
| Daytime plasma LNAA, protein only at dinner (Carter 1989) | known gap → **independent** | 609 µmol/L | **530 µmol/L** | 542 ± 5% |
| Plasma levodopa unchanged across diets (Carter 1989) | structural | 0% spread | 0% spread | < 10% |
| Whey vs casein (Boirie 1997) | independent | whey earlier and higher, casein longer | same (whey +388 at 84 min, casein +275 at 144 min) | direction only |
| Water does not move protein timing | structural | identical peak | identical peak | identical |
| 300 kcal shake half-emptying | structural | 74 min | 74 min | 50-90 min |
| 50 g glucose in 250 mL half-emptying (Blackburn 1984) | known gap (planned independent) | — | 51 min | 73 ± 16 min |
| Guar 36 g/L slows that drink (Blackburn 1984) | known gap | — | 51 min (fibre not an input) | 115 ± 30 min |
| Isocaloric fat- vs carbohydrate-rich meals (Hunt & Stubbs 1975) | structural | — | identical | identical |
| Added energy slows lettuce-meal solids (Moore 1984) | structural | — | 49% / 79% / 94% retained at 60 min | increasing |
| Liquid emptying independent of meal energy (Moore 1984) | known gap | — | water half-emptying 13 / 19 / 36 min | within 25% |
| Soy before milk protein in a mixed meal (Bos 2003) | known gap (planned independent) | — | 5.3 vs 5.7 h | 2.5 h and 3.9 h ± 45 min |
| Whey > soy > casein leucine rise (Tang 2009) | structural | — | +275 / +213 / +159 µmol/L | ordered |
| Digestibility mass balance (cooked egg, Evenepoel 1998) | structural | — | exact | within 2% |
| Leucine fall 2 h after 75 g glucose (Shaham 2008) | calibrated | — | 33.0% | 33% ± 2 points |
| Half-maximal time of that fall (Shaham 2008) | independent | — | 66 min | 50-72 min |
| Carbohydrate- vs protein-rich breakfast ratios (Wurtman 2003) | independent | — | tryptophan 88%, tyrosine 33% | 36-88% / 10-64% |
| Protein-free meals lower LNAA (Fernstrom 1979) | independent | — | −27% / −34% / −36% | below fasting |
| Missing composition is not zero | structural | — | precedence and default share hold | as stated |

What this does and does not show:

- **The Carter evening-diet gap closes, and only with both nutrition
  mechanisms.** Ablations on the same scenarios: with neither (v2) the evening
  mean is 609 µmol/L. Insulin action alone, at Shaham's strength, breaks the
  even-diet calibration (best single-volume fit 762 / 581 against 732 / 640),
  because with linear protein rises the high-versus-even difference leaves
  room for almost no daytime baseline offset. Habitual-intake disposal alone
  also misfits them (708 / 672; evening 621). Together, with Price 1994's
  table taken as published and not fitted, the conflict disappears: the even diets fit (729 / 645) and the evening diet, which was
  not used for fitting, lands at 530 (−2.2%). The check is reclassified from
  known gap to independent. Its pass rests on the scenario assumptions in
  `scenarios.py` (meal times, energies, a 0.55 carbohydrate share of
  non-protein energy, and each diet's daily protein as its habitual intake).
- **An alternative was rejected.** In an intermediate configuration of this
  work, fitting a habitual-intake slope of the fasting levels jointly with the
  volume also matched the evening diet (543 µmol/L), but needed fasting levels
  that *fall* with more protein (slope −0.35), contradicting Fernstrom 1979.
  It was not adopted.
- **Planned independent checks that failed are kept visible as known gaps.**
  The calorie-constant Brener rate empties Blackburn's 50 g glucose drink in
  51 min, not 73. In Bos 2003's ~770 kcal mixed meal the order soy-before-milk
  holds, but the model's plasma LNAA peaks at 5.3 and 5.7 h, not 2.5 and
  3.9 h: calorie-limited emptying of a large solid meal keeps delivering
  protein until the stomach is empty, so single-meal peaks come late and close
  together.
- **Moore 1984's liquid finding conflicts with the fed-state liquid slowing.**
  Moore saw liquid emptying unchanged by meal energy; the model slows water
  with the energy in the stomach, which the Nutt 34-minute calibration (a
  drug-side output) relies on. It stays a known gap.
- **The Wurtman tryptophan difference sits at the edge of the subject range**
  (88% against 36-88%; median 54%): the insulin effect on tryptophan, set at
  half the branched-chain effect, may be too strong.
- The meal peak reduction stays at the low edge (19% against 29%). Gut
  transporter competition was not added (drug side).
- The Nutt, Boirie, Tang and Fernstrom checks test direction only, because
  the abstracts give no effect sizes. Boirie 1997's full text reports plasma
  leucine only in a figure and a percentage table whose columns could not be
  attributed reliably, so the check was not extended to magnitudes.

## What-if prototype

`python3 -I tool/physiology_reference/whatif.py` runs a synthetic 100 mg
immediate-release dose with a ~600 kcal, 30 g protein meal at different
offsets. Each value is a median with its 5th-95th percentile from 200 seeded
draws. Areas cover 0-4 h after the dose, relative to the same draw with no meal.
Peak time and peak are unchanged from v2; the brain-delivery area is lower
because the v3 amino-acid side (insulin action, smaller effective volume,
splanchnic fractions) raises plasma LNAA more after a protein meal.

| Scenario | Peak time (min) | Peak (mg/L) | Brain delivery area (v3) | v2 |
| --- | --- | --- | --- | --- |
| No meal | 53 (36-86) | 1.14 (0.77-1.69) | reference | reference |
| Meal 60 min before dose | 86 (54-160) | 0.92 (0.57-1.35) | 69% (49-87%) | 78% (65-86%) |
| Meal with dose | 94 (58-174) | 0.88 (0.53-1.30) | 73% (53-89%) | 80% (64-88%) |
| Meal 30 min after dose | 46 (33-91) | 1.05 (0.66-1.60) | 86% (72-95%) | 91% (80-95%) |
| Meal 60 min after dose | 53 (36-77) | 1.13 (0.77-1.69) | 92% (82-97%) | 95% (89-97%) |

![Modeled plasma levodopa and brain-entry index](assets/physiology-whatif.svg)

The direction of a meal relative to the dose matters, and the shipped
user-facing score cannot show it, because it treats both directions the same
(`database_backed_meal_check_usecase.dart`, `_proteinTimingPenalty`). The
window and meal are synthetic choices: the table is a comparison of modeled
curves, not a ranking or a recommended time.

## Nutrition-only outputs (v3)

`lib/domain/usecases/physiology_nutrition_outputs.dart` (mirroring
`competing_lnaa_load` and `meal_response` in `model.py`) gives the planner
nutrition-only numbers that read no medicine and no dose:

- **Competing-LNAA load** of a serving or plate: the six competing LNAAs as
  ingested and as truly ileal-digestible µmol, per component with its profile
  basis (measured, protein-type table, mixed default). Composition only, no
  simulation.
- **Plasma LNAA rise and its time course**: pre-meal level, peak rise, time of
  peak and rise area over 0-4 h after the meal.
- **Amino-acid appearance timing**: µmol of competing LNAAs reaching plasma
  in 4 h, the time by which half has appeared, and the time of peak
  appearance.

`PhysiologyNutritionProvider.summarize` adds 5th/50th/95th percentile bands
from the same 100 seeded draws (seed 20261020); `central` runs one simulation
for list views. Central values (bands for two outputs) for the fixture's
synthetic meals:

| Meal | Competing LNAA ingested / digestible (µmol) | Peak LNAA rise (µmol/L) | Half appearance (min) |
| --- | --- | --- | --- |
| Whey shake, 25 g protein | 50,338 / 47,620 | 696 (426-1,105) | 49 (36-71) |
| Steak and potatoes, 44 g | 88,504 / 81,504 | 474 (180-856), still rising at 4 h | 149 (132-157) |
| Oatmeal with milk, 15 g | 30,576 / 28,131 | 96 (28-244) | 107 (80-127) |
| Two eggs and toast, 18 g | 37,727 / 34,238 | 212 (43-436) | 129 (103-150) |
| Mixed lunch, 30 g (mixed default) | 57,307 / 52,722 | 195 (23-470) | 144 (133-151) |

Single-meal rise magnitudes are not validated against human data (see
"Verification still needed"); treat them as model outputs for comparing
foods, not as expected plasma values.

Cost (Dart, macOS, JIT): one 390-min timing simulation 0.50 ms (v2 0.41 ms,
+20%); one 240-min nutrition simulation 0.5 ms; a banded result (101
simulations) 26-39 ms. List chips can stay on the single central simulation.
Python: timing 21 ms, nutrition 11 ms, a two-day Carter scenario 131 ms.

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
   - `reality_checks.py` (28 checks in v3; none fail, 4 known gaps);
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
     12,295 numbers in v2. v3 adds the Shaham, Wurtman, Tang, Bos and Moore
     scenarios, their derived quantities and the nutrition outputs with
     bands for five synthetic meals: 24,597 numbers. On the development machine
     (macOS, CPython 3.9) the largest difference is 0; CPython 3.12 sums floats with compensation, so
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
6. **Formulations stay out of scope.** Decision of 2026-10-23: the model does
   not extend the drug side (formulations, decarboxylase inhibitors, COMT
   inhibitors, drug pharmacokinetics). Only immediate-release levodopa is
   executable, as in v2; anything else is refused.
7. **Use the nutrition outputs (v3).** The Next-meal planner can read the
   competing-LNAA load, plasma LNAA rise and appearance timing with bands
   (`PhysiologyNutritionProvider`) instead of, or next to, the brain-delivery
   ratio. The meal converter does not yet pass carbohydrate grams, fat grams
   or a protein type, so app meals use the default carbohydrate share and the
   mixed profile until it does.

## Verification still needed

- BBB Km values against the Smith et al. 1987 table.
- Fasting plasma amino-acid reference values, from a cited reference-range
  source.
- Energy of the consensus scintigraphy meal (assumed 255 kcal).
- The Nutt 1984 meal composition, from the full text. The 34-minute
  calibration depends on it.
- Single-meal plasma amino-acid magnitudes. The effective volume (29.3 L) is
  fitted to daily means; peak rises after one meal (e.g. +696 µmol/L of six
  LNAAs after 25 g whey) are untested. Candidates: Boirie 1997 and Pennings
  2011 figures, Bos 2003 dietary amino-acid curves.
- Timing of protein appearance after large mixed meals (Bos 2003 known gap)
  and of glucose drinks (Blackburn 1984 known gap).
- Per-amino-acid digestibility (Gaudichon 2002 found lower values for several
  amino acids with soy) and splanchnic extraction beyond leucine and
  phenylalanine.
- The insulin sensitivity of tryptophan and the aromatic amino acids (Wurtman
  tryptophan difference at the edge of its range).

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
- Shaham O et al. Mol Syst Biol 2008;4:214. DOI 10.1038/msb.2008.50.
- Wurtman RJ et al. Am J Clin Nutr 2003;77:128-32. DOI 10.1093/ajcn/77.1.128.
- Fernstrom JD et al. Am J Clin Nutr 1979;32:1912-22. DOI 10.1093/ajcn/32.9.1912.
- Price GM et al. Clin Sci 1994;86:91-102. DOI 10.1042/cs0860091.
- Matthews DE et al. Am J Physiol 1993;264:E109-18. DOI 10.1152/ajpendo.1993.264.1.E109.
- Matthews DE et al. Metabolism 1999;48:1555-63. DOI 10.1016/s0026-0495(99)90245-7.
- Gaudichon C et al. J Nutr 1999;129:890-5. DOI 10.1093/jn/129.4.890.
- Mariotti F et al. J Nutr 1999;129:1992-7. DOI 10.1093/jn/129.11.1992.
- Evenepoel P et al. J Nutr 1998;128:1716-22. DOI 10.1093/jn/128.10.1716.
- Oberli M et al. J Nutr 2015;145:2221-8. DOI 10.3945/jn.115.216838.
- Bos C et al. Am J Clin Nutr 2005;81:87-94. DOI 10.1093/ajcn/81.1.87.
- Bos C et al. J Nutr 2003;133:1308-15. DOI 10.1093/jn/133.5.1308.
- Tang JE et al. J Appl Physiol 2009;107:987-92. DOI 10.1152/japplphysiol.00076.2009.
- Pennings B et al. Am J Clin Nutr 2013;98:121-8. DOI 10.3945/ajcn.112.051201.
- Hunt JN, Stubbs DF. J Physiol 1975;245:209-25. DOI 10.1113/jphysiol.1975.sp010841.
- Moore JG et al. Dig Dis Sci 1984;29:513-9. DOI 10.1007/BF01296271.
- Blackburn NA et al. Br J Nutr 1984;52:197-204. DOI 10.1079/bjn19840088.
- Morgan LM et al. Br J Nutr 1985;53:467-75. DOI 10.1079/bjn19850056.
- USDA FoodData Central, SR Legacy (release 2025-04-24): FDC 171283, 172179, 174276, 173407, 171287, 173904.
