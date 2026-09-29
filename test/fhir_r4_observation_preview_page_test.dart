import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/services/smart_sandbox_discovery_client.dart';
import 'package:parkinsum_companion/features/diagnostics/engineering_diagnostics_page.dart';
import 'package:parkinsum_companion/features/diagnostics/fhir_r4_observation_preview_page.dart';

import 'helpers/page_test_harness.dart';

void main() {
  testWidgets('engineering diagnostics opens the local FHIR preview', (
    tester,
  ) async {
    await pumpFeaturePage(tester, const EngineeringDiagnosticsPage());
    await tester.pump();
    final entry = find.byKey(const Key('open-fhir-r4-observation-preview'));
    await tester.scrollUntilVisible(
      entry,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.byType(FhirR4ObservationPreviewPage), findsOneWidget);
    expect(find.text('FHIR R4 Observation preview'), findsOneWidget);
    expect(
      find.textContaining('Use fabricated or de-identified data only.'),
      findsOneWidget,
    );
    expectNoWidgetErrors();
  });

  testWidgets(
    'synthetic resource previews locally and unprojected fields hold',
    (tester) async {
      await pumpFeaturePage(
        tester,
        const FhirR4ObservationPreviewPage(localeTag: 'en-US'),
      );

      final fillExample = find.byKey(const Key('fhir-preview-fill-example'));
      await _bringIntoView(tester, fillExample);
      await tester.tap(fillExample);
      await tester.pumpAndSettle();
      final runPreview = find.byKey(const Key('fhir-preview-run'));
      await _bringIntoView(tester, runPreview);
      await tester.tap(runPreview);
      await tester.pumpAndSettle();

      expect(find.text('Ready for local review'), findsOneWidget);
      expect(find.text('120 mmHg'), findsOneWidget);
      expect(find.text('80 mmHg'), findsOneWidget);
      expect(
        find.textContaining('Nothing was imported or saved.'),
        findsOneWidget,
      );
      expectNoWidgetErrors();

      final resourceField = find.byKey(const Key('fhir-preview-resource-json'));
      await _bringIntoView(tester, resourceField);
      final controller = tester.widget<TextField>(resourceField).controller!;
      final resource = jsonDecode(controller.text) as Map<String, dynamic>;
      resource['category'] = [
        {
          'coding': [
            {'system': 'https://example.org/codes', 'code': 'held'},
          ],
        },
      ];
      await tester.enterText(resourceField, jsonEncode(resource));
      await _bringIntoView(tester, runPreview);
      await tester.tap(runPreview);
      await tester.pumpAndSettle();

      expect(find.text('Needs review'), findsOneWidget);
      expect(
        find.textContaining('Nothing was imported or saved.'),
        findsOneWidget,
      );
      final details = find.byKey(const Key('fhir-preview-diagnostic-details'));
      await _bringIntoView(tester, details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(find.textContaining('Observation.category'), findsOneWidget);
      expectNoWidgetErrors();
    },
  );

  testWidgets('SMART discovery is explicit and displays only bounded checks', (
    tester,
  ) async {
    var requests = 0;
    await pumpFeaturePage(
      tester,
      FhirR4ObservationPreviewPage(
        localeTag: 'en-US',
        discoveryLoader: () async {
          requests++;
          return const SmartSandboxDiscoveryReport(
            status200: true,
            jsonContentType: true,
            authorizationEndpointOnSandbox: true,
            tokenEndpointOnSandbox: true,
            standaloneLaunchAdvertised: true,
            publicClientAdvertised: true,
            pkceS256Advertised: true,
            pkcePlainAdvertised: false,
            observationReadScopeAdvertised: true,
            authorizationCodeGrantAdvertised: true,
            authorizationCodeResponseTypeAdvertised: true,
            standalonePatientContextAdvertised: true,
            patientPermissionAdvertised: true,
            permissionV2Advertised: true,
          );
        },
      ),
    );

    final action = find.byKey(const Key('smart-sandbox-discover'));
    await _bringIntoView(tester, action);
    expect(requests, 0);
    await tester.tap(action);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(requests, 1);
    expect(
      find.byKey(const Key('smart-sandbox-discovery-result')),
      findsOneWidget,
    );
    expect(find.text('HTTP 200 with JSON'), findsOneWidget);
    expect(find.text('PKCE S256 is advertised'), findsOneWidget);
    expect(find.text('PKCE plain is not advertised'), findsOneWidget);
    expect(find.text('Authorization-code grant is listed'), findsOneWidget);
    expect(
      find.text('Authorization-code response type is listed'),
      findsOneWidget,
    );
    expect(find.textContaining('not SMART certification'), findsOneWidget);
    expectNoWidgetErrors();
  });

  testWidgets('invalid JSON reports a generic error and Clear empties input', (
    tester,
  ) async {
    await pumpFeaturePage(
      tester,
      const FhirR4ObservationPreviewPage(localeTag: 'zh-CN'),
    );

    final input = find.byKey(const Key('fhir-preview-resource-json'));
    await _bringIntoView(tester, input);
    await tester.enterText(input, '{not valid json');
    final runPreview = find.byKey(const Key('fhir-preview-run'));
    await _bringIntoView(tester, runPreview);
    await tester.tap(runPreview);
    await tester.pumpAndSettle();
    expect(find.text('无法解析 JSON。请检查结构后重试。'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text && (widget.data ?? '').contains('{not valid json'),
      ),
      findsNothing,
    );

    final clear = find.byKey(const Key('fhir-preview-clear'));
    await _bringIntoView(tester, clear);
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).controller!.text, isEmpty);
    expect(find.byKey(const Key('fhir-preview-input-error')), findsNothing);
    expectNoWidgetErrors();
  });

  testWidgets('64 KiB limit applies to UTF-8 bytes', (tester) async {
    await pumpFeaturePage(
      tester,
      const FhirR4ObservationPreviewPage(localeTag: 'en-US'),
    );

    final input = find.byKey(const Key('fhir-preview-resource-json'));
    await _bringIntoView(tester, input);
    final oversizedJson = jsonEncode({
      'resourceType': 'Observation',
      'padding': List.filled(22000, '汉').join(),
    });
    expect(utf8.encode(oversizedJson).length, greaterThan(64 * 1024));
    tester.widget<TextField>(input).controller!.text = oversizedJson;
    final runPreview = find.byKey(const Key('fhir-preview-run'));
    tester.widget<FilledButton>(runPreview).onPressed!();
    await tester.pumpAndSettle();

    expect(
      find.text('This preview accepts resources up to 64 KiB.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('fhir-preview-result')), findsNothing);
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
