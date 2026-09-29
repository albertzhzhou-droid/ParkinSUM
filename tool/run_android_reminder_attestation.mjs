#!/usr/bin/env node

import { createHash, randomBytes } from 'node:crypto';
import { promises as fs } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';
import { pathToFileURL } from 'node:url';

import { inspectAndroidApkManifest } from './android_apk_manifest_inspection.mjs';
import { AndroidAttestationChildSupervisor } from './android_attestation_child_supervisor.mjs';
import {
  acquireAndroidAttestationExclusiveLease,
  AndroidAttestationProcessIdentityDisappearedError,
} from './android_attestation_exclusive_lease.mjs';

let activeCommandSupervisor = null;

export const attestationSchema =
  'parkinsum.android-reminder-run-attestation/4';
export const attestationSchemaVersion = 4;
export const executionIsolationSchema =
  'parkinsum.android-reminder-execution-isolation/2';
export const executionIsolationSchemaVersion = 2;
export const integrationReportSchema =
  'parkinsum.android-reminder-integration-observation/4';
export const integrationReportSchemaVersion = 4;
export const capabilitySnapshotSentinel =
  'PARKINSUM_ANDROID_REMINDER_CAPABILITY_SNAPSHOT:';
export const attestationValidationSentinel =
  'PARKINSUM_ANDROID_REMINDER_ATTESTATION_VALIDATION:';
export const reminderIntegrationEntrypoint =
  'integration_test/android_reminder_scheduling_test.dart';
export const reminderAttestationApplicationId =
  'com.parkinsum.companion.reminderattestation';
export const reminderAttestationApplicationLabel =
  'ParkinSUM Reminder Attestation';
export const reminderAttestationBuildConfiguration = 'reminder_attestation';
export const attestationBoundary =
  'Cooperatively isolated, checksum-bound scheduler, plugin-registry, manifest, ' +
  'and APK signature integrity evidence does not fence independent build ' +
  'commands, prove detached descendants ended, establish a reviewed production ' +
  'signer, or prove ' +
  'visible notification delivery, display timing, lock-screen behavior, ' +
  'activation, background execution, or reproducible source-to-binary ' +
  'provenance.';

const sha256Pattern = /^[a-f0-9]{64}$/;
const gitObjectPattern = /^[a-f0-9]{40}(?:[a-f0-9]{24})?$/;
const runIdPattern = /^[A-Za-z0-9][A-Za-z0-9_-]{7,95}$/;
const safeLabelPattern = /^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$/;
const supportedSignatureSchemes = new Set(['v1', 'v2', 'v3', 'v3.1', 'v4']);
const supportedAbis = new Set([
  'arm64-v8a',
  'armeabi-v7a',
  'x86',
  'x86_64',
]);
const leaseHeartbeatIntervalMs = 5_000;
const leaseStaleAfterMs = 60_000;
const expectedIntegrationKeys = new Set([
  'schema_uri',
  'schema_version',
  'run_id',
  'source_head_sha',
  'source_state_sha256',
  'source_state_bound',
  'build_mode',
  'flutter_target_platform',
  'storage_boundary',
  'real_user_data_accessed',
  'notification_capability_schema',
  'notification_capability_schema_version',
  'notification_capability_manifest_sha256',
  'notification_capability_profile_sha256',
  'notification_capability_platform',
  'notification_delivery_mode',
  'permission',
  'plugin_reported_pending_after_schedule',
  'plugin_reported_pending_after_clear',
  'visible_delivery_evidence',
  'visible_delivery_verified',
  'alarm_manager_inspected',
  'notification_boundary',
  'notification_privacy_mode',
  'notification_locale_snapshot',
  'android_requested_visibility',
  'configured_copy_contains_user_label',
  'system_visible_copy_inspected',
  'system_visible_copy_contains_user_label',
  'effective_lockscreen_visibility_inspected',
]);
const expectedAttestationKeys = new Set([
  '$schema',
  'schema_version',
  'run_id',
  'mode',
  'pass',
  'failures',
  'source',
  'artifact',
  'platform_binding',
  'device',
  'execution_isolation',
  'capability',
  'integration',
  'claims',
  'boundary',
]);
const expectedExecutionIsolationKeys = new Set([
  'schema_uri',
  'schema_version',
  'owner_identity_sha256',
  'lease_evidence_sha256',
  'process_start_provider',
  'heartbeat_interval_ms',
  'stale_after_ms',
  'stale_reclaims',
  'resources',
  'checkpoints',
  'continuous_ownership_verified',
  'children_drained_before_device_cleanup',
  'device_cleanup_completed_while_owned',
]);
const expectedExecutionResourceKeys = new Set([
  'kind',
  'resource_key_sha256',
  'owner_token_sha256',
]);
export const requiredExecutionIsolationCheckpoints = Object.freeze([
  'acquiredBeforeSourceAndDeviceInspection',
  'beforeBuild',
  'afterBuildBeforeStage',
  'beforeDeviceAbsenceCheck',
  'beforeFlutterDrive',
  'afterFlutterDriveBeforePull',
  'childrenDrainedBeforeDeviceCleanup',
  'deviceCleanupCompletedWhileOwned',
  'beforeAttestationPublish',
]);

export class SerializedAttestationLeaseOperations {
  constructor(lease) {
    if (lease == null || typeof lease.heartbeat !== 'function') {
      throw new TypeError('lease must expose heartbeat()');
    }
    this.lease = lease;
    this.tail = Promise.resolve();
    this.failure = null;
    this.timer = null;
  }

  run(operation) {
    if (typeof operation !== 'function') {
      throw new TypeError('lease operation must be a function');
    }
    const pending = this.tail.then(async () => {
      if (this.failure != null) throw this.failure;
      return operation(this.lease);
    });
    this.tail = pending.then(
      () => undefined,
      (error) => {
        this.failure ??= error;
      },
    );
    return pending;
  }

  startHeartbeat(intervalMs) {
    if (!Number.isInteger(intervalMs) || intervalMs <= 0) {
      throw new TypeError('heartbeat interval must be a positive integer');
    }
    if (this.timer != null) {
      throw new Error('serialized heartbeat is already running');
    }
    this.timer = setInterval(() => {
      void this.run((lease) => lease.heartbeat()).catch(() => {
        // run() records the first failure; later operations then fail closed.
      });
    }, intervalMs);
    this.timer.unref?.();
  }

  async stopHeartbeat() {
    if (this.timer != null) clearInterval(this.timer);
    this.timer = null;
    await this.tail;
    if (this.failure != null) throw this.failure;
  }
}

export async function registerSupervisedLeaseChild({
  lease,
  leaseOperations,
  record,
}) {
  let identity;
  try {
    identity = await lease.captureChildIdentity({
      pid: record.pid,
      processGroupId: record.pid,
      role: `attestation-${path.basename(record.command).slice(0, 100)}`,
    });
  } catch (error) {
    // A very short-lived Linux child may be gone before /proc identity capture.
    // ENOENT/ESRCH is conclusive that this direct PID is no longer active at
    // that instant; waiting for ChildProcess `close` remains mandatory. Other
    // probe failures retain the lease fail-closed.
    if (
      error instanceof AndroidAttestationProcessIdentityDisappearedError ||
      error?.code === 'PROCESS_IDENTITY_DISAPPEARED'
    ) {
      return null;
    }
    throw error;
  }
  await leaseOperations.run((ownedLease) =>
    ownedLease.registerChild(identity),
  );
  return identity;
}

export function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value != null && typeof value === 'object') {
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, canonicalize(value[key])]),
    );
  }
  return value;
}

export function canonicalJson(value) {
  return JSON.stringify(canonicalize(value));
}

