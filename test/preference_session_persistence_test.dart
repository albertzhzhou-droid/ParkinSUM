import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/app_database_memory.dart';
import 'package:parkinsum_companion/core/db/app_database_web.dart';
import 'package:parkinsum_companion/core/db/web_user_state_store.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/core/models/user_preference_write_scope.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/core/state/active_drug_selection_transaction.dart';
import 'package:parkinsum_companion/core/state/persisted_value_mutation.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final field in ['profile', 'active_drug']) {
    for (final transition in ['signout', 'same_uid_relogin', 'disposal']) {
      test('$field late dispatched acknowledgement after $transition', () async {
        SharedPreferences.setMockInitialValues({});
        final database = _DelayedDispatchedMemoryStore();
        final state = AppState(
          services: Services.createEphemeral(appDatabase: database),
        );
        await state.bootstrap();
        final startingOwner = state.currentUserId;
        var notifications = 0;
        state.addListener(() => notifications += 1);
        final gate = database.arm(field);
        final operation = field == 'profile'
            ? state
                  .saveUserProfile(
                    state.userProfile.copyWith(displayLocale: 'fr-CA'),
                  )
                  .then(
                    (result) => (
                      status: result.status.name,
                      applied: result.appliesToCurrentSession,
                      committed: result.wasCommitted,
                    ),
                  )
            : state
                  .setActiveDrugIds(['drug_levodopa_carbidopa'])
                  .then(
                    (result) => (
                      status: result.status.name,
                      applied: result.appliesToCurrentSession,
                      committed: result.wasCommitted,
                    ),
                  );
        await gate.started.future;
        if (transition == 'disposal') {
          state.dispose();
        } else {
          await state.signOut();
          if (transition == 'same_uid_relogin') {
            await state.bootstrap();
            expect(state.currentUserId, startingOwner);
          }
        }
        // Settle the synthetic auth stream before measuring old callbacks.
        await Future<void>.delayed(Duration.zero);
        final before = _visible(state);
        final notificationCount = notifications;
        gate.release.complete();
        final result = await operation;
        expect(result.status, 'committedForPreviousSession');
        expect(result.committed, true);
        expect(result.applied, false);
        expect(_visible(state), before);
        expect(notifications, notificationCount);
        // This seam delays an already dispatched call: never claim cancellation.
        if (field == 'profile') {
          expect((await database.loadUserProfile()).displayLocale, 'fr-CA');
        } else {
          expect(await database.loadActiveDrugIds(), [
            'drug_levodopa_carbidopa',
          ]);
        }
        if (transition != 'disposal') state.dispose();
      });
    }
  }

  test('a fresh session save survives the old request finally block', () async {
    final coordinator = PersistedValueMutationCoordinator<String>();
    final oldAck = Completer<void>();
    final newAck = Completer<void>();
    final applied = <String>[];
    final running = <bool>[];
    final old = coordinator.commit(
      previousValue: 'old',
      nextValue: 'old-session-next',
      persist: (_) => oldAck.future,
      apply: applied.add,
      refresh: () async {},
      onRunningChanged: running.add,
    );
    coordinator.invalidate();
    final fresh = coordinator.commit(
      previousValue: 'fresh',
      nextValue: 'fresh-next',
      persist: (_) => newAck.future,
      apply: applied.add,
      refresh: () async {},
      onRunningChanged: running.add,
    );
    oldAck.complete();
    expect(
      (await old).status,
      PersistedValueMutationStatus.committedForPreviousSession,
    );
    expect(coordinator.isRunning, true);
    expect(applied, isEmpty);
    newAck.complete();
    expect((await fresh).status, PersistedValueMutationStatus.committed);
    expect(applied, ['fresh-next']);
    expect(running, [true, true, false]);
  });

  test(
    'expiry during database readback preserves the acknowledged profile commit',
    () async {
      SharedPreferences.setMockInitialValues({});
      var authorized = true;
      final store = _ReadbackExpiryStore(() => authorized = false);
      final database = WebAppDatabase(userStateStore: store);
      final before = await database.loadUserProfile();
      var applied = 0;
      var refreshed = 0;
      final running = <bool>[];
      final result = await PersistedValueMutationCoordinator<UserProfile>()
          .commit(
            previousValue: before,
            nextValue: before.copyWith(
              patientId: 'synthetic_owner',
              displayLocale: 'fr-CA',
            ),
            persist: (value) => database.saveUserProfileForSession(
              value,
              scope: _scope(() => authorized),
            ),
            apply: (_) => applied += 1,
            refresh: () async => refreshed += 1,
            onRunningChanged: running.add,
            isCurrent: () => authorized,
          );
      expect(
        result.status,
        PersistedValueMutationStatus.committedForPreviousSession,
      );
      expect(result.wasCommitted, isTrue);
      expect(result.appliesToCurrentSession, isFalse);
      expect(applied, 0);
      expect(refreshed, 0);
      expect(running, [true]);
      expect(
        (await WebAppDatabase(
          userStateStore: store,
        ).loadUserProfile()).displayLocale,
        'fr-CA',
      );
    },
  );

  test(
    'already invalid authorization causes no persistence or callbacks',
    () async {
      final coordinator = PersistedValueMutationCoordinator<String>();
      var calls = 0;
      final result = await coordinator.commit(
        previousValue: 'old',
        nextValue: 'new',
        isCurrent: () => false,
        persist: (_) async => calls += 1,
        apply: (_) => calls += 1,
        refresh: () async => calls += 1,
        onRunningChanged: (_) => calls += 1,
      );
      expect(
        result.status,
        PersistedValueMutationStatus.cancelledBeforePersistence,
      );
      expect(result.wasCommitted, false);
      expect(calls, 0);
    },
  );

  test(
    'old persistence failure is distinct from cancelled or committed',
    () async {
      final coordinator = PersistedValueMutationCoordinator<String>();
      final persistence = Completer<void>();
      var calls = 0;
      final request = coordinator.commit(
        previousValue: 'old',
        nextValue: 'new',
        persist: (_) => persistence.future,
        apply: (_) => calls += 1,
        refresh: () async => calls += 1,
        onRunningChanged: (_) {},
      );
      coordinator.invalidate();
      persistence.completeError(StateError('late platform failure'));
      final result = await request;
      expect(
        result.status,
        PersistedValueMutationStatus.failedForPreviousSession,
      );
      expect(result.wasCommitted, false);
      expect(result.persistenceError, isA<StateError>());
      expect(calls, 0);
    },
  );

  test(
    'old medication acknowledgement cannot release a fresh running save',
    () async {
      final coordinator = ActiveDrugSelectionCoordinator();
      final oldAck = Completer<void>();
      final freshAck = Completer<void>();
      final applied = <List<String>>[];
      final running = <bool>[];
      final old = coordinator.commit(
        previousIds: ['old'],
        nextIds: ['old-next'],
        persist: (_) => oldAck.future,
        apply: applied.add,
        refresh: () async {},
        onRunningChanged: running.add,
      );
      coordinator.invalidate();
      final fresh = coordinator.commit(
        previousIds: ['fresh'],
        nextIds: ['fresh-next'],
        persist: (_) => freshAck.future,
        apply: applied.add,
        refresh: () async {},
        onRunningChanged: running.add,
      );
      oldAck.complete();
      expect(
        (await old).status,
        ActiveDrugSelectionCommitStatus.committedForPreviousSession,
      );
      expect(coordinator.isRunning, true);
      expect(applied, isEmpty);
      freshAck.complete();
      expect((await fresh).status, ActiveDrugSelectionCommitStatus.committed);
      expect(applied, [
        ['fresh-next'],
      ]);
      expect(running, [true, true, false]);
    },
  );

  test(
    'old medication failure does not emit a current-session error callback',
    () async {
      final coordinator = ActiveDrugSelectionCoordinator();
      final persistence = Completer<void>();
      var callbacks = 0;
      final pending = coordinator.commit(
        previousIds: ['old'],
        nextIds: ['new'],
        persist: (_) => persistence.future,
        apply: (_) => callbacks += 1,
        refresh: () async => callbacks += 1,
        onRunningChanged: (_) {},
        onError: (_, _) => callbacks += 1,
      );
      coordinator.invalidate();
      persistence.completeError(StateError('late platform failure'));
      final result = await pending;
      expect(
        result.status,
        ActiveDrugSelectionCommitStatus.failedForPreviousSession,
      );
      expect(result.wasCommitted, false);
      expect(result.appliesToCurrentSession, false);
      expect(result.persistenceError, isA<StateError>());
      expect(callbacks, 0);
    },
  );

  for (final backend in ['memory', 'web']) {
    test('$backend rejects a foreign profile before dispatch', () async {
      SharedPreferences.setMockInitialValues({});
      var writes = 0;
      final memory = InMemoryAppDatabase();
      final web = WebAppDatabase(
        userStateWriter: (prefs, key, value) async {
          writes += 1;
          return prefs.setString(key, value);
        },
      );
      final ScopedUserPreferenceStore store = backend == 'memory'
          ? memory
          : web;
      await expectLater(
        store.saveUserProfileForSession(
          UserProfile.defaults().copyWith(patientId: 'foreign_owner'),
          scope: _scope(() => true),
        ),
        throwsStateError,
      );
      expect(writes, 0);
      expect(
        (await memory.loadUserProfile()).patientId,
        isNot('foreign_owner'),
      );
      expect((await web.loadUserProfile()).patientId, isNot('foreign_owner'));
    });
  }

  for (final field in ['profile', 'active_drug']) {
    test('Web queued $field rechecks before platform dispatch', () async {
      SharedPreferences.setMockInitialValues({});
      final dispatched = Completer<void>();
      final firstAck = Completer<void>();
      var writes = 0;
      final database = WebAppDatabase(
        userStateWriter: (prefs, key, value) async {
          writes += 1;
          if (writes == 1) {
            dispatched.complete();
            await firstAck.future;
          }
          return prefs.setString(key, value);
        },
      );
      final firstScope = _scope(() => true);
      final first = database.saveUserProfileForSession(
        UserProfile.defaults().copyWith(patientId: 'synthetic_owner'),
        scope: firstScope,
      );
      await dispatched.future;
      var valid = true;
      final queuedScope = _scope(() => valid);
      final queued = field == 'profile'
          ? database.saveUserProfileForSession(
              UserProfile.defaults().copyWith(
                patientId: 'synthetic_owner',
                displayLocale: 'fr-CA',
              ),
              scope: queuedScope,
            )
          : database.saveActiveDrugIdsForSession([
              'synthetic_drug',
            ], scope: queuedScope);
      final rejected = expectLater(
        queued,
        throwsA(isA<UserPreferenceWriteScopeChanged>()),
      );
      valid = false;
      firstAck.complete();
      await first;
      await rejected;
      expect(writes, 1);
      expect((await database.loadUserProfile()).displayLocale, 'en-US');
      expect(await database.loadActiveDrugIds(), isEmpty);
      // Rejection must release the queue; the next authorized save can succeed.
      await database.saveActiveDrugIdsForSession([
        'fresh_drug',
      ], scope: firstScope);
      expect(await database.loadActiveDrugIds(), ['fresh_drug']);
      expect(writes, 2);
    });
  }
}

