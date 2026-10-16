import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, readFileSync, renameSync, unlinkSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { artifactIdentity, captureInputs, INPUT_EXCLUSIONS, sourcePaths, sha256 } from './verification_runtime.mjs';

function fileFixture(t) {
  const cwd = mkdtempSync(join(tmpdir(), 'parkinsum-complete-file-evidence-'));
  t.after(() => rmSync(cwd, { recursive: true, force: true }));
  mkdirSync(join(cwd, 'lib'));
  mkdirSync(join(cwd, 'build'));
  writeFileSync(join(cwd, 'lib/input.dart'), 'synthetic source bytes');
  writeFileSync(join(cwd, 'build/actual.bin'), 'synthetic artifact bytes');
  return cwd;
}

test('a positive-size source with an empty failed read cannot receive a source fingerprint', (t) => {
  const cwd = fileFixture(t);
  assert.throws(() => captureInputs(cwd, ['lib/input.dart'], { readFile: () => Buffer.alloc(0) }), { code: 'FILE_CONTENT_INCOMPLETE' });
});

test('a partially read artifact cannot be promoted by its truncated checksum', (t) => {
  const cwd = fileFixture(t);
  assert.throws(() => artifactIdentity(cwd, 'build/actual.bin', { readFile: path => readFileSync(path).subarray(0, 5) }), { code: 'FILE_CONTENT_INCOMPLETE' });
});

test('a real same-length inode replacement during input capture is refused', (t) => {
  const cwd = fileFixture(t);
  const replacement = join(cwd, 'lib/replacement.dart');
  writeFileSync(replacement, 'different source data!');
  assert.equal(readFileSync(replacement).length, readFileSync(join(cwd, 'lib/input.dart')).length);
  assert.throws(() => captureInputs(cwd, ['lib/input.dart'], {
    readFile: path => { const bytes = readFileSync(path); renameSync(replacement, path); return bytes; },
  }), { code: 'FILE_CHANGED_DURING_CAPTURE' });
});

test('a source removed during content capture fails instead of returning a successful snapshot', (t) => {
  const cwd = fileFixture(t);
  assert.throws(() => captureInputs(cwd, ['lib/input.dart'], {
    readFile: path => { const bytes = readFileSync(path); unlinkSync(path); return bytes; },
  }), { code: 'ENOENT' });
});

test('actual complete content and genuine empty files retain their original fingerprint representation', (t) => {
  const cwd = fileFixture(t);
  writeFileSync(join(cwd, 'lib/empty.dart'), '');
  const inputs = captureInputs(cwd, ['lib/empty.dart', 'lib/input.dart']);
  assert.deepEqual(inputs.files, [
    { path: 'lib/empty.dart', sha256: sha256(Buffer.alloc(0)) },
    { path: 'lib/input.dart', sha256: sha256(readFileSync(join(cwd, 'lib/input.dart'))) },
  ]);
  assert.equal(artifactIdentity(cwd, 'build/actual.bin').sha256, sha256(readFileSync(join(cwd, 'build/actual.bin'))));
});

test('only the exact timeline and derived final acceptance document are excluded; plan/research remain bound', (t) => {
  const cwd = mkdtempSync(join(tmpdir(), 'parkinsum-input-scope-fixture-'));
  t.after(() => rmSync(cwd, { recursive: true, force: true }));
  execFileSync('git', ['init', '--quiet'], { cwd });
  mkdirSync(join(cwd, 'docs'));
  const docs = ['docs/APP_EVOLUTION_TIMELINE.md', 'docs/MEGA_UPGRADE_RESULTS_2026-09-30.md', 'docs/MEGA_UPGRADE_EXECUTION_PLAN.md', 'docs/MEGA_UPGRADE_RESULTS_2026-10-01.md', 'docs/IMPORTER_RESEARCH.md'];
  for (const path of docs) writeFileSync(join(cwd, path), 'synthetic static input');
  assert.deepEqual(INPUT_EXCLUSIONS, docs.slice(0, 2));
  assert.deepEqual(sourcePaths(cwd), docs.slice(2).sort());
  const first = captureInputs(cwd);
  writeFileSync(join(cwd, docs[1]), 'derived final counts after source freeze');
  assert.equal(captureInputs(cwd).sha256, first.sha256);
  assert.deepEqual(captureInputs(cwd, docs).exclusions, docs.slice(0, 2));
  assert.equal(captureInputs(cwd, docs).files.length, 3);
  writeFileSync(join(cwd, docs[4]), 'changed research input');
  assert.notEqual(captureInputs(cwd).sha256, first.sha256);
});

test('standard runtime options affect declared identity without exporting their raw values or credentials', async () => {
  const { declaredEnvironment } = await import('./verification_runtime.mjs');
  const env = { PATH: '/fixture/tools', NODE_OPTIONS: '--fixture-private-path', TZ: 'UTC', CI: 'true', npm_config_ignore_scripts: 'true', npm_config_token: 'private-token', FIREBASE_API_KEY: 'private-key' };
  const first = declaredEnvironment(env);
  assert.notEqual(JSON.stringify(declaredEnvironment({ ...env, TZ: 'Australia/Sydney' })), JSON.stringify(first));
  assert.match(first.runtime_option_sha256.NODE_OPTIONS, /^[a-f0-9]{64}$/);
  assert.equal(first.runtime_option_sha256.npm_config_token, undefined);
  assert.ok(!JSON.stringify(first).includes('private-token'));
  assert.ok(!JSON.stringify(first).includes('--fixture-private-path'));
  assert.ok(!JSON.stringify(first).includes('private-key'));
});
