import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/synthetic_meal_journey.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/features/entry/entry_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final locale in ['en', 'zh']) {
    testWidgets(
      '$locale searched food cards preserve unknown, invalid and reported zero',
      (tester) async {
        final state = AppState(services: Services.createEphemeral());
        addTearDown(state.dispose);
        await state.services.ready;
        await state.bootstrap();
        await state.saveUserProfile(
          state.userProfile.copyWith(displayLocale: locale),
        );
        final foods = [
          ...syntheticMealJourneyFoods(),
          FoodItem(
            id: 'reported-zero-food',
            name: 'Reported zero food',
            category: FoodCategory.other,
            proteinG: 0,
            carbsG: 0,
            fatG: 0,
            fiberG: 0,
            sodiumMg: 0,
          ),
          FoodItem(
            id: 'invalid-nutrients-food',
            name: 'Invalid nutrients food',
            category: FoodCategory.other,
            proteinG: double.nan,
            carbsG: double.infinity,
            fatG: double.negativeInfinity,
            fiberG: -1,
            sodiumMg: 0,
          ),
        ];
        state.services.foodRepository.replaceAll(foods);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: state,
            child: const MaterialApp(home: EntryPage()),
          ),
        );
        await tester.pumpAndSettle();
        final search = find.byKey(const ValueKey('entry-food-search'));
        final scrollable = find
            .descendant(
              of: find.byKey(const ValueKey('entry-form-list')),
              matching: find.byType(Scrollable),
            )
            .first;
        // Independent expected strings cover each displayed field. The first
        // two cards are the actual isolated journey fixtures, not replicas.
        final expectedLines = locale == 'zh'
            ? [
                '每 100g：蛋白 10.0 g · 碳水 20.0 g · F 4.0 · Fiber 未知',
                '每 100g：蛋白 未知 g · 碳水 未知 g · F 未知 · Fiber 未知',
                '每 100g：蛋白 0.0 g · 碳水 0.0 g · F 0.0 · Fiber 0.0',
                '每 100g：蛋白 未知 g · 碳水 未知 g · F 未知 · Fiber 未知',
              ]
            : [
                'Per 100g: P 10.0 g - C 20.0 g · F 4.0 · Fiber Unknown',
                'Per 100g: P Unknown g - C Unknown g · F Unknown · Fiber Unknown',
                'Per 100g: P 0.0 g - C 0.0 g · F 0.0 · Fiber 0.0',
                'Per 100g: P Unknown g - C Unknown g · F Unknown · Fiber Unknown',
              ];
        for (var index = 0; index < foods.length; index++) {
          await tester.scrollUntilVisible(search, -400, scrollable: scrollable);
          await tester.enterText(search, foods[index].id);
          await tester.pumpAndSettle();
          final card = find.ancestor(
            of: find.text(foods[index].name),
            matching: find.byType(ListTile),
          );
          await tester.scrollUntilVisible(card, 400, scrollable: scrollable);
          final subtitle = tester.widget<ListTile>(card).subtitle! as Text;
          expect(subtitle.data!.split('\n').first, expectedLines[index]);
          if (index != 2) {
            expect(subtitle.data, isNot(contains('Fiber 0.0')));
          }
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
