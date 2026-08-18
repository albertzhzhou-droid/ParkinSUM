import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/atomic_onboarding_commit.dart';
import '../models/drug_definition.dart';
import '../models/food_item.dart';
import '../models/intake.dart';
import '../models/medication_product_pack.dart';
import '../models/meal.dart';
import '../models/recoverable_user_event.dart';
import '../models/user_profile.dart';
import '../../data/models/interaction_rule_record.dart';
import 'app_database.dart';
import 'recoverable_user_event_store.dart';

const int nativeAppDatabaseSchemaVersion = 8;
const String _nativeOnboardingOperationKey = 'onboarding_operation_id_v1';
const String _nativeOnboardingStageKey = 'onboarding_stage_v1';

const String nativeIntakesCreateTableSql = '''
CREATE TABLE intakes (
  id TEXT PRIMARY KEY,
  drug_id TEXT NOT NULL,
  taken_at INTEGER NOT NULL,
  dosage_note TEXT NOT NULL,
  dose_amount REAL,
  dose_unit TEXT,
  dosage_form TEXT,
  route TEXT,
  release_type TEXT,
  product_selection_json TEXT
)
''';

const List<String> nativeIntakeSchemaV6MigrationStatements = <String>[
  'ALTER TABLE intakes ADD COLUMN dose_amount REAL',
  'ALTER TABLE intakes ADD COLUMN dose_unit TEXT',
  'ALTER TABLE intakes ADD COLUMN dosage_form TEXT',
  'ALTER TABLE intakes ADD COLUMN route TEXT',
  'ALTER TABLE intakes ADD COLUMN release_type TEXT',
];

const List<String> nativeIntakeSchemaV7MigrationStatements = <String>[
  'ALTER TABLE intakes ADD COLUMN product_selection_json TEXT',
];

const String nativeRecoverableEventHistoryCreateTableSql = '''
CREATE TABLE recoverable_event_history (
  history_id TEXT PRIMARY KEY,
  operation_id TEXT NOT NULL UNIQUE,
  event_type TEXT NOT NULL,
  record_id TEXT NOT NULL,
  recorded_at INTEGER NOT NULL,
  revision_json TEXT NOT NULL
)
''';

Map<String, Object?> nativeIntakeToSqliteRow(Intake intake) {
  return <String, Object?>{
    'id': intake.id,
    'drug_id': intake.drugId,
    'taken_at': intake.takenAt.millisecondsSinceEpoch,
    'dosage_note': intake.dosageNote,
    'dose_amount': intake.doseAmount,
    'dose_unit': intake.doseUnit,
    'dosage_form': intake.dosageForm,
    'route': intake.route,
    'release_type': intake.releaseType,
    'product_selection_json': intake.productSelection == null
        ? null
        : jsonEncode(intake.productSelection!.toJson()),
  };
}

Intake nativeIntakeFromSqliteRow(Map<String, Object?> row) {
  return Intake(
    id: row['id'] as String,
    drugId: row['drug_id'] as String,
    takenAt: DateTime.fromMillisecondsSinceEpoch(row['taken_at'] as int),
    dosageNote: (row['dosage_note'] as String?) ?? '',
    doseAmount: (row['dose_amount'] as num?)?.toDouble(),
    doseUnit: row['dose_unit'] as String?,
    dosageForm: row['dosage_form'] as String?,
    route: row['route'] as String?,
    releaseType: row['release_type'] as String?,
    productSelection: row['product_selection_json'] == null
        ? null
        : MedicationProductSelection.fromJson(
            jsonDecode(row['product_selection_json'] as String),
          ),
  );
}

