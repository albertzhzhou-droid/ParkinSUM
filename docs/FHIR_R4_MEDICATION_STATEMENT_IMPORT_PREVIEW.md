# FHIR R4 MedicationStatement import preview

This is a development-only, offline preview for either one FHIR R4
`MedicationStatement` or a `Bundle.type=collection` containing up to 32 such
resources. The pasted JSON limit is 128 KiB. The page requires the caller to
enter release `4.0.1`, a two-letter jurisdiction code and the expected Patient
reference; it compares each subject reference exactly and resolves nothing.

The preview retains the source resource ID and version metadata, source-claimed
FHIR status, medication concept text and codings or unresolved medication
reference, Patient reference, effective date/time or period, assertion time,
information-source reference, `dosage.text`, and collection `fullUrl`. Date-only
and month/year values keep their lexical precision and do not receive an
invented midnight or timezone. The preview hashes the exact pasted UTF-8 input
bytes so formatting changes produce a different input digest.

Only that bounded field subset is projected. Known FHIR elements outside the
subset, unknown elements, unsupported nested fields, mismatched Patient
references, unsupported release/status values, invalid timestamps and
duplicate collection identities are held and shown for review. Medication
coding is displayed as supplied without terminology lookup or identity
resolution; dosage text remains text and is never parsed into a numeric dose.
FHIR status remains the source's own statement. It is not converted to a local
`taken`/`not taken` conclusion or evidence of administration.

Input, preview and caller context exist only in page memory. The feature makes
no network request, writes no database or portable-data package, does not call
the SMART discovery action, and is not eligible for CDSS rules. Closing the
route disposes its controllers and clears the pasted content. Use fabricated or
de-identified material. A SHA-256 digest identifies the exact pasted bytes; it
does not authenticate the source or resource.

The HL7 R4 specification describes MedicationStatement as a report that may be
less specific than MedicationAdministration, and distinguishes a statement
from proof of an administration. This preview is narrower still: it does not
validate a FHIR profile or terminology, establish patient identity or source
authenticity, perform medication reconciliation, or provide EHR interoperability
or clinical evidence. See the [FHIR R4 MedicationStatement specification](https://hl7.org/fhir/R4/medicationstatement.html).

Focused implementation coverage is in
`test/fhir_r4_medication_statement_import_mapper_test.dart` and
`test/fhir_r4_medication_statement_import_page_test.dart`.
