import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/features/diagnostics/engineering_diagnostics_page.dart';
import 'package:parkinsum_companion/features/diagnostics/fhir_r5_medication_product_preview_page.dart';

import 'helpers/page_test_harness.dart';

void main() {
  testWidgets('diagnostics registers the offline FHIR R5 preview route', (
    tester,
  ) async {
    await pumpFeaturePage(
      tester,
      const EngineeringDiagnosticsPage(),
      surfaceSize: const Size(1170, 6000),
    );
    await tester.pumpAndSettle();
    final entry = find.byKey(
      const Key('open-fhir-r5-medication-product-preview'),
    );
    await tester.scrollUntilVisible(
      entry,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    final tile = tester.widget<ListTile>(entry);
    expect(tile.onTap, isNotNull);
    tile.onTap!.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byType(FhirR5MedicationProductPreviewPage, skipOffstage: false),
      findsOneWidget,
    );
    expect(
      tester.state<NavigatorState>(find.byType(Navigator).first).canPop(),
      isTrue,
    );
    expectNoWidgetErrors();
  });

  testWidgets('projects eligible tablet strength and holds a liquid strength', (
    tester,
  ) async {
    await pumpFeaturePage(
      tester,
      FhirR5MedicationProductPreviewPage(
        localeTag: 'en-US',
        snapshotBytesLoader: () async =>
            utf8.encode(jsonEncode(_snapshotPayload())),
      ),
    );
    await tester.pumpAndSettle();

    await _bringIntoView(tester, find.byKey(const Key('fhir-r5-preview-json')));
    expect(find.byKey(const Key('fhir-r5-preview-status')), findsOneWidget);
    var payload = _payload(tester);
    var fragment = payload['medication_fragment'] as Map<String, dynamic>;
    var ingredients = fragment['ingredient'] as List<dynamic>;
    expect(ingredients.single['strengthQuantity'], <String, dynamic>{
      'value': 100.0,
      'unit': 'mg',
      'system': 'http://unitsofmeasure.org',
      'code': 'mg',
    });
    expect(payload['algorithm_eligible'], isFalse);
    expect(payload['resource_or_exchange_eligible'], isFalse);
    final provenance = payload['source_provenance'] as Map<String, dynamic>;
    final localManifest = provenance['local_source_manifest'] as Map;
    expect(
      localManifest['source_asset_sha256'],
      matches(RegExp(r'^[0-9a-f]{64}$')),
    );
    expect(
      localManifest['manifest_sha256'],
      matches(RegExp(r'^[0-9a-f]{64}$')),
    );
    final tabletEvidence =
        (payload['product_strength_evidence'] as List).single as Map;
    final tabletRow = tabletEvidence['source_row_identity'] as Map;
    expect(tabletRow['product_id'], 'tablet-product-id');
    expect(tabletRow['spl_id'], 'tablet-spl-id');
    expect(tabletRow['ingredient_index'], 0);
    expect(
      tabletEvidence['source_row_binding_state'],
      'exact_unique_local_snapshot_row_match',
    );

    final selector = find.byKey(const Key('fhir-r5-product-selector'));
    await _bringIntoView(tester, selector, towardStart: true);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Synthetic liquid').last);
    await tester.pumpAndSettle();

    await _bringIntoView(tester, find.byKey(const Key('fhir-r5-preview-json')));
    payload = _payload(tester);
    fragment = payload['medication_fragment'] as Map<String, dynamic>;
    ingredients = fragment['ingredient'] as List<dynamic>;
    expect(ingredients.single.containsKey('strengthQuantity'), isFalse);
    final evidence = payload['product_strength_evidence'] as List<dynamic>;
    expect(evidence.single['evidence_state'], 'held_product_metadata_only');
    expectNoWidgetErrors();
  });
}

Map<String, dynamic> _payload(WidgetTester tester) =>
    jsonDecode(
          tester
              .widget<SelectableText>(
                find.byKey(const Key('fhir-r5-preview-json')),
              )
              .data!,
        )
        as Map<String, dynamic>;

Map<String, Object?> _snapshotPayload() => <String, Object?>{
  'source_system': 'OPENFDA_NDC',
  'source_url': 'https://api.fda.gov/drug/ndc.json',
  'retrieved_at': '2026-08-17T04:12:16.084Z',
  'limitations': <String>['Synthetic fixture; source data is not verified.'],
  'records': <Map<String, Object?>>[
    _record(
      productNdc: '01234-5678',
      productId: 'tablet-product-id',
      splId: 'tablet-spl-id',
      brand: 'Synthetic tablet',
      form: 'TABLET',
      strength: '100 mg/1',
    ),
    _record(
      productNdc: '01234-5679',
      productId: 'liquid-product-id',
      splId: 'liquid-spl-id',
      brand: 'Synthetic liquid',
      form: 'SOLUTION',
      strength: '50 mg/5 mL',
    ),
  ],
};

Map<String, Object?> _record({
  required String productNdc,
  required String productId,
  required String splId,
  required String brand,
  required String form,
  required String strength,
}) => <String, Object?>{
  'record': <String, Object?>{
    'product_ndc': productNdc,
    'product_id': productId,
    'spl_id': splId,
    'generic_name': 'Synthetic ingredient',
    'brand_name': brand,
    'labeler_name': 'Fixture labeler',
    'product_type': 'HUMAN PRESCRIPTION DRUG',
    'dosage_form': form,
    'route': <String>['ORAL'],
    'finished': true,
    'active_ingredients': <Map<String, Object?>>[
      <String, Object?>{'name': 'synthetic ingredient', 'strength': strength},
    ],
  },
};

Future<void> _bringIntoView(
  WidgetTester tester,
  Finder finder, {
  bool towardStart = false,
}) async {
  const attempts = 12;
  final screenHeight =
      tester.view.physicalSize.height / tester.view.devicePixelRatio;
  for (var attempt = 0; attempt < attempts; attempt++) {
    if (finder.evaluate().isNotEmpty) {
      final rect = tester.getRect(finder);
      if (rect.top >= 0 && rect.bottom <= screenHeight) return;
    }
    await tester.drag(
      find.byType(ListView).first,
      Offset(0, towardStart ? 420 : -420),
    );
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}
