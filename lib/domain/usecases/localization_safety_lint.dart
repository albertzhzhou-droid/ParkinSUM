/// P7 — LocalizationSafetyLint usecase.
///
/// Educational/research prototype only. Deterministic, pure lint over a list of
/// `LocalizationSurface` entries (file I/O lives in the tool wrapper). Checks
/// locale coverage, safety-boundary presence, evidence/limitation wording,
/// placeholder validity, and unsafe prescriptive/overconfident phrases across
/// locales. Not a translation-quality or clinical-safety guarantee; no LLM; does
/// not replace human review.
library;

import 'dart:convert';

import '../entities/localization_safety_lint.dart';
import '../entities/rule_explanation.dart';
import '../entities/safe_copy_template.dart';

class LocalizationSafetyLint {
  const LocalizationSafetyLint();

  /// Finding-type constants.
  static const String missingLocaleCoverage = 'missing_locale_coverage';
  static const String missingSafetyBoundary = 'missing_safety_boundary';
  static const String missingEvidenceTerms = 'missing_evidence_terms';
  static const String bannedPhrase = 'banned_phrase';
  static const String overconfidence = 'overconfidence';
  static const String unknownPlaceholder = 'unknown_placeholder';
  static const String missingRequiredPlaceholder =
      'missing_required_placeholder';
  static const String noLocaleDictionaryDiscovered =
      'no_locale_dictionary_discovered';

  static const List<String> _limitations = [
    'Checks copy safety + localization coverage only; not a translation-quality guarantee.',
    'Not a clinical-safety guarantee; adds no medical advice; uses no LLM translation.',
    'Multilingual banned-phrase patterns are a conservative v1; does not replace human review.',
    'Deterministic over the surfaces it is given; full-dictionary coverage is future work.',
  ];

  /// Multilingual banned-phrase families (conservative v1). Lowercased compare
  /// for Latin scripts; direct contains for CJK.
  static const Map<String, List<String>> bannedFamilies = {
    'en': [
      'recommended dose',
      'recommended timing',
      'adjust your dose',
      'take medication at',
      'take your medication at',
      'avoid protein',
      'safe for you',
      'confirmed safe',
      'clinically validated',
      'patient-calibrated',
    ],
    'zh': [
      '建议剂量',
      '推荐剂量',
      '建议服药',
      '应该服药',
      '应该吃',
      '避免蛋白',
      '对你安全',
      '已验证安全',
      '临床验证',
    ],
    'fr': [
      'dose recommandée',
      'moment recommandé',
      'ajuster votre dose',
      'prenez le médicament',
      'évitez les protéines',
      'sûr pour vous',
      'validé cliniquement',
    ],
    'ja': [
      '推奨用量',
      '服用すべき',
      '薬を服用してください',
      'タンパク質を避ける',
      'あなたに安全',
      '臨床的に検証済み',
    ],
  };

  /// Overconfidence patterns (English; conservative to avoid false positives).
  static const List<String> overconfidencePatterns = [
    'guaranteed',
    'best for you',
    'optimal for you',
    'this will work',
    'always safe',
  ];

  /// Safety-policy values / safe negated phrases that must never be flagged.
  static const Set<String> _safeAllowlist = {
    'not_clinically_calibrated',
    'subject_omitted_no_phi',
    'no_patient_no_subject_no_encounter',
    'no_patient_no_administration_no_phi',
    'inspired_not_conformant',
    'local_not_fhir_provenance_not_w3c_prov',
    'local_not_fhir_bundle',
    'not clinically calibrated',
    'not clinically validated',
    'not medical advice',
    'carries no clinical-validation claim',
    'no clinical-validation claim',
  };