export function sha256Bytes(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

export function executionIsolationFromLeaseEvidence(
  evidence,
  {
    heartbeatIntervalMs = leaseHeartbeatIntervalMs,
    childrenDrainedBeforeDeviceCleanup,
    deviceCleanupCompletedWhileOwned,
  },
) {
  if (!isPlainObject(evidence) || !isPlainObject(evidence.owner)) {
    throw new TypeError('lease evidence is incomplete');
  }
  const provider = evidence.owner.processProbeProvider;
  const processStartProvider =
    provider === 'linux-boot-id-proc-starttime-v1'
      ? 'linuxProcStat'
      : provider === 'darwin-no-stale-reclaim-v1'
        ? 'darwinNoReclaim'
        : null;
  if (processStartProvider == null) {
    throw new Error(`unsupported lease process identity provider: ${provider}`);
  }
  if (!sha256Pattern.test(evidence.owner.processIdentityDigest ?? '')) {
    throw new Error('lease process identity digest is invalid');
  }
  const byKind = new Map(
    (Array.isArray(evidence.resources) ? evidence.resources : []).map(
      (resource) => [resource.kind, resource],
    ),
  );
  const resources = ['buildOutput', 'deviceApplication'].map((kind) => {
    const resource = byKind.get(kind);
    if (
      !isPlainObject(resource) ||
      !sha256Pattern.test(resource.digest ?? '') ||
      !sha256Pattern.test(resource.tokenDigest ?? '')
    ) {
      throw new Error(`lease evidence is missing ${kind}`);
    }
    return {
      kind,
      resource_key_sha256: resource.digest,
      owner_token_sha256: sha256Bytes(
        Buffer.from(
          `parkinsum.android-reminder-owner-token/1\0${kind}\0${resource.digest}\0${resource.tokenDigest}`,
        ),
      ),
    };
  });
  const isolation = evidence.isolation ?? {};
  return {
    schema_uri: executionIsolationSchema,
    schema_version: executionIsolationSchemaVersion,
    owner_identity_sha256: evidence.owner.processIdentityDigest,
    lease_evidence_sha256: sha256Bytes(
      Buffer.from(canonicalJson(evidence)),
    ),
    process_start_provider: processStartProvider,
    heartbeat_interval_ms: heartbeatIntervalMs,
    stale_after_ms: evidence.timing?.staleAfterMs,
    stale_reclaims: evidence.reclaimCount,
    resources,
    checkpoints: (evidence.checkpoints ?? []).map(
      (checkpoint) => checkpoint.label,
    ),
    continuous_ownership_verified:
      isolation.privateLockRootVerified === true &&
      isolation.sortedResourceAcquisitionVerified === true &&
      isolation.tokenAndInodeOwnershipVerified === true &&
      evidence.owner.childIdentityCount === 0,
    children_drained_before_device_cleanup:
      childrenDrainedBeforeDeviceCleanup === true,
    device_cleanup_completed_while_owned:
      deviceCleanupCompletedWhileOwned === true,
  };
}

export function parseSentinelJson(output, sentinel, context) {
  const payloads = output
    .split(/\r?\n/)
    .map((line) => {
      const index = line.indexOf(sentinel);
      return index < 0 ? null : line.slice(index + sentinel.length).trim();
    })
    .filter((value) => value != null && value.length > 0);
  if (payloads.length !== 1) {
    throw new Error(`${context} emitted ${payloads.length} sentinel payloads`);
  }
  const parsed = JSON.parse(payloads[0]);
  if (!isPlainObject(parsed)) throw new Error(`${context} payload is not an object`);
  return parsed;
}

export function parseAaptBadging(output) {
  const required = (pattern, field) => {
    const value = pattern.exec(output)?.[1];
    if (!value) throw new Error(`APK badging is missing ${field}`);
    return value;
  };
  const nativeLine = /^native-code:\s*(.+)$/m.exec(output)?.[1] ?? '';
  const nativeAbis = [...nativeLine.matchAll(/'([^']+)'/g)]
    .map((match) => match[1])
    .sort();
  if (
    nativeAbis.length === 0 ||
    nativeAbis.some((abi) => !supportedAbis.has(abi))
  ) {
    throw new Error('APK badging has no supported native ABI');
  }
  return {
    applicationId: required(/package:\s+name='([^']+)'/, 'application id'),
    versionCode: Number(required(/versionCode='([0-9]+)'/, 'version code')),
    versionName: required(/versionName='([^']+)'/, 'version name'),
    compileSdk: Number(
      required(/compileSdkVersion='([0-9]+)'/, 'compile SDK'),
    ),
    minSdk: Number(
      required(/(?:minSdkVersion|sdkVersion):'([0-9]+)'/, 'minimum SDK'),
    ),
    targetSdk: Number(
      required(/targetSdkVersion:'([0-9]+)'/, 'target SDK'),
    ),
    nativeAbis,
    debuggable: /^application-debuggable$/m.test(output),
  };
}

export function parseApksignerVerification(
  output,
  {
    buildToolsRevision,
    apksignerVersion,
    apksignerJarSha256,
    expectedCertificateSha256 = null,
  },
) {
  if (!safeLabelPattern.test(buildToolsRevision ?? '')) {
    throw new Error('apksigner build-tools revision is invalid');
  }
  if (!safeLabelPattern.test(apksignerVersion ?? '')) {
    throw new Error('apksigner version is invalid');
  }
  if (!sha256Pattern.test(apksignerJarSha256 ?? '')) {
    throw new Error('apksigner JAR digest is invalid');
  }
  if (
    expectedCertificateSha256 != null &&
    !sha256Pattern.test(expectedCertificateSha256)
  ) {
    throw new Error('expected signer certificate digest is invalid');
  }
  if (!/^Verifies$/m.test(output)) {
    throw new Error('apksigner did not report a verified APK');
  }
  const schemes = new Map();
  for (const match of output.matchAll(
    /^Verified using v(1|2|3|3\.1|4) scheme(?: \([^\r\n]*\))?: (true|false)$/gm,
  )) {
    if (schemes.has(match[1])) {
      throw new Error(`apksigner repeated v${match[1]} scheme result`);
    }
    schemes.set(match[1], match[2] === 'true');
  }
  if (schemes.size !== supportedSignatureSchemes.size) {
    throw new Error('apksigner signature-scheme results are incomplete');
  }
  const signerCountMatches = [
    ...output.matchAll(/^Number of signers: ([0-9]+)$/gm),
  ];
  if (signerCountMatches.length !== 1) {
    throw new Error('apksigner signer count is missing or ambiguous');
  }
  const signerCount = Number(signerCountMatches[0][1]);
  if (signerCount !== 1) {
    throw new Error(`apksigner reported ${signerCount} signers; expected one`);
  }
  const certificateMatches = [
    ...output.matchAll(
      /^Signer #1 certificate SHA-256 digest: ([a-f0-9]{64})$/gm,
    ),
  ];
  if (certificateMatches.length !== 1) {
    throw new Error('apksigner certificate digest is missing or ambiguous');
  }
  const certificateSha256 = certificateMatches[0][1];
  const verifiedSchemes = [...schemes.entries()]
    .filter(([, verified]) => verified)
    .map(([scheme]) => `v${scheme}`)
    .sort();
  if (!verifiedSchemes.includes('v2')) {
    throw new Error('APK v2 signature scheme was not verified');
  }
  const expectedCertificateMatch =
    expectedCertificateSha256 != null &&
    expectedCertificateSha256 === certificateSha256;
  return {
    signature_verified: true,
    signer_count: signerCount,
    certificate_sha256: certificateSha256,
    verified_schemes: verifiedSchemes,
    warnings_as_errors: true,
    build_tools_revision: buildToolsRevision,
    apksigner_version: apksignerVersion,
    apksigner_jar_sha256: apksignerJarSha256,
    identity_assurance:
      expectedCertificateSha256 == null
        ? 'observedUnreviewed'
        : 'reviewedAttestation',
    expected_certificate_sha256: expectedCertificateSha256,
    expected_certificate_match: expectedCertificateMatch,
  };
}

export function parseNotificationPluginLock(lockText) {
  const block = /(?:^|\n)  flutter_local_notifications:\n([\s\S]*?)(?=\n  [a-zA-Z0-9_]+:|$)/.exec(
    lockText,
  )?.[1];
  if (!block) throw new Error('pubspec.lock is missing flutter_local_notifications');
  const version = /\n    version:\s+"([^"]+)"/.exec(`\n${block}`)?.[1];
  const packageSha256 = /\n      sha256:\s+"([a-f0-9]{64})"/.exec(
    `\n${block}`,
  )?.[1];
  if (!version || !packageSha256) {
    throw new Error('notification plugin lock identity is incomplete');
  }
  return { version, packageSha256 };
}

export function parseOutputMetadata(metadataText, expected) {
  const metadata = JSON.parse(metadataText);
  const element = Array.isArray(metadata?.elements) ? metadata.elements[0] : null;
  if (
    metadata?.artifactType?.type !== 'APK' ||
    metadata?.applicationId !== expected.applicationId ||
    metadata?.variantName !== expected.variant ||
    !Array.isArray(metadata?.elements) ||
    metadata.elements.length !== 1 ||
    element?.type !== 'SINGLE' ||
    !Array.isArray(element.filters) ||
    element.filters.length !== 0 ||
    !Array.isArray(element.attributes) ||
    element.attributes.length !== 0 ||
    element.versionCode !== expected.versionCode ||
    element.versionName !== expected.versionName ||
    element.outputFile !== expected.fileName
  ) {
    throw new Error('Android output metadata does not bind the staged APK');
  }
  return { outputFile: element.outputFile };
}

