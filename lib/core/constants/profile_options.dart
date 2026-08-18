/// Profile choices shared by onboarding and the post-onboarding settings UI.
///
/// Keeping these lists in one place prevents a user from saving a value after
/// onboarding that the setup flow cannot later render (or the reverse).
const List<String> kSupportedRegistrationRegions = <String>[
  'CN',
  'US',
  'CA',
  'FR',
  'JP',
  'KR',
  'IN',
  'ES',
  'MX',
  'VN',
  'TH',
  'ID',
  'RU',
  'PL',
  'SA',
];

const List<String> kSupportedDisplayLocales = <String>[
  'zh-CN',
  'en-US',
  'en-CA',
  'fr-CA',
  'fr-FR',
  'ja-JP',
  'ko-KR',
  'hi-IN',
  'es-ES',
  'es-MX',
  'vi-VN',
  'th-TH',
  'id-ID',
  'ru-RU',
  'pl-PL',
  'ar-SA',
];

const List<String> kSupportedTextureModes = <String>[
  'unrestricted',
  'soft_or_liquid',
  'liquid_only',
];
