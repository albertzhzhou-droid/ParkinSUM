import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../entities/knowledge_approval_envelope.dart';

/// One externally configured key and its authoritative subject/permissions.
/// Display names in documents have no effect on these grants. A key rotation
/// must retain the same subjectId when it represents the same person.
final class KnowledgeApprovalTrustedKey {
  KnowledgeApprovalTrustedKey({
    required this.keyId,
    required this.subjectId,
    required this.issuer,
    required this.environment,
    required List<int> publicKeyBytes,
    required Set<KnowledgeApprovalRole> roles,
    required Set<KnowledgeApprovalScope> scopes,
    required Set<String> packIds,
    required this.notBeforeUtc,
    required this.expiresAtUtc,
  }) : publicKeyBytes = List.unmodifiable(publicKeyBytes),
       roles = Set.unmodifiable(roles),
       scopes = Set.unmodifiable(scopes),
       packIds = Set.unmodifiable(packIds) {
    for (final id in [keyId, subjectId, issuer, environment, ...packIds]) {
      requireKnowledgeApprovalIdentifier(id);
    }
    requireKnowledgeApprovalUtc(notBeforeUtc);
    requireKnowledgeApprovalUtc(expiresAtUtc);
    if (publicKeyBytes.length != 32 ||
        publicKeyBytes.any((b) => b < 0 || b > 255) ||
        roles.isEmpty ||
        scopes.isEmpty ||
        packIds.isEmpty ||
        packIds.length > 128 ||
        !expiresAtUtc.isAfter(notBeforeUtc)) {
      throw const FormatException('knowledge_approval_trusted_key_invalid');
    }
  }

  final String keyId;
  final String subjectId;
  final String issuer;
  final String environment;
  final List<int> publicKeyBytes;
  final Set<KnowledgeApprovalRole> roles;
  final Set<KnowledgeApprovalScope> scopes;
  final Set<String> packIds;
  final DateTime notBeforeUtc;
  final DateTime expiresAtUtc;
}

/// No keys are shipped by this module. The application's separately controlled
/// authority registry must supply subject mappings, grants and revocations.
final class KnowledgeApprovalTrustPolicy {
  KnowledgeApprovalTrustPolicy({
    required this.issuer,
    required this.environment,
    required Map<String, KnowledgeApprovalTrustedKey> trustedKeys,
    Set<String> revokedKeyIds = const {},
    Set<String> revokedSubjectIds = const {},
    this.maximumApprovalLifetime = const Duration(days: 30),
  }) : trustedKeys = Map.unmodifiable(trustedKeys),
       revokedKeyIds = Set.unmodifiable(revokedKeyIds),
       revokedSubjectIds = Set.unmodifiable(revokedSubjectIds) {
    for (final id in [
      issuer,
      environment,
      ...revokedKeyIds,
      ...revokedSubjectIds,
    ]) {
      requireKnowledgeApprovalIdentifier(id);
    }
    if (trustedKeys.length > 512 ||
        revokedKeyIds.length > 4096 ||
        revokedSubjectIds.length > 4096 ||
        maximumApprovalLifetime <= Duration.zero) {
      throw const FormatException('knowledge_approval_trust_policy_invalid');
    }
    final publicKeys = <String>{};
    for (final entry in trustedKeys.entries) {
      if (entry.key != entry.value.keyId) {
        throw const FormatException('knowledge_approval_trust_key_id_mismatch');
      }
      final keyBytes = base64Encode(entry.value.publicKeyBytes);
      // Key-ID aliases could otherwise bypass a revoked key ID, or let the
      // same key masquerade as two independent review subjects.
      if (!publicKeys.add(keyBytes)) {
        throw const FormatException('knowledge_approval_duplicate_public_key');
      }
    }
  }

  final String issuer;
  final String environment;
  final Map<String, KnowledgeApprovalTrustedKey> trustedKeys;
  final Set<String> revokedKeyIds;
  final Set<String> revokedSubjectIds;
  final Duration maximumApprovalLifetime;
  bool get isConfigured => trustedKeys.isNotEmpty;
}

enum KnowledgeApprovalVerificationStatus {
  verified,
  malformed,
  unconfiguredTrust,
  untrustedKey,
  revokedKey,
  revokedSubject,
  wrongIssuer,
  wrongEnvironment,
  subjectMismatch,
  unauthorizedRole,
  unauthorizedScope,
  invalidSignature,
  notYetValid,
  expired,
  keyExpired,
  keyNotValidAtSigning,
  lifetimeExceeded,
  bindingMismatch,
  decisionMismatch,
  invalidClock,
  authorProofRequired,
  authorProofInvalid,
  authorMismatch,
  selfReview,
}

/// A signature/authorization result only. Clinical validity, successful suite
/// execution, all-rule coverage and state transitions remain the lifecycle
/// service's responsibility. Callers cannot fabricate a verified constructor.
final class KnowledgeApprovalVerification {
  const KnowledgeApprovalVerification._({
    required this.status,
    required this.reason,
    this.envelope,
    this.subjectId,
  });

