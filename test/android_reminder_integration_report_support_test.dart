import 'package:flutter_test/flutter_test.dart';

import '../tool/android_reminder_integration_report_support.dart';

void main() {
  test('Android reminder integration report uses observation schema v4', () {
    expect(
      androidReminderIntegrationReportSchemaUri,
      'parkinsum.android-reminder-integration-observation/4',
    );
    expect(androidReminderIntegrationReportSchemaVersion, 4);
  });

  group('Android reminder integration run id', () {
    test('accepts exact 8 and 96 character boundaries', () {
      const valid = <String>['run-0001', 'android-api36-arm64_notification-v3'];

      final values = <String>[...valid, 'a' * 96];

      for (final value in values) {
        expect(isValidAndroidReminderRunId(value), isTrue, reason: value);
        expect(requireValidAndroidReminderRunId(value), value);
        expect(validAndroidReminderRunIdOrNull(value), value);
      }
    });

    test('rejects missing and exact 7 and 97 character boundaries', () {
      final invalid = <String?>[null, '', 'a' * 7, 'a' * 97];

      for (final value in invalid) {
        if (value != null) {
          expect(isValidAndroidReminderRunId(value), isFalse, reason: value);
          expect(validAndroidReminderRunIdOrNull(value), isNull, reason: value);
        }
        expect(
          () => requireValidAndroidReminderRunId(value),
          throwsFormatException,
          reason: value,
        );
      }
    });

    test('rejects leading symbols and every non-contract character class', () {
      const invalid = <String>[
        '.',
        '..',
        '../escape',
        r'..\escape',
        '/absolute',
        'with space1',
        'with.dot1',
        'with:colon',
        'with+plus1',
        'with@sign1',
        'with\ttab1',
        'with\nline',
        '-leading-hyphen1',
        '_leading-underscore1',
        'unicode-运行',
      ];

      for (final value in invalid) {
        expect(isValidAndroidReminderRunId(value), isFalse, reason: value);
        expect(validAndroidReminderRunIdOrNull(value), isNull, reason: value);
        expect(
          () => requireValidAndroidReminderRunId(value),
          throwsFormatException,
          reason: value,
        );
      }
    });
  });

  test('source state accepts only canonical lowercase SHA-256', () {
    final digest = 'a' * 64;
    expect(isValidSourceStateSha256(digest), isTrue);
    expect(validSourceStateSha256OrNull(digest), digest);

    for (final invalid in <String>[
      '',
      'a' * 63,
      'a' * 65,
      'A' * 64,
      '${'a' * 63}g',
    ]) {
      expect(isValidSourceStateSha256(invalid), isFalse, reason: invalid);
      expect(validSourceStateSha256OrNull(invalid), isNull, reason: invalid);
    }
  });
}
