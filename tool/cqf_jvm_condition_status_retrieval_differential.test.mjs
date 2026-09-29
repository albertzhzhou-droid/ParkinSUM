import assert from 'node:assert/strict';
import test from 'node:test';

import corpus from '../test/fixtures/cql_fhir_r4_condition_status_retrieval_corpus.json' with { type: 'json' };
import { conditionStatusOutcomeKeys } from './cql_fhir_condition_status_retrieval_contract.mjs';
import {
  encodeCqfJvmConditionStatusCases,
  parseCqfJvmConditionStatusOutput,
} from './cqf_jvm_condition_status_retrieval_differential.mjs';

const prefix = 'PARKINSUM_CQF_JVM_CONDITION_STATUS_RESULT';

test('encodes only nine fixed Patient and Condition placeholder pairs', () => {
  const encoded = encodeCqfJvmConditionStatusCases(corpus);
  const lines = encoded.trimEnd().split('\n');
  assert.equal(lines.length, 9);
  assert.doesNotMatch(encoded, /synthetic-patient-/);
  for (const [index, line] of lines.entries()) {
    const [id, context, patient, condition] = line.split('\t');
    assert.equal(Buffer.from(id, 'base64').toString(), corpus.cases[index].id);
    assert.match(Buffer.from(context, 'base64').toString(), /^synthetic-patient-/);
    assert.equal(JSON.parse(Buffer.from(patient, 'base64').toString()).resourceType, 'Patient');
    if (condition !== '-') {
      const resource = JSON.parse(Buffer.from(condition, 'base64').toString());
      assert.equal(resource.resourceType, 'Condition');
      assert.ok(resource.verificationStatus.coding[0].code);
      if (resource.verificationStatus.coding[0].code === 'entered-in-error') assert.equal('clinicalStatus' in resource, false);
    }
  }
  assert.throws(() => encodeCqfJvmConditionStatusCases({ ...corpus, fhirVersion: '5.0.0' }));
});

test('parses exactly nine JVM status outcomes and foreign-subject drop evidence', () => {
  const stdout = corpus.cases.map((testCase) => {
    const outcomes = conditionStatusOutcomeKeys.map((key) => String(testCase.expectedOutcomes[key])).join('\t');
    const dropped = testCase.id === 'foreign_subject_condition' ? 1 : 0;
    return `${prefix}\t${Buffer.from(testCase.id).toString('base64')}\t${dropped}\t${outcomes}`;
  }).join('\n');
  const rows = parseCqfJvmConditionStatusOutput(stdout);
  assert.equal(rows.size, 9);
  assert.deepEqual(rows.get('clinical_active_unconfirmed').outcomes, corpus.cases[0].expectedOutcomes);
  assert.equal(rows.get('verification_entered_in_error').outcomes.hasVerificationStatusEnteredInError, true);
  assert.equal(rows.get('verification_entered_in_error').outcomes.hasClinicalStatusActive, false);
  assert.equal(rows.get('foreign_subject_condition').foreignConditionsDropped, 1);
  assert.throws(() => parseCqfJvmConditionStatusOutput(`${stdout}\n${stdout.split('\n')[0]}`), /duplicate/);
  assert.throws(() => parseCqfJvmConditionStatusOutput(stdout.split('\n').slice(1).join('\n')), /9 fixed cases/);
  assert.throws(() => parseCqfJvmConditionStatusOutput(stdout.replace('\t1\t', '\t2\t')), /foreign-subject count/);
});
