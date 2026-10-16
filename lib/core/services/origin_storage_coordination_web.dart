import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'origin_storage_coordination_contract.dart';
import 'user_state_change_notifications.dart';

/// A participating tab holds the same exclusive Web Lock throughout reread,
/// validation and one-document write. Unsupported/insecure contexts refuse
/// writes instead of silently falling back to an uncoordinated read/write.
Future<T> withOriginStorageLock<T>(
  String key,
  Future<T> Function() action,
) async {
  validateOriginStorageLockKey(key);
  if (!web.window.isSecureContext) throw const OriginStorageUnavailable();
  // Browser callbacks enter from JavaScript. Preserve the caller's Dart error
  // zone so awaited futures, exceptions and scoped transaction values can
  // cross the lock callback boundary without becoming undeliverable.
  final actionZone = Zone.current;
  late T result;
  Object? failure;
  StackTrace? trace;
  var invoked = false;
  final callback = ((web.Lock? lock) {
    return actionZone.run(() async {
      invoked = true;
      try {
        if (lock == null) throw const OriginStorageBusy();
        result = await action();
      } catch (error, stack) {
        failure = error;
        trace = stack;
      }
      return null as JSAny?;
    }).toJS;
  }).toJS;
  try {
    await web.window.navigator.locks
        .request(
          'parkinsum.persistence.$key',
          web.LockOptions(mode: 'exclusive', ifAvailable: true),
          callback,
        )
        .toDart;
  } catch (_) {
    throw const OriginStorageUnavailable();
  }
  if (!invoked) throw const OriginStorageUnavailable();
  if (failure != null) Error.throwWithStackTrace(failure!, trace!);
  return result;
}

final JSFunction _storageHandler = ((web.Event event) {
  // Conservatively expire the local snapshot for any other-tab origin
  // storage change, including account and consent keys. No payload is read.
  _externalChanges.add(null);
}).toJS;

StreamSubscription<void>? _userStateChanges;

void _startExternalChangeListeners() {
  web.window.addEventListener('storage', _storageHandler);
  _userStateChanges = externalUserStateChanges.listen((_) {
    // IndexedDB changes do not emit Web Storage events. Forward only an
    // invalidation signal; no user-state values cross the broadcast channel.
    _externalChanges.add(null);
  });
}

void _stopExternalChangeListeners() {
  web.window.removeEventListener('storage', _storageHandler);
  final subscription = _userStateChanges;
  _userStateChanges = null;
  if (subscription != null) unawaited(subscription.cancel());
}

final StreamController<void> _externalChanges =
    StreamController<void>.broadcast(
      onListen: _startExternalChangeListeners,
      onCancel: _stopExternalChangeListeners,
    );

Stream<void> get externalLocalDataChanges => _externalChanges.stream;

/// Explicit user action only: a page reload discards unsaved local editors.
void reloadAfterExternalLocalDataChange() => web.window.location.reload();
