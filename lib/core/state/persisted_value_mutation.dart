import 'package:parkinsum_companion/core/models/user_preference_write_scope.dart';

enum PersistedValueMutationStatus {
  committed,
  busy,
  committedWithRefreshFailure,
  cancelledBeforePersistence,
  committedForPreviousSession,
  failedForPreviousSession,
}

class PersistedValueMutationResult<T> {
  const PersistedValueMutationResult({
    required this.status,
    required this.value,
    this.refreshError,
    this.persistenceError,
  });

  final PersistedValueMutationStatus status;
  final T value;
  final Object? refreshError;
  final Object? persistenceError;

  bool get wasCommitted =>
      status == PersistedValueMutationStatus.committed ||
      status == PersistedValueMutationStatus.committedWithRefreshFailure ||
      status == PersistedValueMutationStatus.committedForPreviousSession;

  bool get appliesToCurrentSession =>
      status == PersistedValueMutationStatus.committed ||
      status == PersistedValueMutationStatus.committedWithRefreshFailure;
}

typedef PersistValue<T> = Future<void> Function(T value);
typedef ApplyPersistedValue<T> = void Function(T value);
typedef RefreshPersistedValueDerivatives = Future<void> Function();
typedef PersistedValueRunningChanged = void Function(bool isRunning);

/// Storage acknowledgement precedes memory publication. A session lease
/// governs publication; a late acknowledgement never claims write cancellation.
class PersistedValueMutationCoordinator<T> {
  bool _isRunning = false;
  int _generation = 0;

  bool get isRunning => _isRunning;

  /// A new session may start without waiting for an old platform response.
  void invalidate() {
    _generation += 1;
    _isRunning = false;
  }

  Future<PersistedValueMutationResult<T>> commit({
    required T previousValue,
    required T nextValue,
    required PersistValue<T> persist,
    required ApplyPersistedValue<T> apply,
    required RefreshPersistedValueDerivatives refresh,
    required PersistedValueRunningChanged onRunningChanged,
    bool Function()? isCurrent,
  }) async {
    final generation = _generation;
    bool current() => generation == _generation && (isCurrent?.call() ?? true);
    PersistedValueMutationResult<T> cancelled() =>
        PersistedValueMutationResult<T>(
          status: PersistedValueMutationStatus.cancelledBeforePersistence,
          value: previousValue,
        );
    PersistedValueMutationResult<T> previousSessionCommit() =>
        PersistedValueMutationResult<T>(
          status: PersistedValueMutationStatus.committedForPreviousSession,
          value: nextValue,
        );
    if (!current()) return cancelled();
    if (_isRunning) {
      return PersistedValueMutationResult<T>(
        status: PersistedValueMutationStatus.busy,
        value: previousValue,
      );
    }
    _isRunning = true;
    try {
      onRunningChanged(true);
      if (!current()) return cancelled();
      try {
        await persist(nextValue);
      } on UserPreferenceWriteScopeChanged {
        return cancelled();
      } catch (error) {
        if (current()) rethrow;
        return PersistedValueMutationResult<T>(
          status: PersistedValueMutationStatus.failedForPreviousSession,
          value: previousValue,
          persistenceError: error,
        );
      }
      if (!current()) return previousSessionCommit();
      apply(nextValue);
      if (!current()) return previousSessionCommit();
      try {
        await refresh();
      } catch (error) {
        if (!current()) return previousSessionCommit();
        return PersistedValueMutationResult<T>(
          status: PersistedValueMutationStatus.committedWithRefreshFailure,
          value: nextValue,
          refreshError: error,
        );
      }
      if (!current()) return previousSessionCommit();
      return PersistedValueMutationResult<T>(
        status: PersistedValueMutationStatus.committed,
        value: nextValue,
      );
    } finally {
      if (generation == _generation) {
        _isRunning = false;
        if (current()) onRunningChanged(false);
      }
    }
  }
}
