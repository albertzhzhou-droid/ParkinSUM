# FHIR R4 Encounter source preview

Engineering Diagnostics accepts one FHIR R4 `Encounter` or a
`Bundle.type=collection` with up to 32 Encounter entries and a 128 KiB input
limit. The caller declares FHIR release `4.0.1`, a two-letter jurisdiction
code, and the exact expected `Patient` reference. Each Encounter must contain
that exact Patient reference; the source reference itself is omitted from the
preview output. The mapper does not resolve aliases, relative references,
contained resources, or `Group` subjects.

The preview retains `Encounter.status`, the supplied `class` Coding fields,
and `period.start`/`period.end` at their original lexical precision. It does
not convert times, infer durations, compare the period endpoints, or look up
terminology. All nine FHIR R4 status values are recognized as source codes;
`entered-in-error` is held. `class` code is a required source field for this
projection, but its meaning is not validated. FHIR R4 defines the Encounter
resource and its required status binding in the official
[Encounter resource](https://hl7.org/fhir/R4/encounter.html) and
[Encounter status value set](https://hl7.org/fhir/R4/valueset-encounter-status.html).

Known FHIR fields outside this subset, including metadata, extensions,
status/class history, encounter type, participants, appointments, reasons,
diagnoses, hospitalization, location, and service provider are reported as
unmapped and hold the preview. Unknown JSON fields, non-collection Bundles,
duplicate IDs or `fullUrl` values, unsupported statuses, invalid dateTimes,
missing class code, and Patient mismatches are held as well. A pass means only
that this small source projection completed; it is not resource/profile
validation.

Use synthetic or de-identified data only. Input stays in page memory and is
cleared on edits or page disposal. Nothing is persisted, transmitted, resolved,
reconciled, interpreted as a care setting, written back, or consumed by a CDSS
algorithm. This preview is not FHIR conformance validation, clinical
interpretation, or medical advice.
