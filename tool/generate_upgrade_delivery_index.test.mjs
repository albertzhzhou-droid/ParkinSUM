import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { generateDeliveryIndex, recordWebBuild, webBuildParameters, webBuildCommand, canonicalToolchainSha256, main, DELIVERY_INDEX_SCHEMA, WEB_BUILD_RECEIPT_SCHEMA, FORMAL_APP_JOURNEY_SCHEMA } from './generate_upgrade_delivery_index.mjs';
import { runVerification } from './run_verify_all.mjs';
import { captureInputs, sha256, supervise } from './verification_runtime.mjs';

function fixture(t) {
  const cwd = mkdtempSync(join(tmpdir(), 'parkinsum-delivery-fixture-'));
  t.after(() => rmSync(cwd, { recursive: true, force: true }));
  const put = (path, value) => { mkdirSync(dirname(join(cwd, path)), { recursive: true }); writeFileSync(join(cwd, path), value); };
  put('lib/main.dart', 'synthetic fixture formal entrypoint');
  put('lib/main_personal_log_view_benchmark.dart', 'synthetic fixture performance engineering entrypoint');
  put('tool/probe.dart', 'synthetic fixture harness entrypoint');
  put('tool/generate_upgrade_delivery_index.mjs', 'fixture generator identity');
  put('config/input.json', '{"identity":"original"}');
  put('test/fixtures/example.json', '{"synthetic":true}');
  put('package-lock.json', '{"fixture":1}');
  put('pubspec.lock', 'packages:\n  production:\n    dependency: "direct main"\n    source: hosted\n    version: "1.0.0"\n    description:\n      sha256: "0123456789abcdef"\n  build_test:\n    dependency: "direct dev"\n    source: hosted\n    version: "2.0.0"\n');
  put('tool/builder.mjs', `import {mkdirSync,writeFileSync} from 'node:fs';
if(process.argv.includes('--mutate'))writeFileSync('config/input.json','changed during build');
if(!process.argv.includes('--empty')) {mkdirSync('build/web/assets',{recursive:true});for(const [p,v]of Object.entries({'index.html':'fixture html','flutter_bootstrap.js':'fixture bootstrap','main.dart.js':'fixture main','assets/NOTICES':'fixture licenses'}))writeFileSync('build/web/'+p,v);}
if(process.argv.includes('--fail'))process.exitCode=1;
if(process.argv.includes('--hang'))setInterval(()=>{},1000);`);
  put('tool/producer.mjs', `import {mkdirSync,writeFileSync}from'node:fs';mkdirSync('build/fixture',{recursive:true});writeFileSync('build/fixture/report.json',JSON.stringify({schema_version:1,pass:true}));`);
  const sourceFiles = ['lib/main.dart', 'lib/main_personal_log_view_benchmark.dart', 'tool/probe.dart', 'tool/generate_upgrade_delivery_index.mjs', 'tool/builder.mjs', 'tool/producer.mjs', 'config/input.json', 'test/fixtures/example.json', 'package-lock.json', 'pubspec.lock'];
  const toolchain = { node: { version: process.version }, fixture: 'node-only-no-flutter-invoked' };
  const environment = { fixture: 'offline' };
  const base = { cwd, sourceFiles, toolchain, environment, attachSignals: false };
  const gates = [{ id: 'fixture', command: process.execPath, args: ['tool/producer.mjs'], output: { mode: 'json_files', reports: [{ path: 'build/fixture/report.json', predicate: 'boolean', key: 'pass', expected: true, identity: { schema_version: 1 } }] } }];
  const build = (extra = {}) => recordWebBuild({ ...base, executor: (command, args, options) => {
    assert.equal(command, 'flutter');
    assert.ok(args.includes('--no-web-resources-cdn'));
    assert.ok(args.includes('--dart-define=PARKINSUM_BACKEND=local'));
    return supervise(process.execPath, ['tool/builder.mjs', ...(extra.fixtureArgs ?? [])], options);
  }, ...extra });
  const verify = () => runVerification({ ...base, gates });
  const index = (extra = {}) => generateDeliveryIndex({ ...base, verificationInventory: gates, gitMetadata: { committed_head: 'fixture-head', committed_tree: 'fixture-tree', working_tree_dirty: true }, ...extra });
  const current = async (extra = {}) => { await build(); await verify(); return index({ buildReceiptPath: 'build/upgrade_delivery/build_receipt.json', verificationPath: 'build/verify_all/latest.json', ...extra }); };
  return { cwd, put, base, build, verify, index, current };
}

