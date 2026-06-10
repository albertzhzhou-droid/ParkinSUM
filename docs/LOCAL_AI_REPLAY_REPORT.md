# Local AI Scenario Replay — Reviewer Report

Educational/research prototype. Synthetic/demo data only. The replay is
engineering review material — **not medical advice, not calibrated for real
care, and it carries no clinical-validation claim.**

## What it is

A deterministic replay of five fixed synthetic archetypes through the same
conservative + hybrid next-meal orchestrators the app uses, with an offline
scripted Local AI stand-in (no network, no real model):

| Archetype | Expected behaviour |
| --- | --- |
| `missing_medication_time_or_dose` | Data-quality gate keeps the conservative ranking |
| `low_risk_next_meal` | Safety checks permit Local AI reranking of the safe whitelist only |
| `source_fallback_partial_provenance` | AI consent off; deterministic path recorded |
| `safety_gate_blocks_local_ai` | Low-quality meal time blocks AI reranking |
| `medication_catalog_selection_context` | Medication context flows into the safe AI path |

The report pins one safety invariant: **the Local AI path may only reorder the
deterministic candidate whitelist** — it can never add, drop, or invent a
candidate, and it never overrides gate decisions.

## How to run

```sh
npm run recommend:replay
# or, equivalently (also verifies the report content):
flutter test test/local_ai_replay_report_test.dart
```

Either command regenerates the reviewer artifact (both entry points produce
byte-identical files; the focused test additionally asserts the content):

- `build/recommendation_scenario_replay/latest.md` — reviewer Markdown (per
  archetype: rankings, decision path, gate reasons, invariant status,
  expected-id matches, and a why-allowed/why-blocked note).
- `build/recommendation_scenario_replay/latest.json` — structured snapshot of
  the same fields.

Both artifacts are **timestamp-free and deterministic**: regenerating them on
unchanged code produces byte-identical files. If a regenerated report differs
from a previously reviewed one, engine/gate/scenario behaviour actually changed
— review the diff rather than regenerating it away.

Once generated, the artifact is also surfaced downstream: `npm run
release:snapshot` adds a `recommendation_scenario_replay` row (dataset version,
case count, invariant status, gate-reason visibility, synthetic scope) and
`npm run evidence:graph` adds a `recommendation_scenario_replay` node linked to
the release snapshot and the safety boundary.

The broader scenario assertions (decision paths, candidate-set invariant, JSON
byte-stability) live in:

```sh
flutter test test/local_ai_scenario_replay_test.dart
```

## CLI notes

`npm run recommend:replay` runs `tool/run_recommendation_scenario_replay.dart`
under plain `dart run` (no device, no network, no real model). This became
possible after the Flutter-facing i18n members (`BuildContext` access and
`Locale` mapping) were split into `lib/core/i18n/app_i18n_context.dart`,
leaving `app_i18n.dart` — and therefore the whole recommendation stack — pure
Dart. The CLI exits non-zero iff the Local-AI candidate-set invariant is
violated.
