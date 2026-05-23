# ParkinSUM Privacy Policy Draft

This draft is for product, privacy, and legal review before public release.

## Overview

ParkinSUM Companion helps users review Parkinson-related medication, meal
timing, food composition, and evidence-backed recommendation information. The
app may process health-related information entered by the user. This policy
draft explains what data may be processed and what operational controls must be
confirmed before launch.

## Data We May Process

In Firebase mode, the app may process:

- Firebase Authentication account identifier.
- Email address if email/password authentication is enabled.
- Profile settings entered in the app.
- Meal records and food selections.
- Medication selections and timing records.
- Active medication ids.
- Clinical decision support audit records.
- Recommendation/rule-trace metadata.
- App state metadata such as onboarding state.

The app also uses shared reference data:

- food catalog records.
- medication catalog records.
- interaction rules.
- CDSS source documents.
- locale/resource text.
- official-source snapshot metadata.

Shared reference data should not contain user-private clinical records.

## Why Data Is Processed

User-specific data is processed to:

- provide meal and medication timing checks.
- preserve user-specific app state.
- generate recommendation explanations.
- maintain auditability of clinical decision support output.
- support account-bound continuity across sessions.

Shared reference data is processed to:

- load official or curated food and medication records.
- evaluate rule-based recommendations.
- show evidence/provenance information.
- support release readiness and rollback.

## Storage and Access

Private user records are intended to be stored under Firestore paths scoped to
the signed-in Firebase uid:

```text
users/{uid}/...
```

Firestore rules are intended to allow only the signed-in owner to read or write
that user's private records. Shared catalog records are readable by signed-in
users and writable only by admin/importer identities.

Before public release, production operators must confirm:

- Firebase project access list.
- enabled authentication providers.
- admin/importer custom-claim holders.
- backup/export location and retention.
- monitoring/logging data collection.
- support contact.

## Sharing

The app should not sell user data. Production operators should not share
user-private clinical records except where required to provide support, comply
with law, or fulfill a user-authorized export.

Any analytics, crash reporting, error monitoring, or support tooling that can
receive user-entered health-related data must be reviewed before it is enabled.

## User Export and Deletion

Users should be able to request:

- export of their private app data.
- deletion of their private app data.
- account deletion where supported.

Operational instructions are maintained in
`docs/firebase_operations_runbook.md`.

P0 implementation status:

- The app now exposes a Privacy & Disclaimer screen from the login page and the
  Firebase account area.
- The operator CLI has a tested stage export path scoped to `users/{uid}`.
- The operator CLI has a tested stage deletion path for `users/{uid}` and,
  when explicitly approved, Firebase Auth account deletion.
- Public requests can be routed through the published support/privacy contact.

## Important Limitations

Backups may retain data for a limited period after deletion. If historical
backups are restored, operators must account for deletion requests and avoid
reintroducing deleted user data into production.

## Contact

Support contact: parkinsumservice@gmail.com

Privacy contact: parkinsumservice@gmail.com

Owner/operator for internal/private prerelease: `zhouzhenghang`.