test('source and expected hash alone remain inventory-only; generated outputs do not recurse', async (t) => {
  const f = fixture(t);
  f.put('build/web/main.dart.js', 'old unobserved binary');
  f.put('build/upgrade_delivery/private-log.json', '{"private":true}');
  const source = captureInputs(f.cwd, f.base.sourceFiles);
  const first = await f.index({ expectedSource: source.sha256 });
  const second = await f.index();
  assert.equal(first.report.$schema, DELIVERY_INDEX_SCHEMA);
  assert.equal(first.report.disposition, 'inventory_only');
  assert.equal(first.report.current_candidate_evidence, false);
  assert.deepEqual(first.report.web_release, []);
  assert.equal(first.report.source.sha256, second.report.source.sha256);
  assert.ok(first.report.source.files.some((entry) => entry.path.startsWith('test/fixtures/')));
  assert.ok(first.report.source.files.some((entry) => entry.path.startsWith('tool/')));
});

test('observed build and exact passing run bind run/checkpoint/input/artifact identities', async (t) => {
  const f = fixture(t);
  const { report } = await f.current();
  assert.equal(report.disposition, 'current_local_engineering_candidate', JSON.stringify(report.refusal_reasons));
  assert.equal(report.current_candidate_evidence, true);
  assert.equal(report.verification.gate_count, 1);
  assert.match(report.verification.checkpoint.sha256, /^[a-f0-9]{64}$/);
  assert.match(report.verification.input_identity_sha256, /^[a-f0-9]{64}$/);
  assert.equal(report.build_receipt.parameters.target, 'lib/main.dart');
  assert.equal(report.licenses.length, 1);
  assert.equal(report.web_release.length, 4);
  const receipt = JSON.parse(readFileSync(join(f.cwd, 'build/upgrade_delivery/build_receipt.json')));
  assert.equal(receipt.$schema, WEB_BUILD_RECEIPT_SCHEMA);
  assert.equal(receipt.source_stable, true);
  assert.equal(receipt.execution.exit_code, 0);
  assert.equal(report.generator_sha256, sha256('fixture generator identity'));
});

test('old binary is removed and exit zero without a new entrypoint fails receipt', async (t) => {
  const f = fixture(t);
  await f.build();
  const receipt = await f.build({ fixtureArgs: ['--empty'] });
  assert.equal(receipt.status, 'failed');
  assert.equal(receipt.reason, 'missing_generated_web_entrypoint');
});

test('nonzero, timeout and source mutation cannot become build success', async (t) => {
  const f = fixture(t);
  assert.equal((await f.build({ fixtureArgs: ['--fail'] })).status, 'failed');
  const timed = await f.build({ fixtureArgs: ['--hang'], timeoutMs: 80, cleanupGraceMs: 20 });
  assert.equal(timed.status, 'failed');
  assert.equal(timed.reason, 'timeout');
  const mutated = await f.build({ fixtureArgs: ['--mutate'] });
  assert.equal(mutated.status, 'stale');
  assert.equal(mutated.source_stable, false);
});

test('explicit harness target is recorded without being relabeled as formal app', async (t) => {
  const f = fixture(t);
  const receipt = await f.build({ target: 'tool/probe.dart' });
  assert.equal(receipt.parameters.target, 'tool/probe.dart');
  assert.equal(receipt.formal_app_target, false);
  await f.verify();
  const { report } = await f.index({ expectedTarget: 'tool/probe.dart', buildReceiptPath: receipt.receipt_path, verificationPath: 'build/verify_all/latest.json' });
  assert.equal(report.build_receipt.status, 'current');
  assert.equal(report.disposition, 'inventory_only', JSON.stringify(report.refusal_reasons));
  assert.equal(report.current_candidate_evidence, false);
  assert.ok(report.missing_evidence.includes('formal_app_build_target'));
  assert.throws(() => webBuildParameters('../private.dart'));
  assert.throws(() => webBuildParameters('test/private.dart'));
});

