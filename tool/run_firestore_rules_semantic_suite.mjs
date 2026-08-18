import { spawnSync } from 'node:child_process';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

export const requiredFirestoreSemanticCases = Object.freeze([
  'owner can create and read a fully structured intake',
  'cross-user and unauthenticated intake access is denied',
  'malformed structured products, unsafe amounts, and extra fields fail closed',
  'clinical audit is owner-bound and append-only',
  'record history is owner-bound, strict, and append-only',
  'atomic onboarding marker is owner-bound and terminal',
  'catalog is signed-in readable and only privileged claims may write',
]);

function summaryCount(tap, label) {
  const match = tap.match(new RegExp(`^# ${label} (\\d+)$`, 'm'));
  return match == null ? null : Number(match[1]);
}

export function validateSemanticTap(tap) {
  const failures = [];
  for (const name of requiredFirestoreSemanticCases) {
    if (!tap.split('\n').includes(`# Subtest: ${name}`)) {
      failures.push(`missing required semantic case: ${name}`);
    }
  }
  const expected = requiredFirestoreSemanticCases.length;
  const counts = {
    tests: summaryCount(tap, 'tests'),
    pass: summaryCount(tap, 'pass'),
    fail: summaryCount(tap, 'fail'),
    cancelled: summaryCount(tap, 'cancelled'),
    skipped: summaryCount(tap, 'skipped'),
    todo: summaryCount(tap, 'todo'),
  };
  if (counts.tests !== expected) {
    failures.push(`expected ${expected} tests, observed ${counts.tests}`);
  }
  if (counts.pass !== expected) {
    failures.push(`expected ${expected} passing tests, observed ${counts.pass}`);
  }
  for (const label of ['fail', 'cancelled', 'skipped', 'todo']) {
    if (counts[label] !== 0) {
      failures.push(`expected zero ${label}, observed ${counts[label]}`);
    }
  }
  return failures;
}

function run() {
  const result = spawnSync(
    process.execPath,
    [
      '--test',
      '--test-reporter=tap',
      'tool/firestore_rules_semantic.test.mjs',
    ],
    {
      cwd: projectRoot,
      env: process.env,
      encoding: 'utf8',
      maxBuffer: 16 * 1024 * 1024,
    },
  );
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) {
    process.stderr.write(`FAIL semantic test process: ${result.error.message}\n`);
    process.exitCode = 2;
    return;
  }
  const failures = validateSemanticTap(result.stdout ?? '');
  for (const failure of failures) process.stderr.write(`FAIL ${failure}\n`);
  process.exitCode = result.status === 0 && failures.length === 0
    ? 0
    : result.status || 2;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  run();
}
