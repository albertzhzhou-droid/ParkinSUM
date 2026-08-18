enum PersistedValueMutationStatus {
  committed,
  busy,
  committedWithRefreshFailure,
}

class PersistedValueMutationResult<T> {
  const PersistedValueMutationResult({
    required this.status,
    required this.value,
    this.refreshError,
  });

  final PersistedValueMutationStatus status;
  final T value;
  final Object? refreshError;

  bool get wasCommitted => status != PersistedValueMutationStatus.busy;
}

typedef PersistValue<T> = Future<void> Function(T value);
typedef ApplyPersistedValue<T> = void Function(T value);
typedef RefreshPersistedValueDerivatives = Future<void> Function();
typedef PersistedValueRunningChanged = void Function(bool isRunning);

/// Serializes a durable value update and keeps storage authoritative.
///
/// The proposed value is never applied in memory until [persist] succeeds. A
/// later derived-view refresh failure is returned separately because the new
/// value is already durable and must not be rolled back only in memory.
class PersistedValueMutationCoordinator<T> {
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  Future<PersistedValueMutationResult<T>> commit({
    required T previousValue,
    required T nextValue,
    required PersistValue<T> persist,
    required ApplyPersistedValue<T> apply,
    required RefreshPersistedValueDerivatives refresh,
    required PersistedValueRunningChanged onRunningChanged,
  }) async {
    if (_isRunning) {
      return PersistedValueMutationResult<T>(
        status: PersistedValueMutationStatus.busy,
        value: previousValue,
      );
    }

    _isRunning = true;
    onRunningChanged(true);
    try {
      await persist(nextValue);
      apply(nextValue);
      try {
        await refresh();
      } catch (error) {
        return PersistedValueMutationResult<T>(
          status: PersistedValueMutationStatus.committedWithRefreshFailure,
          value: nextValue,
          refreshError: error,
        );
      }
      return PersistedValueMutationResult<T>(
        status: PersistedValueMutationStatus.committed,
        value: nextValue,
      );
    } finally {
      _isRunning = false;
      onRunningChanged(false);
    }
  }
}
