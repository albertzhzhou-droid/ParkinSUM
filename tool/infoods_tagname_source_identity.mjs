#!/usr/bin/env node

import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const modulePath = fileURLToPath(import.meta.url);
const repoRoot = path.dirname(path.dirname(modulePath));
export const INFOODS_TAGNAME_SOURCE_IDENTITY_SCHEMA_URI =
  'parkinsum.infoods-tagname-source-identity/1';
const sourcePageUrl =
  'https://www.fao.org/infoods/infoods/standards-guidelines/food-component-identifiers-tagnames/en/';

const manifestPath = path.join(
  repoRoot,
  'config',
  'infoods_tagname_source_identity.json',
);

function isRecord(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function exactKeys(value, keys, label, failures) {
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
    failures.push(label + ' keys must be exactly: ' + expected.join(', '));
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
  if (!isRecord(manifest?.contentAddress)) return null;
  const { digestHex: _ignoredDigest, ...addressMetadata } = manifest.contentAddress;
  const payload = {
    ...manifest,
    contentAddress: addressMetadata,
  };
  return createHash('sha256')
    .update(canonicalJson(payload), 'utf8')
    .digest('hex');
}

export function validateInfoodsTagnameSourceIdentity(manifest) {
  const failures = [];
  if (
    !exactKeys(
      manifest,
      [
        'schemaUri',
        'schemaVersion',
        'reviewedAt',
        'terminology',
        'sourcePage',
        'sourceVerification',
        'consumptionBoundary',
        'contentAddress',
      ],
      'manifest',
      failures,
    )
  ) {
    return failures;
  }
  if (manifest.schemaUri !== INFOODS_TAGNAME_SOURCE_IDENTITY_SCHEMA_URI) {
    failures.push('schemaUri does not match the INFOODS source contract');
  }
  if (manifest.schemaVersion !== 1) failures.push('schemaVersion must be 1');
  if (!/^\d{4}-\d{2}-\d{2}$/.test(manifest.reviewedAt ?? '')) {
    failures.push('reviewedAt must be an ISO date');
  }

  if (
    exactKeys(
      manifest.terminology,
      ['id', 'publisher', 'jurisdictionScope'],
      'terminology',
      failures,
    )
  ) {
    if (manifest.terminology.id !== 'FAO/INFOODS Food Component Tagnames') {
      failures.push('terminology id must identify the FAO/INFOODS tagnames');
    }
    if (
      manifest.terminology.publisher !==
      'Food and Agriculture Organization of the United Nations'
    ) {
      failures.push('publisher must be FAO');
    }
    if (manifest.terminology.jurisdictionScope !== 'global') {
      failures.push('terminology jurisdiction scope must remain global');
    }
  }

  const sourceKeys = [
    'url',
    'reportedLastUpdated',
    'baseWork',
    'baseWorkYear',
    'baseListUpdatedThroughYear',
    'publishedAdditions',
    'proposedAdditionalTagnameCount',
    'proposedTagnameState',
    'consolidatedExcelListState',
  ];
  if (exactKeys(manifest.sourcePage, sourceKeys, 'sourcePage', failures)) {
    const source = manifest.sourcePage;
    if (source.url !== sourcePageUrl) {
      failures.push('sourcePage.url must be the official FAO/INFOODS page');
    }
    if (!/^\d{4}-\d{2}-\d{2}$/.test(source.reportedLastUpdated ?? '')) {
      failures.push('reportedLastUpdated must be an ISO date');
    } else if (source.reportedLastUpdated > manifest.reviewedAt) {
      failures.push('reportedLastUpdated cannot be later than reviewedAt');
    }
    if (source.baseWorkYear !== 1989 || source.baseListUpdatedThroughYear !== 2007) {
      failures.push('base-work and base-list years must match the reviewed source');
    }
    if (
      source.baseWork !==
      'Identification of Food Components for INFOODS Data Interchange'
    ) {
      failures.push('baseWork must identify the cited source work');
    }
    const additions = source.publishedAdditions;
    if (
      !Array.isArray(additions) ||
      additions.length !== 2 ||
      additions[0]?.year !== 2008 ||
      additions[0]?.count !== 142 ||
      additions[1]?.year !== 2010 ||
      additions[1]?.count !== 156
    ) {
      failures.push('publishedAdditions must match the two dated page entries');
    }
    if (source.proposedAdditionalTagnameCount !== 130) {
      failures.push('proposed count must remain distinct from published tags');
    }
    if (
      source.proposedTagnameState !== 'coming_soon' ||
      source.consolidatedExcelListState !== 'coming_soon'
    ) {
      failures.push('proposed and consolidated lists must remain marked coming soon');
    }
  }

  if (
    exactKeys(
      manifest.sourceVerification,
      [
        'pageReviewedOnline',
        'pageArchivedLocally',
        'remotePageDigest',
        'completeTagnameListDownloaded',
        'tagnameRowsBundled',
        'releaseIdentity',
      ],
      'sourceVerification',
      failures,
    )
  ) {
    const verification = manifest.sourceVerification;
    if (verification.pageReviewedOnline !== true) {
      failures.push('page must be marked reviewed online');
    }
    if (
      verification.pageArchivedLocally !== false ||
      verification.remotePageDigest !== null
    ) {
      failures.push('remote page cannot be described as locally archived or hashed');
    }
    if (
      verification.completeTagnameListDownloaded !== false ||
      verification.tagnameRowsBundled !== false
    ) {
      failures.push('complete tagname data cannot be claimed as downloaded or bundled');
    }
    if (verification.releaseIdentity !== 'not_established') {
      failures.push('a current INFOODS release identity is not established');
    }
  }

  if (
    exactKeys(
      manifest.consumptionBoundary,
      [
        'mappingRecordsShipped',
        'algorithmIdentityBound',
        'currentVocabularyCompletenessEstablished',
        'terminologyConformance',
        'mappingDisposition',
      ],
      'consumptionBoundary',
      failures,
    )
  ) {
    const boundary = manifest.consumptionBoundary;
    for (const key of [
      'mappingRecordsShipped',
      'algorithmIdentityBound',
      'currentVocabularyCompletenessEstablished',
      'terminologyConformance',
    ]) {
      if (boundary[key] !== false) failures.push(key + ' must remain false');
    }
    if (
      boundary.mappingDisposition !==
      'hold_no_mapping_until_a_versioned_complete_source_is_reviewed'
    ) {
      failures.push('mappingDisposition must keep mappings on hold');
    }
  }

  if (
    exactKeys(
      manifest.contentAddress,
      ['algorithm', 'canonicalization', 'digestHex'],
      'contentAddress',
      failures,
    )
  ) {
    if (manifest.contentAddress.algorithm !== 'SHA-256') {
      failures.push('contentAddress algorithm must be SHA-256');
    }
    if (
      manifest.contentAddress.canonicalization !== 'parkinsum-sorted-json-v1'
    ) {
      failures.push('contentAddress canonicalization must be parkinsum-sorted-json-v1');
    }
    if (!/^[a-f0-9]{64}$/.test(manifest.contentAddress.digestHex ?? '')) {
      failures.push('contentAddress digestHex must be lowercase SHA-256');
    } else if (manifest.contentAddress.digestHex !== computeManifestDigest(manifest)) {
      failures.push('contentAddress digest does not match the manifest metadata');
    }
  }
  return failures;
}

export function readAndValidateInfoodsTagnameSourceIdentity() {
  try {
    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    return { manifest, failures: validateInfoodsTagnameSourceIdentity(manifest) };
  } catch (error) {
    return {
      manifest: null,
      failures: ['cannot read INFOODS source identity: ' + error.message],
    };
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === modulePath) {
  const { manifest, failures } = readAndValidateInfoodsTagnameSourceIdentity();
  if (failures.length > 0) {
    process.stderr.write(failures.join('\n') + '\n');
    process.exitCode = 1;
  } else {
    process.stdout.write(
      `INFOODS tagnames source-currency hold passed: reviewed ${manifest.reviewedAt}; page reports ${manifest.sourcePage.reportedLastUpdated}; no complete release or mappings asserted.\n`,
    );
  }
}
