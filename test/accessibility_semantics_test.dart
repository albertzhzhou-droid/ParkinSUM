import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/features/catalog/catalog_page.dart';
import 'package:provider/provider.dart';

/// Accessibility — semantic labels for meaning-bearing icons.
///
/// The catalog list rows (chevron "view details", check-circle "selected as
/// active medication") and the next-meal decision-path icon now carry
/// `semanticLabel`s sourced from i18n. These tests pin (a) the i18n label
/// coverage across the four inlined locales, (b) that the exact icon construct
/// used by the pages exposes the label to the semantics tree, and (c) a
/// page-level audit of the real CatalogPage rendered with a stub asset bundle
/// (brand images become a 1x1 png) and a local-mode AppState.
/// Educational prototype only; synthetic data only.
void main() {
  const labelKeys = ['catalog.view_detail', 'catalog.selected_active'];
  const localeTags = ['en-US', 'zh-CN', 'fr-FR', 'ja-JP'];

  test('a11y label keys resolve in all inlined locales and stay safe', () {
    for (final tag in localeTags) {
      final i18n = AppI18n.fromLocaleTag(tag);
      for (final key in labelKeys) {
        final value = i18n.tr(key);
        expect(value.trim(), isNotEmpty, reason: '$key empty for $tag');
        expect(value, isNot(key), reason: '$key unresolved for $tag');
        expect(findBannedSubstrings(value), isEmpty,
            reason: '$key for $tag contains banned copy');
      }
    }
  });

  testWidgets('catalog trailing icons expose semantic labels', (tester) async {
    final i18n = AppI18n.fromLocaleTag('en-US');
    // The same construct the catalog rows use after the a11y fix.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          ListTile(
            title: const Text('demo food'),
            trailing: Icon(Icons.chevron_right,
                semanticLabel: i18n.tr('catalog.view_detail')),
          ),
          ListTile(
            title: const Text('demo drug'),
            trailing: Icon(Icons.check_circle,
                semanticLabel: i18n.tr('catalog.selected_active')),
          ),
        ]),
      ),
    ));
    // ListTile merges its children's semantics into one node, so match the
    // icon labels inside the merged row labels.
    expect(find.bySemanticsLabel(RegExp('View details')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Selected as active medication')),
        findsOneWidget);
  });

  testWidgets('next-meal decision-path icon exposes its meaning',
      (tester) async {
    final i18n = AppI18n.fromLocaleTag('en-US');
    for (final aiUsed in [true, false]) {
      final label = aiUsed
          ? i18n.tr('next_meal.ai_polished')
          : i18n.tr('next_meal.conservative_engine');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Icon(
            aiUsed ? Icons.auto_awesome_rounded : Icons.shield_outlined,
            semanticLabel: label,
          ),
        ),
      ));
      expect(find.bySemanticsLabel(label), findsOneWidget,
          reason: 'decision-path icon (aiUsed=$aiUsed) must expose "$label"');
    }
  });

  testWidgets('CatalogPage exposes the view-details labels (page-level audit)',
      (tester) async {
    // Local-mode services + AppState; the background sqlite init has no VM
    // support and is irrelevant here, so it is captured by a guarded zone.
    AppState? state;
    runZonedGuarded(() {
      state = AppState(services: Services.createDefault());
    }, (_, __) {});
    expect(state, isNotNull);

    // The page is laid out for a phone viewport; widen the test surface so the
    // showcase card + list render without overflow at the default 800x600.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state!,
        child: MaterialApp(
          home: DefaultAssetBundle(
            bundle: _StubAssetBundle(),
            child: const CatalogPage(),
          ),
        ),
      ),
    );
    await tester.pump();

    // Food rows render with the accessible "view details" trailing label.
    expect(find.bySemanticsLabel(RegExp('View details')), findsWidgets);
  });
}

/// Serves a valid 1x1 transparent PNG for every image asset so page-level
/// widget tests can render brand images without the real asset bundle.
class _StubAssetBundle extends CachingAssetBundle {
  static final Uint8List _onePixelPng = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR (1x1 RGBA)
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, // IDAT
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, // IEND
    0x42, 0x60, 0x82,
  ]);

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      // AssetImage resolves variants through the manifest first; serve a
      // minimal StandardMessageCodec-encoded manifest for the brand assets.
      return const StandardMessageCodec().encodeMessage(<String, Object?>{
        'assets/brand/parkinsum-icon.png': <Object?>[],
        'assets/brand/parkinsum-wordmark.png': <Object?>[],
      })!;
    }
    return ByteData.view(_onePixelPng.buffer);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async => '{}';
}
