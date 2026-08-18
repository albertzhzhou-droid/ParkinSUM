# ADR: Trace-first algorithm observability

- Status: accepted
- Date: 2026-08-17
- Scope: algorithms that can change a visible classification, score, rank,
  gate, fallback, identity, or explanation

## Context

ParkinSUM already emitted structured gastric-emptying, absorption-opportunity,
LNAA-pressure, per-dose, and candidate-score traces. The feature UI reduced
most of that evidence to chips and prose. Other result-affecting algorithms had
no common inventory, so a future algorithm could change a result without a
reviewable UI representation.

The app is an educational prototype. Population findings must not be presented
as individually calibrated pharmacokinetics, clinical gastric-emptying
measurement, symptom prediction, or treatment advice.

## Options considered

1. Static educational diagrams. Easy to render, but can disagree with the
   actual runtime path and cannot expose scenario sensitivity.
2. Trace-first observatory. Render the production engine's deterministic trace,
   plus an auditable registry that assigns every result-affecting algorithm a
   visualization type.
3. Full patient-specific PK/PD simulator. Outside the evidence, validation,
   intended-use, and data available to this project.

## Decision

Use option 2.

- Live mechanism charts consume `MechanisticConflictResult` and
  `MechanisticCandidateScore`; there is no duplicate UI-only formula.
- Fixed, non-personal scenario fixtures make visual output replayable.
- `AlgorithmRegistry` is the coverage contract. Every entry declares inputs,
  outputs, user-visible impact, limitation, source path, live-trace status, and
  one visualization kind.
- The observatory renders every registered entry. Tests assert unique IDs,
  valid source paths, complete visualization coverage, UI reachability, and
  scenario sensitivity.
- Visual curves have text summaries and semantics labels. Color is not the
  only carrier of meaning.
- Uncertainty and limitations remain adjacent to scores. Confidence is never
  collapsed into severity.

## Consequences

- Reviewers can inspect the actual component and composite behavior in the app.
- Adding a result-affecting algorithm also requires a registry entry and UI
  representation.
- The registry scope is explicit: import/export plumbing and diagnostics that
  only report existing state are excluded.
- The observatory improves transparency; it does not constitute clinical
  validation.