test('source/fixture/lock/generator change refuses old evidence rather than replacing hashes', async (t) => {
  for (const path of ['config/input.json', 'test/fixtures/example.json', 'package-lock.json', 'tool/generate_upgrade_delivery_index.mjs']) {
    const f = fixture(t);
    const original = await f.current();
    f.put(path, 'changed source');
    const { report } = await f.index({ buildReceiptPath: 'build/upgrade_delivery/build_receipt.json', verificationPath: 'build/verify_all/latest.json' });
    assert.equal(report.disposition, 'refused', path);
    assert.equal(report.current_candidate_evidence, false);
    assert.notEqual(report.source.sha256, original.report.source.sha256);
    assert.ok(report.refusal_reasons.some((reason) => reason.includes('stale')));
  }
});

test('changed toolchain and expected build parameters refuse candidate evidence', async (t) => {
  const f = fixture(t);
  await f.current();
  const changed = await f.index({ toolchain: { ...f.base.toolchain, fixture: 'changed' }, buildReceiptPath: 'build/upgrade_delivery/build_receipt.json', verificationPath: 'build/verify_all/latest.json' });
  assert.equal(changed.report.disposition, 'refused');
  assert.ok(changed.report.refusal_reasons.some((reason) => reason.includes('toolchain')));
  const target = await f.index({ expectedTarget: 'tool/probe.dart', buildReceiptPath: 'build/upgrade_delivery/build_receipt.json' });
  assert.equal(target.report.disposition, 'refused');
  assert.ok(target.report.refusal_reasons.some((reason) => reason.includes('parameters')));
});

test('changed Web binary, extra artifact or removed license invalidates exact build set', async (t) => {
  for (const mutate of ['main', 'extra', 'remove']) {
    const f = fixture(t);
    await f.current();
    if (mutate === 'main') f.put('build/web/main.dart.js', 'modified');
    if (mutate === 'extra') f.put('build/web/private.json', '{"unexpected":true}');
    if (mutate === 'remove') rmSync(join(f.cwd, 'build/web/assets/NOTICES'));
    const { report } = await f.index({ buildReceiptPath: 'build/upgrade_delivery/build_receipt.json' });
    assert.equal(report.disposition, 'refused', mutate);
    assert.deepEqual(report.web_release, []);
    assert.ok(report.refusal_reasons.includes('Web build artifact set changed'));
  }
});

test('changed producer and checkpoint invalidate verification independently of pass=true', async (t) => {
  for (const mutate of ['producer', 'checkpoint', 'latest']) {
    const f = fixture(t);
    await f.current();
    const latestPath = join(f.cwd, 'build/verify_all/latest.json');
    const run = JSON.parse(readFileSync(latestPath));
    if (mutate === 'producer') f.put('build/fixture/report.json', '{"schema_version":1,"pass":true,"changed":true}');
    if (mutate === 'checkpoint') f.put(run.checkpoint_path, JSON.stringify({ ...JSON.parse(readFileSync(join(f.cwd, run.checkpoint_path))), toolchain_error: 'tampered' }));
    if (mutate === 'latest') f.put('build/verify_all/latest.json', JSON.stringify({ ...run, gate_count: 55 }));
    const { report } = await f.index({ buildReceiptPath: 'build/upgrade_delivery/build_receipt.json', verificationPath: 'build/verify_all/latest.json' });
    assert.equal(report.disposition, 'refused', mutate);
    assert.equal(report.verification, null);
  }
});

test('explicit allowlist refuses private paths and symlink escapes', async (t) => {
  const f = fixture(t);
  const { report } = await f.index({ buildReceiptPath: 'private/receipt.json', verificationPath: 'build/private/report.json' });
  assert.equal(report.disposition, 'refused');
  assert.equal(report.refusal_reasons.length, 2);
  const outside = mkdtempSync(join(tmpdir(), 'parkinsum-delivery-outside-'));
  t.after(() => rmSync(outside, { recursive: true, force: true }));
  mkdirSync(join(f.cwd, 'build'), { recursive: true });
  symlinkSync(outside, join(f.cwd, 'build/web'));
  const result = await f.build();
  assert.equal(result.status, 'failed');
  assert.match(result.reason, /escape|Symlink/);
});

