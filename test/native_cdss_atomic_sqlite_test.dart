import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/cdss_database_native.dart';
import 'package:parkinsum_companion/data/datasources/remote/p0_import_models.dart';
import 'package:parkinsum_companion/data/datasources/remote/fdc_p0_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_fetch_client.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_artifact_store_stub.dart';
import 'package:parkinsum_companion/domain/usecases/clinical_decision_support_service.dart';
import 'package:parkinsum_companion/domain/usecases/fact_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/runtime_rule_engine.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_catalog_projection_service.dart';
import 'package:sqflite/sqflite.dart';

import 'cdss_atomic_import_test.dart' show before, attempted;
import 'held_import_review_evidence_test.dart' show conflictingBundle;
import 'reviewed_import_activation_test.dart' show prepareOn, activate;

ClinicalDecisionSupportService service(NativeCdssDatabase database) =>
    ClinicalDecisionSupportService(
      database: database,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
      artifactStore: InlineCdssArtifactStore(),
    );

class _FailingConceptDatabase extends NativeCdssDatabase {
  _FailingConceptDatabase({
    required super.factory,
    required super.databasePath,
  });
  @override
  Future<void> insertFoodConcept(FoodConceptRecord _) async =>
      throw StateError('Synthetic concept persistence failure');
}

