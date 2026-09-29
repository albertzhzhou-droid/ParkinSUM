import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import {
  buildFhirR5CpgApplyReport,
  validateFhirR5CpgApplyFixture,
} from './fhir_r5_cpg_apply_contract.mjs';

const fixtureBytes = fs.readFileSync(new URL('../test/fixtures/fhir_r5_cpg_apply_contract.json', import.meta.url));
const fixture = JSON.parse(fixtureBytes.toString('utf8'));
const copy = () => structuredClone(fixture);

test('fixed FHIR R5 PlanDefinition/$apply result contract is versioned and synthetic', () => {
  const counts = validateFhirR5CpgApplyFixture(fixture);
  assert.deepEqual(counts, {
    requestParameterCount: 2,
    requestSubjectCount: 1,
    responseParameterCount: 1,
    returnedBundleCount: 1,
    returnedBundleEntryCount: 1,
    requestOrchestrationCount: 1,
    proposedActionCount: 0,
    createdOrUpdatedResourceCount: 0,
  });
  const report = buildFhirR5CpgApplyReport(fixture, fixtureBytes);
  assert.equal(report.status, 'passed');
  assert.equal(report.fhirVersion, '5.0.0');
  assert.equal(report.structureOnly, true);
  assert.equal(report.networkRequestMade, false);
  assert.equal(report.cpgEngineExecuted, false);
  assert.equal(report.fhirValidatorUsed, false);
  assert.equal(report.realPatientDataUsed, false);
  assert.doesNotMatch(JSON.stringify(report), /synthetic-r5-subject|synthetic-r5-plan|ParkinSUMSyntheticR5Plan/);
});

test('rejects duplicate, missing, and unsupported operation input parameters', () => {
  const duplicate = copy();
  duplicate.request.parameter.push(structuredClone(duplicate.request.parameter[1]));
  assert.throws(() => validateFhirR5CpgApplyFixture(duplicate), /exactly two parameters|unique/);

  const missingSubject = copy();
  missingSubject.request.parameter = missingSubject.request.parameter.filter((parameter) => parameter.name !== 'subject');
  assert.throws(() => validateFhirR5CpgApplyFixture(missingSubject), /exactly two parameters/);

  const unsupported = copy();
  unsupported.request.parameter.push({ name: 'encounter', valueReference: { reference: 'Encounter/synthetic' } });
  assert.throws(() => validateFhirR5CpgApplyFixture(unsupported), /exactly two parameters/);
});

test('rejects FHIR, canonical, subject, and response-shape drift', () => {
  const wrongSchemaVersion = copy();
  wrongSchemaVersion.schemaVersion = 2;
  assert.throws(() => validateFhirR5CpgApplyFixture(wrongSchemaVersion), /schemaVersion must equal 1/);

  const wrongVersion = copy();
  wrongVersion.fhirVersion = '4.0.1';
  assert.throws(() => validateFhirR5CpgApplyFixture(wrongVersion), /FHIR R5 5\.0\.0/);

  const wrongPlanVersion = copy();
  wrongPlanVersion.request.parameter[0].resource.version = '2.0.0';
  assert.throws(() => validateFhirR5CpgApplyFixture(wrongPlanVersion), /PlanDefinition version must equal 1\.0\.0/);

  const wrongPlanCanonical = copy();
  wrongPlanCanonical.request.parameter[0].resource.url = 'https://example.org/fhir/PlanDefinition/Other';
  assert.throws(() => validateFhirR5CpgApplyFixture(wrongPlanCanonical), /PlanDefinition canonical must match/);

  const wrongCanonical = copy();
  wrongCanonical.response.parameter[0].resource.entry[0].resource.instantiatesCanonical[0] += '|2.0.0';
  assert.throws(() => validateFhirR5CpgApplyFixture(wrongCanonical), /exact versioned PlanDefinition/);

  const wrongSubject = copy();
  wrongSubject.response.parameter[0].resource.entry[0].resource.subject.reference = 'Patient/other';
  assert.throws(() => validateFhirR5CpgApplyFixture(wrongSubject), /subject must match/);

  const wrongBundle = copy();
  wrongBundle.response.parameter[0].resource.type = 'transaction';
  assert.throws(() => validateFhirR5CpgApplyFixture(wrongBundle), /type=collection/);

  const missingFullUrl = copy();
  delete missingFullUrl.response.parameter[0].resource.entry[0].fullUrl;
  assert.throws(() => validateFhirR5CpgApplyFixture(missingFullUrl), /missing or unsupported fields/);

  const wrongFullUrl = copy();
  wrongFullUrl.response.parameter[0].resource.entry[0].fullUrl = 'urn:uuid:not-the-pinned-id';
  assert.throws(() => validateFhirR5CpgApplyFixture(wrongFullUrl), /fixed unique synthetic fullUrl/);

  const wrongFirstEntry = copy();
  wrongFirstEntry.response.parameter[0].resource.entry[0].resource.resourceType = 'CarePlan';
  assert.throws(() => validateFhirR5CpgApplyFixture(wrongFirstEntry), /RequestOrchestration/);

  const wrongStatus = copy();
  wrongStatus.response.parameter[0].resource.entry[0].resource.status = 'active';
  assert.throws(() => validateFhirR5CpgApplyFixture(wrongStatus), /status must be draft/);

  const wrongIntent = copy();
  wrongIntent.response.parameter[0].resource.entry[0].resource.intent = 'order';
  assert.throws(() => validateFhirR5CpgApplyFixture(wrongIntent), /intent must be proposal/);
});

test('requires the Parameters wrapper for the 0..* PlanDefinition return and one exact return part', () => {
  const directBundle = copy();
  directBundle.response = directBundle.response.parameter[0].resource;
  assert.throws(() => validateFhirR5CpgApplyFixture(directBundle), /response must wrap repeating return Bundles in Parameters/);

  const missingReturn = copy();
  missingReturn.response.parameter = [];
  assert.throws(() => validateFhirR5CpgApplyFixture(missingReturn), /exactly one item/);

  const duplicateReturn = copy();
  duplicateReturn.response.parameter.push(structuredClone(duplicateReturn.response.parameter[0]));
  assert.throws(() => validateFhirR5CpgApplyFixture(duplicateReturn), /exactly one item/);

  const wrongName = copy();
  wrongName.response.parameter[0].name = 'bundle';
  assert.throws(() => validateFhirR5CpgApplyFixture(wrongName), /parameter name must be return/);
});

test('rejects executable additions and transaction metadata in collection output', () => {
  const action = copy();
  action.response.parameter[0].resource.entry[0].resource.action = [{ title: 'Unexpected action' }];
  assert.throws(() => validateFhirR5CpgApplyFixture(action), /unsupported fields/);

  const generatedEntry = copy();
  generatedEntry.response.parameter[0].resource.entry.push({ resource: { resourceType: 'ServiceRequest' } });
  assert.throws(() => validateFhirR5CpgApplyFixture(generatedEntry), /exactly one item/);

  const transactionMetadata = copy();
  transactionMetadata.response.parameter[0].resource.entry[0].request = { method: 'POST', url: 'ServiceRequest' };
  assert.throws(() => validateFhirR5CpgApplyFixture(transactionMetadata), /unsupported fields/);
});
