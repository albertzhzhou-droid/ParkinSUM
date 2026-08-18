import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/usecases/explanation_copy_diagnostics.dart';
import 'package:parkinsum_companion/domain/usecases/localization_lint_diagnostics.dart';
import 'package:parkinsum_companion/features/diagnostics/engineering_diagnostics_page.dart';

import 'helpers/page_test_harness.dart';

/// Engineering diagnostics surface.
///
/// The peripheral governance layer was CLI-only, so nothing it verifies was
/// visible in the app. These tests pin that the in-app view reports the same
/// numbers as the CI gates (shared domain helpers, so the two cannot drift),
/// that it renders, and that it stays framed as engineering status rather than
/// health guidance.
///
/// Educational prototype only; synthetic/demo data only.
void main() {
  group('shared diagnostics computation', () {
    test('registry compiles clean with the shared sample inputs', () {
      // Same call the copy:compile gate makes; 0 blockers is the gate's bar.
      final report = compileRegistryWithSamples();
      expect(report.blockerCount, 0);
      expect(report.compiledCount, report.templateCount);
      expect(report.templateCount, greaterThan(0));
    });

    test(
      'localization lint covers the full dictionary, not just templates',
      () {
        final report = lintAllLocalizationSurfaces();
        expect(report.blockerCount, 0);
        // Registry-only linting was ~26 surfaces; the dictionary is thousands.
        expect(
          report.surfaceCount,
          greaterThan(1000),
          reason: 'lint should cover the app dictionary, not only templates',
        );
      },
    );

    test('every shipped language family contributes surfaces', () {
      final surfaces = appDictionarySurfaces();
      final locales = surfaces.map((s) => s.locale).toSet();
      expect(locales.length, AppI18n.translationFamilies.length);
      expect(surfaces.every((s) => s.source == 'app_i18n'), isTrue);
    });

    test('surface order is deterministic across runs', () {
      String ids() => appDictionarySurfaces().map((s) => s.surfaceId).join(',');
      expect(ids(), ids());
    });
  });

  group('diagnostics page', () {
    testWidgets('renders its checks and the boundary framing', (tester) async {
      // Tall viewport: ListView does not build off-screen children into the
      // element tree, so every card must fit for these finders to see them.
      await pumpFeaturePage(
        tester,
        const EngineeringDiagnosticsPage(),
        surfaceSize: const Size(1170, 5200),
      );
      // The checks run in a post-frame callback.
      await tester.pump();
      expectNoWidgetErrors(reason: 'diagnostics page failed to build');

      expect(find.text('Engineering diagnostics'), findsOneWidget);
      // Boundary framing must be present, not buried.
      expect(find.text(RuleExplanation.defaultNotAdvice), findsOneWidget);
      // Each governance check is surfaced.
      for (final title in const [
        'Explanation copy compiler',
        'Localization safety lint',
        'Mechanistic replay',
        'Safe-copy template registry',
      ]) {
        expect(find.text(title), findsOneWidget, reason: '$title missing');
      }
    });

    testWidgets('reports pass when the gates are clean', (tester) async {
      await pumpFeaturePage(
        tester,
        const EngineeringDiagnosticsPage(),
        surfaceSize: const Size(1170, 5200),
      );
      await tester.pump();
      // A clean tree should show no blocker/error labels anywhere.
      expect(find.textContaining('blocker'), findsNothing);
      expect(find.text('error'), findsNothing);
      expect(find.text('pass'), findsWidgets);
    });

    testWidgets('diagnostics copy contains no banned prescriptive phrases', (
      tester,
    ) async {
      for (final tag in const ['en-US', 'zh-CN', 'fr-FR', 'ja-JP']) {
        final i18n = AppI18n.fromLocaleTag(tag);
        for (final key in const [
          'diagnostics.title',
          'diagnostics.rerun',
          'diagnostics.scope_title',
          'diagnostics.scope_body',
        ]) {
          final value = i18n.tr(key);
          expect(value, isNot(key), reason: '$key unresolved for $tag');
          expect(
            findBannedSubstrings(value),
            isEmpty,
            reason: '$key ($tag) contains banned copy',
          );
        }
      }
    });

    testWidgets('survives a large text scale', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpFeaturePage(tester, const EngineeringDiagnosticsPage());
      await tester.pump();
      expectNoWidgetErrors(reason: 'diagnostics page broke at 1.6x text scale');
    });
  });
}
