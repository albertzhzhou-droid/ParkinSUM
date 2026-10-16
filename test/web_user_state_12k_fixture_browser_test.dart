// Machine-readable engineering witnesses intentionally use unbuffered stdout.
// ignore_for_file: avoid_print
@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/app_database_web.dart';
import 'package:parkinsum_companion/core/db/web_user_state_store.dart';
import 'package:parkinsum_companion/core/db/web_user_state_store_factory.dart';
import 'package:parkinsum_companion/core/db/web_user_state_store_indexeddb.dart';
import 'package:parkinsum_companion/core/models/portable_data_restore.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/engineering/personal_log_view_benchmark_fixture.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:web/web.dart' as web;

const _originalFixtureSha256 =
    '97db49a275871c8fd1592ff28318a77c0a67400d8390052c74346226b6534eba';
const _pulseKey = 'parkinsum.user_state.revision.v1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Browser unit tests do not execute the generated app plugin registrant.
  // Register the official locked Web backend; no preference mock is installed.
  SharedPreferencesPlugin.registerWith(null);

  test(
    'original 10000-meal and 2000-intake fixture survives complete production database writes and reopen',
    () async {
      // Metadata-only guard before obtaining any preferences or database value.
      // One known notification pulse may remain from another test in this same
      // disposable origin. Any other key or malformed pulse refuses execution.
      // No pre-existing value is deleted to make this initial guard pass.
      expect(['localhost', '127.0.0.1', '[::1]'], contains(Uri.base.host));
      final originalOriginMetadata = _guardedOriginMetadata();
      final originalPulse = originalOriginMetadata[_pulseKey];
      final originalDatabaseMetadata = await _databaseMetadataNames();
      expect(
        originalDatabaseMetadata,
        isEmpty,
        reason:
            'This isolated suite must not open or clean an existing database.',
      );
      expect(
        SharedPreferencesStorePlatform.instance,
        isNot(isA<InMemorySharedPreferencesStore>()),
      );
      final actualPreferencesPlatformType = SharedPreferencesStorePlatform
          .instance
          .runtimeType
          .toString();

      // Instantiating the default factory does not open its database. Inspect
      // and close it only; every actual operation below uses an owned name.
      final productionChoice = createWebUserStateStore();
      expect(productionChoice, isA<IndexedDbWebUserStateStore>());
      (productionChoice! as IndexedDbWebUserStateStore).close();

      final fixture = PersonalLogBenchmarkFixture.generate(10000);
      expect(PersonalLogBenchmarkFixture.seed, 31415926);
      expect(
        fixture.inputSha256,
        _originalFixtureSha256,
        reason: 'Reject changed fixture input before the first durable write.',
      );
      expect(fixture.meals, hasLength(10000));
      expect(fixture.intakes, hasLength(2000));

      // Freeze complete original metadata for every row before writing. These
      // canonical strings, individual hashes and collection hash cover every
      // field, including nulls, missingness and deliberately invalid quantities.
      final mealMetadata = List<String>.unmodifiable(
        fixture.meals.map((row) => portableRestoreCanonicalJson(row.toJson())),
      );
      final intakeMetadata = List<String>.unmodifiable(
        fixture.intakes.map(
          (row) => portableRestoreCanonicalJson(row.toJson()),
        ),
      );
      final mealPins = List<String>.unmodifiable(
        mealMetadata.map(_bytesDigest),
      );
      final intakePins = List<String>.unmodifiable(
        intakeMetadata.map(_bytesDigest),
      );
      final beforeWriteWitness = <String, Object?>{
        'stage': 'fixture_pinned_before_first_database_write',
        'fixtureSha256': fixture.inputSha256,
        'actualNonMockPreferencesPlatformType': actualPreferencesPlatformType,
        'originalOriginMetadataSha256': _bytesDigest(
          portableRestoreCanonicalJson(originalOriginMetadata),
        ),
        'parameters': fixture.parameters,
        'mealMetadataCollectionSha256': _bytesDigest(jsonEncode(mealMetadata)),
        'intakeMetadataCollectionSha256': _bytesDigest(
          jsonEncode(intakeMetadata),
        ),
        'allIndividualMealPinsSha256': _bytesDigest(jsonEncode(mealPins)),
        'allIndividualIntakePinsSha256': _bytesDigest(jsonEncode(intakePins)),
        'wholeRowMetadataPinnedCount':
            mealMetadata.length + intakeMetadata.length,
        'capturedUnknownMealCount': fixture.meals
            .where((row) => row.items.single.isNutrientMissing('proteinG'))
            .length,
        'invalidQuantityMealCount': fixture.meals
            .where((row) => row.items.single.quantityFactor == 0)
            .length,
        'reportedZeroMealCount': fixture.meals
            .where(
              (row) =>
                  row.items.single.proteinPer100g == 0 &&
                  !row.items.single.isNutrientMissing('proteinG'),
            )
            .length,
        'unknownRawSentinelProteinPer100gCount': fixture.meals
            .where(
              (row) =>
                  row.items.single.proteinPer100g == 999 &&
                  row.items.single.isNutrientMissing('proteinG'),
            )
            .length,
        'futureMealCount': fixture.meals
            .where(
              (row) => row.effectiveOccurredAt.isAfter(
                PersonalLogBenchmarkFixture.asOf,
              ),
            )
            .length,
        'intakesWithUnspecifiedDoseCount': fixture.intakes
            .where((row) => row.doseAmount == null && row.doseUnit == null)
            .length,
      };
      expect(beforeWriteWitness['capturedUnknownMealCount'], 1000);
      expect(beforeWriteWitness['invalidQuantityMealCount'], 1000);
      expect(beforeWriteWitness['reportedZeroMealCount'], 1000);
      expect(beforeWriteWitness['unknownRawSentinelProteinPer100gCount'], 1000);
      expect(beforeWriteWitness['futureMealCount'], 500);
      expect(beforeWriteWitness['intakesWithUnspecifiedDoseCount'], 2000);
      print(
        'WEB_USER_STATE_12K_BEFORE_WRITE ${jsonEncode(beforeWriteWitness)}',
      );

      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      expect(preferences.getKeys(), isEmpty);
      expect(
        SharedPreferencesStorePlatform.instance,
        isNot(isA<InMemorySharedPreferencesStore>()),
      );
      print(
        'WEB_USER_STATE_12K_ACTUAL_PLATFORM ${jsonEncode({'runtimeType': SharedPreferencesStorePlatform.instance.runtimeType.toString(), 'getInstanceAndReloadSucceeded': true, 'explicitPreferencesMockInstalled': false, 'actualPreferencesKeyCount': preferences.getKeys().length})}',
      );
      final legacyBefore = _legacySnapshot(preferences);
      final databaseName =
          'parkinsum.synthetic.user-state.12k.${DateTime.now().microsecondsSinceEpoch}';
      final connections = <IndexedDbWebUserStateStore>[];
      IndexedDbWebUserStateStore connect() {
        final store = IndexedDbWebUserStateStore(databaseName: databaseName);
        connections.add(store);
        return store;
      }

      addTearDown(() async {
        for (final connection in connections) {
          connection.close();
        }
        await _deleteOwnedDatabase(databaseName);
        final databaseMetadataAfter = await _databaseMetadataNames();
        expect(databaseMetadataAfter, isNot(contains(databaseName)));
        expect(databaseMetadataAfter, originalDatabaseMetadata);
        final markerKey = 'parkinsum.indexeddb.migrated.$databaseName';
        final marker = web.window.localStorage.getItem(markerKey);
        expect(
          marker,
          anyOf(isNull, '1'),
          reason: 'Do not remove an unexpected value even at an owned marker.',
        );
        web.window.localStorage.removeItem(markerKey);
        expect(web.window.localStorage.getItem(markerKey), isNull);
        // Refuse unexpected origin content before restoring the small pulse.
        // Restore its original value, or remove only the pulse created here.
        _guardedOriginMetadata();
        if (originalPulse == null) {
          web.window.localStorage.removeItem(_pulseKey);
        } else {
          web.window.localStorage.setItem(_pulseKey, originalPulse);
        }
        final restoredOriginMetadata = _guardedOriginMetadata();
        expect(restoredOriginMetadata, originalOriginMetadata);
        print(
          'WEB_USER_STATE_12K_CLEANUP ${jsonEncode({'ownedDatabaseAbsentAfterDelete': !databaseMetadataAfter.contains(databaseName), 'ownedMigrationMarkerAbsent': web.window.localStorage.getItem(markerKey) == null, 'databaseMetadataBefore': originalDatabaseMetadata, 'databaseMetadataAfter': databaseMetadataAfter, 'originMetadataBeforeSha256': _bytesDigest(portableRestoreCanonicalJson(originalOriginMetadata)), 'originMetadataAfterSha256': _bytesDigest(portableRestoreCanonicalJson(restoredOriginMetadata)), 'originalPulsePresent': originalPulse != null, 'originalOriginMetadataRestoredExactly': true})}',
        );
      });

      final store = connect();
      final database = WebAppDatabase(userStateStore: store);
      expect(database.userStateBackendId, contains('IndexedDB'));
      final initialState = await database.loadPortableRestoreState();
      expect(initialState.recordIds['meals.json'], isEmpty);
      expect(initialState.recordIds['intakes.json'], isEmpty);
      final profile = UserProfile.defaults().copyWith(
        timezone: 'Etc/UTC',
        displayLocale: 'en-US',
      );
      await database.saveUserProfile(profile);
      await database.saveMeals(fixture.meals);
      await database.saveIntakes(fixture.intakes);

      final expectedState = PortableDataRestoreState({
        ...initialState.json,
        'profile': profile.toJson(),
        'meals': mealMetadata.map(jsonDecode).toList(growable: false),
        'intakes': intakeMetadata.map(jsonDecode).toList(growable: false),
      });
      final saved = await database.loadPortableRestoreState();
      expect(saved.canonicalJson, expectedState.canonicalJson);
      expect(saved.recordIds['meals.json'], hasLength(10000));
      expect(saved.recordIds['intakes.json'], hasLength(2000));
      expect(saved.json['eventHistory'], initialState.json['eventHistory']);
      await _requireWholeRows(
        database,
        mealMetadata,
        intakeMetadata,
        mealPins,
        intakePins,
      );
      await preferences.reload();
      expect(
        _legacySnapshot(preferences).canonicalJson,
        legacyBefore.canonicalJson,
      );
      expect(preferences.getString('db.user_state.v1'), isNull);

      store.close();
      final restarted = WebAppDatabase(userStateStore: connect());
      final reopened = await restarted.loadPortableRestoreState();
      expect(reopened.canonicalJson, saved.canonicalJson);
      expect(reopened.digest, expectedState.digest);
      await _requireWholeRows(
        restarted,
        mealMetadata,
        intakeMetadata,
        mealPins,
        intakePins,
      );
      await preferences.reload();
      expect(
        _legacySnapshot(preferences).canonicalJson,
        legacyBefore.canonicalJson,
      );
      expect(preferences.getString('db.user_state.v1'), isNull);
      print(
        'WEB_USER_STATE_12K_AFTER_REOPEN ${jsonEncode({'fixtureSha256': fixture.inputSha256, 'completeStateSha256': reopened.digest, 'completeStateUtf8Bytes': utf8.encode(reopened.canonicalJson).length, 'mealCount': (reopened.json['meals'] as List).length, 'intakeCount': (reopened.json['intakes'] as List).length, 'wholeRowsCheckedBeforeAndAfterReopen': 24000, 'allOriginalMetadataRetained': true, 'legacySnapshotDigestBefore': legacyBefore.digest, 'legacySnapshotDigestAfter': _legacySnapshot(preferences).digest, 'localStorageDataMirror': false, 'defaultFactoryObservedWithoutOpeningProductionDatabase': true, 'backend': restarted.userStateBackendId, 'clinicalInterpretation': 'None; synthetic software persistence only.'})}',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _requireWholeRows(
  WebAppDatabase database,
  List<String> mealMetadata,
  List<String> intakeMetadata,
  List<String> mealPins,
  List<String> intakePins,
) async {
  final meals = await database.loadMeals();
  final intakes = await database.loadIntakes();
  expect(meals, hasLength(mealMetadata.length));
  expect(intakes, hasLength(intakeMetadata.length));
  for (var index = 0; index < meals.length; index++) {
    final row = portableRestoreCanonicalJson(meals[index].toJson());
    expect(
      row,
      mealMetadata[index],
      reason: 'Complete original meal metadata at row $index',
    );
    expect(_bytesDigest(row), mealPins[index]);
  }
  for (var index = 0; index < intakes.length; index++) {
    final row = portableRestoreCanonicalJson(intakes[index].toJson());
    expect(
      row,
      intakeMetadata[index],
      reason: 'Complete original intake metadata at row $index',
    );
    expect(_bytesDigest(row), intakePins[index]);
  }
}

String _bytesDigest(String text) =>
    sha256.convert(utf8.encode(text)).toString();

Map<String, String> _guardedOriginMetadata() {
  final storage = web.window.localStorage;
  if (storage.length == 0) return const {};
  if (storage.length != 1 || storage.key(0) != _pulseKey) {
    throw StateError('synthetic_origin_contains_unexpected_storage_keys');
  }
  final pulse = storage.getItem(_pulseKey);
  if (pulse == null || !RegExp(r'^[0-9a-f]{20}$').hasMatch(pulse)) {
    throw StateError('synthetic_origin_notification_pulse_invalid');
  }
  return Map<String, String>.unmodifiable({_pulseKey: pulse});
}

Future<List<String>> _databaseMetadataNames() async {
  final metadata = (await web.window.indexedDB.databases().toDart).toDart;
  final names = <String>[for (final database in metadata) database.name]
    ..sort();
  return List<String>.unmodifiable(names);
}

WebUserStateLegacySnapshot _legacySnapshot(SharedPreferences preferences) =>
    WebUserStateLegacySnapshot({
      for (final key in webUserStateLegacyKeys) key: preferences.getString(key),
    });

Future<void> _deleteOwnedDatabase(String name) async {
  if (!name.startsWith('parkinsum.synthetic.user-state.12k.')) {
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
