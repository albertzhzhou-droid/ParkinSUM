# Stage Billing and Backup Drill - 2026-05-22

Scope: stage only. Prod billing, prod backup bucket creation, prod automated
export, and prod scheduled export were not performed.

## Billing

- Billing account: `billingAccounts/012517-646CBE-B0D4EC`
- Stage project: `parkinsum-companion-stage`
- Stage billing status: enabled
- Prod project: `parkinsum-companion`
- Prod billing status: disabled

## Budget Guardrail

- Budget id:
  `billingAccounts/012517-646CBE-B0D4EC/budgets/2d7dd940-9fc2-4839-a483-edfc62309743`
- Display name: `ParkinSUM-stage-backup-guardrail`
- Budget amount: CAD 10/month
- Scope: `parkinsum-companion-stage`
- Alert thresholds: 10%, 50%, 100%, equivalent to CAD 1, CAD 5, CAD 10.
- Notification path: default billing IAM recipients.

## Stage Backup Bucket

- Bucket: `gs://parkinsum-companion-stage-p0-backups`
- Location: `US` multi-region
- Storage class: `STANDARD`
- Public access prevention: enforced
- Uniform bucket-level access: enabled
- Soft delete: disabled
- Lifecycle: delete objects older than 14 days
- Lifecycle file: `tool/stage_backup_lifecycle_14d.json`

## Export Drill

Command:

```sh
gcloud firestore export gs://parkinsum-companion-stage-p0-backups/parkinsum/stage_export_drill_20260522 --project=parkinsum-companion-stage --database='(default)'
```

Result: PASS.

Operation:

```text
projects/parkinsum-companion-stage/databases/(default)/operations/ASA1NGI3ZTJmNTkwOGEtOWQ5Yi00ZjA0LTZmZDgtOTZhYjg0NWQkGnNlbmlsZXBpcAkKMxI
```

Export metadata:

- start: `2026-05-23T03:28:43.610257Z`
- end: `2026-05-23T03:28:45.598988Z`
- documents: 479
- bytes: 461114
- output:
  `gs://parkinsum-companion-stage-p0-backups/parkinsum/stage_export_drill_20260522`

## Restore Drill

Preferred non-production restore target was dev, but dev import was blocked
because dev billing remains disabled by decision. Dev billing was not enabled.

Actual restore drill imported the stage export back into stage:

```sh
gcloud firestore import gs://parkinsum-companion-stage-p0-backups/parkinsum/stage_export_drill_20260522 --project=parkinsum-companion-stage --database='(default)'
```

Result: PASS.

Operation:

```text
projects/parkinsum-companion-stage/databases/(default)/operations/AiAzOGJhNGI1NzkwZDktYzM3OS04Mzg0LWJlOGMtN2FhYjUzYTckGnNlbmlsZXBpcAkKMxI
```

Import metadata:

- start: `2026-05-23T03:30:03.344841Z`
- end: `2026-05-23T03:30:07.136905Z`
- documents: 479 / 479
- bytes: 461114 / 461114

## Post-Drill Gates

- `node tool/backup_prereq_check.mjs --env stage --project parkinsum-companion-stage --release-id stage_backup_after_billing_20260522`:
  `READY_FOR_EXPORT_RESTORE_DRILL`.
- `node tool/backup_prereq_check.mjs --env prod --project parkinsum-companion --release-id prod_backup_manual_only_20260522`:
  `BLOCKED_NO_BILLING_OR_BUCKET`.
- `node tool/operator_gate.mjs --env stage --project parkinsum-companion-stage --release-id stage_after_billing_backup_gate_20260522`:
  PASS.

## Prod Follow-Up

The later prod drill completed billing, a controlled backup bucket, 14-day
lifecycle, and one manual Firestore export. Prod remains manual-only only in
the sense that no scheduled export automation exists.

- report: `docs/prod_billing_backup_monitoring_drill_20260522.md`.
- backup prerequisite gate:
  `build/operator_reports/prod_backup_after_billing_20260522_backup_prereq.json`.
- no scheduled export was created.
- no Firestore import was run.

Prod export command generation remains the operator path:

```sh
node tool/firebase_ops.mjs backup-command --env prod --project parkinsum-companion --release-id <release_id> --bucket gs://parkinsum-prod-backups
```
