import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/knowledge_approval_envelope.dart';
import 'package:parkinsum_companion/domain/usecases/knowledge_approval_verifier.dart';

// Deterministic private seeds are test fixtures only. No trust roots or signing
// material are included in production code or used to claim clinical approval.
void main() {
  final algorithm = Ed25519();
  final now = DateTime.utc(2026, 9, 22, 12);
  late Map<String, SimpleKeyPair> pairs;
  late Map<String, KnowledgeApprovalTrustedKey> keys;
  late KnowledgeApprovalEnvelope author;
  late KnowledgeApprovalEnvelope review;

  String digest(String value) => value * 64;
  KnowledgeApprovalBinding binding({
    int sequence = 1,
    String? previous,
    bool perRule = false,
    String? packDigest,
    String packId = 'pack-a',
  }) => KnowledgeApprovalBinding(
    packId: packId,
    packVersion: '1',
    packDigest: packDigest ?? digest('a'),
    engineDigest: digest('b'),
    suiteDigest: digest('c'),
    sequence: sequence,
    previousEnvelopeDigest: previous,
    ruleId: perRule ? 'rule-a' : null,
    ruleVersion: perRule ? '1' : null,
  );

  KnowledgeApprovalStatement statement({
    required KnowledgeApprovalBinding binding,
    String keyId = 'author-key',
    String subject = 'subject-author',
    String authorSubject = 'subject-author',
    KnowledgeApprovalRole role = KnowledgeApprovalRole.author,
    KnowledgeApprovalDecision decision = KnowledgeApprovalDecision.authored,
    String issuer = 'test-authority',
    String environment = 'test',
    DateTime? issued,
    DateTime? notBefore,
    DateTime? expires,
  }) => KnowledgeApprovalStatement(
    approvalId: 'approval-${binding.sequence}',
    issuer: issuer,
    environment: environment,
    keyId: keyId,
    subjectId: subject,
    authorSubjectId: authorSubject,
    role: role,
    decision: decision,
    binding: binding,
    issuedAtUtc: issued ?? now.subtract(const Duration(minutes: 10)),
    notBeforeUtc:
        notBefore ?? issued ?? now.subtract(const Duration(minutes: 10)),
    expiresAtUtc: expires ?? now.add(const Duration(days: 1)),
  );

  Future<KnowledgeApprovalEnvelope> sign(
    KnowledgeApprovalStatement value, {
    String? signingKey,
  }) async {
    final signature = await algorithm.sign(
      utf8.encode(value.canonicalJson),
      keyPair: pairs[signingKey ?? value.keyId]!,
    );
    return KnowledgeApprovalEnvelope(
      statement: value,
      signatureBase64Url: base64Url.encode(signature.bytes).replaceAll('=', ''),
    );
  }

  KnowledgeApprovalTrustPolicy policy({
    Map<String, KnowledgeApprovalTrustedKey>? trustedKeys,
    Set<String> revokedKeys = const {},
    Set<String> revokedSubjects = const {},
    Duration maximumLifetime = const Duration(days: 30),
  }) => KnowledgeApprovalTrustPolicy(
    issuer: 'test-authority',
    environment: 'test',
    trustedKeys: trustedKeys ?? keys,
    revokedKeyIds: revokedKeys,
    revokedSubjectIds: revokedSubjects,
    maximumApprovalLifetime: maximumLifetime,
  );

  Future<KnowledgeApprovalVerification> verify(
    KnowledgeApprovalEnvelope value, {
    KnowledgeApprovalTrustPolicy? trust,
    KnowledgeApprovalBinding? expectedBinding,
    KnowledgeApprovalRole? expectedRole,
    KnowledgeApprovalDecision? expectedDecision,
    DateTime? at,
    KnowledgeApprovalEnvelope? authorProof,
    bool includeAuthor = true,
  }) => KnowledgeApprovalVerifier(trustPolicy: trust ?? policy()).verify(
    value,
    expectedBinding: expectedBinding ?? value.statement.binding,
    expectedRole: expectedRole ?? value.statement.role,
    expectedDecision: expectedDecision ?? value.statement.decision,
    nowUtc: at ?? now,
    authorEnvelope: includeAuthor ? (authorProof ?? author) : null,
  );

  KnowledgeApprovalTrustedKey grant(
    KnowledgeApprovalTrustedKey key, {
    String? subject,
    String? issuer,
    String? environment,
    Set<KnowledgeApprovalRole>? roles,
    Set<KnowledgeApprovalScope>? scopes,
    Set<String>? packs,
    DateTime? notBefore,
    DateTime? expires,
  }) => KnowledgeApprovalTrustedKey(
    keyId: key.keyId,
    subjectId: subject ?? key.subjectId,
    issuer: issuer ?? key.issuer,
    environment: environment ?? key.environment,
    publicKeyBytes: key.publicKeyBytes,
    roles: roles ?? key.roles,
    scopes: scopes ?? key.scopes,
    packIds: packs ?? key.packIds,
    notBeforeUtc: notBefore ?? key.notBeforeUtc,
    expiresAtUtc: expires ?? key.expiresAtUtc,
  );

  setUpAll(() async {
    pairs = {};
    keys = {};
    final grants = [
      (
        'author-key',
        'subject-author',
        KnowledgeApprovalRole.author,
        KnowledgeApprovalScope.pack,
      ),
      (
        'reviewer-key',
        'subject-reviewer',
        KnowledgeApprovalRole.reviewer,
        KnowledgeApprovalScope.rule,
      ),
      (
        'publisher-key',
        'subject-publisher',
        KnowledgeApprovalRole.publisher,
        KnowledgeApprovalScope.pack,
      ),
      (
        'author-review-key',
        'subject-author',
        KnowledgeApprovalRole.reviewer,
        KnowledgeApprovalScope.rule,
      ),
    ];
    for (var index = 0; index < grants.length; index++) {
      final entry = grants[index];
      final pair = await algorithm.newKeyPairFromSeed(
        List.filled(32, index + 1),
      );
      pairs[entry.$1] = pair;
      keys[entry.$1] = KnowledgeApprovalTrustedKey(
        keyId: entry.$1,
        subjectId: entry.$2,
        issuer: 'test-authority',
        environment: 'test',
        publicKeyBytes: (await pair.extractPublicKey()).bytes,
        roles: {entry.$3},
        scopes: {entry.$4},
        packIds: {'pack-a'},
        notBeforeUtc: now.subtract(const Duration(days: 2)),
        expiresAtUtc: now.add(const Duration(days: 90)),
      );
    }
    pairs['untrusted-key'] = await algorithm.newKeyPairFromSeed(
      List.filled(32, 99),
    );
    author = await sign(statement(binding: binding()));
    review = await sign(
      statement(
        binding: binding(sequence: 2, previous: author.sha256, perRule: true),
        keyId: 'reviewer-key',
        subject: 'subject-reviewer',
        role: KnowledgeApprovalRole.reviewer,
        decision: KnowledgeApprovalDecision.approved,
        issued: now.subtract(const Duration(minutes: 5)),
      ),
    );
  });

  test(
    'actual independent Ed25519 authorship and per-rule review verify',
    () async {
      final authorship = await verify(author, includeAuthor: false);
      expect(authorship.isVerified, isTrue);
      expect(authorship.subjectId, 'subject-author');
      final reviewed = await verify(review);
      expect(reviewed.isVerified, isTrue);
      expect(reviewed.subjectId, 'subject-reviewer');
      expect(reviewed.envelope!.sha256, review.sha256);
    },
  );

  test(
    'publisher grants are separate and published cannot satisfy withdrawn intent',
    () async {
      final publish = await sign(
        statement(
          binding: binding(sequence: 3, previous: review.sha256),
          keyId: 'publisher-key',
          subject: 'subject-publisher',
          role: KnowledgeApprovalRole.publisher,
          decision: KnowledgeApprovalDecision.published,
        ),
      );
      expect((await verify(publish)).isVerified, isTrue);
      expect(
        (await verify(
          publish,
          expectedDecision: KnowledgeApprovalDecision.withdrawn,
        )).status,
        KnowledgeApprovalVerificationStatus.decisionMismatch,
      );
      final withdraw = await sign(
        statement(
          binding: binding(sequence: 4, previous: publish.sha256),
          keyId: 'publisher-key',
          subject: 'subject-publisher',
          role: KnowledgeApprovalRole.publisher,
          decision: KnowledgeApprovalDecision.withdrawn,
        ),
      );
      expect((await verify(withdraw)).isVerified, isTrue);
    },
  );

  test(
    'the same person cannot review their authorship using another trusted key',
    () async {
      final selfReview = await sign(
        statement(
          binding: review.statement.binding,
          keyId: 'author-review-key',
          subject: 'subject-author',
          role: KnowledgeApprovalRole.reviewer,
          decision: KnowledgeApprovalDecision.approved,
        ),
      );
      final result = await verify(selfReview);
      expect(result.status, KnowledgeApprovalVerificationStatus.selfReview);
      expect(result.isVerified, isFalse);
      expect(result.subjectId, isNull);
    },
  );

  test(
    'a claimed different subject cannot override the trusted key mapping',
    () async {
      final disguised = await sign(
        statement(
          binding: review.statement.binding,
          keyId: 'author-review-key',
          subject: 'different-person',
          role: KnowledgeApprovalRole.reviewer,
          decision: KnowledgeApprovalDecision.approved,
        ),
      );
      expect(
        (await verify(disguised)).status,
        KnowledgeApprovalVerificationStatus.subjectMismatch,
      );
    },
  );

  test(
    'no trust roots, unknown keys and name-only or unsigned records never authorize',
    () async {
      expect(
        (await verify(author, trust: policy(trustedKeys: {}))).status,
        KnowledgeApprovalVerificationStatus.unconfiguredTrust,
      );
      final unknown = await sign(
        statement(binding: binding(), keyId: 'untrusted-key'),
      );
      expect(
        (await verify(unknown)).status,
        KnowledgeApprovalVerificationStatus.untrustedKey,
      );
      final verifier = KnowledgeApprovalVerifier(trustPolicy: policy());
      for (final raw in [
        '{}',
        '{"reviewer_name":"Dr Test","approved":true}',
        jsonEncode({'signed': author.statement.toJson()}),
      ]) {
        final result = await verifier.verifyJson(
          raw,
          expectedBinding: binding(),
          expectedRole: KnowledgeApprovalRole.author,
          expectedDecision: KnowledgeApprovalDecision.authored,
          nowUtc: now,
        );
        expect(result.status, KnowledgeApprovalVerificationStatus.malformed);
        expect(result.isVerified, isFalse);
      }
    },
  );

  test(
    'valid signatures cannot cross issuer, environment, role or exact pack/scope grants',
    () async {
      for (final (field, replacement, expected) in [
        (
          'issuer',
          'different-authority',
          KnowledgeApprovalVerificationStatus.wrongIssuer,
        ),
        (
          'environment',
          'production',
          KnowledgeApprovalVerificationStatus.wrongEnvironment,
        ),
      ]) {
        final json = author.statement.toJson()..[field] = replacement;
        final changed = await sign(KnowledgeApprovalStatement.fromJson(json));
        expect((await verify(changed)).status, expected);
      }
      final key = keys['reviewer-key']!;
      for (final (changed, expected) in [
        (
          grant(key, roles: {KnowledgeApprovalRole.author}),
          KnowledgeApprovalVerificationStatus.unauthorizedRole,
        ),
        (
          grant(key, scopes: {KnowledgeApprovalScope.pack}),
          KnowledgeApprovalVerificationStatus.unauthorizedScope,
        ),
        (
          grant(key, packs: {'pack-b'}),
          KnowledgeApprovalVerificationStatus.unauthorizedScope,
        ),
        (
          grant(key, issuer: 'different-authority'),
          KnowledgeApprovalVerificationStatus.wrongIssuer,
        ),
        (
          grant(key, environment: 'production'),
          KnowledgeApprovalVerificationStatus.wrongEnvironment,
        ),
      ]) {
        expect(
          (await verify(
            review,
            trust: policy(trustedKeys: {...keys, key.keyId: changed}),
          )).status,
          expected,
        );
      }
      expect(
        (await verify(
          review,
          expectedRole: KnowledgeApprovalRole.publisher,
        )).status,
        KnowledgeApprovalVerificationStatus.unauthorizedRole,
      );
    },
  );

  test(
    'content, rule, suite, engine, sequence and predecessor must match the caller ledger',
    () async {
      final mutations = {
        'pack_digest': digest('d'),
        'engine_digest': digest('d'),
        'suite_digest': digest('d'),
        'rule_id': 'other-rule',
        'rule_version': '2',
        'sequence': 3,
        'previous_envelope_digest': digest('d'),
      };
      for (final entry in mutations.entries) {
        final expected = KnowledgeApprovalBinding.fromJson({
          ...review.statement.binding.toJson(),
          entry.key: entry.value,
        });
        expect(
          (await verify(review, expectedBinding: expected)).status,
          KnowledgeApprovalVerificationStatus.bindingMismatch,
          reason: entry.key,
        );
      }
    },
  );

  test(
    'tampering a signed field or substituting an attacker signature fails verification',
    () async {
      final modified = KnowledgeApprovalStatement.fromJson({
        ...review.statement.toJson(),
        'reason': 'Changed after signing',
      });
      expect(
        (await verify(
          KnowledgeApprovalEnvelope(
            statement: modified,
            signatureBase64Url: review.signatureBase64Url,
          ),
        )).status,
        KnowledgeApprovalVerificationStatus.invalidSignature,
      );
      expect(
        (await verify(
          await sign(review.statement, signingKey: 'untrusted-key'),
        )).status,
        KnowledgeApprovalVerificationStatus.invalidSignature,
      );
    },
  );

  test(
    'revocation is reevaluated for keys and subjects without trusting old successful results',
    () async {
      expect((await verify(review)).isVerified, isTrue);
      expect(
        (await verify(
          review,
          trust: policy(revokedKeys: {'reviewer-key'}),
        )).status,
        KnowledgeApprovalVerificationStatus.revokedKey,
      );
      expect(
        (await verify(
          review,
          trust: policy(revokedSubjects: {'subject-reviewer'}),
        )).status,
        KnowledgeApprovalVerificationStatus.revokedSubject,
      );
      final expiredAuthor = await verify(
        review,
        trust: policy(revokedKeys: {'author-key'}),
      );
      expect(
        expiredAuthor.status,
        KnowledgeApprovalVerificationStatus.authorProofInvalid,
      );
      expect(expiredAuthor.reason, 'authorship_key_revoked');
    },
  );

  test(
    'missing, forged or differently bound signed authorship cannot support a review',
    () async {
      expect(
        (await verify(review, includeAuthor: false)).status,
        KnowledgeApprovalVerificationStatus.authorProofRequired,
      );
      final forgedAuthor = await sign(
        author.statement,
        signingKey: 'untrusted-key',
      );
      expect(
        (await verify(review, authorProof: forgedAuthor)).status,
        KnowledgeApprovalVerificationStatus.authorProofInvalid,
      );
      final otherArtifact = await sign(
        statement(binding: binding(packDigest: digest('d'))),
      );
      expect(
        (await verify(review, authorProof: otherArtifact)).status,
        KnowledgeApprovalVerificationStatus.authorMismatch,
      );
      final claimed = await sign(
        statement(
          binding: review.statement.binding,
          keyId: 'reviewer-key',
          subject: 'subject-reviewer',
          authorSubject: 'another-author',
          role: KnowledgeApprovalRole.reviewer,
          decision: KnowledgeApprovalDecision.approved,
        ),
      );
      expect(
        (await verify(claimed)).status,
        KnowledgeApprovalVerificationStatus.authorMismatch,
      );
    },
  );

  test(
    'expired authorship is rechecked and an author signing later cannot justify an earlier review',
    () async {
      final expired = await sign(
        statement(
          binding: binding(),
          issued: now.subtract(const Duration(days: 1)),
          expires: now.subtract(const Duration(seconds: 1)),
        ),
      );
      final result = await verify(review, authorProof: expired);
      expect(
        result.status,
        KnowledgeApprovalVerificationStatus.authorProofInvalid,
      );
      expect(result.reason, 'authorship_approval_expired');
      final later = await sign(
        statement(
          binding: binding(),
          issued: now.subtract(const Duration(minutes: 1)),
        ),
      );
      expect(
        (await verify(review, authorProof: later)).status,
        KnowledgeApprovalVerificationStatus.authorMismatch,
      );
    },
  );

  test(
    'time windows, exact expiry, key lifetime, signing validity and UTC clock fail closed',
    () async {
      final future = await sign(
        statement(
          binding: binding(),
          issued: now.add(const Duration(seconds: 1)),
        ),
      );
      expect(
        (await verify(future)).status,
        KnowledgeApprovalVerificationStatus.notYetValid,
      );
      expect(
        (await verify(author, at: author.statement.expiresAtUtc)).status,
        KnowledgeApprovalVerificationStatus.expired,
      );
      expect(
        (await verify(
          author,
          trust: policy(maximumLifetime: const Duration(hours: 1)),
        )).status,
        KnowledgeApprovalVerificationStatus.lifetimeExceeded,
      );
      expect(
        (await verify(author, at: DateTime(2026, 9, 22))).status,
        KnowledgeApprovalVerificationStatus.invalidClock,
      );
      final original = keys['author-key']!;
      final expired = grant(original, expires: now);
      expect(
        (await verify(
          author,
          trust: policy(trustedKeys: {...keys, original.keyId: expired}),
        )).status,
        KnowledgeApprovalVerificationStatus.keyExpired,
      );
      final notSigning = grant(
        original,
        notBefore: now.subtract(const Duration(minutes: 1)),
      );
      expect(
        (await verify(
          author,
          trust: policy(trustedKeys: {...keys, original.keyId: notSigning}),
        )).status,
        KnowledgeApprovalVerificationStatus.keyNotValidAtSigning,
      );
      final futureKey = grant(
        original,
        notBefore: now.add(const Duration(minutes: 1)),
      );
      expect(
        (await verify(
          author,
          trust: policy(trustedKeys: {...keys, original.keyId: futureKey}),
        )).status,
        KnowledgeApprovalVerificationStatus.notYetValid,
      );
    },
  );

  test(
    'one public key cannot impersonate two independently trusted subjects',
    () {
      final reviewer = keys['reviewer-key']!;
      final alias = KnowledgeApprovalTrustedKey(
        keyId: 'reviewer-alias',
        subjectId: 'other-subject',
        issuer: reviewer.issuer,
        environment: reviewer.environment,
        publicKeyBytes: reviewer.publicKeyBytes,
        roles: reviewer.roles,
        scopes: reviewer.scopes,
        packIds: reviewer.packIds,
        notBeforeUtc: reviewer.notBeforeUtc,
        expiresAtUtc: reviewer.expiresAtUtc,
      );
      expect(
        () => policy(trustedKeys: {...keys, alias.keyId: alias}),
        throwsFormatException,
      );
      expect(
        () => policy(trustedKeys: {'wrong-map-key': reviewer}),
        throwsFormatException,
      );
    },
  );

  test(
    'trust configuration is immutable and does not import keys from the approval document',
    () {
      final mutableKeys = Map.of(keys);
      final revoked = <String>{};
      final trust = policy(trustedKeys: mutableKeys, revokedKeys: revoked);
      mutableKeys.clear();
      revoked.add('author-key');
      expect(trust.trustedKeys, hasLength(4));
      expect(trust.revokedKeyIds, isEmpty);
      expect(() => trust.trustedKeys.clear(), throwsUnsupportedError);
      expect(
        () => trust.trustedKeys['author-key']!.publicKeyBytes[0] = 1,
        throwsUnsupportedError,
      );
      expect(
        () => trust.trustedKeys['author-key']!.roles.clear(),
        throwsUnsupportedError,
      );
    },
  );

  test('a same-subject public-key alias cannot bypass key-ID revocation', () {
    final original = keys['author-key']!;
    final alias = KnowledgeApprovalTrustedKey(
      keyId: 'author-alias',
      subjectId: original.subjectId,
      issuer: original.issuer,
      environment: original.environment,
      publicKeyBytes: original.publicKeyBytes,
      roles: original.roles,
      scopes: original.scopes,
      packIds: original.packIds,
      notBeforeUtc: original.notBeforeUtc,
      expiresAtUtc: original.expiresAtUtc,
    );
    expect(
      () => policy(
        trustedKeys: {...keys, alias.keyId: alias},
        revokedKeys: {'author-key'},
      ),
      throwsFormatException,
    );
  });

  test('a signed rejection is never counted as an approval', () async {
    final rejection = await sign(
      statement(
        binding: review.statement.binding,
        keyId: 'reviewer-key',
        subject: 'subject-reviewer',
        role: KnowledgeApprovalRole.reviewer,
        decision: KnowledgeApprovalDecision.rejected,
      ),
    );
    expect(
      (await verify(
        rejection,
        expectedDecision: KnowledgeApprovalDecision.approved,
      )).status,
      KnowledgeApprovalVerificationStatus.decisionMismatch,
    );
    expect((await verify(rejection)).isVerified, isTrue);
  });
}
