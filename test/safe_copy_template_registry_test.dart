import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/localization_safety_lint.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/usecases/localization_safety_lint.dart';
import 'package:parkinsum_companion/domain/usecases/safe_copy_template_registry.dart';

/// P6 (skeleton) — SafeCopyTemplateRegistry. Representative, non-prescriptive
/// boundary copy; a foundation for the localization lint (not wired into UI).
void main() {
  const registry = SafeCopyTemplateRegistry();

  test('1. registry contains the initial required templates', () {
    final ids = registry.templates.map((t) => t.templateId).toSet();
    expect(
        ids,
        containsAll([
          'mechanistic_explanation_boundary',
          'source_quality_boundary',
          'missing_context_boundary',
          'evidence_trace_boundary',
          'not_advice_default',
          'not_clinically_calibrated_default',
        ]));
  });

  test('2. every template has default English text', () {
    for (final t in registry.templates) {
      expect(t.defaultLocale, 'en');
      expect(t.localizedText.containsKey('en'), isTrue);
      expect(t.defaultText.trim(), isNotEmpty);
    }
  });

  test('3. required safety templates contain safety boundary terms', () {
    for (final t in registry.templates) {
      for (final term in t.requiredSafetyTerms) {
        expect(t.defaultText.toLowerCase(), contains(term.toLowerCase()),
            reason: '${t.templateId} must contain safety term "$term"');
      }
    }
  });

  test('4. no template contains a banned advice phrase (self-lint clean)', () {
    const lint = LocalizationSafetyLint();
    final surfaces = [
      for (final t in registry.templates) ...lint.surfacesFromTemplate(t),
    ];
    final report = lint.lint(
      surfaces,
      const LocalizationSafetyLintConfig(),
      localeDictionaryAvailable: false,
    );
    expect(report.blockerCount, 0,
        reason: 'registry templates must lint with 0 blockers');
    // Templates carry no banned medical-advice phrases in their default text.
    for (final t in registry.templates) {
      expect(findBannedSubstrings(t.defaultText), isEmpty,
          reason: '${t.templateId} default text leaked a banned phrase');
    }
    expect(findBannedSubstrings(jsonEncode(report.toJson())), isEmpty);
  });

  test('templates serialize deterministically', () {
    final a = jsonEncode(registry.templates.map((t) => t.toJson()).toList());
    final b = jsonEncode(registry.templates.map((t) => t.toJson()).toList());
    expect(a, b);
  });
}
