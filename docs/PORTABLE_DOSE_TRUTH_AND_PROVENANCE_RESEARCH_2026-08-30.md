# Portable dose truth, provenance, and privacy projection boundary

Reviewed: 2026-08-30

Status: schema-v3 export and no-write inspection implemented; authenticity,
durable import, and privacy projection remain future work.

## Decision

The portable package may carry dose evidence only if it keeps four meanings
separate:

1. what the user originally entered;
2. what the versioned parser can and cannot interpret;
3. whether the production confirmation and assertion gates allow result use at
   one explicit observation time; and
4. the canonical quantity, which exists only after the combined gate passes.

The schema-v2 dose-truth contract remains embedded in package schema v3. It does not
turn a parse result into a medication fact, a local receipt into a signature,
or a passing checksum into source authenticity. Inspection is a no-write
preview. There is no durable import transaction, migration execution,
last-known-good rollback, issuer, signature, verifier policy, or revocation
service.

## Primary-source boundary map

| Source | Requirement or caution used here | Current ParkinSUM boundary |
| --- | --- | --- |
| [RFC 8785, JSON Canonicalization Scheme](https://www.rfc-editor.org/rfc/rfc8785.html) | Hashing or signing JSON needs an invariant representation. JCS constrains input to I-JSON and specifies ECMAScript primitive serialization, recursive UTF-16 property sorting, and UTF-8 output. | `sorted-key-json-v1` recursively sorts keys, but has no complete JCS/I-JSON conformance suite and is not labelled RFC 8785/JCS. Any future signature must pin and independently test its canonicalization version. |
| [NIST FIPS 180-4](https://csrc.nist.gov/pubs/fips/180-4/upd1/final) | SHA-256 generates a message digest that can detect change after the digest was generated. | Per-file, aggregate, owner, and evidence digests support deterministic binding and mutation detection. They do not encrypt the package, authenticate its writer, establish non-repudiation, or stop an editor from changing content and recomputing every unsigned digest. |
| [FHIR R5 Provenance definitions](https://hl7.org/fhir/R5/provenance-definitions.html) | Provenance identifies target resources, activity/recorded time, responsible agents, source entities, and optional signatures. | Local receipts, assertions, decisions, and audit links are not FHIR Provenance resources. There is no conformant target reference, agent policy, source-entity mapping, or FHIR signature. |
| [FHIR R5 AuditEvent](https://www.hl7.org/fhir/R5/auditevent.html) | AuditEvent records operational, privacy, and security events in terms of who, what, where, when, and why, and is distinct from record provenance. | A local preview finding is not a server-authoritative AuditEvent. Export and preview do not establish an append-only operational audit service. |
| [FHIR R5 Bundle definitions](https://hl7.org/fhir/R5/bundle-definitions.html) | Bundle defines purpose/type, persistent identity, entry/fullUrl rules, resource version relationships, and an optional digital signature. | `parkinsum_user_portable_data_package` is a custom JSON envelope, not a FHIR Bundle. A package id or JSON file inventory cannot be relabelled as Bundle identity or conformance. |
| [W3C Verifiable Credentials Data Model 2.0](https://www.w3.org/TR/vc-data-model-2.0/) | Verifiability of a credential does not imply that its claims are true; a verifier separately evaluates issuer, proof, subject, claims, status, and policy. | The package is not a Verifiable Credential. Even a future valid proof could establish integrity/authenticity only within an explicit trust policy; it could not prove that a dose was taken or is clinically correct. |
| [W3C Verifiable Credential Data Integrity 1.0](https://www.w3.org/TR/vc-data-integrity/) | A proof system requires an identified cryptographic suite, verification material, proof purpose, and verification processing. | The current `signatureStatus` is `unsigned`; there is no Data Integrity proof, proof suite, verification method, purpose, controller authorization, key status, or conformance claim. |
| [NIST SP 800-63C Rev. 4](https://pages.nist.gov/800-63-4/sp800-63c.html) | Pairwise pseudonymous identifiers should contain no identifying information and be difficult to guess; random or secret-keyed derivation is preferred. | The manifest owner capability is random and opaque, but nested dose evidence still contains a stable digest derived from the raw dose-owner scope. The standard is used as privacy-design guidance only; ParkinSUM is not claiming federation or NIST conformance. |

## Two owner scopes

| Scope | Runtime meaning | What is serialized | What it cannot prove |
| --- | --- | --- | --- |
| `userScope` | Effective opaque package-owner capability resolved for the current Firebase or local account/device scope | Kind-bound `SHA-256("parkinsum-portable-owner-v1|" + scopeKind + "|" + userScope)` | It does not verify a nested dose receipt and is not an authentication credential or anonymous identifier. |
| `doseOwnerScope` | Raw authenticated scope against which existing dose receipts, assertions, and decisions were created | The raw value is omitted, but nested evidence retains `SHA-256("parkinsum-dose-owner-scope/1\n" + doseOwnerScope)` | It does not authorize the package for another account and, without a signature/trust policy, does not authenticate an external issuer. |

Generation passes both scopes explicitly. Inspection requires both current
scopes again. The manifest owner comparison and the dose-evidence owner
comparison are independent fail-closed checks; neither may stand in for the
other.

## Schema-v2 dose-truth contract

For each intake, the package retains:

| Layer | Schema-v2 representation | Result-use meaning |
| --- | --- | --- |
| Raw record | `dosageNote` plus nullable structured `dose` fields | Preserved evidence only; null and numeric zero remain distinct. |
| Parseability | Grammar-v2 `doseTruth.parseability`, including raw/normalized text, grammar identity/digest, reason codes, typed expression, local unit identity, and source span | Accepted parsing is necessary but never sufficient for a result. |
| Confirmation evidence | `doseConfirmation.evidenceStatus`, receipt or quarantined invalid-evidence digest | Receipt presence is labelled unverified until the row-bound production coordinator checks owner, raw expression, grammar, structured value, product, record revision, and time. |
| Reconciliation evidence | `medicationReconciliation` assertion/decision envelope or quarantined invalid-evidence digest | The assertion graph independently retains conflicts, stale decisions, retractions, source timing, and held reasons. |
| Combined decision | `doseTruth.confirmationVerification`, `reconciliationVerification`, and `resultUse` | `AdministrationDoseConfirmationCoordinator.evaluateForResultUse` is the authoritative combined gate for this artifact. |
| Canonical output | `doseTruth.canonicalQuantity` | Eligible mass is normalized to `mg` with `value == milligrams`; eligible volume stays `mL` with `milligrams: null`. Every held result has `canonicalQuantity: null`. |

The observation time is the UTC `manifest.createdAt`, copied into each intake's
`doseTruth.observedAtUtc`. Confirmation, assertion, and decision evidence dated
after that instant is held. Because the observation instant is inside each
intake row, changing it changes the embedded-files digest and package id when
the package contains at least one intake.

Inspection reconstructs the intake without collapsing literal zero, re-runs
the same parser and combined production coordinator, and requires the exported
dose-truth object to equal that recomputed object exactly. Editing a row and
then recomputing the package's unsigned SHA-256 values cannot make a stale raw
expression, wrong owner, assertion conflict, future evidence, or other held
state eligible.

Schema v1 is rejected as unsupported and yields only a proposed reviewed
v1-to-v3 migration. There is no frozen v1 validator or migrator. Package schema
v2 is readable through a preview-only reminder-presentation migration. A ready
schema-v2 or schema-v3 preview still changes no durable
record. Durable import requires a separate isolated plan, explicit user
confirmation, atomic commit, last-known-good rollback, crash recovery, and
post-write verification.

## Integrity is not authenticity

The current evidence establishes only local self-consistency:

- lexical and decoded budgets bound parsing;
- closed schema validation rejects missing, unknown, malformed, or future
  fields;
- owner bindings reject a package or nested evidence for the wrong current
  scope;
- SHA-256 binds the embedded files and package id; and
- exact production-gate recomputation prevents a self-resigned row from
  changing its dose-truth meaning.

The package remains unsigned. A party able to construct a different internally
consistent package can recompute all current hashes. There is no independently
controlled signing key, issuer, proof purpose, verifier, trusted time, key
validity interval, rotation, revocation, credential status, transparency log,
or non-repudiation evidence. Future authenticity belongs to the existing
server-authoritative provenance and external medication-assertion trust work;
it must not be inferred from this portable-package slice.

## P1 future work: portable dose-owner privacy projection

Risk statement: local authentication currently derives the raw scope as
`local_<normalized-email>`. The stable, publicly specified dose-owner hash can
therefore be dictionary-tested and correlated across independently generated
packages even though the raw email is absent. This does not expose the
protected random manifest capability, but it prevents an anonymity or
unlinkability claim for nested dose evidence.

Machine-governed queue identity:
`portable_dose_evidence_privacy_projection`.

Priority: P1. Impact 5, risk 5, effort 4; queue score
`(5 + 5) * (6 - 4) = 20`. The effort remains four because this boundary
requires a new portable schema, legacy-chain preservation, protected mapping
or encrypted-original recovery, cross-package fixtures, and rollback review;
it is not only an identifier substitution.

Acceptance boundary:

1. New local accounts use a high-entropy internal account subject key that is
   independent of email, display name, and other guessable login text before a
   dose receipt or assertion identity is created.
2. Legacy email-derived receipts remain explicitly legacy and held, are
   re-confirmed, or pass a reviewed migration that preserves the original
   evidence separately. They are never silently relabelled as newly issued
   high-entropy evidence.
3. A versioned export projection can emit package-scoped, unguessable evidence
   identifiers without exposing the stable internal owner digest. It records
   that it is a projection and does not present projected identifiers as the
   original receipt, assertion, decision, signature, or credential.
4. Same-account verification, cross-device recovery, and durable import use an
   explicit protected mapping or recovery protocol. Missing mapping material,
   wrong account, key invalidation, restore to another device, and schema drift
   fail closed without discarding the original evidence.
5. Fixtures cover offline dictionary candidates, two-package correlation,
   account switching, legacy migration, lost mapping material, wrong keys,
   acknowledgement loss, rollback, and mutation of every projected identity.
   Raw identifiers, candidate digests, and stable internal pseudonyms are
   mechanically absent from the portable bytes.
6. UI and documentation say package-scoped pseudonymous, not anonymous, until
   independent privacy review and target-device evidence support a stronger
   statement.

This projection is a privacy control, not a signature or clinical-evidence
upgrade. It must not change whether the combined dose gate is eligible, and it
must remain separate from future FHIR, W3C VC, or legal-portability conformance
work.
