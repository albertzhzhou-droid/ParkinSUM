# Executable Contracts and Metamorphic Gates for Non-Numerical Algorithms

Date reviewed: 2026-09-02

ParkinSUM is an educational/research prototype. This work verifies deterministic
software behavior on fixed synthetic inputs. It is not scientific truth,
clinical calibration, patient-level accuracy, benefit, safety, regulatory
qualification, or medical advice.

## Why a separate gate is necessary

The mathematical invariant gate can test curves, units, complements, bounds,
and numerical ordering, but many registered algorithms return classifications,
rankings, provenance decisions, schema outcomes, or safe abstentions. Treating
those behaviors as numerical validation would overstate the evidence. This
slice therefore creates a separately versioned executable-contract report and
keeps its claim class distinct in code, CI, and the Algorithm Observatory.

FDA's computational-model credibility guidance emphasizes evidence appropriate
to the model's context of use, while FDA recognition of ASME V&V 40 frames
credibility around risk-informed verification and validation. Metamorphic
testing is useful where a conventional test oracle is incomplete: a reviewed
transformation of the input should preserve or predictably change a declared
property of the output. NIST describes this approach for cybersecurity, and
the primary empirical literature reports its use for complex software and
decision-support systems.

Sources:

- FDA, *Assessing the Credibility of Computational Modeling and Simulation in
  Medical Device Submissions*:
  <https://www.fda.gov/regulatory-information/search-fda-guidance-documents/assessing-credibility-computational-modeling-and-simulation-medical-device-submissions>
- FDA recognized consensus standard, ASME V&V 40:
  <https://www.accessdata.fda.gov/scripts/cdrh/cfdocs/cfstandards/detail.cfm?standard__identification_no=38534>
- NIST, *Metamorphic Testing for Cybersecurity*:
  <https://www.nist.gov/publications/metamorphic-testing-cybersecurity>
- Segura et al., metamorphic-testing survey, IEEE TSE:
  <https://doi.org/10.1109/TSE.2013.46>
- Metamorphic testing of decision-support systems, IET Software:
  <https://doi.org/10.1049/iet-sen.2009.0084>
- Zhang et al., *MR-Scout: Automated Synthesis of Metamorphic Relations from
  Existing Test Cases*, ACM TOSEM:
  <https://doi.org/10.1145/3656340>
- Data-mutation-directed metamorphic-relation identification, *Software:
  Practice and Experience*:
  <https://doi.org/10.1002/spe.3280>

## Implemented first wave

The schema-v1 report covers exactly eight registered algorithms:

| Algorithm | Contract relation |
| --- | --- |
| `runtime_rule_support` | Conjunct permutation preserves referenced paths and missing-field result. |
| `catalog_resolution` | Catalog input permutation preserves deterministic identity ranking; empty query remains invalid. |
| `source_authority` | Relevant official sources retain their declared order; cross-jurisdiction conflict remains visible. |
| `runtime_rule_engine` | Jurisdiction ordering is preserved and dimensionally equivalent g/mg inputs fire the same rule. |
| `rule_registry_compiler` | A valid row compiles and deletion of required identity fails schema compilation. |
| `fact_conflict` | Unrelated-fact permutation cannot hide a same-scope contradiction; different scope remains a coexisting variant. |
| `recommendation_orchestrator` | Fixed scenarios preserve conservative fallback and the deterministic candidate set. |
| `local_ai_adapter` | Candidate sets are reorder-only; consent withdrawal and a disallowed endpoint produce zero transport calls. |

Every check uses a production API or reviewed production pure function, fixed
synthetic inputs, deterministic failure codes, and specification plus
observation digests. The report binds the current algorithm configuration and
registered source bundle. Missing, extra, non-finite, blocked, malformed, or
identity-drifted observations fail closed. Async checks use an injected fake
HTTP client; they do not open a socket or call a model.

## Defect found by the relation

The fact-conflict classifier previously returned from the first inspected fact.
If an unrelated attribute appeared first, it could hide a later same-scope
contradiction. The production classifier now filters to the relevant attribute
before applying scope and precedence rules. A regression test preserves this
behavior, and the deliberate contract mutation changes only the
`fact_conflict` status.

## UI and CI evidence

The Algorithm Observatory renders a separate executable-contract panel with
pending, blocked, failed, passed, and `notCovered` states, all eight checks,
digests, relations, references, and failure codes. Every algorithm card also
shows its executable-contract status. Coverage is explicit:

- mathematical/unit specifications passed: 23/23;
- executable-contract coverage: 8 of 63;
- mathematical/unit coverage: 22 of 63;
- deduplicated combined coverage: 30 of 63;
- still uncovered: 33 of 63.

