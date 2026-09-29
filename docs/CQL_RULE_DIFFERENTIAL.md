# Independent CQL rule comparison

`npm run cql:diff` runs fixed FHIR R4 retrieval checks for Condition existence
and status, Observation, MedicationStatement, MedicationRequest,
MedicationDispense, MedicationAdministration, and AllergyIntolerance, plus a
synthetic Questionnaire/PlanDefinition artifact-binding check. It then compares
the current Dart `RuntimeRuleEngine` with four CQL execution paths.
Pinned `@cqframework/cql@5.3.0` translates manufactured CQL to ELM; pinned
`cql-execution@3.3.2` executes that same ELM; Google CQL
`v0.0.3-0.20260814184421-b9169ccd54a3` parses and evaluates authored source;
and CQF CQL `org.cqframework:engine@5.3.0` translates and evaluates it through
the JVM variants. Google CQL contributes an independent parser/interpreter
path rather than another run of CQF-generated ELM. CQF JavaScript and JVM share
an upstream implementation family, so JVM agreement is platform-parity
evidence, not an independent CQL engine.

The schema-v24 implementation is designed to report the four literal-comparison identities,
three-valued outcomes, diagnostic parity, runtime agreement, and corpus digest.
It also records separate Condition existence and nine-case Condition status
comparisons, Observation and terminology probes, ten-case MedicationStatement,
18-case MedicationRequest, 11-case MedicationDispense, nine-case
MedicationAdministration, and six-case AllergyIntolerance differentials. These
FHIR status/retrieval checks use Google CQL, the pinned CQF JavaScript
translator/executor, and CQF JVM. The six-case Observation membership
projection emits an information-only card for its fixed unanimous-true case,
returns four no-guidance responses for unanimous-false cases, and withholds a
card with `engine_disagreement` for the pinned `Coding.version` provider
difference. This fail-closed development projection is not terminology
conformance evidence.

