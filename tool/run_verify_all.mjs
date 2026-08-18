#!/usr/bin/env node
// Runs every deterministic governance gate plus the committed-golden drift
// check, and composes the results into build/verify_all/latest.{json,md}.
//
// Usage:
//   npm run verify:all              # all gates, non-zero exit on any blocker
//   npm run verify:all -- --list    # print the gate list and exit 0
//   npm run verify:all -- --skip-goldens
//
// Why this exists: the gates were previously reachable only as ~10 separate CI
// steps. There was no single command a reviewer could run and no composed
// output — just a green check and scattered logs. Every gate here is offline,
// synthetic-data only, and exits non-zero on a blocker, so this is a real
// ratchet rather than a summary.
//
// The composed report is timestamp-free, matching the other artifacts in this
// repo, so regenerated reports diff cleanly. A gate that did not run is
// recorded as `missing_artifact` — never as a pass.
//
// Educational/research prototype. Synthetic data only. Not medical advice.

import { spawnSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';

const MISSING = 'missing_artifact';

/** Every gate runs offline against synthetic fixtures. */
const GATES = [
  { id: 'copy_compile', script: 'copy:compile', what: 'Explanation copy compiles (0 blocker)' },
  { id: 'localization_lint', script: 'localization:lint', what: 'Localization safety lint (full i18n dictionary)' },
  { id: 'mechanistic_replay', script: 'mechanistic:replay', what: 'Mechanistic replay' },
  { id: 'recommendation_replay', script: 'recommend:replay', what: 'Local AI scenario replay (candidate-set invariant)' },
  { id: 'scenario_fuzz', script: 'scenario:fuzz', what: 'Synthetic scenario fuzzer' },
  { id: 'privacy_preflight', script: 'privacy:preflight', what: 'Local privacy preflight' },
  { id: 'source_access', script: 'source:access', what: 'Source access contract check' },
  { id: 'source_drift', script: 'source:drift', what: 'Source version drift check' },
  { id: 'contribution_route', script: 'contribution:route', what: 'Contribution safety router' },
];

/**
 * The cross-commit drift ratchet. Listing `verify:all` as "all gates" while
 * skipping the goldens would be precisely the kind of overclaim these checks
 * exist to prevent, so it runs by default.
 */
const GOLDEN_GATE = {
  id: 'committed_goldens',
  what: 'Committed golden drift check (cross-commit)',
  command: 'flutter',
  args: ['test', 'test/goldens_test.dart'],
};

const argv = process.argv.slice(2);
const skipGoldens = argv.includes('--skip-goldens');

if (argv.includes('--list')) {
  for (const gate of GATES) console.log(`${gate.id}\tnpm run ${gate.script}`);
  if (!skipGoldens) console.log(`${GOLDEN_GATE.id}\tflutter test test/goldens_test.dart`);
  process.exit(0);
}

/** Runs one gate, capturing its status without letting a crash pass as success. */
function runGate(gate) {
  const command = gate.command ?? 'npm';
  const args = gate.args ?? ['run', '--silent', gate.script];
  const result = spawnSync(command, args, { encoding: 'utf8' });

  // A spawn that never produced an exit status did not pass — it did not run.
  if (result.error || result.status === null) {
    return {
      id: gate.id,
      what: gate.what,
      status: MISSING,
      exit_code: null,
      detail: result.error ? String(result.error.message) : 'no exit status',
    };
  }

  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`.trim();
  const lines = output.split('\n').filter((line) => line.trim().length > 0);
  return {
    id: gate.id,
    what: gate.what,
    status: result.status === 0 ? 'pass' : 'FAILED',
    exit_code: result.status,
    // Last meaningful line only: enough to identify the failure without
    // pasting an entire gate log into a committed report.
    detail: lines.length > 0 ? lines[lines.length - 1] : '(no output)',
  };
}

const gatesToRun = skipGoldens ? GATES : [...GATES, GOLDEN_GATE];
const results = [];
for (const gate of gatesToRun) {
  process.stdout.write(`• ${gate.what} … `);
  const result = runGate(gate);
  results.push(result);
  console.log(result.status);
}

const failed = results.filter((r) => r.status !== 'pass');
const pass = failed.length === 0;

const report = {
  report_type: 'parkinsum_verify_all',
  // Deliberately timestamp-free so regenerated reports diff cleanly.
  gate_count: results.length,
  pass,
  failed_gate_ids: failed.map((r) => r.id),
  goldens_included: !skipGoldens,
  gates: results,
  not_clinically_calibrated: true,
  synthetic_demo_data_only: true,
  no_medical_advice: true,
  safety_boundary:
    'Do not change medication, diet, or timing based on this app. Review ' +
    'with a qualified clinician before making health decisions.',
  not_advice_text:
    'This is an educational prototype output. It is not medical advice and ' +
    'must not be used to make medication, dietary, or timing decisions.',
};

const markdown = [
  '# Verification summary',
  '',
  'Every gate below is deterministic, offline, and runs on synthetic/demo data',
  'only. This is an educational prototype and is not calibrated for real care.',
  '',
  `**Result:** ${pass ? 'all gates passed' : `${failed.length} gate(s) failed`}`,
  `**Goldens included:** ${skipGoldens ? 'no (--skip-goldens)' : 'yes'}`,
  '',
  '| Gate | Status | Detail |',
  '| --- | --- | --- |',
  ...results.map(
    (r) => `| ${r.what} | ${r.status} | ${String(r.detail).replaceAll('|', '\\|')} |`,
  ),
  '',
  '## Reproduce',
  '',
  '```bash',
  'npm run verify:all',
  '```',
  '',
  '## Safety boundary',
  '',
  report.safety_boundary,
  '',
  report.not_advice_text,
  '',
].join('\n');

mkdirSync('build/verify_all', { recursive: true });
writeFileSync('build/verify_all/latest.json', `${JSON.stringify(report, null, 2)}\n`);
writeFileSync('build/verify_all/latest.md', markdown);

console.log('');
console.log(
  pass
    ? `All ${results.length} gates passed.`
    : `${failed.length} of ${results.length} gates failed: ${failed.map((r) => r.id).join(', ')}`,
);
console.log('Report: build/verify_all/latest.json');
console.log('Report: build/verify_all/latest.md');

process.exit(pass ? 0 : 1);
