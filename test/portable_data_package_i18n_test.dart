import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n_full_translations.dart';

void main() {
  const localeFamilies = <String>[
    'zh',
    'en',
    'fr',
    'ja',
    'ko',
    'hi',
    'es',
    'vi',
    'th',
    'id',
    'ru',
    'pl',
    'ar',
  ];
  const translatedFamilies = <String>[
    'fr',
    'ja',
    'ko',
    'hi',
    'es',
    'vi',
    'th',
    'id',
    'ru',
    'pl',
    'ar',
  ];
  const interpolationNames = <String>[
    'cases',
    'conflicts',
    'consent',
    'count',
    'decision',
    'decisions',
    'drift',
    'enabled',
    'languages',
    'location',
    'match',
    'modes',
    'partitions',
    'protection',
    'receipt',
    'records',
    'revision',
    'runtime',
    'runtimes',
    'seeds',
    'source',
    'target',
    'total',
    'unsupported',
    'validator',
  ];
  const boundaryKeys = <String>[
    'portable.unencrypted_title',
    'portable.unencrypted_body',
    'portable.boundary',
    'portable.export_body',
    'portable.preview_body',
    'portable.status_ready',
    'portable.migration_receipt_boundary',
    'portable.reminder_target_consent',
    'portable.no_write',
    'portable.rotate_body',
    'portable.save_failed_copied',
    'portable.save_failed_residual_copied',
  ];

  Map<String, String> interpolationSamples() => {
    for (final name in interpolationNames) name: 'sample_${name}_value',
  };

  Set<String> resolvedInterpolationNames(String text) => {
    for (final name in interpolationNames)
      if (text.contains('sample_${name}_value')) name,
  };

  Set<String> placeholdersIn(String text) => {
    for (final match in RegExp(r'\{([A-Za-z0-9_]+)\}').allMatches(text))
      match.group(1)!,
  };

  test('manifest matches every portable page key and all translated rows', () {
    final pageSource = File(
      'lib/features/settings/portable_data_package_page.dart',
    ).readAsStringSync();
    final visibleKeys =
        RegExp(r'portable\.[A-Za-z0-9_]+')
            .allMatches(pageSource)
            .map((match) => match.group(0)!)
            .where((key) => key != 'portable.status_')
            .toSet()
          ..addAll(<String>{
            'portable.status_ready',
            'portable.status_wrongOwner',
            'portable.status_unsupportedSchema',
            'portable.status_corrupt',
          });

    expect(
      kPortableDataPackageTranslationKeys.toSet(),
      containsAll(visibleKeys),
      reason: 'Every visible page key must appear in the translation manifest.',
    );
    expect(
      kPortableDataPackageUiTranslations.keys.toSet(),
      translatedFamilies.toSet(),
    );
    for (final entry in kPortableDataPackageUiTranslations.entries) {
      expect(
        entry.value.keys.toSet(),
        kPortableDataPackageTranslationKeys.toSet(),
        reason: '${entry.key} must translate every portable page key.',
      );
    }
  });

  test(
    'every shipped locale resolves native text and matching placeholders',
    () {
      final params = interpolationSamples();
      final english = AppI18n.fromLocaleTag('en');

      for (final family in localeFamilies) {
        final i18n = AppI18n.fromLocaleTag(family);
        expect(i18n.languageFamily, family);
        for (final key in kPortableDataPackageTranslationKeys) {
          final resolved = i18n.tr(key, params);
          expect(resolved, isNotEmpty, reason: '$family/$key is empty.');
          expect(resolved, isNot(key), reason: '$family leaked $key.');
          expect(
            RegExp(r'\{[A-Za-z0-9_]+\}').hasMatch(resolved),
            isFalse,
            reason: '$family/$key contains an unresolved placeholder.',
          );
          expect(
            resolvedInterpolationNames(resolved),
            resolvedInterpolationNames(english.tr(key, params)),
            reason: '$family/$key changed the English interpolation contract.',
          );
          if (family != 'en' &&
              (key == 'portable.title' || boundaryKeys.contains(key))) {
            expect(
              resolved,
              isNot(english.tr(key, params)),
              reason: '$family/$key still falls back to English.',
            );
          }
        }
      }
    },
  );

  test('translated package rows preserve placeholder names exactly', () {
    final english = AppI18n.fromLocaleTag('en');
    for (final entry in kPortableDataPackageUiTranslations.entries) {
      for (final key in kPortableDataPackageTranslationKeys) {
        expect(
          placeholdersIn(entry.value[key]!),
          resolvedInterpolationNames(english.tr(key, interpolationSamples())),
          reason: '${entry.key}/$key changed placeholder names.',
        );
      }
    }
  });

  test(
    'sensitive export and preview boundaries are present in every locale',
    () {
      final english = AppI18n.fromLocaleTag('en');
      for (final family in localeFamilies) {
        final i18n = AppI18n.fromLocaleTag(family);
        for (final key in boundaryKeys) {
          final translated = i18n.tr(key, interpolationSamples());
          expect(
            translated.trim().length,
            greaterThan(8),
            reason: '$family/$key looks truncated.',
          );
          if (family != 'en') {
            expect(
              translated,
              isNot(english.tr(key, interpolationSamples())),
              reason: '$family/$key is not native copy.',
            );
          }
        }
      }
    },
  );
}
