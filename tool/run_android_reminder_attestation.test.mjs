import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { describe, test } from 'node:test';

import {
  AndroidAttestationChildSupervisor,
  AttestationAbortError,
} from './android_attestation_child_supervisor.mjs';
import { AndroidAttestationProcessIdentityDisappearedError } from './android_attestation_exclusive_lease.mjs';

import {
  attestationBoundary,
  attestationSchema,
  attestationSchemaVersion,
  canonicalJson,
  completeAttestationIsolationLifecycle,
  evaluateAttestation,
  executionIsolationSchema,
  executionIsolationSchemaVersion,
  formatErrorTree,
  integrationReportSchema,
  integrationReportSchemaVersion,
  parseAaptBadging,
  parseApksignerVerification,
  parseNotificationPluginLock,
  parseOutputMetadata,
  parseSentinelJson,
  reminderIntegrationEntrypoint,
  reminderAttestationApplicationId,
  reminderAttestationApplicationLabel,
  reminderAttestationBuildConfiguration,
  registerSupervisedLeaseChild,
  requiredExecutionIsolationCheckpoints,
  SerializedAttestationLeaseOperations,
  sha256Bytes,
  executionIsolationFromLeaseEvidence,
  validateExecutionIsolation,
  validateIntegrationReport,
} from './run_android_reminder_attestation.mjs';

const runId = 'reminder-20260830-abcdef123456';
const sourceHeadSha = 'a'.repeat(40);
const sourceTreeSha = 'b'.repeat(40);
const sourceStateSha256 = 'c'.repeat(64);
const artifactSha256 = 'd'.repeat(64);
const changedSha256 = 'e'.repeat(64);
const capabilityManifestSha256 = '1'.repeat(64);
const capabilityProfileSha256 = '2'.repeat(64);
const capability = Object.freeze({
  schema: 'parkinsum.reminder-notification-capability-matrix/1',
  schemaVersion: 1,
  manifestSha256: capabilityManifestSha256,
  profileSha256: capabilityProfileSha256,
});

function deferred() {
  let resolve;
  let reject;
  const promise = new Promise((resolvePromise, rejectPromise) => {
    resolve = resolvePromise;
    reject = rejectPromise;
  });
  return { promise, resolve, reject };
}

function integrationReportFixture() {
  return {
    schema_uri: integrationReportSchema,
    schema_version: integrationReportSchemaVersion,
    run_id: runId,
    source_head_sha: sourceHeadSha,
    source_state_sha256: sourceStateSha256,
    source_state_bound: true,
    build_mode: 'debug',
    flutter_target_platform: 'android',
    storage_boundary: 'no-user-storage',
    real_user_data_accessed: false,
    notification_capability_schema: capability.schema,
    notification_capability_schema_version: capability.schemaVersion,
    notification_capability_manifest_sha256: capability.manifestSha256,
    notification_capability_profile_sha256: capability.profileSha256,
    notification_capability_platform: 'android',
    notification_delivery_mode: 'scheduled',
    permission: 'not-requested',
    plugin_reported_pending_after_schedule: 7,
    plugin_reported_pending_after_clear: 0,
    visible_delivery_evidence: 'implementedUnverified',
    visible_delivery_verified: false,
    alarm_manager_inspected: false,
    notification_boundary:
      'Logging reminder only — ParkinSUM does not calculate or prescribe a dose time.',
    notification_privacy_mode: 'minimal',
    notification_locale_snapshot: 'en',
    android_requested_visibility: 'secret',
    configured_copy_contains_user_label: false,
    system_visible_copy_inspected: false,
    system_visible_copy_contains_user_label: null,
    effective_lockscreen_visibility_inspected: false,
  };
}

function reportValidationContext() {
  return {
    runId,
    sourceHeadSha,
    sourceStateSha256,
    buildMode: 'debug',
    capability,
  };
}

