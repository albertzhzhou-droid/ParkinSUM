# Algorithm trace-surface lifecycle and semantic-path research

Reviewed: 2026-08-31

## Question

How should ParkinSUM distinguish a production-engine-derived algorithm trace from a static UI explanation, keep that distinction auditable as the registry changes, and prepare for meaningful source/follow-up path coverage without leaking health data or overstating correctness?

## Evidence used

- OpenTelemetry's semantic conventions define shared names, types, meanings, and valid values so signals remain correlatable across producers and consumers. Its telemetry-schema specification exists because producers and consumers otherwise drift when conventions change. These are observability design precedents, not proof that OpenTelemetry is the right runtime dependency for ParkinSUM. [Semantic Conventions 1.44.0](https://opentelemetry.io/docs/specs/semconv/) · [Telemetry Schemas](https://opentelemetry.io/docs/specs/otel/schemas/)
- OpenTelemetry's URL convention explicitly warns that captured URL components can create security risk and requires credentials and known sensitive query values to be excluded or scrubbed. ParkinSUM applies the stricter prospective boundary that algorithm trace artifacts must not contain raw URLs, query strings, health text, user identifiers, or raw medication and meal values. [Semantic conventions for URL](https://opentelemetry.io/docs/specs/semconv/url/)
- Path-directed metamorphic-test research reports that source-case path diversity and source/follow-up execution differences can improve test prioritization and fault detection. It does not show that path diversity alone establishes correctness or that its results transfer to ParkinSUM's domain. [Path-directed source test case generation and prioritization in metamorphic testing](https://doi.org/10.1016/j.jss.2021.111091)
- Coverage-guided property-based testing retains inputs that expand control-flow coverage, especially when semantic preconditions are sparse. This supports a future separation between locked regression cases and exploratory generators; it does not justify replacing reviewed domain partitions with unconstrained fuzzing. [Coverage Guided, Property Based Testing](https://doi.org/10.1145/3360607)
- The recent Metamorphic Coverage proposal treats distinct code reached by source/follow-up pairs as evidence separate from ordinary coverage. It is a preprint and should inform a research queue, not a shipped clinical or release claim. [Metamorphic Coverage](https://arxiv.org/abs/2508.16307)

## Implemented slice

ParkinSUM now has a schema-v1 content-addressed trace-surface manifest. It binds:

- all 63 registered result-affecting algorithms to exactly one explicit disposition;
- fourteen production-trace algorithms to `observatory.production-snapshot/1`;
- fixture schema and revision, registration/disposal lifecycle, the `app-tools.observatory` destination, provider source, algorithm-specific UI surface keys, and executable test owners;
- the other 49 algorithms to `staticContractOnly`, without treating a generic icon or static flow as runtime evidence;
- the complete registry source/UI/static-visual mapping to a separate SHA-256 identity;
- a CI gate that compares compiled ownership with the reviewed JSON manifest and rejects route/source/test drift;
- an Algorithm Observatory panel that exposes counts, schema, digest, lifecycle, route, and the non-clinical boundary.

The current increments also expose five existing production calls as separate
nodes. `medication_entry_validator` reports structural validity, required-field
presence, and issue count without medication names or source identifiers.
`time_axis_builder` shows per-type event offsets and caller-window placement
relative to the first meal, counts missing or rejected inputs, and omits
absolute UTC minutes and event identifiers. The `protein_trend` node calls the
production aggregation on three fixed synthetic meals with deliberately
different input and occurrence-time order; it renders relative-day offsets and
the arithmetic mean without row IDs, meal titles, food names, or absolute
timestamps. The `input_quality_gate` node
reports dimension-level completeness statuses and the held product-strength-
only case, while stating that this standalone assessment does not authorize or
veto the other Observatory traces. The standalone dose-parser probe executes
five fixed syntax cases and emits only status/reason counts; it withholds raw
text and quantities and does not feed the other Observatory scenarios. The
`gastric_structural_uncertainty_shadow_ensemble` trace now binds the existing
read-only report to its registry identity, summarizes matched and held
trajectories, and confirms the production curve digest is unchanged. The
`protein_distribution` node projects stored production scorer outputs for
fixed synthetic candidates, reports role counts and bounded score summaries,
and omits names, identifiers, catalog references, protein grams, and absolute
timestamps. It does not recompute outputs or affect ranking. The manifest
reports 14/63 production traces and 49 static contracts. This remains synthetic
engineering evidence; the other 49 traces, semantic execution-path
coverage, and target-device accessibility evidence are still open.

This is an auditability improvement. It does not add production trace providers for the other 49 algorithms, measure source/follow-up path diversity, establish fixture representativeness, or validate scientific and clinical behavior.

## Next research contract

Before adding path measurements, define a closed low-cardinality semantic taxonomy with explicit schema migration and privacy rules. The future implementation should retain separate source and follow-up ordered path identities, correlation and generator/configuration/source-bundle identities, and an explicit unavailable or incomplete state. It must measure cardinality, serialized size, event count, and runtime overhead; instrumentation must not change outputs or ordering.

The taxonomy should reject free-form health text, medication or meal values, account identifiers, raw URLs, query strings, local paths, and identifying timestamps. Metamorphic path diversity must remain a separate evidence lane from relation pass/fail, ordinary coverage, mutation results, scientific validity, and clinical safety.
