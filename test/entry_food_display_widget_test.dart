import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/features/entry/entry_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Meal entry shows catalogue foods by name in the display language, with
/// readable nutrients and source, results under the search box, and adds a
/// food at its reference serving. Synthetic profile and catalogue data only.
Future<AppState> _readyState(WidgetTester tester, String locale) async {
  final state = AppState(services: Services.createEphemeral());
  addTearDown(state.dispose);
  await state.services.ready;
  await state.bootstrap();
  await state.saveUserProfile(
    state.userProfile.copyWith(displayLocale: locale),
  );
  return state;
}

Future<void> _pumpEntry(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(1280, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: EntryPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _entryScrollable() => find
    .descendant(
      of: find.byKey(const Key('entry-form-list')),
      matching: find.byType(Scrollable),
    )
    .first;

String _subtitleOf(WidgetTester tester, String foodId) {
  final tile = find.descendant(
    of: find.byKey(ValueKey('entry-food-result-$foodId')),
    matching: find.byType(ListTile),
  );
  return (tester.widget<ListTile>(tile).subtitle! as Text).data!;
}

String _titleOf(WidgetTester tester, String foodId) {
  final tile = find.descendant(
    of: find.byKey(ValueKey('entry-food-result-$foodId')),
    matching: find.byType(ListTile),
  );
  return (tester.widget<ListTile>(tile).title! as Text).data!;
}

final _hanCharacters = RegExp(r'[一-鿿]');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'en-US search lists readable results under the box and adds a serving',
    (tester) async {
      final state = await _readyState(tester, 'en-US');
      await _pumpEntry(tester, state);

      expect(
        find.byKey(const ValueKey('entry-food-search-hint')),
        findsOneWidget,
      );
      // Specialist context is collapsed until asked for.
      expect(find.text('Iron supplement taken with this meal'), findsNothing);

      final search = find.byKey(const ValueKey('entry-food-search'));
      await tester.enterText(search, 'milk');
      await tester.pumpAndSettle();

      // Results start directly under the search box and are on screen
      // without scrolling.
      final results = find.byKey(const ValueKey('entry-food-search-results'));
      expect(results, findsOneWidget);
      final searchBottom = tester.getBottomLeft(search).dy;
      final resultsTop = tester.getTopLeft(results).dy;
      expect(resultsTop, greaterThan(searchBottom));
      expect(resultsTop - searchBottom, lessThan(40));
      const wholeMilk = 'food_ref_usda_171265';
      final wholeMilkCard = find.byKey(
        const ValueKey('entry-food-result-$wholeMilk'),
      );
      expect(wholeMilkCard, findsOneWidget);
      expect(tester.getBottomLeft(wholeMilkCard).dy, lessThan(1000));

      expect(_titleOf(tester, wholeMilk), 'Milk, whole, 3.25% fat');
      final subtitle = _subtitleOf(tester, wholeMilk);
      expect(
        subtitle.split('\n'),
        containsAllInOrder([
          'Per 100 g: Protein 3.1 g · Carbs 4.8 g · Fat 3.3 g · Fiber 0.0 g',
          'Adds 1 cup, 244 g (source portion)',
          'USDA FoodData Central · United States',
        ]),
      );
      for (final internal in [
        '171265',
        'USDA_FDC',
        'Projected from CDSS',
        'warning',
        'FDC SR Legacy',
      ]) {
        expect(subtitle, isNot(contains(internal)), reason: internal);
      }
      // No catalogue title or subtitle on the page is in Chinese.
      for (final tile in tester.widgetList<ListTile>(
        find.descendant(
          of: results.hitTestable(),
          matching: find.byType(ListTile),
        ),
      )) {
        expect((tile.title! as Text).data, isNot(matches(_hanCharacters)));
      }
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.data ?? '', isNot(contains('UNSPECIFIED_CIQUAL')));
      }

      await tester.tap(find.byKey(const ValueKey('entry-add-food-$wholeMilk')));
      await tester.pump();
      expect(
        find.text('Milk, whole, 3.25% fat added: 1 cup, 244 g'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: wholeMilkCard,
          matching: find.byIcon(Icons.check_circle),
        ),
        findsOneWidget,
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('entry-added-food-amount-0')),
        300,
        scrollable: _entryScrollable(),
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('entry-added-food-amount-0')),
            )
            .data,
        '1 cup, 244 g · reference serving (source portion)',
      );
      expect(find.text('Protein 7.7 g · Carbs 11.7 g'), findsOneWidget);

      // A food with no reference serving keeps 100 g and says so.
      await tester.scrollUntilVisible(
        search,
        -300,
        scrollable: _entryScrollable(),
      );
      await tester.enterText(search, 'food_coffee');
      await tester.pumpAndSettle();
      expect(
        _subtitleOf(tester, 'food_coffee'),
        contains('Adds 100 g (no reference serving)'),
      );
      await tester.tap(
        find.byKey(const ValueKey('entry-add-food-food_coffee')),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('entry-added-food-amount-1')),
        300,
        scrollable: _entryScrollable(),
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('entry-added-food-amount-1')),
            )
            .data,
        '100 g · no reference serving',
      );

      // The specialist sections open behind "More context" and still record
      // their inputs.
      final moreContext = find.byKey(const ValueKey('entry-more-context'));
      await tester.scrollUntilVisible(
        moreContext,
        300,
        scrollable: _entryScrollable(),
      );
      expect(
        find.text('Iron supplements, thickener and enteral feeding'),
        findsOneWidget,
      );
      await tester.tap(find.text('More context'));
      await tester.pumpAndSettle();
      final iron = find.text('Iron supplement taken with this meal');
      await tester.scrollUntilVisible(
        iron,
        200,
        scrollable: _entryScrollable(),
      );
      await tester.tap(iron);
      await tester.pumpAndSettle();
      expect(
        find.text('Set: Iron supplement taken with this meal'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('entry-save-meal')));
      await tester.pumpAndSettle();
      final meal = state.meals.single;
      expect(meal.items.map((item) => item.grams), [244, 100]);
      expect(meal.items.first.proteinG, closeTo(3.15 * 2.44, 1e-9));
      expect(meal.coeventSubstanceTags, contains('iron_salt'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('zh-CN keeps Chinese reference titles and grams-only servings', (
    tester,
  ) async {
    final state = await _readyState(tester, 'zh-CN');
    await _pumpEntry(tester, state);
    await tester.enterText(
      find.byKey(const ValueKey('entry-food-search')),
      'milk',
    );
    await tester.pumpAndSettle();
    const wholeMilk = 'food_ref_usda_171265';
    expect(_titleOf(tester, wholeMilk), '全脂牛奶（3.25%）');
    expect(
      _subtitleOf(tester, wholeMilk).split('\n'),
      containsAllInOrder([
        '每 100 g：蛋白质 3.1 g · 碳水 4.8 g · 脂肪 3.3 g · 膳食纤维 0.0 g',
        '添加 244 g（来源份量）',
        'USDA FoodData Central（美国农业部） · 美国',
      ]),
    );
    expect(tester.takeException(), isNull);
  });
}
