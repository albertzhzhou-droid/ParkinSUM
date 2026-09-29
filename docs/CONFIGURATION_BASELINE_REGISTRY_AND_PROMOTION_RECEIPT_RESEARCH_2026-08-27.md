# Configuration baseline registry and reviewed promotion receipt research

Reviewed: 2026-08-27

## Question

How can a ParkinSUM configuration move from a reviewed candidate to the active
baseline without letting a stale UI, replayed receipt, self-review, partial
write, or rollback erase the decision history?

## Primary-source findings

### NASA-STD-7009B

The active NASA standard requires acceptance criteria to be defined by the
program or project and approved by delegated technical authority. Configuration
activation therefore needs an authority-bearing receipt distinct from model
execution and test results.

Source: https://standards.nasa.gov/standard/nasa/nasa-std-7009

### FDA General Principles of Software Validation

FDA's guidance states that validation status must be re-established after a
change, that local changes can have global impact, and that independent review
is preferable for higher-risk applications. ParkinSUM therefore binds the
change-impact package and all review lanes to the exact candidate receipt and
rejects proposer/reviewer identity collapse.

Source: https://www.fda.gov/media/73141/download

### FDA 2026 Computer Software Assurance guidance

The final 2026 guidance recommends a feature- and intended-use-specific,
risk-based choice of assurance activities. It applies to production and quality
management system software and does not classify ParkinSUM. The relevant design
lesson is that one receipt must preserve which obligations were satisfied,
not-applicable, unresolved, or rejected rather than reducing review to one
boolean.

Source: https://www.fda.gov/regulatory-information/search-fda-guidance-documents/computer-software-assurance-production-and-quality-management-system-software

### W3C PROV constraints

PROV validity requires consistent uniqueness and ordering and rejects invalid
cycles. The registry is therefore an append-only hash chain. Promotion,
rejection, rollback and revocation are new events; rollback moves the active
pointer but never deletes the intervening evidence.

Source: https://www.w3.org/TR/prov-constraints/

## Implemented contract

- A versioned promotion receipt binds the expected active configuration,
  candidate, source bundle, build artifact, semantic impact package, replay,
  context-of-use record, obligation matrix, environment, population scope,
  issue/expiry time and reviewer signatures.
- Seven independent Ed25519 reviewer roles are required for a promotable
  receipt. Unknown keys, altered signatures, self-review and role collapse fail
  closed.
- The transition engine uses both an expected registry revision and expected
  active configuration identity. Revision conflicts, stale pointers, replayed
  receipts, cross-environment reuse and expired receipts become retained failed
  events.
- Rollback is permitted only to a configuration previously active in the same
  verified event chain. The active pointer changes; history is not erased.
- Revocation retains the last-known configuration identity for auditability but
  marks it unusable. Only a newly reviewed activation can restore use; the
  system does not silently fall back to an unreviewed configuration.
- The Observatory renders the exact active/candidate/receipt/registry
  identities, candidate decision, event timeline, scope, obligation states and
  non-clinical boundary.
- The current real package remains inactive: its seven scientific and
  engineering review obligations are unresolved and it has no independent
  signatures. This is deliberate, not a test failure.

## Remaining systems boundary

The shipped local governance contract produces a deterministic content-addressed
registry artifact and a compare-and-swap transition value. It is not yet a
multi-writer, externally witnessed, durable service. A crash between storage
layers, compromised signing ceremony, off-device transparency equivocation, or
lost device recovery requires a separate storage and transparency design. That
work is kept in the upgrade queue rather than implied by the local contract.

## Researched next upgrade

RFC 9162 specifies signed Merkle tree heads plus independently verifiable
inclusion and consistency proofs for Certificate Transparency. Its certificate
scope does not directly govern ParkinSUM. The transferable engineering pattern
is to commit each authoritative registry head to an append-only Merkle log so a
client can test that one decision is included and that a newer checkpoint
extends, rather than rewrites, an older checkpoint.

Source: https://www.rfc-editor.org/rfc/rfc9162

NIST SSDF 1.1 recommends collecting and safeguarding provenance for release
components. This supports binding a deployed artifact to its reviewed source
and configuration identities, but it is software-supply-chain evidence rather
than model credibility or clinical evidence.

Source: https://csrc.nist.gov/pubs/sp/800/218/final

The queued durable-store slice therefore requires crash-atomic conditional
append, idempotency, signed checkpoints, inclusion and consistency proofs,
independent witnesses, key lifecycle controls and UI separation between local
cache, authoritative state and externally witnessed state. Those are future
acceptance criteria, not claims about the current local implementation.
