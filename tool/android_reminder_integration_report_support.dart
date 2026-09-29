const androidReminderIntegrationReportSchemaUri =
    'parkinsum.android-reminder-integration-observation/4';
const androidReminderIntegrationReportSchemaVersion = 4;

const androidReminderRunIdEnvironmentName = 'PARKINSUM_REMINDER_RUN_ID';
const sourceHeadShaEnvironmentName = 'PARKINSUM_SOURCE_HEAD_SHA';
const sourceStateSha256EnvironmentName = 'PARKINSUM_SOURCE_STATE_SHA256';

final RegExp _androidReminderRunIdPattern = RegExp(
  r'^[A-Za-z0-9][A-Za-z0-9_-]{7,95}$',
);
final RegExp _lowercaseSha256Pattern = RegExp(r'^[0-9a-f]{64}$');
final RegExp _gitObjectIdPattern = RegExp(r'^[0-9a-f]{40}([0-9a-f]{24})?$');

bool isValidAndroidReminderRunId(String value) =>
    _androidReminderRunIdPattern.hasMatch(value);

String requireValidAndroidReminderRunId(String? value) {
  if (value == null || !isValidAndroidReminderRunId(value)) {
    throw const FormatException(
      'PARKINSUM_REMINDER_RUN_ID must contain 8-96 ASCII letters, digits, '
      'underscores, or hyphens, and must start with a letter or digit.',
    );
  }
  return value;
}

String? validAndroidReminderRunIdOrNull(String value) =>
    isValidAndroidReminderRunId(value) ? value : null;

bool isValidSourceStateSha256(String value) =>
    _lowercaseSha256Pattern.hasMatch(value);

String? validSourceStateSha256OrNull(String value) =>
    isValidSourceStateSha256(value) ? value : null;

bool isValidSourceHeadSha(String value) => _gitObjectIdPattern.hasMatch(value);

String? validSourceHeadShaOrNull(String value) =>
    isValidSourceHeadSha(value) ? value : null;
