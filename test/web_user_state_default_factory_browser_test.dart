// ignore_for_file: avoid_print

@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/app_database_web.dart';
import 'package:parkinsum_companion/core/db/web_user_state_store.dart';
import 'package:parkinsum_companion/core/db/web_user_state_store_factory.dart';
import 'package:parkinsum_companion/core/db/web_user_state_store_indexeddb.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/portable_data_restore.dart';
import 'package:parkinsum_companion/core/models/recoverable_user_event.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/core/services/origin_storage_coordination.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';
import 'package:web/web.dart' as web;

const _defaultDatabaseName = 'parkinsum.personal-records.v1';
const _ownedPrefix = 'parkinsum.synthetic.default-factory.';
const _pulseKey = 'parkinsum.user_state.revision.v1';
// The first actual run accepted the 8 MiB UTF-16 cap without native quota
// failure. This owned, initially empty test origin permits a 12 MiB retry.
const _maximumFillBytes = 12 * 1024 * 1024;
const _maximumFillAttempts = 10000;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Register the official Web adapter, as browser unit tests do not execute
  // the generated application registrant. No preference mock is installed.
  SharedPreferencesPlugin.registerWith(null);

  test(
    'unaltered production default factory migrates real six strings and refuses live legacy rewrites while preserving both complete sides',
    () async {
      // Only this strict initially empty headless unit-test origin authorizes
      // ownership of the otherwise production-named database. No user browser
      // origin or pre-existing database may enter this test.
      final scope = await _FreshOwnedOrigin.acquire(
        'default',
        allowDefault: true,
      );
      final original = _SyntheticOriginal();
      await scope.seedLegacy(original.legacyValues);
      final frozen = await scope.legacySnapshot();
      expect(
        frozen.canonicalJson,
        WebUserStateLegacySnapshot(original.legacyValues).canonicalJson,
      );
      final factoryChoice = createWebUserStateStore();
      expect(factoryChoice, isA<IndexedDbWebUserStateStore>());
      final store = factoryChoice! as IndexedDbWebUserStateStore;
      expect(store.databaseName, _defaultDatabaseName);
      scope.claimConnection(store);

      expect(
        await withOriginStorageLock('user_state.v1', () => store.read(frozen)),
        original.legacyValues['db.user_state.v1'],
      );
      final database = WebAppDatabase(userStateStore: store);
      await _requireCompleteState(database, original.state);
      final rawBefore = await scope.readEnvelope(store.databaseName);
      final documentBefore = _requireEnvelope(rawBefore, frozen);
      expect(
        PortableDataRestoreState(documentBefore).canonicalJson,
        original.state.canonicalJson,
      );
      expect(
        web.window.localStorage.getItem(scope.markerFor(store.databaseName)),
        '1',
      );

      final changedMeals = jsonEncode([
        original.meal
            .copyWith(title: 'Synthetic older writer changed meal')
            .toJson(),
      ]);
      await scope.writeLegacy('db.meals', changedMeals);
      final changed = await scope.legacySnapshot();
      expect(changed.values, {...frozen.values, 'db.meals': changedMeals});
      expect(changed.digest, isNot(frozen.digest));
      final candidate = original.candidateState;
      final conflict = isA<StateError>().having(
        (error) => error.message,
        'failure reason',
        'web_user_state_legacy_writer_conflict',
      );
      // Public store calls retain the required origin-lock protocol and pass
      // the original witness. Only the factory's real raw reader can detect
      // the intervening actual localStorage write in these calls.
      await expectLater(
        withOriginStorageLock('user_state.v1', () => store.read(frozen)),
        throwsA(conflict),
      );
      await expectLater(
        withOriginStorageLock(
          'user_state.v1',
          () => store.write(
            candidate.canonicalJson,
            expectedDocument: original.legacyValues['db.user_state.v1'],
            legacy: frozen,
            authorize: () => true,
          ),
        ),
        throwsA(conflict),
      );
      expect(await scope.readEnvelope(store.databaseName), rawBefore);
      expect(
        (await scope.legacySnapshot()).canonicalJson,
        changed.canonicalJson,
      );
      _requireRealRawLegacy(changed);
      print(
        'WEB_DEFAULT_FACTORY_LIVE_LEGACY ${jsonEncode({'actualPlatform': SharedPreferencesStorePlatform.instance.runtimeType.toString(), 'unalteredProductionFactoryUsed': true, 'customLiveReaderInjected': false, 'allSixOriginalStringsRetainedInEnvelope': true, 'defaultDatabaseInitiallyAbsentAndOwnedByFreshTest': true, 'originalEnvelopeSha256': portableRestoreBytesDigest(rawBefore), 'originalLegacySha256': frozen.digest, 'newActualLegacySha256': changed.digest, 'wholeOriginalIndexedDbAndChangedLegacyBothRetained': true, 'readAndWriteRefused': true, 'actualTwoTabExecution': false})}',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'actual localStorage quota refuses the migration marker before new personal records and removal of only owned filler permits retry',
    () async {
      final scope = await _FreshOwnedOrigin.acquire('marker-quota');
      final original = _SyntheticOriginal();
      await scope.seedLegacy(original.legacyValues);
      final frozen = await scope.legacySnapshot();
      final name = scope.ownedDatabaseName;
      final store = scope.connect(name);
      _OwnedQuotaFill fill;
      try {
        fill = _OwnedQuotaFill.saturate(scope);
      } on _NativeQuotaHold catch (hold) {
        _recordHold('marker', hold.message);
        return;
      }
      final markerKey = scope.markerFor(name);
      expect(web.window.localStorage.getItem(markerKey), isNull);
      Object? markerFailure;
      try {
        await withOriginStorageLock('user_state.v1', () => store.read(frozen));
      } catch (error) {
        markerFailure = error;
      }
      if (markerFailure == null) {
        _recordHold(
          'marker',
          'Native quota did not reliably refuse the marker; no candidate mutation was attempted.',
        );
        return;
      }
      final refusedMarker = isA<StateError>().having(
        (error) => error.message,
        'failure reason',
        'web_user_state_migration_marker_unavailable',
      );
      expect(markerFailure, refusedMarker);
      final rawMigration = await scope.readEnvelope(name);
      final migrationDocument = _requireEnvelope(rawMigration, frozen);
      expect(
        portableRestoreCanonicalJson(migrationDocument),
        original.state.canonicalJson,
      );
      expect(
        (jsonDecode(rawMigration) as Map)['document'],
        original.legacyValues['db.user_state.v1'],
      );
      expect(web.window.localStorage.getItem(markerKey), isNull);

      final database = WebAppDatabase(userStateStore: store);
      await expectLater(
        database.saveMeals([original.meal, original.newMeal]),
        throwsA(refusedMarker),
      );
      expect(
        await scope.readEnvelope(name),
        rawMigration,
        reason:
            'No new row, changed profile, history or receipt may publish after marker refusal.',
      );
      expect(
        (await scope.legacySnapshot()).canonicalJson,
        frozen.canonicalJson,
      );
      _requireRealRawLegacy(frozen);
      expect(web.window.localStorage.getItem(_pulseKey), isNull);
      scope.removeOwnedRaw(fill.key);

      await _requireCompleteState(database, original.state);
      expect(web.window.localStorage.getItem(markerKey), '1');
      await database.saveMeals([original.meal, original.newMeal]);
      await _requireCompleteState(database, original.candidateState);
      store.close();
      final restarted = WebAppDatabase(userStateStore: scope.connect(name));
      await _requireCompleteState(restarted, original.candidateState);
      expect(
        (await scope.legacySnapshot()).canonicalJson,
        frozen.canonicalJson,
      );
      print(
        'WEB_ACTUAL_MARKER_QUOTA ${jsonEncode({...fill.evidence, 'nativeMarkerRefusalObserved': true, 'originalCompleteStateSha256': original.state.digest, 'originalMigrationEnvelopeSha256': portableRestoreBytesDigest(rawMigration), 'newPersonalStateRefusedAndNotPublished': true, 'allSixRawOriginalLegacyStringsRetained': true, 'retryAfterRemovingOnlyOwnedFillerSucceeded': true, 'reopenedCompleteCandidateSha256': original.candidateState.digest, 'localStorageDataMirror': false})}',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'actual quota failure of the legacy notification pulse does not roll back or repeat a committed complete IndexedDB state',
    () async {
      final scope = await _FreshOwnedOrigin.acquire('pulse-quota');
      final original = _SyntheticOriginal();
      await scope.seedLegacy(original.legacyValues);
      final frozen = await scope.legacySnapshot();
      final name = scope.ownedDatabaseName;
      var publicationCount = 0;
      final store = scope.connect(
        name,
        afterPublication: () => publicationCount++,
      );
      final database = WebAppDatabase(userStateStore: store);
      await _requireCompleteState(database, original.state);
      expect(web.window.localStorage.getItem(scope.markerFor(name)), '1');
      expect(web.window.localStorage.getItem(_pulseKey), isNull);
      final rawBefore = await scope.readEnvelope(name);
      _OwnedQuotaFill fill;
      try {
        fill = _OwnedQuotaFill.saturate(scope);
      } on _NativeQuotaHold catch (hold) {
        _recordHold('pulse', hold.message);
        return;
      }
      Object? nativePulseFailure;
      try {
        // The same native key and fixed payload size as production. A failed
        // setItem is atomic and leaves this previously absent key absent.
        scope.writeOwnedRaw(_pulseKey, '0' * 20);
      } catch (error) {
        nativePulseFailure = error;
      }
      if (nativePulseFailure == null) {
        scope.removeOwnedRaw(_pulseKey);
        _recordHold(
          'pulse',
          'The native API accepted the fixed-size pulse despite saturation; no notification failure is claimed.',
        );
        return;
      }
      expect(
        _isNativeQuotaFailure(nativePulseFailure),
        isTrue,
        reason: 'Other native failures are not quota evidence.',
      );
      expect(web.window.localStorage.getItem(_pulseKey), isNull);
      final fillBefore = web.window.localStorage.getItem(fill.key);
      final originalDebugPrint = debugPrint;
      var pulseFailureDiagnosticCount = 0;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message == 'WebUserState: legacy change pulse unavailable') {
          pulseFailureDiagnosticCount++;
        }
        originalDebugPrint(message, wrapWidth: wrapWidth);
      };
      addTearDown(() {
        debugPrint = originalDebugPrint;
      });
      await database.saveMeals([original.meal, original.newMeal]);
      expect(publicationCount, 1);
      expect(
        pulseFailureDiagnosticCount,
        1,
        reason:
            'The actual production notification catch must observe native pulse failure; omitting notification cannot pass.',
      );
      expect(
        web.window.localStorage.getItem(_pulseKey),
        isNull,
        reason:
            'Production notification attempted the real fixed-size key; quota refusal must not become a data failure.',
      );
      expect(web.window.localStorage.getItem(fill.key), fillBefore);
      expect(web.window.localStorage.getItem(scope.markerFor(name)), '1');
      await _requireCompleteState(database, original.candidateState);
      final rawAfter = await scope.readEnvelope(name);
      expect(rawAfter, isNot(rawBefore));
      expect(
        PortableDataRestoreState(
          _requireEnvelope(rawAfter, frozen),
        ).canonicalJson,
        original.candidateState.canonicalJson,
      );
      store.close();
      final restarted = WebAppDatabase(userStateStore: scope.connect(name));
      await _requireCompleteState(restarted, original.candidateState);
      expect(await scope.readEnvelope(name), rawAfter);
      expect(publicationCount, 1);
      expect(pulseFailureDiagnosticCount, 1);
      expect(
        (await scope.legacySnapshot()).canonicalJson,
        frozen.canonicalJson,
      );
      _requireRealRawLegacy(frozen);
      print(
        'WEB_ACTUAL_NOTIFICATION_PULSE_QUOTA ${jsonEncode({...fill.evidence, 'nativePulseSetItemFailure': nativePulseFailure.toString(), 'actualProductionPulseFailureDiagnosticCount': pulseFailureDiagnosticCount, 'markerAlreadySuccessfulBeforeSaturation': true, 'productionPulseStillAbsentAfterPublication': true, 'completeCandidateSha256': original.candidateState.digest, 'completeEnvelopeAfterPublicationSha256': portableRestoreBytesDigest(rawAfter), 'publicationCount': publicationCount, 'noRollbackOrDuplicatePublication': true, 'newActualConnectionVerifiedCompleteCandidate': true, 'broadcastChannelThrowCovered': false, 'actualTwoTabExecution': false})}',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _SyntheticOriginal {
  _SyntheticOriginal() {
    final time = DateTime.utc(2026, 10, 1, 12);
    final food = FoodItem(
      id: 'synthetic-source-food',
      name: 'Synthetic unknown food',
      category: FoodCategory.other,
      proteinG: 999,
      carbsG: 10,
      fatG: 1,
      fiberG: 2,
      sodiumMg: 3,
      missingNutrientFields: const {'proteinG'},
      sourceSystem: 'SYNTHETIC_TEST',
    );
    meal = Meal(
      id: 'synthetic-original-meal',
      title: 'Synthetic original meal',
      eatenAt: time,
      recordedAt: time.add(const Duration(minutes: 5)),
      items: [MealItem.fromFood(food: food, quantityFactor: 1.25)],
    );
    final intake = Intake(
      id: 'synthetic-original-intake',
      drugId: 'synthetic-original-drug',
      takenAt: time,
      dosageNote: 'Synthetic unknown dose; no clinical meaning.',
    );
    final revisions = [
      RecoverableUserEventRevision.create(
        operationId: 'synthetic_original_meal',
        eventType: RecoverableUserEventType.meal,
        recordId: meal.id,
        mutationType: RecoverableUserEventMutationType.create,
        beforePayload: null,
        afterPayload: meal.toJson(),
        recordedAtUtc: time,
        source: 'synthetic_default_factory_test',
      ),
      RecoverableUserEventRevision.create(
        operationId: 'synthetic_original_intake',
        eventType: RecoverableUserEventType.intake,
        recordId: intake.id,
        mutationType: RecoverableUserEventMutationType.create,
        beforePayload: null,
        afterPayload: intake.toJson(),
        recordedAtUtc: time,
        source: 'synthetic_default_factory_test',
      ),
    ];
    final profile = UserProfile.defaults().copyWith(
      timezone: 'Etc/UTC',
      displayLocale: 'zh-CN',
    );
    final json = <String, Object?>{
      'schemaVersion': 3,
      'onboarded': true,
      'profile': profile.toJson(),
      'activeDrugIds': [intake.drugId],
      'intakes': [intake.toJson()],
      'meals': [meal.toJson()],
      'eventHistory': revisions.map((row) => row.toJson()).toList(),
    };
    state = PortableDataRestoreState(json);
    // Distinct whitespace is intentional: migration must retain all six
    // original String values, not only a semantically reconstructed document.
    legacyValues = Map<String, String>.unmodifiable({
      'db.active_drugs': const JsonEncoder.withIndent(
        ' ',
      ).convert(json['activeDrugIds']),
      'db.intakes': const JsonEncoder.withIndent(' ').convert(json['intakes']),
      'db.meals': const JsonEncoder.withIndent(' ').convert(json['meals']),
      'db.meta.onboarded': 'true',
      'db.user_profile': const JsonEncoder.withIndent(
        ' ',
      ).convert(json['profile']),
      'db.user_state.v1': const JsonEncoder.withIndent('  ').convert(json),
    });
  }

  late final Meal meal;
  late final PortableDataRestoreState state;
  late final Map<String, String> legacyValues;
  Meal get newMeal => meal.copyWith(
    id: 'synthetic-new-meal',
    title: 'Synthetic new complete row',
  );
  PortableDataRestoreState get candidateState => PortableDataRestoreState({
    ...state.json,
    'meals': [meal.toJson(), newMeal.toJson()],
  });
}

class _FreshOwnedOrigin {
  _FreshOwnedOrigin(
    this.label,
    this.allowDefault,
    this.originalOriginMetadata,
    this.originalDatabaseMetadata,
  );

  final String label;
  final bool allowDefault;
  final Map<String, String> originalOriginMetadata;
  final List<String> originalDatabaseMetadata;
  final connections = <IndexedDbWebUserStateStore>[];
  final claimedDatabaseNames = <String>{};
  final expectedOwnedRaw = <String, String>{};
  late final SharedPreferences preferences;
  late final String ownedDatabaseName =
      '$_ownedPrefix$label.${DateTime.now().microsecondsSinceEpoch}';
  late final String fillKey = '$ownedDatabaseName.quota-fill';

  static Future<_FreshOwnedOrigin> acquire(
    String label, {
    bool allowDefault = false,
  }) async {
    expect(['localhost', '127.0.0.1', '[::1]'], contains(Uri.base.host));
    expect(
      web.window.navigator.userAgent,
      contains('HeadlessChrome'),
      reason:
          'Only a disposable headless browser unit-test origin is authorized.',
    );
    // Refuse on key count before reading any unknown stored value. The exact
    // metadata snapshot below is therefore the already-proven empty map.
    expect(
      web.window.localStorage.length,
      0,
      reason: 'Never inspect or remove pre-existing origin data.',
    );
    final metadata = _originMetadata();
    expect(
      metadata,
      isEmpty,
      reason: 'Never remove pre-existing origin data to pass this guard.',
    );
    final databases = await _databaseMetadataNames();
    expect(
      databases,
      isEmpty,
      reason: 'Even the default database is owned only when initially absent.',
    );
    final scope = _FreshOwnedOrigin(label, allowDefault, metadata, databases);
    addTearDown(scope.cleanup);
    expect(
      SharedPreferencesStorePlatform.instance,
      isA<SharedPreferencesPlugin>(),
    );
    expect(
      SharedPreferencesStorePlatform.instance,
      isNot(isA<InMemorySharedPreferencesStore>()),
    );
    scope.preferences = await SharedPreferences.getInstance();
    await scope.preferences.reload();
    expect(scope.preferences.getKeys(), isEmpty);
    print(
      'WEB_FRESH_DEFAULT_FACTORY_ORIGIN ${jsonEncode({'case': label, 'actualPlatform': SharedPreferencesStorePlatform.instance.runtimeType.toString(), 'officialPluginActualGetInstanceAndReload': true, 'initialOriginMetadataEmpty': true, 'initialDatabaseMetadataEmpty': true, 'headlessLoopbackOnly': true, 'defaultDatabaseOwnedProtocolAuthorized': allowDefault})}',
    );
    return scope;
  }

  void claimConnection(IndexedDbWebUserStateStore store) {
    final name = store.databaseName;
    if (!name.startsWith(_ownedPrefix) &&
        !(allowDefault && name == _defaultDatabaseName)) {
      throw StateError('synthetic_scope_refuses_unowned_database');
    }
    claimedDatabaseNames.add(name);
    connections.add(store);
  }

  IndexedDbWebUserStateStore connect(
    String name, {
    void Function()? afterPublication,
  }) {
    final store = IndexedDbWebUserStateStore(
      databaseName: name,
      afterPublication: afterPublication,
    );
    claimConnection(store);
    return store;
  }

  String markerFor(String name) => 'parkinsum.indexeddb.migrated.$name';

  Future<void> seedLegacy(Map<String, String> values) async {
    expect(values.length, webUserStateLegacyKeys.length);
    for (final key in webUserStateLegacyKeys) {
      await writeLegacy(key, values[key]!);
    }
    _requireRealRawLegacy(await legacySnapshot());
  }

  Future<void> writeLegacy(String key, String value) async {
    if (!webUserStateLegacyKeys.contains(key)) {
      throw StateError('synthetic_scope_refuses_unowned_preference_key');
    }
    expect(await preferences.setString(key, value), isTrue);
    final rawKey = 'flutter.$key';
    expectedOwnedRaw[rawKey] = jsonEncode(value);
    expect(web.window.localStorage.getItem(rawKey), expectedOwnedRaw[rawKey]);
  }

  Future<WebUserStateLegacySnapshot> legacySnapshot() async {
    await preferences.reload();
    return WebUserStateLegacySnapshot({
      for (final key in webUserStateLegacyKeys) key: preferences.getString(key),
    });
  }

  void writeOwnedRaw(String key, String value) {
    if (key != fillKey && key != _pulseKey) {
      throw StateError('synthetic_scope_refuses_unowned_raw_key');
    }
    web.window.localStorage.setItem(key, value);
    expectedOwnedRaw[key] = value;
  }

  void removeOwnedRaw(String key) {
    final expected = expectedOwnedRaw[key];
    if (expected == null || web.window.localStorage.getItem(key) != expected) {
      throw StateError(
        'synthetic_scope_refuses_removing_unowned_or_changed_key',
      );
    }
    web.window.localStorage.removeItem(key);
    expect(web.window.localStorage.getItem(key), isNull);
    expectedOwnedRaw.remove(key);
  }

  Future<String> readEnvelope(String name) async {
    if (!claimedDatabaseNames.contains(name)) {
      throw StateError('synthetic_scope_refuses_reading_unowned_database');
    }
    final opened = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(name);
    request.onupgradeneeded = ((web.Event _) {
      request.transaction?.abort();
    }).toJS;
    request.onsuccess = ((web.Event _) {
      final database = request.result as web.IDBDatabase;
      if (opened.isCompleted) {
        database.close();
      } else {
        opened.complete(database);
      }
    }).toJS;
    request.onerror = ((web.Event _) {
      if (!opened.isCompleted) {
        opened.completeError(StateError('synthetic_owned_read_open_failed'));
      }
    }).toJS;
    request.onblocked = ((web.Event _) {
      if (!opened.isCompleted) {
        opened.completeError(StateError('synthetic_owned_read_blocked'));
      }
    }).toJS;
    final database = await opened.future;
    try {
      final completed = Completer<String>();
      String? raw;
      final transaction = database.transaction('documents'.toJS, 'readonly');
      transaction.oncomplete = ((web.Event _) {
        if (completed.isCompleted) return;
        if (raw == null) {
          completed.completeError(
            StateError('synthetic_owned_envelope_absent'),
          );
        } else {
          completed.complete(raw);
        }
      }).toJS;
      transaction.onabort = ((web.Event _) {
        if (!completed.isCompleted) {
          completed.completeError(StateError('synthetic_owned_read_aborted'));
        }
      }).toJS;
      final read = transaction.objectStore('documents').get('user_state'.toJS);
      read.onsuccess = ((web.Event _) {
        try {
          final result = read.result;
          raw = result == null ? null : (result as JSString).toDart;
        } catch (_) {
          transaction.abort();
        }
      }).toJS;
      return await completed.future;
    } finally {
      database.close();
    }
  }

  Future<void> cleanup() async {
    for (final connection in connections) {
      connection.close();
    }
    // Database ownership was explicitly obtained from an empty metadata list.
    // This includes the default name only in the first authorized fresh case.
    for (final name in claimedDatabaseNames) {
      final done = Completer<void>();
      final request = web.window.indexedDB.deleteDatabase(name);
      request.onsuccess = ((web.Event _) {
        if (!done.isCompleted) done.complete();
      }).toJS;
      request.onerror = ((web.Event _) {
        if (!done.isCompleted) {
          done.completeError(StateError('synthetic_owned_delete_failed'));
        }
      }).toJS;
      request.onblocked = ((web.Event _) {
        if (!done.isCompleted) {
          done.completeError(StateError('synthetic_owned_delete_blocked'));
        }
      }).toJS;
      await done.future;
    }
    final databaseMetadataAfter = await _databaseMetadataNames();
    expect(databaseMetadataAfter, originalDatabaseMetadata);
    final originBeforeCleanup = _originMetadata();
    final ownedMarkers = {
      for (final name in claimedDatabaseNames) markerFor(name),
    };
    final unexpected = <String>[];
    for (final entry in originBeforeCleanup.entries) {
      final key = entry.key;
      final value = entry.value;
      final expected = expectedOwnedRaw[key];
      final knownMarker = ownedMarkers.contains(key) && value == '1';
      final knownPulse =
          key == _pulseKey && RegExp(r'^[0-9a-f]{20}$').hasMatch(value);
      if ((expected != null && value == expected) ||
          knownMarker ||
          knownPulse) {
        web.window.localStorage.removeItem(key);
        expect(web.window.localStorage.getItem(key), isNull);
      } else {
        // Preserve unknown keys/values rather than clear or hide a collision.
        unexpected.add(key);
      }
    }
    expect(
      unexpected,
      isEmpty,
      reason: 'Unexpected origin metadata was preserved.',
    );
    final originAfter = _originMetadata();
    expect(originAfter, originalOriginMetadata);
    for (final name in claimedDatabaseNames) {
      expect(web.window.localStorage.getItem(markerFor(name)), isNull);
    }
    print(
      'WEB_DEFAULT_FACTORY_OWNED_CLEANUP ${jsonEncode({'case': label, 'ownedDatabaseNames': claimedDatabaseNames.toList()..sort(), 'databaseMetadataBefore': originalDatabaseMetadata, 'databaseMetadataAfter': databaseMetadataAfter, 'originMetadataBeforeSha256': portableRestoreDigest(originalOriginMetadata), 'originMetadataAfterSha256': portableRestoreDigest(originAfter), 'exactOriginalOriginMetadataRestored': true, 'ownedDatabasesAndMarkersReadBackAbsent': true, 'noUnknownKeyCleared': true})}',
    );
  }
}

class _OwnedQuotaFill {
  _OwnedQuotaFill(
    this.key,
    this.accountingBytes,
    this.attempts,
    this.nativeQuotaFailures,
  );
  final String key;
  final int accountingBytes;
  final int attempts;
  final int nativeQuotaFailures;

  Map<String, Object?> get evidence => {
    'quotaMethod': 'single_owned_ascii_key_native_setItem_binary_saturation',
    'fillUtf16KeyAndValueAccountingBytes': accountingBytes,
    'fillAccountingGuardBytes': _maximumFillBytes,
    'nativeSetItemAttempts': attempts,
    'attemptGuard': _maximumFillAttempts,
    'observedNativeQuotaFailures': nativeQuotaFailures,
    'windowStorageApiReplaced': false,
  };

  static _OwnedQuotaFill saturate(_FreshOwnedOrigin scope) {
    final key = scope.fillKey;
    expect(web.window.localStorage.getItem(key), isNull);
    // ASCII is at most this many UTF-8 bytes and exactly twice this many
    // UTF-16 accounting bytes. Include the single key in the conservative cap.
    final maximumCharacters = _maximumFillBytes ~/ 2 - key.length;
    if (maximumCharacters <= 0) {
      throw StateError('synthetic_quota_key_exceeds_guard');
    }
    final source = 'x' * maximumCharacters;
    var attempts = 0;
    var quotaFailures = 0;
    bool putLength(int length) {
      if (++attempts > _maximumFillAttempts ||
          length < 0 ||
          2 * (key.length + length) > _maximumFillBytes) {
        throw StateError('synthetic_quota_attempt_or_bytes_guard_exceeded');
      }
      try {
        scope.writeOwnedRaw(key, source.substring(0, length));
        return true;
      } catch (error) {
        if (!_isNativeQuotaFailure(error)) rethrow;
        quotaFailures++;
        return false;
      }
    }

    if (putLength(maximumCharacters)) {
      throw const _NativeQuotaHold(
        'No native QuotaExceededError within the conservative 12 MiB owned fill bound.',
      );
    }
    if (!putLength(0)) {
      throw const _NativeQuotaHold(
        'Native quota could not allocate the owned filler key; stable saturation was not established.',
      );
    }
    var lower = 0;
    var upper = maximumCharacters;
    while (lower + 1 < upper) {
      final middle = (lower + upper) ~/ 2;
      if (putLength(middle)) {
        lower = middle;
      } else {
        upper = middle;
      }
    }
    expect(
      putLength(lower + 1),
      isFalse,
      reason: 'Require a real native failure at the first extra character.',
    );
    expect(web.window.localStorage.getItem(key)!.length, lower);
    expect(attempts, lessThanOrEqualTo(_maximumFillAttempts));
    final bytes = 2 * (key.length + lower);
    expect(bytes, lessThanOrEqualTo(_maximumFillBytes));
    return _OwnedQuotaFill(key, bytes, attempts, quotaFailures);
  }
}

class _NativeQuotaHold implements Exception {
  const _NativeQuotaHold(this.message);
  final String message;
}

bool _isNativeQuotaFailure(Object error) =>
    RegExp(r'\bQuotaExceededError\b').hasMatch(error.toString());

void _recordHold(String stage, String reason) {
  final message = 'HOLD: real $stage quota failure is unqualified: $reason';
  print(
    'WEB_NATIVE_QUOTA_HOLD ${jsonEncode({'stage': stage, 'reason': reason})}',
  );
  markTestSkipped(message);
}

Future<void> _requireCompleteState(
  WebAppDatabase database,
  PortableDataRestoreState expected,
) async {
  final observed = await database.loadPortableRestoreState();
  expect(observed.canonicalJson, expected.canonicalJson);
  expect(observed.digest, expected.digest);
  final expectedJson = expected.json;
  expect(
    (await database.loadMeals()).map((row) => row.toJson()).toList(),
    expectedJson['meals'],
  );
  expect(
    (await database.loadIntakes()).map((row) => row.toJson()).toList(),
    expectedJson['intakes'],
  );
  expect(
    (await database.loadRecoverableUserEventHistory()).reversed
        .map((row) => row.toJson())
        .toList(),
    expectedJson['eventHistory'],
  );
  expect((await database.loadUserProfile()).toJson(), expectedJson['profile']);
  expect(await database.loadActiveDrugIds(), expectedJson['activeDrugIds']);
  expect(await database.loadOnboarded(), expectedJson['onboarded']);
  expect(
    await database.loadPortableRestoreReceipt(ownerScope: 'local_user'),
    isNull,
  );
}

Map<String, Object?> _requireEnvelope(
  String raw,
  WebUserStateLegacySnapshot legacy,
) {
  final envelope = Map<String, Object?>.from(jsonDecode(raw) as Map);
  expect(envelope.keys.toSet(), {
    'schema',
    'legacyKeys',
    'legacyDigest',
    'document',
    'documentDigest',
  });
  expect(envelope['schema'], 'parkinsum.indexeddb-user-state/1');
  expect(envelope['legacyKeys'], legacy.values);
  expect(envelope['legacyDigest'], legacy.digest);
  final document = envelope['document'] as String;
  expect(envelope['documentDigest'], portableRestoreDigest(document));
  return Map<String, Object?>.from(jsonDecode(document) as Map);
}

void _requireRealRawLegacy(WebUserStateLegacySnapshot legacy) {
  for (final key in webUserStateLegacyKeys) {
    expect(
      web.window.localStorage.getItem('flutter.$key'),
      jsonEncode(legacy.values[key]),
    );
  }
}

Map<String, String> _originMetadata() {
  final storage = web.window.localStorage;
  final result = <String, String>{};
  for (var index = 0; index < storage.length; index++) {
    final key = storage.key(index);
    if (key == null) throw StateError('synthetic_origin_metadata_changed');
    final value = storage.getItem(key);
    if (value == null) throw StateError('synthetic_origin_metadata_changed');
    result[key] = value;
  }
  return Map<String, String>.unmodifiable(result);
}

Future<List<String>> _databaseMetadataNames() async {
  final metadata = (await web.window.indexedDB.databases().toDart).toDart;
  final names = <String>[for (final database in metadata) database.name]
    ..sort();
  return List<String>.unmodifiable(names);
}
