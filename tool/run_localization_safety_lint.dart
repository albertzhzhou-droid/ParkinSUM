// Runs the localization safety lint and writes a report under
// build/localization_safety_lint/.
//
// Usage:
//   dart run tool/run_localization_safety_lint.dart [--strict]
//
// It lints BOTH the SafeCopyTemplateRegistry's representative copy AND the
// app's full i18n dictionary (`AppI18n.translationDictionary`) across every
// shipped language family. The dictionary used to be unreachable from a
// pure-Dart CLI because `app_i18n.dart` imported Flutter; the Flutter-facing
// members now live in `app_i18n_context.dart`, so the whole dictionary is
// lintable. See docs/LOCALIZATION_SAFETY_LINT.md.
//
// No network; no slow verification commands. Exits non-zero iff a blocker
// finding exists. Safety/governance lint only — not a translation-quality or
// clinical-safety guarantee; no LLM; not clinically calibrated.

import 'dart:io';

import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/domain/entities/localization_safety_lint.dart';
import 'package:parkinsum_companion/domain/usecases/localization_safety_lint.dart';
import 'package:parkinsum_companion/domain/usecases/safe_copy_template_registry.dart';

void main(List<String> args) {
  final strict = args.contains('--strict');
  const lint = LocalizationSafetyLint();
  const registry = SafeCopyTemplateRegistry();

  // Representative boundary copy (carries safety roles + placeholder
  // contracts), plus every string the app can actually display.
  final surfaces = <LocalizationSurface>[
    for (final t in registry.templates) ...lint.surfacesFromTemplate(t),
    ..._appDictionarySurfaces(),
  ];

  const config = LocalizationSafetyLintConfig(
    requiredLocales: ['en', 'zh', 'fr', 'ja'],
    sourceLocale: 'en',
  );
  final report = lint.lint(
    surfaces,
    strict
        ? const LocalizationSafetyLintConfig(
            requiredLocales: ['en', 'zh', 'fr', 'ja'],
            sourceLocale: 'en',
            strictMode: true,
          )
        : config,
    localeDictionaryAvailable: true,
  );

  final outDir = Directory('build/localization_safety_lint');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  File('${outDir.path}/latest.json')
      .writeAsStringSync(encodeLocalizationSafetyReport(report));
  File('${outDir.path}/latest.md')
      .writeAsStringSync(renderLocalizationSafetyMarkdown(report));

  stdout
    ..writeln('Localization safety lint: ${report.surfaceCount} surfaces, '
        'info=${report.findingCounts['info'] ?? 0} '
        'warn=${report.findingCounts['warn'] ?? 0} '
        'blocker=${report.blockerCount} '
        '(pass=${report.pass}).')
    ..writeln('Report: ${outDir.path}/latest.json')
    ..writeln('Report: ${outDir.path}/latest.md');
  exit(report.pass ? 0 : 1);
}

/// Every shipped translation as a lintable surface.
///
/// Keys are emitted in sorted order per family so the report stays
/// deterministic run-to-run. Role is `plain`: the dictionary carries no
/// per-key safety contract, so these are scanned for banned/prescriptive
/// phrasing rather than required-term presence.
List<LocalizationSurface> _appDictionarySurfaces() {
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
