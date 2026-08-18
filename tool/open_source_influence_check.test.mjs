import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import {
  buildObservedInventory,
  normalizeGitHubRepository,
  validateInfluenceInventory,
} from './open_source_influence_check.mjs';

const committed = JSON.parse(
  readFileSync('config/open_source_influence_inventory.json', 'utf8'),
);

function fixture() {
  const inventory = structuredClone(committed);
  return { inventory, observed: buildObservedInventory(inventory) };
}

function codes(inventory, observed) {
  return validateInfluenceInventory(inventory, observed).map(
    (item) => item.code,
  );
}

test('committed inventory covers every documented influence and release path', () => {
  const { inventory, observed } = fixture();
  assert.deepEqual(validateInfluenceInventory(inventory, observed), []);
  assert.equal(inventory.influences.length, 34);
  assert.deepEqual(
    inventory.influences
      .filter((entry) => entry.transferStatus !== 'concept_only')
      .map((entry) => entry.id),
    ['flutter_framework', 'flutter_local_notifications'],
  );
});

test('GitHub URL normalization collapses case, paths, and dot-git aliases', () => {
  assert.equal(
    normalizeGitHubRepository(
      'https://github.com/FriesI23/mhabit/blob/main/LICENSE',
    ),
    'friesi23/mhabit',
  );
  assert.equal(
    normalizeGitHubRepository('https://github.com/FriesI23/mhabit.git'),
    'friesi23/mhabit',
  );
});

test('missing or newly documented upstream influence fails closed', () => {
  const { inventory, observed } = fixture();
  inventory.influences.pop();
  assert(codes(inventory, observed).includes('influence_discovery_drift'));

  const next = fixture();
  next.observed.githubRepositories.push('example/new-upstream');
  assert(
    codes(next.inventory, next.observed).includes('influence_discovery_drift'),
  );
});

test('concept-only research cannot acquire local or distribution authority', () => {
  const { inventory, observed } = fixture();
  const entry = inventory.influences.find((value) => value.id === 'rxode2');
  entry.localPaths = ['pubspec.yaml'];
  entry.copyingAuthorized = true;
  assert(
    codes(inventory, observed).includes('concept_only_boundary_violation'),
  );
});

test('unresolved license can never cross the release boundary', () => {
  const { inventory, observed } = fixture();
  const entry = inventory.influences.find((value) => value.id === 'healthlog');
  entry.transferStatus = 'linked';
  entry.copyingAuthorized = true;
  entry.distributionAuthorized = true;
  entry.localPaths = ['pubspec.lock'];
  entry.obligations = ['license_notice'];
  inventory.releaseBoundary.copiedLinkedVendoredOrDerivedInfluenceIds.push(
    'healthlog',
  );
  assert(codes(inventory, observed).includes('unresolved_license_transfer'));
});

test('reciprocal transfer requires legal review, notice, and source disclosure', () => {
  const { inventory, observed } = fixture();
  const entry = inventory.influences.find((value) => value.id === 'rxode2');
  entry.transferStatus = 'derived';
  entry.copyingAuthorized = true;
  entry.distributionAuthorized = true;
  entry.localPaths = ['pubspec.lock'];
  entry.obligations = ['license_notice'];
  inventory.releaseBoundary.copiedLinkedVendoredOrDerivedInfluenceIds.push(
    'rxode2',
  );
  const result = codes(inventory, observed);
  assert(result.includes('missing_license_obligation'));
  assert.equal(
    validateInfluenceInventory(inventory, observed).filter(
      (item) => item.code === 'missing_license_obligation',
    ).length,
    2,
  );
});

test('permissive copied code still requires a license notice', () => {
  const { inventory, observed } = fixture();
  const entry = inventory.influences.find(
    (value) => value.id === 'ohif_viewers',
  );
  entry.transferStatus = 'copied';
  entry.copyingAuthorized = true;
  entry.distributionAuthorized = true;
  entry.localPaths = ['pubspec.lock'];
  entry.obligations = [];
  inventory.releaseBoundary.copiedLinkedVendoredOrDerivedInfluenceIds.push(
    'ohif_viewers',
  );
  assert(codes(inventory, observed).includes('missing_license_obligation'));
});

test('duplicate identity, malformed commit, and extra fields are rejected', () => {
  const duplicate = fixture();
  duplicate.inventory.influences[1].id =
    duplicate.inventory.influences[0].id;
  assert(
    codes(duplicate.inventory, duplicate.observed).includes(
      'duplicate_influence_id',
    ),
  );

  const malformed = fixture();
  malformed.inventory.influences[0].pinnedCommit = 'main';
  malformed.inventory.influences[0].unexpected = true;
  const result = codes(malformed.inventory, malformed.observed);
  assert(result.includes('invalid_pinned_commit'));
  assert(result.includes('unsupported_influence_shape'));
});

test('license status cannot overstate GitHub or declared evidence', () => {
  const { inventory, observed } = fixture();
  const unresolved = inventory.influences.find(
    (value) => value.id === 'healthlog',
  );
  unresolved.licenseStatus = 'machine_detected';
  assert(codes(inventory, observed).includes('false_machine_detection'));
});

test('unreviewed vendored directory and release-boundary identity drift block', () => {
  const { inventory, observed } = fixture();
  observed.vendoredDirectories.push('lib/vendor');
  assert(codes(inventory, observed).includes('vendored_artifact_drift'));

  const next = fixture();
  next.inventory.releaseBoundary.copiedLinkedVendoredOrDerivedInfluenceIds = [];
  assert(
    codes(next.inventory, next.observed).includes(
      'release_boundary_identity_drift',
    ),
  );
});

test('linked version and pinned source revision must match reviewed files', () => {
  const { inventory, observed } = fixture();
  inventory.releaseBoundary.linkedVersionEvidence.flutter_framework.version =
    '99.0.0';
  inventory.releaseBoundary.linkedVersionEvidence.flutter_local_notifications.sourceRevision =
    'f'.repeat(40);
  const result = codes(inventory, observed);
  assert(result.includes('linked_version_source_mismatch'));
  assert(result.includes('linked_source_revision_mismatch'));
});
