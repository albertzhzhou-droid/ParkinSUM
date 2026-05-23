# IAM / Operator Governance

Release id: `internal_governance_20260523`

Report: `build/operator_reports/internal_iam_governance_20260523_iam_governance.json`

## Operator Identities

- Stage operator:
  `parkinsum-stage-operator@parkinsum-companion-stage.iam.gserviceaccount.com`.
- Prod operator:
  `parkinsum-prod-operator@parkinsum-companion.iam.gserviceaccount.com`.
- Prod breakglass:
  `parkinsum-prod-breakglass@parkinsum-companion.iam.gserviceaccount.com`.

The originally proposed breakglass account id
`parkinsum-prod-breakglass-operator` exceeds the Google service account
30-character account-id limit. The shortened account above is the effective
breakglass identity.

## Credential Rules

- Do not create or commit service account private keys.
- Use ADC or service account impersonation.
- Review operator IAM bindings every internal release.
- On device loss: revoke local ADC credentials, remove affected IAM bindings,
  disable affected service accounts if needed, and record the incident.
- On offboarding: remove user principals, revoke tokens, review custom claims,
  and rotate any exposed local token files.

## Prod Breakglass Policy

The breakglass service account has no standing destructive or privileged
application roles. Future prod user deletion/export/claims operations require a
separate approval record, temporary IAM binding, execution audit, and binding
removal.
