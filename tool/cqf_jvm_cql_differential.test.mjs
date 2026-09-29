import assert from 'node:assert/strict';
import test from 'node:test';

import {
  assertCqfJvmLockfile,
  encodeCqfJvmCases,
  encodeCqfJvmFhirCases,
  parseCqfJvmOutput,
} from './cqf_jvm_cql_differential.mjs';

const cases = [
  { id: 'dose_true', cql: '250 >= 200' },
  { id: 'dose_unknown', cql: 'null >= 200' },
];

const fhirCorpus = {
  schemaVersion: 2,
  scope: 'synthetic-fhir-r4-retrieval',
  fhirVersion: '4.0.1',
  context: 'Patient',
  expression: 'exists([Condition])',
  cases: [
    {
      id: 'condition_present',
      patientContextId: 'synthetic-patient-present',
      expectedCql: 'true',
      expectedResponseErrors: [],
      expectedResponseWarnings: [],
      bundle: {
        resourceType: 'Bundle',
        type: 'collection',
        entry: [
          { resource: { resourceType: 'Patient', id: 'synthetic-patient-present' } },
          {
            resource: {
              resourceType: 'Condition',
              id: 'synthetic-condition-present',
              subject: { reference: 'Patient/synthetic-patient-present' },
              code: {
                coding: [{
                  system: 'urn:parkinsum:synthetic-test',
                  code: 'condition-placeholder',
                  display: 'Synthetic test-only placeholder',
                }],
              },
            },
          },
        ],
      },
    },
    {
      id: 'condition_absent',
      patientContextId: 'synthetic-patient-empty',
      expectedCql: 'false',
      expectedResponseErrors: [],
      expectedResponseWarnings: ['criterion_not_met'],
      bundle: {
        resourceType: 'Bundle',
        type: 'collection',
        entry: [{ resource: { resourceType: 'Patient', id: 'synthetic-patient-empty' } }],
      },
    },
    {
      id: 'condition_foreign_patient',
      patientContextId: 'synthetic-patient-empty',
      expectedCql: 'false',
      expectedResponseErrors: [],
      expectedResponseWarnings: ['criterion_not_met'],
      bundle: {
        resourceType: 'Bundle',
        type: 'collection',
        entry: [
          { resource: { resourceType: 'Patient', id: 'synthetic-patient-empty' } },
          {
            resource: {
              resourceType: 'Condition',
              id: 'synthetic-condition-foreign',
              subject: { reference: 'Patient/synthetic-patient-other' },
              code: {
                coding: [{
                  system: 'urn:parkinsum:synthetic-test',
                  code: 'condition-placeholder',
                  display: 'Synthetic test-only placeholder',
                }],
              },
            },
          },
        ],
      },
    },
  ],
};

const encoded = (value) => Buffer.from(value, 'utf8').toString('base64');

test('CQF JVM input uses a bounded base64 line protocol', () => {
  assert.equal(
    encodeCqfJvmCases(cases),
    `${encoded('dose_true')}\t${encoded('250 >= 200')}\n`
      + `${encoded('dose_unknown')}\t${encoded('null >= 200')}\n`,
  );
  assert.throws(() => encodeCqfJvmCases([{ id: 'duplicate', cql: 'true' }, { id: 'duplicate', cql: 'false' }]), /unique/);
  assert.throws(() => encodeCqfJvmCases([{ id: 'bad-id!', cql: 'true' }]), /identifiers/);
  assert.throws(() => encodeCqfJvmCases([{ id: 'line_break', cql: 'true\nfalse' }]), /invalid/);
});

