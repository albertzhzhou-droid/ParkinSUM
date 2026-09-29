import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parkinsum_companion/features/diagnostics/engineering_diagnostics_page.dart';
import 'package:parkinsum_companion/features/diagnostics/knowledge_lifecycle_workbench_page.dart';
import 'package:parkinsum_companion/features/diagnostics/rule_test_workbench_page.dart';
import 'package:parkinsum_companion/features/settings/settings_capability_page.dart';

import 'helpers/page_test_harness.dart';

void main() {
  testWidgets('diagnostics opens the isolated synthetic rule workbench', (
    tester,
  ) async {
    await pumpFeaturePage(tester, const EngineeringDiagnosticsPage());
    await tester.pump();
    final entry = find.byKey(const Key('open-rule-test-workbench'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(RuleTestWorkbenchPage), findsOneWidget);
    expectNoWidgetErrors();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(EngineeringDiagnosticsPage), findsOneWidget);
    expectNoWidgetErrors();
  });

  testWidgets('capability center opens the synthetic rule test workbench', (
    tester,
  ) async {
    await pumpFeaturePage(tester, const SettingsCapabilityPage());
    final entry = find.text('Rule test workbench (synthetic only)');
    await tester.scrollUntilVisible(
      entry,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    // scrollUntilVisible can stop with the row on the viewport edge.
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(RuleTestWorkbenchPage), findsOneWidget);
    expect(find.textContaining('Synthetic examples only.'), findsOneWidget);
    expect(find.text('Rule test workbench'), findsOneWidget);
    expectNoWidgetErrors(reason: 'settings could not open the rule workbench');
  });

  testWidgets('diagnostics exposes signed knowledge lifecycle controls', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await pumpFeaturePage(tester, const EngineeringDiagnosticsPage());
    await tester.pump();
    final entry = find.byKey(const Key('open-knowledge-lifecycle-workbench'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(KnowledgeLifecycleWorkbenchPage), findsOneWidget);
    expect(find.textContaining('Trusted signing keys: 0'), findsOneWidget);
    expect(
      find.textContaining('exact bundled prototype baseline'),
      findsOneWidget,
    );
    expectNoWidgetErrors();
  });
}