function executionIsolationFixture() {
  return {
    schema_uri: executionIsolationSchema,
    schema_version: executionIsolationSchemaVersion,
    owner_identity_sha256: 'f'.repeat(64),
    lease_evidence_sha256: 'e'.repeat(64),
    process_start_provider: 'darwinNoReclaim',
    heartbeat_interval_ms: 5_000,
    stale_after_ms: 60_000,
    stale_reclaims: 0,
    resources: [
      {
        kind: 'buildOutput',
        resource_key_sha256: '0'.repeat(64),
        owner_token_sha256: '1'.repeat(64),
      },
      {
        kind: 'deviceApplication',
        resource_key_sha256: '2'.repeat(64),
        owner_token_sha256: '3'.repeat(64),
      },
    ],
    checkpoints: [...requiredExecutionIsolationCheckpoints],
    continuous_ownership_verified: true,
    children_drained_before_device_cleanup: true,
    device_cleanup_completed_while_owned: true,
  };
}

function attestationFixture() {
  const report = integrationReportFixture();
  return {
    $schema: attestationSchema,
    schema_version: attestationSchemaVersion,
    run_id: runId,
    mode: 'development',
    pass: true,
    failures: [],
    source: {
      head_sha: sourceHeadSha,
      head_tree_sha: sourceTreeSha,
      dirty: true,
      source_state_sha256: sourceStateSha256,
      pre_post_match: true,
    },
    artifact: {
      file_name: 'app-debug.apk',
      sha256: artifactSha256,
      bytes: 123456,
      sha256_after_run: artifactSha256,
      stable: true,
      application_id: reminderAttestationApplicationId,
      application_label: reminderAttestationApplicationLabel,
      build_configuration: reminderAttestationBuildConfiguration,
      version_code: 2,
      version_name: '0.2.0',
      variant: 'debug',
      entrypoint: reminderIntegrationEntrypoint,
      debuggable: true,
      min_sdk: 24,
      target_sdk: 36,
      native_abis: ['arm64-v8a', 'x86_64'],
      installed_base_sha256: artifactSha256,
      installed_base_bytes: 123456,
      installed_matches_input: true,
      split_count: 1,
      signing: {
        signature_verified: true,
        signer_count: 1,
        certificate_sha256: '8'.repeat(64),
        verified_schemes: ['v2'],
        warnings_as_errors: true,
        build_tools_revision: '36.1.0',
        apksigner_version: '0.9',
        apksigner_jar_sha256: '9'.repeat(64),
        identity_assurance: 'observedUnreviewed',
        expected_certificate_sha256: null,
        expected_certificate_match: false,
      },
    },
    device: {
      sdk_int: 36,
      android_release: '16',
      supported_abis: ['arm64-v8a', 'x86_64'],
      primary_abi: 'x86_64',
      device_kind: 'emulator',
      pre_post_match: true,
      application_id_absent_before_install: true,
      application_id_removed_after_run: true,
    },
    execution_isolation: executionIsolationFixture(),
    platform_binding: {
      pubspec_lock_sha256: '3'.repeat(64),
      notification_plugin_version: '22.3.0',
      notification_plugin_package_sha256: '4'.repeat(64),
      source_manifest_sha256: '5'.repeat(64),
      merged_manifest_sha256: '6'.repeat(64),
      apk_manifest_tree_sha256: 'a'.repeat(64),
      output_metadata_sha256: '7'.repeat(64),
      compile_sdk: 36,
      min_sdk: 24,
      target_sdk: 36,
      post_notifications_declared: true,
      reboot_receivers_declared: true,
      build_mode: 'debug',
    },
    capability: {
      schema: capability.schema,
      schema_version: capability.schemaVersion,
      manifest_sha256: capability.manifestSha256,
      profile_sha256: capability.profileSha256,
      platform: 'android',
      delivery_mode: 'scheduled',
    },
    integration: {
      report_data_sha256: sha256Bytes(Buffer.from(canonicalJson(report))),
      report_data: report,
    },
    claims: {
      artifact_execution_bound: true,
      scheduler_registry_round_trip_observed: true,
      visible_delivery_verified: false,
      release_eligible: false,
    },
    boundary: attestationBoundary,
  };
}

function mutateReport(mutator) {
  const report = integrationReportFixture();
  mutator(report);
  return validateIntegrationReport(report, reportValidationContext());
}

