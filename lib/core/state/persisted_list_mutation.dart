enum PersistedListMutationStatus {
  committed,
  unchanged,
  busy,
  persistenceFailed,
  committedWithRefreshFailure,
}

enum PersistedListMutationFailureStage { persistence, refresh }

class PersistedListMutationResult<T> {
  const PersistedListMutationResult({
    required this.status,
    required this.items,
  });

  final PersistedListMutationStatus status;
  final List<T> items;

  bool get wasCommitted =>
      status == PersistedListMutationStatus.committed ||
      status == PersistedListMutationStatus.committedWithRefreshFailure;

  bool get shouldReportSaveFailure =>
      status == PersistedListMutationStatus.persistenceFailed ||
      status == PersistedListMutationStatus.busy;
}

typedef PersistList<T> = Future<void> Function(List<T> items);
typedef ApplyPersistedList<T> = void Function(List<T> items);
typedef RefreshPersistedListDerivatives = Future<void> Function();
typedef PersistedListMutationRunningChanged = void Function(bool isRunning);
typedef PersistedListMutationError =
    void Function(PersistedListMutationFailureStage stage, Object error);

/// Serializes a persisted-list mutation while keeping storage authoritative.
///
/// The in-memory list changes only after persistence succeeds. A later failure
/// while refreshing recommendations or other derived views is reported as a
/// separate committed state, because rolling back memory at that point would
/// make it disagree with durable storage.
class PersistedListMutationCoordinator<T> {
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  PersistedListMutationResult<T> unchanged(List<T> items) =>
      PersistedListMutationResult<T>(
        status: PersistedListMutationStatus.unchanged,
        items: List<T>.unmodifiable(items),
      );

  Future<PersistedListMutationResult<T>> commit({
    required List<T> previousItems,
    required List<T> nextItems,
    required PersistList<T> persist,
    required ApplyPersistedList<T> apply,
    required RefreshPersistedListDerivatives refresh,
    required PersistedListMutationRunningChanged onRunningChanged,
    PersistedListMutationError? onError,
  }) async {
    final previous = List<T>.unmodifiable(previousItems);
    final next = List<T>.unmodifiable(nextItems);
    if (_isRunning) {
      return PersistedListMutationResult<T>(
        status: PersistedListMutationStatus.busy,
        items: previous,
      );
    }

    _isRunning = true;
    onRunningChanged(true);
    try {
      try {
        await persist(next);
      } catch (error) {
        onError?.call(PersistedListMutationFailureStage.persistence, error);
        return PersistedListMutationResult<T>(
          status: PersistedListMutationStatus.persistenceFailed,
          items: previous,
        );
      }

      apply(next);
      try {
        await refresh();
      } catch (error) {
        onError?.call(PersistedListMutationFailureStage.refresh, error);
        return PersistedListMutationResult<T>(
          status: PersistedListMutationStatus.committedWithRefreshFailure,
          items: next,
        );
      }
      return PersistedListMutationResult<T>(
        status: PersistedListMutationStatus.committed,
        items: next,
      );
    } finally {
      _isRunning = false;
      onRunningChanged(false);
    }
  }
}
