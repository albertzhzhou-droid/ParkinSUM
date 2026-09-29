import assert from 'node:assert/strict';
import test from 'node:test';

import fixture from '../test/fixtures/cql_fhir_r4_condition_status_retrieval_corpus.json' with { type: 'json' };
import {
  conditionClinicalStatuses,
  conditionVerificationStatuses,
  fixedConditionStatusCorpus,
  scopeConditionStatusBundle,
  validateConditionStatusCorpus,
} from './cql_fhir_condition_status_retrieval_contract.mjs';
import { runConditionStatusRetrievalDifferential } from './cql_fhir_condition_status_retrieval.mjs';

test('fixed Condition corpus covers both six-code R4 bindings and the entered-in-error invariant', () => {
  assert.equal(validateConditionStatusCorpus(fixture), fixture);
  assert.deepEqual(fixture, fixedConditionStatusCorpus);
  assert.deepEqual(conditionClinicalStatuses, ['active', 'recurrence', 'relapse', 'inactive', 'remission', 'resolved']);
  assert.deepEqual(conditionVerificationStatuses, [
    'unconfirmed', 'provisional', 'differential', 'confirmed', 'refuted', 'entered-in-error',
  ]);
  assert.equal(fixture.cases.length, 9);
  const clinical = new Set(fixture.cases.map((testCase) =>
    testCase.bundle.entry[1]?.resource.clinicalStatus?.coding[0].code).filter(Boolean));
  const verification = new Set(fixture.cases.map((testCase) =>
    testCase.bundle.entry[1]?.resource.verificationStatus?.coding[0].code).filter(Boolean));
  assert.deepEqual([...clinical], conditionClinicalStatuses);
  assert.deepEqual([...verification], conditionVerificationStatuses);

  const enteredInError = fixture.cases.find((testCase) => testCase.id === 'verification_entered_in_error');
  assert.equal(Object.hasOwn(enteredInError.bundle.entry[1].resource, 'clinicalStatus'), false);
  const drift = structuredClone(fixture);
  drift.cases[0].bundle.entry[1].resource.clinicalStatus.coding[0].system = 'http://snomed.info/sct';
  assert.throws(() => validateConditionStatusCorpus(drift), /fixed synthetic FHIR Condition status corpus/);
});

test('Condition Patient scoping retains matching resources and filters the foreign synthetic subject', () => {
  const matching = scopeConditionStatusBundle(fixture.cases[0].bundle, fixture.cases[0].patientContextId);
  assert.equal(matching.foreignConditionsDropped, 0);
  assert.equal(matching.bundle.entry.length, 2);
  const absent = fixture.cases.find((testCase) => testCase.id === 'no_condition');
  assert.equal(scopeConditionStatusBundle(absent.bundle, absent.patientContextId).bundle.entry.length, 1);
  const foreignCase = fixture.cases.at(-1);
  const foreign = scopeConditionStatusBundle(foreignCase.bundle, foreignCase.patientContextId);
  assert.equal(foreign.foreignConditionsDropped, 1);
  assert.deepEqual(foreign.bundle.entry, [foreignCase.bundle.entry[0]]);
  const drift = structuredClone(foreignCase.bundle);
  drift.meta = { source: 'outside fixed fixture' };
  assert.throws(
    () => scopeConditionStatusBundle(drift, foreignCase.patientContextId),
    /fixed_synthetic_r4_contract/,
  );
});

test('pinned JavaScript CQL path matches all nine Condition status cases', async () => {
  const report = await runConditionStatusRetrievalDifferential();
  assert.equal(report.caseCount, 9);
  assert.equal(report.outcomeParityCount, 9);
  assert.deepEqual(report.cases.map((row) => row.outcomes), fixture.cases.map((row) => row.expectedOutcomes));
  assert.equal(report.cases.at(-1).foreignConditionsDropped, 1);
  assert.equal(report.networkRequestMade, false);
  assert.equal(report.realPatientDataUsed, false);
  const text = JSON.stringify(report);
  assert.doesNotMatch(text, /synthetic-patient-|synthetic-condition-|condition-clinical|condition-ver-status/);
  assert.doesNotMatch(text, /"resourceType"|"reference"/);
});
