import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/features/diagnostics/fhir_r4_condition_import_page.dart';

void main() {
  testWidgets('Condition preview stays local and expires after input edits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: FhirR4ConditionImportPage(localeTag: 'en-US')),
    );
    await tester.tap(find.byKey(const Key('fhir-condition-load-example')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fhir-condition-run-preview')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('fhir-condition-import-result')),
      findsOneWidget,
    );
    expect(find.textContaining('previewable subset'), findsOneWidget);
    expect(find.textContaining('Clinical status (source)'), findsOneWidget);
    expect(find.textContaining('Verification status (source)'), findsOneWidget);
    expect(find.textContaining('Synthetic condition'), findsWidgets);
    expect(
      find.byKey(const Key('fhir-condition-patient-match-0')),
      findsOneWidget,
    );

    final resultText = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const Key('fhir-condition-import-result')),
            matching: find.byType(Text),
          ),
        )
        .map((widget) => widget.data ?? '')
        .join('\n');
    expect(resultText, isNot(contains('Patient/synthetic-1')));

    await tester.enterText(find.byKey(const Key('fhir-condition-json')), '{}');
    await tester.pump();
    expect(find.byKey(const Key('fhir-condition-import-result')), findsNothing);
  });
}
