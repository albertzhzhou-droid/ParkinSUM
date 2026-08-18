# Recoverable User Event History: Research and Product Boundary

Date: 2026-08-18
Scope: meal and medication-intake create, update, delete, and restore
Status: engineering recovery feature; not a clinical record, legal audit log, or proof of authorship

## Decision

ParkinSUM should treat a user-visible Undo/history feature as three separate layers:

1. **Current record** — the meal or intake that ordinary timelines and algorithms consume.
2. **Recoverable revision** — an immutable before/after transition used to undo an accidental action without overwriting a newer edit.
3. **Independent provenance or audit evidence** — a future, separately governed layer for actors, authorization, signatures, retention, and external verification.

The current worktree implements layers 1 and 2 for meals and intakes. It does not claim layer 3.

## Primary-source findings

### Provenance is not the same as an Undo stack

HL7 FHIR R5 distinguishes `Provenance`, which describes the activity and agents that created, revised, deleted, or signed a resource version, from `AuditEvent`, which records usage and other activities as events occur. FHIR also notes that version-specific references may be required to identify past versions unambiguously. The ParkinSUM revision envelope borrows only the narrow engineering pattern of immutable version identity; it is not FHIR-conformant and contains no clinician, organization, authorization, or signature claim.

- HL7 FHIR R5 Provenance: https://hl7.org/fhir/provenance.html
- HL7 FHIR R5 AuditEvent: https://www.hl7.org/fhir/R5/auditevent.html
- W3C PROV-O `wasRevisionOf`: https://www.w3.org/TR/prov-o/

### Atomicity must bind the record and its revision

SQLite documents that all changes inside one transaction occur completely or not at all, including across program, operating-system, or power interruption under its supported durability configuration. Cloud Firestore documents that transaction writes are applied only at the end of a successful transaction, transactions may be retried after contention, read operations must precede writes, transaction functions must not mutate application state, and client transactions fail offline. These boundaries justify atomic record-plus-history writes, but they do not prove mobile-device crash durability, offline cloud restore, or multi-device conflict handling without target evidence.

- SQLite transactional guarantee: https://www.sqlite.org/transactional.html
- SQLite transaction semantics: https://www.sqlite.org/lang_transaction.html
- Firestore transactions and batched writes: https://firebase.google.com/docs/firestore/manage-data/transactions
- Firestore serializable isolation: https://firebase.google.com/docs/firestore/transaction-data-contention

### Undo must be predictable and its result visible

Apple's Human Interface Guidelines recommend naming the operation that will be undone, helping people predict the result, and visibly showing the restored outcome. This supports an immediate delete Snackbar plus a reviewable Settings history center. A generic “restore” that silently overwrites a newer state would violate that predictability boundary, so ParkinSUM uses a content-digest compare-and-set and disables stale restore buttons.

- Apple HIG, Undo and redo: https://developer.apple.com/design/human-interface-guidelines/undo-and-redo/
- Flutter `SnackBarAction`: https://api.flutter.dev/flutter/material/SnackBarAction-class.html

## Open-source pattern review

No upstream source code was copied.

| Project | Observed pattern | Transferable lesson | Boundary |
|---|---|---|---|
| Joplin | Previous note versions can be reviewed and restored; retention is configurable and versions synchronize across devices. | Separate current content, historical versions, retention, and restore UI. | Notes are not structured medication or meal events; Joplin's retention/sync implementation and license are not imported. |
| HealthLog | Public project description includes undoable deletion with a 30-day grace period in a self-hosted health timeline. | A grace period and explicit recovery surface are understandable user controls. | Project licensing and backend architecture require separate review; a marketing description is not evidence of ParkinSUM correctness. |
| OpenNutriTracker | Public project description includes undo for the last water entry. | Immediate, localized undo is useful for accidental logging. | Last-action undo alone does not provide durable history or conflict-safe restore. |
| medication-tracker | Public project description includes undo for accidental medication logs and history browsing. | Medication logging benefits from direct forgiveness in the primary journey. | Repository behavior was not treated as a clinical or durability reference. |

Sources:

- Joplin note history: https://joplinapp.org/help/apps/note_history/
- Joplin trash: https://joplinapp.org/help/apps/trash/
- HealthLog: https://github.com/MBombeck/HealthLog
- OpenNutriTracker: https://github.com/simonoppowa/OpenNutriTracker
- medication-tracker: https://github.com/PanagiotisKaraliolios/medication-tracker

## Current implementation truth

- A schema-v1 revision canonically binds operation ID, record type and ID, mutation type, before/after payloads and SHA-256 digests, UTC evidence time, source, and restore lineage.
- In-memory, Web aggregate state, native SQLite, and Firestore adapters compare the current payload digest and commit the new record plus revision atomically within the adapter's available transaction boundary.
- Duplicate operation replay is idempotent only when the current record still equals the revision result.
- Restore creates a new revision. It is allowed only when the current record digest still equals the selected revision's `after` digest; it never overwrites an intervening edit.
- Deleted records leave the current meal/intake collections immediately, so ordinary timelines and model inputs do not consume tombstones.
- Immediate delete Undo and a filterable Settings history center are available.

## Limits that remain open

- Owner scope is enforced by the selected local database or Firestore path, but schema v1 does not repeat an opaque owner binding inside each revision.
- Revision payloads do not yet carry relationship-impact links to recommendation traces, handoff artifacts, catalog identity, or audit bundles.
- Web uses one aggregate SharedPreferences value. This gives one-call publication and local compare-and-set semantics, but the package explicitly does not promise critical-data durability and there is no two-tab transactional coordinator.
- Firestore client transactions fail offline and physical-device/cross-device acknowledgement-loss tests are not complete.
- The Firestore history reader currently exposes only the newest 500 revisions and has no pagination or completeness receipt; this is a bounded recovery view, not a complete export.
- History is not yet included in the portable package, complete cloud export, retention policy, account deletion receipt, encrypted backup, or permanent purge workflow.
- Chinese and English UI strings exist; the remaining shipped locales use the product's English fallback.
- The history is append-style but not cryptographically append-only. A privileged database operator or compromised local process could rewrite it.

## Future upgrade decisions

### Relationship-aware restore impact preview

Before restoring a revision, build a read-only impact graph showing which current meal/intake, recommendation explanation, personal-log handoff, algorithm trace, and exported relationship links would become stale or be re-derived. The preview must bind the selected history ID and current-record digest, and any drift invalidates confirmation. It must not imply that historical algorithm output remains scientifically valid after inputs or code change.

### Tamper-evident history checkpoints

If the product later needs evidence that revisions were not silently rewritten, use a versioned canonical leaf contract plus per-owner append-only checkpoints and independently verifiable consistency proofs. RFC 9162 demonstrates Merkle inclusion and consistency proofs for append-only logs, while also warning that split views require monitoring or gossip. This is only a structural pattern: ParkinSUM must not claim Certificate Transparency conformance, non-repudiation, or clinical authenticity. FHIR signatures similarly require an explicit trust and key-management boundary.

- RFC 9162 Certificate Transparency v2: https://www.rfc-editor.org/rfc/rfc9162.html
- FHIR R5 Provenance signatures and removal: https://hl7.org/fhir/provenance.html
