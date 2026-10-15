import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/app_database_web.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/user_preference_write_scope.dart';
import 'package:parkinsum_companion/core/services/care_workspace_service.dart';
import 'package:parkinsum_companion/core/services/care_workspace_store.dart';
import 'package:parkinsum_companion/core/services/origin_storage_coordination.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/features/shared/local_storage_stale_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'platform participating lock encloses the whole action and releases after failures',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final order = <String>[];
      final first = withOriginStorageLock('synthetic.lock', () async {
        order.add('A-read');
        entered.complete();
        await release.future;
        order.add('A-write');
        return 1;
      });
      await entered.future;
      final second = withOriginStorageLock('synthetic.lock', () async {
        order.add('B-read');
        return 2;
      });
      if (kIsWeb) {
        await expectLater(second, throwsA(isA<OriginStorageBusy>()));
      } else {
        await Future<void>.delayed(Duration.zero);
      }
      expect(order, ['A-read']);
      release.complete();
      expect(await first, 1);
      if (kIsWeb) {
        expect(
          await withOriginStorageLock('synthetic.lock', () async {
            order.add('B-read');
            return 2;
          }),
          2,
        );
      } else {
        expect(await second, 2);
      }
      expect(order, ['A-read', 'A-write', 'B-read']);
      await expectLater(
        withOriginStorageLock<void>('synthetic.lock', () async {
          throw StateError('synthetic failure');
        }),
        throwsStateError,
      );
      expect(await withOriginStorageLock('synthetic.lock', () async => 3), 3);
    },
  );

  test('invalid namespace never invokes a write', () async {
    var called = false;
    await expectLater(
      withOriginStorageLock<void>('raw owner / unsafe', () async {
        called = true;
      }),
      throwsArgumentError,
    );
    expect(called, isFalse);
  });

  test(
    'Web profile source witness rejects an earlier preview after another profile save',
    () async {
      final db = WebAppDatabase();
      final before = await db.loadUserProfile();
      final scope = UserPreferenceWriteScope(
        ownerUid: before.patientId,
        sessionEpoch: 1,
        isCurrent: () => true,
        expectedProfileDigest: userPreferenceProfileDigest(before),
      );
      await db.saveUserProfileForSession(
        before.copyWith(displayLocale: 'zh-CN'),
        scope: scope,
      );
      await expectLater(
        db.saveUserProfileForSession(
          before.copyWith(displayLocale: 'ar'),
          scope: scope,
        ),
        throwsStateError,
      );
      expect((await db.loadUserProfile()).displayLocale, 'zh-CN');
    },
  );

  test(
    'Web selection source witness rejects stale whole-selection replacement',
    () async {
      final db = WebAppDatabase();
      final profile = await db.loadUserProfile();
      final scope = UserPreferenceWriteScope(
        ownerUid: profile.patientId,
        sessionEpoch: 1,
        isCurrent: () => true,
        expectedActiveSelectionDigest: userPreferenceSelectionDigest([]),
      );
      await db.saveActiveDrugIdsForSession(['synthetic-a'], scope: scope);
      await expectLater(
        db.saveActiveDrugIdsForSession(['synthetic-b'], scope: scope),
        throwsStateError,
      );
      expect(await db.loadActiveDrugIds(), ['synthetic-a']);
      expect(
        userPreferenceSelectionDigest(['b', 'a', 'a']),
        userPreferenceSelectionDigest(['a', 'b']),
      );
    },
  );

  test(
    'two actual Care services retain both records through the platform whole-mutation lock',
    () async {
      final heldStore = _HeldLocalCareStore();
      final a = CareWorkspaceService(store: heldStore);
      final b = CareWorkspaceService(store: LocalCareWorkspaceStore());
      Future<void> add(CareWorkspaceService service, String id) async {
        await service.mutate(
          'synthetic-owner',
          (current) => current.copyWith(
            notes: [
              ...current.notes,
              CareDiscussionNote(
                id: id,
                text: id,
                recordedAt: DateTime.utc(2026, 10, 1),
                recorderId: 'synthetic-owner',
              ),
            ],
          ),
          authorize: () => true,
        );
      }

      final first = add(a, 'a');
      await heldStore.entered.future;
      final second = add(b, 'b');
      if (kIsWeb) {
        await expectLater(second, throwsA(isA<OriginStorageBusy>()));
      } else {
        await Future<void>.delayed(Duration.zero);
      }
      expect(await heldStore.read('synthetic-owner'), isNull);
      heldStore.release.complete();
      await first;
      if (kIsWeb) {
        final committed = await a.load('synthetic-owner');
        expect(committed.notes.map((note) => note.id), ['a']);
        await add(b, 'b');
      } else {
        await second;
      }
      final expected = [
        for (final id in ['a', 'b'])
          CareDiscussionNote(
            id: id,
            text: id,
            recordedAt: DateTime.utc(2026, 10, 1),
            recorderId: 'synthetic-owner',
          ).toJson(),
      ];
      expect(
        (await a.load('synthetic-owner')).notes.map((note) => note.toJson()),
        expected,
      );
      expect(
        (await b.load('synthetic-owner')).notes.map((note) => note.toJson()),
        expected,
      );
    },
  );

  test(
    'external-change observation expires state leases, derived cache and new mutations without deleting original records',
    () async {
      final events = StreamController<void>.broadcast();
      addTearDown(events.close);
      final services = Services.createEphemeral();
      await services.ready;
      await services.userDataService.saveOnboarded(true);
      final state = AppState(
        services: services,
        externalStorageChanges: events.stream,
      );
      addTearDown(state.dispose);
      await state.bootstrap();
      expect(
        await state.addDiscussionNote('Original retained question'),
        isTrue,
      );
      final lease = state.captureVisitPreparationLease();
      final epoch = state.preferenceMutationSessionEpoch;
      events.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(state.isLocalStorageStale, isTrue);
      expect(state.isVisitPreparationLeaseCurrent(lease), isFalse);
      expect(state.preferenceMutationSessionEpoch, greaterThan(epoch));
      expect(state.discussionNotes.single.text, 'Original retained question');
      expect(await state.addDiscussionNote('Do not save stale state'), isFalse);
      final profile = await state.saveUserProfile(
        state.userProfile.copyWith(displayLocale: 'zh-CN'),
      );
      expect(profile.wasCommitted, isFalse);
      final intake = Intake(
        id: 'do-not-persist',
        drugId: 'unknown',
        takenAt: DateTime.utc(2026, 10, 1),
        dosageNote: 'unknown',
      );
      final saved = await state.addIntake(intake);
      expect(saved.wasCommitted, isFalse);
      expect(await services.userDataService.loadIntakes(), isEmpty);
      expect(() => state.exportCarePortableData(), throwsStateError);
    },
  );

  for (final locale in ['en-US', 'zh-CN']) {
    testWidgets(
      '$locale stale-state explanation and explicit reload remain operable at 390px/200%',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var requests = 0;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: LocalStorageStalePage(
              localeTag: locale,
              onReload: () => requests++,
            ),
          ),
        );
        final button = find.byKey(
          const ValueKey('local-storage-explicit-reload'),
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
        expect(requests, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

/// Delays inside the real platform lock, before the first service reread.
final class _HeldLocalCareStore
    implements CareWorkspaceStore, CoordinatedCareWorkspaceStore {
  final _delegate = LocalCareWorkspaceStore();
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<T> coordinateMutation<T>(
    String ownerScope,
    Future<T> Function() mutation,
  ) => _delegate.coordinateMutation(ownerScope, () async {
    entered.complete();
    await release.future;
    return mutation();
  });

  @override
  Future<String?> read(String ownerScope) => _delegate.read(ownerScope);

  @override
  Future<void> write(
    String ownerScope,
    String document, {
    required bool Function() authorize,
  }) => _delegate.write(ownerScope, document, authorize: authorize);
}
