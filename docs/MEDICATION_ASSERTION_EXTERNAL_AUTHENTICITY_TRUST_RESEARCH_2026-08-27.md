# Medication assertion external authenticity and trust research

Reviewed: 2026-08-27

## Decision

ParkinSUM must continue to treat every imported medication assertion as an
untrusted source claim, even when it carries a source name, actor role, content
digest, FHIR-shaped provenance, or a syntactically valid digital signature.
The next interoperability slice needs an explicit verifier result and trust
policy before external evidence can become eligible for any result-affecting
path. The current local conflict graph therefore remains fail-closed.

## Evidence map

### HL7 FHIR R5 Provenance

FHIR R5 describes Provenance as a record-keeping assertion about how a resource
came to be in its current state. It supports multiple provenance records for a
resource/version and includes an optional `signature` element. HL7 states that
the signature can support integrity verification and non-repudiation, and that
the signer should match a Provenance agent. This supports retaining target,
version, agent, activity, recorded time, signature purpose, and verification
material as separate fields. It does not mean that a resource with a
Provenance label is authentic, clinically correct, or trusted by ParkinSUM.

Source:

- https://hl7.org/fhir/R5/provenance.html
- https://hl7.org/fhir/R5/provenance-definitions.html

### HL7 FHIR R5 AuditEvent

FHIR R5 distinguishes AuditEvent from Provenance: AuditEvent records security
and operational events as they occur, while Provenance records the context in
which information was created or transformed. HL7 also notes that audit records
generally should not accept update or delete operations because doing so would
compromise audit integrity. This supports a separate append-only verification
and access-decision ledger rather than rewriting the medication assertion.

Source:

- https://hl7.org/fhir/R5/auditevent.html

### W3C Verifiable Credentials Data Model 2.0

The W3C Recommendation defines issuer, holder, and verifier roles and a model
for tamper-evident claims. Crucially, it leaves the decision about which issuers
to trust, and for which data or purposes, outside the data model. It also warns
that the model does not imply transitive trust. This is the key boundary for
ParkinSUM: successful proof verification is not the same as issuer
authorization, clinical authority, semantic correctness, freshness, or fitness
for a medication algorithm.

Source:

- https://www.w3.org/TR/vc-data-model-2.0/

## Proposed contract

The future `ExternalAssertionVerificationReceipt` should bind:

- the exact assertion and source-artifact digests;
- proof suite and canonicalization identifiers and versions;
- verification key identifier, issuer identifier, verifier identity and
  verification time;
- cryptographic result separately from issuer-policy result;
- permitted purpose, medication-data scope and jurisdiction;
- credential status/revocation evidence and its freshness time;
- key-validity interval, rotation/supersession links and trust-policy digest;
- explicit statuses for unsupported proof, unknown issuer, expired evidence,
  revoked credential, stale status, policy mismatch and verifier error.

The verification receipt must be append-only and content-addressed. Rechecking
after key rotation, revocation-list refresh or trust-policy change appends a new
receipt and makes the prior decision stale; it never edits the assertion or
silently upgrades a source role.

## Required UI

The reconciliation screen should show three independent states:

1. content integrity: whether the exact bytes match the proof;
2. issuer trust: whether the issuer is authorized for this purpose under the
   selected policy and jurisdiction;
3. clinical meaning: still unresolved unless a qualified reconciliation
   workflow establishes it.

Users must be able to inspect issuer, key, proof type, checked-at time, status
freshness, revocation result and policy reason without seeing raw secrets. A
green signature icon alone is prohibited because it collapses these separate
questions into a misleading authenticity claim.

## Verification plan

- deterministic valid, tampered, wrong-key, wrong-issuer and unsupported-suite
  fixtures;
- expired, revoked, stale-status, rotated-key and trust-policy-change fixtures;
- cross-account and cross-environment replay mutations;
- offline behavior that reports `verification unavailable` rather than using a
  cached pass beyond its freshness window;
- append-only AuditEvent-style decision history and recovery tests;
- accessibility and localization tests for every verification state;
- external security review before any external assertion affects results.

## Boundary

This research defines an engineering trust boundary. It does not implement
FHIR, W3C Verifiable Credentials, a certificate authority, a clinical health
information exchange, or medication reconciliation, and it does not validate
the truth or medical relevance of any signed claim.
