enum UserLoggingReminderKind { mealLog, intakeLog }

enum ReminderNotificationPrivacyMode { minimal, generic }

class UserLoggingReminder {
  const UserLoggingReminder({
    required this.id,
    required this.kind,
    required this.label,
    required this.minuteOfDay,
    required this.weekdays,
    required this.enabled,
    this.activationToken = '',
    this.notificationPrivacyMode = ReminderNotificationPrivacyMode.minimal,
    this.notificationLocaleCode = 'en',
  });

  final String id;
  final UserLoggingReminderKind kind;
  final String label;
  final int minuteOfDay;
  final Set<int> weekdays;
  final bool enabled;
  final String activationToken;
  final ReminderNotificationPrivacyMode notificationPrivacyMode;
  final String notificationLocaleCode;

  int get hour => minuteOfDay ~/ 60;
  int get minute => minuteOfDay % 60;

  UserLoggingReminder copyWith({
    bool? enabled,
    String? activationToken,
    ReminderNotificationPrivacyMode? notificationPrivacyMode,
    String? notificationLocaleCode,
  }) => UserLoggingReminder(
    id: id,
    kind: kind,
    label: label,
    minuteOfDay: minuteOfDay,
    weekdays: weekdays,
    enabled: enabled ?? this.enabled,
    activationToken: activationToken ?? this.activationToken,
    notificationPrivacyMode:
        notificationPrivacyMode ?? this.notificationPrivacyMode,
    notificationLocaleCode:
        notificationLocaleCode ?? this.notificationLocaleCode,
  );

  DateTime nextOccurrence(DateTime now) {
    for (var offset = 0; offset <= 7; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset, hour, minute);
      if (!weekdays.contains(day.weekday)) continue;
      if (day.isAfter(now)) return day;
    }
    return DateTime(now.year, now.month, now.day + 7, hour, minute);
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 3,
    'id': id,
    'kind': kind.name,
    'label': label,
    'minuteOfDay': minuteOfDay,
    'weekdays': weekdays.toList()..sort(),
    'enabled': enabled,
    'activationToken': activationToken,
    'notificationPrivacyMode': notificationPrivacyMode.name,
    'notificationLocaleCode': notificationLocaleCode,
  };

  factory UserLoggingReminder.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final kindName = json['kind'];
    final label = json['label'];
    final minuteOfDay = json['minuteOfDay'];
    final rawWeekdays = json['weekdays'];
    final enabled = json['enabled'];
    final activationToken = json['activationToken'];
    final schemaVersion = json['schemaVersion'];
    final privacyModeName = json['notificationPrivacyMode'];
    final rawNotificationLocaleCode = json['notificationLocaleCode'];
    if (schemaVersion is! int || schemaVersion < 1 || schemaVersion > 3) {
      throw const FormatException('Reminder schema version is unsupported.');
    }
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Reminder id is required.');
    }
    if (label is! String || label.trim().isEmpty || label.length > 80) {
      throw const FormatException('Reminder label must be 1-80 characters.');
    }
    if (minuteOfDay is! int || minuteOfDay < 0 || minuteOfDay >= 1440) {
      throw const FormatException('Reminder minuteOfDay is invalid.');
    }
    if (rawWeekdays is! List) {
      throw const FormatException('Reminder weekdays are required.');
    }
    final weekdays = rawWeekdays.whereType<int>().toSet();
    if (weekdays.isEmpty || weekdays.any((day) => day < 1 || day > 7)) {
      throw const FormatException('Reminder weekdays must be within 1-7.');
    }
    final kind = UserLoggingReminderKind.values.where(
      (candidate) => candidate.name == kindName,
    );
    if (kind.isEmpty) throw const FormatException('Reminder kind is invalid.');
    final ReminderNotificationPrivacyMode privacyMode;
    final String notificationLocaleCode;
    if (schemaVersion < 3) {
      privacyMode = ReminderNotificationPrivacyMode.minimal;
      notificationLocaleCode = 'en';
    } else {
      final matches = ReminderNotificationPrivacyMode.values.where(
        (candidate) => candidate.name == privacyModeName,
      );
      if (matches.isEmpty) {
        throw const FormatException(
          'Reminder notification privacy mode is invalid.',
        );
      }
      privacyMode = matches.single;
      if (rawNotificationLocaleCode is! String ||
          !RegExp(
            r'^[A-Za-z]{2,3}(?:[-_][A-Za-z]{2,4})?$',
          ).hasMatch(rawNotificationLocaleCode)) {
        throw const FormatException('Reminder notification locale is invalid.');
      }
      notificationLocaleCode = rawNotificationLocaleCode.replaceAll('_', '-');
    }
    return UserLoggingReminder(
      id: id,
      kind: kind.single,
      label: label.trim(),
      minuteOfDay: minuteOfDay,
      weekdays: Set<int>.unmodifiable(weekdays),
      enabled: enabled is bool ? enabled : false,
      activationToken:
          activationToken is String &&
              RegExp(r'^[a-f0-9]{32}$').hasMatch(activationToken)
          ? activationToken
          : '',
      notificationPrivacyMode: privacyMode,
      notificationLocaleCode: notificationLocaleCode,
    );
  }
}
