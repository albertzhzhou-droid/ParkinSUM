#!/usr/bin/env node
// Fail-closed drift gate for the repository-owned portion of Apple App
// Privacy and Google Play Data Safety declarations.
//
// This tool does not infer legal conclusions and never submits store answers.
// It proves that a dated, human-reviewed repository snapshot still matches
// dependency locks, source permissions, Apple manifests/entitlements, literal
// network destinations, and (when supplied) built artifact facts.

import { createHash } from 'node:crypto';
import {
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  writeFileSync,
} from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const contractPath = path.join(root, 'config/store_privacy_contract.json');
const schemaUri = 'https://parkinsum.app/schemas/store-privacy-contract/v1';
const shaPattern = /^[0-9a-f]{64}$/;

export function sha256Bytes(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

export function sha256File(filePath) {
  return sha256Bytes(readFileSync(filePath));
}

function sorted(values) {
  return [...values].sort((a, b) => a.localeCompare(b));
}

function equalStringSets(left, right) {
  const a = sorted(new Set(left));
  const b = sorted(new Set(right));
  return a.length === b.length && a.every((value, index) => value === b[index]);
}

function directYamlKeys(text, sectionName, nextSectionName) {
  const start = text.indexOf(`${sectionName}:\n`);
  const end = text.indexOf(`${nextSectionName}:\n`);
  if (start < 0 || end < start) return [];
  const block = text.slice(start + sectionName.length + 2, end);
  return sorted(
    [...block.matchAll(/^  ([A-Za-z0-9_]+):/gm)].map((match) => match[1]),
  );
}

export function parsePubspecDirectDependencies(text) {
  return directYamlKeys(text, 'dependencies', 'dev_dependencies');
}

export function parsePubspecLock(text) {
  const packages = {};
  const lines = text.split(/\r?\n/);
  let inPackages = false;
  let current = null;
  for (const line of lines) {
    if (line === 'packages:') {
      inPackages = true;
      continue;
    }
    if (!inPackages) continue;
    const packageMatch = line.match(/^  ([A-Za-z0-9_]+):$/);
    if (packageMatch) {
      current = packageMatch[1];
      continue;
    }
    const versionMatch = line.match(/^    version: "([^"]+)"$/);
    if (current && versionMatch) {
      packages[current] = versionMatch[1];
      current = null;
    }
  }
  return Object.fromEntries(Object.entries(packages).sort(([a], [b]) => a.localeCompare(b)));
}

export function parseAndroidPermissions(xml) {
  return sorted(
    new Set(
      [...xml.matchAll(/<uses-permission\b[^>]*android:name="([^"]+)"[^>]*\/?\s*>/g)]
        .map((match) => match[1]),
    ),
  );
}

export function parseAndroidBackupPolicy(xml) {
  const application = xml.match(/<application\b[\s\S]*?>/)?.[0] ?? '';
  return {
    allowBackup: application.match(/android:allowBackup="([^"]+)"/)?.[1] ?? null,
    fullBackupContent:
      application.match(/android:fullBackupContent="([^"]+)"/)?.[1] ?? null,
    dataExtractionRules:
      application.match(/android:dataExtractionRules="([^"]+)"/)?.[1] ?? null,
  };
}

export function parseApplePrivacyManifest(xml) {
  const collectedDataTypes = sorted(
    new Set(
      [...xml.matchAll(
        /<key>NSPrivacyCollectedDataType<\/key>\s*<string>([^<]+)<\/string>/g,
      )].map((match) => match[1]),
    ),
  );
  const trackingMatch = xml.match(
    /<key>NSPrivacyTracking<\/key>\s*<(true|false)\s*\/>/,
  );
  const accessedApiTypes = sorted(
    new Set(
      [...xml.matchAll(
        /<key>NSPrivacyAccessedAPIType<\/key>\s*<string>([^<]+)<\/string>/g,
      )].map((match) => match[1]),
    ),
  );
  const reasons = sorted(
    new Set(
      [...xml.matchAll(
        /<key>NSPrivacyAccessedAPITypeReasons<\/key>\s*<array>([\s\S]*?)<\/array>/g,
      )].flatMap((match) =>
        [...match[1].matchAll(/<string>([^<]+)<\/string>/g)].map(
          (reason) => reason[1],
        ),
      ),
    ),
  );
  const trackingDomainsMatch = xml.match(
    /<key>NSPrivacyTrackingDomains<\/key>\s*<array>([\s\S]*?)<\/array>/,
  );
  const trackingDomains = trackingDomainsMatch
    ? sorted(
        new Set(
          [...trackingDomainsMatch[1].matchAll(/<string>([^<]+)<\/string>/g)]
            .map((match) => match[1]),
        ),
      )
    : [];
  return {
    collectedDataTypes,
    tracking: trackingMatch ? trackingMatch[1] === 'true' : null,
    trackingDomains,
    accessedApiTypes,
    accessedApiReasons: reasons,
  };
}

