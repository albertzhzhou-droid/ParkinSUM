enum FhirR4MedicationAdministrationDisposition { previewable, held }

enum FhirR4MedicationAdministrationTimePrecision {
  year,
  month,
  day,
  second,
  fractionalSecond,
}

/// Caller-declared scope. Patient references are compared literally.
final class FhirR4MedicationAdministrationImportContext {
  const FhirR4MedicationAdministrationImportContext({
    required this.fhirVersion,
    required this.jurisdiction,
    required this.expectedPatientReference,
  });

  final String fhirVersion;
  final String jurisdiction;
  final String expectedPatientReference;
}

final class FhirR4MedicationAdministrationCodingPreview {
  const FhirR4MedicationAdministrationCodingPreview({
    this.system,
    this.version,
    this.code,
    this.display,
    this.userSelected,
  });

  final String? system;
  final String? version;
  final String? code;
  final String? display;
  final bool? userSelected;
}

/// A source CodeableConcept. Codings are not looked up or normalized.
final class FhirR4MedicationAdministrationConceptPreview {
  const FhirR4MedicationAdministrationConceptPreview({
    required this.codings,
    this.text,
  });

  final List<FhirR4MedicationAdministrationCodingPreview> codings;
  final String? text;
}

/// Keeps the supplied spelling and precision; partial dates are not expanded.
final class FhirR4MedicationAdministrationTimePreview {
  const FhirR4MedicationAdministrationTimePreview({
    required this.lexical,
    required this.precision,
    this.utc,
  });

  final String lexical;
  final FhirR4MedicationAdministrationTimePrecision precision;
  final DateTime? utc;
}

final class FhirR4MedicationAdministrationImportEntryPreview {
  const FhirR4MedicationAdministrationImportEntryPreview({
    required this.disposition,
    required this.patientReferenceMatched,
    required this.medicationCodings,
    required this.statusReasons,
    required this.reasonCodes,
    required this.unmappedPaths,
    this.status,
    this.resourceId,
    this.bundleEntryFullUrl,
    this.resourceVersionId,
    this.metaSource,
    this.metaLastUpdated,
    this.medicationConceptText,
    this.subjectReference,
    this.category,
    this.effectiveDateTime,
    this.effectivePeriodStart,
    this.effectivePeriodEnd,
  });

  final FhirR4MedicationAdministrationDisposition disposition;

  /// The exact R4 source code; it is not proof that an administration occurred.
  final String? status;
  final bool patientReferenceMatched;
  final String? resourceId;
  final String? bundleEntryFullUrl;
  final String? resourceVersionId;
  final String? metaSource;
  final FhirR4MedicationAdministrationTimePreview? metaLastUpdated;
  final String? medicationConceptText;
  final List<FhirR4MedicationAdministrationCodingPreview> medicationCodings;
  final String? subjectReference;
  final FhirR4MedicationAdministrationConceptPreview? category;
  final List<FhirR4MedicationAdministrationConceptPreview> statusReasons;
  final FhirR4MedicationAdministrationTimePreview? effectiveDateTime;
  final FhirR4MedicationAdministrationTimePreview? effectivePeriodStart;
  final FhirR4MedicationAdministrationTimePreview? effectivePeriodEnd;
  final List<String> reasonCodes;
  final List<String> unmappedPaths;

  bool get previewable =>
      disposition == FhirR4MedicationAdministrationDisposition.previewable;
}

/// Bounded, in-memory projection of FHIR R4 source fields only.
final class FhirR4MedicationAdministrationImportPreview {
  const FhirR4MedicationAdministrationImportPreview({
    required this.context,
    required this.inputSha256,
    required this.containerType,
    required this.entries,
    required this.reasonCodes,
    required this.unmappedPaths,
  });

  static const String schemaUri =
      'parkinsum.fhir-r4-medication-administration-import-preview/1';
  static const String supportedFhirVersion = '4.0.1';
  static const int maximumInputBytes = 128 * 1024;
  static const int maximumEntries = 32;
  static const bool persistsData = false;
  static const bool algorithmEligible = false;

  final FhirR4MedicationAdministrationImportContext context;
  final String inputSha256;
  final String containerType;
  final List<FhirR4MedicationAdministrationImportEntryPreview> entries;
  final List<String> reasonCodes;
  final List<String> unmappedPaths;

  bool get previewable =>
      entries.isNotEmpty &&
      reasonCodes.isEmpty &&
      unmappedPaths.isEmpty &&
      entries.every((entry) => entry.previewable);

  int get heldEntryCount => entries.where((entry) => !entry.previewable).length;
}
