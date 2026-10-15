@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/app_database_web.dart';
import 'package:parkinsum_companion/core/db/web_user_state_store.dart';
import 'package:parkinsum_companion/core/db/web_user_state_store_indexeddb.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/core/models/portable_data_restore.dart';
import 'package:parkinsum_companion/core/services/user_state_change_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var sequence = 0;
  late String databaseName;
  final connections = <IndexedDbWebUserStateStore>[];
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sequence += 1;
    databaseName =
        'parkinsum.synthetic.user-state.${DateTime.now().microsecondsSinceEpoch}.$sequence';
  });
  tearDown(() async {
    for (final connection in connections) {
      connection.close();
    }
    connections.clear();
    await _deleteOwnedDatabase(databaseName);
    web.window.localStorage.removeItem(
      'parkinsum.indexeddb.migrated.$databaseName',
    );
  });

  IndexedDbWebUserStateStore connect({
    void Function()? beforePublication,
    void Function()? afterWriteQueued,
    void Function()? afterPublication,
    WebUserStateLegacySnapshot Function()? readCurrentLegacy,
  }) {
    final store = IndexedDbWebUserStateStore(
      databaseName: databaseName,
      beforePublication: beforePublication,
      afterWriteQueued: afterWriteQueued,
      afterPublication: afterPublication,
      readCurrentLegacy: readCurrentLegacy,
    );
    connections.add(store);
    return store;
  }

  test(
    'real IndexedDB retains original keys and full aggregate across connection restart',
    () async {
      final profile = UserProfile.defaults().copyWith(displayLocale: 'zh-CN');
      SharedPreferences.setMockInitialValues({
        'db.user_profile': jsonEncode(profile.toJson()),
        'db.active_drugs': '["unresolved-drug"]',
      });
      final preferences = await SharedPreferences.getInstance();
      final old = _snapshot(preferences);
      final store = connect();
      final database = WebAppDatabase(userStateStore: store);
      await database.saveOnboarded(true);
      final completeState = await database.loadPortableRestoreState();
      store.close();
      final restarted = WebAppDatabase(userStateStore: connect());
      expect(
        (await restarted.loadPortableRestoreState()).canonicalJson,
        completeState.canonicalJson,
      );
      expect((await restarted.loadUserProfile()).displayLocale, 'zh-CN');
      expect(await restarted.loadActiveDrugIds(), ['unresolved-drug']);
      await preferences.reload();
      expect(_snapshot(preferences).canonicalJson, old.canonicalJson);
    },
  );

  test(
    'real IndexedDB stores a six MiB complete value without a localStorage data mirror',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final legacy = _snapshot(preferences);
      final store = connect();
      final initial = await store.read(legacy);
      final large = jsonEncode({
        'synthetic': List.filled(6 * 1024 * 1024, 'x').join(),
      });
      await store.write(
        large,
        expectedDocument: initial,
        legacy: legacy,
        authorize: () => true,
      );
      store.close();
      expect(await connect().read(legacy), large);
      await preferences.reload();
      expect(_snapshot(preferences).canonicalJson, legacy.canonicalJson);
      expect(preferences.getString('db.user_state.v1'), isNull);
    },
  );

  test(
    'queued write followed by actual transaction abort preserves entire prior envelope',
    () async {
      var abort = false;
      final store = connect(
        afterWriteQueued: () {
          if (abort) throw StateError('synthetic_abort_after_put');
        },
      );
      final legacy = _snapshot(await SharedPreferences.getInstance());
      final initial = await store.read(legacy);
      await store.write(
        'original',
        expectedDocument: initial,
        legacy: legacy,
        authorize: () => true,
      );
      abort = true;
      await expectLater(
        store.write(
          'must not publish',
          expectedDocument: 'original',
          legacy: legacy,
          authorize: () => true,
        ),
        throwsStateError,
      );
      expect(await connect().read(legacy), 'original');
    },
  );

  test(
    'real committed lost acknowledgment is recovered by existing whole-value readback',
    () async {
      var publications = 0;
      final store = connect(
        afterPublication: () {
          publications += 1;
          throw StateError('synthetic_lost_ack');
        },
      );
      final database = WebAppDatabase(userStateStore: store);
      await database.saveOnboarded(true);
      expect(await database.loadOnboarded(), isTrue);
      expect(publications, 1);
      expect(
        await WebAppDatabase(userStateStore: connect()).loadOnboarded(),
        isTrue,
      );
    },
  );

  test(
    'a sequential legacy write refuses future reads and writes without deleting either side',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final legacy = _snapshot(preferences);
      final store = connect();
      final before = await store.read(legacy);
      await store.write(
        'new complete aggregate',
        expectedDocument: before,
        legacy: legacy,
        authorize: () => true,
      );
      await preferences.setString('db.active_drugs', '["older-version-value"]');
      final changed = _snapshot(preferences);
      await expectLater(store.read(changed), throwsStateError);
      await expectLater(
        store.write(
          'must not overwrite',
          expectedDocument: 'new complete aggregate',
          legacy: changed,
          authorize: () => true,
        ),
        throwsStateError,
      );
      expect(await store.read(legacy), 'new complete aggregate');
      expect(
        preferences.getString('db.active_drugs'),
        '["older-version-value"]',
      );
    },
  );

  test(
    'surviving migration marker refuses resurrection after owned database deletion',
    () async {
      final legacy = _snapshot(await SharedPreferences.getInstance());
      final store = connect();
      final before = await store.read(legacy);
      await store.write(
        'current aggregate',
        expectedDocument: before,
        legacy: legacy,
        authorize: () => true,
      );
      store.close();
      await _deleteOwnedDatabase(databaseName);
      await expectLater(connect().read(legacy), throwsStateError);
    },
  );

  test(
    'stale expected value and expired dispatch authorization never overwrite current data',
    () async {
      final legacy = _snapshot(await SharedPreferences.getInstance());
      final store = connect();
      final before = await store.read(legacy);
      await store.write(
        'current',
        expectedDocument: before,
        legacy: legacy,
        authorize: () => true,
      );
      await expectLater(
        connect().write(
          'stale',
          expectedDocument: before,
          legacy: legacy,
          authorize: () => true,
        ),
        throwsStateError,
      );
      await expectLater(
        store.write(
          'expired',
          expectedDocument: 'current',
          legacy: legacy,
          authorize: () => false,
        ),
        throwsStateError,
      );
      expect(await store.read(legacy), 'current');
    },
  );

  test(
    'own change notification does not invalidate its sending receiver',
    () async {
      var changes = 0;
      final listener = externalUserStateChanges.listen((_) => changes += 1);
      addTearDown(listener.cancel);
      notifyUserStateChanged();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(changes, 0);
    },
  );

  test(
    'authorization expiring after commit is reported as expired without undoing original-owner data',
    () async {
      var authorized = true;
      final store = connect(afterPublication: () => authorized = false);
      final legacy = _snapshot(await SharedPreferences.getInstance());
      final before = await store.read(legacy);
      await expectLater(
        store.write(
          'committed original-owner value',
          expectedDocument: before,
          legacy: legacy,
          authorize: () => authorized,
        ),
        throwsStateError,
      );
      expect(await connect().read(legacy), 'committed original-owner value');
    },
  );

  test(
    'missing document replaced by an unknown key is rejected and raw envelope remains exact',
    () async {
      final legacy = _snapshot(await SharedPreferences.getInstance());
      final store = connect();
      await store.read(legacy);
      // Five fields and a valid null digest previously bypassed a length-only
      // check. This actual IndexedDB value omits the mandatory document field.
      final corrupted = jsonEncode({
        'schema': 'parkinsum.indexeddb-user-state/1',
        'legacyKeys': legacy.values,
        'legacyDigest': legacy.digest,
        'documentDigest': portableRestoreDigest(null),
        'unknownField': null,
      });
      expect(
        await _ownedRawEntry(databaseName, writeRaw: corrupted),
        corrupted,
      );
      await expectLater(store.read(legacy), throwsFormatException);
      await expectLater(
        store.write(
          'must not replace corrupted raw',
          expectedDocument: null,
          legacy: legacy,
          authorize: () => true,
        ),
        throwsFormatException,
      );
      expect(await _ownedRawEntry(databaseName), corrupted);
    },
  );

  test(
    'actual asynchronous IndexedDB reads and ordered mutations cannot self-contend for the Web Lock',
    () async {
      final database = WebAppDatabase(userStateStore: connect());
      await database.saveOnboarded(true);
      final values = await Future.wait<Object?>([
        database.loadMeals(),
        database.loadIntakes(),
        database.loadUserProfile(),
        database.loadPortableRestoreState(),
      ]);
      expect(values[0], isEmpty);
      expect(values[1], isEmpty);
      expect((values[2] as UserProfile).displayLocale, 'en-US');
      expect((values[3] as PortableDataRestoreState).json['onboarded'], isTrue);
      final ordered = await Future.wait<Object?>([
        database.saveOnboarded(false),
        database.loadOnboarded(),
        database.saveOnboarded(true),
        database.loadOnboarded(),
      ]);
      expect(ordered[1], isFalse);
      expect(ordered[3], isTrue);
    },
  );

  for (final phase in ['before_put', 'after_put_queued']) {
    test(
      'live legacy change $phase aborts the actual IndexedDB transaction and retains both old values',
      () async {
        const rawKey = 'flutter.db.active_drugs';
        expect(
          web.window.localStorage.getItem(rawKey),
          isNull,
          reason: 'Only a new disposable test key may be changed.',
        );
        addTearDown(() => web.window.localStorage.removeItem(rawKey));
        var armed = false;
        void legacyWrite() {
          if (armed) {
            web.window.localStorage.setItem(
              rawKey,
              jsonEncode('["synthetic_legacy_race"]'),
            );
          }
        }

        final store = connect(
          beforePublication: phase == 'before_put' ? legacyWrite : null,
          afterWriteQueued: phase == 'after_put_queued' ? legacyWrite : null,
          readCurrentLegacy: _liveBrowserSnapshot,
        );
        final legacy = _liveBrowserSnapshot();
        final before = await store.read(legacy);
        await store.write(
          'original aggregate',
          expectedDocument: before,
          legacy: legacy,
          authorize: () => true,
        );
        armed = true;
        await expectLater(
          store.write(
            'must not publish raced candidate',
            expectedDocument: 'original aggregate',
            legacy: legacy,
            authorize: () => true,
          ),
          throwsStateError,
        );
        final retained =
            jsonDecode((await _ownedRawEntry(databaseName))!) as Map;
        expect(retained['document'], 'original aggregate');
        expect(retained['legacyKeys'], legacy.values);
        expect(
          web.window.localStorage.getItem(rawKey),
          jsonEncode('["synthetic_legacy_race"]'),
        );
      },
    );
  }

  test(
    'legacy change after actual commit refuses success and preserves both versions',
    () async {
      const rawKey = 'flutter.db.active_drugs';
      expect(web.window.localStorage.getItem(rawKey), isNull);
      addTearDown(() => web.window.localStorage.removeItem(rawKey));
      final store = connect(
        afterPublication: () => web.window.localStorage.setItem(
          rawKey,
          jsonEncode('["synthetic_post_commit_legacy"]'),
        ),
        readCurrentLegacy: _liveBrowserSnapshot,
      );
      final legacy = _liveBrowserSnapshot();
      final before = await store.read(legacy);
      await expectLater(
        store.write(
          'actually committed candidate',
          expectedDocument: before,
          legacy: legacy,
          authorize: () => true,
        ),
        throwsStateError,
      );
      final retained = jsonDecode((await _ownedRawEntry(databaseName))!) as Map;
      expect(retained['document'], 'actually committed candidate');
      expect(
        web.window.localStorage.getItem(rawKey),
        jsonEncode('["synthetic_post_commit_legacy"]'),
      );
    },
  );
}

