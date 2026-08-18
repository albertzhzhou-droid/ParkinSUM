import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/purpose_bound_consent.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';

void main() {
  test('grant, clock rollback, and revoke use monotonic receipt sequence', () {
    final granted = UserProfile.defaults().withLocalAiConsentDecision(
      enabled: true,
      recordedAt: DateTime.utc(2026, 8, 18, 12),
      source: 'consent_center',
    );
    final revoked = granted.withLocalAiConsentDecision(
      enabled: false,
      recordedAt: DateTime.utc(2025, 1, 1),
      source: 'consent_center',
    );

    expect(granted.hasCurrentLocalAiConsent, isTrue);
    expect(revoked.hasCurrentLocalAiConsent, isFalse);
    expect(revoked.consentReceipts.map((receipt) => receipt.sequence), [1, 2]);
    expect(
      revoked.consentReceipts.last.recordedAtUtc,
      DateTime.utc(2025, 1, 1),
    );
    expect(revoked.localAiConsentEvaluation.reason, 'consent_revoked');
  });

  test('notice and receipt identities are deterministic and round-trip', () {
    final profile = UserProfile.defaults().withLocalAiConsentDecision(
      enabled: true,
      recordedAt: DateTime.utc(2026, 8, 18, 12),
      source: 'onboarding',
    );
    final restored = UserProfile.fromJson(profile.toJson());

    expect(LocalAiConsentNotice.sha256Digest, hasLength(64));
    expect(restored.hasCurrentLocalAiConsent, isTrue);
    expect(
      restored.consentReceipts.single.toJson(),
      profile.consentReceipts.single.toJson(),
    );
    expect(restored.toJson(), profile.toJson());
  });

  test('legacy boolean is preserved as review-needed but denied', () {
    final json = UserProfile.defaults().toJson()
      ..remove('consentReceipts')
      ..remove('consentReceiptLedgerBlocked')
      ..remove('legacyLocalAiConsentRequested')
      ..['localAiConsentEnabled'] = true;

    final restored = UserProfile.fromJson(json);

    expect(restored.localAiConsentEnabled, isFalse);
    expect(restored.hasCurrentLocalAiConsent, isFalse);
    expect(restored.legacyLocalAiConsentRequested, isTrue);
    expect(restored.localAiConsentEvaluation.reason, 'consent_receipt_missing');
  });

  test('tampered receipt blocks grant and explicit revoke repairs ledger', () {
    final granted = UserProfile.defaults().withLocalAiConsentDecision(
      enabled: true,
      recordedAt: DateTime.utc(2026, 8, 18),
      source: 'settings',
    );
    final json = Map<String, dynamic>.from(granted.toJson());
    final receipts = List<dynamic>.from(json['consentReceipts'] as List);
    final receipt = Map<String, dynamic>.from(receipts.single as Map);
    receipt['receiptId'] = List<String>.filled(64, '0').join();
    receipts[0] = receipt;
    json['consentReceipts'] = receipts;

    final blocked = UserProfile.fromJson(json);
    expect(
      blocked.localAiConsentEvaluation.status,
      PurposeBoundConsentStatus.blockedIntegrity,
    );
    expect(
      () => blocked.withLocalAiConsentDecision(
        enabled: true,
        recordedAt: DateTime.utc(2026, 8, 19),
        source: 'consent_center',
      ),
      throwsStateError,
    );

    final repaired = blocked.withLocalAiConsentDecision(
      enabled: false,
      recordedAt: DateTime.utc(2026, 8, 19),
      source: 'consent_center',
    );
    expect(repaired.consentReceiptLedgerBlocked, isFalse);
    expect(repaired.hasCurrentLocalAiConsent, isFalse);
    expect(repaired.consentReceipts.single.sequence, 1);
    expect(
      repaired.consentReceipts.single.decision,
      PurposeBoundConsentDecision.revoke,
    );
  });

  test('duplicate or missing sequence fails closed', () {
    final once = UserProfile.defaults().withLocalAiConsentDecision(
      enabled: true,
      recordedAt: DateTime.utc(2026, 8, 18),
      source: 'settings',
    );
    final second = PurposeBoundConsentReceipt.localAi(
      decision: PurposeBoundConsentDecision.revoke,
      sequence: 1,
      recordedAt: DateTime.utc(2026, 8, 19),
      source: 'settings',
    );

    final result = evaluateLocalAiConsent([
      once.consentReceipts.single,
      second,
    ]);

    expect(result.status, PurposeBoundConsentStatus.blockedIntegrity);
    expect(result.granted, isFalse);
  });
}
