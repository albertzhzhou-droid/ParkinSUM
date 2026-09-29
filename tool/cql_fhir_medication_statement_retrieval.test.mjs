import assert from 'node:assert/strict';
import test from 'node:test';

import fixture from '../test/fixtures/cql_fhir_r4_medication_statement_retrieval_corpus.json' with { type: 'json' };
import {
  fixedMedicationStatementCorpus,
  scopeMedicationStatementBundle,
  validateMedicationStatementCorpus,
} from './cql_fhir_medication_statement_retrieval_contract.mjs';
import { runMedicationStatementRetrievalDifferential } from './cql_fhir_medication_statement_retrieval.mjs';

test('MedicationStatement corpus is exactly ten fixed synthetic FHIR R4 cases covering all eight statuses', () => {
  assert.equal(validateMedicationStatementCorpus(fixture), fixture);
  assert.deepEqual(fixture, fixedMedicationStatementCorpus);
  assert.equal(fixture.schemaVersion, 1);
  assert.equal(fixture.fhirVersion, '4.0.1');
  assert.equal(fixture.context, 'Patient');
  assert.equal(fixture.cases.length, 10);
  assert.deepEqual(
    fixture.cases.slice(0, 8).map((testCase) => testCase.bundle.entry[1].resource.status),
    ['active', 'completed', 'entered-in-error', 'intended', 'stopped', 'unknown', 'not-taken', 'on-hold'],
  );

  const unknownField = structuredClone(fixture);
  unknownField.cases[0].bundle.entry[1].resource.dosage = [{ text: 'not in this harness' }];
  assert.throws(() => validateMedicationStatementCorpus(unknownField), /fixed synthetic FHIR MedicationStatement corpus/);

  const statusMutation = structuredClone(fixture);
  statusMutation.cases[0].bundle.entry[1].resource.status = 'intended';
  assert.throws(() => validateMedicationStatementCorpus(statusMutation), /fixed synthetic FHIR MedicationStatement corpus/);
});

test('Patient scoping retains matching statements and drops foreign subjects', () => {
  const active = scopeMedicationStatementBundle(
    fixture.cases[0].bundle,
    fixture.cases[0].patientContextId,
  );
  assert.equal(active.foreignStatementsDropped, 0);
  assert.equal(active.bundle.entry.length, 2);
  assert.equal(active.bundle.entry[1].resource.status, 'active');

  const foreign = scopeMedicationStatementBundle(
    fixture.cases[9].bundle,
    fixture.cases[9].patientContextId,
  );
  assert.equal(foreign.foreignStatementsDropped, 1);
  assert.deepEqual(foreign.bundle.entry, [fixture.cases[9].bundle.entry[0]]);

  const malformed = structuredClone(fixture.cases[9].bundle);
  malformed.entry[1].resource.subject.reference = 'MedicationStatement/unscoped';
  assert.throws(
    () => scopeMedicationStatementBundle(malformed, fixture.cases[9].patientContextId),
    /medication_statement_subject_reference/,
  );
});

test('pinned JavaScript CQL path reads every fixed FHIR R4 MedicationStatement status value', async () => {
  const report = await runMedicationStatementRetrievalDifferential();
  assert.equal(report.schemaVersion, 1);
  assert.equal(report.fhirVersion, '4.0.1');
  assert.equal(report.context, 'Patient');
  assert.equal(report.caseCount, 10);
  assert.equal(report.outcomeParityCount, 10);
  assert.deepEqual(report.cases.map((row) => row.outcomes), fixture.cases.map((row) => row.expectedOutcomes));
  assert.equal(report.cases[9].foreignStatementsDropped, 1);
  assert.equal(report.networkRequestMade, false);
  assert.equal(report.realPatientDataUsed, false);
  const reportText = JSON.stringify(report);
  assert.doesNotMatch(reportText, /synthetic-patient-|synthetic-medication-statement-/);
  assert.doesNotMatch(reportText, /Synthetic medication placeholder|"resourceType"|"reference"/);
});