/// The production schema for the Native `foods` table.
///
/// Kept as a shared constant so migration/round-trip tests exercise the exact
/// SQL used by [NativeAppDatabase], rather than a test-only approximation.
const String nativeFoodsCreateTableSql = '''
CREATE TABLE foods (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  protein REAL NOT NULL,
  carbs REAL NOT NULL,
  fat REAL NOT NULL,
  fiber REAL NOT NULL,
  sodium REAL NOT NULL,
  category TEXT NOT NULL,
  aliases TEXT NOT NULL,
  description TEXT NOT NULL,
  source_system TEXT NOT NULL,
  source_food_code TEXT,
  jurisdiction TEXT NOT NULL,
  texture_class TEXT,
  iddsi_level INTEGER,
  missing_nutrient_fields TEXT NOT NULL DEFAULT '[]',
  energy_kcal REAL,
  water_g REAL,
  amino_acid_profile_json TEXT,
  basis_type TEXT,
  preparation_state TEXT,
  qualifier_kind TEXT
)
''';

/// Version-5 migration shared by production and the real-SQLite migration test.
///
/// Pre-v5 rows never stored energy/water or a missingness bitmap. Their zero
/// nutrient values are therefore ambiguous: they may be real zeros or values
/// that an older importer coerced from absent data. The safe default is to mark
/// those zeros as unknown while retaining the numeric compatibility value.
const List<String> nativeFoodSchemaV5MigrationStatements = <String>[
  "ALTER TABLE foods ADD COLUMN missing_nutrient_fields TEXT NOT NULL DEFAULT '[]'",
  'ALTER TABLE foods ADD COLUMN energy_kcal REAL',
  'ALTER TABLE foods ADD COLUMN water_g REAL',
  'ALTER TABLE foods ADD COLUMN amino_acid_profile_json TEXT',
  'ALTER TABLE foods ADD COLUMN basis_type TEXT',
  'ALTER TABLE foods ADD COLUMN preparation_state TEXT',
  'ALTER TABLE foods ADD COLUMN qualifier_kind TEXT',
  '''
UPDATE foods
SET missing_nutrient_fields =
  '[' ||
  CASE WHEN protein = 0 THEN '"proteinG",' ELSE '' END ||
  CASE WHEN carbs = 0 THEN '"carbsG",' ELSE '' END ||
  CASE WHEN fat = 0 THEN '"fatG",' ELSE '' END ||
  CASE WHEN fiber = 0 THEN '"fiberG",' ELSE '' END ||
  CASE WHEN sodium = 0 THEN '"sodiumMg",' ELSE '' END ||
  '"energyKcal","waterG"]'
''',
];

/// Complete SQLite projection for a [FoodItem].
Map<String, Object?> nativeFoodToSqliteRow(FoodItem food) {
  final missingNutrientFields = <String>{...food.missingNutrientFields};
  if (food.energyKcal == null) missingNutrientFields.add('energyKcal');
  if (food.waterG == null) missingNutrientFields.add('waterG');
  final sortedMissingNutrientFields = missingNutrientFields.toList()..sort();
  return <String, Object?>{
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
    'missing_nutrient_fields': jsonEncode(sortedMissingNutrientFields),
    'energy_kcal': food.energyKcal,
    'water_g': food.waterG,
    'amino_acid_profile_json': food.aminoAcidProfile == null
        ? null
        : jsonEncode(food.aminoAcidProfile!.toJson()),
    'basis_type': food.basisType,
    'preparation_state': food.preparationState,
    'qualifier_kind': food.qualifierKind,
  };
}

List<String> _decodeStringList(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) return const <String>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List<dynamic>) {
      return decoded.map((value) => value.toString()).toList(growable: false);
    }
  } on FormatException {
    // A malformed local value is treated as absent, never fabricated.
  }
  return const <String>[];
}

Set<String> _legacyMissingNutrientFields(Map<String, Object?> row) {
  final missing = <String>{'energyKcal', 'waterG'};
  const nutrientColumns = <String, String>{
    'protein': 'proteinG',
    'carbs': 'carbsG',
    'fat': 'fatG',
    'fiber': 'fiberG',
    'sodium': 'sodiumMg',
  };
  for (final entry in nutrientColumns.entries) {
    final value = row[entry.key];
    if (value == null || (value is num && value == 0)) {
      missing.add(entry.value);
    }
  }
  return missing;
}

