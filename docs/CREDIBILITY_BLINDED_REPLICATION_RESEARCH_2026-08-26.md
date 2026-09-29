# Blinded replication capsule and discrepancy adjudication research

Reviewed 2026-08-26. Educational/research prototype; synthetic data only. This
document records engineering design inputs. It does not establish external
replication, scientific or clinical validity, model qualification, regulatory
acceptance, clinical benefit, or patient-specific safety.

## Source triage

1. **NIST AI RMF Core and Playbook — primary public risk-management sources.**
   NIST Measure 1.3 calls for internal experts who were not front-line
   developers and/or independent assessors; the Playbook suggests separate
   testing teams and documenting test sets, metrics, tools, processes and
   materials so evaluation can be repeated consistently. Map also asks that
   testing processes enable corroboration by independent evaluators and that
   training/test lineage be traceable.
   - https://airc.nist.gov/airmf-resources/airmf/5-sec-core/
   - https://airc.nist.gov/airmf-resources/playbook/measure/
   - https://airc.nist.gov/airmf-resources/playbook/map/
2. **FDA Digital Health and AI Glossary / GMLP — primary regulator-authored
   design inputs for ML data separation.** FDA states that test data for
   AI-enabled medical products should be independent of training and tuning
   data. ParkinSUM's present core trace is deterministic and mechanistic rather
   than a trained ML medical device, so the rule is used conservatively for
   role and evidence separation, not as a conformance claim.
   - https://www.fda.gov/science-research/artificial-intelligence-and-medical-products/fda-digital-health-and-artificial-intelligence-glossary-educational-resource
   - https://www.fda.gov/medical-devices/software-medical-device-samd/good-machine-learning-practice-medical-device-development-guiding-principles
3. **FDA CM&S credibility guidance — primary regulator guidance for
   mechanistic models.** It describes a risk-informed credibility framework for
   physics-based, mechanistic and first-principles models. This supports binding
   a replication package to an explicit context, exact model implementation and
   planned evidence, while keeping model credibility distinct from software
   repeatability.
   - https://www.fda.gov/regulatory-information/search-fda-guidance-documents/assessing-credibility-computational-modeling-and-simulation-medical-device-submissions

## Design translation

The current slice implements the following bounded engineering controls:

- a versioned content-addressed capsule binds the accepted protocol event,
  execution attestation, locked input manifest, analysis plan, configuration,
  registered source bundle, code, environment, dependency lock, deterministic
  command, output schema, random seed, tolerance policy, creator authority and
  expiry;
- the capsule contains only a salted expected-result commitment, never the
  expected values or raw participant data;
- a separately named and authorized synthetic actor records a complete response
  before the custodian releases expected results;
- comparison retains reported, null, failed and adverse outcomes, and classifies
  code, data, environment, dependency, analysis, protocol, stochastic, clock,
  authorization and unknown discrepancies;
- adjudication is an append-only predecessor chain. Agreement cannot be
  accepted while discrepancies remain; rejection, hold, correction, rerun and
  revocation stay visible;
- eleven deterministic mutations cover result/data leakage, same-actor
  execution, missing authority, early unblinding, environment/dependency drift,
  null suppression, post-result tolerance switching, response/clock/log
  failure, commitment forgery, false agreement, future schema and revocation;
- Algorithm Observatory renders capsule, blinding, independent response,
  environment match, comparison and adjudication as six separate lanes.

## What remains unknown

All actors, clocks, authorities, signatures and inputs in this slice are local
synthetic fixtures. The code does not prove organizational independence,
external custody, raw-data authorization, dataset representativeness, faithful
execution on another machine, qualified personnel, trusted clocks, real key
custody, reproducible operating-system/container images, or independent
scientific review. A matching digest or output is repeatability evidence, not
evidence that the model represents biology or is safe for care.

## Next research-derived gate

The next queued slice is a statistical-analysis, uncertainty and error-control
contract. ICH E9 separates type-I-error choice, sample-size assumptions,
analysis sets, estimation and confidence intervals; ICH E9(R1) requires a clear
estimand and planned sensitivity analyses for assumptions; EMA's current
multiplicity page and guidance address multiple endpoints, subgroups, type I
error, estimation and confidence intervals.

- https://database.ich.org/sites/default/files/E9_Guideline.pdf
- https://database.ich.org/sites/default/files/E9-R1_Step4_Guideline_2019_1203.pdf
- https://www.ema.europa.eu/en/multiplicity-issues-clinical-trials-scientific-guideline

That future gate must preserve the prospective estimand, endpoint hierarchy,
analysis set, intercurrent-event and missing-data strategy, alpha/multiplicity
plan, effect estimate and uncertainty interval, precision/sample-size
assumptions, sensitivity analyses, null/inconclusive/adverse results and every
post-result change. It remains research governance and must not generate a
clinical efficacy claim from synthetic data.
