import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  computeManifestDigest,
  readAndValidateInfoodsTagnameSourceIdentity,
  validateInfoodsTagnameSourceIdentity,
} from './infoods_tagname_source_identity.mjs';

const repoRoot = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const original = JSON.parse(
  fs.readFileSync(
    path.join(repoRoot, 'config', 'infoods_tagname_source_identity.json'),
    'utf8',
  ),
);

function rehash(mutator) {
  const candidate = structuredClone(original);
  mutator(candidate);
  candidate.contentAddress.digestHex = computeManifestDigest(candidate);
  return candidate;
}

function expectFailure(candidate, pattern) {
  const failures = validateInfoodsTagnameSourceIdentity(candidate);
  assert.ok(
    failures.some((failure) => pattern.test(failure)),
    'expected failure matching ' + pattern + ', got: ' + failures.join('; '),
  );
}

test('FAO/INFOODS page identity preserves its stated age and published history', () => {
  const { manifest, failures } = readAndValidateInfoodsTagnameSourceIdentity();
  assert.deepEqual(failures, []);
  assert.equal(manifest.reviewedAt, '2026-09-24');
  assert.equal(manifest.sourcePage.reportedLastUpdated, '2022-10-20');
  assert.equal(manifest.sourcePage.baseWorkYear, 1989);
  assert.equal(manifest.sourcePage.baseListUpdatedThroughYear, 2007);
  assert.deepEqual(manifest.sourcePage.publishedAdditions, [
    { year: 2008, count: 142 },
    { year: 2010, count: 156 },
  ]);
});

test('proposed and consolidated lists remain distinct from a released vocabulary', () => {
  assert.equal(original.sourcePage.proposedAdditionalTagnameCount, 130);
  assert.equal(original.sourcePage.proposedTagnameState, 'coming_soon');
  assert.equal(original.sourcePage.consolidatedExcelListState, 'coming_soon');
  assert.equal(original.sourceVerification.releaseIdentity, 'not_established');
  expectFailure(
    rehash((candidate) => {
      candidate.sourcePage.consolidatedExcelListState = 'published';
    }),
    /remain marked coming soon/,
  );
});

test('source observation does not claim a local archive, complete download, or mapping', () => {
  for (const key of [
    'pageArchivedLocally',
    'completeTagnameListDownloaded',
    'tagnameRowsBundled',
  ]) {
    expectFailure(
      rehash((candidate) => {
        candidate.sourceVerification[key] = true;
      }),
      /cannot be described as locally archived|cannot be claimed as downloaded or bundled/,
    );
  }
  expectFailure(
    rehash((candidate) => {
      candidate.consumptionBoundary.mappingRecordsShipped = true;
    }),
    /mappingRecordsShipped must remain false/,
  );
});

test('page source and reported update date are pinned to the official record', () => {
  expectFailure(
    rehash((candidate) => {
      candidate.sourcePage.url = 'https://example.invalid/tagnames';
    }),
    /official FAO\/INFOODS page/,
  );
  expectFailure(
    rehash((candidate) => {
      candidate.sourcePage.reportedLastUpdated = '2026-09-25';
    }),
    /cannot be later than reviewedAt/,
  );
});

test('metadata digest binds provenance and the hold boundary', () => {
  assert.equal(original.contentAddress.digestHex, computeManifestDigest(original));
  const changed = structuredClone(original);
  changed.sourcePage.publishedAdditions[0].count += 1;
  assert.notEqual(
    changed.contentAddress.digestHex,
    computeManifestDigest(changed),
  );
  expectFailure(
    rehash((candidate) => {
      candidate.consumptionBoundary.terminologyConformance = true;
    }),
    /terminologyConformance must remain false/,
  );
});
