import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parkinsum_companion/core/services/capability_manifest_distribution.dart';
import 'package:parkinsum_companion/core/services/capability_rollout_service.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/domain/entities/signed_capability_manifest.dart';
import 'package:parkinsum_companion/domain/usecases/local_ai_recommendation_adapter.dart';
import 'package:parkinsum_companion/features/diagnostics/capability_rollout_page.dart';

import 'helpers/page_test_harness.dart';

void main() {
  final now = DateTime.utc(2026, 8, 26, 12);
  late Ed25519 algorithm;
  late SimpleKeyPair keyA;
  late SimplePublicKey publicKeyA;
  late CapabilityTrustPolicy trustA;

  setUp(() async {
    algorithm = Ed25519();
    keyA = await algorithm.newKeyPair();
    publicKeyA = await keyA.extractPublicKey();
    trustA = CapabilityTrustPolicy(
      environment: 'staging',
      issuer: 'parkinsum-release',
      trustedEd25519PublicKeys: <String, List<int>>{'key-a': publicKeyA.bytes},
    );
  });

  test(
    'valid Ed25519 manifest verifies and has no targeting surface',
    () async {
      final raw = await _signedEnvelope(
        algorithm: algorithm,
        keyPair: keyA,
        manifest: _manifest(now: now),
      );
      final result = await SignedCapabilityManifestVerifier(
        trustPolicy: trustA,
      ).verify(raw, nowUtc: now);

      expect(result.status, CapabilityManifestVerificationStatus.verified);
      expect(result.envelope!.manifest.sequence, 1);
      final canonical = result.envelope!.canonicalJson;
      for (final forbidden in <String>[
        'patient',
        'account',
        'medication',
        'meal',
        'targeting_key',
        'pseudonym',
        'user_id',
      ]) {
        expect(canonical.toLowerCase(), isNot(contains(forbidden)));
      }
    },
  );

  test(
    'tamper, unknown field, environment, time, and lifetime fail closed',
    () async {
      final valid = await _signedEnvelope(
        algorithm: algorithm,
        keyPair: keyA,
        manifest: _manifest(now: now),
      );
      final verifier = SignedCapabilityManifestVerifier(trustPolicy: trustA);
      final tampered = jsonDecode(valid) as Map<String, dynamic>;
      final signed = tampered['signed'] as Map<String, dynamic>;
      final capabilities = signed['capabilities'] as List<dynamic>;
      (capabilities.first as Map<String, dynamic>)['enabled'] = true;
      expect(
        (await verifier.verify(jsonEncode(tampered), nowUtc: now)).status,
        CapabilityManifestVerificationStatus.invalidSignature,
      );

      final unknown = jsonDecode(valid) as Map<String, dynamic>;
      (unknown['signed'] as Map<String, dynamic>)['patient_id'] = 'forbidden';
      expect(
        (await verifier.verify(jsonEncode(unknown), nowUtc: now)).status,
        CapabilityManifestVerificationStatus.malformed,
      );

      final wrongEnvironment = await _signedEnvelope(
        algorithm: algorithm,
        keyPair: keyA,
        manifest: _manifest(now: now, environment: 'production'),
      );
      expect(
        (await verifier.verify(wrongEnvironment, nowUtc: now)).status,
        CapabilityManifestVerificationStatus.wrongEnvironment,
      );

      final future = await _signedEnvelope(
        algorithm: algorithm,
        keyPair: keyA,
        manifest: _manifest(
          now: now,
          issuedAt: now.add(const Duration(hours: 1)),
          notBefore: now.add(const Duration(hours: 1)),
          expiresAt: now.add(const Duration(hours: 2)),
        ),
      );
      expect(
        (await verifier.verify(future, nowUtc: now)).status,
        CapabilityManifestVerificationStatus.notYetValid,
      );

      final expired = await _signedEnvelope(
        algorithm: algorithm,
        keyPair: keyA,
        manifest: _manifest(
          now: now,
          issuedAt: now.subtract(const Duration(days: 2)),
          notBefore: now.subtract(const Duration(days: 2)),
          expiresAt: now.subtract(const Duration(hours: 1)),
        ),
      );
      expect(
        (await verifier.verify(expired, nowUtc: now)).status,
        CapabilityManifestVerificationStatus.expired,
      );

      final overlong = await _signedEnvelope(
        algorithm: algorithm,
        keyPair: keyA,
        manifest: _manifest(
          now: now,
          issuedAt: now,
          notBefore: now,
          expiresAt: now.add(const Duration(days: 15)),
        ),
      );
      expect(
        (await verifier.verify(overlong, nowUtc: now)).status,
        CapabilityManifestVerificationStatus.lifetimeExceeded,
      );
    },
  );

  test('activation persists a signed last-known-good across restart', () async {
    final store = MemoryCapabilityActivationStore(scope: 'restart');
    final service = _service(store: store, trust: trustA, now: now);
    final raw = await _signedEnvelope(
      algorithm: algorithm,
      keyPair: keyA,
      manifest: _manifest(
        now: now,
        values: const <SignedCapabilityId, bool>{
          SignedCapabilityId.localAiReranking: true,
        },
      ),
    );

    final activated = await service.activate(raw);
    expect(activated.activationStatus, CapabilityActivationStatus.active);
    expect(
      activated.evaluate(SignedCapabilityId.localAiReranking).enabled,
      isTrue,
    );
    expect(
      activated
          .evaluate(
            SignedCapabilityId.localAiReranking,
            localPrerequisiteSatisfied: false,
          )
          .enabled,
      isFalse,
    );

    final restarted = _service(store: store, trust: trustA, now: now);
    final loaded = await restarted.load();
    expect(loaded.activationStatus, CapabilityActivationStatus.active);
    expect(
      loaded.envelope!.manifest.sha256,
      activated.envelope!.manifest.sha256,
    );
  });

  test('invalid candidate cannot replace last-known-good', () async {
    final store = MemoryCapabilityActivationStore(scope: 'lkg');
    final service = _service(store: store, trust: trustA, now: now);
    final firstManifest = _manifest(
      now: now,
      values: const <SignedCapabilityId, bool>{
        SignedCapabilityId.localAiReranking: true,
      },
    );
    await service.activate(
      await _signedEnvelope(
        algorithm: algorithm,
        keyPair: keyA,
        manifest: firstManifest,
      ),
    );
    final firstDigest = service.snapshot.envelope!.manifest.sha256;

    final invalid =
        jsonDecode(
              await _signedEnvelope(
                algorithm: algorithm,
                keyPair: keyA,
                manifest: _manifest(
                  now: now,
                  sequence: 2,
                  previous: firstDigest,
                ),
              ),
            )
            as Map<String, dynamic>;
    (invalid['signature'] as Map<String, dynamic>)['value_base64url'] =
        base64Url.encode(List<int>.filled(64, 7)).replaceAll('=', '');
    final rejected = await service.activate(jsonEncode(invalid));
    expect(
      rejected.activationStatus,
      CapabilityActivationStatus.verificationRejected,
    );
    expect(rejected.envelope!.manifest.sha256, firstDigest);
    expect(
      rejected.evaluate(SignedCapabilityId.localAiReranking).enabled,
      isTrue,
    );
    expect(
      (await _service(
        store: store,
        trust: trustA,
        now: now,
      ).load()).envelope!.manifest.sha256,
      firstDigest,
    );
  });

  test('replay, downgrade, and chain fork are rejected', () async {
    final store = MemoryCapabilityActivationStore(scope: 'ordering');
    final service = _service(store: store, trust: trustA, now: now);
    final first = _manifest(now: now);
    final firstRaw = await _signedEnvelope(
      algorithm: algorithm,
      keyPair: keyA,
      manifest: first,
    );
    await service.activate(firstRaw);

    final sameSequenceDifferent = await _signedEnvelope(
      algorithm: algorithm,
      keyPair: keyA,
      manifest: _manifest(
        now: now,
        values: const <SignedCapabilityId, bool>{
          SignedCapabilityId.externalCatalogRefresh: true,
        },
      ),
    );
    expect(
      (await service.activate(sameSequenceDifferent)).activationStatus,
      CapabilityActivationStatus.replayRejected,
    );

    final second = _manifest(now: now, sequence: 2, previous: first.sha256);
    await service.activate(
      await _signedEnvelope(
        algorithm: algorithm,
        keyPair: keyA,
        manifest: second,
      ),
    );
    expect(
      (await service.activate(firstRaw)).activationStatus,
      CapabilityActivationStatus.downgradeRejected,
    );

    final fork = await _signedEnvelope(
      algorithm: algorithm,
      keyPair: keyA,
      manifest: _manifest(now: now, sequence: 3, previous: ''.padLeft(64, '0')),
    );
    expect(
      (await service.activate(fork)).activationStatus,
      CapabilityActivationStatus.chainRejected,
    );

    final gap = await _signedEnvelope(
      algorithm: algorithm,
      keyPair: keyA,
      manifest: _manifest(now: now, sequence: 4, previous: second.sha256),
    );
    expect(
      (await service.activate(gap)).activationStatus,
      CapabilityActivationStatus.chainRejected,
    );
  });

  test('key rotation and revocation are enforced', () async {
    final keyB = await algorithm.newKeyPair();
    final publicKeyB = await keyB.extractPublicKey();
    final rotatingTrust = CapabilityTrustPolicy(
      environment: 'staging',
      issuer: 'parkinsum-release',
      trustedEd25519PublicKeys: <String, List<int>>{
        'key-a': publicKeyA.bytes,
        'key-b': publicKeyB.bytes,
      },
    );
    final store = MemoryCapabilityActivationStore(scope: 'rotation');
    final service = _service(store: store, trust: rotatingTrust, now: now);
    final first = _manifest(now: now);
    await service.activate(
      await _signedEnvelope(
        algorithm: algorithm,
        keyPair: keyA,
        manifest: first,
      ),
    );

    final wrongReason = _manifest(
      now: now,
      sequence: 2,
      previous: first.sha256,
      keyId: 'key-b',
    );
    expect(
      (await service.activate(
        await _signedEnvelope(
          algorithm: algorithm,
          keyPair: keyB,
          manifest: wrongReason,
        ),
      )).activationStatus,
      CapabilityActivationStatus.keyTransitionRejected,
    );

    final rotated = _manifest(
      now: now,
      sequence: 2,
      previous: first.sha256,
      keyId: 'key-b',
      reason: CapabilityManifestReason.keyRotation,
    );
    expect(
      (await service.activate(
        await _signedEnvelope(
          algorithm: algorithm,
          keyPair: keyB,
          manifest: rotated,
        ),
      )).activationStatus,
      CapabilityActivationStatus.active,
    );

    final revokedTrust = CapabilityTrustPolicy(
      environment: 'staging',
      issuer: 'parkinsum-release',
      trustedEd25519PublicKeys: <String, List<int>>{
        'key-a': publicKeyA.bytes,
        'key-b': publicKeyB.bytes,
      },
      revokedKeyIds: const <String>{'key-b'},
    );
    final restarted = _service(store: store, trust: revokedTrust, now: now);
    final loaded = await restarted.load();
    expect(
      loaded.verificationStatus,
      CapabilityManifestVerificationStatus.revokedKey,
    );
    expect(
      loaded.evaluate(SignedCapabilityId.localAiReranking).enabled,
      isFalse,
    );
  });

  test(
    'verified history permits exact rollback and rejects invented target',
    () async {
      final store = MemoryCapabilityActivationStore(scope: 'rollback');
      final service = _service(store: store, trust: trustA, now: now);
      final first = _manifest(
        now: now,
        values: const <SignedCapabilityId, bool>{
          SignedCapabilityId.localAiReranking: true,
        },
      );
      await service.activate(
        await _signedEnvelope(
          algorithm: algorithm,
          keyPair: keyA,
          manifest: first,
        ),
      );
      final second = _manifest(now: now, sequence: 2, previous: first.sha256);
      await service.activate(
        await _signedEnvelope(
          algorithm: algorithm,
          keyPair: keyA,
          manifest: second,
        ),
      );

      final invented = _manifest(
        now: now,
        sequence: 3,
        previous: second.sha256,
        reason: CapabilityManifestReason.rollback,
        rollbackTarget: CapabilityRollbackTarget(
          sequence: 1,
          manifestSha256: ''.padLeft(64, 'f'),
        ),
        values: const <SignedCapabilityId, bool>{
          SignedCapabilityId.localAiReranking: true,
        },
      );
      expect(
        (await service.activate(
          await _signedEnvelope(
            algorithm: algorithm,
            keyPair: keyA,
            manifest: invented,
          ),
        )).activationStatus,
        CapabilityActivationStatus.rollbackRejected,
      );

      final rollback = _manifest(
        now: now,
        sequence: 3,
        previous: second.sha256,
        reason: CapabilityManifestReason.rollback,
        rollbackTarget: CapabilityRollbackTarget(
          sequence: 1,
          manifestSha256: first.sha256,
        ),
        values: const <SignedCapabilityId, bool>{
          SignedCapabilityId.localAiReranking: true,
        },
      );
      final rolledBack = await service.activate(
        await _signedEnvelope(
          algorithm: algorithm,
          keyPair: keyA,
          manifest: rollback,
        ),
      );
      expect(rolledBack.activationStatus, CapabilityActivationStatus.active);
      expect(
        rolledBack.evaluate(SignedCapabilityId.localAiReranking).enabled,
        isTrue,
      );
    },
  );

  test(
    'tampered persisted history fails closed instead of authorizing rollback',
    () async {
      final store = MemoryCapabilityActivationStore(scope: 'history-tamper');
      final service = _service(store: store, trust: trustA, now: now);
      final first = _manifest(now: now);
      await service.activate(
        await _signedEnvelope(
          algorithm: algorithm,
          keyPair: keyA,
          manifest: first,
        ),
      );
      final second = _manifest(now: now, sequence: 2, previous: first.sha256);
      await service.activate(
        await _signedEnvelope(
          algorithm: algorithm,
          keyPair: keyA,
          manifest: second,
        ),
      );

      final persisted =
          jsonDecode((await store.read())!) as Map<String, dynamic>;
      final history = persisted['history'] as List<dynamic>;
      final historyEnvelope =
          (history.single as Map<String, dynamic>)['envelope']
              as Map<String, dynamic>;
      (historyEnvelope['signature']
          as Map<String, dynamic>)['value_base64url'] = base64Url
          .encode(List<int>.filled(64, 3))
          .replaceAll('=', '');
      final tamperedStore = MemoryCapabilityActivationStore(
        scope: 'history-tamper-restart',
        initialValue: canonicalCapabilityJson(persisted),
      );
      final restarted = _service(store: tamperedStore, trust: trustA, now: now);
      final loaded = await restarted.load();

      expect(
        loaded.activationStatus,
        CapabilityActivationStatus.conservativeDefaults,
      );
      expect(loaded.reason, contains('persisted_history_verification_failed'));
      expect(loaded.hasActiveManifest, isFalse);
    },
  );

  test(
    'emergency disable cannot enable a previously disabled capability',
    () async {
      final store = MemoryCapabilityActivationStore(scope: 'emergency');
      final service = _service(store: store, trust: trustA, now: now);
      final first = _manifest(now: now);
      await service.activate(
        await _signedEnvelope(
          algorithm: algorithm,
          keyPair: keyA,
          manifest: first,
        ),
      );
      final unsafe = _manifest(
        now: now,
        sequence: 2,
        previous: first.sha256,
        reason: CapabilityManifestReason.emergencyDisable,
        values: const <SignedCapabilityId, bool>{
          SignedCapabilityId.localAiReranking: true,
        },
      );
      expect(
        (await service.activate(
          await _signedEnvelope(
            algorithm: algorithm,
            keyPair: keyA,
            manifest: unsafe,
          ),
        )).activationStatus,
        CapabilityActivationStatus.rollbackRejected,
      );
    },
  );

  test(
    'process-wide serial order prevents concurrent genesis overwrite',
    () async {
      final store = _BlockingFirstWriteStore(scope: 'concurrent');
      final firstService = _service(store: store, trust: trustA, now: now);
      final secondService = _service(store: store, trust: trustA, now: now);
      final first = _manifest(now: now, manifestId: 'manifest-first');
      final competing = _manifest(
        now: now,
        manifestId: 'manifest-competing',
        values: const <SignedCapabilityId, bool>{
          SignedCapabilityId.externalCatalogRefresh: true,
        },
      );
      final firstFuture = firstService.activate(
        await _signedEnvelope(
          algorithm: algorithm,
          keyPair: keyA,
          manifest: first,
        ),
      );
      await store.firstWriteStarted.future;
      final competingFuture = secondService.activate(
        await _signedEnvelope(
          algorithm: algorithm,
          keyPair: keyA,
          manifest: competing,
        ),
      );
      store.releaseFirstWrite.complete();

      expect(
        (await firstFuture).activationStatus,
        CapabilityActivationStatus.active,
      );
      expect(
        (await competingFuture).activationStatus,
        CapabilityActivationStatus.replayRejected,
      );
      expect(
        (await _service(
          store: store,
          trust: trustA,
          now: now,
        ).load()).envelope!.manifest.manifestId,
        'manifest-first',
      );
    },
  );

  test(
    'acknowledgement loss is recovered while a failed write keeps defaults',
    () async {
      final raw = await _signedEnvelope(
        algorithm: algorithm,
        keyPair: keyA,
        manifest: _manifest(now: now),
      );
      final ackLost = _WriteThenThrowStore(scope: 'ack-lost');
      final recovered = await _service(
        store: ackLost,
        trust: trustA,
        now: now,
      ).activate(raw);
      expect(
        recovered.activationStatus,
        CapabilityActivationStatus.recoveredAfterAcknowledgementLoss,
      );

      final failed = await _service(
        store: _ThrowBeforeWriteStore(scope: 'write-fail'),
        trust: trustA,
        now: now,
      ).activate(raw);
      expect(
        failed.activationStatus,
        CapabilityActivationStatus.persistenceFailed,
      );
      expect(
        failed.evaluate(SignedCapabilityId.localAiReranking).enabled,
        isFalse,
      );
    },
  );

  test('unconfigured trust and clear both use conservative defaults', () async {
    final unconfiguredTrust = CapabilityTrustPolicy(
      environment: 'staging',
      issuer: 'parkinsum-release',
      trustedEd25519PublicKeys: const <String, List<int>>{},
    );
    final store = MemoryCapabilityActivationStore(scope: 'clear');
    final unconfigured = await _service(
      store: store,
      trust: unconfiguredTrust,
      now: now,
    ).load();
    expect(
      unconfigured.activationStatus,
      CapabilityActivationStatus.unconfigured,
    );

    final configured = _service(store: store, trust: trustA, now: now);
    await configured.activate(
      await _signedEnvelope(
        algorithm: algorithm,
        keyPair: keyA,
        manifest: _manifest(now: now),
      ),
    );
    final cleared = await configured.clearToConservativeDefaults();
    expect(cleared.activationStatus, CapabilityActivationStatus.cleared);
    expect(await store.read(), isNull);
  });

  test(
    'managed Local AI policy blocks before consent or network probing',
    () async {
      var evaluations = 0;
      final adapter = LocalAiRecommendationAdapter(
        managedCapabilityAllowsRequest: () {
          evaluations += 1;
          return false;
        },
      );
      final result = await adapter.probe(userProfile: UserProfile.defaults());
      expect(evaluations, 1);
      expect(result.available, isFalse);
      expect(result.skipped, isTrue);
      expect(
        result.message,
        'Local AI probe skipped by signed capability policy.',
      );
    },
  );

  test('distribution policy rejects SSRF-shaped or ambiguous endpoints', () {
    for (final configuration in <(String, String)>[
      ('http://release.example.com/manifest.json', 'release.example.com'),
      ('https://user@release.example.com/manifest.json', 'release.example.com'),
      (
        'https://release.example.com/manifest.json?token=secret',
        'release.example.com',
      ),
      ('https://127.0.0.1/manifest.json', '127.0.0.1'),
      ('https://release.example.com/manifest.json', 'other.example.com'),
      (
        'https://release.example.com/manifest.json',
        'release.example.com,unused.example.com',
      ),
    ]) {
      final policy = CapabilityManifestDistributionPolicy.fromConfiguration(
        endpointUrl: configuration.$1,
        allowedHostsCsv: configuration.$2,
      );
      expect(policy.isConfigured, isFalse);
      expect(
        policy.configurationStatus,
        CapabilityManifestFetchStatus.invalidConfiguration,
      );
    }

    final valid = CapabilityManifestDistributionPolicy.fromConfiguration(
      endpointUrl: 'https://release.example.com/capability/manifest.json',
      allowedHostsCsv: 'release.example.com',
    );
    expect(valid.isConfigured, isTrue);
    expect(
      valid.safeEndpointLabel,
      'https://release.example.com/capability/manifest.json',
    );

    final sameOrigin = CapabilityManifestDistributionPolicy.fromConfiguration(
      endpointUrl: 'https://release.example.com/capability/manifest.json',
      allowedHostsCsv: 'release.example.com',
      runtimeOrigin: Uri.parse('https://release.example.com/app/'),
    );
    expect(sameOrigin.isConfigured, isFalse);

    final dedicatedCrossOrigin =
        CapabilityManifestDistributionPolicy.fromConfiguration(
          endpointUrl: 'https://release.example.com/capability/manifest.json',
          allowedHostsCsv: 'release.example.com',
          runtimeOrigin: Uri.parse('https://app.example.com/'),
        );
    expect(dedicatedCrossOrigin.isConfigured, isTrue);
  });

  test(
    'trusted distribution fetch activates and then uses conditional GET',
    () async {
      final raw = await _signedEnvelope(
        algorithm: algorithm,
        keyPair: keyA,
        manifest: _manifest(
          now: now,
          values: const <SignedCapabilityId, bool>{
            SignedCapabilityId.localAiReranking: true,
          },
        ),
      );
      final contentEtag = _contentEtag(raw);
      var requests = 0;
      final distribution = CapabilityManifestDistributionClient(
        policy: _distributionPolicy(),
        client: MockClient((request) async {
          requests += 1;
          expect(request.method, 'GET');
          expect(request.followRedirects, isFalse);
          expect(request.bodyBytes, isEmpty);
          expect(request.headers, isNot(contains('authorization')));
          expect(request.headers, isNot(contains('cookie')));
          if (requests == 1) {
            expect(request.headers, isNot(contains('if-none-match')));
            return http.Response(
              raw,
              200,
              headers: <String, String>{
                'content-type': 'application/json; charset=utf-8',
                'etag': contentEtag,
              },
            );
          }
          expect(request.headers['if-none-match'], contentEtag);
          return http.Response(
            '',
            304,
            headers: <String, String>{'etag': contentEtag},
          );
        }),
      );
      final service = _service(
        store: MemoryCapabilityActivationStore(scope: 'distribution-success'),
        trust: trustA,
        now: now,
        distributionClient: distribution,
      );

      final first = await service.fetchAndActivate();
      expect(first.fetch.status, CapabilityManifestFetchStatus.fetched);
      expect(first.candidateActivated, isTrue);
      expect(
        first.snapshot.evaluate(SignedCapabilityId.localAiReranking).enabled,
        isTrue,
      );
      expect(first.fetch.byteCount, utf8.encode(raw).length);
      expect(first.fetch.etag, contentEtag);

      final second = await service.fetchAndActivate();
      expect(second.fetch.status, CapabilityManifestFetchStatus.notModified);
      expect(second.snapshot.hasActiveManifest, isTrue);
      expect(requests, 2);
    },
  );

  test(
    'accepted validator persists across restart and clears atomically',
    () async {
      final raw = await _signedEnvelope(
        algorithm: algorithm,
        keyPair: keyA,
        manifest: _manifest(now: now),
      );
      final etag = _contentEtag(raw);
      final store = MemoryCapabilityActivationStore(
        scope: 'distribution-restart',
      );
      final firstClient = CapabilityManifestDistributionClient(
        policy: _distributionPolicy(),
        client: MockClient(
          (_) async => http.Response(
            raw,
            200,
            headers: <String, String>{
              'content-type': 'application/json',
              'etag': etag,
            },
          ),
        ),
      );
      final first = _service(
        store: store,
        trust: trustA,
        now: now,
        distributionClient: firstClient,
      );
      final activated = await first.fetchAndActivate();
      expect(activated.candidateActivated, isTrue);
      expect(firstClient.acceptedEtag, etag);

      final persisted =
          jsonDecode((await store.read())!) as Map<String, dynamic>;
      expect(persisted[r'$schema'], capabilityActivationStateSchema);
      expect(persisted['distribution_cache'], isA<Map<String, dynamic>>());

      final restartedClient = CapabilityManifestDistributionClient(
        policy: _distributionPolicy(),
        client: MockClient((request) async {
          expect(request.headers['if-none-match'], etag);
          return http.Response(
            '',
            304,
            headers: <String, String>{'etag': etag},
          );
        }),
      );
      final restarted = _service(
        store: store,
        trust: trustA,
        now: now,
        distributionClient: restartedClient,
      );
      final loaded = await restarted.load();
      expect(loaded.hasActiveManifest, isTrue);
      expect(restartedClient.acceptedEtag, etag);
      expect(
        (await restarted.fetchAndActivate()).fetch.status,
        CapabilityManifestFetchStatus.notModified,
      );

      await restarted.clearToConservativeDefaults();
      expect(restartedClient.acceptedEtag, isNull);
      expect(await store.read(), isNull);
    },
  );

  test('concurrent fetches serialize through validator commit', () async {
    final raw = await _signedEnvelope(
      algorithm: algorithm,
      keyPair: keyA,
      manifest: _manifest(now: now),
    );
    final etag = _contentEtag(raw);
    final firstRequestStarted = Completer<void>();
    final releaseFirstResponse = Completer<void>();
    var requests = 0;
    final client = CapabilityManifestDistributionClient(
      policy: _distributionPolicy(),
      client: MockClient((request) async {
        requests += 1;
        if (requests == 1) {
          expect(request.headers['if-none-match'], isNull);
          firstRequestStarted.complete();
          await releaseFirstResponse.future;
          return http.Response(
            raw,
            200,
            headers: <String, String>{
              'content-type': 'application/json',
              'etag': etag,
            },
          );
        }
        expect(request.headers['if-none-match'], etag);
        return http.Response('', 304, headers: <String, String>{'etag': etag});
      }),
    );
    final service = _service(
      store: MemoryCapabilityActivationStore(scope: 'distribution-concurrency'),
      trust: trustA,
      now: now,
      distributionClient: client,
    );

    final first = service.fetchAndActivate();
    await firstRequestStarted.future;
    final second = service.fetchAndActivate();
    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);
    releaseFirstResponse.complete();

    expect((await first).candidateActivated, isTrue);
    expect(
      (await second).fetch.status,
      CapabilityManifestFetchStatus.notModified,
    );
    expect(requests, 2);
  });

  test('emergency clear preempts an in-flight fetched candidate', () async {
    final raw = await _signedEnvelope(
      algorithm: algorithm,
      keyPair: keyA,
      manifest: _manifest(now: now),
    );
    final etag = _contentEtag(raw);
    final requestStarted = Completer<void>();
    final releaseResponse = Completer<void>();
    final store = MemoryCapabilityActivationStore(
      scope: 'distribution-clear-preemption',
    );
    final client = CapabilityManifestDistributionClient(
      policy: _distributionPolicy(),
      client: MockClient((_) async {
        requestStarted.complete();
        await releaseResponse.future;
        return http.Response(
          raw,
          200,
          headers: <String, String>{
            'content-type': 'application/json',
            'etag': etag,
          },
        );
      }),
    );
    final service = _service(
      store: store,
      trust: trustA,
      now: now,
      distributionClient: client,
    );

    final pendingFetch = service.fetchAndActivate();
    await requestStarted.future;
    final cleared = await service.clearToConservativeDefaults();
    expect(cleared.activationStatus, CapabilityActivationStatus.cleared);
    expect(await store.read(), isNull);
    releaseResponse.complete();

    final staleFetch = await pendingFetch;
    expect(staleFetch.fetch.status, CapabilityManifestFetchStatus.fetched);
    expect(staleFetch.candidateActivated, isFalse);
    expect(staleFetch.snapshot.hasActiveManifest, isFalse);
    expect(client.acceptedEtag, isNull);
    expect(await store.read(), isNull);
  });

  test(
    'tampered persisted validator fails the activation state closed',
    () async {
      final raw = await _signedEnvelope(
        algorithm: algorithm,
        keyPair: keyA,
        manifest: _manifest(now: now),
      );
      final store = MemoryCapabilityActivationStore(
        scope: 'distribution-cache-tamper-seed',
      );
      final service = _service(
        store: store,
        trust: trustA,
        now: now,
        distributionClient: CapabilityManifestDistributionClient(
          policy: _distributionPolicy(),
          client: MockClient(
            (_) async => http.Response(
              raw,
              200,
              headers: <String, String>{
                'content-type': 'application/json',
                'etag': _contentEtag(raw),
              },
            ),
          ),
        ),
      );
      await service.fetchAndActivate();
      final tampered =
          jsonDecode((await store.read())!) as Map<String, dynamic>;
      (tampered['distribution_cache'] as Map<String, dynamic>)['etag'] =
          '"${'0' * 64}"';
      final restarted = _service(
        store: MemoryCapabilityActivationStore(
          scope: 'distribution-cache-tamper',
          initialValue: canonicalCapabilityJson(tampered),
        ),
        trust: trustA,
        now: now,
      );
      final loaded = await restarted.load();
      expect(
        loaded.activationStatus,
        CapabilityActivationStatus.conservativeDefaults,
      );
      expect(loaded.reason, 'persisted_activation_state_invalid');
      expect(loaded.hasActiveManifest, isFalse);
    },
  );

  test('endpoint change never reuses a persisted validator', () async {
    final raw = await _signedEnvelope(
      algorithm: algorithm,
      keyPair: keyA,
      manifest: _manifest(now: now),
    );
    final envelope = SignedCapabilityEnvelope.parseJson(raw);
    final etag = _contentEtag(raw);
    final store = MemoryCapabilityActivationStore(
      scope: 'distribution-endpoint-change',
      initialValue: CapabilityActivationState(
        activeEnvelope: envelope,
        activatedAtUtc: now,
        history: const <CapabilityManifestHistoryEntry>[],
        distributionCache: CapabilityDistributionCacheState(
          endpointLabel: 'https://old-release.example.com/manifest.json',
          etag: etag,
          contentSha256: etag.substring(1, etag.length - 1),
          manifestSha256: envelope.manifest.sha256,
          acceptedAtUtc: now,
        ),
      ).canonicalJson,
    );
    final client = CapabilityManifestDistributionClient(
      policy: _distributionPolicy(),
      client: MockClient((request) async {
        expect(request.headers['if-none-match'], isNull);
        return http.Response(
          raw,
          200,
          headers: <String, String>{
            'content-type': 'application/json',
            'etag': etag,
          },
        );
      }),
    );
    final service = _service(
      store: store,
      trust: trustA,
      now: now,
      distributionClient: client,
    );
    expect((await service.load()).hasActiveManifest, isTrue);
    expect(client.acceptedEtag, isNull);
    final refreshed = await service.fetchAndActivate();
    expect(refreshed.candidateActivated, isTrue);
    expect(
      refreshed.snapshot.distributionCache?.endpointLabel,
      'https://release.example.com/capability/manifest.json',
    );
  });

  test(
    'schema-v1 state migrates only after a verified fetched candidate',
    () async {
      final raw = await _signedEnvelope(
        algorithm: algorithm,
        keyPair: keyA,
        manifest: _manifest(now: now),
      );
      final seedStore = MemoryCapabilityActivationStore(
        scope: 'migration-seed',
      );
      await _service(store: seedStore, trust: trustA, now: now).activate(raw);
      final legacy =
          jsonDecode((await seedStore.read())!) as Map<String, dynamic>
            ..[r'$schema'] = 'parkinsum.capability-activation-state/1'
            ..remove('distribution_cache');
      final store = MemoryCapabilityActivationStore(
        scope: 'distribution-migration',
        initialValue: canonicalCapabilityJson(legacy),
      );
      final etag = _contentEtag(raw);
      final client = CapabilityManifestDistributionClient(
        policy: _distributionPolicy(),
        client: MockClient((request) async {
          expect(request.headers['if-none-match'], isNull);
          return http.Response(
            raw,
            200,
            headers: <String, String>{
              'content-type': 'application/json',
              'etag': etag,
            },
          );
        }),
      );
      final service = _service(
        store: store,
        trust: trustA,
        now: now,
        distributionClient: client,
      );
      expect((await service.load()).distributionCache, isNull);
      final migrated = await service.fetchAndActivate();
      expect(migrated.candidateActivated, isTrue);
      expect(migrated.snapshot.distributionCache?.etag, etag);
      final persisted =
          jsonDecode((await store.read())!) as Map<String, dynamic>;
      expect(persisted[r'$schema'], capabilityActivationStateSchema);
      expect(persisted['distribution_cache'], isNotNull);
    },
  );

  test(
    'validator commit recovers after persistence acknowledgement loss',
    () async {
      final raw = await _signedEnvelope(
        algorithm: algorithm,
        keyPair: keyA,
        manifest: _manifest(now: now),
      );
      final etag = _contentEtag(raw);
      final store = _WriteThenThrowStore(scope: 'distribution-ack-loss');
      final client = CapabilityManifestDistributionClient(
        policy: _distributionPolicy(),
        client: MockClient(
          (_) async => http.Response(
            raw,
            200,
            headers: <String, String>{
              'content-type': 'application/json',
              'etag': etag,
            },
          ),
        ),
      );
      final service = _service(
        store: store,
        trust: trustA,
        now: now,
        distributionClient: client,
      );
      final recovered = await service.fetchAndActivate();
      expect(
        recovered.snapshot.activationStatus,
        CapabilityActivationStatus.recoveredAfterAcknowledgementLoss,
      );
      expect(recovered.snapshot.distributionCache?.etag, etag);
      expect(client.acceptedEtag, etag);
    },
  );

  test(
    'distribution rejects redirects, wrong media, oversize, and bad ETag',
    () async {
      final cases = <(http.Response, CapabilityManifestFetchStatus)>[
        (
          http.Response(
            '',
            302,
            headers: const <String, String>{
              'location': 'https://other.example.com/manifest.json',
            },
          ),
          CapabilityManifestFetchStatus.redirectRejected,
        ),
        (
          http.Response(
            '{}',
            200,
            headers: const <String, String>{'content-type': 'text/html'},
          ),
          CapabilityManifestFetchStatus.contentTypeRejected,
        ),
        (
          http.Response(
            'x' * (capabilityManifestDistributionMaxBytes + 1),
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          ),
          CapabilityManifestFetchStatus.responseTooLarge,
        ),
        (
          http.Response(
            '{}',
            200,
            headers: const <String, String>{
              'content-type': 'application/json',
              'etag': 'unsafe\r\nheader',
            },
          ),
          CapabilityManifestFetchStatus.protocolRejected,
        ),
        (
          http.Response(
            '{}',
            200,
            headers: <String, String>{
              'content-type': 'application/json',
              'etag': '"${'0' * 64}"',
            },
          ),
          CapabilityManifestFetchStatus.protocolRejected,
        ),
      ];
      for (final testCase in cases) {
        final client = CapabilityManifestDistributionClient(
          policy: _distributionPolicy(),
          client: MockClient((_) async => testCase.$1),
        );
        expect((await client.fetch()).status, testCase.$2);
      }
    },
  );

  test(
    'distribution timeout and invalid candidate preserve last known good',
    () async {
      final timeoutClient = CapabilityManifestDistributionClient(
        policy: _distributionPolicy(timeout: const Duration(milliseconds: 1)),
        client: MockClient((_) => Completer<http.Response>().future),
      );
      expect(
        (await timeoutClient.fetch()).status,
        CapabilityManifestFetchStatus.timeout,
      );

      final valid = await _signedEnvelope(
        algorithm: algorithm,
        keyPair: keyA,
        manifest: _manifest(
          now: now,
          values: const <SignedCapabilityId, bool>{
            SignedCapabilityId.localAiReranking: true,
          },
        ),
      );
      final tampered = jsonDecode(valid) as Map<String, dynamic>;
      (tampered['signed'] as Map<String, dynamic>)['manifest_id'] =
          'tampered-after-signing';
      final tamperedBody = jsonEncode(tampered);
      final validEtag = _contentEtag(valid);
      var requests = 0;
      final distribution = CapabilityManifestDistributionClient(
        policy: _distributionPolicy(),
        client: MockClient((request) async {
          requests += 1;
          if (requests == 1) {
            expect(request.headers['if-none-match'], isNull);
            return http.Response(
              tamperedBody,
              200,
              headers: <String, String>{
                'content-type': 'application/json',
                'etag': _contentEtag(tamperedBody),
              },
            );
          }
          if (requests == 2) {
            expect(request.headers['if-none-match'], isNull);
            return http.Response(
              valid,
              200,
              headers: <String, String>{
                'content-type': 'application/json',
                'etag': validEtag,
              },
            );
          }
          expect(request.headers['if-none-match'], validEtag);
          return http.Response(
            '',
            304,
            headers: <String, String>{'etag': validEtag},
          );
        }),
      );
      final service = _service(
        store: MemoryCapabilityActivationStore(scope: 'distribution-lkg'),
        trust: trustA,
        now: now,
        distributionClient: distribution,
      );
      await service.activate(valid);
      final result = await service.fetchAndActivate();
      expect(result.fetch.status, CapabilityManifestFetchStatus.fetched);
      expect(
        result.snapshot.activationStatus,
        CapabilityActivationStatus.verificationRejected,
      );
      expect(result.snapshot.hasActiveManifest, isTrue);
      expect(
        result.snapshot.evaluate(SignedCapabilityId.localAiReranking).enabled,
        isTrue,
      );
      expect(distribution.acceptedEtag, isNull);
      expect(result.snapshot.distributionCache, isNull);

      final accepted = await service.fetchAndActivate();
      expect(accepted.candidateActivated, isTrue);
      expect(
        accepted.snapshot.activationStatus,
        CapabilityActivationStatus.idempotent,
      );
      expect(accepted.snapshot.distributionCache?.etag, validEtag);
      expect(distribution.acceptedEtag, validEtag);

      final notModified = await service.fetchAndActivate();
      expect(
        notModified.fetch.status,
        CapabilityManifestFetchStatus.notModified,
      );
      expect(requests, 3);
    },
  );

  testWidgets(
    'operator UI shows verified state and preserves LKG on rejection',
    (tester) async {
      final store = MemoryCapabilityActivationStore(scope: 'widget');
      final service = _service(store: store, trust: trustA, now: now);
      final manifest = _manifest(
        now: now,
        values: const <SignedCapabilityId, bool>{
          SignedCapabilityId.localAiReranking: true,
        },
      );
      final valid = await _signedEnvelope(
        algorithm: algorithm,
        keyPair: keyA,
        manifest: manifest,
      );
      await service.activate(valid);

      await pumpFeaturePage(
        tester,
        CapabilityRolloutPage(service: service),
        surfaceSize: const Size(1100, 2600),
      );
      await tester.pumpAndSettle();
      expectNoWidgetErrors(reason: 'capability rollout page failed');
      expect(find.text('Signed capability rollout'), findsOneWidget);
      expect(find.text('Current manifest verified'), findsOneWidget);
      expect(find.text('Enabled'), findsOneWidget);

      final tampered = jsonDecode(valid) as Map<String, dynamic>;
      (tampered['signature'] as Map<String, dynamic>)['value_base64url'] =
          base64Url.encode(List<int>.filled(64, 9)).replaceAll('=', '');
      await tester.enterText(
        find.byKey(const ValueKey('rollout-manifest-input')),
        jsonEncode(tampered),
      );
      final activateButton = find.byKey(const ValueKey('rollout-activate'));
      await tester.scrollUntilVisible(
        activateButton,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(activateButton);
      await tester.pumpAndSettle();
      expectNoWidgetErrors(reason: 'rejected manifest should remain visible');
      expect(find.text('verificationRejected'), findsOneWidget);
      expect(find.text('Current manifest verified'), findsOneWidget);
      expect(find.text('Enabled'), findsOneWidget);
    },
  );

  testWidgets('operator UI exposes the configured trusted distribution route', (
    tester,
  ) async {
    final service = _service(
      store: MemoryCapabilityActivationStore(scope: 'distribution-widget'),
      trust: trustA,
      now: now,
      distributionClient: CapabilityManifestDistributionClient(
        policy: _distributionPolicy(),
        client: MockClient((_) async => http.Response('', 500)),
      ),
    );
    await pumpFeaturePage(
      tester,
      CapabilityRolloutPage(service: service),
      surfaceSize: const Size(1100, 2800),
    );
    await tester.pumpAndSettle();
    final fetchButton = find.byKey(const ValueKey('rollout-fetch'));

    expectNoWidgetErrors(reason: 'trusted distribution route UI failed');
    expect(fetchButton, findsOneWidget);
    expect(tester.widget<OutlinedButton>(fetchButton).onPressed, isNotNull);
    expect(
      find.text('https://release.example.com/capability/manifest.json'),
      findsOneWidget,
    );
    expect(
      find.text('Strict HTTPS release endpoint configured'),
      findsOneWidget,
    );
  });

  testWidgets('operator UI exposes the atomically accepted cache identity', (
    tester,
  ) async {
    final raw = await _signedEnvelope(
      algorithm: algorithm,
      keyPair: keyA,
      manifest: _manifest(now: now),
    );
    final etag = _contentEtag(raw);
    final envelope = SignedCapabilityEnvelope.parseJson(raw);
    final store = MemoryCapabilityActivationStore(
      scope: 'distribution-cache-ui',
    );
    await store.writeExact(
      CapabilityActivationState(
        activeEnvelope: envelope,
        activatedAtUtc: now,
        history: const <CapabilityManifestHistoryEntry>[],
        distributionCache: CapabilityDistributionCacheState(
          endpointLabel: 'https://release.example.com/capability/manifest.json',
          etag: etag,
          contentSha256: etag.substring(1, etag.length - 1),
          manifestSha256: envelope.manifest.sha256,
          acceptedAtUtc: now,
        ),
      ).canonicalJson,
    );
    final service = _service(
      store: store,
      trust: trustA,
      now: now,
      distributionClient: CapabilityManifestDistributionClient(
        policy: _distributionPolicy(),
        client: MockClient(
          (_) async => http.Response(
            raw,
            200,
            headers: <String, String>{
              'content-type': 'application/json',
              'etag': etag,
            },
          ),
        ),
      ),
    );
    final manifestDigest = envelope.manifest.sha256;

    await pumpFeaturePage(
      tester,
      CapabilityRolloutPage(service: service),
      surfaceSize: const Size(1100, 3000),
    );
    for (var frame = 0; frame < 8; frame += 1) {
      await tester.pump(const Duration(milliseconds: 25));
    }

    expectNoWidgetErrors(reason: 'accepted distribution cache UI failed');
    expect(
      find.text('Atomically bound to the current signed manifest'),
      findsOneWidget,
    );
    expect(find.text(etag), findsOneWidget);
    expect(find.text(manifestDigest), findsOneWidget);
    expect(find.text(now.toIso8601String()), findsOneWidget);
  });
}

