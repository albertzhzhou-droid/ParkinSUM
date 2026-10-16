import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawn } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import { defaultGates, runVerification } from './run_verify_all.mjs';
import { outputDeclaration, reportPasses } from './verification_output_contracts.mjs';

const pause = (ms) => new Promise((done) => setTimeout(done, ms));
function fixture(t, code = '') {
  const cwd = mkdtempSync(join(tmpdir(), 'parkinsum-verify-fixture-'));
  t.after(() => rmSync(cwd, { recursive: true, force: true }));
  writeFileSync(join(cwd, 'input.txt'), 'fixed synthetic input');
  writeFileSync(join(cwd, 'producer.mjs'), `import {mkdirSync,writeFileSync,readFileSync,existsSync} from 'node:fs';
mkdirSync('build',{recursive:true});
const [path,mode='write']=process.argv.slice(2);
const countPath=path+'.count';
writeFileSync(countPath,String((existsSync(countPath)?Number(readFileSync(countPath)):0)+1));
if(mode==='write')writeFileSync(path,JSON.stringify({schema:'fixture/1',pass:true}));
if(mode==='fail')process.exitCode=1;
if(mode==='hang')setInterval(()=>{},1000);
${code}`);
  const gate = (id = 'first', mode = 'write') => ({ id, what: id, command: process.execPath, args: ['producer.mjs', `build/${id}.json`, mode],
    output: { mode: 'json_files', reports: [{ path: `build/${id}.json`, predicate: 'boolean', key: 'pass', expected: true, identity: { schema: 'fixture/1' } }] } });
  const run = (gates, extra = {}) => runVerification({ cwd, gates, sourceFiles: ['input.txt', 'producer.mjs'], toolchain: { node: process.version, fixture: true }, environment: {},
    timeoutMs: 3000, cleanupGraceMs: 50, maxLogBytes: 256, attachSignals: false, ...extra });
  return { cwd, gate, run };
}

test('all existing 55 identities have explicit contracts; goldens remain default', () => {
  const gates = defaultGates();
  assert.equal(gates.length, 55);
  assert.equal(defaultGates(true).length, 54);
  assert.equal(gates.at(-1).id, 'committed_goldens');
  assert.equal(gates.filter((gate) => gate.output.mode === 'json_files').length, 44);
  assert.equal(gates.filter((gate) => gate.output.mode !== 'json_files').length, 11);
  for (const gate of gates) assert.ok(outputDeclaration(gate.id));
});

test('existing gastric gate requires the additional actual identifiability report', () => {
  const reports = outputDeclaration('gastric_structures').reports;
  assert.equal(reports.length, 2);
  const contract = reports.find(report => report.path === 'build/gastric_identifiability/latest.json');
  assert.ok(contract);
  assert.equal(reportPasses({schema: 'parkinsum.gastric-identifiability-check/1', pass: true}, contract), true);
  for (const value of [{}, {schema: 'parkinsum.gastric-identifiability-check/1', pass: false}, {schema: 'parkinsum.gastric-identifiability-check/2', pass: true}]) {
    assert.equal(reportPasses(value, contract), false);
  }
});

test('explicit predicates preserve held and rejected governance fixtures', () => {
  const impact = outputDeclaration('algorithm_configuration_impact').reports[0];
  assert.equal(reportPasses({ $schema: impact.identity.$schema, integrity_reasons: [], can_close_impact: false }, impact), true);
  assert.equal(reportPasses({ $schema: impact.identity.$schema, can_close_impact: true }, impact), false);
  const baseline = outputDeclaration('configuration_baseline_registry').reports[0];
  assert.equal(reportPasses({ transition_accepted: false, transition_reason: 'verification_obligations_incomplete', registry: { events: [{}, {}] } }, baseline), true);
});

test('a current producer passes and atomic checkpoints are independently readable', async (t) => {
  const { gate, run, cwd } = fixture(t);
  const statuses = [];
  const report = await run([gate()], { onCheckpoint: (checkpoint) => statuses.push(JSON.parse(readFileSync(join(cwd, 'build/verify_all/runs', checkpoint.run_id, 'checkpoint.json'))).gates[0].status) });
  assert.equal(report.pass, true);
  assert.deepEqual(statuses, ['not_run', 'running', 'pass', 'pass']);
  assert.equal(report.gates[0].artifacts.length, 1);
});

test('exit zero without a newly produced report cannot reuse an old passing file', async (t) => {
  const { gate, run, cwd } = fixture(t);
  mkdirSync(join(cwd, 'build'));
  writeFileSync(join(cwd, 'build/first.json'), '{"schema":"fixture/1","pass":true}');
  const report = await run([gate('first', 'none')]);
  assert.equal(report.pass, false);
  assert.equal(report.gates[0].status, 'missing_or_invalid_report');
});

test('missing command and timeout stay failures; later gates run serially', async (t) => {
  const { gate, run } = fixture(t);
  // The hang is indefinite; a one-second bound still proves timeout while
  // allowing the later Node process to start on a loaded CI host.
  const report = await run([{ ...gate('absent'), command: '/no-such-parkinsum-test-tool' }, gate('slow', 'hang'), gate('after')], { timeoutMs: 1000 });
  assert.equal(report.gates[0].status, 'missing_tool');
  assert.equal(report.gates[1].status, 'timeout');
  assert.equal(report.gates[2].status, 'pass');
  assert.equal(report.pass, false);
});

