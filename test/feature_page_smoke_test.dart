import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/features/analytics/analytics_page.dart';
import 'package:parkinsum_companion/features/auth/auth_page.dart';
import 'package:parkinsum_companion/features/catalog/catalog_page.dart';
import 'package:parkinsum_companion/features/legal/privacy_disclaimer_page.dart';
import 'package:parkinsum_companion/features/main_shell/dashboard_page.dart';
import 'package:parkinsum_companion/features/meals/meal_page.dart';
import 'package:parkinsum_companion/features/medications/medication_page.dart';
import 'package:parkinsum_companion/features/next_meal/next_meal_page.dart';
import 'package:parkinsum_companion/features/timeline/timeline_page.dart';

import 'helpers/page_test_harness.dart';

/// Smoke coverage for the user-facing pages.
///
/// The repo has deep domain coverage but, before this file, no page-level
/// tests: a null dereference, a bad provider read, or a layout assertion in
/// any feature page shipped silently. Each case pumps the real page against a
/// local-mode AppState and asserts it builds without raising.
///
/// These are deliberately shallow — they pin "the page renders and does not
/// throw", not business logic, which the domain suites already cover.
///
/// Educational prototype only; local mode; synthetic/demo data only; no PHI.
void main() {
  Future<void> smoke(WidgetTester tester, Widget page, String label) async {
    await pumpFeaturePage(tester, page);
    expectNoWidgetErrors(reason: '$label failed to build cleanly');
    expect(
      find.byType(page.runtimeType),
      findsOneWidget,
      reason: '$label did not render',
    );
  }

  testWidgets('DashboardPage builds', (t) async {
    await smoke(t, const DashboardPage(), 'DashboardPage');
  });

  testWidgets('CatalogPage builds', (t) async {
    await smoke(t, const CatalogPage(), 'CatalogPage');
  });

  testWidgets('MedicationPage builds', (t) async {
    await smoke(t, const MedicationPage(), 'MedicationPage');
  });

  testWidgets('MealPage builds', (t) async {
    await smoke(t, const MealPage(), 'MealPage');
  });

  testWidgets('NextMealPage builds', (t) async {
    await smoke(t, const NextMealPage(), 'NextMealPage');
  });

  testWidgets('TimelinePage builds', (t) async {
    await smoke(t, const TimelinePage(), 'TimelinePage');
  });

  testWidgets('AnalyticsPage builds', (t) async {
    await smoke(t, const AnalyticsPage(), 'AnalyticsPage');
  });

  testWidgets('AuthPage builds', (t) async {
    await smoke(t, const AuthPage(), 'AuthPage');
  });

  testWidgets('PrivacyDisclaimerPage builds and keeps its boundary copy', (
    t,
  ) async {
    await smoke(t, const PrivacyDisclaimerPage(), 'PrivacyDisclaimerPage');
    // This page exists to carry the educational boundary; an empty render
    // would be a silent safety regression.
    expect(find.byType(Text), findsWidgets);
  });

  testWidgets('pages survive a large text scale (accessibility)', (t) async {
    // Text scaling is the most common source of overflow crashes in the
    // field; assert the densest page tolerates it.
    setTextScale(t, 1.6);
    await pumpFeaturePage(t, const DashboardPage());
    expectNoWidgetErrors(reason: 'DashboardPage broke at 1.6x text scale');
  });
}

/// Applies a text-scale factor for the current test.
void setTextScale(WidgetTester tester, double scale) {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}
