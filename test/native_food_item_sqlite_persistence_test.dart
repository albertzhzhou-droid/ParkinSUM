import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/app_database_native.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/domain/entities/amino_acid_profile.dart';

const _legacyV4FoodsSchema = '''
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
  iddsi_level INTEGER
)
''';

String get _sqlite3Executable =>
    File('/usr/bin/sqlite3').existsSync() ? '/usr/bin/sqlite3' : 'sqlite3';

Future<String> _runSqlite(
  String databasePath,
  String sql, {
  bool jsonOutput = false,
}) async {
  final result = await Process.run(_sqlite3Executable, <String>[
    if (jsonOutput) '-json',
    databasePath,
    sql,
  ]);
  if (result.exitCode != 0) {
    throw StateError(
      'sqlite3 failed (${result.exitCode}): ${result.stderr}\nSQL: $sql',
    );
  }
  return result.stdout.toString().trim();
}

String _sqlLiteral(Object? value) {
  if (value == null) return 'NULL';
  if (value is num) return value.toString();
  return "'${value.toString().replaceAll("'", "''")}'";
}

Future<void> _insertRow(String databasePath, Map<String, Object?> row) async {
  final columns = row.keys.join(', ');
  final values = row.values.map(_sqlLiteral).join(', ');
  await _runSqlite(
    databasePath,
    'INSERT INTO foods ($columns) VALUES ($values)',
  );
}

Future<List<Map<String, Object?>>> _queryRows(
  String databasePath,
  String sql,
) async {
  final output = await _runSqlite(databasePath, sql, jsonOutput: true);
  if (output.isEmpty) return const <Map<String, Object?>>[];
  return (jsonDecode(output) as List<dynamic>)
      .map((row) => Map<String, Object?>.from(row as Map<dynamic, dynamic>))
      .toList(growable: false);
}

