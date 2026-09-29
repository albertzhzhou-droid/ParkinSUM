# Transportability sensitivity, global influence and partial-identification gate

Reviewed: 2026-08-27

Status: deterministic synthetic methodology-governance implementation. It is
not a clinical effect estimate, not calibration, not medical advice and not
regulatory evidence.

## Why this gate exists

The target-population transportability package can diagnose measured overlap
and compare outcome-regression, weighting and augmented estimators. Those
checks do not establish conditional exchangeability across trial participation
when an unmeasured characteristic modifies treatment effect. A green
doubly-robust result must therefore not be allowed to silently imply that
unmeasured transport bias is zero.

[Dahabreh et al.'s bias-function method](https://pmc.ncbi.nlm.nih.gov/articles/PMC10219839/)
parameterizes violations of conditional exchangeability over trial
participation. The parameters are investigator-specified sensitivity inputs,
not values identified by the trial and target samples. The related
[global-sensitivity formulation](https://arxiv.org/abs/2207.09982) directly
parameterizes violations in potential-outcome distributions. ParkinSUM uses
those ideas as governance inputs for a synthetic fixture; it does not claim to
reproduce a published clinical analysis.

Structural nonpositivity is different from a merely uncertain bias parameter.
The [continuous-covariate synthesis literature](https://academic.oup.com/jrsssa/article/188/1/158/7747432)
uses external information and mathematical models to address unsupported
regions. This gate therefore holds structural-positivity failure as
non-identifiable instead of extrapolating a preferred answer.

## Frozen contract

The implemented sign convention is:

`u(a, X) = E[Y^a | X, S=1] - E[Y^a | X, S=0]`

`delta(X) = u(1, X) - u(0, X)`

`adjusted target effect = naive target effect - E_target[delta(X)]`

Before the reference result is visible, the fixture freezes five axes:

1. control-potential-outcome bias, three values;
2. treatment-effect bias difference, seven values;
3. effect-modifier slope, five values;
4. measurement shift, five values; and
5. modifier correlation, five values.

Three attributed elicitation records occur before the result-visibility time.
The full Cartesian product contains 2,625 points. The artifact retains 2,375
admissible points and 250 excluded points with explicit reasons; excluded
combinations cannot disappear from the denominator.

The synthetic bias surface uses the prospectively frozen relation
`delta + 0.5*slope + measurement*(1 + 0.25*correlation)`. This is a manufactured
verification function, not a scientifically fitted disease model.

## Verification surface

Six manufactured local cases cover no violation, the decision threshold, a
null crossing, a protective shift, measurement-only bias and dependent
modifiers. The complete grid is independently used to recompute first-order
and total-effect global sensitivity indices, the partial-identification range,
465 decision-tipping points and 12 null-crossing points.

Eight scenario families run 10,000 repetitions each (80,000 total): reference,
omitted effect modifier, severe unmeasured modifier, measurement error,
dependent modifiers, dual model misspecification, structural positivity
failure and incompatible elicitation. The last two produce explicit held
states with no estimate rather than a synthetic zero.

`tool/independent_transportability_sensitivity_oracle.py` uses only the Python
standard library and imports neither production Dart code nor committed golden
outputs. The release gate applies 30 independent mutations across identity,
chronology, sign, axis, elicitation, grid, exclusion, arithmetic, local/global
results, bounds, tipping regions, scenarios, held states, calibration, oracle,
runtime, upstream, retention, boundary, schema and revocation contracts.

Algorithm Observatory exposes ten separate lanes and dedicated assumption,
elicitation, parameter-space, local, global, bounds, tipping, operating,
independent-replication and boundary sections. A single aggregate credibility
badge cannot replace those surfaces.

## What passing does and does not mean

Passing proves that this repository's synthetic package is internally
consistent, independently reproducible for the manufactured cases and
fail-closed under the enumerated mutations. It does not prove that the chosen
ranges are clinically defensible, that the unknown bias lies inside them, that
conditional transportability holds, or that the target effect is identified.
It cannot repair structural nonpositivity, establish benefit or safety, or
support regulatory acceptance.

## Research-driven next upgrades

- Trial participation can change adherence and other post-assignment
  mediators. [Ross et al.](https://pmc.ncbi.nlm.nih.gov/articles/PMC12614279/)
  show that target effects are not identified without additional assumptions
  when target treatment/adherence data are unavailable, and propose explicit
  sensitivity parameters. The queue therefore adds an adherence and treatment-
  version gate.
- Conditional relative effects may be more plausible to transport than
  conditional differences in some settings, but the assumptions are generally
  not interchangeable. The queue adds an explicit effect-scale comparison
  based on [Wang et al.](https://arxiv.org/abs/2402.02702) rather than selecting
  the more favorable scale after seeing results.
- Cluster-randomized trials require cluster-level participation and treatment
  identities plus within-cluster dependence. The queue adds a cluster-target
  transport gate informed by [Dahabreh et al.](https://onlinelibrary.wiley.com/doi/10.1111/1475-6773.13486).

Each remains `research_required`: adding a source and acceptance contract is
not implementation, calibration or external validation.
