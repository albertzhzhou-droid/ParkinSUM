import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import {
  buildFhirR5PlanDefinitionDataRequirementsReport,
  validateFhirR5PlanDefinitionDataRequirementsFixture,
} from './fhir_r5_plandefinition_data_requirements_contract.mjs';

const fixtureBytes = fs.readFileSync(new URL('../test/fixtures/fhir_r5_plandefinition_data_requirements_contract.json', import.meta.url));
const fixture = JSON.parse(fixtureBytes.toString('utf8'));
const copy = () => structuredClone(fixture);

test('fixed FHIR R5 PlanDefinition/$data-requirements result is a synthetic module-definition Library', () => {
  const counts = validateFhirR5PlanDefinitionDataRequirementsFixture(fixture);
  assert.deepEqual(counts, {
    sourcePlanDefinitionCount: 1,
    sourceLibraryCount: 1,
    returnedModuleDefinitionLibraryCount: 1,
    returnedDependencyCount: 1,
    returnedParameterCount: 1,
    returnedDataRequirementCount: 1,
  });
  const report = buildFhirR5PlanDefinitionDataRequirementsReport(fixture, fixtureBytes);
  assert.equal(report.status, 'passed');
  assert.equal(report.fhirVersion, '5.0.0');
  assert.equal(report.structureOnly, true);
  assert.equal(report.networkRequestMade, false);
  assert.equal(report.operationExecuted, false);
  assert.equal(report.fhirValidatorUsed, false);
  assert.equal(report.realPatientDataUsed, false);
  assert.doesNotMatch(JSON.stringify(report), /ParkinSUMSyntheticR5DataRequirements|hasSyntheticObservation/);
});

test('rejects FHIR version, operation, source identity, and direct-result shape drift', () => {
  const wrongSchemaVersion = copy();
  wrongSchemaVersion.schemaVersion = 2;
  assert.throws(() => validateFhirR5PlanDefinitionDataRequirementsFixture(wrongSchemaVersion), /schemaVersion must equal 1/);

  const wrongFhirVersion = copy();
  wrongFhirVersion.fhirVersion = '4.0.1';
  assert.throws(() => validateFhirR5PlanDefinitionDataRequirementsFixture(wrongFhirVersion), /FHIR R5 5\.0\.0/);

  const wrongOperation = copy();
  wrongOperation.operation = 'PlanDefinition/$apply';
  assert.throws(() => validateFhirR5PlanDefinitionDataRequirementsFixture(wrongOperation), /operation must be PlanDefinition/);

  const wrongPlanVersion = copy();
  wrongPlanVersion.sourcePlanDefinition.version = '2.0.0';
  assert.throws(() => validateFhirR5PlanDefinitionDataRequirementsFixture(wrongPlanVersion), /PlanDefinition version must equal/);

  const wrappedLibrary = copy();
  wrappedLibrary.response = { resourceType: 'Parameters', parameter: [{ name: 'return', resource: wrappedLibrary.response }] };
  assert.throws(() => validateFhirR5PlanDefinitionDataRequirementsFixture(wrappedLibrary), /direct Library response contains missing or unsupported fields/);

  const wrongResource = copy();
  wrongResource.response.resourceType = 'Bundle';
  assert.throws(() => validateFhirR5PlanDefinitionDataRequirementsFixture(wrongResource), /direct Library/);
});

test('rejects module type, missing or duplicate dependency, and dependency version drift', () => {
  const wrongType = copy();
  wrongType.response.type.coding[0].code = 'logic-library';
  assert.throws(() => validateFhirR5PlanDefinitionDataRequirementsFixture(wrongType), /module-definition/);

  const missingDependency = copy();
  missingDependency.response.relatedArtifact = [];
  assert.throws(() => validateFhirR5PlanDefinitionDataRequirementsFixture(missingDependency), /exactly one item/);

  const duplicateDependency = copy();
  duplicateDependency.response.relatedArtifact.push(structuredClone(duplicateDependency.response.relatedArtifact[0]));
  assert.throws(() => validateFhirR5PlanDefinitionDataRequirementsFixture(duplicateDependency), /exactly one item/);

  const wrongDependencyVersion = copy();
  wrongDependencyVersion.response.relatedArtifact[0].resource += '|2.0.0';
  assert.throws(() => validateFhirR5PlanDefinitionDataRequirementsFixture(wrongDependencyVersion), /exact versioned source Library dependency/);
});

test('rejects changed parameter and data-requirement outputs', () => {
  const missingParameter = copy();
  missingParameter.response.parameter = [];
  assert.throws(() => validateFhirR5PlanDefinitionDataRequirementsFixture(missingParameter), /exactly one item/);

  const changedParameterType = copy();
  changedParameterType.response.parameter[0].type.code = 'string';
  assert.throws(() => validateFhirR5PlanDefinitionDataRequirementsFixture(changedParameterType), /parameter type must be boolean/);

  const wrongCardinality = copy();
  wrongCardinality.response.parameter[0].max = '*';
  assert.throws(() => validateFhirR5PlanDefinitionDataRequirementsFixture(wrongCardinality), /optional scalar output/);

  const missingRequirement = copy();
  missingRequirement.response.dataRequirement = [];
  assert.throws(() => validateFhirR5PlanDefinitionDataRequirementsFixture(missingRequirement), /exactly one item/);

  const wrongRequirementType = copy();
  wrongRequirementType.response.dataRequirement[0].type = 'Patient';
  assert.throws(() => validateFhirR5PlanDefinitionDataRequirementsFixture(wrongRequirementType), /data requirement type must be Observation/);
});
