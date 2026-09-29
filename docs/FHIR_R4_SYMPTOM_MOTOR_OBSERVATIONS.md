# FHIR R4 symptom and self-reported motor-state observations

ParkinSUM can preview and explicitly copy a local FHIR R4 `Bundle.type=collection`
containing the latest bounded window of account-entered symptom and
self-reported motor-state observations. The exporter implements a narrow
mapping for the local education and research prototype; it is not a general
FHIR export service or a clinical profile.

## Included fields

Each `Observation` contains `status=preliminary`, an explicitly supplied
Patient reference, `effectiveDateTime` from the user's occurrence time, and
`issued` from the local record time. A project-specific
`Observation.method` coding retains the account-entered source category.
A generated `Observation.note` retains the original timezone string; the
user's private note is omitted. The collection contains at most 12 observations
in stable occurrence-time, record-time, and local-ID order. Each Bundle entry
has a fresh random UUID `fullUrl`; the embedded resource identifier does
not reuse the local record ID.

Symptom labels are carried as `Observation.code.text`; an entered 0–10 severity
is a component labelled as lacking clinical validation. ON, OFF, and uncertain
motor states use versioned project-specific codes. These identifiers are not
LOINC or SNOMED CT mappings, do not claim a terminology binding or constrained
profile, and are not published terminology resources. They are not intended
as interoperable clinical concepts without a future governance and
terminology review.

Unknown observations use FHIR `dataAbsentReason=unknown`; not-measured
observations use `dataAbsentReason=not-performed`. Both omit an Observation
value. Local record IDs, recorder IDs, and free-text notes are omitted.

## User and transfer boundary

The user supplies the Patient reference; ParkinSUM does not resolve or verify
it. The preview is built locally. Copying to the clipboard is a separate,
explicit action, and the UI rechecks account ownership and expires an open
preview if the account changes. No network transfer, EHR connection, or
terminology-server request occurs.

The development check in `tool/run_fhir_r4_bp_profile_check.dart` uses the
checksum-pinned HL7 validator CLI 6.10.4 and manufactured data. It validates
six symptom/motor Observation states, their collection Bundle, the
blood-pressure collection Bundle, and the combined personal-observation
collection Bundle against FHIR R4 core, plus three
blood-pressure Observations against the R4 BP profile. Terminology lookup is
disabled, so project-specific terminology is not validated. The gate requires
zero errors across all nine core resources and all three BP-profile resources.
Expected warnings include unpublished project-specific CodeSystem concepts
and FHIR best-practice narrative/performer guidance; the export does not
identify an independently verified performer. This is a bounded structural
check, not general FHIR conformance or clinical validation.

The timeline also provides a single local preview that combines the bounded
blood-pressure and symptom/motor windows, with a shared manually supplied
Patient reference. Its limits and privacy contract are described in
[`FHIR_R4_PERSONAL_OBSERVATION_COLLECTION.md`](FHIR_R4_PERSONAL_OBSERVATION_COLLECTION.md).

## Standards references

- [FHIR R4 Observation](https://hl7.org/fhir/R4/observation.html)
- [FHIR R4 Bundle](https://hl7.org/fhir/R4/bundle.html)
- [FHIR R4 DataAbsentReason](https://hl7.org/fhir/R4/codesystem-data-absent-reason.html)