Set<String> _missingNutrientFieldsFromRow(Map<String, Object?> row) {
  if (row.containsKey('missing_nutrient_fields')) {
    final missing = <String>{};
    final raw = row['missing_nutrient_fields'];
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List<dynamic>) {
          missing.addAll(decoded.map((value) => value.toString()));
        }
      } on FormatException {
        // Keep the explicit v5 bitmap empty; do not infer zero-valued macros.
      }
    }
    if (row['energy_kcal'] == null) missing.add('energyKcal');
    if (row['water_g'] == null) missing.add('waterG');
    return missing;
  }
  return _legacyMissingNutrientFields(row);
}

Map<String, dynamic>? _decodeOptionalJsonMap(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map<dynamic, dynamic>) {
      return Map<String, dynamic>.from(decoded);
    }
  } on FormatException {
    // A corrupt optional profile is absent rather than a fabricated profile.
  }
  return null;
}

/// Restores every persisted [FoodItem] field from a SQLite row.
FoodItem nativeFoodFromSqliteRow(Map<String, Object?> row) {
  return FoodItem.fromJson(<String, dynamic>{
    'id': row['id'] as String,
    'name': row['name'] as String,
    'category': row['category'] as String,
    'aliases': _decodeStringList(row['aliases']),
    'description': (row['description'] as String?) ?? '',
    'sourceSystem': (row['source_system'] as String?) ?? 'LOCAL_SEED',
    'sourceFoodCode': row['source_food_code'] as String?,
    'jurisdiction': (row['jurisdiction'] as String?) ?? 'GLOBAL',
    'textureClass': row['texture_class'] as String?,
    'iddsiLevel': (row['iddsi_level'] as num?)?.toInt(),
    'proteinG': (row['protein'] as num).toDouble(),
    'carbsG': (row['carbs'] as num).toDouble(),
    'fatG': (row['fat'] as num).toDouble(),
    'fiberG': (row['fiber'] as num).toDouble(),
    'sodiumMg': (row['sodium'] as num).toDouble(),
    'missingNutrientFields': _missingNutrientFieldsFromRow(row).toList(),
    'energyKcal': (row['energy_kcal'] as num?)?.toDouble(),
    'waterG': (row['water_g'] as num?)?.toDouble(),
    'aminoAcidProfile': _decodeOptionalJsonMap(row['amino_acid_profile_json']),
    'basisType': row['basis_type'] as String?,
    'preparationState': row['preparation_state'] as String?,
    'qualifierKind': row['qualifier_kind'] as String?,
  });
}

/// Stable, unambiguous primary key for a meal row item.
///
/// A meal may contain the same food more than once, so `mealId + foodId` is
/// not unique. The list ordinal distinguishes those rows; JSON encoding keeps
/// component boundaries unambiguous even when ids themselves contain `_` or
/// other separators.
String nativeMealItemStorageId({
  required String mealId,
  required String foodId,
  required int ordinal,
}) {
  RangeError.checkNotNegative(ordinal, 'ordinal');
  return jsonEncode(<Object>[mealId, ordinal, foodId]);
}

int? _nativeMealItemOrdinal(Map<String, Object?> row) {
  try {
    final decoded = jsonDecode(row['id'] as String);
    if (decoded is! List || decoded.length != 3 || decoded[1] is! num) {
      return null;
    }
    final ordinal = (decoded[1] as num).toInt();
    return ordinal >= 0 ? ordinal : null;
  } on Object {
    // Rows from schema versions before the JSON tuple primary key used a
    // delimiter-based id. Preserve their database order instead of making an
    // old row unreadable during the v8 migration.
    return null;
  }
}

