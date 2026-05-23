# Firebase Production Operations Runbook

This runbook covers production custom claims, Firestore rules validation,
backup/export, audit logging, error monitoring, and user data export/deletion
for ParkinSUM Companion.

## 1. Production Claims Issuance

Privileged claims recognized by Firestore rules:

- `admin: true`
- `cdssImporter: true`

Use `admin` for operational maintainers only. Use `cdssImporter` for identities
that publish shared reference data. Normal users must not receive either claim.

Before granting a claim:

- [ ] Environment confirmed: dev, stage, or prod.
- [ ] Firebase project id confirmed.
- [ ] Firebase uid confirmed.
- [ ] Request owner recorded.
- [ ] Business reason recorded.
- [ ] Approver recorded.
- [ ] Expiry/review date recorded.
- [ ] Stage verification completed before prod.

After granting a claim:

- [ ] User signs out and signs in again to refresh token.
- [ ] ID token claim is verified.
- [ ] Normal user write to `app_catalog` still fails.
- [ ] Importer/admin write to intended shared path succeeds.
- [ ] Claim grant is recorded in the operator log.

Claim removal:

- [ ] Firebase uid confirmed.
- [ ] `admin` and/or `cdssImporter` removed.
- [ ] Refresh tokens revoked if access must end immediately.
- [ ] User signs out and signs in again.
- [ ] Privileged write fails after token refresh.
- [ ] Removal is recorded in the operator log.

Do not commit service account keys or ad hoc claim-setting scripts with private
credentials. Keep the claim-setting mechanism in an operator-controlled secure
environment.

Safe CLI dry-run:

```sh
node tool/firebase_ops.mjs claims --env stage --project parkinsum-companion-stage --uid <uid> --claim cdssImporter --mode set --operator <name>
```

Execute only after approval:

```sh
node tool/firebase_ops.mjs claims --env stage --project parkinsum-companion-stage --uid <uid> --claim cdssImporter --mode set --operator <name> --execute --confirm <uid> --confirm-project parkinsum-companion-stage
```

## 2. Firestore Rules Test Gate

Rules must pass both static contract checks and live environment checks.

Static checks:

```sh
cd /Users/zhouzhenghang/Desktop/ParkinSUM/flutter_application_1
"/Users/zhouzhenghang/Applications/Flutter SDK/flutter/bin/flutter" test test/firebase_user_binding_test.dart
node tool/firestore_rules_contract_check.mjs
```

Live checks in stage before prod:

- [ ] unauthenticated read/write to `users/{uid}` is denied.
- [ ] user A can read/write `users/{uidA}`.
- [ ] user A cannot read/write `users/{uidB}`.
- [ ] signed-in normal user can read allowed `app_catalog` rows.
- [ ] signed-in normal user cannot write `app_catalog` rows.
- [ ] `cdssImporter` user can write intended `app_catalog` rows.
- [ ] top-level `cdss_tables` read/write is denied.
- [ ] fallback deny-all blocks unknown collections.

Live probe dry-run when tokens are missing:

```sh
node tool/firestore_live_probe.mjs --env stage --project parkinsum-companion-stage
```

Stage live probe with ID tokens:

```sh
node tool/firestore_live_probe.mjs --env stage --project parkinsum-companion-stage --user-a-uid <uidA> --user-b-uid <uidB> --user-a-token <tokenA> --user-b-token <tokenB> --normal-token <normalToken> --importer-token <importerToken>
```

Latest P0 stage live verification:

```sh
node tool/firestore_live_probe.mjs --env stage --project parkinsum-companion-stage --token-file build/operator_tokens/stage_test_tokens_p0.json --cleared-token-file build/operator_tokens/stage_test_tokens_p0_cleared.json --skip-privileged-allow --run-id p0_seed_read_20260522
```

Result: PASS. The run verified unauthenticated private deny, user A owner write
allow, user A read/write user B deny, signed-in catalog read allow, normal
catalog write deny, cleared importer/admin catalog write deny, top-level
`cdss_tables` deny, and fallback deny-all. Earlier in the same P0 pass,
importer/admin write allow was verified before clearing the claims.

Prod read-only probe:

```sh
node tool/firestore_live_probe.mjs --env prod --project parkinsum-companion --read-only --token-file build/operator_tokens/prod_readonly_tokens.json --run-id p0_prod_readonly_20260522
```

Required local token file:

```json
{
  "accounts": [
    { "role": "userA", "uid": "<prod_test_uid_a>", "idToken": "<id_token>" },
    { "role": "userB", "uid": "<prod_other_uid_or_probe_uid>", "idToken": "<id_token_or_same_token>" }
  ]
}
```

Do not commit this file and do not print token values in reports. In prod,
`--read-only` must remain present unless a separate written approval authorizes
prod writes. Without token file, the command exits as dry-run and records
`writeProbeAllowed=false`.

Prod rules deploy command after review:

```sh
firebase deploy --only firestore:rules,firestore:indexes --project <prod_project_id>
```

## 3. Backup and Export Strategy

Before production launch, configure at least one durable export path.

