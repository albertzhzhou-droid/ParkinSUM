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
}