export function parseTruePlistKeys(xml) {
  return sorted(
    new Set(
      [...xml.matchAll(/<key>([^<]+)<\/key>\s*<true\s*\/>/g)].map(
        (match) => match[1],
      ),
    ),
  );
}

function walkFiles(directory, suffix, result = []) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const candidate = path.join(directory, entry.name);
    if (entry.isDirectory()) walkFiles(candidate, suffix, result);
    else if (entry.isFile() && candidate.endsWith(suffix)) result.push(candidate);
  }
  return result;
}

export function extractLiteralHostsFromDart(directory) {
  const hosts = new Set();
  for (const file of walkFiles(directory, '.dart')) {
    const text = readFileSync(file, 'utf8');
    for (const match of text.matchAll(/https?:\/\/[^'"\s)]+/g)) {
      try {
        const cleaned = match[0].replace(/[},;]+$/, '');
        hosts.add(new URL(cleaned).hostname);
      } catch {
        // A malformed literal is not silently accepted; record a sentinel that
        // cannot match an approved hostname and therefore blocks the gate.
        hosts.add(`INVALID_URL_LITERAL:${match[0]}`);
      }
    }
  }
  return sorted(hosts);
}

function addFinding(findings, code, message, artifact = null) {
  findings.push({ code, message, artifact });
}

function requireSafeIdentifier(value, field, findings) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9._:-]+$/.test(value)) {
    addFinding(findings, 'invalid_identifier', `${field} is not a safe identifier.`);
  }
}

