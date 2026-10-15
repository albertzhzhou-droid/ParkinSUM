import 'dart:async';

import 'origin_storage_coordination_contract.dart';

final _tails = <String, Future<void>>{};

/// The nonbrowser implementation serializes participating writers in this
/// process. It supplies no cross-process or native OS transaction guarantee.
Future<T> withOriginStorageLock<T>(
  String key,
  Future<T> Function() action,
) async {
  validateOriginStorageLockKey(key);
  if (!_tails.containsKey(key) && _tails.length >= 128) {
    throw const OriginStorageBusy();
  }
  final previous = _tails[key] ?? Future<void>.value();
  final operation = previous.then((_) => action());
  final tail = operation.then<void>(
    (_) {},
    onError: (Object _, StackTrace _) {},
  );
  _tails[key] = tail;
  try {
    return await operation;
  } finally {
    if (identical(_tails[key], tail)) _tails.remove(key);
  }
}

Stream<void> get externalLocalDataChanges => const Stream.empty();

void reloadAfterExternalLocalDataChange() =>
    throw UnsupportedError('Browser reload is unavailable.');