  final KnowledgeApprovalVerificationStatus status;
  final String reason;
  final KnowledgeApprovalEnvelope? envelope;
  final String? subjectId;
  bool get isVerified =>
      status == KnowledgeApprovalVerificationStatus.verified &&
      envelope != null &&
      subjectId != null;
}

final class KnowledgeApprovalVerifier {
  KnowledgeApprovalVerifier({required this.trustPolicy});

  final KnowledgeApprovalTrustPolicy trustPolicy;
  final Ed25519 _algorithm = Ed25519();

  Future<KnowledgeApprovalVerification> verifyJson(
    String raw, {
    required KnowledgeApprovalBinding expectedBinding,
    required KnowledgeApprovalRole expectedRole,
    required KnowledgeApprovalDecision expectedDecision,
    required DateTime nowUtc,
    KnowledgeApprovalEnvelope? authorEnvelope,
  }) async {
    final KnowledgeApprovalEnvelope envelope;
    try {
      envelope = KnowledgeApprovalEnvelope.parseJson(raw);
    } catch (_) {
      return _failure(
        KnowledgeApprovalVerificationStatus.malformed,
        'approval_envelope_malformed',
      );
    }
    return verify(
      envelope,
      expectedBinding: expectedBinding,
      expectedRole: expectedRole,
      expectedDecision: expectedDecision,
      nowUtc: nowUtc,
      authorEnvelope: authorEnvelope,
    );
  }

  Future<KnowledgeApprovalVerification> verify(
    KnowledgeApprovalEnvelope envelope, {
    required KnowledgeApprovalBinding expectedBinding,
    required KnowledgeApprovalRole expectedRole,
    required KnowledgeApprovalDecision expectedDecision,
    required DateTime nowUtc,
    KnowledgeApprovalEnvelope? authorEnvelope,
  }) async {
    final result = await _verifySignature(
      envelope,
      expectedBinding: expectedBinding,
      expectedRole: expectedRole,
      expectedDecision: expectedDecision,
      nowUtc: nowUtc,
    );
    if (!result.isVerified || expectedRole == KnowledgeApprovalRole.author) {
      return result;
    }
    if (authorEnvelope == null) {
      return _failure(
        KnowledgeApprovalVerificationStatus.authorProofRequired,
        'signed_authorship_required',
        envelope,
      );
    }
    final author = authorEnvelope.statement;
    if (!author.binding.sameArtifact(expectedBinding) ||
        author.subjectId != envelope.statement.authorSubjectId ||
        author.issuedAtUtc.isAfter(envelope.statement.issuedAtUtc)) {
      return _failure(
        KnowledgeApprovalVerificationStatus.authorMismatch,
        'authorship_does_not_bind_this_approval',
        envelope,
      );
    }
    // Recheck the actual signature under today's trust/revocation/expiry policy.
    // Its historical chain acceptance must additionally be replayed by the
    // lifecycle service; using its binding here proves authorship only.
    final verifiedAuthor = await _verifySignature(
      authorEnvelope,
      expectedBinding: author.binding,
      expectedRole: KnowledgeApprovalRole.author,
      expectedDecision: KnowledgeApprovalDecision.authored,
      nowUtc: nowUtc,
    );
    if (!verifiedAuthor.isVerified) {
      return _failure(
        KnowledgeApprovalVerificationStatus.authorProofInvalid,
        'authorship_${verifiedAuthor.reason}',
        envelope,
      );
    }
    if (expectedRole == KnowledgeApprovalRole.reviewer &&
        verifiedAuthor.subjectId == result.subjectId) {
      return _failure(
        KnowledgeApprovalVerificationStatus.selfReview,
        'author_and_reviewer_must_be_distinct_subjects',
        envelope,
      );
    }
    return result;
  }

