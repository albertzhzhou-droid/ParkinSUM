#!/usr/bin/env node
// Local pull-request parity: every step of the pull_request workflow, in the
// workflow's own order, with the exact `run:` text executed by bash as GitHub
// Actions does. Provisioning actions become local capability probes. A step
// whose toolchain or network is absent is reported as SKIPPED with its reason
// and is never counted as a pass; any skip keeps the exit code non-zero.
import { randomUUID } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { delimiter, join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { resolveJava21 } from './run_firestore_rules_semantic.mjs';
import { atomicJson, localPath, supervise } from './verification_runtime.mjs';

export const PR_WORKFLOW = '.github/workflows/ci.yml';
export const VERIFY_PR_REPORT_SCHEMA = 'parkinsum.verify-pr-report/1';
export const EXIT = Object.freeze({ pass: 0, failed: 1, usage: 2, incomplete: 3, sigint: 130, sigterm: 143 });

const ANDROID_MANIFEST = 'build/app/intermediates/merged_manifests/debug/processDebugManifest/AndroidManifest.xml';
const uses = (action, local = {}) => ({ uses: action, ...local });
const run = (command, local = {}) => ({ run: command, ...local });

// One entry per workflow step, in order. `requires` names local capabilities;
// `env` repeats the step's workflow env (values or `${{ }}` expressions, which
// are resolved from this run's own job results, never assumed).
export const PR_PLAN = [
  { id: 'quick-checks', name: 'Format and analysis', steps: [
    uses('actions/checkout@v7'),
    uses('subosito/flutter-action@v2'),
    // CI materializes the package config first; without it dart format falls
    // back to the default language version and reports false changes.
    run('flutter pub get'),
    run('dart format --output=none --set-exit-if-changed lib test tool', { name: 'Check Dart formatting' }),
    run('flutter analyze', { name: 'Analyze Flutter project' }),
  ] },
  { id: 'flutter', name: 'Flutter checks', steps: [
    run('test "$QUICK_CHECK_RESULT" = success', { name: 'Require successful format and analysis', env: { QUICK_CHECK_RESULT: '${{ needs.quick-checks.result }}' } }),
    uses('actions/checkout@v7', { name: 'Check out repository' }),
    uses('subosito/flutter-action@v2', { name: 'Set up Flutter' }),
    run('flutter pub get', { name: 'Install Flutter dependencies' }),
    run('flutter test --concurrency=2', { name: 'Run Flutter tests' }),
    run('flutter build web --release --dart-define=PARKINSUM_BACKEND=local', { name: 'Build local-mode Web release' }),
    run('flutter build apk --debug --dart-define=PARKINSUM_BACKEND=local', { name: 'Build local-mode Android debug APK', requires: ['android_sdk'] }),
    run('npm run open-source:android-gradle-graph', { name: 'Export resolved Android runtime dependency graph', requires: ['android_sdk'] }),
    run(`node tool/store_privacy_contract_check.mjs --android-manifest ${ANDROID_MANIFEST}`, { name: 'Validate built Android privacy facts', requires: ['android_sdk'] }),
    run('npm run open-source:release-evidence:test && npm run open-source:release-evidence', { name: 'Verify Flutter-generated notices in release artifacts', requires: ['android_sdk'] }),
    uses('actions/upload-artifact@v7', { name: 'Upload open-source release evidence' }),
  ] },
  { id: 'node-preflight', name: 'Node public preflight', steps: [
    uses('actions/checkout@v7', { name: 'Check out repository' }),
    uses('subosito/flutter-action@v2', { name: 'Set up Flutter' }),
    uses('actions/setup-node@v7', { name: 'Set up Node.js' }),
    uses('actions/setup-go@v7', { name: 'Set up Go for the independent CQL parser check' }),
    uses('actions/setup-java@v6', { name: 'Set up Java 21 for Firestore Emulator and CQF JVM checks' }),
    uses('gradle/actions/setup-gradle@v6', { name: 'Set up the pinned Gradle runtime for CQF JVM checks' }),
    run('flutter pub get\nnpm ci', { name: 'Install dependencies' }),
    run('gradle --no-daemon -p tool/cqf_jvm_cql_differential --quiet installDist', { name: 'Prepare locked CQF JVM dependencies', requires: ['gradle', 'java21'] }),
    run('npm run cql:diff', { name: 'Compare synthetic CQL across CQL execution paths', env: { PARKINSUM_CQF_JVM_GRADLE_BIN: 'gradle' }, requires: ['go', 'gradle', 'java21'] }),
    run('npm run public:preflight', { name: 'Run public repository preflight' }),
    run('npm run rules:contract', { name: 'Validate Firestore rules contract' }),
    run('npm run rules:runner:test', { name: 'Validate Firestore emulator runtime selection' }),
    run('npm run schema:contract', { name: 'Validate versioned schema catalog' }),
    run('npm run upgrade:queue', { name: 'Validate complete-app research and delivery queue' }),
    run('npm run privacy:store', { name: 'Validate store privacy declaration contract' }),
    run('npm run open-source:firewall', { name: 'Validate open-source influence and license firewall' }),
    run('npm run release:contract', { name: 'Validate release fail-closed contracts' }),
    run('npm run security:dependencies', { name: 'Audit production Node dependencies', requires: ['network'] }),
    run('npm run rules:test', { name: 'Validate Firestore rules behavior in Emulator', requires: ['java21'] }),
  ] },
  { id: 'governance-gates', name: 'Governance gates', steps: [
    uses('actions/checkout@v7', { name: 'Check out repository' }),
    uses('subosito/flutter-action@v2', { name: 'Set up Flutter' }),
    uses('actions/setup-node@v7', { name: 'Set up Node.js' }),
    run('flutter pub get\nnpm ci', { name: 'Install dependencies' }),
    run('npm run verify:all', { name: 'All governance gates + committed-golden drift check' }),
    uses('actions/upload-artifact@v7', { name: 'Upload verification report' }),
  ] },
  { id: 'preflight', name: 'preflight', summary: true, steps: [
    uses('actions/checkout@v7'),
    uses('actions/setup-node@v7'),
    run('node tool/ci_required_status_gate.mjs', { name: 'Require every prerequisite to succeed', env: { PARKINSUM_CI_JOB_RESULTS: '${{ toJSON(needs) }}' } }),
  ] },
];

// What each provisioning action means on a developer machine.
export const PROVISIONING = {
  'actions/checkout@v7': { capability: null, local: 'this checkout is the source under test' },
  'subosito/flutter-action@v2': { capability: 'flutter', local: 'flutter on PATH (CI pins flutter-version)' },
  'actions/setup-node@v7': { capability: 'node', local: 'the Node.js running this command' },
  'actions/setup-go@v7': { capability: 'go', local: 'go on PATH or GO_BIN' },
  'actions/setup-java@v6': { capability: 'java21', local: 'Java 21 from PARKINSUM_JAVA_HOME, JAVA_HOME, java_home or Android Studio JBR; exported as JAVA_HOME for this job' },
  'gradle/actions/setup-gradle@v6': { capability: 'gradle', local: 'gradle on PATH' },
  'actions/upload-artifact@v7': { capability: null, local: 'not applicable; the artifact stays under build/' },
};

// Bounded reader for this repository's canonical workflow spelling (as in
// ci_layering_contract.test.mjs); it is not a general YAML parser.
export function parseWorkflowSteps(source) {
  const offset = source.indexOf('\njobs:\n');
  if (offset < 0) throw new Error('Workflow has no jobs block');
  const body = source.slice(offset + 7);
  const heads = [...body.matchAll(/^ {2}([a-z][a-z0-9-]*):\s*$/gm)];
  return heads.map((head, index) => {
    const text = body.slice(head.index, heads[index + 1]?.index ?? body.length);
    const lines = text.split('\n');
    const start = lines.findIndex((line) => /^ {4}steps:\s*$/.test(line));
    if (start < 0) throw new Error(`Job ${head[1]} has no steps`);
    const steps = [];
    let step = null;
    let key = null;
    for (const raw of lines.slice(start + 1)) {
      if (!raw.trim() || raw.trim().startsWith('#')) continue;
      if (/^ {0,5}\S/.test(raw)) break;
      let line = raw;
      if (/^ {6}- /.test(line)) { step = {}; steps.push(step); line = `        ${line.slice(8)}`; }
      if (!step) throw new Error(`Unexpected line in ${head[1]} steps: ${raw}`);
      const field = line.match(/^ {8}([a-z-]+):\s*(.*)$/);
      if (field) {
        key = field[1];
        step[key] = ['|', '>-', ''].includes(field[2]) ? { style: field[2] || 'map', lines: [] } : field[2].replace(/^(['"])(.*)\1$/, '$2');
        continue;
      }
      if (!/^ {10}/.test(line) || typeof step[key] !== 'object') throw new Error(`Unsupported workflow spelling in ${head[1]}: ${raw}`);
      step[key].lines.push(line.slice(10));
    }
    for (const entry of steps) {
      for (const [name, value] of Object.entries(entry)) {
        if (typeof value !== 'object') continue;
        if (value.style === '|') entry[name] = value.lines.join('\n');
        else if (value.style === '>-') entry[name] = value.lines.map((line) => line.trim()).join(' ');
        else entry[name] = Object.fromEntries(value.lines.map((line) => line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/)).map((match) => {
          if (!match) throw new Error(`Unsupported map entry in ${head[1]}`);
          return [match[1], match[2].replace(/^(['"])(.*)\1$/, '$2')];
        }));
      }
    }
    return { id: head[1], steps };
  });
}

export function workflowTriggersPullRequest(source) {
  return /^on:\n(?: {2}.*\n|\s*#.*\n)*? {2}pull_request:/m.test(source);
}

// Every job and every step (run or uses, its env, its condition) must have a
// plan entry in the same position. Anything else is drift and is fatal.
export function planDrift(workflowJobs, plan = PR_PLAN) {
  const problems = [];
  const planIds = plan.map((job) => job.id);
  const workflowIds = workflowJobs.map((job) => job.id);
  if (JSON.stringify(planIds) !== JSON.stringify(workflowIds)) problems.push(`jobs: workflow [${workflowIds}] vs verify:pr [${planIds}]`);
  for (const job of workflowJobs) {
    const planned = plan.find((entry) => entry.id === job.id);
    if (!planned) continue;
    const length = Math.max(job.steps.length, planned.steps.length);
    for (let index = 0; index < length; index += 1) {
      const actual = job.steps[index];
      const expected = planned.steps[index];
      const where = `${job.id} step ${index + 1}`;
      if (!actual) { problems.push(`${where}: verify:pr has an extra step ${expected.run ?? expected.uses}`); continue; }
      if (!expected) { problems.push(`${where}: workflow step has no verify:pr step: ${actual.run ?? actual.uses}`); continue; }
      if ((actual.run ?? null) !== (expected.run ?? null) || (actual.uses ?? null) !== (expected.uses ?? null)) {
        problems.push(`${where}: workflow runs ${JSON.stringify(actual.run ?? actual.uses)}, verify:pr runs ${JSON.stringify(expected.run ?? expected.uses)}`);
      }
      if (JSON.stringify(actual.env ?? {}) !== JSON.stringify(expected.env ?? {})) problems.push(`${where}: env differs`);
      if (actual.uses && !PROVISIONING[actual.uses]) problems.push(`${where}: action ${actual.uses} has no local provisioning meaning`);
      if (actual['continue-on-error'] !== undefined || (actual.if !== undefined && actual.if !== 'always()')) problems.push(`${where}: unsupported step condition`);
    }
  }
  return problems;
}

async function probe(command, args, cwd, timeoutMs = 30000) {
  const result = await supervise(command, args, { cwd, timeoutMs, cleanupGraceMs: 250, maxLogBytes: 65536 });
  return { ok: !result.spawn_error && !result.termination && result.exit_code === 0, output: (result.output ?? '').trim() };
}

function androidSdk(env = process.env) {
  const candidates = [env.ANDROID_HOME, env.ANDROID_SDK_ROOT, process.platform === 'darwin' ? join(homedir(), 'Library/Android/sdk') : join(homedir(), 'Android/Sdk')];
  return candidates.find((path) => path && existsSync(join(path, 'platform-tools'))) ?? null;
}

export async function probeCapabilities(cwd, { offline = false, workflowSource = '' } = {}) {
  const capabilities = {};
  const flutter = await probe('flutter', ['--version', '--machine'], cwd, 120000);
  let flutterVersion = null;
  try { flutterVersion = JSON.parse(flutter.output.slice(flutter.output.indexOf('{'))).frameworkVersion; } catch { /* reported below */ }
  const pinnedFlutter = workflowSource.match(/flutter-version: '([^']+)'/)?.[1] ?? null;
  capabilities.flutter = flutter.ok
    ? { available: true, detail: `Flutter ${flutterVersion ?? 'unknown'}`, warning: pinnedFlutter && flutterVersion !== pinnedFlutter ? `CI pins Flutter ${pinnedFlutter}` : null }
    : { available: false, detail: 'flutter not found on PATH' };
  const pinnedNode = workflowSource.match(/node-version: "(\d+)"/)?.[1] ?? null;
  capabilities.node = { available: true, detail: `Node ${process.version}`, warning: pinnedNode && process.versions.node.split('.')[0] !== pinnedNode ? `CI uses Node ${pinnedNode}` : null };
  const goBinary = process.env.GO_BIN || 'go';
  const go = await probe(goBinary, ['version'], cwd);
  capabilities.go = go.ok ? { available: true, detail: go.output } : { available: false, detail: `${goBinary} not found (CI provisions Go via actions/setup-go)` };
  const gradle = await probe('gradle', ['--version', '--quiet'], cwd, 120000);
  capabilities.gradle = gradle.ok ? { available: true, detail: gradle.output.split('\n').find((line) => line.startsWith('Gradle')) ?? 'gradle' }
    : { available: false, detail: 'gradle not found on PATH (CI provisions Gradle 8.14 via gradle/actions/setup-gradle)' };
  const java = resolveJava21();
  capabilities.java21 = java ? { available: true, detail: `Java ${java.major}${java.home ? ` at ${java.home}` : ''}`, home: java.home }
    : { available: false, detail: 'no Java 21+ runtime found (CI provisions Temurin 21 via actions/setup-java)' };
  const sdk = androidSdk();
  capabilities.android_sdk = sdk ? { available: true, detail: `Android SDK at ${sdk}` } : { available: false, detail: 'no Android SDK (ANDROID_HOME, ANDROID_SDK_ROOT or the default SDK path)' };
  if (offline) capabilities.network = { available: false, detail: '--offline was requested' };
  else {
    const ping = await probe('npm', ['ping'], cwd, 20000);
    capabilities.network = ping.ok ? { available: true, detail: 'npm registry reachable' } : { available: false, detail: 'npm registry unreachable (npm ping failed)' };
  }
  return capabilities;
}

function resolveEnv(env, jobResults) {
  const needs = Object.fromEntries(Object.entries(jobResults).map(([id, result]) => [id, { result: result === 'not_selected' ? 'skipped' : result, outputs: {} }]));
  return Object.fromEntries(Object.entries(env ?? {}).map(([name, value]) => {
    if (value === '${{ needs.quick-checks.result }}') return [name, jobResults['quick-checks'] ?? 'skipped'];
    if (value === '${{ toJSON(needs) }}') return [name, JSON.stringify(needs)];
    if (value.includes('${{')) throw new Error(`Unsupported workflow expression: ${value}`);
    return [name, value];
  }));
}

// A job that GitHub would report as success must have run and passed every
// step. A locally skipped step makes it incomplete, which the required-status
// gate rejects exactly as it rejects any non-success result.
export function jobResult(steps) {
  const runs = steps.filter((step) => step.kind === 'run');
  if (runs.some((step) => step.status === 'failed' || step.status === 'not_run')) return 'failure';
  if (runs.some((step) => step.status === 'skipped')) return 'skipped';
  return 'success';
}

const slug = (text) => text.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 48);
const seconds = (ms) => `${(ms / 1000).toFixed(1)}s`;

export async function runVerifyPr({ cwd = process.cwd(), jobs: selectedJobs = null, failFast = false, offline = false, timeoutMs = 3600000, out = process.stdout } = {}) {
  const workflowSource = readFileSync(localPath(cwd, PR_WORKFLOW), 'utf8');
  if (!workflowTriggersPullRequest(workflowSource)) throw new Error(`${PR_WORKFLOW} no longer runs on pull_request`);
  const drift = planDrift(parseWorkflowSteps(workflowSource));
  if (drift.length) throw Object.assign(new Error(`verify:pr does not match ${PR_WORKFLOW}:\n  ${drift.join('\n  ')}\nUpdate PR_PLAN in tool/run_verify_pr.mjs.`), { code: 'PLAN_DRIFT' });
  const capabilities = await probeCapabilities(cwd, { offline, workflowSource });
  if (!capabilities.flutter.available) throw new Error('verify:pr needs Flutter on PATH; almost every CI step runs flutter or dart.');
  const runId = randomUUID();
  const runDirectory = `build/verify_pr/runs/${runId}`;
  const controller = new AbortController();
  const onSignal = (name) => () => controller.abort(name);
  const sigint = onSignal('SIGINT');
  const sigterm = onSignal('SIGTERM');
  process.on('SIGINT', sigint);
  process.on('SIGTERM', sigterm);
  const write = (text) => out.write(`${text}\n`);
  write(`verify:pr — ${PR_WORKFLOW}, ${PR_PLAN.length} jobs, run ${runId}`);
  for (const [name, capability] of Object.entries(capabilities)) write(`  ${capability.available ? 'have' : 'MISSING'} ${name}: ${capability.detail}${capability.warning ? ` (warning: ${capability.warning})` : ''}`);
  const jobResults = {};
  const report = { $schema: VERIFY_PR_REPORT_SCHEMA, run_id: runId, workflow: PR_WORKFLOW, capabilities, jobs: [] };
  let ordinal = 0;
  let stopAll = false;
  try {
    for (const job of PR_PLAN) {
      const selected = !selectedJobs || selectedJobs.includes(job.id);
      const record = { id: job.id, name: job.name, selected, steps: [] };
      report.jobs.push(record);
      write(`\n[${job.id}] ${job.name}${selected ? '' : ' — not selected (--job)'}`);
      let jobEnv = {};
      let jobStopped = null;
      for (const step of job.steps) {
        ordinal += 1;
        const label = step.name ?? step.run ?? step.uses;
        const entry = { ordinal, kind: step.run !== undefined ? 'run' : 'uses', label, command: step.run ?? step.uses };
        record.steps.push(entry);
        if (step.uses) {
          const meaning = PROVISIONING[step.uses];
          const capability = meaning.capability ? capabilities[meaning.capability] : null;
          if (capability?.available && meaning.capability === 'java21' && capability.home) {
            jobEnv = { ...jobEnv, JAVA_HOME: capability.home, PATH: `${join(capability.home, 'bin')}${delimiter}${process.env.PATH ?? ''}` };
          }
          Object.assign(entry, { status: 'provision', detail: capability ? `${capability.available ? 'have' : 'missing'}: ${capability.detail}` : meaning.local });
          write(`  ${String(ordinal).padStart(2)} provision ${step.uses} — ${entry.detail}`);
          continue;
        }
        const missing = (step.requires ?? []).filter((name) => !capabilities[name]?.available);
        const unselectedNeed = Object.values(step.env ?? {}).some((value) => value.includes('needs.quick-checks')) && jobResults['quick-checks'] === 'not_selected';
        if (!selected) Object.assign(entry, { status: 'not_run', reason: 'job not selected' });
        else if (controller.signal.aborted) Object.assign(entry, { status: 'not_run', reason: `interrupted (${controller.signal.reason})` });
        else if (stopAll) Object.assign(entry, { status: 'not_run', reason: 'stopped by --fail-fast after an earlier failure' });
        else if (jobStopped) Object.assign(entry, { status: 'not_run', reason: `earlier step in this job failed: ${jobStopped}` });
        else if (unselectedNeed) Object.assign(entry, { status: 'skipped', reason: 'quick-checks was not selected, so its result is unknown' });
        else if (missing.length) Object.assign(entry, { status: 'skipped', reason: missing.map((name) => `${name} unavailable — ${capabilities[name].detail}`).join('; ') });
        if (entry.status) {
          write(`  ${String(ordinal).padStart(2)} ${entry.status === 'skipped' ? 'SKIPPED ' : 'not run '} ${label} — ${entry.reason}`);
          continue;
        }
        const env = { ...process.env, ...jobEnv, ...resolveEnv(step.env, jobResults) };
        entry.log_path = `${runDirectory}/${String(ordinal).padStart(2, '0')}-${job.id}-${slug(label)}.log`;
        out.write(`  ${String(ordinal).padStart(2)} running  ${label} … `);
        const started = Date.now();
        const execution = await supervise('bash', ['--noprofile', '--norc', '-eo', 'pipefail', '-c', step.run], { cwd, env, logPath: localPath(cwd, entry.log_path), timeoutMs, cleanupGraceMs: 2000, maxLogBytes: 64 * 1024 * 1024, signal: controller.signal });
        entry.duration_ms = Date.now() - started;
        entry.exit_code = execution.exit_code;
        if (execution.termination) Object.assign(entry, { status: 'not_run', reason: execution.termination === 'timeout' ? 'timed out' : `interrupted (${execution.termination})` });
        if (execution.termination === 'timeout') entry.status = 'failed';
        else if (!execution.termination) entry.status = execution.spawn_error ? 'failed' : execution.exit_code === 0 ? 'passed' : 'failed';
        // An incomplete prerequisite is reported as a skip of the summary gate,
        // not as a failure of the gate itself.
        const prerequisites = Object.entries(jobResults);
        if (job.summary && entry.status === 'failed' && !prerequisites.some(([, result]) => result === 'failure') && prerequisites.some(([, result]) => result !== 'success')) {
          Object.assign(entry, { status: 'skipped', reason: `required-status gate rejects incomplete prerequisites: ${prerequisites.filter(([, result]) => result !== 'success').map(([id, result]) => `${id} (${result})`).join(', ')}` });
        }
        write(`${entry.status.toUpperCase()} (${seconds(entry.duration_ms)})${entry.reason ? ` — ${entry.reason}` : ''}`);
        if (entry.status === 'failed') {
          jobStopped = label;
          if (failFast) stopAll = true;
          const tail = readFileSync(localPath(cwd, entry.log_path), 'utf8').trimEnd().split('\n').slice(-30);
          write(`     log: ${entry.log_path}`);
          for (const line of tail) write(`     | ${line}`);
        }
      }
      // The summary job compares the other jobs; an unselected job is not a success.
      if (!job.summary) jobResults[job.id] = selected ? jobResult(record.steps) : 'not_selected';
      record.result = selected ? jobResult(record.steps) : 'not_selected';
    }
  } finally {
    process.off('SIGINT', sigint);
    process.off('SIGTERM', sigterm);
  }
  const runSteps = report.jobs.filter((job) => job.selected).flatMap((job) => job.steps.filter((step) => step.kind === 'run'));
  const count = (status) => runSteps.filter((step) => step.status === status).length;
  report.totals = { passed: count('passed'), failed: count('failed'), skipped: count('skipped'), not_run: count('not_run') };
  report.interrupted = controller.signal.aborted ? controller.signal.reason : null;
  report.outcome = report.interrupted ? 'interrupted' : report.totals.failed || report.totals.not_run ? 'failed' : report.totals.skipped ? 'incomplete' : 'passed';
  report.exit_code = report.interrupted === 'SIGINT' ? EXIT.sigint : report.interrupted === 'SIGTERM' ? EXIT.sigterm : EXIT[report.outcome];
  atomicJson(localPath(cwd, `${runDirectory}/report.json`), report);
  atomicJson(localPath(cwd, 'build/verify_pr/latest.json'), report);
  const rows = report.jobs.flatMap((job) => job.steps.filter((step) => step.kind === 'run').map((step) => `| ${job.id} | ${step.label.replace(/\|/g, '\\|').replace(/\n/g, ' ')} | ${step.status}${step.reason ? ` — ${step.reason.replace(/\|/g, '\\|')}` : ''} |`));
  writeFileSync(localPath(cwd, 'build/verify_pr/latest.md'), ['# verify:pr summary', '', `Run: ${runId}. Outcome: **${report.outcome}** (exit ${report.exit_code}).`, '', '| Job | Step | Status |', '| --- | --- | --- |', ...rows, ''].join('\n'));
  write(`\nverify:pr ${report.outcome.toUpperCase()}: ${report.totals.passed} passed, ${report.totals.failed} failed, ${report.totals.skipped} skipped, ${report.totals.not_run} not run.`);
  for (const step of runSteps.filter((entry) => entry.status === 'skipped')) write(`  SKIPPED (not a pass): ${step.label} — ${step.reason}`);
  if (report.outcome === 'incomplete') write('Skipped steps were not verified locally; CI will run them. Exit code 3 means "no failures, but not full CI parity".');
  write('Report: build/verify_pr/latest.json');
  return report;
}

const USAGE = `Usage: npm run verify:pr [-- options]
  --list          print the workflow steps and their local requirements, then exit
  --job=<id>      run only this job (repeatable); other jobs are reported as not selected
  --fail-fast     stop every remaining step after the first failure
  --offline       treat the network as unavailable (skips the npm audit step)
  --step-timeout-ms=<n>  per-step timeout (default 3600000)
Exit codes: 0 all steps passed; 1 a step failed; 2 usage or plan drift; 3 no failure but at least one step skipped; 130/143 interrupted.`;

export async function main(argv = process.argv.slice(2)) {
  const known = /^(--list|--fail-fast|--offline|--help|--job=[a-z-]+|--step-timeout-ms=\d+)$/;
  const unknown = argv.filter((arg) => !known.test(arg));
  if (unknown.length || argv.includes('--help')) { console.error(unknown.length ? `Unknown argument: ${unknown.join(' ')}\n${USAGE}` : USAGE); return unknown.length ? EXIT.usage : EXIT.pass; }
  if (argv.includes('--list')) {
    let ordinal = 0;
    for (const job of PR_PLAN) {
      console.log(`[${job.id}] ${job.name}`);
      for (const step of job.steps) {
        ordinal += 1;
        const what = step.run !== undefined ? step.run.replace(/\n/g, ' && ') : `provision ${step.uses} (${PROVISIONING[step.uses].local})`;
        console.log(`  ${String(ordinal).padStart(2)} ${what}${step.requires ? `   [requires: ${step.requires.join(', ')}]` : ''}`);
      }
    }
    return EXIT.pass;
  }
  const jobs = argv.filter((arg) => arg.startsWith('--job=')).map((arg) => arg.slice(6));
  const unknownJobs = jobs.filter((id) => !PR_PLAN.some((job) => job.id === id));
  if (unknownJobs.length) { console.error(`Unknown job: ${unknownJobs.join(', ')}`); return EXIT.usage; }
  const timeout = argv.find((arg) => arg.startsWith('--step-timeout-ms='));
  try {
    const report = await runVerifyPr({ jobs: jobs.length ? jobs : null, failFast: argv.includes('--fail-fast'), offline: argv.includes('--offline'), timeoutMs: timeout ? Number(timeout.split('=')[1]) : 3600000 });
    return report.exit_code;
  } catch (error) {
    console.error(error.message);
    return EXIT.usage;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) main().then((code) => { process.exitCode = code; });
