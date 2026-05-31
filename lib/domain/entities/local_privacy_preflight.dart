/// P8 — LocalPrivacyPreflight entities.
///
/// Educational/research prototype only. A stricter **repo-hygiene / privacy-risk**
/// preflight that complements `npm run public:preflight`. It detects PHI-like /
/// patient-like data, raw private exports, local machine paths, secret-like
/// strings, operator logs, and real-health-story patterns. It is **NOT** a
/// HIPAA/GDPR/PIPEDA compliance check, **not** a legal certification, **not**
/// clinical validation, and does **not** prove the app is secure — it reduces the
/// risk of accidentally publishing sensitive data or secrets. Synthetic/demo
/// data only.
library;

/// Severity levels for a privacy finding.
class LocalPrivacySeverity {
  static const String info = 'info';
  static const String warn = 'warn';
  static const String blocker = 'blocker';
}

/// Finding categories (rule families).
class LocalPrivacyCategory {
  static const String secret = 'secret';
  static const String phiLikeField = 'phi_like_field';
  static const String localPath = 'local_path';
  static const String rawExport = 'raw_export';
  static const String healthNarrative = 'health_narrative';
  static const String generatedDir = 'generated_dir';
}

class LocalPrivacyPreflightConfig {
  final String rootPath;
  final List<String> scanGlobs;
  final List<String> excludeGlobs;
  final bool strictMode;
  final String deterministicTimestamp;

  /// Public Firebase **client** config paths (Web API key here stays WARN).
  final List<String> knownPublicFirebaseConfigPaths;

  /// Safe policy values that must never be flagged (e.g.
  /// `no_patient_no_subject_no_encounter`).
  final List<String> allowedSafetyPolicyValues;

  /// Generated/local directories reported (WARN) but not blocked.
  final List<String> allowedGeneratedDirs;

  const LocalPrivacyPreflightConfig({
    this.rootPath = '.',
    this.scanGlobs = const [],
    this.excludeGlobs = const [],
    this.strictMode = false,
    this.deterministicTimestamp = 'synthetic-demo',
    this.knownPublicFirebaseConfigPaths = const [
      'lib/firebase_options.dart',
      'android/app/google-services.json',
      'ios/Runner/GoogleService-Info.plist',
      'macos/Runner/GoogleService-Info.plist',
    ],
    this.allowedSafetyPolicyValues = const [
      'subject_omitted_no_phi',
      'no_patient_no_subject_no_encounter',
      'no_patient_no_administration_no_phi',
      'not_clinically_calibrated',
      'synthetic_demo_only',
      'synthetic_demo_data_only',
    ],
    this.allowedGeneratedDirs = const [
      'build/',
      '.dart_tool/',
      'coverage/',
      'node_modules/',
      '.firebase/',
    ],
  });
}

/// A file (or directory) considered for scanning. The scanner is pure: callers
/// (e.g. the CLI) supply targets + content; tests supply in-memory fixtures.
class LocalPrivacyScanTarget {
  final String path;

  /// `file` / `directory` / `binary`.
  final String kind;
  final int sizeBytes;
  final bool included;
  final String skipReason;

  /// Text content (empty for skipped/binary/directory targets).
  final String content;

  const LocalPrivacyScanTarget({
    required this.path,
    required this.kind,
    required this.sizeBytes,
    required this.included,
    this.skipReason = '',
    this.content = '',
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'kind': kind,
        'size_bytes': sizeBytes,
        'included': included,
        'skip_reason': skipReason,
      };
}

class LocalPrivacyFinding {
  final String severity;
  final String findingType;
  final String file;
  final int line;
  final String message;
  final String matchedText;
  final String category;
  final String suggestedFix;
  final String allowlistReason;
  final String safetyBoundary;

  const LocalPrivacyFinding({
    required this.severity,
    required this.findingType,
    required this.file,
    required this.line,
    required this.message,
    this.matchedText = '',
    this.category = '',
    this.suggestedFix = '',
    this.allowlistReason = '',
    this.safetyBoundary = '',
  });

  Map<String, dynamic> toJson() => {
        'severity': severity,
        'finding_type': findingType,
        'file': file,
        'line': line,
        'message': message,
        'matched_text': matchedText,
        'category': category,
        'suggested_fix': suggestedFix,
        'allowlist_reason': allowlistReason,
        'safety_boundary': safetyBoundary,
      };
}

class LocalPrivacyPreflightReport {
  static const String kReportType = 'local_privacy_preflight';

  final String generatedAt;
  final String root;
  final int scannedFiles;
  final int skippedFiles;
  final Map<String, int> counts; // info / warn / blocker
  final bool pass;
  final List<LocalPrivacyFinding> findings;
  final String safetyBoundary;
  final String notAdviceText;
  final bool notClinicallyCalibrated;
  final List<String> limitations;

  const LocalPrivacyPreflightReport({
    required this.generatedAt,
    required this.root,
    required this.scannedFiles,
    required this.skippedFiles,
    required this.counts,
    required this.pass,
    required this.findings,
    required this.safetyBoundary,
    required this.notAdviceText,
    required this.notClinicallyCalibrated,
    required this.limitations,
  });

  int get blockerCount => counts['blocker'] ?? 0;

  Map<String, dynamic> toJson() => {
        'report_type': kReportType,
        'not_clinically_calibrated': notClinicallyCalibrated,
        'synthetic_demo_data_only': true,
        'no_medical_advice': true,
        'generated_at': generatedAt,
        'root': root,
        'scanned_files': scannedFiles,
        'skipped_files': skippedFiles,
        'counts': counts,
        'pass': pass,
        'findings': findings.map((f) => f.toJson()).toList(growable: false),
        'limitations': limitations,
        'safety_boundary': safetyBoundary,
        'not_advice_text': notAdviceText,
      };
}