export function validateIntegrationReport(
  report,
  { runId, sourceHeadSha, sourceStateSha256, buildMode, capability },
) {
  const failures = [];
  if (!isPlainObject(report)) {
    return ['integration_report_not_object'];
  }
  const keys = Object.keys(report);
  if (
    keys.length !== expectedIntegrationKeys.size ||
    keys.some((key) => !expectedIntegrationKeys.has(key))
  ) {
    failures.push('integration_report_keys_invalid');
  }
  const checks = [
    [report.schema_uri === integrationReportSchema, 'integration_schema_invalid'],
    [
      report.schema_version === integrationReportSchemaVersion,
      'integration_schema_version_invalid',
    ],
    [report.run_id === runId, 'integration_run_id_mismatch'],
    [report.source_head_sha === sourceHeadSha, 'integration_source_head_mismatch'],
    [
      report.source_state_sha256 === sourceStateSha256,
      'integration_source_state_mismatch',
    ],
    [report.source_state_bound === true, 'integration_source_unbound'],
    [report.build_mode === buildMode, 'integration_build_mode_mismatch'],
    [report.flutter_target_platform === 'android', 'integration_not_android'],
    [report.storage_boundary === 'no-user-storage', 'integration_storage_boundary'],
    [report.real_user_data_accessed === false, 'integration_real_user_data'],
    [
      report.notification_capability_schema === capability.schema,
      'integration_capability_schema_mismatch',
    ],
    [
      report.notification_capability_schema_version === capability.schemaVersion,
      'integration_capability_version_mismatch',
    ],
    [
      report.notification_capability_manifest_sha256 ===
        capability.manifestSha256,
      'integration_capability_manifest_mismatch',
    ],
    [
      report.notification_capability_profile_sha256 === capability.profileSha256,
      'integration_capability_profile_mismatch',
    ],
    [
      report.notification_capability_platform === 'android',
      'integration_capability_platform_mismatch',
    ],
    [
      report.notification_delivery_mode === 'scheduled',
      'integration_delivery_mode_mismatch',
    ],
    [report.permission === 'not-requested', 'integration_permission_requested'],
    [
      report.plugin_reported_pending_after_schedule === 7,
      'integration_pending_schedule_mismatch',
    ],
    [
      report.plugin_reported_pending_after_clear === 0,
      'integration_pending_clear_mismatch',
    ],
    [
      report.visible_delivery_evidence === 'implementedUnverified',
      'integration_visible_evidence_overstated',
    ],
    [
      report.visible_delivery_verified === false,
      'integration_visible_delivery_overstated',
    ],
    [report.alarm_manager_inspected === false, 'integration_alarm_claim_overstated'],
    [
      report.notification_boundary ===
        'Logging reminder only — ParkinSUM does not calculate or prescribe a dose time.',
      'integration_notification_boundary_mismatch',
    ],
    [
      report.notification_privacy_mode === 'minimal',
      'integration_privacy_mode_mismatch',
    ],
    [
      report.notification_locale_snapshot === 'en',
      'integration_locale_snapshot_mismatch',
    ],
    [
      report.android_requested_visibility === 'secret',
      'integration_visibility_request_mismatch',
    ],
    [
      report.configured_copy_contains_user_label === false,
      'integration_configured_copy_private',
    ],
    [
      report.system_visible_copy_inspected === false,
      'integration_system_visible_copy_claim_overstated',
    ],
    [
      report.system_visible_copy_contains_user_label === null,
      'integration_system_visible_copy_result_overstated',
    ],
    [
      report.effective_lockscreen_visibility_inspected === false,
      'integration_lockscreen_claim_overstated',
    ],
  ];
  for (const [condition, code] of checks) if (!condition) failures.push(code);
  return [...new Set(failures)].sort();
}

export function validateExecutionIsolation(isolation) {
  const failures = [];
  if (!isPlainObject(isolation)) {
    return ['execution_isolation_not_object'];
  }
  const keys = Object.keys(isolation);
  if (
    keys.length !== expectedExecutionIsolationKeys.size ||
    keys.some((key) => !expectedExecutionIsolationKeys.has(key))
  ) {
    failures.push('execution_isolation_keys_invalid');
  }
  if (isolation.schema_uri !== executionIsolationSchema) {
    failures.push('execution_isolation_schema_invalid');
  }
  if (isolation.schema_version !== executionIsolationSchemaVersion) {
    failures.push('execution_isolation_schema_version_invalid');
  }
  if (!sha256Pattern.test(isolation.owner_identity_sha256 ?? '')) {
    failures.push('execution_owner_identity_invalid');
  }
  if (!sha256Pattern.test(isolation.lease_evidence_sha256 ?? '')) {
    failures.push('execution_lease_evidence_digest_invalid');
  }
  if (
    isolation.process_start_provider !== 'linuxProcStat' &&
    isolation.process_start_provider !== 'darwinNoReclaim'
  ) {
    failures.push('execution_process_start_provider_invalid');
  }
  if (
    !Number.isInteger(isolation.heartbeat_interval_ms) ||
    isolation.heartbeat_interval_ms <= 0
  ) {
    failures.push('execution_heartbeat_interval_invalid');
  }
  if (
    !Number.isInteger(isolation.stale_after_ms) ||
    !Number.isInteger(isolation.heartbeat_interval_ms) ||
    isolation.stale_after_ms < 3 * isolation.heartbeat_interval_ms
  ) {
    failures.push('execution_stale_window_invalid');
  }
  if (
    !Number.isInteger(isolation.stale_reclaims) ||
    isolation.stale_reclaims < 0 ||
    isolation.stale_reclaims > 2 ||
    (isolation.process_start_provider === 'darwinNoReclaim' &&
      isolation.stale_reclaims !== 0)
  ) {
    failures.push('execution_stale_reclaims_invalid');
  }

  const resources = isolation.resources;
  if (!Array.isArray(resources) || resources.length !== 2) {
    failures.push('execution_resources_invalid');
  } else {
    const kinds = new Set();
    const resourceKeys = new Set();
    const ownerTokens = new Set();
    let exactResourceKeys = true;
    let validDigests = true;
    for (const resource of resources) {
      if (!isPlainObject(resource)) {
        exactResourceKeys = false;
        validDigests = false;
        continue;
      }
      const resourceFields = Object.keys(resource);
      if (
        resourceFields.length !== expectedExecutionResourceKeys.size ||
        resourceFields.some((key) => !expectedExecutionResourceKeys.has(key))
      ) {
        exactResourceKeys = false;
      }
      kinds.add(resource.kind);
      resourceKeys.add(resource.resource_key_sha256);
      ownerTokens.add(resource.owner_token_sha256);
      if (
        !sha256Pattern.test(resource.resource_key_sha256 ?? '') ||
        !sha256Pattern.test(resource.owner_token_sha256 ?? '')
      ) {
        validDigests = false;
      }
    }
    if (!exactResourceKeys) failures.push('execution_resource_keys_invalid');
    if (!validDigests) failures.push('execution_resource_digest_invalid');
    if (
      kinds.size !== 2 ||
      !kinds.has('buildOutput') ||
      !kinds.has('deviceApplication')
    ) {
      failures.push('execution_resource_kinds_invalid');
    }
    const identities = new Set([...resourceKeys, ...ownerTokens]);
    if (
      resourceKeys.size !== 2 ||
      ownerTokens.size !== 2 ||
      identities.size !== 4
    ) {
      failures.push('execution_resource_identity_collision');
    }
  }

  if (
    !Array.isArray(isolation.checkpoints) ||
    isolation.checkpoints.length !== requiredExecutionIsolationCheckpoints.length ||
    isolation.checkpoints.some(
      (checkpoint, index) =>
        checkpoint !== requiredExecutionIsolationCheckpoints[index],
    )
  ) {
    failures.push('execution_checkpoints_invalid');
  }
  if (isolation.continuous_ownership_verified !== true) {
    failures.push('execution_continuous_ownership_unverified');
  }
  if (isolation.children_drained_before_device_cleanup !== true) {
    failures.push('execution_children_not_drained');
  }
  if (isolation.device_cleanup_completed_while_owned !== true) {
    failures.push('execution_device_cleanup_unbound');
  }
  return [...new Set(failures)].sort();
}

