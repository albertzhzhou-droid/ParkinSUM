import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/state/active_drug_selection_transaction.dart';

void main() {
  test('persistence failure leaves the previous selection applied', () async {
    final coordinator = ActiveDrugSelectionCoordinator();
    var applied = <String>['old'];
    var refreshCount = 0;
    final running = <bool>[];
    final failures = <ActiveDrugSelectionFailureStage>[];

    final result = await coordinator.commit(
      previousIds: applied,
      nextIds: const <String>['new'],
      persist: (_) async => throw StateError('storage unavailable'),
      apply: (ids) => applied = ids,
      refresh: () async => refreshCount += 1,
      onRunningChanged: running.add,
      onError: (stage, _) => failures.add(stage),
    );

    expect(result.status, ActiveDrugSelectionCommitStatus.persistenceFailed);
    expect(result.activeIds, <String>['old']);
    expect(applied, <String>['old']);
    expect(refreshCount, 0);
    expect(running, <bool>[true, false]);
    expect(failures, <ActiveDrugSelectionFailureStage>[
      ActiveDrugSelectionFailureStage.persistence,
    ]);
  });

  test('commits in persist, apply, refresh order', () async {
    final coordinator = ActiveDrugSelectionCoordinator();
    final order = <String>[];

    final result = await coordinator.commit(
      previousIds: const <String>['old'],
      nextIds: const <String>['new'],
      persist: (_) async => order.add('persist'),
      apply: (_) => order.add('apply'),
      refresh: () async => order.add('refresh'),
      onRunningChanged: (running) => order.add('running:$running'),
    );

    expect(result.status, ActiveDrugSelectionCommitStatus.committed);
    expect(result.wasCommitted, isTrue);
    expect(order, <String>[
      'running:true',
      'persist',
      'apply',
      'refresh',
      'running:false',
    ]);
  });

  test(
    'concurrent update is rejected without a second persistence call',
    () async {
      final coordinator = ActiveDrugSelectionCoordinator();
      final persistence = Completer<void>();
      var persistenceCount = 0;

      final first = coordinator.commit(
        previousIds: const <String>['a'],
        nextIds: const <String>['b'],
        persist: (_) {
          persistenceCount += 1;
          return persistence.future;
        },
        apply: (_) {},
        refresh: () async {},
        onRunningChanged: (_) {},
      );
      final second = await coordinator.commit(
        previousIds: const <String>['a'],
        nextIds: const <String>['c'],
        persist: (_) async => persistenceCount += 1,
        apply: (_) {},
        refresh: () async {},
        onRunningChanged: (_) {},
      );

      expect(second.status, ActiveDrugSelectionCommitStatus.busy);
      expect(persistenceCount, 1);
      persistence.complete();
      expect((await first).status, ActiveDrugSelectionCommitStatus.committed);
    },
  );

  test(
    'refresh failure does not roll back an already persisted selection',
    () async {
      final coordinator = ActiveDrugSelectionCoordinator();
      var applied = <String>['old'];
      final failures = <ActiveDrugSelectionFailureStage>[];

      final result = await coordinator.commit(
        previousIds: applied,
        nextIds: const <String>['new'],
        persist: (_) async {},
        apply: (ids) => applied = ids,
        refresh: () async => throw StateError('derived view failed'),
        onRunningChanged: (_) {},
        onError: (stage, _) => failures.add(stage),
      );

      expect(
        result.status,
        ActiveDrugSelectionCommitStatus.committedWithRefreshFailure,
      );
      expect(result.wasCommitted, isTrue);
      expect(applied, <String>['new']);
      expect(failures, <ActiveDrugSelectionFailureStage>[
        ActiveDrugSelectionFailureStage.refresh,
      ]);
    },
  );

  test('same selection is a no-op regardless of order', () async {
    final coordinator = ActiveDrugSelectionCoordinator();
    var persistenceCount = 0;

    final result = await coordinator.commit(
      previousIds: const <String>['a', 'b'],
      nextIds: const <String>['b', 'a'],
      persist: (_) async => persistenceCount += 1,
      apply: (_) {},
      refresh: () async {},
      onRunningChanged: (_) {},
    );

    expect(result.status, ActiveDrugSelectionCommitStatus.unchanged);
    expect(persistenceCount, 0);
  });
}
