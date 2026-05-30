// Runs the localization safety lint and writes a report under
// build/localization_safety_lint/.
//
// Usage:
//   dart run tool/run_localization_safety_lint.dart [--strict]
//
// It lints the SafeCopyTemplateRegistry's representative copy across the locales
// each template provides. The app's full i18n dictionary is Flutter-coupled and
// not loadable from this pure-Dart CLI, so the report records an informational
// `no_locale_dictionary_discovered` finding rather than fabricating coverage
// (full-dictionary linting is future work; see docs/LOCALIZATION_SAFETY_LINT.md).
//
// No network; no slow verification commands. Exits non-zero iff a blocker
// finding exists. Safety/governance lint only — not a translation-quality or
// clinical-safety guarantee; no LLM; not clinically calibrated.

import 'dart:io';

import 'package:parkinsum_companion/domain/entities/localization_safety_lint.dart';
import 'package:parkinsum_companion/domain/usecases/localization_safety_lint.dart';
import 'package:parkinsum_companion/domain/usecases/safe_copy_template_registry.dart';

void main(List<String> args) {
  final strict = args.contains('--strict');
  const lint = LocalizationSafetyLint();
  const registry = SafeCopyTemplateRegistry();

  final surfaces = <LocalizationSurface>[
    for (final t in registry.templates) ...lint.surfacesFromTemplate(t),
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
    localeDictionaryAvailable: false,
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
