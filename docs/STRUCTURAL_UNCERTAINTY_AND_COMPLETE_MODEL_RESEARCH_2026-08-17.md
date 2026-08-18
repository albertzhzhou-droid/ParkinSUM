# Structural uncertainty and complete-model research

Reviewed: 2026-08-17

Status: architecture and research queue only

## Boundary

This review does not validate ParkinSUM clinically and does not justify a
patient-specific gastric-emptying estimate, levodopa concentration, motor
response prediction, dose change, meal-timing instruction, or protein target.
It maps model structures, evidence layers, provenance requirements, and
reproducibility controls for an education-and-research prototype.

The proposed alternatives are **read-only shadow models** until their intended
observable, parameterization, and calibration data are separately justified.
Agreement among shadow models is not accuracy. Disagreement is model-form
sensitivity, not a confidence interval.

## Evidence method

Only primary papers, regulator guidance, and official project repositories or
documentation were used. A citation supports only the layer actually measured
by that source. Architecture patterns from open-source projects are
concept-level transfers unless a separately recorded license review authorizes
code, model, or data reuse.

The source-access registry records the primary structural sources as
`src.elashoff.gastric.powerexp.1982`, `src.siegel.gastric.biphasic.1988`,
`src.hou.gastric.modelcomparison.2010`, `src.burmen.gastric.pellets.2009`, and
`src.bertoli.gastric.linearexp.2023`; the levodopa model sources as
`src.guebila.levodopa.pbpk.2016` and `src.simon.levodopa.pkpd.2016`; and the
governance-only sources as `src.ema.pbpk.reporting.guideline` and
`src.fda.cms.credibility.guidance`. Every one remains documentation-only and
not allowed for production.

## Gastric-emptying model families are not interchangeable

Let `R(t)` denote normalized meal or tracer retention and `V(t)` denote an
absolute measured gastric volume. The distinction is part of the model type,
not a display preference.

| Family | Representative form | Observable and useful role | Free-parameter / identifiability cautions |
| --- | --- | --- | --- |
| Current lag-shifted monoexponential | `R(t)=1` before `t_lag`; `R(t)=exp[-k(t-t_lag)]` after it | Small, transparent baseline for a normalized retention shadow | The kink is a modeling assumption. Sparse data can trade off `t_lag` against `k`; it cannot represent multiple emptying phases. |
| Elashoff power exponential | `R(t)=2^[-(t/t50)^beta]`, equivalently `exp[-ln(2)*(t/t50)^beta]` | Empirical normalized retention curve parameterized so `R(t50)=0.5`; `beta` changes early-versus-late shape | Elashoff is the canonical power-exponential lineage, not an independent extra family. A rate-form `exp[-(k*t)^beta]` is equivalent only after declaring the reparameterization `k=ln(2)^(1/beta)/t50`; `t50` and `beta` require informative early and late observations and can be strongly correlated. |
| Modified power exponential | `R(t)=1-(1-exp[-k t])^beta` | Siegel et al. used it to represent a solid-meal lag followed by an emptying phase | Healthy-volunteer, meal-specific evidence does not establish a universal individual curve. Formula identity must be recorded because it is not interchangeable with the Elashoff form. |
| Linear-exponential | `V(t)=V0(1+kappa*t/t_empty)*exp[-t/t_empty]` | Absolute MRI volume where early secretion can increase observed volume before emptying dominates | It must not be applied blindly to a normalized tracer-retention state. `V0`, secretion shape, and emptying time need measurements that contain the early-volume rise and late decay. |
| Double-Weibull / dual-phase | Weighted sum of two Weibull components | Flexible description of interrupted or multi-phase pellet emptying | A typical five-parameter form can fit patterns that a two-parameter curve cannot, but sparse observations make it especially vulnerable to non-identifiability and overfit. |
| Explicit bolus, linear, no-emptying interval, or two-phase alternatives | Piecewise structures selected before fitting | Useful falsification candidates when a smooth one-phase curve is structurally wrong | More change points or phases add parameters and discontinuities; they require temporal resolution around each phase, not only a better aggregate fit statistic. |

Primary evidence and limits:

