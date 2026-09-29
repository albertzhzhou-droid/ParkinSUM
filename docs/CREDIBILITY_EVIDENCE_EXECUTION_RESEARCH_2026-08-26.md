# Credibility-evidence execution and leakage research — 2026-08-26

## Decision

ParkinSUM now distinguishes a declared dataset split from an execution whose
independence was mechanically observed. The release gate uses deterministic
synthetic records and adversarial mutations to verify the structure. It does
not claim that a real dataset, participant population, site, acquisition
protocol, model, or clinical outcome is representative or valid.

The UI and report use separate states: `declared`, `mechanicallyObserved`,
`independentlyReviewed`, `unknown`, `violated`, and `revoked`. The current
fixture is `mechanicallyObserved`; scientific-credibility use remains blocked.

## Primary-source evidence map

| Source | Engineering design input | Boundary |
| --- | --- | --- |
| FDA / Health Canada / MHRA, *Good Machine Learning Practice for Medical Device Development* (2021) | Training and test datasets should be independent, considering participant, data-acquisition, and site sources of dependence. Testing should be independent of training data and reflect relevant conditions. | ParkinSUM's deterministic mechanistic trace is not an ML medical device. The principles are used only as conservative independence architecture. |
| FDA, *Assessing the Credibility of Computational Modeling and Simulation in Medical Device Submissions* (2023) | Credibility activities and evidence should be tied prospectively to the exact question, context of use, model risk, and adequacy decisions. | A synthetic execution cannot establish that the modeled mechanisms are scientifically adequate. |
| NIST AI RMF 1.0 Core (2023) | Scientific-integrity and TEVV considerations, test sets, metrics, uncertainty, repeatable evaluation, independent review, limitations, and lifecycle tracking should be documented. | The voluntary framework is not certification, regulatory review, or proof of trustworthiness. |
| FDA, ICH E6(R3) Good Clinical Practice (2025) | Audit trails, user roles, access, UTC ordering, attributed corrections, traceable transfer, analysis-ready dataset finalization, reliable results, and transparent reporting motivate the next protocol-change ledger. | ParkinSUM does not conduct or claim a regulated clinical trial. These controls are future research-governance inspiration only. |

Primary links:

- <https://www.fda.gov/media/153486/download>
- <https://www.fda.gov/regulatory-information/search-fda-guidance-documents/assessing-credibility-computational-modeling-and-simulation-medical-device-submissions>
- <https://airc.nist.gov/airmf-resources/airmf/5-sec-core/>
- <https://www.fda.gov/regulatory-information/search-fda-guidance-documents/e6r3-good-clinical-practice-gcp>
- <https://www.fda.gov/media/169090/download>

## Implemented execution contract

`parkinsum.credibility-evidence-execution-attestation/1` binds:

- the prospective-plan, applicability-manifest, configuration and complete
  algorithm-source-bundle digests;
- raw and derived dataset manifests, exact partition assignment, transformation
  graph, data cutoff, plan-freeze time and execution environment;
- five explicit roles: fit, tune, calibration, comparator and locked test;
- per-record subject group, related-subject group, site, acquisition, device,
  UTC collection time and source-row digest;
- preprocessing fit scope, target use, future-information use, implementation
  digest and execution time;
- sequenced actor, role, authorization, action, split and UTC access events;
- prospectively planned outcomes, reported outcomes and result artifacts; and
- independent-review fields that remain absent for the current synthetic demo.

The verifier fails closed on cross-split subject, relationship, site,
acquisition, device, or source-row overlap; post-cutoff development records;
target-derived or future-derived features; preprocessing fitted outside the fit
split; access before plan freeze; unauthorized access; missing or reordered
holdout/result access; result-aware plan amendments; missing planned outcomes;
identity drift; and revocation.

The offline gate executes five mutation families: cross-split overlap,
preprocessing leakage, early holdout access, unauthorized access, and selective
outcome omission. Every mutation must be detected for the release gate to pass.

## Remaining execution gap

The present execution contains synthetic identifiers only. It does not provide
participant authorization, de-identification, relatedness resolution, a real
site or device registry, raw-to-feature lineage from an authorized source,
independent custody of a locked holdout, signed reviewer authority, durable
access logs, real clock-attestation, or external reproduction. Those remain
dependencies of calibration-dataset governance and the prospective scientific
protocol.

## Successor upgrade implemented

The separate schema-v1 protocol-amendment, deviation, correction and
result-transparency ledger is now implemented and documented in
`CREDIBILITY_PROTOCOL_TRANSPARENCY_RESEARCH_2026-08-26.md`. It preserves the
initial value plus successor events, binds result visibility to sequence and
UTC time, distinguishes planned and post-hoc outcomes, retains rejected events
and fails closed on history erasure or false prospective relabelling.

The next researched gap is a blinded external-replication capsule and
discrepancy-adjudication gate. Internal deterministic checks are not an
independent reproduction. The future flow must prevent the replication actor
from seeing expected results, preserve both result packages, classify every
discrepancy and retain unresolved dissent without treating agreement as
scientific validation.