export function evaluateAttestation(attestation) {
  const failures = [];
  if (!isPlainObject(attestation)) {
    return {
      failures: ['attestation_not_object'],
      pass: false,
      claims: {
        artifact_execution_bound: false,
        scheduler_registry_round_trip_observed: false,
        visible_delivery_verified: false,
        release_eligible: false,
      },
    };
  }
  const attestationKeys = Object.keys(attestation);
  if (
    attestationKeys.length !== expectedAttestationKeys.size ||
    attestationKeys.some((key) => !expectedAttestationKeys.has(key))
  ) {
    failures.push('attestation_keys_invalid');
  }
  if (attestation?.['$schema'] !== attestationSchema) {
    failures.push('attestation_schema_invalid');
  }
  if (attestation?.schema_version !== attestationSchemaVersion) {
    failures.push('attestation_schema_version_invalid');
  }
  if (!runIdPattern.test(attestation?.run_id ?? '')) {
    failures.push('attestation_run_id_invalid');
  }
  if (!['development', 'candidate'].includes(attestation?.mode)) {
    failures.push('attestation_mode_invalid');
  }
  if (attestation?.boundary !== attestationBoundary) {
    failures.push('attestation_boundary_invalid');
  }

  const source = attestation?.source ?? {};
  if (!gitObjectPattern.test(source.head_sha ?? '')) failures.push('source_head_invalid');
  if (!gitObjectPattern.test(source.head_tree_sha ?? '')) {
    failures.push('source_tree_invalid');
  }
  if (!sha256Pattern.test(source.source_state_sha256 ?? '')) {
    failures.push('source_state_invalid');
  }
  if (source.pre_post_match !== true) failures.push('source_state_drift');
  if (attestation?.mode === 'candidate' && source.dirty !== false) {
    failures.push('candidate_source_dirty');
  }

  const artifact = attestation?.artifact ?? {};
  for (const [field, code] of [
    ['sha256', 'artifact_sha_invalid'],
    ['sha256_after_run', 'artifact_post_sha_invalid'],
    ['installed_base_sha256', 'installed_sha_invalid'],
  ]) {
    if (!sha256Pattern.test(artifact[field] ?? '')) failures.push(code);
  }
  if (artifact.sha256 !== artifact.sha256_after_run || artifact.stable !== true) {
    failures.push('artifact_drift');
  }
  if (
    artifact.sha256 !== artifact.installed_base_sha256 ||
    artifact.bytes !== artifact.installed_base_bytes ||
    artifact.installed_matches_input !== true
  ) {
    failures.push('installed_artifact_mismatch');
  }
  if (artifact.split_count !== 1) failures.push('installed_split_count_invalid');
  if (artifact.entrypoint !== reminderIntegrationEntrypoint) {
    failures.push('artifact_entrypoint_invalid');
  }
  if (artifact.application_id !== reminderAttestationApplicationId) {
    failures.push('artifact_application_id_not_isolated');
  }
  if (artifact.application_label !== reminderAttestationApplicationLabel) {
    failures.push('artifact_application_label_invalid');
  }
  if (artifact.build_configuration !== reminderAttestationBuildConfiguration) {
    failures.push('artifact_build_configuration_invalid');
  }
  if (
    artifact.variant !== attestation?.platform_binding?.build_mode ||
    (artifact.variant === 'debug' && artifact.debuggable !== true) ||
    (artifact.variant === 'release' && artifact.debuggable !== false) ||
    !['debug', 'profile', 'release'].includes(artifact.variant)
  ) {
    failures.push('artifact_debuggable_mismatch');
  }

  const signing = artifact.signing ?? {};
  if (
    signing.signature_verified !== true ||
    signing.signer_count !== 1 ||
    signing.warnings_as_errors !== true
  ) {
    failures.push('artifact_signature_verification_invalid');
  }
  if (!sha256Pattern.test(signing.certificate_sha256 ?? '')) {
    failures.push('artifact_signer_certificate_invalid');
  }
  if (!sha256Pattern.test(signing.apksigner_jar_sha256 ?? '')) {
    failures.push('artifact_apksigner_identity_invalid');
  }
  if (
    !safeLabelPattern.test(signing.build_tools_revision ?? '') ||
    !safeLabelPattern.test(signing.apksigner_version ?? '')
  ) {
    failures.push('artifact_apksigner_version_invalid');
  }
  if (
    !Array.isArray(signing.verified_schemes) ||
    signing.verified_schemes.length === 0 ||
    new Set(signing.verified_schemes).size !== signing.verified_schemes.length ||
    !signing.verified_schemes.includes('v2') ||
    signing.verified_schemes.some(
      (scheme) => !supportedSignatureSchemes.has(scheme),
    )
  ) {
    failures.push('artifact_signature_schemes_invalid');
  }
  if (signing.identity_assurance === 'observedUnreviewed') {
    if (
      signing.expected_certificate_sha256 !== null ||
      signing.expected_certificate_match !== false
    ) {
      failures.push('artifact_unreviewed_signer_overstated');
    }
    if (attestation?.mode === 'candidate') {
      failures.push('candidate_signer_unreviewed');
    }
  } else if (signing.identity_assurance === 'reviewedAttestation') {
    if (
      !sha256Pattern.test(signing.expected_certificate_sha256 ?? '') ||
      signing.expected_certificate_sha256 !== signing.certificate_sha256 ||
      signing.expected_certificate_match !== true
    ) {
      failures.push('artifact_reviewed_signer_mismatch');
    }
  } else {
    failures.push('artifact_signer_assurance_invalid');
  }

  const device = attestation?.device ?? {};
  if (!Number.isInteger(device.sdk_int) || device.sdk_int <= 0) {
    failures.push('device_sdk_invalid');
  }
  if (device.pre_post_match !== true) failures.push('device_state_drift');
  if (
    device.device_kind !== 'emulator' ||
    device.application_id_absent_before_install !== true ||
    device.application_id_removed_after_run !== true
  ) {
    failures.push('device_application_sandbox_unbound');
  }
  if (!Array.isArray(device.supported_abis) || !device.supported_abis.includes(device.primary_abi)) {
    failures.push('device_abi_invalid');
  }
  if (!Array.isArray(artifact.native_abis) || !artifact.native_abis.includes(device.primary_abi)) {
    failures.push('artifact_device_abi_mismatch');
  }
  if (Number.isInteger(artifact.min_sdk) && device.sdk_int < artifact.min_sdk) {
    failures.push('artifact_device_sdk_mismatch');
  }

  const executionIsolation = attestation?.execution_isolation;
  failures.push(...validateExecutionIsolation(executionIsolation));

  const capability = attestation?.capability ?? {};
  for (const [field, code] of [
    ['manifest_sha256', 'capability_manifest_invalid'],
    ['profile_sha256', 'capability_profile_invalid'],
  ]) {
    if (!sha256Pattern.test(capability[field] ?? '')) failures.push(code);
  }
  if (capability.platform !== 'android' || capability.delivery_mode !== 'scheduled') {
    failures.push('capability_target_invalid');
  }

  const report = attestation?.integration?.report_data;
  const integrationFailures = validateIntegrationReport(report, {
    runId: attestation?.run_id,
    sourceHeadSha: source.head_sha,
    sourceStateSha256: source.source_state_sha256,
    buildMode: attestation?.platform_binding?.build_mode,
    capability: {
      schema: capability.schema,
      schemaVersion: capability.schema_version,
      manifestSha256: capability.manifest_sha256,
      profileSha256: capability.profile_sha256,
    },
  });
  failures.push(...integrationFailures);
  const integrationReportDigestMatches =
    attestation?.integration?.report_data_sha256 ===
    sha256Bytes(Buffer.from(canonicalJson(report)));
  if (!integrationReportDigestMatches) {
    failures.push('integration_report_digest_mismatch');
  }

  const platform = attestation?.platform_binding ?? {};
  for (const field of [
    'pubspec_lock_sha256',
    'notification_plugin_package_sha256',
    'source_manifest_sha256',
    'merged_manifest_sha256',
    'apk_manifest_tree_sha256',
    'output_metadata_sha256',
  ]) {
    if (!sha256Pattern.test(platform[field] ?? '')) {
      failures.push(`platform_${field}_invalid`);
    }
  }
  if (
    platform.min_sdk !== artifact.min_sdk ||
    platform.target_sdk !== artifact.target_sdk
  ) {
    failures.push('platform_artifact_sdk_mismatch');
  }
  if (
    platform.post_notifications_declared !== true ||
    platform.reboot_receivers_declared !== true
  ) {
    failures.push('platform_notification_manifest_incomplete');
  }
  if (platform.build_mode !== report?.build_mode) {
    failures.push('platform_build_mode_mismatch');
  }

  const uniqueFailures = [...new Set(failures)].sort();
  const artifactExecutionBound =
    source.pre_post_match === true &&
    artifact.sha256 === artifact.sha256_after_run &&
    artifact.stable === true &&
    artifact.sha256 === artifact.installed_base_sha256 &&
    artifact.bytes === artifact.installed_base_bytes &&
    artifact.installed_matches_input === true &&
    artifact.split_count === 1 &&
    device.pre_post_match === true &&
    device.application_id_absent_before_install === true &&
    device.application_id_removed_after_run === true &&
    executionIsolation?.continuous_ownership_verified === true &&
    executionIsolation?.children_drained_before_device_cleanup === true &&
    executionIsolation?.device_cleanup_completed_while_owned === true;
  // This artifact is built from an integration-test entrypoint and is never a
  // production release candidate, even when compiled in release mode.
  const releaseEligible = false;
  const expectedClaims = {
    artifact_execution_bound: artifactExecutionBound,
    scheduler_registry_round_trip_observed:
      integrationFailures.length === 0 && integrationReportDigestMatches,
    visible_delivery_verified: false,
    release_eligible: releaseEligible,
  };
  return {
    failures: uniqueFailures,
    pass: uniqueFailures.length === 0,
    claims: expectedClaims,
  };
}

export async function inspectSourceState(root) {
  const headSha = (
    await capture('git', ['rev-parse', '--verify', 'HEAD'], { cwd: root })
  ).stdout.trim();
  const headTreeSha = (
    await capture('git', ['rev-parse', '--verify', 'HEAD^{tree}'], { cwd: root })
  ).stdout.trim();
  const status = (
    await capture(
      'git',
      [
        'status',
        '--porcelain=v1',
        '-z',
        '--untracked-files=all',
        '--ignore-submodules=none',
      ],
      { cwd: root, encoding: null },
    )
  ).stdout;
  const listed = (
    await capture(
      'git',
      ['ls-files', '-co', '--exclude-standard', '-z'],
      { cwd: root, encoding: null },
    )
  ).stdout;
  const paths = [...new Set(listed.toString('utf8').split('\0').filter(Boolean))]
    .sort();
  const digest = createHash('sha256');
  digest.update('parkinsum.source-state/1\0');
  digest.update(headSha);
  digest.update('\0');
  digest.update(headTreeSha);
  digest.update('\0');
  digest.update(sha256Bytes(status));
  digest.update('\0');
  for (const relative of paths) {
    const absolute = path.resolve(root, relative);
    if (!absolute.startsWith(`${path.resolve(root)}${path.sep}`)) {
      throw new Error(`source path escaped root: ${relative}`);
    }
    digest.update(relative.split(path.sep).join('/'));
    digest.update('\0');
    try {
      const stat = await fs.lstat(absolute);
      digest.update(String(stat.mode & 0o777));
      digest.update('\0');
      if (stat.isSymbolicLink()) {
        digest.update('symlink\0');
        digest.update(await fs.readlink(absolute));
      } else if (stat.isFile()) {
        digest.update('file\0');
        digest.update(sha256Bytes(await fs.readFile(absolute)));
      } else {
        throw new Error(`unsupported source entry type: ${relative}`);
      }
    } catch (error) {
      if (error?.code !== 'ENOENT') throw error;
      digest.update('missing');
    }
    digest.update('\n');
  }
  return {
    headSha,
    headTreeSha,
    dirty: status.length > 0,
    sourceStateSha256: digest.digest('hex'),
  };
}

