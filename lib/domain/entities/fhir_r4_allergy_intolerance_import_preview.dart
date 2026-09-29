enum FhirR4AllergyPreviewDisposition { previewable, held }

enum FhirR4AllergyTimePrecision { year, month, day, second, fractionalSecond }

/// Caller-declared scope. The patient reference is compared as supplied and
/// is never resolved against another resource or service.
final class FhirR4AllergyPreviewContext {
  const FhirR4AllergyPreviewContext({
    required this.fhirVersion,
    required this.jurisdiction,
    required this.expectedPatientReference,
  });

  final String fhirVersion;
  final String jurisdiction;
  final String expectedPatientReference;
}

final class FhirR4AllergyCodingPreview {
  const FhirR4AllergyCodingPreview({
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

/// The supplied CodeableConcept text and codings, without terminology lookup.
final class FhirR4AllergyConceptPreview {
  const FhirR4AllergyConceptPreview({required this.codings, this.text});

  final List<FhirR4AllergyCodingPreview> codings;
  final String? text;
}

/// A source dateTime retained with its original lexical precision.
final class FhirR4AllergyTimePreview {
  const FhirR4AllergyTimePreview({
    required this.lexical,
    required this.precision,
  });

  final String lexical;
  final FhirR4AllergyTimePrecision precision;
}

final class FhirR4AllergyReactionPreview {
  const FhirR4AllergyReactionPreview({
    required this.manifestations,
    required this.unmappedPaths,
    this.substance,
    this.onset,
    this.severity,
    this.exposureRoute,
  });

  final FhirR4AllergyConceptPreview? substance;
  final List<FhirR4AllergyConceptPreview> manifestations;
  final FhirR4AllergyTimePreview? onset;
  final String? severity;
  final FhirR4AllergyConceptPreview? exposureRoute;
  final List<String> unmappedPaths;
}

final class FhirR4AllergyIntoleranceEntryPreview {
  const FhirR4AllergyIntoleranceEntryPreview({
    required this.disposition,
    required this.reasonCodes,
    required this.unmappedPaths,
    required this.category,
    required this.reactions,
    required this.patientReferenceMatched,
    this.resourceId,
    this.resourceVersionId,
    this.metaSource,
    this.metaLastUpdated,
    this.clinicalStatus,
    this.verificationStatus,
    this.type,
    this.criticality,
    this.code,
    this.onset,
    this.recordedDate,
    this.lastOccurrence,
  });

  final FhirR4AllergyPreviewDisposition disposition;
  final List<String> reasonCodes;
  final List<String> unmappedPaths;
  final bool patientReferenceMatched;
  final String? resourceId;
  final String? resourceVersionId;
  final String? metaSource;
  final FhirR4AllergyTimePreview? metaLastUpdated;

  /// These remain distinct source-reported concepts; neither is a conclusion.
  final FhirR4AllergyConceptPreview? clinicalStatus;
  final FhirR4AllergyConceptPreview? verificationStatus;
  final String? type;
  final List<String> category;
  final String? criticality;
  final FhirR4AllergyConceptPreview? code;
  final FhirR4AllergyTimePreview? onset;
  final FhirR4AllergyTimePreview? recordedDate;
  final FhirR4AllergyTimePreview? lastOccurrence;
  final List<FhirR4AllergyReactionPreview> reactions;

  bool get previewable =>
      disposition == FhirR4AllergyPreviewDisposition.previewable;
}

/// Bounded, in-memory projection of an AllergyIntolerance or collection.
/// This is not clinical interpretation, identity resolution, or FHIR validation.
final class FhirR4AllergyIntoleranceImportPreview {
  const FhirR4AllergyIntoleranceImportPreview({
    required this.context,
    required this.inputSha256,
    required this.entries,
    required this.reasonCodes,
    required this.unmappedPaths,
    this.containerType,
  });

  static const String schemaUri =
      'parkinsum.fhir-r4-allergy-intolerance-import-preview/1';
  static const String supportedFhirVersion = '4.0.1';
  static const int maximumInputBytes = 128 * 1024;
  static const int maximumEntries = 32;
  static const bool persistsData = false;
  static const bool algorithmEligible = false;

  final FhirR4AllergyPreviewContext context;
  final String inputSha256;
  final String? containerType;
  final List<FhirR4AllergyIntoleranceEntryPreview> entries;
  final List<String> reasonCodes;
  final List<String> unmappedPaths;

  bool get previewable =>
      entries.isNotEmpty &&
      reasonCodes.isEmpty &&
      unmappedPaths.isEmpty &&
      entries.every((entry) => entry.previewable);

  int get heldEntryCount => entries.where((entry) => !entry.previewable).length;
}
