import assert from 'node:assert/strict';
import {test} from 'node:test';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {inspectRequiredJobResults, REQUIRED_JOB_IDS} from './ci_required_status_gate.mjs';

const independentlyRequired = ['quick-checks', 'flutter', 'node-preflight', 'governance-gates'];
const passing = () => Object.fromEntries(independentlyRequired.map(id => [id, {result: 'success', outputs: {}}]));

test('protected preflight requires every declared prerequisite, including quick checks', () => {
  assert.deepEqual([...REQUIRED_JOB_IDS], independentlyRequired);
  assert.deepEqual(inspectRequiredJobResults(passing()), {pass: true, errors: []});
});

test('all 2401 success/failure/cancellation/skip/neutral/action/timeout combinations fail closed', () => {
  const outcomes = ['success', 'failure', 'cancelled', 'skipped', 'neutral', 'action_required', 'timed_out'];
  let accepted = 0;
  for (const a of outcomes) for (const b of outcomes) for (const c of outcomes) for (const d of outcomes) {
    const states = [a, b, c, d];
    const needs = Object.fromEntries(independentlyRequired.map((id, i) => [id, {result: states[i]}]));
    const result = inspectRequiredJobResults(needs);
    const expected = states.every(state => state === 'success');
    assert.equal(result.pass, expected, JSON.stringify(needs));
    accepted += Number(result.pass);
  }
  assert.equal(accepted, 1);
});

test('missing, malformed, inherited, unknown or additional jobs cannot satisfy protection', () => {
  for (const value of [null, [], true, 'success', 1, {}]) assert.equal(inspectRequiredJobResults(value).pass, false);
  for (const id of independentlyRequired) {
    for (const value of [null, [], 'success', true, {}, {result: 'SUCCESS'}, {result: 1}]) {
      const needs = passing();
      needs[id] = value;
      assert.equal(inspectRequiredJobResults(needs).pass, false);
    }
    const missing = passing();
    delete missing[id];
    assert.equal(inspectRequiredJobResults(missing).pass, false);
    const inherited = Object.assign(Object.create({[id]: {result: 'success'}}), missing);
    assert.equal(inspectRequiredJobResults(inherited).pass, false);
  }
  assert.equal(inspectRequiredJobResults({...passing(), future: {result: 'success'}}).pass, false);
});

test('actual CLI rejects absent, corrupt and failed results and accepts complete success', () => {
  const path = fileURLToPath(new URL('./ci_required_status_gate.mjs', import.meta.url));
  for (const [raw, expected] of [[undefined, 1], ['', 1], ['{', 1], ['[]', 1], [JSON.stringify({...passing(), flutter: {result: 'cancelled'}}), 1], [JSON.stringify(passing()), 0]]) {
    const env = {...process.env};
    delete env.PARKINSUM_CI_JOB_RESULTS;
    if (raw !== undefined) env.PARKINSUM_CI_JOB_RESULTS = raw;
    const result = spawnSync(process.execPath, [path], {env, encoding: 'utf8'});
    assert.equal(result.error, undefined);
    assert.equal(result.status, expected, `${raw}: ${result.stderr}`);
  }
});
