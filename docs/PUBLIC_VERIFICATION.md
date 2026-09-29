# Public Verification Guide

Educational/research prototype. Synthetic/demo data only. **Not medical advice,
not clinically calibrated, and carries no clinical-validation claim.**

These are the exact commands a reviewer can run to verify ParkinSUM Companion
locally. They are **deterministic, synthetic-data regression and governance
checks** — they are **not** clinical validation, and the source-quality report
is **not** a clinical dashboard.

## Prerequisites

Install Flutter, Dart, Node.js, and npm. From the repository root run
`flutter pub get` and `npm ci` once. All checks below run on **synthetic/demo
data** and, except where noted, require **no network**.

**Minimum Dart SDK in practice: 3.11.0** (Flutter 3.47 or newer). The floor is
set by the strictest dependency — currently `xml`, which requires Dart
`^3.11.0`. On an older SDK `flutter pub get` fails during version solving before
any check can run, and the error names `xml` rather than the SDK:

```
Because xml 7.0.1 requires SDK version ^3.11.0 ... version solving failed.
```

`pubspec.yaml` now declares `sdk: ">=3.11.0 <4.0.0"`, matching this dependency
floor. The accompanying formatter migration is part of the current worktree;
review it separately from runtime and evidence changes rather than treating the
large mechanical diff as a behavioral change.

## One command

### `npm run verify:all`
- **Checks:** every deterministic governance gate in one run — explanation copy
  compile, localization safety lint, dose-expression grammar differential
  conformance, administration-dose confirmation receipt reconciliation,
  mechanistic replay, lossless replay-capsule cross-runtime conformance,
  portable-schema validator/migration cross-runtime conformance,
  mathematical/unit invariants, non-numerical executable
  contracts and metamorphic mutations, exact Analyzer/root compatibility,
  independent cross-runtime relation
  evaluation and mutation detection, Local-AI scenario
  replay, synthetic scenario fuzzer, local privacy preflight, store privacy
  declaration drift, open-source influence/license firewall, source access
  contract, source version drift, contribution safety router, context-of-use
  requalification ledger, prospective credibility plan, evidence-execution
  independence, protocol amendment/deviation/result-transparency ledger,
  blinded independent-replication capsule and discrepancy adjudication,
  statistical analysis/error control/uncertainty governance,
  randomization/allocation-concealment/interim-access firewall,
  adaptive-design operating-characteristics simulation and decision-rule
  calibration,
  Bayesian prior/external-borrowing conflict/posterior-decision calibration,
  Bayesian multi-source transportability/model criticism/independent
  replication,
  target-population identification/overlap/doubly robust estimation/independent
  replication,
  target-transportability bias functions/global sensitivity/partial
  identification/independent replication,
  release-artifact Web reflow contract tests, local Wasm hosting attestation
  contract tests,
  evidence currency/correction/retraction/sunset gate,
  claim-level contradiction and synthesis adjudication, and the committed-golden
  drift check.
- **Expected:** `All 55 gates passed.` plus `build/verify_all/latest.{json,md}`.
- **Failure means:** at least one gate reported a blocker; the composed report
  names which. The command exits non-zero, so it is a ratchet, not a summary.
- **Network:** no. **Data:** synthetic only.
- **Inventory:** `npm run verify:all -- --list` prints the gate list.

CI runs this exact command, so local and CI verification cannot drift apart.
The sections below document each gate individually for anyone who wants to run
one in isolation.

### Analyzer compatibility and stable result roots

- **Run:** `npm run algorithm:dependency-compatibility`.
- **Checks:** exact `analyzer 14.1.0` dependency/archive lock; reviewed Dart
  3.13.0 and Flutter 3.47.0 identities; strict schema-v1 manifest bijection for
  all 63 `AlgorithmRegistry` IDs; stable application-owned root/result-sink
  IDs; canonical package/library URI resolution; each `AnalysisContext`'s own
  consistent session; success-result type; blocking error diagnostics; input
  artifact digests; unsafe/unknown/duplicate/drift mutations; and canonical
  order stability.
- **Expected:** compatibility `PASS`, 63/63 resolved roots, and closure state
  `held_pending_full_result_dependency_closure`. The full path-free report is written
  to `build/algorithm_dependency_compatibility/latest.json`.
- **Failure means:** the selected Analyzer/toolchain/input identity or one or
  more stable roots cannot be accepted. A pass verifies root compatibility only;
  the separate bounded preview below is not a complete transitive closure.
- **Network:** no after dependency resolution. **Data:** source metadata only;
  no user or patient data.

### Bounded Analyzer dependency preview

- **Run:** `npm run algorithm:direct-edge-probe`.
- **Checks:** schema-v14 static observations over every discovered regular Dart
  file under `lib/`, stable registered roots, supported declaration edges,
  Analyzer-validated declared-part ownership, conservative recursive
  import/export candidate traversal, per-root bounded forward reachability,
  strongly connected components, reverse declaration and source-unit
  ownership, unresolved blockers, inventory reconciliation, and a canonical
  report digest.
- **Expected:** 63/63 roots, 459/459 accepted source units, 1,025 reachable
  source-unit visits, 2,926 reachable namespace-branch visits, 113,908
  reachable edges, 121 bounded cycle components, 9,104 reverse declaration
  ownership rows and 211 reverse source-ownership rows. The report is written
  to ignored `build/algorithm_direct_edge_probe/latest.json`.
- **Boundary:** exact result sinks, complete dispatch and bridges, full repository
  input-state snapshots, impact binding, and closure UI remain open. The report
  does not establish runtime behavior, exact data flow, scientific validity,
  clinical safety, or patient-specific impact.
- **Network:** no after dependency resolution. **Data:** source metadata only;
  no user or patient data.

### Mathematical and unit invariants

