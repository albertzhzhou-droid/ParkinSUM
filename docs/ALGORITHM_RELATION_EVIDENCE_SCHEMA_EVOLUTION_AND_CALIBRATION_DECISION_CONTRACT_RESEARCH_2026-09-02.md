# Algorithm-Relation Evidence Schema Evolution and Calibration Decision Contract

## Scope and decision

This review separates an implemented defect closure from a larger future
schema-evolution program. The combined relation-domain sampling producer had
already emitted the schema URI
`parkinsum.algorithm-relation-domain-sampling-report/2`, while its numeric
`schema_version` remained `1`. The Dart attestation and schema catalog both
declared version 2, so the three surfaces could appear current while disagreeing
on the machine-readable contract.

The current worktree now closes that split for this report. It also replaces an
implicit "three defective fixtures were rejected" pass condition with a locked,
machine-checked calibration decision. This is software-engineering evidence over
synthetic fixtures. It is not a production error estimate, a clinical error
estimate, scientific validation, patient-level accuracy, benefit, safety,
regulatory qualification, or medical advice.

## Research synthesis

- Duque-Torres et al. distinguish a software fault from a metamorphic relation
  that does not hold for a particular input condition. A relation violation
  therefore needs explicit preconditions and relation-defect adjudication; a
  non-violation does not prove the implementation fault-free
  ([arXiv:2305.09640](https://arxiv.org/abs/2305.09640),
  [SANER DOI](https://doi.org/10.1109/SANER56733.2023.00109)).
- Tolksdorf, Lehmann, and Pradel report that warnings from interactive
  metamorphic debugger testing can be false positives when transformation
  assumptions do not hold in language corner cases. This supports preserving
  the relation's failure mode and review disposition rather than treating every
  alarm as a product defect
  ([ISSTA DOI](https://doi.org/10.1145/3293882.3330567),
  [author preprint](https://www.software-lab.org/publications/issta2019.pdf)).
- MR-Scout filters synthesized relations that produce poor-quality generated
  tests, including false alarms, and treats relation design as a domain-knowledge
  problem. Automatically discovered candidates therefore still need an
  independently reviewed activation boundary
  ([ACM DOI](https://doi.org/10.1145/3656340)).
- Chen et al. show that different relations have materially different mutation
  detection effectiveness. A single aggregate relation count or rate cannot
  substitute for per-relation and per-mutation evidence
  ([PLOS ONE](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0212476)).
- JSON Schema Draft 2020-12 treats dialect and vocabulary identifiers as
  explicit processing contracts. ParkinSUM's URI/numeric/catalog handshake is a
  narrower local governance rule, not a claim that these artifacts are complete
  JSON Schema instances
  ([JSON Schema Core](https://json-schema.org/draft/2020-12/json-schema-core.html)).

## Implemented report-v2 handshake

Before the report is accepted, the sampling gate now requires all four facts to
agree:

1. the emitted report URI is
   `parkinsum.algorithm-relation-domain-sampling-report/2`;
2. the emitted numeric `schema_version` is `2`;
3. the Dart consumer declares the same URI and numeric version; and
4. the schema catalog records `currentVersion: 2` and the expected Dart source.

Unsupported report versions, a stale Dart URI or integer, and catalog drift have
distinct deterministic failure codes. Mutation tests cover report versions 1
and 3 as well as stale Dart and catalog declarations. The report digest remains
separately pinned by the committed Dart attestation.

## Locked defective-relation calibration

The policy scope is
`deliberately_defective_relation_fixture_decisions`. Its metric kind is
`defective_relation_diagnostic_exposure`: an incorrect alarm produced by a
relation that was intentionally made invalid. The locked fixture outcomes are:

| Deliberate relation defect | Applicable decisions | Diagnostic exposures | Other rejection evidence | Required disposition |
|---|---:|---:|---:|---|
| Over-broad deep equality | 64 | 32 | 0 mutation survivors | rejected |
| Under-specified shape-only check | 32 mutation cases | 0 (excluded from the alarm denominator) | 32 mutation survivors | rejected |
| Contradictory always-fail rule | 64 | 64 | 0 mutation survivors | rejected |
| **Locked aggregate** | **128 alarm-applicable decisions** | **96** | **32 under-specification survivors** | **3 / 3 rejected** |

The combined diagnostic-exposure rate is recomputed from the integer numerator
and denominator as `96 / 128 = 3 / 4`. The gate does not reward a lower value:
these relations are deliberately defective, so their erroneous behavior is the
evidence that they should be rejected. Instead, the gate requires exact fixture
membership, per-class failure modes, bounded integer counts, aggregate
consistency, the locked rational result, and the declared interpretation policy.
Any numerator, denominator, rate, class, status, policy, or per-fixture drift
blocks the entire report.

## Interpretation boundary

| Quantity | Current status | Defensible interpretation |
|---|---|---|
| Defective-relation diagnostic exposure | measured on locked synthetic fixtures: 96/128 | Confirms that deliberately invalid relations exhibit their declared failure modes and are rejected |
| Production software false-positive rate | `not_estimated` | No preregistered operational profile plus independently adjudicated product truth exists |
| Clinical error rate | `not_applicable` | No representative clinical population, outcome, or valid clinical reference standard is present |

Algorithm Observatory uses the same terminology and displays the schema-v2
locked-fixture scope, 96/128 diagnostic exposures, and the explicit
non-production boundary. Missing and malformed samples remain 64 precondition
HOLDs and never enter the production API or the alarm denominator.

## Verification

`npm run algorithm:contracts:sampling` now exercises ten Node tests, including
schema-handshake mutations, locked numerator and denominator mutations,
non-integer, negative, missing, numerator-greater-than-denominator, forged-rate,
and per-fixture aggregate mutations. The Dart verifier separately rejects stale
count and denominator attestations, while the Observatory widget test asserts
the user-visible schema-v2 and non-production language.

The regenerated combined report retains:

- 8/8 relations and 160 total synthetic cases;
- 96/96 applicable production cases after 624 production API invocations;
- 64 precondition HOLDs;
- 32/32 sampled reviewed mutations detected with zero survivors;
- 3/3 deliberately defective relations rejected; and
- the locked 96/128 diagnostic-exposure decision.

## Remaining work under the existing queue

No new upgrade item is added in this iteration. Broader relation-registry and
report-family evolution remains within the already present
`algorithm_relation_domain_sampling_and_false_alarm_calibration` work, while
execution-path and generator changes remain under
`algorithm_metamorphic_execution_coverage_and_generator_drift`, and production
sampling claims remain under
`algorithm_sampling_operational_profile_and_budget_adequacy`.

Those existing items must not relabel the locked synthetic 96/128 result as an
operational or clinical error rate. A future implementation slice may add a
frozen N-1/N/N+1 compatibility matrix, independent Dart/Node migration
agreement, canonical before/after digests, migration receipts, downgrade
defense, and explicit `accept`, `migrate`, `HOLD`, and `reject` outcomes without
expanding the queue.
