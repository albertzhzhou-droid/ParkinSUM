import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/features/onboarding/onboarding_flow.dart';

void main() {
  test('normalizes content jurisdiction overrides', () {
    expect(
      OnboardingDraft.parseJurisdictionOverride(' us, ca,US, cn ,, '),
      ['US', 'CA', 'CN'],
    );
  });

  test('builds profile from onboarding selections without dropping AI settings',
      () {
    final base = UserProfile.defaults().copyWith(
      localAiProviderPreference: 'ollama',
      localAiModel: 'custom-model',
      localAiTimeoutMs: 5000,
    );
    const draft = OnboardingDraft(
      registrationRegion: 'CA',
      displayLocale: 'fr-CA',
      dietProfileRegion: 'US',
      swallowingTextureMode: 'soft_or_liquid',
      localAiConsentEnabled: true,
      contentJurisdictionOverrideText: 'ca, us',
      activeDrugIds: ['drug_levodopa_carbidopa'],
      initialIntakeDrugId: null,
      initialIntakeAt: null,
      initialIntakeDoseNote: '',
    );

    final profile = draft.buildProfile(base, patientId: 'uid_123');

    expect(profile.patientId, 'uid_123');
    expect(profile.registrationRegion, 'CA');
    expect(profile.displayLocale, 'fr-CA');
    expect(profile.dietProfileRegion, 'US');
    expect(profile.swallowingTextureMode, 'soft_or_liquid');
    expect(profile.localAiConsentEnabled, isTrue);
    expect(profile.contentJurisdictionOverride, ['CA', 'US']);
    expect(profile.localAiProviderPreference, 'ollama');
    expect(profile.localAiModel, 'custom-model');
    expect(profile.localAiTimeoutMs, 5000);
  });

  test('builds optional initial intake only when drug and time are present',
      () {
    final takenAt = DateTime.utc(2026, 5, 13, 14, 30);
    final draft = OnboardingDraft(
      registrationRegion: 'US',
      displayLocale: 'en-US',
      dietProfileRegion: 'US',
      swallowingTextureMode: 'unrestricted',
      localAiConsentEnabled: false,
      contentJurisdictionOverrideText: '',
      activeDrugIds: ['drug_levodopa_carbidopa'],
      initialIntakeDrugId: 'drug_levodopa_carbidopa',
      initialIntakeAt: takenAt,
      initialIntakeDoseNote: '100/25 mg',
    );

    final intake = draft.buildInitialIntake(intakeId: 'intake_1');

    expect(intake, isNotNull);
    expect(intake!.id, 'intake_1');
    expect(intake.drugId, 'drug_levodopa_carbidopa');
    expect(intake.takenAt, takenAt);
    expect(intake.dosageNote, '100/25 mg');

    const withoutTime = OnboardingDraft(
      registrationRegion: 'US',
      displayLocale: 'en-US',
      dietProfileRegion: 'US',
      swallowingTextureMode: 'unrestricted',
      localAiConsentEnabled: false,
      contentJurisdictionOverrideText: '',
      activeDrugIds: ['drug_levodopa_carbidopa'],
      initialIntakeDrugId: 'drug_levodopa_carbidopa',
      initialIntakeAt: null,
      initialIntakeDoseNote: 'ignored',
    );

    expect(withoutTime.buildInitialIntake(intakeId: 'intake_2'), isNull);
  });

  test('chooses regional default locales conservatively', () {
    expect(defaultLocaleForRegion('CN', 'en-US'), 'zh-CN');
    expect(defaultLocaleForRegion('CA', 'en-US'), 'en-CA');
    expect(defaultLocaleForRegion('CA', 'fr-CA'), 'fr-CA');
    expect(defaultLocaleForRegion('JP', 'en-US'), 'ja-JP');
    expect(defaultLocaleForRegion('US', 'zh-CN'), 'en-US');
  });
}
