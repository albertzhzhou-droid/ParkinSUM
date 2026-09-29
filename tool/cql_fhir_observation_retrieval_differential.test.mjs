import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import test from 'node:test';

import {
  runObservationRetrievalDifferential,
  scopeBundleToPatientContext,
  validateObservationCorpus,
} from './cql_fhir_observation_retrieval_differential.mjs';
import corpus from '../test/fixtures/cql_fhir_r4_observation_retrieval_corpus.json' with { type: 'json' };

const require = createRequire(import.meta.url);
const CqlExecFhir = require('cql-exec-fhir');

test('FHIR Observation retrieval and terminology corpus remains exactly six fixed synthetic cases', () => {
  assert.equal(validateObservationCorpus(corpus), corpus);
  assert.equal(corpus.schemaVersion, 2);
  assert.equal(corpus.cases.length, 6);
  const unknownField = structuredClone(corpus);
  unknownField.cases[0].bundle.entry[0].resource.name = [{ text: 'Not in the fixture contract' }];
  assert.throws(() => validateObservationCorpus(unknownField), /fixed synthetic FHIR Observation corpus/);
  const changedPatient = structuredClone(corpus);
  changedPatient.cases[2].patientContextId = 'synthetic-patient-other';
  assert.throws(() => validateObservationCorpus(changedPatient), /fixed synthetic FHIR Observation corpus/);
  const changedCoding = structuredClone(corpus.cases[0].bundle);
  changedCoding.entry[1].resource.code.coding[0].display = 'Unexpected coding field';
  assert.throws(() => scopeBundleToPatientContext(changedCoding, 'synthetic-patient-present'), /observation_1_coding_shape/);
});

test('Patient scoping keeps matching Observations and drops foreign-subject Observations', () => {
  const present = scopeBundleToPatientContext(corpus.cases[0].bundle, 'synthetic-patient-present');
  assert.equal(present.foreignObservationsDropped, 0);
  assert.equal(present.bundle.entry.length, 2);
  assert.deepEqual(present.bundle.entry, corpus.cases[0].bundle.entry);

  const foreign = scopeBundleToPatientContext(corpus.cases[2].bundle, 'synthetic-patient-empty');
  assert.equal(foreign.foreignObservationsDropped, 1);
  assert.deepEqual(foreign.bundle.entry, [corpus.cases[2].bundle.entry[0]]);
  assert.throws(() => scopeBundleToPatientContext(corpus.cases[0].bundle, 'synthetic-patient-empty'), /patient_context_mismatch/);
  const malformedSubject = structuredClone(corpus.cases[2].bundle);
  malformedSubject.entry[1].resource.subject.reference = 'Observation/unscoped';
  assert.throws(() => scopeBundleToPatientContext(malformedSubject, 'synthetic-patient-empty'), /observation_subject_reference/);
});

test('pinned FHIR CQL runtime evaluates retrieval and local ValueSet membership cases', async () => {
  const unscopedPatientSource = CqlExecFhir.PatientSource.FHIRv401();
  unscopedPatientSource.loadBundles([corpus.cases[2].bundle]);
  const unscopedPatient = unscopedPatientSource.currentPatient();
  assert.equal(unscopedPatient.findRecords('FHIR.Observation').length, 1);

  const report = await runObservationRetrievalDifferential();
  assert.deepEqual(report.cases.map(({
    id,
    expectedResult,
    result,
    expectedRuntimeValueSetMembership,
    runtimeValueSetMembership,
    expectedVersionAwareMembership,
    foreignObservationsDropped,
  }) => (
    {
      id,
      expectedResult,
      result,
      expectedRuntimeValueSetMembership,
      runtimeValueSetMembership,
      expectedVersionAwareMembership,
      foreignObservationsDropped,
    }
  )), [
    {
      id: 'observation_present',
      expectedResult: true,
      result: true,
      expectedRuntimeValueSetMembership: true,
      runtimeValueSetMembership: true,
      expectedVersionAwareMembership: true,
      foreignObservationsDropped: 0,
    },
    {
      id: 'observation_absent',
      expectedResult: false,
      result: false,
      expectedRuntimeValueSetMembership: false,
      runtimeValueSetMembership: false,
      expectedVersionAwareMembership: false,
      foreignObservationsDropped: 0,
    },
    {
      id: 'observation_foreign_subject',
      expectedResult: false,
      result: false,
      expectedRuntimeValueSetMembership: false,
      runtimeValueSetMembership: false,
      expectedVersionAwareMembership: false,
      foreignObservationsDropped: 1,
    },
    {
      id: 'observation_non_member_code',
      expectedResult: true,
      result: true,
      expectedRuntimeValueSetMembership: false,
      runtimeValueSetMembership: false,
      expectedVersionAwareMembership: false,
      foreignObservationsDropped: 0,
    },
    {
      id: 'observation_foreign_code_system',
      expectedResult: true,
      result: true,
      expectedRuntimeValueSetMembership: false,
      runtimeValueSetMembership: false,
      expectedVersionAwareMembership: false,
      foreignObservationsDropped: 0,
    },
    {
      id: 'observation_system_version_mismatch',
      expectedResult: true,
      result: true,
      expectedRuntimeValueSetMembership: true,
      runtimeValueSetMembership: true,
      expectedVersionAwareMembership: false,
      foreignObservationsDropped: 0,
    },
  ]);
  assert.equal(report.schemaVersion, 2);
  assert.equal(report.fhirVersion, '4.0.1');
  assert.deepEqual(report.terminology, {
    valueSetCanonical: 'urn:oid:1.2.3.4.5.6.7',
    valueSetVersion: '2026-09',
    expansionSource: 'fixed-local-synthetic-code-service',
    codingSystemVersionComparedByRuntime: false,
  });
  assert.equal(report.networkRequestMade, false);
  assert.equal(report.realPatientDataUsed, false);
  const reportText = JSON.stringify(report);
  assert.doesNotMatch(reportText, /synthetic-patient-|synthetic-observation-/);
  assert.doesNotMatch(reportText, /"resourceType"|"subject"/);
  assert.doesNotMatch(reportText, /observation-in-set|observation-outside-set|urn:parkinsum:synthetic/);
});
