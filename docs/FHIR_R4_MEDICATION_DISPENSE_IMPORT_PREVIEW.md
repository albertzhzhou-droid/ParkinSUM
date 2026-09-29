# FHIR R4 MedicationDispense source preview

Engineering Diagnostics accepts one FHIR R4 MedicationDispense or a
Bundle.type=collection containing up to 32 dispense resources. The raw JSON
is limited to 128 KiB. The caller declares FHIR 4.0.1, an ISO 3166-1 alpha-2
jurisdiction, and the exact Patient reference to match. The preview compares
Patient references literally; it does not resolve identities or aliases.

The versioned in-memory projection retains the source status, medication
CodeableConcept, category, type, CodeableConcept status reason, source quantity,
days supply, and lexical whenPrepared and whenHandedOver precision. It
preserves quantity values and unit labels without conversion. entered-in-error,
Patient mismatches, invalid choices, invalid values, handover earlier than
preparation, and unknown or known-but-unprojected fields are held for review.
References, dosage instructions, performers, authorizing prescriptions and
other unprojected fields are not resolved or interpreted. Codes are not looked
up.

FHIR distinguishes an order (MedicationRequest), a supply event
(MedicationDispense), actual administration or consumption
(MedicationAdministration), and a reported medication-use statement
(MedicationStatement). Therefore, a pasted dispense status or handover time
is displayed only as a source claim. It does not establish that a person picked
up, took, or adhered to a medicine, and it is not reconciled against a
prescription. See the official
[FHIR R4 MedicationDispense definition](https://hl7.org/fhir/R4/medicationdispense.html),
[MedicationRequest](https://hl7.org/fhir/R4/medicationrequest.html),
[MedicationAdministration](https://hl7.org/fhir/R4/medicationadministration.html),
and [MedicationStatement](https://hl7.org/fhir/R4/medicationstatement.html)
definitions.

The preview stays in page memory. It makes no network request, persistence
write, terminology lookup, identity resolution, medication reconciliation, or
CDSS rule call. A SHA-256 digest identifies the exact submitted bytes; it is
not a signature or evidence that the source is authentic. This is a bounded
source-field preview, not FHIR profile validation, general FHIR conformance,
clinical interpretation, or a dispensing/administration record.
