import '../../domain/entities/user_logging_reminder.dart';
import 'reminder_activation_inbox.dart';
import 'reminder_notification_privacy_policy.dart';

const int reminderNotificationPayloadSchemaVersion = 3;

/// Builds the response capability carried by one scheduled logging reminder.
///
/// The payload contains no label or clinical content. Callers that need to
/// retain its identity should store only a digest of the returned value.
String reminderNotificationPayloadFor(UserLoggingReminder reminder) {
  if (!RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(reminder.id)) {
    throw const FormatException('Reminder id is not notification-safe.');
  }
  if (!isReminderOpaqueTokenValid(reminder.activationToken)) {
    throw const FormatException('Reminder activation token is invalid.');
  }
  final presentation = ReminderNotificationPrivacyPolicy.resolve(
    mode: reminder.notificationPrivacyMode,
    localeName: reminder.notificationLocaleCode,
  );
  return 'parkinsum-reminder:v$reminderNotificationPayloadSchemaVersion:'
      '${reminder.activationToken}:'
      '${reminder.id}:${presentation.identitySha256}';
}
