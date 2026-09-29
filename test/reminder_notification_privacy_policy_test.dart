import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/services/reminder_notification_privacy_policy.dart';
import 'package:parkinsum_companion/domain/entities/user_logging_reminder.dart';

void main() {
  group('ReminderNotificationPrivacyPolicy', () {
    test('minimal mode requests Android lock-screen hiding', () {
      final presentation = ReminderNotificationPrivacyPolicy.resolve(
        mode: ReminderNotificationPrivacyMode.minimal,
        localeName: 'en-CA',
      );

      expect(presentation.languageCode, 'en');
      expect(presentation.title, 'ParkinSUM');
      expect(presentation.body, 'Open ParkinSUM to review a private reminder.');
      expect(presentation.hideFromSecureAndroidLockScreen, isTrue);
      expect(presentation.darwinPreviewRemainsSystemControlled, isTrue);
      expect(presentation.identitySha256, hasLength(64));
    });

    test('generic mode remains generic and requests private visibility', () {
      final presentation = ReminderNotificationPrivacyPolicy.resolve(
        mode: ReminderNotificationPrivacyMode.generic,
        localeName: 'en',
      );

      expect(presentation.title, 'ParkinSUM logging reminder');
      expect(
        presentation.body,
        'Logging prompt only — open ParkinSUM to record something you already chose.',
      );
      expect(presentation.hideFromSecureAndroidLockScreen, isFalse);
    });

    test(
      'all shipped locales have bounded copy and unknown locales use English',
      () {
        const authoredSecrets = <String>[
          'Private levodopa 100 mg at breakfast',
          'patient@example.com',
          'missed dose',
        ];
        for (final locale in const <String>[
          'zh-CN',
          'en-US',
          'fr-CA',
          'ja-JP',
          'ko-KR',
          'hi-IN',
          'es-MX',
          'vi-VN',
          'th-TH',
          'id-ID',
          'ru-RU',
          'pl-PL',
          'ar-SA',
        ]) {
          for (final mode in ReminderNotificationPrivacyMode.values) {
            final presentation = ReminderNotificationPrivacyPolicy.resolve(
              mode: mode,
              localeName: locale,
            );
            expect(presentation.title.trim(), isNotEmpty);
            expect(presentation.body.trim(), isNotEmpty);
            expect(presentation.title.length, lessThanOrEqualTo(80));
            expect(presentation.body.length, lessThanOrEqualTo(160));
            for (final secret in authoredSecrets) {
              expect(presentation.title, isNot(contains(secret)));
              expect(presentation.body, isNot(contains(secret)));
            }
          }
        }

        final fallback = ReminderNotificationPrivacyPolicy.resolve(
          mode: ReminderNotificationPrivacyMode.minimal,
          localeName: 'de-DE',
        );
        expect(fallback.languageCode, 'en');
        expect(fallback.title, 'ParkinSUM');
      },
    );

    test(
      'presentation identity is stable and changes with visible semantics',
      () {
        final enCa = ReminderNotificationPrivacyPolicy.resolve(
          mode: ReminderNotificationPrivacyMode.minimal,
          localeName: 'en-CA',
        );
        final enUs = ReminderNotificationPrivacyPolicy.resolve(
          mode: ReminderNotificationPrivacyMode.minimal,
          localeName: 'en-US',
        );
        final generic = ReminderNotificationPrivacyPolicy.resolve(
          mode: ReminderNotificationPrivacyMode.generic,
          localeName: 'en-US',
        );
        final french = ReminderNotificationPrivacyPolicy.resolve(
          mode: ReminderNotificationPrivacyMode.minimal,
          localeName: 'fr-CA',
        );
        final fallback = ReminderNotificationPrivacyPolicy.resolve(
          mode: ReminderNotificationPrivacyMode.minimal,
          localeName: 'de-DE',
        );

        expect(enCa.identitySha256, enUs.identitySha256);
        expect(generic.identitySha256, isNot(enUs.identitySha256));
        expect(french.identitySha256, isNot(enUs.identitySha256));
        expect(fallback.identitySha256, enUs.identitySha256);
        expect(
          ReminderNotificationPrivacyPolicy.supportedLanguageCode('es-419'),
          'es',
        );
        expect(
          ReminderNotificationPrivacyPolicy.supportedLanguageCode('zh-Hant-TW'),
          'zh',
        );
        expect(
          ReminderNotificationPrivacyPolicy.supportedLanguageCode('de-DE'),
          'en',
        );
      },
    );

    test('policy API cannot accept a user-authored label', () {
      final presentation = ReminderNotificationPrivacyPolicy.resolve(
        mode: ReminderNotificationPrivacyMode.generic,
        localeName: 'en',
      );

      final serialized = '${presentation.title}\n${presentation.body}';
      expect(serialized, isNot(contains('Levodopa')));
      expect(serialized, isNot(contains('meal')));
      expect(serialized, isNot(contains('dose')));
      expect(serialized, isNot(contains('adherence')));
      expect(serialized, isNot(contains('Parkinson')));
    });
  });
}
