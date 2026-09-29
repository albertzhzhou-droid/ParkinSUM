enum FhirR4MedicationDispenseDisposition { previewable, held }

enum FhirR4MedicationDispenseTimePrecision {
  year,
  month,
  day,
  second,
  fractionalSecond,
}

/// Caller-declared scope; Patient references are compared literally.
final class FhirR4MedicationDispenseImportContext {
  const FhirR4MedicationDispenseImportContext({
    required this.fhirVersion,
    required this.jurisdiction,
    required this.expectedPatientReference,
  });

  final String fhirVersion;
  final String jurisdiction;
  final String expectedPatientReference;
}

final class FhirR4MedicationDispenseCodingPreview {
  const FhirR4MedicationDispenseCodingPreview({
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

/// Source CodeableConcept; codes are not looked up or normalized.
final class FhirR4MedicationDispenseConceptPreview {
  const FhirR4MedicationDispenseConceptPreview({
    required this.codings,
    this.text,
  });

  final List<FhirR4MedicationDispenseCodingPreview> codings;
  final String? text;
}

/// Retains lexical precision; a partial date is not expanded to a timestamp.
final class FhirR4MedicationDispenseTimePreview {
  const FhirR4MedicationDispenseTimePreview({
    required this.lexical,
    required this.precision,
    this.utc,
  });

  final String lexical;
  final FhirR4MedicationDispenseTimePrecision precision;
  final DateTime? utc;
}

/// Quantity as reported by the source. No unit conversion or interpretation.
final class FhirR4MedicationDispenseQuantityPreview {
  const FhirR4MedicationDispenseQuantityPreview({
    this.value,
    this.unit,
    this.system,
    this.code,
  });

  final num? value;
  final String? unit;
  final String? system;
  final String? code;
}

final class FhirR4MedicationDispenseImportEntryPreview {
  const FhirR4MedicationDispenseImportEntryPreview({
    required this.disposition,
    required this.patientReferenceMatched,
    required this.medicationCodings,
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
    this.type,
    this.statusReason,
    this.quantity,
    this.daysSupply,
    this.whenPrepared,
    this.whenHandedOver,
  });

  final FhirR4MedicationDispenseDisposition disposition;

  /// Source status, not evidence of pickup or medication use.
  final String? status;
  final bool patientReferenceMatched;
  final String? resourceId;
  final String? bundleEntryFullUrl;
  final String? resourceVersionId;
  final String? metaSource;
  final FhirR4MedicationDispenseTimePreview? metaLastUpdated;
  final String? medicationConceptText;
  final List<FhirR4MedicationDispenseCodingPreview> medicationCodings;
  final String? subjectReference;
  final FhirR4MedicationDispenseConceptPreview? category;
  final FhirR4MedicationDispenseConceptPreview? type;
  final FhirR4MedicationDispenseConceptPreview? statusReason;
  final FhirR4MedicationDispenseQuantityPreview? quantity;
  final FhirR4MedicationDispenseQuantityPreview? daysSupply;
  final FhirR4MedicationDispenseTimePreview? whenPrepared;
  final FhirR4MedicationDispenseTimePreview? whenHandedOver;
  final List<String> reasonCodes;
  final List<String> unmappedPaths;

  bool get previewable =>
      disposition == FhirR4MedicationDispenseDisposition.previewable;
}

/// Bounded, memory-only projection of selected FHIR R4 MedicationDispense fields.
final class FhirR4MedicationDispenseImportPreview {
  const FhirR4MedicationDispenseImportPreview({
    required this.context,
    required this.inputSha256,
    required this.containerType,
    required this.entries,
    required this.reasonCodes,
    required this.unmappedPaths,
  });

  static const String schemaUri =
      'parkinsum.fhir-r4-medication-dispense-import-preview/1';
  static const String supportedFhirVersion = '4.0.1';
  static const int maximumInputBytes = 128 * 1024;
  static const int maximumEntries = 32;
  static const bool persistsData = false;
  static const bool algorithmEligible = false;

  final FhirR4MedicationDispenseImportContext context;
  final String inputSha256;
  final String containerType;
  final List<FhirR4MedicationDispenseImportEntryPreview> entries;
  final List<String> reasonCodes;
  final List<String> unmappedPaths;

  bool get previewable =>
      entries.isNotEmpty &&
      reasonCodes.isEmpty &&
      unmappedPaths.isEmpty &&
      entries.every((entry) => entry.previewable);

  int get heldEntryCount => entries.where((entry) => !entry.previewable).length;
}
