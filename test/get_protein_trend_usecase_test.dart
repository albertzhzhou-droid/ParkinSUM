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

  test(
    'unknown protein excludes the whole meal without changing known zero or ordering',
    () {
      final now = DateTime.utc(2026, 9, 29);
      final zero = _meal(id: 'zero', eatenAt: now, proteinPer100g: 0);
      final known = _meal(
        id: 'known',
        eatenAt: now.subtract(const Duration(days: 1)),
        proteinPer100g: 20,
      );
      final flagged = _meal(id: 'flagged', eatenAt: now, proteinPer100g: 999);
      final missing = flagged.copyWith(
        items: [
          flagged.items.single.copyWith(missingNutrientFields: {'proteinG'}),
        ],
      );
      final partial = known.copyWith(
        id: 'partial',
        items: [known.items.single, missing.items.single],
      );
      final points = useCase([zero, missing, partial, known]);
      expect(points.map((point) => point.time), [
        known.effectiveOccurredAt,
        zero.effectiveOccurredAt,
      ]);
      expect(points.map((point) => point.protein), [20, 0]);
      expect(useCase.knownAverageProtein([zero, missing, partial, known]), 10);
      expect(useCase.knownAverageProtein([missing, partial]), isNull);
      expect(
        useCase.averageProtein([missing]),
        0,
        reason: 'Legacy API sentinel is not used by UI.',
      );
    },
  );

  test(
    'invalid protein, invalid quantity, empty input and overflow do not create points',
    () {
      final base = _meal(
        id: 'base',
        eatenAt: DateTime.utc(2026, 9, 29),
        proteinPer100g: 10,
      );
      final invalid = [
        for (final value in [double.nan, double.infinity, -1.0])
          base.copyWith(
            items: [base.items.single.copyWith(proteinPer100g: value)],
          ),
        for (final value in [double.nan, double.infinity, -1.0, 0.0])
          base.copyWith(
            items: [base.items.single.copyWith(quantityFactor: value)],
          ),
        base.copyWith(
          items: [
            base.items.single.copyWith(
              proteinPer100g: 1e308,
              quantityFactor: 100,
            ),
          ],
        ),
        base.copyWith(items: []),
      ];
      expect(useCase(invalid), isEmpty);
      expect(useCase.knownAverageProtein(invalid), isNull);
      expect(useCase.knownAverageProtein(const []), isNull);
    },
  );

  test('current catalog missingness holds captured numeric protein', () {
    final base = _meal(
      id: 'base',
      eatenAt: DateTime.utc(2026, 9, 29),
      proteinPer100g: 20,
    );
    final food = FoodItem(
      id: 'synthetic-food',
      name: 'synthetic',
      category: FoodCategory.protein,
      jurisdiction: 'US',
      sourceSystem: 'synthetic',
      proteinG: 20,
      carbsG: 0,
      fatG: 0,
      fiberG: 0,
      sodiumMg: 0,
      missingNutrientFields: {'proteinG'},
    );
    expect(useCase([base], catalog: [food]), isEmpty);
    expect(useCase.knownAverageProtein([base], catalog: [food]), isNull);
    expect(base.knownNutrientTotal('carbsG', catalog: [food]), 0);
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