class _FailingActivationReceiptDatabase extends NativeCdssDatabase {
  _FailingActivationReceiptDatabase({
    required super.factory,
    required super.databasePath,
  });
  bool rejectReceipt = false;
  @override
  Future<void> insertConflictAuditLog(ConflictAuditLogRecord record) {
    if (rejectReceipt && record.auditType == 'REVIEWED_IMPORT_ACTIVATION') {
      throw StateError('Synthetic last-receipt failure');
    }
    return super.insertConflictAuditLog(record);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late String path;
  late _SqliteFactory factory;
  late NativeCdssDatabase database;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('parkinsum_cdss_atomic_');
    path = '${directory.path}/synthetic.sqlite';
    factory = _SqliteFactory();
    database = NativeCdssDatabase(factory: factory, databasePath: path);
    await database.initialize();
  });
  tearDown(() async {
    await database.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'ordinary FDC ingestion marker retains eligible mass quantity after actual SQLite reopen',
    () async {
      final bundle =
          const FdcP0Importer(
            fetchClient: FakeSourceFetchClient(textByUrl: {}),
          ).importFoods([
            {
              'fdcId': 999,
              'dataType': 'Branded',
              'description': 'Synthetic mass source',
              'servingSize': 30,
              'servingSizeUnit': 'g',
              'foodNutrients': [
                {
                  'id': 1,
                  'amount': 5,
                  'nutrient': {
                    'id': 1003,
                    'number': '203',
                    'name': 'Protein',
                    'unitName': 'g',
                  },
                },
              ],
            },
          ], sourceLabel: 'synthetic_native_ingestion_status');
      await service(database).importBundle(bundle);
      final original = await _allTables(database);
      await database.close();
      database = NativeCdssDatabase(factory: factory, databasePath: path);
      final projection = await CdssCatalogProjectionService(
        database: database,
      ).projectFoodsWithAudit();
      expect(projection.foods.single.isNutrientMissing('proteinG'), isFalse);
      expect(projection.foods.single.proteinG, 5);
      expect(
        projection.foods.single.nutrientObservationEvidence.single.valueNum,
        5,
      );
      expect(
        projection
            .foods
            .single
            .nutrientObservationEvidence
            .single
            .selectedForLegacyPointProjection,
        isTrue,
      );
      expect(
        projection.queryAudit['read_consistency'],
        'native_sqlite_transaction',
      );
      expect(await _allTables(database), original);
    },
  );

  test(
    'actual native schema and failed import restore the complete SQLite state after reopen',
    () async {
      await database.insertCountryDietProfile(before);
      await database.insertRuleRegistry({
        'rule_id': 'original',
        'rule_version': 'v1',
        'status': 'active',
        'rule_type': 'rule',
        'priority_band': 1,
        'specificity_band': 1,
        'jurisdiction_json': '[]',
        'applies_to_json': '{}',
        'predicate_json': '{}',
        'effect_json': '{}',
        'provenance_json': '{}',
        'override_json': null,
        'compiled_hash': 'synthetic',
        'updated_at': 1000,
      });
      final original = await _allTables(database);
      await database.close();
      database = _FailingConceptDatabase(factory: factory, databasePath: path);
      await expectLater(
        service(database).importBundle(
          const P0ImportBundle(
            countryDietProfiles: [attempted],
            foodConcepts: [
              FoodConceptRecord(
                foodConceptId: 'candidate',
                canonicalNameEn: 'Candidate',
                canonicalNameZh: '候选',
                foodGroup: 'other',
              ),
            ],
          ),
        ),
        throwsStateError,
      );
      expect(factory.last!.rolledBack, 1);
      await database.close();
      database = NativeCdssDatabase(factory: factory, databasePath: path);
      expect(await _allTables(database), original);
      expect(await service(database).latestPromotedSnapshot(), isNull);
    },
  );

  test(
    'native complete promotion commits once and survives connection reopen',
    () async {
      await database.insertCountryDietProfile(before);
      final connection = factory.last!;
      final commitsBefore = connection.committed;
      final report = await service(
        database,
      ).importBundle(const P0ImportBundle(countryDietProfiles: [attempted]));
      expect(connection.committed, commitsBefore + 1);
      await database.close();
      database = NativeCdssDatabase(factory: factory, databasePath: path);
      expect(
        (await database.queryTable(
          'country_diet_profile',
        )).single['guideline_source'],
        attempted.guidelineSource,
      );
      expect(
        (await service(database).latestPromotedSnapshot())?.snapshotId,
        report.promotedSnapshotId,
      );
      expect(await database.queryTable('cdss_record_history'), isNotEmpty);
    },
  );

  test(
    'a native held packet commits completely while live source rows remain unchanged',
    () async {
      await expectLater(
        service(database).importBundle(conflictingBundle()),
        throwsA(isA<CdssImportHeldException>()),
      );
      await database.close();
      database = NativeCdssDatabase(factory: factory, databasePath: path);
      final hold = (await database.queryTable(
        'ingestion_run',
      )).singleWhere((r) => r['status'] == 'held_for_conflict_review');
      expect(
        (await service(database).loadHeldImportReviewEvidence(
          snapshotId: hold['snapshot_id'] as String,
        ))['schema'],
        'parkinsum.held-import-review-evidence/2',
      );
      expect(await database.queryTable('source_document'), isEmpty);
      expect(await database.queryTable('staging_observation'), hasLength(2));
      expect(await service(database).latestPromotedSnapshot(), isNull);
    },
  );

  test(
    'reviewed native activation commits one whole derived version and survives reopen',
    () async {
      final cdss = service(database);
      final held = await prepareOn(database, cdss);
      final preview = await cdss.previewReviewedImport(
        heldSnapshotId: held.snapshotId,
        decisionIds: [held.decisionId],
      );
      final heldRows = await _allTables(database);
      final committedBefore = factory.last!.committed;
      final result = await activate(cdss, preview);
      expect(factory.last!.committed, committedBefore + 1);
      await database.close();
      database = NativeCdssDatabase(factory: factory, databasePath: path);
      expect(
        (await service(database).latestPromotedSnapshot())?.snapshotId,
        result.promotedSnapshotId,
      );
      final fact = (await database.queryTable('resolved_fact')).single;
      expect(fact['chosen_observation_id'], 'b');
      expect(fact['value_num'], 10);
      expect(fact['manual_override'], 1);
      final projected = await CdssCatalogProjectionService(
        database: database,
        requireConsistentCatalog: true,
      ).projectFoodsWithAudit();
      expect(projected.foods.single.proteinG, 10);
      expect(projected.foods.single.nutrientObservationEvidence, hasLength(2));
      expect(
        projected.queryAudit['read_consistency'],
        'native_sqlite_transaction',
      );

      for (final table in [
        'staging_observation',
        'staging_resolved_fact',
        'staging_runtime_event',
      ]) {
        expect(await database.queryTable(table), heldRows[table]);
      }
      expect(
        (await database.queryTable(
          'ingestion_run',
        )).where((r) => r['status'] == 'held_for_conflict_review'),
        (heldRows['ingestion_run'] as List).where(
          (r) => r['status'] == 'held_for_conflict_review',
        ),
      );
      expect(
        (await database.queryTable(
          'conflict_audit_log',
        )).where((r) => r['snapshot_id'] == held.snapshotId),
        heldRows['conflict_audit_log'],
      );
      expect(
        (await database.queryTable(
          'drug_label_section',
        )).single['section_text'],
        'Unchanged source text',
      );
      expect(
        (await database.queryTable('runtime_event')).single['created_at'],
        123,
      );
      await expectLater(activate(service(database), preview), throwsStateError);
    },
  );

  test(
    'native failure after activation marker rolls back all original rows and histories',
    () async {
      await database.close();
      database = _FailingActivationReceiptDatabase(
        factory: factory,
        databasePath: path,
      );
      final cdss = service(database);
      final held = await prepareOn(database, cdss);
      final preview = await cdss.previewReviewedImport(
        heldSnapshotId: held.snapshotId,
        decisionIds: [held.decisionId],
      );
      final original = await _allTables(database);
      (database as _FailingActivationReceiptDatabase).rejectReceipt = true;
      await expectLater(activate(cdss, preview), throwsStateError);
      await database.close();
      database = NativeCdssDatabase(factory: factory, databasePath: path);
      expect(await _allTables(database), original);
      expect(await service(database).latestPromotedSnapshot(), isNull);
    },
  );

  test(
    'native snapshot read inside a write uses the transaction executor without a nested lock',
    () async {
      await database
          .runAtomicWrite(() async {
            await database.insertCountryDietProfile(before);
            final snapshot = await database.readFoodCatalogSnapshot();
            expect(snapshot.consistency, 'native_sqlite_transaction');
            expect(snapshot.holds, isEmpty);
          })
          .timeout(const Duration(seconds: 5));
    },
  );

  test('caught nested native errors still roll back earlier changes', () async {
    await database.insertCountryDietProfile(before);
    await expectLater(
      database.runAtomicWrite(() async {
        await database.insertCountryDietProfile(attempted);
        try {
          await database.runAtomicWrite<void>(
            () async => throw StateError('Synthetic nested failure'),
          );
        } on StateError {
          /* A handled error cannot commit earlier partial writes. */
        }
      }),
      throwsStateError,
    );
    expect(
      (await database.queryTable(
        'country_diet_profile',
      )).single['guideline_source'],
      before.guidelineSource,
    );
  });
}

