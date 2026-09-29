enum FhirR4MedicationRequestPreviewDisposition { previewable, held }

enum FhirR4MedicationRequestTimePrecision {
  year,
  month,
  day,
  second,
  fractionalSecond,
}

/// Caller-declared context. References are compared but never resolved.
final class FhirR4MedicationRequestPreviewContext {
  const FhirR4MedicationRequestPreviewContext({
    required this.fhirVersion,
    required this.jurisdiction,
    required this.expectedPatientReference,
  });

  final String fhirVersion;
  final String jurisdiction;
  final String expectedPatientReference;
}

final class FhirR4MedicationRequestCodingPreview {
  const FhirR4MedicationRequestCodingPreview({
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

/// A source date/time with its original lexical precision.
final class FhirR4MedicationRequestTimePreview {
  const FhirR4MedicationRequestTimePreview({
    required this.lexical,
    required this.precision,
    this.utc,
  });

  final String lexical;
  final FhirR4MedicationRequestTimePrecision precision;
  final DateTime? utc;
}

final class FhirR4MedicationRequestEntryPreview {
  const FhirR4MedicationRequestEntryPreview({
    required this.disposition,
    required this.status,
    required this.intent,
    required this.medicationCodings,
    required this.dosageTexts,
    required this.reasonCodes,
    required this.unmappedPaths,
    this.bundleEntryFullUrl,
    this.resourceId,
    this.resourceVersionId,
    this.metaSource,
    this.metaLastUpdated,
    this.medicationConceptText,
    this.medicationReference,
    this.medicationReferenceDisplay,
    this.subjectReference,
    this.authoredOn,
    this.requesterReference,
    this.requesterDisplay,
  });

  final FhirR4MedicationRequestPreviewDisposition disposition;

  /// Source request lifecycle; it does not assert dispense or administration.
  final String? status;

  /// Source request intent; it remains distinct from MedicationStatement.
  final String? intent;
  final String? bundleEntryFullUrl;
  final String? resourceId;
  final String? resourceVersionId;
  final String? metaSource;
  final FhirR4MedicationRequestTimePreview? metaLastUpdated;
  final String? medicationConceptText;
  final List<FhirR4MedicationRequestCodingPreview> medicationCodings;
  final String? medicationReference;
  final String? medicationReferenceDisplay;
  final String? subjectReference;
  final FhirR4MedicationRequestTimePreview? authoredOn;
  final String? requesterReference;
  final String? requesterDisplay;
  final List<String> dosageTexts;
  final List<String> reasonCodes;
  final List<String> unmappedPaths;

  bool get previewable =>
      disposition == FhirR4MedicationRequestPreviewDisposition.previewable;
}

/// Bounded, in-memory preview of a MedicationRequest or collection.
///
/// The digest binds the exact pasted bytes. Neither resource nor preview is
/// persisted, transmitted, reconciled, or eligible for an algorithm.
final class FhirR4MedicationRequestImportPreview {
  const FhirR4MedicationRequestImportPreview({
    required this.context,
    required this.inputSha256,
    required this.entries,
    required this.reasonCodes,
    required this.unmappedPaths,
    this.containerType,
  });

  static const String schemaUri =
      'parkinsum.fhir-r4-medication-request-import-preview/1';
  static const String supportedFhirVersion = '4.0.1';
  static const int maximumInputBytes = 128 * 1024;
  static const int maximumEntries = 32;
  static const bool persistsData = false;
  static const bool algorithmEligible = false;

  final FhirR4MedicationRequestPreviewContext context;
  final String inputSha256;
  final String? containerType;
  final List<FhirR4MedicationRequestEntryPreview> entries;
  final List<String> reasonCodes;
  final List<String> unmappedPaths;

  bool get previewable =>
      entries.isNotEmpty &&
      reasonCodes.isEmpty &&
      entries.every((entry) => entry.previewable);

  int get heldEntryCount => entries.where((entry) => !entry.previewable).length;
}
