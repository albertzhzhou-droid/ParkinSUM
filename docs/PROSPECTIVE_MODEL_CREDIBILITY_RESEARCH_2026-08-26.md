# Prospective model credibility research — 2026-08-26

## Decision

ParkinSUM now treats a prospective credibility plan and a post-study adequacy
decision as two different, versioned records. The repository gate passes only
when the plan is structurally complete, bound to the exact applicability and
configuration identities, and still truthfully blocks study execution and
research-trace promotion while external evidence is missing.

This is an engineering governance adaptation. ParkinSUM does **not** claim FDA
submission readiness, ASME V&V 40 conformance, scientific or clinical
validation, model qualification, regulatory review, external approval, or
fitness for patient-specific decisions.

## Primary-source evidence map

| Source | What it supports | What it does not support |
| --- | --- | --- |
| FDA, *Assessing the Credibility of Computational Modeling and Simulation in Medical Device Submissions* (2023) | A risk-informed framework tied to a question of interest, context of use, model influence, decision consequence, credibility goals, planned activities, prospective adequacy, generated evidence, and a later post-study adequacy assessment. | It does not validate ParkinSUM, choose ParkinSUM's factor gradations, or make repository tests sufficient for a clinical use. |
| FDA / Health Canada / MHRA, *Good Machine Learning Practice for Medical Device Development* (2021) | Training and test datasets should remain appropriately independent, including patient, data-acquisition, and site sources of dependence; testing should be clinically relevant and independent of training data. | ParkinSUM's present mechanistic trace is not an ML medical device. These principles are used only as conservative dataset-governance design input. |
| NIST AI RMF 1.0 Core (2023) | Context, scientific integrity, test-set and metric documentation, repeatable TEVV, uncertainty, independent review, limitations, and lifecycle risk tracking should be explicit. | It is voluntary risk-management guidance, not a certification or proof that ParkinSUM is trustworthy. |
| FDA recognition record for ASME V&V 40-2018 | Credibility should be commensurate with model reliance and the consequence of an incorrect decision; completed V&V evidence must be assessed for the stated use. | Only the public recognition summary was used. The licensed standard was not reviewed and no conformance claim is made. |

Primary links:

- <https://www.fda.gov/regulatory-information/search-fda-guidance-documents/assessing-credibility-computational-modeling-and-simulation-medical-device-submissions>
- <https://www.fda.gov/media/175363/download>
- <https://www.fda.gov/media/153486/download>
- <https://airc.nist.gov/airmf-resources/airmf/5-sec-core/>
- <https://www.accessdata.fda.gov/scripts/cdrh/cfdocs/cfstandards/detail.cfm?standard__identification_no=38534>

## Implemented contract

`parkinsum.prospective-model-credibility-plan/1` binds:

- exact question of interest, context of use, applicability-manifest digest,
  algorithm-configuration digest, release artifact, author, and UTC plan time;
- model influence, wrong-decision consequence, overall interpretation risk,
  affected provider IDs, and affected predicate IDs;
- all ten credibility-factor lanes, each with an explicit target gradation,
  rationale, planned activity, acceptance criterion, observable identity,
  dataset-manifest identity and digest, independence group, applicability
  boundary, reviewer requirement, expiry, failure disposition, execution
  status, and result artifacts;
- a prospective adequacy decision and a separately represented post-study
  adequacy decision; and
- canonical plan identity, deterministic JSON, immutable collections, and
  fail-closed drift checks.

Three repository-engineering lanes are recorded as executed: software quality
assurance, numerical code verification, and calculation verification. Seven
lanes remain held: model form, model inputs, comparator or validation data,
context-of-use applicability, uncertainty quantification, use error, and human
factors. Those holds cannot be hidden by an aggregate score.

The current prospective decision is `blocked`; the post-study decision is
`notAssessed`. Therefore both governed study execution and research-trace
promotion remain blocked even when plan integrity passes.

## Execution follow-through

The repository now includes the synthetic split-attestation and
leakage-mutation gate described in the original research queue. It binds
subject, related-subject, site, acquisition, device, time and source-row
partitions; transformation fit scope; actor access; first result-access time;
and a locked holdout. Cross-split identity, preprocessing, temporal, access and
selective-reporting mutations must be rejected.

The gate remains distinct from the existing calibration-dataset governance
item: that item governs authorization and immutable dataset provenance, while
the execution attestation verifies that a particular synthetic run honored the
declared independence boundary. See
`docs/CREDIBILITY_EVIDENCE_EXECUTION_RESEARCH_2026-08-26.md` for the current
contract, remaining real-data boundary, and next protocol-history research
item.
