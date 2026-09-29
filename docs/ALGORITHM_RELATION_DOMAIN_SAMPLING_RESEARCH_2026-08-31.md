# Algorithm Relation Domain Sampling and False-Alarm Calibration

## Scope

This iteration advances the reproducible calibration layer around the eight
governed non-numerical algorithm relations. For every applicable normal,
boundary, or adversarial sample, a Dart runner now generates a fresh synthetic
source/follow-up pair and executes the production algorithm APIs. The resulting
observations are then evaluated by the independent Node relation evaluator,
which imports no production Dart. Missing and malformed samples are retained as
explicit precondition HOLDs and never enter a production API.

The paired production execution, independent relation decision, and separate
observation-IR mutation layer are machine-readable and separately hashed.
Passing this layer is finite synthetic engineering evidence, not exhaustive
production-domain coverage or evidence of correctness, scientific truth,
clinical calibration, patient benefit, safety, or advice.

## Research synthesis

- Saha and Kanewala showed that source-test generation strategy affects
  metamorphic fault detection. A relation count without a declared generator,
  seed frame, and domain partition is therefore not a stable adequacy claim
  ([DOI 10.1145/3193977.3193982](https://doi.org/10.1145/3193977.3193982)).
- QuickCheck's generator and shrinking model supports retaining reproducible
  seeds and a minimal counterexample path. Custom generators can also encode
  bias or produce misleading shrink behavior, so generator identity and
  version are part of the governed artifact
  ([DOI 10.1145/1988042.1988046](https://doi.org/10.1145/1988042.1988046)).
- Mutation testing surveys emphasize that equivalent mutants are a distinct,
  difficult classification. They must not be silently counted as ordinary
  survivors or removed to inflate a score
  ([DOI 10.1109/TSE.2010.62](https://doi.org/10.1109/TSE.2010.62)).
- Metamorphic coverage research distinguishes differential source/follow-up
  execution from ordinary coverage. This motivates a separate queued step for
  production-path differential coverage rather than treating the current IR
  diversity count as execution coverage
  ([arXiv:2508.16307](https://arxiv.org/abs/2508.16307)).
- NIST's overview and empirical metamorphic-testing surveys support using
  relations where expected point outputs are unavailable, while still
  requiring explicit relation review and bounded claims
  ([NIST](https://www.nist.gov/publications/metamorphic-testing-cybersecurity),
  [DOI 10.1109/TSE.2013.46](https://doi.org/10.1109/TSE.2013.46)).
- Path-directed source-test generation research reports that source/follow-up
  path diversity changes metamorphic fault-detection effectiveness. The v2
  runner therefore records paired inputs and outputs but does not equate 96
  successful decisions with path adequacy
  ([DOI 10.1016/j.jss.2021.111091](https://doi.org/10.1016/j.jss.2021.111091)).
- Coverage-guided property-based testing supports feedback from execution into
  input generation, but an adaptive search corpus is a different evidence lane
  from a frozen reproducible regression corpus
  ([DOI 10.1145/3360607](https://doi.org/10.1145/3360607)).

## Implemented contract

`config/algorithm_relation_domain_sampling_plan.json` is schema v2. Each of
the eight relations declares:

- a deterministic generator and version;
- four locked integer seeds;
- normal, boundary, missing, malformed, and adversarial partitions;
- an explicit precondition and boundary;
- a shrink strategy;
- a minimum 20-case diversity budget; and
- a synthetic-only, no-real-health-data boundary.

`tool/run_algorithm_relation_production_sampling.dart` executes the applicable
samples, while `tool/algorithm_relation_domain_sampling.mjs` independently
evaluates those observations and retains a separate IR mutation/false-relation
layer. Together they emit 160 byte-stable cases:

| Evidence class | Result |
|---|---:|
| Relations meeting the 20-case/five-partition budget | 8 / 8 |
| Total sampled cases | 160 |
| Missing or malformed cases held at preconditions | 64 |
| Applicable source/follow-up production executions | 96 / 96 passed |
| Production API invocations | 624 |
| Independent Node relation evaluations | 96 / 96 passed |
| Sampled reviewed mutations detected | 32 / 32 |
| Sampled mutation survivors | 0 |
| Defective relations rejected | 3 / 3 |
| Diagnostic exposures among applicable deliberately defective-relation decisions | 96 / 128 |
| Fixed production-generated relation anchors | 8 |

The 75% defective-fixture diagnostic-exposure rate is intentionally not a
production false-positive estimate. It confirms that one over-broad and one
contradictory relation definition reject valid cases; the under-specified
fixture is rejected because it lets adversarial mutations survive.

## Report-v2 schema and calibration closure (2026-09-02)

The combined report now emits both URI revision `/2` and numeric
`schema_version: 2`. The Node producer verifies those values against the Dart
consumer constants and `config/schema_catalog.json` before accepting the
attestation. Mutations to report versions 1 or 3, the Dart URI or integer, and
the catalog version fail closed.

The report also carries a locked
`parkinsum.defective-relation-calibration-policy/1` contract. It requires the
three exact fixture classes and their declared failure modes: over-broad deep
equality exposes 32/64 incorrect alarms, the under-specified shape-only rule
lets 32/32 sampled mutations survive and is excluded from the alarm
denominator, and the contradictory rule exposes 64/64 incorrect alarms. The
gate recomputes the aggregate `96/128 = 3/4` from bounded integer counts and
blocks numerator, denominator, membership, per-class, rate, or policy drift.

This is a locked synthetic regression decision, not a target that rewards a
low rate. A high diagnostic-exposure count is expected because the relations
were deliberately made invalid. Production false-positive rate remains
`not_estimated`; clinical error rate remains `not_applicable`.

Every case retains the relation, algorithm, generator, version, seed,
partition, transformation, optional mutation identity, source/follow-up input
and output digests, relation-observation digest, production invocation count,
precondition and observed status, failure codes, and shrink path. The production
report additionally binds the exact Dart runner and production executor source.
Equivalent, unreachable, invalid, and surviving mutation counts remain separate
fields even when zero.

## Verification and UI

Run `npm run algorithm:contracts:sampling`. It regenerates the fixed Dart
production anchor, executes 96 paired Dart samples, runs ten Node sampling
tests, independently evaluates every applicable relation observation, verifies
the committed Dart attestation pins, and writes ignored production and combined
artifacts under `build/algorithm_relation_production_sampling/` and
`build/algorithm_relation_domain_sampling/`.

Algorithm Observatory preserves the fixed cross-runtime relation gate as its
own panel and adds a separate amber sampling panel. The new panel exposes the
case count, 96/96 independently accepted production samples, 624 production API
invocations, 64 execution-precondition HOLDs, mutations, survivors, defective
relations, locked defective-relation diagnostic exposures, schema-v2 scope,
generator identity, combined/production/executor identities, and the
non-exhaustive boundary.

## Open production-domain closure

The queue item remains `research_required`. Completion still requires:

1. the full reviewed mutation-operator-by-seed matrix against production APIs;
2. independently adjudicated equivalent and unreachable mutants;
3. relation marginal-contribution and redundancy analysis;
4. externally reviewed relation candidates and counterexamples;
5. differential production-path coverage plus generator-version drift gates;
6. predefined seed-budget and stopping rules with repeated seed blocks; and
7. operational-profile representativeness without presenting synthetic
   partition weights as user or population prevalence.

The last item is separately queued as
`algorithm_metamorphic_execution_coverage_and_generator_drift` so a fixed
regression corpus, rotating exploratory seeds, minimized counterexample
promotion, and generator migration evidence cannot be collapsed into the
current IR calibration claim.
