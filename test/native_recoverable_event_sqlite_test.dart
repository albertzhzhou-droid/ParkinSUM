import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/app_database_native.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/recoverable_user_event.dart';

String get _sqlite3Executable =>
    File('/usr/bin/sqlite3').existsSync() ? '/usr/bin/sqlite3' : 'sqlite3';

Future<ProcessResult> _runSqlite(
  String databasePath,
  String sql, {
  bool jsonOutput = false,
}) => Process.run(_sqlite3Executable, <String>[
  '-bail',
  if (jsonOutput) '-json',
  databasePath,
  sql,
]);

String _sqlLiteral(Object? value) {
  if (value == null) return 'NULL';
  if (value is num) return value.toString();
  return "'${value.toString().replaceAll("'", "''")}'";
}

String _insert(String table, Map<String, Object?> row) =>
    'INSERT INTO $table (${row.keys.join(', ')}) VALUES '
    '(${row.values.map(_sqlLiteral).join(', ')})';

Future<List<Map<String, Object?>>> _query(
  String databasePath,
  String sql,
) async {
  final result = await _runSqlite(databasePath, sql, jsonOutput: true);
  expect(result.exitCode, 0, reason: result.stderr.toString());
  final output = result.stdout.toString().trim();
  if (output.isEmpty) return const <Map<String, Object?>>[];
  return (jsonDecode(output) as List<dynamic>)
      .map((row) => Map<String, Object?>.from(row as Map))
      .toList(growable: false);
}

void main() {
  group('Native recoverable event transaction', () {
    late Directory tempDirectory;
    late String databasePath;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'parkinsum_native_history_',
      );
      databasePath = '${tempDirectory.path}/history.sqlite';
      final result = await _runSqlite(
        databasePath,
        '$nativeIntakesCreateTableSql; '
        '$nativeRecoverableEventHistoryCreateTableSql; '
        'PRAGMA user_version = $nativeAppDatabaseSchemaVersion',
      );
      expect(result.exitCode, 0, reason: result.stderr.toString());
    });

    tearDown(() async {
      await tempDirectory.delete(recursive: true);
    });

    test('business row and immutable revision commit together', () async {
      final before = Intake(
        id: 'intake_sqlite_history',
        drugId: 'levodopa_carbidopa',
        takenAt: DateTime.utc(2026, 8, 18, 8),
        dosageNote: '100 mg',
      );
      final after = before.copyWith(dosageNote: '100/25 mg');
      final revision = RecoverableUserEventRevision.create(
        operationId: 'event_op_sqlite_commit',
        eventType: RecoverableUserEventType.intake,
        recordId: before.id,
        mutationType: RecoverableUserEventMutationType.update,
        beforePayload: before.toJson(),
        afterPayload: after.toJson(),
        recordedAtUtc: DateTime.utc(2026, 8, 18, 9),
        source: 'native_test',
      );
      final seed = await _runSqlite(
        databasePath,
        _insert('intakes', nativeIntakeToSqliteRow(before)),
      );
      expect(seed.exitCode, 0, reason: seed.stderr.toString());

      final commit = await _runSqlite(
        databasePath,
        'BEGIN IMMEDIATE; '
        "DELETE FROM intakes WHERE id = '${before.id}'; "
        '${_insert('intakes', nativeIntakeToSqliteRow(after))}; '
        '${_insert('recoverable_event_history', <String, Object?>{'history_id': revision.historyId, 'operation_id': revision.operationId, 'event_type': revision.eventType.name, 'record_id': revision.recordId, 'recorded_at': revision.recordedAtUtc.millisecondsSinceEpoch, 'revision_json': jsonEncode(revision.toJson())})}; COMMIT',
      );
      expect(commit.exitCode, 0, reason: commit.stderr.toString());

      final intakeRows = await _query(
        databasePath,
        'SELECT dosage_note FROM intakes',
      );
      final historyRows = await _query(
        databasePath,
        'SELECT history_id, operation_id FROM recoverable_event_history',
      );
      expect(intakeRows.single['dosage_note'], '100/25 mg');
      expect(historyRows.single['history_id'], revision.historyId);
      expect(historyRows.single['operation_id'], revision.operationId);
    });

    test('history constraint failure rolls the business mutation back', () async {
      final original = Intake(
        id: 'intake_sqlite_rollback',
        drugId: 'levodopa_carbidopa',
        takenAt: DateTime.utc(2026, 8, 18, 8),
        dosageNote: 'original',
      );
      final existingHistory = <String, Object?>{
        'history_id': 'history_existing',
        'operation_id': 'event_op_duplicate',
        'event_type': 'intake',
        'record_id': original.id,
        'recorded_at': DateTime.utc(2026, 8, 18, 8).millisecondsSinceEpoch,
        'revision_json': '{}',
      };
      final seed = await _runSqlite(
        databasePath,
        '${_insert('intakes', nativeIntakeToSqliteRow(original))}; '
        '${_insert('recoverable_event_history', existingHistory)}',
      );
      expect(seed.exitCode, 0, reason: seed.stderr.toString());
      final replacement = original.copyWith(dosageNote: 'must roll back');

      final failed = await _runSqlite(
        databasePath,
        'BEGIN IMMEDIATE; '
        "DELETE FROM intakes WHERE id = '${original.id}'; "
        '${_insert('intakes', nativeIntakeToSqliteRow(replacement))}; '
        '${_insert('recoverable_event_history', <String, Object?>{...existingHistory, 'history_id': 'history_conflicting'})}; COMMIT',
      );
      expect(failed.exitCode, isNot(0));

      final intakes = await _query(
        databasePath,
        'SELECT dosage_note FROM intakes',
      );
      final history = await _query(
        databasePath,
        'SELECT history_id FROM recoverable_event_history',
      );
      expect(intakes.single['dosage_note'], 'original');
      expect(history, <Map<String, Object?>>[
        <String, Object?>{'history_id': 'history_existing'},
      ]);
    });

    test('v8 migration table rejects duplicate operation ids', () async {
      final first = await _runSqlite(
        databasePath,
        "INSERT INTO recoverable_event_history VALUES "
        "('history_a','operation_a','meal','meal_a',1,'{}')",
      );
      expect(first.exitCode, 0, reason: first.stderr.toString());
      final duplicate = await _runSqlite(
        databasePath,
        "INSERT INTO recoverable_event_history VALUES "
        "('history_b','operation_a','meal','meal_b',2,'{}')",
      );
      expect(duplicate.exitCode, isNot(0));
      expect(
        await _query(databasePath, 'PRAGMA user_version'),
        <Map<String, Object?>>[
          <String, Object?>{'user_version': nativeAppDatabaseSchemaVersion},
        ],
      );
    });
  });
}
