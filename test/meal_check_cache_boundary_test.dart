import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/features/meals/meal_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Meal _unknownMeal() => Meal(
  id: 'synthetic-cache-boundary',
  title: 'Synthetic unknown protein',
  eatenAt: DateTime.utc(2026, 9, 30, 12),
  items: [
    MealItem(
      foodId: 'synthetic-unknown-food',
      foodName: 'Synthetic',
      foodCategory: FoodCategory.other,
      quantityFactor: 1,
      foodTags: [],
      missingNutrientFields: {'proteinG'},
      proteinPer100g: 999,
      carbsPer100g: 40,
      fatPer100g: 25,
      fiberPer100g: 0,
      sodiumPer100g: 0,
    ),
  ],
);

Future<AppState> _state() async {
  final services = Services.createEphemeral();
  await services.ready;
  final state = AppState(services: services);
  await state.bootstrap();
  addTearDown(state.dispose);
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('uncached unknown protein never receives a legacy score', () async {
    final state = await _state();
    await state.setActiveDrugIds(['drug_levodopa_carbidopa']);
    final meal = _unknownMeal();
    expect(state.cachedMealCheck(meal), isNull);
    await state.checkMeal(meal);
    expect(
      state.cachedMealCheck(meal),
      isNull,
      reason: 'An unsaved assessment must not populate a saved-record cache.',
    );
  });

  test('nonoral uncached medication never enters the legacy engine', () async {
    final state = await _state();
    state.medRepo.replaceAll([
      DrugDefinition(
        id: 'synthetic-iv',
        genericName: 'Synthetic nonoral levodopa',
        brandNames: [],
        tags: [DrugTag.levodopaLike],
        notes: '',
        route: 'intravenous',
      ),
    ]);
    await state.setActiveDrugIds(['synthetic-iv']);
    expect(state.cachedMealCheck(_unknownMeal()), isNull);
  });

  test('completed saved checks require exact meal content', () async {
    final state = await _state();
    final meal = _unknownMeal();
    expect((await state.addMeal(meal)).wasCommitted, isTrue);
    final completed = state.cachedMealCheck(meal);
    expect(completed, isNotNull);
    expect(
      completed!.score,
      0,
      reason: 'No active medications is a completed check.',
    );
    expect(
      state.cachedMealCheck(Meal.fromJson(meal.toJson())),
      same(completed),
    );
    expect(state.cachedMealCheck(meal.copyWith(title: 'Unsaved edit')), isNull);
    expect(
      state.cachedMealCheck(
        meal.copyWith(items: [meal.items.single.copyWith(quantityFactor: 2)]),
      ),
      isNull,
    );
    expect((await state.deleteMeal(meal.id)).wasCommitted, isTrue);
    expect(state.cachedMealCheck(meal), isNull);
  });

  test(
    'food catalogue revision invalidates a previously completed check',
    () async {
      final state = await _state();
      final meal = _unknownMeal();
      await state.addMeal(meal);
      final previous = state.cachedMealCheck(meal)!;
      state.foodRepo.replaceAll(state.foodRepo.allFoods);
      expect(state.cachedMealCheck(meal), isNull);
      final current = await state.checkMeal(meal);
      expect(state.cachedMealCheck(meal), same(current));
      expect(current, isNot(same(previous)));
    },
  );

  test(
    'medication route changes invalidate even an unchanged meal id',
    () async {
      final state = await _state();
      await state.setActiveDrugIds(['drug_levodopa_carbidopa']);
      final meal = _unknownMeal();
      await state.addMeal(meal);
      expect(state.cachedMealCheck(meal), isNotNull);
      expect(state.followups(), isNotEmpty);
      final oral = state.activeDrugs.single;
      state.medRepo.replaceAll([
        DrugDefinition(
          id: oral.id,
          genericName: oral.genericName,
          brandNames: oral.brandNames,
          tags: oral.tags,
          notes: oral.notes,
          route: 'intravenous',
        ),
      ]);
      expect(state.cachedMealCheck(meal), isNull);
      expect(state.followups(), isEmpty);
      final current = await state.checkMeal(meal);
      expect(state.cachedMealCheck(meal), same(current));
    },
  );

  for (final locale in ['en', 'zh']) {
    testWidgets('$locale meal list shows pending without a fabricated score', (
      tester,
    ) async {
      final state = (await tester.runAsync(() async {
        final state = await _state();
        await state.saveUserProfile(
          state.userProfile.copyWith(displayLocale: locale),
        );
        await state.addMeal(_unknownMeal());
        state.foodRepo.replaceAll(state.foodRepo.allFoods);
        return state;
      }))!;
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: const MaterialApp(home: MealPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          locale == 'zh' ? '尚未完成检查' : 'check not yet completed',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(locale == 'zh' ? '分数 0' : 'Score 0'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
