import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import {
  calculateFdcPortionComposition,
  fdcPortionProjectionSha256,
} from './fdc_portion_composition_oracle.mjs';

const vectors = JSON.parse(
  fs.readFileSync('test/fixtures/fdc_portion_composition_vectors.json', 'utf8'),
);

test('independent JavaScript oracle agrees with every shared FDC portion vector', () => {
  assert.equal(vectors.schema_id, 'parkinsum.fdc-portion-composition-vectors/1');
  for (const vector of vectors.cases) {
    const actual = calculateFdcPortionComposition({
      ...vector,
      sourceDocument: vectors.sourceDocument,
    });
    for (const [key, expected] of Object.entries(vector.expected)) {
      if (typeof expected === 'number') {
        assert.ok(Math.abs(actual[key] - expected) < 1e-12, `${vector.id}: ${key}`);
      } else {
        assert.equal(actual[key], expected, vector.id);
      }
    }
  }
});

test('JavaScript reproduces the shared Dart portion-report SHA-256 vector', () => {
  const vector = JSON.parse(
    fs.readFileSync('test/fixtures/fdc_portion_projection_digest_v1.json', 'utf8'),
  );
  assert.equal(vector.schema_id, 'parkinsum.fdc-portion-projection-digest-vector/1');
  assert.equal(
    fdcPortionProjectionSha256(vector.payload),
    vector.sha256_digest,
  );
});
