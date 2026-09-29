# FHIR R4 MedicationAdministration source preview

Engineering Diagnostics accepts one FHIR R4 `MedicationAdministration` or a
`Bundle.type=collection` containing up to 32 such resources, with a 128 KiB
input limit. The caller declares FHIR release `4.0.1`, an ISO 3166-1 alpha-2
jurisdiction, and an exact expected `Patient` reference. Each record must use
that exact reference. The preview does not resolve aliases, contained
resources, `Group` subjects, or medication references.

The projection retains source status, a `medicationCodeableConcept`, optional
category and status-reason concepts, resource and Bundle-entry identifiers,
selected `meta` fields, and `effectiveDateTime` or `effectivePeriod` lexical
values. Code systems and displays remain as supplied; no terminology lookup,
normalization, or mapping occurs. Partial date precision remains visible.
When both period bounds carry full timestamps, the preview checks that the
start does not follow the end.

FHIR R4 defines MedicationAdministration as a workflow event for a patient
consuming or otherwise being administered a medication, and distinguishes it
from a MedicationRequest order and a MedicationStatement report. This local
preview only displays the source's claims. It cannot authenticate the record
or prove that a medication was administered, consumed, or taken as prescribed
([FHIR R4 MedicationAdministration](https://hl7.org/fhir/R4/medicationadministration.html),
[MedicationRequest](https://hl7.org/fhir/R4/medicationrequest.html),
[MedicationStatement](https://hl7.org/fhir/R4/medicationstatement.html)).

`entered-in-error`, a mismatched Patient, unsupported choices, invalid dates,
and every known-but-unprojected or unknown field remain held. This includes
`dosage`, `medicationReference`, performer, reason, request, context, notes,
extensions, and identifiers other than the resource's logical `id`.
Medication quantities are deliberately not parsed or summarized.

Use synthetic or de-identified input only. The JSON stays in page memory and
clears on edits or page disposal. Nothing is persisted, transmitted, reconciled,
written back, or consumed by a CDSS algorithm. The content digest identifies
the exact pasted bytes but is not source authentication. This subset is not
FHIR conformance validation, medication reconciliation, or a clinical
conclusion.
