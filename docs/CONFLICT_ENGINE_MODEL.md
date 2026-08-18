# Mechanistic Conflict Engine — Model Documentation

## 1. Model purpose

ParkinSUM's mechanistic conflict engine is a deterministic, time-axis,
literature-informed *educational simulation* layer. It sits next to the
existing declarative rule engine and produces a unitless timing-overlap trace
for a narrowly declared model-applicability domain. The trace is a transparent
prototype assumption, not an exposure, absorption, concentration, or symptom
estimate.

It is not a clinical decision tool. It does not predict any individual's
plasma levodopa concentration. It does not recommend medication timing,
dietary choices, or dose changes. Every output carries an explicit
not-advice boundary.

### Clinical-calibration guardrail

The model is **not clinically calibrated**. Gastric-emptying values are
literature-informed prototype parameters (see the parameter set + bibliography);
the amino-acid (LNAA) competition layer is an educational proxy that prefers
actual amino-acid nutrient fields when present and otherwise falls back to a
coarse protein-source approximation. There is **no patient-specific PK/PD
prediction**, no medication/diet/timing advice, and no clinical-validation
claim. Replay reports carry `clinical_calibration_status:
not_clinically_calibrated`, and the public preflight requires this guardrail
phrase to be present in the README and this document.

## 2. Safety scope

- Educational prototype only. Synthetic inputs only.
- No LLM in the conflict engine. The engine is deterministic.
- Hard categorical decisions (PEG block, MAO-B tyramine, enteral feed
  escalation, etc.) continue to come from `RuntimeRuleEngine`; the
  mechanistic engine never overrides them.
- Banned prescriptive copy (see `bannedExplanationSubstrings` in
  `lib/domain/entities/rule_explanation.dart`) is enforced by tests over
  every explanation produced by this engine.

## 3. Input schema

The engine consumes a `TimeAxisConflictContext`:

```
TimeAxisConflictContext
├── referenceMinute                (int, UTC minutes-since-epoch)
├── medicationEvents[]             (MedicationTimelineEvent — only created
│                                   from a validated NormalizedMedicationContext)
├── mealEvents[]                   (MealTimelineEvent — composition referenced
│                                   by id; never inferred)
├── foodComponentEvents[]          (FoodComponentTimelineEvent — per-component
│                                   physical form)
├── userDefinedWindow?             (UserDefinedMealWindow — user-determined)
└── missingFields                  (Set<String>)
```

Meal compositions are passed separately as `Map<String, MealComposition>`
indexed by `compositionId`.

## 4. Time-axis representation

- One minute-level timeline shared by medication and meal events.
- Events are sorted deterministically by minute.
- The engine never invents a missing timestamp; it omits the event and
  records the omission in `missingFields`.
- The user-defined next-meal window is *carried* through the engine, not
  *chosen* by the engine.

## 5. Layer-by-layer description

| Layer | File | Output |
| --- | --- | --- |
| Medication validation | `medication_entry_validator.dart` | `NormalizedMedicationContext` |
| Meal composition normalization | `meal_composition_normalizer.dart` | `MealComposition` (with bands, completeness, missing fields) |
| Time-axis builder | `time_axis_builder.dart` | `TimeAxisConflictContext` |
| Gastric emptying | `gastric_emptying_model.dart` | `GastricEmptyingProfile` per meal |
| Levodopa absorption opportunity | `levodopa_absorption_opportunity_model.dart` | `AbsorptionOpportunityWindow` |
| Amino-acid competition | `amino_acid_competition_model.dart` | `CompetitionPressureTimeline` |
| Composer | `mechanistic_conflict_engine.dart` | `MechanisticConflictResult` |
| Next-meal scorer | `mechanistic_next_meal_scorer.dart` | `List<MechanisticCandidateScore>` |
| Replay runner | `mechanistic_replay_runner.dart` | `MechanisticReplayRunReport` |

## 6. Gastric emptying assumptions

All gastric-emptying numeric values are sourced from
`GastricEmptyingParameterSet.literatureInformedDefault()`
(`lib/domain/entities/gastric_emptying_parameters.dart`). Each parameter
carries `sourceRefs`, an evidence-level (`mechanism` vs
`prototype_heuristic`), and a `limitation` string. Reviewers can trace any
modeled value back to a `Bibliographies.md` row via the parameter's
`sourceRefs`.

