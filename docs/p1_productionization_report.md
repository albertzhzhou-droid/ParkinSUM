# ParkinSUM P1 Productionization Report

Date: 2026-05-22

This report records the P1 lightweight productionization layer added after P0
technical closure and the later full production-structure gate. It does not
mark the app as publicly releasable.

## Monitoring and Audit

Chosen strategy: Google Cloud Logging / Error Reporting plus local operator
audit.

Prod APIs enabled or verified:

- `logging.googleapis.com`.
- `clouderrorreporting.googleapis.com`.

Prod alerting is configured for internal/private prerelease:

- Email notification channel: `parkinsumservice@gmail.com`.
- Hosting uptime check: `ParkinSUM prod Hosting uptime`.
- Uptime alert policy: `ParkinSUM prod Hosting uptime alert`.
- Error log alert policy: `ParkinSUM prod ERROR log alert`.
- SLA: daily ERROR review, weekly Firebase/backup/budget audit, and
  owner/operator response within 24 hours for critical outage.

No Crashlytics, analytics, or third-party monitoring is enabled in this P1
layer. This avoids transmitting health-related user input to external
analytics/monitoring vendors before privacy/legal review is complete.

Operator audit tooling:

```sh
node tool/operator_audit_summary.mjs --release-id <release_id>
```

Output:

- JSON: `build/operator_reports/<release_id>_audit_summary.json`
- Markdown: `build/operator_reports/<release_id>_audit_summary.md`

Redaction policy:

- ID tokens, refresh tokens, credentials, authorization headers, and passwords
  are redacted.
- Email addresses are replaced with `[EMAIL_REDACTED]`.
- UIDs are represented as SHA-256 prefixes.
- User-entered clinical details are not included in the summary report.

Monitoring and incident response owner for internal/private prerelease:
`zhouzhenghang`.

IAM/operator governance report:
`build/operator_reports/internal_iam_governance_20260523_iam_governance.json`.

Monitoring alert setup report:
`build/operator_reports/internal_monitoring_alerts_20260523_monitoring_alert_setup.json`.

Latest verification:

- `node tool/monitoring_gate.mjs --env prod --project parkinsum-companion --release-id prod_cloud_monitoring_20260522`:
  PASS.
- `node tool/operator_audit_summary.mjs --release-id p0p1_prod_full_structure_20260522`:
  PASS.
- Output:
  `build/operator_reports/p0p1_prod_full_structure_20260522_audit_summary.json`.

## Automated Hosting and Browser Smoke

Repo-local Hosting smoke:

```sh
node tool/hosting_smoke.mjs --release-id <release_id>
```

The script verifies stage/prod public Hosting without login:

- HTTP 200 for `https://parkinsum-companion-stage.web.app/`.
- HTTP 200 for `https://parkinsum-companion.web.app/`.
- `Cache-Control: no-store, max-age=0` on the HTML entrypoint.
- HSTS/TLS Hosting response is present.
- Flutter bootstrap HTML is non-empty and references the Flutter bootstrap
  artifact.

This script does not register, sign in, save meal/intake records, or write
Firestore data.

Latest verification:

- Stage:
  `build/browser_smoke/p0p1_stage_full_structure_20260522_hosting_smoke.json`,
  PASS.
- Prod:
  `build/browser_smoke/p0p1_prod_full_structure_20260522_hosting_smoke.json`,
  PASS.

Browser visual smoke:

- Report: `build/browser_smoke/public_visual_smoke_20260523.json`.
- Status: `PASS`.
- Impact: public visual smoke is no longer an internal/private prerelease
  evidence gap.

## Operator Gate

Unified operator gate:

```sh
node tool/operator_gate.mjs --env stage --project parkinsum-companion-stage --release-id <release_id>
node tool/operator_gate.mjs --env prod --project parkinsum-companion --read-only --release-id <release_id>
```

The gate runs:

- production structure validation for Firebase aliases, Hosting config,
  Firebase options, release manifests, acceptance report, and policy docs.
- Firestore rules contract.
- stage/prod manifest JSON validation.
- real data acceptance JSON validation.
- Browser public smoke record validation as an advisory item.
- Hosting smoke.
- backup export command dry-run.
- backup/export prerequisite gate.
- Firestore live probe: stage uses local stage token file when present; prod is
  read-only and uses `build/operator_tokens/prod_readonly_tokens.json`.
- authenticated E2E smoke: stage writes minimal meal/intake/audit data under
  `users/{uid}`, prod reads only.
