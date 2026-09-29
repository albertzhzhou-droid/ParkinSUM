# Signed Knowledge-Pack Governance

This page describes the local lifecycle prototype for complete clinical-rule
packages. It documents an engineering safety boundary; it does not approve a
clinical rule or authorize its use in care.

## Package and approval workflow

A schema-v1 `KnowledgePack` binds a complete rule set to its content/version,
the current engine digest, HTTPS source references with pinned revisions, and
an authored synthetic test suite. Every rule needs positive, negative,
missing-input, and boundary cases, at least four distinct input digests, and
explicit expected-result assertions. Submission executes the package suite
against the current engine; a failing suite cannot be submitted.

The Engineering Diagnostics lifecycle page supports importing a package,
saving it as a draft, viewing its lifecycle, and supplying signed approval
envelopes for submission, review, activation, or withdrawal. It can copy the
next exact approval binding for an external signer. It does not create keys,
sign envelopes, or treat a typed name as proof of identity.

Ed25519 approvals bind the package, rules, engine and test-suite digests to the
approval role, decision, subject, issuer, environment, scope, validity window,
sequence, and preceding envelope. A reviewer approval is checked against the
authored envelope and cannot be signed by the author. Review is scoped to each
rule. A publisher approval is required to activate or withdraw a package.
Verification also checks the configured key grants, expiry, revocation, and
the current governance sequence.

## Production resolution

When the production CDSS service has a governance service, it does not merge
database rules or caller-supplied rules into the resolved package. It evaluates
the whole authorized package, reruns its suite, and rechecks the journal state
before persisting a result. A corrupt journal, rejected authorization, failed
suite, or state change during evaluation yields `REQUIRE_REVIEW`; no partial
rule list is used. The exact pinned prototype baseline is permitted only before
the local history has ever activated or withdrawn a managed package. After
managed history exists, an inactive or withdrawn package is held.

The default application policy ships with no trusted approval keys. Managed
packages therefore remain held unless a separately controlled policy is
provided. A test or workbench service without governance configuration keeps
its isolated registry/caller-supplied behavior; that mode is not the production
path.

## Local journal and limits

The schema-v1 journal is append-only through the service API, hash-links event
sequence and payloads, and is paired with a separately stored sticky head
anchor. The store checks concurrent changes and reads back writes. Missing,
truncated, altered, or inconsistent state fails closed. The local anchor can
detect ordinary rollback and torn writes, but simultaneous loss or replacement
of both local journal keys is not detectable. Local storage is not an external
transparency log or trusted timestamp service, and the device clock is not a
trusted authority.

Application sign-in supplies a local mutation check, not verified clinician
identity, licensure, organizational authority, or a clinical approval process.
Source excerpts and passing synthetic cases do not establish that a rule is
correct, applicable, current, or safe for an individual. The lifecycle is
local-only; there is no remote trust registry, key ceremony, external audit
service, clinical validation, or managed-rule activation in the default build.

Related implementation and tests are registered in the
[capability matrix](CAPABILITY_MATRIX.md) and the schema catalog.
