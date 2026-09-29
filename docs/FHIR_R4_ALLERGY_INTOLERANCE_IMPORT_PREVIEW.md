# FHIR R4 AllergyIntolerance source preview

## Purpose

The Engineering Diagnostics page offers a bounded, offline projection for a
single FHIR R4 `AllergyIntolerance` resource or a collection `Bundle`. It is a
development-only display of selected source fields for synthetic or
de-identified examples. It does not conclude that an allergy is present or
absent, assess causality or safety, validate a FHIR profile, reconcile records,
or provide clinical decision support.

The input is limited to 128 KiB and 32 resources. The caller declares FHIR
4.0.1, an ISO 3166-1 alpha-2 jurisdiction and an expected `Patient` reference.
The mapper compares the resource's `patient.reference` with that exact value;
it does not resolve relative and absolute references, fetch a Patient, or show
the reference in the result panel. The pasted resource and preview remain in
memory until the page is cleared or closed. Nothing is sent, saved, exported,
or passed to an algorithm.

## Projected fields

The preview preserves `clinicalStatus` and `verificationStatus` separately as
source-reported `CodeableConcept`s. It checks each against the FHIR R4 required
value set's code system and code list, while retaining the supplied system,
version, code and display values. It performs no terminology lookup or
translation. An `entered-in-error` verification status is displayed as
source data but held from local review; the R4 constraint that excludes
`clinicalStatus` for that status is also checked. If verification status is
not `entered-in-error`, a clinical status is required for the preview.

Other projected values include the source `type`, `category`, `criticality`,
allergy/intolerance `code`, `onsetDateTime`, `recordedDate`,
`lastOccurrence`, selected `meta` fields, and a limited set of `reaction`
fields: substance, manifestation, onset, severity and exposure route. Date
strings retain their lexical precision. Source text, codings and severity
labels are shown as supplied; they are not interpreted. In particular,
`type`, `criticality`, and reaction `severity` are separate FHIR elements and
this preview does not infer one from another.

Unknown fields and known but unprojected fields are listed by path and hold the
entry for review. This includes modifier extensions, narrative, identifiers,
alternate `onset[x]` choices, reaction descriptions and notes, and unsupported
references. Invalid Patient scope, status bindings, choice combinations,
date values, resource shapes, or collection limits also hold or reject input.
JSON errors are reported without echoing the submitted text.

## Source basis and limits

FHIR R4 defines `AllergyIntolerance` as a patient-specific record and keeps
clinical and verification status as different elements. Its clinical and
verification status bindings are required value sets with separate canonical
code systems. The specification also distinguishes allergy/intolerance type
from seriousness or risk. This preview uses those definitions only to bound
the field projection and fail-closed checks; it does not establish general
FHIR conformance or source authenticity.

The parent `fhir_interoperability_sandbox` queue item remains
`research_required`. SMART authorization, consent, token lifecycle, network
FHIR reads, EHR write-back policy and independent interoperability or
conformance evidence remain open.

- [FHIR R4 AllergyIntolerance](https://hl7.org/fhir/R4/allergyintolerance.html)
- [FHIR R4 AllergyIntolerance clinical status value set](https://hl7.org/fhir/R4/valueset-allergyintolerance-clinical.html)
- [FHIR R4 AllergyIntolerance verification status value set](https://hl7.org/fhir/R4/valueset-allergyintolerance-verification.html)
