import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:parkinsum_companion/core/services/data_service.dart';
import 'package:parkinsum_companion/core/services/reminder_activation_store_io.dart';
import 'package:parkinsum_companion/core/services/user_logging_reminder_service.dart';
import 'package:parkinsum_companion/domain/entities/user_logging_reminder.dart';
import 'package:parkinsum_companion/features/reminders/reminder_center_page.dart';
import 'package:parkinsum_companion/features/timeline/timeline_page.dart';

import 'helpers/page_test_harness.dart';

void main() {
  group('UserLoggingReminder', () {
    test('round-trips the strict local schema', () {
      final reminder = _reminder();

      final restored = UserLoggingReminder.fromJson(reminder.toJson());

      expect(restored.id, reminder.id);
      expect(restored.kind, reminder.kind);
      expect(restored.label, reminder.label);
      expect(restored.minuteOfDay, 9 * 60 + 15);
      expect(restored.weekdays, {1, 3, 5});
      expect(restored.enabled, isTrue);
      expect(restored.activationToken, reminder.activationToken);
      expect(
        restored.notificationPrivacyMode,
        ReminderNotificationPrivacyMode.minimal,
      );
      expect(restored.notificationLocaleCode, 'en');
    });

    test(
      'v2 rows migrate to minimal privacy and v3 persists an explicit mode',
      () {
        final v2 =
            <String, dynamic>{..._reminder().toJson(), 'schemaVersion': 2}
              ..remove('notificationPrivacyMode')
              ..remove('notificationLocaleCode');
        expect(
          UserLoggingReminder.fromJson(v2).notificationPrivacyMode,
          ReminderNotificationPrivacyMode.minimal,
        );
        expect(UserLoggingReminder.fromJson(v2).notificationLocaleCode, 'en');

        final generic = _reminder().copyWith(
          notificationPrivacyMode: ReminderNotificationPrivacyMode.generic,
          notificationLocaleCode: 'fr-CA',
        );
        final v3 = generic.toJson();
        expect(generic.toJson()['schemaVersion'], 3);
        expect(
          UserLoggingReminder.fromJson(
            generic.toJson(),
          ).notificationPrivacyMode,
          ReminderNotificationPrivacyMode.generic,
        );
        expect(
          UserLoggingReminder.fromJson(v3).notificationLocaleCode,
          'fr-CA',
        );
      },
    );

    test('rejects invalid time, days, label, and kind', () {
      final valid = _reminder().toJson();
      expect(
        () => UserLoggingReminder.fromJson({...valid, 'minuteOfDay': 1440}),
        throwsFormatException,
      );
      expect(
        () => UserLoggingReminder.fromJson({
          ...valid,
          'weekdays': [0],
        }),
        throwsFormatException,
      );
      expect(
        () => UserLoggingReminder.fromJson({...valid, 'label': ''}),
        throwsFormatException,
      );
      expect(
        () => UserLoggingReminder.fromJson({...valid, 'kind': 'doseAlarm'}),
        throwsFormatException,
      );
      expect(
        () => UserLoggingReminder.fromJson({
          ...valid,
          'notificationPrivacyMode': 'labelOnLockScreen',
        }),
        throwsFormatException,
      );
      expect(
        () => UserLoggingReminder.fromJson({
          ...valid,
          'notificationLocaleCode': '../private',
        }),
        throwsFormatException,
      );
      expect(
        () => UserLoggingReminder.fromJson(
          {...valid}..remove('notificationLocaleCode'),
        ),
        throwsFormatException,
      );
      expect(
        () => UserLoggingReminder.fromJson({...valid, 'schemaVersion': 4}),
        throwsFormatException,
      );
    });

    test('finds the next selected local weekday and skips elapsed time', () {
      final reminder = _reminder();

      expect(
        reminder.nextOccurrence(DateTime(2026, 8, 17, 8)),
        DateTime(2026, 8, 17, 9, 15),
      );
      expect(
        reminder.nextOccurrence(DateTime(2026, 8, 17, 10)),
        DateTime(2026, 8, 19, 9, 15),
      );
    });
  });

  group('UserLoggingReminderController', () {
    test('scopes durable reminder plans by user', () async {
      final storage = _MemoryDataService();
      final repository = UserLoggingReminderRepository(storage: storage);

      await repository.save('user/a', [_reminder(label: 'First')]);
      await repository.save('user_a', [_reminder(label: 'Second')]);

      expect((await repository.load('user/a')).single.label, 'First');
      expect((await repository.load('user_a')).single.label, 'Second');
    });

    test(
      'migrates the account-scoped v2 store to v3 with minimal privacy',
      () async {
        final storage = _MemoryDataService();
        final repository = UserLoggingReminderRepository(storage: storage);
        const scope = 'migration-user';
        final digest = sha256.convert(utf8.encode(scope)).toString();
        final legacyKey = 'parkinsum.user_logging_reminders.v2.$digest';
        final currentKey = 'parkinsum.user_logging_reminders.v3.$digest';
        final legacyRow =
            <String, dynamic>{..._reminder().toJson(), 'schemaVersion': 2}
              ..remove('notificationPrivacyMode')
              ..remove('notificationLocaleCode');
        storage.values[legacyKey] = jsonEncode([legacyRow]);

        final restored = await repository.load(scope);

        expect(
          restored.single.notificationPrivacyMode,
          ReminderNotificationPrivacyMode.minimal,
        );
        expect(restored.single.notificationLocaleCode, 'en');
        expect(storage.values, isNot(contains(legacyKey)));
        expect(storage.values[currentKey], isNotNull);
        final migrated = jsonDecode(storage.values[currentKey]!) as List;
        expect(
          migrated.single,
          containsPair('notificationPrivacyMode', 'minimal'),
        );
        expect(migrated.single, containsPair('notificationLocaleCode', 'en'));
      },
    );

    test('ambiguous v1 scope keys fail closed instead of migrating', () async {
      final storage = _MemoryDataService();
      await storage.setString(
        'parkinsum.user_logging_reminders.v1.user_a',
        jsonEncode([_reminder(label: 'Legacy private label').toJson()]),
      );
      final repository = UserLoggingReminderRepository(storage: storage);

      expect(await repository.load('user/a'), isEmpty);
      expect(await repository.load('user_a'), isEmpty);
    });

    test(
      'load and explicit resume reconciliation replay the durable plan',
      () async {
        final storage = _MemoryDataService();
        final repository = UserLoggingReminderRepository(storage: storage);
        final gateway = _FakeGateway();
        await repository.save('user', [_reminder()]);
        final controller = UserLoggingReminderController(
          userScope: 'user',
          repository: repository,
          gateway: gateway,
        );

        await controller.load();

        expect(gateway.synchronizationCount, 1);
        expect(gateway.synchronized.single.id, 'reminder-1');
        expect(controller.lastSynchronizedAt, isNotNull);

        expect(await controller.resynchronize(), isTrue);
        expect(gateway.synchronizationCount, 2);
        expect(controller.error, isNull);
      },
    );

    test(
      'permission denial does not create a durable enabled reminder',
      () async {
        final storage = _MemoryDataService();
        final repository = UserLoggingReminderRepository(storage: storage);
        final gateway = _FakeGateway(permissionGranted: false);
        final controller = UserLoggingReminderController(
          userScope: 'user',
          repository: repository,
          gateway: gateway,
        );

        final saved = await controller.save(_reminder());

        expect(saved, isFalse);
        expect(controller.error, 'permission_denied');
        expect(await repository.load('user'), isEmpty);
        expect(gateway.synchronized, isEmpty);
      },
    );

    test(
      'schedule failure rolls back and does not persist a partial plan',
      () async {
        final storage = _MemoryDataService();
        final repository = UserLoggingReminderRepository(storage: storage);
        final gateway = _ScriptedLeaseGateway(failingSynchronizations: {1});
        final controller = UserLoggingReminderController(
          userScope: 'user',
          repository: repository,
          gateway: gateway,
        );

        final saved = await controller.save(_reminder());

        expect(saved, isFalse);
        expect(controller.error, 'schedule_failed');
        expect(await repository.load('user'), isEmpty);
        expect(gateway.synchronizationCount, 2);
      },
    );

    test('persistence failure restores the previous system plan', () async {
      final storage = _FailingMemoryDataService();
      final repository = UserLoggingReminderRepository(storage: storage);
      final gateway = _FakeGateway();
      final controller = UserLoggingReminderController(
        userScope: 'user',
        repository: repository,
        gateway: gateway,
      );
      storage.failWrites = true;

      final saved = await controller.save(_reminder());

      expect(saved, isFalse);
      expect(controller.error, 'save_failed');
      expect(controller.reminders, isEmpty);
      expect(gateway.synchronizationCount, 2);
      expect(gateway.synchronized, isEmpty);
    });

    test(
      'superseded synchronization neither persists nor marks synchronized',
      () async {
        final storage = _MemoryDataService();
        final repository = UserLoggingReminderRepository(storage: storage);
        final gateway = _ScriptedLeaseGateway(blockFirstSynchronization: true);
        final controller = UserLoggingReminderController(
          userScope: 'user-a',
          repository: repository,
          gateway: gateway,
        );

        final save = controller.save(_reminder());
        await gateway.firstSynchronizationStarted.future;
        final cancellation = gateway.cancelScheduledRemindersWithResult();
        gateway.releaseFirstSynchronization();

        expect(await save, isFalse);
        expect(
          (await cancellation).status,
          ReminderNotificationMutationStatus.applied,
        );
        expect(await repository.load('user-a'), isEmpty);
        expect(controller.lastSynchronizedAt, isNull);
        expect(
          controller.lastMutationResult?.status,
          ReminderNotificationMutationStatus.superseded,
        );
        expect(controller.systemStateUnverified, isTrue);
        expect(gateway.synchronizationCount, 1);
        expect(gateway.cancellationCount, 1);
        expect(gateway.synchronized, isEmpty);
      },
    );

    test(
      'primary failure reuses its lease for a successful rollback',
      () async {
        final storage = _MemoryDataService();
        final repository = UserLoggingReminderRepository(storage: storage);
        final gateway = _ScriptedLeaseGateway(failingSynchronizations: {1});
        final controller = UserLoggingReminderController(
          userScope: 'user',
          repository: repository,
          gateway: gateway,
        );

        expect(await controller.save(_reminder()), isFalse);

        expect(await repository.load('user'), isEmpty);
        expect(gateway.synchronizationCount, 2);
        expect(gateway.synchronized, isEmpty);
        expect(
          controller.lastRollbackResult?.status,
          ReminderNotificationMutationStatus.applied,
        );
        expect(
          controller.scheduleSystemState,
          ReminderScheduleSystemState.verified,
        );
        expect(controller.recoveryRequired, isFalse);
      },
    );

    test('rollback failure exposes recovery-required system state', () async {
      final storage = _MemoryDataService();
      final repository = UserLoggingReminderRepository(storage: storage);
      final gateway = _ScriptedLeaseGateway(failingSynchronizations: {2, 3});
      final controller = UserLoggingReminderController(
        userScope: 'user',
        repository: repository,
        gateway: gateway,
      );

      await controller.load();
      expect(controller.lastSynchronizedAt, isNotNull);

      expect(await controller.save(_reminder()), isFalse);

      expect(controller.error, 'recovery_required');
      expect(controller.lastSynchronizedAt, isNull);
      expect(await repository.load('user'), isEmpty);
      expect(gateway.synchronizationCount, 3);
      expect(controller.lastRollbackResult, isNull);
      expect(controller.recoveryRequired, isTrue);
      expect(controller.systemStateUnverified, isTrue);
      expect(
        controller.scheduleSystemState,
        ReminderScheduleSystemState.recoveryRequired,
      );
    });

    test('sign-out cancellation dominates a stale rollback lease', () async {
      final storage = _MemoryDataService();
      final repository = UserLoggingReminderRepository(storage: storage);
      final gateway = _ScriptedLeaseGateway(
        blockFirstSynchronization: true,
        failingSynchronizations: {1},
      );
      final controller = UserLoggingReminderController(
        userScope: 'user-a',
        repository: repository,
        gateway: gateway,
      );

      final save = controller.save(_reminder());
      await gateway.firstSynchronizationStarted.future;
      final cancellation = gateway.cancelScheduledRemindersWithResult();
      gateway.releaseFirstSynchronization();

      expect(await save, isFalse);
      await cancellation;
      expect(await repository.load('user-a'), isEmpty);
      expect(gateway.synchronizationCount, 1);
      expect(gateway.cancellationCount, 1);
      expect(gateway.synchronized, isEmpty);
      expect(
        controller.lastRollbackResult?.status,
        ReminderNotificationMutationStatus.superseded,
      );
      expect(controller.recoveryRequired, isFalse);
      expect(controller.systemStateUnverified, isTrue);
    });

    test('new account lease supersedes A without persisting A', () async {
      final storage = _MemoryDataService();
      final repository = UserLoggingReminderRepository(storage: storage);
      final gateway = _ScriptedLeaseGateway(blockFirstSynchronization: true);
      final controllerA = UserLoggingReminderController(
        userScope: 'user-a',
        repository: repository,
        gateway: gateway,
      );
      final controllerB = UserLoggingReminderController(
        userScope: 'user-b',
        repository: repository,
        gateway: gateway,
      );

      final saveA = controllerA.save(_reminder(label: 'A'));
      await gateway.firstSynchronizationStarted.future;
      final saveB = controllerB.save(_reminder(id: 'reminder-b', label: 'B'));
      gateway.releaseFirstSynchronization();

      expect(await saveA, isFalse);
      expect(await saveB, isTrue);
      expect(await repository.load('user-a'), isEmpty);
      expect((await repository.load('user-b')).single.label, 'B');
      expect(controllerA.lastSynchronizedAt, isNull);
      expect(
        controllerA.lastMutationResult?.status,
        ReminderNotificationMutationStatus.superseded,
      );
      expect(
        controllerB.lastMutationResult?.status,
        ReminderNotificationMutationStatus.applied,
      );
      expect(gateway.synchronized.single.label, 'B');
    });

    test(
      'same-scope newer controller wins native and durable persistence',
      () async {
        final storage = _BlockingFirstWriteDataService();
        addTearDown(storage.releaseFirstWrite);
        final repository = UserLoggingReminderRepository(storage: storage);
        final gateway = _ScriptedLeaseGateway();
        final controllerA = UserLoggingReminderController(
          userScope: 'user',
          repository: repository,
          gateway: gateway,
        );
        final controllerB = UserLoggingReminderController(
          userScope: 'user',
          repository: repository,
          gateway: gateway,
        );

        final saveA = controllerA.save(_reminder(label: 'A'));
        await storage.firstWriteStarted.future;
        final saveB = controllerB.save(_reminder(id: 'reminder-b', label: 'B'));
        await gateway.secondSynchronizationApplied.future;

        expect(gateway.synchronized.single.label, 'B');
        storage.releaseFirstWrite();

        expect(await saveA, isFalse);
        expect(await saveB, isTrue);
        expect((await repository.load('user')).single.label, 'B');
        expect(gateway.synchronized.single.label, 'B');
        expect(
          controllerA.lastPersistenceMutationResult?.status,
          ReminderPersistenceMutationStatus.superseded,
        );
        expect(controllerA.lastPersistenceRollbackResult, isNull);
        expect(
          controllerB.lastPersistenceMutationResult?.status,
          ReminderPersistenceMutationStatus.applied,
        );
      },
    );

    test(
      'collision preflight runs before permission, native, or save',
      () async {
        const first = 'reminder_5bd6179aa3582d38e91a5cba7bf5de6b';
        const second = 'reminder_0c8d58cb34309c90508c88440b15a0a3';
        final storage = _MemoryDataService();
        final repository = UserLoggingReminderRepository(storage: storage);
        final gateway = _FakeGateway();
        final controller = UserLoggingReminderController(
          userScope: 'user',
          repository: repository,
          gateway: gateway,
        );
        expect(await controller.save(_reminder(id: first)), isTrue);
        final permissionCount = gateway.permissionRequestCount;
        final synchronizationCount = gateway.synchronizationCount;

        final saved = await controller.save(_reminder(id: second));

        expect(saved, isFalse);
        expect(controller.error, 'schedule_invalid');
        expect(gateway.permissionRequestCount, permissionCount);
        expect(gateway.synchronizationCount, synchronizationCount);
        expect((await repository.load('user')).single.id, first);
        expect(
          controller.scheduleManifest?.failure?.kind,
          ReminderScheduleManifestFailureKind.notificationIdCollision,
        );
      },
    );

    test(
      'plan-only platform saves ids that collide only in native space',
      () async {
        const first = 'reminder_5bd6179aa3582d38e91a5cba7bf5de6b';
        const second = 'reminder_0c8d58cb34309c90508c88440b15a0a3';
        final storage = _MemoryDataService();
        final repository = UserLoggingReminderRepository(storage: storage);
        final gateway = _FakeGateway(supportsScheduledDelivery: false);
        final controller = UserLoggingReminderController(
          userScope: 'user',
          repository: repository,
          gateway: gateway,
        );

        expect(await controller.save(_reminder(id: first)), isTrue);
        expect(await controller.save(_reminder(id: second)), isTrue);

        expect(controller.reminders.map((reminder) => reminder.id), {
          first,
          second,
        });
        expect((await repository.load('user')), hasLength(2));
        expect(gateway.permissionRequestCount, 0);
        expect(gateway.synchronizationCount, 0);
        expect(controller.scheduleManifest, isNull);
        expect(
          controller.scheduleSystemState,
          ReminderScheduleSystemState.unsupported,
        );
      },
    );

    test('plan-only platform still rejects invalid local schema', () async {
      final repository = UserLoggingReminderRepository(
        storage: _MemoryDataService(),
      );
      final gateway = _FakeGateway(supportsScheduledDelivery: false);
      final controller = UserLoggingReminderController(
        userScope: 'user',
        repository: repository,
        gateway: gateway,
      );

      expect(await controller.save(_reminder(label: '')), isFalse);

      expect(controller.error, 'schedule_invalid');
      expect(await repository.load('user'), isEmpty);
      expect(gateway.synchronizationCount, 0);
      expect(gateway.permissionRequestCount, 0);
    });

    test('editing or toggling rotates the one-time plan capability', () async {
      final storage = _MemoryDataService();
      final repository = UserLoggingReminderRepository(storage: storage);
      final controller = UserLoggingReminderController(
        userScope: 'user',
        repository: repository,
        gateway: _FakeGateway(supportsScheduledDelivery: false),
      );

      expect(await controller.save(_reminder()), isTrue);
      final afterSave = controller.reminders.single;
      expect(
        afterSave.activationToken,
        isNot('0123456789abcdef0123456789abcdef'),
      );
      final stalePayload =
          ReminderNotificationResponseCoordinator.payloadForReminder(afterSave);

      expect(await controller.toggle(afterSave, false), isTrue);
      final afterToggle = controller.reminders.single;
      expect(afterToggle.activationToken, isNot(afterSave.activationToken));

      final resolution =
          await ReminderNotificationResponseCoordinator(
            source: _FakeResponseSource(),
            repository: repository,
            activationInbox: _memoryActivationInbox(),
          ).resolve(
            event: ReminderNotificationResponseEvent(
              payload: stalePayload,
              origin: ReminderNotificationResponseOrigin.foreground,
            ),
            userScope: 'user',
          );
      expect(resolution.status, ReminderResponseResolutionStatus.unavailable);
    });

    test('notification boundary never claims or calculates a dose time', () {
      expect(reminderSafetyBoundary, contains('does not calculate'));
      expect(reminderSafetyBoundary, contains('prescribe a dose time'));
    });

    test('scheduled delivery uses an explicit platform allowlist', () async {
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      for (final platform in const {
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      }) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          LocalReminderNotificationGateway().supportsScheduledDelivery,
          isTrue,
          reason: platform.name,
        );
      }
      for (final platform in const {
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      }) {
        debugDefaultTargetPlatformOverride = platform;
        final gateway = LocalReminderNotificationGateway();
        expect(
          gateway.supportsScheduledDelivery,
          isFalse,
          reason: platform.name,
        );
        await expectLater(
          gateway.synchronize([_reminder()], userScope: 'user'),
          completes,
        );
        final lease = gateway.beginMutationLease(userScope: 'user');
        expect(
          (await gateway.synchronizeWithLease(
            [_reminder()],
            userScope: 'user',
            lease: lease,
          )).status,
          ReminderNotificationMutationStatus.unsupported,
        );
        expect(
          (await gateway.cancelScheduledRemindersWithResult()).status,
          ReminderNotificationMutationStatus.unsupported,
        );
      }
    });
  });

  group('ReminderNotificationActivationInbox', () {
    test(
      'persists one claim across independent file-store instances',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'parkinsum_activation_inbox_',
        );
        addTearDown(() => directory.delete(recursive: true));
        final storeA = FileReminderActivationRecordStore(
          directoryProvider: () async => directory,
        );
        final storeB = FileReminderActivationRecordStore(
          directoryProvider: () async => directory,
        );
        final inboxA = ReminderNotificationActivationInbox(store: storeA);
        final inboxB = ReminderNotificationActivationInbox(store: storeB);
        const payload =
            'parkinsum-reminder:v2:0123456789abcdef0123456789abcdef:reminder_1';

        final captured = await inboxA.capture(
          const ReminderNotificationResponseEvent(
            payload: payload,
            origin: ReminderNotificationResponseOrigin.coldStart,
          ),
        );
        expect((await inboxB.pending()).single.id, captured.id);

        final claims = await Future.wait([
          inboxA.claim(captured.id),
          inboxB.claim(captured.id),
        ]);
        expect(
          claims.map((claim) => claim.status),
          unorderedEquals(const [
            ReminderActivationClaimStatus.claimed,
            ReminderActivationClaimStatus.replayed,
          ]),
        );

        final raw = await File(
          '${directory.path}/$reminderActivationInboxFileName',
        ).readAsString();
        expect(raw, isNot(contains('Private label')));
        expect(raw, isNot(contains('user@example.com')));
        expect(raw, isNot(contains('local_user')));
      },
    );

    test('dedupes one callback window but not a later occurrence', () async {
      var now = DateTime.utc(2026, 8, 17, 12);
      final store = InMemoryReminderActivationRecordStore();
      final inbox = ReminderNotificationActivationInbox(
        store: store,
        now: () => now,
      );
      const event = ReminderNotificationResponseEvent(
        payload: 'opaque-payload',
        origin: ReminderNotificationResponseOrigin.foreground,
      );

      final first = await inbox.capture(event);
      now = now.add(const Duration(seconds: 5));
      final duplicate = await inbox.capture(event);
      now = now.add(const Duration(milliseconds: 1));
      final later = await inbox.capture(event);

      expect(duplicate.id, first.id);
      expect(later.id, isNot(first.id));
    });

    test('rejects invalid or repeatedly colliding activation ids', () async {
      final invalid = ReminderNotificationActivationInbox(
        store: InMemoryReminderActivationRecordStore(),
        newId: () => 'not-an-opaque-token',
      );
      const event = ReminderNotificationResponseEvent(
        payload: 'opaque-payload',
        origin: ReminderNotificationResponseOrigin.foreground,
      );
      await expectLater(invalid.capture(event), throwsStateError);

      await expectLater(
        ReminderNotificationActivationInbox(
          store: InMemoryReminderActivationRecordStore(),
        ).capture(
          ReminderNotificationResponseEvent(
            payload: List<String>.filled(129, 'é').join(),
            origin: ReminderNotificationResponseOrigin.foreground,
          ),
        ),
        throwsFormatException,
      );

      const collision = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final store = InMemoryReminderActivationRecordStore();
      final colliding = ReminderNotificationActivationInbox(
        store: store,
        dedupeWindow: Duration.zero,
        newId: () => collision,
      );
      await colliding.capture(event);
      await expectLater(
        colliding.capture(
          const ReminderNotificationResponseEvent(
            payload: 'different-payload',
            origin: ReminderNotificationResponseOrigin.foreground,
          ),
        ),
        throwsStateError,
      );
    });

    test('expires, discards, and bounds pending events fail closed', () async {
      var now = DateTime.utc(2026, 8, 17, 12);
      final store = InMemoryReminderActivationRecordStore();
      final inbox = ReminderNotificationActivationInbox(
        store: store,
        now: () => now,
        retention: const Duration(minutes: 10),
        dedupeWindow: Duration.zero,
        maxEntries: 2,
      );
      ReminderNotificationResponseEvent event(String payload) =>
          ReminderNotificationResponseEvent(
            payload: payload,
            origin: ReminderNotificationResponseOrigin.foreground,
          );

      final first = await inbox.capture(event('first'));
      now = now.add(const Duration(microseconds: 1));
      final second = await inbox.capture(event('second'));
      now = now.add(const Duration(microseconds: 1));
      await expectLater(inbox.capture(event('third')), throwsStateError);

      await inbox.discard(first.id);
      expect(
        (await inbox.claim(first.id)).status,
        ReminderActivationClaimStatus.discarded,
      );
      final third = await inbox.capture(event('third'));
      expect(third.id, isNot(first.id));

      now = now.add(const Duration(minutes: 11));
      expect(
        (await inbox.claim(second.id)).status,
        ReminderActivationClaimStatus.expired,
      );
      expect(
        (await inbox.claim(third.id)).status,
        ReminderActivationClaimStatus.missing,
      );
    });

    test('corrupt durable state is rejected instead of reset', () async {
      final directory = await Directory.systemTemp.createTemp(
        'parkinsum_activation_corrupt_',
      );
      addTearDown(() => directory.delete(recursive: true));
      await File(
        '${directory.path}/$reminderActivationInboxFileName',
      ).writeAsString('{not-json');
      final inbox = ReminderNotificationActivationInbox(
        store: FileReminderActivationRecordStore(
          directoryProvider: () async => directory,
        ),
      );

      await expectLater(inbox.pending(), throwsFormatException);
      expect(
        directory.listSync().whereType<File>().where(
          (file) => file.path.contains('.corrupt.'),
        ),
        hasLength(1),
      );
      expect(await inbox.pending(), isEmpty);
    });
  });

  group('ReminderNativeMutationQueue', () {
    test(
      'keeps timed-out work in the serial tail before account cancellation',
      () async {
        final queue = ReminderNativeMutationQueue();
        final mutationStarted = Completer<void>();
        final releaseMutation = Completer<void>();
        final events = <String>[];

        final oldSynchronization = queue.synchronize(
          userScope: 'old-user',
          operation: (isCurrent) async {
            events.add('old:start');
            mutationStarted.complete();
            await releaseMutation.future;
            events.add('old:current=${isCurrent()}');
          },
        );
        await mutationStarted.future;
        await expectLater(
          oldSynchronization.timeout(Duration.zero),
          throwsA(isA<TimeoutException>()),
        );

        final cancellation = queue.cancel(
          operation: () async => events.add('cancel'),
        );
        expect(events, const ['old:start']);

        releaseMutation.complete();
        final results = await Future.wait([oldSynchronization, cancellation]);
        expect(events, const ['old:start', 'old:current=false', 'cancel']);
        expect(results.map((result) => result.status), const [
          ReminderNotificationMutationStatus.superseded,
          ReminderNotificationMutationStatus.applied,
        ]);
      },
    );

    test(
      'newer account work invalidates and follows the old mutation',
      () async {
        final queue = ReminderNativeMutationQueue();
        final oldStarted = Completer<void>();
        final releaseOld = Completer<void>();
        final events = <String>[];

        final oldSynchronization = queue.synchronize(
          userScope: 'old-user',
          operation: (isCurrent) async {
            events.add('old:start');
            oldStarted.complete();
            await releaseOld.future;
            events.add('old:current=${isCurrent()}');
          },
        );
        await oldStarted.future;
        final newSynchronization = queue.synchronize(
          userScope: 'new-user',
          operation: (isCurrent) async {
            events.add('new:current=${isCurrent()}');
          },
        );

        expect(events, const ['old:start']);
        releaseOld.complete();
        final results = await Future.wait([
          oldSynchronization,
          newSynchronization,
        ]);
        expect(events, const [
          'old:start',
          'old:current=false',
          'new:current=true',
        ]);
        expect(results.map((result) => result.status), const [
          ReminderNotificationMutationStatus.superseded,
          ReminderNotificationMutationStatus.applied,
        ]);
      },
    );

    test('lease cannot be transferred across account or queue', () async {
      final queueA = ReminderNativeMutationQueue();
      final queueB = ReminderNativeMutationQueue();
      final lease = queueA.beginLease(userScope: 'user-a');

      expect(
        () => queueA.isCurrent(lease, userScope: 'user-b'),
        throwsArgumentError,
      );
      expect(
        () => queueB.isCurrent(lease, userScope: 'user-a'),
        throwsArgumentError,
      );
    });
  });

  group('ReminderNotificationResponseCoordinator', () {
    test('payload is opaque and rejects unsafe reminder ids', () {
      final reminder = _reminder(
        id: 'reminder_123',
        label: 'Private reminder label',
      );
      final payload =
          ReminderNotificationResponseCoordinator.payloadForReminder(reminder);
      expect(payload, startsWith('parkinsum-reminder:v2:'));
      expect(payload, endsWith(':reminder_123'));
      expect(payload, isNot(contains('user@example.com')));
      expect(payload, isNot(contains('Private reminder label')));
      expect(
        () => ReminderNotificationResponseCoordinator.payloadForReminder(
          _reminder(id: 'patient@example.com/reminder'),
        ),
        throwsFormatException,
      );
    });

    test('opens only the current user enabled reminder kind', () async {
      final storage = _MemoryDataService();
      final repository = UserLoggingReminderRepository(storage: storage);
      await repository.save('user-a', [
        _reminder(id: 'meal-reminder', kind: UserLoggingReminderKind.mealLog),
      ]);
      final coordinator = ReminderNotificationResponseCoordinator(
        source: _FakeResponseSource(),
        repository: repository,
        activationInbox: _memoryActivationInbox(),
      );
      final event = ReminderNotificationResponseEvent(
        payload: ReminderNotificationResponseCoordinator.payloadForReminder(
          _reminder(id: 'meal-reminder', kind: UserLoggingReminderKind.mealLog),
        ),
        origin: ReminderNotificationResponseOrigin.foreground,
      );

      expect(
        (await coordinator.resolve(event: event, userScope: 'user-a')).status,
        ReminderResponseResolutionStatus.openMealDraft,
      );

      final otherCoordinator = ReminderNotificationResponseCoordinator(
        source: _FakeResponseSource(),
        repository: repository,
        activationInbox: _memoryActivationInbox(),
      );
      expect(
        (await otherCoordinator.resolve(
          event: event,
          userScope: 'user-b',
        )).status,
        ReminderResponseResolutionStatus.unavailable,
      );
    });

    test(
      'malformed, deleted, disabled, and rapid replay fail closed',
      () async {
        final storage = _MemoryDataService();
        final repository = UserLoggingReminderRepository(storage: storage);
        await repository.save('user', [
          _reminder(id: 'disabled').copyWith(enabled: false),
          _reminder(id: 'enabled'),
        ]);
        var now = DateTime(2026, 8, 17, 12);
        final coordinator = ReminderNotificationResponseCoordinator(
          source: _FakeResponseSource(),
          repository: repository,
          activationInbox: _memoryActivationInbox(now: () => now),
        );

        Future<ReminderResponseResolutionStatus> resolve(
          String? payload,
        ) async => (await coordinator.resolve(
          event: ReminderNotificationResponseEvent(
            payload: payload,
            origin: ReminderNotificationResponseOrigin.coldStart,
          ),
          userScope: 'user',
        )).status;

        expect(await resolve(null), ReminderResponseResolutionStatus.malformed);
        expect(
          await resolve('parkinsum-reminder:v2:bad/id'),
          ReminderResponseResolutionStatus.malformed,
        );
        expect(
          await resolve(
            ReminderNotificationResponseCoordinator.payloadForReminder(
              _reminder(id: 'deleted'),
            ),
          ),
          ReminderResponseResolutionStatus.unavailable,
        );
        expect(
          await resolve(
            ReminderNotificationResponseCoordinator.payloadForReminder(
              _reminder(id: 'disabled').copyWith(enabled: false),
            ),
          ),
          ReminderResponseResolutionStatus.unavailable,
        );
        final enabledPayload =
            ReminderNotificationResponseCoordinator.payloadForReminder(
              _reminder(id: 'enabled'),
            );
        expect(
          await resolve(enabledPayload),
          ReminderResponseResolutionStatus.openIntakeDraft,
        );
        expect(
          await resolve(enabledPayload),
          ReminderResponseResolutionStatus.replayed,
        );
        now = now.add(const Duration(seconds: 6));
        expect(
          await resolve(enabledPayload),
          ReminderResponseResolutionStatus.openIntakeDraft,
        );
      },
    );
  });

  testWidgets('reminder center creates a user-authored local plan', (
    tester,
  ) async {
    final repository = UserLoggingReminderRepository(
      storage: _MemoryDataService(),
    );
    final controller = UserLoggingReminderController(
      userScope: 'user',
      repository: repository,
      gateway: _FakeGateway(supportsScheduledDelivery: false),
    );
    await pumpFeaturePage(
      tester,
      ReminderCenterPage(controller: controller),
      settle: true,
    );

    expect(find.text('Logging prompt only'), findsOneWidget);
    expect(
      find.text('Recurring system delivery is unavailable here'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('reminder-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('reminder-label')),
      'Log my evening intake',
    );
    expect(find.text('System notification preview'), findsOneWidget);
    expect(find.text('ParkinSUM'), findsWidgets);
    expect(
      find.text('Open ParkinSUM to review a private reminder.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('reminder-save')));
    await tester.pumpAndSettle();

    expect(find.text('Log my evening intake'), findsOneWidget);
    expect(controller.reminders.single.label, 'Log my evening intake');
    expect(controller.reminders.single.enabled, isTrue);
    expect(
      controller.reminders.single.notificationPrivacyMode,
      ReminderNotificationPrivacyMode.minimal,
    );
    expect(controller.reminders.single.notificationLocaleCode, 'en-US');

    final originalId = controller.reminders.single.id;
    expect(originalId, matches(RegExp(r'^reminder_[a-f0-9]{32}$')));
    final edit = find.byKey(ValueKey('reminder-edit-$originalId'));
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.text('Edit reminder'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('reminder-label')),
      'Log my updated evening intake',
    );
    final privacyMode = find.byKey(const ValueKey('reminder-privacy-mode'));
    await tester.ensureVisible(privacyMode);
    await tester.tap(privacyMode);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generic logging prompt').last);
    await tester.pumpAndSettle();
    expect(find.text('ParkinSUM logging reminder'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reminder-save')));
    await tester.pumpAndSettle();

    expect(controller.reminders.single.id, originalId);
    expect(controller.reminders.single.label, 'Log my updated evening intake');
    expect(
      controller.reminders.single.notificationPrivacyMode,
      ReminderNotificationPrivacyMode.generic,
    );
    expect(find.text('Log my updated evening intake'), findsOneWidget);

    final delete = find.byKey(ValueKey('reminder-delete-$originalId'));
    await tester.ensureVisible(delete);
    await tester.pumpAndSettle();
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('reminder-delete-confirmation')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('reminder-delete-confirm')));
    await tester.pumpAndSettle();

    expect(controller.reminders, isEmpty);
    expect(find.text('No logging reminders yet'), findsOneWidget);
    expectNoWidgetErrors();
  });

  testWidgets('reminder center reconciles system plans when app resumes', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    final repository = UserLoggingReminderRepository(
      storage: _MemoryDataService(),
    );
    await repository.save('user', [_reminder()]);
    final controller = UserLoggingReminderController(
      userScope: 'user',
      repository: repository,
      gateway: gateway,
    );
    await pumpFeaturePage(
      tester,
      ReminderCenterPage(controller: controller),
      settle: true,
    );
    expect(gateway.synchronizationCount, 1);
    expect(find.byKey(const ValueKey('reminder-sync-status')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reminder-schedule-capacity')),
      findsOneWidget,
    );
    expect(
      find.textContaining('ParkinSUM-planned requests: 3/64'),
      findsOneWidget,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(gateway.synchronizationCount, 2);
    expect(controller.error, isNull);
    expectNoWidgetErrors();
  });

  testWidgets(
    'notification intake draft requires explicit medication and writes nothing on open',
    (tester) async {
      final state = createTestAppState();
      final before = state.intakes.length;
      await pumpFeaturePage(
        tester,
        const IntakeEditorPage(
          key: ValueKey<String>('reminder-intake-draft'),
          requireExplicitMedicationSelection: true,
        ),
        state: state,
        settle: true,
      );

      expect(
        find.byKey(
          const ValueKey<String>('reminder-intake-medication-selection'),
        ),
        findsOneWidget,
      );
      expect(state.intakes.length, before);
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('intake-save')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('intake-save')));
      await tester.pumpAndSettle();

      expect(find.text('Select a medication first'), findsOneWidget);
      expect(state.intakes.length, before);
      expectNoWidgetErrors();
    },
  );
}

UserLoggingReminder _reminder({
  String id = 'reminder-1',
  String label = 'Log intake',
  UserLoggingReminderKind kind = UserLoggingReminderKind.intakeLog,
}) => UserLoggingReminder(
  id: id,
  kind: kind,
  label: label,
  minuteOfDay: 9 * 60 + 15,
  weekdays: const {1, 3, 5},
  enabled: true,
  activationToken: '0123456789abcdef0123456789abcdef',
);

ReminderNotificationActivationInbox _memoryActivationInbox({
  DateTime Function()? now,
  ReminderActivationRecordStore? store,
}) => ReminderNotificationActivationInbox(
  store: store ?? InMemoryReminderActivationRecordStore(),
  now: now,
);

class _MemoryDataService extends DataService {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

class _FailingMemoryDataService extends _MemoryDataService {
  bool failWrites = false;

  @override
  Future<void> setString(String key, String value) async {
    if (failWrites) throw StateError('synthetic persistence failure');
    await super.setString(key, value);
  }
}

class _BlockingFirstWriteDataService extends _MemoryDataService {
  final Completer<void> firstWriteStarted = Completer<void>();
  final Completer<void> _releaseFirst = Completer<void>();
  int _writeCount = 0;

  @override
  Future<void> setString(String key, String value) async {
    _writeCount += 1;
    if (_writeCount == 1) {
      firstWriteStarted.complete();
      await _releaseFirst.future;
    }
    await super.setString(key, value);
  }

  void releaseFirstWrite() {
    if (!_releaseFirst.isCompleted) _releaseFirst.complete();
  }
}

class _FakeGateway
    implements ReminderNotificationGateway, ReminderNotificationPreflight {
  _FakeGateway({
    this.supportsScheduledDelivery = true,
    this.permissionGranted = true,
  });

  @override
  final bool supportsScheduledDelivery;
  final bool permissionGranted;
  List<UserLoggingReminder> synchronized = const [];
  int synchronizationCount = 0;
  int permissionRequestCount = 0;

  @override
  Future<bool> requestPermission() async {
    permissionRequestCount += 1;
    return permissionGranted;
  }

  @override
  ReminderScheduleManifestResult preflightSchedule(
    List<UserLoggingReminder> reminders,
  ) => const ReminderScheduleManifestPreflight().evaluate(
    reminders,
    budget: supportsScheduledDelivery
        ? const ReminderScheduleBudget(
            requestLimit: reminderScheduleProductRequestLimit,
          )
        : null,
  );

  @override
  Future<void> synchronize(
    List<UserLoggingReminder> reminders, {
    required String userScope,
  }) async {
    synchronizationCount += 1;
    synchronized = List.unmodifiable(reminders);
  }
}

class _ScriptedLeaseGateway
    implements
        ReminderNotificationGateway,
        ReminderNotificationLeaseGateway,
        ReminderNotificationPreflight,
        ReminderNotificationAccountLifecycle,
        ReminderNotificationResultAccountLifecycle {
  _ScriptedLeaseGateway({
    this.blockFirstSynchronization = false,
    Set<int> failingSynchronizations = const {},
  }) : failingSynchronizations = Set.unmodifiable(failingSynchronizations);

  final bool blockFirstSynchronization;
  final Set<int> failingSynchronizations;
  final ReminderNativeMutationQueue _queue = ReminderNativeMutationQueue();
  final Completer<void> firstSynchronizationStarted = Completer<void>();
  final Completer<void> secondSynchronizationApplied = Completer<void>();
  final Completer<void> _releaseFirst = Completer<void>();

  List<UserLoggingReminder> synchronized = const [];
  int synchronizationCount = 0;
  int cancellationCount = 0;

  @override
  bool get supportsScheduledDelivery => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  ReminderScheduleManifestResult preflightSchedule(
    List<UserLoggingReminder> reminders,
  ) => const ReminderScheduleManifestPreflight().evaluate(
    reminders,
    budget: const ReminderScheduleBudget(
      requestLimit: reminderScheduleProductRequestLimit,
    ),
  );

  @override
  ReminderNotificationMutationLease beginMutationLease({
    required String userScope,
  }) => _queue.beginLease(userScope: userScope);

  @override
  bool isMutationLeaseCurrent(
    ReminderNotificationMutationLease lease, {
    required String userScope,
  }) => _queue.isCurrent(lease, userScope: userScope);

  @override
  Future<ReminderNotificationMutationResult> synchronizeWithLease(
    List<UserLoggingReminder> reminders, {
    required String userScope,
    required ReminderNotificationMutationLease lease,
  }) => _queue.synchronizeWithLease(
    userScope: userScope,
    lease: lease,
    operation: (isCurrent) async {
      synchronizationCount += 1;
      final invocation = synchronizationCount;
      if (invocation == 1 && !firstSynchronizationStarted.isCompleted) {
        firstSynchronizationStarted.complete();
      }
      if (invocation == 1 && blockFirstSynchronization) {
        await _releaseFirst.future;
      }
      if (failingSynchronizations.contains(invocation)) {
        throw StateError('synthetic synchronization failure $invocation');
      }
      if (isCurrent()) {
        synchronized = List.unmodifiable(reminders);
        if (invocation == 2 && !secondSynchronizationApplied.isCompleted) {
          secondSynchronizationApplied.complete();
        }
      }
    },
  );

  @override
  Future<void> synchronize(
    List<UserLoggingReminder> reminders, {
    required String userScope,
  }) async {
    final result = await synchronizeWithLease(
      reminders,
      userScope: userScope,
      lease: beginMutationLease(userScope: userScope),
    );
    if (result.status == ReminderNotificationMutationStatus.superseded) {
      throw const ReminderNotificationMutationSupersededException();
    }
  }

  void releaseFirstSynchronization() {
    if (!_releaseFirst.isCompleted) _releaseFirst.complete();
  }

  @override
  Future<ReminderNotificationMutationResult>
  cancelScheduledRemindersWithResult() => _queue.cancel(
    operation: () async {
      cancellationCount += 1;
      synchronized = const [];
    },
  );

  @override
  Future<void> cancelScheduledReminders() =>
      cancelScheduledRemindersWithResult().then<void>((_) {});
}

class _FakeResponseSource implements ReminderNotificationResponseSource {
  final StreamController<ReminderNotificationResponseEvent> _controller =
      StreamController<ReminderNotificationResponseEvent>.broadcast();

  @override
  Stream<ReminderNotificationResponseEvent> get responses => _controller.stream;

  @override
  Future<void> startResponseHandling() async {}
}
