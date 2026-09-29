# Gastric observable invariants and precision-diverse verification

Date reviewed: 2026-08-27  
Scope: read-only engineering verification for the gastric structural shadow models  
Production influence: disabled

## Decision

ParkinSUM must verify a gastric equation against the observable it claims to
represent. Normalized meal or tracer retention and pellet retention are
fractions that begin at one, remain in `[0, 1]`, and are non-increasing for the
declared deterministic structures. MRI total gastric volume is an absolute
quantity in mL and may contain a secretion-related early rise; applying the
fraction bound or universal monotonicity rule to that observable would be a
category error.

The production-facing invariant report therefore gains two checks:

1. all six equations are evaluated on a common time grid but assessed with
   observable-specific units, bounds, origin, and monotonicity;
2. held modalities emit no UI trajectory, production output identity remains
   unchanged, and production-derived synthetic observations cannot authorize
   parameter fitting.

A separate Node implementation uses 60-decimal-digit `BigInt` fixed-point
arithmetic, an independently written range-reduced exponential, and an
atanh-series logarithm to reproduce manufactured values for all six equations.
This provides language- and precision-diverse calculation evidence. It does not
provide parameter, biological, or clinical validation.

## Evidence map

### Direct scintigraphic retention

Tougas et al. studied 69 healthy volunteers at seven Canadian institutions,
measured standardized-meal retention at 13 time points, and compared that with
a four-time-point protocol. The observable was proportion of gastric retention,
and the power-exponential curve was protocol- and meal-bound rather than a
universal patient model.

- Primary source: https://pubmed.ncbi.nlm.nih.gov/10638563/
- Engineering consequence: normalized scintigraphic retention receives
  fraction bounds and non-increasing checks; sampling schedule and meal identity
  remain explicit prerequisites for any future fit.

### MRI absolute volume

Bertoli et al. fitted a linear-exponential model to serial MRI gastric-volume
measurements. Absolute gastric volume includes the measurement consequences of
meal dilution and secretion and is not interchangeable with normalized tracer
retention.

- Primary source: https://pmc.ncbi.nlm.nih.gov/articles/PMC10078211/
- Engineering consequence: the MRI structure retains mL units, is never
  overlaid on the current scintigraphic-like fraction fixture, and is not
  rejected merely because an absolute-volume trajectory can rise early.

### Multiparticulate pellet retention

Bürmen et al. compared lag-exponential, Weibull, and five-parameter
double-Weibull models for pellet emptying profiles. This is a dosage-form and
protocol-specific observable, not ordinary meal retention.

- Primary source: https://pubmed.ncbi.nlm.nih.gov/19337822/
- Engineering consequence: pellet curves keep a separate observable identity
  and remain held when only an ordinary-meal retention fixture is available.

### Structural identifiability precedes fitting

Ogungbenro and Aarons showed that identifiability depends on the declared
experiment and measurement model. Their 13C breath-test work required a
two-experiment design and an additional constraint for global identifiability;
the breath signal also contains absorption, metabolism, and excretion processes
and is not a direct gastric-retention measurement.

- Primary source: https://pubmed.ncbi.nlm.nih.gov/21347679/
- Engineering consequence: optimizer convergence and low residual error cannot
  authorize a fit; observable-specific structural identifiability must be
  established before practical-identifiability and held-out checks.

Raue et al. used profile likelihood to distinguish structural and practical
non-identifiability in dynamical systems.

- Primary source: https://pubmed.ncbi.nlm.nih.gov/19505944/
- Engineering consequence: a bounded profile likelihood or a separately
  justified numerical alternative remains part of the research-fit gate.

## Verification limits

- The reference points are manufactured from prior-fixed or production-bound
  parameters; they are not participant observations.
- Decimal agreement checks equation implementation only. It cannot show that a
  structure or parameter is physiologically correct.
- Both implementations use the same published formula identities and fixture
  parameter strings, so transcription errors shared by the specification are
  still possible.
- No shadow result may affect score, rank, recommendation text, medication
  timing, or clinical interpretation.

## Research queue consequences

1. Add an acquisition-schedule information-design benchmark that evaluates
   whether each proposed sampling grid can identify the parameters of its
   matched structure before participant data are collected.
2. Add an explicit 13C breath-test measurement-model lane so indirect breath
   signals can never be treated as direct scintigraphic retention without
   absorption, metabolism, and excretion compartments plus identifiability
   evidence.
3. Extend precision-diverse verification to an external numerical library and
   target-device runtimes; the current independent implementation is a strong
   calculation check but not external reproduction.

