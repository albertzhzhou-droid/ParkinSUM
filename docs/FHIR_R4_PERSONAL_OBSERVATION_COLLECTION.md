# Combined FHIR R4 personal observation collection

The timeline can package its latest blood-pressure, symptom, and self-reported
motor-state observations in one FHIR R4 `Bundle.type=collection`. The mapper
schema is `parkinsum.fhir-r4-personal-collection/1`. It includes at most 12
blood-pressure and 12 symptom/motor observations, ordered by occurrence time,
recording time, and a final local-ID tie-breaker. The local ID is used only for
ordering and duplicate rejection; it is never exported.

Every `Observation.subject.reference` uses the same Patient reference that the
user enters in the preview. The exporter does not resolve that reference or
create a Patient. Each Bundle entry gets a fresh random UUID `fullUrl`, and the
resource ID matches that UUID. Unknown and not-measured states remain distinct.
Blood pressure retains its LOINC-coded profile mapping; symptom and motor
codes remain illustrative ParkinSUM codes without SNOMED CT or LOINC mappings.
Recorder IDs and user-entered free-text notes are omitted.

## Timeline flow

The timeline app bar offers one combined export action when every displayed
observation in the bounded windows belongs to the current account. The user
enters one exact Patient reference, previews the JSON locally, and chooses Copy
to write it to the clipboard. Nothing is uploaded, persisted as FHIR, or sent
as a transaction. A changed account clears the preview and disables copying.
Copied content includes personal health information and is not cleared from
the clipboard automatically.

The Bundle contains resource entries with unique `fullUrl` values and no
`entry.request` or `entry.response`. FHIR R4 defines `collection` as a Bundle
type and reserves request metadata for batch, transaction, and history bundles;
this local export therefore remains a collection preview without server
operation semantics. See [FHIR R4 Bundle](https://hl7.org/fhir/R4/bundle.html)
and [FHIR R4 Observation](https://hl7.org/fhir/R4/observation.html).

## Verification boundary

`test/fhir_r4_personal_observation_collection_mapper_test.dart` checks mixed
resource mapping, ordering, shared Patient reference, UUID alignment, privacy
omissions, missingness, bounds, duplicate rejection, and immutability. The
timeline widget test checks preview, explicit copy, and the absence of
persistence. The optional pinned HL7 validator gate now includes one synthetic
combined Bundle in its FHIR R4 core check with terminology lookup disabled.
These checks do not verify a live Patient reference, terminology, server
compatibility, clinical meaning, clinical validity, or safe use.