export async function inspectDevice(adb, device, root) {
  const shell = async (...args) =>
    (await capture(adb, ['-s', device, 'shell', ...args], { cwd: root }))
      .stdout.trim();
  const state = (
    await capture(adb, ['-s', device, 'get-state'], { cwd: root })
  ).stdout.trim();
  if (state !== 'device') throw new Error(`ADB target is not ready: ${state}`);
  const [sdk, release, abiList, primaryAbi, qemu] = await Promise.all([
    shell('getprop', 'ro.build.version.sdk'),
    shell('getprop', 'ro.build.version.release'),
    shell('getprop', 'ro.product.cpu.abilist'),
    shell('getprop', 'ro.product.cpu.abi'),
    shell('getprop', 'ro.kernel.qemu'),
  ]);
  const supportedDeviceAbis = abiList.split(',').filter(Boolean).sort();
  if (!supportedDeviceAbis.includes(primaryAbi)) {
    throw new Error('ADB primary ABI is absent from supported ABI list');
  }
  return {
    sdkInt: Number(sdk),
    androidRelease: release,
    supportedAbis: supportedDeviceAbis,
    primaryAbi,
    deviceKind:
      qemu === '1' || device.startsWith('emulator-') ? 'emulator' : 'physical',
  };
}

export async function completeAttestationIsolationLifecycle({
  supervisor,
  leaseOperations,
  primaryError = null,
  result,
  finalizePublication = finalizeAttestationPublication,
  onDisposed = () => {},
}) {
  const cleanupErrors = [];
  try {
    await supervisor.drain();
  } catch (error) {
    cleanupErrors.push(error);
  }
  if (leaseOperations != null) {
    try {
      await leaseOperations.stopHeartbeat();
      await leaseOperations.run((ownedLease) => ownedLease.release());
    } catch (error) {
      cleanupErrors.push(error);
    }
  }
  supervisor.disposeSignalHandlers();
  onDisposed();
  try {
    supervisor.throwIfAborted();
  } catch (error) {
    if (primaryError == null) primaryError = error;
    else if (error !== primaryError) cleanupErrors.push(error);
  }

  if (cleanupErrors.length > 0) {
    const errors = primaryError == null
      ? cleanupErrors
      : [primaryError, ...cleanupErrors];
    const aggregate = new AggregateError(
      errors,
      'Android reminder attestation failed while retaining execution isolation',
    );
    aggregate.exitCode = primaryError?.exitCode ?? 1;
    throw aggregate;
  }
  if (primaryError != null) throw primaryError;
  await finalizePublication(result);
  return result;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const root = path.resolve(args.root ?? process.cwd());
  const deviceId = requiredArg(args, 'device');
  const mode = args.mode ?? 'development';
  const buildMode = args['build-mode'] ?? 'debug';
  if (!['development', 'candidate'].includes(mode)) {
    throw new Error('--mode must be development or candidate');
  }
  if (!['debug', 'profile', 'release'].includes(buildMode)) {
    throw new Error('--build-mode must be debug, profile, or release');
  }
  const flutter = args.flutter ?? process.env.PARKINSUM_FLUTTER_BIN ?? 'flutter';
  const androidSdk =
    args['android-sdk'] ??
    process.env.ANDROID_SDK_ROOT ??
    process.env.ANDROID_HOME;
  if (!androidSdk) throw new Error('Android SDK path is required');
  const adb = args.adb ?? path.join(androidSdk, 'platform-tools', 'adb');
  const aapt2 = args.aapt2 ?? (await newestAapt2(androidSdk));
  const apksigner =
    args.apksigner ?? path.join(path.dirname(aapt2), 'apksigner');
  const expectedCertificateSha256 =
    args['expected-certificate-sha256'] ?? null;
  if (
    expectedCertificateSha256 != null &&
    !sha256Pattern.test(expectedCertificateSha256)
  ) {
    throw new Error('--expected-certificate-sha256 must be lowercase SHA-256');
  }
  if (mode === 'candidate' && expectedCertificateSha256 == null) {
    throw new Error(
      'candidate attestation requires --expected-certificate-sha256',
    );
  }

  const rootRealPath = await fs.realpath(root);
  const runId = createRunId();
  const configuredBuildOutputPath = path.join(rootRealPath, 'build', 'app');
  let canonicalBuildOutputPath = configuredBuildOutputPath;
  try {
    canonicalBuildOutputPath = await fs.realpath(configuredBuildOutputPath);
  } catch (error) {
    if (error?.code !== 'ENOENT') throw error;
  }
  const buildOutputResourceKey = `build-output:${canonicalBuildOutputPath}`;
  const deviceApplicationResourceKey = `device-application:${canonicalJson({
    applicationId: reminderAttestationApplicationId,
    deviceId,
  })}`;
  const lockRoot = path.join(
    os.tmpdir(),
    'parkinsum-android-attestation-leases-v1',
  );
  let lease;
  let leaseOperations;
  let primaryError;
  let result;
  const supervisor = new AndroidAttestationChildSupervisor({
    onChildStart: async (record) => {
      record.leaseRegistration = registerSupervisedLeaseChild({
        lease,
        leaseOperations,
        record,
      });
      record.leaseIdentity = await record.leaseRegistration;
    },
    onChildClose: async (record) => {
      if (record.leaseRegistration == null) return;
      const identity = await record.leaseRegistration;
      if (identity != null) {
        await leaseOperations.run((ownedLease) =>
          ownedLease.removeChild(identity),
        );
      }
    },
  });
  supervisor.installSignalHandlers();
  try {
    lease = await acquireAndroidAttestationExclusiveLease({
      lockRoot,
      resourceKeys: [
        { kind: 'buildOutput', key: buildOutputResourceKey },
        { kind: 'deviceApplication', key: deviceApplicationResourceKey },
      ],
      runId,
      parameters: {
        mode,
        buildMode,
        applicationId: reminderAttestationApplicationId,
        deviceIdSha256: sha256Bytes(Buffer.from(deviceId)),
        rootSha256: sha256Bytes(Buffer.from(rootRealPath)),
      },
      staleAfterMs: leaseStaleAfterMs,
    });
    leaseOperations = new SerializedAttestationLeaseOperations(lease);
    activeCommandSupervisor = supervisor;
    supervisor.throwIfAborted();
    leaseOperations.startHeartbeat(leaseHeartbeatIntervalMs);
    await leaseOperations.run((ownedLease) =>
      ownedLease.checkpoint('acquiredBeforeSourceAndDeviceInspection', {
        runId,
        buildMode,
      }),
    );
    result = await runAttestationWorkload({
      root,
      deviceId,
      mode,
      buildMode,
      flutter,
      adb,
      aapt2,
      apksigner,
      expectedCertificateSha256,
      runId,
      lease,
      leaseOperations,
      supervisor,
    });
    supervisor.throwIfAborted();
  } catch (error) {
    primaryError = error;
    if (supervisor?.abortSignal != null) {
      try {
        supervisor.throwIfAborted();
      } catch (abortError) {
        abortError.cause = error;
        primaryError = abortError;
      }
    }
  }

  return completeAttestationIsolationLifecycle({
    supervisor,
    leaseOperations,
    primaryError,
    result,
    onDisposed: () => {
      activeCommandSupervisor = null;
    },
  });
}

