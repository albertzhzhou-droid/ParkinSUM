# Input Quality Gate

Educational/research prototype. Synthetic/demo data only. **Not medical advice,
not clinically calibrated, and carries no clinical-validation claim.**

> **This gate assesses input/context completeness — nothing more.** It is **not**
> a recommendation engine. It does **not** validate clinical correctness, does
> **not** recommend dose, timing, or meal choices, does **not** override
> clinician guidance, and does **not** fabricate missing values. Product strength
> is **not** a user intake dose; a missing nutrient is **not** a true zero.

## 1. Purpose

`InputQualityGate` (P1, also "MealMedicationEntryQualityScorer") evaluates
whether a meal + medication entry carries enough structured, source-linked,
non-ambiguous context to enter mechanistic scoring or mechanistic-primary
ranking. Before the engine runs, it answers a single deterministic question —
*how complete and unambiguous is this input?* — and explains gaps in
non-prescriptive language.

It is a pure **aggregator and interpreter** of signals that already exist in the
codebase; it does not re-implement validation or scoring.

## 2. Safety boundary

The gate adds no medical advice, no diagnosis, no treatment/dose/timing/diet
instruction, and no patient-care workflow. It introduces no patient, subject, or
encounter semantics and uses no LLM. It is not clinically calibrated and carries
no clinical-validation claim. Its output is an educational context-quality
assessment only.

## 3. Relationship to existing validators

The gate **reuses** (never duplicates) the established components:

| Signal | Source component |
| --- | --- |
| Medication dose/unit/identity/metadata validity | `MedicationEntryValidator` → `MedicationContextValidationResult` |
| Medication metadata completeness | `MetadataCompletenessGate.scoreMedicationContext` |
| Meal composition completeness, missing-vs-zero | `MealCompositionNormalizer` → `MealComposition` (`missingFields`, `AmountBand`, `compositionCompleteness`) |
| Food source / nutrient provenance | `FoodVariantMetadata` (`nutrientConfidenceTier`, `sourceRefs`), `SourceAuthorityTier`, `NutrientConfidenceTier` |
| Timing-window presence | `UserDefinedMealWindow` / `TimelineWindow` |
| Localization readiness | optional `LocalizationReadinessStatus` (pairs with P7 LocalizationSafetyLint / SafeCopyTemplateRegistry) |

The gate is an interpreter: it maps these signals into one deterministic
context-quality result, but the underlying validators remain the source of
truth.

## 4. Dimensions scored

`medication_dosage`, `medication_identity`, `medication_metadata`,
`meal_composition`, `meal_timing_window`, `food_source_quality`,
`nutrient_provenance`, `localization_readiness`, and an `overall` summary.

The overall **context** status is the weakest of the *context* dimensions
(dosage, identity, metadata, meal composition, food source quality, nutrient
provenance). The timing window and localization readiness affect mechanistic
eligibility and findings but, by design, do not by themselves make the context
*invalid* (a missing meal window is a normal state, not a defect).

## 5. Status model

`complete` → `sufficient` → `partial` → `insufficient` → `invalid` (weakest).
Each status maps to a deterministic 0..1 score (1.0 / 0.8 / 0.5 / 0.25 / 0.0).
Findings carry a severity of `info` / `warn` / `blocker`. A `blocker` finding
populates `blocking_reasons` and makes mechanistic-primary ranking ineligible.

## 6. Medication dosage boundary

- An explicit positive numeric strength **and** an explicit unit (e.g. `100 mg`)
  → `complete`.
- A unitless number, a slash-format value (e.g. `25/100`), or an unknown unit →
  `invalid` (a bare number is not a dose).
- A missing strength or unit → `insufficient` (never auto-filled).
- **Product strength is not a user intake dose.** When the only numeric present
  is product-strength metadata (`productStrengthMetadataOnly`), the dosage
  dimension stays `insufficient` with an explicit note; product strength never
  rescues a missing user dosage.

## 7. Meal composition boundary

- At least one food component is required; an empty meal → `invalid`.
- Completeness is read from the normalizer; missing protein/calories/portion
  lower completeness and emit `warn` findings.
- **Missing is not zero.** A nutrient in `missingFields` is *unknown*; a true
  `0 g` value (`AmountBand.none`) is a valid zero and is reported as such, not as
  missing. The gate never fabricates a value.

## 8. Source / provenance boundary

- `nutrient_provenance`: `analytical` → no downgrade; `calculated` → small
  downgrade; `imputed/assumed` → clearer downgrade; `unknown`/absent → lowered.
  Unknown provenance never *raises* confidence.
- `food_source_quality`: missing `sourceRefs` lowers quality; a synthetic/seed
  source is capped below official-level confidence; unknown authority is
  lowered. This aligns with the P5 FDC provenance integration and the source
  authority scorer (seed/synthetic never outranks official).

## 9. Timing-window boundary

- No user-defined meal window → the context is **not** invalid, but
  mechanistic-primary ranking is **not eligible** and a fallback reason is
  recorded. The gate never suggests a meal time.
- A non-positive window duration → `invalid` window.
- A valid window + sufficient context → eligible.

## 10. Localization-readiness boundary

A lightweight, optional check (not a full localization lint run):

- No localization status provided → `info` only (never a blocker).
- Missing localized safety copy → `warn`.
- An unsafe localized-copy finding (supplied by the caller) → `blocker`.

## 11. Example synthetic cases

`dart run tool/run_input_quality_demo.dart` (or `npm run input:quality`) runs
eight deterministic synthetic cases: complete context, unitless dose, missing
protein, true 0 g protein, missing user window, unknown release type, synthetic
vs official source, and imputed nutrient provenance. Representative output:

| case | overall | eligible | blockers |
| --- | --- | --- | --- |
| complete_context | complete | true | 0 |
| unitless_dose | insufficient | false | 1 |
| missing_protein | sufficient | true | 0 |
| true_zero_protein | complete | true | 0 |
| missing_user_window | complete | false | 0 |
| unknown_release_type | sufficient | true | 0 |
| synthetic_source | partial | true | 0 |
| imputed_provenance | partial | true | 0 |

## 12. What this gate does not do

- It does not tell the user what to eat, when to eat, when to take medication,
  how to dose, or what is safe.
- It does not validate clinical correctness or biological accuracy.
- It does not fabricate missing values or invent an immediate-release default.
- It does not treat product strength as an intake dose, or missing nutrients as
  zero.
- It does not override clinician guidance and is not clinically calibrated.

## 13. How to run tests

```sh
flutter test --concurrency=1 test/input_quality_gate_test.dart
```

The suite uses in-memory fixtures only (it does not run the app or slow CLI
tools) and covers each dimension, the missing-vs-zero distinction, the
product-strength boundary, provenance ordering, window eligibility,
localization severity, deterministic JSON, and the no-PHI / no-advice guards.

## 14. Future UI integration

The gate is pure domain code with no UI dependency. A future PR could surface
the dimension statuses as a non-prescriptive "context completeness" panel
(showing *why* a result is uncertain, never a recommendation). That UI wiring is
out of scope here.

## 15. Reviewer checklist

- [ ] No advice / dose / timing / "safe for you" phrasing in findings or copy.
- [ ] Missing nutrient stays distinct from a true `0 g`.
- [ ] Product strength never satisfies the user-dosage requirement.
- [ ] Unknown release type lowers metadata quality without inventing IR.
- [ ] Synthetic/seed source never reaches official-level confidence.
- [ ] Missing meal window blocks eligibility but does not invalidate context or
      suggest a time.
- [ ] JSON is deterministic and emits no patient/subject/encounter keys.
