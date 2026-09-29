import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/features/diagnostics/fhir_r4_medication_dispense_import_page.dart';

void main() {
  testWidgets('local preview shows source claims and clears after edits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: FhirR4MedicationDispenseImportPage(localeTag: 'en-US'),
      ),
    );
    await tester.tap(find.byKey(const Key('fhir-med-dispense-load-example')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fhir-med-dispense-run-preview')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('fhir-med-dispense-import-result')),
      findsOneWidget,
    );
    expect(find.textContaining('previewable subset'), findsOneWidget);
    expect(find.textContaining('Status (source)'), findsOneWidget);
    expect(find.textContaining('Medication (source)'), findsOneWidget);
    expect(find.textContaining('Quantity (source)'), findsOneWidget);
    expect(find.textContaining('Days supply (source)'), findsOneWidget);
    expect(find.textContaining('Synthetic medication'), findsWidgets);
    expect(find.textContaining('30 tablets'), findsOneWidget);
    expect(find.textContaining('30 days'), findsOneWidget);
    expect(find.textContaining('does not prove pickup'), findsOneWidget);
    expect(
      find.byKey(const Key('fhir-med-dispense-patient-match-0')),
      findsOneWidget,
    );

    final resultText = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const Key('fhir-med-dispense-import-result')),
            matching: find.byType(Text),
          ),
        )
        .map((widget) => widget.data ?? '')
        .join('\n');
    expect(resultText, isNot(contains('Patient/synthetic-1')));
    expect(resultText, contains('completed'));
    expect(resultText, contains('2026-09-20T11:30:00-04:00'));

    await tester.enterText(
      find.byKey(const Key('fhir-med-dispense-json')),
      '{}',
    );
    await tester.pump();
    expect(
      find.byKey(const Key('fhir-med-dispense-import-result')),
      findsNothing,
    );
  });

  testWidgets('known unprojected fields are held for review', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: FhirR4MedicationDispenseImportPage(localeTag: 'en-US'),
      ),
    );
    await tester.tap(find.byKey(const Key('fhir-med-dispense-load-example')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('fhir-med-dispense-json')),
      '{"resourceType":"MedicationDispense","status":"completed",'
      '"medicationCodeableConcept":{"text":"Synthetic"},'
      '"subject":{"reference":"Patient/synthetic-1"},'
      '"dosageInstruction":[{"text":"unparsed"}]}',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fhir-med-dispense-run-preview')));
    await tester.pumpAndSettle();

    expect(find.textContaining('review required'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText &&
            (widget.data?.contains('MedicationDispense.dosageInstruction') ??
                false),
      ),
      findsOneWidget,
    );
  });
}