The model uses a per-component lag-shifted single-exponential decay:

```
remaining(t) = 1                              if t ≤ lag
remaining(t) = exp(-(ln 2 / t_half) · (t - lag))   if t > lag
```

- **Solid components:** `lag ≈ 20 min`, `t_half ≈ 90 min`.
- **Liquid components:** `lag = 0 min`, `t_half ≈ 15 min`.
- **Unknown physical form:** uses dampened solid defaults *and* widens
  uncertainty.

Numeric fields tagged `prototype_heuristic` are explicitly illustrative. A
small set of lag, half-time, and sensitivity fields still use `mechanism` to
mean that their range or direction is literature-informed; that label does
**not** establish that the selected point value is fitted, externally
transportable, or estimated from person-specific observations. Splitting
direction evidence from selected-value status is
tracked as a required metadata upgrade.

The evidence is heterogeneous rather than uniformly positive. Hardoff et al.
reported slower group means with broad variability, Doi et al. reported an
association between delayed emptying and a later levodopa peak, while Siebner
et al. found no group-level delay in a small early, medicated Parkinson cohort.
The model therefore exposes a sensitivity analysis and must not apply a
universal “Parkinson gastric-delay” multiplier.

## 7. Solid vs liquid behavior

Mixed meals model each component separately. The meal-level remaining
fraction is the mass-weighted sum of component remaining fractions:

```
meal_remaining(t) = Σ fraction_i · remaining_i(t)
```

Liquid components empty faster and contribute a faster meal-level decline
than comparable solid components, matching the direction in the cited
literature.

## 8. Meal-size effect

A linear size multiplier scales half-emptying against a 400 kcal reference:

```
size_multiplier = clamp(0.6 + 0.4 · (kcal / 400 kcal),   0.6 .. 2.0)
```

Tagged `prototype_heuristic`. Larger meals therefore extend the modeled
emptying profile; missing `total_calories` defaults `size_multiplier = 1.0`
and widens uncertainty.

## 9. Fat / protein / fiber effect assumptions

- **Fat:** meals with ≥30% kcal from fat multiply `t_half` by ~1.5×.
- **Fiber (high band):** multiplies `t_half` by ~1.1× **and** widens
  uncertainty.
- **Protein:** does not directly modify the emptying curve here. It feeds
  the amino-acid competition layer (Layer 5) instead.
- **Missing nutrient fields:** the field is recorded in `missingFields`,
  the composition's `compositionCompleteness` drops below 1.0, and the
  uncertainty band widens.

## 10. Overlapping meal handling

When a second meal arrives before the first is mostly emptied, the engine:

1. Computes the first meal's `remaining_fraction_at(t_of_second_meal_start)`.
2. Passes that as `overlappingResidualLoad` into the second meal's
   gastric profile.
3. The second profile's uncertainty band widens proportionally to the
   residual.

The absorption opportunity layer detects residual stomach load at the
medication time only from a meal that has already started. A future candidate
meal can be the competition target, but it cannot travel backward in time and
delay an earlier dose. The latest started meal is accepted only while the dose
still falls within that meal profile's explicit `mostlyEmptiedWindow`; an
arbitrarily old meal cannot unlock a current trace. If no current dose-time
meal context is recorded, the provider returns `insufficient`; the absence of
a record is not inferred as fasting.

## 10a. Multi-dose time axis

The engine evaluates **each levodopa medication event** on the timeline
independently rather than only the first dose:

1. Until a governed terminology can prove a non-target medication identity,
   any additional free-text/non-target medication context makes the
   mechanistic provider `insufficient`. Other medicines remain handled by the
   categorical rule layers; they are not silently dropped from a mixed model
   timeline. If another event is also a known out-of-domain target, the
   unresolved event still takes precedence and the aggregate state remains
   `insufficient`, not a falsely certain `notApplicable`.
2. For every levodopa dose, the engine separately resolves (a) an already
   started meal for dose-time gastric context and (b) a possible future target
   meal for competition. It computes an absorption opportunity only from (a),
   then evaluates (b) against that causally valid window.
