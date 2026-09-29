# Bayesian Multi-Source Transportability and Model Criticism

Date: 2026-08-26  
Scope: synthetic methodology-governance implementation only

## Why this gate exists

The previous Bayesian package could discount one aligned historical summary when it conflicted with current synthetic data. That did not address a harder failure mode: several apparently independent sources may reuse the same cohort, differ in population or outcome definition, omit effect modifiers, drift over time, or share bias. Pooling them can increase apparent precision while making the analysis less trustworthy.

This gate therefore keeps source discovery, dependency, transportability, exchangeability, bias adjustment, model criticism, operating characteristics, and independent replication separate. A green result means only that the constructed fixture obeyed its locked engineering contract.

## Source triage and claim boundaries

| Source | What it supports here | What it does not support |
| --- | --- | --- |
| [FDA January 2026 Bayesian draft guidance](https://www.fda.gov/media/190505/download) | Prior and likelihood prespecification; external-data relevance and quality; prior-data conflict; sensitivity; computation; reporting; joint Bayesian and frequentist operating characteristics | Regulatory conformance or implementation guidance. It is explicitly **Draft — Not for Implementation** |
| [Kaizer, Koopmeiners, and Hobbs 2018, PMID 29036300](https://pubmed.ncbi.nlm.nih.gov/29036300/) | Source-specific exchangeability rather than one blanket pooling assumption; explicit limits from source design and heterogeneity | That ParkinSUM implements MEM or inherits the paper's empirical results |
| [Schmidli et al. 2014, PMID 25355546](https://pubmed.ncbi.nlm.nih.gov/25355546/) | Robust MAP mixtures, prior-data conflict, and the need to inspect posterior summaries together with frequentist operating characteristics | Universal robustness or applicability to this synthetic fixture |
| [Hupf et al. 2021, PMID 33851441](https://pubmed.ncbi.nlm.nih.gov/33851441/) | Multi-study MAP research and explicit residual model dependence | That this deterministic Beta-Binomial fixture is semiparametric MAP |
| [Talts et al. 2018](https://arxiv.org/abs/1804.06788) | Simulation-based calibration as a check of implementation self-consistency under a generative model | Validation of the scientific model or the real-world data-generating process |
| [Gabry et al. 2019](https://doi.org/10.1111/rssa.12378) | Prior and posterior predictive checks as distinct parts of Bayesian workflow | A single predictive check as proof of model adequacy |
| [Shi, Miao, and Tchetgen Tchetgen 2020, PMID 33996381](https://pubmed.ncbi.nlm.nih.gov/33996381/) | Negative controls require explicit causal and subject-matter assumptions and can expose residual bias | That a null synthetic negative control proves absence of confounding |

No paper code, data, tables, figures, or result values were copied into ParkinSUM. The model and fixtures are independently written, synthetic, and intentionally simpler than the cited methods.

## Locked synthetic contract

- Schema: `parkinsum.credibility-bayesian-multisource-model-criticism-package/1`.
- Package version: `2026.08.27-v4`.
- Seven frozen records cover included, excluded, duplicate, dependent, unavailable, and contradictory dispositions.
- Three sources can borrow after source-specific quality, relevance, completeness, overlap, temporal-drift, missing-covariate, bias-risk, exchangeability, current-data conflict, and dependency penalties.
- Shared dependency groups receive an inverse group-size discount.
- Source-specific bias adjustment subtracts `0.05 × bias-risk score` from the constructed source event rate.
- Total borrowed effective sample size is capped at `40`.
- The source ledger was frozen before the first constructed current result. “Exhaustive” means exhaustive only inside this enumerated synthetic search universe, not an exhaustive real literature or data search.
- Raw participant data, real health records, clinical outcomes, and patient-specific inputs are absent.

## Model criticism retained separately

The package records 12 checks instead of one aggregate pass badge:

- prior predictive mean and tail behavior;
- conjugate simulation-based calibration rank deviation;
- posterior predictive current-rate discrepancy;
- weak, skeptical, and multi-source prior sensitivity;
- pseudo-count, moment-matched, and conservative ESS views;
- one leave-one-source-out result for each included source;
- source-order invariance;
- a constructed negative-control outcome;
- deliberate incompatibility detection.

Observed fixture values include prior mean `0.3134`, prior predictive tail probability `0.00122`, maximum SBC rank-bin deviation `0.1125`, posterior predictive discrepancy `0.00331`, negative-control absolute effect `0.008`, and a total capped ESS of `40`. These are deterministic fixture results, not reference ranges for a real study.

## Operating characteristics

Six prospectively enumerated families run 20,000 repetitions each, for 120,000 total simulations:

| Scenario | Decision probability | MCSE | Bias | Coverage | Mean borrowed ESS |
| --- | ---: | ---: | ---: | ---: | ---: |
| Aligned null | 0.0066 | 0.000573 | -0.00260 | 0.9432 | 28.50 |
| Partial-exchangeability alternative | 0.6407 | 0.003393 | -0.01214 | 0.9467 | 25.20 |
| Temporal-drift null | 0.0096 | 0.000689 | 0.00475 | 0.9366 | 17.60 |
| Hidden-bias null | 0.00955 | 0.000688 | 0.00481 | 0.9331 | 10.48 |
| Dependency alternative | 0.6581 | 0.003354 | -0.00807 | 0.9478 | 25.81 |
| Positivity alternative | 0.61575 | 0.003439 | -0.00762 | 0.9503 | 12.72 |

A finite grid can miss important incompatibilities. The values above do not establish universal error control, power, interval calibration, exchangeability, or transportability.

## Independent implementation

`tool/independent_bayesian_multisource_oracle.py` is a Python standard-library-only restatement. It imports no ParkinSUM production code or golden outputs. The release gate verifies the exact script SHA-256 and compares four manufactured posterior means, including leave-one-out, severe-conflict, and reversed-source-order cases. This is an arithmetic cross-check, not external scientific replication.

## UI and release behavior

Algorithm Observatory renders ten independent lanes:

1. source discovery;
2. dependency;
3. transportability;
4. exchangeability;
5. bias adjustment;
6. prior predictive criticism;
7. posterior predictive criticism;
8. sensitivity and negative controls;
9. computation;
10. independent replication.

The deterministic release gate also executes 22 adversarial mutations, including post-result selection, duplicate inclusion, dependency laundering, positivity and exchangeability overclaims, bias removal, overborrowing, omitted or falsely passed criticism, scenario omission, operating-result drift, false-positive inflation, independent-script drift, future schema, and revocation.

## Remaining limitations and next research frontier

This work still lacks real patient-level covariate harmonization, a real target-population estimand, validated negative controls, propensity or outcome models, causal identification, missing-not-at-random sensitivity, real multi-study heterogeneity estimation, signed source custody, an external statistical organization, real R/Stan/PyMC reproduction, regulated computing evidence, and regulator interaction.

The next queue should therefore separate: (1) target-population causal transport with positivity diagnostics and doubly robust estimation; (2) validated negative-control selection and proximal-bias diagnostics; and (3) real probabilistic-programming cross-engine reproducibility with sampler diagnostics and environment capture. None may upgrade the current methodology-governance result into a clinical or regulatory claim.
