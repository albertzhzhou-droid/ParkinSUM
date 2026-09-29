import test from 'node:test';
import assert from 'node:assert/strict';

import corpus from '../test/fixtures/cql_fhir_r4_medication_administration_retrieval_corpus.json' with { type: 'json' };
import {
  encodeCqfJvmMedicationAdministrationCases,
  parseCqfJvmMedicationAdministrationOutput,
} from './cqf_jvm_medication_administration_retrieval_differential.mjs';
import { medicationAdministrationOutcomeKeys } from './cql_fhir_medication_administration_retrieval_contract.mjs';

const prefix = 'PARKINSUM_CQF_JVM_MEDICATION_ADMINISTRATION_RESULT';
const ids = corpus.cases.map((testCase) => testCase.id);

test('encodes only the nine fixed Patient and MedicationAdministration placeholders', () => {
  const encoded = encodeCqfJvmMedicationAdministrationCases(corpus);
  const lines = encoded.trimEnd().split('\n');
  assert.equal(lines.length, 9);
  assert.doesNotMatch(encoded, /Synthetic medication placeholder|synthetic-patient-/);
  for (const [index, line] of lines.entries()) {
    const [encodedId, encodedContext, encodedPatient, encodedAdministration] = line.split('\t');
    assert.equal(Buffer.from(encodedId, 'base64').toString(), ids[index]);
    assert.match(Buffer.from(encodedContext, 'base64').toString(), /^synthetic-patient-/);
    assert.equal(JSON.parse(Buffer.from(encodedPatient, 'base64').toString()).resourceType, 'Patient');
    if (encodedAdministration !== '-') {
      const administration = JSON.parse(Buffer.from(encodedAdministration, 'base64').toString());
      assert.equal(administration.resourceType, 'MedicationAdministration');
      assert.ok(administration.status);
      assert.ok(administration.subject.reference.startsWith('Patient/'));
    }
  }
  assert.throws(() => encodeCqfJvmMedicationAdministrationCases({ ...corpus, fhirVersion: '5.0.0' }));
});

test('parses exactly nine fixed JVM outcomes and foreign-subject drop evidence', () => {
  const stdout = corpus.cases.map((testCase) => {
    const outcomes = medicationAdministrationOutcomeKeys.map((key) => String(testCase.expectedOutcomes[key])).join('\t');
    const dropped = testCase.id === 'foreign_subject_administration' ? 1 : 0;
    return `${prefix}\t${Buffer.from(testCase.id).toString('base64')}\t${dropped}\t${outcomes}`;
  }).join('\n');
  const rows = parseCqfJvmMedicationAdministrationOutput(stdout);
  assert.equal(rows.size, 9);
  assert.deepEqual(rows.get('status_in_progress_administration').outcomes, corpus.cases[0].expectedOutcomes);
  assert.equal(rows.get('foreign_subject_administration').foreignAdministrationsDropped, 1);
  assert.throws(() => parseCqfJvmMedicationAdministrationOutput(`${stdout}\n${stdout.split('\n')[0]}`), /duplicate/);
  assert.throws(() => parseCqfJvmMedicationAdministrationOutput(stdout.split('\n').slice(1).join('\n')), /9 fixed cases/);
  assert.throws(() => parseCqfJvmMedicationAdministrationOutput(stdout.replace('\t1\t', '\t2\t')), /foreign-subject count/);
});
