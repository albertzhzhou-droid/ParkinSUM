# ParkinSUM P0/P1 Resume Closure Report - 2026-05-22

This report records the continuation from the prior P0/P1 production-structure
gate. It keeps the release decision as internal/private prerelease only.

## Re-run Gates

| Gate | Result |
| --- | --- |
| `npm audit --audit-level=low` | PASS, 0 vulnerabilities |
| `node tool/firestore_rules_contract_check.mjs` | PASS, 10/10 checks |
| `node tool/production_structure_check.mjs --release-id p0p1_resume_structure_20260522` | PASS |
| `node tool/operator_gate.mjs --env stage --project parkinsum-companion-stage --release-id p0p1_resume_stage_retained_gate_20260522 --retained-evidence` | PASS |
| `node tool/operator_gate.mjs --env prod --project parkinsum-companion --read-only --release-id p0p1_resume_prod_retained_gate_20260522 --retained-evidence` | PASS |
| `flutter analyze` | PASS |
| `flutter test --concurrency=1` | PASS, 148 tests |
| `flutter test test/p0_importers_test.dart --concurrency=1` | PASS, 67 tests |
| Firebase web build, `PARKINSUM_ENV=dev` | PASS |
| Firebase web build, `PARKINSUM_ENV=stage` | PASS |
| Firebase web build, `PARKINSUM_ENV=prod` | PASS |
| Stage billing and backup drill | PASS |

## Retained Live Evidence

- Stage full-structure gate:
  `build/operator_reports/p0p1_stage_full_structure_20260522_operator_gate.json`
- Prod full-structure gate:
  `build/operator_reports/p0p1_prod_full_structure_20260522_operator_gate.json`
- Stage retained-evidence rerun:
  `build/operator_reports/p0p1_resume_stage_retained_gate_20260522_operator_gate.json`
- Prod retained-evidence rerun:
  `build/operator_reports/p0p1_resume_prod_retained_gate_20260522_operator_gate.json`
- Stage billing/backup drill:
  `build/operator_reports/stage_billing_backup_drill_20260522.json`
- Stage post-backup operator gate:
  `build/operator_reports/stage_after_billing_backup_gate_20260522_operator_gate.json`

Prod retained readonly account state:

```text
token file: build/operator_tokens/prod_readonly_tokens.json
file mode: 0600
created at: 2026-05-22T16:15:00.228Z
retention: enabled_after_probe
uid hashes: e10ee14e916c, af3e1dd65fa0
claims: admin=false, cdssImporter=false
```

## Current Decision

Internal/private prerelease technical status: PASS.

Public release decision: HOLD.

Public blockers:

- stage backup/export/restore drill is complete; prod billing, controlled
  bucket, 14-day lifecycle, and one manual export drill are complete. Prod
  restore verification is metadata-only and no import was run.
- public support/privacy contact is `parkinsumservice@gmail.com`.
- production monitoring owner and incident response owner for internal/private
  prerelease: `zhouzhenghang`.
- owner/operator internal clinical/domain and legal/privacy acceptance is
  recorded; external professional review is not claimed.
- Browser public visual smoke evidence is recorded in
  `build/browser_smoke/public_visual_smoke_20260523.json`.
