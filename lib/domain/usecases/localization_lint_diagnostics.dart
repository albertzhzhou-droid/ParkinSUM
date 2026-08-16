/// Shared surface construction for the localization safety lint.
///
/// The lint needs two kinds of surface: the representative boundary copy from
/// the SafeCopyTemplateRegistry (which carries safety roles and placeholder
/// contracts), and every string the app can actually display. Building them in
/// one place keeps the CLI gate and any in-app diagnostics view reporting the
/// same numbers.
///
/// Educational prototype only. Pure/deterministic; no I/O; adds no medical
/// advice and is not wired into scoring.
library;

import '../../core/i18n/app_i18n.dart';
import '../entities/localization_safety_lint.dart';
import 'localization_safety_lint.dart';
import 'safe_copy_template_registry.dart';

/// Locales the lint requires coverage for.
const List<String> kLocalizationLintRequiredLocales = ['en', 'zh', 'fr', 'ja'];

/// Default (non-strict) lint configuration.
const LocalizationSafetyLintConfig kLocalizationLintConfig =
    LocalizationSafetyLintConfig(
  requiredLocales: kLocalizationLintRequiredLocales,
  sourceLocale: 'en',
);

/// Every shipped translation as a lintable surface.
///
/// Keys are emitted in sorted order per family so reports stay deterministic.
/// Role is `plain`: the dictionary carries no per-key safety contract, so these
/// are scanned for banned/prescriptive phrasing rather than required terms.
List<LocalizationSurface> appDictionarySurfaces() {
  final out = <LocalizationSurface>[];
  final dictionary = AppI18n.translationDictionary;
  for (final family in AppI18n.translationFamilies) {
    final entries = dictionary[family]!;
    final keys = entries.keys.toList(growable: false)..sort();
    for (final key in keys) {
      final text = entries[key] ?? '';
      if (text.trim().isEmpty) continue;
      out.add(LocalizationSurface(
        surfaceId: 'app_i18n.$family.$key',
        locale: family,
        key: key,
        text: text,
        source: 'app_i18n',
      ));
    }
  }
  return out;
}

/// Registry boundary copy plus the full app dictionary.
List<LocalizationSurface> allLocalizationSurfaces({
  SafeCopyTemplateRegistry registry = const SafeCopyTemplateRegistry(),
  LocalizationSafetyLint lint = const LocalizationSafetyLint(),
}) =>
    <LocalizationSurface>[
      for (final t in registry.templates) ...lint.surfacesFromTemplate(t),
      ...appDictionarySurfaces(),
    ];

/// Runs the lint over [allLocalizationSurfaces].
LocalizationSafetyReport lintAllLocalizationSurfaces({
  LocalizationSafetyLint lint = const LocalizationSafetyLint(),
  LocalizationSafetyLintConfig config = kLocalizationLintConfig,
}) =>
    lint.lint(
      allLocalizationSurfaces(lint: lint),
      config,
      localeDictionaryAvailable: true,
    );