describe('canonical JSON and SHA-256 helpers', () => {
  test('sort object keys recursively while preserving array order', () => {
    const value = {
      z: 9,
      list: [{ d: 4, c: 3 }, 2],
      a: { b: 2, a: 1 },
    };

    const canonical = canonicalJson(value);

    assert.equal(
      canonical,
      '{"a":{"a":1,"b":2},"list":[{"c":3,"d":4},2],"z":9}',
    );
    assert.equal(
      sha256Bytes(Buffer.from(canonical)),
      '1ec5abd21a08a7f569e35626b12bfe2f96de579001716b089e16a06930a6238e',
    );
    assert.deepEqual(value.list, [{ d: 4, c: 3 }, 2]);
  });

  test('extract exactly one sentinel JSON object', () => {
    assert.deepEqual(
      parseSentinelJson(
        'Shell: PARKINSUM_TEST:{"bound":true}\nAll tests passed!\n',
        'PARKINSUM_TEST:',
        'test reporter',
      ),
      { bound: true },
    );
    assert.throws(
      () => parseSentinelJson('no payload', 'PARKINSUM_TEST:', 'test reporter'),
      /emitted 0 sentinel payloads/,
    );
  });

  test('renders aggregate children and causes without hiding root failures', () => {
    const workload = new Error('workload exploded');
    const cleanup = new Error('cleanup exploded');
    workload.cause = new Error('device vanished');
    const rendered = formatErrorTree(
      new AggregateError([workload, cleanup], 'attestation failed'),
    );
    assert.match(rendered, /attestation failed/);
    assert.match(rendered, /workload exploded/);
    assert.match(rendered, /device vanished/);
    assert.match(rendered, /cleanup exploded/);
  });
});

