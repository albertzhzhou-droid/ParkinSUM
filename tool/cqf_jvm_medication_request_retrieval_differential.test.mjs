import test from 'node:test';
import assert from 'node:assert/strict';

import corpus from '../test/fixtures/cql_fhir_r4_medication_request_retrieval_corpus.json' with { type: 'json' };
import {
  encodeCqfJvmMedicationRequestCases,
  parseCqfJvmMedicationRequestOutput,
} from './cqf_jvm_medication_request_retrieval_differential.mjs';
import { medicationRequestOutcomeKeys } from './cql_fhir_medication_request_retrieval_contract.mjs';

const prefix = 'PARKINSUM_CQF_JVM_MEDICATION_REQUEST_RESULT';
const ids = corpus.cases.map((testCase) => testCase.id);

test('encodes only the 18 fixed Patient and MedicationRequest placeholders', () => {
  const lines = encodeCqfJvmMedicationRequestCases(corpus).trimEnd().split('\n');
  assert.equal(lines.length, 18);
  for (const [index, line] of lines.entries()) {
    const [encodedId, encodedContext, encodedPatient, encodedRequest] = line.split('\t');
    assert.equal(Buffer.from(encodedId, 'base64').toString(), ids[index]);
    assert.match(Buffer.from(encodedContext, 'base64').toString(), /^synthetic-patient-/);
    assert.equal(JSON.parse(Buffer.from(encodedPatient, 'base64').toString()).resourceType, 'Patient');
    if (encodedRequest !== '-') {
      const request = JSON.parse(Buffer.from(encodedRequest, 'base64').toString());
      assert.equal(request.resourceType, 'MedicationRequest');
      assert.ok(request.status);
      assert.ok(request.intent);
    }
  }
  assert.throws(() => encodeCqfJvmMedicationRequestCases({ ...corpus, fhirVersion: '5.0.0' }));
});

test('parses exactly 18 fixed JVM outcome rows and their Patient-drop evidence', () => {
  const stdout = corpus.cases.map((testCase) => {
    const outcomes = medicationRequestOutcomeKeys.map((key) => String(testCase.expectedOutcomes[key])).join('\t');
    const dropped = testCase.id === 'foreign_subject_request' ? 1 : 0;
    return `${prefix}\t${Buffer.from(testCase.id).toString('base64')}\t${dropped}\t${outcomes}`;
  }).join('\n');
  const rows = parseCqfJvmMedicationRequestOutput(stdout);
  assert.equal(rows.size, 18);
  assert.deepEqual(rows.get('status_active_request').outcomes, corpus.cases[0].expectedOutcomes);
  assert.equal(rows.get('foreign_subject_request').foreignRequestsDropped, 1);
  assert.throws(() => parseCqfJvmMedicationRequestOutput(`${stdout}\n${stdout.split('\n')[0]}`), /duplicate/);
  assert.throws(() => parseCqfJvmMedicationRequestOutput(stdout.split('\n').slice(1).join('\n')), /18 fixed cases/);
  assert.throws(() => parseCqfJvmMedicationRequestOutput(stdout.replace('\t1\t', '\t2\t')), /foreign-subject count/);
});
