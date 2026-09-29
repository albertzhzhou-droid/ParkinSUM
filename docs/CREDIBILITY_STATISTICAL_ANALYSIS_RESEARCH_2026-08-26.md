# Statistical analysis, error control, and uncertainty governance

Status: implemented as a deterministic synthetic governance fixture on
2026-08-26. This is research and engineering governance, not clinical or
statistical validation.

## Question

What minimum machine-checkable contract prevents ParkinSUM from presenting a
synthetic result while silently changing the target question, analysis set,
missing-data method, multiplicity rule, denominator, sensitivity analysis, or
post-result decision rule?

## Primary-source research map

### ICH E9: Statistical Principles for Clinical Trials

Source: <https://database.ich.org/sites/default/files/E9_Guideline.pdf>

The guideline separates protocol and statistical-analysis-plan decisions from
later access to unblinded results. It calls for the principal analysis,
analysis sets, missing-value handling, sample-size basis, estimation and
confidence intervals, multiplicity, interim analyses, and subgroup analyses to
be specified and justified. It also treats multiplicity from several primary
variables, repeated evaluation, interim looks, or treatment comparisons as a
type-I-error problem that requires a declared strategy.

Implemented consequence:

- authored, frozen, and first-result-access clocks are separate;
- one explicit endpoint hierarchy binds estimand, family, analysis set,
  estimator, missing-data method, hypothesis, sidedness, alpha, and decision
  rule;
- overall alpha, confidence level, multiplicity, interim-look count,
  alpha-spending identity, power, variance, effect, attrition, target sample
  size, and minimum informative denominator are retained;
- every planned endpoint must keep an explicit reported, null, inconclusive,
  failed, contradictory, adverse, or missing state.

### ICH E9(R1): Addendum on estimands and sensitivity analysis

Source:
<https://database.ich.org/sites/default/files/E9-R1_Step4_Guideline_2019_1203.pdf>

The addendum connects the trial objective to an estimand defined through the
treatment condition, population, variable, population-level summary and
handling of intercurrent events. It distinguishes sensitivity analysis from a
different scientific question: a sensitivity analysis should assess robustness
for the same estimand under different assumptions.

Implemented consequence:

- every estimand names the scientific question, population, variable, horizon,
  summary measure, effect measure, and strategy for each intercurrent event;
- analysis results cannot change the endpoint's estimand;
- each primary endpoint requires at least two prospectively planned,
  same-estimand sensitivity analyses;
- post-result estimand, endpoint, analysis-set, missing-data, alpha,
  multiplicity, sample-size, subgroup, or sensitivity changes fail closed.

### EMA: Multiplicity issues in clinical trials

Source:
<https://www.ema.europa.eu/en/multiplicity-issues-clinical-trials-scientific-guideline>

The EMA guideline frames multiple endpoints and subgroup claims as multiplicity
problems affecting both type-I error and interpretation of estimates and
confidence intervals.

Implemented consequence:

- multiple confirmatory endpoints cannot use the single-primary no-adjustment
  mode;
- confirmatory alpha allocations must remain within the overall family budget;
- each confirmatory result retains a multiplicity-adjusted p-value that cannot
  be smaller than its unadjusted p-value;
- a p-value and confidence interval that imply incompatible decisions trigger
  an integrity finding.

## Implemented artifact

The versioned
`parkinsum.credibility-statistical-analysis-package/1` binds the previous
prospective-plan, execution, protocol-transparency, and blinded-replication
chain to:

1. explicit estimands and intercurrent-event strategies;
2. endpoint hierarchy and prospective analysis contracts;
3. alpha, confidence, multiplicity, interim and sample-size assumptions;
4. complete result states with estimates, intervals, p-values and reconciled
   denominators;
5. prospectively planned same-estimand sensitivity analyses;
6. append-only, independently reviewed deviation events;
7. runtime configuration and algorithm-source-bundle identities.

The independent gate applies 12 mutation families. The UI exposes seven lanes:
design, estimand, estimate, uncertainty, error control, sensitivity, and
deviations. It also displays counts for every result state, including zero-count
states, so absence cannot be misread as suppression.

## Boundary

The current data are fixed synthetic fixtures. Passing confirms deterministic
contract enforcement only. It does not establish adequacy of a real study,
validity of assumptions, representativeness, causal effect, clinical
importance, external replication, regulatory acceptance, benefit, safety, or
medical advice.

## Researched next upgrade

Next queue item:
`credibility_randomization_allocation_concealment_and_interim_firewall_gate`.

It is intentionally separate from this slice. The present gate validates the
declared statistical semantics; the next gate will validate operational role
separation around randomization and interim access:

- content-addressed randomization schedule and allocation-concealment identity;
- authorized emergency-unblinding events with reason and disclosure scope;
- independent interim-review authority and sponsor/investigator firewall;
- append-only access records for unblinded treatment and interim-result data;
- prospectively locked alpha-spending and stopping boundaries;
- recommendation, acceptance, override, rollback, and revocation history.

Research seed: ICH E9 sections on randomization, blinding and interim analysis.
Before implementation, the item must also be checked against the current ICH
E6(R3) good-clinical-practice materials. It remains governance research and
must not be described as GCP compliance.
