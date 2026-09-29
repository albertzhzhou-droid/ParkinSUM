import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/services/reminder_notification_capability_matrix.dart';
import 'package:parkinsum_companion/core/services/reminder_notification_run_attestation.dart';

const _headSha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _treeSha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _sourceSha =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _apkSha =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const _changedApkSha =
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
const _pubspecLockSha =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _sourceManifestSha =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _mergedManifestSha =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _apkManifestTreeSha =
    '5555555555555555555555555555555555555555555555555555555555555555';
const _outputMetadataSha =
    '4444444444444444444444444444444444444444444444444444444444444444';
const _pluginPackageSha =
    '1447ba911c60f2ba3f25dae1af151ec187162566b0f57e37771bf0b400f013ad';
const _certificateSha =
    'd5106acb503a636166825b4ed0f792d50fa01da0b15e9f05c44c1efac06e0914';
const _apksignerJarSha =
    '6666666666666666666666666666666666666666666666666666666666666666';
const _ownerIdentitySha =
    '7777777777777777777777777777777777777777777777777777777777777777';
const _buildResourceKeySha =
    '8888888888888888888888888888888888888888888888888888888888888888';
const _deviceResourceKeySha =
    '9999999999999999999999999999999999999999999999999999999999999999';
const _buildOwnerTokenSha =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _deviceOwnerTokenSha =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _leaseEvidenceSha =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
const _runId = 'reminder-run-20260830-0001';

