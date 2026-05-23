# Security Policy

Report security concerns privately by email:

`parkinsumservice@gmail.com`

Do not open a public issue or pull request containing:

- Personal health information.
- Real medication schedules, symptoms, meals, or patient records.
- Firebase ID tokens, refresh tokens, API credentials, service account keys, or
  local credential file paths.
- Raw operator audit logs.
- User exports, account identifiers, emails, or full Firebase UIDs.

## Public Repository Boundary

This repository is a public prototype showcase. Use synthetic or sample data
only. If you accidentally disclose a secret or private record, revoke or rotate
the exposed credential first, then contact the maintainer.

## Supported Security Review Scope

Security reports may cover:

- Firestore rules and account isolation.
- Public demo boundary bypasses.
- Accidental secret or health-data exposure.
- Operator tooling that could print or retain sensitive data.
- Dependency or build configuration issues.
