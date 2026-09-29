import test from 'node:test';
import assert from 'node:assert/strict';

import corpus from '../test/fixtures/cql_fhir_r4_medication_statement_retrieval_corpus.json' with { type: 'json' };
import {
  encodeCqfJvmMedicationStatementCases,
  parseCqfJvmMedicationStatementOutput,
} from './cqf_jvm_medication_statement_retrieval_differential.mjs';

const prefix = 'PARKINSUM_CQF_JVM_MEDICATION_STATEMENT_RESULT';
const ids = corpus.cases.map((testCase) => testCase.id);

test('encodes only the ten fixed Patient and MedicationStatement placeholders', () => {
  const lines = encodeCqfJvmMedicationStatementCases(corpus).trimEnd().split('\n');
  assert.equal(lines.length, 10);
  for (const [index, line] of lines.entries()) {
    const [encodedId, encodedContext, encodedPatient, encodedStatement] = line.split('\t');
    assert.equal(Buffer.from(encodedId, 'base64').toString(), ids[index]);
    assert.match(Buffer.from(encodedContext, 'base64').toString(), /^synthetic-patient-/);
    assert.equal(JSON.parse(Buffer.from(encodedPatient, 'base64').toString()).resourceType, 'Patient');
    if (encodedStatement !== '-') {
      assert.equal(JSON.parse(Buffer.from(encodedStatement, 'base64').toString()).resourceType, 'MedicationStatement');
    }
  }
  assert.throws(() => encodeCqfJvmMedicationStatementCases({ ...corpus, fhirVersion: '5.0.0' }));
});

test('parses exactly ten fixed JVM outcome rows', () => {
  const stdout = corpus.cases.map((testCase) => {
    const outcomes = Object.values(testCase.expectedOutcomes).map(String).join('\t');
    return `${prefix}\t${Buffer.from(testCase.id).toString('base64')}\t${outcomes}`;
  }).join('\n');
  const rows = parseCqfJvmMedicationStatementOutput(stdout);
  assert.equal(rows.size, 10);
  assert.deepEqual(rows.get('active_statement').outcomes, corpus.cases[0].expectedOutcomes);
  assert.throws(() => parseCqfJvmMedicationStatementOutput(`${stdout}\n${stdout.split('\n')[0]}`), /duplicate/);
  assert.throws(() => parseCqfJvmMedicationStatementOutput(stdout.split('\n').slice(1).join('\n')), /10 fixed cases/);
});