async function runAttestationWorkload({
  root,
  deviceId,
  mode,
  buildMode,
  flutter,
  adb,
  aapt2,
  apksigner,
  expectedCertificateSha256,
  runId,
  lease,
  leaseOperations,
  supervisor,
}) {

  const sourcePre = await inspectSourceState(root);
  if (mode === 'candidate' && sourcePre.dirty) {
    throw new Error('candidate attestation requires a clean source worktree');
  }
  const devicePre = await inspectDevice(adb, deviceId, root);
  if (devicePre.deviceKind !== 'emulator') {
    throw new Error(
      'schema v3 permits emulator-only runs; use an isolated application ID '
        + 'before adding physical-device execution',
    );
  }
  const capabilitySnapshotOutput = (
    await capture(
      flutter,
      [
        'test',
        '--no-pub',
        '--reporter=expanded',
        'tool/print_android_reminder_capability_snapshot.dart',
      ],
      { cwd: root, stream: true },
    )
  ).stdout;
  const capabilitySnapshot = parseSentinelJson(
    capabilitySnapshotOutput,
    capabilitySnapshotSentinel,
    'Android reminder capability snapshot',
  );
  const capability = {
    schema: capabilitySnapshot.schema,
    schemaVersion: capabilitySnapshot.schema_version,
    manifestSha256: capabilitySnapshot.manifest_sha256,
    profileSha256: capabilitySnapshot.profile_sha256,
    platform: capabilitySnapshot.platform,
    deliveryMode: capabilitySnapshot.delivery_mode,
  };
  const runDir = path.join(root, 'build', 'android_reminder_attestation', runId);
  await fs.mkdir(runDir, { recursive: true });
  const target = reminderIntegrationEntrypoint;
  const defines = [
    `PARKINSUM_REMINDER_RUN_ID=${runId}`,
    `PARKINSUM_SOURCE_HEAD_SHA=${sourcePre.headSha}`,
    `PARKINSUM_SOURCE_STATE_SHA256=${sourcePre.sourceStateSha256}`,
  ];
  const buildArgs = [
    'build',
    'apk',
    `--${buildMode}`,
    '--no-pub',
    `--target=${target}`,
    '--android-project-arg=PARKINSUM_REMINDER_ATTESTATION=true',
    ...defines.map((value) => `--dart-define=${value}`),
  ];
  await leaseOperations.run((ownedLease) =>
    ownedLease.checkpoint('beforeBuild', {
      buildMode,
      targetSha256: sha256Bytes(Buffer.from(target)),
    }),
  );
  await runLogged(flutter, buildArgs, {
    cwd: root,
    stdoutPath: path.join(runDir, 'build.stdout.log'),
    stderrPath: path.join(runDir, 'build.stderr.log'),
  });
  await leaseOperations.run((ownedLease) =>
    ownedLease.checkpoint('afterBuildBeforeStage', { buildMode }),
  );

  const builtApk = path.join(
    root,
    'build',
    'app',
    'outputs',
    'flutter-apk',
    `app-${buildMode}.apk`,
  );
  const stagedApk = path.join(runDir, `app-${buildMode}.apk`);
  await fs.copyFile(builtApk, stagedApk);
  await fs.chmod(stagedApk, 0o444);
  const stagedPre = await fileIdentity(stagedApk);
  const aaptOutput = (
    await capture(aapt2, ['dump', 'badging', stagedApk], { cwd: root })
  ).stdout;
  const apk = parseAaptBadging(aaptOutput);
  if (apk.applicationId !== reminderAttestationApplicationId) {
    throw new Error(
      `attestation APK application ID is not isolated: ${apk.applicationId}`,
    );
  }
  const apkManifestTreeOutput = (
    await capture(
      aapt2,
      ['dump', 'xmltree', '--file', 'AndroidManifest.xml', stagedApk],
      { cwd: root },
    )
  ).stdout;
  const apkManifest = inspectAndroidApkManifest(apkManifestTreeOutput, {
    expectedPackageName: reminderAttestationApplicationId,
    expectedApplicationLabel: reminderAttestationApplicationLabel,
  });
  const apksignerJar = await resolveApksignerJar(apksigner);
  const [apksignerVersion, apksignerVerification] = await Promise.all([
    capture(apksigner, ['version'], { cwd: root }),
    capture(
      apksigner,
      ['verify', '--verbose', '--print-certs', '--Werr', stagedApk],
      { cwd: root },
    ),
  ]);
  const signing = parseApksignerVerification(apksignerVerification.stdout, {
    buildToolsRevision: path.basename(path.dirname(apksigner)),
    apksignerVersion: apksignerVersion.stdout.trim(),
    apksignerJarSha256: (await fileIdentity(apksignerJar)).sha256,
    expectedCertificateSha256,
  });
  await leaseOperations.run((ownedLease) =>
    ownedLease.checkpoint('beforeDeviceAbsenceCheck', {
      applicationIdSha256: sha256Bytes(Buffer.from(apk.applicationId)),
    }),
  );
  const applicationIdAbsentBeforeInstall = !(await isPackageInstalled(
    adb,
    deviceId,
    apk.applicationId,
    root,
  ));
  if (!applicationIdAbsentBeforeInstall) {
    throw new Error(
      'isolated reminder attestation package already exists on the device; ' +
        'refusing to read or replace its sandbox',
    );
  }

  let report;
  let installedPaths;
  let stagedPost;
  let installedIdentity;
  let devicePost;
  let applicationIdRemovedAfterRun = false;
  let childrenDrainedBeforeDeviceCleanup = false;
  let deviceCleanupCompletedWhileOwned = false;
  let workloadError;
  try {
    await leaseOperations.run((ownedLease) =>
      ownedLease.checkpoint('beforeFlutterDrive', {
        artifactSha256: stagedPre.sha256,
      }),
    );
    await runLogged(
      flutter,
      [
        'drive',
        '--no-pub',
        `--${buildMode}`,
        '--driver=test_driver/android_reminder_integration_test.dart',
        `--target=${target}`,
        '-d',
        deviceId,
        `--use-application-binary=${stagedApk}`,
        '--keep-app-running',
        '--timeout=180',
      ],
      {
        cwd: root,
        env: { ...process.env, PARKINSUM_REMINDER_RUN_ID: runId },
        stdoutPath: path.join(runDir, 'drive.stdout.log'),
        stderrPath: path.join(runDir, 'drive.stderr.log'),
      },
    );
    await leaseOperations.run((ownedLease) =>
      ownedLease.checkpoint('afterFlutterDriveBeforePull', {
        artifactSha256: stagedPre.sha256,
      }),
    );

    const reportPath = path.join(runDir, 'report_data.json');
    const reportBytes = await fs.readFile(reportPath);
    report = JSON.parse(reportBytes.toString('utf8'));
    const integrationFailures = validateIntegrationReport(report, {
      runId,
      sourceHeadSha: sourcePre.headSha,
      sourceStateSha256: sourcePre.sourceStateSha256,
      buildMode,
      capability,
    });
    if (integrationFailures.length > 0) {
      throw new Error(
        `integration report failed: ${integrationFailures.join(', ')}`,
      );
    }

    installedPaths = await installedPackagePaths(
      adb,
      deviceId,
      apk.applicationId,
      root,
    );
    const installedBase = path.join(runDir, 'installed-base.apk');
    await capture(
      adb,
      ['-s', deviceId, 'pull', installedPaths[0], installedBase],
      { cwd: root, stream: true },
    );
    [stagedPost, installedIdentity, devicePost] = await Promise.all([
      fileIdentity(stagedApk),
      fileIdentity(installedBase),
      inspectDevice(adb, deviceId, root),
    ]);
  } catch (error) {
    workloadError = error;
  }
  let deviceCleanupError;
  try {
    await supervisor.drain();
    childrenDrainedBeforeDeviceCleanup = supervisor.childrenDrained;
    if (!childrenDrainedBeforeDeviceCleanup) {
      throw new Error('attestation children remained active before cleanup');
    }
    await leaseOperations.run((ownedLease) =>
      ownedLease.checkpoint('childrenDrainedBeforeDeviceCleanup', {
        activeChildren: supervisor.activeCount,
      }),
    );
    applicationIdRemovedAfterRun = await removeIsolatedPackageIfPresent(
      adb,
      deviceId,
      apk.applicationId,
      root,
      { allowDuringAbort: true },
    );
    if (!applicationIdRemovedAfterRun) {
      throw new Error('isolated reminder attestation package cleanup failed');
    }
    await leaseOperations.run((ownedLease) => ownedLease.assertOwned());
    deviceCleanupCompletedWhileOwned = true;
    await leaseOperations.run((ownedLease) =>
      ownedLease.checkpoint('deviceCleanupCompletedWhileOwned', {
        applicationRemoved: applicationIdRemovedAfterRun,
      }),
    );
  } catch (error) {
    deviceCleanupError = error;
  }
  if (workloadError != null || deviceCleanupError != null) {
    if (workloadError != null && deviceCleanupError != null) {
      throw new AggregateError(
        [workloadError, deviceCleanupError],
        'Android reminder workload and isolated package cleanup both failed',
      );
    }
    throw workloadError ?? deviceCleanupError;
  }

  const pubspecLockPath = path.join(root, 'pubspec.lock');
  const sourceManifestPath = path.join(
    root,
    'android',
    'app',
    'src',
    'main',
    'AndroidManifest.xml',
  );
  const mergedManifestPath = path.join(
    root,
    'build',
    'app',
    'intermediates',
    'merged_manifests',
    buildMode,
    `process${capitalize(buildMode)}Manifest`,
    'AndroidManifest.xml',
  );
  const outputMetadataPath = path.join(
    root,
    'build',
    'app',
    'outputs',
    'apk',
    buildMode,
    'output-metadata.json',
  );
  const [pubspecLock, mergedManifest, outputMetadata] = await Promise.all([
    fs.readFile(pubspecLockPath),
    fs.readFile(mergedManifestPath),
    fs.readFile(outputMetadataPath),
  ]);
  const plugin = parseNotificationPluginLock(pubspecLock.toString('utf8'));
  const metadata = parseOutputMetadata(outputMetadata.toString('utf8'), {
    applicationId: apk.applicationId,
    variant: buildMode,
    versionCode: apk.versionCode,
    versionName: apk.versionName,
    fileName: path.basename(stagedApk),
  });
  const metadataApkIdentity = await fileIdentity(
    path.join(path.dirname(outputMetadataPath), metadata.outputFile),
  );
  if (
    metadataApkIdentity.sha256 !== stagedPre.sha256 ||
    metadataApkIdentity.bytes !== stagedPre.bytes
  ) {
    throw new Error('Gradle output metadata APK differs from the staged APK');
  }
  const evidenceDirectory = path.join(runDir, 'platform');
  await fs.mkdir(evidenceDirectory, { recursive: true });
  await Promise.all([
    fs.copyFile(
      mergedManifestPath,
      path.join(evidenceDirectory, 'merged-AndroidManifest.xml'),
    ),
    fs.copyFile(
      outputMetadataPath,
      path.join(evidenceDirectory, 'output-metadata.json'),
    ),
    fs.writeFile(
      path.join(evidenceDirectory, 'apk-manifest-tree.txt'),
      apkManifestTreeOutput,
    ),
    fs.writeFile(
      path.join(evidenceDirectory, 'apksigner-verify.txt'),
      apksignerVerification.stdout,
    ),
  ]);
  const platformBinding = {
    pubspec_lock_sha256: sha256Bytes(pubspecLock),
    notification_plugin_version: plugin.version,
    notification_plugin_package_sha256: plugin.packageSha256,
    source_manifest_sha256: (await fileIdentity(sourceManifestPath)).sha256,
    merged_manifest_sha256: sha256Bytes(mergedManifest),
    apk_manifest_tree_sha256: sha256Bytes(
      Buffer.from(apkManifestTreeOutput),
    ),
    output_metadata_sha256: sha256Bytes(outputMetadata),
    compile_sdk: apk.compileSdk,
    min_sdk: apk.minSdk,
    target_sdk: apk.targetSdk,
    post_notifications_declared: apkManifest.postNotificationsDeclared,
    reboot_receivers_declared:
      apkManifest.bootReceiver.exported === false &&
      apkManifest.bootReceiver.bootCompletedActionDeclared === true,
    build_mode: buildMode,
  };
  const sourcePost = await inspectSourceState(root);
  const sourceMatches =
    sourcePre.sourceStateSha256 === sourcePost.sourceStateSha256;
  const deviceMatches = canonicalJson(devicePre) === canonicalJson(devicePost);
  const artifactMatches =
    stagedPre.sha256 === stagedPost.sha256 && stagedPre.bytes === stagedPost.bytes;
  const installedMatches =
    stagedPre.sha256 === installedIdentity.sha256 &&
    stagedPre.bytes === installedIdentity.bytes;
  await leaseOperations.run((ownedLease) =>
    ownedLease.checkpoint('beforeAttestationPublish', {
      artifactSha256: stagedPre.sha256,
      sourceStateSha256: sourcePre.sourceStateSha256,
    }),
  );
  await leaseOperations.run((ownedLease) => ownedLease.assertOwned());
  const leaseEvidence = lease.evidence();
  const executionIsolation = executionIsolationFromLeaseEvidence(
    leaseEvidence,
    {
      heartbeatIntervalMs: leaseHeartbeatIntervalMs,
      childrenDrainedBeforeDeviceCleanup,
      deviceCleanupCompletedWhileOwned,
    },
  );
  await fs.writeFile(
    path.join(runDir, 'execution-lease-evidence.json'),
    `${JSON.stringify(leaseEvidence, null, 2)}\n`,
  );
  await leaseOperations.run((ownedLease) => ownedLease.assertOwned());
  const draft = {
    $schema: attestationSchema,
    schema_version: attestationSchemaVersion,
    run_id: runId,
    mode,
    pass: true,
    failures: [],
    source: {
      head_sha: sourcePre.headSha,
      head_tree_sha: sourcePre.headTreeSha,
      dirty: sourcePre.dirty,
      source_state_sha256: sourcePre.sourceStateSha256,
      pre_post_match: sourceMatches,
    },
    artifact: {
      file_name: path.basename(stagedApk),
      sha256: stagedPre.sha256,
      bytes: stagedPre.bytes,
      sha256_after_run: stagedPost.sha256,
      stable: artifactMatches,
      application_id: apk.applicationId,
      application_label: apkManifest.applicationLabel,
      build_configuration: reminderAttestationBuildConfiguration,
      version_code: apk.versionCode,
      version_name: apk.versionName,
      variant: buildMode,
      entrypoint: target,
      debuggable: apk.debuggable,
      min_sdk: apk.minSdk,
      target_sdk: apk.targetSdk,
      native_abis: apk.nativeAbis,
      installed_base_sha256: installedIdentity.sha256,
      installed_base_bytes: installedIdentity.bytes,
      installed_matches_input: installedMatches,
      split_count: installedPaths.length,
      signing,
    },
    device: {
      sdk_int: devicePre.sdkInt,
      android_release: devicePre.androidRelease,
      supported_abis: devicePre.supportedAbis,
      primary_abi: devicePre.primaryAbi,
      device_kind: devicePre.deviceKind,
      pre_post_match: deviceMatches,
      application_id_absent_before_install: applicationIdAbsentBeforeInstall,
      application_id_removed_after_run: applicationIdRemovedAfterRun,
    },
    execution_isolation: executionIsolation,
    platform_binding: platformBinding,
    capability: {
      schema: capability.schema,
      schema_version: capability.schemaVersion,
      manifest_sha256: capability.manifestSha256,
      profile_sha256: capability.profileSha256,
      platform: capability.platform,
      delivery_mode: capability.deliveryMode,
    },
    integration: {
      report_data_sha256: sha256Bytes(Buffer.from(canonicalJson(report))),
      report_data: report,
    },
    claims: {
      artifact_execution_bound: false,
      scheduler_registry_round_trip_observed: false,
      visible_delivery_verified: false,
      release_eligible: false,
    },
    boundary: attestationBoundary,
  };
  const evaluated = evaluateAttestation(draft);
  draft.pass = evaluated.pass;
  draft.failures = evaluated.failures;
  draft.claims = evaluated.claims;
  if (!draft.pass) {
    throw new Error(`attestation failed: ${draft.failures.join(', ')}`);
  }

  const pendingAttestationPath = path.join(runDir, 'attestation.pending.json');
  const attestationPath = path.join(runDir, 'attestation.json');
  const markdownPath = path.join(runDir, 'attestation.md');
  const attestationContentSha256 = sha256Bytes(
    Buffer.from(canonicalJson(draft)),
  );
  await fs.writeFile(
    pendingAttestationPath,
    `${JSON.stringify(draft, null, 2)}\n`,
  );
  const validatorTestOutput = (
    await capture(
      flutter,
      [
        'test',
        '--no-pub',
        '--reporter=expanded',
        'tool/validate_android_reminder_attestation.dart',
      ],
      {
        cwd: root,
        env: {
          ...process.env,
          PARKINSUM_ANDROID_REMINDER_ATTESTATION_PATH: pendingAttestationPath,
        },
        stream: true,
      },
    )
  ).stdout;
  const validator = parseSentinelJson(
    validatorTestOutput,
    attestationValidationSentinel,
    'Android reminder Dart attestation validator',
  );
  if (
    validator.pass !== true ||
    validator.run_id !== runId ||
    validator.content_sha256 !== attestationContentSha256 ||
    validator.integration_report_data_sha256 !==
      draft.integration.report_data_sha256 ||
    validator.application_id !== draft.artifact.application_id ||
    validator.certificate_sha256 !== draft.artifact.signing.certificate_sha256 ||
    validator.signer_identity_assurance !==
      draft.artifact.signing.identity_assurance ||
    validator.execution_isolation_bound !== true ||
    validator.visible_delivery_verified !== false ||
    validator.release_eligible !== draft.claims.release_eligible
  ) {
    throw new Error('Dart attestation validator disagreed with the Node run');
  }
  const sourceFinal = await inspectSourceState(root);
  if (
    sourceFinal.sourceStateSha256 !== sourcePre.sourceStateSha256 ||
    sourceFinal.sourceStateSha256 !== sourcePost.sourceStateSha256
  ) {
    throw new Error('source state changed after evidence collection');
  }
  await leaseOperations.run((ownedLease) => ownedLease.assertOwned());
  supervisor.throwIfAborted();
  const pendingMarkdownPath = path.join(runDir, 'attestation.pending.md');
  await fs.writeFile(pendingMarkdownPath, renderMarkdown(draft));
  return {
    root,
    runId,
    pendingAttestationPath,
    attestationPath,
    pendingMarkdownPath,
    markdownPath,
    attestationContentSha256,
    leaseAcquiredAtMs: lease.evidence().timing.acquiredAtMs,
    summary: {
      pass: true,
      runId,
      attestation: path.relative(root, attestationPath),
      artifactSha256: stagedPre.sha256,
      sourceStateSha256: sourcePre.sourceStateSha256,
      visibleDeliveryVerified: false,
      releaseEligible: draft.claims.release_eligible,
    },
  };
}

