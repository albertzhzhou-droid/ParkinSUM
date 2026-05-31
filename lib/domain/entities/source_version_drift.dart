/// P3 — SourceVersionDrift entities.
///
/// Educational/research prototype only. A deterministic **provenance /
/// release-hygiene** drift checker over local source/version metadata
/// (source-access registry, model assumptions, bibliography, source adapters,
/// generated build artifacts, docs).
///
/// It does **NOT** fetch or update live source data, is **NOT** legal/license
/// clearance, **NOT** clinical validation, **NOT** clinical calibration, and
/// does **NOT** prove medical correctness. It only detects metadata/version
/// drift from the local files available. Synthetic/demo data only; no PHI /
/// patient / subject / encounter semantics.
library;

class SourceVersionDriftSeverity {
  static const String info = 'info';
  static const String warn = 'warn';
  static const String blocker = 'blocker';
}

/// Kinds of record the checker reasons over.
class SourceVersionRecordType {
  static const String sourceDocument = 'source_document';
  static const String sourceAccessRegistry = 'source_access_registry';
  static const String modelAssumption = 'model_assumption';
  static const String bibliographyEntry = 'bibliography_entry';
  static const String sourceAdapter = 'source_adapter';
  static const String importerFixture = 'importer_fixture';
  static const String generatedArtifact = 'generated_artifact';
  static const String documentation = 'documentation';
  static const String unknown = 'unknown';
}

class SourceVersionDriftFindingType {
  static const String missingSourceId = 'missing_source_id';
  static const String missingVersion = 'missing_version';
  static const String missingEffectiveDate = 'missing_effective_date';
  static const String missingLastChecked = 'missing_last_checked';
  static const String missingPolicyReviewDate = 'missing_policy_review_date';
  static const String generatedArtifactMissing = 'generated_artifact_missing';
  static const String generatedArtifactStale = 'generated_artifact_stale';
  static const String bibliographyMissing = 'bibliography_missing';
  static const String bibliographyMismatch = 'bibliography_mismatch';
  static const String sourceRegistryMismatch = 'source_registry_mismatch';
  static const String fixtureStatusMismatch = 'fixture_status_mismatch';
  static const String unknownImplementationStatus =
      'unknown_implementation_status';
  static const String deprecatedSourceUsed = 'deprecated_source_used';
  static const String projectionVersionMissing = 'projection_version_missing';
  static const String assumptionRegistryUnreferenced =
      'assumption_registry_unreferenced';
  static const String documentationClaimMismatch =
      'documentation_claim_mismatch';
}

/// One source/version metadata record (supplied by the CLI collector or tests).
class SourceVersionRecord {
  final String recordId;
  final String sourceId;
  final String sourceFamily;
  final String recordType;
  final String file;
  final String version;
  final String effectiveDate;
  final String lastChecked;
  final String lastPolicyReviewed;

  /// ISO-8601 timestamp for generated artifacts (empty when none).
  final String generatedAt;
  final String implementationStatus;
  final List<String> bibliographyRefs;
  final List<String> documentationRefs;
  final List<String> sourceRefs;
  final List<String> limitations;

  /// Free-form string metadata. Recognized keys include:
  /// `exists` ('true'/'false'), `expected` ('true'/'false'),
  /// `optional` ('true'/'false'), `production_claim` ('true'/'false'),
  /// `doc_says_production` ('true'/'false'), `mechanism_role` ('true'/'false').
  final Map<String, String> metadata;

  const SourceVersionRecord({
    required this.recordId,
    this.sourceId = '',
    this.sourceFamily = '',
    required this.recordType,
    this.file = '',
    this.version = '',
    this.effectiveDate = '',
    this.lastChecked = '',
    this.lastPolicyReviewed = '',
    this.generatedAt = '',
    this.implementationStatus = '',
    this.bibliographyRefs = const [],
    this.documentationRefs = const [],
    this.sourceRefs = const [],
    this.limitations = const [],
    this.metadata = const {},
  });

