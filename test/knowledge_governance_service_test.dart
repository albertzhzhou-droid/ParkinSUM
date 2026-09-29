import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/knowledge_approval_envelope.dart';
import 'package:parkinsum_companion/domain/entities/knowledge_governance_state.dart';
import 'package:parkinsum_companion/domain/entities/knowledge_pack.dart';
import 'package:parkinsum_companion/domain/entities/rule_test_case.dart';
import 'package:parkinsum_companion/domain/usecases/knowledge_approval_verifier.dart';
import 'package:parkinsum_companion/domain/usecases/knowledge_governance_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'knowledge_pack_test.dart' show createKnowledgeTestPack;

final _now = DateTime.utc(2026, 9, 22, 12);
final _algorithm = Ed25519();
final _pairs = <String, SimpleKeyPair>{};
final _keys = <String, KnowledgeApprovalTrustedKey>{};

KnowledgeApprovalVerifier _verifier({
  Set<String> revoked = const {},
  bool empty = false,
}) => KnowledgeApprovalVerifier(
  trustPolicy: KnowledgeApprovalTrustPolicy(
    issuer: 'test-authority',
    environment: 'synthetic-tests',
    trustedKeys: empty ? {} : _keys,
    revokedKeyIds: revoked,
  ),
);

// Signing keys are deterministic test-only fixtures, never application roots.
class _Harness {
  _Harness({
    KnowledgePack? pack,
    MemoryKnowledgeGovernanceStore? store,
    KnowledgeApprovalVerifier? verifier,
  }) : pack = pack ?? createKnowledgeTestPack(),
       store = store ?? MemoryKnowledgeGovernanceStore() {
    service = KnowledgeGovernanceService(
      store: this.store,
      verifier: verifier ?? _verifier(),
      nowUtc: () => _now,
    );
  }
  final KnowledgePack pack;
  final MemoryKnowledgeGovernanceStore store;
  late KnowledgeGovernanceService service;

  Future<KnowledgeApprovalEnvelope> approval(
    KnowledgeApprovalDecision decision, {
    String? ruleId,
    KnowledgeApprovalBinding? binding,
    String? keyId,
    String? reason,
    String? approvalId,
  }) async {
    final role = switch (decision) {
      KnowledgeApprovalDecision.authored => KnowledgeApprovalRole.author,
      KnowledgeApprovalDecision.approved ||
      KnowledgeApprovalDecision.rejected => KnowledgeApprovalRole.reviewer,
      _ => KnowledgeApprovalRole.publisher,
    };
    final key = keyId ?? '${role.name}-key';
    final bound =
        binding ??
        service.bindingForNext(await service.loadState(), pack, ruleId: ruleId);
    final statement = KnowledgeApprovalStatement(
      approvalId: approvalId ?? '${decision.name}-${bound.sequence}',
      issuer: 'test-authority',
      environment: 'synthetic-tests',
      keyId: key,
      subjectId: _keys[key]!.subjectId,
      authorSubjectId: pack.authorId,
      role: role,
      decision: decision,
      binding: bound,
      issuedAtUtc: _now.subtract(const Duration(minutes: 1)),
      notBeforeUtc: _now.subtract(const Duration(minutes: 1)),
      expiresAtUtc: _now.add(const Duration(days: 1)),
      reason: reason,
    );
    final signature = await _algorithm.sign(
      utf8.encode(statement.canonicalJson),
      keyPair: _pairs[key]!,
    );
    return KnowledgeApprovalEnvelope(
      statement: statement,
      signatureBase64Url: base64Url.encode(signature.bytes).replaceAll('=', ''),
    );
  }

  Future<void> draft() async {
    await service.saveDraft(
      pack,
      actorId: pack.authorId,
      authorize: () => true,
    );
  }

  Future<void> submit() async {
    await service.submit(
      pack.digest,
      authorApproval: await approval(KnowledgeApprovalDecision.authored),
      authorize: () => true,
    );
  }

  Future<void> reviewAll() async {
    for (final ruleId in pack.ruleSet.ruleVersions.keys) {
      await service.acceptReview(
        pack.digest,
        review: await approval(
          KnowledgeApprovalDecision.approved,
          ruleId: ruleId,
        ),
        authorize: () => true,
      );
    }
  }