test('historical screenshots keep their original source/binary hashes and unbound images are excluded', async (t) => {
  const f = fixture(t);
  const path = 'build/upgrade_delivery/screenshots/next.jpg';
  f.put(path, 'synthetic screenshot bytes');
  f.put('build/upgrade_delivery/screenshots/unbound.jpg', 'not inventoried');
  const oldSource = '0'.repeat(64);
  const oldBinary = '1'.repeat(64);
  f.put('build/upgrade_delivery/screenshots/next-provenance.json', JSON.stringify({ captured_at_utc: '2026-09-30T00:00:00Z', screenshots: [{ path, sha256: sha256('synthetic screenshot bytes'), working_source_sha256: oldSource, web_main_sha256: oldBinary }] }));
  const { report } = await f.current();
  assert.equal(report.screenshots.entries.length, 1);
  assert.equal(report.screenshots.entries[0].captured_source_sha256, oldSource);
  assert.equal(report.screenshots.entries[0].captured_web_main_sha256, oldBinary);
  assert.equal(report.screenshots.entries[0].current_candidate, false);
  assert.equal(report.screenshots.entries[0].disposition, 'historical_next_capture');
});

test('screenshot tampering refuses evidence and SPDX count is lock-derived including dev/build', async (t) => {
  const f = fixture(t);
  const path = 'build/upgrade_delivery/screenshots/next.jpg';
  f.put(path, 'changed screenshot');
  f.put('build/upgrade_delivery/screenshots/next-provenance.json', JSON.stringify({ screenshots: [{ path, sha256: sha256('original screenshot'), working_source_sha256: '0'.repeat(64), web_main_sha256: '1'.repeat(64) }] }));
  const { report } = await f.index();
  assert.equal(report.disposition, 'refused');
  assert.equal(report.dependency_sbom.package_count, 2);
  const sbom = JSON.parse(readFileSync(join(f.cwd, report.dependency_sbom.path)));
  assert.equal(sbom.packages.length, 2);
  assert.ok(sbom.packages.every((entry) => entry.licenseConcluded === 'NOASSERTION' && entry.licenseDeclared === 'NOASSERTION'));
  assert.ok(sbom.packages.some((entry) => entry.summary.includes('direct dev')));
  assert.match(sbom.documentComment, /Does not prove binary reachability/);
});

function megaCapture(f, receipt, mutate = {}) {
  const path = 'build/upgrade_delivery/screenshots/mega.jpg';
  f.put(path, 'synthetic MEGA capture');
  f.put('build/upgrade_delivery/screenshots/mega-provenance.json', JSON.stringify({ screenshots: [{
    path, sha256: sha256('synthetic MEGA capture'), working_source_sha256: receipt.source.sha256,
    web_main_sha256: receipt.artifacts.find((entry) => entry.path === 'build/web/main.dart.js').sha256,
    build_id: receipt.build_id, target: receipt.parameters.target, captured_at_utc: '2026-09-30T03:00:00Z',
    ...mutate,
  }] }));
}

test('MEGA formal capture binds current full source/build/target/binary while NEXT stays historical', async (t) => {
  const f = fixture(t);
  const receipt = await f.build();
  await f.verify();
  megaCapture(f, receipt);
  const nextPath = 'build/upgrade_delivery/screenshots/next.jpg';
  f.put(nextPath, 'historical NEXT');
  f.put('build/upgrade_delivery/screenshots/next-provenance.json', JSON.stringify({ screenshots: [{ path: nextPath, sha256: sha256('historical NEXT'), working_source_sha256: '0'.repeat(64), web_main_sha256: '1'.repeat(64) }] }));
  const { report } = await f.index({ buildReceiptPath: receipt.receipt_path, verificationPath: 'build/verify_all/latest.json' });
  assert.equal(report.current_candidate_evidence, true);
  assert.equal(report.screenshots.provenance.length, 2);
  assert.equal(report.screenshots.entries.find((entry) => entry.path === nextPath).current_candidate, false);
  const mega = report.screenshots.entries.find((entry) => entry.path.endsWith('mega.jpg'));
  assert.equal(mega.current_candidate, true);
  assert.equal(mega.captured_build_id, receipt.build_id);
  assert.equal(mega.captured_target, 'lib/main.dart');
});

test('wrong build ID, stale source, wrong binary and absent time exclude MEGA capture from current evidence', async (t) => {
  for (const mutate of [{ build_id: 'wrong-build' }, { working_source_sha256: '0'.repeat(64) }, { web_main_sha256: '1'.repeat(64) }, { captured_at_utc: null }]) {
    const f = fixture(t);
    const receipt = await f.build();
    megaCapture(f, receipt, mutate);
    const { report } = await f.index({ buildReceiptPath: receipt.receipt_path });
    assert.equal(report.screenshots.entries.length, 0);
    assert.equal(report.screenshots.excluded_unbound_captures.length, 1);
    assert.equal(report.screenshots.excluded_unbound_captures[0].current_candidate, false);
  }
});