describe('attestation isolation lifecycle coordination', () => {
  test('drains children, stops heartbeat, releases, then finalizes in strict order', async () => {
    const events = [];
    const result = { runId: 'ordered-lifecycle' };
    const supervisor = {
      async drain() {
        events.push('drain');
      },
      disposeSignalHandlers() {
        events.push('disposeSignalHandlers');
      },
      throwIfAborted() {
        events.push('abortCheck');
      },
    };
    const leaseOperations = {
      async stopHeartbeat() {
        events.push('stopHeartbeat');
      },
      async run(operation) {
        return operation({
          async release() {
            events.push('release');
          },
        });
      },
    };

    const completed = await completeAttestationIsolationLifecycle({
      supervisor,
      leaseOperations,
      result,
      finalizePublication: async (publishedResult) => {
        assert.equal(publishedResult, result);
        events.push('finalize');
      },
    });

    assert.equal(completed, result);
    assert.deepEqual(events, [
      'drain',
      'stopHeartbeat',
      'release',
      'disposeSignalHandlers',
      'abortCheck',
      'finalize',
    ]);
  });

  test('does not finalize when lease release rejects', async () => {
    const releaseFailure = new Error('release ownership mismatch');
    let finalizeCalls = 0;
    const supervisor = {
      async drain() {},
      disposeSignalHandlers() {},
      throwIfAborted() {},
    };
    const leaseOperations = {
      async stopHeartbeat() {},
      async run(operation) {
        return operation({
          async release() {
            throw releaseFailure;
          },
        });
      },
    };

    await assert.rejects(
      completeAttestationIsolationLifecycle({
        supervisor,
        leaseOperations,
        result: { runId: 'release-failure' },
        finalizePublication: async () => {
          finalizeCalls += 1;
        },
      }),
      (error) => {
        assert.ok(error instanceof AggregateError);
        assert.deepEqual(error.errors, [releaseFailure]);
        return true;
      },
    );
    assert.equal(finalizeCalls, 0);
  });

  test('SIGTERM while drain is blocked fails with exit 143 and never finalizes', async () => {
    const fakeProcess = new EventEmitter();
    const supervisor = new AndroidAttestationChildSupervisor({
      processObject: fakeProcess,
      platform: 'linux',
      spawnProcess: () => {
        throw new Error('unexpected child launch');
      },
    });
    const drainStarted = deferred();
    const drainGate = deferred();
    supervisor.drain = async () => {
      drainStarted.resolve();
      await drainGate.promise;
    };
    supervisor.installSignalHandlers();
    let finalizeCalls = 0;
    const completion = completeAttestationIsolationLifecycle({
      supervisor,
      leaseOperations: {
        async stopHeartbeat() {},
        async run(operation) {
          return operation({ async release() {} });
        },
      },
      result: { runId: 'signal-during-drain' },
      finalizePublication: async () => {
        finalizeCalls += 1;
      },
    });
    const rejection = assert.rejects(completion, (error) => {
      assert.ok(error instanceof AttestationAbortError);
      assert.equal(error.exitCode, 143);
      return true;
    });

    await drainStarted.promise;
    fakeProcess.emit('SIGTERM');
    drainGate.resolve();
    await rejection;

    assert.equal(finalizeCalls, 0);
    assert.equal(fakeProcess.listenerCount('SIGTERM'), 0);
  });

  test('SIGTERM while release is blocked fails with exit 143 and never finalizes', async () => {
    const fakeProcess = new EventEmitter();
    const supervisor = new AndroidAttestationChildSupervisor({
      processObject: fakeProcess,
      platform: 'linux',
      spawnProcess: () => {
        throw new Error('unexpected child launch');
      },
    });
    supervisor.installSignalHandlers();
    const releaseStarted = deferred();
    const releaseGate = deferred();
    let finalizeCalls = 0;
    const completion = completeAttestationIsolationLifecycle({
      supervisor,
      leaseOperations: {
        async stopHeartbeat() {},
        async run(operation) {
          return operation({
            async release() {
              releaseStarted.resolve();
              await releaseGate.promise;
            },
          });
        },
      },
      result: { runId: 'signal-during-release' },
      finalizePublication: async () => {
        finalizeCalls += 1;
      },
    });
    const rejection = assert.rejects(completion, (error) => {
      assert.ok(error instanceof AttestationAbortError);
      assert.equal(error.exitCode, 143);
      return true;
    });

    await releaseStarted.promise;
    fakeProcess.emit('SIGTERM');
    releaseGate.resolve();
    await rejection;

    assert.equal(finalizeCalls, 0);
    assert.equal(fakeProcess.listenerCount('SIGTERM'), 0);
  });
});

