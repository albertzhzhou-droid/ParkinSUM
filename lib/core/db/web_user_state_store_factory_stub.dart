import 'web_user_state_store.dart';

/// WebAppDatabase is also exercised by VM tests. Native production continues
/// to use its existing SQLite factory; this is not a Web failure fallback.
WebUserStateStore? createWebUserStateStore() => null;
