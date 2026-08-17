import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/app_database_native.dart';

void main() {
  test('duplicate food rows in one meal receive distinct ordinal ids', () {
    final first = nativeMealItemStorageId(
      mealId: 'meal_1',
      foodId: 'food_1',
      ordinal: 0,
    );
    final second = nativeMealItemStorageId(
      mealId: 'meal_1',
      foodId: 'food_1',
      ordinal: 1,
    );

    expect(first, isNot(second));
  });

  test(
    'meal item storage id is stable and component boundaries are unambiguous',
    () {
      final first = nativeMealItemStorageId(
        mealId: 'meal_1',
        foodId: '2_food',
        ordinal: 3,
      );
      final repeated = nativeMealItemStorageId(
        mealId: 'meal_1',
        foodId: '2_food',
        ordinal: 3,
      );
      final differentComponents = nativeMealItemStorageId(
        mealId: 'meal',
        foodId: '1_2_food',
        ordinal: 3,
      );

      expect(repeated, first);
      expect(differentComponents, isNot(first));
    },
  );

  test('negative meal item ordinal is rejected', () {
    expect(
      () => nativeMealItemStorageId(
        mealId: 'meal_1',
        foodId: 'food_1',
        ordinal: -1,
      ),
      throwsRangeError,
    );
  });
}