void main() {
  group('Android reminder run attestation', () {
    test('dirty development evidence round-trips with a canonical digest', () {
      final attestation = _fixture();

      expect(attestation.pass, isTrue);
      expect(attestation.source.dirty, isTrue);
      expect(attestation.releaseEligible, isFalse);
      expect(attestation.claims.visibleDeliveryVerified, isFalse);
      expect(attestation.platformBinding.notificationPluginVersion, '22.3.0');
      expect(attestation.executionIsolation.resources, hasLength(2));
      expect(
        attestation.executionIsolation.leaseEvidenceSha256,
        _leaseEvidenceSha,
      );
      expect(
        attestation.executionIsolation.resources.map((value) => value.kind),
        [
          ReminderNotificationRunExecutionResourceKind.buildOutput,
          ReminderNotificationRunExecutionResourceKind.deviceApplication,
        ],
      );
      final reportData =
          attestation.integration.toJson()['report_data']
              as Map<String, Object?>;
      expect(reportData, hasLength(30));
      expect(reportData['source_state_bound'], isTrue);
      expect(reportData['alarm_manager_inspected'], isFalse);
      expect(reportData['effective_lockscreen_visibility_inspected'], isFalse);
      expect(
        attestation.integration.reportDataSha256,
        matches(RegExp(r'^[a-f0-9]{64}$')),
      );

      final decoded = ReminderNotificationRunAttestation.fromJson(
        _deepJson(attestation.toJson()),
      );
      expect(decoded.toJson(), attestation.toJson());
      expect(decoded.canonicalJson, attestation.canonicalJson);
      expect(decoded.contentSha256, attestation.contentSha256);
      expect(decoded.contentSha256, matches(RegExp(r'^[a-f0-9]{64}$')));

      final reversed = Map<String, Object?>.fromEntries(
        attestation.toJson().entries.toList().reversed,
      );
      expect(
        ReminderNotificationRunAttestation.fromJson(reversed).contentSha256,
        attestation.contentSha256,
      );
    });

    test('candidate evidence is clean and release eligibility is derived', () {
      final candidate = _fixture(
        mode: ReminderNotificationRunMode.candidate,
        dirty: false,
        buildMode: 'release',
      );

      expect(candidate.pass, isTrue);
      expect(candidate.releaseEligible, isFalse);

      expect(
        () => _fixture(
          mode: ReminderNotificationRunMode.candidate,
          dirty: true,
          releaseEligible: false,
        ),
        throwsFormatException,
      );
      expect(
        () => _fixture(dirty: true, releaseEligible: true),
        throwsFormatException,
      );
      expect(
        () => _fixture(
          mode: ReminderNotificationRunMode.candidate,
          dirty: false,
          buildMode: 'release',
          releaseEligible: true,
        ),
        throwsFormatException,
      );
    });

    test('failed evidence retains drift without becoming release eligible', () {
      final failed = _fixture(
        pass: false,
        sourcePrePostMatch: false,
        artifactExecutionBound: false,
        failures: const ['source_pre_post_drift'],
      );

      expect(failed.pass, isFalse);
      expect(failed.releaseEligible, isFalse);
      expect(
        ReminderNotificationRunAttestation.fromJson(
          _deepJson(failed.toJson()),
        ).toJson(),
        failed.toJson(),
      );
      expect(
        () => _fixture(pass: true, failures: const ['invented_failure']),
        throwsFormatException,
      );
      expect(
        () => _fixture(pass: false, failures: const []),
        throwsFormatException,
      );
    });

    test(
      'top-level and nested schemas reject extra, missing, historical, and future data',
      () {
        final base = _fixture();

        final extra = _deepJson(base.toJson())..['unexpected'] = true;
        expect(
          () => ReminderNotificationRunAttestation.fromJson(extra),
          throwsFormatException,
        );

        final missing = _deepJson(base.toJson())..remove('boundary');
        expect(
          () => ReminderNotificationRunAttestation.fromJson(missing),
          throwsFormatException,
        );

        final historical = _deepJson(base.toJson())
          ..['schema_version'] = 3
          ..[r'$schema'] = 'parkinsum.android-reminder-run-attestation/3';
        expect(
          () => ReminderNotificationRunAttestation.fromJson(historical),
          throwsFormatException,
        );

        final future = _deepJson(base.toJson())..['schema_version'] = 5;
        expect(
          () => ReminderNotificationRunAttestation.fromJson(future),
          throwsFormatException,
        );

        final futureSchema = _deepJson(base.toJson())
          ..[r'$schema'] = 'parkinsum.android-reminder-run-attestation/5';
        expect(
          () => ReminderNotificationRunAttestation.fromJson(futureSchema),
          throwsFormatException,
        );

        final missingIsolation = _deepJson(base.toJson())
          ..remove('execution_isolation');
        expect(
          () => ReminderNotificationRunAttestation.fromJson(missingIsolation),
          throwsFormatException,
        );

        final nestedExtra = _deepJson(base.toJson());
        (nestedExtra['source'] as Map<String, Object?>)['unexpected'] = true;
        expect(
          () => ReminderNotificationRunAttestation.fromJson(nestedExtra),
          throwsFormatException,
        );

        final reportExtra = _deepJson(base.toJson());
        _reportData(reportExtra)['unexpected'] = true;
        expect(
          () => ReminderNotificationRunAttestation.fromJson(reportExtra),
          throwsFormatException,
        );

        final futureReport = _deepJson(base.toJson());
        _reportData(futureReport)['schema_version'] = 5;
        expect(
          () => ReminderNotificationRunAttestation.fromJson(futureReport),
          throwsFormatException,
        );
      },
    );

    test('execution isolation schemas reject missing and unknown keys', () {
      final base = _fixture();

      final extra = _deepJson(base.toJson());
      _executionIsolationData(extra)['unexpected'] = true;
      expect(
        () => ReminderNotificationRunAttestation.fromJson(extra),
        throwsFormatException,
      );

      final missing = _deepJson(base.toJson());
      _executionIsolationData(missing).remove('lease_evidence_sha256');
      expect(
        () => ReminderNotificationRunAttestation.fromJson(missing),
        throwsFormatException,
      );

      final historical = _deepJson(base.toJson());
      _executionIsolationData(historical)
        ..['schema_version'] = 1
        ..['schema_uri'] = 'parkinsum.android-reminder-execution-isolation/1';
      expect(
        () => ReminderNotificationRunAttestation.fromJson(historical),
        throwsFormatException,
      );

      final futureVersion = _deepJson(base.toJson());
      _executionIsolationData(futureVersion)['schema_version'] = 3;
      expect(
        () => ReminderNotificationRunAttestation.fromJson(futureVersion),
        throwsFormatException,
      );

      final futureSchema = _deepJson(base.toJson());
      _executionIsolationData(futureSchema)['schema_uri'] =
          'parkinsum.android-reminder-execution-isolation/3';
      expect(
        () => ReminderNotificationRunAttestation.fromJson(futureSchema),
        throwsFormatException,
      );

      final resourceExtra = _deepJson(base.toJson());
      (_executionResources(resourceExtra).first
              as Map<String, Object?>)['unexpected'] =
          true;
      expect(
        () => ReminderNotificationRunAttestation.fromJson(resourceExtra),
        throwsFormatException,
      );

      final resourceMissing = _deepJson(base.toJson());
      (_executionResources(resourceMissing).first as Map<String, Object?>)
          .remove('owner_token_sha256');
      expect(
        () => ReminderNotificationRunAttestation.fromJson(resourceMissing),
        throwsFormatException,
      );
    });

    test('execution resources and process identity fail closed on drift', () {
      final base = _fixture();

      final invalidDigest = _deepJson(base.toJson());
      (_executionResources(invalidDigest).first
              as Map<String, Object?>)['resource_key_sha256'] =
          'not-a-digest';
      expect(
        () => ReminderNotificationRunAttestation.fromJson(invalidDigest),
        throwsFormatException,
      );

      final invalidLeaseEvidenceDigest = _deepJson(base.toJson());
      _executionIsolationData(
        invalidLeaseEvidenceDigest,
      )['lease_evidence_sha256'] = 'not-a-digest';
      expect(
        () => ReminderNotificationRunAttestation.fromJson(
          invalidLeaseEvidenceDigest,
        ),
        throwsFormatException,
      );

      final duplicateKind = _deepJson(base.toJson());
      (_executionResources(duplicateKind)[1] as Map<String, Object?>)['kind'] =
          'buildOutput';
      expect(
        () => ReminderNotificationRunAttestation.fromJson(duplicateKind),
        throwsFormatException,
      );

      final duplicateKey = _deepJson(base.toJson());
      (_executionResources(duplicateKey)[1]
              as Map<String, Object?>)['resource_key_sha256'] =
          _buildResourceKeySha;
      expect(
        () => ReminderNotificationRunAttestation.fromJson(duplicateKey),
        throwsFormatException,
      );

      final duplicateToken = _deepJson(base.toJson());
      (_executionResources(duplicateToken)[1]
              as Map<String, Object?>)['owner_token_sha256'] =
          _buildOwnerTokenSha;
      expect(
        () => ReminderNotificationRunAttestation.fromJson(duplicateToken),
        throwsFormatException,
      );

      final keyTokenCollision = _deepJson(base.toJson());
      (_executionResources(keyTokenCollision)[1]
              as Map<String, Object?>)['owner_token_sha256'] =
          _buildResourceKeySha;
      expect(
        () => ReminderNotificationRunAttestation.fromJson(keyTokenCollision),
        throwsFormatException,
      );

      final unsupportedProvider = _deepJson(base.toJson());
      _executionIsolationData(unsupportedProvider)['process_start_provider'] =
          'pidOnly';
      expect(
        () => ReminderNotificationRunAttestation.fromJson(unsupportedProvider),
        throwsFormatException,
      );

      final darwinReclaim = _deepJson(base.toJson());
      _executionIsolationData(darwinReclaim)['stale_reclaims'] = 1;
      expect(
        () => ReminderNotificationRunAttestation.fromJson(darwinReclaim),
        throwsFormatException,
      );
    });

    test('execution timing and ownership checkpoint sequence fail closed', () {
      final base = _fixture();

      final zeroHeartbeat = _deepJson(base.toJson());
      _executionIsolationData(zeroHeartbeat)['heartbeat_interval_ms'] = 0;
      expect(
        () => ReminderNotificationRunAttestation.fromJson(zeroHeartbeat),
        throwsFormatException,
      );

      final prematureStale = _deepJson(base.toJson());
      _executionIsolationData(prematureStale)['stale_after_ms'] = 2999;
      expect(
        () => ReminderNotificationRunAttestation.fromJson(prematureStale),
        throwsFormatException,
      );

      for (final staleReclaims in [-1, 3]) {
        final invalidReclaims = _deepJson(base.toJson());
        _executionIsolationData(invalidReclaims)['stale_reclaims'] =
            staleReclaims;
        expect(
          () => ReminderNotificationRunAttestation.fromJson(invalidReclaims),
          throwsFormatException,
        );
      }

      final missingCheckpoint = _deepJson(base.toJson());
      (_executionIsolationData(missingCheckpoint)['checkpoints'] as List)
          .removeLast();
      expect(
        () => ReminderNotificationRunAttestation.fromJson(missingCheckpoint),
        throwsFormatException,
      );

      final reorderedCheckpoints = _deepJson(base.toJson());
      final checkpoints =
          _executionIsolationData(reorderedCheckpoints)['checkpoints'] as List;
      final first = checkpoints[0];
      checkpoints[0] = checkpoints[1];
      checkpoints[1] = first;
      expect(
        () => ReminderNotificationRunAttestation.fromJson(reorderedCheckpoints),
        throwsFormatException,
      );
    });

    test('execution ownership booleans are mandatory mechanical facts', () {
      final base = _fixture();
      for (final field in [
        'continuous_ownership_verified',
        'children_drained_before_device_cleanup',
        'device_cleanup_completed_while_owned',
      ]) {
        final drifted = _deepJson(base.toJson());
        _executionIsolationData(drifted)[field] = false;
        expect(
          () => ReminderNotificationRunAttestation.fromJson(drifted),
          throwsFormatException,
        );
      }
    });

    test('source, APK, device, and capability drift fail closed', () {
      final base = _fixture();

      final sourceDrift = _deepJson(base.toJson());
      (sourceDrift['source'] as Map<String, Object?>)['pre_post_match'] = false;
      expect(
        () => ReminderNotificationRunAttestation.fromJson(sourceDrift),
        throwsFormatException,
      );

      final apkDrift = _deepJson(base.toJson());
      (apkDrift['artifact'] as Map<String, Object?>)['sha256_after_run'] =
          _changedApkSha;
      expect(
        () => ReminderNotificationRunAttestation.fromJson(apkDrift),
        throwsFormatException,
      );

      final productionPackage = _deepJson(base.toJson());
      (productionPackage['artifact']
              as Map<String, Object?>)['application_id'] =
          'com.parkinsum.companion';
      expect(
        () => ReminderNotificationRunAttestation.fromJson(productionPackage),
        throwsFormatException,
      );

      final signerDrift = _deepJson(base.toJson());
      final signer =
          (signerDrift['artifact'] as Map<String, Object?>)['signing']
              as Map<String, Object?>;
      signer['certificate_sha256'] = 'not-a-digest';
      expect(
        () => ReminderNotificationRunAttestation.fromJson(signerDrift),
        throwsFormatException,
      );

      final schemeDrift = _deepJson(base.toJson());
      ((schemeDrift['artifact'] as Map<String, Object?>)['signing']
          as Map<String, Object?>)['verified_schemes'] = <Object?>[
        'v3',
      ];
      expect(
        () => ReminderNotificationRunAttestation.fromJson(schemeDrift),
        throwsFormatException,
      );

      final deviceDrift = _deepJson(base.toJson());
      (deviceDrift['device'] as Map<String, Object?>)['primary_abi'] =
          'armeabi-v7a';
      expect(
        () => ReminderNotificationRunAttestation.fromJson(deviceDrift),
        throwsFormatException,
      );

      final sandboxDrift = _deepJson(base.toJson());
      (sandboxDrift['device']
              as Map<String, Object?>)['application_id_removed_after_run'] =
          false;
      expect(
        () => ReminderNotificationRunAttestation.fromJson(sandboxDrift),
        throwsFormatException,
      );

      final capabilityDrift = _deepJson(base.toJson());
      (capabilityDrift['capability']
              as Map<String, Object?>)['manifest_sha256'] =
          _changedApkSha;
      expect(
        () => ReminderNotificationRunAttestation.fromJson(capabilityDrift),
        throwsFormatException,
      );

      final reportDigestDrift = _deepJson(base.toJson());
      (reportDigestDrift['integration']
              as Map<String, Object?>)['report_data_sha256'] =
          _changedApkSha;
      expect(
        () => ReminderNotificationRunAttestation.fromJson(reportDigestDrift),
        throwsFormatException,
      );
    });

    test('platform lock, manifest, SDK, and build-mode facts fail closed', () {
      final base = _fixture();

      final pluginDrift = _deepJson(base.toJson());
      (pluginDrift['platform_binding']
              as Map<String, Object?>)['notification_plugin_version'] =
          '22.3.1';
      expect(
        () => ReminderNotificationRunAttestation.fromJson(pluginDrift),
        throwsFormatException,
      );

      final permissionDeclarationDrift = _deepJson(base.toJson());
      (permissionDeclarationDrift['platform_binding']
              as Map<String, Object?>)['post_notifications_declared'] =
          false;
      expect(
        () => ReminderNotificationRunAttestation.fromJson(
          permissionDeclarationDrift,
        ),
        throwsFormatException,
      );

      final sdkDrift = _deepJson(base.toJson());
      (sdkDrift['platform_binding'] as Map<String, Object?>)['min_sdk'] = 23;
      expect(
        () => ReminderNotificationRunAttestation.fromJson(sdkDrift),
        throwsFormatException,
      );

      final modeDrift = _deepJson(base.toJson());
      (modeDrift['platform_binding'] as Map<String, Object?>)['build_mode'] =
          'profile';
      expect(
        () => ReminderNotificationRunAttestation.fromJson(modeDrift),
        throwsFormatException,
      );
    });

    test(
      'permission, user data, visible delivery, and non-7-to-0 claims fail',
      () {
        final base = _fixture();

        final permission = _deepJson(base.toJson());
        _reportData(permission)['permission'] = 'returned-allowed';
        expect(
          () => ReminderNotificationRunAttestation.fromJson(permission),
          throwsFormatException,
        );

        final userData = _deepJson(base.toJson());
        _reportData(userData)['real_user_data_accessed'] = true;
        expect(
          () => ReminderNotificationRunAttestation.fromJson(userData),
          throwsFormatException,
        );

        final configuredCopy = _deepJson(base.toJson());
        _reportData(configuredCopy)['configured_copy_contains_user_label'] =
            true;
        expect(
          () => ReminderNotificationRunAttestation.fromJson(configuredCopy),
          throwsFormatException,
        );

        final uninspectedSystemResult = _deepJson(base.toJson());
        _reportData(
          uninspectedSystemResult,
        )['system_visible_copy_contains_user_label'] = false;
        expect(
          () => ReminderNotificationRunAttestation.fromJson(
            uninspectedSystemResult,
          ),
          throwsFormatException,
        );

        final visible = _deepJson(base.toJson());
        _reportData(visible)['visible_delivery_verified'] = true;
        (visible['claims']
                as Map<String, Object?>)['visible_delivery_verified'] =
            true;
        expect(
          () => ReminderNotificationRunAttestation.fromJson(visible),
          throwsFormatException,
        );

        final wrongScheduledCount = _deepJson(base.toJson());
        _reportData(
          wrongScheduledCount,
        )['plugin_reported_pending_after_schedule'] = 6;
        expect(
          () =>
              ReminderNotificationRunAttestation.fromJson(wrongScheduledCount),
          throwsFormatException,
        );

        final wrongClearCount = _deepJson(base.toJson());
        _reportData(wrongClearCount)['plugin_reported_pending_after_clear'] = 1;
        expect(
          () => ReminderNotificationRunAttestation.fromJson(wrongClearCount),
          throwsFormatException,
        );
      },
    );

    test('caller-owned lists are copied and exposed as unmodifiable', () {
      final abis = <String>['x86_64', 'arm64-v8a'];
      final failures = <String>[];
      final attestation = _fixture(nativeAbis: abis, failures: failures);

      abis.add('x86');
      failures.add('late_mutation');
      expect(attestation.artifact.nativeAbis, ['arm64-v8a', 'x86_64']);
      expect(attestation.failures, isEmpty);
      expect(
        () => attestation.artifact.nativeAbis.add('x86'),
        throwsUnsupportedError,
      );
      expect(
        () => attestation.failures.add('mutation'),
        throwsUnsupportedError,
      );
      expect(
        () => attestation.executionIsolation.resources.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => attestation.executionIsolation.checkpoints.clear(),
        throwsUnsupportedError,
      );
    });
  });
}

