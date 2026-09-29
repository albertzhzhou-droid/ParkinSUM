import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:parkinsum_companion/core/services/reminder_notification_privacy_policy.dart';
import 'package:parkinsum_companion/core/services/user_logging_reminder_service.dart';
import 'package:parkinsum_companion/domain/entities/user_logging_reminder.dart';

import '../tool/android_reminder_integration_report_support.dart';

const _configuredRunId = String.fromEnvironment('PARKINSUM_REMINDER_RUN_ID');
const _configuredSourceHeadSha = String.fromEnvironment(
  'PARKINSUM_SOURCE_HEAD_SHA',
);
const _configuredSourceStateSha256 = String.fromEnvironment(
  'PARKINSUM_SOURCE_STATE_SHA256',
);

const _unboundRunId = 'local-unbound';
const _unboundSourceHeadSha = '0000000000000000000000000000000000000000';
const _unboundSourceStateSha256 =
    '0000000000000000000000000000000000000000000000000000000000000000';

String get _buildMode {
  if (kReleaseMode) return 'release';
  if (kProfileMode) return 'profile';
  return 'debug';
}

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
    final configuredCopyContainsUserLabel =
        '${presentation.title} ${presentation.body}'.contains(reminder.label);
    expect(presentation.hideFromSecureAndroidLockScreen, isTrue);
    expect(configuredCopyContainsUserLabel, isFalse);

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

    final capabilityProfile = gateway.notificationCapabilityProfile;
    final configuredRunId = validAndroidReminderRunIdOrNull(_configuredRunId);
    final configuredSourceHeadSha = validSourceHeadShaOrNull(
      _configuredSourceHeadSha,
    );
    final configuredSourceStateSha256 = validSourceStateSha256OrNull(
      _configuredSourceStateSha256,
    );
    final sourceStateBound =
        configuredRunId != null &&
        configuredSourceHeadSha != null &&
        configuredSourceStateSha256 != null;
    expect(capabilityProfile.platform, ReminderNotificationPlatform.android);
    expect(
      capabilityProfile.evidenceFor(
        ReminderNotificationCapability.visibleDelivery,
      ),
      ReminderNotificationCapabilityEvidence.implementedUnverified,
    );

    binding.reportData = <String, dynamic>{
      'schema_uri': androidReminderIntegrationReportSchemaUri,
      'schema_version': androidReminderIntegrationReportSchemaVersion,
      'run_id': configuredRunId ?? _unboundRunId,
      'source_head_sha': configuredSourceHeadSha ?? _unboundSourceHeadSha,
      'source_state_sha256':
          configuredSourceStateSha256 ?? _unboundSourceStateSha256,
      'source_state_bound': sourceStateBound,
      'build_mode': _buildMode,
      'flutter_target_platform': defaultTargetPlatform.name,
      'storage_boundary': 'no-user-storage',
      'real_user_data_accessed': false,
      'notification_capability_schema':
          ReminderNotificationCapabilityMatrix.schema,
      'notification_capability_schema_version':
          ReminderNotificationCapabilityMatrix.schemaVersion,
      'notification_capability_manifest_sha256':
          gateway.notificationCapabilityManifestSha256,
      'notification_capability_profile_sha256': capabilityProfile.contentSha256,
      'notification_capability_platform': capabilityProfile.platform.name,
      'notification_delivery_mode': capabilityProfile.deliveryMode.name,
      'permission': 'not-requested',
      'plugin_reported_pending_after_schedule': 7,
      'plugin_reported_pending_after_clear': 0,
      'visible_delivery_evidence': capabilityProfile
          .evidenceFor(ReminderNotificationCapability.visibleDelivery)
          .name,
      'visible_delivery_verified': false,
      'alarm_manager_inspected': false,
      'notification_boundary': reminderSafetyBoundary,
      'notification_privacy_mode': reminder.notificationPrivacyMode.name,
      'notification_locale_snapshot': reminder.notificationLocaleCode,
      'android_requested_visibility': 'secret',
      'configured_copy_contains_user_label': configuredCopyContainsUserLabel,
      'system_visible_copy_inspected': false,
      'system_visible_copy_contains_user_label': null,
      'effective_lockscreen_visibility_inspected': false,
    };
  });
}
