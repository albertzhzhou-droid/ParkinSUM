import assert from 'node:assert/strict';
import test from 'node:test';

import fixture from '../test/fixtures/cql_fhir_r4_medication_request_retrieval_corpus.json' with { type: 'json' };
import {
  fixedMedicationRequestCorpus,
  medicationRequestIntents,
  medicationRequestStatuses,
  scopeMedicationRequestBundle,
  validateMedicationRequestCorpus,
} from './cql_fhir_medication_request_retrieval_contract.mjs';
import { runMedicationRequestRetrievalDifferential } from './cql_fhir_medication_request_retrieval.mjs';

test('MedicationRequest corpus covers every R4 status and intent in 18 fixed synthetic cases', () => {
  assert.equal(validateMedicationRequestCorpus(fixture), fixture);
  assert.deepEqual(fixture, fixedMedicationRequestCorpus);
  assert.equal(fixture.schemaVersion, 1);
  assert.equal(fixture.fhirVersion, '4.0.1');
  assert.equal(fixture.context, 'Patient');
  assert.equal(fixture.cases.length, 18);
  assert.deepEqual(
    fixture.cases.slice(0, medicationRequestStatuses.length)
      .map((testCase) => testCase.bundle.entry[1].resource.status),
    medicationRequestStatuses,
  );
  assert.deepEqual(
    fixture.cases.slice(medicationRequestStatuses.length, 16)
      .map((testCase) => testCase.bundle.entry[1].resource.intent),
    medicationRequestIntents,
  );

  const unknownField = structuredClone(fixture);
  unknownField.cases[0].bundle.entry[1].resource.dosageInstruction = [{ text: 'outside this probe' }];
  assert.throws(() => validateMedicationRequestCorpus(unknownField), /fixed synthetic FHIR MedicationRequest corpus/);

  const intentMutation = structuredClone(fixture);
  intentMutation.cases[0].bundle.entry[1].resource.intent = 'option';
  assert.throws(() => validateMedicationRequestCorpus(intentMutation), /fixed synthetic FHIR MedicationRequest corpus/);
});

test('Patient scoping retains matching requests and drops a foreign subject', () => {
  const active = scopeMedicationRequestBundle(
    fixture.cases[0].bundle,
    fixture.cases[0].patientContextId,
  );
  assert.equal(active.foreignRequestsDropped, 0);
  assert.equal(active.bundle.entry.length, 2);
  assert.equal(active.bundle.entry[1].resource.status, 'active');
  assert.equal(active.bundle.entry[1].resource.intent, 'order');

  const foreignCase = fixture.cases.at(-1);
  const foreign = scopeMedicationRequestBundle(foreignCase.bundle, foreignCase.patientContextId);
  assert.equal(foreign.foreignRequestsDropped, 1);
  assert.deepEqual(foreign.bundle.entry, [foreignCase.bundle.entry[0]]);

  const malformed = structuredClone(foreignCase.bundle);
  malformed.entry[1].resource.subject.reference = 'MedicationRequest/unscoped';
  assert.throws(
    () => scopeMedicationRequestBundle(malformed, foreignCase.patientContextId),
    /medication_request_subject_reference/,
  );
});

test('pinned JavaScript CQL path reads all statuses and intents without joining their meanings', async () => {
  const report = await runMedicationRequestRetrievalDifferential();
  assert.equal(report.schemaVersion, 1);
  assert.equal(report.fhirVersion, '4.0.1');
  assert.equal(report.context, 'Patient');
  assert.equal(report.caseCount, 18);
  assert.equal(report.outcomeParityCount, 18);
  assert.deepEqual(report.cases.map((row) => row.outcomes), fixture.cases.map((row) => row.expectedOutcomes));
  assert.equal(report.cases.at(-1).foreignRequestsDropped, 1);
  assert.equal(report.networkRequestMade, false);
  assert.equal(report.realPatientDataUsed, false);
  const reportText = JSON.stringify(report);
  assert.doesNotMatch(reportText, /synthetic-patient-|synthetic-medication-request-/);
  assert.doesNotMatch(reportText, /Synthetic medication placeholder|"resourceType"|"reference"/);
});
