import assert from 'node:assert/strict';
import test from 'node:test';

import fixture from '../test/fixtures/cql_fhir_r4_encounter_status_retrieval_corpus.json' with { type: 'json' };
import {
  encounterStatuses,
  fixedEncounterStatusCorpus,
  scopeEncounterStatusBundle,
  validateEncounterStatusCorpus,
} from './cql_fhir_encounter_retrieval_contract.mjs';
import { runEncounterStatusRetrievalDifferential } from './cql_fhir_encounter_retrieval.mjs';

test('fixed Encounter corpus covers every R4 status, absence, and one foreign subject', () => {
  assert.equal(validateEncounterStatusCorpus(fixture), fixture);
  assert.deepEqual(fixture, fixedEncounterStatusCorpus);
  assert.equal(fixture.cases.length, 11);
  const observed = fixture.cases
    .filter((testCase) => testCase.id.startsWith('status_'))
    .map((testCase) => testCase.bundle.entry[1].resource.status);
  assert.deepEqual(observed, encounterStatuses);
  assert.equal(fixture.cases.find((testCase) => testCase.id === 'no_encounter').bundle.entry.length, 1);
  assert.equal(fixture.cases.find((testCase) => testCase.id === 'foreign_subject_encounter')
    .expectedOutcomes.hasAnyEncounter, false);

  const drift = structuredClone(fixture);
  drift.cases[0].bundle.entry[1].resource.status = 'active';
  assert.throws(() => validateEncounterStatusCorpus(drift), /fixed synthetic FHIR Encounter status corpus/);
});

test('Encounter Patient scoping retains only the matching synthetic subject', () => {
  const matching = scopeEncounterStatusBundle(fixture.cases[0].bundle, fixture.cases[0].patientContextId);
  assert.equal(matching.foreignEncountersDropped, 0);
  assert.equal(matching.bundle.entry.length, 2);

  const absent = fixture.cases.find((testCase) => testCase.id === 'no_encounter');
  assert.equal(scopeEncounterStatusBundle(absent.bundle, absent.patientContextId).bundle.entry.length, 1);

  const foreignCase = fixture.cases.find((testCase) => testCase.id === 'foreign_subject_encounter');
  const foreign = scopeEncounterStatusBundle(foreignCase.bundle, foreignCase.patientContextId);
  assert.equal(foreign.foreignEncountersDropped, 1);
  assert.deepEqual(foreign.bundle.entry, [foreignCase.bundle.entry[0]]);
  const drift = structuredClone(foreignCase.bundle);
  drift.meta = { source: 'outside fixed fixture' };
  assert.throws(() => scopeEncounterStatusBundle(drift, foreignCase.patientContextId),
    /fixed_synthetic_r4_contract/);
});

test('pinned JavaScript CQL path matches all eleven Encounter status cases', async () => {
  const report = await runEncounterStatusRetrievalDifferential();
  assert.equal(report.caseCount, 11);
  assert.equal(report.outcomeParityCount, 11);
  assert.deepEqual(report.cases.map((row) => row.outcomes), fixture.cases.map((row) => row.expectedOutcomes));
  assert.equal(report.cases.at(-1).foreignEncountersDropped, 1);
  assert.equal(report.networkRequestMade, false);
  assert.equal(report.realPatientDataUsed, false);
  assert.doesNotMatch(JSON.stringify(report), /synthetic-patient-|synthetic-encounter-/);
});
