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
| `nextMealRecommendationResult` | Candidate scores, when the scenario includes a user window + candidates. |
| `pass` / `failureReason` | Bool + diagnostic message. |

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
