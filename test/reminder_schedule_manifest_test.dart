import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/services/reminder_schedule_manifest.dart';
import 'package:parkinsum_companion/domain/entities/user_logging_reminder.dart';

void main() {
  group('ReminderScheduleManifestPreflight capacity', () {
    test('reports exact 0, 1, and 7 request projections', () {
      final empty = _evaluate(const []);
      final one = _evaluate([
        _reminder(id: 'one', weekdays: {3}),
      ]);
      final seven = _evaluate([_reminder(id: 'seven')]);

      expect(empty.accepted, isTrue);
      expect(empty.projected, 0);
      expect(empty.limit, 64);
      expect(empty.headroom, 64);
      expect(empty.excess, 0);
      expect(empty.manifest!.entries, isEmpty);

      expect(one.accepted, isTrue);
      expect(one.projected, 1);
      expect(one.headroom, 63);
      expect(one.manifest!.entries.single.weekday, 3);
      expect(one.manifest!.entries.single.capabilityDigest, hasLength(64));
      expect(
        one.manifest!.entries.single.capabilityDigest,
        isNot('0123456789abcdef0123456789abcdef'),
      );

      expect(seven.accepted, isTrue);
      expect(seven.projected, 7);
      expect(seven.headroom, 57);
      expect(
        seven.manifest!.entries.map((entry) => entry.weekday),
        orderedEquals([1, 2, 3, 4, 5, 6, 7]),
      );
    });

    test('accepts 63 and 64 but rejects 65 and 70 against a 64 budget', () {
      final sixtyThree = _evaluate(_fullWeekReminders(9));
      final sixtyFour = _evaluate([
        ..._fullWeekReminders(9),
        _reminder(id: 'extra_1', weekdays: {1}),
      ]);
      final sixtyFive = _evaluate([
        ..._fullWeekReminders(9),
        _reminder(id: 'extra_2', weekdays: {1, 2}),
      ]);
      final seventy = _evaluate(_fullWeekReminders(10));

      expect(sixtyThree.accepted, isTrue);
      expect(sixtyThree.projected, 63);
      expect(sixtyThree.headroom, 1);
      expect(sixtyThree.excess, 0);

      expect(sixtyFour.accepted, isTrue);
      expect(sixtyFour.projected, 64);
      expect(sixtyFour.headroom, 0);
      expect(sixtyFour.excess, 0);

      expect(sixtyFive.accepted, isFalse);
      expect(sixtyFive.projected, 65);
      expect(sixtyFive.limit, 64);
      expect(sixtyFive.headroom, 0);
      expect(sixtyFive.excess, 1);
      expect(
        sixtyFive.failure!.kind,
        ReminderScheduleManifestFailureKind.capacityExceeded,
      );
      expect(sixtyFive.manifest, isNull);

      expect(seventy.accepted, isFalse);
      expect(seventy.projected, 70);
      expect(seventy.headroom, 0);
      expect(seventy.excess, 6);
      expect(
        seventy.failure!.kind,
        ReminderScheduleManifestFailureKind.capacityExceeded,
      );
    });

    test('disabled plans consume zero request slots', () {
      final result = const ReminderScheduleManifestPreflight().evaluate([
        _reminder(id: 'disabled', enabled: false),
      ], budget: const ReminderScheduleBudget(requestLimit: 0));

      expect(result.accepted, isTrue);
      expect(result.projected, 0);
      expect(result.limit, 0);
      expect(result.headroom, 0);
      expect(result.excess, 0);
      expect(result.manifest!.entries, isEmpty);
    });
  });

  group('ReminderScheduleManifestPreflight validation', () {
    test('returns typed id, token, and duplicate-plan failures', () {
      final invalidId = _evaluate([_reminder(id: 'not valid')]);
      final invalidToken = _evaluate([
        _reminder(id: 'bad_token', activationToken: 'invalid'),
      ]);
      final duplicate = _evaluate([
        _reminder(id: 'duplicate'),
        _reminder(id: 'duplicate', weekdays: {1}),
      ]);

      expect(
        invalidId.failure!.kind,
        ReminderScheduleManifestFailureKind.invalidReminderId,
      );
      expect(invalidId.failure!.reminderId, 'not valid');
      expect(
        invalidToken.failure!.kind,
        ReminderScheduleManifestFailureKind.invalidActivationToken,
      );
      expect(invalidToken.failure!.reminderId, 'bad_token');
      expect(
        duplicate.failure!.kind,
        ReminderScheduleManifestFailureKind.duplicateReminderId,
      );
      expect(duplicate.failure!.reminderId, 'duplicate');
    });

    test('rejects invalid injected budgets and notification ids', () {
      final invalidBudget = const ReminderScheduleManifestPreflight().evaluate([
        _reminder(id: 'valid'),
      ], budget: const ReminderScheduleBudget(requestLimit: -1));
      final invalidNotificationId = ReminderScheduleManifestPreflight(
        notificationIdHasher: (_, _) => -1,
      ).evaluate([_reminder(id: 'valid')]);

      expect(
        invalidBudget.failure!.kind,
        ReminderScheduleManifestFailureKind.invalidBudget,
      );
      expect(invalidBudget.limit, -1);
      expect(invalidBudget.headroom, isNull);
      expect(
        invalidNotificationId.failure!.kind,
        ReminderScheduleManifestFailureKind.invalidNotificationId,
      );
    });
  });

  group('ReminderScheduleManifestPreflight identifiers', () {
    test('detects a real collision in the current 31-bit FNV mapping', () {
      const first = 'reminder_5bd6179aa3582d38e91a5cba7bf5de6b';
      const second = 'reminder_0c8d58cb34309c90508c88440b15a0a3';

      expect(fnv1a31ReminderNotificationId(first, 1), 480530336);
      expect(fnv1a31ReminderNotificationId(second, 1), 480530336);

      final result = const ReminderScheduleManifestPreflight().evaluate([
        _reminder(id: second, weekdays: {1}),
        _reminder(id: first, weekdays: {1}),
      ]);

      expect(result.accepted, isFalse);
      expect(result.projected, 2);
      expect(
        result.failure!.kind,
        ReminderScheduleManifestFailureKind.notificationIdCollision,
      );
      expect(result.failure!.notificationId, 480530336);
      expect(
        {result.failure!.reminderId, result.failure!.otherReminderId},
        {first, second},
      );
      expect(result.manifest, isNull);
    });

    test('supports an injected hasher for deterministic collision tests', () {
      final result =
          ReminderScheduleManifestPreflight(
            notificationIdHasher: (_, _) => 42,
          ).evaluate([
            _reminder(id: 'injected', weekdays: {1, 7}),
          ]);

      expect(result.accepted, isFalse);
      expect(
        result.failure!.kind,
        ReminderScheduleManifestFailureKind.notificationIdCollision,
      );
      expect(result.failure!.notificationId, 42);
      expect({result.failure!.weekday, result.failure!.otherWeekday}, {1, 7});
    });

    test(
      'manifest order is stable across plan and weekday insertion order',
      () {
        final first = const ReminderScheduleManifestPreflight().evaluate([
          _reminder(id: 'z_plan', weekdays: {4, 2}),
          _reminder(id: 'a_plan', weekdays: {7, 1, 3}),
        ]);
        final second = const ReminderScheduleManifestPreflight().evaluate([
          _reminder(id: 'a_plan', weekdays: {3, 7, 1}),
          _reminder(id: 'z_plan', weekdays: {2, 4}),
        ]);

        final firstEntries = first.manifest!.entries
            .map((entry) => '${entry.slotKey}=${entry.notificationId}')
            .toList();
        final secondEntries = second.manifest!.entries
            .map((entry) => '${entry.slotKey}=${entry.notificationId}')
            .toList();

        expect(
          first.manifest!.entries.map((entry) => entry.slotKey),
          orderedEquals([
            'a_plan:1',
            'a_plan:3',
            'a_plan:7',
            'z_plan:2',
            'z_plan:4',
          ]),
        );
        expect(secondEntries, firstEntries);
      },
    );
  });
}

ReminderScheduleManifestResult _evaluate(List<UserLoggingReminder> reminders) =>
    const ReminderScheduleManifestPreflight().evaluate(
      reminders,
      budget: const ReminderScheduleBudget(requestLimit: 64),
    );

List<UserLoggingReminder> _fullWeekReminders(int count) => List.generate(
  count,
  (index) => _reminder(id: 'plan_${index.toString().padLeft(2, '0')}'),
  growable: false,
);

UserLoggingReminder _reminder({
  required String id,
  Set<int> weekdays = const {1, 2, 3, 4, 5, 6, 7},
  bool enabled = true,
  String activationToken = '0123456789abcdef0123456789abcdef',
}) => UserLoggingReminder(
  id: id,
  kind: UserLoggingReminderKind.intakeLog,
  label: 'Private label is not copied into the manifest',
  minuteOfDay: 9 * 60,
  weekdays: weekdays,
  enabled: enabled,
  activationToken: activationToken,
);
