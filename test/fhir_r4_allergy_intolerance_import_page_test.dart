import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/features/diagnostics/engineering_diagnostics_page.dart';
import 'package:parkinsum_companion/features/diagnostics/fhir_r4_allergy_intolerance_import_page.dart';

import 'helpers/page_test_harness.dart';

void main() {
  testWidgets('engineering diagnostics opens the local allergy preview', (
    tester,
  ) async {
    await pumpFeaturePage(tester, const EngineeringDiagnosticsPage());
    final entry = find.byKey(
      const Key('open-fhir-r4-allergy-intolerance-preview'),
    );
    await _bringIntoView(tester, entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.byType(FhirR4AllergyIntoleranceImportPage), findsOneWidget);
    expect(find.text('FHIR R4 AllergyIntolerance preview'), findsOneWidget);
    expect(
      find.textContaining('does not conclude that an allergy is present'),
      findsOneWidget,
    );
    expectNoWidgetErrors();
  });

  testWidgets('synthetic preview keeps source statuses separate and scoped', (
    tester,
  ) async {
    await pumpFeaturePage(
      tester,
      const FhirR4AllergyIntoleranceImportPage(localeTag: 'en-US'),
      surfaceSize: const Size(1290, 5200),
    );
    final fill = find.byKey(const Key('fhir-allergy-fill-example'));
    await _bringIntoView(tester, fill);
    await tester.tap(fill);
    await tester.pumpAndSettle();

    final run = find.byKey(const Key('fhir-allergy-run'));
    await _bringIntoView(tester, run);
    await tester.tap(run);
    await tester.pumpAndSettle();

    expect(find.text('Ready for local review'), findsOneWidget);
    expect(
      find.textContaining('Clinical status (source-reported):'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Verification status (source-reported):'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Type (source-reported): allergy'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Reaction severity (source-reported): mild'),
      findsOneWidget,
    );
    expect(
      find.textContaining('expected Patient reference matched exactly'),
      findsOneWidget,
    );
    final result = find.byKey(const Key('fhir-allergy-result'));
    final resultText = tester
        .widgetList<Text>(
          find.descendant(of: result, matching: find.byType(Text)),
        )
        .map((widget) => widget.data ?? '')
        .join('\n');
    expect(resultText, isNot(contains('Patient/synthetic-1')));
    expect(resultText, isNot(contains('synthetic-allergy-intolerance-1')));
    expectNoWidgetErrors();

    final input = find.byKey(const Key('fhir-allergy-json'));
    await _bringIntoView(tester, input);
    final raw = tester.widget<TextField>(input).controller!.text;
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    final bundleEntry =
        (parsed['entry'] as List).single as Map<String, dynamic>;
    final resource = bundleEntry['resource'] as Map<String, dynamic>;
    resource['extension'] = [
      {'url': 'https://example.org/synthetic', 'valueString': 'held'},
    ];
    await tester.enterText(input, jsonEncode(parsed));
    await _bringIntoView(tester, run);
    await tester.tap(run);
    await tester.pumpAndSettle();

    expect(find.text('Needs review'), findsOneWidget);
    final details = find.byKey(const Key('fhir-allergy-diagnostics'));
    await _bringIntoView(tester, details);
    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(find.text('Bundle.entry[0].resource.extension'), findsOneWidget);
    expectNoWidgetErrors();
  });

  testWidgets('invalid JSON stays hidden and Clear empties local input', (
    tester,
  ) async {
    await pumpFeaturePage(
      tester,
      const FhirR4AllergyIntoleranceImportPage(localeTag: 'zh-CN'),
      surfaceSize: const Size(1290, 4600),
    );
    final input = find.byKey(const Key('fhir-allergy-json'));
    await _bringIntoView(tester, input);
    await tester.enterText(input, '{not valid json');
    final run = find.byKey(const Key('fhir-allergy-run'));
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
    expect(find.byKey(const Key('fhir-allergy-result')), findsNothing);

    final clear = find.byKey(const Key('fhir-allergy-clear'));
    await _bringIntoView(tester, clear);
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).controller!.text, isEmpty);
    expect(find.byKey(const Key('fhir-allergy-input-error')), findsNothing);
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
