# FHIR R4 owner-entered medication discussion statements

CareWorkspace can preview up to 128 account-entered medication discussion
items as an R4 `Bundle.type=collection` of `MedicationStatement` resources.
The mapper schema is
`parkinsum.fhir-r4-medication-statement-collection/1`. Each entry receives a
fresh UUID `fullUrl` and a matching resource ID; local record and recorder IDs
are never exported.

The user supplies the exact Patient reference. Each statement contains the
entered medication name as `medicationCodeableConcept.text`, the entered status
as `active`, `stopped`, or `unknown`, and the local entry time as
`dateAsserted`. Entered dose/schedule text is preserved without parsing in
`dosage.text` when present. The mapper adds no medication terminology coding,
`informationSource`, or effective-use period. It omits the local category,
ingredient label, question, and other discussion history.

FHIR R4 describes MedicationStatement as a report about medication use, which
may come from a patient, another person, or a clinician; it is distinct from an
order or administration. The source and clinical accuracy of these local
entries are not established. The UI therefore warns that receiving systems may
treat the exported status as a Patient medication-use statement and asks the
user to review both the Patient reference and content before copying. The
Patient reference is not resolved, and the export is not a medication
reconciliation or verification service. See [FHIR R4 MedicationStatement](https://hl7.org/fhir/R4/medicationstatement.html)
and [FHIR R4 Bundle](https://hl7.org/fhir/R4/bundle.html).

## CareWorkspace flow

The export is enabled only when every included entry belongs to the current
account. The preview accepts relative `Patient/id` or an absolute HTTPS Patient
reference, builds JSON locally, and copies only after a separate explicit
action. Account changes or record changes expire the preview. No FHIR resource
is saved, uploaded, sent to an EHR, or copied before the user selects Copy.
Copied medication details may remain in the operating system clipboard after
the app closes.

## Verification boundary

The mapper tests cover status and timestamp projection, stable ordering,
explicit Patient references, unique UUID identities, owner eligibility,
bounded size, duplicate rejection, omitted local/private fields, and deep
immutability. The CareWorkspace widget tests cover preview, copy-on-request,
no persistence, account-switch expiry, and record-change expiry. The optional pinned HL7 validator
gate includes one synthetic MedicationStatement and one synthetic collection
among eleven FHIR R4 core resources with terminology lookup disabled. These
checks do not resolve a real Patient, validate medication identity, establish
general FHIR conformance, or demonstrate clinical correctness, safety, or
interoperability with a server.
