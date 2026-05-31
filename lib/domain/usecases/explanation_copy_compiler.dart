/// P6 — ExplanationCopyCompiler.
///
/// Educational/research prototype only. Pure, deterministic compiler that renders
/// and validates non-prescriptive user-facing copy from `SafeCopyTemplate`s. It
/// binds placeholders, enforces required safety/evidence terms, rejects banned
/// prescriptive phrases (reusing the LocalizationSafetyLint banned-phrase
/// families), and checks source/limitation/not-advice requirements.
///
/// It adds no medical advice, no dose/timing/diet guidance, and no
/// clinical-calibration claim, and it is NOT wired into the UI or scoring. No
/// PHI / patient / subject / encounter semantics.
library;

import 'dart:convert';

import '../entities/explanation_copy.dart';
import '../entities/rule_explanation.dart';
import '../entities/safe_copy_template.dart';
import 'localization_safety_lint.dart';
import 'safe_copy_template_registry.dart';

class ExplanationCopyCompiler {
  const ExplanationCopyCompiler();

  static const String _safetyBoundary =
      'Deterministic copy compilation + validation only. It adds no medical '
      'advice, no dose/timing/diet guidance, and no clinical-calibration claim, '
      'and is not wired into the UI or scoring.';

  static const List<String> _limitations = [
    'Compiles + validates copy templates; it does not migrate UI strings or change scoring.',
    'Banned-phrase matching reuses the conservative LocalizationSafetyLint families; not a clinical-safety guarantee.',
    'Required safety/evidence terms are enforced on the default-locale render; other locales are covered by localization:lint.',
    'Synthetic/demo data only; not clinically calibrated; carries no clinical-validation claim.',
  ];

  /// Safe negations / policy values that must never count as a banned phrase.
  static const List<String> _safeNegations = [
    'not clinically calibrated',
    'not clinically validated',
    'not medical advice',
    'carries no clinical-validation claim',
    'no clinical-validation claim',
  ];

  static final RegExp _placeholder = RegExp(r'\{([a-zA-Z0-9_]+)\}');

  /// Compile a single template at [locale] with the given [bindings] + [context].
  CopyCompileResult compile(
    SafeCopyTemplate template, {
    Map<String, String> bindings = const {},
    String locale = '',
    CopyCompileContext context = const CopyCompileContext(),
  }) {
    final findings = <CopyCompileFinding>[];
    final requested = locale.isEmpty ? template.defaultLocale : locale;
    final usedFallback = !template.localizedText.containsKey(requested);
    final effectiveLocale = usedFallback ? template.defaultLocale : requested;
    final raw = template.localizedText[effectiveLocale] ?? '';

    CopyCompileFinding f(String sev, String type, String msg,
            {String detail = ''}) =>
        CopyCompileFinding(
          severity: sev,
          findingType: type,
          templateId: template.templateId,
          locale: effectiveLocale,
          message: msg,
          detail: detail,
        );

    if (usedFallback && locale.isNotEmpty) {
      findings.add(f(
          CopyCompileSeverity.info,
          CopyCompileFindingType.localeFallback,
          'Locale "$locale" not available; rendered the default locale '
          '"${template.defaultLocale}".'));
    }

    // Placeholder validation.
    for (final req in template.requiredPlaceholders) {
      if (!bindings.containsKey(req)) {
        findings.add(f(
            CopyCompileSeverity.blocker,
            CopyCompileFindingType.missingRequiredPlaceholder,
            'Required placeholder "{$req}" has no binding.'));
      }
    }
    for (final key in bindings.keys) {
      if (!template.allowedPlaceholders.contains(key) &&
          !template.requiredPlaceholders.contains(key)) {
        findings.add(f(
            CopyCompileSeverity.warn,
            CopyCompileFindingType.unknownPlaceholder,
            'Binding "$key" is not an allowed placeholder for this template.'));
      }
    }

    // Render.
    var text = raw;
    bindings.forEach((k, v) {
      text = text.replaceAll('{$k}', v);
    });
    final leftover =
        _placeholder.allMatches(text).map((m) => m.group(0)!).toSet();
    if (leftover.isNotEmpty) {
      findings.add(f(
          CopyCompileSeverity.blocker,
          CopyCompileFindingType.unresolvedPlaceholder,
          'Unresolved placeholder(s) remain after rendering: '
          '${leftover.join(', ')}.'));
    }

    final lower = text.toLowerCase();

    // Required safety/evidence terms — enforced on the default-locale render
    // (other locales are validated by localization:lint).
    if (effectiveLocale == template.defaultLocale) {
      for (final term in template.requiredSafetyTerms) {
        if (!lower.contains(term.toLowerCase())) {
          findings.add(f(
              CopyCompileSeverity.blocker,
              CopyCompileFindingType.missingSafetyTerm,
              'Required safety term "$term" is missing from the rendered text.'));
        }
      }
      for (final term in template.requiredEvidenceTerms) {
        if (!lower.contains(term.toLowerCase())) {
          findings.add(f(
              CopyCompileSeverity.warn,
              CopyCompileFindingType.missingEvidenceTerm,
              'Evidence term "$term" is missing from the rendered text.'));
        }
      }
    }

    // Banned prescriptive phrases (reuse the lint families). Skip safe negations.
    for (final family in template.bannedPhraseFamilies) {
      final phrases = LocalizationSafetyLint.bannedFamilies[family] ?? const [];
      for (final phrase in phrases) {
        if (_containsBanned(text, lower, phrase)) {
          findings.add(f(
              CopyCompileSeverity.blocker,
              CopyCompileFindingType.bannedPhrase,
              'Banned prescriptive phrase ($family) detected.',
              detail: phrase));
        }
      }
    }

    // Structural requirements.
    if (template.requiresSourceRefs && context.sourceRefs.isEmpty) {
      findings.add(f(
          CopyCompileSeverity.blocker,
          CopyCompileFindingType.requiresSourceRefsUnsatisfied,
          'Template requires sourceRefs but none were supplied.'));
    }
    if (template.requiresLimitationText && !context.hasLimitationText) {
      findings.add(f(
          CopyCompileSeverity.blocker,
          CopyCompileFindingType.requiresLimitationUnsatisfied,
          'Template requires limitation text but none was supplied.'));
    }
    if (template.requiresNotAdviceText &&
        !context.hasNotAdviceText &&
        !lower.contains('not medical advice')) {
      findings.add(f(
          CopyCompileSeverity.blocker,
          CopyCompileFindingType.requiresNotAdviceUnsatisfied,
          'Template requires not-advice text but it is absent.'));
    }

    final hasBlocker =
        findings.any((x) => x.severity == CopyCompileSeverity.blocker);
    final compiled = hasBlocker
        ? null
        : CompiledCopy(
            templateId: template.templateId,
            outputType: template.outputType,
            locale: effectiveLocale,
            usedDefaultLocaleFallback: usedFallback && locale.isNotEmpty,
            text: text,
            boundPlaceholders: Map<String, String>.from(bindings),
          );

    return CopyCompileResult(compiled: compiled, findings: findings);
  }

