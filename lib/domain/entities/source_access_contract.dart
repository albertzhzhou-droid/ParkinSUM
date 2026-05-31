/// P9 — SourceAccessContract entities.
///
/// Educational/research prototype only. Converts ParkinSUM's source-access and
/// licensing assumptions into a machine-readable contract so `sourceRefs` and
/// source-system usage cannot silently imply more authority or production
/// readiness than they actually have.
///
/// This is **source governance / release-hygiene** metadata only. It is **NOT**
/// legal advice, **NOT** license clearance, **NOT** clinical validation, it
/// performs **no live ingestion**, and it does **not** make any fixture-tested
/// source production-ready. Synthetic/demo data only; no patient/subject/
/// encounter semantics.
library;

/// Finding severity.
class SourceAccessSeverity {
  static const String info = 'info';
  static const String warn = 'warn';
  static const String blocker = 'blocker';
}

/// How an observed reference is being used (supplied by the collector).
class SourceUsageType {
  static const String mechanismEvidence = 'mechanism_evidence';
  static const String identityOrCoding = 'identity_or_coding';
  static const String sourceQuality = 'source_quality';
  static const String fixture = 'fixture';
  static const String documentation = 'documentation';
  static const String modelAssumption = 'model_assumption';
  static const String production = 'production';
  static const String unknown = 'unknown';
}

/// A single record from the machine-readable source access registry.
class SourceAccessRecord {
  final String sourceId;
  final String displayName;
  final String owner;
  final String jurisdiction;
  final String sourceFamily;
  final String dataDomain;
  final String accessMethod;
  final bool requiresApiKey;
  final bool requiresAccount;
  final bool licenseReviewNeeded;
  final bool legalReviewNeeded;
  final String implementationStatus;
  final bool allowedForFixture;
  final bool allowedForLiveSmoke;
  final bool allowedForProduction;
  final bool canSupportMechanismEvidenceAlone;
  final bool canSupportIdentityOrCoding;
  final bool canSupportSourceQualityScoring;
  final List<String> knownLimitations;
  final List<String> documentationRefs;
  final List<String> bibliographyRefs;
  final String lastPolicyReviewed;
  final String notes;

  const SourceAccessRecord({
    required this.sourceId,
    required this.displayName,
    required this.owner,
    required this.jurisdiction,
    required this.sourceFamily,
    required this.dataDomain,
    required this.accessMethod,
    this.requiresApiKey = false,
    this.requiresAccount = false,
    this.licenseReviewNeeded = false,
    this.legalReviewNeeded = false,
    required this.implementationStatus,
    this.allowedForFixture = true,
    this.allowedForLiveSmoke = false,
    this.allowedForProduction = false,
    this.canSupportMechanismEvidenceAlone = false,
    this.canSupportIdentityOrCoding = false,
    this.canSupportSourceQualityScoring = false,
    this.knownLimitations = const [],
    this.documentationRefs = const [],
    this.bibliographyRefs = const [],
    this.lastPolicyReviewed = '',
    this.notes = '',
  });

  /// Statuses that indicate "production ready". Today none of the repo's sources
  /// are production-ready (fixture-tested / spec / documentation only).
  bool get isProductionReady =>
      implementationStatus == 'implemented_production_ready';

  bool get isFixtureOnly =>
      implementationStatus == 'implemented_fixture_tested' ||
      implementationStatus == 'fixture_only';

  bool get isDeprecated => implementationStatus == 'deprecated';

  bool get hasUnknownAccess =>
      accessMethod == 'unknown' || implementationStatus == 'unknown';

  static List<String> _strList(dynamic v) =>
      (v as List?)?.map((e) => e.toString()).toList(growable: false) ??
      const [];

  static bool _b(dynamic v) => v == true;

