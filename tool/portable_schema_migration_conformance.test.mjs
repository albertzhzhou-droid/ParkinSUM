import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import {
  canonicalDigest,
  canonicalize,
  isDartInt,
  parseJsonRejectingDuplicates,
  runConformance,
  validateEnvelope,
  validateReceipt,
} from './portable_schema_migration_conformance.mjs';

const vectors = parseJsonRejectingDuplicates(
  fs.readFileSync('build/portable_schema_migration/dart_vectors.json', 'utf8'),
);

test('independent canonicalizer preserves order independence and Unicode bytes', () => {
  assert.equal(
    canonicalize({ z: 1, a: { y: true, x: null } }),
    canonicalize({ a: { x: null, y: true }, z: 1 }),
  );
  assert.notEqual(canonicalDigest({ value: 'é' }), canonicalDigest({ value: 'é' }));
});

test('duplicate object members are rejected before JSON.parse last-value wins', () => {
  assert.throws(
    () => parseJsonRejectingDuplicates('{"a":1,"\\u0061":2}'),
    /duplicate_object_member:a/,
  );
  assert.deepEqual(parseJsonRejectingDuplicates('{"a":[1,{"b":true}]}'), {
    a: [1, { b: true }],
  });
});

test('numeric canonicalizer preserves Dart VM lexical types and int bounds', () => {
  const fixture = vectors.numericCanonicalizationFixtures[0];
  const parsed = parseJsonRejectingDuplicates(fixture.sourceJson);
  assert.equal(canonicalize(parsed), fixture.canonicalJson);
  assert.equal(canonicalize(fixture.sourceDocument), fixture.canonicalJson);

  const typed = parseJsonRejectingDuplicates(
    '{"int":1,"double":1.0,"maximum":9223372036854775807,' +
      '"above":9223372036854775808}',
  );
  assert.equal(isDartInt(typed, 'int', typed.int), true);
  assert.equal(isDartInt(typed, 'double', typed.double), false);
  assert.equal(isDartInt(typed, 'maximum', typed.maximum), true);
  assert.equal(isDartInt(typed, 'above', typed.above), false);

  const mutated = parseJsonRejectingDuplicates(
    '{"integer":9223372036854775807,"double":1.0}',
  );
  mutated.integer = 0;
  mutated.double = 2;
  assert.equal(canonicalize(mutated), '{"double":2,"integer":0}');
});

test('frozen envelope and receipt mutations fail closed', () => {
  const fixture = vectors.fixtures[0];
  const unknown = structuredClone(fixture.sourceDocument);
  unknown.future = true;
  assert.throws(() => validateEnvelope(unknown, 2), /key_mismatch/);

  const receipt = structuredClone(fixture.receipt);
  receipt.decision = 'durable_import_authorized';
  assert.throws(() => validateReceipt(receipt), /receipt_digest_drift/);
});

test('Dart vectors pass independent migration and mutation conformance', () => {
  const report = runConformance(vectors);
  assert.equal(report.pass, true, report.failures.join('\n'));
  assert.equal(report.dartFixtureCount, 3);
  assert.equal(report.numericCanonicalizationFixtureCount, 1);
  assert.deepEqual(report.numericCanonicalizationResults, [
    { id: 'dart_json_number_lexical_types', pass: true },
  ]);
  assert.deepEqual(report.mutationResults, {
    property_reordering_preserves_canonical_output: true,
    unknown_root_field_blocked: true,
    omitted_required_field_blocked: true,
    mixed_version_field_blocked: true,
    duplicate_object_member_blocked_before_decode: true,
    future_schema_blocked: true,
    receipt_digest_mutation_blocked: true,
    null_and_zero_preserved: true,
    unicode_code_points_preserved_without_normalization: true,
  });
});
