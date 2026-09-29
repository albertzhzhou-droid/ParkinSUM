# Bayesian prior, borrowing-conflict, and posterior calibration governance

Date: 2026-08-26  
Scope: deterministic synthetic methodology governance only  
Status: mechanically implemented; scientific, clinical, GCP, and regulatory use blocked

## Outcome

This slice converts the queued Bayesian-methodology research item into a content-addressed, executable synthetic governance package. It keeps prior provenance, external-data suitability, dynamic borrowing, prior-data conflict, computation, posterior decision, frequentist operating characteristics, and independent oracle/adjudication as eight separate lanes. The implementation uses an independently written robust Beta-mixture prior with a weak Beta reference component and an analytically evaluated binomial likelihood. It is not a clinical analysis and is not an implementation of a published EMAP algorithm.

The package retains two external-evidence decisions, ten prospectively locked scenario families, 400,000 deterministic repetitions, five manufactured oracle vectors, and eighteen executable adversarial mutation packages. Raw seeds and commitment salts are excluded from public serialization.

## Source triage and boundaries

| Source | Current status | What it supports here | What it cannot establish |
| --- | --- | --- | --- |
| [FDA, Use of Bayesian Methodology in Clinical Trials (January 2026)](https://www.fda.gov/media/190505/download) | Draft — Not for Implementation; nonbinding | Separate prior/likelihood/posterior definitions; prospective success criteria; external-evidence relevance and quality; static versus dynamic discounting; prior-data conflict; ESS; sensitivity; computation; Bayesian and frequentist operating characteristics | Conformance, an accepted analysis, Bayesian validity, a clinical conclusion, or regulatory acceptance |
| [FDA, Adaptive Designs final guidance (2019)](https://www.fda.gov/media/78495/download) | Final nonbinding guidance | Prospectively fixed simulation, nuisance/conflict grids, Monte Carlo uncertainty, code/seed reproducibility, and frequentist operating-characteristic reporting | Universal calibration, study adequacy, or approval |
| [Li, Chen, and Scott 2016, PMID 27541990](https://pubmed.ncbi.nlm.nih.gov/27541990/) | Primary methods article | Prior-data conflict must be a named simulation dimension; robust borrowing methods require frequentist operating-characteristic comparison | Universal robustness or ParkinSUM validation |
| [Zhang, Pan, and Yuan 2021, PMID 34506959](https://pubmed.ncbi.nlm.nih.gov/34506959/) | Primary methods article | Dynamic borrowing should decline as current and historical data become less congruent; Type-I error and power require simulation | That this synthetic robust-mixture implementation is EMAP or inherits the paper's results |

The FDA draft explicitly says that Type-I error alone is not a complete measure of prior influence. ParkinSUM therefore reports false-positive probability separately from posterior mixture weight and borrowed effective sample size. The draft also requires examining prior-data conflict over a broad effect range, documenting included and excluded external sources, and evaluating prior sensitivity and computation. Those requirements are represented as separate fail-closed fields rather than a single pass badge.

## Locked synthetic contract

- Schema: `parkinsum.credibility-bayesian-borrowing-calibration-package/1`.
- Package version: `2026.08.27-v5`.
- Prior: robust two-component Beta mixture, informative starting weight `0.70`, weak reference `Beta(1,1)`.
- Dynamic discounting: posterior robust-mixture component weight, prospectively capped at `0.80`.
- Maximum prior effective sample size: `40`.
- External eligibility: quality and relevance must each be at least `0.75`, with aligned population, outcome, and estimand.
- Likelihood: synthetic conjugate Beta–Binomial calculation.
- Estimand: synthetic binary-response risk difference.
- Success rule: posterior probability of a positive effect is at least `0.975`.
- Computation: closed-form component updates and a declared normal approximation for the posterior risk difference; no MCMC claim.
- RNG: `parkinsum.xorshift32-box-muller/1`, reproducibility only and not cryptographic.

The included external-control record is synthetic and aligned. A second mismatched record is explicitly excluded but retained, preventing an apparently clean prior from erasing unfavorable evidence-selection decisions.

## Scenario grid and observed operating characteristics

| Scenario | Decision probability | Bias | Approx. coverage | Mean borrowing weight | Mean borrowed ESS |
| --- | ---: | ---: | ---: | ---: | ---: |
| Null, no conflict | 0.0197 | -0.0010 | 0.9609 | 0.7994 | 31.98 |
| Null, mild conflict | 0.0450 | 0.0195 | 0.9466 | 0.7619 | 30.48 |
| Null, severe conflict | 0.0527 | 0.0151 | 0.9236 | 0.2865 | 11.46 |
| Prior misspecification | 0.6907 | -0.0300 | 0.9158 | 0.6006 | 24.02 |
| Likelihood misspecification | 0.7921 | -0.0043 | 0.9037 | 0.7965 | 31.86 |
| Sparse data | 0.6390 | -0.0133 | 0.9733 | 0.7918 | 31.67 |
| Missing at random | 0.8200 | -0.0050 | 0.9642 | 0.7989 | 31.96 |
| Non-adherence | 0.8305 | -0.0480 | 0.8976 | 0.7994 | 31.98 |
| Delayed outcome | 0.8791 | -0.0053 | 0.9671 | 0.7991 | 31.96 |
| Low-quality external data | 0.7959 | -0.0037 | 0.9468 | 0.0000 | 0.00 |

These values are deterministic outputs of a finite synthetic grid. They are useful for regression and governance testing only. They do not imply a calibrated clinical design. In particular, the normal approximation, approximate-binomial generator, fixed binary endpoint, chosen effect sizes, and finite grid do not cover real accrual, censoring, estimand complexity, treatment heterogeneity, safety endpoints, or unknown data-generating processes.

## Fail-closed mutation coverage

The release gate requires detection of prior cherry-picking, hyperparameter switching, external-cohort duplication, population/outcome mismatch, overborrowing, disabled discounting, prior-conflict suppression, posterior-threshold switching, selective posterior reporting, false convergence, seed substitution, model-code drift, post-result scenario calibration, false-positive inflation, power failure, oracle redefinition, future schema, and explicit revocation.

## UI representation

Algorithm Observatory renders:

1. prior provenance and prospective lock;
2. external-data suitability;
3. borrowing weight and effective sample size;
4. no/mild/severe prior-data conflict;
5. closed-form computation and Monte Carlo precision;
6. posterior threshold and decision state;
7. frequentist false-positive probability, power, bias, and coverage; and
8. manufactured oracle plus adjudication.

The FDA draft status is shown directly in the panel. A green mechanical status cannot be read as Bayesian validity, clinical validation, GCP compliance, FDA review, regulatory acceptance, benefit, or safety.

## Next research frontier

The next queue item is multi-source transportability, exchangeability, covariate alignment, and prior-predictive model criticism. It must add an exhaustive source-search ledger, source-specific bias and estimand mapping, leave-one-source-out sensitivity, negative controls, prior predictive checks, alternative ESS definitions, and an independent implementation before any stronger methodology claim can be considered.