export function validateContractSnapshot(contract, observed, options = {}) {
  const findings = [];
  if (!contract || typeof contract !== 'object' || Array.isArray(contract)) {
    return [{ code: 'invalid_contract', message: 'Contract root must be an object.', artifact: null }];
  }
  if (contract.$schema !== schemaUri || contract.schemaVersion !== 1) {
    addFinding(findings, 'unsupported_schema', 'Expected store privacy contract schema v1.');
  }
  const review = contract.review ?? {};
  if (!/^\d{4}-\d{2}-\d{2}$/.test(review.reviewedAt ?? '')) {
    addFinding(findings, 'invalid_review_date', 'review.reviewedAt must be YYYY-MM-DD.');
  }
  requireSafeIdentifier(review.reviewerRole, 'review.reviewerRole', findings);
  if (options.requireStoreApproval === true && review.storeOwnerApproval !== 'approved') {
    addFinding(
      findings,
      'store_owner_approval_missing',
      'Release approval was requested, but the dated store-owner approval is not approved.',
    );
  }

  const expectedLocks = contract.lockIdentities ?? {};
  for (const [file, expected] of Object.entries(expectedLocks)) {
    if (!shaPattern.test(expected)) {
      addFinding(findings, 'invalid_lock_digest', `${file} has an invalid SHA-256.`, file);
    } else if (observed.lockIdentities?.[file] !== expected) {
      addFinding(
        findings,
        'dependency_lock_drift',
        `${file} no longer matches the reviewed dependency identity.`,
        file,
      );
    }
  }

  const expectedDirect = Object.keys(contract.runtimeDirectDependencies ?? {});
  if (!equalStringSets(expectedDirect, observed.runtimeDirectDependencies ?? [])) {
    addFinding(
      findings,
      'runtime_dependency_drift',
      'pubspec runtime dependency names differ from the reviewed inventory.',
      'pubspec.yaml',
    );
  }
  for (const [dependency, classification] of Object.entries(
    contract.runtimeDirectDependencies ?? {},
  )) {
    requireSafeIdentifier(dependency, `runtime dependency ${dependency}`, findings);
    requireSafeIdentifier(classification, `classification for ${dependency}`, findings);
  }
  const expectedOperator = Object.keys(contract.operatorDependencies ?? {});
  if (!equalStringSets(expectedOperator, observed.operatorDependencies ?? [])) {
    addFinding(
      findings,
      'operator_dependency_drift',
      'package.json production dependencies differ from the reviewed operator inventory.',
      'package.json',
    );
  }

  const apple = contract.apple ?? {};
  for (const [file, expected] of Object.entries(apple.privacyManifests ?? {})) {
    if (observed.appleManifestDigests?.[file] !== expected) {
      addFinding(
        findings,
        'apple_privacy_manifest_drift',
        `${file} differs from its reviewed SHA-256.`,
        file,
      );
    }
    const facts = observed.appleManifestFacts?.[file];
    if (!facts) {
      addFinding(findings, 'apple_privacy_manifest_missing', `${file} is missing.`, file);
      continue;
    }
    if (!equalStringSets(facts.collectedDataTypes, apple.collectedDataTypes ?? [])) {
      addFinding(
        findings,
        'apple_collected_data_drift',
        `${file} collected-data types differ from the reviewed declaration.`,
        file,
      );
    }
    if (facts.tracking !== apple.tracking) {
      addFinding(findings, 'apple_tracking_drift', `${file} tracking flag changed.`, file);
    }
    if (!equalStringSets(facts.trackingDomains, apple.trackingDomains ?? [])) {
      addFinding(findings, 'apple_tracking_domain_drift', `${file} tracking domains changed.`, file);
    }
    if (!equalStringSets(facts.accessedApiTypes, apple.appRequiredReasonApis ?? [])) {
      addFinding(findings, 'apple_required_api_drift', `${file} required-reason API types changed.`, file);
    }
  }
  for (const [name, declaration] of Object.entries(
    apple.reviewedThirdPartyPrivacyManifests ?? {},
  )) {
    if (!declaration.manifestSha256) continue;
    const digest = observed.thirdPartyAppleManifestDigests?.[name];
    if (digest !== declaration.manifestSha256) {
      addFinding(
        findings,
        'apple_third_party_manifest_drift',
        `${name} privacy manifest differs from the reviewed package bytes.`,
        declaration.manifestPath ?? null,
      );
    }
    const facts = observed.thirdPartyAppleManifestFacts?.[name];
    if (!facts) {
      addFinding(
        findings,
        'apple_third_party_manifest_missing',
        `${name} reviewed privacy manifest is unavailable.`,
        declaration.manifestPath ?? null,
      );
      continue;
    }
    const expectedTypes = declaration.accessedApiCategory
      ? [declaration.accessedApiCategory]
      : [];
    const expectedReasons = declaration.reason ? [declaration.reason] : [];
    if (
      !equalStringSets(facts.accessedApiTypes, expectedTypes) ||
      !equalStringSets(facts.accessedApiReasons, expectedReasons) ||
      facts.tracking !== false ||
      facts.collectedDataTypes.length !== 0
    ) {
      addFinding(
        findings,
        'apple_third_party_manifest_fact_drift',
        `${name} privacy manifest facts differ from the reviewed declaration.`,
        declaration.manifestPath ?? null,
      );
    }
  }
  for (const [file, expected] of Object.entries(
    apple.keychainAccessGroupEntitlements ?? {},
  )) {
    if (observed.keychainEntitlementDigests?.[file] !== expected) {
      addFinding(
        findings,
        'apple_keychain_entitlement_drift',
        `${file} differs from its reviewed Keychain entitlement bytes.`,
        file,
      );
    }
    if (observed.keychainEntitlementFacts?.[file] !== true) {
      addFinding(
        findings,
        'apple_keychain_entitlement_missing',
        `${file} does not contain the reviewed keychain-access-groups array.`,
        file,
      );
    }
  }
  if (observed.appleProjectKeychainEntitlements !== true) {
    addFinding(
      findings,
      'apple_keychain_entitlement_not_applied',
      'Apple Runner build configurations do not all apply the reviewed Keychain entitlements.',
      'ios/Runner.xcodeproj/project.pbxproj',
    );
  }
  if (observed.appleProjectPrivacyResource !== true) {
    addFinding(
      findings,
      'apple_manifest_not_bundled',
      'PrivacyInfo.xcprivacy is not present in both Apple target resource phases.',
      'ios/Runner.xcodeproj/project.pbxproj',
    );
  }
  const requiredEntitlements = Object.entries(apple.releaseEntitlements ?? {})
    .filter(([, required]) => required === true)
    .map(([key]) => key);
  if (!requiredEntitlements.every((key) => observed.appleReleaseEntitlements?.includes(key))) {
    addFinding(
      findings,
      'apple_entitlement_drift',
      'macOS release entitlements no longer contain every reviewed required entitlement.',
      'macos/Runner/Release.entitlements',
    );
  }

  const android = contract.android ?? {};
  if (observed.androidSourceManifestSha256 !== android.sourceManifestSha256) {
    addFinding(
      findings,
      'android_source_manifest_drift',
      'Android source manifest differs from the reviewed SHA-256.',
      'android/app/src/main/AndroidManifest.xml',
    );
  }
  if (observed.androidDataExtractionRulesSha256 !== android.dataExtractionRules?.sha256) {
    addFinding(
      findings,
      'android_backup_policy_drift',
      'Android data extraction rules differ from the reviewed deny-all policy.',
      android.dataExtractionRules?.path ?? null,
    );
  }
  if (
    android.dataExtractionRules?.cloudBackup !== 'deny_all' ||
    android.dataExtractionRules?.deviceTransfer !== 'deny_all' ||
    observed.androidBackupPolicyDenyAll !== true
  ) {
    addFinding(
      findings,
      'android_backup_policy_not_deny_all',
      'Cloud backup and device transfer must explicitly exclude every app-data domain.',
      android.dataExtractionRules?.path ?? null,
    );
  }
  if (!equalStringSets(observed.androidSourcePermissions ?? [], android.sourcePermissions ?? [])) {
    addFinding(
      findings,
      'android_source_permission_drift',
      'Android source permissions differ from the reviewed inventory.',
      'android/app/src/main/AndroidManifest.xml',
    );
  }
  for (const permission of android.expectedMergedPermissions ?? []) {
    if (!(permission in (android.permissions ?? {}))) {
      addFinding(
        findings,
        'unclassified_android_permission',
        `${permission} has no reviewed purpose classification.`,
      );
    }
  }
  if (observed.androidMergedPermissions) {
    if (!equalStringSets(observed.androidMergedPermissions, android.expectedMergedPermissions ?? [])) {
      addFinding(
        findings,
        'android_merged_permission_drift',
        'Built Android merged permissions differ from the reviewed inventory.',
        observed.androidMergedManifestPath,
      );
    }
    const backup = observed.androidMergedBackupPolicy ?? {};
    if (
      backup.allowBackup !== 'false' ||
      backup.fullBackupContent !== 'false' ||
      backup.dataExtractionRules !== '@xml/data_extraction_rules'
    ) {
      addFinding(
        findings,
        'android_merged_backup_policy_drift',
        'Built Android merged manifest does not retain the reviewed deny-backup attributes.',
        observed.androidMergedManifestPath,
      );
    }
  }

  if (!equalStringSets(
    observed.literalHosts ?? [],
    contract.networkDestinations?.literalHosts ?? [],
  )) {
    addFinding(
      findings,
      'network_destination_drift',
      'Dart HTTP(S) literal hosts differ from the reviewed destination inventory.',
      'lib/',
    );
  }
  for (const flow of contract.dataFlows ?? []) {
    requireSafeIdentifier(flow.id, 'data flow id', findings);
    requireSafeIdentifier(flow.location, `data flow location ${flow.id}`, findings);
    requireSafeIdentifier(flow.purpose, `data flow purpose ${flow.id}`, findings);
    if (!Array.isArray(flow.fields)) {
      addFinding(findings, 'invalid_data_flow', `${flow.id} fields must be an array.`);
    }
  }
  if (!(contract.dataFlows ?? []).some((flow) => flow.id === 'operational_telemetry')) {
    addFinding(findings, 'telemetry_flow_unclassified', 'Operational telemetry state must be explicit.');
  }
  for (const store of ['apple', 'googlePlay']) {
    const snapshot = contract.storeDeclarationSnapshots?.[store];
    if (!snapshot || !/^\d{4}-\d{2}-\d{2}$/.test(snapshot.reviewedAt ?? '')) {
      addFinding(findings, 'store_snapshot_missing', `${store} lacks a dated declaration snapshot.`);
    }
    if (options.requireStoreApproval === true && !String(snapshot?.status ?? '').startsWith('approved')) {
      addFinding(
        findings,
        'store_snapshot_not_approved',
        `${store} declaration snapshot is not approved for submission.`,
      );
    }
  }
  if (observed.appleBundleManifestMissing === true) {
    addFinding(
      findings,
      'apple_artifact_manifest_missing',
      'The supplied Apple app bundle does not contain PrivacyInfo.xcprivacy in the expected location.',
      observed.appleBundlePath,
    );
  } else if (observed.appleBundleManifestSha256) {
    const expected = apple.privacyManifests?.[observed.appleBundleManifestContractPath];
    if (!expected || observed.appleBundleManifestSha256 !== expected) {
      addFinding(
        findings,
        'apple_artifact_manifest_drift',
        'The supplied Apple app bundle privacy manifest does not match the reviewed platform manifest.',
        observed.appleBundlePath,
      );
    }
  }
  return findings;
}