CapabilityRolloutService _service({
  required CapabilityActivationStore store,
  required CapabilityTrustPolicy trust,
  required DateTime now,
  CapabilityManifestDistributionClient? distributionClient,
}) => CapabilityRolloutService(
  store: store,
  verifier: SignedCapabilityManifestVerifier(trustPolicy: trust),
  distributionClient: distributionClient,
  utcNow: () => now,
);

CapabilityManifestDistributionPolicy _distributionPolicy({
  Duration timeout = const Duration(seconds: 1),
}) => CapabilityManifestDistributionPolicy.fromConfiguration(
  endpointUrl: 'https://release.example.com/capability/manifest.json',
  allowedHostsCsv: 'release.example.com',
  timeout: timeout,
);

String _contentEtag(String value) => '"${sha256.convert(utf8.encode(value))}"';

SignedCapabilityManifest _manifest({
  required DateTime now,
  String manifestId = 'manifest-1',
  int sequence = 1,
  String keyId = 'key-a',
  String environment = 'staging',
  DateTime? issuedAt,
  DateTime? notBefore,
  DateTime? expiresAt,
  String? previous,
  CapabilityManifestReason reason = CapabilityManifestReason.stagedEnable,
  CapabilityRollbackTarget? rollbackTarget,
  Map<SignedCapabilityId, bool> values = const <SignedCapabilityId, bool>{},
}) {
  final capabilities =
      SignedCapabilityId.values
          .map(
            (id) => SignedCapabilityValue(id: id, enabled: values[id] ?? false),
          )
          .toList()
        ..sort((left, right) => left.id.wireName.compareTo(right.id.wireName));
  return SignedCapabilityManifest(
    manifestId: manifestId,
    sequence: sequence,
    issuer: 'parkinsum-release',
    keyId: keyId,
    environment: environment,
    issuedAtUtc: issuedAt ?? now.subtract(const Duration(minutes: 1)),
    notBeforeUtc: notBefore ?? now.subtract(const Duration(minutes: 1)),
    expiresAtUtc: expiresAt ?? now.add(const Duration(days: 7)),
    reason: reason,
    previousManifestSha256: previous,
    rollbackTarget: rollbackTarget,
    capabilities: capabilities,
  );
}