Future<Map<String, Object?>> _allTables(NativeCdssDatabase database) async {
  final names = await database.queryTable('sqlite_master');
  return {
    for (final row in names.where((r) => r['type'] == 'table'))
      row['name'] as String: await database.queryTable(row['name'] as String),
  };
}

// The unmodified NativeCdssDatabase schema, SQL, zone and transaction code runs
// against a real temporary SQLite connection. This is not a Flutter plugin or
// physical-device test. No fake in-memory SQL engine is used.
class _SqliteFactory implements DatabaseFactory {
  _SqliteConnection? last;
  @override
  Future<Database> openDatabase(
    String path, {
    OpenDatabaseOptions? options,
  }) async {
    final exists = await File(path).exists();
    final database = await _SqliteConnection.open(path);
    last = database;
    if (!exists) await options?.onCreate?.call(database, options.version!);
    return database;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SqliteConnection implements Database {
  _SqliteConnection(this.process, this.lines);
  final Process process;
  final StreamIterator<String> lines;
  int sequence = 0, committed = 0, rolledBack = 0;
  bool closed = false;
  static Future<_SqliteConnection> open(String path) async {
    final process = await Process.start('/usr/bin/sqlite3', [
      '-bail',
      '-json',
      path,
    ]);
    process.stderr.transform(utf8.decoder).listen((message) {
      if (message.trim().isNotEmpty) throw StateError(message);
    });
    return _SqliteConnection(
      process,
      StreamIterator(
        process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
      ),
    );
  }

  Future<String> send(String sql) async {
    final marker = 'cdss_transaction_${++sequence}';
    process.stdin.writeln('$sql;\n.print $marker');
    await process.stdin.flush();
    final result = <String>[];
    while (await lines.moveNext().timeout(const Duration(seconds: 5))) {
      if (lines.current == marker) return result.join('\n');
      result.add(lines.current);
    }
    throw StateError('Temporary SQLite connection closed.');
  }

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async =>
      send(_bind(sql, arguments));
  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final raw = await send(
      'SELECT ${columns?.join(',') ?? '*'} FROM $table${where == null ? '' : ' WHERE ${_bind(where, whereArgs)}'}${orderBy == null ? '' : ' ORDER BY $orderBy'}',
    );
    return raw.isEmpty
        ? []
        : (jsonDecode(raw) as List)
              .map((r) => Map<String, Object?>.from(r as Map))
              .toList();
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction) action, {
    bool? exclusive,
  }) async {
    await send('BEGIN IMMEDIATE');
    try {
      final result = await action(_SqliteTransaction(this));
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
    if (closed) return;
    closed = true;
    await process.stdin.close();
    await process.exitCode;
    await lines.cancel();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SqliteTransaction implements Transaction {
  _SqliteTransaction(this.database);
  @override
  final _SqliteConnection database;
  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) => database.query(
    table,
    columns: columns,
    where: where,
    whereArgs: whereArgs,
    orderBy: orderBy,
  );
  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final raw = await database.send(
      'INSERT${conflictAlgorithm == ConflictAlgorithm.replace ? ' OR REPLACE' : ''} INTO $table (${values.keys.join(',')}) VALUES (${values.values.map(_literal).join(',')}); SELECT last_insert_rowid() AS result',
    );
    return ((jsonDecode(raw) as List).single['result'] as num).toInt();
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final raw = await database.send(
      'UPDATE $table SET ${values.entries.map((e) => '${e.key} = ${_literal(e.value)}').join(',')}${where == null ? '' : ' WHERE ${_bind(where, whereArgs)}'}; SELECT changes() AS result',
    );
    return ((jsonDecode(raw) as List).single['result'] as num).toInt();
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final raw = await database.send(
      'DELETE FROM $table${where == null ? '' : ' WHERE ${_bind(where, whereArgs)}'}; SELECT changes() AS result',
    );
    return ((jsonDecode(raw) as List).single['result'] as num).toInt();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String _literal(Object? value) => value == null
    ? 'NULL'
    : value is num
    ? '$value'
    : value is bool
    ? (value ? '1' : '0')
    : "'${value.toString().replaceAll("'", "''")}'";
String _bind(String sql, List<Object?>? values) {
  var index = 0;
  final result = sql.replaceAllMapped(
    RegExp(r'\?'),
    (_) => _literal(values![index++]),
  );
  if (index != (values?.length ?? 0)) {
    throw ArgumentError('SQL argument count.');
  }
  return result;
}