The mathematical/unit report is now schema v2: it publishes exact probe
bindings and fails closed when a passing specification is relabeled to claim an
algorithm its observed probe is not authorized to cover. Its twenty-first check
binds `legacy_food_recommendations` to a black-box production probe. Its
twenty-second check runs manufactured FDC-shaped rows through the production
amino-acid extractor and verifies supported g/mg normalization, true-zero
preservation, number-over-name identity precedence, deterministic ordering,
and fail-closed handling of missing, unknown, non-finite, negative,
non-numeric, or duplicate semantic values. These properties are code and
calculation verification, not biological or clinical validation. Its
twenty-third check runs manufactured catalog and meal records through the
production candidate adapters: source-missing markers override stale nutrient
and energy numbers, present true zero is preserved, and a grams-per-100-g
source value `V` is converted for a serving mass `W` by
`N=(V×W)/100`. Only exact `per_100g` input is eligible; `per_100mL`,
unknown unit/basis, invalid source values, and invalid serving quantities are
held rather than guessed. This is a fixed internal adapter check, not a typed
quantity algebra, external independent reproduction, or biological/clinical
validation. The boundary is derived from USDA's
[Foundation Foods](https://fdc.nal.usda.gov/Foundation_Foods_Documentation/),
[Global Branded Foods](https://fdc.nal.usda.gov/GBFPD_Documentation/), and
[FDC API](https://fdc.nal.usda.gov/api-spec/fdc_api.html) documentation plus
the [BIPM SI Brochure](https://www.bipm.org/en/publications/si-brochure/).

`npm run algorithm:contracts` writes
`build/algorithm_executable_contract/latest.json`. `npm run verify:all` runs it
as an independent composed gate and fails if report integrity or the declared
63/8/30/33 coverage identity drifts.

## Independent cross-runtime relation gate

The first-wave common-runtime limitation is now addressed by a separate,
schema-v1 relation registry and a Node oracle that imports no production Dart.
The production gate emits a neutral observation intermediate representation;
the Node implementation evaluates the eight relation definitions again rather
than trusting Dart's pass booleans. The registry records preconditions,
transformations, expected relations, required observations, rationale, review
metadata, sources, known false-relation risks, and targeted mutation operators.

The committed offline evidence is:

- 8/8 independently evaluated relations passed;
- 16/16 targeted intermediate-representation mutations were detected, with
  zero survivors and no collateral relation failures;
- 3/3 deliberately invalid relation definitions were rejected; and
- 6/6 deterministic completion, withdrawal, timeout, cancellation, and
  capability-revocation orderings passed.

`npm run algorithm:contracts:independent` regenerates and verifies
`build/algorithm_contract_independent_oracle/latest.json`. A Dart attestation
pins the relation-registry, Node-oracle, executable-specification,
configuration, registered-source-bundle, and report identities. The Algorithm
Observatory renders these results in a distinct offline-evidence panel; it does
not execute Node in the app.

Current pinned identities:

- relation registry:
  `b4c4dd5f9093439cb32194ca6a3457d0e94539900e8687a57ea8109a7446e54e`;
- independent Node oracle:
  `aa96bf83f6916fe73b47be8057129ef57ae3420a8b615b5c6a07a40f5e8d04e0`;
- executable specification:
  `ff35483181c82282c5c4507ac927911eb04395f5ab60b24aa48b8b2970096cae`;
- algorithm configuration (`2026.09.02-v40`):
  `56cf755398784e7067c32bc1eb1d197f2b2c737868b6b015aaa431018959ceaf`;
- registered algorithm source bundle:
  `fc9eebdaa016136f558f4a07c7c0b70254092633a25ca1bf26312a104a9d4bdf`;
- independent report:
  `0cbb9d05c103ad8fdddd9c546b88778feeb4260b4f6950ff5540f656e93bd79e`.

## Limits and next research step

Cross-runtime agreement reduces one class of common-mode implementation error;
it still cannot prove that a relation is scientifically true or sufficient.
The fixtures cover a small, fixed input family, and the 16 mutations are
reviewed IR faults rather than an exhaustive source-level mutation campaign.
The schema-v2 production-pair calibration slice is documented in
`ALGORITHM_RELATION_DOMAIN_SAMPLING_RESEARCH_2026-08-31.md`; 96 applicable
source/follow-up samples now execute production APIs and undergo independent
Node evaluation, while 64 missing/malformed cases remain precondition HOLDs.
The queue therefore retains
`algorithm_relation_domain_sampling_and_false_alarm_calibration` for the full
production mutation matrix, equivalent-mutant review, relation diversity,
differential path coverage and seed/operational-profile adequacy. Automated
relation discovery may suggest candidates, but activation still requires
independent domain review. Mutation score and agreement must never be
presented as correctness, scientific validity, clinical safety, or regulatory
evidence.
