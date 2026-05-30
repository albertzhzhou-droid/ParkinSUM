import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/localization_safety_lint.dart';
import 'package:parkinsum_companion/domain/usecases/localization_safety_lint.dart';
import 'package:parkinsum_companion/domain/usecases/safe_copy_template_registry.dart';

import 'helpers/no_phi_json_assertions.dart';

/// P7 — LocalizationSafetyLint. Deterministic, pure copy-safety + localization
/// coverage lint. Not a translation-quality or clinical-safety guarantee.
void main() {
  const lint = LocalizationSafetyLint();

  LocalizationSurface s(
    String id,
    String locale,
    String key,
    String text, {
    String role = 'plain',
    List<String> allowed = const [],
    List<String> required = const [],
  }) =>
      LocalizationSurface(
        surfaceId: id,
        locale: locale,
        key: key,
        text: text,
        source: 'test',
        expectedSafetyRole: role,
        allowedPlaceholders: allowed,
        requiredPlaceholders: required,
      );

  LocalizationSafetyReport lintOne(LocalizationSurface surface,
          {LocalizationSafetyLintConfig? config}) =>
      lint.lint([surface], config ?? const LocalizationSafetyLintConfig());

  bool hasType(LocalizationSafetyReport r, String type) =>
      r.findings.any((f) => f.findingType == type);

  test('4. surface with a banned advice phrase fails (blocker)', () {
    final r =
        lintOne(s('x', 'en', 'k', 'We suggest the recommended dose now.'));
    expect(hasType(r, LocalizationSafetyLint.bannedPhrase), isTrue);
    expect(r.blockerCount, greaterThan(0));
    expect(r.pass, isFalse);
  });

  test('5. missing required locale is reported', () {
    final r = lint.lint(
      [
        s('x', 'en', 'safety.k', 'Educational; not medical advice.',
            role: 'boundary')
      ],
      const LocalizationSafetyLintConfig(requiredSafetyKeys: ['safety.k']),
    );
    expect(hasType(r, LocalizationSafetyLint.missingLocaleCoverage), isTrue);
    // en present, zh/fr/ja missing → 3 coverage findings.
    expect(
        r.findings
            .where((f) =>
                f.findingType == LocalizationSafetyLint.missingLocaleCoverage)
            .length,
        3);
  });

  test('6. missing safety boundary is reported for boundary surfaces', () {
    final r = lintOne(s('x', 'en', 'k', 'Pick this option.', role: 'boundary'));
    expect(hasType(r, LocalizationSafetyLint.missingSafetyBoundary), isTrue);
  });

  test('7. missing source/limitation wording reported for explanation', () {
    final r = lintOne(
        s('x', 'en', 'k', 'This is an educational note.', role: 'explanation'));
    expect(hasType(r, LocalizationSafetyLint.missingEvidenceTerms), isTrue);
  });

  test('8. English banned phrases detected', () {
    for (final p in [
      'adjust your dose',
      'safe for you',
      'clinically validated'
    ]) {
      final r = lintOne(s('x', 'en', 'k', 'note: $p here'));
      expect(hasType(r, LocalizationSafetyLint.bannedPhrase), isTrue,
          reason: 'should flag "$p"');
    }
  });

  test('9. Chinese banned phrases detected', () {
    for (final p in ['建议剂量', '对你安全', '临床验证']) {
      final r = lintOne(s('x', 'zh', 'k', '提示：$p。'));
      expect(hasType(r, LocalizationSafetyLint.bannedPhrase), isTrue,
          reason: 'should flag "$p"');
    }
  });

  test('10. French banned phrases detected', () {
    for (final p in [
      'dose recommandée',
      'sûr pour vous',
      'validé cliniquement'
    ]) {
      final r = lintOne(s('x', 'fr', 'k', 'note : $p ici'));
      expect(hasType(r, LocalizationSafetyLint.bannedPhrase), isTrue,
          reason: 'should flag "$p"');
    }
  });

  test('11. Japanese banned phrases detected', () {
    for (final p in ['推奨用量', 'あなたに安全', '臨床的に検証済み']) {
      final r = lintOne(s('x', 'ja', 'k', 'メモ：$p。'));
      expect(hasType(r, LocalizationSafetyLint.bannedPhrase), isTrue,
          reason: 'should flag "$p"');
    }
  });

  test('12. safety-policy allowlist values are not flagged', () {
    // Policy value naming omission must not trip the banned scan.
    final r1 = lintOne(s(
        'x', 'en', 'phi_policy', 'no_patient_no_subject_no_encounter',
        role: 'policy_value'));
    expect(hasType(r1, LocalizationSafetyLint.bannedPhrase), isFalse);
    // "not clinically calibrated" must not be flagged as "clinically validated"
    // or overconfidence.
    final r2 = lintOne(s('x', 'en', 'k',
        'Educational; not clinically calibrated and not clinically validated.',
        role: 'boundary'));
    expect(hasType(r2, LocalizationSafetyLint.bannedPhrase), isFalse);
    expect(r2.blockerCount, 0);
  });

  test('13. unknown placeholder is reported', () {
    final r = lintOne(s('x', 'en', 'k', 'value {overlap_percent} and {rogue}',
        role: 'plain', allowed: ['overlap_percent']));
    expect(hasType(r, LocalizationSafetyLint.unknownPlaceholder), isTrue);
  });

  test('14. missing required placeholder is reported', () {
    final r = lintOne(s('x', 'en', 'k', 'no placeholders here',
        role: 'plain',
        allowed: ['overlap_percent'],
        required: ['overlap_percent']));
    expect(
        hasType(r, LocalizationSafetyLint.missingRequiredPlaceholder), isTrue);
  });

  test('15. report JSON is deterministic', () {
    final surfaces = [
      s('a', 'en', 'k',
          'Educational; modeled, source-linked; not medical advice.',
          role: 'explanation'),
      s('b', 'zh', 'k', '提示：建议剂量。'),
    ];
    final a = encodeLocalizationSafetyReport(
        lint.lint(surfaces, const LocalizationSafetyLintConfig()));
    final b = encodeLocalizationSafetyReport(
        lint.lint(surfaces, const LocalizationSafetyLintConfig()));
    expect(a, b);
  });

  test('16. markdown report includes counts', () {
    final md = renderLocalizationSafetyMarkdown(
        lintOne(s('x', 'en', 'k', 'adjust your dose')));
    expect(md, contains('surfaces:'));
    expect(md, contains('blocker:'));
    expect(md, contains('pass'));
  });

  test('17. no PHI / patient / subject / encounter KEYS in report JSON', () {
    final r = lint.lint(
      [
        s('x', 'en', 'k', 'adjust your dose'),
        s('y', 'en', 'phi_policy', 'no_patient_no_subject_no_encounter',
            role: 'policy_value')
      ],
      const LocalizationSafetyLintConfig(),
    );
    scanNoPhiKeys(jsonDecode(encodeLocalizationSafetyReport(r)));
  });

  test('18. existing safe registry passes with 0 blockers', () {
    const registry = SafeCopyTemplateRegistry();
    final surfaces = [
      for (final t in registry.templates) ...lint.surfacesFromTemplate(t),
    ];
    final r = lint.lint(surfaces, const LocalizationSafetyLintConfig(),
        localeDictionaryAvailable: false);
    expect(r.blockerCount, 0);
    expect(r.pass, isTrue);
    // The CLI fallback info finding is present, not fabricated coverage.
    expect(hasType(r, LocalizationSafetyLint.noLocaleDictionaryDiscovered),
        isTrue);
  });
}
