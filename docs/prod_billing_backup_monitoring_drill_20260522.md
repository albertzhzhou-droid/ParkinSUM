# Prod Billing, Backup, and Monitoring Drill

Date: 2026-05-22 / 2026-05-23 UTC
Environment: prod
Project: `parkinsum-companion`

## Result

Prod billing, budget, controlled backup bucket, one manual Firestore export,
and Google Cloud native monitoring APIs are in place.

This drill did not run a Firestore import, did not create scheduled exports,
did not write application data to prod Firestore, did not grant prod claims,
and did not delete prod users.

Public release remains `HOLD` for non-technical sign-off and visual evidence
items listed below.

## Billing and Budget

- Billing account:
  `billingAccounts/012517-646CBE-B0D4EC`.
- Prod billing: enabled for `parkinsum-companion`.
- Budget:
  `billingAccounts/012517-646CBE-B0D4EC/budgets/716aa6b7-dae3-4cef-a38d-fce2aebd101e`.
- Display name: `ParkinSUM-prod-backup-guardrail`.
- Monthly amount: CAD 10.
- Thresholds: CAD 1, CAD 5, CAD 10.

## Backup Bucket

- Bucket: `gs://parkinsum-prod-backups`.
- Location: `US` multi-region.
- Storage class: `STANDARD`.
- Uniform bucket-level access: enabled.
- Public access prevention: enforced.
- Soft delete: disabled (`0` seconds).
- Lifecycle: delete objects older than 14 days.
- Lifecycle file:
  `tool/prod_backup_lifecycle_14d.json`.

## Firestore Export

Command executed:

```sh
gcloud firestore export gs://parkinsum-prod-backups/parkinsum/prod_export_drill_20260522 --project=parkinsum-companion --database='(default)'
```

Operation:

```text
projects/parkinsum-companion/databases/(default)/operations/ASBiNmJiYzc4NTYzZDktYzRjYi1mY2M0LTM4ZGQtNGExNjYxMzkkGnNlbmlsZXBpcAkKMxI
```

Result:

- operation state: `SUCCESSFUL`.
- start: `2026-05-23T04:02:12.917706Z`.
- end: `2026-05-23T04:02:24.317254Z`.
- documents: 524.
- bytes: 826166.
- output:
  `gs://parkinsum-prod-backups/parkinsum/prod_export_drill_20260522`.

Artifact metadata verified:

- `prod_export_drill_20260522.overall_export_metadata`.
- `all_namespaces_all_kinds.export_metadata`.
- output shards `output-0` through `output-10`.

Restore scope: metadata-only verification. No `gcloud firestore import` was
run against prod, stage, or dev.

## Monitoring

Chosen route: Google Cloud Logging / Error Reporting plus local operator audit.

Enabled or verified APIs:

- `logging.googleapis.com`.
- `clouderrorreporting.googleapis.com`.

Monitoring gate:
`build/operator_reports/prod_cloud_monitoring_20260522_monitoring_gate.json`
passed.

No Crashlytics, Firebase Analytics, Google Analytics, Sentry, Bugsnag,
Datadog, or New Relic dependency is present in the app/package dependency
checks.

## Safety Checks

- Cloud Scheduler API is disabled; no scheduled export was created.
- Cloud Functions API is disabled; no backup function was created.
- Firestore operation list for prod contains this export operation only in this
  pass; no import operation was run.
- Prod custom claims and prod users were not changed in this drill.
- Existing prod readonly disposable Auth test accounts remain enabled by the
  prior operator decision.

## Reports

- JSON report:
  `build/operator_reports/prod_billing_backup_monitoring_drill_20260522.json`.
- Backup prerequisite gate:
  `build/operator_reports/prod_backup_after_billing_20260522_backup_prereq.json`.
- Monitoring gate:
  `build/operator_reports/prod_cloud_monitoring_20260522_monitoring_gate.json`.

## Remaining Public Release Hold Items

- Public support/privacy contact: `parkinsumservice@gmail.com`.
- Monitoring and incident response owner for internal/private prerelease:
  `zhouzhenghang`.
- Owner/operator internal clinical/domain and legal/privacy acceptance:
  `zhouzhenghang`.
- External clinical/legal professional review is not claimed for public launch.
- Browser public visual smoke evidence:
  `build/browser_smoke/public_visual_smoke_20260523.json`.
