import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/features/diagnostics/fhir_r4_encounter_import_page.dart';

void main() {
  testWidgets('previews only the fixed local synthetic Encounter example', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: FhirR4EncounterImportPage(localeTag: 'en')),
    );

    final loadExample = find.byKey(const Key('fhir-encounter-load-example'));
    await tester.scrollUntilVisible(
      loadExample,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(loadExample);
    await tester.pumpAndSettle();
    final runPreview = find.byKey(const Key('fhir-encounter-run-preview'));
    await tester.scrollUntilVisible(
      runPreview,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(runPreview);
    await tester.pumpAndSettle();

    expect(find.text('FHIR R4 Encounter preview'), findsOneWidget);
    expect(find.text('Source status: finished'), findsOneWidget);
    expect(
      find.textContaining(
        'demo · https://example.org/synthetic-encounter-class',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Period start: 2026-09-20T10:00:00-04:00'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Container: Encounter · entries: 1 · held: 0'),
      findsOneWidget,
    );
    expect(
      find.textContaining('not saved, sent, or used by a CDSS rule'),
      findsOneWidget,
    );
  });

  testWidgets('invalid edits clear the prior preview before another run', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: FhirR4EncounterImportPage(localeTag: 'en')),
    );
    final loadExample = find.byKey(const Key('fhir-encounter-load-example'));
    await tester.scrollUntilVisible(
      loadExample,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(loadExample);
    await tester.pumpAndSettle();
    final runPreview = find.byKey(const Key('fhir-encounter-run-preview'));
    await tester.scrollUntilVisible(
      runPreview,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(runPreview);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fhir-encounter-entry-0')), findsOneWidget);

    final jsonField = find.byKey(const Key('fhir-encounter-json'));
    await tester.scrollUntilVisible(
      jsonField,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(jsonField, '{bad json');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fhir-encounter-entry-0')), findsNothing);
  });
}
