# Target-population causal transportability research and synthetic gate

Date: 2026-08-26  
Status: implemented synthetic methodology-governance fixture; package 2026.08.27-v3  
Scope: educational/research prototype; no patient data, clinical calibration,
causal-effect claim, safety claim, GCP claim or regulatory claim

## Decision

ParkinSUM now keeps target-population causal identification separate from the
existing descriptive/Bayesian multi-source suitability package. The new gate
does not award a generic “transportable” score. It freezes an explicit target
contrast and assumptions, diagnoses observed support and weighting behavior,
compares four estimators under manufactured correctness and misspecification,
holds structural non-overlap as non-identifiable, and reproduces the reference
cases with an independently written Python stdlib script.

The gate is a software and methodology-governance check. It cannot prove the
conditional transportability assumption, the absence of unmeasured effect
modification, or the correctness of a model in real data.

## Primary methods reviewed

| Source | Used for | Does not establish |
| --- | --- | --- |
| Cole & Stuart, *Generalizing Evidence From Randomized Clinical Trials to Target Populations: The ACTG 320 Trial* ([PMCID: PMC6289264](https://pmc.ncbi.nlm.nih.gov/articles/PMC6289264/)) | Sampling/participation weighting, explicit trial-versus-target membership and overlap diagnostics | That any ParkinSUM target sample is representative or that the required covariates are sufficient |
| Westreich et al., *Transportability of Trial Results Using Inverse Odds of Sampling Weights* ([DOI: 10.1093/aje/kwx164](https://doi.org/10.1093/aje/kwx164)) | Inverse-odds-of-sampling estimator and explicit selection-score/weight diagnostics | That estimated weights repair structural non-overlap, measurement mismatch or unmeasured modifiers |
| Dahabreh et al., *Generalizing causal inferences from individuals in randomized trials to all trial-eligible individuals* ([arXiv:1709.04589](https://arxiv.org/abs/1709.04589)) | Outcome-regression, inverse-odds and augmented/doubly robust comparison; one-model-correct manufactured cases | That “double robustness” means robust to both models being wrong, or that identification assumptions are empirically proven |
| Lesko et al., *Generalizing Study Results: A Potential Outcomes Perspective* ([PMCID: PMC6049838](https://pmc.ncbi.nlm.nih.gov/articles/PMC6049838/)) | Explicit target population, selection/transport terminology and potential-outcomes identification boundary | A universal terminology mapping or a clinical effect estimate |
| Dahabreh et al., *Sensitivity analysis using bias functions for studies extending inferences from a randomized trial to a target population* ([PMCID: PMC10219839](https://pmc.ncbi.nlm.nih.gov/articles/PMC10219839/)) | Future bias-function sensitivity for violations of conditional exchangeability/transportability | Identification or correction of every unmeasured effect modifier from observed data alone |

No article code, patient data, tables, figures or reported effect estimate is
copied into ParkinSUM. The implementation is an independently constructed
finite synthetic fixture.

## Frozen target-population contract

- Target: `synthetic-trial-eligible-target-v1`.
- Eligibility: the trial and target use the same frozen synthetic baseline
  eligibility definition; membership remains distinct.
- Contrast: `E[Y(1)-Y(0) | S=0] at 28 days`.
- Treatment/version: `synthetic-intervention-a`, version
  `synthetic-intervention-a-v1`.
- Comparator: `synthetic-comparator-v1`.
- Outcome: `synthetic-continuous-outcome-28d`.
- Follow-up: fixed day-28 window.
- Censoring: complete reference fixture; misspecification is a separate stress
  scenario.
- Sampling: a non-nested synthetic randomized trial and separately sampled
  target population.
- Graph: target/trial membership and measured modifiers affect sampling;
  treatment and modifiers affect the synthetic outcome; randomized treatment
  is generated only inside the trial.

Seven assumptions are retained as individual records with diagnostics and a
fail/hold disposition: consistency, no interference, within-trial treatment
exchangeability, treatment positivity, conditional transportability,
selection positivity and cross-sample measurement alignment. The gate treats
the conditional transportability lane as an assumption plus sensitivity
boundary, never as an observed fact.

## Synthetic records and overlap

The retained package contains 260 trial records with randomized treatment and
outcome and 360 target records with baseline covariates only. IDs and roles are
disjoint; any target treatment/outcome value, missing required covariate,
duplicate ID or claim of real patient origin fails the gate.

Six prespecified strata contain trial counts `80, 70, 50, 30, 20, 10` and 60
target records each. This yields:

- trial-participation scores from 0.142857 to 0.571429;
- inverse-odds weights from 0.75 to 6.0;
- 10 influential records under the frozen threshold;
- weighted effective sample size 156.441;
- maximum effect-modifier SMD 0.635525 before weighting and approximately
  `1.41e-15` after weighting;
- no support violation or unknown target covariate in the clean reference
  package.

These values are manufactured diagnostics, not evidence that a future real
target population has adequate positivity.

## Estimators and manufactured double-robustness boundary

The target truth is fixed at 0.18 and the untransported trial contrast at 0.14.
Four estimators are retained: trial-only, outcome regression, inverse odds of
sampling, and augmented inverse odds. The four exact cases are:

| Frozen case | Trial only | Outcome regression | Inverse odds | Augmented inverse odds |
| --- | ---: | ---: | ---: | ---: |
| Both nuisance models correct | 0.14 | 0.18 | 0.18 | 0.18 |
| Sampling model misspecified, outcome model correct | 0.14 | 0.18 | 0.14 | 0.18 |
| Outcome model misspecified, sampling model correct | 0.14 | 0.14 | 0.18 | 0.18 |
| Both nuisance models misspecified | 0.14 | 0.14 | 0.14 | 0.14 |

This construction illustrates the declared one-model-correct property. It is
not evidence that either nuisance model is correct in an application.

Weight-truncation sensitivity remains visible rather than silently selecting a
preferred cap: caps 1.5, 2.0, 4.0 and untruncated produce estimates 0.155556,
0.162667, 0.174118 and 0.18 with effective sample sizes 240.254, 220.357,
183.951 and 156.441 respectively.

## Operating-characteristic scenarios

Seven prospectively frozen families run 10,000 deterministic repetitions each
(70,000 total): both models correct, sampling-model misspecification,
outcome-model misspecification, dual misspecification, rare treatment,
censoring-model misspecification and structural support violation. Every
estimator retains mean, bias, variance, 95% coverage, decision probability and
Monte Carlo standard error.

For the augmented estimator, mean bias is approximately -0.000292, 0.000286
and 0.000270 in the correct, sampling-misspecified and outcome-misspecified
cases. Dual misspecification retains bias -0.039815 and 0.8309 coverage;
censoring misspecification retains bias -0.025316 and 0.9218 coverage. The
structural-support case emits `heldNonidentifiable` with null estimates rather
than an extrapolated number.

These operating results are a finite deterministic Gaussian error construction
around manufactured case means. They are not patient-data simulation, a
published method reproduction, or universal frequentist calibration.

## Independent replication and executable mutations

`tool/independent_target_transportability_oracle.py` uses only the Python
standard library, imports neither ParkinSUM production code nor golden output,
and reproduces the four exact cases to tolerance `1e-12`. Its locked digest is
`c71d6ac79dccba1310901af8a892d06467f7733878437c31402a0fda73419baf`.

The release gate executes 26 adversarial packages covering post-result change,
contract/graph/assumption omission, duplicate or leaked target records,
covariate and synthetic-origin drift, support/unknown-covariate laundering,
weight and balance drift, estimator omission/arithmetic, double-robustness
overclaim, sensitivity/scenario omission, operating-calibration drift,
estimation under non-identifiability, independent-script/result mismatch,
runtime identity, retention, boundary, future schema and revocation.

Algorithm Observatory renders nine independent lanes: identification, overlap,
weighting, outcome modeling, estimator agreement, sensitivity, operating
characteristics, independent replication and unresolved limitations.

## Remaining limitations and research queue

Current evidence does not provide a real target sample, a causal graph reviewed
against target data and domain evidence, sufficient measured effect modifiers,
external code review, regulated-computing evidence or causal/clinical
validation. The next research work therefore remains explicit in the complete
app queue:

1. bias-function global sensitivity and partial-identification bounds for
   unmeasured effect modification;
2. complex-survey design, calibration/raking weights and variance estimation
   when the target sample is not simple random;
3. multiple-trial transport with trial-level heterogeneity, dependency and
   leave-one-trial-out diagnostics.

Each future gate must keep uncertainty, non-identifiability and unresolved
assumptions visible in Algorithm Observatory. None may convert a finite passing
fixture into a statement of causal truth, clinical benefit, safety or
regulatory acceptance.
