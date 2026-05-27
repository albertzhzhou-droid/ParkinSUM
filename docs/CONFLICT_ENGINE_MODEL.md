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
instantaneous intestinal arrival rate (derivative of `emptiedFractionAt`)
and (b) a protein amplitude factor scaled against a 20 g reference. The
competition score is the *average pressure inside the absorption
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
- Evaluates each candidate at the window's *start* and *midpoint*, picks
  the worse-overlap of the two (conservative).
- Ranks candidates ascending by `conflictOverlapScore`, breaking ties by
  `nutritionDataCompleteness` descending.
- Returns `insufficient_context` for *every* candidate when the
  medication context is invalid — never pretends to optimize against a
  bare numeric dose.

## 19. What the model does NOT infer

- Real plasma levodopa concentration.
- Real patient gastric emptying or GI status.
- Personalized medication timing, dose, or dietary recommendations.
- Clinical evidence grading. The `evidence_level` field in the assumption
  registry is documentation-level only.
- Stoichiometric LNAA composition (the competition proxy operates on
  total protein grams).

## 20. Implementation status

- **Engine + scorer:** complete and exercised by 32 focused tests + a
  14-scenario replay runner.
- **Wiring:**
  - `NextMealRecommendationOrchestrator.recommend(...)` now attaches a
    `mechanisticTrace` and (when `userDefinedWindow` is provided)
    `mechanisticCandidateScores` to `NextMealRecommendationResult`.
  - `DatabaseBackedMealCheckUseCase.call(...)` attaches the trace JSON
    to `InteractionResult.mechanisticTraceJson` for downstream rendering
    and replay.
- **UI:** consumers see the new fields. Visual presentation in
  `lib/features/next_meal/next_meal_page.dart` is a follow-up.

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
