enum FhirR4MedicationStatementImportDisposition { previewable, held }

enum FhirR4MedicationStatementTimePrecision {
  year,
  month,
  day,
  second,
  fractionalSecond,
  unknown,
}

/// Caller-declared context. The preview never resolves any supplied reference.
final class FhirR4MedicationStatementImportContext {
  const FhirR4MedicationStatementImportContext({
    required this.fhirVersion,
    required this.jurisdiction,
    required this.expectedPatientReference,
  });

  final String fhirVersion;
  final String jurisdiction;
  final String expectedPatientReference;
}

final class FhirR4MedicationStatementCodingPreview {
  const FhirR4MedicationStatementCodingPreview({
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

/// FHIR source date/time retained with its original spelling and precision.
/// Partial dates do not receive an invented midnight or timezone.
final class FhirR4MedicationStatementTimePreview {
  const FhirR4MedicationStatementTimePreview({
    required this.lexical,
    required this.precision,
    this.utc,
  });

  final String lexical;
  final FhirR4MedicationStatementTimePrecision precision;
  final DateTime? utc;
}

final class FhirR4MedicationStatementImportEntryPreview {
  const FhirR4MedicationStatementImportEntryPreview({
    required this.disposition,
    required this.status,
    required this.bundleEntryFullUrl,
    required this.medicationCodings,
    required this.reasonCodes,
    required this.unmappedPaths,
    this.resourceId,
    this.resourceVersionId,
    this.metaSource,
    this.metaLastUpdated,
    this.medicationConceptText,
    this.medicationReference,
    this.medicationReferenceDisplay,
    this.subjectReference,
    this.effectiveDateTime,
    this.effectivePeriodStart,
    this.effectivePeriodEnd,
    this.dateAsserted,
    this.informationSourceReference,
    this.informationSourceDisplay,
    this.dosageTexts = const <String>[],
  });

  final FhirR4MedicationStatementImportDisposition disposition;

  /// The exact FHIR status value. This is a source claim, not an
  /// administration/adherence finding.
  final String? status;
  final String? bundleEntryFullUrl;
  final String? resourceId;
  final String? resourceVersionId;
  final String? metaSource;
  final FhirR4MedicationStatementTimePreview? metaLastUpdated;
  final String? medicationConceptText;
  final List<FhirR4MedicationStatementCodingPreview> medicationCodings;
  final String? medicationReference;
  final String? medicationReferenceDisplay;
  final String? subjectReference;
  final FhirR4MedicationStatementTimePreview? effectiveDateTime;
  final FhirR4MedicationStatementTimePreview? effectivePeriodStart;
  final FhirR4MedicationStatementTimePreview? effectivePeriodEnd;
  final FhirR4MedicationStatementTimePreview? dateAsserted;
  final String? informationSourceReference;
  final String? informationSourceDisplay;
  final List<String> dosageTexts;
  final List<String> reasonCodes;
  final List<String> unmappedPaths;

  bool get previewable =>
      disposition == FhirR4MedicationStatementImportDisposition.previewable;
}

/// Bounded, in-memory preview of one MedicationStatement or a collection.
///
/// The original JSON digest binds the exact pasted bytes, but neither the
/// resource nor this preview is persisted or eligible for algorithm use.
final class FhirR4MedicationStatementImportPreview {
  const FhirR4MedicationStatementImportPreview({
    required this.context,
    required this.inputSha256,
    required this.entries,
    required this.reasonCodes,
    required this.unmappedPaths,
    this.containerType,
  });

  static const String schemaUri =
      'parkinsum.fhir-r4-medication-statement-import-preview/1';
  static const String supportedFhirVersion = '4.0.1';
  static const int maximumInputBytes = 128 * 1024;
  static const int maximumEntries = 32;
  static const bool persistsData = false;
  static const bool algorithmEligible = false;

  final FhirR4MedicationStatementImportContext context;
  final String inputSha256;
  final String? containerType;
  final List<FhirR4MedicationStatementImportEntryPreview> entries;
  final List<String> reasonCodes;
  final List<String> unmappedPaths;

  bool get previewable =>
      entries.isNotEmpty &&
      reasonCodes.isEmpty &&
      entries.every((entry) => entry.previewable);
  int get heldEntryCount => entries.where((entry) => !entry.previewable).length;
}
