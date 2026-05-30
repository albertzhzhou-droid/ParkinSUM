# Public Verification Guide

Educational/research prototype. Synthetic/demo data only. **Not medical advice,
not clinically calibrated, and carries no clinical-validation claim.**

These are the exact commands a reviewer can run to verify ParkinSUM Companion
locally. They are **deterministic, synthetic-data regression and governance
checks** — they are **not** clinical validation, and the source-quality report
is **not** a clinical dashboard.

## Prerequisites

Install Flutter, Dart, Node.js, and npm. From the repository root run
`flutter pub get` and `npm ci` once. All checks below run on **synthetic/demo
data** and, except where noted, require **no network**.

## Core checks

### `flutter analyze`
- **Checks:** static analysis of the Dart/Flutter codebase.
- **Expected:** `No issues found!`
- **Failure means:** a static error/warning was introduced.
- **Network:** no. **Data:** n/a.

### `flutter test --concurrency=1`
- **Checks:** the full unit/widget test suite (rules, importers, mechanistic
  engine, metadata, evidence views, safety-copy guards).
- **Expected:** `All tests passed!`
- **Failure means:** a regression in deterministic behavior or a safety guard.
- **Network:** no. **Data:** synthetic only.

### `dart run tool/run_mechanistic_replay.dart`  (or `npm run mechanistic:replay`)
- **Checks:** the deterministic mechanistic replay suite (41 synthetic
  scenarios) and a banned-prescriptive-phrase scan over every emission.
- **Expected:** `Mechanistic replay: 41/41 scenarios passed.` and report files
  under `build/mechanistic_replay/latest.{json,md}`.
- **Failure means:** a scenario's modeled output changed unexpectedly, or banned
  copy leaked. **This is synthetic regression testing, not clinical validation.**
- **Network:** no. **Data:** synthetic only.

### `npm run public:preflight`
- **Checks:** public-positioning + banned-claim + boundary guardrails across
  README and public docs.
- **Expected:** `"pass": true` with `BLOCKER: 0`.
- **Failure means:** a public doc drifted into an unsafe claim or dropped a
  required boundary phrase.
- **Network:** no. **Data:** n/a.

### `node tool/firestore_rules_contract_check.mjs`  (or `npm run rules:contract`)
- **Checks:** Firestore security-rules contract (owner-scoped, deny-by-default,
  admin/importer write gates).
- **Expected:** `Firestore rules contract passed: 13/13`.
- **Failure means:** a rule regressed against the contract.
- **Network:** no. **Data:** n/a.

## Source-quality report (optional)

### `dart run tool/run_source_quality_perturbation_report.dart`  (or `npm run source:quality`)
- **Checks:** how candidate scoring moves when **only** source/provenance
  quality changes, holding the meal/conflict/model input constant.
- **Expected:** `Source-quality perturbation report: 13 rows.` and report files
  under `build/source_quality_perturbation/latest.{json,md}`.
- **Failure means:** a provenance/source-quality invariant changed (e.g.
  official-in-jurisdiction no longer ≥ synthetic equivalent, or conflict overlap
  no longer dominant).
- **Network:** no. **Data:** synthetic only.
- **Note:** this is a deterministic educational analysis artifact, **not a
  clinical dashboard** and not user-facing advice.

## Release snapshot + demo walkthrough (optional, composed)

These compose the artifacts above into reviewable summaries. They are pure
generators — they parse existing reports (and accept injected counts) rather than
re-running slow commands — and report `missing_artifact` instead of fabricating
results.

### `dart run tool/run_release_snapshot.dart`  (or `npm run release:snapshot`)
- **Checks:** composes one release-evidence snapshot from
  `build/mechanistic_replay/latest.json`,
  `build/source_quality_perturbation/latest.json`, and
  `build/public_release_preflight/latest.json`; analyze/test/firestore results may
  be injected via flags (e.g. `--analyze=clean --test-count=460 --firestore=13/13`).
- **Expected:** `build/release_snapshot/latest.{json,md}` with a per-check table;
  any absent input shows `missing_artifact`.
- **Failure means:** an underlying artifact is missing/malformed (recorded
  in-band, not fabricated). The tool itself exits 0 — it is an evidence summary,
  not a gate.
- **Network:** no. **Data:** synthetic only. **Not clinical validation.**

### `dart run tool/generate_public_demo_walkthrough.dart`  (or `npm run demo:walkthrough`)
- **Checks:** composes a reviewer walkthrough from the replay, source-quality,
  release-snapshot, and a synthetic EvidenceTraceBundle sample.
- **Expected:** `build/public_demo_walkthrough/latest.{md,json}` with synthetic
  input / source-quality / missingness / replay / evidence-bundle summaries plus
  the safety boundary and a "what this does not prove" section; absent inputs show
  `missing_artifact`.
- **Failure means:** a consumed artifact is missing (recorded, not fabricated).
- **Network:** no. **Data:** synthetic only. **No advice; not a clinical
  dashboard.**

## What these checks do and do not establish

- **They establish:** deterministic behavior, preserved provenance/missingness,
  intact safety boundaries, and that public docs stay within the educational
  positioning.
- **They do not establish:** any clinical accuracy, patient-outcome validity, or
  regulatory approval. The model is **not clinically calibrated**, importer
  adapters are fixture-validated (not live production ingestion), and all data is
  synthetic/demo.

See `docs/EVIDENCE_AND_TRACEABILITY_DEMO_GUIDE.md` for a guided walkthrough and
`docs/CAPABILITY_MATRIX.md` for the implemented-vs-future-work summary.
