@Timeout(Duration(minutes: 5))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/analysis/food_repository.dart';
import 'package:parkinsum_companion/core/constants/dish_catalog.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/core/state/dish_plate_handoff.dart';
import 'package:parkinsum_companion/core/theme/paper_theme.dart';
import 'package:parkinsum_companion/domain/entities/dish_recipe.dart';
import 'package:parkinsum_companion/features/main_shell/main_shell.dart';
import 'package:parkinsum_companion/features/main_shell/main_tab_route.dart';
import 'package:parkinsum_companion/features/next_meal/advanced_dishes_page.dart';
import 'package:parkinsum_companion/features/next_meal/advanced_dishes_widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Synthetic data only: the built-in catalog plus fabricated foods.

final _repo = FoodRepository.createDefault();

int _count(String region) =>
    kDishCatalog.where((d) => d.regions.contains(region)).length;

Widget _host(Widget child, {String locale = 'en-US', ThemeData? theme}) =>
    MaterialApp(
      theme: theme ?? Paper.themeData(),
      home: AppI18nScope(i18n: AppI18n.fromLocaleTag(locale), child: child),
    );

AdvancedDishesView _view({
  String region = 'CN',
  FoodItem? Function(String)? lookup,
  List<DishRecipe>? dishes,
  ValueChanged<DishPlateRequest>? onAddToPlate,
  ValueChanged<FoodItem>? onOpenFood,
}) => AdvancedDishesView(
  userRegion: region,
  lookup: lookup ?? _repo.getById,
  dishes: dishes,
  onAddToPlate: onAddToPlate ?? (_) {},
  onOpenFood: onOpenFood,
);

Future<void> _setSize(WidgetTester tester, double width, [double h = 2400]) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, h);
  addTearDown(tester.view.reset);
  return Future.value();
}

