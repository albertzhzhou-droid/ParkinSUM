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

### `dart run tool/generate_evidence_graph.dart`  (or `npm run evidence:graph`)
- **Checks:** composes a local evidence/provenance **graph** (nodes + edges) from
  the replay, source-quality, release-snapshot artifacts and a synthetic
  EvidenceTraceBundle sample.
- **Expected:** `build/evidence_graph/latest.{json,mmd,md}`; absent inputs show
  nodes with `status: missing_artifact`.
- **Failure means:** a consumed artifact is missing (recorded as a
  `missing_artifact` node, not fabricated).
- **Network:** no. **Data:** synthetic only. **Local graph — not a FHIR
  Provenance resource, not W3C PROV, not a patient record.** See
  `docs/EVIDENCE_GRAPH.md`.

### `dart run tool/run_synthetic_scenario_fuzzer.dart`  (or `npm run scenario:fuzz`)
- **Checks:** deterministic synthetic boundary cases (dosage, nutrient
  missingness, release-type, source-quality, window/ranking, safety-copy/no-PHI)
  evaluated against the existing gates with real code.
- **Expected:** `build/synthetic_scenario_fuzzer/latest.{json,md}` and
  `N/N cases passed`. Supports `--seed`, `--case-count`, `--family`.
- **Failure means:** a boundary regression — e.g. a unitless dose validates,
  missing nutrient treated as zero, tier ordering broken, or banned/advice copy
  leaked. **Exits non-zero** on a must-pass invariant failure.
- **Network:** no. **Data:** synthetic only. **Stress testing, not clinical
  validation or patient simulation.** See `docs/SYNTHETIC_SCENARIO_FUZZER.md`.

### `dart run tool/run_localization_safety_lint.dart`  (or `npm run localization:lint`)
- **Checks:** user-visible copy + localization surfaces for missing safety
  boundaries, missing evidence/limitation wording, placeholder problems, and
  unsafe prescriptive/overconfident phrases (en/zh/fr/ja). Lints the safe-copy
  template registry; supports `--strict`.
- **Expected:** `build/localization_safety_lint/latest.{json,md}` with
  info/warn/blocker counts and `pass=true` (0 blockers) for the safe registry.
- **Failure means:** unsafe localized copy (or, in strict mode, missing required
  coverage/placeholder). **Exits non-zero** on a blocker.
- **Network:** no. **Data:** synthetic/template only. **Copy-safety lint — not a
  translation-quality or clinical-safety guarantee; no LLM.** See
  `docs/LOCALIZATION_SAFETY_LINT.md`.

### `dart run tool/run_local_privacy_preflight.dart`  (or `npm run privacy:preflight`)
- **Checks:** git-tracked files for secrets (private keys, service accounts,
  tokens, api-key/password assignments, DB-URL credentials), PHI-like fields,
  absolute local machine paths, raw private export filenames, real-health
  narratives, and generated/local directories. Complements `public:preflight`;
  honors the Firebase-client-config and safety-policy allowlists; supports
  `--strict`.
- **Expected:** `build/local_privacy_preflight/latest.{json,md}` with
  info/warn/blocker counts and `pass=true` (0 blockers) for the repo.
- **Failure means:** a likely secret/PHI/raw-export leak (or, in strict mode, a
  warn). **Exits non-zero** on a blocker.
- **Network:** no. **Data:** synthetic/demo only. **Repo-hygiene / privacy-risk
  preflight — NOT HIPAA/GDPR/PIPEDA compliance, not a legal certification, not
  clinical validation, and does not prove the app is secure.** See
  `docs/LOCAL_PRIVACY_PREFLIGHT.md`.

### `dart run tool/run_source_access_contract_check.dart`  (or `npm run source:access`)
- **Checks:** tracked source references against the machine-readable source
  access contract: fixture/live/production status, API-key/account constraints,
  license/legal-review flags, and mechanism-evidence vs identity/coding roles.
- **Expected:** `build/source_access_contract/latest.{json,md}` with
  `pass=true` and zero blockers.
- **Failure means:** a source ID or usage role needs explicit governance
  metadata. **This is release hygiene, not legal advice, license clearance,
  production-readiness certification, or clinical validation.**
- **Network:** no. **Data:** metadata only. See
  `docs/SOURCE_ACCESS_CONTRACT.md`.

### `dart run tool/run_input_quality_demo.dart`  (or `npm run input:quality`)
- **Checks:** runs the InputQualityGate over eight deterministic synthetic
  cases (complete context, unitless dose, missing protein, true 0 g protein,
  missing window, unknown release type, synthetic vs official source, imputed
  provenance) and reports per-dimension context-completeness status.
- **Expected:** `build/input_quality/latest.{json,md}` with one row per case
  (overall status, mechanistic-primary eligibility, blocker count).
- **Failure means:** a context-completeness invariant changed — e.g. a unitless
  dose validated, missing nutrient treated as zero, product strength rescued a
  missing dose, or synthetic source reached official confidence.
- **Network:** no. **Data:** synthetic only. **Input/context-completeness
  assessment only — not medical advice, not a recommendation engine, and not
  clinically calibrated.** See `docs/INPUT_QUALITY_GATE.md`.

### `dart run tool/run_catalog_resolution_demo.dart`  (or `npm run catalog:resolve`)
- **Checks:** runs the CatalogResolutionEngine over fixed synthetic queries
  (milk tea, 奶茶, levodopa, Sinemet, carbidopa levodopa 25/100, levodopa CR,
  unknown food, unknown drug) against a small synthetic catalog and reports the
  ranked candidates, confidence band, match type, and status per query.
- **Expected:** `build/catalog_resolution/latest.{json,md}` with one row per
  query; exact/brand/localized matches resolve high, ambiguous queries are
  `ambiguous`, and unknown queries are `unresolved`.
- **Failure means:** a resolution invariant changed — e.g. an ambiguous query
  became overconfident `resolved`, a dose-like token was converted into a
  candidate strength, or a synthetic source was treated as official.
- **Network:** no. **Data:** synthetic only. **Returns candidates + uncertainty
  — not a recommendation, not medical advice, infers no user dose, and is not
  clinically calibrated.** See `docs/CATALOG_RESOLUTION_ENGINE.md`.

### `dart run tool/run_source_version_drift_check.dart`  (or `npm run source:drift`)
- **Checks:** collects source/version metadata records from the source-access
  registry, model-assumption registry, bibliography, source adapters, and build
  artifacts, then flags missing version/date metadata, stale/undated artifacts,
  registry/bibliography mismatches, fixture-vs-production status conflicts,
  deprecated-source usage, and assumption-registry drift. Supports `--strict`,
  `--now=ISO`, `--staleness-days=N`.
- **Expected:** `build/source_version_drift/latest.{json,md}` with record count
  and info/warn/blocker counts; `pass=true` (0 blocker) for the repo.
- **Failure means:** a provenance/version drift that should fail release hygiene
  (e.g. a fixture-only source claimed production-ready). **Exits non-zero** on a
  blocker.
- **Network:** no. **Data:** local files only. **Provenance / release-hygiene
  only — does not fetch or update live sources, is not legal/license clearance,
  not clinical validation, and does not prove medical correctness.** See
  `docs/SOURCE_VERSION_DRIFT_CHECK.md`.

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
