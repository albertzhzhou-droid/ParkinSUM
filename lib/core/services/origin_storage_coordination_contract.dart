/// Cooperative same-origin writers only. These errors disclose no storage
/// document, account key or platform exception payload.
final class OriginStorageBusy implements Exception {
  const OriginStorageBusy();
  @override
  String toString() => 'Local storage is being changed by another writer.';
}

final class OriginStorageUnavailable implements Exception {
  const OriginStorageUnavailable();
  @override
  String toString() => 'Local storage coordination is unavailable.';
}

void validateOriginStorageLockKey(String key) {
  if (!RegExp(r'^[A-Za-z0-9_.-]{1,180}$').hasMatch(key)) {
    throw ArgumentError('Invalid local storage coordination key.');
  }
}