UserPreferenceWriteScope _scope(bool Function() valid) =>
    UserPreferenceWriteScope(
      ownerUid: 'synthetic_owner',
      sessionEpoch: 1,
      isCurrent: valid,
    );

String _visible(AppState state) => jsonEncode({
  'owner': state.currentUserId,
  'profile': state.userProfile.toJson(),
  'active_ids': state.activeDrugIds.toList(),
});

class _DelayedDispatchedMemoryStore extends InMemoryAppDatabase {
  String? _field;
  _WriteGate? _gate;

  _WriteGate arm(String field) {
    _field = field;
    return _gate = _WriteGate();
  }

  Future<void> _pause(String field) async {
    if (_field != field || _gate == null) return;
    final gate = _gate!;
    _gate = null;
    gate.started.complete();
    await gate.release.future;
  }

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    await _pause('profile');
    await super.saveUserProfile(profile);
  }

  @override
  Future<void> saveActiveDrugIds(List<String> ids) async {
    await _pause('active_drug');
    await super.saveActiveDrugIds(ids);
  }
}

class _WriteGate {
  final started = Completer<void>();
  final release = Completer<void>();
}

/// Expires the session after storage has acknowledged, during the database's
/// independent readback. This is later than the store's own publication hook.
class _ReadbackExpiryStore implements WebUserStateStore {
  _ReadbackExpiryStore(this.expire);

  final void Function() expire;
  String? _document;
  bool _awaitingReadback = false;

  @override
  String get backendId => 'synthetic acknowledged readback';

  @override
  Future<String?> read(WebUserStateLegacySnapshot legacy) async {
    if (_awaitingReadback) {
      _awaitingReadback = false;
      expire();
    }
    return _document;
  }

  @override
  Future<void> write(
    String document, {
    required String? expectedDocument,
    required WebUserStateLegacySnapshot legacy,
    required bool Function() authorize,
  }) async {
    if (!authorize() || expectedDocument != _document) {
      throw StateError('synthetic write refused');
    }
    _document = document;
    _awaitingReadback = true;
  }
}
