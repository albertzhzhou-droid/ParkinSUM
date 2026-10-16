import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, mkdirSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

test('existing FHIR producer CLI writes the explicit report and preserves exact stdout JSON', (t) => {
  const cwd = mkdtempSync(join(tmpdir(), 'parkinsum-fhir-output-'));
  t.after(() => rmSync(cwd, { recursive: true, force: true }));
  for (const stem of ['fhir_r5_cpg_apply_contract', 'fhir_r5_activitydefinition_apply_contract', 'fhir_r5_plandefinition_data_requirements_contract']) {
    const path = `build/verify_all/producers/${stem}.json`;
    const result = spawnSync(process.execPath, [resolve(`tool/${stem}.mjs`), `--report=${path}`], { cwd, encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(JSON.parse(result.stdout), JSON.parse(readFileSync(join(cwd, path))));
  }
});

test('report interface refuses arbitrary/private paths and symlink escapes', (t) => {
  const cwd = mkdtempSync(join(tmpdir(), 'parkinsum-fhir-output-'));
  const elsewhere = mkdtempSync(join(tmpdir(), 'parkinsum-fhir-elsewhere-'));
  t.after(() => { rmSync(cwd, { recursive: true, force: true }); rmSync(elsewhere, { recursive: true, force: true }); });
  const helper = pathToFileURL(resolve('tool/fhir_contract_report_output.mjs')).href;
  for (const path of ['../private.json', '/tmp/private.json', 'build/private.json']) {
    const result = spawnSync(process.execPath, ['--input-type=module', '-e', `import{emitContractReport}from${JSON.stringify(helper)};emitContractReport({},[${JSON.stringify(`--report=${path}`)}]);`], { cwd, encoding: 'utf8' });
    assert.notEqual(result.status, 0);
  }
  mkdirSync(join(cwd, 'build/verify_all'), { recursive: true });
  symlinkSync(elsewhere, join(cwd, 'build/verify_all/producers'));
  const result = spawnSync(process.execPath, [resolve('tool/fhir_r5_cpg_apply_contract.mjs'), '--report=build/verify_all/producers/fixture.json'], { cwd, encoding: 'utf8' });
  assert.notEqual(result.status, 0);
});
