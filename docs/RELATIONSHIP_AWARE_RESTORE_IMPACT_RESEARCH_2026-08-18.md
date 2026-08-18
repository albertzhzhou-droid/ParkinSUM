# Relationship-aware restore impact preview

Date: 2026-08-18
Product boundary: education and research prototype; this work does not make ParkinSUM a medical record, validated clinical model, or regulated decision-support system.

## Decision

ParkinSUM should not treat restoring one meal or intake row as an isolated write. A historical value may change catalog relationships and invalidate current meal checks, recommendation explanations, mechanistic traces, handoff summaries, audit projections, and portable-package relationship links. The history center therefore presents a read-only impact preview before it writes.

The preview is content-addressed and bound to:

- the selected immutable history revision;
- the exact current record digest expected by the compare-and-set boundary;
- a domain-separated digest of the current account scope;
- a versioned relationship-graph contract;
- the exact bytes of every relevant food or medication catalog entry;
- the current algorithm-configuration digest; and
- the added, removed, unresolved, and retained relationships plus derived-output categories.

Confirmation rebuilds the preview from current authoritative state and requires the preview identity to match. Record, account, catalog, relationship, or algorithm drift therefore performs no write. Missing catalog relationships in the state being restored block confirmation rather than producing an incomplete downstream interpretation.

The existing restore transaction remains authoritative: the restored meal or intake and its new immutable restore revision are persisted together. Derived refresh happens only after durable publication. If that refresh fails, the UI reports “record restored; derived refresh incomplete” and does not mislabel the durable write as failed or roll it back.

## Evidence mapping

| Source | Relevant principle | ParkinSUM interpretation | Limit |
|---|---|---|---|
| [Apple Human Interface Guidelines: Undo and redo](https://developer.apple.com/design/human-interface-guidelines/undo-and-redo/) | Help people predict the result of undo/redo and show what changed. | The history center shows the exact target action and affected relationship/derived-output categories before confirmation. | This is interaction guidance, not a data-integrity standard. |
| [W3C PROV-O](https://www.w3.org/TR/prov-o/) | Revisions are derivations; entities can be generated and invalidated by activities. | Restoring creates a new revision. It never rewrites the selected historical evidence, and old derived outputs are treated as invalidated rather than current. | The implementation is PROV-inspired; it does not emit a complete PROV-O graph. |
| [HL7 FHIR R5 Provenance](https://hl7.org/fhir/provenance.html) | Provenance links an activity to version-specific targets, entities, and agents; AuditEvent has a different event-tracking role. | Preview and future lineage work must bind exact versions and keep restoration evidence distinct from operational audit events. | ParkinSUM does not claim FHIR Provenance conformance or EHR status. |
| [Cloud Firestore transactions](https://firebase.google.com/docs/firestore/manage-data/transactions) | Transactions read current state, retry after concurrent changes, and never partially apply writes; client transactions fail offline. | A future durable invalidation ledger needs backend-native expected-revision semantics and must not mutate UI state inside retryable transaction functions. | Current restore adapters atomically commit the record and history revision, but not downstream invalidation intents. |
| [SQLite transactions](https://www.sqlite.org/lang_transaction.html) and [transactional guarantees](https://www.sqlite.org/transactional.html) | A transaction provides a stable snapshot and all-or-nothing durable writes; write contention and error handling remain explicit. | Native restore plus a future lineage/invalidation intent should share one database transaction. | The same guarantee cannot be inferred for every Web or cloud adapter without adapter-specific conformance tests. |

## Open-source pattern review

No upstream code was copied.

- [Joplin’s public revision API](https://github.com/laurent22/joplin/blob/dev/readme/api/references/rest_api.md) models revisions as a distinct item family with parent/item identity, timestamps, metadata differences, and an explicit history deletion endpoint. The useful pattern is separating immutable revision records from the live item. ParkinSUM additionally needs account, catalog, scientific-configuration, and relationship drift checks because restoring a health-related event can alter derived explanations.
- [Automerge](https://github.com/SmartBear/automerge) exposes historical snapshots of a document’s change history. The useful pattern is time-travel as a view over immutable changes. ParkinSUM does not adopt CRDT merge semantics: a clinical-context record restore must remain compare-and-set and fail closed when its current revision differs.
- The reviewed systems focus mainly on document state. Neither pattern by itself proves that downstream scientific output remains valid after restoring an input. ParkinSUM therefore treats the historical record and every derived artifact as different entities.

## What this slice implements

- Deterministic schema-v1 restore-impact preview.
- Byte-equivalent restore versus record-removal prediction.
- Food and medication relationship delta with duplicate elimination and deterministic ordering.
- Missing target relationship block.
- Current account, record, catalog, graph, and algorithm identity binding.
- Pre-confirmation recomputation and stale-preview rejection.
- Explicit derived-output invalidation/recomputation notice.
- Explicit preservation of immutable revision history.
- Separate committed-with-refresh-failure result.
- Accessible modal review with Cancel and explicit Confirm actions.
- Native Chinese, English, French, and Japanese copy for the preview.

## Remaining work

This is not a complete dependency graph. The preview currently enumerates five derived-output categories, not every materialized artifact instance. Recommendation and meal-check state is primarily in memory; handoff and portable packages are generated on demand. No backend currently commits a durable invalidation/re-derivation intent in the same transaction as the restored record.

The new queue item `derived_artifact_lineage_invalidation_ledger` therefore remains research-required. It must add bounded artifact-level lineage, idempotent invalidation and regeneration, backend acknowledgement-loss tests, state labels for current/stale/recomputing/unavailable, retention/deletion semantics, and cross-target conformance. A self-recorded lineage graph would remain engineering provenance only; it would not prove scientific validity, clinician authorship, legal non-repudiation, or regulatory compliance.
