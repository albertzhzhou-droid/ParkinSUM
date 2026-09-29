import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/domain/usecases/get_protein_trend_usecase.dart';

void main() {
  final useCase = GetProteinTrendUseCase();

  test('orders totals by effective occurrence time and averages per meal', () {
    final meals = <Meal>[
      _meal(
        id: 'later',
        eatenAt: DateTime.utc(2026, 1, 1),
        occurredAt: DateTime.utc(2026, 1, 3),
        proteinPer100g: 30,
      ),
      _meal(
        id: 'first',
        eatenAt: DateTime.utc(2026, 1, 3),
        occurredAt: DateTime.utc(2026, 1, 1),
        proteinPer100g: 10,
      ),
      _meal(
        id: 'range-fallback',
        eatenAt: DateTime.utc(2026, 1, 1),
        occurredRangeStart: DateTime.utc(2026, 1, 2),
        proteinPer100g: 20,
      ),
    ];

    final points = useCase.call(meals);

    expect(points.map((point) => point.time), [
      DateTime.utc(2026, 1, 1),
      DateTime.utc(2026, 1, 2),
      DateTime.utc(2026, 1, 3),
    ]);
    expect(points.map((point) => point.protein), [10, 20, 30]);
    expect(useCase.averageProtein(meals), 20);
  });

  test('returns zero for the empty per-meal mean', () {
    expect(useCase.averageProtein(const <Meal>[]), 0);
  });
}

Meal _meal({
  required String id,
  required DateTime eatenAt,
  DateTime? occurredAt,
  DateTime? occurredRangeStart,
  required double proteinPer100g,
}) => Meal(
  id: id,
  eatenAt: eatenAt,
  occurredAt: occurredAt,
  occurredRangeStart: occurredRangeStart,
  title: 'synthetic',
  items: [
    MealItem(
      foodId: 'synthetic-food',
      foodName: 'synthetic',
      foodCategory: FoodCategory.protein,
      quantityFactor: 1,
      foodTags: const [],
      proteinPer100g: proteinPer100g,
      carbsPer100g: 0,
      fatPer100g: 0,
      fiberPer100g: 0,
      sodiumPer100g: 0,
    ),
  ],
);
