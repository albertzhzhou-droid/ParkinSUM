import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/features/medications/medication_product_picker.dart';
import 'package:provider/provider.dart';

import 'helpers/page_test_harness.dart';

void main() {
  testWidgets('searches an identifier and returns the exact package', (
    tester,
  ) async {
    final state = createTestAppState();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: DefaultAssetBundle(
          bundle: _ProductAssetBundle(
            File(
              'assets/data/common_medication_products_openfda.json',
            ).readAsStringSync(),
          ),
          child: const MaterialApp(home: MedicationProductPickerPage()),
        ),
      ),
    );

    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find
          .byKey(const ValueKey<String>('medication-product-search'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }
    expect(
      find.byKey(const ValueKey<String>('medication-product-search')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('medication-product-search')),
      '72865-362',
    );
    await tester.pump();

    final visibleText = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? '')
        .toList(growable: false);
    expect(
      visibleText.any((text) => text.contains('NDC 72865-362')),
      isTrue,
      reason: visibleText.join(' | '),
    );
  });
}

class _ProductAssetBundle extends CachingAssetBundle {
  final String json;

  _ProductAssetBundle(this.json);

  @override
  Future<ByteData> load(String key) async => ByteData.view(Uint8List(0).buffer);

  @override
  Future<String> loadString(String key, {bool cache = true}) async => json;
}