void main() {
  group('Native FoodItem SQLite persistence', () {
    late Directory tempDirectory;
    late String databasePath;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'parkinsum_native_food_',
      );
      databasePath = '${tempDirectory.path}/foods.sqlite';
    });

    tearDown(() async {
      await tempDirectory.delete(recursive: true);
    });

    test('round-trips every FoodItem field through real SQLite', () async {
      await _runSqlite(
        databasePath,
        '$nativeFoodsCreateTableSql; '
        'PRAGMA user_version = $nativeAppDatabaseSchemaVersion',
      );

      final original = FoodItem(
        id: 'fdc:123',
        name: "Chef's lentils 豆",
        category: FoodCategory.protein,
        aliases: <String>['lentils', '扁豆'],
        description: 'Analytical food record',
        sourceSystem: 'USDA_FDC',
        sourceFoodCode: '123',
        jurisdiction: 'US',
        textureClass: 'soft',
        iddsiLevel: 6,
        proteinG: 9.02,
        carbsG: 20.13,
        fatG: 0.38,
        fiberG: 0,
        sodiumMg: 2.1,
        missingNutrientFields: <String>{'fiberG'},
        energyKcal: 116.25,
        waterG: 69.64,
        aminoAcidProfile: const AminoAcidProfile(
          leucine: 0.65,
          isoleucine: 0.39,
          valine: 0.45,
          phenylalanine: 0.45,
          tyrosine: 0.24,
          tryptophan: 0.08,
          histidine: 0.25,
          methionine: 0.08,
          threonine: 0.32,
          lysine: 0.63,
          cystine: 0.12,
          arginine: 0.7,
          nutrientIds: <String>['505', '506'],
          sourceRefs: <String>['fdc:123'],
          partial: true,
          derivations: <String, NutrientDerivation>{
            'leucine': NutrientDerivation(
              derivationCode: 'A',
              derivationDescription: 'Analytical measurement',
              sourceCode: '1',
              dataPoints: 4,
              min: 0.6,
              max: 0.7,
              median: 0.65,
            ),
          },
          fdcDataType: 'Foundation',
        ),
        basisType: 'per_100g',
        preparationState: 'cooked',
        qualifierKind: 'analytical',
      );

      await _insertRow(databasePath, nativeFoodToSqliteRow(original));
      final rows = await _queryRows(
        databasePath,
        "SELECT * FROM foods WHERE id = 'fdc:123'",
      );
      final restored = nativeFoodFromSqliteRow(rows.single);

      expect(restored.toJson(), original.toJson());
      expect(restored.missingNutrientFields, <String>{'fiberG'});
      expect(restored.energyKcal, 116.25);
      expect(restored.waterG, 69.64);
      expect(
        restored.aminoAcidProfile?.toJson(),
        original.aminoAcidProfile?.toJson(),
      );
      expect(restored.basisType, 'per_100g');
      expect(restored.preparationState, 'cooked');
      expect(restored.qualifierKind, 'analytical');
    });

    test(
      'default seed canonicalizes null optional nutrients without inferring macro zeros',
      () async {
        await _runSqlite(databasePath, nativeFoodsCreateTableSql);
        final defaultSeed = FoodItem(
          id: 'default_seed',
          name: 'Default seed',
          category: FoodCategory.other,
          proteinG: 0,
          carbsG: 0,
          fatG: 0,
          fiberG: 0,
          sodiumMg: 0,
        );

        final canonicalRow = nativeFoodToSqliteRow(defaultSeed);
        expect(
          jsonDecode(canonicalRow['missing_nutrient_fields']! as String),
          unorderedEquals(<String>['energyKcal', 'waterG']),
        );

        // Simulate a pre-canonical v5 row whose bitmap was left at the schema
        // default. Read-time normalization must restore optional missingness,
        // without treating new, explicitly stored macro zeros as unknown.
        final inconsistentRow = <String, Object?>{
          ...canonicalRow,
          'missing_nutrient_fields': '[]',
        };
        await _insertRow(databasePath, inconsistentRow);
        final rows = await _queryRows(
          databasePath,
          "SELECT * FROM foods WHERE id = 'default_seed'",
        );
        final restored = nativeFoodFromSqliteRow(rows.single);

        expect(restored.missingNutrientFields, <String>{
          'energyKcal',
          'waterG',
        });
        expect(restored.missingNutrientFields, isNot(contains('proteinG')));
        expect(restored.missingNutrientFields, isNot(contains('carbsG')));
        expect(restored.missingNutrientFields, isNot(contains('fatG')));
        expect(restored.missingNutrientFields, isNot(contains('fiberG')));
        expect(restored.missingNutrientFields, isNot(contains('sodiumMg')));
      },
    );

    test('v4 migration preserves unknown rather than inventing zero', () async {
      await _runSqlite(
        databasePath,
        '$_legacyV4FoodsSchema; PRAGMA user_version = 4',
      );
      await _insertRow(databasePath, <String, Object?>{
        'id': 'legacy_food',
        'name': 'Legacy food',
        'protein': 0,
        'carbs': 27.5,
        'fat': 0,
        'fiber': 4.0,
        'sodium': 0,
        'category': 'carbs',
        'aliases': '[]',
        'description': '',
        'source_system': 'LOCAL_SEED',
        'source_food_code': null,
        'jurisdiction': 'GLOBAL',
        'texture_class': null,
        'iddsi_level': null,
      });

      final migrationSql = nativeFoodSchemaV5MigrationStatements
          .map((statement) => '$statement;')
          .join('\n');
      await _runSqlite(
        databasePath,
        'BEGIN; $migrationSql '
        'PRAGMA user_version = $nativeAppDatabaseSchemaVersion; COMMIT',
      );

      final rows = await _queryRows(
        databasePath,
        "SELECT * FROM foods WHERE id = 'legacy_food'",
      );
      final restored = nativeFoodFromSqliteRow(rows.single);

      expect(restored.missingNutrientFields, <String>{
        'proteinG',
        'fatG',
        'sodiumMg',
        'energyKcal',
        'waterG',
      });
      expect(restored.missingNutrientFields, isNot(contains('carbsG')));
      expect(restored.missingNutrientFields, isNot(contains('fiberG')));
      expect(restored.energyKcal, isNull);
      expect(restored.waterG, isNull);
      expect(restored.aminoAcidProfile, isNull);
      expect(restored.basisType, isNull);
      expect(restored.preparationState, isNull);
      expect(restored.qualifierKind, isNull);
      expect(restored.proteinG, 0);
      expect(restored.fatG, 0);
      expect(restored.sodiumMg, 0);

      final version = await _runSqlite(databasePath, 'PRAGMA user_version');
      expect(version, nativeAppDatabaseSchemaVersion.toString());
    });
  });
}
