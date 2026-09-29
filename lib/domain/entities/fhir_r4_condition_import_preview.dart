enum FhirR4ConditionDisposition { previewable, held }

enum FhirR4ConditionDatePrecision { year, month, day, second, fractionalSecond }

/// Caller-declared scope. The Patient reference is compared literally and is
/// never resolved against another resource or service.
final class FhirR4ConditionPreviewContext {
  const FhirR4ConditionPreviewContext({
    required this.fhirVersion,
    required this.jurisdiction,
    required this.expectedPatientReference,
  });

  final String fhirVersion;
  final String jurisdiction;
  final String expectedPatientReference;
}

final class FhirR4ConditionCodingPreview {
  const FhirR4ConditionCodingPreview({
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

/// Source CodeableConcept text and codings, without terminology lookup.
final class FhirR4ConditionConceptPreview {
  const FhirR4ConditionConceptPreview({required this.codings, this.text});

  final List<FhirR4ConditionCodingPreview> codings;
  final String? text;
}

/// Source dateTime retained at its supplied lexical precision.
final class FhirR4ConditionTimePreview {
  const FhirR4ConditionTimePreview({
    required this.lexical,
    required this.precision,
  });

  final String lexical;
  final FhirR4ConditionDatePrecision precision;
}

final class FhirR4ConditionEntryPreview {
  const FhirR4ConditionEntryPreview({
    required this.disposition,
    required this.patientReferenceMatched,
    required this.categories,
    required this.reasonCodes,
    required this.unmappedPaths,
    this.resourceId,
    this.entryFullUrl,
    this.resourceVersionId,
    this.metaSource,
    this.metaLastUpdated,
    this.clinicalStatus,
    this.verificationStatus,
    this.code,
    this.onsetDateTime,
    this.abatementDateTime,
    this.recordedDate,
  });

  final FhirR4ConditionDisposition disposition;

  /// The literal source reference is intentionally never returned or displayed.
  final bool patientReferenceMatched;
  final String? resourceId;
  final String? entryFullUrl;
  final String? resourceVersionId;
  final String? metaSource;
  final FhirR4ConditionTimePreview? metaLastUpdated;

  /// These are source-reported fields, not an interpreted diagnosis state.
  final FhirR4ConditionConceptPreview? clinicalStatus;
  final FhirR4ConditionConceptPreview? verificationStatus;
  final List<FhirR4ConditionConceptPreview> categories;
  final FhirR4ConditionConceptPreview? code;
  final FhirR4ConditionTimePreview? onsetDateTime;
  final FhirR4ConditionTimePreview? abatementDateTime;
  final FhirR4ConditionTimePreview? recordedDate;
  final List<String> reasonCodes;
  final List<String> unmappedPaths;

  bool get previewable => disposition == FhirR4ConditionDisposition.previewable;
}

/// Bounded, in-memory projection of a Condition or collection Bundle.
/// This is not diagnosis interpretation, identity resolution, or FHIR
/// conformance validation.
final class FhirR4ConditionImportPreview {
  const FhirR4ConditionImportPreview({
    required this.context,
    required this.inputSha256,
    required this.entries,
    required this.reasonCodes,
    required this.unmappedPaths,
    required this.containerType,
  });

  static const String schemaUri =
      'parkinsum.fhir-r4-condition-import-preview/1';
  static const String supportedFhirVersion = '4.0.1';
  static const int maximumInputBytes = 128 * 1024;
  static const int maximumEntries = 32;
  static const bool persistsData = false;
  static const bool algorithmEligible = false;

  final FhirR4ConditionPreviewContext context;
  final String inputSha256;
  final String containerType;
  final List<FhirR4ConditionEntryPreview> entries;
  final List<String> reasonCodes;
  final List<String> unmappedPaths;

  bool get previewable =>
      entries.isNotEmpty &&
      reasonCodes.isEmpty &&
      unmappedPaths.isEmpty &&
      entries.every((entry) => entry.previewable);

  int get heldEntryCount => entries.where((entry) => !entry.previewable).length;
}
