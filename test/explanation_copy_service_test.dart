import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/usecases/explanation_copy_service.dart';
import 'package:parkinsum_companion/domain/usecases/localization_safety_lint.dart';

/// P6 — ExplanationCopyService. Runtime accessor that resolves boundary copy
/// through the compiler-validated registry, with a guaranteed fallback.
void main() {
  const service = ExplanationCopyService();

  // 1 — not-advice copy resolves and equals the canonical default text.
  test('notAdvice resolves to the canonical not-advice text', () {
    expect(service.notAdvice(), RuleExplanation.defaultNotAdvice);
    expect(service.notAdvice().trim(), isNotEmpty);
  });

  // 2 — safety-boundary copy resolves and equals the canonical default text.
  test('safetyBoundary resolves to the canonical safety-boundary text', () {
    expect(service.safetyBoundary(), RuleExplanation.defaultSafetyBoundary);
    expect(service.safetyBoundary().trim(), isNotEmpty);
  });

  // 3 — an unknown template id falls back to the supplied fallback.
  test('unknown template falls back', () {
    expect(
      service.resolve('no_such_template', fallback: 'FALLBACK'),
      'FALLBACK',
    );
  });

  // 4 — a known template resolves to its compiled registry text.
  test('known template resolves to compiled text', () {
    final text = service.resolve(
      'not_clinically_calibrated_default',
      fallback: 'FALLBACK',
    );
    expect(text, isNot('FALLBACK'));
    expect(text.toLowerCase(), contains('not clinically calibrated'));
  });

  // 5 — resolved boundary copy contains no banned prescriptive phrase.
  test('resolved boundary copy is banned-phrase free', () {
    final blob =
        '${service.notAdvice()} ${service.safetyBoundary()}'.toLowerCase();
    for (final phrases in LocalizationSafetyLint.bannedFamilies.values) {
      for (final phrase in phrases) {
        if (phrase.runes.any((r) => r >= 0x3400)) {
          continue; // CJK not present in the English boundary text
        }
        // Allow safe negations (e.g. "not clinically validated").
        if (blob.contains(phrase) && !blob.contains('not $phrase')) {
          fail('Banned phrase "$phrase" present in resolved boundary copy.');
        }
      }
    }
  });

  // 6 — service output is deterministic.
  test('service output is deterministic', () {
    expect(service.notAdvice(), service.notAdvice());
    expect(service.safetyBoundary(), service.safetyBoundary());
  });

  // 7 — locale-strict resolve returns compiled text for a locale the template
  // carries (en), and equals the migrated i18n boundary string.
  test('resolveForLocale returns compiled text for en', () {
    final text = service.resolveForLocale(
      'legacy_no_conflict',
      locale: 'en',
      fallback: 'FALLBACK',
    );
    expect(text, isNot('FALLBACK'));
    expect(text.toLowerCase(), contains('not medical advice'));
  });

  // 8 — locale-strict resolve does NOT substitute English for a locale the
  // template lacks; it returns the (localized) fallback instead.
  test('resolveForLocale keeps the localized fallback for missing locale', () {
    const localized = '未检测到显著的规则冲突（仅基于内置规则；并非医疗建议）。';
    final text = service.resolveForLocale(
      'legacy_no_conflict',
      locale: 'zh',
      fallback: localized,
    );
    expect(text, localized);
  });

  // 9 — unknown template id in resolveForLocale falls back too.
  test('resolveForLocale falls back for unknown template', () {
    expect(
      service.resolveForLocale('nope', locale: 'en', fallback: 'FB'),
      'FB',
    );
  });
}