  factory SourceAccessRecord.fromJson(Map<String, dynamic> j) =>
      SourceAccessRecord(
        sourceId: (j['source_id'] ?? '').toString(),
        displayName: (j['display_name'] ?? '').toString(),
        owner: (j['owner'] ?? '').toString(),
        jurisdiction: (j['jurisdiction'] ?? '').toString(),
        sourceFamily: (j['source_family'] ?? 'unknown').toString(),
        dataDomain: (j['data_domain'] ?? 'unknown').toString(),
        accessMethod: (j['access_method'] ?? 'unknown').toString(),
        requiresApiKey: _b(j['requires_api_key']),
        requiresAccount: _b(j['requires_account']),
        licenseReviewNeeded: _b(j['license_review_needed']),
        legalReviewNeeded: _b(j['legal_review_needed']),
        implementationStatus:
            (j['implementation_status'] ?? 'unknown').toString(),
        allowedForFixture: _b(j['allowed_for_fixture']),
        allowedForLiveSmoke: _b(j['allowed_for_live_smoke']),
        allowedForProduction: _b(j['allowed_for_production']),
        canSupportMechanismEvidenceAlone:
            _b(j['can_support_mechanism_evidence_alone']),
        canSupportIdentityOrCoding: _b(j['can_support_identity_or_coding']),
        canSupportSourceQualityScoring:
            _b(j['can_support_source_quality_scoring']),
        knownLimitations: _strList(j['known_limitations']),
        documentationRefs: _strList(j['documentation_refs']),
        bibliographyRefs: _strList(j['bibliography_refs']),
        lastPolicyReviewed: (j['last_policy_reviewed'] ?? '').toString(),
        notes: (j['notes'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'source_id': sourceId,
        'display_name': displayName,
        'owner': owner,
        'jurisdiction': jurisdiction,
        'source_family': sourceFamily,
        'data_domain': dataDomain,
        'access_method': accessMethod,
        'requires_api_key': requiresApiKey,
        'requires_account': requiresAccount,
        'license_review_needed': licenseReviewNeeded,
        'legal_review_needed': legalReviewNeeded,
        'implementation_status': implementationStatus,
        'allowed_for_fixture': allowedForFixture,
        'allowed_for_live_smoke': allowedForLiveSmoke,
        'allowed_for_production': allowedForProduction,
        'can_support_mechanism_evidence_alone':
            canSupportMechanismEvidenceAlone,
        'can_support_identity_or_coding': canSupportIdentityOrCoding,
        'can_support_source_quality_scoring': canSupportSourceQualityScoring,
        'known_limitations': knownLimitations,
        'documentation_refs': documentationRefs,
        'bibliography_refs': bibliographyRefs,
        'last_policy_reviewed': lastPolicyReviewed,
        'notes': notes,
      };
}

/// Parsed registry: records keyed by source id, plus policy metadata.
class SourceAccessContract {
  final String registryType;
  final String version;
  final String safetyBoundary;
  final String companionDoc;
  final Map<String, SourceAccessRecord> records;

  const SourceAccessContract({
    this.registryType = 'source_access_registry',
    this.version = '',
    this.safetyBoundary = '',
    this.companionDoc = '',
    required this.records,
  });

  SourceAccessRecord? operator [](String id) => records[id];
  bool contains(String id) => records.containsKey(id);
  int get sourceCount => records.length;

  factory SourceAccessContract.fromJson(Map<String, dynamic> j) {
    final list = (j['sources'] as List?) ?? const [];
    final map = <String, SourceAccessRecord>{};
    for (final e in list) {
      final r = SourceAccessRecord.fromJson(e as Map<String, dynamic>);
      if (r.sourceId.isNotEmpty) map[r.sourceId] = r;
    }
    return SourceAccessContract(
      registryType: (j['registry_type'] ?? 'source_access_registry').toString(),
      version: (j['version'] ?? '').toString(),
      safetyBoundary: (j['safety_boundary'] ?? '').toString(),
      companionDoc: (j['companion_doc'] ?? '').toString(),
      records: map,
    );
  }

  Map<String, dynamic> toJson() => {
        'registry_type': registryType,
        'version': version,
        'safety_boundary': safetyBoundary,
        'companion_doc': companionDoc,
        'sources': (records.keys.toList()..sort())
            .map((k) => records[k]!.toJson())
            .toList(growable: false),
      };
}

/// One observed reference to a source id from code/docs/tests/artifacts.
class ObservedSourceRef {
  final String sourceId;
  final String file;
  final String role;
  final String usageType;

  const ObservedSourceRef({
    required this.sourceId,
    required this.file,
    this.role = '',
    this.usageType = SourceUsageType.unknown,
  });

  /// Whether the reference comes from a docs surface (affects severity).
  bool get isDoc =>
      file.endsWith('.md') ||
      file.startsWith('docs/') ||
      file == 'Bibliographies.md';

  Map<String, dynamic> toJson() => {
        'source_id': sourceId,
        'file': file,
        'role': role,
        'usage_type': usageType,
      };
}

class SourceAccessFinding {
  final String severity;
  final String findingType;
  final String sourceId;
  final String file;
  final String message;
  final String suggestedFix;
  final String safetyBoundary;

  const SourceAccessFinding({
    required this.severity,
    required this.findingType,
    required this.sourceId,
    required this.file,
    required this.message,
    this.suggestedFix = '',
    this.safetyBoundary = '',
  });

  Map<String, dynamic> toJson() => {
        'severity': severity,
        'finding_type': findingType,
        'source_id': sourceId,
        'file': file,
        'message': message,
        'suggested_fix': suggestedFix,
        'safety_boundary': safetyBoundary,
      };
}

class SourceAccessContractReport {
  static const String kReportType = 'source_access_contract';

  final String generatedAt;
  final String registryPath;
  final int sourceCount;
  final int referenceCount;
  final Map<String, int> counts; // info / warn / blocker
  final bool pass;
  final List<SourceAccessFinding> findings;
  final String safetyBoundary;
  final bool notClinicallyCalibrated;
  final List<String> limitations;

  const SourceAccessContractReport({
    required this.generatedAt,
    required this.registryPath,
    required this.sourceCount,
    required this.referenceCount,
    required this.counts,
    required this.pass,
    required this.findings,
    required this.safetyBoundary,
    required this.notClinicallyCalibrated,
    required this.limitations,
  });

  int get blockerCount => counts['blocker'] ?? 0;

  Map<String, dynamic> toJson() => {
        'report_type': kReportType,
        'not_clinically_calibrated': notClinicallyCalibrated,
        'not_legal_advice': true,
        'not_license_clearance': true,
        'no_live_ingestion': true,
        'generated_at': generatedAt,
        'registry_path': registryPath,
        'source_count': sourceCount,
        'reference_count': referenceCount,
        'counts': counts,
        'pass': pass,
        'findings': findings.map((f) => f.toJson()).toList(growable: false),
        'limitations': limitations,
        'safety_boundary': safetyBoundary,
      };
}
