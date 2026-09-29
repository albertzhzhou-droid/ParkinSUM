# FHIR R4 Condition source preview

The Engineering Diagnostics page accepts one FHIR R4 `Condition` or a
`Bundle.type=collection` containing up to 32 Conditions, with a 128 KiB input
limit. The caller declares FHIR release `4.0.1`, an ISO 3166-1 alpha-2
jurisdiction, and the exact expected `Patient` reference. Each Condition must
carry that exact reference; the page does not resolve aliases, relative
references, contained resources, or a `Group` subject.

The projection keeps the source resource ID, `meta.versionId`, `meta.source`,
and `meta.lastUpdated`, the supplied `clinicalStatus` and
`verificationStatus` as separate CodeableConcepts, `category`, `code`,
`onsetDateTime`, `abatementDateTime`, and `recordedDate`. Codes and displays
remain source text; no terminology lookup, normalization, or mapping occurs.
Date values retain their lexical precision instead of being converted to a
local date or timestamp.

The bounded status checks use the required R4 clinical and verification code
systems. They hold a problem-list item without the required clinical status,
`entered-in-error` paired with a clinical status, and an abatement date paired
with a clinical status other than inactive, remission, or resolved. These are
structural preview constraints; the app does not decide whether a condition
exists, is current, or applies to a person. The FHIR R4 specification defines
Condition as a clinical problem/diagnosis resource and explicitly separates
its clinical and verification statuses and Patient/Group subject types
([Condition](https://hl7.org/fhir/R4/condition.html),
[clinical status value set](https://hl7.org/fhir/R4/valueset-condition-clinical.html),
[verification status value set](https://hl7.org/fhir/R4/valueset-condition-ver-status.html),
[category value set](https://hl7.org/fhir/R4/valueset-condition-category.html)).

Known R4 fields outside this projection, including severity, body site,
encounter, extensions, recorder/asserter, staging, evidence, notes, and the
non-`dateTime` onset/abatement choices, are reported as unmapped and hold the
preview. Unknown JSON fields, non-collection Bundles, duplicate IDs/`fullUrl`
values, unsupported status codings, invalid dates, and Patient mismatches also
remain held. The page shows a SHA-256 of the exact pasted bytes; it is a content
identity, not a signature or proof of source authenticity.

Use synthetic or de-identified input only. The JSON remains in page memory and
is cleared on edits or page disposal. Nothing is persisted, transmitted,
reconciled, written back, or consumed by a CDSS algorithm. This bounded
projection is not FHIR conformance validation, diagnosis confirmation, or
clinical interpretation.
