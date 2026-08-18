# Independent numerical oracle research and implementation boundary

Date reviewed: 2026-08-18

## Decision

ParkinSUM now has a versioned, read-only numerical oracle for the six algorithms that currently emit production-provider traces. The oracle restates the reviewed equations and units independently, obtains only the final production observations, and compares 19 scalar truth vectors with explicit tolerances. Missing, extra, non-finite, or out-of-tolerance observations fail closed.

This is implementation and calculation verification for a fixed, non-personal engineering fixture. It is not biological validation, clinical validation, a patient prediction, a pharmacokinetic model qualification, or medical advice.

## Why this is a separate evidence layer

The FDA's November 2023 final guidance describes a risk-informed credibility framework for physics-based, mechanistic, and first-principles models. The underlying guidance distinguishes code verification, calculation verification, and validation evidence; passing one does not silently satisfy the others. ASME V&V 40 likewise says credibility evidence should be commensurate with model reliance and the consequence of a wrong decision, and explicitly describes its framework as neither a step-by-step validation method nor a universal quantitative credibility score.

ParkinSUM therefore keeps these claims separate:

1. Invariants and replay goldens detect regressions and impossible structures.
2. The numerical oracle detects shared-equation mistakes that can preserve monotonicity, bounds, and deterministic digests.
3. Applicability and typed abstention prevent unsupported inputs from producing modeled numbers.
4. None of the above establishes biological or clinical accuracy.

## Implemented architecture

```text
versioned independent equations + manufactured fixture
                         |
                         v
              19 expected scalar vectors
                         |
              exact observation-shape gate
                         |
production Observatory snapshot -> finite/tolerance comparison
                         |
 verified | mismatch | not covered | blocked
                         |
  Observatory panel + per-algorithm status + release tests
```

The oracle does not import production constants, private formula helpers, production fixture output, or golden generators. The production side is invoked only to obtain observations from the fixed `mixedReference` Observatory scenario. Its manifest is canonicalized and SHA-256 identified.

### Covered now

- `meal_composition_normalizer`
- `gastric_emptying`
- `levodopa_absorption_opportunity`
- `amino_acid_competition`
- `mechanistic_conflict`
- `mechanistic_candidate_scorer`

The vectors cover totals and completeness, a closed-form gastric remaining fraction and derived windows, IR absorption timing and openness, the full absorption-grid LNAA overlap integral, conflict composition, and candidate-score composition. Mutation tests kill minute/hour scaling, wrong-but-normalized weight, sign, and threshold-branch defects.

### Not covered now

The other 52 registered result-affecting algorithms remain explicitly `notCovered`. The queue item therefore remains open. The current oracle also runs in Dart using the same floating-point runtime as production, uses one manufactured scenario, and is not a solver/platform precision qualification.

## Open-source pattern review

- [mrgsolve](https://github.com/metrumresearchgroup/mrgsolve) is a mature open-source R package for ODE-based population PK/PD and QSP simulation. Its separate runtime and model files illustrate why a future cross-language differential oracle can reduce common-runtime failure modes. ParkinSUM did not copy its equations or code.
- [ToxMCP PBPK MCP](https://github.com/ToxMCP/pbpk-mcp) exposes simulation and PK-analysis workflows while documenting distinct verification and qualification concerns. ParkinSUM used this as an architectural comparison only; no upstream code was copied.

These projects do not validate ParkinSUM's educational timing-overlap model. They inform a future engineering pattern: a separately implemented, separately versioned executable reference with a neutral vector-exchange schema.

## Sources and limits

- [FDA, Assessing the Credibility of Computational Modeling and Simulation in Medical Device Submissions, final guidance, November 2023](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/assessing-credibility-computational-modeling-and-simulation-medical-device-submissions). Applicable as a credibility-boundary framework; ParkinSUM is not claiming a device submission or FDA acceptance.
- [ASME V&V 40-2018 official summary](https://www.asme.org/codes-standards/find-codes-standards/assessing-credibility-of-computational-modeling-through-verification-and-validation-application-to-medical-devices). The full standard is licensed; this review relies only on the public official summary and does not claim conformance.
- [mrgsolve public repository](https://github.com/metrumresearchgroup/mrgsolve). Reviewed for architecture and independent-runtime comparison, not as a source of ParkinSUM constants.
- [ToxMCP PBPK MCP public repository](https://github.com/ToxMCP/pbpk-mcp). Reviewed for workflow boundaries, not as clinical evidence.

## Next research item

A cross-language, precision-diverse oracle should use a neutral versioned vector exchange, a separately maintained implementation, higher-precision or analytic reference arithmetic where justified, and a platform matrix. Its signed evidence would still be engineering verification only. It must not be described as clinical calibration, validation, or regulatory qualification.
