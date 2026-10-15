# ParkinSUM Privacy Policy Draft

This draft is for product, privacy, and legal review before public release.
Local data-flow facts below were checked against the active source on
2026-09-29. This update is not store-account approval or a legal conclusion.

## Overview

ParkinSUM Companion helps users review Parkinson-related medication, meal
timing, food composition, and evidence-backed recommendation information. The
app may process health-related information entered by the user. This policy
draft explains what data may be processed and what operational controls must be
confirmed before launch.

## Data We May Process

Local mode can also contain owner-entered health-related records. Public
demonstrations use synthetic data; that does not mean ordinary app records,
exports, drafts or recovery snapshots contain no personal information.

The current local upgrade adds the following storage:

| Local record | Purpose and content | Storage boundary |
| --- | --- | --- |
| Owner-scoped meal input draft | Resume an unfinished entry, including the selected foods, quantity, time, meal title and confirmation state. These can reveal eating or health-related activity. | One draft per owner in local preferences; the key and envelope use an owner digest. The separate synthetic trial uses a memory store. |
| Same-owner Web restore receipt and rollback snapshot | Recover from a scoped merge or undo it while the state is unchanged. The receipt retains original portable-package bytes and the complete prior Web user aggregate, including profile, meal/intake records and revision history. | Stored with the Web user aggregate in browser storage. It includes the local owner identifier; it is not an encrypted vault. Only the last restore receipt is retained, and undo retains its receipt metadata. |
| Evidence-currency candidate review receipts | Retain the comparison time, baseline/candidate reference-evidence snapshots, declared changes and provider dispositions. The current schema does not include meal/intake payloads, but its account association and review activity can still be sensitive. | Local preferences under an owner-digest key, separate from runtime activation. Capacity is bounded and older receipts are not silently evicted. |

These three additions are local-only in the inspected implementation. They do
not add a Firebase upload or a new external destination. Existing Firebase
data flows remain separately declared; this statement does not mean Firebase
mode as a whole is local-only.

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

Normal local app records are persisted using platform-local databases or
preferences; Web user records use browser storage. Meal draft and candidate
receipt owner hashes separate storage lookup keys, and content hashes check
internal consistency. **Neither mechanism encrypts the payload or proves
anonymity, authorization against someone with storage access, or publisher
authenticity.** A predictable owner identifier can remain linkable through a
hash. The protected random portable-owner capability is a separate secret
storage mechanism; it does not encrypt the exported package or restore
snapshot.

The Synthetic meal journey creates an independent in-memory app/service graph
and in-memory draft store. Reset recreates that temporary graph, and leaving
the trial disposes it. Its meal/draft state does not use the normal persistent
user store. Other diagnostics that explicitly save review receipts use their
declared local persistence; they do not inherit the trial's memory-only scope.

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

The new restore flow logs bounded operation stages without its package, owner
or before-state content. This is not a claim that all application, SDK,
operator, build or device logs are free of personal data. Review actual logging
and support exports in their respective scopes; raw logs and user-selected
screenshots cannot inherit the privacy-safe support bundle's allowlist.

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

Current local export/restore scope is narrower than complete app-data recovery.
Portable v4 exports include current profile/preferences, medication selections,
intakes, meals, this-device reminder descriptions and observations. They exclude
care discussions, follow-up outcomes, self-checks, meal drafts and replay or
currency-review receipts. The new Web restore accepts only a same-owner scoped
merge that preserves its file content; nonempty reminder/observation packages,
conflicts and lossy evidence are held. Notification permissions, reminder
activation and AI consent are not imported. Portable packages and retained
restore snapshots are sensitive, unencrypted local data.

Signing out revokes the active session and old draft/restore operations; it is
not a deletion of every locally persisted owner record. Saving/discarding a
draft clears the matching draft. Undoing a restore returns the previous user
state but retains its local receipt and source package. The Firebase stage
deletion drill does not establish deletion of local draft or review archives,
browser storage, user-exported files, or historical backups. Those retention
and deletion paths need their own documented operator/user scope before an
all-data deletion promise is made.

## Important Limitations

Backups may retain data for a limited period after deletion. If historical
backups are restored, operators must account for deletion requests and avoid
reintroducing deleted user data into production.

## Contact

Support contact: parkinsumservice@gmail.com

Privacy contact: parkinsumservice@gmail.com

Owner/operator for internal/private prerelease: `zhouzhenghang`.
