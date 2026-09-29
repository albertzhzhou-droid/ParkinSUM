import assert from 'node:assert/strict';
import test from 'node:test';

import fixture from '../test/fixtures/cql_fhir_r4_medication_dispense_retrieval_corpus.json' with { type: 'json' };
import {
  fixedMedicationDispenseCorpus,
  medicationDispenseStatuses,
  scopeMedicationDispenseBundle,
  validateMedicationDispenseCorpus,
} from './cql_fhir_medication_dispense_retrieval_contract.mjs';
import { runMedicationDispenseRetrievalDifferential } from './cql_fhir_medication_dispense_retrieval.mjs';

test('MedicationDispense corpus covers every R4 status in 11 fixed synthetic cases', () => {
  assert.equal(validateMedicationDispenseCorpus(fixture), fixture);
  assert.deepEqual(fixture, fixedMedicationDispenseCorpus);
  assert.equal(fixture.schemaVersion, 1);
  assert.equal(fixture.fhirVersion, '4.0.1');
  assert.equal(fixture.context, 'Patient');
  assert.equal(fixture.cases.length, 11);
  assert.deepEqual(
    fixture.cases.slice(0, medicationDispenseStatuses.length)
      .map((testCase) => testCase.bundle.entry[1].resource.status),
    medicationDispenseStatuses,
  );

  const unknownField = structuredClone(fixture);
  unknownField.cases[0].bundle.entry[1].resource.dosageInstruction = [{ text: 'outside this probe' }];
  assert.throws(() => validateMedicationDispenseCorpus(unknownField), /fixed synthetic FHIR MedicationDispense corpus/);
});

test('Patient scoping retains matching dispense and drops a foreign subject', () => {
  const matching = scopeMedicationDispenseBundle(
    fixture.cases[0].bundle,
    fixture.cases[0].patientContextId,
  );
  assert.equal(matching.foreignDispensesDropped, 0);
  assert.equal(matching.bundle.entry.length, 2);
  assert.equal(matching.bundle.entry[1].resource.status, 'preparation');

  const foreignCase = fixture.cases.at(-1);
  const foreign = scopeMedicationDispenseBundle(foreignCase.bundle, foreignCase.patientContextId);
  assert.equal(foreign.foreignDispensesDropped, 1);
  assert.deepEqual(foreign.bundle.entry, [foreignCase.bundle.entry[0]]);

  const malformed = structuredClone(foreignCase.bundle);
  malformed.entry[1].resource.subject.reference = 'MedicationDispense/unscoped';
  assert.throws(
    () => scopeMedicationDispenseBundle(malformed, foreignCase.patientContextId),
    /medication_dispense_subject_reference/,
  );
});

test('pinned JavaScript CQL path reads all statuses with exact Patient scoping', async () => {
  const report = await runMedicationDispenseRetrievalDifferential();
  assert.equal(report.schemaVersion, 1);
  assert.equal(report.fhirVersion, '4.0.1');
  assert.equal(report.context, 'Patient');
  assert.equal(report.caseCount, 11);
  assert.equal(report.outcomeParityCount, 11);
  assert.deepEqual(report.cases.map((row) => row.outcomes), fixture.cases.map((row) => row.expectedOutcomes));
  assert.equal(report.cases.at(-1).foreignDispensesDropped, 1);
  assert.equal(report.networkRequestMade, false);
  assert.equal(report.realPatientDataUsed, false);
  const reportText = JSON.stringify(report);
  assert.doesNotMatch(reportText, /synthetic-patient-|synthetic-medication-dispense-/);
  assert.doesNotMatch(reportText, /Synthetic medication placeholder|"resourceType"|"reference"/);
});
