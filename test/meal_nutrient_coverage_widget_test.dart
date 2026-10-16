import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/features/analytics/analytics_page.dart';
import 'package:parkinsum_companion/features/main_shell/dashboard_page.dart';
import 'package:parkinsum_companion/features/meals/meal_page.dart';
import 'package:parkinsum_companion/features/timeline/timeline_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

FoodItem food(String id, double protein, {Set<String> missing = const {}}) =>
    FoodItem(
      id: id,
      name: id,
      category: FoodCategory.protein,
      proteinG: protein,
      carbsG: 0,
      fatG: 0,
      fiberG: 0,
      sodiumMg: 0,
      missingNutrientFields: missing,
    );

Meal meal(FoodItem item, String id) => Meal(
  id: id.toLowerCase().replaceAll(' ', '-'),
  title: id,
  eatenAt: DateTime.now(),
  occurredAt: DateTime.now(),
  items: [MealItem.fromFood(food: item, quantityFactor: 1)],
);

Widget host(AppState state, Widget page) => ChangeNotifierProvider.value(
  value: state,
  child: MaterialApp(home: page),
);

Future<AppState> ready(String locale) async {
  final state = AppState(services: Services.createEphemeral());
  await state.services.ready;
  await state.bootstrap();
  await state.saveUserProfile(
    state.userProfile.copyWith(displayLocale: locale),
  );
  final foods = [
    food('known-zero', 0),
    food('captured-unknown', 999, missing: {'proteinG'}),
    food('catalog-unknown', 0, missing: {'proteinG'}),
  ];
  state.services.foodRepository.replaceAll(foods);
  await state.addMeal(meal(foods.first, 'Measured zero meal'));
  await state.addMeal(meal(foods[1], 'Captured unknown meal'));
  // A legacy snapshot with no captured marker is held by current catalog evidence.
  await state.addMeal(
    meal(food('catalog-unknown', 50), 'Catalog unknown meal'),
  );
  return state;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final locale in ['en', 'zh']) {
    testWidgets(
      '$locale analytics reports excluded meals and keeps measured zero',
      (tester) async {
        final state = await ready(locale);
        addTearDown(state.dispose);
        await tester.binding.setSurfaceSize(const Size(900, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(host(state, const AnalyticsPage()));
        await tester.pumpAndSettle();
        expect(state.proteinTrend.single.protein, 0);
        expect(state.averageKnownProtein, 0);
        final coverage = find.byKey(
          const ValueKey('insights-protein-coverage'),
        );
        await tester.ensureVisible(coverage);
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(coverage).data,
          contains(locale == 'zh' ? '1 餐计入' : '1 meals included'),
        );
        expect(
          tester.widget<Text>(coverage).data,
          contains(locale == 'zh' ? '2 餐因蛋白质未知' : '2 meals excluded'),
        );
        await state.deleteMeal('measured-zero-meal');
        await tester.pumpAndSettle();
        expect(state.proteinTrend, isEmpty);
        expect(state.averageKnownProtein, isNull);
        expect(find.text('0.0 g'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'history, timeline and dashboard retain unknown separately from zero',
    (tester) async {
      final state = await ready('en');
      addTearDown(state.dispose);
      await tester.binding.setSurfaceSize(const Size(1000, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(host(state, const MealPage()));
      await tester.pumpAndSettle();
      expect(find.textContaining('P=Unknown'), findsNWidgets(2));
      expect(find.textContaining('P=0.0g'), findsOneWidget);
      await tester.pumpWidget(host(state, const TimelinePage()));
      await tester.pumpAndSettle();
      expect(find.textContaining('protein Unknown'), findsNWidgets(2));
      expect(find.textContaining('protein 0.0'), findsOneWidget);
      await state.deleteMeal('measured-zero-meal');
      await tester.pumpWidget(host(state, const DashboardPage()));
      await tester.pumpAndSettle();
      final mean = find.descendant(
        of: find.byKey(const ValueKey('dashboard-stat-protein')),
        matching: find.text('—'),
      );
      expect(mean, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
