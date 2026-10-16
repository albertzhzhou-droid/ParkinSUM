import 'dart:convert';

import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:web/web.dart' as web;

import 'web_user_state_store.dart';
import 'web_user_state_store_indexeddb.dart';

WebUserStateStore? createWebUserStateStore() {
  // This explicit public mock is installed by SharedPreferences test helpers.
  // A real browser always uses IndexedDB, including when IndexedDB fails.
  if (SharedPreferencesStorePlatform.instance
      is InMemorySharedPreferencesStore) {
    return null;
  }
  return IndexedDbWebUserStateStore(readCurrentLegacy: _readCurrentLegacy);
}

WebUserStateLegacySnapshot _readCurrentLegacy() {
  final values = <String, String?>{};
  for (final key in webUserStateLegacyKeys) {
    // This app never changes SharedPreferences' default `flutter.` prefix.
    // shared_preferences_web 2.4.3 stores String values as JSON strings. Read
    // only these six exact keys; no unrelated origin payload is inspected.
    final raw = web.window.localStorage.getItem('flutter.$key');
    if (raw == null) {
      values[key] = null;
    } else {
      final value = jsonDecode(raw);
      if (value is! String) {
        throw StateError('web_user_state_legacy_value_invalid');
      }
      values[key] = value;
    }
  }
  return WebUserStateLegacySnapshot(values);
}
