import '../../core/models/drug_definition.dart';
import '../../core/models/intake.dart';
import '../../core/models/medication_product_pack.dart';
import '../../core/models/user_profile.dart';
import '../../domain/usecases/intake_dose_context_builder.dart';

class OnboardingDraft {
  final String registrationRegion;
  final String displayLocale;
  final String? dietProfileRegion;
  final String swallowingTextureMode;
  final bool localAiConsentEnabled;
  final String contentJurisdictionOverrideText;
  final List<String> activeDrugIds;
  final String? initialIntakeDrugId;
  final DateTime? initialIntakeAt;
  final String initialIntakeDoseNote;

  /// The product and unit count the person picked, if any. Its dose
  /// derivation is recorded only when the dose note came from that pick.
  final MedicationProductSelection? initialIntakeProductSelection;

  /// The product record behind [initialIntakeProductSelection]; its form,
  /// route and release type are carried onto the intake.
  final MedicationProductPack? initialIntakeProduct;

  const OnboardingDraft({
    required this.registrationRegion,
    required this.displayLocale,
    required this.dietProfileRegion,
    required this.swallowingTextureMode,
    required this.localAiConsentEnabled,
    required this.contentJurisdictionOverrideText,
    required this.activeDrugIds,
    required this.initialIntakeDrugId,
    required this.initialIntakeAt,
    required this.initialIntakeDoseNote,
    this.initialIntakeProductSelection,
    this.initialIntakeProduct,
  });

  UserProfile buildProfile(
    UserProfile baseProfile, {
    required String patientId,
    DateTime? consentRecordedAt,
  }) {
    final profile = baseProfile.copyWith(
      patientId: patientId,
      registrationRegion: registrationRegion,
      displayLocale: displayLocale,
      contentJurisdictionOverride: parseJurisdictionOverride(
        contentJurisdictionOverrideText,
      ),
      dietProfileRegion: dietProfileRegion ?? registrationRegion,
      swallowingTextureMode: swallowingTextureMode,
      localAiConsentEnabled: false,
    );
    return profile.withLocalAiConsentDecision(
      enabled: localAiConsentEnabled,
      recordedAt: consentRecordedAt ?? DateTime.now().toUtc(),
      source: 'onboarding',
    );
  }

  Intake? buildInitialIntake({required String intakeId, DrugDefinition? drug}) {
    final drugId = initialIntakeDrugId;
    final takenAt = initialIntakeAt;
    if (drugId == null || takenAt == null) return null;
    final intake = IntakeDoseContextBuilder()
        .build(
          id: intakeId,
          drugId: drugId,
          takenAt: takenAt,
          dosageNote: initialIntakeDoseNote.trim(),
          drug: drug,
        )
        .copyWith(productSelection: initialIntakeProductSelection);
    final product = initialIntakeProduct;
    final selection = initialIntakeProductSelection;
    return product != null &&
            selection != null &&
            selection.packId == product.id
        ? withProductFormulation(intake, product)
        : intake;
  }

  static List<String> parseJurisdictionOverride(String text) {
    final seen = <String>{};
    final values = <String>[];
    for (final raw in text.split(',')) {
      final normalized = raw.trim().toUpperCase();
      if (normalized.isEmpty || seen.contains(normalized)) continue;
      seen.add(normalized);
      values.add(normalized);
    }
    return values;
  }
}

String defaultLocaleForRegion(String regionCode, String currentLocale) {
  switch (regionCode) {
    case 'CN':
      return currentLocale.startsWith('zh') ? currentLocale : 'zh-CN';
    case 'CA':
      return currentLocale.startsWith('fr') ? currentLocale : 'en-CA';
    case 'FR':
      return 'fr-FR';
    case 'JP':
      return 'ja-JP';
    case 'KR':
      return 'ko-KR';
    case 'IN':
      return 'hi-IN';
    case 'ES':
      return 'es-ES';
    case 'MX':
      return 'es-MX';
    case 'VN':
      return 'vi-VN';
    case 'TH':
      return 'th-TH';
    case 'ID':
      return 'id-ID';
    case 'RU':
      return 'ru-RU';
    case 'PL':
      return 'pl-PL';
    case 'SA':
      return 'ar-SA';
    default:
      return currentLocale.startsWith('en') ? currentLocale : 'en-US';
  }
}
