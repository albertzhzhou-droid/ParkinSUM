import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/state/persisted_list_mutation.dart';

void main() {
  test('persistence failure keeps the previous in-memory list', () async {
    final coordinator = PersistedListMutationCoordinator<String>();
    var applied = <String>['old'];
    var refreshCount = 0;
    final failures = <PersistedListMutationFailureStage>[];

    final result = await coordinator.commit(
      previousItems: applied,
      nextItems: const <String>['new'],
      persist: (_) async => throw StateError('storage unavailable'),
      apply: (items) => applied = items,
      refresh: () async => refreshCount += 1,
      onRunningChanged: (_) {},
      onError: (stage, _) => failures.add(stage),
    );

    expect(result.status, PersistedListMutationStatus.persistenceFailed);
    expect(result.shouldReportSaveFailure, isTrue);
    expect(applied, <String>['old']);
    expect(refreshCount, 0);
    expect(failures, <PersistedListMutationFailureStage>[
      PersistedListMutationFailureStage.persistence,
    ]);
  });

  test('commits in persist, apply, refresh order', () async {
    final coordinator = PersistedListMutationCoordinator<String>();
    final order = <String>[];

    final result = await coordinator.commit(
      previousItems: const <String>['old'],
      nextItems: const <String>['new'],
      persist: (_) async => order.add('persist'),
      apply: (_) => order.add('apply'),
      refresh: () async => order.add('refresh'),
      onRunningChanged: (running) => order.add('running:$running'),
    );

    expect(result.status, PersistedListMutationStatus.committed);
    expect(result.wasCommitted, isTrue);
    expect(order, <String>[
      'running:true',
      'persist',
      'apply',
      'refresh',
      'running:false',
    ]);
  });

  test('refresh failure preserves the committed list', () async {
    final coordinator = PersistedListMutationCoordinator<String>();
    var applied = <String>['old'];

    final result = await coordinator.commit(
      previousItems: applied,
      nextItems: const <String>['new'],
      persist: (_) async {},
      apply: (items) => applied = items,
      refresh: () async => throw StateError('derived view failed'),
      onRunningChanged: (_) {},
    );

    expect(
      result.status,
      PersistedListMutationStatus.committedWithRefreshFailure,
    );
    expect(result.wasCommitted, isTrue);
    expect(result.shouldReportSaveFailure, isFalse);
    expect(applied, <String>['new']);
  });

  test('concurrent mutation is rejected without a second write', () async {
    final coordinator = PersistedListMutationCoordinator<String>();
    final persistence = Completer<void>();
    var persistenceCount = 0;

    final first = coordinator.commit(
      previousItems: const <String>['a'],
      nextItems: const <String>['b'],
      persist: (_) {
        persistenceCount += 1;
        return persistence.future;
      },
      apply: (_) {},
      refresh: () async {},
      onRunningChanged: (_) {},
    );
    final second = await coordinator.commit(
      previousItems: const <String>['a'],
      nextItems: const <String>['c'],
      persist: (_) async => persistenceCount += 1,
      apply: (_) {},
      refresh: () async {},
      onRunningChanged: (_) {},
    );

    expect(second.status, PersistedListMutationStatus.busy);
    expect(second.shouldReportSaveFailure, isTrue);
    expect(persistenceCount, 1);
    persistence.complete();
    expect((await first).status, PersistedListMutationStatus.committed);
  });

  test('unchanged result does not enter the transaction', () {
    final coordinator = PersistedListMutationCoordinator<String>();

    final result = coordinator.unchanged(const <String>['same']);

    expect(result.status, PersistedListMutationStatus.unchanged);
    expect(result.wasCommitted, isFalse);
    expect(coordinator.isRunning, isFalse);
  });
}
