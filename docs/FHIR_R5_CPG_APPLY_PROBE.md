# FHIR R5 CPG operation synthetic probes

These development probes follow the HL7 R5 [`PlanDefinition/$apply` operation](https://hl7.org/fhir/R5/plandefinition-operation-apply.html), [`ActivityDefinition/$apply` operation](https://hl7.org/fhir/R5/activitydefinition-operation-apply.html), [`PlanDefinition/$data-requirements` operation](https://hl7.org/fhir/R5/operation-plandefinition-data-requirements.html), [`RequestOrchestration`](https://hl7.org/fhir/R5/requestorchestration.html), and [`Bundle`](https://hl7.org/fhir/R5/bundle.html) definitions. They are separate from ParkinSUM's existing FHIR R4 CQL artifact checks.

## Structure-only command

Run the deterministic, no-network contract tests and redacted fixture report with:

```sh
npm run fhir:r5:cpg-apply-contract
```

Run the deterministic, no-network ActivityDefinition contract with:

```sh
npm run fhir:r5:activitydefinition-apply-contract
```

Run the deterministic, no-network PlanDefinition data-requirements contract with:

```sh
npm run fhir:r5:plandefinition-data-requirements-contract
```

The PlanDefinition schema-v1 fixture pins FHIR 5.0.0, one synthetic PlanDefinition, and one synthetic subject Reference. Its operation response is a FHIR `Parameters` resource with one `return` parameter containing one `Bundle.type=collection`; that Bundle's first entry has a fixed unique synthetic `fullUrl` and the matching RequestOrchestration with a versioned PlanDefinition canonical, `status=draft`, and `intent=proposal`. This wrapper follows the operation's `return` cardinality of `0..*` and the general FHIR operation response rules. The separate ActivityDefinition schema-v1 fixture binds one synthetic `ActivityDefinition.kind=RequestOrchestration` and one subject; its `1..1` Resource result is the direct RequestOrchestration with the exact versioned ActivityDefinition canonical, matching subject, and `draft`/`proposal` fields. Both outputs contain zero actions and no additional resources. The third schema-v1 fixture covers `PlanDefinition/$data-requirements`: it pins one synthetic PlanDefinition and one versioned synthetic logic Library, then checks the direct returned `Library` has `type=module-definition`, one exact versioned dependency, one Boolean output parameter, and one synthetic Observation data requirement. The operation specifies a single `Library` return, so the direct resource form follows the general FHIR operation response rule. All reports contain structural counts and fixture SHA-256 digests, not resource identifiers.

## Optional HL7 core validator command

The separate validator path checks the full PlanDefinition `Parameters` response, ActivityDefinition RequestOrchestration, and data-requirements Library with the official [HL7 FHIR Validator CLI 6.10.4](https://github.com/hapifhir/org.hl7.fhir.core/releases/tag/6.10.4). It accepts the JAR only when its SHA-256 is `1106b9d58f9e363e47bea7c4fc065841e5fc91fe9d062775c3bfdd212bd653cc`, requires Java 11 or newer, selects FHIR 5.0.0, and passes `-tx n/a` to disable terminology-server validation.

After obtaining that release JAR and a compatible Java runtime, run:

```sh
FHIR_VALIDATOR_JAR=/path/to/validator_cli.jar \
JAVA_BIN=/path/to/java \
npm run fhir:r5:cpg-apply:validate
```

The validator process receives only those three manufactured operation-response resources, each written to a mode-0600 temporary file and removed after the run. The validator may download `hl7.fhir.r5.core#5.0.0` or its dependencies if they are absent from the local FHIR package cache; the selected package version is fixed, but the package bytes are not separately hashed by this probe. Terminology-server lookup is disabled, though warnings and notes may still be reported. The command is optional and is not run by the app; `verify:all` tests its invocation and output contract but does not start the external CLI.

A zero-error result applies only to these three synthetic operation responses against the selected FHIR R5 core package. The command does not execute either `$apply` operation or `$data-requirements`, aggregate dependencies, evaluate CQL, start a CPG engine, validate an implementation guide, or establish broad FHIR conformance, clinical correctness, safety, effectiveness, or interoperability. No patient data is used.

The optional validator command is not currently executable on the recorded host: `FHIR_VALIDATOR_JAR` is not configured, Java 8 is on `PATH`, and the FHIR R5 core package is not cached. Its contract tests pass independently; no validator result is claimed until the pinned JAR and a compatible runtime are available and the command runs successfully.
