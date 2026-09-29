enum FhirR4EncounterDisposition { previewable, held }

/// Caller-declared scope for one local Encounter preview.
final class FhirR4EncounterImportContext {
  const FhirR4EncounterImportContext({
    required this.fhirVersion,
    required this.jurisdiction,
    required this.expectedPatientReference,
  });

  final String fhirVersion;
  final String jurisdiction;
  final String expectedPatientReference;
}

/// Coding values are copied as source claims; no terminology lookup occurs.
final class FhirR4EncounterClassPreview {
  const FhirR4EncounterClassPreview({
    this.system,
    this.version,
    this.code,
    this.display,
  });

  final String? system;
  final String? version;
  final String? code;
  final String? display;
}

/// Encounter period endpoints retain their exact supplied lexical precision.
final class FhirR4EncounterTimePreview {
  const FhirR4EncounterTimePreview(this.lexical);

  final String lexical;
}

final class FhirR4EncounterEntryPreview {
  const FhirR4EncounterEntryPreview({
    required this.disposition,
    required this.patientReferenceMatched,
    required this.status,
    required this.encounterClass,
    required this.reasonCodes,
    required this.unmappedPaths,
    this.periodStart,
    this.periodEnd,
  });

  final FhirR4EncounterDisposition disposition;

  /// Only the match result is exposed; the source Patient reference is omitted.
  final bool patientReferenceMatched;

  /// These are source-reported values, not a care-state interpretation.
  final String? status;
  final FhirR4EncounterClassPreview? encounterClass;
  final FhirR4EncounterTimePreview? periodStart;
  final FhirR4EncounterTimePreview? periodEnd;
  final List<String> reasonCodes;
  final List<String> unmappedPaths;

  bool get previewable => disposition == FhirR4EncounterDisposition.previewable;
}

/// Bounded, in-memory FHIR R4 Encounter projection for engineering review.
/// It is neither persisted nor eligible for a ParkinSUM algorithm.
final class FhirR4EncounterImportPreview {
  const FhirR4EncounterImportPreview({
    required this.context,
    required this.inputSha256,
    required this.containerType,
    required this.entries,
    required this.reasonCodes,
    required this.unmappedPaths,
  });

  static const String schemaUri =
      'parkinsum.fhir-r4-encounter-import-preview/1';
  static const String supportedFhirVersion = '4.0.1';
  static const int maximumInputBytes = 128 * 1024;
  static const int maximumEntries = 32;
  static const bool persistsData = false;
  static const bool algorithmEligible = false;

  final FhirR4EncounterImportContext context;
  final String inputSha256;
  final String containerType;
  final List<FhirR4EncounterEntryPreview> entries;
  final List<String> reasonCodes;
  final List<String> unmappedPaths;

  bool get previewable =>
      entries.isNotEmpty &&
      reasonCodes.isEmpty &&
      unmappedPaths.isEmpty &&
      entries.every((entry) => entry.previewable);

  int get heldEntryCount => entries.where((entry) => !entry.previewable).length;
}
