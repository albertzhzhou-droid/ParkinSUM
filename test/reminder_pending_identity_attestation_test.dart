import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/core/services/data_service.dart';
import 'package:parkinsum_companion/core/services/user_logging_reminder_service.dart';
import 'package:parkinsum_companion/domain/entities/user_logging_reminder.dart';
import 'package:parkinsum_companion/features/reminders/reminder_center_page.dart';

import 'helpers/page_test_harness.dart';

void main() {
  group('ReminderPendingIdentityAttestor', () {
    test('matches complete identity sets independent of order', () {
      final result = const ReminderPendingIdentityAttestor().evaluate(
        planned: [_identity(7, 'planned-a'), _identity(9, 'planned-b')],
        installed: [_identity(9, 'planned-b'), _identity(7, 'planned-a')],
      );

      expect(result.status, ReminderPendingIdentityAttestationStatus.matched);
      expect(result.matched, isTrue);
      expect(result.plannedCount, 2);
      expect(result.installedCount, 2);
      expect(result.missingCount, 0);
      expect(result.extraCount, 0);
      expect(result.replacedCount, 0);
    });

    test('count equality cannot hide a replaced pending payload', () {
      final result = const ReminderPendingIdentityAttestor().evaluate(
        planned: [_identity(7, 'current-capability')],
        installed: [_identity(7, 'stale-capability')],
      );

      expect(result.status, ReminderPendingIdentityAttestationStatus.drift);
      expect(result.plannedCount, result.installedCount);
      expect(result.replacedCount, 1);
      expect(result.missingCount, 0);
      expect(result.extraCount, 0);
    });

    test('reports missing and extra identities separately', () {
      final result = const ReminderPendingIdentityAttestor().evaluate(
        planned: [_identity(1, 'one'), _identity(2, 'two')],
        installed: [_identity(2, 'two'), _identity(3, 'three')],
      );

      expect(result.status, ReminderPendingIdentityAttestationStatus.drift);
      expect(result.missingCount, 1);
      expect(result.extraCount, 1);
      expect(result.replacedCount, 0);
    });

    test('duplicate or malformed identity sets fail uninspectable', () {
      final duplicate = const ReminderPendingIdentityAttestor().evaluate(
        planned: [_identity(1, 'one'), _identity(1, 'one-again')],
        installed: const [],
      );
      final malformed = const ReminderPendingIdentityAttestor().evaluate(
        planned: const [
          ReminderPendingRequestIdentity(
            notificationId: -1,
            payloadDigest: 'not-a-digest',
          ),
        ],
        installed: const [],
      );

      expect(
        duplicate.status,
        ReminderPendingIdentityAttestationStatus.uninspectable,
      );
      expect(
        malformed.status,
        ReminderPendingIdentityAttestationStatus.uninspectable,
      );
    });

    test('plugin registry ignores unrelated notification categories', () {
      final planned = _identity(7, 'current');
      final result = const ReminderPendingIdentityAttestor()
          .evaluatePluginRegistry(
            planned: [planned],
            pending: const [
              ReminderPendingRequestSnapshot(
                notificationId: 99,
                payload: 'another-feature:payload',
              ),
            ],
          );

      expect(result.missingCount, 1);
      expect(result.extraCount, 0);
      expect(result.replacedCount, 0);
    });

    test(
      'plugin registry retains planned-id collisions and old reminder extras',
      () {
        final result = const ReminderPendingIdentityAttestor()
            .evaluatePluginRegistry(
              planned: [_identity(7, 'current')],
              pending: const [
                ReminderPendingRequestSnapshot(
                  notificationId: 7,
                  payload: null,
                ),
                ReminderPendingRequestSnapshot(
                  notificationId: 11,
                  payload:
                      'parkinsum-reminder:v2:0123456789abcdef0123456789abcdef:old',
                ),
              ],
            );

        expect(result.replacedCount, 1);
        expect(result.extraCount, 1);
        expect(result.missingCount, 0);
      },
    );
  });

  group('UserLoggingReminderController identity attestation', () {
    test(
      'exact plugin-registry identity match retains verified state',
      () async {
        final gateway = _AttestingGateway(
          const ReminderPendingIdentityAttestation(
            status: ReminderPendingIdentityAttestationStatus.matched,
            plannedCount: 1,
            installedCount: 1,
            missingCount: 0,
            extraCount: 0,
            replacedCount: 0,
          ),
        );
        final controller = UserLoggingReminderController(
          userScope: 'user-a',
          repository: UserLoggingReminderRepository(
            storage: _MemoryDataService(),
          ),
          gateway: gateway,
        );

        final saved = await controller.save(_reminder());

        expect(saved, isTrue);
        expect(controller.error, isNull);
        expect(
          controller.scheduleSystemState,
          ReminderScheduleSystemState.verified,
        );
        expect(controller.pendingIdentityAttestation?.matched, isTrue);
        expect(controller.lastSynchronizedAt, isNotNull);
      },
    );

    test(
      'drift keeps the durable plan but removes verified UI state',
      () async {
        final storage = _MemoryDataService();
        final repository = UserLoggingReminderRepository(storage: storage);
        final gateway = _AttestingGateway(
          const ReminderPendingIdentityAttestation(
            status: ReminderPendingIdentityAttestationStatus.drift,
            plannedCount: 1,
            installedCount: 1,
            missingCount: 0,
            extraCount: 0,
            replacedCount: 1,
          ),
        );
        final controller = UserLoggingReminderController(
          userScope: 'user-a',
          repository: repository,
          gateway: gateway,
        );

        final saved = await controller.save(_reminder());

        expect(saved, isTrue, reason: 'the local authored plan was persisted');
        expect((await repository.load('user-a')).single.id, 'reminder-1');
        expect(controller.error, 'schedule_identity_unverified');
        expect(
          controller.scheduleSystemState,
          ReminderScheduleSystemState.unverified,
        );
        expect(controller.lastSynchronizedAt, isNull);
        expect(controller.pendingIdentityAttestation?.replacedCount, 1);
        expect(await controller.resynchronize(), isFalse);
      },
    );
  });

  test('attestation copy is native in every shipped language family', () {
    const keys = {
      'reminders.identity_attestation_title',
      'reminders.identity_attestation_matched',
      'reminders.identity_attestation_drift',
      'reminders.identity_attestation_uninspectable',
      'reminders.error_schedule_identity_unverified',
    };
    final dictionary = AppI18n.translationDictionary;
    final english = dictionary['en']!;

    for (final family in AppI18n.translationFamilies) {
      final translations = dictionary[family]!;
      for (final key in keys) {
        expect(translations, contains(key), reason: '$family is missing $key');
        expect(
          _placeholders(translations[key]!),
          _placeholders(english[key]!),
          reason: '$family changed the placeholder contract for $key',
        );
        if (family != 'en') {
          expect(
            translations[key],
            isNot(english[key]),
            reason: '$family still falls back to English for $key',
          );
        }
      }
    }
  });

  testWidgets(
    'reminder center renders count-only plugin drift without private payloads',
    (tester) async {
      final controller = UserLoggingReminderController(
        userScope: 'private-user-scope',
        repository: UserLoggingReminderRepository(
          storage: _MemoryDataService(),
        ),
        gateway: _AttestingGateway(
          const ReminderPendingIdentityAttestation(
            status: ReminderPendingIdentityAttestationStatus.drift,
            plannedCount: 0,
            installedCount: 1,
            missingCount: 0,
            extraCount: 1,
            replacedCount: 0,
          ),
        ),
      );

      await pumpFeaturePage(
        tester,
        ReminderCenterPage(controller: controller),
        settle: true,
      );

      expect(
        find.byKey(const ValueKey('reminder-pending-identity-attestation')),
        findsOneWidget,
      );
      expect(
        find.textContaining('0 missing, 1 extra, and 0 replaced'),
        findsOneWidget,
      );
      expect(find.textContaining('private-user-scope'), findsNothing);
      expect(find.textContaining('parkinsum-reminder:v2:'), findsNothing);
      expect(
        find.textContaining('plugin-reported pending identities'),
        findsOneWidget,
      );
      expectNoWidgetErrors();
    },
  );
}

