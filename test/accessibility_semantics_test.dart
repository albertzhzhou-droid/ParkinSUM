import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';

/// Accessibility — semantic labels for meaning-bearing icons.
///
/// The catalog list rows (chevron "view details", check-circle "selected as
/// active medication") and the next-meal decision-path icon now carry
/// `semanticLabel`s sourced from i18n. Full page-level semantics audits need
/// an asset-bundle test harness (brand images) and stay follow-up work; these
/// tests pin (a) the i18n label coverage across the four inlined locales and
/// (b) that the exact icon construct used by the pages exposes the label to
/// the semantics tree. Educational prototype only; synthetic data only.
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
}