Future<String> _signedEnvelope({
  required Ed25519 algorithm,
  required SimpleKeyPair keyPair,
  required SignedCapabilityManifest manifest,
}) async {
  final signature = await algorithm.sign(
    utf8.encode(manifest.canonicalJson),
    keyPair: keyPair,
  );
  return SignedCapabilityEnvelope(
    manifest: manifest,
    signatureBase64Url: base64Url.encode(signature.bytes).replaceAll('=', ''),
  ).canonicalJson;
}

final class _BlockingFirstWriteStore implements CapabilityActivationStore {
  _BlockingFirstWriteStore({required this.scope});

  final String scope;
  final firstWriteStarted = Completer<void>();
  final releaseFirstWrite = Completer<void>();
  String? _value;
  bool _didBlock = false;

  @override
  String get mutationScope => scope;

  @override
  Future<void> clear() async => _value = null;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> writeExact(String canonicalState) async {
    if (!_didBlock) {
      _didBlock = true;
      firstWriteStarted.complete();
      await releaseFirstWrite.future;
    }
    _value = canonicalState;
  }
}

final class _WriteThenThrowStore implements CapabilityActivationStore {
  _WriteThenThrowStore({required this.scope});

  final String scope;
  String? _value;

  @override
  String get mutationScope => scope;

  @override
  Future<void> clear() async => _value = null;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> writeExact(String canonicalState) async {
    _value = canonicalState;
    throw StateError('acknowledgement_lost');
  }
}

final class _ThrowBeforeWriteStore implements CapabilityActivationStore {
  _ThrowBeforeWriteStore({required this.scope});

  final String scope;

  @override
  String get mutationScope => scope;

  @override
  Future<void> clear() async => throw StateError('write_failed');

  @override
  Future<String?> read() async => null;

  @override
  Future<void> writeExact(String canonicalState) async =>
      throw StateError('write_failed');
}
