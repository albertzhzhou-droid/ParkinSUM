import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/synthetic_meal_journey.dart';
import 'package:parkinsum_companion/core/db/app_database_native.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/domain/usecases/catalog_food_to_candidate.dart';

Future<String> sqlite(String path, String sql) async {
  final result = await Process.run('/usr/bin/sqlite3', ['-json', path, sql]);
  if (result.exitCode != 0) throw StateError('${result.stderr}');
  return result.stdout.toString().trim();
}

String literal(Object? value) =>
    value is num ? '$value' : "'${value.toString().replaceAll("'", "''")}'";

void main() {
  test(
    'new unknown meal item survives JSON, real SQLite and catalogue removal',
    () async {
      final dir = await Directory.systemTemp.createTemp('meal_missingness_');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/meals.sqlite';
      await sqlite(path, nativeMealItemsCreateTableSql);
      final item = MealItem.fromFood(
        food: syntheticMealJourneyFoods().last,
        quantityFactor: 1.6,
      );
      final jsonRoundtrip = MealItem.fromJson(item.toJson());
      expect(jsonRoundtrip.missingNutrientFields, contains('proteinG'));
      final row = nativeMealItemToSqliteRow(
        jsonRoundtrip,
        mealId: 'new',
        ordinal: 0,
      );
      await sqlite(
        path,
        'INSERT INTO meal_items (${row.keys.join(',')}) VALUES (${row.values.map(literal).join(',')})',
      );
      final restored = nativeMealItemFromSqliteRow(
        Map<String, Object?>.from(
          (jsonDecode(await sqlite(path, 'SELECT * FROM meal_items')) as List)
                  .single
              as Map,
        ),
      );
      expect(restored.toJson(), item.toJson());
      // No catalogue match remains available after this persistence round-trip.
      final component = mealItemToFoodComponent(
        restored,
        componentId: 'reopened',
      );
      expect(component.proteinGrams, isNull);
      expect(component.carbohydrateGrams, isNull);
      expect(component.fatGrams, isNull);
      expect(component.fiberGrams, isNull);
    },
  );

  test(
    'v11 migration keeps legacy content and gives only an empty marker',
    () async {
      final dir = await Directory.systemTemp.createTemp('meal_migration_');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/meals.sqlite';
      final legacySql = nativeMealItemsCreateTableSql.replaceAll(
        ", missing_nutrients TEXT NOT NULL DEFAULT '[]'",
        '',
      );
      await sqlite(path, legacySql);
      await sqlite(
        path,
        "INSERT INTO meal_items VALUES ('legacy', 'old', 'food', 'legacy food', 'other', 1, 0, 20, 0, 0, 0, '[]')",
      );
      final before = Map<String, Object?>.from(
        (jsonDecode(await sqlite(path, 'SELECT * FROM meal_items')) as List)
                .single
            as Map,
      );
      await sqlite(path, nativeMealItemSchemaV12MigrationStatement);
      final after = Map<String, Object?>.from(
        (jsonDecode(await sqlite(path, 'SELECT * FROM meal_items')) as List)
                .single
            as Map,
      );
      expect(after['missing_nutrients'], '[]');
      after.remove('missing_nutrients');
      expect(after, before);
      expect(
        nativeMealItemFromSqliteRow(
          after,
        ).toJson().containsKey('missingNutrientFields'),
        isFalse,
      );
    },
  );
}