describe('Android build metadata parsers', () => {
  test('parse aapt badging into normalized package, SDK, ABI, and debug facts', () => {
    const parsed = parseAaptBadging(`package: name='com.parkinsum.companion' versionCode='2' versionName='0.2.0' compileSdkVersion='36'
sdkVersion:'24'
targetSdkVersion:'36'
application-label:'ParkinSUM'
application-debuggable
native-code: 'x86_64' 'arm64-v8a'
`);

    assert.deepEqual(parsed, {
      applicationId: 'com.parkinsum.companion',
      versionCode: 2,
      versionName: '0.2.0',
      compileSdk: 36,
      minSdk: 24,
      targetSdk: 36,
      nativeAbis: ['arm64-v8a', 'x86_64'],
      debuggable: true,
    });
  });

  test('reject aapt badging without a supported native ABI', () => {
    assert.throws(
      () =>
        parseAaptBadging(`package: name='com.parkinsum.companion' versionCode='2' versionName='0.2.0' compileSdkVersion='36'
sdkVersion:'24'
targetSdkVersion:'36'
native-code: 'mips'
`),
      /no supported native ABI/,
    );
  });

  test('parse the pinned notification plugin identity from pubspec.lock', () => {
    const packageSha256 = '8'.repeat(64);
    const parsed = parseNotificationPluginLock(`packages:
  flutter_local_notifications:
    dependency: "direct main"
    description:
      name: flutter_local_notifications
      sha256: "${packageSha256}"
      url: "https://pub.dev"
    source: hosted
    version: "22.3.0"
  flutter_local_notifications_linux:
    dependency: transitive
    source: hosted
    version: "6.0.0"
`);

    assert.deepEqual(parsed, { version: '22.3.0', packageSha256 });
  });

  test('reject an incomplete notification plugin lock identity', () => {
    assert.throws(
      () =>
        parseNotificationPluginLock(`packages:
  flutter_local_notifications:
    dependency: "direct main"
    source: hosted
    version: "22.3.0"
`),
      /lock identity is incomplete/,
    );
  });

  test('parse one warnings-fatal APK signer and bind verifier identity', () => {
    const output = `Verifies
Verified using v1 scheme (JAR signing): false
Verified using v2 scheme (APK Signature Scheme v2): true
Verified using v3 scheme (APK Signature Scheme v3): false
Verified using v3.1 scheme (APK Signature Scheme v3.1): false
Verified using v4 scheme (APK Signature Scheme v4): false
Number of signers: 1
Signer #1 certificate SHA-256 digest: ${'8'.repeat(64)}
`;
    assert.deepEqual(
      parseApksignerVerification(output, {
        buildToolsRevision: '36.1.0',
        apksignerVersion: '0.9',
        apksignerJarSha256: '9'.repeat(64),
      }),
      {
        signature_verified: true,
        signer_count: 1,
        certificate_sha256: '8'.repeat(64),
        verified_schemes: ['v2'],
        warnings_as_errors: true,
        build_tools_revision: '36.1.0',
        apksigner_version: '0.9',
        apksigner_jar_sha256: '9'.repeat(64),
        identity_assurance: 'observedUnreviewed',
        expected_certificate_sha256: null,
        expected_certificate_match: false,
      },
    );
    assert.throws(
      () =>
        parseApksignerVerification(output.replace('Number of signers: 1', 'Number of signers: 2'), {
          buildToolsRevision: '36.1.0',
          apksignerVersion: '0.9',
          apksignerJarSha256: '9'.repeat(64),
        }),
      /expected one/,
    );
    assert.throws(
      () =>
        parseApksignerVerification(output.replace('APK Signature Scheme v2): true', 'APK Signature Scheme v2): false'), {
          buildToolsRevision: '36.1.0',
          apksignerVersion: '0.9',
          apksignerJarSha256: '9'.repeat(64),
        }),
      /v2 signature scheme was not verified/,
    );
  });

  test('bind one unfiltered output metadata APK to expected identity', () => {
    const metadata = JSON.stringify({
      artifactType: { type: 'APK', kind: 'Directory' },
      applicationId: 'com.parkinsum.companion',
      variantName: 'debug',
      elements: [
        {
          type: 'SINGLE',
          filters: [],
          attributes: [],
          versionCode: 2,
          versionName: '0.2.0',
          outputFile: 'app-debug.apk',
        },
      ],
    });
    const expected = {
      applicationId: 'com.parkinsum.companion',
      variant: 'debug',
      versionCode: 2,
      versionName: '0.2.0',
      fileName: 'app-debug.apk',
    };
    assert.deepEqual(parseOutputMetadata(metadata, expected), {
      outputFile: 'app-debug.apk',
    });
    assert.throws(
      () => parseOutputMetadata(metadata, { ...expected, variant: 'release' }),
      /does not bind/,
    );
  });
});

