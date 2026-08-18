import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/app_database_native.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/medication_product_pack.dart';
import 'package:parkinsum_companion/domain/usecases/dosage_note_parser.dart';
import 'package:parkinsum_companion/domain/usecases/intake_dose_context_builder.dart';

const _legacyV5IntakesSchema = '''
CREATE TABLE intakes (
  id TEXT PRIMARY KEY,
  drug_id TEXT NOT NULL,
  taken_at INTEGER NOT NULL,
  dosage_note TEXT NOT NULL
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
    throw StateError('sqlite3 failed: ${result.stderr}\nSQL: $sql');
  }
  return result.stdout.toString().trim();
}

String _sqlLiteral(Object? value) {
  if (value == null) return 'NULL';
  if (value is num) return value.toString();
  return "'${value.toString().replaceAll("'", "''")}'";
}

Future<void> _insertIntake(
  String databasePath,
  Map<String, Object?> row,
) async {
  await _runSqlite(
    databasePath,
    'INSERT INTO intakes (${row.keys.join(', ')}) '
    'VALUES (${row.values.map(_sqlLiteral).join(', ')})',
  );
}

Future<Map<String, Object?>> _readIntake(String databasePath) async {
  final output = await _runSqlite(
    databasePath,
    'SELECT * FROM intakes LIMIT 1',
    jsonOutput: true,
  );
  final rows = jsonDecode(output) as List<dynamic>;
  return Map<String, Object?>.from(rows.single as Map<dynamic, dynamic>);
}

void main() {
  final drug = DrugDefinition(
    id: 'levodopa_ir',
    genericName: 'levodopa',
    brandNames: const <String>[],
    tags: const <DrugTag>[DrugTag.levodopaLike],
    notes: '',
    route: 'oral',
    dosageForm: 'tablet',
    releaseType: 'immediate',
  );

  test('builder records explicit dose and formulation snapshot', () {
    final intake = IntakeDoseContextBuilder().build(
      id: 'i1',
      drugId: drug.id,
      takenAt: DateTime.utc(2026, 8, 16, 12),
      dosageNote: ' 100 milligrams ',
      drug: drug,
    );

    expect(intake.dosageNote, '100 milligrams');
    expect(intake.doseAmount, 100);
    expect(intake.doseUnit, 'mg');
    expect(intake.dosageForm, 'tablet');
    expect(intake.route, 'oral');
    expect(intake.releaseType, 'immediate');
  });

  test('ambiguous note never receives a fabricated structured dose', () {
    final intake = IntakeDoseContextBuilder().build(
      id: 'i2',
      drugId: drug.id,
      takenAt: DateTime.utc(2026, 8, 16, 12),
      dosageNote: '25 mg / 100 mg',
      drug: drug,
    );

    expect(intake.doseAmount, isNull);
    expect(intake.doseUnit, isNull);
    expect(DosageNoteParser().milligramsForIntake(intake), isNull);
  });

  test('structured dose is preferred while legacy JSON remains readable', () {
    final structured = Intake(
      id: 'i3',
      drugId: drug.id,
      takenAt: DateTime.utc(2026, 8, 16, 12),
      dosageNote: 'old note 50 mg',
      doseAmount: 75,
      doseUnit: 'mg',
    );
    expect(DosageNoteParser().milligramsForIntake(structured), 75);

    final legacy = Intake.fromJson(<String, dynamic>{
      'id': 'legacy',
      'drugId': drug.id,
      'takenAt': '2026-08-16T12:00:00.000Z',
      'dosageNote': '50 mg',
    });
    expect(legacy.doseAmount, isNull);
    expect(legacy.doseUnit, isNull);
    expect(DosageNoteParser().milligramsForIntake(legacy), 50);
  });

  group('native SQLite intake schema v7', () {
    late Directory tempDirectory;
    late String databasePath;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'parkinsum_native_intake_',
      );
      databasePath = '${tempDirectory.path}/intakes.sqlite';
    });

    tearDown(() async {
      await tempDirectory.delete(recursive: true);
    });

    test('round-trips structured fields through real SQLite', () async {
      await _runSqlite(databasePath, nativeIntakesCreateTableSql);
      final original = IntakeDoseContextBuilder()
          .build(
            id: "intake'quoted",
            drugId: drug.id,
            takenAt: DateTime.utc(2026, 8, 16, 12, 30),
            dosageNote: '0.5 g',
            drug: drug,
          )
          .copyWith(
            productSelection: const MedicationProductSelection(
              packId: 'openfda_ndc_72865_362_01',
              identifierSystem: 'ndcPackage',
              identifierValue: '72865-362-01',
              displayName: 'Carbidopa and Levodopa',
              labelerName: 'Example labeler',
              strengthDisplay: 'CARBIDOPA 25 mg + LEVODOPA 100 mg',
              packageDescription: '100 TABLET in 1 BOTTLE',
              doseBasisIngredient: 'LEVODOPA',
              unitQuantity: 0.5,
              unitLabel: 'TABLET',
            ),
          );

      await _insertIntake(databasePath, nativeIntakeToSqliteRow(original));
      final restored = nativeIntakeFromSqliteRow(
        await _readIntake(databasePath),
      );

      expect(
        restored.takenAt.millisecondsSinceEpoch,
        original.takenAt.millisecondsSinceEpoch,
      );
      final restoredFields = restored.toJson()..remove('takenAt');
      final originalFields = original.toJson()..remove('takenAt');
      expect(restoredFields, originalFields);
      expect(DosageNoteParser().milligramsForIntake(restored), 500);
    });

    test('v5 migration keeps legacy dose context unknown', () async {
      await _runSqlite(
        databasePath,
        '$_legacyV5IntakesSchema; '
        "INSERT INTO intakes VALUES ('legacy', 'drug', 1, 'levodopa 100');",
      );
      for (final statement in nativeIntakeSchemaV6MigrationStatements) {
        await _runSqlite(databasePath, statement);
      }
      for (final statement in nativeIntakeSchemaV7MigrationStatements) {
        await _runSqlite(databasePath, statement);
      }

      final restored = nativeIntakeFromSqliteRow(
        await _readIntake(databasePath),
      );
      expect(restored.dosageNote, 'levodopa 100');
      expect(restored.doseAmount, isNull);
      expect(restored.doseUnit, isNull);
      expect(restored.dosageForm, isNull);
      expect(restored.route, isNull);
      expect(restored.releaseType, isNull);
      expect(restored.productSelection, isNull);
    });
  });
}