  LocalizationSafetyReport lint(
    List<LocalizationSurface> surfaces,
    LocalizationSafetyLintConfig config, {
    /// When false, an informational `no_locale_dictionary_discovered` finding is
    /// recorded (e.g. the Flutter-coupled app dictionary is not loadable from a
    /// pure-Dart CLI). Coverage is never fabricated.
    bool localeDictionaryAvailable = true,
  }) {
    final findings = <LocalizationSafetyFinding>[];

    if (surfaces.isEmpty) {
      findings.add(const LocalizationSafetyFinding(
        severity: 'warn',
        findingType: noLocaleDictionaryDiscovered,
        surfaceId: 'none',
        locale: '-',
        key: '-',
        message: 'No localization surfaces supplied to lint.',
        safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      ));
    } else if (!localeDictionaryAvailable) {
      findings.add(const LocalizationSafetyFinding(
        severity: 'info',
        findingType: noLocaleDictionaryDiscovered,
        surfaceId: 'app_i18n',
        locale: '-',
        key: '-',
        message: 'App localization dictionary not loaded in this context; '
            'linted safe-copy templates only. Full-dictionary coverage is '
            'future work (coverage not fabricated).',
        safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      ));
    }

    // Rule A — required-locale coverage for each required safety key.
    if (config.requiredSafetyKeys.isNotEmpty) {
      for (final key in config.requiredSafetyKeys) {
        final localesForKey =
            surfaces.where((s) => s.key == key).map((s) => s.locale).toSet();
        for (final loc in config.requiredLocales) {
          if (!localesForKey.contains(loc)) {
            findings.add(LocalizationSafetyFinding(
              severity: config.strictMode ? 'blocker' : 'warn',
              findingType: missingLocaleCoverage,
              surfaceId: 'key:$key',
              locale: loc,
              key: key,
              message: 'Required safety key "$key" is missing locale "$loc".',
              suggestedFix: 'Add a non-prescriptive "$key" string for "$loc".',
              safetyBoundary: RuleExplanation.defaultSafetyBoundary,
            ));
          }
        }
      }
    }

    // Per-surface rules B–G.
    for (final s in surfaces) {
      final role = s.expectedSafetyRole;
      final lower = s.text.toLowerCase();

      // Rule G allowlist: policy values are exempt from banned/overconfidence.
      final isPolicyValue =
          role == 'policy_value' || _safeAllowlist.contains(s.text.trim());

      // Rule B — safety boundary for boundary/explanation surfaces.
      if (role == 'boundary' || role == 'explanation') {
        final hasBoundary = lower.contains('educational') ||
            lower.contains('not medical advice') ||
            lower.contains('not clinically calibrated') ||
            lower.contains('not clinical validation') ||
            lower.contains('modeled') ||
            lower.contains('simulated') ||
            lower.contains('source-linked') ||
            // CJK / FR equivalents used in project copy.
            s.text.contains('教育') ||
            s.text.contains('未经临床校准') ||
            s.text.contains('不是医疗建议');
        if (!hasBoundary) {
          findings.add(LocalizationSafetyFinding(
            severity: 'warn',
            findingType: missingSafetyBoundary,
            surfaceId: s.surfaceId,
            locale: s.locale,
            key: s.key,
            message:
                'Boundary/explanation surface lacks a non-prescriptive safety '
                'boundary term.',
            suggestedFix:
                'Add educational / not-medical-advice / not-clinically-'
                'calibrated wording.',
            safetyBoundary: RuleExplanation.defaultSafetyBoundary,
          ));
        }
      }

      // Rule C — evidence/limitation wording for explanation surfaces.
      if (role == 'explanation') {
        final hasEvidence = lower.contains('source') ||
            lower.contains('evidence') ||
            lower.contains('provenance') ||
            lower.contains('limitation') ||
            lower.contains('modeled') ||
            s.text.contains('溯源') ||
            s.text.contains('来源');
        if (!hasEvidence) {
          findings.add(LocalizationSafetyFinding(
            severity: 'warn',
            findingType: missingEvidenceTerms,
            surfaceId: s.surfaceId,
            locale: s.locale,
            key: s.key,
            message: 'Explanation surface lacks source/evidence/limitation '
                'wording.',
            safetyBoundary: RuleExplanation.defaultSafetyBoundary,
          ));
        }
      }

      // Rule D — banned phrase families (skip policy values).
      if (!isPolicyValue) {
        for (final entry in bannedFamilies.entries) {
          for (final pattern in entry.value) {
            if (_isBannedHit(s.text, lower, pattern, entry.key)) {
              findings.add(LocalizationSafetyFinding(
                severity: 'blocker',
                findingType: bannedPhrase,
                surfaceId: s.surfaceId,
                locale: s.locale,
                key: s.key,
                message: 'Unsafe prescriptive phrase (${entry.key}) detected.',
                matchedText: pattern,
                suggestedFix: 'Rewrite as a non-prescriptive educational note.',
                safetyBoundary: RuleExplanation.defaultSafetyBoundary,
              ));
            }
          }
        }

        // Rule F — overconfidence heuristic (English).
        for (final pattern in overconfidencePatterns) {
          if (lower.contains(pattern) && !_negatedNearby(lower, pattern)) {
            findings.add(LocalizationSafetyFinding(
              severity: 'warn',
              findingType: overconfidence,
              surfaceId: s.surfaceId,
              locale: s.locale,
              key: s.key,
              message: 'Overconfident wording detected.',
              matchedText: pattern,
              safetyBoundary: RuleExplanation.defaultSafetyBoundary,
            ));
          }
        }
      }

      // Rule E — placeholder validation.
      if (s.allowedPlaceholders.isNotEmpty ||
          s.requiredPlaceholders.isNotEmpty) {
        final present = _placeholders(s.text);
        for (final p in present) {
          if (!s.allowedPlaceholders.contains(p)) {
            findings.add(LocalizationSafetyFinding(
              severity: 'warn',
              findingType: unknownPlaceholder,
              surfaceId: s.surfaceId,
              locale: s.locale,
              key: s.key,
              message: 'Unknown placeholder "{$p}".',
              matchedText: '{$p}',
              safetyBoundary: RuleExplanation.defaultSafetyBoundary,
            ));
          }
        }
        for (final req in s.requiredPlaceholders) {
          if (!present.contains(req)) {
            findings.add(LocalizationSafetyFinding(
              severity: config.strictMode ? 'blocker' : 'warn',
              findingType: missingRequiredPlaceholder,
              surfaceId: s.surfaceId,
              locale: s.locale,
              key: s.key,
              message: 'Missing required placeholder "{$req}".',
              matchedText: '{$req}',
              safetyBoundary: RuleExplanation.defaultSafetyBoundary,
            ));
          }
        }
      }
    }

    final counts = <String, int>{'info': 0, 'warn': 0, 'blocker': 0};
    for (final f in findings) {
      counts[f.severity] = (counts[f.severity] ?? 0) + 1;
    }

    return LocalizationSafetyReport(
      generatedAt: config.deterministicTimestamp,
      requiredLocales: config.requiredLocales,
      surfaceCount: surfaces.length,
      findingCounts: counts,
      pass: (counts['blocker'] ?? 0) == 0,
      findings: findings,
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      notAdviceText: RuleExplanation.defaultNotAdvice,
      notClinicallyCalibrated: true,
      limitations: _limitations,
    );
  }

