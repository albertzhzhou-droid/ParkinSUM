# Algorithm configuration change impact and requalification research

Reviewed: 2026-08-27

## Product question

How does ParkinSUM now move from “the configuration digest changed” to a
truthful, reviewable answer about what changed, which algorithms and visible
outputs may be affected, what deterministic evidence was rerun, and which
independent verification or context-of-use decisions remain unresolved?

## Primary-source findings

### NASA-STD-7009B: credibility belongs to an intended use and authority

The active NASA modeling-and-simulation standard describes credibility products
across development and use, with project-defined acceptance criteria approved
by delegated technical authority. ParkinSUM therefore must not treat a matching
digest, a passing test, or a small numerical delta as self-approval. The impact
package records exact identities and unresolved reviewer authority separately.

Source: https://standards.nasa.gov/standard/nasa/nasa-std-7009

### FDA software-validation guidance: even local changes need system impact analysis

FDA's General Principles of Software Validation states that a local change can
have global system impact, calls for analysis of the entire system, and ties
regression scope to complexity, safety risk, and independence of review. This
supports field-to-algorithm-to-output traversal plus explicit review obligations,
including unchanged but vulnerable outputs rather than changed outputs alone.

Source: https://www.fda.gov/media/73141/download

### FDA 2026 computer-software assurance: assurance is feature- and risk-specific

The February 2026 final guidance recommends examining the intended use of
individual features, functions, or operations and selecting assurance activity
using a risk-based analysis. It is guidance for production and quality-system
software, not a ParkinSUM regulatory classification. Its useful engineering
lesson is to make obligations selective and explicit instead of declaring that
one undifferentiated green test suite validates every claim.

Source: https://www.fda.gov/regulatory-information/search-fda-guidance-documents/computer-software-assurance-production-and-quality-management-system-software

### W3C PROV constraints: a provenance graph can be present and still invalid

PROV-CONSTRAINTS distinguishes provenance presence from provenance validity.
Unique identities, compatible ordering, type constraints, impossibility
constraints, and rejection of strict-precedence cycles are prerequisites for
safe reasoning. The impact graph therefore keeps unknown, orphaned,
many-to-many, source-only, and missing-replay edges visible and fail-closed.

Source: https://www.w3.org/TR/prov-constraints/

## Implemented product contract

- Two independently pinned configuration SHA-256 identities are verified
  before semantic comparison. A self-declared or circular baseline is rejected.
- Canonical recursive comparison retains paths, before/after values, change
  kinds, semantic aspects, and affected algorithm IDs.
- All 63 registered algorithms have an algorithm-to-output-to-replay-to-UI
  relationship. Missing replay fixtures and source-bundle-only coverage remain
  visible rather than being promoted into complete impact coverage.
- Three deterministic production-engine Observatory scenarios run before and
  after a manufactured gastric-parameter baseline. Every output retains input,
  configuration, source-bundle, platform, and tolerance identities.
- Software quality, code verification, calculation verification, scientific
  validation, human factors, transportability, and context-of-use
  requalification are separate obligations with separate reviewer authorities.
- The current package is deliberately promotion-blocked because all independent
  obligations are unresolved. Green replay is not scientific validation.

## Truth boundary

The prior identity is a manufactured deterministic change-control fixture, not
repository history and not evidence that 85 or 90 minutes is clinically valid.
The matrix demonstrates traceability and change-control behavior. It does not
establish individual gastric emptying, levodopa pharmacokinetics, symptom
prediction, patient benefit, regulatory approval, or medical advice.

A separate research boundary remains: the current relationship graph is
reviewed and explicit, not a mechanically derived transitive result-dependency
closure. See
`docs/ALGORITHM_TRANSITIVE_RESULT_DEPENDENCY_CLOSURE_RESEARCH_2026-09-02.md`.

## Shipped downstream baseline gate

The local `configuration_baseline_registry_and_reviewed_promotion_receipt` is
now implemented. A versioned receipt binds the expected active and candidate
configurations, source bundle, build, impact package, replay artifact,
context-of-use record, obligation matrix, environment, population scope,
expiry and separated reviewer signatures. An append-only hash chain retains
successful and rejected promotion, rollback and revocation attempts; expected
revision and expected active identity provide the compare-and-swap contract.
The real candidate remains inactive because its obligations are unresolved and
it has no independent signatures.

## Next researched upgrade

The next gap is
`configuration_baseline_durable_store_and_transparency_witness`. The shipped
registry is a deterministic local artifact, not a crash-atomic multi-writer
authority or an externally witnessed transparency log. Durable conditional
append, idempotent recovery, independently witnessed checkpoints,
inclusion/consistency proofs, signing-key lifecycle and split-view detection
remain future acceptance criteria rather than current claims.
