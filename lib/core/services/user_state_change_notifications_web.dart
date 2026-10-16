import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

const _channelName = 'parkinsum.user-state.changed.v1';
const _pulseKey = 'parkinsum.user_state.revision.v1';
web.BroadcastChannel? _channel;
int _sequence = 0;

final StreamController<void> _changes = StreamController<void>.broadcast(
  onListen: () {
    try {
      final channel = web.BroadcastChannel(_channelName);
      channel.onmessage = ((web.MessageEvent _) => _changes.add(null)).toJS;
      _channel = channel;
    } catch (_) {
      // The legacy storage pulse remains available; no health payload is sent.
      debugPrint('WebUserState: change channel unavailable');
    }
  },
  onCancel: () {
    _channel?.close();
    _channel = null;
  },
);

Stream<void> get externalUserStateChanges => _changes.stream;

/// Both channels carry only a change signal. Notification failure never undoes
/// an already completed IndexedDB transaction or authorizes a duplicate write.
void notifyUserStateChanged() {
  try {
    // BroadcastChannel excludes its sending object. Reusing our receiver keeps
    // this tab from invalidating its own session after a successful save.
    final sender = _channel ?? web.BroadcastChannel(_channelName);
    sender.postMessage(null);
    if (_channel == null) sender.close();
  } catch (_) {
    debugPrint('WebUserState: change broadcast unavailable');
  }
  try {
    // Fixed-size metadata also expires participating older tabs that only
    // subscribe to storage events. It does not contain an owner or record.
    _sequence = (_sequence + 1) & 0xffff;
    final pulse =
        '${DateTime.now().microsecondsSinceEpoch.toRadixString(16).padLeft(16, '0')}'
        '${_sequence.toRadixString(16).padLeft(4, '0')}';
    web.window.localStorage.setItem(_pulseKey, pulse);
  } catch (_) {
    debugPrint('WebUserState: legacy change pulse unavailable');
  }
}