ReminderNotificationRunAttestation _fixture({
  ReminderNotificationRunMode mode = ReminderNotificationRunMode.development,
  bool dirty = true,
  bool pass = true,
  bool sourcePrePostMatch = true,
  bool artifactExecutionBound = true,
  bool releaseEligible = false,
  String buildMode = 'debug',
  Iterable<String> failures = const [],
  Iterable<String> nativeAbis = const ['arm64-v8a', 'x86_64'],
}) {
  final matrix = ReminderNotificationCapabilityMatrix.current;
  final profile = matrix.profileFor(ReminderNotificationPlatform.android);
  final source = ReminderNotificationRunSource(
    headSha: _headSha,
    headTreeSha: _treeSha,
    dirty: dirty,
    sourceStateSha256: _sourceSha,
    prePostMatch: sourcePrePostMatch,
  );
  final artifact = ReminderNotificationRunArtifact(
    fileName: 'app-$buildMode.apk',
    sha256Digest: _apkSha,
    bytes: 123456,
    sha256AfterRun: _apkSha,
    stable: true,
    applicationId: 'com.parkinsum.companion.reminderattestation',
    applicationLabel: 'ParkinSUM Reminder Attestation',
    buildConfiguration: 'reminder_attestation',
    versionCode: 2,
    versionName: '0.2.0',
    variant: buildMode,
    entrypoint: ReminderNotificationRunArtifact.requiredEntrypoint,
    debuggable: buildMode == 'debug',
    minSdk: 24,
    targetSdk: 36,
    nativeAbis: nativeAbis,
    installedBaseSha256: _apkSha,
    installedBaseBytes: 123456,
    installedMatchesInput: true,
    splitCount: 1,
    signing: ReminderNotificationRunSigning(
      signatureVerified: true,
      signerCount: 1,
      certificateSha256: _certificateSha,
      verifiedSchemes: const ['v2'],
      warningsAsErrors: true,
      buildToolsRevision: '36.1.0',
      apksignerVersion: '0.9',
      apksignerJarSha256: _apksignerJarSha,
      identityAssurance: mode == ReminderNotificationRunMode.candidate
          ? ReminderNotificationSignerIdentityAssurance.reviewedAttestation
          : ReminderNotificationSignerIdentityAssurance.observedUnreviewed,
      expectedCertificateSha256: mode == ReminderNotificationRunMode.candidate
          ? _certificateSha
          : null,
      expectedCertificateMatch: mode == ReminderNotificationRunMode.candidate,
    ),
  );
  final platformBinding = ReminderNotificationRunPlatformBinding(
    pubspecLockSha256: _pubspecLockSha,
    notificationPluginVersion: ReminderNotificationRunPlatformBinding
        .requiredNotificationPluginVersion,
    notificationPluginPackageSha256: _pluginPackageSha,
    sourceManifestSha256: _sourceManifestSha,
    mergedManifestSha256: _mergedManifestSha,
    apkManifestTreeSha256: _apkManifestTreeSha,
    outputMetadataSha256: _outputMetadataSha,
    compileSdk: 36,
    minSdk: 24,
    targetSdk: 36,
    postNotificationsDeclared: true,
    rebootReceiversDeclared: true,
    buildMode: buildMode,
  );
  final device = ReminderNotificationRunDevice(
    sdkInt: 36,
    androidRelease: '16',
    supportedAbis: const ['x86_64', 'arm64-v8a'],
    primaryAbi: 'x86_64',
    deviceKind: ReminderNotificationDeviceKind.emulator,
    prePostMatch: true,
    applicationIdAbsentBeforeInstall: true,
    applicationIdRemovedAfterRun: true,
  );
  final executionIsolation = ReminderNotificationRunExecutionIsolation(
    ownerIdentitySha256: _ownerIdentitySha,
    processStartProvider:
        ReminderNotificationProcessStartProvider.darwinNoReclaim,
    heartbeatIntervalMs: 1000,
    staleAfterMs: 3000,
    staleReclaims: 0,
    resources: [
      ReminderNotificationRunExecutionResource(
        kind: ReminderNotificationRunExecutionResourceKind.deviceApplication,
        resourceKeySha256: _deviceResourceKeySha,
        ownerTokenSha256: _deviceOwnerTokenSha,
      ),
      ReminderNotificationRunExecutionResource(
        kind: ReminderNotificationRunExecutionResourceKind.buildOutput,
        resourceKeySha256: _buildResourceKeySha,
        ownerTokenSha256: _buildOwnerTokenSha,
      ),
    ],
    checkpoints: ReminderNotificationRunExecutionIsolation.requiredCheckpoints,
    leaseEvidenceSha256: _leaseEvidenceSha,
    continuousOwnershipVerified: true,
    childrenDrainedBeforeDeviceCleanup: true,
    deviceCleanupCompletedWhileOwned: true,
  );
  final capability = ReminderNotificationRunCapability(
    schema: ReminderNotificationCapabilityMatrix.schema,
    schemaVersion: ReminderNotificationCapabilityMatrix.schemaVersion,
    manifestSha256: matrix.manifestSha256,
    profileSha256: profile.contentSha256,
    platform: ReminderNotificationPlatform.android.name,
    deliveryMode: ReminderNotificationDeliveryMode.scheduled.name,
  );
  final integration = ReminderNotificationRunIntegrationObservation.create(
    runId: _runId,
    sourceHeadSha: source.headSha,
    sourceStateSha256: source.sourceStateSha256,
    buildMode: platformBinding.buildMode,
    notificationCapabilitySchema: capability.schema,
    notificationCapabilitySchemaVersion: capability.schemaVersion,
    notificationCapabilityManifestSha256: capability.manifestSha256,
    notificationCapabilityProfileSha256: capability.profileSha256,
  );
  return ReminderNotificationRunAttestation(
    runId: _runId,
    mode: mode,
    pass: pass,
    failures: failures,
    source: source,
    artifact: artifact,
    platformBinding: platformBinding,
    device: device,
    executionIsolation: executionIsolation,
    capability: capability,
    integration: integration,
    claims: ReminderNotificationRunClaims(
      artifactExecutionBound: artifactExecutionBound,
      schedulerRegistryRoundTripObserved: true,
      visibleDeliveryVerified: false,
      releaseEligible: releaseEligible,
    ),
  );
}

Map<String, Object?> _deepJson(Map<String, Object?> value) =>
    Map<String, Object?>.from(jsonDecode(jsonEncode(value)) as Map);

Map<String, Object?> _reportData(Map<String, Object?> attestation) {
  final integration = attestation['integration'] as Map<String, Object?>;
  return integration['report_data'] as Map<String, Object?>;
}

Map<String, Object?> _executionIsolationData(
  Map<String, Object?> attestation,
) => attestation['execution_isolation'] as Map<String, Object?>;

List<Object?> _executionResources(Map<String, Object?> attestation) =>
    _executionIsolationData(attestation)['resources'] as List<Object?>;
