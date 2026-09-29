import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import {
  buildFhirR5ActivityDefinitionApplyReport,
  validateFhirR5ActivityDefinitionApplyFixture,
} from './fhir_r5_activitydefinition_apply_contract.mjs';

const fixtureBytes = fs.readFileSync(new URL('../test/fixtures/fhir_r5_activitydefinition_apply_contract.json', import.meta.url));
const fixture = JSON.parse(fixtureBytes.toString('utf8'));
const copy = () => structuredClone(fixture);

test('fixed FHIR R5 ActivityDefinition/$apply contract returns one direct synthetic proposal', () => {
  const counts = validateFhirR5ActivityDefinitionApplyFixture(fixture);
  assert.deepEqual(counts, {
    requestParameterCount: 2,
    requestSubjectCount: 1,
    returnedResourceCount: 1,
    returnedRequestOrchestrationCount: 1,
    proposedActionCount: 0,
    createdOrUpdatedResourceCount: 0,
  });
  const report = buildFhirR5ActivityDefinitionApplyReport(fixture, fixtureBytes);
  assert.equal(report.status, 'passed');
  assert.equal(report.fhirVersion, '5.0.0');
  assert.equal(report.operation, 'ActivityDefinition/$apply');
  assert.equal(report.structureOnly, true);
  assert.equal(report.networkRequestMade, false);
  assert.equal(report.cpgEngineExecuted, false);
  assert.equal(report.fhirValidatorUsed, false);
  assert.equal(report.realPatientDataUsed, false);
  assert.doesNotMatch(JSON.stringify(report), /synthetic-r5-subject|ParkinSUMSyntheticR5Activity/);
});

test('rejects duplicate, missing, and unsupported operation input parameters', () => {
  const duplicate = copy();
  duplicate.request.parameter.push(structuredClone(duplicate.request.parameter[1]));
  assert.throws(() => validateFhirR5ActivityDefinitionApplyFixture(duplicate), /exactly two parameters|unique/);

  const missingActivity = copy();
  missingActivity.request.parameter = missingActivity.request.parameter.filter((parameter) => parameter.name !== 'activityDefinition');
  assert.throws(() => validateFhirR5ActivityDefinitionApplyFixture(missingActivity), /exactly two parameters/);

  const unsupported = copy();
  unsupported.request.parameter.push({ name: 'encounter', valueReference: { reference: 'Encounter/synthetic' } });
  assert.throws(() => validateFhirR5ActivityDefinitionApplyFixture(unsupported), /exactly two parameters/);
});

test('rejects schema, version, canonical, resource-kind, and subject drift', () => {
  const wrongSchemaVersion = copy();
  wrongSchemaVersion.schemaVersion = 2;
  assert.throws(() => validateFhirR5ActivityDefinitionApplyFixture(wrongSchemaVersion), /schemaVersion must equal 1/);

  const wrongVersion = copy();
  wrongVersion.fhirVersion = '4.0.1';
  assert.throws(() => validateFhirR5ActivityDefinitionApplyFixture(wrongVersion), /FHIR R5 5\.0\.0/);

  const wrongActivityVersion = copy();
  wrongActivityVersion.request.parameter[0].resource.version = '2.0.0';
  assert.throws(() => validateFhirR5ActivityDefinitionApplyFixture(wrongActivityVersion), /ActivityDefinition version must equal 1\.0\.0/);

  const wrongCanonical = copy();
  wrongCanonical.request.parameter[0].resource.url = 'https://example.org/fhir/ActivityDefinition/Other';
  assert.throws(() => validateFhirR5ActivityDefinitionApplyFixture(wrongCanonical), /ActivityDefinition canonical must match/);

  const wrongKind = copy();
  wrongKind.request.parameter[0].resource.kind = 'MedicationRequest';
  assert.throws(() => validateFhirR5ActivityDefinitionApplyFixture(wrongKind), /kind must be RequestOrchestration/);

  const changedOutputType = copy();
  changedOutputType.response.resourceType = 'Parameters';
  assert.throws(() => validateFhirR5ActivityDefinitionApplyFixture(changedOutputType), /response must be the ActivityDefinition kind resource directly/);

  const changedSubject = copy();
  changedSubject.response.subject.reference = 'Patient/other';
  assert.throws(() => validateFhirR5ActivityDefinitionApplyFixture(changedSubject), /response subject must match/);
});

test('rejects actionable output additions and wrong proposal identity', () => {
  const action = copy();
  action.response.action = [{ title: 'Unexpected action' }];
  assert.throws(() => validateFhirR5ActivityDefinitionApplyFixture(action), /contains missing or unsupported fields/);

  const wrongCanonical = copy();
  wrongCanonical.response.instantiatesCanonical[0] += '|2.0.0';
  assert.throws(() => validateFhirR5ActivityDefinitionApplyFixture(wrongCanonical), /exact versioned ActivityDefinition canonical/);

  const wrongStatus = copy();
  wrongStatus.response.status = 'active';
  assert.throws(() => validateFhirR5ActivityDefinitionApplyFixture(wrongStatus), /status must be draft/);

  const wrongIntent = copy();
  wrongIntent.response.intent = 'order';
  assert.throws(() => validateFhirR5ActivityDefinitionApplyFixture(wrongIntent), /intent must be proposal/);
});
