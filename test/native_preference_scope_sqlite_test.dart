import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/app_database_native.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/core/models/user_preference_write_scope.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  late Directory directory;
  late String path;
  late _CliDatabase sqlite;
  late NativeAppDatabase store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'preference_scope_sqlite_',
    );
    path = '${directory.path}/synthetic.sqlite';
    final seed = await Process.run('/usr/bin/sqlite3', [
      '-bail',
      path,
      'CREATE TABLE app_meta(key TEXT PRIMARY KEY,value TEXT NOT NULL);'
          'CREATE TABLE active_drugs(id TEXT PRIMARY KEY);'
          "INSERT INTO app_meta VALUES('user_profile','original-profile');"
          "INSERT INTO active_drugs VALUES('original_drug');",
    ]);
    expect(seed.exitCode, 0, reason: seed.stderr.toString());
    sqlite = await _CliDatabase.open(path);
    store = NativeAppDatabase(databaseOpener: () async => sqlite);
  });

  tearDown(() async {
    await sqlite.close();
    await directory.delete(recursive: true);
  });

  test('profile guard rejects before opening a database', () async {
    var opens = 0;
    final guarded = NativeAppDatabase(
      databaseOpener: () async {
        opens += 1;
        return sqlite;
      },
    );
    await expectLater(
      guarded.saveUserProfileForSession(_profile(), scope: _scope(() => false)),
      throwsA(isA<UserPreferenceWriteScopeChanged>()),
    );
    expect(opens, 0);
    expect(await _rows(path, 'SELECT value FROM app_meta'), [
      {'value': 'original-profile'},
    ]);
  });

  test(
    'authorization is rechecked after asynchronous database acquisition',
    () async {
      final acquired = Completer<Database>();
      var valid = true;
      final guarded = NativeAppDatabase(databaseOpener: () => acquired.future);
      final pending = guarded.saveUserProfileForSession(
        _profile(),
        scope: _scope(() => valid),
      );
      final rejected = expectLater(
        pending,
        throwsA(isA<UserPreferenceWriteScopeChanged>()),
      );
      valid = false;
      acquired.complete(sqlite);
      await rejected;
      expect(sqlite.transactions, 0);
      expect(await _rows(path, 'SELECT value FROM app_meta'), [
        {'value': 'original-profile'},
      ]);
    },
  );

  test(
    'invalidation after the actual profile insert rolls back SQLite',
    () async {
      var valid = true;
      sqlite.afterWrite = (_) => valid = false;
      await expectLater(
        store.saveUserProfileForSession(_profile(), scope: _scope(() => valid)),
        throwsA(isA<UserPreferenceWriteScopeChanged>()),
      );
      expect(sqlite.rolledBack, 1);
      expect(sqlite.committed, 0);
      expect(await _rows(path, 'SELECT value FROM app_meta'), [
        {'value': 'original-profile'},
      ]);
    },
  );

  for (final phase in ['delete', 'first_insert']) {
    test(
      'medication invalidation after $phase rolls back the whole selection',
      () async {
        var valid = true;
        sqlite.afterWrite = (operation) {
          if ((phase == 'delete' && operation == 'delete') ||
              (phase == 'first_insert' && operation == 'insert')) {
            valid = false;
          }
        };
        await expectLater(
          store.saveActiveDrugIdsForSession([
            'new_a',
            'new_b',
          ], scope: _scope(() => valid)),
          throwsA(isA<UserPreferenceWriteScopeChanged>()),
        );
        expect(sqlite.rolledBack, 1);
        expect(sqlite.committed, 0);
        expect(await _rows(path, 'SELECT id FROM active_drugs ORDER BY id'), [
          {'id': 'original_drug'},
        ]);
      },
    );
  }

  test(
    'valid profile and complete medication selection commit and read back',
    () async {
      final scope = _scope(() => true);
      await store.saveUserProfileForSession(_profile(), scope: scope);
      await store.saveActiveDrugIdsForSession(['new_a', 'new_b'], scope: scope);
      expect(sqlite.committed, 2);
      final row = (await _rows(path, 'SELECT value FROM app_meta')).single;
      expect(jsonDecode(row['value'] as String), _profile().toJson());
      expect(await _rows(path, 'SELECT id FROM active_drugs ORDER BY id'), [
        {'id': 'new_a'},
        {'id': 'new_b'},
      ]);
    },
  );
}

