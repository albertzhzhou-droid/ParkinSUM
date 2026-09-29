enum FhirR4ObservationImportDisposition { previewable, held }

/// Caller-supplied context for a local FHIR Observation preview.
///
/// None of these values is inferred from the resource. The preview does not
/// persist the context or observation and never feeds a result-producing rule.
final class FhirR4ObservationImportContext {
  const FhirR4ObservationImportContext({
    required this.sourceFhirBase,
    required this.fhirVersion,
    required this.jurisdiction,
    required this.expectedPatientReference,
  });

  final String sourceFhirBase;
  final String fhirVersion;
  final String jurisdiction;
  final String expectedPatientReference;
}

/// One BP component as observed in the imported FHIR resource.
///
/// `value` and `dataAbsentReasonCode` remain separate so an unknown value is
/// never converted to zero or conflated with a measurement that was not taken.
final class FhirR4ObservationComponentPreview {
  const FhirR4ObservationComponentPreview({
    required this.code,
    required this.codeSystem,
    required this.codeSystemVersion,
    this.codeDisplay,
    this.codeConceptText,
    this.value,
    this.comparator,
    this.unitDisplay,
    this.unitSystem,
    this.unitCode,
    this.dataAbsentReasonCode,
    this.dataAbsentReasonSystem,
    this.dataAbsentReasonVersion,
    this.dataAbsentReasonDisplay,
    this.dataAbsentReasonText,
  });

  final String code;
  final String codeSystem;
  final String? codeSystemVersion;
  final String? codeDisplay;
  final String? codeConceptText;
  final num? value;
  final String? comparator;
  final String? unitDisplay;
  final String? unitSystem;
  final String? unitCode;
  final String? dataAbsentReasonCode;
  final String? dataAbsentReasonSystem;
  final String? dataAbsentReasonVersion;
  final String? dataAbsentReasonDisplay;
  final String? dataAbsentReasonText;
}

/// A versioned, in-memory preview of a narrowly supported FHIR R4 BP panel.
///
/// This is not an imported/persisted personal record, a FHIR validator, or a
/// clinical result. Values are preview-only until a separate provenance-aware
/// persistence and review workflow is implemented.
final class FhirR4ObservationImportPreview {
  const FhirR4ObservationImportPreview({
    required this.disposition,
    required this.context,
    required this.reasonCodes,
    required this.unmappedPaths,
    this.resourceId,
    this.resourceVersionId,
    this.metaSource,
    this.metaLastUpdatedLexical,
    this.metaLastUpdatedUtc,
    this.status,
    this.observationCodeVersion,
    this.observationCodeDisplay,
    this.observationCodeText,
    this.subjectReference,
    this.effectiveDateTimeLexical,
    this.effectiveAtUtc,
    this.issuedLexical,
    this.issuedAtUtc,
    this.components = const <FhirR4ObservationComponentPreview>[],
  });

  static const String schemaUri =
      'parkinsum.fhir-r4-observation-import-preview/1';
  static const String supportedFhirVersion = '4.0.1';
  static const String loincSystem = 'http://loinc.org';
  static const String ucumSystem = 'http://unitsofmeasure.org';
  static const String dataAbsentReasonSystem =
      'http://terminology.hl7.org/CodeSystem/data-absent-reason';
  static const String bloodPressurePanelCode = '85354-9';
  static const String systolicCode = '8480-6';
  static const String diastolicCode = '8462-4';
  static const String bloodPressureUnitCode = 'mm[Hg]';

  static const bool persistsData = false;
  static const bool algorithmEligible = false;

  final FhirR4ObservationImportDisposition disposition;
  final FhirR4ObservationImportContext context;
  final String? resourceId;
  final String? resourceVersionId;
  final String? metaSource;
  final String? metaLastUpdatedLexical;
  final DateTime? metaLastUpdatedUtc;
  final String? status;
  final String? observationCodeVersion;
  final String? observationCodeDisplay;
  final String? observationCodeText;
  final String? subjectReference;
  final String? effectiveDateTimeLexical;
  final DateTime? effectiveAtUtc;
  final String? issuedLexical;
  final DateTime? issuedAtUtc;
  final List<FhirR4ObservationComponentPreview> components;
  final List<String> reasonCodes;
  final List<String> unmappedPaths;

  bool get previewable =>
      disposition == FhirR4ObservationImportDisposition.previewable;
}
