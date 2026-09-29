#!/usr/bin/env node

import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const modulePath = fileURLToPath(import.meta.url);
const repoRoot = path.dirname(path.dirname(modulePath));
export const RXNORM_RELEASE_IDENTITY_SCHEMA_URI =
  'parkinsum.rxnorm-release-identity/1';

const activeTermTypes = [
  'GPCK',
  'BPCK',
  'SCD',
  'SBD',
  'MIN',
  'IN',
  'PIN',
  'BN',
  'DF',
];

const expectedTopLevelKeys = [
  'schemaUri',
  'schemaVersion',
  'reviewedAt',
  'terminology',
  'release',
  'scope',
  'terms',
  'consumptionBoundary',
  'contentAddress',
];

function isRecord(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function hasExactKeys(value, keys, label, failures) {
  if (!isRecord(value)) {
    failures.push(label + ' must be an object');
    return false;
  }
  const actual = Object.keys(value).sort();
  const expected = [...keys].sort();
  if (
    actual.length !== expected.length ||
    actual.some((key, index) => key !== expected[index])
  ) {
    failures.push(
      label + ' keys must be exactly: ' + expected.join(', '),
    );
    return false;
  }
  return true;
}

export function canonicalJson(value) {
  if (Array.isArray(value)) {
    return '[' + value.map(canonicalJson).join(',') + ']';
  }
  if (isRecord(value)) {
    const members = Object.keys(value)
      .sort()
      .map((key) => JSON.stringify(key) + ':' + canonicalJson(value[key]));
    return '{' + members.join(',') + '}';
  }
  return JSON.stringify(value);
}

export function computeManifestDigest(manifest) {
  const contentAddress = manifest?.contentAddress;
  if (!isRecord(contentAddress)) return null;
  const { digestHex: _ignoredDigest, ...contentAddressMetadata } =
    contentAddress;
  const payload = {
    ...manifest,
    contentAddress: contentAddressMetadata,
  };
  return createHash('sha256').update(canonicalJson(payload), 'utf8').digest('hex');
}

export function validateRxNormReleaseIdentity(manifest) {
  const failures = [];
  if (
    !hasExactKeys(
      manifest,
      expectedTopLevelKeys,
      'manifest',
      failures,
    )
  ) {
    return failures;
  }

  if (manifest.schemaUri !== RXNORM_RELEASE_IDENTITY_SCHEMA_URI) {
    failures.push('schemaUri does not match the source contract');
  }
  if (manifest.schemaVersion !== 1) {
    failures.push('schemaVersion must be 1');
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(manifest.reviewedAt ?? '')) {
    failures.push('reviewedAt must be an ISO date');
  }

  const terminologyKeys = [
    'id',
    'publisher',
    'releaseProduct',
    'jurisdictionScope',
  ];
  if (
    hasExactKeys(
      manifest.terminology,
      terminologyKeys,
      'terminology',
      failures,
    )
  ) {
    if (manifest.terminology.id !== 'RxNorm') {
      failures.push('terminology id must be RxNorm');
    }
    if (manifest.terminology.publisher !== 'U.S. National Library of Medicine') {
      failures.push('terminology publisher must be the U.S. NLM');
    }
    if (manifest.terminology.releaseProduct !== 'Current Prescribable Content') {
      failures.push('release product must identify Current Prescribable Content');
    }
    if (manifest.terminology.jurisdictionScope !== 'US-centric') {
      failures.push('RxNorm jurisdiction scope must remain US-centric');
    }
  }

  const releaseKeys = [
    'date',
    'filename',
    'downloadUrl',
    'publisherChecksum',
    'releaseNotesUrl',
  ];
  if (
    hasExactKeys(manifest.release, releaseKeys, 'release', failures)
  ) {
    const date = manifest.release.date;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date ?? '')) {
      failures.push('release date must be an ISO date');
    } else {
      const compactDate = date.slice(5, 7) + date.slice(8, 10) + date.slice(0, 4);
      const expectedFilename =
        'RxNorm_full_prescribe_' + compactDate + '.zip';
      if (manifest.release.filename !== expectedFilename) {
        failures.push('release filename must encode the pinned release date');
      }
      if (manifest.reviewedAt < date) {
        failures.push('release date cannot be later than reviewedAt');
      }
    }
    const expectedDownloadUrl =
      'https://download.nlm.nih.gov/umls/kss/rxnorm/' +
      manifest.release.filename;
    if (manifest.release.downloadUrl !== expectedDownloadUrl) {
      failures.push('downloadUrl must point to the exact dated NLM file');
    }
    if (/current/i.test(manifest.release.downloadUrl ?? '')) {
      failures.push('generic current URLs are not release identities');
    }
    const checksum = manifest.release.publisherChecksum;
    if (
      hasExactKeys(
        checksum,
        ['algorithm', 'value', 'sourceUrl', 'localVerification'],
        'publisherChecksum',
        failures,
      )
    ) {
      if (checksum.algorithm !== 'MD5' || !/^[a-f0-9]{32}$/.test(checksum.value)) {
        failures.push('publisher checksum must be a lowercase 32-digit MD5');
      }
      if (
        checksum.sourceUrl !==
        'https://www.nlm.nih.gov/research/umls/rxnorm/docs/rxnormfiles.html'
      ) {
        failures.push('publisher checksum must cite the official NLM file listing');
      }
      if (checksum.localVerification !== 'not_downloaded') {
        failures.push('publisher checksum cannot be called locally verified');
      }
    }
    if (
      typeof manifest.release.releaseNotesUrl !== 'string' ||
      !manifest.release.releaseNotesUrl.startsWith(
        'https://www.nlm.nih.gov/research/umls/rxnorm/docs/',
      ) ||
      !manifest.release.releaseNotesUrl.endsWith(
        'rxnorm_releasenotes_prescribe_' +
          date.slice(5, 7) +
          date.slice(8, 10) +
          date.slice(0, 4) +
          '.html',
      )
    ) {
      failures.push('release notes must be linked from official NLM');
    }
  }

  const scopeKeys = [
    'sourceVocabulary',
    'activeTermTypeCounts',
    'rxnormNdcCount',
    'evidenceUrl',
    'interpretation',
  ];
  if (hasExactKeys(manifest.scope, scopeKeys, 'scope', failures)) {
    if (manifest.scope.sourceVocabulary !== 'RXNORM') {
      failures.push('source vocabulary must be RXNORM');
    }
    if (
      hasExactKeys(
        manifest.scope.activeTermTypeCounts,
        activeTermTypes,
        'activeTermTypeCounts',
        failures,
      )
    ) {
      for (const [termType, count] of Object.entries(
        manifest.scope.activeTermTypeCounts,
      )) {
        if (!Number.isSafeInteger(count) || count < 0) {
          failures.push(termType + ' active count must be a non-negative integer');
        }
      }
    }
    if (
      !Number.isSafeInteger(manifest.scope.rxnormNdcCount) ||
      manifest.scope.rxnormNdcCount < 0
    ) {
      failures.push('rxnormNdcCount must be a non-negative integer');
    }
    if (
      manifest.scope.evidenceUrl !== manifest.release?.releaseNotesUrl
    ) {
      failures.push('scope counts and release notes must share one evidence URL');
    }
    if (
      !String(manifest.scope.interpretation).includes(
        'archive is not parsed by this project',
      )
    ) {
      failures.push('scope must state that the release archive is not parsed');
    }
  }

  const termKeys = [
    'currentPrescribableContentDownload',
    'fullMonthlyReleaseDownload',
    'attributionRequested',
    'redistributionCurrencyDisclosureRequired',
    'noNLMEndorsementOrLogo',
    'otherSourceVocabularyRestrictions',
    'evidenceUrl',
  ];
  if (hasExactKeys(manifest.terms, termKeys, 'terms', failures)) {
    if (
      manifest.terms.currentPrescribableContentDownload !==
      'no_license_required_per_NLM_release_listing'
    ) {
      failures.push('Current Prescribable Content download disposition drifted');
    }
    if (
      manifest.terms.fullMonthlyReleaseDownload !==
      'free_UMLS_license_required'
    ) {
      failures.push('full monthly RxNorm release licensing boundary drifted');
    }
    for (const key of [
      'attributionRequested',
      'redistributionCurrencyDisclosureRequired',
      'noNLMEndorsementOrLogo',
    ]) {
      if (manifest.terms[key] !== true) {
        failures.push(key + ' must remain explicit');
      }
    }
    if (
      manifest.terms.otherSourceVocabularyRestrictions !==
      'not_reviewed_for_full_release'
    ) {
      failures.push('full-release source-vocabulary restrictions remain unreviewed');
    }
    if (
      manifest.terms.evidenceUrl !==
      'https://www.nlm.nih.gov/research/umls/rxnorm/docs/termsofservice.html'
    ) {
      failures.push('terms must cite the official NLM terms page');
    }
  }

  const boundaryKeys = [
    'archiveDownloaded',
    'publisherChecksumVerifiedLocally',
    'terminologyRowsBundled',
    'rxcuiMappingsShipped',
    'absenceInThisSubset',
    'releaseDrift',
    'releaseFreshness',
    'algorithmIdentityBound',
    'clinicalOrTerminologyConformance',
  ];
  if (
    hasExactKeys(
      manifest.consumptionBoundary,
      boundaryKeys,
      'consumptionBoundary',
      failures,
    )
  ) {
    for (const key of [
      'archiveDownloaded',
      'publisherChecksumVerifiedLocally',
      'terminologyRowsBundled',
      'rxcuiMappingsShipped',
      'algorithmIdentityBound',
      'clinicalOrTerminologyConformance',
    ]) {
      if (manifest.consumptionBoundary[key] !== false) {
        failures.push(key + ' must remain false for this metadata-only slice');
      }
    }
    if (
      manifest.consumptionBoundary.absenceInThisSubset !==
      'unresolved_not_retired'
    ) {
      failures.push('absence from the active subset must not imply retirement');
    }
    if (manifest.consumptionBoundary.releaseDrift !== 'hold_and_requalify') {
      failures.push('release drift must hold and require requalification');
    }
    if (
      manifest.consumptionBoundary.releaseFreshness !==
      'NLM_latest_list_confirmed_on_reviewedAt; offline_checker_does_not_recheck'
    ) {
      failures.push('offline validation must not claim current external freshness');
    }
  }

  if (
    hasExactKeys(
      manifest.contentAddress,
      ['algorithm', 'canonicalization', 'digestHex'],
      'contentAddress',
      failures,
    )
  ) {
    if (
      manifest.contentAddress.algorithm !== 'SHA-256' ||
      manifest.contentAddress.canonicalization !==
        'parkinsum-sorted-json-v1'
    ) {
      failures.push('content address algorithm or canonicalization drifted');
    }
    const expectedDigest = computeManifestDigest(manifest);
    if (
      !/^[a-f0-9]{64}$/.test(manifest.contentAddress.digestHex ?? '') ||
      manifest.contentAddress.digestHex !== expectedDigest
    ) {
      failures.push('contentAddress.digestHex does not match the manifest content');
    }
  }

  return failures;
}

export function readAndValidateRxNormReleaseIdentity({
  root = repoRoot,
} = {}) {
  const absolutePath = path.join(root, 'config', 'rxnorm_release_identity.json');
  let manifest;
  try {
    manifest = JSON.parse(fs.readFileSync(absolutePath, 'utf8'));
  } catch (error) {
    return {
      manifest: null,
      failures: ['manifest cannot be read as JSON: ' + error.message],
    };
  }
  return {
    manifest,
    failures: validateRxNormReleaseIdentity(manifest),
  };
}

function main() {
  const { manifest, failures } = readAndValidateRxNormReleaseIdentity();
  if (failures.length > 0 || manifest === null) {
    for (const failure of failures) process.stderr.write('FAIL ' + failure + '\n');
    process.exitCode = 1;
    return;
  }
  process.stdout.write(
    'RxNorm release identity v1 passed: ' +
      manifest.release.filename +
      '; metadata SHA-256 ' +
      manifest.contentAddress.digestHex +
      '; archive not downloaded; no RXCUI mappings shipped.\n',
  );
}

if (process.argv[1] && path.resolve(process.argv[1]) === modulePath) main();
