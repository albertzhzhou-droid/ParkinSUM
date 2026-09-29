#!/usr/bin/env node

import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const fixturePath = new URL('../test/fixtures/fhir_r5_plandefinition_data_requirements_contract.json', import.meta.url);
const planCanonical = 'https://example.org/fhir/PlanDefinition/ParkinSUMSyntheticR5DataRequirementsPlan';
const logicLibraryCanonical = 'https://example.org/fhir/Library/ParkinSUMSyntheticR5DataRequirementsLogic';
const syntheticVersion = '1.0.0';

function reject(message) {
  throw new Error(`FHIR R5 PlanDefinition/$data-requirements contract rejected: ${message}`);
}

function requireCondition(condition, message) {
  if (!condition) reject(message);
}

function requireExactKeys(value, expected, label) {
  requireCondition(value !== null && typeof value === 'object' && !Array.isArray(value), `${label} must be an object`);
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  requireCondition(
    actual.length === wanted.length && actual.every((key, index) => key === wanted[index]),
    `${label} contains missing or unsupported fields`,
  );
}

function requireOne(value, label) {
  requireCondition(Array.isArray(value) && value.length === 1, `${label} must contain exactly one item`);
  return value[0];
}

export function validateFhirR5PlanDefinitionDataRequirementsFixture(fixture) {
  requireExactKeys(
    fixture,
    ['schemaVersion', 'fhirVersion', 'operation', 'sourcePlanDefinition', 'sourceLibrary', 'response'],
    'fixture',
  );
  requireCondition(fixture.schemaVersion === 1, 'fixture schemaVersion must equal 1');
  requireCondition(fixture.fhirVersion === '5.0.0', 'fixture must pin FHIR R5 5.0.0');
  requireCondition(fixture.operation === 'PlanDefinition/$data-requirements', 'operation must be PlanDefinition/$data-requirements');

  requireExactKeys(fixture.sourcePlanDefinition, ['canonical', 'version'], 'source PlanDefinition identity');
  requireCondition(fixture.sourcePlanDefinition.canonical === planCanonical, 'source PlanDefinition canonical must match the fixed fixture');
  requireCondition(fixture.sourcePlanDefinition.version === syntheticVersion, 'source PlanDefinition version must equal 1.0.0');
  requireExactKeys(fixture.sourceLibrary, ['canonical', 'version'], 'source Library identity');
  requireCondition(fixture.sourceLibrary.canonical === logicLibraryCanonical, 'source Library canonical must match the fixed fixture');
  requireCondition(fixture.sourceLibrary.version === syntheticVersion, 'source Library version must equal 1.0.0');

  const library = fixture.response;
  requireExactKeys(
    library,
    ['resourceType', 'status', 'type', 'relatedArtifact', 'parameter', 'dataRequirement'],
    'direct Library response',
  );
  requireCondition(library.resourceType === 'Library', 'single return resource must be a direct Library');
  requireCondition(library.status === 'draft', 'synthetic returned Library status must be draft');
  requireExactKeys(library.type, ['coding'], 'Library.type');
  const typeCoding = requireOne(library.type.coding, 'Library.type.coding');
  requireExactKeys(typeCoding, ['system', 'code', 'display'], 'Library.type.coding[0]');
  requireCondition(typeCoding.system === 'http://terminology.hl7.org/CodeSystem/library-type', 'Library.type system is invalid');
  requireCondition(typeCoding.code === 'module-definition', 'returned Library type must be module-definition');
  requireCondition(typeCoding.display === 'Module Definition', 'returned Library type display is invalid');

  const dependency = requireOne(library.relatedArtifact, 'Library.relatedArtifact');
  requireExactKeys(dependency, ['type', 'resource'], 'Library.relatedArtifact[0]');
  requireCondition(dependency.type === 'depends-on', 'synthetic Library dependency type must be depends-on');
  requireCondition(
    dependency.resource === `${fixture.sourceLibrary.canonical}|${fixture.sourceLibrary.version}`,
    'module-definition Library must preserve the exact versioned source Library dependency',
  );

  const parameter = requireOne(library.parameter, 'Library.parameter');
  requireExactKeys(parameter, ['name', 'use', 'min', 'max', 'type'], 'Library.parameter[0]');
  requireCondition(parameter.name === 'hasSyntheticObservation', 'Library parameter name must be fixed');
  requireCondition(parameter.use === 'out' && parameter.min === 0 && parameter.max === '1', 'Library parameter cardinality must be optional scalar output');
  requireExactKeys(parameter.type, ['code'], 'Library.parameter[0].type');
  requireCondition(parameter.type.code === 'boolean', 'Library parameter type must be boolean');

  const dataRequirement = requireOne(library.dataRequirement, 'Library.dataRequirement');
  requireExactKeys(dataRequirement, ['type'], 'Library.dataRequirement[0]');
  requireCondition(dataRequirement.type === 'Observation', 'Library data requirement type must be Observation');

  return {
    sourcePlanDefinitionCount: 1,
    sourceLibraryCount: 1,
    returnedModuleDefinitionLibraryCount: 1,
    returnedDependencyCount: 1,
    returnedParameterCount: 1,
    returnedDataRequirementCount: 1,
  };
}

export function buildFhirR5PlanDefinitionDataRequirementsReport(fixture, fixtureBytes) {
  const counts = validateFhirR5PlanDefinitionDataRequirementsFixture(fixture);
  return {
    schemaVersion: 1,
    status: 'passed',
    fhirVersion: '5.0.0',
    operation: 'PlanDefinition/$data-requirements',
    ...counts,
    fixtureSha256: createHash('sha256').update(fixtureBytes).digest('hex'),
    realPatientDataUsed: false,
    networkRequestMade: false,
    operationExecuted: false,
    fhirValidatorUsed: false,
    structureOnly: true,
  };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const fixtureBytes = readFileSync(fixturePath);
  const fixture = JSON.parse(fixtureBytes.toString('utf8'));
  process.stdout.write(`${JSON.stringify(buildFhirR5PlanDefinitionDataRequirementsReport(fixture, fixtureBytes), null, 2)}\n`);
}