String _resultCount(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('dishes-result-count')))
    .data!;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void _expectMinTarget(WidgetTester tester, Finder finder) {
  for (final element in finder.evaluate()) {
    final size = tester.getSize(find.byWidget(element.widget).first);
    expect(size.height, greaterThanOrEqualTo(44), reason: '$element');
    expect(size.width, greaterThanOrEqualTo(44), reason: '$element');
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('route', () {
    test('/app/next-meal/advanced is a sub-route of Next meal', () {
      final route = MainTabRoute.fromUri(Uri.parse('/app/next-meal/advanced'));
      expect(route, MainTabRoute.nextMealAdvanced);
      expect(route.id, AdvancedDishesPage.routeId);
      expect(route.uri.path, AdvancedDishesPage.routePath);
      expect(route.tab, MainTabRoute.nextMeal);
      expect(MainTabRoute.fromId('next-meal/advanced'), route);
      expect(
        MainTabRoute.fromUri(Uri.parse('/app/next-meal/unknown')),
        MainTabRoute.nextMeal,
      );
      expect(MainTabRoute.values, isNot(contains(route)));
    });
  });

  group('list and filters', () {
    testWidgets('defaults to the onboarding region at 375 px', (tester) async {
      await _setSize(tester, 375);
      await tester.pumpWidget(_host(_view(region: 'CN')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'no overflow at 375 px');
      expect(_resultCount(tester), '${_count('CN')} dishes');
      expect(find.text('My region (China)'), findsOneWidget);
      expect(
        find.textContaining('simple preparation examples'),
        findsOneWidget,
      );
      expect(find.textContaining('not dietary advice'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('dish-card-dish_cn_tomato_egg')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dish-card-dish_fr_ratatouille')),
        findsNothing,
      );
      _expectMinTarget(tester, find.byType(DishesChoice));
      _expectMinTarget(tester, find.byType(OutlinedButton));
    });

    testWidgets('all regions, other regions and the fallback', (tester) async {
      await _setSize(tester, 375);
      await tester.pumpWidget(_host(_view(region: 'CN')));
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey('dishes-region-all')));
      expect(_resultCount(tester), '${kDishCatalog.length} dishes');
      await _tap(tester, find.byKey(const ValueKey('dishes-region-others')));
      await _tap(tester, find.byKey(const ValueKey('dishes-region-JP')));
      expect(_resultCount(tester), '${_count('JP')} dishes');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('dishes-region-others')),
          matching: find.text('Japan'),
        ),
        findsOneWidget,
      );
      await _tap(tester, find.byKey(const ValueKey('dishes-clear-filters')));
      expect(_resultCount(tester), '${_count('CN')} dishes');

      // A region with no tagged dishes shows every region and says so.
      await tester.pumpWidget(_host(_view(region: 'ID')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('dishes-region-fallback')),
        findsOneWidget,
      );
      expect(_resultCount(tester), '${kDishCatalog.length} dishes');
    });

    testWidgets('search and texture filter, empty state', (tester) async {
      await _setSize(tester, 375);
      await tester.pumpWidget(_host(_view(region: 'CN')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('dishes-search')),
        'tofu',
      );
      await tester.pumpAndSettle();
      final tofu = kDishCatalog.where(
        (d) =>
            d.regions.contains('CN') &&
            [
              d.name.en,
              for (final i in d.ingredients) i.name.en,
            ].any((t) => t.toLowerCase().contains('tofu')),
      );
      expect(_resultCount(tester), '${tofu.length} dishes');
      // Chinese text matches too.
      await tester.enterText(find.byKey(const ValueKey('dishes-search')), '番茄');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('dish-card-dish_cn_tomato_egg')),
        findsOneWidget,
      );

      await tester.enterText(find.byKey(const ValueKey('dishes-search')), '');
      await _tap(tester, find.byKey(const ValueKey('dishes-texture-pureed')));
      final pureed = kDishCatalog.where(
        (d) => d.regions.contains('CN') && d.offersTexture(DishTexture.pureed),
      );
      expect(_resultCount(tester), '${pureed.length} dishes');
      expect(
        find.byKey(const ValueKey('dish-card-dish_cn_plain_congee')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dish-card-dish_cn_garlic_bok_choy')),
        findsNothing,
      );

      await tester.enterText(
        find.byKey(const ValueKey('dishes-search')),
        'zzzz-nothing',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dishes-empty')), findsOneWidget);
      expect(_resultCount(tester), '0 dishes');
      await _tap(tester, find.byKey(const ValueKey('dishes-clear-filters')));
      expect(_resultCount(tester), '${_count('CN')} dishes');
    });
  });

  group('detail', () {
    testWidgets('narrow: ingredients, steps, time, nutrition and sources', (
      tester,
    ) async {
      await _setSize(tester, 375);
      FoodItem? opened;
      await tester.pumpWidget(
        _host(_view(region: 'CN', onOpenFood: (f) => opened = f)),
      );
      await tester.pumpAndSettle();
      await _tap(
        tester,
        find.byKey(const ValueKey('dish-card-dish_cn_tomato_egg')),
      );
      expect(
        find.byKey(const ValueKey('dish-detail-page-dish_cn_tomato_egg')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Tomato and egg stir-fry'), findsOneWidget);
      expect(find.text('Prep 5 min · cook 8 min'), findsOneWidget);
      expect(find.text('Wok or large frying pan'), findsOneWidget);
      for (var n = 1; n <= 4; n++) {
        expect(find.byKey(ValueKey('dish-step-$n')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('dish-step-5')), findsNothing);
      // Scallion is not in the catalog.
      expect(find.text('Not in catalog · nutrition unknown'), findsOneWidget);
      expect(
        find.text(
          'Catalog coverage: 5 of 6 ingredients (97% of ingredient weight)',
        ),
        findsOneWidget,
      );
      final protein = tester
          .getSemantics(find.byKey(const ValueKey('dish-nutrient-protein')))
          .label;
      expect(
        protein,
        matches(RegExp(r'^Protein: \d+\.\d g from 5 of 6 ingredients$')),
      );
      expect(
        find.text('known for 5 of 6 ingredients; the rest unknown'),
        findsWidgets,
      );
      expect(find.textContaining('IDDSI 6 wording'), findsOneWidget);
      expect(find.textContaining('not swallowing advice'), findsOneWidget);

      await _tap(
        tester,
        find.byKey(const ValueKey('dish-open-food-food_ref_usda_171287')),
      );
      expect(opened?.id, 'food_ref_usda_171287');

      await _tap(tester, find.byKey(const ValueKey('dish-provenance')));
      expect(
        find.byKey(const ValueKey('dish-provenance-sheet')),
        findsOneWidget,
      );
      expect(find.text('Source: USDA_FDC · code 171287'), findsOneWidget);
      expect(
        find.text('LNAA from the source amino-acid profile'),
        findsWidgets,
      );
      expect(find.text('LNAA 0: the source reports 0 g protein'), findsWidgets);
      _expectMinTarget(
        tester,
        find.byKey(const ValueKey('dish-provenance-close')),
      );
      await _tap(tester, find.byKey(const ValueKey('dish-provenance-close')));
      expect(find.byKey(const ValueKey('dish-provenance-sheet')), findsNothing);
    });

    testWidgets('add ingredients to plate exposes catalog foods only', (
      tester,
    ) async {
      await _setSize(tester, 375);
      DishPlateRequest? request;
      await tester.pumpWidget(
        _host(_view(region: 'ES', onAddToPlate: (r) => request = r)),
      );
      await tester.pumpAndSettle();
      await _tap(
        tester,
        find.byKey(const ValueKey('dish-card-dish_es_chickpeas_spinach')),
      );
      _expectMinTarget(tester, find.byKey(const ValueKey('dish-add-to-plate')));
      await _tap(tester, find.byKey(const ValueKey('dish-add-to-plate')));
      expect(request?.dishId, 'dish_es_chickpeas_spinach');
      expect(request!.items.map((i) => i.foodId), [
        'food_ref_usda_168462',
        'food_ref_usda_169230',
        'food_ref_usda_171413',
      ]);
      expect(request!.skippedIngredientNames.map((n) => n.en), [
        'Chickpeas, cooked',
        'Ground cumin',
        'Smoked paprika',
      ]);
      expect(
        find.textContaining(
          '3 catalog ingredients sent to the Next-meal plate',
        ),
        findsOneWidget,
      );
    });

    testWidgets('missing ingredients read as unknown, never 0', (tester) async {
      await _setSize(tester, 375);
      // A synthetic catalog where every food is unknown: nothing resolves.
      DishPlateRequest? request;
      await tester.pumpWidget(
        _host(
          _view(
            region: 'CN',
            lookup: (_) => null,
            onAddToPlate: (r) => request = r,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Protein Unknown'), findsWidgets);
      expect(find.textContaining('0.0 g'), findsNothing);
      await _tap(
        tester,
        find.byKey(const ValueKey('dish-card-dish_cn_plain_congee')),
      );
      expect(
        find.text('Catalog entry not found · nutrition unknown'),
        findsNWidgets(2),
      );
      expect(find.text('Not in catalog · nutrition unknown'), findsOneWidget);
      for (final key in ['protein', 'energy', 'competingLnaa']) {
        expect(
          tester.getSemantics(find.byKey(ValueKey('dish-nutrient-$key'))).label,
          endsWith(': Unknown'),
        );
      }
      expect(find.textContaining('0.0 g'), findsNothing);
      expect(find.textContaining('0 kcal'), findsNothing);
      await _tap(tester, find.byKey(const ValueKey('dish-add-to-plate')));
      expect(request, isNull);
      expect(
        find.text(
          'None of these ingredients are in the catalog, so there is nothing to add.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('desktop split shows the selected dish beside the list', (
      tester,
    ) async {
      await _setSize(tester, 1440, 1600);
      await tester.pumpWidget(_host(_view(region: 'FR')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final first = kDishCatalog.firstWhere((d) => d.regions.contains('FR'));
      expect(
        find.byKey(ValueKey('dish-detail-body-${first.id}')),
        findsOneWidget,
      );
      await _tap(
        tester,
        find.byKey(const ValueKey('dish-card-dish_fr_ratatouille')),
      );
      expect(
        find.byKey(const ValueKey('dish-detail-body-dish_fr_ratatouille')),
        findsOneWidget,
      );
      expect(find.byType(Navigator), findsOneWidget);
    });

    testWidgets('Chinese copy and dark theme', (tester) async {
      await _setSize(tester, 375);
      await tester.pumpWidget(
        _host(
          _view(region: 'CN'),
          locale: 'zh-CN',
          theme: ThemeData(brightness: Brightness.dark),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('我的地区（中国）'), findsOneWidget);
      expect(find.text('番茄炒蛋'), findsOneWidget);
      expect(find.textContaining('不是饮食建议'), findsOneWidget);
      await _tap(
        tester,
        find.byKey(const ValueKey('dish-card-dish_cn_steamed_fish')),
      );
      expect(find.text('每份食材'), findsOneWidget);
      expect(find.text('第 1 步'), findsNothing); // read through semantics
      expect(
        tester.getSemantics(find.byKey(const ValueKey('dish-step-1'))).label,
        startsWith('第 1 步：'),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('shell', () {
    Future<AppState> fixture() async {
      final services = Services.createEphemeral();
      await services.ready;
      await services.userDataService.saveOnboarded(true);
      final state = AppState(services: services);
      await state.bootstrap();
      await state.saveUserProfile(
        state.userProfile.copyWith(registrationRegion: 'US'),
      );
      return state;
    }

    testWidgets('sidebar entry opens the sub-route; back returns', (
      tester,
    ) async {
      await _setSize(tester, 1440, 1400);
      final state = (await tester.runAsync(fixture))!;
      addTearDown(state.dispose);
      var tab = 'next-meal';
      late StateSetter rebuild;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: MaterialApp(
            theme: Paper.themeData(),
            home: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return MainShell(
                  selectedTabId: tab,
                  onTabSelected: (id) => rebuild(() => tab = id),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The "Meals & food" group starts collapsed.
      await _tap(tester, find.text('MEALS & FOOD'));
      await _tap(tester, find.byKey(const ValueKey('tool-advanced-dishes')));
      expect(tab, 'next-meal/advanced');
      expect(
        find.byKey(const ValueKey('advanced-dishes-page')),
        findsOneWidget,
      );
      expect(find.text('My region (United States)'), findsOneWidget);
      expect(_resultCount(tester), '${_count('US')} dishes');
      expect(tester.takeException(), isNull);
      await _tap(tester, find.byKey(const ValueKey('dishes-back')));
      expect(tab, 'next-meal');
      expect(find.byKey(const ValueKey('advanced-dishes-page')), findsNothing);
    });

    testWidgets('planner link opens the page; a dish fills the planner plate', (
      tester,
    ) async {
      await _setSize(tester, 1440, 2400);
      final state = (await tester.runAsync(fixture))!;
      addTearDown(state.dispose);
      addTearDown(DishPlateHandoff.instance.take);
      var tab = 'next-meal';
      late StateSetter rebuild;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: MaterialApp(
            theme: Paper.themeData(),
            home: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return MainShell(
                  selectedTabId: tab,
                  onTabSelected: (id) => rebuild(() => tab = id),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey('next-meal-advanced-link')));
      expect(tab, AdvancedDishesPage.routeId);
      await _tap(
        tester,
        find.byKey(const ValueKey('dish-card-dish_us_banana_oatmeal')),
      );
      await _tap(tester, find.byKey(const ValueKey('dish-add-to-plate')));
      expect(DishPlateHandoff.instance.pending, isNull, reason: 'taken');
      await _tap(tester, find.byKey(const ValueKey('dishes-back')));
      expect(tab, 'next-meal');
      for (final id in ['food_ref_usda_173904', 'food_ref_usda_171267']) {
        expect(
          find.byKey(ValueKey('next-meal-plate-item-$id'), skipOffstage: false),
          findsOneWidget,
          reason: id,
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('default plate action offers on the shared hand-off', (
      tester,
    ) async {
      await _setSize(tester, 375);
      final state = (await tester.runAsync(fixture))!;
      addTearDown(state.dispose);
      addTearDown(DishPlateHandoff.instance.take);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: MaterialApp(
            theme: Paper.themeData(),
            home: const AdvancedDishesPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(
        tester,
        find.byKey(const ValueKey('dish-card-dish_us_banana_oatmeal')),
      );
      await _tap(tester, find.byKey(const ValueKey('dish-add-to-plate')));
      final pending = DishPlateHandoff.instance.pending;
      expect(pending?.dishId, 'dish_us_banana_oatmeal');
      expect(pending!.items, hasLength(4));
      expect(pending.skippedIngredientNames, isEmpty);
    });
  });
}
