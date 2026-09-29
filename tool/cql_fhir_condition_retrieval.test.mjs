import assert from 'node:assert/strict';
import test from 'node:test';

import fixture from '../test/fixtures/cql_fhir_r4_retrieval_corpus.json' with { type: 'json' };
import {
  fixedConditionCorpus,
  scopeConditionBundle,
  validateConditionCorpus,
} from './cql_fhir_condition_retrieval_contract.mjs';
import { runConditionRetrievalDifferential } from './cql_fhir_condition_retrieval.mjs';

test('Condition corpus is the exact three-case synthetic Patient-context fixture', () => {
  assert.equal(validateConditionCorpus(fixture), fixture);
  assert.deepEqual(fixture, fixedConditionCorpus);
  assert.equal(fixture.schemaVersion, 2);
  assert.equal(fixture.fhirVersion, '4.0.1');
  assert.equal(fixture.context, 'Patient');
  assert.deepEqual(fixture.cases.map(({ id }) => id), [
    'condition_present',
    'condition_absent',
    'condition_foreign_patient',
  ]);

  const mutated = structuredClone(fixture);
  mutated.cases[0].bundle.entry[1].resource.note = [{ text: 'outside the fixed contract' }];
  assert.throws(() => validateConditionCorpus(mutated), /fixed_synthetic_r4_contract/);
});

test('Condition retrieval keeps the matching subject and drops the foreign synthetic subject', () => {
  const matching = scopeConditionBundle(
    fixture.cases[0].bundle,
    fixture.cases[0].patientContextId,
  );
  assert.equal(matching.foreignConditionsDropped, 0);
  assert.equal(matching.bundle.entry.length, 2);

  const absent = scopeConditionBundle(
    fixture.cases[1].bundle,
    fixture.cases[1].patientContextId,
  );
  assert.equal(absent.foreignConditionsDropped, 0);
  assert.equal(absent.bundle.entry.length, 1);

  const foreignCase = fixture.cases[2];
  const foreign = scopeConditionBundle(foreignCase.bundle, foreignCase.patientContextId);
  assert.equal(foreign.foreignConditionsDropped, 1);
  assert.deepEqual(foreign.bundle.entry, [foreignCase.bundle.entry[0]]);

  const malformed = structuredClone(foreignCase.bundle);
  malformed.entry[1].resource.subject.reference = 'Patient/unscoped';
  assert.throws(
    () => scopeConditionBundle(malformed, foreignCase.patientContextId),
    /fixed_synthetic_r4_contract/,
  );
  const extraField = structuredClone(foreignCase.bundle);
  extraField.identifier = { value: 'outside the fixed contract' };
  assert.throws(
    () => scopeConditionBundle(extraField, foreignCase.patientContextId),
    /fixed_synthetic_r4_contract/,
  );
});

test('pinned JavaScript CQL path evaluates all three Condition retrieval cases', async () => {
  const report = await runConditionRetrievalDifferential();
  assert.equal(report.schemaVersion, 1);
  assert.equal(report.fhirVersion, '4.0.1');
  assert.equal(report.context, 'Patient');
  assert.equal(report.caseCount, 3);
  assert.equal(report.outcomeParityCount, 3);
  assert.deepEqual(report.cases.map((row) => row.outcomes), [
    { hasCondition: true },
    { hasCondition: false },
    { hasCondition: false },
  ]);
  assert.equal(report.cases[2].foreignConditionsDropped, 1);
  assert.equal(report.networkRequestMade, false);
  assert.equal(report.realPatientDataUsed, false);
  const reportText = JSON.stringify(report);
  assert.doesNotMatch(reportText, /synthetic-patient-|synthetic-condition-/);
  assert.doesNotMatch(reportText, /Synthetic test-only placeholder|"resourceType"|"reference"/);
});
