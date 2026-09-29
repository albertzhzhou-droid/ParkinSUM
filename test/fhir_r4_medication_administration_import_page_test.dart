import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/features/diagnostics/fhir_r4_medication_administration_import_page.dart';

void main() {
  testWidgets('local preview displays source claims and clears on edits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: FhirR4MedicationAdministrationImportPage(localeTag: 'en-US'),
      ),
    );
    await tester.tap(find.byKey(const Key('fhir-med-admin-load-example')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fhir-med-admin-run-preview')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('fhir-med-admin-import-result')),
      findsOneWidget,
    );
    expect(find.textContaining('previewable subset'), findsOneWidget);
    expect(find.textContaining('Status (source)'), findsOneWidget);
    expect(find.textContaining('Medication (source)'), findsOneWidget);
    expect(find.textContaining('Synthetic medication'), findsWidgets);
    expect(
      find.byKey(const Key('fhir-med-admin-patient-match-0')),
      findsOneWidget,
    );

    final resultText = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const Key('fhir-med-admin-import-result')),
            matching: find.byType(Text),
          ),
        )
        .map((widget) => widget.data ?? '')
        .join('\n');
    expect(resultText, isNot(contains('Patient/synthetic-1')));
    expect(resultText, contains('completed'));

    await tester.enterText(find.byKey(const Key('fhir-med-admin-json')), '{}');
    await tester.pump();
    expect(find.byKey(const Key('fhir-med-admin-import-result')), findsNothing);
  });

  testWidgets('unprojected dosage is visibly held for review', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: FhirR4MedicationAdministrationImportPage(localeTag: 'en-US'),
      ),
    );
    await tester.tap(find.byKey(const Key('fhir-med-admin-load-example')));
    await tester.pumpAndSettle();
    final jsonField = find.byKey(const Key('fhir-med-admin-json'));
    await tester.enterText(
      jsonField,
      '{"resourceType":"MedicationAdministration","status":"completed",'
      '"medicationCodeableConcept":{"text":"Synthetic"},'
      '"subject":{"reference":"Patient/synthetic-1"},'
      '"effectiveDateTime":"2026-09-20","dosage":{"text":"1 tablet"}}',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fhir-med-admin-run-preview')));
    await tester.pumpAndSettle();

    expect(find.textContaining('review required'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText &&
            (widget.data?.contains('MedicationAdministration.dosage') ?? false),
      ),
      findsOneWidget,
    );
  });
}
