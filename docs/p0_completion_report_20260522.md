# ParkinSUM P0 Completion Report - 2026-05-22

This report records the current P0 technical closure state after the P0/P1
production-structure gate and the final non-fake blocker closure. It does not
claim external clinical/legal professional review for public launch.

## Environment Isolation

| Environment | Firebase project | Runtime config | Hosting |
| --- | --- | --- | --- |
| dev | `parkinsum-companion-dev` | web config present; non-web fails fast | not deployed |
| stage | `parkinsum-companion-stage` | web config present; non-web fails fast | `https://parkinsum-companion-stage.web.app` |
| prod | `parkinsum-companion` | web/prod config present | `https://parkinsum-companion.web.app` |

Dev project creation, dev Web app creation, dev Firestore rules/index deployment,
and dev web build passed.

## Local Gates

- `npm audit --audit-level=low`: PASS
- `node tool/firestore_rules_contract_check.mjs`: PASS
- `node tool/firestore_live_probe.mjs --env prod --project parkinsum-companion --read-only --run-id p0_prod_readonly_20260522`:
  superseded by real prod read-only probe with disposable Auth users, PASS,
  `writeProbeAllowed: false`
- `flutter analyze`: PASS
- `flutter test --concurrency=1`: PASS, 148 tests
- `flutter test test/p0_importers_test.dart --concurrency=1`: PASS, 67 tests
- Firebase web builds for `dev`, `stage`, and `prod`: PASS

## Stage Live Firebase Probe

Latest run id: `p0_seed_read_20260522`

Full-structure rerun evidence:
`build/operator_reports/p0p1_stage_full_structure_20260522_operator_gate.json`
passed with `technicalPass: true` and `internalPrereleaseDecision:
TECHNICAL_PASS_PRIVATE_PRERELEASE`.

Result: PASS.

Verified:

- unauthenticated private read/write denied.
- user A owner write allowed.
- user A read/write user B denied.
- signed-in normal user can read seeded `app_catalog`.
- signed-in normal user cannot write `app_catalog`.
- importer/admin writes allowed before claim removal.
- importer/admin writes denied after claim removal and token refresh.
- top-level `cdss_tables` denied.
- fallback unknown collection denied.

No prod Firestore write, prod claim mutation, or prod user deletion was
performed.

## Prod Read-Only Firebase Probe

Prod disposable readonly Auth users were created by operator decision and are
retained enabled after the probe. No prod custom claims were granted and no
prod Firestore write/delete was performed.

Evidence:

- token file: `build/operator_tokens/prod_readonly_tokens.json`, local only,
  mode `0600`, ignored under `build/`.
- created at: `2026-05-22T16:15:00.228Z`
- retention: `enabled_after_probe`
- uid hashes: `e10ee14e916c`, `af3e1dd65fa0`
- live probe run id: `p0p1_prod_full_structure_20260522_live_probe`
- operator gate:
  `build/operator_reports/p0p1_prod_full_structure_20260522_operator_gate.json`

Verified:

- unauthenticated private read denied.
- user A cannot read user B private data.
- signed-in prod readonly user can read `app_catalog/foods/rows/food_banana`.
- top-level `cdss_tables` denied.
- fallback unknown collection denied.
- `writeProbeAllowed: false`.

During this pass a prod rules mismatch was found first: top-level
`cdss_tables` returned 404 instead of permission denied. Local
`firestore.rules` was deployed to prod with Firebase CLI, then the prod
read-only probe passed with 403 deny responses on protected paths.

## Official Data Acceptance

Stage curated seed acceptance:

- report: `build/acceptance_reports/p0_stage_real_data_acceptance_20260522.md`
- seed: `build/firebase_seed/stage_official_core_seed.json`
- seed sha256:
  `70f5fc58fe8e05bba574ddd9d79ed70b2a4b33210b9d8b416eaff019eda54f95`
- snapshot id: `firebase_seed_p0_core_v1`
- import run id: `ingest_firebase_seed_p0_core_v1`
- documents uploaded to stage: 504/504
- readiness blockers: 0
- readiness warnings: 2

The remaining warnings are clinical/domain reviewer sign-off and pending
privacy/support contact.

## Release and Hosting

Stage:

- manifest: `build/release_manifests/p0_stage_20260522T000753Z.json`
- release:
  `projects/parkinsum-companion-stage/sites/parkinsum-companion-stage/channels/live/releases/1779408512894000`
- version:
  `projects/parkinsum-companion-stage/sites/parkinsum-companion-stage/versions/f179c5e30c0f115a`
- source bundle sha256:
  `e3ad04eb3feb65712f6fd40a36af11628d1371911be953060e604dd21119da4d`

Prod:

