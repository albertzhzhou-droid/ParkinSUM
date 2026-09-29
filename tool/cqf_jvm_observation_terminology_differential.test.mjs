import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import corpus from '../test/fixtures/cql_fhir_r4_observation_retrieval_corpus.json' with { type: 'json' };
import {
  encodeCqfJvmObservationCases,
  parseCqfJvmObservationOutput,
  runCqfJvmObservationTerminologyDifferential,
} from './cqf_jvm_observation_terminology_differential.mjs';
import { assertCqfJvmLockfile } from './cqf_jvm_cql_differential.mjs';

const expectedIds = [
  'observation_present',
  'observation_absent',
  'observation_foreign_subject',
  'observation_non_member_code',
  'observation_foreign_code_system',
  'observation_system_version_mismatch',
];
const encode = (value) => Buffer.from(value, 'utf8').toString('base64');

test('CQF JVM Observation input is exactly the six fixed synthetic FHIR bundles', () => {
  const rows = encodeCqfJvmObservationCases(corpus).trimEnd().split('\n');
  assert.equal(rows.length, 6);
  assert.deepEqual(rows.map((row) => Buffer.from(row.split('\t')[0], 'base64').toString('utf8')), expectedIds);
  assert.equal(rows[1].endsWith('\t-'), true);
  assert.equal(rows[2].endsWith('\t-'), false);
  const drifted = structuredClone(corpus);
  drifted.cases[0].bundle.entry[1].resource.id = 'synthetic-other';
  assert.throws(() => encodeCqfJvmObservationCases(drifted), /fixed synthetic FHIR Observation corpus/);
});

test('CQF JVM Observation output requires one bounded result for every fixed case', () => {
  const lines = expectedIds.map((id, index) => [
    'PARKINSUM_CQF_JVM_OBSERVATION_RESULT',
    encode(id),
    index === 0 || index >= 3 ? 'true' : 'false',
    index === 0 ? 'true' : 'false',
    index === 0 ? 'true' : 'false',
  ].join('\t')).join('\n');
  assert.equal(parseCqfJvmObservationOutput(lines).size, 6);
  assert.throws(() => parseCqfJvmObservationOutput(`${lines}\n${lines.split('\n')[0]}`), /duplicate case/);
  assert.throws(() => parseCqfJvmObservationOutput(lines.split('\n').slice(1).join('\n')), /returned 5 rows/);
  assert.throws(() => parseCqfJvmObservationOutput(lines.replace('\ttrue\ttrue\ttrue', '\tmaybe\ttrue\ttrue')), /invalid outcome/);
});

test('CQF JVM dependencies remain pinned in the local lockfile', () => {
  const lock = readFileSync(new URL('./cqf_jvm_cql_differential/gradle.lockfile', import.meta.url), 'utf8');
  assert.ok(assertCqfJvmLockfile(lock).includes('org.cqframework:engine:5.3.0'));
});

test('cross-runtime report cannot omit the JavaScript baseline', () => {
  assert.throws(
    () => runCqfJvmObservationTerminologyDifferential('.', corpus),
    /requires the pinned JavaScript Observation report/,
  );
});
