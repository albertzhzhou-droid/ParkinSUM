import 'dart:convert';

import 'package:crypto/crypto.dart';

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
    required this.identitySha256,
  });

  final ReminderNotificationPrivacyMode mode;
  final String languageCode;
  final String title;
  final String body;

  /// Maps to Android `VISIBILITY_SECRET` when true and `VISIBILITY_PRIVATE`
  /// otherwise. Android users retain ultimate control in system settings.
  final bool hideFromSecureAndroidLockScreen;

  /// Canonical identity of the exact non-sensitive copy and requested
  /// platform presentation semantics submitted for scheduling.
  final String identitySha256;

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
  static const String identitySchema =
      'parkinsum.reminder-notification-presentation/1';

  static ReminderNotificationPresentation resolve({
    required ReminderNotificationPrivacyMode mode,
    required String localeName,
  }) {
    final languageCode = _supportedLanguageCode(localeName);
    final copy = _copyByLanguage[languageCode]!;
    final title = copy.titleFor(mode);
    final body = copy.bodyFor(mode);
    final hideFromSecureAndroidLockScreen =
        mode == ReminderNotificationPrivacyMode.minimal;
    final identitySha256 = sha256
        .convert(
          utf8.encode(
            jsonEncode(<Object?>[
              identitySchema,
              mode.name,
              languageCode,
              title,
              body,
              hideFromSecureAndroidLockScreen,
              true,
            ]),
          ),
        )
        .toString();
    return ReminderNotificationPresentation(
      mode: mode,
      languageCode: languageCode,
      title: title,
      body: body,
      hideFromSecureAndroidLockScreen: hideFromSecureAndroidLockScreen,
      identitySha256: identitySha256,
    );
  }

  static String supportedLanguageCode(String localeName) {
    final languageCode = reminderNotificationLanguageCode(localeName);
    return _copyByLanguage.containsKey(languageCode) ? languageCode : 'en';
  }

  static String _supportedLanguageCode(String localeName) =>
      supportedLanguageCode(localeName);

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
    'ko': _ReminderNotificationCopy(
      minimalTitle: 'ParkinSUM',
      minimalBody: 'ParkinSUM을 열어 비공개 알림을 확인하세요.',
      genericTitle: 'ParkinSUM 기록 알림',
      genericBody: '기록 알림일 뿐입니다. ParkinSUM을 열어 이미 직접 결정한 내용을 기록하세요.',
    ),
    'hi': _ReminderNotificationCopy(
      minimalTitle: 'ParkinSUM',
      minimalBody: 'निजी रिमाइंडर देखने के लिए ParkinSUM खोलें।',
      genericTitle: 'ParkinSUM लॉगिंग रिमाइंडर',
      genericBody:
          'यह केवल लॉगिंग संकेत है—अपनी पहले से तय की गई बात दर्ज करने के लिए ParkinSUM खोलें।',
    ),
    'es': _ReminderNotificationCopy(
      minimalTitle: 'ParkinSUM',
      minimalBody: 'Abre ParkinSUM para revisar un recordatorio privado.',
      genericTitle: 'Recordatorio de registro de ParkinSUM',
      genericBody:
          'Solo es un aviso de registro: abre ParkinSUM para anotar algo que ya decidiste.',
    ),
    'vi': _ReminderNotificationCopy(
      minimalTitle: 'ParkinSUM',
      minimalBody: 'Mở ParkinSUM để xem lời nhắc riêng tư.',
      genericTitle: 'Lời nhắc ghi chép ParkinSUM',
      genericBody:
          'Chỉ là lời nhắc ghi chép — mở ParkinSUM để ghi lại điều bạn đã tự quyết định.',
    ),
    'th': _ReminderNotificationCopy(
      minimalTitle: 'ParkinSUM',
      minimalBody: 'เปิด ParkinSUM เพื่อดูการเตือนส่วนตัว',
      genericTitle: 'การเตือนบันทึก ParkinSUM',
      genericBody:
          'เป็นเพียงการเตือนให้บันทึก — เปิด ParkinSUM เพื่อบันทึกสิ่งที่คุณตัดสินใจไว้แล้ว',
    ),
    'id': _ReminderNotificationCopy(
      minimalTitle: 'ParkinSUM',
      minimalBody: 'Buka ParkinSUM untuk melihat pengingat pribadi.',
      genericTitle: 'Pengingat pencatatan ParkinSUM',
      genericBody:
          'Hanya pengingat pencatatan — buka ParkinSUM untuk mencatat hal yang sudah Anda putuskan.',
    ),
    'ru': _ReminderNotificationCopy(
      minimalTitle: 'ParkinSUM',
      minimalBody: 'Откройте ParkinSUM, чтобы просмотреть личное напоминание.',
      genericTitle: 'Напоминание о записи ParkinSUM',
      genericBody:
          'Только предложение сделать запись — откройте ParkinSUM и запишите то, что уже решили.',
    ),
    'pl': _ReminderNotificationCopy(
      minimalTitle: 'ParkinSUM',
      minimalBody: 'Otwórz ParkinSUM, aby sprawdzić prywatne przypomnienie.',
      genericTitle: 'Przypomnienie o zapisie ParkinSUM',
      genericBody:
          'To tylko prośba o zapis — otwórz ParkinSUM i zanotuj to, co już wybrano.',
    ),
    'ar': _ReminderNotificationCopy(
      minimalTitle: 'ParkinSUM',
      minimalBody: 'افتح ParkinSUM لمراجعة تذكير خاص.',
      genericTitle: 'تذكير بالتسجيل من ParkinSUM',
      genericBody:
          'هذا تنبيه للتسجيل فقط — افتح ParkinSUM لتسجيل أمر سبق أن قررته بنفسك.',
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
