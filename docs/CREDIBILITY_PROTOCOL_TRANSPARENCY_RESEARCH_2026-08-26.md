# Credibility protocol transparency ledger research — 2026-08-26

## Scope and non-claim boundary

This note maps public research-governance ideas to a deterministic ParkinSUM
engineering control. ParkinSUM is an educational/research prototype operating
on synthetic fixtures. It is not a clinical-trial registry, does not conduct a
regulated clinical investigation, and does not claim GCP implementation,
scientific validation, regulatory acceptance, clinical benefit, or
patient-specific safety.

## Primary-source map

| Source | Design input used here | Boundary retained |
| --- | --- | --- |
| [FDA final ICH E6(R3) guidance](https://www.fda.gov/media/169090/download) | Audit trails should retain the initial entry and subsequent changes; corrections need attribution, justification and supporting source records; workflow actions, roles/access, unambiguous UTC time and analysis-before-dataset-finalization controls should be reviewable. | Clinical-trial good-practice guidance is used only as conservative architecture input. The local synthetic ledger is not evidence of GCP conformance. |
| [ClinicalTrials.gov results definitions](https://clinicaltrials.gov/policy/results-definitions) | Pre-specified and post-hoc outcomes are different categories; unavailable outcome data need an explanation; analysis populations, outcome values and analyses are explicit fields rather than absence interpreted as zero. | ParkinSUM does not submit a study record. The terminology only prevents synthetic planned, post-hoc, unavailable and omitted states from collapsing into one value. |
| [FDA draft protocol-deviation guidance](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/protocol-deviations-clinical-investigations-drugs-biological-products-and-devices) | Consistent classification, importance and reporting of deviations are useful engineering properties. | This is December 2024 draft guidance, not for implementation. No final FDA taxonomy or compliance claim is inferred. |
| [FDA computational-model credibility guidance](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/assessing-credibility-computational-modeling-and-simulation-medical-device-submissions) | Credibility evidence must stay bound to a defined question, context of use, model risk and exact evidence. | ParkinSUM has no submission, qualification, regulator review or real-data credibility package. |
| [NIST AI RMF Core](https://airc.nist.gov/airmf-resources/airmf/5-sec-core/) | Document test sets, methods, results and limitations; independent review can reduce internal bias and conflicts of interest. | Voluntary risk-management guidance is not certification or proof that the mechanistic model is trustworthy. |

## Implemented contract

`parkinsum.credibility-protocol-transparency-ledger/1` now binds:

- the exact prospective credibility plan and evidence-execution attestation;
- applicability manifest, algorithm configuration and registered source-bundle
  identities;
- study, release, analysis-plan, dataset and code identities;
- an append-only predecessor chain for initial protocol, pre-result amendment,
  dataset lock, result publication and attributed correction;
- author, closed actor role, authority, independent reviewer, decision, reason,
  occurrence/observation UTC time, accessed splits, visible result classes,
  affected factors/outcomes and scientific/data/rights/context impacts; and
- separately enumerable planned, reported, post-hoc, withdrawn, not-collected,
  unavailable and omitted outcome states.

The verifier fails closed on unsupported schema or runtime identity, malformed
digests, duplicate/non-contiguous events, broken predecessors, clock replay,
concurrent unresolved plan changes, missing acknowledgement/review, reviewer
disagreement, role escalation, post-result prospective relabelling, erased
result visibility, result-before-lock, correction-history erasure, outcome
contract drift, omission, binding mismatch and revocation. A rejected event is
retained as `held`, while the last independently accepted digest remains
explicit.

The offline release gate exercises eight mutation families. The Algorithm
Observatory renders the event timeline, prospective/result-visibility state,
review decision, last accepted sequence and every outcome category, including
zero-count categories.

## Remaining evidence gap

The current ledger is immutable only inside one synthetic object and generated
report. It has no durable append-only store, signature or key custody, trusted
clock, multi-writer conflict protocol, participant-rights authority, real
dataset lock, independent organization, external result registry, recovery
drill or real result package. It therefore cannot prove that a real execution
was prospective, complete, independently reviewed, representative, valid or
safe.

## Researched next queue item

The next distinct gap is an **independent blinded replication capsule and
discrepancy-adjudication gate**. FDA/Health Canada/MHRA GMLP says test data
should be independent of training data. NIST AI RMF says test sets, metrics and
tools should be documented and that independent review can reduce internal
bias. The current worktree records those identities but the same process still
constructs and verifies the synthetic evidence.

A future capsule should bind the accepted protocol revision, locked input
manifest, code/configuration/environment, deterministic command, expected
output schema and result-visibility policy without revealing expected values
to the replication actor. An independent response should bind actor authority,
received capsule digest, environment, outputs, failures and monotonic/UTC
times. A comparator must preserve both sides, classify code/data/environment/
analysis/protocol discrepancies, require adjudication, and never convert
agreement into scientific validation. Raw participant data must not be bundled
without separate authorization, de-identification and controlled access.
