/// P7 — LocalizationSafetyLint entities.
///
/// Educational/research prototype only. A safety/governance lint that checks
/// user-visible copy + localization surfaces for missing safety boundaries,
/// missing evidence/limitation wording, placeholder problems, and unsafe
/// prescriptive/overconfident phrases across locales. It is NOT a
/// translation-quality guarantee, NOT a clinical-safety guarantee, adds no
/// medical advice, uses no LLM translation, and does not replace human review.
library;

class LocalizationSafetyLintConfig {
  /// Locales every safety-critical key must cover.
  final List<String> requiredLocales;

  /// The authoritative source locale (e.g. `en`).
  final String sourceLocale;

  /// Keys that must exist in all [requiredLocales] (coverage rule A).
  final List<String> requiredSafetyKeys;

  /// In strict mode, missing-coverage findings escalate to `blocker`.
  final bool strictMode;
  final String deterministicTimestamp;

  const LocalizationSafetyLintConfig({
    this.requiredLocales = const ['en', 'zh', 'fr', 'ja'],
    this.sourceLocale = 'en',
    this.requiredSafetyKeys = const [],
    this.strictMode = false,
    this.deterministicTimestamp = 'synthetic-demo',
  });
}

/// One localized text surface to lint (file I/O lives in the tool wrapper).
class LocalizationSurface {
  final String surfaceId;
  final String locale;
  final String key;
  final String text;

  /// Where this came from, e.g. `safe_copy_template` / `app_i18n` / `report`.
  final String source;

  /// Expected role, e.g. `boundary` / `explanation` / `policy_value` / `plain`.
  final String expectedSafetyRole;

  /// Optional placeholder contract (populated when derived from a template).
  final List<String> allowedPlaceholders;
  final List<String> requiredPlaceholders;

  const LocalizationSurface({
    required this.surfaceId,
    required this.locale,
    required this.key,
    required this.text,
    required this.source,
    this.expectedSafetyRole = 'plain',
    this.allowedPlaceholders = const [],
    this.requiredPlaceholders = const [],
  });

  Map<String, dynamic> toJson() => {
        'surface_id': surfaceId,
        'locale': locale,
        'key': key,
        'source': source,
        'expected_safety_role': expectedSafetyRole,
        // Note: `text` is intentionally omitted from the report JSON to avoid
        // echoing any flagged copy; `matched_text` on findings carries the
        // minimal snippet needed for triage.
      };
}

class LocalizationSafetyFinding {
  /// `info` | `warn` | `blocker`.
  final String severity;
  final String findingType;
  final String surfaceId;
  final String locale;
  final String key;
  final String message;
  final String matchedText;
  final String suggestedFix;
  final String safetyBoundary;

  const LocalizationSafetyFinding({
    required this.severity,
    required this.findingType,
    required this.surfaceId,
    required this.locale,
    required this.key,
    required this.message,
    this.matchedText = '',
    this.suggestedFix = '',
    this.safetyBoundary = '',
  });

  Map<String, dynamic> toJson() => {
        'severity': severity,
        'finding_type': findingType,
        'surface_id': surfaceId,
        'locale': locale,
        'key': key,
        'message': message,
        'matched_text': matchedText,
        'suggested_fix': suggestedFix,
        'safety_boundary': safetyBoundary,
      };
}

class LocalizationSafetyReport {
  static const String kReportType = 'localization_safety_lint';

  final String generatedAt;
  final List<String> requiredLocales;
  final int surfaceCount;
  final Map<String, int> findingCounts; // info / warn / blocker
  final bool pass;
  final List<LocalizationSafetyFinding> findings;
  final String safetyBoundary;
  final String notAdviceText;
  final bool notClinicallyCalibrated;
  final List<String> limitations;

  const LocalizationSafetyReport({
    required this.generatedAt,
    required this.requiredLocales,
    required this.surfaceCount,
    required this.findingCounts,
    required this.pass,
    required this.findings,
    required this.safetyBoundary,
    required this.notAdviceText,
    required this.notClinicallyCalibrated,
    required this.limitations,
  });

  int get blockerCount => findingCounts['blocker'] ?? 0;

  Map<String, dynamic> toJson() => {
        'report_type': kReportType,
        'not_clinically_calibrated': notClinicallyCalibrated,
        'synthetic_demo_data_only': true,
        'no_medical_advice': true,
        'generated_at': generatedAt,
        'required_locales': requiredLocales,
        'surface_count': surfaceCount,
        'finding_counts': findingCounts,
        'pass': pass,
        'findings': findings.map((f) => f.toJson()).toList(growable: false),
        'limitations': limitations,
        'safety_boundary': safetyBoundary,
        'not_advice_text': notAdviceText,
      };
}
