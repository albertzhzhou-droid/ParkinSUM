import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../domain/entities/user_logging_reminder.dart';

typedef ReminderScheduleNotificationIdHasher =
    int Function(String reminderId, int weekday);

/// The existing ParkinSUM notification identifier mapping.
///
/// The result is intentionally restricted to the non-negative 31-bit range so
/// this pure-Dart preflight exactly matches the identifiers currently produced
/// by the native notification gateway.
int fnv1a31ReminderNotificationId(String reminderId, int weekday) {
  var hash = 0x811c9dc5;
  for (final codeUnit in '$reminderId:$weekday'.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

/// A caller-supplied request budget for the platform being reconciled.
///
/// This type deliberately contains no platform detection. The application
/// boundary remains responsible for selecting and truthfully labelling the
/// policy that applies to the current platform.
class ReminderScheduleBudget {
  const ReminderScheduleBudget({required this.requestLimit});

  final int requestLimit;
}

class ReminderScheduleManifestEntry {
  const ReminderScheduleManifestEntry({
    required this.reminderId,
    required this.capabilityDigest,
    required this.minuteOfDay,
    required this.weekday,
    required this.notificationId,
  });

  final String reminderId;
  final String capabilityDigest;
  final int minuteOfDay;
  final int weekday;
  final int notificationId;

  String get slotKey => '$reminderId:$weekday';
}

class ReminderScheduleManifest {
  ReminderScheduleManifest._(List<ReminderScheduleManifestEntry> entries)
    : entries = List<ReminderScheduleManifestEntry>.unmodifiable(entries);

  /// Entries are ordered by opaque reminder id and then weekday.
  ///
  /// Input list and [Set] iteration order therefore cannot change the manifest.
  final List<ReminderScheduleManifestEntry> entries;

  int get projected => entries.length;
}

enum ReminderScheduleManifestFailureKind {
  invalidBudget,
  invalidReminderId,
  duplicateReminderId,
  invalidActivationToken,
  invalidMinuteOfDay,
  invalidWeekdays,
  capacityExceeded,
  notificationIdHasherFailed,
  invalidNotificationId,
  notificationIdCollision,
}

/// Machine-readable failure details that do not contain reminder labels or
/// activation tokens.
class ReminderScheduleManifestFailure {
  const ReminderScheduleManifestFailure({
    required this.kind,
    this.reminderId,
    this.weekday,
    this.otherReminderId,
    this.otherWeekday,
    this.notificationId,
  });

  final ReminderScheduleManifestFailureKind kind;
  final String? reminderId;
  final int? weekday;
  final String? otherReminderId;
  final int? otherWeekday;
  final int? notificationId;
}

class ReminderScheduleManifestResult {
  const ReminderScheduleManifestResult._({
    required this.projected,
    required this.limit,
    required this.headroom,
    required this.excess,
    required this.manifest,
    required this.failure,
  });

  final int projected;
  final int? limit;

  /// Remaining request slots, clamped to zero when the plan exceeds its limit.
  final int? headroom;

  /// Requests over the supplied limit, or null when no limit was supplied.
  final int? excess;
  final ReminderScheduleManifest? manifest;
  final ReminderScheduleManifestFailure? failure;

  bool get accepted => failure == null;
}

/// Builds a deterministic schedule manifest without touching persistence,
/// permissions, Flutter bindings, or a native notification API.
class ReminderScheduleManifestPreflight {
  const ReminderScheduleManifestPreflight({
    this.notificationIdHasher = fnv1a31ReminderNotificationId,
  });

  static final RegExp _reminderIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,80}$');
  static final RegExp _activationTokenPattern = RegExp(r'^[a-f0-9]{32}$');

  final ReminderScheduleNotificationIdHasher notificationIdHasher;

  ReminderScheduleManifestResult evaluate(
    Iterable<UserLoggingReminder> reminders, {
    ReminderScheduleBudget? budget,
  }) {
    final ordered = reminders.toList(growable: false)
      ..sort((left, right) => left.id.compareTo(right.id));
    final projected = ordered
        .where((reminder) => reminder.enabled)
        .fold<int>(0, (total, reminder) => total + reminder.weekdays.length);
    final limit = budget?.requestLimit;

    ReminderScheduleManifestResult failure(
      ReminderScheduleManifestFailure value,
    ) => _result(projected: projected, limit: limit, failure: value);

    if (limit != null && limit < 0) {
      return failure(
        const ReminderScheduleManifestFailure(
          kind: ReminderScheduleManifestFailureKind.invalidBudget,
        ),
      );
    }

    for (final reminder in ordered) {
      if (!_reminderIdPattern.hasMatch(reminder.id)) {
        return failure(
          ReminderScheduleManifestFailure(
            kind: ReminderScheduleManifestFailureKind.invalidReminderId,
            reminderId: reminder.id,
          ),
        );
      }
    }

    final seenReminderIds = <String>{};
    for (final reminder in ordered) {
      if (!seenReminderIds.add(reminder.id)) {
        return failure(
          ReminderScheduleManifestFailure(
            kind: ReminderScheduleManifestFailureKind.duplicateReminderId,
            reminderId: reminder.id,
          ),
        );
      }
    }

    for (final reminder in ordered) {
      if (!_activationTokenPattern.hasMatch(reminder.activationToken)) {
        return failure(
          ReminderScheduleManifestFailure(
            kind: ReminderScheduleManifestFailureKind.invalidActivationToken,
            reminderId: reminder.id,
          ),
        );
      }
      if (reminder.minuteOfDay < 0 || reminder.minuteOfDay >= 1440) {
        return failure(
          ReminderScheduleManifestFailure(
            kind: ReminderScheduleManifestFailureKind.invalidMinuteOfDay,
            reminderId: reminder.id,
          ),
        );
      }
      if (reminder.weekdays.isEmpty ||
          reminder.weekdays.any((weekday) => weekday < 1 || weekday > 7)) {
        return failure(
          ReminderScheduleManifestFailure(
            kind: ReminderScheduleManifestFailureKind.invalidWeekdays,
            reminderId: reminder.id,
          ),
        );
      }
    }

    if (limit != null && projected > limit) {
      return failure(
        const ReminderScheduleManifestFailure(
          kind: ReminderScheduleManifestFailureKind.capacityExceeded,
        ),
      );
    }

    final entries = <ReminderScheduleManifestEntry>[];
    final entriesByNotificationId = <int, ReminderScheduleManifestEntry>{};
    for (final reminder in ordered.where((reminder) => reminder.enabled)) {
      final weekdays = reminder.weekdays.toList(growable: false)..sort();
      for (final weekday in weekdays) {
        late final int notificationId;
        try {
          notificationId = notificationIdHasher(reminder.id, weekday);
        } catch (_) {
          return failure(
            ReminderScheduleManifestFailure(
              kind: ReminderScheduleManifestFailureKind
                  .notificationIdHasherFailed,
              reminderId: reminder.id,
              weekday: weekday,
            ),
          );
        }
        if (notificationId < 0 || notificationId > 0x7fffffff) {
          return failure(
            ReminderScheduleManifestFailure(
              kind: ReminderScheduleManifestFailureKind.invalidNotificationId,
              reminderId: reminder.id,
              weekday: weekday,
              notificationId: notificationId,
            ),
          );
        }

        final entry = ReminderScheduleManifestEntry(
          reminderId: reminder.id,
          capabilityDigest: sha256
              .convert(utf8.encode(reminder.activationToken))
              .toString(),
          minuteOfDay: reminder.minuteOfDay,
          weekday: weekday,
          notificationId: notificationId,
        );
        final existing = entriesByNotificationId[notificationId];
        if (existing != null) {
          return failure(
            ReminderScheduleManifestFailure(
              kind: ReminderScheduleManifestFailureKind.notificationIdCollision,
              reminderId: entry.reminderId,
              weekday: entry.weekday,
              otherReminderId: existing.reminderId,
              otherWeekday: existing.weekday,
              notificationId: notificationId,
            ),
          );
        }
        entriesByNotificationId[notificationId] = entry;
        entries.add(entry);
      }
    }

    return _result(
      projected: projected,
      limit: limit,
      manifest: ReminderScheduleManifest._(entries),
    );
  }

  ReminderScheduleManifestResult _result({
    required int projected,
    required int? limit,
    ReminderScheduleManifest? manifest,
    ReminderScheduleManifestFailure? failure,
  }) {
    final validLimit = limit != null && limit >= 0;
    final difference = validLimit ? limit - projected : null;
    return ReminderScheduleManifestResult._(
      projected: projected,
      limit: limit,
      headroom: difference == null
          ? null
          : difference < 0
          ? 0
          : difference,
      excess: difference == null
          ? null
          : difference < 0
          ? -difference
          : 0,
      manifest: manifest,
      failure: failure,
    );
  }
}
