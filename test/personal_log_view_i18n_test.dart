import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n_log_view_translations.dart';
import 'package:parkinsum_companion/features/shared/personal_log_view_controls.dart';

void main() {
  test('all new view keys have dictionary entries and exact placeholders', () {
    final placeholder = RegExp(r'\{([A-Za-z0-9_]+)\}');
    expect(kPersonalLogViewEnglish.keys.toSet(), logViewFallbacks.keys.toSet());
    expect(
      kPersonalLogViewChinese.keys.toSet(),
      kPersonalLogViewEnglish.keys.toSet(),
    );
    for (final family in AppI18n.translationFamilies) {
      final i18n = AppI18n.fromLocaleTag(family);
      for (final entry in kPersonalLogViewEnglish.entries) {
        final names = placeholder
            .allMatches(entry.value)
            .map((m) => m[1]!)
            .toSet();
        final raw = AppI18n.translationDictionary[family]![entry.key]!;
        expect(
          placeholder.allMatches(raw).map((m) => m[1]!).toSet(),
          names,
          reason: '$family/${entry.key}',
        );
        final params = {for (final name in names) name: 'checked_$name'};
        final resolved = i18n.tr(entry.key, params);
        expect(resolved, isNot(entry.key));
        expect(placeholder.hasMatch(resolved), isFalse);
        for (final name in names) {
          expect(resolved, contains('checked_$name'));
        }
      }
    }
  });

  test('Chinese and explicit English fallback boundaries remain honest', () {
    expect(
      AppI18n.fromLocaleTag('zh').tr('log_view.source_basis'),
      contains('当前目录'),
    );
    expect(
      AppI18n.fromLocaleTag('ja').tr('log_view.source_basis'),
      kPersonalLogViewEnglish['log_view.source_basis'],
    );
  });
}