ReminderPendingRequestIdentity _identity(int id, String payload) =>
    ReminderPendingRequestIdentity.fromPayload(
      notificationId: id,
      payload: payload,
    );

Set<String> _placeholders(String value) => RegExp(
  r'\{[A-Za-z0-9_]+\}',
).allMatches(value).map((match) => match.group(0)!).toSet();

UserLoggingReminder _reminder() => const UserLoggingReminder(
  id: 'reminder-1',
  kind: UserLoggingReminderKind.mealLog,
  label: 'Log breakfast',
  minuteOfDay: 8 * 60,
  weekdays: {1},
  enabled: true,
  activationToken: '0123456789abcdef0123456789abcdef',
);

class _AttestingGateway
    implements
        ReminderNotificationGateway,
        ReminderNotificationPreflight,
        ReminderNotificationIdentityInspector {
  _AttestingGateway(this.attestation);

  final ReminderPendingIdentityAttestation attestation;

  @override
  bool get supportsScheduledDelivery => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> synchronize(
    List<UserLoggingReminder> reminders, {
    required String userScope,
  }) async {}

  @override
  ReminderScheduleManifestResult preflightSchedule(
    List<UserLoggingReminder> reminders,
  ) => const ReminderScheduleManifestPreflight().evaluate(
    reminders,
    budget: const ReminderScheduleBudget(requestLimit: 64),
  );

  @override
  Future<ReminderPendingIdentityAttestation> attestPendingSchedule(
    List<UserLoggingReminder> reminders,
  ) async => attestation;
}

class _MemoryDataService extends DataService {
  final Map<String, String> _values = {};

  @override
  Future<String?> getString(String key) async => _values[key];

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }
}
