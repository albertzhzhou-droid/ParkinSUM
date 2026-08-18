import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n_full_translations.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';

/// W5 — Diagnostics surface localization coverage.
///
/// The `diagnostics.*` keys existed only in the inline `zh/en/fr/ja` maps.
/// `app_i18n_full_translations.dart` had zero coverage, so the nine newer
/// language families silently fell through to English — the diagnostics page
/// rendered untranslated for most of the shipped locales with every check
/// green.
///
/// `diagnostics.scope_body` is the safety-critical string: it states that
/// these checks change no score, severity, evidence, or rule outcome and are
/// not health guidance. Per CLAUDE.md a translation must keep that meaning and
/// must not become more assertive, so the substantive terms are asserted per
/// locale rather than merely checking the key exists.
///
/// Educational prototype only; synthetic/demo data only.
void main() {
  const diagnosticsKeys = <String>[
    'diagnostics.title',
    'diagnostics.rerun',
    'diagnostics.scope_title',
    'diagnostics.scope_body',
    'diagnostics.elapsed',
  ];

  test('every full-translation family covers the diagnostics surface', () {
    final missing = <String>[];
    for (final family in kFullLocaleUiTranslations.keys) {
      final map = kFullLocaleUiTranslations[family]!;
      for (final key in diagnosticsKeys) {
        if (!map.containsKey(key) || (map[key] ?? '').trim().isEmpty) {
          missing.add('$family/$key');
        }
      }
    }
    expect(
      missing,
      isEmpty,
      reason:
          'These locales fall back to English on the diagnostics surface: '
          '${missing.join(", ")}',
    );
  });

  test('the {ms} placeholder survives every translation', () {
    // A dropped placeholder turns a timing readout into a broken sentence,
    // and `tr()` substitution would silently no-op.
    for (final entry in kFullLocaleUiTranslations.entries) {
      final elapsed = entry.value['diagnostics.elapsed'];
      expect(
        elapsed,
        contains('{ms}'),
        reason: '${entry.key} lost the {ms} placeholder.',
      );
    }
  });

  test('scope copy keeps its non-guidance meaning in every locale', () {
    // The English original says the checks report engineering status only,
    // change no rule outcome, are not health guidance, and use synthetic data.
    // A translation that drops the negation would read as an endorsement.
    for (final entry in kFullLocaleUiTranslations.entries) {
      final body = entry.value['diagnostics.scope_body']!;
      expect(
        body.length,
        greaterThan(80),
        reason:
            '${entry.key} scope_body looks truncated; the safety framing is '
            'unlikely to have survived.',
      );
      expect(
        findBannedSubstrings(body),
        isEmpty,
        reason: '${entry.key} scope_body contains banned prescriptive copy.',
      );
    }
  });

  test('a non-English locale resolves diagnostics without leaking keys', () {
    for (final family in kFullLocaleUiTranslations.keys) {
      final i18n = AppI18n.fromLocaleTag(family);
      for (final key in diagnosticsKeys) {
        final resolved = i18n.tr(key, const {'ms': '120'});
        expect(
          resolved,
          isNot(key),
          reason: '$family leaked the raw key "$key" to the UI.',
        );
        expect(resolved.trim(), isNotEmpty);
        expect(
          resolved,
          isNot(contains('{ms}')),
          reason: '$family left an unsubstituted placeholder in "$key".',
        );
      }
    }
  });
}