MealItem _nativeMealItemFromRow(Map<String, Object?> row) {
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
        .toList(growable: false),
    proteinPer100g: (row['protein'] as num).toDouble(),
    carbsPer100g: (row['carbs'] as num).toDouble(),
    fatPer100g: (row['fat'] as num).toDouble(),
    fiberPer100g: (row['fiber'] as num).toDouble(),
    sodiumPer100g: (row['sodium'] as num).toDouble(),
  );
}

Meal _nativeMealFromRows(
  Map<String, Object?> row,
  List<Map<String, Object?>> itemRows,
) {
  final mealId = row['id'] as String;
  final matchingItems = itemRows
      .where((item) => item['meal_id'] == mealId)
      .toList(growable: false);
  if (matchingItems.every((item) => _nativeMealItemOrdinal(item) != null)) {
    matchingItems.sort(
      (left, right) => _nativeMealItemOrdinal(
        left,
      )!.compareTo(_nativeMealItemOrdinal(right)!),
    );
  }
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
            row['occurred_range_start'] as int,
          ),
    occurredRangeEnd: row['occurred_range_end'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row['occurred_range_end'] as int),
    timeSource: (row['time_source'] as String?) ?? 'migration_legacy',
    timePrecision: (row['time_precision'] as String?) ?? 'exact',
    nextMealWindowStart: row['next_meal_window_start'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            row['next_meal_window_start'] as int,
          ),
    nextMealWindowEnd: row['next_meal_window_end'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            row['next_meal_window_end'] as int,
          ),
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
    enteralFeedProteinGPerDay: (row['enteral_feed_protein_g_per_day'] as num?)
        ?.toDouble(),
    title: row['title'] as String,
    items: matchingItems.map(_nativeMealItemFromRow).toList(growable: false),
  );
}

