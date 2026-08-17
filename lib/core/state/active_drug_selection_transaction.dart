enum ActiveDrugSelectionCommitStatus {
  committed,
  unchanged,
  busy,
  persistenceFailed,
  committedWithRefreshFailure,
}

enum ActiveDrugSelectionFailureStage { persistence, refresh }

class ActiveDrugSelectionResult {
  const ActiveDrugSelectionResult({
    required this.status,
    required this.activeIds,
  });

  final ActiveDrugSelectionCommitStatus status;
  final List<String> activeIds;

  bool get wasCommitted =>
      status == ActiveDrugSelectionCommitStatus.committed ||
      status == ActiveDrugSelectionCommitStatus.committedWithRefreshFailure;
}

typedef PersistActiveDrugIds = Future<void> Function(List<String> ids);
typedef ApplyActiveDrugIds = void Function(List<String> ids);
typedef RefreshActiveDrugDerivatives = Future<void> Function();
typedef ActiveDrugSelectionRunningChanged = void Function(bool isRunning);
typedef ActiveDrugSelectionError =
    void Function(ActiveDrugSelectionFailureStage stage, Object error);

/// Serializes an active-medication update and keeps persistence authoritative.
///
/// Memory is changed only after persistence succeeds, so a storage failure
/// leaves the previous selection intact. Derived recommendation refresh is a
/// separate post-commit phase: if it fails, the saved selection remains the
/// truth and callers receive a distinct status instead of a misleading save
/// failure.
class ActiveDrugSelectionCoordinator {
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  Future<ActiveDrugSelectionResult> commit({
    required List<String> previousIds,
    required List<String> nextIds,
    required PersistActiveDrugIds persist,
    required ApplyActiveDrugIds apply,
    required RefreshActiveDrugDerivatives refresh,
    required ActiveDrugSelectionRunningChanged onRunningChanged,
    ActiveDrugSelectionError? onError,
  }) async {
    final previous = List<String>.unmodifiable(previousIds);
    final next = List<String>.unmodifiable(nextIds);
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
    onRunningChanged(true);
    try {
      try {
        await persist(next);
      } catch (error) {
        onError?.call(ActiveDrugSelectionFailureStage.persistence, error);
        return ActiveDrugSelectionResult(
          status: ActiveDrugSelectionCommitStatus.persistenceFailed,
          activeIds: previous,
        );
      }

      apply(next);
      try {
        await refresh();
      } catch (error) {
        onError?.call(ActiveDrugSelectionFailureStage.refresh, error);
        return ActiveDrugSelectionResult(
          status: ActiveDrugSelectionCommitStatus.committedWithRefreshFailure,
          activeIds: next,
        );
      }
      return ActiveDrugSelectionResult(
        status: ActiveDrugSelectionCommitStatus.committed,
        activeIds: next,
      );
    } finally {
      _isRunning = false;
      onRunningChanged(false);
    }
  }

  bool _sameSelection(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    return left.toSet().containsAll(right);
  }
}
