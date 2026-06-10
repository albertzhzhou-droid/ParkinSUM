/// Flutter-facing access to [AppI18n].
///
/// [AppI18n] itself is pure Dart (so non-Flutter tools — e.g. the Local-AI
/// scenario replay CLI — can compile the recommendation stack with `dart run`).
/// Everything that needs `BuildContext`, `Locale`, or the `AppState` provider
/// lives here instead. UI code imports THIS file; pure-Dart code imports
/// `app_i18n.dart` directly.
library;

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'app_i18n.dart';

export 'app_i18n.dart';

/// Maps a BCP-47-ish tag (e.g. `en-US`) to a Flutter [Locale].
Locale appI18nLocaleFor(String localeTag) {
  final parts = localeTag.split('-');
  if (parts.length >= 2) {
    return Locale(parts[0], parts[1]);
  }
  return Locale(parts.first);
}

extension AppI18nBuildContext on BuildContext {
  /// Resolves the current [AppI18n] from the user profile's display locale.
  ///
  /// 这里不能再用 context.select/watch：
  /// EntryPage 等页面会在 didChangeDependencies、保存回调、弹窗动作里读取 i18n，
  /// 若继续依赖 provider 的 build-phase API，会触发
  /// “Tried to use context.select outside of the build method” 断言。
  /// 因此统一改成 listen:false 的只读访问，让 build 内外都能安全取当前 locale。
  AppI18n get appI18n {
    final localeTag =
        Provider.of<AppState>(this, listen: false).userProfile.displayLocale;
    return AppI18n.fromLocaleTag(localeTag);
  }
}