3. Aggregation is **deterministic max-overlap**: the dose with the highest
   modeled overlap drives the primary `interaction_score`, severity, and
   confidence. A high-overlap dose is never averaged away by lower-overlap
   doses. Ties break by earliest dose minute for stability.
4. Every applicable dose is retained in `perEventTraces` (with its own
   `interactionScore`, competition band, delayed-arrival likelihood, source
   refs, and uncertainty reasons), and `perEventCount` records how many doses
   were modeled. If any levodopa-context event is outside the declared v1
   applicability domain, the provider abstains for the whole timeline instead
   of dropping that event or borrowing an immediate-release curve.

## 10b. Dose comes only from user input (hard requirement)

The engine never invents, defaults, or infers a medication strength. Dose is
parsed from the user-entered free-text dosage note (`DosageNoteParser`) and is
treated as explicit **only** when both a numeric value and a recognized unit
(`mg`/`g`/`mcg`/`ml`) are present:

- `"100 mg"` → strength 100 mg.
- `"levodopa 100"`, bare `"100"`, slashed `"25/100"`, empty → **not explicit**;
  strength/unit are left null, the `MedicationEntryValidator` returns
  `insufficient`/`invalid`, and dose-dependent interpretation is blocked. The
  reason surfaces in `missingFields` / `fallbackReasons` / `dataNotes` and the
  replay report's `dosageContextComplete = false`.

There is no code path that substitutes a private default strength.

## 11. Food-food interaction

Per-component modeling means food-food interactions surface naturally:

- A high-fat component in a mixed meal extends the meal's overall
  half-emptying via the fat multiplier.
- A liquid component empties faster than a solid component in the same
  meal; both contribute to the cumulative meal-level remaining fraction.
- High protein in any component raises the competition-pressure timeline
  amplitude in Layer 5.

## 12. Levodopa absorption-window assumptions

The executable v1 provider has one deliberately narrow configuration:

- Absorption opportunity starts after a short post-dose lag.
- Immediate-release: lag ≈ 5 min, duration ≈ 90 min.
- It executes only when the runtime fields explicitly contain the exact
  carbidopa + levodopa token set plus oral, swallowed-tablet, and
  immediate-release values. These string checks are not yet a governed product
  identity or terminology service; that remains an open credibility boundary.
- Extended-, controlled-, delayed-release, capsule, enteral, inhaled,
  subcutaneous, unknown, unspecified, or malformed metadata causes an explicit
  `notApplicable` or `insufficient` abstention. No IR-shaped fallback and no
  ER/CR/DR curve are executable.
- Release type is taken from the explicit medication context and is never
  inferred from dose, brand, tag, or a substring match.
- A high residual stomach load at the medication time shifts the window
  forward and widens it. Delay likelihood band reflects this:
  - `low` (residual ≤ 0.4)
  - `moderate` (0.4 < residual ≤ 0.7)
  - `high` (residual > 0.7)
- No overlapping meal profile is `insufficient`, so the provider emits no
  window, peak, openness samples, delay band, or modeled numeric result.

These lag and duration constants define a unitless engineering trace. Product
labels and small PK studies motivate the need to separate formulations; they
do not validate these constants as human PK. This is not a PK prediction.

### 12b. Medication section provenance in the per-event trace

When a `NormalizedMedicationContext` carries `metadata`
(`MechanisticMedicationMetadata`, bridged from CDSS records — see
`docs/IMPORTER_METADATA_FLOW.md` §14d), each `MechanisticPerEventTrace`
additionally surfaces the medication provenance: `releaseTypeSource`,
`doseForm`, `route`, `levodopaComponentPresent`, `combinationComponentCount`,
`labelSectionRefCount`, `medicationSourceSystem`, `medicationSourceDocId`, and
`medicationMetadataCompleteness`. This is **provenance/traceability only** — it
never contributes to the dose, and the intake dose still comes solely from the
user-facing dosage path (product/component strength never fabricates a dose).
Before the context becomes executable, the validator requires the nested
product variant, source document, jurisdiction, component set, route, form,
release type, and extraction-confidence bounds to agree with the top-level
structured entry. Missing identity bindings or contradictions fail closed;
provenance cannot be used to disguise a different formulation.

