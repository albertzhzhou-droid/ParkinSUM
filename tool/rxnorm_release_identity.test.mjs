import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  computeManifestDigest,
  readAndValidateRxNormReleaseIdentity,
  validateRxNormReleaseIdentity,
} from './rxnorm_release_identity.mjs';

const repoRoot = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const original = JSON.parse(
  fs.readFileSync(
    path.join(repoRoot, 'config', 'rxnorm_release_identity.json'),
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
  const failures = validateRxNormReleaseIdentity(candidate);
  assert.ok(
    failures.some((failure) => pattern.test(failure)),
    'expected failure matching ' + pattern + ', got: ' + failures.join('; '),
  );
}

test('pinned NLM Current Prescribable Content release matches published identity', () => {
  const { manifest, failures } = readAndValidateRxNormReleaseIdentity();
  assert.deepEqual(failures, []);
  assert.equal(manifest.release.date, '2026-09-08');
  assert.equal(manifest.release.filename, 'RxNorm_full_prescribe_09082026.zip');
  assert.equal(
    manifest.release.releaseNotesUrl,
    'https://www.nlm.nih.gov/research/umls/rxnorm/docs/2026/rxnorm_releasenotes_prescribe_09082026.html',
  );
  assert.equal(
    manifest.release.publisherChecksum.value,
    '88bbe4cefabd8e71f58651c1c3188646',
  );
  assert.equal(manifest.release.publisherChecksum.localVerification, 'not_downloaded');
  assert.deepEqual(manifest.scope.activeTermTypeCounts, {
    GPCK: 608,
    BPCK: 706,
    SCD: 12076,
    SBD: 8079,
    MIN: 961,
    IN: 5844,
    PIN: 1943,
    BN: 4134,
    DF: 120,
  });
  assert.equal(manifest.scope.rxnormNdcCount, 239152);
  assert.equal(
    manifest.terms.currentPrescribableContentDownload,
    'no_license_required_per_NLM_release_listing',
  );
  assert.equal(manifest.terms.fullMonthlyReleaseDownload, 'free_UMLS_license_required');
});

test('metadata digest binds the complete release, scope, terms, and use boundary', () => {
  assert.equal(
    original.contentAddress.digestHex,
    computeManifestDigest(original),
  );
  const changed = structuredClone(original);
  changed.scope.activeTermTypeCounts.SCD += 1;
  assert.notEqual(
    changed.contentAddress.digestHex,
    computeManifestDigest(changed),
  );
});

test('dated release file and URL must agree with the pinned publication date', () => {
  expectFailure(
    rehash((candidate) => {
      candidate.release.filename = 'RxNorm_full_prescribe_08032026.zip';
    }),
    /filename must encode/,
  );
  expectFailure(
    rehash((candidate) => {
      candidate.release.downloadUrl =
        'https://download.nlm.nih.gov/umls/kss/rxnorm/RxNorm_full_prescribe_current.zip';
    }),
    /exact dated NLM file|generic current/,
  );
});

test('publisher checksum stays a cited MD5 until the archive is actually downloaded', () => {
  expectFailure(
    rehash((candidate) => {
      candidate.release.publisherChecksum.value = 'not-a-checksum';
    }),
    /lowercase 32-digit MD5/,
  );
  expectFailure(
    rehash((candidate) => {
      candidate.consumptionBoundary.publisherChecksumVerifiedLocally = true;
    }),
    /must remain false/,
  );
});

test('active release scope rejects unknown term types and invalid counts', () => {
  const extraType = structuredClone(original);
  extraType.scope.activeTermTypeCounts.UNKNOWN = 1;
  expectFailure(rehash((candidate) => {
    candidate.scope.activeTermTypeCounts = extraType.scope.activeTermTypeCounts;
  }), /activeTermTypeCounts keys/);
  expectFailure(
    rehash((candidate) => {
      candidate.scope.activeTermTypeCounts.SCD = -1;
    }),
    /non-negative integer/,
  );
});

test('subset absence stays unresolved and never means retired', () => {
  expectFailure(
    rehash((candidate) => {
      candidate.consumptionBoundary.absenceInThisSubset = 'retired';
    }),
    /must not imply retirement/,
  );
});

test('metadata-only pin cannot silently turn into bundled mappings or result use', () => {
  for (const key of [
    'archiveDownloaded',
    'terminologyRowsBundled',
    'rxcuiMappingsShipped',
    'algorithmIdentityBound',
    'clinicalOrTerminologyConformance',
  ]) {
    expectFailure(
      rehash((candidate) => {
        candidate.consumptionBoundary[key] = true;
      }),
      /must remain false/,
    );
  }
});

test('license terms distinguish CPC download from the full monthly release', () => {
  expectFailure(
    rehash((candidate) => {
      candidate.terms.fullMonthlyReleaseDownload = 'no_license_required';
    }),
    /full monthly RxNorm release licensing boundary drifted/,
  );
  expectFailure(
    rehash((candidate) => {
      candidate.terms.attributionRequested = false;
    }),
    /attributionRequested must remain explicit/,
  );
});

test('unknown fields force deliberate manifest-version review', () => {
  const candidate = rehash((manifest) => {
    manifest.unreviewedField = 'must not be ignored';
  });
  expectFailure(candidate, /manifest keys must be exactly/);
});

test('content-address tampering fails even when all release fields remain intact', () => {
  const candidate = structuredClone(original);
  candidate.contentAddress.digestHex = '0'.repeat(64);
  expectFailure(candidate, /does not match the manifest content/);
});