test('resume reuses only passed matching inputs/command/artifacts and reruns unfinished gate', async (t) => {
  const { gate, run, cwd } = fixture(t);
  const first = await run([gate('first'), gate('second', 'none')]);
  const second = await run([gate('first'), gate('second')], { resumePath: first.checkpoint_path });
  assert.equal(second.pass, true);
  assert.equal(second.gates[0].reused_from_run_id, first.run_id);
  assert.equal(readFileSync(join(cwd, 'build/first.json.count'), 'utf8'), '1');
  assert.equal(readFileSync(join(cwd, 'build/second.json.count'), 'utf8'), '2');
  assert.notEqual(second.run_id, first.run_id);
});

test('changed input, toolchain, command or artifact each invalidates resume', async (t) => {
  const { gate, run, cwd } = fixture(t);
  let report = await run([gate()]);
  writeFileSync(join(cwd, 'input.txt'), 'changed');
  report = await run([gate()], { resumePath: report.checkpoint_path });
  assert.equal(report.gates[0].reused_from_run_id, undefined);
  report = await run([gate()], { resumePath: report.checkpoint_path, toolchain: { node: 'changed-fixture-version' } });
  assert.equal(report.gates[0].reused_from_run_id, undefined);
  writeFileSync(join(cwd, 'build/first.json'), '{ "schema":"fixture/1", "pass":true }');
  report = await run([gate()], { resumePath: report.checkpoint_path });
  assert.equal(report.gates[0].reused_from_run_id, undefined);
  assert.equal(readFileSync(join(cwd, 'build/first.json.count'), 'utf8'), '4');
  const changedCommand = { ...gate(), args: [...gate().args, 'different-declared-parameter'] };
  report = await run([changedCommand], { resumePath: report.checkpoint_path });
  assert.equal(report.gates[0].reused_from_run_id, undefined);
  assert.equal(readFileSync(join(cwd, 'build/first.json.count'), 'utf8'), '5');
});

test('source changes during a gate revoke its result and leave later gates not_run', async (t) => {
  const { gate, run } = fixture(t, "writeFileSync('input.txt','changed while executing');");
  const report = await run([gate(), gate('later')]);
  assert.equal(report.gates[0].status, 'source_changed');
  assert.equal(report.gates[1].status, 'not_run');
  assert.equal(report.pass, false);
});

test('console-only contract does not claim a producer; logs stay bounded', async (t) => {
  const { gate, run } = fixture(t, "process.stdout.write('x'.repeat(5000));");
  const report = await run([{ ...gate(), output: { mode: 'console_test', reports: [] } }]);
  assert.equal(report.pass, true);
  assert.equal(report.gates[0].artifacts.length, 0);
  assert.equal(report.gates[0].log_artifact.bytes, 256);
  assert.equal(report.gates[0].execution.log_truncated, true);
});

for (const [name, text, reason] of [
  ['reported failure even with later success', '00:03 +245 -2: Some tests failed.\n00:04 +7: All tests passed!\n', 'console_reported_test_failure'],
  ['unfinished exit zero', '00:03 +245: still running\n', 'console_test_completion_missing'],
  ['marker without test counts', 'All tests passed!\n', 'console_test_completion_missing'],
  ['zero test completion', '00:01 +0: All tests passed!\n', 'console_test_count_incomplete'],
  ['expected golden skipped', '00:01 +6 ~1: All tests passed!\n', 'console_test_count_incomplete'],
]) test(`golden console refuses ${name}`, async (t) => {
  const { gate, run } = fixture(t, `process.stdout.write(${JSON.stringify(text)});`);
  const report = await run([{ ...gate(), output: outputDeclaration('committed_goldens') }]);
  assert.equal(report.gates[0].execution.exit_code, 0);
  assert.equal(report.pass, false);
  assert.equal(report.gates[0].reason, reason);
});

test('complete seven-test ANSI compact summary passes its explicit contract', async (t) => {
  const { gate, run } = fixture(t, `process.stdout.write(${JSON.stringify('\u001b[32m00:01 +3: running\r00:02 +7: All tests passed!\u001b[0m\n')});`);
  const report = await run([{ ...gate(), output: outputDeclaration('committed_goldens') }]);
  assert.equal(report.pass, true);
  assert.deepEqual(report.gates[0].completion_validation.counts, { passed: 7, skipped: 0, failed: 0 });
});

test('golden completion cannot qualify a truncated log', async (t) => {
  const { gate, run } = fixture(t, "process.stdout.write('00:02 +7: All tests passed!\\n'+'x'.repeat(5000));");
  const report = await run([{ ...gate(), output: outputDeclaration('committed_goldens') }]);
  assert.equal(report.gates[0].execution.exit_code, 0);
  assert.equal(report.gates[0].execution.log_truncated, true);
  assert.equal(report.pass, false);
  assert.equal(report.gates[0].reason, 'console_log_incomplete');
});