The same `MechanisticMedicationMetadata` is also exportable as a local,
**FHIR-inspired, PHI-free MedicationKnowledge view**
(`FhirInspiredMedicationKnowledgeMapper` → `FhirInspiredMedicationKnowledgeView`;
see `docs/IMPORTER_METADATA_FLOW.md` §14e). That view is **serialization only** —
it does not affect scoring or the dose path, is `inspired_not_conformant`, omits
all patient-care semantics, and serializes product strength strictly as product
metadata (`product_label_metadata`), never as a user intake dose. That view's
label section refs additionally carry an optional, conservative **LOINC
document-section code** (`LabelSectionCodeMapper`; known FDA SPL headings only,
`unknown` otherwise — never guessed). LOINC presence is traceability only; it
does not affect the conflict model, scoring, or the dose path.

### 12a. Absorption opportunity openness profile

In addition to the flat window (kept for compatibility), the model emits a
deterministic **sampled openness curve** (`opennessProfile`: a list of
`(minute, openness 0..1)` samples on `AbsorptionOpportunityWindow`):

- Immediate-release rises sharply to a full-openness peak then decays to a low
  tail (sharp, short).
- No extended-, controlled-, or delayed-release openness curve is executable;
  those formulations produce an explicit abstention.
- When the meal context is incomplete (no overlapping meal profile) the whole
  provider abstains instead of flattening a guessed curve.

`openness` is a unitless educational weight — NOT an absorbed fraction and NOT
a blood concentration. The amino-acid competition overlap (Layer 5) is
**openness-weighted** (`Σ pressure·openness / Σ openness`) so competition
pressure arriving near the peak opportunity counts more than pressure at the
window edges. Both sums cover the full validated absorption-openness grid;
times without competition pressure contribute zero to the numerator but keep
their openness weight in the denominator, so a brief intersection cannot look
equivalent to whole-window overlap. A missing, malformed, empty, or
not-applicable opportunity profile causes abstention; it is not replaced by a
flat numeric window. Not PK/PD calibration, not dose-response advice.

## 13. Amino-acid competition assumptions

The competition pressure proxy is the product of (a) the meal's
instantaneous intestinal arrival rate (derivative of `emptiedFractionAt`),
(b) a protein amplitude factor scaled against a 20 g reference, and (c)
an **LNAA load factor** that depends on the protein source type of each
food component (`ProteinSourceType` in `lib/domain/entities/protein_source.dart`).
The load factor is direction-only: animal protein generally carries higher
LNAA per gram than plant protein. Magnitudes are tagged
`prototype_heuristic`; direction is grounded in the cited reviews (Nutt et
al. 1989; Cereda et al. 2017; Boelens Keun et al. 2021; Virmani et al.
2023). When the component's protein source is `unknown`, the uncertainty
band widens by one step rather than the model faking precision.

The competition score is the *openness-weighted* competition pressure across
an available absorption opportunity profile (see §12a). Discretized bands:

| Overlap (avg pressure × overlap fraction) | Competition band |
| --- | --- |
| 0 | `none` |
| < 0.1 | `low` |
| < 0.25 | `moderate` |
| ≥ 0.25 | `high` |

Missing protein → typed `insufficient`, null numeric wire fields, and no
pressure curve. Unknown is never inserted as zero into the composite.

### 13a. Actual amino-acid fields, absolute grams, and dose-relative proxy

When every positive-protein component carries a complete six-LNAA profile,
the LNAA layer uses `AminoAcidDataMode.actualAminoAcidFields`. When coverage is
mixed, it uses `hybridActualAndProteinSourceProxy`: covered components retain
their measured fields, uncovered components use the disclosed protein-source
proxy, uncertainty widens, and whole-meal LNAA grams/dose-relative ratios stay
null rather than presenting a hybrid estimate as a measured total. The layer
additionally exposes, in `CompetitionLnaaSummary`:

- `competingLnaaGrams` — absolute competing LNAA grams summed across components
  (null in proxy/unknown mode; missing ≠ zero).
