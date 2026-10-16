import assert from 'node:assert/strict';
import {readFileSync, existsSync} from 'node:fs';
import {test} from 'node:test';

const ci = readFileSync('.github/workflows/ci.yml', 'utf8');
const manual = readFileSync('.github/workflows/public-release-preflight.yml', 'utf8');

// This is a bounded contract for the repository's canonical workflow spelling,
// not a general YAML parser or a claim that GitHub executed the jobs.
function jobs(source) {
  const offset = source.indexOf('\njobs:\n');
  assert(offset >= 0);
  const body = source.slice(offset + 7);
  const entries = [...body.matchAll(/^  ([a-z][a-z0-9-]*):\s*$/gm)];
  const result = {};
  for (let i = 0; i < entries.length; i++) {
    const name = entries[i][1];
    assert(!Object.hasOwn(result, name), `Duplicate job ${name}`);
    result[name] = body.slice(entries[i].index, entries[i + 1]?.index ?? body.length);
  }
  return result;
}

function inspectWorkflows(source, manualSource) {
  assert.match(source, /^  pull_request:\s*$/m);
  assert.match(source, /^  push:\n    branches:\n      - main\s*$/m);
  assert.doesNotMatch(source, /^    (paths|paths-ignore):/m);
  assert.doesNotMatch(source, /^\s*(?:-\s+)?continue-on-error:/m);
  assert.deepEqual([...source.matchAll(/^ {8}if: (.+)$/gm)].map(value => value[1]), ['always()', 'always()']);
  const j = jobs(source);
  assert.deepEqual(Object.keys(j), ['quick-checks', 'flutter', 'node-preflight', 'governance-gates', 'preflight']);
  assert.match(j['quick-checks'], /run: dart format --output=none --set-exit-if-changed lib test tool/);
  assert.match(j['quick-checks'], /run: flutter analyze/);
  assert.match(j.flutter, /^    name: Flutter checks\s*$/m);
  assert.match(j.flutter, /^    needs: quick-checks\s*$/m);
  assert.match(j.flutter, /^    if: \$\{\{ always\(\) \}\}\s*$/m);
  const firstStep = j.flutter.slice(j.flutter.indexOf('    steps:')).split('\n      - ')[1];
  assert.match(firstStep, /QUICK_CHECK_RESULT: \$\{\{ needs\.quick-checks\.result \}\}/);
  assert.match(firstStep, /run: test "\$QUICK_CHECK_RESULT" = success/);
  assert.deepEqual([...source.matchAll(/^\s+(?:-\s+)?run: (flutter test[^\n]*)$/gm)].map(value => value[1]), ['flutter test --concurrency=2']);
  assert(existsSync('test/registered_user_algorithm_journey_test.dart'));
  for (const command of [
    'flutter build web --release --dart-define=PARKINSUM_BACKEND=local',
    'flutter build apk --debug --dart-define=PARKINSUM_BACKEND=local',
    'npm run open-source:android-gradle-graph',
    'node tool/store_privacy_contract_check.mjs',
    'npm run open-source:release-evidence:test && npm run open-source:release-evidence',
  ]) assert(j.flutter.includes(command), command);
  for (const command of [
    'npm run cql:diff', 'npm run public:preflight', 'npm run rules:contract',
    'npm run rules:runner:test', 'npm run schema:contract', 'npm run upgrade:queue',
    'npm run privacy:store', 'npm run open-source:firewall', 'npm run release:contract',
    'npm run security:dependencies', 'npm run rules:test',
  ]) assert(j['node-preflight'].includes(`run: ${command}`), command);
  assert.match(j['node-preflight'], /^    name: Node public preflight\s*$/m);
  assert.match(j['governance-gates'], /^    name: Governance gates\s*$/m);
  assert.match(j['governance-gates'], /run: npm run verify:all\s*$/m);
  assert.match(j['governance-gates'], /path: build\/verify_all\//);
  assert.doesNotMatch(source, /--skip-goldens/);
  assert.match(j.preflight, /^    name: preflight\s*$/m);
  assert.match(j.preflight, /^    needs: \[quick-checks, flutter, node-preflight, governance-gates\]\s*$/m);
  assert.match(j.preflight, /^    if: \$\{\{ always\(\) \}\}\s*$/m);
  assert.match(j.preflight, /PARKINSUM_CI_JOB_RESULTS: \$\{\{ toJSON\(needs\) \}\}/);
  assert.match(j.preflight, /run: node tool\/ci_required_status_gate\.mjs/);
  assert.match(manualSource, /^on:\n  workflow_dispatch:\s*\njobs:/m);
  assert.doesNotMatch(manualSource, /^  (pull_request|push):/m);
  const audit = jobs(manualSource);
  assert.deepEqual(Object.keys(audit), ['preflight']);
  assert.match(audit.preflight, /^    name: Manual release audit\s*$/m);
  assert.match(audit.preflight, /run: flutter test --concurrency=1/);
  assert.match(audit.preflight, /run: npm run public:preflight/);
  return true;
}

test('current local workflows retain protected identity and all required coverage', () => {
  assert.equal(inspectWorkflows(ci, manual), true);
});

test('omitted coverage, skipped prerequisites, ambiguous contexts and duplicate suites reject', () => {
  const changes = [
    source => source.replace('    name: preflight', '    name: changed-context'),
    source => source.replace('needs: [quick-checks, flutter, node-preflight, governance-gates]', 'needs: [flutter, node-preflight]'),
    source => source.replaceAll('if: ${{ always() }}', 'if: ${{ success() }}'),
    source => source.replace('run: test "$QUICK_CHECK_RESULT" = success', 'run: true'),
    source => source.replace('run: flutter test --concurrency=2', 'run: flutter test test/catalog_search_index_test.dart'),
    source => source.replace('run: npm run verify:all', 'run: npm run verify:all -- --skip-goldens'),
    source => source.replace('run: npm run rules:test', 'run: true'),
    source => source.replace('run: flutter build apk --debug --dart-define=PARKINSUM_BACKEND=local', 'run: true'),
    source => source.replace('run: flutter test --concurrency=2', 'run: flutter test --concurrency=2\n      - run: flutter test'),
    source => source.replace('run: flutter test --concurrency=2', 'if: false\n        run: flutter test --concurrency=2'),
    source => source.replace('run: npm run verify:all', 'continue-on-error: true\n        run: npm run verify:all'),
  ];
  for (const [index, change] of changes.entries()) assert.throws(() => inspectWorkflows(change(ci), manual), `Workflow negative case ${index}`);
  assert.throws(() => inspectWorkflows(ci, manual.replace('workflow_dispatch:', 'pull_request:')));
  assert.throws(() => inspectWorkflows(ci, manual.replace('name: Manual release audit\n    runs-on:', 'name: preflight\n    runs-on:')));
});