  /// Converts a [SafeCopyTemplate] into one surface per localized locale.
  List<LocalizationSurface> surfacesFromTemplate(SafeCopyTemplate t) {
    final role = t.outputType == 'policy' ? 'boundary' : 'explanation';
    return [
      for (final entry in t.localizedText.entries)
        LocalizationSurface(
          surfaceId: 'template:${t.templateId}:${entry.key}',
          locale: entry.key,
          key: t.templateId,
          text: entry.value,
          source: 'safe_copy_template',
          expectedSafetyRole: role,
          allowedPlaceholders: t.allowedPlaceholders,
          requiredPlaceholders: t.requiredPlaceholders,
        ),
    ];
  }

  bool _isBannedHit(String raw, String lower, String pattern, String family) {
    final isLatin = family == 'en' || family == 'fr';
    final hay = isLatin ? lower : raw;
    final needle = isLatin ? pattern.toLowerCase() : pattern;
    if (!hay.contains(needle)) return false;
    // Allow safe negated/allowlist phrases (e.g. "not clinically validated").
    for (final safe in _safeAllowlist) {
      if (hay.contains(safe.toLowerCase()) &&
          safe.toLowerCase().contains(needle)) {
        return false;
      }
    }
    if (isLatin && _negatedNearby(hay, needle)) return false;
    return true;
  }

  bool _negatedNearby(String hay, String needle) {
    final idx = hay.indexOf(needle);
    if (idx < 0) return false;
    final start = (idx - 8).clamp(0, hay.length);
    final prefix = hay.substring(start, idx);
    return prefix.contains('not ') ||
        prefix.contains('never ') ||
        prefix.contains('non ') ||
        prefix.contains('pas ') ||
        prefix.contains('no ');
  }

  Set<String> _placeholders(String text) {
    final out = <String>{};
    for (final m in RegExp(r'\{([a-zA-Z0-9_]+)\}').allMatches(text)) {
      out.add(m.group(1)!);
    }
    return out;
  }
}

/// Deterministic JSON encoder for the lint report.
String encodeLocalizationSafetyReport(LocalizationSafetyReport report) =>
    const JsonEncoder.withIndent('  ').convert(report.toJson());

/// Deterministic markdown for the lint report.
String renderLocalizationSafetyMarkdown(LocalizationSafetyReport report) {
  final b = StringBuffer()
    ..writeln('# ParkinSUM Localization Safety Lint')
    ..writeln()
    ..writeln('Educational/research prototype. **Not a translation-quality '
        'guarantee, not a clinical-safety guarantee, not medical advice, and not '
        'clinically calibrated.** No LLM translation; does not replace human '
        'review.')
    ..writeln()
    ..writeln('- required locales: ${report.requiredLocales.join(', ')}')
    ..writeln('- surfaces: ${report.surfaceCount}')
    ..writeln('- info: ${report.findingCounts['info'] ?? 0} · '
        'warn: ${report.findingCounts['warn'] ?? 0} · '
        'blocker: ${report.findingCounts['blocker'] ?? 0}')
    ..writeln('- pass (0 blocker): ${report.pass}')
    ..writeln()
    ..writeln('| severity | type | surface | locale | key | matched |')
    ..writeln('| --- | --- | --- | --- | --- | --- |');
  for (final f in report.findings) {
    b.writeln('| ${f.severity} | ${f.findingType} | ${f.surfaceId} | '
        '${f.locale} | ${f.key} | ${f.matchedText} |');
  }
  b
    ..writeln()
    ..writeln('## Limitations')
    ..writeln();
  for (final l in report.limitations) {
    b.writeln('- $l');
  }
  b
    ..writeln()
    ..writeln('## Safety boundary')
    ..writeln()
    ..writeln(report.safetyBoundary)
    ..writeln()
    ..writeln(report.notAdviceText);
  return b.toString();
}