Minimum manual export before each production_candidate publish:

```sh
firebase firestore:export gs://<backup_bucket>/parkinsum/<release_id> --project <prod_project_id>
```

Generate the command and audit record without running the export:

```sh
node tool/firebase_ops.mjs backup-command --env prod --project parkinsum-companion --release-id <release_id> --bucket gs://<backup_bucket>
```

Stage backup drill result:

- Stage project `parkinsum-companion-stage` is linked to billing account
  `billingAccounts/012517-646CBE-B0D4EC`.
- Prod project `parkinsum-companion` is now also linked to the same billing
  account for controlled manual backup/export operations.
- Stage budget guardrail exists:
  `billingAccounts/012517-646CBE-B0D4EC/budgets/2d7dd940-9fc2-4839-a483-edfc62309743`.
- Budget thresholds are CAD 1, CAD 5, and CAD 10 against a CAD 10 monthly
  budget scoped to stage.
- Stage bucket exists:
  `gs://parkinsum-companion-stage-p0-backups`.
- Bucket lifecycle deletes objects older than 14 days.
- Stage export drill succeeded:
  `gs://parkinsum-companion-stage-p0-backups/parkinsum/stage_export_drill_20260522`,
  479 documents, 461114 bytes.
- Stage restore drill succeeded by importing the stage export back into stage:
  479/479 documents, 461114/461114 bytes.
- Report: `docs/stage_billing_backup_drill_20260522.md`.

Prod backup drill result:

- Billing account:
  `billingAccounts/012517-646CBE-B0D4EC`.
- Prod budget guardrail:
  `billingAccounts/012517-646CBE-B0D4EC/budgets/716aa6b7-dae3-4cef-a38d-fce2aebd101e`.
- Budget thresholds are CAD 1, CAD 5, and CAD 10 against a CAD 10 monthly
  budget scoped to prod.
- Bucket: `gs://parkinsum-prod-backups`.
- Bucket lifecycle deletes objects older than 14 days.
- Prod export drill succeeded:
  `gs://parkinsum-prod-backups/parkinsum/prod_export_drill_20260522`,
  524 documents, 826166 bytes.
- Restore verification was metadata-only. No `gcloud firestore import` was run
  against prod, stage, or dev.
- No scheduled prod export was created.
- Report: `docs/prod_billing_backup_monitoring_drill_20260522.md`.

Prod remains explicit-operator only for future exports. Generate and audit the
command first:

```sh
node tool/firebase_ops.mjs backup-command --env prod --project parkinsum-companion --release-id <release_id> --bucket gs://parkinsum-prod-backups
```

Every internal/private prerelease must include a fresh manual prod export before
the owner/operator acceptance is signed. The current internal release export is:

```text
release id: internal_governance_20260523
path: gs://parkinsum-prod-backups/parkinsum/internal_governance_20260523
operation: projects/parkinsum-companion/databases/(default)/operations/ASA4MWE0MjhlMTQ3ZGUtMjEyOC1mNGI0LTZiOTAtZjhjZGE2MGEkGnNlbmlsZXBpcAkKMxI
documents: 524
bytes: 826166
restore: metadata-only, no import
```

Record:

- release id.
- Firebase project id.
- database id.
- export bucket/path.
- export start and completion time.
- operator.
- restore test status.

Backup requirements:

- [x] Stage bucket access is restricted.
- [x] Stage retention period is documented.
- [x] Stage export path is tied to release/drill id.
- [x] Stage restore process is tested.
- [x] Prod bucket access is restricted.
- [x] Prod retention period is documented.
- [x] Prod manual export path is tied to drill id.
- [x] Prod restore verification is metadata-only with no import run.
- [ ] User deletion obligations are considered when restoring old backups.
- [x] Prod backup destination and billing decision are explicitly approved.

## 4. Logging and Audit Review

Maintain an operator log outside normal user collections. At minimum record:

- rules deployments.
- index deployments.
- seed uploads.
- official data imports.
- claim grants/removals.
- release candidate decisions.
- override reasons.
- rollback events.
- user data export/deletion requests.

For each event, record:

- timestamp.
- operator.
- environment.
- Firebase project id.
- affected uid or release id.
- action.
- reason.
- evidence/artifact link.

The app should keep patient/private runtime records under `users/{uid}` only.
Shared logs must not include meal details, medication details, or other
user-private clinical content unless a privacy review explicitly approves it.

## 5. Error Monitoring

Before public release, choose and document one monitoring path:

- Firebase Crashlytics/Performance where platform support and privacy review are
  completed.
- Google Cloud Logging/Error Reporting for backend/operator scripts.
- A separate privacy-reviewed monitoring vendor.
- Manual internal release monitoring for non-public pilots.

Minimum monitoring checklist:

- [ ] Monitoring owner recorded.
- [ ] Error source recorded.
- [ ] Sensitive data redaction reviewed.
- [ ] Alert threshold recorded.
- [ ] Incident response owner recorded.
- [ ] Rollback trigger tied to severe production errors.

Do not enable analytics, crash reporting, or third-party monitoring that can
collect health-related user input until it is covered by the privacy notice.

