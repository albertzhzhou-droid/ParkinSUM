import '../../domain/entities/user_logging_reminder.dart';

/// The exact system-visible notification copy selected for one reminder.
///
/// User-authored reminder labels are intentionally absent from this API, so a
/// caller cannot accidentally substitute them into lock-screen content.
class ReminderNotificationPresentation {
  const ReminderNotificationPresentation({
    required this.mode,
    required this.languageCode,
    required this.title,
    required this.body,
    required this.hideFromSecureAndroidLockScreen,
  });

  final ReminderNotificationPrivacyMode mode;
  final String languageCode;
  final String title;
  final String body;

  /// Maps to Android `VISIBILITY_SECRET` when true and `VISIBILITY_PRIVATE`
  /// otherwise. Android users retain ultimate control in system settings.
  final bool hideFromSecureAndroidLockScreen;

  /// Apple preview visibility is a system/user setting. ParkinSUM can minimize
  /// the submitted text but cannot promise to hide it from the lock screen.
  bool get darwinPreviewRemainsSystemControlled => true;
}

/// Pure, versionable presentation policy for scheduled reminder copy.
///
/// Both modes exclude the user's label, event kind, medication, dose, meal,
/// account, disease, and adherence status. [minimal] additionally requests
/// Android's secret lock-screen visibility; Darwin platforms still follow the
/// user's system preview setting.
abstract final class ReminderNotificationPrivacyPolicy {
  static ReminderNotificationPresentation resolve({
    required ReminderNotificationPrivacyMode mode,
    required String localeName,
  }) {
    final languageCode = _supportedLanguageCode(localeName);
    final copy = _copyByLanguage[languageCode]!;
    return ReminderNotificationPresentation(
      mode: mode,
      languageCode: languageCode,
      title: copy.titleFor(mode),
      body: copy.bodyFor(mode),
      hideFromSecureAndroidLockScreen:
          mode == ReminderNotificationPrivacyMode.minimal,
    );
  }

  static String _supportedLanguageCode(String localeName) {
    final normalized = localeName.trim().toLowerCase();
    final languageCode = normalized.split(RegExp('[-_]')).first;
    return _copyByLanguage.containsKey(languageCode) ? languageCode : 'en';
  }

  static const Map<String, _ReminderNotificationCopy> _copyByLanguage = {
    'en': _ReminderNotificationCopy(
      minimalTitle: 'ParkinSUM',
      minimalBody: 'Open ParkinSUM to review a private reminder.',
      genericTitle: 'ParkinSUM logging reminder',
      genericBody:
          'Logging prompt only — open ParkinSUM to record something you already chose.',
    ),
    'zh': _ReminderNotificationCopy(
      minimalTitle: 'ParkinSUM',
      minimalBody: '打开 ParkinSUM 查看一条私密提醒。',
      genericTitle: 'ParkinSUM 记录提醒',
      genericBody: '仅用于提醒记录——打开 ParkinSUM 记录你已经自行决定的事项。',
    ),
    'fr': _ReminderNotificationCopy(
      minimalTitle: 'ParkinSUM',
      minimalBody: 'Ouvrez ParkinSUM pour consulter un rappel privé.',
      genericTitle: 'Rappel de journalisation ParkinSUM',
      genericBody:
          'Invite de journalisation uniquement — ouvrez ParkinSUM pour noter un élément déjà choisi.',
    ),
    'ja': _ReminderNotificationCopy(
      minimalTitle: 'ParkinSUM',
      minimalBody: 'ParkinSUM を開いて非公開のリマインダーを確認してください。',
      genericTitle: 'ParkinSUM 記録リマインダー',
      genericBody: '記録の促しのみです。ParkinSUM を開き、自分で決めた内容を記録してください。',
    ),
  };
}

class _ReminderNotificationCopy {
  const _ReminderNotificationCopy({
    required this.minimalTitle,
    required this.minimalBody,
    required this.genericTitle,
    required this.genericBody,
  });

  final String minimalTitle;
  final String minimalBody;
  final String genericTitle;
  final String genericBody;

  String titleFor(ReminderNotificationPrivacyMode mode) => switch (mode) {
    ReminderNotificationPrivacyMode.minimal => minimalTitle,
    ReminderNotificationPrivacyMode.generic => genericTitle,
  };

  String bodyFor(ReminderNotificationPrivacyMode mode) => switch (mode) {
    ReminderNotificationPrivacyMode.minimal => minimalBody,
    ReminderNotificationPrivacyMode.generic => genericBody,
  };
}
