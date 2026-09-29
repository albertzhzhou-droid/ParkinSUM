# FHIR R4 blood-pressure export slice

`FhirR4BloodPressureMapper` exports one local blood-pressure
`PersonalObservation` as an HL7 FHIR R4 `Observation` that declares the
official Blood Pressure profile. The slice fixes FHIR to v4.0.1 and uses the
profile's LOINC panel (`85354-9`), systolic (`8480-6`) and diastolic (`8462-4`)
codes, and UCUM `mm[Hg]` quantities. See the [FHIR R4 BP profile](https://hl7.org/fhir/R4/bp.html)
and [FHIR R4 Observation](https://hl7.org/fhir/R4/observation.html).
Recent timeline readings can also be packaged in an R4
[Bundle](https://hl7.org/fhir/R4/bundle.html) with type
[collection](https://hl7.org/fhir/R4/codesystem-bundle-type.html). A collection
groups resources into one package; this adapter does not create transaction
entries or contact a FHIR server.

## Terminology release identity

Mapper schema v2 includes `Coding.version: "2.83"` on its LOINC panel and
component codings. LOINC 2.83 was released on 2026-08-19; its official
[download page](https://loinc.org/downloads/) identifies the release, and the
[LOINC license](https://loinc.org/license) governs use of its terminology.
LOINC's license permits its codes and related information in electronic
records/messages under its stated conditions; this export remains a local
FHIR-style message and is not a general redistribution of the terminology
table.

The implementation pins UCUM specification 2.2 (2024-06-17), but FHIR R4's
`Quantity` has `system` and `code` fields without a code-system `version` field.
The export therefore keeps `http://unitsofmeasure.org` and `mm[Hg]` without
inventing a custom version field. The version is recorded in the local mapper
contract, not the FHIR quantity. This does not perform UCUM terminology
validation or claim UCUM conformance. See the official [UCUM specification](https://ucum.org/ucum)
and its [license](https://ucum.org/license).

## Offline import preview

`FhirR4BloodPressureImportMapper` previews a decoded FHIR R4 `Observation`
map for one exact BP-panel subset. The caller supplies the FHIR base, release,
jurisdiction, and expected `Patient` reference; the mapper does not discover or
verify them against a server. It keeps resource version metadata, LOINC coding
versions/displays, source date strings and UTC instants, and each component's
value or distinct `unknown`/`not-performed` absent reason. It accepts only a
single BP panel code (`85354-9`) and one systolic (`8480-6`) plus one diastolic
(`8462-4`) component with LOINC version 2.83 and UCUM `mm[Hg]`.

The preview holds unsupported fields, comparator quantities, invalid or
partial timestamps, invalid context, and mismatched Patient references. It is
an in-memory engineering boundary only: it creates no local observation,
performs no SMART authorization or network request, and cannot feed a CDSS
algorithm. The decoded numeric value does not retain the source JSON's exact
decimal spelling, so this is not a lossless archive or database-import path.
Synthetic boundary tests live in
`test/fhir_r4_blood_pressure_import_mapper_test.dart`.

The Engineering diagnostics page exposes this mapper as a local preview. It
accepts one JSON resource up to 64 KiB, requires the caller context above, and
shows either the mapped subset or held reasons while the source remains in its
input editor. Use fabricated or de-identified input only. The page keeps input in
memory while open and clears its fields when leaving; it does not save, send,
export, or feed the preview to a rule, and it has no dedicated clipboard action.
This diagnostic page does not add SMART
authorization, a server fetch, identity resolution, or database import.

The caller must provide the exact `Patient` reference. The mapper checks its
shape but does not resolve it, create a Patient, or infer a reference from a
local account or recorder ID. It exports the occurrence instant as
`effectiveDateTime`, recording instant as `issued`, and keeps the original
timezone label, source, and posture in a short `note`. It does not export
free-text notes or internal recorder identity. Recorded observations use
`preliminary` status because this workflow has no separate verification step.
Unknown and not-measured observations retain standard
`dataAbsentReason` codes; the BP component codes remain present. Non-BP input,
invalid FHIR IDs, unsupported Patient references, or a changed unit are held
instead of rewritten.

## Local timeline export

The timeline shows an export action on blood-pressure observation cards. Only
the account that recorded the observation can start the flow. The user must
enter the exact Patient reference, inspect a local JSON preview, then choose
Copy to write it to the clipboard. This does not save a FHIR resource or make
a network request. If the account changes while the dialog is open, the
preview is cleared and copying is disabled. The clipboard payload contains
personal health information and is not cleared automatically after copying.

The trend card separately offers a collection of its most recent 12
blood-pressure observations. Entries are ordered by occurrence time, recording
time, then ID; unknown and not-measured entries are retained with their absent
reasons. The collection is rejected if empty, oversized, contains repeated
FHIR IDs, or unsupported observations; the timeline also refuses preview when
any included record is not owned by the current account. Its Bundle contains
only `resource` entries and has
`type: collection`; it has no request/transaction semantics, Patient resource,
automatic transfer, or persistence.

`test/timeline_observation_page_test.dart` covers invalid and valid references,
preview without clipboard writes, explicit copy, omitted free-text/recorder
identity, no persistence, account-switch expiry, and bounded collection export
including missing statuses and mixed-owner rejection. Mapper validation and
deep immutability are covered by `test/fhir_r4_blood_pressure_collection_mapper_test.dart`.

## Synthetic profile check

The check creates three fabricated blood-pressure observations and their
collection, six fabricated symptom/motor observations and their collection,
and a combined collection Bundle in a temporary directory. It runs the pinned
official HL7 validator CLI 6.10.4 against FHIR R4 and the BP profile for each
blood-pressure Observation, then validates the nine collection and
symptom/motor resources against the R4 core package without applying the
Observation profile.
It accepts the validator jar only when its SHA-256 is
`1106b9d58f9e363e47bea7c4fc065841e5fc91fe9d062775c3bfdd212bd653cc`, the digest
published by the [official 6.10.4 release](https://github.com/hapifhir/org.hl7.fhir.core/releases/tag/6.10.4).
The validator's R4 core package is 4.0.1. The run uses `-tx n/a`; therefore it
checks structural/profile constraints against the pinned local packages and
does not claim terminology-server validation.

Download the jar from the release link above, then run:

```sh
FHIR_VALIDATOR_JAR=/path/to/validator_cli.jar \
JAVA_BIN=/path/to/java \
npm run fhir:r4-bp:validate
```

`JAVA_BIN` may be omitted when a compatible Java runtime is on `PATH`. The
validator requires Java 11 or newer. Successful output reports one zero-error
result for each of the recorded, unknown, and not-measured blood-pressure
examples, plus eleven FHIR R4 core results for the two individual collections,
the combined collection, six symptom/motor resources, and one synthetic
MedicationStatement plus collection. The run uses `-tx n/a`; its
warnings and notes include the skipped terminology service and omitted UCUM
code-system validation. They are retained in the raw validator output. A
zero-error structural/profile result is engineering interoperability evidence
only.

This adapter covers a bounded BP Observation profile, individual collection,
and combined collection using synthetic resources. It does not provide general FHIR
serialization, terminology validation, reference resolution, FHIR server
exchange, complete care-record export, or evidence of clinical validity or
safe use.