- [Elashoff, Reedy, and Meyer (1982)](https://www.sciencedirect.com/science/article/pii/S0016508582801455)
  proposed nonlinear least-squares comparison and the power-exponential model.
  It is a methods paper, not evidence that one parameter set transports to a
  particular ParkinSUM user. The `t50` parameterization above is also stated
  explicitly in a later open nonlinear mixed-effects implementation
  ([Gajewska-Knapik et al.](https://pmc.ncbi.nlm.nih.gov/articles/PMC3608145/));
  that implementation supports formula identity, not universal calibration.
- [Siegel et al. (1988)](https://pubmed.ncbi.nlm.nih.gov/3343018/) studied a
  dual-labelled solid/liquid meal in 24 healthy volunteers and described a
  biphasic solid-emptying pattern with a modified power-exponential fit. Its
  sample and meal do not establish disease-, meal-, or person-level validity.
- [Hou et al. (2010)](https://pubmed.ncbi.nlm.nih.gov/20649756/) compared four
  models using retrospective scintigraphic records with hourly observations
  and informative priors. The work supports treating model choice and lag
  definitions as uncertain; it does not provide a universal structure or an
  individual identifiability guarantee.
- [Bürmen et al. (2009)](https://pubmed.ncbi.nlm.nih.gov/19337822/) compared
  lag-exponential, Weibull, and double-Weibull descriptions for fasting pellet
  profiles. The more flexible model described interrupted profiles better in
  that setting, but the pellet/fasting context and added parameters limit
  transfer.
- [Bertoli et al. (2023)](https://pmc.ncbi.nlm.nih.gov/articles/PMC10078211/)
  used a linear-exponential form for MRI-measured absolute gastric volume,
  including an early secretion-related increase. This is direct evidence that
  the measurement state must travel with the formula; it is not a license to
  reinterpret a normalized retention curve as volume.
- A later [stochastic gastric-emptying methods paper](https://pmc.ncbi.nlm.nih.gov/articles/PMC4825969/)
  summarizes exponential, power-exponential, double-power-exponential,
  linear-exponential, and modified-power-exponential families while motivating
  discrete emptying events. That supports structural alternatives, not a
  patient-specific stochastic parameterization.

### Identifiability gate

“The optimizer converged” is not an identifiability result. Before any model is
fit rather than run with literature-fixed shadow parameters, all of the
following must be true:

1. The measured observable matches the model state: absolute volume,
   normalized solid retention, normalized liquid retention, dosage-form
   transit, and plasma concentration are not substitutes.
2. Unique informative observations exceed the number of free parameters. This
   is necessary, not sufficient. The sampling window must cover any early
   secretion/lag behavior, the main emptying phase, and the late tail implicated
   by the chosen structure.
3. Dose/formulation, meal composition and state, disease context, measurement
   modality, units, censoring, missingness, and observation times are recorded.
4. Multiple initializations plus profile-likelihood, posterior, or equivalent
   parameter diagnostics expose flat, multimodal, boundary, and highly
   correlated solutions. Condition number and shrinkage are recorded when a
   population model supplies them.
5. Prediction stability is checked under held-out subjects or sites and under
   leave-timepoint-out perturbations. AIC, residual fit, or visual agreement on
   the calibration records alone is insufficient.
6. Failure of any gate leaves the structure literature-fixed and read-only, or
   unavailable. The UI must say why no individual parameter estimate exists.

These are conservative engineering gates inferred from the measurement and
parameter demands of the cited studies; they are not a claim that any single
diagnostic proves biological identifiability.

## Levodopa evidence must remain layered

The future model should preserve this chain rather than collapse it into a
single “absorption” coefficient:

```text
meal / formulation event
  -> gastric state and dosage-form transit
  -> dissolution and intestinal input
  -> plasma levodopa PK
  -> blood-brain-barrier competition with large neutral amino acids
  -> effect-site exposure / pharmacodynamics
  -> measured motor endpoint
```

| Evidence layer | What an eligible study may support | What it cannot support alone |
| --- | --- | --- |
| Gastric measurement | Association between an observed emptying/transit measure and later exposure timing in its population and protocol | Intestinal bioavailability, brain exposure, motor benefit, or a universal meal coefficient |
| Fed/formulation PK | Formulation- and population-specific changes in `Cmax`, `Tmax`, AUC, or variability under the studied meal | A general protein effect, gastric mechanism attribution, or patient-specific prediction |
| PBPK | Explicit compartments, mass balance, hypotheses about parameter-to-exposure pathways, and sensitivity analysis | Intended-use credibility without qualified inputs, calibration/validation data, uncertainty analysis, and context-of-use evidence |
| LNAA competition | A transport mechanism or measured plasma amino-acid/exposure relation in the studied design | Gastric-emptying kinetics or a meal recommendation |
| PK/PD | A population- and endpoint-specific relation between exposure/effect-site state and observed response | Clinical benefit or transportability outside the selected formulation, disease stage, dose, endpoint, and observation design |

[Ben Guebila and Thiele (2016)](https://www.nature.com/articles/npjsba201613)
connected a 42-ODE PBPK model with constraint-based analysis and reported 243
parameters. Some kinetic parameters were fit to averaged fasting plasma data
from 24 healthy volunteers receiving one levodopa/benserazide regimen. This is a
useful mechanistic and reproducibility precedent, but it does not validate
ParkinSUM, an individual with Parkinson disease, a fed state, another
formulation, brain exposure, or a motor endpoint.

[Crevoisier et al. (2003)](https://pubmed.ncbi.nlm.nih.gov/12551706/) reported a
fed-versus-fasted crossover for a specific dual-release levodopa/benserazide
product in 19 healthy volunteers. It supports formulation-specific food-effect
evidence, not a universal gastric, protein, or clinical-response coefficient.

[Simon et al. (2016)](https://pubmed.ncbi.nlm.nih.gov/26936272/) estimated a
population PK/effect-site model in 30 selected patients with Parkinson disease
and peak-dose dyskinesia. Its variability estimates and endpoint are useful for
showing why population and parameter uncertainty must be explicit; they are not
transportable individual predictions.

The [EMA PBPK reporting guideline](https://www.ema.europa.eu/en/reporting-physiologically-based-pharmacokinetic-pbpk-modelling-simulation-scientific-guideline)
requires the platform, intended purpose, assumptions, input plausibility,
uncertainty, and predictive performance to be reported. The
[FDA model-credibility guidance](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/assessing-credibility-computational-modeling-and-simulation-medical-device-submissions)
uses a risk-informed context-of-use approach. These are governance boundaries,
not endorsements of this prototype or evidence of clinical effectiveness.

### Minimum future calibration decomposition

A complete research protocol must validate each claimed layer against a
corresponding observable:

- gastric retention or volume against the specified scintigraphy, MRI, breath,
  or transit measurement;
- intestinal/plasma PK against formulation- and meal-appropriate concentration
  sampling;
- LNAA transport hypotheses against measured amino-acid and levodopa exposure
  data rather than food-category labels;
- effect-site or motor PD against a prespecified endpoint and observation model.

Passing one layer cannot silently validate another. Joint estimation is allowed
only when the protocol demonstrates practical identifiability of the joint
parameterization and reports covariance and predictive uncertainty.

## Open-source architecture transfer and license firewall

| Project | Transferable architecture | Official license boundary |
| --- | --- | --- |
| [PK-Sim](https://github.com/Open-Systems-Pharmacology/PK-Sim) and the [OSP Suite](https://github.com/Open-Systems-Pharmacology/Suite) | Explicit PBPK building blocks; parameter provenance; versioned projects; separation of model construction, simulation, parameter identification, and qualification | Repositories are GPL-2.0. ParkinSUM may study concepts, but must not copy, link, vendor, or adapt code without a compatibility/legal decision and fulfillment of source and notice obligations. |
| [OSP PBPK Model Library](https://github.com/Open-Systems-Pharmacology/OSP-PBPK-Model-Library) | Pair model projects with evaluation/qualification reports and versioned releases | Model, data, and report assets require license verification per repository/release. A software repository license must not be assumed to grant every dataset or model asset. |
| [rxode2](https://github.com/nlmixr2/rxode2) | Unit-labelled ordered dose/observation event tables, ODE execution, reproducible simulation boundaries | GPL-3.0. Current transfer is the event-ledger pattern only; no code or linked runtime is authorized by this review. |
| [nlmixr2](https://github.com/nlmixr2/nlmixr2) | Population estimation workflow; covariance, correlation, shrinkage, and condition-number diagnostics | GPL-3.0. Estimation concepts may inform acceptance criteria; code reuse needs a separate compatibility and obligations review. |
| [OHIF Viewer](https://github.com/OHIF/Viewers) | Registered, versioned extension modules with explicit lifecycle and services; useful for algorithm-trace provider isolation | MIT permits reuse subject to its terms, including preservation of copyright and license notices. This roadmap remains concept-only until an artifact-level decision is recorded. |

The [rxode2 event-table documentation](https://nlmixr2.github.io/rxode2/reference/eventTable.html)
is the direct pattern for ordered dose and observation events with amount and
time units. The [OSP parameter-identification documentation](https://docs.open-systems-pharmacology.org/shared-tools-and-example-workflows/parameter-identification)
and [nlmixr2 estimation documentation](https://nlmixr2.github.io/nlmixr2est/reference/nlmixr2.html)
show why the estimation method, objective, bounds, covariance, and diagnostics
must be retained with a fitted parameter set. The
[OHIF extension documentation](https://github.com/OHIF/Viewers/blob/master/platform/docs/docs/platform/extensions/index.md)
shows an explicit extension identifier, registration, module, service, and
lifecycle boundary.

For every upstream-derived artifact, the future license gate must record the
official URL, release/tag or commit, SPDX identifier, artifact type, whether the
transfer is concept-only/copied/linked/derived, attribution/NOTICE obligations,
and a legal-review result. “Open source” is not a license conclusion.

## Complete future architecture

### 1. Shadow model ensemble

- Keep the current production structure unchanged while Elashoff
  power-exponential, modified power-exponential, linear-exponential, and
  dual/lag structures run on the same synthetic ledger.
- Each provider declares formula, observable, units, free versus fixed
  parameters, intended domain, source IDs, and identifiability status.
- The UI shows structure-by-time trajectories and pairwise disagreement as
  model-form sensitivity. No ensemble mean is called more accurate without
  independent validation.

### 2. Parameter provenance and digest

Every result-affecting parameter records:

- semantic identifier and formula/structure identifier;
- original and canonical unit;
- value or distribution, supported range, and transformation;
- status: measured, literature-derived, fitted, or prototype heuristic;
- source IDs and extraction/review date;
- calibration dataset, split, estimator, software/environment, and diagnostic
  identifiers when fitted;
- immutable canonical digest.

Any result-affecting change must alter the configuration digest and replay
identity. Reproducibility of a digest does not establish biological validity.

### 3. Unit-aware event ledger

The ledger stores immutable, typed dose, meal, observation, and context events
with original value/unit, canonical value/unit, timezone/offset, stable ordering
for equal timestamps, source, missingness/censoring, formulation/route, and
revision provenance. It rejects dimensionally invalid conversions and ambiguous
ordering. A deterministic ledger digest plus configuration digest must reproduce
the same shadow replay. The ledger must not infer or recommend a dose event.

### 4. Calibration dataset governance

Before fitting, a versioned dataset manifest records identity and content hash,
custodian, consent/IRB/DUA or other authorization boundary, license/use
restriction, population, site, formulation, fed state, meal/LNAA variables,
measurement modality, units, missingness/censoring, and raw-to-analysis lineage.

Subject/site/time splits are immutable and leakage-resistant. De-identification,
retention, withdrawal/deletion, access logging, and incident handling are
defined before ingestion. Raw participant data must not enter the public
repository, demo bundle, logs, or goldens. Synthetic fixtures validate software
only and are never described as calibration.

### 5. Post-registration real-backend journey

The first-day journey must use the production Auth/repository boundaries against
temporary SQLite, real browser storage, and Firebase Auth plus Firestore
emulators. It covers registration, ownership, meal/intake creation, trace view,
edit/delete, cold service-graph restart, offline/retry behavior, and account
switch without a test-only repository substitution. It verifies units,
null-versus-zero, provenance, stable identifiers, and audit relationships.

### 6. Device notification conformance

Pending-request counts prove only plugin registry state. Release-equivalent
physical-device evidence must cover visible delivery and tap behavior plus:

- OS/manufacturer/device, app artifact checksum, configuration digest, locale,
  timezone, permission and power-management state;
- permission allow/deny/revoke, Android exact-alarm eligibility, Doze/battery
  policy, reboot, app/OS update, timezone and daylight-saving transitions;
- schedule, reschedule, cancel, sign-out/account switch, visible delivery,
  body-tap activation, duplicate activation, and terminated-app behavior;
- plan-only platforms making no native scheduling call and never reporting
  scheduled-delivery success.

Android documents inexact/exact alarm and power-state constraints in its
[official alarm guidance](https://developer.android.com/develop/background-work/services/alarms),
and Apple documents local-notification scheduling in its
[UserNotifications guidance](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app).
Platform API support is not evidence that a notification was visibly delivered.

## Dependency order

```text
mathematical invariants + units
  -> parameter provenance + configuration digest
  -> unit-aware event ledger
  -> shadow model ensemble
  -> calibration dataset governance
  -> prospective layer-specific calibration

license firewall
  -> any upstream code/model/data reuse

atomic onboarding + real integration harness
  -> post-registration real-backend journey

release artifact journey + platform capability truth
  -> physical-device notification conformance
```

The queue encodes engineering and research readiness only. No item may change
to “shipped” merely because a shadow model runs, a parameter optimizer
converges, an open-source example is reproducible, a pending notification is
registered, or an emulator journey passes.
