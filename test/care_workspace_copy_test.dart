import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/core/i18n/care_workspace_copy.dart';
import 'package:parkinsum_companion/domain/entities/localization_safety_lint.dart';
import 'package:parkinsum_companion/domain/usecases/localization_safety_lint.dart';

void main() {
  test(
    'every workflow copy key is native in every shipped language family',
    () {
      final shippedFamilies = AppI18n.translationFamilies.toSet();
      expect(kCareWorkspaceFollowupCopy.keys.toSet(), shippedFamilies);

      final english = kCareWorkspaceFollowupCopy['en']!;
      final englishKeys = english.keys.toSet();
      for (final family in shippedFamilies) {
        final translations = kCareWorkspaceFollowupCopy[family]!;
        expect(translations.keys.toSet(), englishKeys, reason: family);
        for (final key in englishKeys) {
          expect(translations[key]!.trim(), isNotEmpty, reason: '$family:$key');
          if (family != 'en') {
            expect(
              translations[key],
              isNot(english[key]),
              reason: '$family:$key should not silently use English.',
            );
          }
        }
      }
    },
  );

  test('visit preview copy covers every shipped family and placeholder', () {
    final shippedFamilies = AppI18n.translationFamilies.toSet();
    expect(kCareWorkspaceVisitCopy.keys.toSet(), shippedFamilies);

    final english = kCareWorkspaceVisitCopy['en']!;
    Set<String?> placeholders(String value) => RegExp(
      r'\{([a-zA-Z]+)\}',
    ).allMatches(value).map((match) => match.group(1)).toSet();
    for (final family in shippedFamilies) {
      final translations = kCareWorkspaceVisitCopy[family]!;
      expect(translations.keys.toSet(), english.keys.toSet(), reason: family);
      for (final entry in english.entries) {
        final translation = translations[entry.key]!;
        expect(translation.trim(), isNotEmpty, reason: '$family:${entry.key}');
        expect(
          placeholders(translation),
          placeholders(entry.value),
          reason: '$family:${entry.key} placeholder parity',
        );
        if (family != 'en') {
          expect(
            translation,
            isNot(entry.value),
            reason: '$family:${entry.key} should not silently use English.',
          );
        }
      }
    }
  });

  test('all translated status and boundary strings pass the advice lint', () {
    final surfaces = [
      for (final family in AppI18n.translationFamilies)
        for (final entry in kCareWorkspaceFollowupCopy[family]!.entries)
          LocalizationSurface(
            surfaceId: 'care_workspace.$family.${entry.key}',
            locale: family,
            key: entry.key,
            text: entry.value,
            source: 'care_workspace_copy',
          ),
    ];
    surfaces.addAll([
      for (final family in AppI18n.translationFamilies)
        for (final entry in kCareWorkspaceVisitCopy[family]!.entries)
          LocalizationSurface(
            surfaceId: 'care_workspace_visit.$family.${entry.key}',
            locale: family,
            key: entry.key,
            text: entry.value,
            source: 'care_workspace_visit_copy',
          ),
    ]);
    final report = const LocalizationSafetyLint().lint(
      surfaces,
      const LocalizationSafetyLintConfig(),
    );
    expect(report.blockerCount, 0);
  });

  test('regional locale tags resolve to their language family', () {
    expect(
      careWorkspaceFollowupCopy('status.needsReview', localeTag: 'ja-JP'),
      '要確認',
    );
    expect(
      careWorkspaceFollowupCopy('status.needsReview', localeTag: 'zh-CN'),
      '待核实',
    );
    expect(
      careWorkspaceFollowupCopy('status.needsReview', localeTag: 'xx-YY'),
      'To review',
    );
    expect(
      careWorkspaceVisitCopy('preview.title', localeTag: 'ja-JP'),
      '受診用チェックリストのプレビュー',
    );
    expect(
      careWorkspaceVisitCopy('preview.title', localeTag: 'xx-YY'),
      'Visit checklist preview',
    );
  });
}