  /// Compile every template in [registry] at its default locale using
  /// [bindingsByTemplate] (sample bindings) + [contextByTemplate].
  CopyCompileReport compileAll(
    SafeCopyTemplateRegistry registry, {
    Map<String, Map<String, String>> bindingsByTemplate = const {},
    Map<String, CopyCompileContext> contextByTemplate = const {},
    String generatedAt = 'synthetic-demo',
  }) {
    final compiled = <CompiledCopy>[];
    final findings = <CopyCompileFinding>[];
    for (final t in registry.templates) {
      final r = compile(
        t,
        bindings: bindingsByTemplate[t.templateId] ?? const {},
        context: contextByTemplate[t.templateId] ?? const CopyCompileContext(),
      );
      if (r.compiled != null) compiled.add(r.compiled!);
      findings.addAll(r.findings);
    }
    final counts = <String, int>{
      CopyCompileSeverity.info: 0,
      CopyCompileSeverity.warn: 0,
      CopyCompileSeverity.blocker: 0,
    };
    for (final x in findings) {
      counts[x.severity] = (counts[x.severity] ?? 0) + 1;
    }
    return CopyCompileReport(
      generatedAt: generatedAt,
      templateCount: registry.templates.length,
      compiledCount: compiled.length,
      counts: counts,
      pass: (counts[CopyCompileSeverity.blocker] ?? 0) == 0,
      compiled: compiled,
      findings: findings,
      safetyBoundary: _safetyBoundary,
      notClinicallyCalibrated: true,
      limitations: _limitations,
    );
  }

  bool _containsBanned(String text, String lower, String phrase) {
    final isCjk = phrase.runes.any((r) => r >= 0x3400);
    final hay = isCjk ? text : lower;
    final needle = isCjk ? phrase : phrase.toLowerCase();
    var idx = hay.indexOf(needle);
    while (idx >= 0) {
      // Skip when the match is part of a safe negation window.
      final start = (idx - 8).clamp(0, hay.length);
      final window = hay.substring(start, idx + needle.length);
      final safe = _safeNegations.any(
          (n) => (isCjk ? text : lower).contains(n) && window.contains('not'));
      if (!safe) return true;
      idx = hay.indexOf(needle, idx + needle.length);
    }
    return false;
  }
}

/// Deterministic JSON encoder.
String encodeCopyCompileReport(CopyCompileReport r) =>
    const JsonEncoder.withIndent('  ').convert(r.toJson());

/// Deterministic markdown renderer.
String renderCopyCompileMarkdown(CopyCompileReport r) {
  final b = StringBuffer()
    ..writeln('# ParkinSUM Explanation Copy Compiler')
    ..writeln()
    ..writeln(
        'Educational/research prototype. **Deterministic copy compilation '
        '+ validation only — no medical advice, no clinical-calibration claim, '
        'and not wired into the UI or scoring.**')
    ..writeln()
    ..writeln('- templates: ${r.templateCount}')
    ..writeln('- compiled: ${r.compiledCount}')
    ..writeln('- info: ${r.counts['info'] ?? 0} · '
        'warn: ${r.counts['warn'] ?? 0} · '
        'blocker: ${r.blockerCount}')
    ..writeln('- pass (0 blocker): ${r.pass}')
    ..writeln()
    ..writeln('## Compiled copy')
    ..writeln()
    ..writeln('| template | output | locale | text |')
    ..writeln('| --- | --- | --- | --- |');
  for (final c in r.compiled) {
    final oneLine = c.text.replaceAll('\n', ' ');
    b.writeln('| ${c.templateId} | ${c.outputType} | ${c.locale} | $oneLine |');
  }
  if (r.findings.isNotEmpty) {
    b
      ..writeln()
      ..writeln('## Findings')
      ..writeln()
      ..writeln('| severity | type | template | message |')
      ..writeln('| --- | --- | --- | --- |');
    for (final f in r.findings) {
      b.writeln('| ${f.severity} | ${f.findingType} | ${f.templateId} | '
          '${f.message} |');
    }
  }
  b
    ..writeln()
    ..writeln('## Limitations')
    ..writeln();
  for (final l in r.limitations) {
    b.writeln('- $l');
  }
  b
    ..writeln()
    ..writeln('## Safety boundary')
    ..writeln()
    ..writeln(r.safetyBoundary)
    ..writeln()
    ..writeln(RuleExplanation.defaultNotAdvice);
  return b.toString();
}