function collectObserved({ androidManifestPath = null, appleBundlePath = null } = {}) {
  const contract = JSON.parse(readFileSync(contractPath, 'utf8'));
  const lockIdentities = {};
  for (const file of Object.keys(contract.lockIdentities ?? {})) {
    const absolute = path.join(root, file);
    lockIdentities[file] = existsSync(absolute) ? sha256File(absolute) : null;
  }
  const appleManifestDigests = {};
  const appleManifestFacts = {};
  const thirdPartyAppleManifestDigests = {};
  const thirdPartyAppleManifestFacts = {};
  const keychainEntitlementDigests = {};
  const keychainEntitlementFacts = {};
  for (const file of Object.keys(contract.apple?.privacyManifests ?? {})) {
    const absolute = path.join(root, file);
    if (existsSync(absolute)) {
      const xml = readFileSync(absolute, 'utf8');
      appleManifestDigests[file] = sha256File(absolute);
      appleManifestFacts[file] = parseApplePrivacyManifest(xml);
    }
  }
  for (const file of Object.keys(
    contract.apple?.keychainAccessGroupEntitlements ?? {},
  )) {
    const absolute = path.join(root, file);
    if (!existsSync(absolute)) continue;
    const xml = readFileSync(absolute, 'utf8');
    keychainEntitlementDigests[file] = sha256File(absolute);
    keychainEntitlementFacts[file] =
      /<key>keychain-access-groups<\/key>\s*<array(?:\s*\/|>)/.test(xml);
  }
  const packageConfigPath = path.join(root, '.dart_tool/package_config.json');
  const packageConfig = JSON.parse(readFileSync(packageConfigPath, 'utf8'));
  for (const [name, declaration] of Object.entries(
    contract.apple?.reviewedThirdPartyPrivacyManifests ?? {},
  )) {
    if (!declaration.manifestSha256) continue;
    const packageName = declaration.package ?? name;
    const packageRecord = packageConfig.packages.find(
      (candidate) => candidate.name === packageName,
    );
    if (!packageRecord || typeof declaration.manifestPath !== 'string') continue;
    const packageRoot = fileURLToPath(
      new URL(packageRecord.rootUri, pathToFileURL(packageConfigPath)),
    );
    const manifest = path.join(packageRoot, declaration.manifestPath);
    if (!existsSync(manifest)) continue;
    const xml = readFileSync(manifest, 'utf8');
    thirdPartyAppleManifestDigests[name] = sha256File(manifest);
    thirdPartyAppleManifestFacts[name] = parseApplePrivacyManifest(xml);
  }
  const packageJson = JSON.parse(readFileSync(path.join(root, 'package.json'), 'utf8'));
  const iosProject = readFileSync(path.join(root, 'ios/Runner.xcodeproj/project.pbxproj'), 'utf8');
  const macosProject = readFileSync(path.join(root, 'macos/Runner.xcodeproj/project.pbxproj'), 'utf8');
  const observed = {
    lockIdentities,
    runtimeDirectDependencies: parsePubspecDirectDependencies(
      readFileSync(path.join(root, 'pubspec.yaml'), 'utf8'),
    ),
    operatorDependencies: sorted(Object.keys(packageJson.dependencies ?? {})),
    pubspecPackages: parsePubspecLock(readFileSync(path.join(root, 'pubspec.lock'), 'utf8')),
    appleManifestDigests,
    appleManifestFacts,
    thirdPartyAppleManifestDigests,
    thirdPartyAppleManifestFacts,
    keychainEntitlementDigests,
    keychainEntitlementFacts,
    appleProjectPrivacyResource:
      (iosProject.match(/PrivacyInfo\.xcprivacy in Resources/g) ?? []).length >= 2 &&
      (macosProject.match(/PrivacyInfo\.xcprivacy in Resources/g) ?? []).length >= 2,
    appleProjectKeychainEntitlements:
      (iosProject.match(/CODE_SIGN_ENTITLEMENTS = Runner\/Runner\.entitlements;/g) ?? [])
        .length >= 3 &&
      (macosProject.match(/CODE_SIGN_ENTITLEMENTS = Runner\/(?:DebugProfile|Release)\.entitlements;/g) ?? [])
        .length >= 3,
    appleReleaseEntitlements: parseTruePlistKeys(
      readFileSync(path.join(root, 'macos/Runner/Release.entitlements'), 'utf8'),
    ),
    androidSourcePermissions: parseAndroidPermissions(
      readFileSync(path.join(root, 'android/app/src/main/AndroidManifest.xml'), 'utf8'),
    ),
    literalHosts: extractLiteralHostsFromDart(path.join(root, 'lib')),
  };
  const androidSourceManifest = path.join(root, 'android/app/src/main/AndroidManifest.xml');
  const extractionRulesPath = path.join(root, contract.android?.dataExtractionRules?.path ?? '');
  const extractionRulesText = existsSync(extractionRulesPath)
    ? readFileSync(extractionRulesPath, 'utf8')
    : '';
  const requiredBackupDomains = [
    'root',
    'file',
    'database',
    'sharedpref',
    'external',
    'device_root',
    'device_file',
    'device_database',
    'device_sharedpref',
  ];
  const cloudSection = extractionRulesText.match(/<cloud-backup\b[\s\S]*?<\/cloud-backup>/)?.[0] ?? '';
  const transferSection = extractionRulesText.match(/<device-transfer>[\s\S]*?<\/device-transfer>/)?.[0] ?? '';
  const excludesEveryDomain = (section) =>
    requiredBackupDomains.every((domain) =>
      new RegExp(`<exclude\\s+domain="${domain}"\\s+path="\\."\\s*\\/>`).test(section),
    );
  observed.androidSourceManifestSha256 = sha256File(androidSourceManifest);
  observed.androidDataExtractionRulesSha256 = existsSync(extractionRulesPath)
    ? sha256File(extractionRulesPath)
    : null;
  observed.androidBackupPolicyDenyAll =
    /android:allowBackup="false"/.test(readFileSync(androidSourceManifest, 'utf8')) &&
    /android:dataExtractionRules="@xml\/data_extraction_rules"/.test(
      readFileSync(androidSourceManifest, 'utf8'),
    ) &&
    excludesEveryDomain(cloudSection) &&
    excludesEveryDomain(transferSection);
  if (androidManifestPath) {
    const absolute = path.resolve(root, androidManifestPath);
    observed.androidMergedManifestPath = path.relative(root, absolute);
    observed.androidMergedManifestSha256 = existsSync(absolute) ? sha256File(absolute) : null;
    const mergedText = existsSync(absolute) ? readFileSync(absolute, 'utf8') : '';
    observed.androidMergedPermissions = parseAndroidPermissions(mergedText);
    observed.androidMergedBackupPolicy = parseAndroidBackupPolicy(mergedText);
  }
  if (appleBundlePath) {
    const absoluteBundle = path.resolve(root, appleBundlePath);
    const candidates = [
      path.join(absoluteBundle, 'PrivacyInfo.xcprivacy'),
      path.join(absoluteBundle, 'Contents/Resources/PrivacyInfo.xcprivacy'),
    ];
    const manifestIndex = candidates.findIndex((candidate) => existsSync(candidate));
    const manifest = manifestIndex >= 0 ? candidates[manifestIndex] : null;
    observed.appleBundlePath = path.relative(root, absoluteBundle);
    observed.appleBundleManifestMissing = !manifest;
    observed.appleBundleManifestSha256 = manifest ? sha256File(manifest) : null;
    observed.appleBundleManifestContractPath =
      manifestIndex === 0
        ? 'ios/Runner/PrivacyInfo.xcprivacy'
        : manifestIndex === 1
          ? 'macos/Runner/PrivacyInfo.xcprivacy'
          : null;
  }
  return { contract, observed };
}

