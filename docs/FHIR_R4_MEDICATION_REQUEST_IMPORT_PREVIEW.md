# FHIR R4 MedicationRequest preview

This is a development-only offline preview for one FHIR R4 `MedicationRequest`
or a `Bundle.type=collection` containing up to 32 MedicationRequest resources.
The input limit is 128 KiB. The caller declares release `4.0.1`, a two-letter
jurisdiction code, and the exact expected Patient reference; subjects are
compared literally and never resolved.

The bounded projection preserves the source resource ID and version metadata,
the exact request `status` and `intent`, medication concept text/codings or an
unresolved Medication reference, Patient reference, `authoredOn` lexical
precision, requester reference/display, dosage-instruction text, and collection
`fullUrl`. The preview supports the eight R4 request statuses (`active`,
`on-hold`, `cancelled`, `completed`, `entered-in-error`, `stopped`, `draft`,
`unknown`) and eight intents (`proposal`, `plan`, `order`, `original-order`,
`reflex-order`, `filler-order`, `instance-order`, `option`).

`entered-in-error` stays held because FHIR marks it as a modifier status. The
`doNotPerform` modifier and other recognized-but-unprojected fields also hold
the entry; unknown fields are listed only by path. Codings are displayed as
supplied without terminology lookup, and dosage instructions are never parsed
into a numeric dose. Partial date/time precision is preserved without adding an
invented instant.

FHIR defines MedicationRequest as a request resource in a workflow. Its status
and intent are not evidence that medication was dispensed, administered,
consumed, or taken as prescribed. It remains distinct from MedicationStatement,
which is source-reported medication-use information, and from
MedicationAdministration ([FHIR R4 MedicationRequest](https://hl7.org/fhir/R4/medicationrequest.html),
[FHIR R4 MedicationStatement](https://hl7.org/fhir/R4/medicationstatement.html)).

Input and preview remain in page memory and are cleared when the route closes.
The page makes no network request, database write, export, terminology lookup,
identity resolution, medication reconciliation, or algorithm call. A local
preview digest binds the exact pasted bytes but does not authenticate the
source or resource. Use fabricated or de-identified input. The preview is not
a FHIR profile validator, prescription validator, SMART launch, EHR import,
general FHIR-conformance result, or clinical decision.

Focused coverage is in
`test/fhir_r4_medication_request_import_mapper_test.dart` and
`test/fhir_r4_medication_request_import_page_test.dart`. Run it with
`npm run fhir:r4:medication-request:preview:test`.