test('changed complete console log is not reused on resume', async (t) => {
  const { gate, run, cwd } = fixture(t, "process.stdout.write('00:02 +7: All tests passed!\\n');");
  const declared = { ...gate(), output: outputDeclaration('committed_goldens') };
  const first = await run([declared]);
  assert.equal(first.pass, true);
  writeFileSync(join(cwd, first.gates[0].log_path), '00:02 +7: All tests passed!\nchanged after verification');
  const next = await run([declared], { resumePath: first.checkpoint_path });
  assert.equal(next.pass, true);
  assert.equal(next.gates[0].reused_from_run_id, undefined);
  assert.equal(readFileSync(join(cwd, 'build/first.json.count'), 'utf8'), '2');
});

test('unsupported or null console completion declarations fail closed', async (t) => {
  const { gate, run } = fixture(t);
  for (const completion of [null, { protocol: 'unknown', minimum_passed: 7 }, { protocol: 'flutter_test_summary_v1', minimum_passed: 0 }]) {
    await assert.rejects(run([{ ...gate(), output: { mode: 'console_test', reports: [], completion } }]), /Unsupported console completion contract/);
  }
});

for (const interruption of ['SIGINT', 'SIGTERM']) test(`${interruption} revokes a live run and kills its own stubborn child group`, { skip: process.platform === 'win32' }, async (t) => {
  const { cwd, gate } = fixture(t);
  writeFileSync(join(cwd, 'producer.mjs'), `import{spawn}from'node:child_process';import{mkdirSync,writeFileSync}from'node:fs';
mkdirSync('build',{recursive:true});process.on('SIGTERM',()=>{});
const grandchild=spawn(process.execPath,['-e',"process.on('SIGTERM',()=>{});setInterval(()=>{},1000)"],{stdio:'ignore'});
writeFileSync('build/grandchild.pid',String(grandchild.pid));setInterval(()=>{},1000);`);
  const module = pathToFileURL(resolve('tool/run_verify_all.mjs')).href;
  writeFileSync(join(cwd, 'driver.mjs'), `import{runVerification}from ${JSON.stringify(module)};await runVerification({cwd:process.cwd(),gates:${JSON.stringify([gate(), gate('later')])},sourceFiles:['input.txt','producer.mjs'],toolchain:{node:'fixture'},environment:{},timeoutMs:5000,cleanupGraceMs:80});`);
  const child = spawn(process.execPath, ['driver.mjs'], { cwd, stdio: 'ignore' });
  const completion = new Promise((done) => child.once('close', done));
  t.after(() => { try { child.kill('SIGKILL'); } catch {} });
  for (let i = 0; i < 100 && !existsSync(join(cwd, 'build/grandchild.pid')); i += 1) await pause(20);
  assert.equal(existsSync(join(cwd, 'build/grandchild.pid')), true);
  const pid = Number(readFileSync(join(cwd, 'build/grandchild.pid')));
  child.kill(interruption);
  await completion;
  const report = JSON.parse(readFileSync(join(cwd, 'build/verify_all/latest.json')));
  assert.equal(report.interruption, interruption);
  assert.equal(report.gates[0].status, 'interrupted');
  assert.equal(report.gates[1].status, 'not_run');
  for (let i = 0; i < 50; i += 1) { try { process.kill(pid, 0); await pause(20); } catch { break; } }
  assert.throws(() => process.kill(pid, 0), { code: 'ESRCH' });
});

test('malformed JSON, wrong schema and explicit false remain invalid producer evidence', async (t) => {
  for (const bytes of ['{broken', '{"schema":"fixture/2","pass":true}', '{"schema":"fixture/1","pass":false}']) {
    const f = fixture(t, `writeFileSync(path,${JSON.stringify(bytes)});`);
    const report = await f.run([f.gate()]);
    assert.equal(report.pass, false);
    assert.equal(report.gates[0].status, 'missing_or_invalid_report');
  }
});

test('later producer overwrite invalidates earlier shared report before final summary', async (t) => {
  const f = fixture(t, "if(process.argv.includes('rewrite-shared'))writeFileSync('build/first.json',JSON.stringify({schema:'fixture/1',pass:true,changed:true}));");
  const second = { ...f.gate('second'), args: [...f.gate('second').args, 'rewrite-shared'] };
  const report = await f.run([f.gate(), second]);
  assert.equal(report.gates[0].status, 'artifact_changed');
  assert.equal(report.gates[1].status, 'pass');
  assert.equal(report.pass, false);
});

test('report path IO error produces checkpointed failure and leaves later gate not_run', async (t) => {
  const f = fixture(t);
  mkdirSync(join(f.cwd, 'build/first.json'), { recursive: true });
  const report = await f.run([f.gate(), f.gate('later')]);
  assert.equal(report.gates[0].status, 'runner_error');
  assert.equal(report.gates[1].status, 'not_run');
  assert.equal(report.pass, false);
  const checkpoint = JSON.parse(readFileSync(join(f.cwd, report.checkpoint_path)));
  assert.equal(checkpoint.gates[0].status, 'runner_error');
});
