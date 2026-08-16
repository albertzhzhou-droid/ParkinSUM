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

import 'package:parkinsum_companion/domain/entities/localization_safety_lint.dart';
import 'package:parkinsum_companion/domain/usecases/localization_lint_diagnostics.dart';
import 'package:parkinsum_companion/domain/usecases/localization_safety_lint.dart';

void main(List<String> args) {
  final strict = args.contains('--strict');
  // Surfaces + config live in the domain layer so this CLI and any in-app
  // diagnostics view lint exactly the same set.
  final report = strict
      ? const LocalizationSafetyLint().lint(
          allLocalizationSurfaces(),
          const LocalizationSafetyLintConfig(
            requiredLocales: kLocalizationLintRequiredLocales,
            sourceLocale: 'en',
            strictMode: true,
          ),
          localeDictionaryAvailable: true,
        )
      : lintAllLocalizationSurfaces();

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
