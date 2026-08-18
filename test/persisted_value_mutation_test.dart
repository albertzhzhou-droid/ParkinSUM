import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/state/persisted_value_mutation.dart';

void main() {
  test('persistence failure leaves the previous value applied', () async {
    final coordinator = PersistedValueMutationCoordinator<String>();
    var applied = 'old';
    final running = <bool>[];

    await expectLater(
      coordinator.commit(
        previousValue: 'old',
        nextValue: 'new',
        persist: (_) async => throw StateError('disk unavailable'),
        apply: (value) => applied = value,
        refresh: () async {},
        onRunningChanged: running.add,
      ),
      throwsStateError,
    );

    expect(applied, 'old');
    expect(running, [true, false]);
    expect(coordinator.isRunning, isFalse);
  });

  test('post-commit refresh failure remains a committed result', () async {
    final coordinator = PersistedValueMutationCoordinator<String>();
    var applied = 'old';
    final result = await coordinator.commit(
      previousValue: 'old',
      nextValue: 'new',
      persist: (_) async {},
      apply: (value) => applied = value,
      refresh: () async => throw StateError('derived view failed'),
      onRunningChanged: (_) {},
    );

    expect(applied, 'new');
    expect(
      result.status,
      PersistedValueMutationStatus.committedWithRefreshFailure,
    );
    expect(result.refreshError, isA<StateError>());
  });

  test(
    'overlapping commits are rejected without applying a second value',
    () async {
      final coordinator = PersistedValueMutationCoordinator<String>();
      final persistenceGate = Completer<void>();
      var applied = 'old';
      final first = coordinator.commit(
        previousValue: 'old',
        nextValue: 'first',
        persist: (_) => persistenceGate.future,
        apply: (value) => applied = value,
        refresh: () async {},
        onRunningChanged: (_) {},
      );

      final second = await coordinator.commit(
        previousValue: 'old',
        nextValue: 'second',
        persist: (_) async {},
        apply: (value) => applied = value,
        refresh: () async {},
        onRunningChanged: (_) {},
      );
      expect(second.status, PersistedValueMutationStatus.busy);
      expect(applied, 'old');

      persistenceGate.complete();
      expect((await first).status, PersistedValueMutationStatus.committed);
      expect(applied, 'first');
    },
  );
}
