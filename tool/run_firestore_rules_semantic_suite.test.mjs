import assert from 'node:assert/strict';
import test from 'node:test';

import {
  requiredFirestoreSemanticCases,
  validateSemanticTap,
} from './run_firestore_rules_semantic_suite.mjs';

function tapFixture({
  names = requiredFirestoreSemanticCases,
  tests = names.length,
  pass = names.length,
  fail = 0,
  cancelled = 0,
  skipped = 0,
  todo = 0,
} = {}) {
  return [
    'TAP version 13',
    ...names.flatMap((name, index) => [
      `# Subtest: ${name}`,
      `ok ${index + 1} - ${name}`,
    ]),
    `1..${tests}`,
    `# tests ${tests}`,
    `# pass ${pass}`,
    `# fail ${fail}`,
    `# cancelled ${cancelled}`,
    `# skipped ${skipped}`,
    `# todo ${todo}`,
  ].join('\n');
}

test('accepts exactly the seven required passing semantic cases', () => {
  assert.deepEqual(validateSemanticTap(tapFixture()), []);
});

test('rejects missing, skipped, todo, failed, or extra cases', () => {
  const missing = requiredFirestoreSemanticCases.slice(1);
  assert.ok(
    validateSemanticTap(tapFixture({ names: missing }))
      .some((failure) => failure.includes('missing required semantic case')),
  );
  assert.ok(
    validateSemanticTap(tapFixture({ skipped: 1, pass: 6 }))
      .some((failure) => failure.includes('zero skipped')),
  );
  assert.ok(
    validateSemanticTap(tapFixture({ todo: 1, pass: 6 }))
      .some((failure) => failure.includes('zero todo')),
  );
  assert.ok(
    validateSemanticTap(tapFixture({ fail: 1, pass: 6 }))
      .some((failure) => failure.includes('zero fail')),
  );
  assert.ok(
    validateSemanticTap(tapFixture({
      names: [...requiredFirestoreSemanticCases, 'unexpected case'],
    })).some((failure) => failure.includes('expected 7 tests')),
  );
});
