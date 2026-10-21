import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { test } from 'node:test';
import { inspectRequiredJobResults } from './ci_required_status_gate.mjs';
import { EXIT, PR_PLAN, PR_WORKFLOW, PROVISIONING, jobResult, main, parseWorkflowSteps, planDrift, workflowTriggersPullRequest } from './run_verify_pr.mjs';

const ci = readFileSync(PR_WORKFLOW, 'utf8');
const drift = (source) => planDrift(parseWorkflowSteps(source));

test('verify:pr mirrors every job and step of the pull-request workflow in order', () => {
  assert.deepEqual(drift(ci), []);
  const steps = parseWorkflowSteps(ci).flatMap((job) => job.steps);
  assert.equal(steps.length, PR_PLAN.flatMap((job) => job.steps).length);
  assert(steps.some((step) => step.run === 'flutter pub get\nnpm ci'), 'block scalars keep their line structure');
  assert(steps.some((step) => step.run?.startsWith('node tool/store_privacy_contract_check.mjs --android-manifest build/')), 'folded scalars are joined');
});

test('ci.yml is the only workflow that pull requests run', () => {
  const triggered = readdirSync('.github/workflows').filter((name) => /\.ya?ml$/.test(name))
    .filter((name) => workflowTriggersPullRequest(readFileSync(`.github/workflows/${name}`, 'utf8')));
  assert.deepEqual(triggered, ['ci.yml'], 'A new pull_request workflow needs its own verify:pr coverage.');
});

test('a step added, removed, reordered or changed in the workflow without verify:pr fails', () => {
  const changes = {
    'added run step': ci.replace('      - name: Validate versioned schema catalog\n', '      - name: Brand new gate\n        run: npm run brand:new\n\n      - name: Validate versioned schema catalog\n'),
    'added inline step': ci.replace('      - run: flutter pub get\n', '      - run: flutter pub get\n      - run: npm run lint:extra\n'),
    'added action': ci.replace('      - name: Install Flutter dependencies\n', '      - uses: example/new-action@v1\n      - name: Install Flutter dependencies\n'),
    'removed step': ci.replace('      - name: Validate release fail-closed contracts\n        run: npm run release:contract\n', ''),
    'changed command': ci.replace('run: flutter test --concurrency=2', 'run: flutter test --concurrency=4'),
    'changed block line': ci.replace('          flutter pub get\n          npm ci\n', '          flutter pub get\n          npm ci\n          npm run extra\n'),
    'changed env': ci.replace('PARKINSUM_CQF_JVM_GRADLE_BIN: gradle', 'PARKINSUM_CQF_JVM_GRADLE_BIN: gradlew'),
    'conditional step': ci.replace('        run: npm run rules:test', '        if: false\n        run: npm run rules:test'),
    'tolerated failure': ci.replace('        run: npm run verify:all', '        continue-on-error: true\n        run: npm run verify:all'),
    'reordered steps': ci.replace('      - name: Validate Firestore rules contract\n        run: npm run rules:contract\n\n      - name: Validate Firestore emulator runtime selection\n        run: npm run rules:runner:test\n',
      '      - name: Validate Firestore emulator runtime selection\n        run: npm run rules:runner:test\n\n      - name: Validate Firestore rules contract\n        run: npm run rules:contract\n'),
    'added job': ci.replace('\n  preflight:\n', '\n  extra:\n    runs-on: ubuntu-latest\n    steps:\n      - run: npm run extra\n\n  preflight:\n'),
  };
  for (const [label, source] of Object.entries(changes)) {
    assert.notEqual(source, ci, `mutation did not apply: ${label}`);
    assert.notDeepEqual(drift(source), [], label);
  }
});

test('every provisioning action has a declared local meaning', () => {
  for (const step of PR_PLAN.flatMap((job) => job.steps).filter((entry) => entry.uses)) assert(PROVISIONING[step.uses], step.uses);
  for (const [action, meaning] of Object.entries(PROVISIONING)) assert.equal(typeof meaning.local, 'string', action);
});

test('toolchain- and network-dependent steps declare what they need', () => {
  const requires = Object.fromEntries(PR_PLAN.flatMap((job) => job.steps).filter((step) => step.run).map((step) => [step.run, step.requires ?? []]));
  assert.deepEqual(requires['npm run rules:test'], ['java21']);
  assert.deepEqual(requires['npm run security:dependencies'], ['network']);
  assert.deepEqual(requires['npm run cql:diff'], ['go', 'gradle', 'java21']);
  assert.deepEqual(requires['flutter build apk --debug --dart-define=PARKINSUM_BACKEND=local'], ['android_sdk']);
  assert.deepEqual(requires['dart format --output=none --set-exit-if-changed lib test tool'], []);
  const quick = PR_PLAN[0].steps.map((step) => step.run).filter(Boolean);
  assert(quick.indexOf('flutter pub get') < quick.indexOf('dart format --output=none --set-exit-if-changed lib test tool'), 'format needs the package language version');
});

test('a skipped step is never a pass and the required-status gate rejects it', () => {
  const step = (status) => ({ kind: 'run', status });
  assert.equal(jobResult([step('passed'), step('passed')]), 'success');
  assert.equal(jobResult([step('passed'), step('skipped')]), 'skipped');
  assert.equal(jobResult([step('skipped'), step('failed')]), 'failure');
  assert.equal(jobResult([step('passed'), step('not_run')]), 'failure');
  const needs = { 'quick-checks': { result: 'success' }, flutter: { result: 'success' }, 'node-preflight': { result: 'skipped' }, 'governance-gates': { result: 'success' } };
  assert.equal(inspectRequiredJobResults(needs).pass, false);
});

test('the CLI is wired into npm with explicit exit codes', async () => {
  const pkg = JSON.parse(readFileSync('package.json', 'utf8'));
  assert.equal(pkg.scripts['verify:pr'], 'node tool/run_verify_pr.mjs');
  assert.deepEqual({ ...EXIT }, { pass: 0, failed: 1, usage: 2, incomplete: 3, sigint: 130, sigterm: 143 });
  const errors = [];
  const original = console.error;
  console.error = (message) => errors.push(message);
  try { assert.equal(await main(['--bogus']), EXIT.usage); }
  finally { console.error = original; }
  assert.match(errors.join('\n'), /Unknown argument/);
});