  Future<void> activate() async {
    await service.activate(
      pack.digest,
      publisherApproval: await approval(KnowledgeApprovalDecision.published),
      authorize: () => true,
    );
  }

  Future<void> toActive() async {
    await draft();
    await submit();
    await reviewAll();
    await activate();
  }

  Future<void> withdraw() async {
    await service.withdraw(
      pack.digest,
      publisherApproval: await approval(
        KnowledgeApprovalDecision.withdrawn,
        reason: 'Synthetic fixture withdrawn for test',
      ),
      authorize: () => true,
    );
  }
}

class _FaultStore extends MemoryKnowledgeGovernanceStore {
  bool failAfterAnchor = false;
  int? pauseReadNumber;
  int reads = 0;
  Completer<void> entered = Completer<void>();
  Completer<void> resume = Completer<void>();
  void pauseOnRead(int number) {
    reads = 0;
    pauseReadNumber = number;
    entered = Completer<void>();
    resume = Completer<void>();
  }

  @override
  Future<String?> read() async {
    final snapshot = document;
    if (++reads == pauseReadNumber) {
      pauseReadNumber = null;
      entered.complete();
      await resume.future;
    }
    return snapshot;
  }

  @override
  Future<void> writeExact({
    required String document,
    required String anchor,
    required String? expectedAnchor,
    required bool Function() authorize,
  }) async {
    if (failAfterAnchor) {
      if (!authorize() || this.anchor != expectedAnchor) {
        throw StateError('test session or CAS mismatch');
      }
      this.anchor = anchor;
      throw StateError('test injected document write failure');
    }
    await super.writeExact(
      document: document,
      anchor: anchor,
      expectedAnchor: expectedAnchor,
      authorize: authorize,
    );
  }
}

