# Mechanistic Replay Runner

The mechanistic replay runner exercises the deterministic, time-axis
conflict / next-meal recommendation engine against a fixed suite of
synthetic scenarios and writes a machine-readable report under
`build/mechanistic_replay/`.

Educational simulation. Synthetic inputs only. Not medical advice.

## Run it

```sh
dart run tool/run_mechanistic_replay.dart
```

Or via npm wrapper (handy in CI):

```sh
npm run mechanistic:replay
```

Outputs:

- `build/mechanistic_replay/latest.json` — full per-scenario report.
- `build/mechanistic_replay/latest.md` — human-readable summary.

The runner exits **0** iff every scenario passes and every output is free
of banned prescriptive substrings (see `bannedExplanationSubstrings` in
`lib/domain/entities/rule_explanation.dart`). Otherwise exits non-zero.

## Scenario format

Defined in `lib/core/constants/mechanistic_replay_scenarios.dart`.

```dart
MechanisticReplayScenario(
  scenarioId: 's01_low_protein_far',
  title: '...',
  expectedOutputType: ScenarioExpectedOutputType.noModeledInteraction,
  expectedSeverityCeiling: SeverityBand.low,
  expectedConfidenceCeiling: ConfidenceBand.high,
  expectInsufficientContext: false,
  expectNonEmptyRecommendations: false,
  medicationEntries: [...],
  medicationMinutesOffsets: [MinutesOffset(...)],
  meals: [...],
  userDefinedWindow: ...,
  candidateFoods: [...],
  notes: '...',
)
```

Every offset is in **minutes relative to the scenario reference time**
(default `2026-01-01T08:00Z`). The runner always uses UTC; this keeps
fixtures deterministic across machines.

## Expected-output schema

Per-case report row (see `MechanisticReplayCaseReport`):

| Field | Meaning |
| --- | --- |
| `scenarioId` | Scenario identifier. |
| `medicationContextValidity` | `valid` / `insufficient` / `invalid` / `none`. |
| `mealContextCompleteness` | 0..1; reflects how many composition fields the normalizer was given. |
| `gastricEmptyingProfileSummary` | One-line `lag=Xmin uncertainty=Y` summary. |
| `absorptionOpportunityWindow` | Modeled window, when present. |
| `aminoAcidCompetitionBand` | `none` / `low` / `moderate` / `high` / `unknown`. |
| `interactionScore` | Engine's composite score (0..1). |
| `severityBand` | `none` / `low` / `moderate` / `high` / `unknown`. |
| `confidenceBand` | `high` / `medium` / `low` / `insufficient`. |
| `triggeredMechanisms` | Engine-attributed drivers. |
| `blockedMechanisms` | Mechanisms that were *not allowed* to fire (e.g. when context is invalid). |
| `sourceRefs` | `model_assumption_registry.dart` source IDs. |
| `bannedPhraseHits` | Always empty in a passing run. |
| `nextMealRecommendationResult` | Candidate scores, when the scenario includes a user window + candidates. Each score carries `sampledWindowSummary` with per-sample offsets, overlap, and confidence. |
| `competitionLnaaSummary` | LNAA load summary (effective load factor, protein sources present, whether uncertainty was widened) when a meal had protein. |
| `rankerUsed` | Which ranker the orchestrator-equivalent path would use for this scenario (`mechanistic_engine_only` or `mechanistic_primary_window_sampled`). |
| `sampledWindowOffsets` | Deterministic list of per-sample offsets (minutes within the user window). Empty when no candidates. |
| `top_final_candidate_score` | Composite final score of the top-ranked candidate (0..1). |
| `top_protein_redistribution_score` | Top candidate's protein-redistribution score. |
| `top_protein_window_role` | Top candidate's protein window role. |
| `top_nutrition_adequacy_contribution` | Top candidate's nutrition-adequacy proxy contribution. |
| `top_source_authority_score` / `top_jurisdiction_match_score` | Top candidate provenance scores. |
| `top_candidate_source_system` | Source system of the top candidate. |
| `medication_source_system` / `medication_source_doc_id` / `medication_source_version` | Medication provenance bridged from CDSS metadata (fixture-tested), when attached. |
| `medication_label_section_ref_count` | Number of label-section refs backing the product (0 when none → lower completeness, not a fake trace). |
| `medication_release_type` / `medication_release_type_source` | Release type + where it came from (`structured_variant_metadata` / `unknown`; never inferred from dose). |
| `medication_dose_form` / `medication_route` | Source-backed dose form + route. |
| `medication_combination_components` | Component ingredient names (e.g. carbidopa + levodopa) — combination products preserve all components. |
| `dosage_source` | Where the analyzable dose came from (`user_or_variant_strength` / `insufficient` / `none`). Product metadata never fabricates a dose. |
| `medication_metadata_completeness` / `medication_missing_fields` | Medication-context completeness grade + recorded missing provenance fields. |
| `pass` / `failureReason` | Bool + diagnostic message. |

The suite contains **41 scenarios** (s01–s40, including s04b), covering
catalog-backed medication context, missing-field downgrades, invalid medication,
daytime high-overlap vs evening low-overlap protein behavior, zero-vs-moderate
protein in low-overlap windows, the no-window fallback, amino-acid
actual-fields vs protein-source-proxy modes (s22/s23), additional invalid
medication forms (s24/s25), mechanistic-primary overwriting the legacy
order (s26), production-readiness coverage (s27–s31: amino-acid food in a
far window, mixed-mode candidate sets, invalid-with-window, no-window
fallback visibility, daytime-overlap amino-acid food), missingness/uncertainty
and enteral coverage (s32–s38), and **medication section-provenance bridging**
(s39 SPL IR carbidopa/levodopa with label-section refs; s40 SPL ER) where CDSS
drug metadata reaches the mechanistic context without fabricating a dose. Report rows
additionally carry `amino_acid_data_mode`, `amino_acid_nutrient_ids`,
`source_implementation_status`, `live_fetch_enabled`, `license_review_status`,
`can_support_mechanism_evidence_alone`, and `clinical_calibration_status`
(`not_clinically_calibrated`).

## Banned-phrase scan

Every emission — `limitationText`, `safetyBoundary`, `notAdviceText`,
every `MechanisticLayerTrace.description`, every assumption string, and
every candidate explanation — is concatenated and scanned for substrings
in `bannedExplanationSubstrings`. Any hit fails the scenario.

This is the *code-level* enforcement that prevents the engine's
educational copy from drifting into medication-timing, dose, dietary, or
clinical-validation advice.

## How to add a scenario

1. Append a `MechanisticReplayScenario` literal to
   `mechanisticReplayScenarios` in
   `lib/core/constants/mechanistic_replay_scenarios.dart`.
2. Use only synthetic catalog-backed medication entries (or deliberately
   invalid ones for negative scenarios).
3. Use synthetic food components — no real patient data, no personal
   identifiers.
4. Run the runner; iterate on the expected fields until they describe
   the engine's actual behavior. The runner emits a clear failure reason
   when expectations don't match.

## CI integration suggestion

```sh
flutter analyze
flutter test --concurrency=1
dart run tool/run_mechanistic_replay.dart
```

Together these enforce: clean static analysis, all unit tests pass, and
every replay scenario produces the expected output type, severity band,
confidence band, and banned-phrase-clean copy.