- manifest: `build/release_manifests/p0_prod_20260522T001247Z.json`
- release:
  `projects/parkinsum-companion/sites/parkinsum-companion/channels/live/releases/1779408806993000`
- version:
  `projects/parkinsum-companion/sites/parkinsum-companion/versions/e37ac581d49babae`
- source bundle sha256:
  `53709e93a0f759d9cd7f666cb90b90c29ae4883f7adfc20b611476e87a05871c`

Hosting HTTP smoke passed for both public URLs. Firebase Hosting returns 200
with `no-store` cache headers for the HTML entrypoint and TLS on the default
`web.app` domains.

The current in-app Browser visual smoke on 2026-05-23 opened both Firebase
`web.app` URLs in read-only mode and captured screenshots. Browser evidence is
recorded in `build/browser_smoke/public_visual_smoke_20260523.json`; HTTP/Hosting
smoke remains the technical evidence for public URL reachability.

Latest public URL evidence:

```text
stage URL: https://parkinsum-companion-stage.web.app/
stage HTTP: 200, cache-control no-store, max-age=0
stage Browser visual smoke: PASS
stage hosting smoke: build/browser_smoke/p0p1_stage_full_structure_20260522_hosting_smoke.json

prod URL: https://parkinsum-companion.web.app/
prod HTTP: 200, cache-control no-store, max-age=0
prod Browser visual smoke: PASS
prod hosting smoke: build/browser_smoke/p0p1_prod_full_structure_20260522_hosting_smoke.json
```

Prod read-only live probe status:

```text
command: node tool/firestore_live_probe.mjs --env prod --project parkinsum-companion --read-only --token-file build/operator_tokens/prod_readonly_tokens.json
result: PASS
writeProbeAllowed: false
account retention: enabled_after_probe
```

The real prod read/deny probe used disposable readonly Auth users and did not
perform prod Firestore writes.

## P1 Operator Gate Overlay

P1 lightweight productionization tooling has been added and verified:

- `tool/operator_audit_summary.mjs`: local redacted operator-audit summary.
- `tool/hosting_smoke.mjs`: repo-local stage/prod Hosting HTTP/cache/bootstrap
  smoke.
- `tool/operator_gate.mjs`: rules, manifests, acceptance report, Hosting smoke,
  backup-command dry-run, live-probe, audit summary, and clinical-review
  aggregator.
- `tool/clinical_review_report.mjs`: fixed clinical safety-review checklist and
  report.

Latest full-structure operator gates:

- stage:
  `build/operator_reports/p0p1_stage_full_structure_20260522_operator_gate.json`,
  technical PASS, internal private prerelease
  `TECHNICAL_PASS_PRIVATE_PRERELEASE`, public release `HOLD`.
- stage after billing/backup drill:
  `build/operator_reports/stage_after_billing_backup_gate_20260522_operator_gate.json`,
  technical PASS, stage backup prerequisite READY.
- prod:
  `build/operator_reports/p0p1_prod_full_structure_20260522_operator_gate.json`,
  technical PASS, internal private prerelease
  `TECHNICAL_PASS_PRIVATE_PRERELEASE`, public release `HOLD`.

Stage gate executed allowed Firestore writes. Prod gate executed real read/deny
probes with `build/operator_tokens/prod_readonly_tokens.json` and remained
read-only with `writeProbeAllowed: false`.

## User Rights Drill

Disposable stage uid: `uAN2yV1gfRSGR1DsLE0uLk6Ey2P2`

- wrote minimal private test data under `users/{uid}/app_meta/...`: PASS
- exported only `users/{uid}`: PASS, 1 document
- deleted `users/{uid}`: PASS, 1 document deleted
- deleted disposable Auth account with explicit flag: PASS
- post-delete export: PASS, 0 documents
- audit log: `build/operator_audit/operator_audit.jsonl`

## Remaining Blockers

- Stage backup/export/restore drill is complete. Prod now has billing, a
  controlled backup bucket, a 14-day lifecycle, and one successful manual
  Firestore export drill. Prod restore verification is metadata-only; no prod,
  stage, or dev import was run. No scheduled prod export was created.
- Prod readonly disposable Auth test accounts are retained enabled by operator
  decision; cleanup must use the audited CLI path if/when no longer needed.
- Public visual smoke evidence is recorded in
  `build/browser_smoke/public_visual_smoke_20260523.json`.
- Public support/privacy contact is `parkinsumservice@gmail.com`.
- Monitoring and incident response owner for internal/private prerelease is
  `zhouzhenghang`.
- Owner/operator internal clinical/domain and legal/privacy acceptance is
  recorded; external professional review is not claimed.
- Custom public domain is not configured; current Hosting uses Firebase default
  `web.app` TLS domains.