Future<void> _insertNativeMeal(DatabaseExecutor database, Meal meal) async {
  await database.insert('meals', <String, Object?>{
    'id': meal.id,
    'title': meal.title,
    'eaten_at': meal.eatenAt.millisecondsSinceEpoch,
    'recorded_at': meal.recordedAt.millisecondsSinceEpoch,
    'occurred_at': meal.occurredAt?.millisecondsSinceEpoch,
    'occurred_range_start': meal.occurredRangeStart?.millisecondsSinceEpoch,
    'occurred_range_end': meal.occurredRangeEnd?.millisecondsSinceEpoch,
    'time_source': meal.timeSource,
    'time_precision': meal.timePrecision,
    'next_meal_window_start': meal.nextMealWindowStart?.millisecondsSinceEpoch,
    'next_meal_window_end': meal.nextMealWindowEnd?.millisecondsSinceEpoch,
    'coevent_time': meal.coeventTime?.millisecondsSinceEpoch,
    'coevent_substance_tags': jsonEncode(meal.coeventSubstanceTags),
    'thickener_type': meal.thickenerType,
    'enteral_feed_mode': meal.enteralFeedMode,
    'enteral_feed_formula': meal.enteralFeedFormula,
    'enteral_feed_protein_g_per_day': meal.enteralFeedProteinGPerDay,
  });
  for (var ordinal = 0; ordinal < meal.items.length; ordinal++) {
    final item = meal.items[ordinal];
    await database.insert('meal_items', <String, Object?>{
      'id': nativeMealItemStorageId(
        mealId: meal.id,
        foodId: item.foodId,
        ordinal: ordinal,
      ),
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

class NativeAppDatabase implements AppDatabase, RecoverableUserEventStore {
  Database? _database;

  Future<Database> _open() async {
    if (_database != null) return _database!;

    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, 'parkinsum_companion.db');

    _database = await openDatabase(
      path,
      version: nativeAppDatabaseSchemaVersion,
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
        await db.execute(nativeIntakesCreateTableSql);
        await db.execute(nativeFoodsCreateTableSql);
        await db.execute(
          'CREATE TABLE medications (id TEXT PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL, notes TEXT NOT NULL, tags TEXT NOT NULL, aliases TEXT NOT NULL, interaction_summary TEXT NOT NULL, source_system TEXT NOT NULL, source_product_code TEXT, jurisdiction TEXT NOT NULL, route TEXT NOT NULL, dosage_form TEXT NOT NULL, release_type TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE interaction_rules (id TEXT PRIMARY KEY, drug_id TEXT NOT NULL, rule_type TEXT NOT NULL, target TEXT NOT NULL, severity INTEGER NOT NULL, weight REAL NOT NULL, description TEXT NOT NULL)',
        );
        await db.execute('CREATE TABLE active_drugs (id TEXT PRIMARY KEY)');
        await db.execute(nativeRecoverableEventHistoryCreateTableSql);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // meals: 新增“记录时间 / 实际发生时间 / 可选区间 / 下一餐时间窗”字段。
          await db.execute('ALTER TABLE meals ADD COLUMN recorded_at INTEGER');
          await db.execute('ALTER TABLE meals ADD COLUMN occurred_at INTEGER');
          await db.execute(
            'ALTER TABLE meals ADD COLUMN occurred_range_start INTEGER',
          );
          await db.execute(
            'ALTER TABLE meals ADD COLUMN occurred_range_end INTEGER',
          );
          await db.execute('ALTER TABLE meals ADD COLUMN time_source TEXT');
          await db.execute('ALTER TABLE meals ADD COLUMN time_precision TEXT');
          await db.execute(
            'ALTER TABLE meals ADD COLUMN next_meal_window_start INTEGER',
          );
          await db.execute(
            'ALTER TABLE meals ADD COLUMN next_meal_window_end INTEGER',
          );
          await db.execute(
            "UPDATE meals SET recorded_at = eaten_at, occurred_at = eaten_at, time_source = 'migration_legacy', time_precision = 'exact' WHERE recorded_at IS NULL",
          );

          // foods: 为目录搜索和展示增加来源、别名、描述。
          await db.execute(
            "ALTER TABLE foods ADD COLUMN aliases TEXT NOT NULL DEFAULT '[]'",
          );
          await db.execute(
            "ALTER TABLE foods ADD COLUMN description TEXT NOT NULL DEFAULT ''",
          );
          await db.execute(
            "ALTER TABLE foods ADD COLUMN source_system TEXT NOT NULL DEFAULT 'LOCAL_SEED'",
          );
          await db.execute(
            'ALTER TABLE foods ADD COLUMN source_food_code TEXT',
          );
          await db.execute(
            "ALTER TABLE foods ADD COLUMN jurisdiction TEXT NOT NULL DEFAULT 'GLOBAL'",
          );

          // medications: 增加更丰富的标签摘要与来源信息。
          await db.execute(
            "ALTER TABLE medications ADD COLUMN aliases TEXT NOT NULL DEFAULT '[]'",
          );
          await db.execute(
            "ALTER TABLE medications ADD COLUMN interaction_summary TEXT NOT NULL DEFAULT ''",
          );
          await db.execute(
            "ALTER TABLE medications ADD COLUMN source_system TEXT NOT NULL DEFAULT 'LOCAL_SEED'",
          );
          await db.execute(
            'ALTER TABLE medications ADD COLUMN source_product_code TEXT',
          );
          await db.execute(
            "ALTER TABLE medications ADD COLUMN jurisdiction TEXT NOT NULL DEFAULT 'GLOBAL'",
          );
          await db.execute(
            "ALTER TABLE medications ADD COLUMN route TEXT NOT NULL DEFAULT 'unspecified'",
          );
          await db.execute(
            "ALTER TABLE medications ADD COLUMN dosage_form TEXT NOT NULL DEFAULT 'unspecified'",
          );
          await db.execute(
            "ALTER TABLE medications ADD COLUMN release_type TEXT NOT NULL DEFAULT 'unspecified'",
          );
        }
        if (oldVersion < 3) {
          // meals: 新增高风险共事件/肠内营养上下文，供数据库驱动冲突引擎直接消费。
          await db.execute('ALTER TABLE meals ADD COLUMN coevent_time INTEGER');
          await db.execute(
            "ALTER TABLE meals ADD COLUMN coevent_substance_tags TEXT NOT NULL DEFAULT '[]'",
          );
          await db.execute('ALTER TABLE meals ADD COLUMN thickener_type TEXT');
          await db.execute(
            'ALTER TABLE meals ADD COLUMN enteral_feed_mode TEXT',
          );
          await db.execute(
            'ALTER TABLE meals ADD COLUMN enteral_feed_formula TEXT',
          );
          await db.execute(
            'ALTER TABLE meals ADD COLUMN enteral_feed_protein_g_per_day REAL',
          );
        }
        if (oldVersion < 4) {
          // foods: 新增结构化质地/IDDSI 字段，支撑吞咽上下文下的保守推荐。
          await db.execute('ALTER TABLE foods ADD COLUMN texture_class TEXT');
          await db.execute('ALTER TABLE foods ADD COLUMN iddsi_level INTEGER');
        }
        if (oldVersion < 5) {
          for (final statement in nativeFoodSchemaV5MigrationStatements) {
            await db.execute(statement);
          }
        }
        if (oldVersion < 6) {
          for (final statement in nativeIntakeSchemaV6MigrationStatements) {
            await db.execute(statement);
          }
        }
        if (oldVersion < 7) {
          for (final statement in nativeIntakeSchemaV7MigrationStatements) {
            await db.execute(statement);
          }
        }
        if (oldVersion < 8) {
          await db.execute(nativeRecoverableEventHistoryCreateTableSql);
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
        nativeFoodToSqliteRow(food),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await foodBatch.commit(noResult: true);

    final medicationBatch = db.batch();
    for (final medication in seedMedications) {
      medicationBatch.insert('medications', {
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
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await medicationBatch.commit(noResult: true);

    final ruleBatch = db.batch();
    for (final rule in seedRules) {
      ruleBatch.insert('interaction_rules', {
        'id': rule.id,
        'drug_id': rule.drugId,
        'rule_type': rule.ruleType,
        'target': rule.target,
        'severity': rule.severity,
        'weight': rule.weight,
        'description': rule.description,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await ruleBatch.commit(noResult: true);
  }

  @override
  Future<void> commitOnboarding(AtomicOnboardingCommit commit) async {
    final db = await _open();
    await db.transaction((transaction) async {
      final marker = await transaction.query(
        'app_meta',
        columns: <String>['value'],
        where: 'key = ?',
        whereArgs: <Object?>[_nativeOnboardingOperationKey],
        limit: 1,
      );
      if (marker.isNotEmpty && marker.first['value'] == commit.operationId) {
        return;
      }

      final batch = transaction.batch()
        ..insert('app_meta', <String, Object?>{
          'key': 'user_profile',
          'value': jsonEncode(commit.profile.toJson()),
        }, conflictAlgorithm: ConflictAlgorithm.replace)
        ..delete('active_drugs')
        ..delete('intakes');
      for (final id in commit.activeDrugIds) {
        batch.insert('active_drugs', <String, Object?>{'id': id});
      }
      for (final intake in commit.intakes) {
        batch.insert('intakes', nativeIntakeToSqliteRow(intake));
      }
      batch
        ..insert('app_meta', <String, Object?>{
          'key': 'onboarded',
          'value': 'true',
        }, conflictAlgorithm: ConflictAlgorithm.replace)
        ..insert('app_meta', <String, Object?>{
          'key': _nativeOnboardingOperationKey,
          'value': commit.operationId,
        }, conflictAlgorithm: ConflictAlgorithm.replace)
        ..insert('app_meta', <String, Object?>{
          'key': _nativeOnboardingStageKey,
          'value': atomicOnboardingCommitStageCommitted,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<bool> loadOnboarded() async {
    final db = await _open();
    final rows = await db.query(
      'app_meta',
      where: 'key = ?',
      whereArgs: ['onboarded'],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return rows.first['value'] == 'true';
  }

  @override
  Future<void> saveOnboarded(bool value) async {
    final db = await _open();
    await db.transaction((transaction) async {
      await transaction.insert('app_meta', {
        'key': 'onboarded',
        'value': value ? 'true' : 'false',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (!value) {
        await transaction.delete(
          'app_meta',
          where: 'key IN (?, ?)',
          whereArgs: <Object?>[
            _nativeOnboardingOperationKey,
            _nativeOnboardingStageKey,
          ],
        );
      }
    });
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
    await db.insert('app_meta', {
      'key': 'user_profile',
      'value': jsonEncode(profile.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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
    return mealRows
        .map((row) => _nativeMealFromRows(row, itemRows))
        .toList(growable: false);
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

      for (var ordinal = 0; ordinal < meal.items.length; ordinal++) {
        final item = meal.items[ordinal];
        batch.insert('meal_items', {
          'id': nativeMealItemStorageId(
            mealId: meal.id,
            foodId: item.foodId,
            ordinal: ordinal,
          ),
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
    return rows.map(nativeIntakeFromSqliteRow).toList(growable: false);
  }

  @override
  Future<void> saveIntakes(List<Intake> intakes) async {
    final db = await _open();
    final batch = db.batch()..delete('intakes');
    for (final intake in intakes) {
      batch.insert('intakes', nativeIntakeToSqliteRow(intake));
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<RecoverableUserEventRevision>>
  loadRecoverableUserEventHistory() async {
    final db = await _open();
    final rows = await db.query(
      'recoverable_event_history',
      orderBy: 'recorded_at DESC, history_id DESC',
    );
    return rows
        .map(
          (row) => RecoverableUserEventRevision.fromJson(
            Map<String, dynamic>.from(
              jsonDecode(row['revision_json'] as String) as Map,
            ),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> commitRecoverableUserEventMutation(
    RecoverableUserEventMutation mutation,
  ) async {
    final revision = mutation.revision..validate();
    final db = await _open();
    await db.transaction((transaction) async {
      final existing = await transaction.query(
        'recoverable_event_history',
        columns: const <String>['revision_json'],
        where: 'history_id = ? OR operation_id = ?',
        whereArgs: <Object?>[revision.historyId, revision.operationId],
      );
      final currentPayload = await _nativeCurrentEventPayload(
        transaction,
        revision,
      );
      final currentDigest = recoverableUserEventPayloadDigest(currentPayload);
      if (existing.isNotEmpty) {
        if (existing.length != 1 ||
            RecoverableUserEventRevision.fromJson(
                  Map<String, dynamic>.from(
                    jsonDecode(existing.single['revision_json'] as String)
                        as Map,
                  ),
                ).historyId !=
                revision.historyId ||
            currentDigest != revision.afterDigest) {
          throw RecoverableUserEventConflict(
            recordId: revision.recordId,
            expectedDigest: revision.afterDigest,
            actualDigest: currentDigest,
          );
        }
        return;
      }
      if (currentDigest != mutation.expectedCurrentDigest) {
        throw RecoverableUserEventConflict(
          recordId: revision.recordId,
          expectedDigest: mutation.expectedCurrentDigest,
          actualDigest: currentDigest,
        );
      }

      switch (revision.eventType) {
        case RecoverableUserEventType.meal:
          await transaction.delete(
            'meal_items',
            where: 'meal_id = ?',
            whereArgs: <Object?>[revision.recordId],
          );
          await transaction.delete(
            'meals',
            where: 'id = ?',
            whereArgs: <Object?>[revision.recordId],
          );
          if (revision.afterPayload != null) {
            await _insertNativeMeal(
              transaction,
              Meal.fromJson(Map<String, dynamic>.from(revision.afterPayload!)),
            );
          }
        case RecoverableUserEventType.intake:
          await transaction.delete(
            'intakes',
            where: 'id = ?',
            whereArgs: <Object?>[revision.recordId],
          );
          if (revision.afterPayload != null) {
            await transaction.insert(
              'intakes',
              nativeIntakeToSqliteRow(
                Intake.fromJson(
                  Map<String, dynamic>.from(revision.afterPayload!),
                ),
              ),
            );
          }
      }
      await transaction.insert('recoverable_event_history', <String, Object?>{
        'history_id': revision.historyId,
        'operation_id': revision.operationId,
        'event_type': revision.eventType.name,
        'record_id': revision.recordId,
        'recorded_at': revision.recordedAtUtc.millisecondsSinceEpoch,
        'revision_json': jsonEncode(revision.toJson()),
      });
    });
  }

  Future<Map<String, Object?>?> _nativeCurrentEventPayload(
    DatabaseExecutor database,
    RecoverableUserEventRevision revision,
  ) async {
    switch (revision.eventType) {
      case RecoverableUserEventType.meal:
        final rows = await database.query(
          'meals',
          where: 'id = ?',
          whereArgs: <Object?>[revision.recordId],
          limit: 1,
        );
        if (rows.isEmpty) return null;
        final itemRows = await database.query(
          'meal_items',
          where: 'meal_id = ?',
          whereArgs: <Object?>[revision.recordId],
        );
        return Map<String, Object?>.from(
          _nativeMealFromRows(rows.single, itemRows).toJson(),
        );
      case RecoverableUserEventType.intake:
        final rows = await database.query(
          'intakes',
          where: 'id = ?',
          whereArgs: <Object?>[revision.recordId],
          limit: 1,
        );
        if (rows.isEmpty) return null;
        return Map<String, Object?>.from(
          nativeIntakeFromSqliteRow(rows.single).toJson(),
        );
    }
  }

  @override
  Future<List<FoodItem>> loadFoods() async {
    final db = await _open();
    final rows = await db.query('foods', orderBy: 'name ASC');
    return rows.map(nativeFoodFromSqliteRow).toList(growable: false);
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
        .map(
          (row) => InteractionRuleRecord(
            id: row['id'] as String,
            drugId: row['drug_id'] as String,
            ruleType: row['rule_type'] as String,
            target: row['target'] as String,
            severity: row['severity'] as int,
            weight: (row['weight'] as num).toDouble(),
            description: row['description'] as String,
          ),
        )
        .toList(growable: false);
  }

  DrugDefinition _medicationFromRow(Map<String, Object?> row) {
    final tagNames = jsonDecode(row['tags'] as String) as List<dynamic>;
    return DrugDefinition(
      id: row['id'] as String,
      genericName: row['type'] as String,
      brandNames: [row['name'] as String],
      aliases:
          (jsonDecode((row['aliases'] as String?) ?? '[]') as List<dynamic>)
              .map((value) => value.toString())
              .toList(growable: false),
      tags: parseDrugTags(tagNames),
      notes: row['notes'] as String,
      interactionSummary: (row['interaction_summary'] as String?) ?? '',
      sourceSystem: (row['source_system'] as String?) ?? 'LOCAL_SEED',
      sourceProductCode: row['source_product_code'] as String?,
      jurisdiction: (row['jurisdiction'] as String?) ?? 'GLOBAL',
      route: (row['route'] as String?) ?? 'unspecified',
      dosageForm: (row['dosage_form'] as String?) ?? 'unspecified',
      releaseType: (row['release_type'] as String?) ?? 'unspecified',
    );
  }
}

AppDatabase createAppDatabaseImpl() => NativeAppDatabase();