- `competingLnaaGramsPerServing` — present only when a real serving mass is
  known.
- `doseRelativeLnaaRatio` (g LNAA per 100 mg levodopa) and
  `doseRelativeAvailable` — populated **only** when an explicit user-entered
  dose is available. The dose is taken from the validated medication context;
  no dose is ever invented. Missing/non-explicit dose → ratio unavailable.
- `partialAminoAcidData` — true when a component/profile is incomplete, a value
  is unit-ambiguous, or only part of the meal has complete profiles. Partial or
  hybrid evidence widens uncertainty rather than being trusted as fully narrow.
- `aminoAcidConfidenceTier` — when the FDC payload carries per-nutrient
  provenance (`foodNutrientDerivation` / `dataPoints` / food `dataType`), the
  extractor maps it to an ordinal `NutrientConfidenceTier`
  (analytical / calculated / imputedOrAssumed / unknown). The competition layer
  reports the conservative **weakest-wins** aggregate and **widens uncertainty
  for any weaker-than-analytical tier** (calculated/imputed/unknown), exactly
  like partial handling. This is a provenance signal, **not** a
  measurement-uncertainty or clinical-accuracy estimate; a missing derivation
  stays missing and never raises confidence
  (`src.usda.fdc.foundation_docs`). Beyond LNAA uncertainty, the tier now also
  feeds **candidate metadata completeness** (`MetadataCompletenessGate
  .scoreCandidateFood` → `CandidateMetadata.completeness` →
  `MechanisticCandidateScore`) and is stored explicitly on `FoodVariantMetadata`,
  so source quality affects only the analysis trace's confidence/composite —
  never the production recommendation order, advice, or an override of
  source-authority/jurisdiction policy
  (see `docs/IMPORTER_METADATA_FLOW.md` §9 and
  `docs/SOURCE_QUALITY_PERTURBATION_REPORT.md`).

The modeled value is a **unitless timing-overlap proxy motivated by possible
intestinal competition**; it is not absorbed fraction, transporter occupancy,
or concentration. Broader blood–brain-barrier LNAA transport competition is
named as a cited mechanism in the trace but is not quantified here.

The pressure timeline uses the gastric model's intestinal-arrival curve for
**shape**, normalizes that curve to its own peak, then applies a bounded
protein/LNAA load amplitude. This keeps the pressure and its 0–1 band thresholds
on the same relative scale. Earlier code compared a fraction-per-minute rate
directly with unitless 0.10/0.25 thresholds, which compressed every rendered
curve near zero. The normalized result is still a prototype heuristic—not an
amino-acid concentration, transporter occupancy, or clinical effect probability.

## 14. Uncertainty / confidence scoring

The engine returns a discrete `ConfidenceBand`:

| Condition | Confidence |
| --- | --- |
| `compositionCompleteness < 0.4` | typed `insufficient`; no modeled score |
| competition band == `unknown` | `low` |
| `missingTimelineFields ≥ 3` | `low` |
| emptying `uncertaintyBand == veryWide` | `low` |
| emptying `uncertaintyBand == wide` | `medium` |
| `compositionCompleteness < 0.85` | `medium` |
| otherwise | `high` |

Uncertainty reasons are surfaced in the result so reviewers can see exactly
which inputs degraded confidence.

### 14.1 Visible gastric time-scale sensitivity

`GastricEmptyingProfile.sensitivityEnvelopeAt()` evaluates the same component
model at 0.76× and 1.24× the central lag/half-time scale. The 24% fraction is
an illustrative symmetric transform motivated by a study reporting 24.5%
between-participant variation in measured half-time among healthy participants.
That study does not supply a Parkinson distribution. The transform is displayed
beside the central curve as a deterministic one-way sensitivity analysis—not a
confidence interval, clinical reference range, gastric-emptying test, or
patient prediction. The primary trace remains the central parameter set;
sensitivity lines never silently alter ranking.

For high residual stomach load, the absorption opportunity uses 34 minutes as
its illustrative central shift, matching the mean meal-associated absorption
delay reported by Nutt et al. (1984). The small selected sample prevents this
value from being interpreted as an individual or formulation-independent
estimate. The residual-load thresholds and the 17/34/68-minute window
transform are prototype heuristics; the end of the opportunity window remains
deliberately widened.