  Future<KnowledgeApprovalVerification> _verifySignature(
    KnowledgeApprovalEnvelope envelope, {
    required KnowledgeApprovalBinding expectedBinding,
    required KnowledgeApprovalRole expectedRole,
    required KnowledgeApprovalDecision expectedDecision,
    required DateTime nowUtc,
  }) async {
    if (!nowUtc.isUtc || nowUtc.year < 1 || nowUtc.year > 9999) {
      return _failure(
        KnowledgeApprovalVerificationStatus.invalidClock,
        'verification_clock_not_canonical_utc',
        envelope,
      );
    }
    if (!trustPolicy.isConfigured) {
      return _failure(
        KnowledgeApprovalVerificationStatus.unconfiguredTrust,
        'trusted_authority_registry_not_configured',
        envelope,
      );
    }
    final statement = envelope.statement;
    if (!statement.binding.matches(expectedBinding)) {
      return _failure(
        KnowledgeApprovalVerificationStatus.bindingMismatch,
        'artifact_or_chain_binding_mismatch',
        envelope,
      );
    }
    if (statement.role != expectedRole) {
      return _failure(
        KnowledgeApprovalVerificationStatus.unauthorizedRole,
        'unexpected_approval_role',
        envelope,
      );
    }
    if (statement.decision != expectedDecision) {
      return _failure(
        KnowledgeApprovalVerificationStatus.decisionMismatch,
        'unexpected_approval_decision',
        envelope,
      );
    }
    final key = trustPolicy.trustedKeys[statement.keyId];
    if (key == null) {
      return _failure(
        KnowledgeApprovalVerificationStatus.untrustedKey,
        'key_not_in_trusted_registry',
        envelope,
      );
    }
    if (statement.issuer != trustPolicy.issuer ||
        statement.issuer != key.issuer) {
      return _failure(
        KnowledgeApprovalVerificationStatus.wrongIssuer,
        'issuer_not_authorized_for_key',
        envelope,
      );
    }
    if (statement.environment != trustPolicy.environment ||
        statement.environment != key.environment) {
      return _failure(
        KnowledgeApprovalVerificationStatus.wrongEnvironment,
        'environment_not_authorized_for_key',
        envelope,
      );
    }
    if (statement.subjectId != key.subjectId) {
      return _failure(
        KnowledgeApprovalVerificationStatus.subjectMismatch,
        'claimed_subject_does_not_match_key',
        envelope,
      );
    }
    if (trustPolicy.revokedKeyIds.contains(key.keyId)) {
      return _failure(
        KnowledgeApprovalVerificationStatus.revokedKey,
        'key_revoked',
        envelope,
      );
    }
    if (trustPolicy.revokedSubjectIds.contains(key.subjectId)) {
      return _failure(
        KnowledgeApprovalVerificationStatus.revokedSubject,
        'subject_revoked',
        envelope,
      );
    }
    if (!key.roles.contains(statement.role)) {
      return _failure(
        KnowledgeApprovalVerificationStatus.unauthorizedRole,
        'role_not_authorized_for_key',
        envelope,
      );
    }
    if (!key.scopes.contains(statement.scope) ||
        !key.packIds.contains(statement.binding.packId)) {
      return _failure(
        KnowledgeApprovalVerificationStatus.unauthorizedScope,
        'scope_or_pack_not_authorized_for_key',
        envelope,
      );
    }
    if (nowUtc.isBefore(key.notBeforeUtc) ||
        nowUtc.isBefore(statement.notBeforeUtc)) {
      return _failure(
        KnowledgeApprovalVerificationStatus.notYetValid,
        'approval_or_key_not_yet_valid',
        envelope,
      );
    }
    if (!nowUtc.isBefore(key.expiresAtUtc)) {
      return _failure(
        KnowledgeApprovalVerificationStatus.keyExpired,
        'signing_key_expired',
        envelope,
      );
    }
    if (statement.issuedAtUtc.isBefore(key.notBeforeUtc) ||
        !statement.issuedAtUtc.isBefore(key.expiresAtUtc)) {
      return _failure(
        KnowledgeApprovalVerificationStatus.keyNotValidAtSigning,
        'key_not_valid_at_claimed_signing_time',
        envelope,
      );
    }
    if (!nowUtc.isBefore(statement.expiresAtUtc)) {
      return _failure(
        KnowledgeApprovalVerificationStatus.expired,
        'approval_expired',
        envelope,
      );
    }
    if (statement.expiresAtUtc.difference(statement.issuedAtUtc) >
        trustPolicy.maximumApprovalLifetime) {
      return _failure(
        KnowledgeApprovalVerificationStatus.lifetimeExceeded,
        'approval_lifetime_exceeded',
        envelope,
      );
    }
    final bool valid;
    try {
      valid = await _algorithm.verify(
        utf8.encode(statement.canonicalJson),
        signature: Signature(
          envelope.signatureBytes,
          publicKey: SimplePublicKey(
            key.publicKeyBytes,
            type: KeyPairType.ed25519,
          ),
        ),
      );
    } catch (_) {
      return _failure(
        KnowledgeApprovalVerificationStatus.invalidSignature,
        'signature_verification_failed',
        envelope,
      );
    }
    if (!valid) {
      return _failure(
        KnowledgeApprovalVerificationStatus.invalidSignature,
        'signature_verification_failed',
        envelope,
      );
    }
    return KnowledgeApprovalVerification._(
      status: KnowledgeApprovalVerificationStatus.verified,
      reason: 'verified',
      envelope: envelope,
      subjectId: key.subjectId,
    );
  }
}

KnowledgeApprovalVerification _failure(
  KnowledgeApprovalVerificationStatus status,
  String reason, [
  KnowledgeApprovalEnvelope? envelope,
]) => KnowledgeApprovalVerification._(
  status: status,
  reason: reason,
  envelope: envelope,
);