WebUserStateLegacySnapshot _snapshot(SharedPreferences preferences) =>
    WebUserStateLegacySnapshot({
      for (final key in webUserStateLegacyKeys) key: preferences.getString(key),
    });

WebUserStateLegacySnapshot _liveBrowserSnapshot() =>
    WebUserStateLegacySnapshot({
      for (final key in webUserStateLegacyKeys)
        key: switch (web.window.localStorage.getItem('flutter.$key')) {
          final String raw => jsonDecode(raw) as String,
          null => null,
        },
    });

/// Direct corruption inspection is limited to this test's owned database. It
/// deliberately bypasses the production decoder without repairing its value.
Future<String?> _ownedRawEntry(String name, {String? writeRaw}) async {
  if (!name.startsWith('parkinsum.synthetic.user-state.')) {
    throw StateError('Refuse accessing an unowned browser database.');
  }
  final opened = Completer<web.IDBDatabase>();
  final request = web.window.indexedDB.open(name, 1);
  request.onsuccess = ((web.Event _) => opened.complete(
    request.result as web.IDBDatabase,
  )).toJS;
  request.onerror = ((web.Event _) => opened.completeError(
    StateError('synthetic_open_failed'),
  )).toJS;
  final database = await opened.future;
  try {
    final completed = Completer<String?>();
    String? value;
    final transaction = database.transaction(
      'documents'.toJS,
      writeRaw == null ? 'readonly' : 'readwrite',
    );
    transaction.oncomplete = ((web.Event _) => completed.complete(value)).toJS;
    transaction.onabort = ((web.Event _) => completed.completeError(
      StateError('synthetic_raw_transaction_aborted'),
    )).toJS;
    final objectStore = transaction.objectStore('documents');
    if (writeRaw != null) objectStore.put(writeRaw.toJS, 'user_state'.toJS);
    final read = objectStore.get('user_state'.toJS);
    read.onsuccess = ((web.Event _) {
      final result = read.result;
      value = result == null ? null : (result as JSString).toDart;
    }).toJS;
    return await completed.future;
  } finally {
    database.close();
  }
}

Future<void> _deleteOwnedDatabase(String name) async {
  if (!name.startsWith('parkinsum.synthetic.user-state.')) {
    throw StateError('Refuse deleting an unowned browser database.');
  }
  final completed = Completer<void>();
  final request = web.window.indexedDB.deleteDatabase(name);
  request.onsuccess = ((web.Event _) {
    if (!completed.isCompleted) completed.complete();
  }).toJS;
  request.onerror = ((web.Event _) {
    if (!completed.isCompleted) {
      completed.completeError(StateError('synthetic_delete_failed'));
    }
  }).toJS;
  request.onblocked = ((web.Event _) {
    if (!completed.isCompleted) {
      completed.completeError(StateError('synthetic_delete_blocked'));
    }
  }).toJS;
  await completed.future;
}