## 15. Explanation schema

Every `MechanisticConflictResult` carries a `MechanisticExplanation`:

```
MechanisticExplanation
├── resultId
├── layerTraces[]                 (per-layer description, inputsUsed,
│                                  assumptionsApplied, uncertaintyContribution)
├── inputFieldsUsed[]
├── missingOrUncertainInputs[]
├── sourceRefs[]                  (model_assumption_registry sourceIds)
├── limitationText                (default `defaultLimitation`)
├── safetyBoundary                (default `RuleExplanation.defaultSafetyBoundary`)
└── notAdviceText                 (default `RuleExplanation.defaultNotAdvice`)
```

The trace is JSON-serializable for the replay runner.

## 16. Testability requirements

- Every provider serializes an explicit availability state. Insufficient,
  not-applicable, or integrity-blocked outputs carry null modeled numbers and
  no curve; compatibility sentinels are never presented as results.
- Every modeled assumption has a `sourceId` in
  `model_assumption_registry.dart`, mapped to a citation in
  `Bibliographies.md`.
- Every output is scanned in tests for banned prescriptive substrings.
- The replay runner serializes the full result tree and asserts expected
  output types, severity floors/ceilings, and confidence ceilings.

## 17. Synthetic scenario fixtures

The scenarios in `lib/core/constants/mechanistic_replay_scenarios.dart`
(35+ and growing) cover at least:

1. Valid context + small low-protein meal far from medication.
2. Valid context + high-protein solid meal close to medication.
3. Valid context + high-fat mixed meal before medication.
4. Overlapping meals.
5. Liquid-only meal.
6. Missing meal protein data.
7. Missing meal start time.
8. Invalid unitless medication entry "100".
9. "levodopa 100" without unit.
10. "25/100" without catalog normalization.
11. Mixed solid+liquid meal.
12. High-fat + protein in the same meal.
13. User-defined next-meal window with multiple candidates.
14. User-defined next-meal window with missing-nutrient candidate.
15. Multi-dose immediate-release day (max-overlap aggregation).
16. Actual amino-acid profile (actual-fields mode) vs protein-source proxy.
17. Partial amino-acid profile (partial flag + widened uncertainty).
18. High-calorie/high-fat meal (gastric uncertainty widened).
19. Explicit user dose enabling the dose-relative LNAA proxy.

The replay report (`MechanisticReplayCaseReport`) additionally surfaces, per
scenario: `mealComponentCount`, `gastricEmptyingAssumptions`,
`absorptionOpennessSampleCount` / `absorptionPeakOpenness`, `aminoAcidDataMode`,
`partialAminoAcidData`, `competingLnaaGrams`,
`doseRelativeLnaaAvailable` / `doseRelativeLnaaRatio`, `scoringParameterSetId`,
`userEnteredDosage` / `dosageContextComplete`, and `perEventCount`.

## 18. Next-meal recommendation boundary

`MechanisticNextMealScorer` strictly:

- **Requires** a `UserDefinedMealWindow`. Without one, every candidate
  returns `insufficient_context`.
- **Never picks the window.** The window comes from the caller; the
  scorer only evaluates candidates inside it.
- Uses **multi-point sampling** inside the window:
  `max(5, ceil(window_minutes / 15))` samples, capped at 12. Each sample
  is a hypothetical meal event at a candidate offset; the engine runs
  end-to-end for each. Best, worst, average, and per-sample summaries are
  surfaced in
  `MechanisticCandidateScore.sampledWindowSummary` for trace and UI.
- May calculate an analysis-only composite score, but the production
  recommendation path does not use that score to reorder foods. The UI aligns
  every candidate trace to the existing conservative heuristic order.
- Returns `insufficient_context` for *every* candidate when the
  medication context is invalid — never pretends to optimize against a
  bare numeric dose.

