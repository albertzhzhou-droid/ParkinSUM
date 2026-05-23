import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/drug_definition.dart';
import '../models/food_item.dart';
import '../models/intake.dart';
import '../models/meal.dart';
import '../models/user_profile.dart';
import '../../data/models/interaction_rule_record.dart';
import 'app_database.dart';

class NativeAppDatabase implements AppDatabase {
  Database? _database;

  Future<Database> _open() async {
    if (_database != null) return _database!;

    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, 'parkinsum_companion.db');

    _database = await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE app_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE meals (id TEXT PRIMARY KEY, title TEXT NOT NULL, eaten_at INTEGER NOT NULL, recorded_at INTEGER, occurred_at INTEGER, occurred_range_start INTEGER, occurred_range_end INTEGER, time_source TEXT, time_precision TEXT, next_meal_window_start INTEGER, next_meal_window_end INTEGER, coevent_time INTEGER, coevent_substance_tags TEXT NOT NULL DEFAULT \'[]\', thickener_type TEXT, enteral_feed_mode TEXT, enteral_feed_formula TEXT, enteral_feed_protein_g_per_day REAL)',
        );
        await db.execute(
          'CREATE TABLE meal_items (id TEXT PRIMARY KEY, meal_id TEXT NOT NULL, food_id TEXT NOT NULL, food_name TEXT NOT NULL, category TEXT NOT NULL, quantity REAL NOT NULL, protein REAL NOT NULL, carbs REAL NOT NULL, fat REAL NOT NULL, fiber REAL NOT NULL, sodium REAL NOT NULL, tags TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE intakes (id TEXT PRIMARY KEY, drug_id TEXT NOT NULL, taken_at INTEGER NOT NULL, dosage_note TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE foods (id TEXT PRIMARY KEY, name TEXT NOT NULL, protein REAL NOT NULL, carbs REAL NOT NULL, fat REAL NOT NULL, fiber REAL NOT NULL, sodium REAL NOT NULL, category TEXT NOT NULL, aliases TEXT NOT NULL, description TEXT NOT NULL, source_system TEXT NOT NULL, source_food_code TEXT, jurisdiction TEXT NOT NULL, texture_class TEXT, iddsi_level INTEGER)',
        );
        await db.execute(
          'CREATE TABLE medications (id TEXT PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL, notes TEXT NOT NULL, tags TEXT NOT NULL, aliases TEXT NOT NULL, interaction_summary TEXT NOT NULL, source_system TEXT NOT NULL, source_product_code TEXT, jurisdiction TEXT NOT NULL, route TEXT NOT NULL, dosage_form TEXT NOT NULL, release_type TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE interaction_rules (id TEXT PRIMARY KEY, drug_id TEXT NOT NULL, rule_type TEXT NOT NULL, target TEXT NOT NULL, severity INTEGER NOT NULL, weight REAL NOT NULL, description TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE active_drugs (id TEXT PRIMARY KEY)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // meals: 新增“记录时间 / 实际发生时间 / 可选区间 / 下一餐时间窗”字段。
          await db.execute('ALTER TABLE meals ADD COLUMN recorded_at INTEGER');
          await db.execute('ALTER TABLE meals ADD COLUMN occurred_at INTEGER');
          await db.execute(
              'ALTER TABLE meals ADD COLUMN occurred_range_start INTEGER');
          await db.execute(
              'ALTER TABLE meals ADD COLUMN occurred_range_end INTEGER');
          await db.execute('ALTER TABLE meals ADD COLUMN time_source TEXT');
          await db.execute('ALTER TABLE meals ADD COLUMN time_precision TEXT');
          await db.execute(
              'ALTER TABLE meals ADD COLUMN next_meal_window_start INTEGER');
          await db.execute(
              'ALTER TABLE meals ADD COLUMN next_meal_window_end INTEGER');
          await db.execute(
            "UPDATE meals SET recorded_at = eaten_at, occurred_at = eaten_at, time_source = 'migration_legacy', time_precision = 'exact' WHERE recorded_at IS NULL",
          );

          // foods: 为目录搜索和展示增加来源、别名、描述。
          await db.execute(
              "ALTER TABLE foods ADD COLUMN aliases TEXT NOT NULL DEFAULT '[]'");
          await db.execute(
              "ALTER TABLE foods ADD COLUMN description TEXT NOT NULL DEFAULT ''");
          await db.execute(
              "ALTER TABLE foods ADD COLUMN source_system TEXT NOT NULL DEFAULT 'LOCAL_SEED'");
          await db
              .execute('ALTER TABLE foods ADD COLUMN source_food_code TEXT');
          await db.execute(
              "ALTER TABLE foods ADD COLUMN jurisdiction TEXT NOT NULL DEFAULT 'GLOBAL'");

          // medications: 增加更丰富的标签摘要与来源信息。
          await db.execute(
              "ALTER TABLE medications ADD COLUMN aliases TEXT NOT NULL DEFAULT '[]'");
          await db.execute(
              "ALTER TABLE medications ADD COLUMN interaction_summary TEXT NOT NULL DEFAULT ''");
          await db.execute(
              "ALTER TABLE medications ADD COLUMN source_system TEXT NOT NULL DEFAULT 'LOCAL_SEED'");
          await db.execute(
              'ALTER TABLE medications ADD COLUMN source_product_code TEXT');
          await db.execute(
              "ALTER TABLE medications ADD COLUMN jurisdiction TEXT NOT NULL DEFAULT 'GLOBAL'");
          await db.execute(
              "ALTER TABLE medications ADD COLUMN route TEXT NOT NULL DEFAULT 'oral'");
          await db.execute(
              "ALTER TABLE medications ADD COLUMN dosage_form TEXT NOT NULL DEFAULT 'unspecified'");
          await db.execute(
              "ALTER TABLE medications ADD COLUMN release_type TEXT NOT NULL DEFAULT 'unspecified'");
        }
        if (oldVersion < 3) {
          // meals: 新增高风险共事件/肠内营养上下文，供数据库驱动冲突引擎直接消费。
          await db.execute('ALTER TABLE meals ADD COLUMN coevent_time INTEGER');
          await db.execute(
              "ALTER TABLE meals ADD COLUMN coevent_substance_tags TEXT NOT NULL DEFAULT '[]'");
          await db.execute('ALTER TABLE meals ADD COLUMN thickener_type TEXT');
          await db
              .execute('ALTER TABLE meals ADD COLUMN enteral_feed_mode TEXT');
          await db.execute(
              'ALTER TABLE meals ADD COLUMN enteral_feed_formula TEXT');
          await db.execute(
              'ALTER TABLE meals ADD COLUMN enteral_feed_protein_g_per_day REAL');
        }
        if (oldVersion < 4) {
          // foods: 新增结构化质地/IDDSI 字段，支撑吞咽上下文下的保守推荐。
          await db.execute('ALTER TABLE foods ADD COLUMN texture_class TEXT');
          await db.execute('ALTER TABLE foods ADD COLUMN iddsi_level INTEGER');
        }
      },
    );

    return _database!;
  }

  @override
  Future<void> initialize({
    required List<FoodItem> seedFoods,
    required List<DrugDefinition> seedMedications,
    required List<InteractionRuleRecord> seedRules,
  }) async {
    final db = await _open();

    final foodBatch = db.batch();
    for (final food in seedFoods) {
      foodBatch.insert(
        'foods',
        {
          'id': food.id,
          'name': food.name,
          'protein': food.proteinG,
          'carbs': food.carbsG,
          'fat': food.fatG,
          'fiber': food.fiberG,
          'sodium': food.sodiumMg,
          'category': food.category.name,
          'aliases': jsonEncode(food.aliases),
          'description': food.description,
          'source_system': food.sourceSystem,
          'source_food_code': food.sourceFoodCode,
          'jurisdiction': food.jurisdiction,
          'texture_class': food.textureClass,
          'iddsi_level': food.iddsiLevel,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await foodBatch.commit(noResult: true);

    final medicationBatch = db.batch();
    for (final medication in seedMedications) {
      medicationBatch.insert(
        'medications',
        {
          'id': medication.id,
          'name': medication.displayName,
          'type': medication.genericName,
          'notes': medication.notes,
          'tags': jsonEncode(medication.tags.map((tag) => tag.name).toList()),
          'aliases': jsonEncode(medication.aliases),
          'interaction_summary': medication.interactionSummary,
          'source_system': medication.sourceSystem,
          'source_product_code': medication.sourceProductCode,
          'jurisdiction': medication.jurisdiction,
          'route': medication.route,
          'dosage_form': medication.dosageForm,
          'release_type': medication.releaseType,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await medicationBatch.commit(noResult: true);

    final ruleBatch = db.batch();
    for (final rule in seedRules) {
      ruleBatch.insert(
        'interaction_rules',
        {
          'id': rule.id,
          'drug_id': rule.drugId,
          'rule_type': rule.ruleType,
          'target': rule.target,
          'severity': rule.severity,
          'weight': rule.weight,
          'description': rule.description,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await ruleBatch.commit(noResult: true);
  }

  @override
  Future<bool> loadOnboarded() async {
    final db = await _open();
    final rows = await db.query('app_meta',
        where: 'key = ?', whereArgs: ['onboarded'], limit: 1);
    if (rows.isEmpty) return false;
    return rows.first['value'] == 'true';
  }

  @override
  Future<void> saveOnboarded(bool value) async {
    final db = await _open();
    await db.insert(
      'app_meta',
      {'key': 'onboarded', 'value': value ? 'true' : 'false'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<UserProfile> loadUserProfile() async {
    final db = await _open();
    final rows = await db.query(
      'app_meta',
      where: 'key = ?',
      whereArgs: ['user_profile'],
      limit: 1,
    );
    if (rows.isEmpty) {
      return UserProfile.defaults();
    }
    return UserProfile.fromJson(
      jsonDecode(rows.first['value'] as String) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    final db = await _open();
    await db.insert(
      'app_meta',
      {'key': 'user_profile', 'value': jsonEncode(profile.toJson())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<String>> loadActiveDrugIds() async {
    final db = await _open();
    final rows = await db.query('active_drugs');
    return rows.map((row) => row['id'].toString()).toList(growable: false);
  }

  @override
  Future<void> saveActiveDrugIds(List<String> ids) async {
    final db = await _open();
    final batch = db.batch()..delete('active_drugs');
    for (final id in ids) {
      batch.insert('active_drugs', {'id': id});
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<Meal>> loadMeals() async {
    final db = await _open();
    final mealRows = await db.query('meals', orderBy: 'eaten_at DESC');
    final itemRows = await db.query('meal_items');

    return mealRows.map((row) {
      final mealId = row['id'] as String;
      final items = itemRows
          .where((item) => item['meal_id'] == mealId)
          .map(_mealItemFromRow)
          .toList();
      return Meal(
        id: mealId,
        eatenAt: DateTime.fromMillisecondsSinceEpoch(row['eaten_at'] as int),
        recordedAt: row['recorded_at'] == null
            ? DateTime.fromMillisecondsSinceEpoch(row['eaten_at'] as int)
            : DateTime.fromMillisecondsSinceEpoch(row['recorded_at'] as int),
        occurredAt: row['occurred_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row['occurred_at'] as int),
        occurredRangeStart: row['occurred_range_start'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                row['occurred_range_start'] as int),
        occurredRangeEnd: row['occurred_range_end'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                row['occurred_range_end'] as int),
        timeSource: (row['time_source'] as String?) ?? 'migration_legacy',
        timePrecision: (row['time_precision'] as String?) ?? 'exact',
        nextMealWindowStart: row['next_meal_window_start'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                row['next_meal_window_start'] as int),
        nextMealWindowEnd: row['next_meal_window_end'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                row['next_meal_window_end'] as int),
        coeventTime: row['coevent_time'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row['coevent_time'] as int),
        coeventSubstanceTags:
            (jsonDecode((row['coevent_substance_tags'] as String?) ?? '[]')
                    as List<dynamic>)
                .map((value) => value.toString())
                .toList(growable: false),
        thickenerType: row['thickener_type'] as String?,
        enteralFeedMode: row['enteral_feed_mode'] as String?,
        enteralFeedFormula: row['enteral_feed_formula'] as String?,
        enteralFeedProteinGPerDay:
            (row['enteral_feed_protein_g_per_day'] as num?)?.toDouble(),
        title: row['title'] as String,
        items: items,
      );
    }).toList(growable: false);
  }

  @override
  Future<void> saveMeals(List<Meal> meals) async {
    final db = await _open();
    final batch = db.batch()
      ..delete('meal_items')
      ..delete('meals');

    for (final meal in meals) {
      batch.insert('meals', {
        'id': meal.id,
        'title': meal.title,
        'eaten_at': meal.eatenAt.millisecondsSinceEpoch,
        'recorded_at': meal.recordedAt.millisecondsSinceEpoch,
        'occurred_at': meal.occurredAt?.millisecondsSinceEpoch,
        'occurred_range_start': meal.occurredRangeStart?.millisecondsSinceEpoch,
        'occurred_range_end': meal.occurredRangeEnd?.millisecondsSinceEpoch,
        'time_source': meal.timeSource,
        'time_precision': meal.timePrecision,
        'next_meal_window_start':
            meal.nextMealWindowStart?.millisecondsSinceEpoch,
        'next_meal_window_end': meal.nextMealWindowEnd?.millisecondsSinceEpoch,
        'coevent_time': meal.coeventTime?.millisecondsSinceEpoch,
        'coevent_substance_tags': jsonEncode(meal.coeventSubstanceTags),
        'thickener_type': meal.thickenerType,
        'enteral_feed_mode': meal.enteralFeedMode,
        'enteral_feed_formula': meal.enteralFeedFormula,
        'enteral_feed_protein_g_per_day': meal.enteralFeedProteinGPerDay,
      });

      for (final item in meal.items) {
        batch.insert('meal_items', {
          'id': '${meal.id}_${item.foodId}',
          'meal_id': meal.id,
          'food_id': item.foodId,
          'food_name': item.foodName,
          'category': item.foodCategory.name,
          'quantity': item.quantityFactor,
          'protein': item.proteinPer100g,
          'carbs': item.carbsPer100g,
          'fat': item.fatPer100g,
          'fiber': item.fiberPer100g,
          'sodium': item.sodiumPer100g,
          'tags': jsonEncode(item.foodTags),
        });
      }
    }

    await batch.commit(noResult: true);
  }

  @override
  Future<List<Intake>> loadIntakes() async {
    final db = await _open();
    final rows = await db.query('intakes', orderBy: 'taken_at DESC');
    return rows
        .map(
          (row) => Intake(
            id: row['id'] as String,
            drugId: row['drug_id'] as String,
            takenAt:
                DateTime.fromMillisecondsSinceEpoch(row['taken_at'] as int),
            dosageNote: row['dosage_note'] as String,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> saveIntakes(List<Intake> intakes) async {
    final db = await _open();
    final batch = db.batch()..delete('intakes');
    for (final intake in intakes) {
      batch.insert('intakes', {
        'id': intake.id,
        'drug_id': intake.drugId,
        'taken_at': intake.takenAt.millisecondsSinceEpoch,
        'dosage_note': intake.dosageNote,
      });
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<FoodItem>> loadFoods() async {
    final db = await _open();
    final rows = await db.query('foods', orderBy: 'name ASC');
    return rows.map(_foodFromRow).toList(growable: false);
  }

  @override
  Future<List<DrugDefinition>> loadMedications() async {
    final db = await _open();
    final rows = await db.query('medications', orderBy: 'name ASC');
    return rows.map(_medicationFromRow).toList(growable: false);
  }

  @override
  Future<List<InteractionRuleRecord>> loadInteractionRules() async {
    final db = await _open();
    final rows = await db.query('interaction_rules');
    return rows
        .map((row) => InteractionRuleRecord(
              id: row['id'] as String,
              drugId: row['drug_id'] as String,
              ruleType: row['rule_type'] as String,
              target: row['target'] as String,
              severity: row['severity'] as int,
              weight: (row['weight'] as num).toDouble(),
              description: row['description'] as String,
            ))
        .toList(growable: false);
  }

  MealItem _mealItemFromRow(Map<String, Object?> row) {
    final categoryName = row['category'] as String;
    final category = FoodCategory.values.firstWhere(
      (value) => value.name == categoryName,
      orElse: () => FoodCategory.other,
    );

    return MealItem(
      foodId: row['food_id'] as String,
      foodName: row['food_name'] as String,
      foodCategory: category,
      quantityFactor: (row['quantity'] as num).toDouble(),
      foodTags: (jsonDecode(row['tags'] as String) as List<dynamic>)
          .map((value) => value.toString())
          .toList(),
      proteinPer100g: (row['protein'] as num).toDouble(),
      carbsPer100g: (row['carbs'] as num).toDouble(),
      fatPer100g: (row['fat'] as num).toDouble(),
      fiberPer100g: (row['fiber'] as num).toDouble(),
      sodiumPer100g: (row['sodium'] as num).toDouble(),
    );
  }

  FoodItem _foodFromRow(Map<String, Object?> row) {
    final category = FoodCategory.values.firstWhere(
      (value) => value.name == row['category'],
      orElse: () => FoodCategory.other,
    );
    return FoodItem(
      id: row['id'] as String,
      name: row['name'] as String,
      category: category,
      aliases:
          (jsonDecode((row['aliases'] as String?) ?? '[]') as List<dynamic>)
              .map((value) => value.toString())
              .toList(growable: false),
      description: (row['description'] as String?) ?? '',
      sourceSystem: (row['source_system'] as String?) ?? 'LOCAL_SEED',
      sourceFoodCode: row['source_food_code'] as String?,
      jurisdiction: (row['jurisdiction'] as String?) ?? 'GLOBAL',
      textureClass: row['texture_class'] as String?,
      iddsiLevel: (row['iddsi_level'] as num?)?.toInt(),
      proteinG: (row['protein'] as num).toDouble(),
      carbsG: (row['carbs'] as num).toDouble(),
      fatG: (row['fat'] as num).toDouble(),
      fiberG: (row['fiber'] as num).toDouble(),
      sodiumMg: (row['sodium'] as num).toDouble(),
    );
  }

  DrugDefinition _medicationFromRow(Map<String, Object?> row) {
    final tagNames = (jsonDecode(row['tags'] as String) as List<dynamic>)
        .map((value) => value.toString())
        .toList(growable: false);
    return DrugDefinition(
      id: row['id'] as String,
      genericName: row['type'] as String,
      brandNames: [row['name'] as String],
      aliases:
          (jsonDecode((row['aliases'] as String?) ?? '[]') as List<dynamic>)
              .map((value) => value.toString())
              .toList(growable: false),
      tags: tagNames
          .map(
            (name) => DrugTag.values.firstWhere(
              (value) => value.name == name,
              orElse: () => DrugTag.levodopaLike,
            ),
          )
          .toList(growable: false),
      notes: row['notes'] as String,
      interactionSummary: (row['interaction_summary'] as String?) ?? '',
      sourceSystem: (row['source_system'] as String?) ?? 'LOCAL_SEED',
      sourceProductCode: row['source_product_code'] as String?,
      jurisdiction: (row['jurisdiction'] as String?) ?? 'GLOBAL',
      route: (row['route'] as String?) ?? 'oral',
      dosageForm: (row['dosage_form'] as String?) ?? 'unspecified',
      releaseType: (row['release_type'] as String?) ?? 'unspecified',
    );
  }
}

AppDatabase createAppDatabaseImpl() => NativeAppDatabase();