describe('integration observation contract', () => {
  test('accept the exact 30-field scheduler and registry observation', () => {
    const report = integrationReportFixture();

    assert.equal(Object.keys(report).length, 30);
    assert.deepEqual(
      validateIntegrationReport(report, reportValidationContext()),
      [],
    );
  });

  const mutationCases = [
    {
      name: 'missing field',
      mutate: (report) => delete report.notification_locale_snapshot,
      failures: [
        'integration_locale_snapshot_mismatch',
        'integration_report_keys_invalid',
      ],
    },
    {
      name: 'extra field',
      mutate: (report) => {
        report.unexpected = true;
      },
      failures: ['integration_report_keys_invalid'],
    },
    {
      name: 'future schema version',
      mutate: (report) => {
        report.schema_version = integrationReportSchemaVersion + 1;
      },
      failures: ['integration_schema_version_invalid'],
    },
    {
      name: 'run identity drift',
      mutate: (report) => {
        report.run_id = 'reminder-20260830-different';
      },
      failures: ['integration_run_id_mismatch'],
    },
    {
      name: 'source state drift',
      mutate: (report) => {
        report.source_state_sha256 = changedSha256;
      },
      failures: ['integration_source_state_mismatch'],
    },
    {
      name: 'capability manifest drift',
      mutate: (report) => {
        report.notification_capability_manifest_sha256 = changedSha256;
      },
      failures: ['integration_capability_manifest_mismatch'],
    },
    {
      name: 'permission was requested',
      mutate: (report) => {
        report.permission = 'returned-allowed';
      },
      failures: ['integration_permission_requested'],
    },
    {
      name: 'notification safety boundary drift',
      mutate: (report) => {
        report.notification_boundary = 'A different boundary';
      },
      failures: ['integration_notification_boundary_mismatch'],
    },
    {
      name: 'notification locale snapshot drift',
      mutate: (report) => {
        report.notification_locale_snapshot = 'fr';
      },
      failures: ['integration_locale_snapshot_mismatch'],
    },
    {
      name: 'visible delivery is overstated',
      mutate: (report) => {
        report.visible_delivery_evidence = 'verified';
        report.visible_delivery_verified = true;
      },
      failures: [
        'integration_visible_delivery_overstated',
        'integration_visible_evidence_overstated',
      ],
    },
    {
      name: 'scheduled pending count drift',
      mutate: (report) => {
        report.plugin_reported_pending_after_schedule = 6;
      },
      failures: ['integration_pending_schedule_mismatch'],
    },
    {
      name: 'cleared pending count drift',
      mutate: (report) => {
        report.plugin_reported_pending_after_clear = 1;
      },
      failures: ['integration_pending_clear_mismatch'],
    },
    {
      name: 'real user data access',
      mutate: (report) => {
        report.real_user_data_accessed = true;
      },
      failures: ['integration_real_user_data'],
    },
    {
      name: 'configured copy contains a user label',
      mutate: (report) => {
        report.configured_copy_contains_user_label = true;
      },
      failures: ['integration_configured_copy_private'],
    },
    {
      name: 'uninspected system copy is reported as a result',
      mutate: (report) => {
        report.system_visible_copy_contains_user_label = false;
      },
      failures: ['integration_system_visible_copy_result_overstated'],
    },
  ];

  for (const { name, mutate, failures } of mutationCases) {
    test(`reject ${name}`, () => {
      assert.deepEqual(mutateReport(mutate), failures);
    });
  }
});