test('engineering harness and missing validated receipt cannot qualify MEGA captures', async (t) => {
  const f = fixture(t);
  const receipt = await f.build({ target: 'tool/probe.dart' });
  megaCapture(f, receipt);
  const harness = await f.index({ expectedTarget: 'tool/probe.dart', buildReceiptPath: receipt.receipt_path });
  assert.equal(harness.report.screenshots.entries.length, 0);
  assert.equal(harness.report.screenshots.excluded_unbound_captures[0].reason, 'engineering_or_unbound_target');
  const unbound = await f.index();
  assert.equal(unbound.report.screenshots.entries.length, 0);
  assert.equal(unbound.report.screenshots.excluded_unbound_captures[0].reason, 'validated_build_unavailable');
});

const benchmarkTarget = 'lib/main_personal_log_view_benchmark.dart';
const w31ReceiptPath = 'build/mega_upgrade/w31_formal_journey.json';
const w31CheckNames = ['formal_entry_release', 'persistent_services_backend', 'meal_create_edit', 'tab_reopen_persistence', 'portable_export_integrity', 'restore_inspect_confirm', 'restore_undo', 'report_export', 'insights_to_timeline'];
function observedW31(f, mutate = {}) {
  const source = captureInputs(f.cwd, f.base.sourceFiles);
  const receipt = { $schema: FORMAL_APP_JOURNEY_SCHEMA, status: 'verified', target: 'lib/main.dart', working_source_sha256: source.sha256,
    build_id: 'observed-formal-build', web_main_sha256: '1'.repeat(64), checks: Object.fromEntries(w31CheckNames.map((name) => [name, true])),
    boundary: 'Node synthetic fixture of root-observed UI checks only; not actual formal app evidence.', ...mutate };
  f.put(w31ReceiptPath, JSON.stringify(receipt));
  return receipt;
}
const benchmarkOptions = { target: benchmarkTarget, benchmarkW31ReceiptPath: w31ReceiptPath };

test('benchmark emits only four fixed defines bound to actual source/canonical toolchain and observed receipt', async (t) => {
  const f = fixture(t);
  observedW31(f);
  const receipt = await f.build(benchmarkOptions);
  assert.equal(receipt.status, 'built');
  assert.equal(receipt.formal_app_target, false);
  const defines = receipt.parameters.benchmark.dart_defines;
  assert.deepEqual(defines, [
    'PARKINSUM_W31_BASELINE_VERIFIED=true', `PARKINSUM_W31_RECEIPT=${w31ReceiptPath}`,
    `PARKINSUM_BENCHMARK_INPUT_SHA256=${receipt.source.sha256}`,
    `PARKINSUM_BENCHMARK_TOOLCHAIN=${canonicalToolchainSha256(receipt.toolchain)}`,
  ]);
  assert.equal(receipt.command.args.filter((arg) => arg.startsWith('--dart-define=')).length, 5); // Backend + four fixed benchmark flags.
  assert.ok(!receipt.command.args.some((arg) => arg.includes('PARKINSUM_BENCHMARK_BUILD_RECEIPT')));
  assert.equal(receipt.parameters.benchmark.w31_receipt.sha256, sha256(readFileSync(join(f.cwd, w31ReceiptPath))));
  assert.match(receipt.parameters.benchmark.scope, /No benchmark measurement/);
  const { report } = await f.index({ expectedTarget: benchmarkTarget, buildReceiptPath: receipt.receipt_path });
  assert.equal(report.build_receipt.status, 'current');
  assert.equal(report.current_candidate_evidence, false);
  assert.equal(report.disposition, 'inventory_only');
});

test('toolchain compile hash uses canonical object ordering and changes on actual version change', () => {
  const first = { flutter: { version: 'fixture', revision: 'A' }, node: 'fixture-node' };
  const reordered = { node: 'fixture-node', flutter: { revision: 'A', version: 'fixture' } };
  assert.equal(canonicalToolchainSha256(first), canonicalToolchainSha256(reordered));
  assert.notEqual(canonicalToolchainSha256(first), canonicalToolchainSha256({ ...first, node: 'changed-version' }));
});