The composite `finalCandidateScore` weights are centralized in
`NextMealScoringParameterSet` (`next_meal_scoring_parameters.dart`), each weight
carrying `sourceRefs`, an evidence level, and a limitation. The set is
injectable and surfaced per candidate via `scoringParameterSetId`. The
invariant `conflictRemainsDominant` guarantees modeled conflict overlap (and
the uncertainty penalty) stay dominant, so provenance/metadata can never
outrank a high modeled conflict overlap. It is **enforced at construction**:
`MechanisticNextMealScorer` throws `ArgumentError` if injected with a
non-dominant weight set, so an unsafe set cannot enter the scorer.

### Trace-only decision influence

`NextMealRecommendationOrchestrator._enrichWithMechanistic` may compute an
inspectable candidate trace when the user supplies a window and the runtime
applicability/context gates pass. The current equations are not product- and
population-specifically validated for optimization, so they never reorder
`recommendations`. `rankerUsed` reports `heuristic_legacy_fallback` unless a
separately consented local-AI safe-whitelist reorder actually produced the
final order, in which case it reports `local_ai_safe_candidate_rerank`;
`mechanisticPrimaryEligible` remains false, and the eligibility record includes
`mechanistic_trace_only_not_validated_for_ranking`.

This is an executable decision-influence ceiling, not a disclaimer. A future
change to ranking requires a separately reviewed context of use, governed
calibration/validation evidence, and a versioned promotion contract.

## 19. What the model does NOT infer

- Real plasma levodopa concentration.
- Real patient gastric emptying or GI status.
- Personalized medication timing, dose, or dietary recommendations.
- Clinical evidence grading. The `evidence_level` field in the assumption
  registry is documentation-level only.
- Patient-specific stoichiometric LNAA transport kinetics. When actual
  amino-acid fields are present the model uses absolute competing LNAA grams
  and (with an explicit dose) a dose-relative ratio; otherwise it falls back to
  a total-protein-grams proxy. Neither is a calibrated transport model.

## 20. Implementation status and open credibility work

- **Engine + scorer:** implemented as an educational, abstaining trace and
  exercised by focused invariant, mutation, applicability, replay, and UI
  tests. This is engineering verification, not biological validation.
- **Centralized gastric-emptying parameter set:** implemented
  (`lib/domain/entities/gastric_emptying_parameters.dart`).
- **LNAA / protein-source proxy:** implemented
  (`lib/domain/entities/protein_source.dart`,
  `lib/domain/usecases/amino_acid_competition_model.dart`); load factors are
  direction-only and tagged `prototype_heuristic`.
- **Multi-point window sampling:** implemented; deterministic, 5–12 samples.
- **Trace-only decision influence:** enforced in
  `NextMealRecommendationOrchestrator`; the stable trace-only reason makes model
  non-influence inspectable, while `rankerUsed` truthfully names the heuristic
  or separately consented local-AI producer of the final order.
- **Catalog wiring:** `AppState._augmentFoodRepoFromProjection` merges
  CDSS-projected foods into the runtime food repository at boot, best-
  effort. The seed/persisted catalog remains the fallback.
- **Wiring (data fields):**
  - `NextMealRecommendationResult` carries `mechanisticTrace`,
    `mechanisticCandidateScores`, `rankerUsed`.
  - `InteractionResult.mechanisticTraceJson` survives JSON round-trip.
- **UI:** `MechanisticConflictTraceCard` +
  `MechanisticCandidateScoreLine` render compact, non-prescriptive
  summaries in `next_meal_page.dart` and `interaction_result_view.dart`
  via an `ExpansionTile`. Raw JSON is not shown by default.
- **Still open:** governed product/ingredient terminology and release manifests,
  independently curated applicability fixtures, immutable calibration datasets,
  prospective/external validation, and any evidence supporting clinical or
  ranking use. Until those exist, abstention and trace-only influence are
  mandatory.

## 21. Future literature-calibration path

- Replace the prototype heuristic multipliers with literature-fitted
  half-times when a published cohort study with adequate transparency is
  identified.
- Add per-LNAA stoichiometry to the amino-acid competition layer when a
  reviewer-acceptable model paper is available.
- Add a per-region food-effect adjustment to the absorption layer.
- Continuous-window candidate search inside the user-defined window.

Until those are in, every assumption is tagged in
`model_assumption_registry.dart` and the closest mechanism citation in
`Bibliographies.md`. Reviewers can trace every output back to its source.
