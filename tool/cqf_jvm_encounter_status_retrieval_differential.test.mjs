import assert from 'node:assert/strict';
import test from 'node:test';

import corpus from '../test/fixtures/cql_fhir_r4_encounter_status_retrieval_corpus.json' with { type: 'json' };
import { encounterStatusOutcomeKeys } from './cql_fhir_encounter_retrieval_contract.mjs';
import {
  encodeCqfJvmEncounterStatusCases,
  parseCqfJvmEncounterStatusOutput,
} from './cqf_jvm_encounter_status_retrieval_differential.mjs';

const prefix = 'PARKINSUM_CQF_JVM_ENCOUNTER_STATUS_RESULT';

test('encodes only the eleven fixed Patient and Encounter placeholder pairs', () => {
  const encoded = encodeCqfJvmEncounterStatusCases(corpus);
  const lines = encoded.trimEnd().split('\n');
  assert.equal(lines.length, 11);
  assert.doesNotMatch(encoded, /synthetic-patient-/);
  for (const [index, line] of lines.entries()) {
    const [id, context, patient, encounter] = line.split('\t');
    assert.equal(Buffer.from(id, 'base64').toString(), corpus.cases[index].id);
    assert.match(Buffer.from(context, 'base64').toString(), /^synthetic-patient-/);
    assert.equal(JSON.parse(Buffer.from(patient, 'base64').toString()).resourceType, 'Patient');
    if (encounter !== '-') {
      const resource = JSON.parse(Buffer.from(encounter, 'base64').toString());
      assert.equal(resource.resourceType, 'Encounter');
      assert.ok(resource.status);
    }
  }
  assert.throws(() => encodeCqfJvmEncounterStatusCases({ ...corpus, fhirVersion: '5.0.0' }));
});

test('parses exactly eleven JVM status outcomes and foreign-subject drop evidence', () => {
  const stdout = corpus.cases.map((testCase) => {
    const outcomes = encounterStatusOutcomeKeys
      .map((key) => String(testCase.expectedOutcomes[key])).join('\t');
    const dropped = testCase.id === 'foreign_subject_encounter' ? 1 : 0;
    return `${prefix}\t${Buffer.from(testCase.id).toString('base64')}\t${dropped}\t${outcomes}`;
  }).join('\n');
  const rows = parseCqfJvmEncounterStatusOutput(stdout);
  assert.equal(rows.size, 11);
  assert.deepEqual(rows.get('status_in_progress').outcomes, corpus.cases[3].expectedOutcomes);
  assert.equal(rows.get('status_entered_in_error').outcomes.hasStatusEnteredInError, true);
  assert.equal(rows.get('status_entered_in_error').outcomes.hasStatusInProgress, false);
  assert.equal(rows.get('foreign_subject_encounter').foreignEncountersDropped, 1);
  assert.throws(() => parseCqfJvmEncounterStatusOutput(`${stdout}\n${stdout.split('\n')[0]}`), /duplicate/);
  assert.throws(() => parseCqfJvmEncounterStatusOutput(stdout.split('\n').slice(1).join('\n')), /11 fixed cases/);
  assert.throws(() => parseCqfJvmEncounterStatusOutput(stdout.replace('\t1\t', '\t2\t')), /foreign-subject count/);
});