Current P1 monitoring decision:

- Use Google Cloud Monitoring / Error Reporting plus local operator audit
  summary.
- Do not enable Crashlytics, analytics, or third-party monitoring yet.
- Notification channel:
  `parkinsumservice@gmail.com`.
- Prod uptime alert:
  `ParkinSUM prod Hosting uptime alert`.
- Prod error-log alert:
  `ParkinSUM prod ERROR log alert`.
- SLA: new Error Reporting / ERROR events are checked daily; Hosting/Auth/
  Firestore/backup/budget posture is reviewed weekly; critical outage requires
  owner/operator response within 24 hours and an explicit rollback decision.
- Generate a redacted operator audit report with:

```sh
node tool/operator_audit_summary.mjs --release-id <release_id>
```

The report redacts tokens, credential values, emails, and full UIDs. User-entered
clinical details must not be written to shared operator logs.

Current governance reports:

- IAM governance:
  `build/operator_reports/internal_iam_governance_20260523_iam_governance.json`.
- Monitoring alert setup:
  `build/operator_reports/internal_monitoring_alerts_20260523_monitoring_alert_setup.json`.
- Monitoring gate:
  `build/operator_reports/internal_monitoring_alerts_20260523_monitoring_gate.json`.

## 6. User Data Export Path

A user data export should include only that user's private records:

- `users/{uid}/profile/current`
- `users/{uid}/meals/...`
- `users/{uid}/intakes/...`
- `users/{uid}/active_drugs/...`
- `users/{uid}/app_meta/...`
- `users/{uid}/clinical_audits/...`
- `users/{uid}/cdss_tables/...`

Export request checklist:

- [ ] Requester identity verified.
- [ ] Firebase uid confirmed.
- [ ] Export scope confirmed.
- [ ] Export generated from `users/{uid}` only.
- [ ] Shared catalog rows excluded unless needed as reference metadata.
- [ ] Export delivery method approved.
- [ ] Operator log updated.

Safe CLI dry-run:

```sh
node tool/firebase_ops.mjs user-export --env stage --project parkinsum-companion-stage --uid <uid> --operator <name>
```

Execute only after approval:

```sh
node tool/firebase_ops.mjs user-export --env stage --project parkinsum-companion-stage --uid <uid> --operator <name> --execute --confirm <uid> --confirm-project parkinsum-companion-stage
```

P0 stage drill:

```text
uid: uAN2yV1gfRSGR1DsLE0uLk6Ey2P2
export: build/user_exports/p0_stage_disposable_export.json
scope: users/uAN2yV1gfRSGR1DsLE0uLk6Ey2P2
documents: 1
operator audit: build/operator_audit/operator_audit.jsonl
```

The export command scoped output to `users/{uid}` only.

## 7. User Data Deletion Path

Deletion is destructive and requires explicit operator confirmation.

Deletion scope:

- Firestore private data under `users/{uid}`.
- Firebase Auth account, if requested and approved.
- Any support logs that contain user-identifying data, where feasible.

Deletion checklist:

- [ ] Requester identity verified.
- [ ] Firebase uid confirmed.
- [ ] User understands deletion scope.
- [ ] Backup retention limitation disclosed.
- [ ] Firestore `users/{uid}` deletion completed.
- [ ] Auth account deletion completed if requested.
- [ ] Deletion verification completed.
- [ ] Operator log updated without storing clinical details.

Safe CLI dry-run:

```sh
node tool/firebase_ops.mjs user-delete --env stage --project parkinsum-companion-stage --uid <uid> --operator <name>
```

Execute Firestore private-data deletion only after approval:

```sh
node tool/firebase_ops.mjs user-delete --env stage --project parkinsum-companion-stage --uid <uid> --operator <name> --execute --confirm <uid> --confirm-project parkinsum-companion-stage
```

Add `--delete-auth` only when the approved request also covers Firebase Auth
account deletion.

Do not delete shared catalog, source document, or rule records as part of a
single-user deletion request unless those records contain user-private data.

P0 stage drill:

```text
uid: uAN2yV1gfRSGR1DsLE0uLk6Ey2P2
deleted Firestore documents: 1
Auth account deleted: true
post-delete export: build/user_exports/p0_stage_disposable_after_delete.json
post-delete documents: 0
operator audit: build/operator_audit/operator_audit.jsonl
```

This drill used a disposable stage account only. Do not reuse it as a product
account.

## 8. Production Acceptance Summary

Before marking Firebase production acceptance complete:

- [x] claims workflow recorded.
- [x] rules static checks passed.
- [x] stage live rules checks passed.
- [ ] prod rules target reviewed.
- [x] backup/export strategy recorded.
- [x] audit log path recorded.
- [x] monitoring path recorded.
- [x] privacy policy reviewed for internal/private prerelease by owner/operator.
- [x] user export path documented.
- [x] user deletion path documented.
- [x] browser smoke passed on Firebase mode.

Remaining caveat: external clinical/legal professional review is not claimed by
the owner/operator internal/private prerelease sign-off.
