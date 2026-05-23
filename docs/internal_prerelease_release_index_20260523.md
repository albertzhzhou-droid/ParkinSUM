# ParkinSUM Internal Prerelease Release Index

Release id: `internal_governance_20260523`

Decision: `PASS_INTERNAL_PRIVATE_PRERELEASE`

Public launch caveat: external clinical/legal professional review is not
claimed.

## Contact and Ownership

- Support/privacy contact: `parkinsumservice@gmail.com`.
- Owner/operator: `zhouzhenghang`.
- Monitoring owner: `zhouzhenghang`.
- Incident response owner: `zhouzhenghang`.

## Evidence Bundle

| Area | Evidence |
| --- | --- |
| Release manifest | `build/release_manifests/p0_prod_20260522T001247Z.json`, `build/release_manifests/p0_stage_20260522T000753Z.json` |
| Visual smoke | `build/browser_smoke/internal_contact_visual_smoke_20260523.json` |
| IAM governance | `build/operator_reports/internal_iam_governance_20260523_iam_governance.json` |
| Monitoring alerts | `build/operator_reports/internal_monitoring_alerts_20260523_monitoring_alert_setup.json` |
| Monitoring gate | `build/operator_reports/internal_monitoring_alerts_20260523_monitoring_gate.json` |
| Prod backup export | `build/operator_reports/internal_prod_backup_export_20260523.json` |
| Safety verification | `build/operator_reports/internal_safety_verification_20260523.json` |
| Prod readonly account lifecycle | `build/operator_reports/internal_prod_readonly_lifecycle_20260523_prod_readonly_lifecycle.json` |
| Stage operator gate | `build/operator_reports/internal_stage_governance_gate_20260523_operator_gate.json` |
| Prod operator gate | `build/operator_reports/internal_prod_governance_gate_20260523_operator_gate.json` |
| Final signoff package | `build/clinical_review/final_signoff_package_20260522.json` |
| Known risks | `docs/known_risks.md` |
| Acceptance record | `docs/internal_prerelease_acceptance_20260523.md` |

## Required Before Every Future Internal Release

- Run a new prod manual Firestore export to
  `gs://parkinsum-prod-backups/parkinsum/<release_id>`.
- Run stage and prod operator gates.
- Refresh Browser visual smoke.
- Review prod readonly account lifecycle.
- Confirm monitoring channel and alert policies remain enabled.
- Owner/operator signs the acceptance record for the new release id.
