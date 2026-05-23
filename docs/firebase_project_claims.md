# Firebase Project and Claims Management

This document defines how ParkinSUM should separate Firebase environments and
manage privileged custom claims.

## Environment Project Matrix

Use separate Firebase projects for real dev/stage/prod isolation.

| Environment | Purpose | Suggested project id | Data policy |
| --- | --- | --- | --- |
| dev | developer testing | `parkinsum-companion-dev` | disposable test data only |
| stage | production-like acceptance | `parkinsum-companion-stage` | test users and accepted test snapshots |
| prod | real release | `parkinsum-companion` | production access control and retention |

Current local config includes web Firebase options for `parkinsum-companion-dev`,
`parkinsum-companion-stage`, and `parkinsum-companion`. Dev/stage non-web app
configs are not generated and intentionally fail fast at runtime.

Dev status as of 2026-05-21:

- Firebase project exists: `parkinsum-companion-dev`.
- Firebase Web app exists: `ParkinSUM Companion Dev Web`.
- Web app id: `1:36630731726:web:d9359715300da8fb13299f`.
- Firestore `(default)` database exists.
- `firestore.rules` and `firestore.indexes.json` are deployed to dev.
- Identity Toolkit and Firebase Hosting APIs are enabled.

Stage status as of 2026-05-21:

- Firebase project exists: `parkinsum-companion-stage`.
- Firebase Web app exists: `ParkinSUM Companion Stage Web`.
- Firestore `(default)` database exists in `nam5`.
- `firestore.rules` and `firestore.indexes.json` are deployed to stage.
- Email/password Authentication is enabled for test accounts.
- Stage live rules probe passed with normal user A/B and importer test users.
- Admin test account was added for the P0 stage operator pass.
- Importer/admin claims were granted, live-probed, cleared, token-refreshed, and
  verified as unable to write privileged `app_catalog` paths after removal.
- Hosting is deployed to `https://parkinsum-companion-stage.web.app`.

Prod status as of 2026-05-21:

- Hosting is deployed to `https://parkinsum-companion.web.app`.
- No prod custom claims were granted or removed during the P0 pass.
- No prod Firestore writes or user deletions were performed during the P0 pass.

## Required Firebase Controls

For each environment, record:

- Firebase project id.
- Firestore database id.
- Auth providers enabled.
- Admin users.
- Importer users.
- Hosting target, if used.
- Backup/export owner.
- Monitoring/log review owner.
- Support contact.

## Custom Claims

Firestore rules currently recognize:

- `admin: true`
- `cdssImporter: true`

Use `admin` only for project-level operational users. Use `cdssImporter` for
users or service identities allowed to publish shared catalog/CDSS reference
data.

Do not grant either claim to normal app users.

## Claim Assignment Process

Before granting a claim:

- [ ] Confirm target environment.
- [ ] Confirm Firebase uid.
- [ ] Confirm request owner.
- [ ] Confirm business reason.
- [ ] Confirm expiry/review date.
- [ ] Record approver.

After granting a claim:

- [ ] Ask the user to sign out and sign in again so the token refreshes.
- [ ] Verify the user's ID token contains the intended claim.
- [ ] Verify privileged write behavior in stage before prod.
- [ ] Record timestamp and operator.

## Claim Removal Process

Remove claims when access is no longer required:

- [ ] Confirm Firebase uid.
- [ ] Remove `admin` and/or `cdssImporter`.
- [ ] Revoke refresh tokens if access must end immediately.
- [ ] Verify privileged writes fail after token refresh.
- [ ] Record timestamp and operator.

## Verification Checks

Run these checks before stage/prod publication:

- normal signed-in user can read allowed shared catalog rows.
- normal signed-in user cannot write shared catalog rows.
- importer user can write intended shared catalog rows.
- admin user can perform intended operational writes.
- unauthenticated user cannot read private user data.
- user A cannot read or write user B private data.
- top-level `cdss_tables` remains denied.

Latest stage verification record:

```text
run id: p0_seed_read_20260522
project: parkinsum-companion-stage
user A: liJgCPx8N8UQOler81M7Srkdyd22
user B: Nzr7NygNSLhyrLy7un2hWjA3QwO2
importer: VMJ4iRyaF9MKaQDPAcrOBNDBV6l2
admin: FlETkTgNEWX4RXZ16yME0QJdxuw2
result: PASS
```

Covered behavior:

- unauthenticated private read/write denied.
- user A owner write allowed.
- user A read/write user B denied.
- normal signed-in catalog read allowed after seed upload.
- normal signed-in catalog write denied.
- importer/admin catalog write allowed before claim removal.
- importer/admin catalog write denied after claim removal and token refresh.
- top-level `cdss_tables` denied.
- unknown collection denied by fallback rule.

## Operational Notes

- Firebase Web API keys are not secrets, but project access and privileged
  service credentials are sensitive.
- Never commit service account private keys.
- Prefer short-lived operator sessions and documented claim grants.
- Keep prod claim grants small and reviewed before each release.
- Keep real patient/private records under `users/{uid}` paths only.
