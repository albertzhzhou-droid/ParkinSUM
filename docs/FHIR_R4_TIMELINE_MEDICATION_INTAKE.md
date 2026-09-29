# FHIR R4 timeline medication-intake statement

The timeline can preview one saved, current-account medication intake as a
FHIR R4 `MedicationStatement`. The mapper schema is
`parkinsum.fhir-r4-medication-intake-statement/1`.

The owner enters the exact Patient reference used by the receiving system. The
resource keeps the medication catalog's display name in
`medicationCodeableConcept.text`, sets the required status to `unknown`, and
uses `effectiveDateTime` for the saved event date. It preserves only the
original free-text `dosageNote` in `dosage.text`; it does not project parsed
amount/unit values, product selections, dose-confirmation receipts, local IDs,
or terminology codings. It omits `dateAsserted` because the app does not record
when the user entered each intake. A generated `note` identifies the item as a
user-entered report whose medication identity and use have not been
independently verified.

The event timestamp retains full precision only when the saved Dart `DateTime`
is explicitly UTC. For a local `DateTime`, the original offset was not
preserved, so the mapper outputs its calendar date only and explains this in
the generated note. This avoids inventing a time-zone offset. The date-only
shape is allowed by FHIR R4 `dateTime`.

The dialog makes a local JSON preview, requires a separate Copy action, and
expires if the account, intake contents, or medication catalog changes. No
FHIR resource is saved or uploaded, no EHR request occurs, and the mapper is
outside result-producing algorithms. FHIR R4 distinguishes a
`MedicationStatement` report from the more specific `MedicationAdministration`
event; this export does not verify administration, adherence, medication
identity, or current treatment. Copied content may remain in the operating
system clipboard after the app closes.

The mapper tests cover UTC and date-only precision, status and text projection,
private-field omission, reference validation, size bounds, and immutability.
Timeline tests cover local preview, copy-on-request, no record mutation, and
stale-preview invalidation after an intake edit. These checks do not establish
general FHIR conformance, clinical correctness, safety, or interoperability
with a server. See the official [FHIR R4 MedicationStatement
resource](https://hl7.org/fhir/R4/medicationstatement.html) and
[dateTime datatype](https://hl7.org/fhir/R4/datatypes.html#dateTime).
