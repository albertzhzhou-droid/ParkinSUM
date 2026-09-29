import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/features/diagnostics/engineering_diagnostics_page.dart';
import 'package:parkinsum_companion/features/diagnostics/fhir_r4_medication_request_import_page.dart';

import 'helpers/page_test_harness.dart';

void main() {
  testWidgets('engineering diagnostics opens the MedicationRequest preview', (
    tester,
  ) async {
    await pumpFeaturePage(tester, const EngineeringDiagnosticsPage());
    final entry = find.byKey(
      const Key('open-fhir-r4-medication-request-preview'),
    );
    await _bringIntoView(tester, entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.byType(FhirR4MedicationRequestImportPage), findsOneWidget);
    expect(find.text('FHIR R4 MedicationRequest preview'), findsOneWidget);
    expect(
      find.textContaining('not proof that medication was dispensed'),
      findsOneWidget,
    );
    expectNoWidgetErrors();
  });

  testWidgets(
    'synthetic request preview preserves status and intent separately',
    (tester) async {
      await pumpFeaturePage(
        tester,
        const FhirR4MedicationRequestImportPage(localeTag: 'en-US'),
        surfaceSize: const Size(1290, 5200),
      );
      final fill = find.byKey(const Key('fhir-med-request-fill-example'));
      await _bringIntoView(tester, fill);
      await tester.tap(fill);
      await tester.pumpAndSettle();

      final run = find.byKey(const Key('fhir-med-request-run'));
      await _bringIntoView(tester, run);
      await tester.tap(run);
      await tester.pumpAndSettle();

      expect(find.text('Ready for local review'), findsOneWidget);
      expect(
        find.text('Request status (source-reported): active'),
        findsOneWidget,
      );
      expect(
        find.text('Request intent (source-reported): order'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'not MedicationStatement or administration records',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Source dosage instruction (not parsed)'),
        findsOneWidget,
      );
      expectNoWidgetErrors();

      final input = find.byKey(const Key('fhir-med-request-json'));
      await _bringIntoView(tester, input);
      final raw = tester.widget<TextField>(input).controller!.text;
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      final bundleEntry =
          (parsed['entry'] as List).single as Map<String, dynamic>;
      final resource = bundleEntry['resource'] as Map<String, dynamic>;
      resource['doNotPerform'] = true;
      await tester.enterText(input, jsonEncode(parsed));
      await _bringIntoView(tester, run);
      await tester.tap(run);
      await tester.pumpAndSettle();

      expect(find.text('Needs review'), findsOneWidget);
      expect(
        find.textContaining('Bundle.entry[0].resource.doNotPerform'),
        findsOneWidget,
      );
      expectNoWidgetErrors();
    },
  );

  testWidgets('invalid JSON stays hidden and Clear empties the local input', (
    tester,
  ) async {
    await pumpFeaturePage(
      tester,
      const FhirR4MedicationRequestImportPage(localeTag: 'zh-CN'),
      surfaceSize: const Size(1290, 4600),
    );
    final input = find.byKey(const Key('fhir-med-request-json'));
    await _bringIntoView(tester, input);
    await tester.enterText(input, '{not valid json');
    final run = find.byKey(const Key('fhir-med-request-run'));
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
    expect(find.byKey(const Key('fhir-med-request-result')), findsNothing);

    final clear = find.byKey(const Key('fhir-med-request-clear'));
    await _bringIntoView(tester, clear);
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).controller!.text, isEmpty);
    expect(find.byKey(const Key('fhir-med-request-input-error')), findsNothing);
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