void main() {
  setUpAll(() async {
    for (var index = 0; index < KnowledgeApprovalRole.values.length; index++) {
      final role = KnowledgeApprovalRole.values[index];
      final keyId = '${role.name}-key';
      final pair = await _algorithm.newKeyPairFromSeed(
        List.filled(32, index + 41),
      );
      _pairs[keyId] = pair;
      _keys[keyId] = KnowledgeApprovalTrustedKey(
        keyId: keyId,
        subjectId: 'subject-${role.name}',
        issuer: 'test-authority',
        environment: 'synthetic-tests',
        publicKeyBytes: (await pair.extractPublicKey()).bytes,
        roles: role == KnowledgeApprovalRole.author
            ? {role, KnowledgeApprovalRole.reviewer}
            : {role},
        scopes: role == KnowledgeApprovalRole.author
            ? KnowledgeApprovalScope.values.toSet()
            : {
                role == KnowledgeApprovalRole.reviewer
                    ? KnowledgeApprovalScope.rule
                    : KnowledgeApprovalScope.pack,
              },
        packIds: {'synthetic-pack'},
        notBeforeUtc: _now.subtract(const Duration(days: 2)),
        expiresAtUtc: _now.add(const Duration(days: 90)),
      );
    }
  });

  test('exact packaged baseline only before managed activation', () async {
    final h = _Harness();
    expect(
      KnowledgeGovernanceService.prototypeBaseline().contentDigest,
      knowledgePrototypeBaselineDigest,
    );
    final initial = await h.service.resolveAuthorizedRules();
    expect(initial.allowed, isTrue);
    expect(initial.isPrototypeBaseline, isTrue);
    expect(await h.service.isResolutionCurrent(initial), isTrue);
    final different = await h.service.resolveAuthorizedRules(
      baselineCandidate: h.pack.ruleSet,
    );
    expect(different.allowed, isFalse);
    await h.draft();
    expect(
      (await h.service.resolveAuthorizedRules()).isPrototypeBaseline,
      isTrue,
    );
    expect(await h.service.isResolutionCurrent(initial), isFalse);
  });

  test(
    'signed lifecycle replays exact complete rules then withdrawal holds forever',
    () async {
      final h = _Harness();
      await h.toActive();
      final state = await h.service.loadState();
      expect(state.approvalSequence, 3);
      expect(state.journal.events, hasLength(4));
      expect(state.activePack!.status, KnowledgePackStatus.active);
      expect(state.activePack!.suiteResult!['clinical_validation'], isFalse);
      expect(
        (state.activePack!.suiteResult!['cases'] as List).every(
          (c) => c['passed'] == true,
        ),
        isTrue,
      );
      final fresh = KnowledgeGovernanceService(
        store: h.store,
        verifier: _verifier(),
        nowUtc: () => _now,
      );
      final result = await fresh.resolveAuthorizedRules();
      expect(result.allowed, isTrue);
      expect(result.packageDigest, h.pack.digest);
      expect(result.pack!.sources.single.digest, h.pack.sources.single.digest);
      expect(
        result.rules.map((r) => r.ruleId),
        h.pack.ruleSet.ruleVersions.keys,
      );
      expect(result.isPrototypeBaseline, isFalse);
      expect(await fresh.isResolutionCurrent(result), isTrue);
      expect(() => result.rules.clear(), throwsUnsupportedError);
      expect(
        () => result.rules.single.conditions.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => result.rules.single.thenClause.actions.first.clear(),
        throwsUnsupportedError,
      );
      await h.withdraw();
      expect(await fresh.isResolutionCurrent(result), isFalse);
      expect((await fresh.resolveAuthorizedRules()).allowed, isFalse);
      final after = await fresh.loadState();
      expect(after.everManaged, isTrue);
      expect(after.activePack, isNull);
      expect(
        after.packages[h.pack.digest]!.status,
        KnowledgePackStatus.withdrawn,
      );
      expect(
        (await fresh.resolveAuthorizedRules(
          baselineCandidate: RuleTestRuleSet.baseline(),
        )).allowed,
        isFalse,
      );
    },
  );

  test(
    'all rules require independent review and stale signatures cannot publish',
    () async {
      final h = _Harness(pack: createKnowledgeTestPack(ruleCount: 2));
      await h.draft();
      await h.submit();
      final premature = await h.approval(KnowledgeApprovalDecision.published);
      await expectLater(
        h.service.activate(
          h.pack.digest,
          publisherApproval: premature,
          authorize: () => true,
        ),
        throwsStateError,
      );
      final firstId = h.pack.ruleSet.ruleVersions.keys.first;
      final self = await h.approval(
        KnowledgeApprovalDecision.approved,
        ruleId: firstId,
        keyId: 'author-key',
      );
      await expectLater(
        h.service.acceptReview(
          h.pack.digest,
          review: self,
          authorize: () => true,
        ),
        throwsStateError,
      );
      final first = await h.approval(
        KnowledgeApprovalDecision.approved,
        ruleId: firstId,
      );
      await h.service.acceptReview(
        h.pack.digest,
        review: first,
        authorize: () => true,
      );
      expect(
        (await h.service.loadState()).packages[h.pack.digest]!.status,
        KnowledgePackStatus.submitted,
      );
      await expectLater(
        h.service.activate(
          h.pack.digest,
          publisherApproval: await h.approval(
            KnowledgeApprovalDecision.published,
          ),
          authorize: () => true,
        ),
        throwsStateError,
      );
      await h.service.acceptReview(
        h.pack.digest,
        review: await h.approval(
          KnowledgeApprovalDecision.approved,
          ruleId: h.pack.ruleSet.ruleVersions.keys.last,
        ),
        authorize: () => true,
      );
      await expectLater(
        h.service.activate(
          h.pack.digest,
          publisherApproval: premature,
          authorize: () => true,
        ),
        throwsStateError,
      );
      await h.activate();
      expect((await h.service.resolveAuthorizedRules()).rules, hasLength(2));
    },
  );

  test(
    'rejection is terminal and duplicate package versions cannot replace content',
    () async {
      final h = _Harness();
      await h.draft();
      await h.submit();
      await h.service.acceptReview(
        h.pack.digest,
        review: await h.approval(
          KnowledgeApprovalDecision.rejected,
          ruleId: h.pack.ruleSet.ruleVersions.keys.single,
        ),
        authorize: () => true,
      );
      expect(
        (await h.service.loadState()).packages[h.pack.digest]!.status,
        KnowledgePackStatus.rejected,
      );
      await expectLater(h.activate(), throwsStateError);
      await expectLater(
        h.service.saveDraft(
          h.pack,
          actorId: h.pack.authorId,
          authorize: () => true,
        ),
        throwsStateError,
      );
      expect((await h.service.loadState()).journal.events, hasLength(3));
    },
  );

  test(
    'suite checks final decisions and each rule even when a different rule wins',
    () async {
      final wrongFinal = createKnowledgeTestPack(
        changeCases: (cases) => [
          KnowledgeTestCase(
            category: cases.first.category,
            targetRuleId: cases.first.targetRuleId,
            expectedMatch: cases.first.expectedMatch,
            rationale: 'Deliberately wrong winner expectation',
            testCase: cases.first.testCase.copyWith(
              expected: RuleTestExpectations(targets: []),
            ),
          ),
          ...cases.skip(1),
        ],
      );
      final h = _Harness(pack: wrongFinal);
      await h.draft();
      await expectLater(h.submit(), throwsStateError);
      final noBoundary = _Harness(
        pack: createKnowledgeTestPack(changeCases: (c) => c.take(3).toList()),
      );
      await noBoundary.draft();
      await expectLater(noBoundary.submit(), throwsFormatException);
      final wrongMatch = _Harness(
        pack: createKnowledgeTestPack(
          changeCases: (cases) => [
            ...cases.take(3),
            KnowledgeTestCase(
              category: KnowledgeCaseCategory.boundary,
              targetRuleId: cases.last.targetRuleId,
              expectedMatch: KnowledgeRuleMatch.notMatched,
              rationale:
                  'Final output is right, but independent rule assertion is wrong.',
              testCase: cases.last.testCase,
            ),
          ],
        ),
      );
      await wrongMatch.draft();
      await expectLater(wrongMatch.submit(), throwsStateError);
    },
  );

  test(
    'untrusted, revoked, expired or changed-engine packages fail closed',
    () async {
      final untrusted = _Harness(verifier: _verifier(empty: true));
      await untrusted.draft();
      await expectLater(untrusted.submit(), throwsStateError);
      final h = _Harness();
      await h.toActive();
      for (final service in [
        KnowledgeGovernanceService(
          store: h.store,
          verifier: _verifier(revoked: {'reviewer-key'}),
          nowUtc: () => _now,
        ),
        KnowledgeGovernanceService(
          store: h.store,
          verifier: _verifier(),
          nowUtc: () => _now.add(const Duration(days: 2)),
        ),
        KnowledgeGovernanceService(
          store: h.store,
          verifier: _verifier(),
          nowUtc: () => _now,
          engineDigest: (_) => '0' * 64,
        ),
      ]) {
        expect((await service.resolveAuthorizedRules()).allowed, isFalse);
      }
    },
  );

  test(
    'corrupt, truncated or rolled-back storage cannot recover baseline',
    () async {
      final h = _Harness();
      await h.toActive();
      final document = h.store.document;
      final anchor = h.store.anchor;
      for (final damaged in [
        null,
        '{',
        document!.replaceFirst('"events":', '"unknown":'),
        document.replaceFirst(
          '"schema_version":1',
          '"schema_version":0,"schema_version":1',
        ),
      ]) {
        h.store.document = damaged;
        expect((await h.service.resolveAuthorizedRules()).allowed, isFalse);
      }
      h.store.document = document;
      h.store.anchor = null;
      expect((await h.service.resolveAuthorizedRules()).allowed, isFalse);
      h.store.anchor = anchor;
      await h.withdraw();
      h.store.document = document;
      expect((await h.service.resolveAuthorizedRules()).allowed, isFalse);
    },
  );

  test(
    'torn anchor-first write holds resolution and never resets history',
    () async {
      final store = _FaultStore();
      final h = _Harness(store: store);
      await h.toActive();
      store.failAfterAnchor = true;
      await expectLater(h.withdraw(), throwsStateError);
      expect((await h.service.resolveAuthorizedRules()).allowed, isFalse);
      expect(store.document, isNotNull);
      expect(store.anchor, isNotNull);
    },
  );

  test(
    'concurrent duplicate review commits once and preserves the chain',
    () async {
      final h = _Harness();
      await h.draft();
      await h.submit();
      final review = await h.approval(
        KnowledgeApprovalDecision.approved,
        ruleId: h.pack.ruleSet.ruleVersions.keys.single,
      );
      final results = await Future.wait([
        for (var i = 0; i < 2; i++)
          h.service
              .acceptReview(
                h.pack.digest,
                review: review,
                authorize: () => true,
              )
              .then((_) => true)
              .catchError((Object _) => false),
      ]);
      expect(results.where((v) => v), hasLength(1));
      expect((await h.service.loadState()).approvalSequence, 2);
    },
  );

  test(
    'resolution rejects withdrawal during replay and after suite evaluation',
    () async {
      for (final barrier in [2, 3]) {
        final store = _FaultStore();
        final h = _Harness(store: store);
        await h.toActive();
        store.pauseOnRead(barrier);
        final pending = h.service.resolveAuthorizedRules();
        await store.entered.future;
        await h.withdraw();
        store.resume.complete();
        expect(
          (await pending).allowed,
          isFalse,
          reason: 'snapshot read barrier $barrier',
        );
      }
    },
  );

  test(
    'session revocation during async load prevents draft persistence',
    () async {
      final store = _FaultStore();
      final h = _Harness(store: store);
      var authorized = true;
      store.pauseOnRead(1);
      final pending = h.service.saveDraft(
        h.pack,
        actorId: h.pack.authorId,
        authorize: () => authorized,
      );
      await store.entered.future;
      authorized = false;
      store.resume.complete();
      await expectLater(pending, throwsStateError);
      expect(store.document, isNull);
      expect(store.anchor, isNull);
    },
  );

  test('local preference store verifies exact write, CAS and reload', () async {
    SharedPreferences.setMockInitialValues({});
    final service = KnowledgeGovernanceService(
      store: LocalKnowledgeGovernanceStore(),
      verifier: _verifier(),
      nowUtc: () => _now,
    );
    final pack = createKnowledgeTestPack();
    final saved = await service.saveDraft(
      pack,
      actorId: pack.authorId,
      authorize: () => true,
    );
    expect((await service.loadState()).headDigest, saved.headDigest);
    final store = LocalKnowledgeGovernanceStore();
    await expectLater(
      store.writeExact(
        document: '{}',
        anchor: '{}',
        expectedAnchor: null,
        authorize: () => true,
      ),
      throwsStateError,
    );
    expect(
      (await service.resolveAuthorizedRules()).isPrototypeBaseline,
      isTrue,
    );
  });

  test(
    'withdrawing replacement package never restores a superseded package',
    () async {
      final first = _Harness();
      await first.toActive();
      final second = _Harness(
        pack: createKnowledgeTestPack(version: '2'),
        store: first.store,
      );
      await second.toActive();
      final state = await second.service.loadState();
      expect(state.activePackDigest, second.pack.digest);
      expect(
        state.packages[first.pack.digest]!.status,
        KnowledgePackStatus.superseded,
      );
      await second.withdraw();
      expect((await first.service.resolveAuthorizedRules()).allowed, isFalse);
      await expectLater(first.activate(), throwsStateError);
    },
  );

  test(
    'recomputed unsigned event hashes cannot forge passing suite evidence',
    () async {
      final h = _Harness();
      await h.toActive();
      final state = await h.service.loadState();
      final events = <KnowledgeGovernanceEvent>[];
      for (final old in state.journal.events) {
        final payload = knowledgeCopy(old.payload) as Map<String, dynamic>;
        if (old.kind == KnowledgeGovernanceEventKind.submitted) {
          payload['suite_result']['cases'][0]['actual_match'] = 'notMatched';
        }
        events.add(
          KnowledgeGovernanceEvent(
            sequence: old.sequence,
            previousDigest: events.lastOrNull?.digest,
            kind: old.kind,
            actorId: old.actorId,
            occurredAtUtc: old.occurredAtUtc,
            payload: payload,
          ),
        );
      }
      final forged = KnowledgeGovernanceJournal(events);
      h.store.document = forged.encode();
      h.store.anchor = jsonEncode({
        'schema_version': 1,
        'head_digest': forged.headDigest,
        'event_count': events.length,
        'ever_managed': true,
      });
      await expectLater(h.service.loadState(), throwsStateError);
      expect((await h.service.resolveAuthorizedRules()).allowed, isFalse);
    },
  );
}
