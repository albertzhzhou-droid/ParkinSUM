# User-owned portable data package: evidence and implementation boundary

Reviewed: 2026-08-17

## Decision

ParkinSUM now has an export-and-preview slice for a user-owned portable data
package. It is intentionally smaller than account deletion, backup/restore, or
a complete legal data-portability workflow:

- Settings can generate one readable JSON file from the account-scoped state
  currently loaded by the app plus this-device logging reminders.
- The package has an explicit format identifier, schema version, embedded file
  inventory, per-file SHA-256 digests, an aggregate content digest, and an
  unsigned package identifier.
- A no-write preview verifies the schema, owner binding, file inventory,
  digests, record budgets, identifiers, conflicts, and unsupported fields.
- There is no import commit, account deletion, cloud-only audit enumeration,
  encryption, authenticity signature, or compliance certification.

This is a data-interchange feature. It does not calculate or modify medication,
meal, gastric-emptying, conflict-engine, or clinical-decision-support results.

## Evidence mapping

| Source | Relevant point | Local transfer | Limit retained |
| --- | --- | --- | --- |
| [RFC 8785: JSON Canonicalization Scheme](https://www.rfc-editor.org/info/rfc8785/) | Cryptographic use of JSON needs deterministic representation. | Map keys are recursively sorted before hashing. The manifest names this local contract `sorted-key-json-v1`. | This is **not** claimed to implement RFC 8785; in particular, no full ECMAScript number-serialization conformance claim is made. |
| [NIST FIPS 180-4](https://csrc.nist.gov/pubs/fips/180-4/upd1/final) | Defines SHA-256. | SHA-256 is used for per-file and aggregate mutation detection and domain-separated bindings. | A digest is not encryption, authorization, or authenticity. An attacker who can rewrite a package can recompute unsigned hashes. |
| [UK ICO right-to-data-portability guidance](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/individual-rights/individual-rights/right-to-data-portability/) | Structured, commonly used, machine-readable formats support portability; controllers should consider secure transmission. | JSON is documented, structured, and directly copyable/downloadable; the UI warns that it is sensitive and unencrypted. | This implementation does not assert that its current-snapshot scope satisfies any jurisdiction's complete portability obligation. |
| [Firebase Delete User Data extension](https://firebase.google.com/docs/extensions/official/delete-user-data) | Automated deletion depends on configured user-data locations and has explicit operational limits. | Export is separated from deletion; no “delete everything” button was added without a complete path inventory, recent authentication, failure reporting, and retention contract. | No deletion guarantee or receipt exists in this slice. |
| [Flutter `shared_preferences` 2.5.5](https://pub.dev/packages/shared_preferences) | The official package warns that asynchronous persistence is not guaranteed after a write returns and that it must not store critical data; the cached API can also diverge across isolates/engine instances. | The current local owner token is labeled a device-cache-bound interim mechanism; malformed/read/write/verification failures stop export rather than rotating silently. | The token is not claimed durable, recoverable, secure-storage-backed, or suitable for cross-device restore. |

Open-source projects were reviewed for product patterns, not copied code:

- [mHabit](https://github.com/friesi23/mhabit) demonstrates that self-hosting,
  explicit backup/restore, and user control can be first-class product
  surfaces.
- [HealthLog](https://github.com/MBombeck/HealthLog) demonstrates a local-first
  health-log export surface.
- [health-md-android](https://github.com/codybontecou/health-md-android)
  demonstrates an explicit platform export action for user health data.
- [Open mHealth Shimmer](https://github.com/openmhealth/shimmer) demonstrates
  the value of normalizing heterogeneous health data into explicit schemas.

Those repositories informed only the product questions: “Can the user see the
boundary?”, “Can the artifact move without the app?”, and “Is schema meaning
explicit?” ParkinSUM's schema and implementation were written locally.

## Package contract (schema 1)

The root is `parkinsum_user_portable_data_package` with `schemaVersion: 1`.
It embeds these logical files:

1. `profile.json`
2. `preferences.json`
3. `medication_selections.json`
4. `intakes.json`
5. `meals.json`
6. `reminders.json`
7. `audit_links.json`

The raw account identifier is never serialized. The manifest owner binding is
`SHA-256("parkinsum-portable-owner-v1|" + scopeKind + "|" +
effectiveOpaqueScope)`. This is a domain-separated, one-way **pseudonymous
binding** used to reject a package in another signed-in account/device scope.
It is not anonymous, encrypted, opaque against all linkage, or a credential.

For Firebase, `effectiveOpaqueScope` is the high-entropy authenticated UID. For
local accounts, it is a random 256-bit token under the mechanically discoverable
`userPortableDataOwnerTokenSchemaVersion: 2` contract. Version 1 stored the raw
capability under the `portable_data_owner_token_v1_` SharedPreferences prefix;
version 2 stores a strict envelope under the
`portable_data_owner_token_v2_` protected-store namespace. A valid v1 value is
accepted only as one-way migration input, written and read back through the
protected adapter, then removed and verified absent. Malformed, conflicting,
dropped-write, or cleanup-mismatch state stops the operation instead of
silently inventing a new identity.

The protected envelope records a random 256-bit capability, random key id,
owner lookup digest, revision, UTC creation/rotation times, and the exact
platform-protection class. The current adapter uses a non-synchronizing
ThisDeviceOnly Data Protection Keychain item on Apple platforms, the package's
RSA-OAEP-wrapped AES-GCM Android mode with silent reset disabled, origin-bound
WebCrypto on secure Web origins, DPAPI on Windows, and Secret Service on Linux.
These are platform-policy statements, not proof that a key is hardware-backed.
The UI exposes protection class and revision and offers explicit local
rotation; it warns that older local-owner bindings will stop validating and
clears the current artifact/preview after a successful rotation.

The local email-derived login scope is used only to derive a one-way lookup key
and never determines or leaves in the exported binding. This prevents a
low-entropy email dictionary from reproducing the artifact binding, but a
local package still may not validate after app-data clearing, reinstall,
platform-key invalidation, browser-origin change, or device migration. No
recovery or token-transfer contract exists yet, and target-device
Keychain/Keystore/Web/DPAPI/Secret-Service migration drills remain open.

Records and embedded-file paths are deterministic. Record collections are
sorted by stable id before serialization, map keys are recursively sorted, and
timestamps are normalized to UTC ISO 8601. Digest comparison is therefore
repeatable for the same logical snapshot and generation time is kept outside
the content digest.

### Fidelity rules

- Nullable dose amount/unit/form/route/release fields remain present. Numeric
  zero stays numeric zero and is not collapsed into null.
- Nutrient snapshots preserve `value`, `unit`, `missing`, the legacy
  compatibility value, and a status. A source-missing nutrient exports null
  even if the compatibility field is zero.
- Medication and food catalog snapshots retain source system/code,
  jurisdiction, basis/preparation/qualifier data, missing nutrient fields, and
  amino-acid provenance where present.
- Medication selections are the union of medications active at export and
  medication ids referenced by retained historical intakes. Each row has an
  `activeAtExport` boolean. This prevents a deselected historical intake from
  producing a dangling or falsely current relationship; its audit relationship
  is `references_medication_selection`.
- Relationship audit links retain stable source/target ids. Cloud-only
  clinical audit documents are explicitly excluded because the current
  cross-backend repository has no complete, consistent read contract for
  them.
- Raw UID, email, legacy `patientId`, credentials, reminder activation tokens,
  and local-AI endpoints are excluded. Tests mechanically scan for sentinel
  values representing each class.

## Fail-closed preview budgets

Preview performs no durable writes. It rejects a package before it can be
reported ready when any of these limits or contracts fail:

| Budget/contract | Limit or behavior |
| --- | --- |
| UTF-8 package size | 32 MiB |
| JSON nesting depth | 24 |
| One string value | 64 KiB UTF-8 |
| One numeric token | 128 source characters |
| Fields in one object | 128 |
| JSON nodes | 500,000 |
| Total records | 175,000 |
| Medication selections | 512 |
| Intakes | 50,000 |
| Meals | 25,000 |
| Reminders | 512 |
| Audit links | 100,000 |
| Stable ids | Unique per record class, at most 256 UTF-8 bytes, ASCII safe-id grammar only |
| Unknown fields | Recursively reported as unsupported schema; never import-ready |
| Duplicate object keys | Rejected lexically, including escape-equivalent keys |
| New schema, owner mismatch, bad checksum | Never import-ready |

The size, depth, object-width, string, numeric-token, duplicate-key, and
500,000-node checks run in a bounded lexical pass **before** full `jsonDecode`,
so a shallow many-node array or very long number cannot force materialization
first. Production inspection is dispatched through Flutter's `compute` worker
where isolates are available. After decoding, schema-v1 validation checks
required keys and scalar types, canonical UTC timestamps, finite/nonnegative
numeric domains, status/enum constants, reminder time and weekday ranges,
nutrient missing/value consistency, manifest counts/hash formats, ids, exact
audit-link relationships, and record budgets. A self-resigned invalid document
therefore remains corrupt rather than becoming ready.

Malformed JSON and unexpected runtime exceptions produce generic findings;
they do not reflect the raw exception, local path, or source text into the UI.
The browser/desktop delivery result is checked separately from generation. If
direct delivery is unsupported or fails, the UI falls back to copying JSON and
does not claim that a new file was confirmed saved. The desktop sink creates no
target or temporary file, so failure handling never deletes by pathname.

## Platform and backend boundary

- Web uses an explicit browser download.
- macOS, Windows, and Linux currently fail closed for new-file publication.
  Pure cross-platform `dart:io` does not expose both an atomic no-replace
  publish and a persistent file-identity witness across reservation and
  publish. Therefore a missing target returns `unsupported` and the UI uses its
  authorized Copy JSON fallback. An already-existing byte-identical file may be
  recognized after a bounded read from an open read-only handle, but the page
  still uses Copy JSON and never presents that as a newly completed save. The
  existing file is never modified or deleted. A different or late-arriving
  target is left untouched.
  Earlier Windows branch simulation was test-seam coverage, not evidence from
  a Windows filesystem, and no cross-platform atomic-save claim is made.
- Android/iOS currently use the universal Copy JSON fallback. A system document
  provider/share sheet is still required before claiming user-visible file
  delivery on mobile.
- Firebase and local mode use the same package service. The page maintains an
  observed account scope and monotonic epoch. Every account transition clears
  generated artifacts, pasted text, preview bindings, reminder ids, and errors
  before the new scope paints. Every awaited owner-token, reminder, inspection,
  paste, copy, and save step rechecks the epoch. Copy/save revalidate the exact
  JSON bytes to be delivered and pass an authorization lease into the clipboard
  or file sink for a check immediately before its side effect.
- Preview state is bound to the SHA-256 of the inspected input, the account
  epoch, a deterministic digest of current medication/intake/meal/reminder
  record ids, and a bounded process-local reminder repository revision.
  Inspection captures current ids and revision both before and after the async
  parser; any change rejects publication. The display getter recomputes the app
  record-id digest, and a revision listener clears the preview immediately when
  any repository instance in this Dart process completes a same-scope reminder
  write whose encoded value passes immediate read-back equality. Editing,
  paste, “Use generated,” account transition, or detected data
  change clears or hides it. Generate-time integrity checking is not shown as
  an import-conflict preview.

The reminder revision is deliberately process-local. It detects
repository-acknowledged writes through `UserLoggingReminderRepository` in the
current Dart process, including another repository instance, after an immediate
exact read-back. This is not proof of critical-data or crash durability. It
cannot synchronously observe another isolate or an external
`SharedPreferences` writer. A future transactional store must provide a durable
cross-process revision/change-feed contract before that stronger claim can be
made.

The package represents current loaded app state. It is not evidence that all
server history, Storage objects, clinical audit documents, backups, or retained
operator data were enumerated.

## Verification implemented

Automated conformance/fault tests cover:

- deterministic output under input reordering and successful self-preview;
- null-versus-zero, timestamp, unit, provenance, and audit-link preservation;
- sentinel scans for UID, email, patient id, activation token, and endpoints;
- wrong owner/kind, checksum tampering, future schema, top-level/deep unknown
  fields, self-resigned scalar/domain violations, malformed structures,
  malformed JSON, duplicate JSON keys, oversized number tokens,
  duplicate/unsafe ids, and every input budget before full decoding;
- a deselected historical-intake medication with an inactive but existing
  selection target;
- conflict reporting without mutation;
- explicit preview binding, oversize paste rejection before controller
  assignment, direct-save failure fallback, and account A to account B clearing
  for import-only state plus delayed paste/copy/save interleavings;
- pending-inspection and post-preview mutations of same-account reminders,
  including the rule that only exact repository read-back advances the
  process-local revision;
- concurrent local-capability creation, verified v1 preference migration,
  protected read-back after acknowledgement loss, dropped writes, malformed or
  conflicting state, account isolation, rotation, revocation, and explicit UI
  clearing without logging or exporting the capability;
- desktop missing/same/different targets, a target introduced after the absence
  check, post-check failure, lease expiry, unsafe names, and proof that the sink
  neither overwrites nor deletes the competing path.

## Residual work before “complete portability” or deletion

1. Design a durable import transaction with explicit confirmation, schema
   migration, last-known-good rollback, and crash/fault injection.
2. Add historical schema fixtures and round-trip tests on every supported
   desktop, browser, and mobile target.
3. Add mobile document-provider/share-sheet delivery and user-visible success
   evidence.
4. Enumerate cloud audit/history/storage data behind recent authentication and
   a versioned backend read contract.
5. Add optional encryption with an explicit key-recovery model; separately add
   signatures if authenticity is required.
6. Add streaming/chunked generation and parsing before raising current budgets.
7. Specify conflict semantics for WebDAV/self-hosted sync before adding it.
8. Treat account/data deletion as a separate recent-authenticated workflow with
   progress, partial-failure recovery, retention disclosures, and a receipt.
9. Replace the page-local authorization lease with a platform/global auth
   barrier if the product requires a formal proof that no account transition
   can occur in the tiny interval between the final synchronous check and the
   operating-system side-effect call.
10. Add a native no-replace atomic publish primitive where supported. The
    current desktop sink intentionally declines all new-file writes until it can
    hold and verify an OS-specific ownership witness through publication.
11. Convert all preview finding text to stable structured codes with complete
    locale coverage. The preview/status container is a semantic live region and
    zh/en product copy is localized, but service findings currently use English
    fallback text for other locales.
12. Move the local owner token from `SharedPreferences` to a transactional,
    security-reviewed durable store with explicit migration, backup/restore,
    cross-device recovery, and account-deletion cleanup semantics. Until then,
    the binding is device-cache-bound and must not be described as recoverable.
13. Replace the process-local reminder revision with a durable, cross-isolate
    revision/change feed. Until then, preview freshness cannot synchronously
    observe direct external preference mutation, and immediate read-back does
    not establish crash durability.
