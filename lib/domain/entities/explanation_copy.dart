/// P6 — ExplanationCopy entities (the compiler layer over SafeCopyTemplate).
///
/// Educational/research prototype only. The ExplanationCopyCompiler renders and
/// VALIDATES non-prescriptive user-facing copy from `SafeCopyTemplate`s: it binds
/// placeholders, checks required safety/evidence terms, rejects banned
/// prescriptive phrases, and enforces source/limitation/not-advice requirements.
///
/// It adds no medical advice, no dose/timing/diet guidance, and no
/// clinical-calibration claim. It does not wire copy into the UI or scoring; it
/// is a deterministic copy-compilation + validation layer. No PHI / patient /
/// subject / encounter semantics.
library;

class CopyCompileSeverity {
  static const String info = 'info';
  static const String warn = 'warn';
  static const String blocker = 'blocker';
}

class CopyCompileFindingType {
  static const String missingRequiredPlaceholder =
      'missing_required_placeholder';
  static const String unknownPlaceholder = 'unknown_placeholder';
  static const String unresolvedPlaceholder = 'unresolved_placeholder';
  static const String missingSafetyTerm = 'missing_safety_term';
  static const String missingEvidenceTerm = 'missing_evidence_term';
  static const String bannedPhrase = 'banned_phrase';
  static const String localeFallback = 'locale_fallback';
  static const String requiresSourceRefsUnsatisfied =
      'requires_source_refs_unsatisfied';
  static const String requiresLimitationUnsatisfied =
      'requires_limitation_unsatisfied';
  static const String requiresNotAdviceUnsatisfied =
      'requires_not_advice_unsatisfied';
}

/// Context the caller supplies to satisfy a template's structural requirements
/// (never fabricated by the compiler).
class CopyCompileContext {
  final List<String> sourceRefs;
  final bool hasLimitationText;
  final bool hasNotAdviceText;

  const CopyCompileContext({
    this.sourceRefs = const [],
    this.hasLimitationText = false,
    this.hasNotAdviceText = false,
  });
}

/// A successfully rendered copy string + its provenance.
class CompiledCopy {
  final String templateId;
  final String outputType;
  final String locale;
  final bool usedDefaultLocaleFallback;
  final String text;
  final Map<String, String> boundPlaceholders;

  const CompiledCopy({
    required this.templateId,
    required this.outputType,
    required this.locale,
    required this.usedDefaultLocaleFallback,
    required this.text,
    required this.boundPlaceholders,
  });

  Map<String, dynamic> toJson() => {
        'template_id': templateId,
        'output_type': outputType,
        'locale': locale,
        'used_default_locale_fallback': usedDefaultLocaleFallback,
        'text': text,
        'bound_placeholders': boundPlaceholders,
      };
}

class CopyCompileFinding {
  final String severity;
  final String findingType;
  final String templateId;
  final String locale;
  final String message;
  final String detail;

  const CopyCompileFinding({
    required this.severity,
    required this.findingType,
    required this.templateId,
    required this.locale,
    required this.message,
    this.detail = '',
  });

  Map<String, dynamic> toJson() => {
        'severity': severity,
        'finding_type': findingType,
        'template_id': templateId,
        'locale': locale,
        'message': message,
        'detail': detail,
      };
}

/// Result of compiling one template (rendered copy when valid, plus findings).
class CopyCompileResult {
  final CompiledCopy? compiled;
  final List<CopyCompileFinding> findings;

  const CopyCompileResult({required this.compiled, required this.findings});

  bool get hasBlocker =>
      findings.any((f) => f.severity == CopyCompileSeverity.blocker);
  bool get valid => compiled != null && !hasBlocker;
}

/// Aggregate report for compiling a set of templates.
class CopyCompileReport {
  static const String kReportType = 'explanation_copy_compile';

  final String generatedAt;
  final int templateCount;
  final int compiledCount;
  final Map<String, int> counts; // info / warn / blocker
  final bool pass;
  final List<CompiledCopy> compiled;
  final List<CopyCompileFinding> findings;
  final String safetyBoundary;
  final bool notClinicallyCalibrated;
  final List<String> limitations;

  const CopyCompileReport({
    required this.generatedAt,
    required this.templateCount,
    required this.compiledCount,
    required this.counts,
    required this.pass,
    required this.compiled,
    required this.findings,
    required this.safetyBoundary,
    required this.notClinicallyCalibrated,
    required this.limitations,
  });

  int get blockerCount => counts['blocker'] ?? 0;

  Map<String, dynamic> toJson() => {
        'report_type': kReportType,
        'not_clinically_calibrated': notClinicallyCalibrated,
        'no_medical_advice': true,
        'not_wired_into_ui_or_scoring': true,
        'generated_at': generatedAt,
        'template_count': templateCount,
        'compiled_count': compiledCount,
        'counts': counts,
        'pass': pass,
        'compiled': compiled.map((c) => c.toJson()).toList(growable: false),
        'findings': findings.map((f) => f.toJson()).toList(growable: false),
        'limitations': limitations,
        'safety_boundary': safetyBoundary,
      };
}