The schema-v8 artifact subreport adds both PlanDefinition applicability
conditions bound to the exact versioned primary Library and resolved to Boolean
CQL definitions by title. It derives six local scenarios from the supported
`exists([Condition])` and `exists([Observation])` definitions and their
Patient-scoped data requirements. For each resource type, a matching resource
returns true, absence returns false, and a foreign-subject resource returns
false after filtering. It also evaluates all nine combinations of matching,
absent, and foreign-subject Condition and Observation resources. Each row
retains both CQL Boolean results and checks combined action applicability against
the FHIR R4 rule that same-kind `PlanDefinition.action.condition` entries
combine with AND semantics. This is a local synthetic combination check, not a
PlanDefinition execution engine. Unsupported expression shapes fail closed.
The report emits only bounded condition titles, resource types, scenario labels,
Boolean outcomes and drop counts; it omits CQL source, Bundle content, Patient
IDs and scenario resource IDs. See the [FHIR R4 PlanDefinition condition definition](https://hl7.org/fhir/R4/plandefinition-definitions.html).

Schema-v16 added the CQF JVM MedicationDispense path, schema-v17 added the
three-path MedicationAdministration comparison, schema-v18 added
AllergyIntolerance, schema-v19 added CQF JavaScript to Condition existence,
schema-v20 added all fixed Condition clinicalStatus and verificationStatus
predicates to the three FHIR retrieval paths, and schema-v21 adds a fixed
PlanDefinition-to-CQL Library binding. The complete schema-v21 gate passed on
2026-09-26 with Google CQL Go 1.26.8, direct Dart VM execution, and Java 17
compilation against cached CQF dependencies. Temporary direct JVM and Dart VM
launchers were needed because the sandbox could not start the official Gradle
lock service or Dart package-hook launcher; the official Gradle task remains
unverified. Schema-v22 added PlanDefinition-derived applicability scenarios to
that artifact-binding report; schema-v23 adds a second bound existence
condition and six generated outcomes across Condition and Observation.
Schema-v24 adds the nine-row paired Condition/Observation matrix and validates
the same-kind AND outcome for the action. The fixed `Coding.version` mismatch
still withholds its card. The prior schema-v23 `cql:diff` run exited 0 with
status `passed`, with all six artifact scenarios matching and both foreign
resources filtered. Schema-v24 is implemented but has not completed its full
gate in this environment: `npm run --silent cql:diff` stops when the official
Gradle wrapper cannot create its cache lock file (`Operation not permitted`),
and the current shell has no Go or `gofmt` executable, so the updated Google CQL
Go package test and composite report remain unverified. These
are synthetic development results, not terminology, FHIR/CQL conformance, or
clinical evidence. The binding follows the [HL7 CPG Computable Plan Definition
profile](https://hl7.org/fhir/uv/cpg/StructureDefinition-cpg-computableplandefinition.html)
and the FHIR R4 [`text/cql` expression language](https://hl7.org/fhir/R4/valueset-expression-language.html).

The nine fixed cases cover true, false and unknown comparison results; a
missing dose and missing timestamp; values just below and at a 0.2 g boundary
against a mg/day input; an inclusive 60-minute boundary and a 61-minute case;
and an intentionally unsupported unit. The run currently yields six direct
matches. For the two missing-input cases, the Dart candidate matcher returns
false while `RuntimeRuleSupport` marks the relevant field for the service's
`REQUIRE_REVIEW` path. The low-level unsupported-unit witness returns no Dart
match while CQL propagates an unknown. This witness bypasses the versioned rule
case contract, which rejects unsupported dose units before a pack can be
approved; it is retained to make the engine boundary visible.

The CQL unit vector expresses the narrow g-to-mg threshold conversion as CQL
arithmetic. It does not test a general UCUM service. The CQL date expression
reverses the local rule engine's `left - right` timestamps because CQL's
`difference in minutes between A and B` is `B - A`. The comparison is
deterministic and uses manufactured literals only.

All four CQL paths agree on the nine fixed manufactured literal outcomes and
authored `Errors`/`Warnings` lists. `cql-execution` consumes ELM from the primary
translator, so it does not independently validate CQL-to-ELM translation.
Google CQL parses the source independently, but is explicitly experimental,
supports only a subset of CQL, and has no ELM import/export. The CQF JVM path
uses the same upstream implementation family as the JavaScript path; it checks
cross-platform packaging and execution, not implementation independence. The
fixed corpus does not exercise FHIR retrieval. A separate, strictly bounded
probe evaluates `exists([Condition])` in FHIR 4.0.1 Patient context against
three code-owned local synthetic Bundles through Google CQL, the pinned CQF
JavaScript translator/executor with its FHIR Patient source, and the CQF JVM
FHIR parser/engine. The fixtures cover a matching Condition, no Condition, and
a Condition whose `subject` points to a different synthetic Patient. Each
local harness scopes Conditions to the declared Patient context before
evaluation; all three Boolean outcomes agree across the three paths, for
**3/3** three-runtime outcome parity. Google CQL and CQF JVM retain their
existing **3/3** diagnostic parity. The CQF JavaScript adapter drops the one
foreign-subject Condition before local evaluation. The case-level report
retains only outcomes and the fixture digest; Bundle contents are not emitted.
This probe does not run through the Dart runtime and does not exercise
terminology or an external provider. Its parity-checked results now also pass through a
separate schema-v1 CDS Hooks projection: the matching fixture returns one
`info` card, while the patient-only and foreign-subject cases return empty
`cards` arrays with the fixed `criterion_not_met` response warning. Namespaced
metadata retains only case/version/engine identities, outcomes, source
references, and the corpus digest; patient IDs, resource IDs and Bundle content
are omitted. CDS Hooks v2 permits an empty cards array when no guidance is
available and requires a short card summary; this local fixed-corpus mapping is
not a service implementation or clinical recommendation
([CDS Hooks v2.0.1](https://cds-hooks.hl7.org/STU2/)). The JavaScript executor's documented partial CQL support
and `Number` precision limits also apply. This is not general CQL or FHIR
conformance evidence.

A separate ten-case MedicationStatement probe evaluates
`exists([MedicationStatement])` and exact status-value predicates for all eight
FHIR R4 codes: `active`, `completed`, `entered-in-error`, `intended`, `stopped`,
`unknown`, `not-taken`, and `on-hold`. It runs through the Google CQL Go parser,
the pinned CQF JavaScript translator/executor pair, and the CQF JVM engine; all
three return the same nine Boolean outcomes for each case. The corpus also
includes no statement and a foreign-subject statement; each local retriever
drops the foreign resource outside the declared Patient context. The fixtures
use only a text-only synthetic medication placeholder, with no coded product,
dose, terminology request, network access, or real patient data. The report
emits case labels, Boolean outcomes, engine identities and a fixture digest,
never Patient IDs or Bundle contents. This narrow status/retrieval check is not
MedicationAdministration evidence, medication reconciliation, clinical
decision support, or general FHIR/CQL conformance ([FHIR R4 MedicationStatement](https://hl7.org/fhir/R4/medicationstatement.html)).

A separate 18-case FHIR R4 MedicationRequest probe evaluates request existence,
the eight R4 `status` codes (`active`, `on-hold`, `cancelled`, `completed`,
`entered-in-error`, `stopped`, `draft`, and `unknown`), and the eight distinct
`intent` codes (`proposal`, `plan`, `order`, `original-order`, `reflex-order`,
`filler-order`, `instance-order`, and `option`). The cases cover one value per
predicate, no request, and a foreign-subject request. Google CQL Go, the pinned
CQF JavaScript path, and CQF JVM each return the expected Boolean map in all 18
cases and filter the foreign request from the declared Patient context. These
are separate status and intent checks; a MedicationRequest is a request/order,
not evidence that medication was dispensed or administered. The local report
contains only case labels, Boolean outcomes, engine identities, and a fixture
digest. This fixed synthetic retrieval comparison is not prescription
validation, medication reconciliation, clinical decision support, or general
FHIR/CQL conformance ([FHIR R4 MedicationRequest](https://hl7.org/fhir/R4/medicationrequest.html)).

A separate 11-case FHIR R4 MedicationDispense probe evaluates resource presence
and exact `status` predicates for all nine R4 status codes: `preparation`,
`in-progress`, `cancelled`, `on-hold`, `completed`, `entered-in-error`,
`stopped`, `declined`, and `unknown`. Its fixed synthetic Patient-context
Bundles also include an empty case and a foreign-subject dispense. Google CQL
Go, the pinned CQF JavaScript translator/executor path, and CQF JVM must each
match all expected Boolean outcomes and drop the foreign-subject resource. The
JavaScript and JVM paths use the same CQF implementation family, so this adds a
platform check rather than an independent CQL engine. The report contains only
case labels, Boolean outcomes, runtime identities, and the fixture digest. This
is a bounded resource-retrieval comparison: a dispense
record describes a supply event and does not prove pickup, medication use,
adherence, dispensing accuracy, or clinical decision support. It is not a
general FHIR/CQL conformance claim ([FHIR R4 MedicationDispense](https://hl7.org/fhir/R4/medicationdispense.html)).

The same gate also validates a separate, fixed synthetic artifact Bundle with
one FHIR R4 PlanDefinition, one Questionnaire, and two embedded Libraries. It checks that the
Questionnaire's `cqf-library` canonical pins the exact primary
`Library.url|version`, that each Library contains one canonical-Base64
`text/cql` attachment, and that the CQL library name/version matches its FHIR
Library identity. The primary Library's `relatedArtifact` must declare both
the exact included Library version and the FHIR 4.0.1 ModelInfo dependency;
the included Library declares that same model dependency. Google CQL parses
both sources together, resolves the exact `include` version, and evaluates the
two primary definitions through an alias into the included library. The primary
library retains its fixed `exists([Condition])` expression and now adds
`exists([Observation])`, with matching output parameter and data-requirement
bindings. The local harness code scopes the placeholder Observation to the
same synthetic Patient context as the Condition. A separate six-case
Go-backed Observation/ValueSet differential now runs through the pinned Google
CQL interpreter and is reported independently from the artifact binding. The
SDC `launchContext` must
identify Patient, and each item `initialExpression` definition title must
resolve. Each FHIR Library's `parameter` entries must map all of that library's
top-level CQL definitions exactly once, with the same name, `use=out`, optional
singleton cardinality (`min=0`, `max=1`), and FHIR `boolean` type. The checker
also confirms that each parsed evaluation result is Boolean.

The PlanDefinition pins that same primary Library by its exact versioned
canonical. Its two `applicability` conditions use `text/cql` and name the
fixed `Synthetic Condition Present` and `Synthetic Observation Present`
definitions; Google CQL must resolve and evaluate both as Booleans. The
schema-v8 artifact report records
the plan id, library canonical, both resolved condition titles, six
per-condition outcomes, and nine combined action outcomes without emitting CQL
or FHIR resource content. This verifies only the local binding and bounded
scenario shapes. HL7's
[CPG Computable Plan Definition](https://hl7.org/fhir/uv/cpg/StructureDefinition-cpg-computableplandefinition.html)
profile describes `PlanDefinition.library` as the logic used by the plan and
`action.condition.expression` as Boolean-valued. FHIR R4 combines multiple
conditions of the same kind with AND semantics. FHIR R4's
[`text/cql` expression code](https://hl7.org/fhir/R4/valueset-expression-language.html)
defines the language used by the synthetic condition.

The checker parses each library's CQL model and maps every fixed retrieve to
`Library.dataRequirement`: FHIR resource type to `type`, the pinned FHIR
ModelInfo template identifier to `profile`, and the CQL Patient context to
`subjectCodeableConcept`. Both libraries require Patient; the primary also
requires Condition and Observation. The schema-v8 artifact report retains
dependency, output-parameter and data-requirement counts, context, linked titles,
six per-condition outcomes, nine combined applicability outcomes, and the
fixture digest, never source or resource content. Missing, duplicate, mistyped or
unmatched requirements, unsupported resource types or terminology filters,
missing/duplicate/mistyped output parameters, unknown fields, malformed CQL,
or version drift fail closed.

This transfers the authoring relationship described in the [HL7 Common CQL
Assets for FHIR authoring guide](https://hl7.org/fhir/us/cql/2.0.0/en/authoring.html),
its [relatedArtifact dependency contract](https://hl7.org/fhir/uv/cql/conformance.html),
and the SDC [Patient launch-context](https://hl7.org/fhir/uv/sdc/en/StructureDefinition-sdc-questionnaire-launchContext.html)
and [initial-expression](https://hl7.org/fhir/uv/sdc/en/StructureDefinition-sdc-questionnaire-initialExpression.html)
extensions. The fixed FHIR ModelInfo canonical is backed by Google's pinned
local FHIR 4.0.1 model. It is not general FHIR validation: it does not fetch
external libraries, evaluate patient data, invoke a remote `$populate`, use an endpoint, or validate
clinical meaning. The CQL parser is an experimental, partial development tool;
the fixture does not establish CQL/FHIR conformance or clinical correctness.

`npm run cql:sdc:population-preview:test` verifies a bounded local subset of
the SDC `Questionnaire/$populate` operation, and
`npm run cql:sdc:population-preview` emits its schema-v3 report. It accepts one
FHIR `Parameters` input naming the exact pinned Questionnaire by versioned
canonical URI, exact `Reference`, or identical resource, compiles both embedded Libraries with
`@cqframework/cql@5.3.0`, and returns the FHIR R4
operation-output shape (`Parameters.parameter[name=response].resource`) with an
in-progress `QuestionnaireResponse`, the exact Questionnaire canonical, and
the two synthetic Boolean answers. It supplies no Patient resource, omits the
response subject, and makes no network request. Subject, context, data,
additional parameters, and modified Questionnaire resources fail closed. HL7 SDC defines `$populate` as
an operation returning a `QuestionnaireResponse`; its populated answers
require user review, and an empty CQL/FHIRPath result for a Boolean item is not
equivalent to `false` ([SDC form population](https://hl7.org/fhir/uv/sdc/STU4/en/populate.html)).
This is a local fixed-fixture operation subset, not a remote operation or a
general SDC/FHIR conformance test. The mapper keeps a null/empty expression
unanswered and preserves explicit `false` as `valueBoolean=false`. Its
`Parameters.parameter[name=response]` envelope follows the pinned [SDC
`$populate` operation definition](https://hl7.org/fhir/uv/sdc/STU4/en/OperationDefinition-Questionnaire-populate.html).

The separate `npm run cql:fhir:observation` route compiles
`exists([Observation])` and a code-in-ValueSet retrieve with the pinned FHIR
4.0.1 ModelInfo shipped by `cql-exec-fhir@2.1.6`. It evaluates six fixed local
synthetic Bundles with `cql-execution@3.3.2` and that package's R4
`PatientSource`: matching, absent, and foreign-subject Observations; a
non-member code; a code in a different system; and a matching code whose
`Coding.version` differs from the local expansion. The ValueSet is resolved
only through an in-memory synthetic `CodeService`; no terminology package,
server, VSAC, credential, or network is used. The local harness removes
foreign-subject Observations before loading each Bundle. A regression test
confirms that the upstream `PatientSource` itself returns a foreign-subject
Observation when given the unscoped Bundle, so the adapter does not claim
patient isolation. The report includes only case outcomes, the
foreign-resource removal count, and source/fixture digests; it excludes Patient
and resource IDs, clinical codes, and Bundle content. The pinned JavaScript
runtime matches code and system but does not compare `Coding.version`; the
version-mismatch case therefore reports runtime membership `true` alongside
the fixture's version-aware test expectation of `false`. This is a recorded runtime limitation,
not terminology conformance. It remains a local synthetic smoke test, not
FHIR/CQL terminology conformance, clinical validation, or an external service
call.

The companion `npm run cql:fhir:observation:jvm` check runs the same six
strictly validated bundles through CQF JVM CQL 5.3.0, its pinned FHIR 4.0.1
model, and a fixed in-memory `TerminologyProvider`. It evaluates both direct
CQL `Code in ValueSet` and a ValueSet-filtered Observation retrieve. A bounded
local retrieve provider scopes by the fixed Patient context and delegates
membership to the version-aware synthetic expansion. The JavaScript result is
`true` for the `v2` mismatch while the JVM's configured provider returns
`false`; the other five membership outcomes agree. This records a difference
between these two local provider paths, not a CQL/FHIR terminology standard or
conformance claim. The JVM report uses only case labels and Boolean outcomes.
It does not establish that the pinned engine extracts arbitrary FHIR Coding
values or that either runtime is suitable for clinical decisions.

The Go-backed Google CQL route runs the same six Observation fixtures through
the pinned parser/interpreter, Google's local FHIR 4.0.1 model, a fixed local
one-code ValueSet expansion, and a narrow subject-reference filter. Its Boolean
outcomes and membership results match JavaScript for all six cases; its
membership results match the CQF JVM provider for five. For the fixed
`Coding.version: v2` case, Go and JavaScript report membership while CQF JVM
returns non-membership. Inspection of the pinned Go interpreter shows that it
does not pass FHIR Coding.version to its terminology provider. This records
behavior of these pinned provider paths, not a normative terminology rule.
The Go subreport and combined schema-v1 cross-runtime summary contain case
labels, Boolean outcomes, and fixture digests without resource content. This is
a development-only comparison, not a network integration, conformance check,
clinical validation, or application route.

The Google local Bundle path uses Google's FhirProto Go module
[`github.com/google/fhir/go@v0.7.4`](https://github.com/google/fhir/commit/31c3b614b7bf203c9b1d53306688b3bd6984e11d), pinned in the Go lock files and classified as a development-only Apache-2.0 influence. It is not an application dependency. These fixed probes do not validate FHIR profiles, arbitrary patient-context isolation, or terminology conformance.
The CQF path uses `org.cqframework:engine-fhir:5.3.0` and
`org.cqframework:quick:5.3.0`, pinned through the same reviewed CQF CQL
5.3.0 source commit and development Gradle lock. The quick module supplies the
FHIR 4.0.1 model info used by the local parser. These artifacts stay outside
the app dependency graph and release outputs.

The schema-v2 corpus also declares expected response-level CQL `Errors` and
`Warnings` lists. The CQF JavaScript path evaluates both lists, their counts,
and their first values; `cql-execution` checks the lists over the same ELM, and
Google CQL and CQF JVM evaluate the authored lists in their separate paths. A true result produces one
information-only card; false and unknown results produce an empty `cards`
array. Synthetic false cases carry the warning code `criterion_not_met`, while
unknown cases carry the error code `evaluation_indeterminate` in the strictly
namespaced `org.parkinsum.cql-differential-response` response extension. This
exercises the [AHRQ CQL Services](https://github.com/AHRQ-CDS/AHRQ-CDS-Connect-CQL-SERVICES)
pattern of keeping authored errors/warnings at the response level so they
survive suppressed or absent cards. The response shape is checked against
[CDS Hooks v2.0.1](https://cds-hooks.hl7.org/STU2/); the local extension is a
bounded project test contract, not a general CDS Hooks profile. CQL translation
or evaluation exceptions still fail the command and are never converted into
successful response diagnostics.
The card extension records both CQL package identities and outcomes separately
from the Dart candidate match and review flag. Missing dose and time remain
`unknown` with review recommended, while the unsupported-unit case remains
`unknown` even though the Dart candidate is false and its narrow missing-field
guard does not recommend review. Cards include case and rule versions, source
references, the corpus digest, and a stable input digest, but no raw input
value. The digest is unsalted and pseudonymous, not anonymization; only this
manufactured corpus is permitted. The projection is implemented under `tool/`
and is not an application or service integration.

All four literal-comparison paths are pinned development tools: [`@cqframework/cql@5.3.0`](https://github.com/cqframework/clinical_quality_language), [`org.cqframework:engine@5.3.0`](https://central.sonatype.com/artifact/org.cqframework/engine/5.3.0), [`cql-execution@3.3.2`](https://github.com/cqframework/cql-execution/releases/tag/v3.3.2), and [Google CQL at the reviewed source commit](https://github.com/google/cql/commit/b9169ccd54a3a8b0ac928aff338b9f7d6a4b163a). The separate CQF FHIR probe pins [`engine-fhir@5.3.0`](https://central.sonatype.com/artifact/org.cqframework/engine-fhir/5.3.0) and [`quick@5.3.0`](https://central.sonatype.com/artifact/org.cqframework/quick/5.3.0); CQF and Google artifacts declare Apache-2.0. The Go module and toolchain and the locked Gradle/JVM project run only in this development gate and are excluded from the application dependency graph and release artifacts. The JVM project commits its resolved Gradle dependency lock. CI uses Java 21; a local Java 17+ runtime is sufficient. CQL itself defines three-valued Boolean logic, with `null` representing unknown; see the [HL7 CQL Author's Guide](https://cql.hl7.org/02-authorsguide.html).

The literal comparison has no FHIR model; the Observation terminology check
loads the pinned FHIR 4.0.1 model info, six fixed synthetic Bundles, and one
in-memory synthetic ValueSet expansion with non-clinical test codes. Neither
path uses an external terminology service, clinical content, real patient
data, or an accuracy target. This one fixed foreign-subject
case validates only the test harness's narrow Condition subject filter; the
probe does not establish general FHIR validation, resource conformance,
patient-context isolation for arbitrary Bundles, or external provider behavior.
The cards are not production CDS Hooks responses. This gate
does not replace the signed knowledge-pack lifecycle, rule-level case review,
or a clinical governance process.

### MedicationAdministration retrieval differential

A separate nine-case synthetic FHIR R4 corpus checks resource presence and
each of the seven `MedicationAdministration.status` codes (`in-progress`,
`not-done`, `on-hold`, `completed`, `entered-in-error`, `stopped`, and
`unknown`), plus an absent resource and a foreign-subject resource. Google CQL
parses the authored CQL directly; the pinned CQF JavaScript translator and
executor and CQF JVM engine evaluate the same fixed predicates. All three paths
match the expected Boolean outcomes and drop the foreign-subject resource from
the declared Patient context. The JavaScript/JVM pair shares one upstream CQF
implementation family, so it supplies platform-parity evidence. The
schema-v1 subreport and schema-v17 aggregate emit fixed case labels, outcomes,
engine identities, and the fixture digest without resource contents or
synthetic identifiers. This is a bounded retrieval/status check, not dose or
administration validation, proof of medication use, adherence, clinical
decision support, or general FHIR/CQL conformance ([FHIR R4
MedicationAdministration](https://hl7.org/fhir/R4/medicationadministration.html)).

### AllergyIntolerance retrieval differential

A separate six-case synthetic FHIR R4 corpus checks resource presence, the
three `clinicalStatus` codes, the four `verificationStatus` codes, absence,
and a foreign-Patient reference. Its `entered-in-error` case omits
`clinicalStatus`, as required by the R4 resource invariant. Google CQL parses
the authored CQL directly; the pinned CQF JavaScript translator/executor and
CQF JVM engine evaluate the same eight Boolean predicates. All three paths
match every fixed expectation and drop the foreign resource before evaluation.
Reports retain only fixed case labels, Boolean outcomes, runtime identities,
and the fixture digest. FHIR defines AllergyIntolerance as an individual's
susceptibility to a substance and distinguishes that from circumstance-based
drug-food interactions; this probe only checks retrieval/status behavior and
does not interpret an allergy, resolve terminology, or make an interaction or
safety claim ([FHIR R4 AllergyIntolerance](https://hl7.org/fhir/R4/allergyintolerance.html),
[clinical status codes](https://hl7.org/fhir/R4/valueset-allergyintolerance-clinical.html),
[verification status codes](https://hl7.org/fhir/R4/valueset-allergyintolerance-verification.html)).

### Condition status retrieval differential

A separate nine-case synthetic FHIR R4 corpus checks the six
`Condition.clinicalStatus` codes and the six `Condition.verificationStatus`
codes as distinct predicates. It includes the R4 `entered-in-error` invariant
(verification status is present while `clinicalStatus` is omitted), an absent
Condition, and a foreign-Patient `subject`. Google CQL Go, the pinned CQF
JavaScript translator/executor with the FHIR 4.0.1 Patient source, and CQF JVM
evaluate the same thirteen Boolean predicates. Each path filters the foreign
subject before retrieval and matches all expected outcomes. The schema-v1
subreports and schema-v24 composite retain fixed case labels, Boolean values,
engine identities, and a fixture digest; they omit resource IDs and coding
systems. These are fixed local retrieval checks, not terminology validation,
interpretation of a condition, diagnosis, treatment, or general FHIR/CQL
conformance. The status code lists and invariant come from the official
[FHIR R4 Condition resource](https://hl7.org/fhir/R4/condition.html), its
[clinical status value set](https://hl7.org/fhir/R4/valueset-condition-clinical.html),
and its [verification status value set](https://hl7.org/fhir/R4/valueset-condition-ver-status.html).

### Versioned synthetic concept-template preview

`npm run cql:template:preview:test` and `npm run cql:template:preview` exercise
input schema 2 and output schema
`parkinsum.cql-concept-template-draft/2`. The first template kind is deliberately
narrow: a Patient-scoped FHIR R4 Observation retrieve filtered by
one explicitly versioned ValueSet, with an integer count comparison selected
from five closed operators. The generator emits deterministic CQL and an
experimental `status: draft` Library with its Boolean output parameter and
explicit Patient and Observation data requirements, following the FHIR R4
[Library](https://hl7.org/fhir/R4/library.html) and
[DataRequirement](https://hl7.org/fhir/R4/metadatatypes.html#DataRequirement)
resource shapes. CQF CQL 5.3.0 translates the generated CQL;
the checker then compares the ELM Library identity, output expression,
ValueSet binding, comparator, threshold, and Observation retrieve against the
input template.
The CQL library name is deterministically derived from the validated slug,
contains no underscore, and is also the final segment of the Library canonical.
The draft declares exact `depends-on` relationships for the FHIR 4.0.1
ModelInfo Library and the versioned ValueSet; its output parameter set is
checked against the sole top-level CQL expression. These fields implement a
bounded subset of the HL7 CQL authoring metadata contract.
The preview then evaluates the generated ELM through pinned
`cql-execution@3.3.2` and `cql-exec-fhir@2.1.6`, using a fixed in-memory
synthetic ValueSet expansion and synthetic FHIR R4 Bundles. It checks zero,
one, just-below, exact-threshold, just-above, non-member-code, and foreign-
subject cases; duplicate numeric boundaries are removed at threshold zero.
Per-case rows contain only case labels, counts, Boolean outcomes, and the number
of foreign Observations filtered before execution; the aggregate identifies the
pinned engine and synthetic expansion source. No Patient or Observation IDs are
emitted. Unsupported or malformed synthetic Bundle shapes fail closed.

`npm run cql:template:differential:test` checks the bounded bridge protocol and
`npm run cql:template:differential` independently translates and executes the
same generated CQL through the pinned CQF JVM 5.3.0 path. One offline Gradle run
covers all five comparators over the fixed threshold boundaries, ValueSet
exclusion, and foreign-subject cases (30 paired outcomes). The bridge binds each
JVM result to the exact generated CQL source digest; the JVM builds only fixed
synthetic FHIR resources and uses an in-memory ValueSet provider. Any result,
case-count, Patient-scope, source-digest, or engine-version mismatch fails
closed. The aggregate emits only fixed case labels, counts, digests, and
Boolean results. `npm run cql:diff` includes this second runtime path.

The checked-in example is synthetic; a local template file can be previewed
with `npm run cql:template:preview -- --template path/to/template.json`.

Translation reports one expected warning because no terminology provider is
configured to resolve the ValueSet membership operator. The preview does not
resolve production terminology or read patient data, call an endpoint, save the
Library, activate a rule, or claim FHIR conformance or clinical validity. The
two CQF-family runtime paths check generated-template behavior against fixed
synthetic values; they are not independent implementations or clinical
validation. The Boolean-count corpus does not test unknown-result or general
terminology-version behavior, or clinical meaning. The fixture uses an
`example.org` synthetic ValueSet identity. “Most recent” selection and
quantity/unit comparisons remain outside this first template kind; they require
separately tested ordering and UCUM semantics. The new name and dependency
metadata follow selected CQL authoring requirements, but no FHIR validator or
full CQL/FHIR conformance test is run.
