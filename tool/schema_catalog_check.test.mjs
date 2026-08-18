import assert from 'node:assert/strict';
import test from 'node:test';

import {
  readAndValidateSchemaCatalog,
  requiredSchemaSurfaces,
  validateSchemaCatalog,
} from './schema_catalog_check.mjs';

function baseline() {
  const result = readAndValidateSchemaCatalog();
  assert.ok(result.catalog, result.failures.join('\n'));
  return result;
}

function schemaById(catalog, id) {
  const schema = catalog.schemas.find((candidate) => candidate.id === id);
  assert.ok(schema, `missing test fixture schema ${id}`);
  return schema;
}

test('committed catalog covers every required and discovered schema surface', () => {
  const { catalog, failures } = baseline();
  assert.deepEqual(failures, []);
  assert.equal(catalog.schemas.length, requiredSchemaSurfaces.length);
  assert.equal(
    schemaById(catalog, 'parkinsum.algorithm-evaluation').currentVersion,
    4,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.algorithm-configuration').currentVersion,
    2,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.mechanistic-numerical-oracle').currentVersion,
    1,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.mechanistic-event-ledger').currentVersion,
    1,
  );
  assert.equal(
    schemaById(
      catalog,
      'parkinsum.open-source-influence-inventory',
    ).currentVersion,
    1,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.user-portable-data-package').currentVersion,
    1,
  );
  assert.equal(
    schemaById(
      catalog,
      'parkinsum.recoverable-event-restore-impact',
    ).currentVersion,
    1,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.restore-relationship-graph').currentVersion,
    1,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.restore-impact-account').currentVersion,
    1,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.portable-owner-token').currentVersion,
    2,
  );
  assert.equal(
    schemaById(
      catalog,
      'parkinsum.portable-owner-secret-envelope',
    ).currentVersion,
    1,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.protected-secret-store').currentVersion,
    1,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.privacy-safe-support-bundle').currentVersion,
    1,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.purpose-bound-consent-receipt')
      .currentVersion,
    1,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.recoverable-user-event-history')
      .currentVersion,
    1,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.cdss-database-web').versionStatus,
    'unversioned',
  );
});

test('deleting the support-bundle entry fails required and source discovery', () => {
  const { catalog } = baseline();
  const mutated = structuredClone(catalog);
  mutated.schemas = mutated.schemas.filter(
    (schema) => schema.id !== 'parkinsum.privacy-safe-support-bundle',
  );
  const failures = validateSchemaCatalog(mutated);
  assert.ok(
    failures.some((failure) =>
      failure.includes(
        'required schema surface is missing: parkinsum.privacy-safe-support-bundle',
      ),
    ),
  );
  assert.ok(
    failures.some((failure) =>
      failure.includes('privacySafeSupportBundleSchemaVersion'),
    ),
  );
});

test('deleting the portable package entry fails required and source discovery', () => {
  const { catalog } = baseline();
  const mutated = structuredClone(catalog);
  mutated.schemas = mutated.schemas.filter(
    (schema) => schema.id !== 'parkinsum.user-portable-data-package',
  );
  const failures = validateSchemaCatalog(mutated);
  assert.ok(
    failures.some((failure) =>
      failure.includes(
        'required schema surface is missing: parkinsum.user-portable-data-package',
      ),
    ),
  );
  assert.ok(
    failures.some((failure) =>
      failure.includes('userPortableDataPackageSchemaVersion'),
    ),
  );
});

test('deleting the portable owner token boundary fails required discovery', () => {
  const { catalog } = baseline();
  const mutated = structuredClone(catalog);
  mutated.schemas = mutated.schemas.filter(
    (schema) => schema.id !== 'parkinsum.portable-owner-token',
  );
  const failures = validateSchemaCatalog(mutated);
  assert.ok(
    failures.some((failure) =>
      failure.includes(
        'required schema surface is missing: parkinsum.portable-owner-token',
      ),
    ),
  );
  assert.ok(
    failures.some((failure) =>
      failure.includes('userPortableDataOwnerTokenSchemaVersion'),
    ),
  );
});

test('deleting a public schema-URI entry fails required and URI discovery', () => {
  const { catalog } = baseline();
  const mutated = structuredClone(catalog);
  mutated.schemas = mutated.schemas.filter(
    (schema) => schema.id !== 'parkinsum.algorithm-evaluation',
  );
  const failures = validateSchemaCatalog(mutated);
  assert.ok(
    failures.some((failure) =>
      failure.includes(
        'required schema surface is missing: parkinsum.algorithm-evaluation',
      ),
    ),
  );
  assert.ok(
    failures.some((failure) =>
      failure.includes(
        'discovered schema URI is not cataloged: parkinsum.algorithm-evaluation/4',
      ),
    ),
  );
});

test('catalog version drift from production source fails closed', () => {
  const { catalog } = baseline();
  const mutated = structuredClone(catalog);
  schemaById(mutated, 'parkinsum.algorithm-evaluation').currentVersion = 3;
  const failures = validateSchemaCatalog(mutated);
  assert.ok(
    failures.some(
      (failure) =>
        failure.includes('source version 4 does not match catalog 3') ||
        failure.includes('algorithm-evaluation/4 disagrees with catalog'),
    ),
  );
});

test('duplicate schema ids fail closed', () => {
  const { catalog } = baseline();
  const mutated = structuredClone(catalog);
  mutated.schemas.push(
    structuredClone(
      schemaById(mutated, 'parkinsum.atomic-onboarding-commit'),
    ),
  );
  assert.ok(
    validateSchemaCatalog(mutated).some((failure) =>
      failure.includes('duplicate schema id: parkinsum.atomic-onboarding-commit'),
    ),
  );
});

test('missing, escaping, and non-Dart source paths fail closed', () => {
  const { catalog } = baseline();
  for (const badSource of [
    'lib/core/models/does_not_exist.dart',
    '../outside.dart',
    'lib/core/models/intake.json',
  ]) {
    const mutated = structuredClone(catalog);
    schemaById(mutated, 'parkinsum.intake-record').source = badSource;
    const failures = validateSchemaCatalog(mutated);
    assert.ok(
      failures.some(
        (failure) =>
          failure.includes('source does not exist') ||
          failure.includes('normalized relative lib/*.dart path'),
      ),
      `${badSource}: ${failures.join('\n')}`,
    );
  }
});

test('unversioned boundaries cannot pretend to have a catalog version', () => {
  const { catalog } = baseline();
  const mutated = structuredClone(catalog);
  schemaById(mutated, 'parkinsum.cdss-database-web').currentVersion = 1;
  assert.ok(
    validateSchemaCatalog(mutated).some((failure) =>
      failure.includes('unversioned surfaces must use currentVersion null'),
    ),
  );
});

test('unsupported catalog versions and malformed schema collections fail without crashing', () => {
  const { catalog } = baseline();
  const future = structuredClone(catalog);
  future.catalogVersion = 3;
  assert.ok(
    validateSchemaCatalog(future).some((failure) =>
      failure.includes('catalogVersion must be 2'),
    ),
  );

  const malformed = { ...catalog, schemas: { unexpected: true } };
  assert.doesNotThrow(() => validateSchemaCatalog(malformed));
  assert.ok(
    validateSchemaCatalog(malformed).some((failure) =>
      failure.includes('schemas must be a non-empty array'),
    ),
  );
});
