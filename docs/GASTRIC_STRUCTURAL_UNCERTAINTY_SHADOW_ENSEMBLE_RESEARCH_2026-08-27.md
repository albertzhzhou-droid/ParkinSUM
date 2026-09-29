# Gastric Structural-Uncertainty Shadow Ensemble Research

Reviewed: 2026-08-27

## Outcome

ParkinSUM now exposes six gastric-emptying structures in the Algorithm Observatory while keeping the production component lag-exponential curve unchanged. Four normalized-retention structures are compared on one compatible axis. The MRI absolute-volume and pellet-retention structures remain visible but are held out because their observables or acquisition modalities do not match the synthetic normalized-retention series.

This is read-only engineering sensitivity analysis. It is not an ensemble predictor, confidence interval, individual gastric-emptying test, plasma levodopa model, symptom prediction, clinical validation, diagnosis, or treatment guidance. No shadow value enters conflict scoring, candidate ranking, recommendation copy, or medication timing.

## Primary-source evidence map

| Source | What was directly observed | What ParkinSUM uses | What it does not establish |
|---|---|---|---|
| [Elashoff, Reedy & Meyer 1982](https://pubmed.ncbi.nlm.nih.gov/7129034/) | A power-exponential family was proposed for quantitative analysis of gastric-emptying curves. | A distinct `R(t)=2^(-(t/T50)^beta)` normalized-retention shadow. | A universally valid parameter set or an individual prediction. |
| [Siegel et al. 1988](https://pubmed.ncbi.nlm.nih.gov/3343018/) | Dual-labelled meals in 24 healthy volunteers were described with `R(t)=1-(1-exp(-k*t))^beta`, with meal-dependent biphasic behavior. | A separate modified power-exponential structure; it is never mislabeled as the Elashoff equation. | Transfer to Parkinson disease, another meal, or a specific person. |
| [Hou et al. 2010](https://pubmed.ncbi.nlm.nih.gov/20649756/) | In 320 retrospective records with four hourly scintigraphic measurements and informative priors, PE/MPE represented time dependence better than a linear model, while lag estimates depended on definition. | Explicit model-form and lag-definition disagreement. | That relative fit identifies one true structure or makes sparse individual fits stable. |
| [Locatelli, Mrhar & Bogataj 2009](https://pubmed.ncbi.nlm.nih.gov/19337822/) | Nineteen individual and three mean fasting pellet profiles were fitted with lag-exponential, Weibull, and five-parameter double-Weibull models; patterns included interruptive emptying. | An observable-held double-Weibull pellet contract and a lower-complexity explicit-lag comparison. | Interchangeability between pellets, ordinary food retention, fed state, or MRI volume. |
| [Bertoli et al. 2023](https://pmc.ncbi.nlm.nih.gov/articles/PMC10078211/) | Serial MRI work used a linear-exponential absolute gastric-volume model that can represent an early secretion-related volume increase. | A separate `V(t)=V0*(1+kappa*t/T)*exp(-t/T)` absolute-volume contract. | Permission to normalize the curve and overlay it as scintigraphic retention. |
| [Raue et al. 2009](https://pubmed.ncbi.nlm.nih.gov/19505944/) | Profile likelihood distinguishes structural and practical non-identifiability caused by model structure or limited/noisy data. | A fit gate requiring adequate sampling, multistart stability, bounded profile likelihood or a conservative condition-number check, held-out prediction, and an independent implementation. | That optimizer convergence or low training error proves identifiable parameters. |
| [FDA computational-model credibility guidance, 2023](https://www.fda.gov/media/154985/download) | Credibility is context-of-use and model-risk dependent and separates code verification, calculation verification, calibration, validation, uncertainty, applicability, and adequacy. | Exact configuration/event identity, production-invariance evidence, explicit context boundaries, and research-only fit disposition. | Regulatory acceptance, clinical validity, or sufficient credibility for a patient-care context of use. |

## Parkinson-disease evidence remains heterogeneous

The biological direction is plausible but not transportable as one deterministic personal curve:

- [Hardoff et al. 2001](https://pubmed.ncbi.nlm.nih.gov/11748735/) reported group-level delay and wide variability across 51 people with Parkinson disease and 22 controls, with treatment/response subgroups behaving differently.
- [Doi et al. 2012](https://pubmed.ncbi.nlm.nih.gov/22632782/) found an association between delayed gastric-emptying breath-test results and later plasma levodopa peaks in 31 treated participants. Association in one cohort does not identify the causal path or calibrate the ParkinSUM curve.
- [Siebner et al. 2022](https://pubmed.ncbi.nlm.nih.gov/35280265/) found no group delay in 15 medicated people with early Parkinson disease versus 15 matched controls and substantial inter-subject variability.

The implementation therefore shows structural disagreement and missing measurement domains instead of selecting a disease-wide “best” curve.

## Implemented contracts

1. Every structure declares formula, measured observable, modality, original/canonical unit, free parameters, parameter authority, evidence IDs, supported domain, and limitation.
2. The report is bound to the same mechanistic event-ledger and algorithm-configuration identities as the production replay.
3. The production profile is hashed before and after the shadow calculation; any mutation fails the report and the release gate.
4. Only observable- and modality-matched trajectories can enter the pairwise disagreement table.
5. Synthetic or production-derived observations can display prior-fixed curves but can never authorize fitting.
6. A non-synthetic research series still needs informative early/late sampling, at least ten multistarts, one stable optimum, identifiability evidence, at least two held-out points, bounded held-out error, and an independent diagnostic implementation.
7. The Algorithm Observatory displays all six structures, including the two held states, so absence of a comparable trajectory is visible rather than silently converted to zero.

## Verification scope

- Deterministic domain and mutation tests cover structure count, formula distinction, bounds, replay identity, production invariance, synthetic-fit rejection, eligible-fit conditions, and every fit-gate mutation.
- A real widget test verifies the chart, six structure cards, observable/modality labels, fit disposition, and non-clinical boundary.
- `npm run gastric:structures` emits a versioned JSON/Markdown artifact and independently evaluates 17 release checks.
- The report schema, source IDs, registry descriptor, configuration identity, and verification gate are release-governed.

Passing these checks demonstrates implementation integrity only. No external participant dataset has been fitted or validated in this worktree.

## Researched next upgrades

### 1. Modality-specific calibration and identifiability benchmark

Acquire governed, de-identified external datasets separately for standardized scintigraphic normalized retention, serial MRI absolute volume, and pellet protocols. Pre-register train/validation splits; run independent optimizers and profile-likelihood diagnostics; compare predictive error and calibration by acquisition schedule, meal, formulation, fed state, site, and population. Promotion must remain impossible without independent review and context-of-use requalification.

### 2. Secretion, sieving, and intermittent-emptying state model

Research a mass/volume state model that separates secretion from caloric-content emptying and a particle-size or dosage-form lane that can represent sieving and intermittent pellet emptying. The model must conserve declared mass-like states, permit MRI volume rise only on the volume observable, and never infer unmeasured particle distribution or secretion from ordinary meal metadata.

Both upgrades are added to `config/complete_app_upgrade_queue.json`; neither is represented as shipped functionality.