test('benchmark baseline requires exact URI/status/formal target/current source/build/binary and all nine true checks', async (t) => {
  for (const mutation of [{ $schema: 'unknown/1' }, { status: 'HOLD' }, { target: 'tool/probe.dart' }, { working_source_sha256: '0'.repeat(64) }, { build_id: '' }, { web_main_sha256: 'invalid' }, { checks: [] }, { checks: {} }, ...w31CheckNames.map((name) => ({ checks: Object.fromEntries(w31CheckNames.map((key) => [key, key !== name])) }))]) {
    const f = fixture(t);
    observedW31(f, mutation);
    let invoked = false;
    const receipt = await f.build({ ...benchmarkOptions, executor: async () => { invoked = true; throw new Error('must not execute builder'); } });
    assert.equal(receipt.status, mutation.working_source_sha256 ? 'stale' : 'failed');
    assert.equal(invoked, false, JSON.stringify(mutation));
  }
});

test('fixed W31 argument is required only on benchmark target and arbitrary Dart defines are rejected', async (t) => {
  const f = fixture(t);
  observedW31(f);
  await assert.rejects(f.build({ target: benchmarkTarget }), /exact formal W31 receipt/);
  await assert.rejects(f.build({ target: benchmarkTarget, benchmarkW31ReceiptPath: 'build/private/receipt.json' }), /exact formal W31 receipt/);
  await assert.rejects(f.build({ target: 'lib/main.dart', benchmarkW31ReceiptPath: w31ReceiptPath }), /forbidden on other targets/);
  await assert.rejects(f.build({ target: 'tool/probe.dart', benchmarkW31ReceiptPath: w31ReceiptPath }), /forbidden on other targets/);
  await assert.rejects(main(['--build-web', '--dart-define=ARBITRARY=true']), /Unknown delivery argument/);
  assert.throws(() => webBuildParameters('lib/main.dart', { dart_defines: ['PARKINSUM_W31_BASELINE_VERIFIED=true'] }), /forbidden/);
  assert.throws(() => webBuildCommand({ target: 'lib/main.dart', benchmark: { dart_defines: ['PARKINSUM_W31_BASELINE_VERIFIED=true'] } }), /forbidden/);
  assert.throws(() => webBuildCommand({ target: benchmarkTarget, benchmark: { dart_defines: ['ARBITRARY=true'] } }), /Only four fixed/);
});

test('changed source revokes W31 baseline and changed receipt during build cannot attest success', async (t) => {
  const stale = fixture(t);
  observedW31(stale);
  stale.put('config/input.json', 'new input after W31');
  const rejected = await stale.build(benchmarkOptions);
  assert.equal(rejected.status, 'stale');
  assert.match(rejected.reason, /source is stale/);
  const changed = fixture(t);
  const baseline = observedW31(changed);
  const receipt = await changed.build({ ...benchmarkOptions, executor: async (command, args, options) => {
    const execution = await supervise(process.execPath, ['tool/builder.mjs'], options);
    changed.put(w31ReceiptPath, JSON.stringify({ ...baseline, additional_observation: true }));
    return execution;
  } });
  assert.equal(receipt.status, 'stale');
  assert.match(receipt.reason, /changed during benchmark/);
});

test('post-build receipt/compile parameter changes refuse benchmark evidence and cannot acquire formal green', async (t) => {
  for (const mutation of ['w31', 'flag', 'target', 'formal']) {
    const f = fixture(t);
    const baseline = observedW31(f);
    const receipt = await f.build(benchmarkOptions);
    if (mutation === 'w31') f.put(w31ReceiptPath, JSON.stringify({ ...baseline, additional_observation: true }));
    else {
      if (mutation === 'flag') receipt.parameters.benchmark.dart_defines[2] = 'PARKINSUM_BENCHMARK_INPUT_SHA256=' + '0'.repeat(64);
      if (mutation === 'target') { receipt.parameters.target = 'lib/main.dart'; receipt.formal_app_target = true; }
      if (mutation === 'formal') receipt.formal_app_target = true;
      f.put(receipt.receipt_path, JSON.stringify(receipt));
      f.put('build/upgrade_delivery/build_receipt.json', JSON.stringify(receipt));
    }
    const expectedTarget = mutation === 'target' ? 'lib/main.dart' : benchmarkTarget;
    const { report } = await f.index({ expectedTarget, buildReceiptPath: receipt.receipt_path });
    assert.equal(report.current_candidate_evidence, false);
    if (mutation !== 'formal') assert.equal(report.disposition, 'refused', mutation);
    if (report.build_receipt) assert.equal(report.build_receipt.formal_app_target, false);
  }
});
