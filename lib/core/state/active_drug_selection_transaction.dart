import 'package:parkinsum_companion/core/models/user_preference_write_scope.dart';

enum ActiveDrugSelectionCommitStatus {
  committed,
  unchanged,
  busy,
  persistenceFailed,
  committedWithRefreshFailure,
  cancelledBeforePersistence,
  committedForPreviousSession,
  failedForPreviousSession,
}

enum ActiveDrugSelectionFailureStage { persistence, refresh }

class ActiveDrugSelectionResult {
  const ActiveDrugSelectionResult({
    required this.status,
    required this.activeIds,
    this.persistenceError,
  });

  final ActiveDrugSelectionCommitStatus status;
  final List<String> activeIds;
  final Object? persistenceError;

  bool get wasCommitted =>
      status == ActiveDrugSelectionCommitStatus.committed ||
      status == ActiveDrugSelectionCommitStatus.committedWithRefreshFailure ||
      status == ActiveDrugSelectionCommitStatus.committedForPreviousSession;

  bool get appliesToCurrentSession =>
      status == ActiveDrugSelectionCommitStatus.committed ||
      status == ActiveDrugSelectionCommitStatus.committedWithRefreshFailure ||
      status == ActiveDrugSelectionCommitStatus.unchanged;
}

typedef PersistActiveDrugIds = Future<void> Function(List<String> ids);
typedef ApplyActiveDrugIds = void Function(List<String> ids);
typedef RefreshActiveDrugDerivatives = Future<void> Function();
typedef ActiveDrugSelectionRunningChanged = void Function(bool isRunning);
typedef ActiveDrugSelectionError =
    void Function(ActiveDrugSelectionFailureStage stage, Object error);

/// Keeps storage authoritative and suppresses publication by an old session.
class ActiveDrugSelectionCoordinator {
  bool _isRunning = false;
  int _generation = 0;

  bool get isRunning => _isRunning;

  void invalidate() {
    _generation += 1;
    _isRunning = false;
  }

  Future<ActiveDrugSelectionResult> commit({
    required List<String> previousIds,
    required List<String> nextIds,
    required PersistActiveDrugIds persist,
    required ApplyActiveDrugIds apply,
    required RefreshActiveDrugDerivatives refresh,
    required ActiveDrugSelectionRunningChanged onRunningChanged,
    ActiveDrugSelectionError? onError,
    bool Function()? isCurrent,
  }) async {
    final generation = _generation;
    bool current() => generation == _generation && (isCurrent?.call() ?? true);
    final previous = List<String>.unmodifiable(previousIds);
    final next = List<String>.unmodifiable(nextIds);
    ActiveDrugSelectionResult cancelled() => ActiveDrugSelectionResult(
      status: ActiveDrugSelectionCommitStatus.cancelledBeforePersistence,
      activeIds: previous,
    );
    ActiveDrugSelectionResult previousSessionCommit() =>
        ActiveDrugSelectionResult(
          status: ActiveDrugSelectionCommitStatus.committedForPreviousSession,
          activeIds: next,
        );
    if (!current()) return cancelled();
    if (_sameSelection(previous, next)) {
      return ActiveDrugSelectionResult(
        status: ActiveDrugSelectionCommitStatus.unchanged,
        activeIds: previous,
      );
    }
    if (_isRunning) {
      return ActiveDrugSelectionResult(
        status: ActiveDrugSelectionCommitStatus.busy,
        activeIds: previous,
      );
    }
    _isRunning = true;
    try {
      onRunningChanged(true);
      if (!current()) return cancelled();
      try {
        await persist(next);
      } on UserPreferenceWriteScopeChanged {
        return cancelled();
      } catch (error) {
        if (!current()) {
          return ActiveDrugSelectionResult(
            status: ActiveDrugSelectionCommitStatus.failedForPreviousSession,
            activeIds: previous,
            persistenceError: error,
          );
        }
        onError?.call(ActiveDrugSelectionFailureStage.persistence, error);
        return ActiveDrugSelectionResult(
          status: ActiveDrugSelectionCommitStatus.persistenceFailed,
          activeIds: previous,
          persistenceError: error,
        );
      }
      if (!current()) return previousSessionCommit();
      apply(next);
      if (!current()) return previousSessionCommit();
      try {
        await refresh();
      } catch (error) {
        if (!current()) return previousSessionCommit();
        onError?.call(ActiveDrugSelectionFailureStage.refresh, error);
        return ActiveDrugSelectionResult(
          status: ActiveDrugSelectionCommitStatus.committedWithRefreshFailure,
          activeIds: next,
        );
      }
      if (!current()) return previousSessionCommit();
      return ActiveDrugSelectionResult(
        status: ActiveDrugSelectionCommitStatus.committed,
        activeIds: next,
      );
    } finally {
      if (generation == _generation) {
        _isRunning = false;
        if (current()) onRunningChanged(false);
      }
    }
  }

  bool _sameSelection(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    return left.toSet().containsAll(right);
  }
}
