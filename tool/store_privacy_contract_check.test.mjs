import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import {
  parseAndroidPermissions,
  parseAndroidBackupPolicy,
  parseApplePrivacyManifest,
  parsePubspecDirectDependencies,
  parsePubspecLock,
  extractLiteralHostsFromDart,
  validateContractSnapshot,
} from './store_privacy_contract_check.mjs';

test('literal host inventory excludes anchored raw regex while malformed URL literals remain visible', () => {
  const directory = mkdtempSync(path.join(os.tmpdir(), 'parkinsum-host-literals-'));
  try {
    writeFileSync(path.join(directory, 'source.dart'), String.raw`
      const pattern = r'^(?:Patient/[A-Za-z0-9.-]{1,64}|https://[^\s?#]+/Patient/[A-Za-z0-9.-]{1,64})$';
      const doubleQuotedPattern = r"^https://[^\s]+$";
      const url = 'https://api.example.test/data';
      const rawUrl = r'https://raw.example.test/data';
      const malformed = 'https://[broken';
      const malformedRaw = r'https://[also-broken';
    `);
    assert.deepEqual(extractLiteralHostsFromDart(directory), [
      'api.example.test',
      'INVALID_URL_LITERAL:https://[also-broken',
      'INVALID_URL_LITERAL:https://[broken',
      'raw.example.test',
    ]);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

function fixture() {
  const contract = {
    $schema: 'https://parkinsum.app/schemas/store-privacy-contract/v1',
    schemaVersion: 1,
    review: {
      reviewedAt: '2026-08-18',
      reviewerRole: 'repository_privacy_engineering_review',
      storeOwnerApproval: 'pending_external_account_owner',
    },
    lockIdentities: { 'pubspec.lock': 'a'.repeat(64) },
    runtimeDirectDependencies: { flutter: 'application_framework' },
    operatorDependencies: { 'firebase-admin': 'operator_only_backend_administration' },
    apple: {
      privacyManifests: { 'ios/Runner/PrivacyInfo.xcprivacy': 'b'.repeat(64) },
      collectedDataTypes: ['NSPrivacyCollectedDataTypeHealth'],
      tracking: false,
      trackingDomains: [],
      appRequiredReasonApis: [],
      keychainAccessGroupEntitlements: {
        'ios/Runner/Runner.entitlements': 'e'.repeat(64),
      },
      releaseEntitlements: {
        'com.apple.security.app-sandbox': true,
        'com.apple.security.network.client': true,
      },
    },
    android: {
      sourceManifestSha256: 'c'.repeat(64),
      dataExtractionRules: {
        path: 'android/app/src/main/res/xml/data_extraction_rules.xml',
        sha256: 'd'.repeat(64),
        cloudBackup: 'deny_all',
        deviceTransfer: 'deny_all',
      },
      sourcePermissions: ['android.permission.RECEIVE_BOOT_COMPLETED'],
      expectedMergedPermissions: [
        'android.permission.INTERNET',
        'android.permission.RECEIVE_BOOT_COMPLETED',
      ],
      permissions: {
        'android.permission.INTERNET': 'backend_connectivity',
        'android.permission.RECEIVE_BOOT_COMPLETED': 'restore_reminders',
      },
    },
    networkDestinations: { literalHosts: ['api.example.test'] },
    dataFlows: [
      {
        id: 'operational_telemetry',
        location: 'none',
        fields: [],
        purpose: 'disabled',
      },
    ],
    storeDeclarationSnapshots: {
      apple: { reviewedAt: '2026-08-18', status: 'draft_pending_owner' },
      googlePlay: { reviewedAt: '2026-08-18', status: 'draft_pending_owner' },
    },
  };
  const observed = {
    lockIdentities: { 'pubspec.lock': 'a'.repeat(64) },
    runtimeDirectDependencies: ['flutter'],
    operatorDependencies: ['firebase-admin'],
    appleManifestDigests: {
      'ios/Runner/PrivacyInfo.xcprivacy': 'b'.repeat(64),
    },
    appleManifestFacts: {
      'ios/Runner/PrivacyInfo.xcprivacy': {
        collectedDataTypes: ['NSPrivacyCollectedDataTypeHealth'],
        tracking: false,
        trackingDomains: [],
        accessedApiTypes: [],
      },
    },
    appleProjectPrivacyResource: true,
    keychainEntitlementDigests: {
      'ios/Runner/Runner.entitlements': 'e'.repeat(64),
    },
    keychainEntitlementFacts: {
      'ios/Runner/Runner.entitlements': true,
    },
    appleProjectKeychainEntitlements: true,
    appleReleaseEntitlements: [
      'com.apple.security.app-sandbox',
      'com.apple.security.network.client',
    ],
    androidSourcePermissions: ['android.permission.RECEIVE_BOOT_COMPLETED'],
    androidSourceManifestSha256: 'c'.repeat(64),
    androidDataExtractionRulesSha256: 'd'.repeat(64),
    androidBackupPolicyDenyAll: true,
    androidMergedPermissions: [
      'android.permission.INTERNET',
      'android.permission.RECEIVE_BOOT_COMPLETED',
    ],
    androidMergedBackupPolicy: {
      allowBackup: 'false',
      fullBackupContent: 'false',
      dataExtractionRules: '@xml/data_extraction_rules',
    },
    literalHosts: ['api.example.test'],
  };
  return { contract, observed };
}

test('matching reviewed snapshot passes without pretending store approval', () => {
  const { contract, observed } = fixture();
  assert.deepEqual(validateContractSnapshot(contract, observed), []);
});

test('versioned runtime egress manifest is pinned, reviewed and time limited', () => {
  const { contract, observed } = fixture();
  const platformConfigurationSnapshot = {
    schemaVersion: 1,
    evidenceScope: 'repository_source_configuration_only',
    web: { cspHeaders: [{ source: '**', sources: ["'self'"] }] },
  };
  contract.networkDestinations.runtimeEgressPolicyManifest = {
    path: 'config/runtime_network_egress_policy.json',
    policyVersion: '2026.09.24-v2',
    status: 'application_layer_gate_partial',
    sha256: 'f'.repeat(64),
  };
  observed.runtimeEgressPolicyManifest = {
    schemaVersion: 1,
    policyVersion: '2026.09.24-v2',
    status: 'application_layer_gate_partial',
    expiresAt: '2026-12-23T00:00:00Z',
    rules: [{ id: 'public-source' }, { id: 'local-loopback' }],
    platformConfigurationSnapshot,
  };
  observed.runtimeEgressPolicyManifestSha256 = 'f'.repeat(64);
  observed.platformNetworkConfiguration = structuredClone(platformConfigurationSnapshot);

  assert.deepEqual(
    validateContractSnapshot(contract, observed, {
      now: Date.parse('2026-09-24T00:00:00Z'),
    }),
    [],
  );

  observed.platformNetworkConfiguration.web.cspHeaders[0].sources.push('https://unknown.example');
  const platformDriftCodes = validateContractSnapshot(contract, observed, {
    now: Date.parse('2026-09-24T00:00:00Z'),
  }).map((finding) => finding.code);
  assert.deepEqual(platformDriftCodes, ['runtime_platform_configuration_drift']);
  observed.platformNetworkConfiguration = structuredClone(platformConfigurationSnapshot);

  observed.runtimeEgressPolicyManifest.expiresAt = '2026-09-23T00:00:00Z';
  const expiredCodes = validateContractSnapshot(contract, observed, {
    now: Date.parse('2026-09-24T00:00:00Z'),
  }).map((finding) => finding.code);
  assert.deepEqual(expiredCodes, ['runtime_egress_policy_manifest_expired']);

  observed.runtimeEgressPolicyManifest.expiresAt = '2026-12-23T00:00:00Z';
  observed.runtimeEgressPolicyManifest.rules.push({ id: 'public-source' });
  const driftCodes = validateContractSnapshot(contract, observed, {
    now: Date.parse('2026-09-24T00:00:00Z'),
  }).map((finding) => finding.code);
  assert.deepEqual(driftCodes, ['runtime_egress_policy_manifest_drift']);

  observed.runtimeEgressPolicyManifest.rules.pop();
  observed.runtimeEgressPolicyManifestSha256 = 'a'.repeat(64);
  const digestCodes = validateContractSnapshot(contract, observed, {
    now: Date.parse('2026-09-24T00:00:00Z'),
  }).map((finding) => finding.code);
  assert.deepEqual(digestCodes, ['runtime_egress_policy_manifest_drift']);
});

test('selected RxNorm concept properties have a separate consented data flow', () => {
  const contract = JSON.parse(
    readFileSync(new URL('../config/store_privacy_contract.json', import.meta.url), 'utf8'),
  );
  const manifestBytes = readFileSync(
    new URL('../config/runtime_network_egress_policy.json', import.meta.url),
  );
  const manifest = JSON.parse(manifestBytes.toString('utf8'));
  const flow = contract.dataFlows.find(
    (candidate) => candidate.id === 'rxnorm_selected_concept_properties_lookup',
  );
  const dynamicClass =
    contract.networkDestinations.dynamicClasses
      .user_consented_rxnorm_concept_properties_lookup;

  assert.equal(manifest.policyVersion, '2026.09.25-v6');
  assert.equal(
    contract.networkDestinations.runtimeEgressPolicyManifest.policyVersion,
    manifest.policyVersion,
  );
  assert.equal(
    contract.networkDestinations.runtimeEgressPolicyManifest.sha256,
    createHash('sha256').update(manifestBytes).digest('hex'),
  );
  assert.deepEqual(flow.fields, [
    'user_selected_rxnorm_concept_identifier',
    'ordinary_network_metadata_outside_application_payload',
  ]);
  assert.equal(flow.thirdParty, true);
  assert.deepEqual(dynamicClass.hostPatterns, ['rxnav.nlm.nih.gov']);
  assert.deepEqual(dynamicClass.data, flow.fields);
  assert.match(dynamicClass.purpose, /separate_user_opt_in/);
});

test('selected RxNorm display names have a separate FDA data flow and rule', () => {
  const contract = JSON.parse(
    readFileSync(new URL('../config/store_privacy_contract.json', import.meta.url), 'utf8'),
  );
  const manifestBytes = readFileSync(
    new URL('../config/runtime_network_egress_policy.json', import.meta.url),
  );
  const manifest = JSON.parse(manifestBytes.toString('utf8'));
  const flow = contract.dataFlows.find(
    (candidate) => candidate.id === 'rxnorm_candidate_openfda_label_lookup',
  );
  const dynamicClass =
    contract.networkDestinations.dynamicClasses
      .user_consented_rxnorm_candidate_openfda_label_lookup;
  const rule = manifest.rules.find(
    (candidate) =>
      candidate.id === 'openfda-rxnorm-candidate-label-user-lookup',
  );

  assert.deepEqual(flow.fields, [
    'two_user_selected_rxnorm_candidate_display_names',
    'ordinary_network_metadata_outside_application_payload',
  ]);
  assert.equal(flow.thirdParty, true);
  assert.deepEqual(dynamicClass.hostPatterns, ['api.fda.gov']);
  assert.deepEqual(dynamicClass.data, flow.fields);
  assert.match(dynamicClass.purpose, /separate_user_opt_in/);
  assert.equal(rule.purpose, 'user_initiated_openfda_rxnorm_candidate_label_lookup');
  assert.deepEqual(rule.permittedDataClasses, [
    'userSelectedRxNormCandidateDisplayName',
  ]);
  assert.deepEqual(rule.allowedQueryParameters, ['search', 'limit']);
  assert.equal(rule.redirects, 'deny');
  assert.equal(rule.maxRequestBodyBytes, 0);
  assert.equal(manifest.policyVersion, '2026.09.25-v6');
  assert.equal(
    contract.networkDestinations.runtimeEgressPolicyManifest.sha256,
    createHash('sha256').update(manifestBytes).digest('hex'),
  );
});

test('selected RxNorm history status has a separate exact-path consented data flow', () => {
  const contract = JSON.parse(
    readFileSync(new URL('../config/store_privacy_contract.json', import.meta.url), 'utf8'),
  );
  const manifestBytes = readFileSync(
    new URL('../config/runtime_network_egress_policy.json', import.meta.url),
  );
  const manifest = JSON.parse(manifestBytes.toString('utf8'));
  const flow = contract.dataFlows.find(
    (candidate) => candidate.id === 'rxnorm_selected_concept_history_lookup',
  );
  const dynamicClass =
    contract.networkDestinations.dynamicClasses
      .user_consented_rxnorm_concept_history_lookup;
  const rule = manifest.rules.find(
    (candidate) => candidate.id === 'rxnav-concept-history-user-lookup',
  );

  assert.equal(manifest.policyVersion, '2026.09.25-v6');
  assert.equal(
    contract.networkDestinations.runtimeEgressPolicyManifest.policyVersion,
    manifest.policyVersion,
  );
  assert.equal(
    contract.networkDestinations.runtimeEgressPolicyManifest.sha256,
    createHash('sha256').update(manifestBytes).digest('hex'),
  );
  assert.deepEqual(flow.fields, [
    'user_selected_rxnorm_concept_identifier',
    'ordinary_network_metadata_outside_application_payload',
  ]);
  assert.equal(flow.thirdParty, true);
  assert.deepEqual(dynamicClass.hostPatterns, ['rxnav.nlm.nih.gov']);
  assert.deepEqual(dynamicClass.data, flow.fields);
  assert.match(dynamicClass.purpose, /separate_user_opt_in/);
  assert.deepEqual(rule.pathPattern, [
    '/REST/rxcui/{numericRxCui}/historystatus.json',
  ]);
  assert.equal(rule.query, 'deny');
  assert.equal(rule.purpose, 'user_initiated_rxnorm_concept_history_lookup');
  assert.deepEqual(rule.permittedDataClasses, ['userSelectedRxCui']);
  assert.equal(rule.redirects, 'deny');
  assert.equal(rule.maxRequestBodyBytes, 0);
  assert.equal(rule.maxResponseBodyBytes, 64 * 1024);
});

test('release mode fails closed until store owner and snapshots are approved', () => {
  const { contract, observed } = fixture();
  const findings = validateContractSnapshot(contract, observed, {
    requireStoreApproval: true,
  });
  assert.deepEqual(
    findings.map((finding) => finding.code).sort(),
    [
      'store_owner_approval_missing',
      'store_snapshot_not_approved',
      'store_snapshot_not_approved',
    ],
  );
});

test('dependency and lock drift block instead of inheriting an old review', () => {
  const { contract, observed } = fixture();
  observed.lockIdentities['pubspec.lock'] = 'c'.repeat(64);
  observed.runtimeDirectDependencies.push('new_sdk');
  const codes = validateContractSnapshot(contract, observed).map((finding) => finding.code);
  assert(codes.includes('dependency_lock_drift'));
  assert(codes.includes('runtime_dependency_drift'));
});

test('new merged permission without classification blocks', () => {
  const { contract, observed } = fixture();
  observed.androidMergedPermissions.push('android.permission.CAMERA');
  const codes = validateContractSnapshot(contract, observed).map((finding) => finding.code);
  assert(codes.includes('android_merged_permission_drift'));
});

test('backup or device-transfer policy drift blocks', () => {
  const { contract, observed } = fixture();
  observed.androidBackupPolicyDenyAll = false;
  const codes = validateContractSnapshot(contract, observed).map((finding) => finding.code);
  assert(codes.includes('android_backup_policy_not_deny_all'));
});

test('built Android manifest must retain deny-backup attributes', () => {
  const { contract, observed } = fixture();
  observed.androidMergedBackupPolicy.allowBackup = 'true';
  const codes = validateContractSnapshot(contract, observed).map(
    (finding) => finding.code,
  );
  assert(codes.includes('android_merged_backup_policy_drift'));
});

test('network destination drift blocks', () => {
  const { contract, observed } = fixture();
  observed.literalHosts.push('tracker.example');
  const codes = validateContractSnapshot(contract, observed).map((finding) => finding.code);
  assert(codes.includes('network_destination_drift'));
});

test('Apple manifest and entitlement drift block', () => {
  const { contract, observed } = fixture();
  observed.appleManifestFacts['ios/Runner/PrivacyInfo.xcprivacy'].tracking = true;
  observed.appleReleaseEntitlements = ['com.apple.security.app-sandbox'];
  const codes = validateContractSnapshot(contract, observed).map((finding) => finding.code);
  assert(codes.includes('apple_tracking_drift'));
  assert(codes.includes('apple_entitlement_drift'));
});

test('missing or unapplied Apple Keychain entitlement blocks', () => {
  const { contract, observed } = fixture();
  observed.keychainEntitlementFacts['ios/Runner/Runner.entitlements'] = false;
  observed.appleProjectKeychainEntitlements = false;
  const codes = validateContractSnapshot(contract, observed).map(
    (finding) => finding.code,
  );
  assert(codes.includes('apple_keychain_entitlement_missing'));
  assert(codes.includes('apple_keychain_entitlement_not_applied'));
});

test('reviewed dependency privacy manifest byte or fact drift blocks', () => {
  const { contract, observed } = fixture();
  contract.apple.reviewedThirdPartyPrivacyManifests = {
    secure_storage: {
      manifestSha256: 'e'.repeat(64),
      manifestPath: 'Resources/PrivacyInfo.xcprivacy',
      accessedApiCategory: null,
      reason: null,
    },
  };
  observed.thirdPartyAppleManifestDigests = {
    secure_storage: 'f'.repeat(64),
  };
  observed.thirdPartyAppleManifestFacts = {
    secure_storage: {
      collectedDataTypes: ['NSPrivacyCollectedDataTypeHealth'],
      tracking: false,
      trackingDomains: [],
      accessedApiTypes: [],
      accessedApiReasons: [],
    },
  };
  const codes = validateContractSnapshot(contract, observed).map(
    (finding) => finding.code,
  );
  assert(codes.includes('apple_third_party_manifest_drift'));
  assert(codes.includes('apple_third_party_manifest_fact_drift'));
});

test('supplied Apple bundle without manifest blocks', () => {
  const { contract, observed } = fixture();
  observed.appleBundleManifestMissing = true;
  observed.appleBundlePath = 'build/ios/Runner.app';
  const codes = validateContractSnapshot(contract, observed).map((finding) => finding.code);
  assert(codes.includes('apple_artifact_manifest_missing'));
});

test('supplied Apple bundle manifest must match the reviewed platform bytes', () => {
  const { contract, observed } = fixture();
  observed.appleBundleManifestMissing = false;
  observed.appleBundleManifestContractPath =
    'ios/Runner/PrivacyInfo.xcprivacy';
  observed.appleBundleManifestSha256 = 'e'.repeat(64);
  const codes = validateContractSnapshot(contract, observed).map(
    (finding) => finding.code,
  );
  assert(codes.includes('apple_artifact_manifest_drift'));
});

test('parsers extract only the reviewed top-level facts', () => {
  assert.deepEqual(
    parsePubspecDirectDependencies(`dependencies:\n  flutter:\n    sdk: flutter\n  http: ^1.0.0\ndev_dependencies:\n  flutter_test:\n`),
    ['flutter', 'http'],
  );
  assert.deepEqual(
    parsePubspecLock(`packages:\n  alpha:\n    dependency: transitive\n    version: "1.2.3"\n  beta:\n    version: "4.5.6"\n`),
    { alpha: '1.2.3', beta: '4.5.6' },
  );
  assert.deepEqual(
    parseAndroidPermissions(`<manifest xmlns:android="x"><uses-permission android:name="b"/><uses-permission android:name="a" /></manifest>`),
    ['a', 'b'],
  );
  assert.deepEqual(
    parseAndroidBackupPolicy(`<manifest><application android:allowBackup="false" android:fullBackupContent="false" android:dataExtractionRules="@xml/data_extraction_rules" /></manifest>`),
    {
      allowBackup: 'false',
      fullBackupContent: 'false',
      dataExtractionRules: '@xml/data_extraction_rules',
    },
  );
  assert.deepEqual(
    parseApplePrivacyManifest(`<plist><dict>
      <key>NSPrivacyTracking</key><false/>
      <key>NSPrivacyTrackingDomains</key><array/>
      <key>NSPrivacyCollectedDataTypes</key><array><dict>
        <key>NSPrivacyCollectedDataType</key><string>NSPrivacyCollectedDataTypeHealth</string>
      </dict></array>
      <key>NSPrivacyAccessedAPITypes</key><array/>
    </dict></plist>`),
    {
      collectedDataTypes: ['NSPrivacyCollectedDataTypeHealth'],
      tracking: false,
      trackingDomains: [],
      accessedApiTypes: [],
      accessedApiReasons: [],
    },
  );
});

test('invalid review metadata and missing telemetry classification block', () => {
  const { contract, observed } = fixture();
  contract.review.reviewedAt = 'today';
  contract.review.reviewerRole = 'raw role with spaces';
  contract.dataFlows = [];
  const codes = validateContractSnapshot(contract, observed).map((finding) => finding.code);
  assert(codes.includes('invalid_review_date'));
  assert(codes.includes('invalid_identifier'));
  assert(codes.includes('telemetry_flow_unclassified'));
});
