import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/core/services/data_service.dart';
import 'package:parkinsum_companion/core/services/user_logging_reminder_service.dart';
import 'package:parkinsum_companion/domain/entities/user_logging_reminder.dart';
import 'package:parkinsum_companion/features/reminders/reminder_center_page.dart';

import 'helpers/page_test_harness.dart';

void main() {
  testWidgets(
    'readiness separates applied request and matching registry from delivery',
    (tester) async {
      final repository = UserLoggingReminderRepository(
        storage: _MemoryDataService(),
      );
      final gateway = _CapabilityGateway(
        platform: ReminderNotificationPlatform.android,
      );
      final controller = UserLoggingReminderController(
        userScope: 'user',
        repository: repository,
        gateway: gateway,
      );
      expect(await controller.save(_reminder()), isTrue);

      await pumpFeaturePage(
        tester,
        ReminderCenterPage(controller: controller),
        settle: true,
      );

      expect(
        find.byKey(const ValueKey('reminder-delivery-readiness')),
        findsOneWidget,
      );
      expect(find.text('Saved on this device'), findsOneWidget);
      expect(
        find.text('Plugin request completed; delivery is not proven'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Permission request call returned allowed; use current inspection state',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Plugin inspection reports enabled; delivery is not proven'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Plugin report matches the local plan; not OS delivery proof',
        ),
        findsOneWidget,
      );
      expect(find.text('Unverified'), findsOneWidget);
      expect(
        controller.deliveryReadiness.visibleDelivery,
        ReminderVisibleDeliveryReadiness.unverified,
      );
      expectNoWidgetErrors();
    },
  );

  testWidgets('plan-only profile stays local and reflows at 320 px', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = _CapabilityGateway(
      platform: ReminderNotificationPlatform.web,
    );
    final controller = UserLoggingReminderController(
      userScope: 'user',
      repository: UserLoggingReminderRepository(storage: _MemoryDataService()),
      gateway: gateway,
    );
    expect(await controller.save(_reminder()), isTrue);

    await pumpFeaturePage(
      tester,
      ReminderCenterPage(controller: controller),
      settle: true,
    );

    expect(
      find.text('Plan-only; no system notification API is called'),
      findsOneWidget,
    );
    expect(find.text('Saved on this device'), findsOneWidget);
    expect(
      find.text('Recurring system delivery is unavailable here'),
      findsOneWidget,
    );
    expect(gateway.permissionCalls, 0);
    expect(gateway.inspectionCalls, 0);
    expect(gateway.synchronizationCalls, 0);
    expect(gateway.attestationCalls, 0);
    expectNoWidgetErrors();
  });

  test('permission request outcomes never fabricate a user denial', () async {
    const cases = {
      ReminderPermissionRequestOutcome.returnedNotAllowed:
          ReminderPermissionRequestReadiness.returnedNotAllowed,
      ReminderPermissionRequestOutcome.adapterUnavailable:
          ReminderPermissionRequestReadiness.adapterUnavailable,
      ReminderPermissionRequestOutcome.failed:
          ReminderPermissionRequestReadiness.failed,
    };

    for (final entry in cases.entries) {
      final gateway = _CapabilityGateway(
        platform: ReminderNotificationPlatform.android,
        permissionOutcome: entry.key,
      );
      final controller = UserLoggingReminderController(
        userScope: 'user-${entry.key.name}',
        repository: UserLoggingReminderRepository(
          storage: _MemoryDataService(),
        ),
        gateway: gateway,
      );

      expect(await controller.save(_reminder()), isFalse);
      expect(controller.deliveryReadiness.permissionRequest, entry.value);
      expect(
        controller.deliveryReadiness.permissionInspection,
        ReminderPermissionInspectionReadiness.notInspected,
      );
      expect(gateway.synchronizationCalls, 0);
      expect(gateway.attestationCalls, 0);
    }
  });

  test('inspection disabled or failed blocks a new enabled plan', () async {
    for (final outcome in const {
      ReminderPermissionInspectionOutcome.disabled,
      ReminderPermissionInspectionOutcome.failed,
      ReminderPermissionInspectionOutcome.adapterUnavailable,
    }) {
      final gateway = _CapabilityGateway(
        platform: ReminderNotificationPlatform.android,
        inspectionOutcome: outcome,
      );
      final controller = UserLoggingReminderController(
        userScope: 'user-${outcome.name}',
        repository: UserLoggingReminderRepository(
          storage: _MemoryDataService(),
        ),
        gateway: gateway,
      );

      expect(await controller.save(_reminder()), isFalse);
      expect(
        controller.deliveryReadiness.permissionRequest,
        ReminderPermissionRequestReadiness.returnedAllowed,
      );
      expect(
        controller.deliveryReadiness.permissionInspection,
        switch (outcome) {
          ReminderPermissionInspectionOutcome.disabled =>
            ReminderPermissionInspectionReadiness.disabled,
          ReminderPermissionInspectionOutcome.failed =>
            ReminderPermissionInspectionReadiness.failed,
          ReminderPermissionInspectionOutcome.adapterUnavailable =>
            ReminderPermissionInspectionReadiness.unavailable,
          ReminderPermissionInspectionOutcome.enabled =>
            ReminderPermissionInspectionReadiness.enabled,
        },
      );
      expect(gateway.synchronizationCalls, 0);
      expect(gateway.attestationCalls, 0);
    }
  });

  test('readiness copy is native in every shipped language family', () {
    const keys = {
      'reminders.readiness_title',
      'reminders.readiness_contract',
      'reminders.readiness_boundary',
      'reminders.readiness_platform_android',
      'reminders.readiness_platform_ios',
      'reminders.readiness_platform_macos',
      'reminders.readiness_platform_web',
      'reminders.readiness_platform_windows',
      'reminders.readiness_platform_linux',
      'reminders.readiness_platform_unknown',
      'reminders.readiness_local_plan',
      'reminders.readiness_adapter',
      'reminders.readiness_schedule_request',
      'reminders.readiness_permission_request',
      'reminders.readiness_permission_inspection',
      'reminders.readiness_registry',
      'reminders.readiness_visible_delivery',
      'reminders.readiness_body_tap',
      'reminders.readiness_cold_start',
      'reminders.readiness_background_action',
      'reminders.readiness_local_none',
      'reminders.readiness_local_saved',
      'reminders.readiness_adapter_plan_only',
      'reminders.readiness_evidence_artifact_verified',
      'reminders.readiness_evidence_implemented_unverified',
      'reminders.readiness_evidence_unavailable',
      'reminders.readiness_request_not_requested',
      'reminders.readiness_request_applied',
      'reminders.readiness_request_rolled_back',
      'reminders.readiness_request_superseded',
      'reminders.readiness_request_unsupported',
      'reminders.readiness_request_failed',
      'reminders.readiness_request_recovery_required',
      'reminders.readiness_permission_not_requested',
      'reminders.readiness_permission_granted',
      'reminders.readiness_permission_denied',
      'reminders.readiness_permission_failed',
      'reminders.readiness_permission_unavailable',
      'reminders.readiness_inspection_not_inspected',
      'reminders.readiness_inspection_enabled',
      'reminders.readiness_inspection_disabled',
      'reminders.readiness_inspection_unavailable',
      'reminders.readiness_inspection_failed',
      'reminders.readiness_registry_not_inspected',
      'reminders.readiness_registry_matched',
      'reminders.readiness_registry_drift',
      'reminders.readiness_registry_uninspectable',
      'reminders.readiness_registry_unsupported',
      'reminders.readiness_visible_unverified',
      'reminders.readiness_visible_artifact_verified',
    };
    const universalPlatformLabels = {
      'reminders.readiness_platform_android',
      'reminders.readiness_platform_ios',
      'reminders.readiness_platform_macos',
      'reminders.readiness_platform_web',
      'reminders.readiness_platform_windows',
      'reminders.readiness_platform_linux',
    };
    expect(keys, hasLength(50));
    final dictionary = AppI18n.translationDictionary;
    final english = dictionary['en']!;

    for (final family in AppI18n.translationFamilies) {
      final translations = dictionary[family]!;
      for (final key in keys) {
        expect(translations, contains(key), reason: '$family is missing $key');
        expect(
          _placeholders(translations[key]!),
          _placeholders(english[key]!),
          reason: '$family changed placeholders for $key',
        );
        if (family != 'en' && !universalPlatformLabels.contains(key)) {
          expect(
            translations[key],
            isNot(english[key]),
            reason: '$family still falls back to English for $key',
          );
        }
      }
    }
  });
}

