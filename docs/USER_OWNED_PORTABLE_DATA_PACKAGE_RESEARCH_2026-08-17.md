# User-owned portable data package: evidence and implementation boundary

Reviewed: 2026-08-30; implementation addendum: 2026-09-23

## Implementation update (2026-09-23)

The active package contract is now schema v4. It adds
`observations.json` for the current loaded local observation snapshot while
keeping the v2 and v3 validators frozen. V2/v3 packages migrate only in the
read-only preview and mark observation history as unavailable in the source
schema; they do not imply that the source history was empty. The export keeps
user-entered notes, values, missingness, source, both timestamps, original
timezone, unit and posture, but replaces the local recorder ID with the
`package_owner` role. The package remains unsigned and unencrypted, and durable
import remains outside this implementation slice.

The contract details below describe the reviewed schema-v3 snapshot that
preceded this addendum. The active shape and migration identities are in the
portable-schema registry and cross-runtime conformance entries of
`config/schema_catalog.json`.

## Decision

ParkinSUM now has an export-and-preview slice for a user-owned portable data
package. It is intentionally smaller than account deletion, backup/restore, or
a complete legal data-portability workflow:

- Settings can generate one readable JSON file from the account-scoped state
  currently loaded by the app plus this-device logging reminders.
- The schema-v3 package has an explicit format identifier, embedded file
  inventory, per-file SHA-256 digests, an aggregate content digest, and an
  unsigned package identifier. Each intake separately preserves raw dose
  evidence, parseability, confirmation and reconciliation evidence, result-use
  eligibility, held reasons, and any eligible canonical quantity.
- A no-write preview verifies the schema, package-owner binding, file
  inventory, digests, record budgets, identifiers, conflicts, and unsupported
  fields. It also re-evaluates every intake with the production combined dose
  result gate against the current dose-owner scope and package observation
  time.
- Frozen v2/v3 validator identities and one reviewed v2-to-v3 transform now form
  a second gate after production nested validation. The preview emits and shows
  a privacy-bounded receipt, and a Dart/Node corpus checks canonical output,
  version drift, duplicate members, unknown/omitted fields, receipt mutation,
  Unicode preservation, and null-versus-zero preservation.
- Schema v3 reminder rows preserve privacy mode, normalized scheduled-copy
  language, locale-decision state, and the source presentation-policy digest.
  Activation capabilities and plugin notification identifiers remain excluded.
  Preview recomputes current-policy match or drift and states that enabled
  source intent still requires explicit target-device consent.
- There is no import commit, account deletion, cloud-only audit enumeration,
  encryption, authenticity signature, or compliance certification.

This is a data-interchange feature. Schema 3 retains the schema-v2 dose-truth
contract and re-runs the production
administration-dose result-use gate to verify the truth state exported for each
intake, but it does not create guidance, change an application record, or feed
an imported value into the gastric-emptying, conflict, ranking, or recommendation
engines.

## Evidence mapping