UserProfile _profile() => UserProfile.defaults().copyWith(
  patientId: 'synthetic_owner',
  displayLocale: 'fr-CA',
);
UserPreferenceWriteScope _scope(bool Function() valid) =>
    UserPreferenceWriteScope(
      ownerUid: 'synthetic_owner',
      sessionEpoch: 1,
      isCurrent: valid,
    );

Future<List<dynamic>> _rows(String path, String sql) async {
  final result = await Process.run('/usr/bin/sqlite3', [
    '-bail',
    '-json',
    path,
    sql,
  ]);
  expect(result.exitCode, 0, reason: result.stderr.toString());
  return (jsonDecode(result.stdout.toString().trim()) as List);
}

String _literal(Object? value) => value == null
    ? 'NULL'
    : value is num
    ? '$value'
    : "'${value.toString().replaceAll("'", "''")}'";

/// Adapter executes actual NativeAppDatabase transaction callbacks against a
/// real temporary SQLite connection. It does not exercise the Flutter plugin.
class _CliDatabase implements Database {
  _CliDatabase(this.process, this.lines);
  final Process process;
  final StreamIterator<String> lines;
  int _sequence = 0;
  int transactions = 0;
  int committed = 0;
  int rolledBack = 0;
  void Function(String operation)? afterWrite;

  static Future<_CliDatabase> open(String path) async {
    final process = await Process.start('/usr/bin/sqlite3', ['-bail', path]);
    process.stderr.transform(utf8.decoder).listen((value) {
      if (value.trim().isNotEmpty) throw StateError(value);
    });
    return _CliDatabase(
      process,
      StreamIterator(
        process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
      ),
    );
  }

  Future<List<String>> send(String sql) async {
    final marker = 'scope_transaction_${++_sequence}';
    process.stdin.writeln("$sql; SELECT '$marker';");
    await process.stdin.flush();
    final output = <String>[];
    while (await lines.moveNext().timeout(const Duration(seconds: 5))) {
      if (lines.current == marker) return output;
      output.add(lines.current);
    }
    throw StateError(
      'Temporary SQLite connection closed before acknowledgement.',
    );
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) async {
    transactions += 1;
    await send('BEGIN IMMEDIATE');
    try {
      final result = await action(_CliTransaction(this));
      await send('COMMIT');
      committed += 1;
      return result;
    } catch (_) {
      await send('ROLLBACK');
      rolledBack += 1;
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    await process.stdin.close();
    await process.exitCode;
    await lines.cancel();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CliTransaction implements Transaction {
  _CliTransaction(this.database);
  @override
  final _CliDatabase database;

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    if (!['app_meta', 'active_drugs'].contains(table)) {
      throw ArgumentError(table);
    }
    final conflict = conflictAlgorithm == ConflictAlgorithm.replace
        ? ' OR REPLACE'
        : '';
    final result = await database.send(
      'INSERT$conflict INTO $table '
      '(${values.keys.join(',')}) VALUES (${values.values.map(_literal).join(',')}); '
      'SELECT last_insert_rowid()',
    );
    database.afterWrite?.call('insert');
    return int.parse(result.single);
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    if (table != 'active_drugs' || where != null) throw ArgumentError(table);
    final result = await database.send(
      'DELETE FROM active_drugs; SELECT changes()',
    );
    database.afterWrite?.call('delete');
    return int.parse(result.single);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