test('CQF JVM FHIR input is restricted to three exact synthetic patient-context cases', () => {
  const patientPresent = JSON.stringify({ resourceType: 'Patient', id: 'synthetic-patient-present' });
  const conditionPresent = JSON.stringify(fhirCorpus.cases[0].bundle.entry[1].resource);
  const patientAbsent = JSON.stringify({ resourceType: 'Patient', id: 'synthetic-patient-empty' });
  const conditionForeign = JSON.stringify(fhirCorpus.cases[2].bundle.entry[1].resource);
  assert.equal(
    encodeCqfJvmFhirCases(fhirCorpus),
    `${encoded('condition_present')}\t${encoded('synthetic-patient-present')}\t${encoded(patientPresent)}\t${encoded(conditionPresent)}\n`
      + `${encoded('condition_absent')}\t${encoded('synthetic-patient-empty')}\t${encoded(patientAbsent)}\t-\n`
      + `${encoded('condition_foreign_patient')}\t${encoded('synthetic-patient-empty')}\t${encoded(patientAbsent)}\t${encoded(conditionForeign)}\n`,
  );
  const extra = structuredClone(fhirCorpus);
  extra.cases[0].bundle.entry[1].resource.note = 'outside fixed fixture';
  assert.throws(() => encodeCqfJvmFhirCases(extra), /fixed synthetic bundles/);
  const changedOutcome = structuredClone(fhirCorpus);
  changedOutcome.cases[1].expectedCql = 'unknown';
  assert.throws(() => encodeCqfJvmFhirCases(changedOutcome), /fixed corpus expectation/);
  const changedContext = structuredClone(fhirCorpus);
  changedContext.cases[2].patientContextId = 'synthetic-patient-other';
  assert.throws(() => encodeCqfJvmFhirCases(changedContext), /fixed corpus expectation/);
});

test('CQF JVM output preserves three-valued outcomes and response diagnostics', () => {
  const stdout = [
    'Gradle task output',
    `PARKINSUM_CQF_JVM_RESULT\t${encoded('dose_true')}\ttrue\t-\t-`,
    `PARKINSUM_CQF_JVM_RESULT\t${encoded('dose_unknown')}\tunknown\t${encoded('evaluation_indeterminate')}\t-`,
  ].join('\n');
  assert.deepEqual([...parseCqfJvmOutput(stdout, cases).values()], [
    { id: 'dose_true', result: 'true', errors: [], warnings: [] },
    { id: 'dose_unknown', result: 'unknown', errors: ['evaluation_indeterminate'], warnings: [] },
  ]);
});

test('CQF JVM output rejects missing, duplicated, unexpected, or malformed rows', () => {
  const good = `PARKINSUM_CQF_JVM_RESULT\t${encoded('dose_true')}\ttrue\t-\t-`;
  assert.throws(() => parseCqfJvmOutput(good, cases), /returned 1 rows/);
  assert.throws(
    () => parseCqfJvmOutput(`${good}\n${good}`, cases),
    /unexpected or duplicate/,
  );
  assert.throws(
    () => parseCqfJvmOutput(`PARKINSUM_CQF_JVM_RESULT\t${encoded('other')}\ttrue\t-\t-`, cases),
    /unexpected or duplicate/,
  );
  assert.throws(
	() => parseCqfJvmOutput(`PARKINSUM_CQF_JVM_RESULT\t${encoded('dose_true')}\tfalse\t!\t-`, cases),
    /canonical base64/,
  );
  assert.throws(
    () => parseCqfJvmOutput(`PARKINSUM_CQF_JVM_RESULT\t${encoded('dose_true')}\tfalse\t-\t-`, cases),
    /returned 1 rows/,
  );
});

test('CQF JVM lockfile binds the CQL and FHIR 5.3.0 modules and logger backend', () => {
  const lock = [
    'org.cqframework:engine:5.3.0=runtimeClasspath',
    'org.cqframework:engine-fhir:5.3.0=runtimeClasspath',
    'org.cqframework:engine-fhir-jvm:5.3.0=runtimeClasspath',
    'org.cqframework:engine-jvm:5.3.0=runtimeClasspath',
    'org.cqframework:quick:5.3.0=runtimeClasspath',
    'org.cqframework:cql-to-elm-jvm:5.3.0=runtimeClasspath',
    'org.slf4j:slf4j-nop:2.0.13=runtimeClasspath',
  ].join('\n');
  assert.equal(assertCqfJvmLockfile(lock).length, 7);
  assert.throws(() => assertCqfJvmLockfile(lock.replace('engine-jvm:5.3.0', 'engine-jvm:5.2.0')), /missing pinned/);
});