| Source | Relevant point | Local transfer | Limit retained |
| --- | --- | --- | --- |
| [RFC 8785: JSON Canonicalization Scheme](https://www.rfc-editor.org/rfc/rfc8785.html) | Cryptographic use of JSON needs an invariant representation, including I-JSON input, ECMAScript primitive serialization, UTF-16 property ordering, and UTF-8 output. | Map keys are recursively sorted before hashing. The manifest names this local contract `sorted-key-json-v1`. | This is **not** claimed to implement RFC 8785/JCS; there is no complete I-JSON, ECMAScript number/string serialization, UTF-16 sorting, or independent conformance suite. |
| [NIST FIPS 180-4](https://csrc.nist.gov/pubs/fips/180-4/upd1/final) | Defines SHA-256. | SHA-256 is used for per-file and aggregate mutation detection and domain-separated bindings. | A digest is not encryption, authorization, or authenticity. An attacker who can rewrite a package can recompute unsigned hashes. |
| [UK ICO right-to-data-portability guidance](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/individual-rights/individual-rights/right-to-data-portability/) | Structured, commonly used, machine-readable formats support portability; controllers should consider secure transmission. | JSON is documented, structured, and directly copyable/downloadable; the UI warns that it is sensitive and unencrypted. | This implementation does not assert that its current-snapshot scope satisfies any jurisdiction's complete portability obligation. |
| [Firebase Delete User Data extension](https://firebase.google.com/docs/extensions/official/delete-user-data) | Automated deletion depends on configured user-data locations and has explicit operational limits. | Export is separated from deletion; no “delete everything” button was added without a complete path inventory, recent authentication, failure reporting, and retention contract. | No deletion guarantee or receipt exists in this slice. |
| [Flutter `flutter_secure_storage` 10.3.1](https://pub.dev/packages/flutter_secure_storage) | The package exposes platform-specific protected-storage policies rather than one universal hardware guarantee. | The current owner capability uses a versioned protected envelope, verified read-back, rotation and revocation. `SharedPreferences` is accepted only as one-way legacy migration input. | Platform policy is not hardware-attestation, backup, restore, migration, or key-recovery evidence. |
| [NIST SP 800-63C Rev. 4](https://pages.nist.gov/800-63-4/sp800-63c.html) | Pairwise pseudonymous identifiers should contain no identifying information and be difficult to guess; random or secret-keyed derivation is preferred. | The future portable-evidence projection is queued to use package-local, unguessable identities. | Schema 2 does not meet that target for nested dose evidence: its stable unsalted digest can be linked across packages and a low-entropy local scope can be dictionary-tested. This is a privacy-design transfer, not a claim that ParkinSUM is a federation system or NIST-conformant. |
| [FHIR R5 Provenance](https://hl7.org/fhir/R5/provenance-definitions.html), [AuditEvent](https://www.hl7.org/fhir/R5/auditevent.html), and [Bundle](https://hl7.org/fhir/R5/bundle.html) | Provenance separates target, recorded activity, agents and source entities; AuditEvent records operational/security who-what-where-when-why; Bundle has resource-identity rules and an optional signature. | These fields shape future provenance, audit and signature work. | The current package is not a FHIR Bundle, Provenance or AuditEvent resource and has no standards-based signature. |
| [W3C Verifiable Credentials Data Model 2.0](https://www.w3.org/TR/vc-data-model-2.0/) | Verifiability does not imply that encoded claims are true; issuer, proof, subject, status, claims, and verifier policy remain distinct. | The package keeps byte integrity, evidence meaning, and result eligibility separate. | The package is not a Verifiable Credential or [Data Integrity](https://www.w3.org/TR/vc-data-integrity/) proof and has no issuer/verifier trust policy, proof suite, credential status, key rotation, or revocation contract. |

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

## Package contract (schema 3)

The root is `parkinsum_user_portable_data_package` with `schemaVersion: 3`.
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

Schema v3 retains the schema-v2 distinction between two non-interchangeable
scopes:

- `userScope` is the effective opaque package-owner capability. Only its
  kind-bound digest enters the manifest and package identifier.
- `doseOwnerScope` is the current raw authenticated scope already bound into
  dose receipts, assertions, and decisions. It is used only in memory to
  re-run the production gate and is never serialized directly.

Passing the manifest owner check cannot substitute for passing the dose-owner
check. Conversely, a valid nested dose-owner digest does not authorize a
package for another account or device scope.

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

The local email-derived login scope does not determine the manifest owner
binding and is not exported in raw form. The manifest binding therefore cannot
be reproduced by an email dictionary. That statement does **not** extend to the
nested original dose-evidence chain: confirmation receipts and medication
assertions retain the stable unsalted SHA-256 owner-scope digest needed to
verify their original content-addressed identities. That pseudonym can link
independently exported artifacts, and a low-entropy `local_<email>` scope can be
tested offline. Schema 2 is therefore neither anonymous nor unlinkable. A
separate schema projection must replace or protect the complete receipt →
assertion → graph → decision identity chain before durable cross-device import
or synchronization.

A local package also may not validate after app-data clearing, reinstall,
platform-key invalidation, browser-origin change, or device migration. No
recovery or token-transfer contract exists yet, and target-device
Keychain/Keystore/Web/DPAPI/Secret-Service migration drills remain open.

Records and embedded-file paths are deterministic. Record collections are
sorted by stable id before serialization, map keys are recursively sorted, and
timestamps are normalized to UTC ISO 8601. Digest comparison is therefore
repeatable for the same logical snapshot and observation time. The manifest
`createdAt` scalar is outside the embedded-files digest, but the same instant is
written into every intake `doseTruth.observedAtUtc`; when at least one intake is
present, changing generation time changes the content digest and package id.

### Fidelity rules

- Nullable dose amount/unit/form/route/release fields remain present. Numeric
  zero stays numeric zero and is not collapsed into null.
- Each intake keeps the raw dose fields, grammar-v2 parseability,
  `doseConfirmation` evidence status, medication-reconciliation assertions and
  decisions, confirmation verification, assertion subgate, combined result-use
  gate and sorted hold reasons as separate fields.
- Generation and inspection both call
  `AdministrationDoseConfirmationCoordinator.evaluateForResultUse` with the
  raw dose-owner scope and use `manifest.createdAt` as the artifact as-of time.
  A wrong owner, stale raw expression, parser/grammar/product/row drift,
  unresolved assertion conflict, or future confirmation/assertion/decision
  holds result use.
- An eligible mass is canonicalized to `mg` (`value == milligrams`); an eligible
  volume remains `mL` with `milligrams: null`. A held result always has
  `canonicalQuantity: null`; the original typed value remains in parseability
  and receipt evidence.
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
where isolates are available. After decoding, schema-v3 validation checks
required keys and scalar types, canonical UTC timestamps, finite/nonnegative
numeric domains, status/enum constants, reminder time and weekday ranges,
nutrient missing/value consistency, manifest counts/hash formats, ids, exact
audit-link relationships, record budgets, dose/reconciliation envelope shapes,
and exact recomputation of every row's combined production dose gate. A
self-resigned invalid document therefore remains corrupt rather than becoming
ready.

Schema v2 is accepted only through a reviewed preview migration. Its reminder
rows have no presentation fields, so preview interprets those fields as
`minimal` / English intent and still requires explicit target-device consent;
it does not request permission, schedule, or write. Schema v1 remains
unsupported and returns a proposed v1-to-v3 migration because no frozen v1
validator, migrator, or durable import write exists. A migration proposal is
not migration execution, and preview readiness is not permission to write.

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
- schema-v3 reminder presentation fields, source-policy digest drift, invalid
  privacy/locale/status values, v2 preview defaults, target-consent summary,
  and proof that preview performs no permission request or scheduling;
- concurrent local-capability creation, verified v1 preference migration,
  protected read-back after acknowledgement loss, dropped writes, malformed or
  conflicting state, account isolation, rotation, revocation, and explicit UI
  clearing without logging or exporting the capability;
- desktop missing/same/different targets, a target introduced after the absence
  check, post-check failure, lease expiry, unsafe names, and proof that the sink
  neither overwrites nor deletes the competing path.

## Residual work before “complete portability” or deletion

1. Design a durable import transaction with explicit confirmation, frozen
   historical validators, last-known-good rollback, and crash/fault
   injection. The current preview must remain no-write until that contract is
   implemented and separately authorized.
2. Continue the queued
   `portable_schema_continuous_differential_fuzz_and_corpus_promotion`. Its
   first fixed local slice now has a versioned three-seed/13-partition plan,
   production-matched parser budgets, a non-preemptive post-return elapsed
   threshold, 31 retained synthetic cases covered by one corpus-level privacy
   review, and 47-case Dart production-preview versus independent Node
   disposition/reason/identity agreement. Node independently recomputes source,
   output and receipt identities and matches the retained Dart VM numeric,
   reminder-safety and EOF/node-precedence boundaries; the UI labels the lanes
   as compiled offline scope rather than a recent on-device receipt. The Node
   semantic projection still does not mirror every Dart non-reminder file
   shape, scalar, identifier/reference graph and record budget. It also needs
   cross-runtime replay minimization and privacy-reviewed promotion, a hard-kill
   timeout, dedicated package-byte and pure-node boundary cases, continuous
   coverage-guided execution, allocation telemetry, corpus-growth adequacy and
   historical round trips through every supported desktop, browser and mobile
   release artifact.
   Partition presence is not
   equivalence-class coverage or exhaustive evidence; the new
   `portable_schema_equivalence_class_coverage_and_semantic_mutation_adequacy`
   research item governs that next layer.
3. Add mobile document-provider/share-sheet delivery and user-visible success
   evidence.
4. Enumerate cloud audit/history/storage data behind recent authentication and
   a versioned backend read contract.
5. Add optional encryption with an explicit key-recovery model. If authenticity
   is required, separately pin canonicalization and proof-suite versions,
   signer, issuer, verifier policy, key validity, rotation, revocation, and
   status. Neither SHA-256 nor RFC 8785/JCS alone provides authenticity.
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
12. Run target-device protected-store migration, loss, reinstall, key
    invalidation, backup/restore, cross-device recovery and account-deletion
    cleanup drills. The protected envelope and one-way legacy migration are
    implemented, but they do not prove recoverability or hardware backing.
13. Replace the process-local reminder revision with a durable, cross-isolate
    revision/change feed. Until then, preview freshness cannot synchronously
    observe direct external preference mutation, and immediate read-back does
    not establish crash durability.
14. Define a new portable dose-evidence privacy projection. It must remove or
    protect the stable raw-scope digest and every dependent receipt, assertion,
    graph and decision identity without presenting a projected chain as the
    original credential; add dictionary and cross-package linkage tests before
    enabling durable import or synchronization.
15. Add the target-device reminder import transaction. It must review platform
    capability, effective language and privacy intent, issue fresh target
    activation capabilities, recompute presentation identity, and recover from
    partial install or acknowledgement loss without replaying source IDs.
