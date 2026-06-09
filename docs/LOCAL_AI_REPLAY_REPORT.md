# Local AI Scenario Replay — Reviewer Report

Educational/research prototype. Synthetic/demo fixtures only. The replay is
engineering review material — **not medical advice, not clinically calibrated,
and it carries no clinical-validation claim.**

## What it is

A deterministic replay of five fixed synthetic archetypes through the same
conservative + hybrid next-meal orchestrators the app uses, with an offline
scripted Local AI stand-in (no network, no real model):

| Archetype | Expected behaviour |
| --- | --- |
| `missing_medication_time_or_dose` | Data-quality gate keeps the conservative ranking |
| `low_risk_next_meal` | Gate open; Local AI may reorder the safe whitelist only |
| `source_fallback_partial_provenance` | AI consent off; deterministic path recorded |
| `safety_gate_blocks_local_ai` | Low-quality meal time blocks AI reranking |
| `medication_catalog_selection_context` | Medication context flows into the safe AI path |

The report pins one safety invariant: **the Local AI path may only reorder the
deterministic candidate whitelist** — it can never add, drop, or invent a
candidate, and it never overrides gate decisions.

## How to run

```sh
flutter test test/local_ai_replay_report_test.dart
```

This one command regenerates and verifies the reviewer artifact:

- `build/recommendation_scenario_replay/latest.md` — reviewer Markdown (per
  archetype: rankings, decision path, gate reasons, invariant status,
  expected-id matches, and a why-allowed/why-blocked note).
- `build/recommendation_scenario_replay/latest.json` — structured snapshot of
  the same fields.

Both artifacts are **timestamp-free and deterministic**: regenerating them on
unchanged code produces byte-identical files. If a regenerated report differs
from a previously reviewed one, engine/gate/scenario behaviour actually changed
— review the diff rather than regenerating it away.

The broader scenario assertions (decision paths, candidate-set invariant, JSON
byte-stability) live in:

```sh
flutter test test/local_ai_scenario_replay_test.dart
```

## Why there is no `dart run` CLI

The orchestrator transitively imports Flutter via `app_i18n`, so a plain-Dart
CLI cannot compile without a larger i18n refactor. The focused test above is
the supported one-command entry point; a Flutter-free import path for the
orchestrator remains documented future work.