async function finalizeAttestationPublication(result) {
  const {
    root,
    runId,
    pendingAttestationPath,
    attestationPath,
    pendingMarkdownPath,
    markdownPath,
    attestationContentSha256,
    leaseAcquiredAtMs,
    summary,
  } = result;
  await fs.rename(pendingAttestationPath, attestationPath);
  await fs.rename(pendingMarkdownPath, markdownPath);
  const latestPath = path.join(
    root,
    'build',
    'android_reminder_attestation',
    'latest.json',
  );
  const pendingLatestPath = path.join(
    root,
    'build',
    'android_reminder_attestation',
    `.latest.${runId}.pending.json`,
  );
  await fs.writeFile(
    pendingLatestPath,
    `${JSON.stringify({
      run_id: runId,
      attestation: path.relative(root, attestationPath),
      attestation_sha256: attestationContentSha256,
      lease_acquired_at_ms: leaseAcquiredAtMs,
      execution_isolation_released: true,
    }, null, 2)}\n`,
  );
  await fs.rename(pendingLatestPath, latestPath);
  process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);
}

async function capture(
  command,
  args,
  {
    cwd,
    env = process.env,
    encoding = 'utf8',
    stream = false,
    allowDuringAbort = false,
  } = {},
) {
  const supervisor =
    activeCommandSupervisor ?? new AndroidAttestationChildSupervisor();
  const stdout = [];
  const stderr = [];
  const record = await supervisor.launch(command, args, {
    cwd,
    env,
    stdio: ['ignore', 'pipe', 'pipe'],
    allowDuringAbort,
    executionBarrier: true,
    onSpawn: (child) => {
      child.stdout.on('data', (chunk) => {
        stdout.push(chunk);
        if (stream) process.stdout.write(chunk);
      });
      child.stderr.on('data', (chunk) => {
        stderr.push(chunk);
        if (stream) process.stderr.write(chunk);
      });
    },
  });
  const { code, signal, spawnError } = await record.completion;
  const out = Buffer.concat(stdout);
  const err = Buffer.concat(stderr);
  if (spawnError != null) throw spawnError;
  if (code !== 0) {
    const termination = signal == null ? `exit ${code}` : `signal ${signal}`;
    throw new Error(
      `${command} ended with ${termination}: ${err.toString('utf8').trim()}`,
    );
  }
  return {
    stdout: encoding == null ? out : out.toString(encoding),
    stderr: encoding == null ? err : err.toString(encoding),
  };
}

