import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:parkinsum_companion/core/services/reminder_notification_privacy_policy.dart';
import 'package:parkinsum_companion/core/services/user_logging_reminder_service.dart';
import 'package:parkinsum_companion/domain/entities/user_logging_reminder.dart';

const _testedCommit = String.fromEnvironment(
  'PARKINSUM_TEST_COMMIT',
  defaultValue: 'local-uncommitted',
);
const _testedTarget = String.fromEnvironment(
  'PARKINSUM_TEST_TARGET',
  defaultValue: 'local-android-device',
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android schedules and cancels every weekly logging prompt', (
    tester,
  ) async {
    expect(defaultTargetPlatform, TargetPlatform.android);
    final gateway = LocalReminderNotificationGateway();
    addTearDown(() async {
      debugPrint('[ReminderIntegration] teardown:cancel');
      await gateway.synchronize(const [], userScope: 'integration-user');
    });

    final target = DateTime.now().add(const Duration(minutes: 5));
    final reminder = UserLoggingReminder(
      id: 'android-integration-reminder',
      kind: UserLoggingReminderKind.intakeLog,
      label: 'Log an intake you already chose to take',
      minuteOfDay: target.hour * 60 + target.minute,
      weekdays: const {1, 2, 3, 4, 5, 6, 7},
      enabled: true,
      activationToken: '33333333333333333333333333333333',
      notificationPrivacyMode: ReminderNotificationPrivacyMode.minimal,
      notificationLocaleCode: 'en',
    );
    final presentation = ReminderNotificationPrivacyPolicy.resolve(
      mode: reminder.notificationPrivacyMode,
      localeName: reminder.notificationLocaleCode,
    );
    expect(presentation.hideFromSecureAndroidLockScreen, isTrue);
    expect(
      '${presentation.title} ${presentation.body}',
      isNot(contains(reminder.label)),
    );

    // Scheduling a pending request is distinct from permission to display it.
    // This test intentionally avoids a system permission dialog; target-device
    // permission and visible-delivery evidence remain a separate matrix row.
    debugPrint('[ReminderIntegration] schedule:start');
    await gateway.synchronize([reminder], userScope: 'integration-user');
    debugPrint('[ReminderIntegration] schedule:complete');
    expect(await gateway.pendingReminderCount(), 7);
    debugPrint('[ReminderIntegration] pending:seven');

    await gateway.synchronize(const [], userScope: 'integration-user');
    expect(await gateway.pendingReminderCount(), 0);
    debugPrint('[ReminderIntegration] pending:zero');

    binding.reportData = <String, dynamic>{
      'schema_version': 1,
      'commit': _testedCommit,
      'target': _testedTarget,
      'flutter_target_platform': defaultTargetPlatform.name,
      'storage_boundary': 'no-user-storage',
      'real_user_data_accessed': false,
      'permission': 'not-requested',
      'plugin_reported_pending_after_schedule': 7,
      'plugin_reported_pending_after_clear': 0,
      'alarm_manager_inspected': false,
      'notification_boundary': reminderSafetyBoundary,
      'notification_privacy_mode': reminder.notificationPrivacyMode.name,
      'notification_locale_snapshot': reminder.notificationLocaleCode,
      'android_requested_visibility': 'secret',
      'system_visible_copy_contains_user_label': false,
      'effective_lockscreen_visibility_inspected': false,
    };
  });
}
