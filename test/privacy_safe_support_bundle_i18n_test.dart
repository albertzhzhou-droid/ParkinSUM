import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';

void main() {
  const localeFamilies = <String>[
    'zh-CN',
    'en-US',
    'fr-FR',
    'ja-JP',
    'ko-KR',
    'hi-IN',
    'es-ES',
    'vi-VN',
    'th-TH',
    'id-ID',
    'ru-RU',
    'pl-PL',
    'ar-SA',
  ];
  const keys = <String>[
    'support.title',
    'support.boundary_title',
    'support.boundary_body',
    'support.local_only',
    'support.sections_title',
    'support.sections_body',
    'support.section_build',
    'support.section_platform',
    'support.section_diagnostics',
    'support.section_governance',
    'support.generate',
    'support.preview_title',
    'support.preview_meta',
    'support.copy',
    'support.save',
    'support.copied',
    'support.save_fallback_copied',
    'support.download_requested',
    'support.existing_verified',
    'support.error_scope',
    'support.error_generation',
    'support.error_source_changed',
    'support.error_copy',
    'support.error_save',
  ];

  test(
    'every shipped locale resolves the support surface without raw keys',
    () {
      for (final locale in localeFamilies) {
        final i18n = AppI18n.fromLocaleTag(locale);
        for (final key in keys) {
          final resolved = i18n.tr(key, const {'bytes': '42', 'sha': 'abcdef'});
          expect(resolved, isNot(key), reason: '$locale leaked $key');
          expect(
            resolved.trim(),
            isNotEmpty,
            reason: '$locale left $key empty',
          );
          expect(
            resolved,
            isNot(contains('{')),
            reason: '$locale left $key unresolved',
          );
        }
      }
    },
  );

  test('reviewed Chinese and English copy deny automatic disclosure', () {
    final zh = AppI18n.fromLocaleTag('zh-CN');
    final en = AppI18n.fromLocaleTag('en-US');

    expect(zh.tr('support.local_only'), contains('不会自动上传'));
    expect(zh.tr('support.boundary_body'), contains('不会包含健康记录'));
    expect(
      en.tr('support.local_only').toLowerCase(),
      contains('never uploaded'),
    );
    expect(
      en.tr('support.boundary_body').toLowerCase(),
      contains('excludes health records'),
    );
  });
}
