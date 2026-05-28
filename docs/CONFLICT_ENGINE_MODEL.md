# Mechanistic Conflict Engine — Model Documentation

## 1. Model purpose

ParkinSUM's mechanistic conflict engine is a deterministic, time-axis,
literature-informed *educational simulation* layer. It sits next to the
existing declarative rule engine and produces continuous-valued exposure-
disruption estimates that approximate the pathway by which meals may affect
levodopa availability for absorption.

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

All numeric magnitudes are tagged `prototype_heuristic` in
`model_assumption_registry.dart`. The *direction* of each effect is grounded
in the cited literature; the exact magnitudes are illustrative and are not
patient-calibrated.

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

The absorption opportunity layer also detects residual stomach load at
the medication time and shifts/widens the window accordingly.

## 10a. Multi-dose time axis

The engine evaluates **each levodopa medication event** on the timeline
independently rather than only the first dose:

1. Non-levodopa events (e.g. iron, MAO-B inhibitors) are **excluded** from
   levodopa-specific food-interaction scoring — they are handled by other
   rule layers.
2. For every levodopa dose, the engine finds that dose's primary meal,
   computes residual stomach load, gastric emptying, the absorption
   opportunity window, and the amino-acid competition overlap.
3. Aggregation is **deterministic max-overlap**: the dose with the highest
   modeled overlap drives the primary `interaction_score`, severity, and
   confidence. A high-overlap dose is never averaged away by lower-overlap
   doses. Ties break by earliest dose minute for stability.
4. Every evaluated dose is retained in `perEventTraces` (with its own
   `interactionScore`, competition band, delayed-arrival likelihood, source
   refs, and uncertainty reasons), and `perEventCount` records how many doses
   were modeled. Extended/controlled-release doses widen the absorption window
   per Section 12.

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

Per the cited DailyMed labeling and PK reviews:

- Absorption opportunity starts after a short post-dose lag.
- Immediate-release: lag ≈ 5 min, duration ≈ 90 min.
- Extended/controlled-release: lag ≈ 30 min, duration ≈ 240 min.
- A high residual stomach load at the medication time shifts the window
  forward and widens it. Delay likelihood band reflects this:
  - `low` (residual ≤ 0.4)
  - `moderate` (0.4 < residual ≤ 0.7)
  - `high` (residual > 0.7)
  - `unknown` (no overlapping meal profile available)

This is an educational simulation, not a PK prediction.

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

The competition score is the *average pressure inside the absorption
opportunity window*. Discretized bands:

| Overlap (avg pressure × overlap fraction) | Competition band |
| --- | --- |
| 0 | `none` |
| < 0.1 | `low` |
| < 0.25 | `moderate` |
| ≥ 0.25 | `high` |

Missing protein → `unknown` band and `veryWide` uncertainty.

## 14. Uncertainty / confidence scoring

The engine returns a discrete `ConfidenceBand`:

| Condition | Confidence |
| --- | --- |
| `compositionCompleteness < 0.4` | `insufficient` |
| competition band == `unknown` | `low` |
| `missingTimelineFields ≥ 3` | `low` |
| emptying `uncertaintyBand == veryWide` | `low` |
| emptying `uncertaintyBand == wide` | `medium` |
| `compositionCompleteness < 0.85` | `medium` |
| otherwise | `high` |

Uncertainty reasons are surfaced in the result so reviewers can see exactly
which inputs degraded confidence.

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

- The engine never produces a number when inputs are insufficient — it
  returns one of the `insufficient*` interaction types.
- Every modeled assumption has a `sourceId` in
  `model_assumption_registry.dart`, mapped to a citation in
  `Bibliographies.md`.
- Every output is scanned in tests for banned prescriptive substrings.
- The replay runner serializes the full result tree and asserts expected
  output types, severity floors/ceilings, and confidence ceilings.

## 17. Synthetic scenario fixtures

14 scenarios in `lib/core/constants/mechanistic_replay_scenarios.dart`
cover:

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

## 18. Next-meal recommendation boundary

`MechanisticNextMealScorer` strictly:

- **Requires** a `UserDefinedMealWindow`. Without one, every candidate
  returns `insufficient_context`.
- **Never picks the window.** The window comes from the caller; the
  scorer only evaluates candidates inside it.
- Uses **multi-point sampling** inside the window:
  `max(5, ceil(window_minutes / 15))` samples, capped at 12. Each sample
  is a hypothetical meal event at a candidate offset; the engine runs
  end-to-end for each. The conservative (worst-case) overlap drives
  ranking; best, average, and per-sample summaries are surfaced in
  `MechanisticCandidateScore.sampledWindowSummary` for trace and UI.
- Ranks candidates ascending by worst-case `conflictOverlapScore`,
  breaking ties by `nutritionDataCompleteness` descending, then by
  candidate id for deterministic order.
- Returns `insufficient_context` for *every* candidate when the
  medication context is invalid — never pretends to optimize against a
  bare numeric dose.

### Mechanistic-primary ranking promotion

`NextMealRecommendationOrchestrator._enrichWithMechanistic` promotes the
mechanistic engine to be the **primary ranker** of `recommendations`
exactly when **all** of these hold:

1. `request.userDefinedWindow != null`, and
2. `mechanisticTrace.confidenceBand` is `medium` or `high`, and
3. every candidate has a `MechanisticCandidateScore` with
   `insufficientContext == false`.

In every other case the existing legacy heuristic (`_levodopaWindowPenalty`,
documented as a fallback in the orchestrator source) drives ordering.
The result's new `rankerUsed` field surfaces which path ran
(`mechanistic_primary` or `heuristic_legacy_fallback`) so reviewers can
audit ranking decisions without reading code.

## 19. What the model does NOT infer

- Real plasma levodopa concentration.
- Real patient gastric emptying or GI status.
- Personalized medication timing, dose, or dietary recommendations.
- Clinical evidence grading. The `evidence_level` field in the assumption
  registry is documentation-level only.
- Stoichiometric LNAA composition (the competition proxy operates on
  total protein grams).

## 20. Implementation status

- **Engine + scorer:** complete; exercised by 38+ focused tests + a
  15-scenario replay runner.
- **Centralized gastric-emptying parameter set:** complete
  (`lib/domain/entities/gastric_emptying_parameters.dart`).
- **LNAA / protein-source proxy:** complete
  (`lib/domain/entities/protein_source.dart`,
  `lib/domain/usecases/amino_acid_competition_model.dart`); load factors are
  direction-only and tagged `prototype_heuristic`.
- **Multi-point window sampling:** complete; deterministic, 5–12 samples.
- **Mechanistic-primary ranking promotion:** complete in
  `NextMealRecommendationOrchestrator`; `rankerUsed` surfaces which path
  ran.
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
