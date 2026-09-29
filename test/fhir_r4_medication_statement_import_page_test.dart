import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/features/diagnostics/engineering_diagnostics_page.dart';
import 'package:parkinsum_companion/features/diagnostics/fhir_r4_medication_statement_import_page.dart';

import 'helpers/page_test_harness.dart';

void main() {
  testWidgets('engineering diagnostics opens the local import preview', (
    tester,
  ) async {
    await pumpFeaturePage(tester, const EngineeringDiagnosticsPage());
    final entry = find.byKey(
      const Key('open-fhir-r4-medication-statement-import'),
    );
    await _bringIntoView(tester, entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.byType(FhirR4MedicationStatementImportPage), findsOneWidget);
    expect(
      find.text('FHIR R4 MedicationStatement import preview'),
      findsOneWidget,
    );
    expect(find.textContaining('not proof of administration'), findsOneWidget);
    expectNoWidgetErrors();
  });

  testWidgets(
    'synthetic collection preview stays in memory and source-claimed',
    (tester) async {
      await pumpFeaturePage(
        tester,
        const FhirR4MedicationStatementImportPage(localeTag: 'en-US'),
        surfaceSize: const Size(1290, 5200),
      );
      final fill = find.byKey(const Key('fhir-med-statement-fill-example'));
      await _bringIntoView(tester, fill);
      await tester.tap(fill);
      await tester.pumpAndSettle();

      final run = find.byKey(const Key('fhir-med-statement-run'));
      await _bringIntoView(tester, run);
      await tester.tap(run);
      await tester.pumpAndSettle();

      expect(find.text('Ready for local review'), findsOneWidget);
      expect(
        find.text('FHIR status (source-reported): unknown'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Medication identity (unresolved): Synthetic medication',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Nothing was imported or saved.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Source dosage text (not parsed)'),
        findsOneWidget,
      );
      expectNoWidgetErrors();

      final input = find.byKey(const Key('fhir-med-statement-json'));
      await _bringIntoView(tester, input);
      final raw = tester.widget<TextField>(input).controller!.text;
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      final entry = (parsed['entry'] as List).single as Map<String, dynamic>;
      final resource = entry['resource'] as Map<String, dynamic>;
      resource['extension'] = [
        {'url': 'https://example.org/x', 'valueString': 'held'},
      ];
      await tester.enterText(input, jsonEncode(parsed));
      await _bringIntoView(tester, run);
      await tester.tap(run);
      await tester.pumpAndSettle();

      expect(find.text('Needs review'), findsOneWidget);
      expect(
        find.textContaining('Bundle.entry[0].resource.extension'),
        findsOneWidget,
      );
      expectNoWidgetErrors();
    },
  );

  testWidgets('invalid JSON is not echoed and Clear empties the input', (
    tester,
  ) async {
    await pumpFeaturePage(
      tester,
      const FhirR4MedicationStatementImportPage(localeTag: 'zh-CN'),
      surfaceSize: const Size(1290, 4600),
    );
    final input = find.byKey(const Key('fhir-med-statement-json'));
    await _bringIntoView(tester, input);
    await tester.enterText(input, '{not valid json');
    final run = find.byKey(const Key('fhir-med-statement-run'));
    await _bringIntoView(tester, run);
    await tester.tap(run);
    await tester.pumpAndSettle();

    expect(find.text('无法预览此 JSON。请检查资源结构后重试。'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text && (widget.data ?? '').contains('{not valid json'),
      ),
      findsNothing,
    );
    expect(find.byKey(const Key('fhir-med-statement-result')), findsNothing);

    final clear = find.byKey(const Key('fhir-med-statement-clear'));
    await _bringIntoView(tester, clear);
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).controller!.text, isEmpty);
    expect(
      find.byKey(const Key('fhir-med-statement-input-error')),
      findsNothing,
    );
    expectNoWidgetErrors();
  });

  testWidgets('input size is bounded using UTF-8 bytes', (tester) async {
    await pumpFeaturePage(
      tester,
      const FhirR4MedicationStatementImportPage(localeTag: 'en-US'),
      surfaceSize: const Size(1290, 4600),
    );
    final input = find.byKey(const Key('fhir-med-statement-json'));
    await _bringIntoView(tester, input);
    final oversized = jsonEncode({
      'resourceType': 'MedicationStatement',
      'padding': List.filled(50000, '汉').join(),
    });
    expect(utf8.encode(oversized).length, greaterThan(128 * 1024));
    tester.widget<TextField>(input).controller!.text = oversized;
    final run = find.byKey(const Key('fhir-med-statement-run'));
    tester.widget<FilledButton>(run).onPressed!();
    await tester.pumpAndSettle();

    expect(
      find.text('This preview accepts up to 128 KiB of JSON.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('fhir-med-statement-result')), findsNothing);
    expectNoWidgetErrors();
  });
}

Future<void> _bringIntoView(WidgetTester tester, Finder finder) async {
  if (find.byType(Scrollable).evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}
