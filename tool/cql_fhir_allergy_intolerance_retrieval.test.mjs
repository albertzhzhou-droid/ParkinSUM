import test from 'node:test';
import assert from 'node:assert/strict';

import corpus from '../test/fixtures/cql_fhir_r4_allergy_intolerance_retrieval_corpus.json' with { type: 'json' };
import {
  fixedAllergyIntoleranceCorpus,
  scopeAllergyIntoleranceBundle,
  validateAllergyIntoleranceCorpus,
} from './cql_fhir_allergy_intolerance_retrieval_contract.mjs';
import { runAllergyIntoleranceRetrievalDifferential } from './cql_fhir_allergy_intolerance_retrieval.mjs';

test('fixed AllergyIntolerance corpus covers each R4 status and the entered-in-error invariant', () => {
  assert.deepEqual(validateAllergyIntoleranceCorpus(corpus), fixedAllergyIntoleranceCorpus);
  assert.equal(corpus.cases.length, 6);
  assert.deepEqual(
    corpus.cases.slice(0, 3).map((testCase) => testCase.bundle.entry[1].resource.clinicalStatus.coding[0].code),
    ['active', 'inactive', 'resolved'],
  );
  const enteredInError = corpus.cases[3].bundle.entry[1].resource;
  assert.equal(enteredInError.verificationStatus.coding[0].code, 'entered-in-error');
  assert.equal(Object.hasOwn(enteredInError, 'clinicalStatus'), false);
});

test('AllergyIntolerance corpus validation rejects system drift and invalid entered-in-error status', () => {
  const wrongSystem = structuredClone(corpus);
  wrongSystem.cases[0].bundle.entry[1].resource.clinicalStatus.coding[0].system = 'http://snomed.info/sct';
  assert.throws(() => validateAllergyIntoleranceCorpus(wrongSystem), /fixed synthetic FHIR AllergyIntolerance corpus/);

  const invalidInvariant = structuredClone(corpus.cases[3].bundle.entry[1].resource);
  invalidInvariant.clinicalStatus = structuredClone(corpus.cases[0].bundle.entry[1].resource.clinicalStatus);
  const invalidBundle = {
    ...corpus.cases[3].bundle,
    entry: [...corpus.cases[3].bundle.entry.slice(0, 1), { resource: invalidInvariant }],
  };
  assert.throws(() => scopeAllergyIntoleranceBundle(invalidBundle, corpus.cases[3].patientContextId));
});

test('AllergyIntolerance local scope drops a foreign Patient reference before CQL evaluation', () => {
  const result = scopeAllergyIntoleranceBundle(
    corpus.cases.at(-1).bundle,
    corpus.cases.at(-1).patientContextId,
  );
  assert.equal(result.foreignAllergyIntolerancesDropped, 1);
  assert.equal(result.bundle.entry.length, 1);
  assert.equal(result.bundle.entry[0].resource.resourceType, 'Patient');
});

test('CQF JavaScript AllergyIntolerance retrieval matches all fixed status predicates', async () => {
  const report = await runAllergyIntoleranceRetrievalDifferential();
  assert.equal(report.caseCount, 6);
  assert.equal(report.outcomeParityCount, 6);
  assert.equal(report.cases.at(-1).foreignAllergyIntolerancesDropped, 1);
  assert.equal(report.cases[3].outcomes.hasClinicalStatusActive, false);
  assert.equal(report.cases[3].outcomes.hasVerificationStatusEnteredInError, true);
});
