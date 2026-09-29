import test from 'node:test';
import assert from 'node:assert/strict';

import corpus from '../test/fixtures/cql_fhir_r4_medication_dispense_retrieval_corpus.json' with { type: 'json' };
import {
  encodeCqfJvmMedicationDispenseCases,
  parseCqfJvmMedicationDispenseOutput,
} from './cqf_jvm_medication_dispense_retrieval_differential.mjs';
import { medicationDispenseOutcomeKeys } from './cql_fhir_medication_dispense_retrieval_contract.mjs';

const prefix = 'PARKINSUM_CQF_JVM_MEDICATION_DISPENSE_RESULT';
const ids = corpus.cases.map((testCase) => testCase.id);

test('encodes only the 11 fixed Patient and MedicationDispense placeholders', () => {
  const encoded = encodeCqfJvmMedicationDispenseCases(corpus);
  const lines = encoded.trimEnd().split('\n');
  assert.equal(lines.length, 11);
  assert.doesNotMatch(encoded, /Synthetic medication placeholder|synthetic-patient-/);
  for (const [index, line] of lines.entries()) {
    const [encodedId, encodedContext, encodedPatient, encodedDispense] = line.split('\t');
    assert.equal(Buffer.from(encodedId, 'base64').toString(), ids[index]);
    assert.match(Buffer.from(encodedContext, 'base64').toString(), /^synthetic-patient-/);
    assert.equal(JSON.parse(Buffer.from(encodedPatient, 'base64').toString()).resourceType, 'Patient');
    if (encodedDispense !== '-') {
      const dispense = JSON.parse(Buffer.from(encodedDispense, 'base64').toString());
      assert.equal(dispense.resourceType, 'MedicationDispense');
      assert.ok(dispense.status);
      assert.ok(dispense.subject.reference.startsWith('Patient/'));
    }
  }
  assert.throws(() => encodeCqfJvmMedicationDispenseCases({ ...corpus, fhirVersion: '5.0.0' }));
});

test('parses exactly 11 fixed JVM outcomes and foreign-subject drop evidence', () => {
  const stdout = corpus.cases.map((testCase) => {
    const outcomes = medicationDispenseOutcomeKeys.map((key) => String(testCase.expectedOutcomes[key])).join('\t');
    const dropped = testCase.id === 'foreign_subject_dispense' ? 1 : 0;
    return `${prefix}\t${Buffer.from(testCase.id).toString('base64')}\t${dropped}\t${outcomes}`;
  }).join('\n');
  const rows = parseCqfJvmMedicationDispenseOutput(stdout);
  assert.equal(rows.size, 11);
  assert.deepEqual(rows.get('status_preparation_dispense').outcomes, corpus.cases[0].expectedOutcomes);
  assert.equal(rows.get('foreign_subject_dispense').foreignDispensesDropped, 1);
  assert.throws(() => parseCqfJvmMedicationDispenseOutput(`${stdout}\n${stdout.split('\n')[0]}`), /duplicate/);
  assert.throws(() => parseCqfJvmMedicationDispenseOutput(stdout.split('\n').slice(1).join('\n')), /11 fixed cases/);
  assert.throws(() => parseCqfJvmMedicationDispenseOutput(stdout.replace('\t1\t', '\t2\t')), /foreign-subject count/);
});
