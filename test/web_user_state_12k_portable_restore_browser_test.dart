// Machine-readable engineering witnesses intentionally use unbuffered stdout.
// ignore_for_file: avoid_print
@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/app_database_web.dart';
import 'package:parkinsum_companion/core/db/web_user_state_store.dart';
import 'package:parkinsum_companion/core/db/web_user_state_store_factory.dart';
import 'package:parkinsum_companion/core/db/web_user_state_store_indexeddb.dart';
import 'package:parkinsum_companion/core/models/portable_data_restore.dart';
import 'package:parkinsum_companion/core/models/recoverable_user_event.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/core/services/portable_data_restore_coordinator.dart';
import 'package:parkinsum_companion/domain/entities/portable_schema_migration.dart';
import 'package:parkinsum_companion/domain/usecases/portable_data_compact_transport_service.dart';
import 'package:parkinsum_companion/domain/usecases/user_portable_data_package_service.dart';
import 'package:parkinsum_companion/engineering/personal_log_view_benchmark_fixture.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:web/web.dart' as web;

const _fixtureSha256 =
    '97db49a275871c8fd1592ff28318a77c0a67400d8390052c74346226b6534eba';
const _pulseKey = 'parkinsum.user_state.revision.v1';
const _ownedPrefix = 'parkinsum.synthetic.user-state.12k-portable.';
const _owner = 'local_user';
const _kind = 'local_device_account';
const _packageService = UserPortableDataPackageService();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Browser unit tests do not execute the generated app plugin registrant.
  // Register the official locked Web backend; no preference mock is installed.
  SharedPreferencesPlugin.registerWith(null);

  test(
    'default schema 5 full 12k restore aborts safely, persists a receipt, reopens and undoes the complete original state',
    () async {
      final stageClock = Stopwatch()..start();
      const operationBudget = Duration(minutes: 7, seconds: 30);
      const totalBudget = Duration(minutes: 8);
      var cancelled = false;
      bool authorize() => !cancelled && stageClock.elapsed < operationBudget;
      void checkActive() {
        if (!authorize()) {
          cancelled = true;
          throw TimeoutException('synthetic_restore_operation_deadline');
        }
      }

      final cancellationTimer = Timer(operationBudget, () => cancelled = true);
      addTearDown(cancellationTimer.cancel);
      late final Future<void> lifecycleSettled;
      Future<T> cleanupAwait<T>(Future<T> Function() operation) {
        final remaining = totalBudget - stageClock.elapsed;
        if (remaining <= Duration.zero) {
          throw TimeoutException('synthetic_restore_cleanup_deadline');
        }
        return operation().timeout(remaining);
      }

      final stageStarts = <String, int>{};
      void startStage(String stage) {
        checkActive();
        final elapsedMs = stageClock.elapsedMilliseconds;
        stageStarts[stage] = elapsedMs;
        print(
          'WEB_USER_STATE_12K_PORTABLE_STAGE '
          '${jsonEncode({'stage': stage, 'event': 'start', 'elapsedMs': elapsedMs})}',
        );
      }

      void completeStage(String stage) {
        checkActive();
        final elapsedMs = stageClock.elapsedMilliseconds;
        final stageElapsedMs = elapsedMs - stageStarts.remove(stage)!;
        print(
          'WEB_USER_STATE_12K_PORTABLE_STAGE '
          '${jsonEncode({'stage': stage, 'event': 'complete', 'elapsedMs': elapsedMs, 'stageElapsedMs': stageElapsedMs})}',
        );
      }

      Future<void> runLifecycle() async {
        startStage('origin_guard');
        // Inspect only metadata before obtaining any existing preference value or
        // opening any database. A known pulse may remain from another test in
        // this disposable origin; nothing is deleted to make the guard succeed.
        expect(['localhost', '127.0.0.1', '[::1]'], contains(Uri.base.host));
        final originalOriginMetadata = _guardedOriginMetadata();
        final originalPulse = originalOriginMetadata[_pulseKey];
        final originalDatabaseMetadata = await _databaseMetadataNames();
        expect(
          originalDatabaseMetadata,
          isEmpty,
          reason: 'Refuse an origin containing any pre-existing database.',
        );
        expect(
          SharedPreferencesStorePlatform.instance,
          isNot(isA<InMemorySharedPreferencesStore>()),
        );

        // The default production factory is checked without opening its real
        // database. All actual operations use the synthetic name below.
        final productionChoice = createWebUserStateStore();
        expect(productionChoice, isA<IndexedDbWebUserStateStore>());
        (productionChoice! as IndexedDbWebUserStateStore).close();
        completeStage('origin_guard');

        startStage('fixture_pinning');
        final fixture = PersonalLogBenchmarkFixture.generate(10000);
        final fixtureSha256 = fixture.inputSha256;
        expect(PersonalLogBenchmarkFixture.seed, 31415926);
        expect(
          fixtureSha256,
          _fixtureSha256,
          reason: 'Pin the unchanged Chrome fixture before any durable write.',
        );
        expect(fixture.meals, hasLength(10000));
        expect(fixture.intakes, hasLength(2000));
        final mealMetadata = Map<String, String>.unmodifiable({
          for (final row in fixture.meals)
            row.id: portableRestoreCanonicalJson(row.toJson()),
        });
        final intakeMetadata = Map<String, String>.unmodifiable({
          for (final row in fixture.intakes)
            row.id: portableRestoreCanonicalJson(row.toJson()),
        });
        final mealPins = Map<String, String>.unmodifiable({
          for (final entry in mealMetadata.entries)
            entry.key: portableRestoreBytesDigest(entry.value),
        });
        final intakePins = Map<String, String>.unmodifiable({
          for (final entry in intakeMetadata.entries)
            entry.key: portableRestoreBytesDigest(entry.value),
        });
        final beforeWriteWitness = <String, Object?>{
          'stage': 'whole_original_fixture_pinned_before_first_write',
          'fixtureSha256': fixtureSha256,
          'seed': PersonalLogBenchmarkFixture.seed,
          'wholeRowCount': mealMetadata.length + intakeMetadata.length,
          'mealMetadataSha256': portableRestoreDigest(mealMetadata),
          'intakeMetadataSha256': portableRestoreDigest(intakeMetadata),
          'allIndividualMealPinsSha256': portableRestoreDigest(mealPins),
          'allIndividualIntakePinsSha256': portableRestoreDigest(intakePins),
          'capturedUnknownRaw999MealCount': fixture.meals
              .where(
                (row) =>
                    row.items.single.isNutrientMissing('proteinG') &&
                    row.items.single.proteinPer100g == 999,
              )
              .length,
          'reportedZeroMealCount': fixture.meals
              .where(
                (row) =>
                    !row.items.single.isNutrientMissing('proteinG') &&
                    row.items.single.proteinPer100g == 0,
              )
              .length,
          'invalidQuantityMealCount': fixture.meals
              .where((row) => row.items.single.quantityFactor == 0)
              .length,
          'futureMealCount': fixture.meals
              .where(
                (row) => row.effectiveOccurredAt.isAfter(
                  PersonalLogBenchmarkFixture.asOf,
                ),
              )
              .length,
          'unspecifiedDoseIntakeCount': fixture.intakes
              .where((row) => row.doseAmount == null && row.doseUnit == null)
              .length,
        };
        expect(beforeWriteWitness['capturedUnknownRaw999MealCount'], 1000);
        expect(beforeWriteWitness['reportedZeroMealCount'], 1000);
        expect(beforeWriteWitness['invalidQuantityMealCount'], 1000);
        expect(beforeWriteWitness['futureMealCount'], 500);
        expect(beforeWriteWitness['unspecifiedDoseIntakeCount'], 2000);
        print(
          'WEB_USER_STATE_12K_PORTABLE_BEFORE_WRITE '
          '${jsonEncode(beforeWriteWitness)}',
        );
        completeStage('fixture_pinning');

        startStage('original_setup');
        final preferences = await SharedPreferences.getInstance();
        await preferences.reload();
        expect(preferences.getKeys(), isEmpty);
        expect(
          SharedPreferencesStorePlatform.instance,
          isNot(isA<InMemorySharedPreferencesStore>()),
        );
        print(
          'WEB_USER_STATE_12K_PORTABLE_ACTUAL_PLATFORM ${jsonEncode({'runtimeType': SharedPreferencesStorePlatform.instance.runtimeType.toString(), 'getInstanceAndReloadSucceeded': true, 'explicitPreferencesMockInstalled': false, 'actualPreferencesKeyCount': preferences.getKeys().length})}',
        );
        final legacyBefore = _legacySnapshot(preferences);
        final databaseName =
            '$_ownedPrefix${DateTime.now().microsecondsSinceEpoch}';
        final connections = <IndexedDbWebUserStateStore>[];
        var failureMode = '';
        var beforePublicationRefusals = 0;
        var afterQueuedAborts = 0;
        final beforePublicationFailure = StateError(
          'synthetic_12k_before_publication',
        );
        final afterQueuedFailure = StateError(
          'synthetic_12k_abort_after_queued_put',
        );
        IndexedDbWebUserStateStore connect({bool faults = false}) {
          checkActive();
          final store = IndexedDbWebUserStateStore(
            databaseName: databaseName,
            readCurrentLegacy: () {
              checkActive();
              return _legacySnapshot(preferences);
            },
            beforePublication: faults
                ? () {
                    checkActive();
                    if (failureMode == 'before_publication') {
                      beforePublicationRefusals++;
                      throw beforePublicationFailure;
                    }
                  }
                : null,
            afterWriteQueued: faults
                ? () {
                    checkActive();
                    if (failureMode == 'after_queued') {
                      afterQueuedAborts++;
                      // The actual IDB put has been queued. The production store
                      // aborts this transaction and resolves its failure on onabort.
                      throw afterQueuedFailure;
                    }
                  }
                : null,
          );
          connections.add(store);
          return store;
        }

        addTearDown(() async {
          cancelled = true;
          cancellationTimer.cancel();
          // Future.timeout does not stop its underlying restore. Drain the
          // entire lifecycle before deleting its database; otherwise a late
          // readback could reopen the name after cleanup and migrate it again.
          try {
            await cleanupAwait(() => lifecycleSettled);
          } catch (_) {
            print(
              'WEB_USER_STATE_12K_PORTABLE_CLEANUP_HOLD '
              '${jsonEncode({'ownedLifecycleSettled': false, 'ownedDatabaseDeletionDispatched': false, 'originalOriginMetadataRestoredExactly': false})}',
            );
            rethrow;
          }
          for (final connection in connections) {
            connection.close();
          }
          await cleanupAwait(() => _deleteOwnedDatabase(databaseName));
          final databaseMetadataAfter = await cleanupAwait(
            _databaseMetadataNames,
          );
          expect(databaseMetadataAfter, isNot(contains(databaseName)));
          expect(databaseMetadataAfter, originalDatabaseMetadata);
          final markerKey = 'parkinsum.indexeddb.migrated.$databaseName';
          final marker = web.window.localStorage.getItem(markerKey);
          expect(
            marker,
            anyOf(isNull, '1'),
            reason: 'Refuse deleting an unexpected owned marker value.',
          );
          web.window.localStorage.removeItem(markerKey);
          expect(web.window.localStorage.getItem(markerKey), isNull);
          _guardedOriginMetadata();
          if (originalPulse == null) {
            web.window.localStorage.removeItem(_pulseKey);
          } else {
            web.window.localStorage.setItem(_pulseKey, originalPulse);
          }
          final restoredMetadata = _guardedOriginMetadata();
          expect(restoredMetadata, originalOriginMetadata);
          print(
            'WEB_USER_STATE_12K_PORTABLE_CLEANUP ${jsonEncode({'ownedDatabaseAbsentAfterDelete': !databaseMetadataAfter.contains(databaseName), 'ownedMigrationMarkerAbsent': web.window.localStorage.getItem(markerKey) == null, 'databaseMetadataBefore': originalDatabaseMetadata, 'databaseMetadataAfter': databaseMetadataAfter, 'originMetadataBeforeSha256': portableRestoreDigest(originalOriginMetadata), 'originMetadataAfterSha256': portableRestoreDigest(restoredMetadata), 'originalPulsePresent': originalPulse != null, 'originalOriginMetadataRestoredExactly': true})}',
          );
        });

        final firstStore = connect(faults: true);
        final database = WebAppDatabase(userStateStore: firstStore);
        expect(database.userStateBackendId, contains('IndexedDB'));
        final empty = await database.loadPortableRestoreState();
        expect(empty.recordIds.values.every((ids) => ids.isEmpty), isTrue);
        final originalProfile = UserProfile.defaults().copyWith(
          timezone: 'Asia/Shanghai',
          displayLocale: 'zh-CN',
        );
        await database.saveUserProfile(originalProfile);
        await database.saveOnboarded(true);
        const originalDrugId = 'synthetic-original-medication';
        await database.saveActiveDrugIds(const [originalDrugId]);
        final originalMeal = fixture.meals[1].copyWith(
          id: 'synthetic-original-meal',
          title: 'Synthetic original unknown meal',
        );
        final originalIntake = fixture.intakes.first.copyWith(
          id: 'synthetic-original-intake',
          drugId: originalDrugId,
        );
        final revisions = [
          RecoverableUserEventRevision.create(
            operationId: 'synthetic_original_meal_create',
            eventType: RecoverableUserEventType.meal,
            recordId: originalMeal.id,
            mutationType: RecoverableUserEventMutationType.create,
            beforePayload: null,
            afterPayload: originalMeal.toJson(),
            recordedAtUtc: PersonalLogBenchmarkFixture.asOf,
            source: 'synthetic_12k_portable_test',
          ),
          RecoverableUserEventRevision.create(
            operationId: 'synthetic_original_intake_create',
            eventType: RecoverableUserEventType.intake,
            recordId: originalIntake.id,
            mutationType: RecoverableUserEventMutationType.create,
            beforePayload: null,
            afterPayload: originalIntake.toJson(),
            recordedAtUtc: PersonalLogBenchmarkFixture.asOf,
            source: 'synthetic_12k_portable_test',
          ),
        ];
        for (final revision in revisions) {
          await database.commitRecoverableUserEventMutation(
            RecoverableUserEventMutation(revision: revision),
          );
        }
        final originalState = PortableDataRestoreState({
          ...empty.json,
          'onboarded': true,
          'profile': originalProfile.toJson(),
          'activeDrugIds': [originalDrugId],
          'meals': [originalMeal.toJson()],
          'intakes': [originalIntake.toJson()],
          'eventHistory': revisions.map((row) => row.toJson()).toList(),
        });
        await _requireCompleteState(database, originalState);
        expect(
          await database.loadPortableRestoreReceipt(ownerScope: _owner),
          isNull,
        );
        final originalRaw = await _readOwnedEnvelope(
          databaseName,
          checkActive: checkActive,
        );
        _requireEnvelope(originalRaw, legacyBefore);
        completeStage('original_setup');

        final exportedProfile = UserProfile.defaults().copyWith(
          timezone: 'Etc/UTC',
          displayLocale: 'en-US',
        );
        // Exercise the default production choice: no preferCompactTransport flag
        // and no relaxed service limits. This original input must select schema 5.
        startStage('create');
        final artifact = _packageService.create(
          snapshot: UserPortableDataSnapshot(
            userScope: _owner,
            doseOwnerScope: _owner,
            scopeKind: _kind,
            profile: exportedProfile,
            activeDrugIds: const [],
            intakes: fixture.intakes,
            meals: fixture.meals,
            medicationCatalog: fixture.drugs,
            foodCatalog: fixture.foods,
            reminders: const [],
            observations: const [],
          ),
          generatedAt: PersonalLogBenchmarkFixture.asOf,
        );
        expect(artifact.document['schemaVersion'], 5);
        completeStage('create');

        startStage('integrity_and_resolve');
        _requirePackageIntegrity(artifact);
        final wireFiles = Map<String, Object?>.from(
          artifact.document['files'] as Map,
        );
        final logicalFiles = PortableDataCompactTransportService.resolve(
          wireFiles,
        );
        expect(logicalFiles.files['meals.json'], hasLength(10000));
        expect(logicalFiles.files['intakes.json'], hasLength(2000));
        expect(logicalFiles.files['reminders.json'], isEmpty);
        expect(
          (logicalFiles.files['observations.json'] as Map)['records'],
          isEmpty,
        );
        completeStage('integrity_and_resolve');

        startStage('inspect');
        final preview = _packageService.inspect(
          packageJson: artifact.prettyJson,
          currentUserScope: _owner,
          currentDoseOwnerScope: _owner,
          currentScopeKind: _kind,
          existingRecordIds: originalState.recordIds,
        );
        expect(
          preview.status,
          UserPortableDataPreviewStatus.ready,
          reason: preview.findings.join('; '),
        );
        expect(preview.schemaVersion, 5);
        expect(preview.conflictCount, 0);
        expect(preview.recordCounts['meals.json'], 10000);
        expect(preview.recordCounts['intakes.json'], 2000);
        final schemaReceipt = preview.schemaMigrationReceipt;
        expect(schemaReceipt, isNotNull);
        expect(schemaReceipt!.sourceVersion, 5);
        expect(schemaReceipt.targetVersion, 5);
        expect(schemaReceipt.decision, 'not_required_compact_transport');
        expect(
          schemaReceipt.sourceBytesSha256,
          portableRestoreBytesDigest(artifact.prettyJson),
        );
        expect(
          schemaReceipt.receiptSha256,
          portableCanonicalSha256(schemaReceipt.toJson(includeDigest: false)),
        );
        completeStage('inspect');

        startStage('prepare');
        final coordinator = PortableDataRestoreCoordinator(store: database);
        final request = await coordinator.prepare(
          packageJson: artifact.prettyJson,
          ownerScope: _owner,
          effectiveOwnerScope: _owner,
          scopeKind: _kind,
          foodCatalog: fixture.foods,
          medicationCatalog: fixture.drugs,
          authorize: authorize,
        );
        completeStage('prepare');

        startStage('payload_equality');
        expect(request.expectedStateDigest, originalState.digest);
        expect(
          request.packageJsonSha256,
          portableRestoreBytesDigest(artifact.prettyJson),
        );
        expect(request.payload.json['profile'], exportedProfile.toJson());
        _requireRows(
          request.payload.json['meals'] as List,
          mealMetadata,
          mealPins,
          'prepared original meal',
        );
        _requireRows(
          request.payload.json['intakes'] as List,
          intakeMetadata,
          intakePins,
          'prepared original intake',
        );
        await _requireCompleteState(database, originalState);
        expect(
          await _readOwnedEnvelope(databaseName, checkActive: checkActive),
          originalRaw,
          reason:
              'Create, inspect and prepare must not publish record changes.',
        );
        completeStage('payload_equality');

        for (final mode in ['before_publication', 'after_queued']) {
          failureMode = mode;
          final expectedFailure = mode == 'before_publication'
              ? beforePublicationFailure
              : afterQueuedFailure;
          startStage('fault_commit_$mode');
          await expectLater(
            coordinator.commit(
              request: request,
              currentPackageJson: artifact.prettyJson,
              explicitlyConfirmed: true,
              authorize: authorize,
            ),
            throwsA(same(expectedFailure)),
          );
          completeStage('fault_commit_$mode');

          startStage('fault_preservation_$mode');
          failureMode = '';
          await _requireCompleteState(database, originalState);
          expect(
            await database.loadPortableRestoreReceipt(ownerScope: _owner),
            isNull,
          );
          expect(
            await _readOwnedEnvelope(databaseName, checkActive: checkActive),
            originalRaw,
            reason:
                '$mode must preserve the whole original envelope and receipt.',
          );
          // A new real connection verifies durability, not a cached model string.
          final faultRestart = WebAppDatabase(userStateStore: connect());
          await _requireCompleteState(faultRestart, originalState);
          expect(
            await faultRestart.loadPortableRestoreReceipt(ownerScope: _owner),
            isNull,
          );
          await _requireLegacyUnchanged(preferences, legacyBefore);
          completeStage('fault_preservation_$mode');
        }
        expect(beforePublicationRefusals, 1);
        expect(afterQueuedAborts, 1);
        print(
          'WEB_USER_STATE_12K_PORTABLE_REFUSALS ${jsonEncode({'beforePublicationRefusalCount': beforePublicationRefusals, 'afterQueuedActualTransactionAbortCount': afterQueuedAborts, 'completeOriginalStateSha256': originalState.digest, 'originalEnvelopeSha256': portableRestoreBytesDigest(originalRaw), 'completeRecordsHistoryProfileSelectionsAndReceiptPreserved': true, 'verifiedViaNewActualIndexedDbConnection': true})}',
        );

        startStage('successful_commit');
        final receipt = await coordinator.commit(
          request: request,
          currentPackageJson: artifact.prettyJson,
          explicitlyConfirmed: true,
          authorize: authorize,
        );
        completeStage('successful_commit');

        startStage('successful_commit_verification');
        final sortedMealIds = mealMetadata.keys.toList()..sort();
        final sortedIntakeIds = intakeMetadata.keys.toList()..sort();
        final expectedRestored = PortableDataRestoreState({
          ...originalState.json,
          'profile': exportedProfile.toJson(),
          'meals': [
            originalMeal.toJson(),
            for (final id in sortedMealIds) jsonDecode(mealMetadata[id]!),
          ],
          'intakes': [
            originalIntake.toJson(),
            for (final id in sortedIntakeIds) jsonDecode(intakeMetadata[id]!),
          ],
        });
        await _requireCompleteState(database, expectedRestored);
        _requireRestoreReceipt(
          receipt,
          request,
          artifact,
          originalState,
          expectedRestored,
        );
        expect(
          (await database.loadPortableRestoreReceipt(
            ownerScope: _owner,
          ))!.canonicalJson,
          receipt.canonicalJson,
        );
        final restoredDocument = _requireEnvelope(
          await _readOwnedEnvelope(databaseName, checkActive: checkActive),
          legacyBefore,
        );
        expect(restoredDocument['portableRestoreReceipt'], receipt.json);
        completeStage('successful_commit_verification');

        startStage('reopen');
        for (final connection in connections) {
          connection.close();
        }
        final reopened = WebAppDatabase(userStateStore: connect());
        await _requireCompleteState(reopened, expectedRestored);
        expect(
          (await reopened.loadPortableRestoreReceipt(
            ownerScope: _owner,
          ))!.canonicalJson,
          receipt.canonicalJson,
        );
        _requireRows(
          (await reopened.loadMeals())
              .where((row) => mealMetadata.containsKey(row.id))
              .map((row) => row.toJson())
              .toList(),
          mealMetadata,
          mealPins,
          'reopened original meal',
        );
        _requireRows(
          (await reopened.loadIntakes())
              .where((row) => intakeMetadata.containsKey(row.id))
              .map((row) => row.toJson())
              .toList(),
          intakeMetadata,
          intakePins,
          'reopened original intake',
        );
        completeStage('reopen');

        // Re-export only the incoming typed IDs. Original existing rows are
        // deliberately retained separately in the restored database merge.
        startStage('reexport');
        final reexport = _packageService.create(
          snapshot: UserPortableDataSnapshot(
            userScope: _owner,
            doseOwnerScope: _owner,
            scopeKind: _kind,
            profile: await reopened.loadUserProfile(),
            activeDrugIds: const [],
            intakes: (await reopened.loadIntakes()).where(
              (row) => intakeMetadata.containsKey(row.id),
            ),
            meals: (await reopened.loadMeals()).where(
              (row) => mealMetadata.containsKey(row.id),
            ),
            medicationCatalog: fixture.drugs,
            foodCatalog: fixture.foods,
            reminders: const [],
            observations: const [],
          ),
          generatedAt: PersonalLogBenchmarkFixture.asOf,
        );
        _requirePackageIntegrity(reexport);
        expect(reexport.canonicalJson, artifact.canonicalJson);
        expect(reexport.contentSha256, artifact.contentSha256);
        expect(reexport.packageId, artifact.packageId);
        await _requireLegacyUnchanged(preferences, legacyBefore);
        completeStage('reexport');

        startStage('undo');
        await reopened.rollbackPortableRestore(
          receipt,
          ownerScope: _owner,
          authorize: authorize,
        );
        await _requireCompleteState(reopened, originalState);
        expect(
          await reopened.loadPortableRestoreReceipt(ownerScope: _owner),
          isNull,
        );
        final undoneDocument = _requireEnvelope(
          await _readOwnedEnvelope(databaseName, checkActive: checkActive),
          legacyBefore,
        );
        expect(undoneDocument['portableRestoreReceipt'], {
          ...receipt.json,
          'rolledBack': true,
        });
        expect(
          PortableDataRestoreState(undoneDocument).canonicalJson,
          originalState.canonicalJson,
        );
        completeStage('undo');

        // The same durable Undo is idempotent and survives another connection
        // close/reopen. No notification permission or cross-store record is used.
        startStage('undo_idempotent_reopen');
        await reopened.rollbackPortableRestore(
          receipt,
          ownerScope: _owner,
          authorize: authorize,
        );
        for (final connection in connections) {
          connection.close();
        }
        final undoneReopened = WebAppDatabase(userStateStore: connect());
        final finalUndone = await _requireCompleteState(
          undoneReopened,
          originalState,
        );
        expect(
          await undoneReopened.loadPortableRestoreReceipt(ownerScope: _owner),
          isNull,
        );
        await _requireLegacyUnchanged(preferences, legacyBefore);
        completeStage('undo_idempotent_reopen');
        startStage('final_witness');
        print(
          'WEB_USER_STATE_12K_PORTABLE_AFTER_UNDO_REOPEN ${jsonEncode({'fixtureSha256': fixtureSha256, 'schemaVersion': artifact.document['schemaVersion'], 'packageBytesSha256': request.packageJsonSha256, 'packageContentSha256': artifact.contentSha256, 'packageFileChecksumsVerified': artifact.files.length, 'schemaReceiptSha256': schemaReceipt.receiptSha256, 'restoreReceiptSha256': portableRestoreBytesDigest(receipt.canonicalJson), 'originalCompleteStateSha256': originalState.digest, 'restoredCompleteStateSha256': expectedRestored.digest, 'undoneCompleteStateSha256': finalUndone.digest, 'incomingMealCount': 10000, 'incomingIntakeCount': 2000, 'originalMealCount': 1, 'originalIntakeCount': 1, 'originalRecoveryHistoryCount': 2, 'restoredMealCountIncludingOriginal': 10001, 'restoredIntakeCountIncludingOriginal': 2001, 'noRemindersOrObservations': true, 'defaultSchemaChoiceExercised': true, 'wholeOriginalRowMetadataRetained': true, 'completeOriginalStateRecoveredAfterUndoAndReopen': true, 'legacySnapshotSha256': legacyBefore.digest, 'localStorageDataMirror': false, 'actualTwoTabExecution': false, 'clinicalInterpretation': 'None; synthetic software persistence only.'})}',
        );
        completeStage('final_witness');
        checkActive();
      }

      final pendingLifecycle = runLifecycle();
      // Observe the original future even after the operation deadline fires.
      lifecycleSettled = pendingLifecycle.then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {},
      );
      final remaining = operationBudget - stageClock.elapsed;
      await pendingLifecycle.timeout(
        remaining > Duration.zero ? remaining : Duration.zero,
        onTimeout: () {
          cancelled = true;
          throw TimeoutException('synthetic_restore_operation_deadline');
        },
      );
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

void _requireRows(
  List rows,
  Map<String, String> originalMetadata,
  Map<String, String> originalPins,
  String stage,
) {
  expect(rows, hasLength(originalMetadata.length), reason: stage);
  final seen = <String>{};
  for (final raw in rows) {
    final row = Map<String, Object?>.from(raw as Map);
    final id = row['id'] as String;
    expect(seen.add(id), isTrue, reason: '$stage duplicate typed id $id');
    expect(
      originalMetadata.containsKey(id),
      isTrue,
      reason: '$stage unknown typed id $id',
    );
    final canonical = portableRestoreCanonicalJson(row);
    expect(
      canonical,
      originalMetadata[id],
      reason: '$stage complete fields for $id',
    );
    expect(
      portableRestoreBytesDigest(canonical),
      originalPins[id],
      reason: '$stage original pin for $id',
    );
  }
  // Every row above has a unique known ID and exact full fields/hash. Equal
  // cardinality plus hash membership proves the same complete ID set without
  // the matcher's quadratic unordered-Set comparison at 10,000 rows.
  expect(seen.length, originalMetadata.length, reason: stage);
  expect(seen.containsAll(originalMetadata.keys), isTrue, reason: stage);
}

Future<PortableDataRestoreState> _requireCompleteState(
  WebAppDatabase database,
  PortableDataRestoreState expected,
) async {
  final observed = await database.loadPortableRestoreState();
  final observedDigest = observed.digest;
  final expectedDigest = expected.digest;
  // This compares every field of the complete aggregate. Reopened typed meal
  // and intake readers are also checked against all 12,000 original row pins
  // below. Re-reading the full aggregate through six additional getters at
  // every stage duplicated large receipt decoding without adding fields.
  expect(
    observed.canonicalJson == expected.canonicalJson,
    isTrue,
    reason:
        'Complete state equality: observed $observedDigest, '
        'expected $expectedDigest.',
  );
  expect(observedDigest, expectedDigest);
  print(
    'WEB_USER_STATE_12K_PORTABLE_COMPLETE_STATE ${jsonEncode({'completeCanonicalFieldsEqual': true, 'wholeStateSha256': observedDigest, 'canonicalChars': observed.canonicalJson.length})}',
  );
  return observed;
}

void _requireRestoreReceipt(
  PortableDataRestoreReceipt receipt,
  PortableDataRestoreRequest request,
  UserPortableDataPackageArtifact artifact,
  PortableDataRestoreState original,
  PortableDataRestoreState restored,
) {
  expect(receipt.json, {
    'version': 1,
    'ownerScope': _owner,
    'operationId': request.operationId,
    'packageJsonSha256': portableRestoreBytesDigest(artifact.prettyJson),
    'sourcePackageJson': artifact.prettyJson,
    'beforeDigest': original.digest,
    'afterDigest': restored.digest,
    'beforeState': original.json,
    'rolledBack': false,
  });
  expect(receipt.beforeDigest, original.digest);
  expect(receipt.afterDigest, restored.digest);
  expect(
    PortableDataRestoreState(
      Map<String, Object?>.from(receipt.json['beforeState'] as Map),
    ).canonicalJson,
    original.canonicalJson,
  );
}

void _requirePackageIntegrity(UserPortableDataPackageArtifact artifact) {
  final files = Map<String, Object?>.from(artifact.document['files'] as Map);
  final manifest = artifact.document['manifest'] as Map;
  final summaries = manifest['files'] as List;
  expect(
    files.keys.toSet(),
    summaries.map((raw) => (raw as Map)['path']).toSet(),
  );
  expect(summaries, hasLength(artifact.files.length));
  for (final summary in artifact.files) {
    final raw =
        summaries.singleWhere((row) => (row as Map)['path'] == summary.path)
            as Map;
    expect(raw['sha256'], portableCanonicalSha256(files[summary.path]));
    expect(raw['sha256'], summary.sha256);
    expect(raw['recordCount'], summary.recordCount);
    final file = files[summary.path];
    final independentlyCounted = file is List
        ? file.length
        : file is Map && file['records'] is List
        ? (file['records'] as List).length
        : file is Map && file['links'] is List
        ? (file['links'] as List).length
        : 1;
    expect(raw['recordCount'], independentlyCounted);
  }
  expect(artifact.contentSha256, portableCanonicalSha256(files));
  expect(
    (manifest['integrity'] as Map)['contentSha256'],
    artifact.contentSha256,
  );
  expect(
    artifact.packageId,
    portableSha256(
      'parkinsum-portable-package-v${artifact.document['schemaVersion']}|'
      '${artifact.ownerScopeSha256}|${artifact.contentSha256}',
    ),
  );
  expect(jsonDecode(artifact.prettyJson), jsonDecode(artifact.canonicalJson));
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
  expect(
    portableRestoreCanonicalJson(envelope['legacyKeys']),
    legacy.canonicalJson,
  );
  expect(envelope['legacyDigest'], legacy.digest);
  final document = envelope['document'] as String;
  expect(envelope['documentDigest'], portableRestoreDigest(document));
  return Map<String, Object?>.from(jsonDecode(document) as Map);
}

Future<void> _requireLegacyUnchanged(
  SharedPreferences preferences,
  WebUserStateLegacySnapshot original,
) async {
  await preferences.reload();
  expect(_legacySnapshot(preferences).canonicalJson, original.canonicalJson);
  expect(preferences.getString('db.user_state.v1'), isNull);
  expect(
    preferences.getKeys(),
    isEmpty,
    reason:
        'No catalog, personal state or package may be mirrored to localStorage.',
  );
}

WebUserStateLegacySnapshot _legacySnapshot(SharedPreferences preferences) =>
    WebUserStateLegacySnapshot({
      for (final key in webUserStateLegacyKeys) key: preferences.getString(key),
    });

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

Future<String> _readOwnedEnvelope(
  String name, {
  required void Function() checkActive,
}) async {
  if (!name.startsWith(_ownedPrefix)) {
    throw StateError('Refuse reading an unowned browser database.');
  }
  checkActive();
  final opened = Completer<web.IDBDatabase>();
  final request = web.window.indexedDB.open(name);
  request.onupgradeneeded = ((web.Event _) {
    // The database must already exist. Never create it to make a read pass.
    request.transaction?.abort();
  }).toJS;
  request.onsuccess = ((web.Event _) {
    final database = request.result as web.IDBDatabase;
    if (opened.isCompleted) {
      database.close();
    } else {
      try {
        checkActive();
        opened.complete(database);
      } catch (error, trace) {
        database.close();
        opened.completeError(error, trace);
      }
    }
  }).toJS;
  request.onerror = ((web.Event _) {
    if (!opened.isCompleted) {
      opened.completeError(
        StateError('synthetic_owned_database_read_open_failed'),
      );
    }
  }).toJS;
  request.onblocked = ((web.Event _) {
    if (!opened.isCompleted) {
      opened.completeError(StateError('synthetic_owned_database_read_blocked'));
    }
  }).toJS;
  final database = await opened.future;
  try {
    // A cancelled open still owns the returned handle until this finally.
    checkActive();
    final completed = Completer<String>();
    String? raw;
    final transaction = database.transaction('documents'.toJS, 'readonly');
    transaction.oncomplete = ((web.Event _) {
      if (completed.isCompleted) return;
      if (raw == null) {
        completed.completeError(StateError('synthetic_owned_envelope_absent'));
      } else {
        completed.complete(raw);
      }
    }).toJS;
    transaction.onabort = ((web.Event _) {
      if (!completed.isCompleted) {
        completed.completeError(
          StateError('synthetic_owned_envelope_read_aborted'),
        );
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

Future<void> _deleteOwnedDatabase(String name) async {
  if (!name.startsWith(_ownedPrefix)) {
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