Set<String> _placeholders(String value) => RegExp(
  r'\{([a-zA-Z0-9_]+)\}',
).allMatches(value).map((match) => match.group(1)!).toSet();

UserLoggingReminder _reminder() => const UserLoggingReminder(
  id: 'reminder-1',
  kind: UserLoggingReminderKind.intakeLog,
  label: 'Private user label',
  minuteOfDay: 555,
  weekdays: {1},
  enabled: true,
  activationToken: '0123456789abcdef0123456789abcdef',
);

class _CapabilityGateway
    implements
        ReminderNotificationGateway,
        ReminderNotificationPreflight,
        ReminderNotificationIdentityInspector,
        ReminderNotificationCapabilityProvider,
        ReminderNotificationPermissionGateway {
  _CapabilityGateway({
    required ReminderNotificationPlatform platform,
    this.permissionOutcome = ReminderPermissionRequestOutcome.returnedAllowed,
    this.inspectionOutcome = ReminderPermissionInspectionOutcome.enabled,
  }) : notificationCapabilityProfile = ReminderNotificationCapabilityMatrix
           .current
           .profileFor(platform);

  final ReminderPermissionRequestOutcome permissionOutcome;
  final ReminderPermissionInspectionOutcome inspectionOutcome;

  @override
  final ReminderNotificationCapabilityProfile notificationCapabilityProfile;

  @override
  ReminderNotificationCapabilityMatrix get notificationCapabilityMatrix =>
      ReminderNotificationCapabilityMatrix.current;

  @override
  String get notificationCapabilityManifestSha256 =>
      notificationCapabilityMatrix.manifestSha256;

  @override
  bool get supportsScheduledDelivery =>
      notificationCapabilityProfile.supportsScheduledDelivery;

  int permissionCalls = 0;
  int inspectionCalls = 0;
  int synchronizationCalls = 0;
  int attestationCalls = 0;

  @override
  Future<bool> requestPermission() async {
    permissionCalls += 1;
    return permissionOutcome ==
        ReminderPermissionRequestOutcome.returnedAllowed;
  }

  @override
  Future<ReminderPermissionRequestOutcome>
  requestPermissionWithOutcome() async {
    permissionCalls += 1;
    return permissionOutcome;
  }

  @override
  Future<ReminderPermissionInspectionOutcome> inspectPermission() async {
    inspectionCalls += 1;
    return inspectionOutcome;
  }

  @override
  Future<void> synchronize(
    List<UserLoggingReminder> reminders, {
    required String userScope,
  }) async {
    synchronizationCalls += 1;
  }

  @override
  ReminderScheduleManifestResult preflightSchedule(
    List<UserLoggingReminder> reminders,
  ) => const ReminderScheduleManifestPreflight().evaluate(
    reminders,
    budget: supportsScheduledDelivery
        ? const ReminderScheduleBudget(
            requestLimit: reminderScheduleProductRequestLimit,
          )
        : null,
  );

  @override
  Future<ReminderPendingIdentityAttestation> attestPendingSchedule(
    List<UserLoggingReminder> reminders,
  ) async {
    attestationCalls += 1;
    final planned = reminders
        .where((reminder) => reminder.enabled)
        .fold<int>(0, (count, reminder) => count + reminder.weekdays.length);
    return ReminderPendingIdentityAttestation(
      status: ReminderPendingIdentityAttestationStatus.matched,
      plannedCount: planned,
      installedCount: planned,
      missingCount: 0,
      extraCount: 0,
      replacedCount: 0,
    );
  }
}

class _MemoryDataService extends DataService {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}