async function runLogged(
  command,
  args,
  { cwd, env = process.env, stdoutPath, stderrPath },
) {
  await fs.mkdir(path.dirname(stdoutPath), { recursive: true });
  const supervisor =
    activeCommandSupervisor ?? new AndroidAttestationChildSupervisor();
  const stdout = [];
  const stderr = [];
  const record = await supervisor.launch(command, args, {
    cwd,
    env,
    stdio: ['ignore', 'pipe', 'pipe'],
    executionBarrier: true,
    onSpawn: (child) => {
      child.stdout.on('data', (chunk) => {
        stdout.push(chunk);
        process.stdout.write(chunk);
      });
      child.stderr.on('data', (chunk) => {
        stderr.push(chunk);
        process.stderr.write(chunk);
      });
    },
  });
  const { code, signal, spawnError } = await record.completion;
  await Promise.all([
    fs.writeFile(stdoutPath, Buffer.concat(stdout)),
    fs.writeFile(stderrPath, Buffer.concat(stderr)),
  ]);
  if (spawnError != null) throw spawnError;
  if (code !== 0) {
    const termination = signal == null ? `exit ${code}` : `signal ${signal}`;
    throw new Error(`${command} ended with ${termination}`);
  }
}

async function fileIdentity(file) {
  const bytes = await fs.readFile(file);
  return { sha256: sha256Bytes(bytes), bytes: bytes.length };
}

async function installedPackagePaths(adb, device, applicationId, root) {
  const output = (
    await capture(
      adb,
      ['-s', device, 'shell', 'pm', 'path', applicationId],
      { cwd: root },
    )
  ).stdout;
  const paths = output
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => line.replace(/^package:/, ''));
  if (paths.length === 0 || paths.some((entry) => !entry.startsWith('/'))) {
    throw new Error('installed package paths are unavailable');
  }
  return paths;
}

async function isPackageInstalled(
  adb,
  device,
  applicationId,
  root,
  { allowDuringAbort = false } = {},
) {
  const output = (
    await capture(
      adb,
      ['-s', device, 'shell', 'pm', 'list', 'packages', applicationId],
      { cwd: root, allowDuringAbort },
    )
  ).stdout;
  return output
    .split(/\r?\n/)
    .map((line) => line.trim())
    .some((line) => line === `package:${applicationId}`);
}

async function removeIsolatedPackageIfPresent(
  adb,
  device,
  applicationId,
  root,
  { allowDuringAbort = false } = {},
) {
  if (applicationId !== reminderAttestationApplicationId) {
    throw new Error('refusing to remove a non-attestation application ID');
  }
  if (
    !(await isPackageInstalled(adb, device, applicationId, root, {
      allowDuringAbort,
    }))
  ) {
    return true;
  }
  const result = await capture(
    adb,
    ['-s', device, 'uninstall', applicationId],
    { cwd: root, allowDuringAbort },
  );
  if (result.stdout.trim() !== 'Success') return false;
  return !(await isPackageInstalled(adb, device, applicationId, root, {
    allowDuringAbort,
  }));
}

async function resolveApksignerJar(apksigner) {
  const directory = path.dirname(apksigner);
  const candidates = [
    path.join(directory, 'apksigner.jar'),
    path.join(directory, 'lib', 'apksigner.jar'),
  ];
  for (const candidate of candidates) {
    try {
      const stat = await fs.stat(candidate);
      if (stat.isFile() && stat.size > 0) return candidate;
    } catch (error) {
      if (error?.code !== 'ENOENT') throw error;
    }
  }
  throw new Error('apksigner.jar was not found beside the verifier');
}

async function newestAapt2(androidSdk) {
  const directory = path.join(androidSdk, 'build-tools');
  const versions = (await fs.readdir(directory, { withFileTypes: true }))
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort((a, b) => b.localeCompare(a, undefined, { numeric: true }));
  for (const version of versions) {
    const candidate = path.join(directory, version, 'aapt2');
    try {
      await fs.access(candidate);
      return candidate;
    } catch {
      // Try the next installed build-tools version.
    }
  }
  throw new Error('Android aapt2 was not found');
}

function createRunId() {
  const stamp = new Date().toISOString().replace(/[-:.TZ]/g, '').slice(0, 14);
  return `reminder-${stamp}-${randomBytes(6).toString('hex')}`;
}

function renderMarkdown(report) {
  return `# Android reminder integration attestation\n\n` +
    `- Run: \`${report.run_id}\`\n` +
    `- Mode: \`${report.mode}\`\n` +
    `- Result: **${report.pass ? 'PASS' : 'FAIL'}**\n` +
    `- Source: \`${report.source.head_sha}\` (${report.source.dirty ? 'dirty development snapshot' : 'clean'})\n` +
    `- Source state SHA-256: \`${report.source.source_state_sha256}\`\n` +
    `- APK SHA-256: \`${report.artifact.sha256}\`\n` +
    `- Device: Android API ${report.device.sdk_int}, ${report.device.primary_abi}, ${report.device.device_kind}\n` +
    `- Execution isolation: \`${report.execution_isolation.process_start_provider}\`, ${report.execution_isolation.resources.length} resources, ${report.execution_isolation.checkpoints.length} checkpoints\n` +
    `- Plugin registry: ${report.integration.report_data.plugin_reported_pending_after_schedule} -> ${report.integration.report_data.plugin_reported_pending_after_clear}\n` +
    `- Visible delivery verified: **false**\n` +
    `- Release eligible: **${report.claims.release_eligible}**\n\n` +
    `## Boundary\n\n${report.boundary}\n`;
}

function parseArgs(argv) {
  const parsed = {};
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token.startsWith('--')) continue;
    const [inlineKey, inlineValue] = token.slice(2).split('=', 2);
    if (inlineValue != null) {
      parsed[inlineKey] = inlineValue;
      continue;
    }
    const next = argv[index + 1];
    if (next == null || next.startsWith('--')) parsed[inlineKey] = true;
    else {
      parsed[inlineKey] = next;
      index += 1;
    }
  }
  return parsed;
}

function requiredArg(args, name) {
  const value = args[name];
  if (typeof value !== 'string' || value.length === 0) {
    throw new Error(`--${name} is required`);
  }
  return value;
}

function isPlainObject(value) {
  return value != null && typeof value === 'object' && !Array.isArray(value);
}

function capitalize(value) {
  return `${value[0].toUpperCase()}${value.slice(1)}`;
}

export function formatErrorTree(error, { indent = '', seen = new Set() } = {}) {
  if (error == null) return `${indent}Unknown error`;
  if (seen.has(error)) return `${indent}[circular error reference]`;
  if (typeof error !== 'object') return `${indent}${String(error)}`;
  seen.add(error);
  const head = error.stack ?? `${error.name ?? 'Error'}: ${error.message ?? ''}`;
  const lines = head
    .split('\n')
    .map((line) => `${indent}${line}`);
  if (Array.isArray(error.errors)) {
    error.errors.forEach((nested, index) => {
      lines.push(`${indent}  [${index + 1}]`);
      lines.push(formatErrorTree(nested, { indent: `${indent}    `, seen }));
    });
  }
  if (error.cause != null && !error.errors?.includes?.(error.cause)) {
    lines.push(`${indent}  Caused by:`);
    lines.push(
      formatErrorTree(error.cause, { indent: `${indent}    `, seen }),
    );
  }
  return lines.join('\n');
}

if (
  process.argv[1] != null &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  main().catch((error) => {
    process.stderr.write(`${formatErrorTree(error)}\n`);
    process.exitCode = Number.isInteger(error.exitCode) ? error.exitCode : 1;
  });
}
