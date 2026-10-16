import assert from 'node:assert/strict';
import test from 'node:test';

import {
  bodyDigest,
  canonicalize,
  parseCapsuleJson,
  replayMaxJsonBytes,
  replayMaxJsonContainerDepth,
  runConformance,
  validateCapsule,
} from './mechanistic_replay_capsule_conformance.mjs';

const marker = '$parkinsum_number';

function capsule() {
  const value = {
    schema: 'parkinsum.mechanistic-replay-capsule/1',
    schema_version: 1,
    canonicalization_profile: 'parkinsum.jcs-safe-lossless-scalars/1',
    capsule_id: 'node_fixture',
    generated_at_utc: '2026-08-31T12:00:00.000Z',
    timezone_contract: {
      timestamp_semantic: 'historical_event_instant',
      engine_time_representation: 'utc_epoch_minute',
      ledger_time_representation: 'offset_timestamp_plus_utc_instant',
      iana_zone_id: null,
      tzdb_version: null,
      future_civil_time_authorized: false,
      boundary: 'The current engine consumes historical UTC minutes. Event-specific ' +
        'offsets survive in the embedded ledger, but no IANA zone, tzdb ' +
        'release, DST fold or future civil-time intent is fabricated.',
    },
    ledger: { schema_version: { [marker]: 'i64', value: '3' } },
    context: { value: { [marker]: 'f64', value: '3ff0000000000000' } },
    meal_compositions: [],
  };
  value.capsule_sha256 = bodyDigest(value);
  return value;
}

test('canonicalizer is stable under property reordering', () => {
  const original = capsule();
  const reversed = Object.fromEntries(Object.entries(original).reverse());
  assert.equal(canonicalize(reversed), canonicalize(original));
  assert.equal(bodyDigest(reversed), original.capsule_sha256);
});

test('validator rejects native payload numbers after a valid outer rehash', () => {
  const value = capsule();
  value.context.value = 1;
  value.capsule_sha256 = bodyDigest(value);
  assert.throws(() => validateCapsule(value), /native_number_forbidden/);
});

test('validator rejects digest and root-schema drift', () => {
  const digest = capsule();
  digest.capsule_sha256 = '0'.repeat(64);
  assert.throws(() => validateCapsule(digest), /digest_mismatch/);

  const extra = capsule();
  extra.future = true;
  extra.capsule_sha256 = bodyDigest(extra);
  assert.throws(() => validateCapsule(extra), /key_mismatch/);
});

test('raw replay rejects duplicate root, escaped names and members within arrays', () => {
  const value = capsule();
  const raw = canonicalize(value);
  const cases = [
    raw.replace('{', `{"capsule_id":${JSON.stringify(value.capsule_id)},`),
    raw.replace('"context":{', '"context":{"same":true,"sa\\u006de":false,'),
    '{"items":[{"a":1,"\\u0061":1}]}',
  ];
  for (const duplicate of cases) {
    assert.throws(() => parseCapsuleJson(duplicate), /duplicate_object_member/);
  }
});

test('raw replay enforces UTF-8 capacity, container depth and future schema', () => {
  const utf8Oversized = `"${'餐'.repeat(Math.floor(replayMaxJsonBytes / 3) + 1)}"`;
  assert.ok(utf8Oversized.length < replayMaxJsonBytes);
  assert.throws(() => parseCapsuleJson(utf8Oversized), /byte_limit/);
  const tooDeep = `${'['.repeat(replayMaxJsonContainerDepth + 1)}0${']'.repeat(replayMaxJsonContainerDepth + 1)}`;
  assert.throws(() => parseCapsuleJson(tooDeep), /depth_budget/);
  // Rejection at the schema step establishes that the transport ceilings are
  // inclusive; test values are deliberately not replay-capsule objects.
  assert.throws(() => parseCapsuleJson(`${' '.repeat(replayMaxJsonBytes - 2)}{}`), /key_mismatch/);
  assert.throws(() => parseCapsuleJson(`${'['.repeat(replayMaxJsonContainerDepth)}0${']'.repeat(replayMaxJsonContainerDepth)}`), /not_object/);
  const future = capsule();
  future.schema_version = 2;
  future.capsule_sha256 = bodyDigest(future);
  assert.throws(() => parseCapsuleJson(canonicalize(future)), /unsupported_capsule_schema/);
});

test('cross-runtime report covers every mutation family', () => {
  const value = capsule();
  const report = runConformance({
    vectors: [
      {
        scenario: 'nodeFixture',
        capsule_sha256: value.capsule_sha256,
        canonical_json: canonicalize(value),
      },
    ],
  });
  assert.equal(report.pass, true);
  assert.deepEqual(report.mutation_results, {
    map_reordering_stable: true,
    binary64_bit_mutation_detected: true,
    native_json_number_blocked: true,
    null_and_missing_distinct: true,
    unicode_code_points_distinct: true,
  });
});
