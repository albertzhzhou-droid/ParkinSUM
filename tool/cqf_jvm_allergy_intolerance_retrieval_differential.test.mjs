import test from 'node:test';
import assert from 'node:assert/strict';

import corpus from '../test/fixtures/cql_fhir_r4_allergy_intolerance_retrieval_corpus.json' with { type: 'json' };
import {
  encodeCqfJvmAllergyIntoleranceCases,
  parseCqfJvmAllergyIntoleranceOutput,
} from './cqf_jvm_allergy_intolerance_retrieval_differential.mjs';
import { allergyIntoleranceOutcomeKeys } from './cql_fhir_allergy_intolerance_retrieval_contract.mjs';

const prefix = 'PARKINSUM_CQF_JVM_ALLERGY_INTOLERANCE_RESULT';
const ids = corpus.cases.map((testCase) => testCase.id);

test('encodes only the six fixed Patient and AllergyIntolerance placeholders', () => {
  const encoded = encodeCqfJvmAllergyIntoleranceCases(corpus);
  const lines = encoded.trimEnd().split('\n');
  assert.equal(lines.length, 6);
  assert.doesNotMatch(encoded, /synthetic-patient-/);
  for (const [index, line] of lines.entries()) {
    const [encodedId, encodedContext, encodedPatient, encodedAllergy] = line.split('\t');
    assert.equal(Buffer.from(encodedId, 'base64').toString(), ids[index]);
    assert.match(Buffer.from(encodedContext, 'base64').toString(), /^synthetic-patient-/);
    assert.equal(JSON.parse(Buffer.from(encodedPatient, 'base64').toString()).resourceType, 'Patient');
    if (encodedAllergy !== '-') {
      const allergy = JSON.parse(Buffer.from(encodedAllergy, 'base64').toString());
      assert.equal(allergy.resourceType, 'AllergyIntolerance');
      assert.ok(allergy.verificationStatus.coding[0].code);
      assert.ok(allergy.patient.reference.startsWith('Patient/'));
    }
  }
  assert.throws(() => encodeCqfJvmAllergyIntoleranceCases({ ...corpus, fhirVersion: '5.0.0' }));
});

test('parses exactly six JVM outcomes and foreign-subject drop evidence', () => {
  const stdout = corpus.cases.map((testCase) => {
    const outcomes = allergyIntoleranceOutcomeKeys.map((key) => String(testCase.expectedOutcomes[key])).join('\t');
    const dropped = testCase.id === 'foreign_subject_allergy_intolerance' ? 1 : 0;
    return `${prefix}\t${Buffer.from(testCase.id).toString('base64')}\t${dropped}\t${outcomes}`;
  }).join('\n');
  const rows = parseCqfJvmAllergyIntoleranceOutput(stdout);
  assert.equal(rows.size, 6);
  assert.deepEqual(rows.get('clinical_active_unconfirmed').outcomes, corpus.cases[0].expectedOutcomes);
  assert.equal(rows.get('verification_entered_in_error').outcomes.hasClinicalStatusActive, false);
  assert.equal(rows.get('foreign_subject_allergy_intolerance').foreignAllergyIntolerancesDropped, 1);
  assert.throws(() => parseCqfJvmAllergyIntoleranceOutput(`${stdout}\n${stdout.split('\n')[0]}`), /duplicate/);
  assert.throws(() => parseCqfJvmAllergyIntoleranceOutput(stdout.split('\n').slice(1).join('\n')), /6 fixed cases/);
  assert.throws(() => parseCqfJvmAllergyIntoleranceOutput(stdout.replace('\t1\t', '\t2\t')), /foreign-subject count/);
});