  bool get isFixtureOnly =>
      implementationStatus == 'implemented_fixture_tested' ||
      implementationStatus == 'fixture_only' ||
      implementationStatus == 'fixture_tested';

  bool get claimsProductionReady =>
      implementationStatus == 'implemented_production_ready' ||
      implementationStatus == 'production_ready' ||
      implementationStatus == 'production_parser' ||
      metadata['production_claim'] == 'true';

  bool get isDeprecated => implementationStatus == 'deprecated';

  bool get hasUnknownStatus =>
      implementationStatus.isEmpty || implementationStatus == 'unknown';

  bool get exists => metadata['exists'] != 'false';
  bool get isExpected => metadata['expected'] == 'true';
  bool get isOptional => metadata['optional'] == 'true';
  bool get isMechanismRole => metadata['mechanism_role'] == 'true';

  Map<String, dynamic> toJson() => {
        'record_id': recordId,
        'source_id': sourceId,
        'source_family': sourceFamily,
        'record_type': recordType,
        'file': file,
        'version': version,
        'effective_date': effectiveDate,
        'last_checked': lastChecked,
        'last_policy_reviewed': lastPolicyReviewed,
        'generated_at': generatedAt,
        'implementation_status': implementationStatus,
        'bibliography_refs': bibliographyRefs,
        'documentation_refs': documentationRefs,
        'source_refs': sourceRefs,
        'limitations': limitations,
        'metadata': metadata,
      };
}

class SourceVersionDriftFinding {
  final String severity;
  final String findingType;
  final String sourceId;
  final String recordId;
  final String file;
  final String message;
  final String suggestedFix;
  final String safetyBoundary;

  const SourceVersionDriftFinding({
    required this.severity,
    required this.findingType,
    required this.sourceId,
    required this.recordId,
    required this.file,
    required this.message,
    this.suggestedFix = '',
    this.safetyBoundary = '',
  });

  Map<String, dynamic> toJson() => {
        'severity': severity,
        'finding_type': findingType,
        'source_id': sourceId,
        'record_id': recordId,
        'file': file,
        'message': message,
        'suggested_fix': suggestedFix,
        'safety_boundary': safetyBoundary,
      };
}

class SourceVersionDriftReport {
  static const String kReportType = 'source_version_drift';

  final String generatedAt;
  final int recordCount;
  final Map<String, int> findingCounts; // info / warn / blocker
  final bool pass;
  final List<SourceVersionRecord> records;
  final List<SourceVersionDriftFinding> findings;
  final String safetyBoundary;
  final bool notClinicallyCalibrated;
  final List<String> limitations;

  const SourceVersionDriftReport({
    required this.generatedAt,
    required this.recordCount,
    required this.findingCounts,
    required this.pass,
    required this.records,
    required this.findings,
    required this.safetyBoundary,
    required this.notClinicallyCalibrated,
    required this.limitations,
  });

  int get blockerCount => findingCounts['blocker'] ?? 0;

  Map<String, dynamic> toJson() => {
        'report_type': kReportType,
        'not_clinically_calibrated': notClinicallyCalibrated,
        'no_live_fetch': true,
        'not_legal_or_license_clearance': true,
        'generated_at': generatedAt,
        'record_count': recordCount,
        'finding_counts': findingCounts,
        'pass': pass,
        'records': records.map((r) => r.toJson()).toList(growable: false),
        'findings': findings.map((f) => f.toJson()).toList(growable: false),
        'limitations': limitations,
        'safety_boundary': safetyBoundary,
      };
}

/// Optional configuration.
class SourceVersionDriftConfig {
  /// Deterministic "now" used for staleness comparison (ISO-8601). Tests pass a
  /// fixed value so results are reproducible.
  final String referenceTimestamp;

  /// Staleness threshold in days for generated artifacts.
  final int stalenessThresholdDays;

  /// When true, selected WARN findings escalate to BLOCKER.
  final bool strictMode;

  const SourceVersionDriftConfig({
    this.referenceTimestamp = '',
    this.stalenessThresholdDays = 180,
    this.strictMode = false,
  });
}