function parseArgs(argv) {
  const options = { requireStoreApproval: false };
  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (value === '--require-store-approval') options.requireStoreApproval = true;
    else if (value === '--android-manifest') options.androidManifestPath = argv[++index];
    else if (value === '--apple-bundle') options.appleBundlePath = argv[++index];
    else throw new Error(`Unknown argument: ${value}`);
  }
  return options;
}

function runCli() {
  const options = parseArgs(process.argv.slice(2));
  const { contract, observed } = collectObserved(options);
  const findings = validateContractSnapshot(contract, observed, options);
  const sourceIdentity = sha256Bytes(
    JSON.stringify({
      contract_sha256: sha256File(contractPath),
      lock_identities: observed.lockIdentities,
      runtime_direct_dependencies: observed.runtimeDirectDependencies,
      operator_dependencies: observed.operatorDependencies,
      apple_manifest_digests: observed.appleManifestDigests,
      third_party_apple_manifest_digests:
        observed.thirdPartyAppleManifestDigests,
      keychain_entitlement_digests: observed.keychainEntitlementDigests,
      apple_project_privacy_resource: observed.appleProjectPrivacyResource,
      apple_release_entitlements: observed.appleReleaseEntitlements,
      android_source_manifest_sha256: observed.androidSourceManifestSha256,
      android_data_extraction_rules_sha256:
        observed.androidDataExtractionRulesSha256,
      android_source_permissions: observed.androidSourcePermissions,
      literal_hosts: observed.literalHosts,
    }),
  );
  const report = {
    report_type: 'parkinsum_store_privacy_contract',
    schema_version: 1,
    pass: findings.length === 0,
    release_approval_required: options.requireStoreApproval,
    repository_reviewed_at: contract.review?.reviewedAt ?? null,
    store_owner_approval: contract.review?.storeOwnerApproval ?? null,
    source_identity_sha256: sourceIdentity,
    pubspec_package_count: Object.keys(observed.pubspecPackages ?? {}).length,
    literal_host_count: observed.literalHosts?.length ?? 0,
    android_merged_manifest_sha256: observed.androidMergedManifestSha256 ?? null,
    apple_bundle_manifest_sha256: observed.appleBundleManifestSha256 ?? null,
    findings,
    boundary:
      'A passing repository gate proves declaration drift was not detected. It is not legal advice, store-owner approval, an App Store Connect receipt, or a Play Console receipt.',
  };
  const outputDir = path.join(root, 'build/store_privacy');
  mkdirSync(outputDir, { recursive: true });
  writeFileSync(path.join(outputDir, 'latest.json'), `${JSON.stringify(report, null, 2)}\n`);
  const markdown = [
    '# Store privacy contract check',
    '',
    `**Result:** ${report.pass ? 'pass' : `${findings.length} blocker(s)`}`,
    `**Repository review date:** ${report.repository_reviewed_at}`,
    `**Store-owner approval:** ${report.store_owner_approval}`,
    `**Source identity:** \`${sourceIdentity}\``,
    '',
    report.boundary,
    '',
    ...(findings.length === 0
      ? ['No repository declaration drift was detected.']
      : findings.map((finding) => `- \`${finding.code}\`: ${finding.message}`)),
    '',
  ].join('\n');
  writeFileSync(path.join(outputDir, 'latest.md'), markdown);
  if (findings.length === 0) {
    console.log(
      `Store privacy contract passed: ${report.pubspec_package_count} pub packages, ` +
        `${report.literal_host_count} literal hosts, source ${sourceIdentity}.`,
    );
    process.exit(0);
  }
  for (const finding of findings) console.error(`${finding.code}: ${finding.message}`);
  process.exit(1);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  runCli();
}