describe('attestation evaluation', () => {
  test('maps private lease evidence to domain-separated public isolation-v2 evidence', () => {
    const isolation = executionIsolationFromLeaseEvidence(
      {
        resources: [
          {
            kind: 'deviceApplication',
            digest: '2'.repeat(64),
            tokenDigest: '9'.repeat(64),
          },
          {
            kind: 'buildOutput',
            digest: '0'.repeat(64),
            tokenDigest: '9'.repeat(64),
          },
        ],
        owner: {
          processIdentityDigest: 'f'.repeat(64),
          processProbeProvider: 'darwin-no-stale-reclaim-v1',
          childIdentityCount: 0,
        },
        timing: { staleAfterMs: 60_000 },
        reclaimCount: 0,
        checkpoints: requiredExecutionIsolationCheckpoints.map((label) => ({
          label,
        })),
        isolation: {
          privateLockRootVerified: true,
          sortedResourceAcquisitionVerified: true,
          tokenAndInodeOwnershipVerified: true,
        },
      },
      {
        heartbeatIntervalMs: 5_000,
        childrenDrainedBeforeDeviceCleanup: true,
        deviceCleanupCompletedWhileOwned: true,
      },
    );

    assert.deepEqual(validateExecutionIsolation(isolation), []);
    assert.notEqual(
      isolation.resources[0].owner_token_sha256,
      isolation.resources[1].owner_token_sha256,
    );
    assert.equal(isolation.process_start_provider, 'darwinNoReclaim');
  });

  test('serializes lease operations and poisons later work after a failure', async () => {
    let active = 0;
    let maximumActive = 0;
    const operations = new SerializedAttestationLeaseOperations({
      async heartbeat() {},
    });
    const guarded = () =>
      operations.run(async () => {
        active += 1;
        maximumActive = Math.max(maximumActive, active);
        await new Promise((resolve) => setTimeout(resolve, 5));
        active -= 1;
      });
    await Promise.all([guarded(), guarded(), guarded()]);
    assert.equal(maximumActive, 1);

    const failure = new Error('lease operation failed');
    await assert.rejects(operations.run(async () => {
      throw failure;
    }), /lease operation failed/);
    await assert.rejects(operations.run(async () => {}), /lease operation failed/);
    await assert.rejects(operations.stopHeartbeat(), /lease operation failed/);
  });

  test('treats a conclusively exited fast child as drained without poisoning the lease', async () => {
    let mutableRegistrationCalled = false;
    const missing = new AndroidAttestationProcessIdentityDisappearedError(
      4321,
      new Error('process already exited'),
    );
    const identity = await registerSupervisedLeaseChild({
      lease: {
        async captureChildIdentity() {
          throw missing;
        },
      },
      leaseOperations: {
        async run() {
          mutableRegistrationCalled = true;
        },
      },
      record: { pid: 4321, command: '/usr/bin/true' },
    });
    assert.equal(identity, null);
    assert.equal(mutableRegistrationCalled, false);

    const bootIdMissing = new Error('boot identity source unavailable');
    bootIdMissing.code = 'ENOENT';
    await assert.rejects(
      registerSupervisedLeaseChild({
        lease: {
          async captureChildIdentity() {
            throw bootIdMissing;
          },
        },
        leaseOperations: { async run() {} },
        record: { pid: 4322, command: '/usr/bin/true' },
      }),
      /boot identity source unavailable/,
    );
  });

  test('strictly validates execution-isolation evidence', () => {
    assert.deepEqual(validateExecutionIsolation(executionIsolationFixture()), []);

    const historical = executionIsolationFixture();
    historical.schema_uri =
      'parkinsum.android-reminder-execution-isolation/1';
    historical.schema_version = 1;
    assert.deepEqual(validateExecutionIsolation(historical), [
      'execution_isolation_schema_invalid',
      'execution_isolation_schema_version_invalid',
    ]);

    const unknownKey = executionIsolationFixture();
    unknownKey.unexpected = true;
    assert.deepEqual(validateExecutionIsolation(unknownKey), [
      'execution_isolation_keys_invalid',
    ]);

    const duplicateIdentity = executionIsolationFixture();
    duplicateIdentity.resources[1].owner_token_sha256 =
      duplicateIdentity.resources[0].resource_key_sha256;
    assert.deepEqual(validateExecutionIsolation(duplicateIdentity), [
      'execution_resource_identity_collision',
    ]);

    const prematureReclaim = executionIsolationFixture();
    prematureReclaim.stale_reclaims = 1;
    assert.deepEqual(validateExecutionIsolation(prematureReclaim), [
      'execution_stale_reclaims_invalid',
    ]);
  });

  test('accept development evidence and derive bounded claims', () => {
    const evaluated = evaluateAttestation(attestationFixture());

    assert.deepEqual(evaluated, {
      failures: [],
      pass: true,
      claims: {
        artifact_execution_bound: true,
        scheduler_registry_round_trip_observed: true,
        visible_delivery_verified: false,
        release_eligible: false,
      },
    });
  });

  test('rejects historical outer-v3 evidence after the isolation digest upgrade', () => {
    const historical = attestationFixture();
    historical.$schema = 'parkinsum.android-reminder-run-attestation/3';
    historical.schema_version = 3;
    const evaluated = evaluateAttestation(historical);
    assert.equal(evaluated.pass, false);
    assert.ok(evaluated.failures.includes('attestation_schema_invalid'));
    assert.ok(evaluated.failures.includes('attestation_schema_version_invalid'));
  });

  const driftCases = [
    {
      name: 'source changes during the run',
      mutate: (attestation) => {
        attestation.source.pre_post_match = false;
      },
      failures: ['source_state_drift'],
      artifactExecutionBound: false,
    },
    {
      name: 'APK bytes change during the run',
      mutate: (attestation) => {
        attestation.artifact.sha256_after_run = changedSha256;
      },
      failures: ['artifact_drift'],
      artifactExecutionBound: false,
    },
    {
      name: 'installed APK differs from the staged input',
      mutate: (attestation) => {
        attestation.artifact.installed_base_sha256 = changedSha256;
        attestation.artifact.installed_matches_input = false;
      },
      failures: ['installed_artifact_mismatch'],
      artifactExecutionBound: false,
    },
    {
      name: 'device ABI is absent from the APK',
      mutate: (attestation) => {
        attestation.artifact.native_abis = ['arm64-v8a'];
      },
      failures: ['artifact_device_abi_mismatch'],
    },
    {
      name: 'platform SDK facts drift from APK metadata',
      mutate: (attestation) => {
        attestation.platform_binding.target_sdk = 35;
      },
      failures: ['platform_artifact_sdk_mismatch'],
    },
    {
      name: 'capability binding drifts from the integration report',
      mutate: (attestation) => {
        attestation.capability.profile_sha256 = changedSha256;
      },
      failures: ['integration_capability_profile_mismatch'],
      schedulerObserved: false,
    },
    {
      name: 'integration report digest drifts',
      mutate: (attestation) => {
        attestation.integration.report_data_sha256 = changedSha256;
      },
      failures: ['integration_report_digest_mismatch'],
      schedulerObserved: false,
    },
    {
      name: 'APK signer certificate is malformed',
      mutate: (attestation) => {
        attestation.artifact.signing.certificate_sha256 = 'not-a-digest';
      },
      failures: ['artifact_signer_certificate_invalid'],
    },
    {
      name: 'APK v2 signature verification is absent',
      mutate: (attestation) => {
        attestation.artifact.signing.verified_schemes = ['v3'];
      },
      failures: ['artifact_signature_schemes_invalid'],
    },
    {
      name: 'isolated package sandbox is not cleanly removed',
      mutate: (attestation) => {
        attestation.device.application_id_removed_after_run = false;
      },
      failures: ['device_application_sandbox_unbound'],
      artifactExecutionBound: false,
    },
    {
      name: 'execution ownership is not continuous',
      mutate: (attestation) => {
        attestation.execution_isolation.continuous_ownership_verified = false;
      },
      failures: ['execution_continuous_ownership_unverified'],
      artifactExecutionBound: false,
    },
    {
      name: 'child processes are not drained before cleanup',
      mutate: (attestation) => {
        attestation.execution_isolation.children_drained_before_device_cleanup =
          false;
      },
      failures: ['execution_children_not_drained'],
      artifactExecutionBound: false,
    },
    {
      name: 'execution checkpoints are reordered',
      mutate: (attestation) => {
        const checkpoints = attestation.execution_isolation.checkpoints;
        [checkpoints[0], checkpoints[1]] = [checkpoints[1], checkpoints[0]];
      },
      failures: ['execution_checkpoints_invalid'],
    },
    {
      name: 'artifact uses the production application ID',
      mutate: (attestation) => {
        attestation.artifact.application_id = 'com.parkinsum.companion';
      },
      failures: ['artifact_application_id_not_isolated'],
    },
  ];

  for (const {
    name,
    mutate,
    failures,
    artifactExecutionBound = true,
    schedulerObserved = true,
  } of driftCases) {
    test(`fail closed when ${name}`, () => {
      const attestation = attestationFixture();
      mutate(attestation);

      const evaluated = evaluateAttestation(attestation);

      assert.equal(evaluated.pass, false);
      assert.deepEqual(evaluated.failures, failures);
      assert.equal(
        evaluated.claims.artifact_execution_bound,
        artifactExecutionBound,
      );
      assert.equal(
        evaluated.claims.scheduler_registry_round_trip_observed,
        schedulerObserved,
      );
      assert.equal(evaluated.claims.release_eligible, false);
    });
  }
});