- operator audit summary.
- monitoring gate.
- clinical engine gate.
- clinical review report.

The gate can pass technically while still returning `publicReleaseDecision:
HOLD`, because support/privacy contact, monitoring ownership, Browser visual
evidence, and clinical/legal sign-off are external release blockers.

Latest verification:

- `node tool/operator_gate.mjs --env stage --project parkinsum-companion-stage --release-id p0p1_stage_full_structure_20260522`:
  PASS, `technicalPass: true`, `publicReleaseDecision: HOLD`.
- `node tool/operator_gate.mjs --env prod --project parkinsum-companion --read-only --release-id p0p1_prod_full_structure_20260522`:
  PASS, `technicalPass: true`, `publicReleaseDecision: HOLD`.
- Stage gate used refreshed local stage test ID tokens and executed the allowed
  stage live probe and authenticated E2E writes under the stage test user.
- Prod gate used retained disposable readonly Auth users and executed read/deny
  probes only. `writeProbeAllowed` remained `false`.
- Reports:
  `build/operator_reports/p0p1_stage_full_structure_20260522_operator_gate.json`
  and
  `build/operator_reports/p0p1_prod_full_structure_20260522_operator_gate.json`.
- Retained-evidence rerun:
  `build/operator_reports/p0p1_final_stage_retained_gate_20260522_operator_gate.json`
  and
  `build/operator_reports/p0p1_final_prod_retained_gate_20260522_operator_gate.json`,
  both PASS. This mode validates retained live/Flutter/Hosting evidence without
  repeating stage writes or prod read-only network probes.

## Clinical Review

Clinical review report:

```sh
node tool/clinical_review_report.mjs --release-id <release_id>
```

Fixed representative cases:

- Levodopa/protein timing.
- Iron/mineral/dairy timing.
- Missing timing fallback.
- Low-risk/no-conflict case.
- MAOI/tyramine caution.

Final owner/operator acceptance for internal/private prerelease is recorded in
`docs/clinical_legal_privacy_final_signoff_package_20260522.md`. External
clinical/legal professional review is not claimed.

Latest verification:

- `node tool/clinical_review_report.mjs --release-id p0p1_prod_full_structure_20260522`:
  PASS.
- Output:
  `build/clinical_review/p0p1_prod_full_structure_20260522_clinical_review.json`.

Clinical engine gate:

- Report:
  `build/clinical_review/p0p1_prod_full_structure_20260522_clinical_engine_gate.json`.
- Result: PASS in the full-structure gate. It executes the real Flutter tests
  for database-backed meal checks, runtime rule engine, and recommendation
  benchmark coverage.

## Final Local Gate Results

- `npm audit --audit-level=low`: PASS, 0 vulnerabilities.
- `node tool/firestore_rules_contract_check.mjs`: PASS, 10/10 checks.
- `node tool/firestore_live_probe.mjs --env prod --project parkinsum-companion --read-only --token-file build/operator_tokens/prod_readonly_tokens.json`:
  PASS with real disposable readonly Auth users and `writeProbeAllowed: false`.
- Stage billing/backup drill:
  `docs/stage_billing_backup_drill_20260522.md`, PASS for stage export/restore.
- Prod billing/backup/monitoring drill:
  `docs/prod_billing_backup_monitoring_drill_20260522.md`, PASS for billing,
  budget, controlled bucket, 14-day lifecycle, manual export, metadata-only
  restore verification, and Cloud Logging/Error Reporting API availability.

- `flutter analyze`: PASS.
- `flutter test --concurrency=1`: PASS, 148 tests.
- `flutter test test/p0_importers_test.dart --concurrency=1`: PASS, 67 tests.
- Firebase web builds for `dev`, `stage`, and `prod`: PASS.
- Retained-evidence stage/prod operator gates after this rerun: PASS.

## Current Public Release Decision

Decision: `HOLD`.

Reasons:

- Stage backup/export/restore drill passed. Prod billing, budget, controlled
  bucket, lifecycle, and one manual export drill passed. Prod automated backup
  is intentionally not enabled.
- Prod disposable readonly Auth test accounts are retained enabled by operator
  decision and must be cleaned up through the audited CLI when no longer
  needed.
- Browser public visual smoke evidence passed.
- Public support/privacy contact is `parkinsumservice@gmail.com`.
- Monitoring and incident response owner for internal/private prerelease is
  `zhouzhenghang`.
- Owner/operator internal clinical/domain and legal/privacy acceptance is
  recorded; external professional review is not claimed.