- **Run:** `npm run mechanistic:invariants`.
- **Checks:** 23 digest-bound checks: 15 fixed scenario/provider checks, five
  black-box dose-input checks, one black-box
  `legacy_food_recommendations` scorer check, and one black-box FDC amino-acid
  extraction check, plus one black-box production catalog-candidate projection
  check. Report schema v2 publishes exact
  probe-to-algorithm bindings and fails closed if a passing check is relabeled
  to claim coverage outside its observed probe. The legacy scorer contract
  bounds its heuristic score to 0..100 and uses food ID to stabilize equal-score
  ordering. The extraction contract preserves a reported zero, normalizes only
  supported g/mg units to grams, and holds missing, unknown, non-finite,
  negative, non-numeric, or duplicate semantic values instead of converting
  them into measured nutrient values. The projection contract gives source
  missing markers precedence over stale numbers, preserves a present true zero,
  and applies `N=(V×W)/100` only to grams-per-100-g source values and a
  valid serving mass. It holds `per_100mL`, unknown/missing unit or basis, and
  invalid source or serving values rather than guessing a density. This boundary
  follows USDA's [Foundation Foods](https://fdc.nal.usda.gov/Foundation_Foods_Documentation/),
  [Global Branded Foods](https://fdc.nal.usda.gov/GBFPD_Documentation/), and
  [FDC API](https://fdc.nal.usda.gov/api-spec/fdc_api.html) documentation plus
  the [BIPM SI Brochure](https://www.bipm.org/en/publications/si-brochure/).
- **Expected:** `Mechanistic model verification: 23/23 checks; 22/63 algorithms
  covered`; `build/mechanistic_model_verification/latest.json` lists the other
  41 algorithms as `notCovered`.
- **Boundary:** deterministic code and calculation verification over synthetic
  inputs only. It does not prove that every importer emits correct missingness
  and basis metadata, provide an external independent reproduction or typed
  quantity algebra, or establish biological/clinical validation, patient-level
  accuracy, benefit, safety, regulatory qualification, or medical advice.

### Algorithm configuration identity and declared-scope completeness witnesses

- **Run:** `flutter test test/levodopa_absorption_opportunity_parameters_test.dart test/legacy_food_recommendation_parameters_test.dart test/algorithm_component_graph_identity_test.dart test/parkinsum_algorithm_sdk_test.dart test/algorithm_observatory_page_test.dart`.
- **Checks:** algorithm-configuration schema v6 binds 33 numeric score,
  boundary, threshold and Top-K leaves plus the score-descending/food-ID-
  ascending tie policy to the exact production legacy recommender. Invalid
  NaN, range, threshold-order, integer or policy values fail before execution;
  an injected runtime scorer cannot reuse a mismatched identity. Coverage
  schema v2 additionally verifies all 17 declared gastric-emptying and 13
  declared absorption numeric and structural fields, production sinks, source
  fingerprints, source bundle and exact dependency digests before publishing
  either declared-scope completeness witness.
  The Observatory renders canonical structured values and per-row
  `prototype-heuristic · not clinical` copy, including a 320-pixel/200% text
  fixture.
- **Expected:** 119 total provenance records, 16/63 algorithms field + source
  bound, 47/63 source-bundle-only, and exactly two claimed complete per-field:
  `gastric_emptying` (17 fields) and `levodopa_absorption_opportunity` (13
  fields). The dose-parser record binds its local grammar and unit-map identity
  while leaving internal branch coverage incomplete. The protein-trend record
  binds its effective-time basis, per-meal protein amount, order, and mean
  formula. The current canonical identity is `2026.09.29-v52`, configuration
  digest `77d2a1d030443c12f125e0ee9606f25a085dab76ef73d7a20fb62d7c9019a99d`,
  and registered source-bundle digest
  `15a293f7efa3501b0d206570d651b1abecc828e2d796751debd5225cece4bd6d`. The v52
  identity binds the mechanistic trace's offline evidence-currency gate and
  per-result snapshot receipt; neither is a signature or clinical validation.
  The v49 digest also binds the `protein_trend` production trace-provider ID;
  this is trace provenance and does not change calculation behavior.
- **Boundary:** default arithmetic agreement and identity mutation are
  implementation evidence only. Helper feature maps and categorical/reason
  branches keep the legacy scorer incomplete, 61 algorithms have no complete
  witness, and no test validates the weights,
  catalog, candidate-set stability, clinical utility, benefit, safety, or
  medical advice.

### Non-numerical executable contracts

- **Run:** `npm run algorithm:contracts`.
- **Checks:** eight fixed synthetic production-API relations covering runtime
  rule support, catalog resolution, source authority, runtime rule execution,
  registry compilation, fact conflict, recommendation orchestration, and the
  local AI adapter. The AI path uses an injected fake client and opens no
  network socket.
- **Expected:** `8/8 checks`, `8/63 direct`, `30/63 combined`, and `33
  uncovered`, plus
  `build/algorithm_executable_contract/latest.json`.
- **Boundary:** software behavior verification only; not numerical, scientific,
  clinical, patient-safety, or regulatory validation.

### Independent cross-runtime relation oracle

- **Run:** `npm run algorithm:contracts:independent`.
- **Checks:** regenerates the Dart contract report, runs six Node tests, and
  executes a Node oracle that imports no production Dart. It independently
  evaluates all eight governed relations, 16 targeted IR mutations, three
  deliberately invalid relations, and six async terminal orderings while
  binding registry, oracle, specification, configuration, source-bundle, and
  report digests.
- **Expected:** `8/8 relations`, `16/16 mutations detected`, `0 survivors`,
  `3/3 invalid relations rejected`, and `6/6 scheduler cases`, plus
  `build/algorithm_contract_independent_oracle/latest.json`.
- **Boundary:** fixed synthetic offline software evidence only. Node does not
  run in the app; agreement and mutation score are not relation truth,
  exhaustive adequacy, numerical/scientific/clinical validation, patient
  safety, or regulatory evidence.

### Lossless mechanistic replay capsule

- **Run:** `npm run mechanistic:lossless-replay`.
- **Checks:** captures three rich synthetic scenarios in Dart, serializes exact
  integer and binary64 scalar wrappers, strictly parses and reconstructs the
  complete ledger/context/composition input, reauthorizes it, then runs an
  independently written Node canonicalizer and mutation suite.
- **Expected:** three Dart vectors, four Node tests, three Node vector checks,
  and no replay-integrity findings; ignored artifacts are written under
  `build/mechanistic_replay_capsule/`.
- **Boundary:** custom JCS-safe engineering replay evidence only; not complete
  RFC 8785 conformance, durable persistence, timezone-rule fidelity,
  scientific or clinical validation.

### Portable-schema migration registry

- **Run:** `npm run portable:schema-migration`.
- **Checks:** produces deterministic v2/v3 packages through Flutter-hosted Dart,
  validates them with frozen version-specific contracts, migrates v2 to v3,
  verifies a privacy-bounded receipt, then runs an independently written Node
  raw-JSON parser, canonicalizer, migrator, and mutation suite.
- **Expected:** two Dart package vectors, one Dart VM numeric-canonicalization
  fixture, eight Dart mutation/invariant checks, five Node tests, two Node
  package-vector checks, one numeric-fixture check, and nine Node
  mutation/invariant checks; ignored evidence is written under
  `build/portable_schema_migration/`.
- **Boundary:** finite synthetic Dart/Node evidence only. It is not complete
  JSON Schema or RFC 8785/JCS conformance, every-platform parser agreement,
  issuer authenticity, durable-import safety, or clinical validation.

### Portable-schema fixed differential campaign

- **Run:** `npm run portable:schema-fuzz`.
- **Checks:** reruns the frozen migration corpus, executes a versioned
  three-seed generator and 31 corpus-level privacy-reviewed synthetic
  regression cases
  through the Dart production preview, then independently parses and classifies
  the same raw JSON in Node. Duplicate/escaped-equivalent members, valid and
  invalid Unicode scalar spellings, malformed/truncated JSON, schema drift and
  depth/width/source-string-token/decoded-string/key/number-token,
  manifest-inventory and integrity-contract guards are included. Compound
  lexical failures also lock production reason-code precedence. Reminder
  activation/consent/presentation, empty/duplicate reminder IDs, Dart
  integer-versus-double lexical types, signed-64-bit numeric canonicalization
  and EOF-before-node-budget precedence are retained. All 47 cases assert
  expected/Dart/Node disposition and reason-code agreement; Node independently
  recomputes source, output and receipt identities. A post-return elapsed
  overrun is blocking, but is not a preemptive timeout.
- **Expected:** 47 cases, 13/13 declared partitions, seven Node fuzz tests, and
  exact disposition/reason/identity agreement; ignored evidence is written
  under `build/portable_schema_fuzz/`.
- **Boundary:** fixed local synthetic Dart/Node evidence only. It is not
  continuous or coverage-guided fuzzing, a hard-kill timeout, cross-runtime
  replay minimization, automatic corpus promotion, complete independent
  semantics for every non-reminder file shape/scalar/reference/record budget,
  dedicated package-byte or pure-node boundary evidence, every-platform
  release-artifact parser evidence, issuer authenticity, durable-import safety,
  or clinical validation.

### Relation-domain production sampling and defective-relation diagnostics

- **Run:** `npm run algorithm:contracts:sampling`.
- **Checks:** regenerates the fixed Dart production anchor, executes paired Dart
  production APIs for 96 applicable source/follow-up samples, and runs ten
  Node tests over a schema-v2 deterministic plan and report. URI revision,
  numeric version, Dart consumer and schema catalog must agree. Four seeds for each of eight
  relations span normal, boundary, missing, malformed, and adversarial
  partitions; the independent Node evaluator checks every production
  observation, while defective relations and IR mutations remain separate.
- **Expected:** `8/8 relations`, `160 cases`, `96/96 production samples`, `624
  production API invocations`, `64 precondition HOLDs`, `32/32 sampled
  mutations detected`, `0 survivors`, and `3/3 defective relations rejected`,
  with a passing locked `96/128 = 3/4` diagnostic-exposure decision,
  plus both sampling reports under `build/algorithm_relation_*_sampling/`.
- **Boundary:** missing and malformed cases are held before production
  execution. The 96/128 diagnostic exposures are incorrect alarms generated by
  deliberately defective synthetic relations so those relations can be
  rejected; they are not a production false-positive rate. Full operator-by-seed mutation strength, differential path
  coverage, operational-profile adequacy, scientific/clinical validity,
  patient safety, and regulatory evidence remain open.

### Administration-dose confirmation receipt and reconciliation

- **Run:** `npm run dose:confirmation`.
- **Checks:** an immutable account-digest-bound local receipt over the exact
  intake, medication, product snapshot, raw expression, parsed AST, structured
  quantity, administration time, grammar identity, expected revision and
  explicit UI action. Synthetic mutations cover cross-account replay, raw,
  product, time and structured-value replacement, malformed digest, future
  schema, stale revision, ambiguous expression and unconfirmed numeric input.
- **Expected:** `pass; 11 synthetic cases; failures=0` plus
  `build/administration_dose_confirmation/latest.{json,md}`.
- **Boundary:** this is local assertion-integrity evidence only. It is not FHIR
  conformance, a prescription, clinician verification, medication-adherence
  evidence, proof of administration, dose-safety evidence or clinical
  validation.

The composed gate executes deterministic tests for the Web reflow and Wasm
hosting evaluators; it does not launch a browser. Run
`npm run wasm:hosting-attestation` only after a fresh
`flutter build web --wasm --no-web-resources-cdn` to produce the local
same-artifact Chromium evidence described in
`docs/WASM_HOSTING_ATTESTATION_RESEARCH_2026-08-27.md`. That browser run does
not approve production Hosting.

### Protocol amendment, deviation and result-transparency ledger

- **Run:** `npm run credibility:transparency`.
- **Checks:** an append-only predecessor chain for the initial protocol,
  pre-result amendment, dataset lock, result publication and attributed
  correction; exact plan/execution/data/code identities; UTC order; actor role,
  authority, review, acknowledgement and result visibility; separately
  enumerable planned, reported and post-hoc outcomes; and eight failure
  mutations covering chain/clock replay, false prospective relabelling,
  correction erasure, omission, review/role escalation, rejected-event hold,
  future schema and revocation.
- **Expected:** `status=mechanicallyObserved`, five retained events, three
  outcomes and eight detected mutation families.
- **Boundary:** this is a synthetic engineering audit trail. It is not a
  clinical-trial registry, GCP conformance, scientific validation, regulatory
  review or clinical-safety evidence.

### Blinded independent replication capsule and discrepancy adjudication

- **Run:** `npm run credibility:replication`.
- **Checks:** a content-addressed capsule excludes expected values and raw
  participant data while binding the accepted protocol, execution, input,
  analysis, code, configuration, source-bundle, environment, dependency,
  command, output-schema, seed and tolerance identities. A separately
  authorized response is finalized before expected-result release; exact
  comparison retains reported, null, failed and adverse outcomes; discrepancy
  classes and append-only adjudication remain separate.
- **Expected:** `status=mechanicallyObserved`, six evidence lanes, five retained
  outcomes and eleven mutation families covering leakage, actor collapse,
  early unblinding, environment/dependency drift, null suppression, tolerance
  switching, response failure, commitment forgery, false agreement, future
  schema and revocation.
- **Boundary:** this is a synthetic role-separation fixture in one local
  process, not external scientific replication, model credibility, clinical
  validation, regulatory review or patient-safety evidence.

### Statistical analysis, error control and uncertainty governance

- **Run:** `npm run credibility:statistics`.
- **Checks:** the exact estimand and intercurrent-event strategies, endpoint
  hierarchy, analysis-set/estimator/missing-data bindings, alpha and Holm
  multiplicity, confidence level, interim and sample-size assumptions,
  complete result states with intervals and denominators, two planned
  same-estimand primary sensitivities, and append-only deviation history.
- **Expected:** `status=mechanicallyObserved`, seven evidence lanes, five
  retained results and twelve mutation families covering estimand and analysis
  drift, alpha/multiplicity failure, interval/p-value inconsistency,
  denominator drift, result suppression, post-result changes, broken history,
  held deviations, future schema and revocation.
- **Boundary:** this is a fixed synthetic statistical-governance fixture. It
  does not create real inference or establish study adequacy, statistical or
  clinical validation, causal effect, regulatory acceptance, benefit or
  patient safety.

### Randomization, allocation concealment and interim-access firewall

- **Run:** `npm run credibility:randomization`.
- **Checks:** the exact statistical package and runtime identities, prospective
  randomization lock, concealed schedule and seed commitments, four opaque
  eligibility-gated assignments, separated generator/enrollment/sponsor/
  statistician/data-manager/committee roles, nine append-only access events,
  emergency-unblinding policy, two alpha-spending boundaries, committee
  conflicts and quorum, one retained recommendation, sponsor response and
  revocation state. Public JSON is checked for seed, salt and future-assignment
  exclusion.
- **Expected:** `status=mechanicallyObserved`, seven evidence lanes, four
  retained assignments and thirteen mutation families covering secret or
  future-assignment exposure, commitment forgery, role collapse, assignment
  replay or ineligibility, sponsor interim exposure, invalid emergency
  unblinding, committee conflict, alpha/boundary drift, repeated looks or
  quorum failure, sponsor override, held access, future schema and revocation.
- **Boundary:** every identity, actor, authority, clock and assignment is a
  fixed synthetic fixture in one local process. Passing is operational-
  governance evidence only; it does not prove allocation concealment,
  committee independence, GCP compliance, study adequacy, clinical validity,
  regulatory acceptance, benefit or patient safety.

### Adaptive-design operating characteristics and decision-rule calibration

- **Run:** `npm run credibility:adaptive`.
- **Checks:** a schema-v1 simulation package bound to the exact governed
  randomization/interim and statistical packages, runtime identities,
  prospectively locked decision code, inherited two-look timing and
  efficacy/futility thresholds, analysis model, scenario catalog and
  secret-free seed manifest. Twelve null, alternative, operational and
  misspecification families retain 700,000 simulations with Type-I error,
  power, MCSE, bias, coverage, stopping/selection and sample-size/duration
  behavior plus five independently restated manufactured decisions.
- **Expected:** `status=mechanicallyObserved`, seven UI/report lanes, 12
  scenarios, 700,000 repetitions, five oracle vectors and 17 detected mutation
  packages covering timing/threshold/identity/seed/scenario/result/arithmetic/
  calibration/history/schema/revocation failures.
- **Boundary:** this is a fixed synthetic normal-approximation fixture and a
  finite scenario grid. Passing does not establish study adequacy, universal
  error control, statistical or clinical validation, GCP compliance,
  regulatory acceptance, benefit, safety or medical advice. ICH E20 remains a
  Step 2 draft and is not treated as implementation authority.

### Bayesian prior, external borrowing conflict and posterior-decision calibration

- **Run:** `npm run credibility:bayesian`.
- **Checks:** a schema-v1 package bound to the exact adaptive-design and
  runtime identities, prospectively locked robust Beta-mixture prior,
  weak-reference prior, likelihood, estimand, missingness strategy, posterior
  success threshold, dynamic discounting, borrowing and ESS caps, secret-free
  seed manifest, and an included/excluded external-evidence ledger. Ten
  no-conflict, mild/severe-conflict, misspecification, sparse, missingness,
  non-adherence, delay and data-quality families retain 400,000 simulations
  with posterior decision probability, borrowing weight, ESS, conflict,
  false-positive probability, power, bias, coverage and MCSE.
- **Expected:** `status=mechanicallyObserved`, eight UI/report lanes, two
  external-evidence decisions, ten scenarios, 400,000 repetitions, five oracle
  vectors, zero borrowing from the low-quality source scenario, monotone
  conflict discounting and 18 detected mutation packages.
- **Boundary:** this is an independently written synthetic robust-mixture and
  normal-approximation fixture, not an implementation of a published EMAP
  method. Passing does not establish Bayesian validity, transportability,
  study adequacy, clinical validity, GCP compliance, regulatory acceptance,
  benefit, safety or medical advice. FDA January 2026 Bayesian guidance remains
  Draft — Not for Implementation.

### Bayesian multi-source transportability and model criticism

- **Run:** `npm run credibility:multisource`.
- **Checks:** a schema-v1 package bound to the exact upstream Bayesian and
  runtime identities; a prospectively frozen seven-source ledger retaining
  included, excluded, duplicate, dependent, unavailable and contradictory
  records; source-specific dependency, overlap, transportability,
  exchangeability and bias assumptions; a total borrowed-ESS cap; prior
  predictive, conjugate SBC, posterior predictive, alternative-prior,
  leave-one-source-out, order-invariance, manufactured negative-control and
  incompatibility checks; and six operating scenarios with 120,000 total
  repetitions and MCSE.
- **Expected:** `status=mechanicallyObserved`, ten UI/report lanes, seven source
  records, twelve criticism checks, six scenario families, 120,000
  repetitions, exact reproduction of four manufactured cases by the
  stdlib-only Python oracle, and 22 detected mutation packages.
- **Boundary:** the search ledger, source records, outcomes and negative control
  are synthetic. The independent oracle covers closed-form manufactured cases,
  not a full Stan/PyMC/R heterogeneous model. Passing cannot establish an
  exhaustive real evidence search, source exchangeability, patient-level
  causal transportability, absence of unmeasured confounding, Bayesian or
  clinical validity, benefit, safety, GCP compliance or regulatory acceptance.

### Target-population causal transportability and doubly robust estimation

- **Run:** `npm run credibility:transportability`.
- **Checks:** a schema-v1 package bound to exact upstream multi-source,
  algorithm-configuration and runtime identities; a prospectively frozen
  target population, eligibility rule, causal contrast, treatment versions,
  comparator, outcome, follow-up, censoring, sampling mechanism, causal graph
  and seven identification assumptions; disjoint synthetic randomized-trial
  and outcome-free target samples; overlap, support, unknown-covariate,
  influential-weight, effective-sample-size and balance diagnostics; trial-only,
  outcome-regression, inverse-odds-of-sampling and augmented inverse-odds
  estimators; weight-truncation sensitivity; seven operating scenarios; and an
  independently written Python stdlib oracle.
- **Expected:** `status=mechanicallyObserved`, nine UI/report lanes, 260 trial
  records, 360 target records, seven scenario families, 70,000 total
  repetitions, four manufactured double-robustness cases, structural-support
  violation held as non-identifiable, exact independent reproduction and 26
  detected mutation packages.
- **Boundary:** every record, response and sampling score is synthetic. The
  operating-characteristic grid is a finite deterministic normal-error
  construction, not patient-data simulation. Double robustness only protects
  the manufactured estimator when at least one declared nuisance model is
  correct; it cannot repair structural non-overlap, unknown covariates or
  unmeasured effect modification. Passing cannot establish identification,
  causal transportability, clinical effect, benefit, safety, GCP compliance or
  regulatory acceptance.

### Target-transportability bias functions, global sensitivity and partial identification

- **Run:** `npm run credibility:transport-sensitivity`.
- **Checks:** a schema-v1 package bound to the exact target-population parent,
  algorithm configuration, registered source bundle and runtime identities; a
  prospectively frozen sign convention and five result-blind sensitivity axes;
  three attributed elicitation records; a complete 2,625-point Cartesian grid
  retaining 2,375 admissible and 250 excluded combinations with reasons; six
  manufactured local cases; recomputed first-order and total-effect global
  sensitivity indices; a partial-identification envelope and decision/null
  tipping regions; eight operating scenarios; and an independently written
  Python stdlib oracle.
- **Expected:** `status=mechanicallyObserved`, ten UI/report lanes, 80,000 total
  repetitions, structural-positivity failure held as non-identifiable,
  incompatible elicitation held with no consensus, exact independent
  reproduction and 30 detected mutation packages.
- **Boundary:** every parameter, elicitation record and simulated outcome is
  synthetic. Bias functions expose how conclusions change under chosen
  violations; they do not learn the unknown bias, prove conditional
  transportability or repair structural nonpositivity. Passing cannot identify
  a clinical effect, establish benefit or safety, or support GCP or regulatory
  acceptance.

### Claim evidence contradiction and synthesis adjudication

- **Run:** `npm run evidence:synthesis`.
- **Checks:** the versioned claim/outcome/measure/PICOS matrix, exact
  evidence-currency source revisions, study-family independence, favorable,
  null, opposing and adverse directions, risk-of-bias, applicability,
  precision, reporting-bias, declared certainty, dual-review artifacts,
  expiry, provider coverage and canonical digests.
- **Expected:** the offline gate passes while truthfully reporting all five
  initial bodies as held for independent review, zero blocked bodies and zero
  integrity failures. A hold is not silently converted into approval.
- **Failure means:** a governed body became contradictory, malformed, stale,
  source-invalid, structurally incomparable, insufficiently reviewed, or
  drifted from its versioned identity.
- **Boundary:** this is evidence-governance support only. It does not calculate
  a clinical evidence grade, establish causality or treatment effect, validate
  a model, replace independent review, or authorize medical advice.

### Store privacy declaration drift contract

- **Run:** `npm run privacy:store`
- **Checks:** the dated repository snapshot against runtime dependencies and
  lock identities, Apple privacy manifests and macOS release entitlements,
  Android source permissions, every literal Dart HTTP(S) host, data-flow
  classifications, and draft Apple/Google store-answer snapshots.
- **Artifact checks:** after an Android build, pass
  `--android-manifest <merged-manifest>`; after an Apple build, pass
  `--apple-bundle <Runner.app>`. `--require-store-approval` deliberately fails
  until a dated App Store Connect/Play Console owner approval is recorded.
- **Boundary:** a passing repository check is not legal advice, a store
  submission, or evidence that current store answers have been approved.

### Open-source influence and license firewall

- **Run:** `npm run open-source:firewall`.
- **Checks:** every GitHub repository cited in the upgrade queue or research
  documentation has an exact inventory entry with a reviewed commit, license
  evidence, concept-only or transfer disposition, and release-boundary
  obligations. Unresolved licenses and `NOASSERTION` fail closed if any local
  transfer or distribution is claimed.
- **Expected:** all checker tests pass and the final line reports the pinned,
  unresolved, and transferred counts.
- **Failure means:** a cited upstream is unreviewed, a pin/license claim drifted,
  an unreviewed vendored directory appeared, or transfer obligations are
  incomplete.
- **Network:** no; live upstream drift is a separate queued gate. **Data:**
  repository metadata only. Passing is not legal advice, an artifact SBOM, or
  proof that every platform NOTICE bundle is complete.

### Built open-source notice evidence

- **Run:** after the local-mode Web release and Android debug APK builds,
  `npm run open-source:android-gradle-graph`, then
  `npm run open-source:release-evidence:test && npm run open-source:release-evidence`.
- **Checks:** the Web `assets/NOTICES` file exists and is non-empty; Android's
  `assets/flutter_assets/NOTICES.Z` decompresses successfully; and its exact
  bytes match Web. The report binds the Web output tree, APK, dependency locks,
  influence inventory and catalog version to SHA-256 evidence. Separate
  CycloneDX 1.7 documents bind each artifact to the Pub dependency graph rooted
  at the app's runtime dependency list. Android also includes the resolved
  `:app` `debugRuntimeClasspath` graph, maps Flutter plugin projects to Pub
  names, and records resolved Gradle artifact hashes. CI uploads the report,
  exported graph, and BOM files.
- **Expected:** thirteen contract tests pass and the final line says the requested
  platforms passed. Production Web preflights emit Web-only evidence.
- **Failure means:** a required bundle is missing or empty, Android gzip is
  invalid, notice content differs between the built Web and Android outputs,
  an Android Gradle component cannot be mapped to a locked package, the
  resolved graph is incomplete, or the versioned evidence contract has drifted.
- **Boundary:** unsigned release-hygiene evidence only. The BOM composition is
  explicitly incomplete: Android buildscript/plugin classpaths, SDK/NDK,
  non-runtime configurations, and other platforms are excluded; target-binary
  inclusion is not asserted; every component's license remains `NOASSERTION`.
  This does not prove license-text completeness or legal approval.

### Committed goldens (cross-commit drift)

`test/goldens/` holds **committed expected output** for the deterministic
generators. Every other determinism check in this repo builds an artifact twice
in the same process and compares the two copies — that proves self-consistency,
not stability across commits. The goldens are the baseline that makes a
behaviour change at commit N show up as a reviewable diff against commit N-1.

- **Run:** `flutter test test/goldens_test.dart` (also inside `verify:all`).
- **Refresh (deliberately):** `UPDATE_GOLDENS=1 flutter test test/goldens_test.dart`,
  then **read the diff before committing it**. Regenerating a golden without
  reading it discards exactly the signal it exists to preserve.
- A missing golden fails rather than being created silently: an absent baseline
  must never read as a pass.

## Core checks

### `flutter analyze`
- **Checks:** static analysis of the Dart/Flutter codebase.
- **Expected:** `No issues found!`
- **Failure means:** a static error/warning was introduced.
- **Network:** no. **Data:** n/a.

### `flutter test --concurrency=1`
- **Checks:** the full unit/widget test suite (rules, importers, mechanistic
  engine, metadata, evidence views, safety-copy guards).
- **Expected:** `All tests passed!`
- **Failure means:** a regression in deterministic behavior or a safety guard.
- **Network:** no. **Data:** synthetic only.

### `dart run tool/run_mechanistic_replay.dart`  (or `npm run mechanistic:replay`)
- **Checks:** the deterministic mechanistic replay suite (41 synthetic
  scenarios) and a banned-prescriptive-phrase scan over every emission.
- **Expected:** `Mechanistic replay: 41/41 scenarios passed.` and report files
  under `build/mechanistic_replay/latest.{json,md}`.
- **Failure means:** a scenario's modeled output changed unexpectedly, or banned
  copy leaked. **This is synthetic regression testing, not clinical validation.**
- **Network:** no. **Data:** synthetic only.

### `npm run public:preflight`
- **Checks:** public-positioning + banned-claim + boundary guardrails across
  README and public docs.
- **Expected:** `"pass": true` with `BLOCKER: 0`.
- **Failure means:** a public doc drifted into an unsafe claim or dropped a
  required boundary phrase.
- **Network:** no. **Data:** n/a.

### `node tool/firestore_rules_contract_check.mjs`  (or `npm run rules:contract`)
- **Checks:** Firestore security-rules contract (owner-scoped, deny-by-default,
  admin/importer write gates).
- **Expected:** `Firestore rules contract passed: 13/13`.
- **Failure means:** a rule regressed against the contract.
- **Network:** no. **Data:** n/a.

## Source-quality report (optional)

### `dart run tool/run_source_quality_perturbation_report.dart`  (or `npm run source:quality`)
- **Checks:** how candidate scoring moves when **only** source/provenance
  quality changes, holding the meal/conflict/model input constant.
- **Expected:** `Source-quality perturbation report: 13 rows.` and report files
  under `build/source_quality_perturbation/latest.{json,md}`.
- **Failure means:** a provenance/source-quality invariant changed (e.g.
  official-in-jurisdiction no longer ≥ synthetic equivalent, or conflict overlap
  no longer dominant).
- **Network:** no. **Data:** synthetic only.
- **Note:** this is a deterministic educational analysis artifact, **not a
  clinical dashboard** and not user-facing advice.

## Release snapshot + demo walkthrough (optional, composed)

These compose the artifacts above into reviewable summaries. They are pure
generators — they parse existing reports (and accept injected counts) rather than
re-running slow commands — and report `missing_artifact` instead of fabricating
results.

### Recommended reviewer order

1. `npm run recommend:replay` (or `flutter test
   test/local_ai_replay_report_test.dart`) — regenerates the deterministic
   Local-AI scenario replay artifact; both entry points produce byte-identical
   files. Proves the Local-AI candidate-set invariant held over the five
   synthetic archetypes; does NOT prove model quality or real-care behaviour.
2. `npm run release:snapshot` — composes all artifacts into one evidence
   summary. Proves which artifacts exist and what they reported; does NOT
   re-run any check.
3. Inspect `build/release_snapshot/latest.md` and `npm run evidence:graph` —
   shows how the artifacts relate (including the Local-AI replay node). Proves
   local traceability only; NOT FHIR/W3C-PROV conformance and not clinical
   validation.
4. `npm run public:preflight` and `npm run privacy:preflight` — repo-hygiene
   and copy-boundary gates. Prove the public tree carries no banned claims or
   sensitive artifacts; do NOT prove security or regulatory compliance.

All artifacts are synthetic/demo data only and none of them make the prototype
calibrated for real care.

### `dart run tool/run_release_snapshot.dart`  (or `npm run release:snapshot`)
- **Checks:** composes one release-evidence snapshot from
  `build/mechanistic_replay/latest.json`,
  `build/source_quality_perturbation/latest.json`,
  `build/public_release_preflight/latest.json`, and
  `build/recommendation_scenario_replay/latest.json` (generate the last one with
  `npm run recommend:replay`); analyze/test/firestore
  results may be injected via flags (e.g. `--analyze=clean --test-count=460
  --firestore=13/13`).
- **Expected:** `build/release_snapshot/latest.{json,md}` with a per-check table;
  any absent input shows `missing_artifact`. The Local-AI scenario replay row
  also surfaces the dataset version, case count, candidate-set invariant,
  gate-reason visibility for blocked scenarios, and the synthetic/non-advice
  scope declaration in `recommendation_scenario_replay_detail`.
- **Failure means:** an underlying artifact is missing/malformed (recorded
  in-band, not fabricated). The tool itself exits 0 — it is an evidence summary,
  not a gate.
- **Network:** no. **Data:** synthetic only. **Not clinical validation.**

### `dart run tool/generate_public_demo_walkthrough.dart`  (or `npm run demo:walkthrough`)
- **Checks:** composes a reviewer walkthrough from the replay, source-quality,
  release-snapshot, and a synthetic EvidenceTraceBundle sample.
- **Expected:** `build/public_demo_walkthrough/latest.{md,json}` with synthetic
  input / source-quality / missingness / replay / evidence-bundle summaries plus
  the safety boundary and a "what this does not prove" section; absent inputs show
  `missing_artifact`.
- **Failure means:** a consumed artifact is missing (recorded, not fabricated).
- **Network:** no. **Data:** synthetic only. **No advice; not a clinical
  dashboard.**

### `dart run tool/generate_evidence_graph.dart`  (or `npm run evidence:graph`)
- **Checks:** composes a local evidence/provenance **graph** (nodes + edges) from
  the replay, source-quality, release-snapshot artifacts and a synthetic
  EvidenceTraceBundle sample.
- **Expected:** `build/evidence_graph/latest.{json,mmd,md}`; absent inputs show
  nodes with `status: missing_artifact`.
- **Failure means:** a consumed artifact is missing (recorded as a
  `missing_artifact` node, not fabricated).
- **Network:** no. **Data:** synthetic only. **Local graph — not a FHIR
  Provenance resource, not W3C PROV, not a patient record.** See
  `docs/EVIDENCE_GRAPH.md`.

### `dart run tool/run_synthetic_scenario_fuzzer.dart`  (or `npm run scenario:fuzz`)
- **Checks:** deterministic synthetic boundary cases (dosage, nutrient
  missingness, release-type, source-quality, window/ranking, safety-copy/no-PHI)
  evaluated against the existing gates with real code.
- **Expected:** `build/synthetic_scenario_fuzzer/latest.{json,md}` and
  `N/N cases passed`. Supports `--seed`, `--case-count`, `--family`.
- **Failure means:** a boundary regression — e.g. a unitless dose validates,
  missing nutrient treated as zero, tier ordering broken, or banned/advice copy
  leaked. **Exits non-zero** on a must-pass invariant failure.
- **Network:** no. **Data:** synthetic only. **Stress testing, not clinical
  validation or patient simulation.** See `docs/SYNTHETIC_SCENARIO_FUZZER.md`.

### `dart run tool/run_localization_safety_lint.dart`  (or `npm run localization:lint`)
- **Checks:** user-visible copy + localization surfaces for missing safety
  boundaries, missing evidence/limitation wording, placeholder problems, and
  unsafe prescriptive/overconfident phrases (en/zh/fr/ja). Lints the safe-copy
  template registry; supports `--strict`.
- **Expected:** `build/localization_safety_lint/latest.{json,md}` with
  info/warn/blocker counts and `pass=true` (0 blockers) for the safe registry.
- **Failure means:** unsafe localized copy (or, in strict mode, missing required
  coverage/placeholder). **Exits non-zero** on a blocker.
- **Network:** no. **Data:** synthetic/template only. **Copy-safety lint — not a
  translation-quality or clinical-safety guarantee; no LLM.** See
  `docs/LOCALIZATION_SAFETY_LINT.md`.

### `dart run tool/run_local_privacy_preflight.dart`  (or `npm run privacy:preflight`)
- **Checks:** git-tracked files for secrets (private keys, service accounts,
  tokens, api-key/password assignments, DB-URL credentials), PHI-like fields,
  absolute local machine paths, raw private export filenames, real-health
  narratives, and generated/local directories. Complements `public:preflight`;
  blocks concrete keys in tracked Firebase client config, honors the
  safety-policy allowlist, and supports
  `--strict`.
- **Expected:** `build/local_privacy_preflight/latest.{json,md}` with
  info/warn/blocker counts and `pass=true` (0 blockers) for the repo.
- **Failure means:** a likely secret/PHI/raw-export leak (or, in strict mode, a
  warn). **Exits non-zero** on a blocker.
- **Network:** no. **Data:** synthetic/demo only. **Repo-hygiene / privacy-risk
  preflight — NOT HIPAA/GDPR/PIPEDA compliance, not a legal certification, not
  clinical validation, and does not prove the app is secure.** See
  `docs/LOCAL_PRIVACY_PREFLIGHT.md`.

### `dart run tool/run_source_access_contract_check.dart`  (or `npm run source:access`)
- **Checks:** tracked source references against the machine-readable source
  access contract: fixture/live/production status, API-key/account constraints,
  license/legal-review flags, and mechanism-evidence vs identity/coding roles.
- **Expected:** `build/source_access_contract/latest.{json,md}` with
  `pass=true` and zero blockers.
- **Failure means:** a source ID or usage role needs explicit governance
  metadata. **This is release hygiene, not legal advice, license clearance,
  production-readiness certification, or clinical validation.**
- **Network:** no. **Data:** metadata only. See
  `docs/SOURCE_ACCESS_CONTRACT.md`.

### `dart run tool/run_input_quality_demo.dart`  (or `npm run input:quality`)
- **Checks:** runs the InputQualityGate over eight deterministic synthetic
  cases (complete context, unitless dose, missing protein, true 0 g protein,
  missing window, unknown release type, synthetic vs official source, imputed
  provenance) and reports per-dimension context-completeness status.
- **Expected:** `build/input_quality/latest.{json,md}` with one row per case
  (overall status, backward-compatible trace-eligibility field, blocker count).
- **Failure means:** a context-completeness invariant changed — e.g. a unitless
  dose validated, missing nutrient treated as zero, product strength rescued a
  missing dose, or synthetic source reached official confidence.
- **Network:** no. **Data:** synthetic only. **Input/context-completeness
  assessment only — not medical advice, not a recommendation engine, and not
  clinically calibrated.** See `docs/INPUT_QUALITY_GATE.md`.

### `dart run tool/run_catalog_resolution_demo.dart`  (or `npm run catalog:resolve`)
- **Checks:** runs the CatalogResolutionEngine over fixed synthetic queries
  (milk tea, 奶茶, levodopa, Sinemet, carbidopa levodopa 25/100, levodopa CR,
  unknown food, unknown drug) against a small synthetic catalog and reports the
  ranked candidates, confidence band, match type, and status per query.
- **Expected:** `build/catalog_resolution/latest.{json,md}` with one row per
  query; exact/brand/localized matches resolve high, ambiguous queries are
  `ambiguous`, and unknown queries are `unresolved`.
- **Failure means:** a resolution invariant changed — e.g. an ambiguous query
  became overconfident `resolved`, a dose-like token was converted into a
  candidate strength, or a synthetic source was treated as official.
- **Network:** no. **Data:** synthetic only. **Returns candidates + uncertainty
  — not a recommendation, not medical advice, infers no user dose, and is not
  clinically calibrated.** See `docs/CATALOG_RESOLUTION_ENGINE.md`.

### `dart run tool/run_source_version_drift_check.dart`  (or `npm run source:drift`)
- **Checks:** collects source/version metadata records from the source-access
  registry, model-assumption registry, bibliography, source adapters, and build
  artifacts, then flags missing version/date metadata, stale/undated artifacts,
  registry/bibliography mismatches, fixture-vs-production status conflicts,
  deprecated-source usage, and assumption-registry drift. Supports `--strict`,
  `--now=ISO`, `--staleness-days=N`.
- **Expected:** `build/source_version_drift/latest.{json,md}` with record count
  and info/warn/blocker counts; `pass=true` (0 blocker) for the repo.
- **Failure means:** a provenance/version drift that should fail release hygiene
  (e.g. a fixture-only source claimed production-ready). **Exits non-zero** on a
  blocker.
- **Network:** no. **Data:** local files only. **Provenance / release-hygiene
  only — does not fetch or update live sources, is not legal/license clearance,
  not clinical validation, and does not prove medical correctness.** See
  `docs/SOURCE_VERSION_DRIFT_CHECK.md`.

### `dart run tool/run_contribution_safety_router.dart`  (or `npm run contribution:route`)
- **Checks:** classifies the working-tree diff (or a `--base`/`--head` range)
  into review-risk categories, suggests labels, and generates a change-aware
  reviewer checklist with the commands to run; flags possible medical-claim,
  clinical-advice, secret, PHI, and source-access risks (allowlisting detector
  files so it does not flag its own rules).
- **Expected:** `build/contribution_safety_router/latest.{json,md}` with the
  risk level, categories, labels, findings, and checklist; `pass=true` (0
  blocker) for a clean diff.
- **Failure means:** a non-allowlisted change matched a clinical-advice /
  medical-claim / secret / PHI keyword group. **Exits non-zero** on a blocker.
- **Network:** no. **Data:** local diff only. **Deterministic
  repository-governance routing — not AI code review, not a medical/legal
  reviewer, and does not replace human review.** See
  `docs/CONTRIBUTION_SAFETY_ROUTER.md`.

### `dart run tool/run_explanation_copy_compile.dart`  (or `npm run copy:compile`)
- **Checks:** renders + validates every `SafeCopyTemplate` in the registry —
  placeholder binding, required safety/evidence terms, banned prescriptive
  phrases (reusing the localization:lint families), and source/limitation/
  not-advice requirements.
- **Expected:** `build/explanation_copy/latest.{json,md}` with the compiled copy
  and `pass=true` (0 blocker) for the shipped registry.
- **Failure means:** a template would render unsafe/incomplete copy (banned
  phrase, missing safety term, unresolved placeholder, or unmet requirement).
  **Exits non-zero** on a blocker.
- **Network:** no. **Data:** synthetic/template only. **Copy compilation +
  validation only — no medical advice, no clinical-calibration claim, and not
  wired into the UI or scoring.** See `docs/EXPLANATION_COPY_COMPILER.md`.

## What these checks do and do not establish

- **They establish:** deterministic behavior, preserved provenance/missingness,
  intact safety boundaries, and that public docs stay within the educational
  positioning.
- **They do not establish:** any clinical accuracy, patient-outcome validity, or
  regulatory approval. The model is **not clinically calibrated**, importer
  adapters are fixture-validated (not live production ingestion), and all data is
  synthetic/demo.

See `docs/EVIDENCE_AND_TRACEABILITY_DEMO_GUIDE.md` for a guided walkthrough and
`docs/CAPABILITY_MATRIX.md` for the implemented-vs-future-work summary.
