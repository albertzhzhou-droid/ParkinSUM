import assert from 'node:assert/strict';
import test from 'node:test';

import fixture from '../test/fixtures/cql_fhir_r4_medication_administration_retrieval_corpus.json' with { type: 'json' };
import {
  fixedMedicationAdministrationCorpus,
  medicationAdministrationStatuses,
  scopeMedicationAdministrationBundle,
  validateMedicationAdministrationCorpus,
} from './cql_fhir_medication_administration_retrieval_contract.mjs';
import { runMedicationAdministrationRetrievalDifferential } from './cql_fhir_medication_administration_retrieval.mjs';

test('MedicationAdministration corpus covers all seven R4 statuses in nine fixed synthetic cases', () => {
  assert.equal(validateMedicationAdministrationCorpus(fixture), fixture);
  assert.deepEqual(fixture, fixedMedicationAdministrationCorpus);
  assert.equal(fixture.schemaVersion, 1);
  assert.equal(fixture.fhirVersion, '4.0.1');
  assert.equal(fixture.context, 'Patient');
  assert.equal(fixture.cases.length, 9);
  assert.deepEqual(
    fixture.cases.slice(0, medicationAdministrationStatuses.length)
      .map((testCase) => testCase.bundle.entry[1].resource.status),
    medicationAdministrationStatuses,
  );

  const unknownField = structuredClone(fixture);
  unknownField.cases[0].bundle.entry[1].resource.dosage = { dose: { value: 100 } };
  assert.throws(() => validateMedicationAdministrationCorpus(unknownField), /fixed synthetic FHIR MedicationAdministration corpus/);
});

test('Patient scoping retains matching administration and drops a foreign subject', () => {
  const matchingCase = fixture.cases[0];
  const matching = scopeMedicationAdministrationBundle(matchingCase.bundle, matchingCase.patientContextId);
  assert.equal(matching.foreignAdministrationsDropped, 0);
  assert.equal(matching.bundle.entry.length, 2);
  assert.equal(matching.bundle.entry[1].resource.status, 'in-progress');

  const foreignCase = fixture.cases.at(-1);
  const foreign = scopeMedicationAdministrationBundle(foreignCase.bundle, foreignCase.patientContextId);
  assert.equal(foreign.foreignAdministrationsDropped, 1);
  assert.deepEqual(foreign.bundle.entry, [foreignCase.bundle.entry[0]]);

  const malformed = structuredClone(foreignCase.bundle);
  malformed.entry[1].resource.subject.reference = 'MedicationAdministration/unscoped';
  assert.throws(
    () => scopeMedicationAdministrationBundle(malformed, foreignCase.patientContextId),
    /medication_administration_subject_reference/,
  );
});

test('pinned JavaScript CQL path reads all statuses with exact Patient scoping', async () => {
  const report = await runMedicationAdministrationRetrievalDifferential();
  assert.equal(report.schemaVersion, 1);
  assert.equal(report.fhirVersion, '4.0.1');
  assert.equal(report.context, 'Patient');
  assert.equal(report.caseCount, 9);
  assert.equal(report.outcomeParityCount, 9);
  assert.deepEqual(report.cases.map((row) => row.outcomes), fixture.cases.map((row) => row.expectedOutcomes));
  assert.equal(report.cases.at(-1).foreignAdministrationsDropped, 1);
  assert.equal(report.networkRequestMade, false);
  assert.equal(report.realPatientDataUsed, false);
  const reportText = JSON.stringify(report);
  assert.doesNotMatch(reportText, /synthetic-patient-|synthetic-ma-/);
  assert.doesNotMatch(reportText, /Synthetic medication placeholder|2026-01-15T12:00:00Z|"resourceType"|"reference"/);
});
