# Adaptive-design operating characteristics and decision-rule calibration

Reviewed: 2026-08-26

Status: implemented as a deterministic synthetic governance fixture and release gate. This is not a clinical-trial design, statistical or clinical validation, GCP evidence, regulatory review, benefit/safety evidence, or medical advice.

## Answer first

The prior randomization/interim firewall established who may receive an assignment or see interim information, but it could not show how the retained decision rule behaves when a trial is repeated under different assumptions. This slice adds a prospectively locked, content-addressed simulation package that inherits the exact two-look timing and efficacy/futility thresholds from the governed interim-boundary plan. It retains 12 scenario families, 700,000 deterministic repetitions, Type-I error, power, bias, interval coverage, sample-size/duration and selection/stopping behavior, Monte Carlo standard errors, five independently restated manufactured decision cases, 17 adversarial mutation families, and seven separate UI/release-report lanes.

## Primary-source evidence map

| Source | Status on 2026-08-26 | What it supports here | What it does not support |
| --- | --- | --- | --- |
| [FDA Adaptive Designs for Clinical Trials of Drugs and Biologics (November 2019)](https://www.fda.gov/media/78495/download) | Final FDA guidance; nonbinding recommendations | Prospectively specified adaptation timing/rules; null and alternative scenario grids; Type-I error, power, expected/minimum/maximum sample size, bias and confidence-interval coverage; simulation precision; readable code and seeds | It does not approve ParkinSUM, validate this normal-approximation fixture, or make a finite grid exhaustive |
| [FDA Complex Innovative Trial Design guidance (December 2020)](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/interacting-fda-complex-innovative-trial-designs-drugs-and-biological-products) | Final FDA guidance; nonbinding recommendations | Early review of complex designs and a reproducible simulation plan with parameter configurations, results, code and seeds | It does not turn a local deterministic gate into regulatory interaction or acceptance |
| [ICH E20 Adaptive Designs for Clinical Trials](https://www.fda.gov/media/188961/download) | Step 2 draft, endorsed 25 June 2025 and under public consultation | Future-oriented terminology and design-governance research | The draft explicitly does not confirm full ICH-party acceptance and does not supersede current regional guidance; it is not treated as implementation authority |
| [FDA Use of Bayesian Methodology in Clinical Trials (January 2026)](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/use-bayesian-methodology-clinical-trials-drug-and-biological-products) | Draft, not for implementation | Defines the next research direction: prior provenance, borrowing, prior-data conflict and posterior decision calibration | It is not implemented by this slice and cannot support a Bayesian or regulatory claim |

FDA 2019 explains why repeated unadjusted looks can inflate Type-I error and recommends evaluating operating characteristics across null-compatible nuisance-parameter scenarios. It identifies Type-I error, power, expected/minimum/maximum sample size, bias and interval coverage as relevant outputs. It also gives 100,000 iterations per Type-I scenario as an example yielding roughly ±0.1 percentage-point 95% precision, while allowing a justified smaller count for other characteristics. ParkinSUM therefore uses 100,000 repetitions for each of two null scenarios and 50,000 for each of ten alternative or stress scenarios, always exposing the resulting Monte Carlo standard error instead of labeling a point estimate exact.

## Implemented contract

- Schema: `parkinsum.credibility-adaptive-design-simulation-package/1`.
- Decision rule: two-look group-sequential synthetic fixture at 50% and 100% information.
- Threshold authority: the exact `InterimBoundaryPlan` retained by the randomization/interim package; current synthetic efficacy Z boundaries are 2.80 and 1.98 and futility Z boundaries are 0.20 and 0.00.
- Identity chain: randomization package, statistical package, runtime configuration, algorithm source bundle, analysis model, decision-rule code, scenario catalog and committed seed manifest.
- Public-secret boundary: raw master seed and commitment salt never enter the public package or release report.
- Scenario families: null normal, null variance grid, alternative normal, boundary effect, heavy tail, correlated endpoints, time trend, delayed outcome, missing at random, non-adherence, sparse data and model misspecification.
- Operating characteristics: success/false-positive probability, efficacy/futility/maximum-sample stopping counts, MCSE, mean estimate, bias, interval coverage, mean sample size, duration fraction, selection probability and failures.
- Manufactured oracle: five hand-restated decisions test early efficacy, early futility, continue/final efficacy, continue/final no-efficacy and exact-boundary equality without calling the simulator's decision branch.

The retained deterministic run produced false-positive estimates of 0.02432 and 0.02416 in the two null scenarios. Their conservative 95% upper bounds remain below the fixture's 0.03 fail-closed envelope. Alternative lower bounds are checked against prospectively declared scenario-specific floors; the smallest current lower bound is the boundary-effect stress scenario rather than being hidden or averaged away. These values are regression evidence for this exact synthetic configuration, not estimates of a real trial or universal guarantees.

## Seven visible lanes

1. Design, code, upstream boundary and seed identity.
2. Prospectively locked scenario coverage and result retention.
3. Repetition count, arithmetic reconciliation and Monte Carlo precision.
4. Null-grid Type-I error envelope and decision-rule drift.
5. Alternative-grid power, bias and interval coverage.
6. Sample-size, duration, selection and stopping behavior.
7. Manufactured decision oracle, history, adjudication and revocation.

The Algorithm Observatory renders all seven lanes, the maximum MCSE, largest null 95% upper bound, smallest alternative 95% lower bound and the governed decision thresholds. It also repeats the synthetic-only boundary in the UI.

## Mutation evidence

The release gate requires 17 failures or holds to be detected: seed substitution; decision-timing drift; adaptation removal; threshold drift; scenario omission; post-lock scenario insertion; Monte Carlo underpower; result suppression; unprespecified result addition; false convergence arithmetic; Type-I inflation; power failure; bias/coverage failure; oracle redefinition; runtime-identity drift; broken prospective chronology; future schema; and explicit revocation. Timing and adaptation removal share one fixture, so the list contains 18 failure mechanisms across 17 executable mutation packages.

## Remaining limitations and next queue item

This is one local normal-approximation engine with one independently restated manufactured-case oracle. It has no external statistical implementation, parallel simulation platform, real enrollment/accrual/censoring data, validated estimator, signed seed custodian, independent statistician, regulated software lifecycle, external review or target-release attestation. The scenario grid is deliberately finite and cannot prove universal calibration.

The next P0 research item is `credibility_bayesian_prior_borrowing_conflict_robustness_and_posterior_decision_calibration_gate`. It must remain separate because Bayesian priors, external-data borrowing and posterior success thresholds introduce failure modes that the current frequentist group-sequential fixture cannot test. Until that queue item is independently implemented and reviewed, ParkinSUM makes no Bayesian-methodology claim.
