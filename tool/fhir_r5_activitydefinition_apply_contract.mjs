#!/usr/bin/env node

import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const fixturePath = new URL('../test/fixtures/fhir_r5_activitydefinition_apply_contract.json', import.meta.url);
const activityCanonical = 'https://example.org/fhir/ActivityDefinition/ParkinSUMSyntheticR5Activity';
const activityVersion = '1.0.0';
const syntheticSubject = 'Patient/synthetic-r5-subject';

function reject(message) {
  throw new Error(`FHIR R5 ActivityDefinition/$apply contract rejected: ${message}`);
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

export function validateFhirR5ActivityDefinitionApplyFixture(fixture) {
  requireExactKeys(fixture, ['schemaVersion', 'fhirVersion', 'operation', 'request', 'response'], 'fixture');
  requireCondition(fixture.schemaVersion === 1, 'fixture schemaVersion must equal 1');
  requireCondition(fixture.fhirVersion === '5.0.0', 'fixture must pin FHIR R5 5.0.0');
  requireCondition(fixture.operation === 'ActivityDefinition/$apply', 'operation must be ActivityDefinition/$apply');

  const request = fixture.request;
  requireExactKeys(request, ['resourceType', 'parameter'], 'request');
  requireCondition(request.resourceType === 'Parameters', 'request must be a FHIR Parameters resource');
  requireCondition(Array.isArray(request.parameter) && request.parameter.length === 2, 'request must have exactly two parameters');
  const activityParameter = request.parameter.find((parameter) => parameter?.name === 'activityDefinition');
  const subjectParameter = request.parameter.find((parameter) => parameter?.name === 'subject');
  requireCondition(activityParameter !== undefined && subjectParameter !== undefined, 'request must bind one activityDefinition and one subject');
  requireCondition(new Set(request.parameter.map((parameter) => parameter?.name)).size === 2, 'request parameter names must be unique');

  requireExactKeys(activityParameter, ['name', 'resource'], 'activityDefinition parameter');
  requireCondition(activityParameter.name === 'activityDefinition', 'activityDefinition parameter name is invalid');
  const activity = activityParameter.resource;
  requireExactKeys(activity, ['resourceType', 'id', 'url', 'version', 'status', 'kind'], 'ActivityDefinition');
  requireCondition(activity.resourceType === 'ActivityDefinition', 'activityDefinition parameter must contain an ActivityDefinition');
  requireCondition(activity.id === 'synthetic-r5-activity', 'ActivityDefinition id must be the fixed synthetic id');
  requireCondition(activity.url === activityCanonical, 'ActivityDefinition canonical must match the fixed fixture');
  requireCondition(activity.version === activityVersion, 'ActivityDefinition version must equal 1.0.0');
  requireCondition(activity.status === 'draft', 'ActivityDefinition status must be draft');
  requireCondition(activity.kind === 'RequestOrchestration', 'ActivityDefinition kind must be RequestOrchestration');

  requireExactKeys(subjectParameter, ['name', 'valueReference'], 'subject parameter');
  requireCondition(subjectParameter.name === 'subject', 'subject parameter name is invalid');
  requireExactKeys(subjectParameter.valueReference, ['reference'], 'subject Reference');
  requireCondition(subjectParameter.valueReference.reference === syntheticSubject, 'subject must use the fixed synthetic Patient reference');

  const result = fixture.response;
  requireExactKeys(
    result,
    ['resourceType', 'id', 'instantiatesCanonical', 'status', 'intent', 'subject'],
    'response RequestOrchestration',
  );
  requireCondition(result.resourceType === 'RequestOrchestration', 'response must be the ActivityDefinition kind resource directly');
  requireCondition(result.id === 'synthetic-r5-activity-apply-result', 'response id must be fixed and synthetic');
  requireCondition(
    JSON.stringify(result.instantiatesCanonical) === JSON.stringify([`${activityCanonical}|${activityVersion}`]),
    'response must reference the exact versioned ActivityDefinition canonical',
  );
  requireCondition(result.status === 'draft', 'response status must be draft');
  requireCondition(result.intent === 'proposal', 'response intent must be proposal');
  requireExactKeys(result.subject, ['reference'], 'response subject');
  requireCondition(result.subject.reference === syntheticSubject, 'response subject must match the request subject');

  return {
    requestParameterCount: 2,
    requestSubjectCount: 1,
    returnedResourceCount: 1,
    returnedRequestOrchestrationCount: 1,
    proposedActionCount: 0,
    createdOrUpdatedResourceCount: 0,
  };
}

export function buildFhirR5ActivityDefinitionApplyReport(fixture, fixtureBytes) {
  const counts = validateFhirR5ActivityDefinitionApplyFixture(fixture);
  return {
    schemaVersion: 1,
    status: 'passed',
    fhirVersion: '5.0.0',
    operation: 'ActivityDefinition/$apply',
    ...counts,
    fixtureSha256: createHash('sha256').update(fixtureBytes).digest('hex'),
    realPatientDataUsed: false,
    networkRequestMade: false,
    cpgEngineExecuted: false,
    fhirValidatorUsed: false,
    structureOnly: true,
  };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const fixtureBytes = readFileSync(fixturePath);
  const fixture = JSON.parse(fixtureBytes.toString('utf8'));
  process.stdout.write(`${JSON.stringify(buildFhirR5ActivityDefinitionApplyReport(fixture, fixtureBytes), null, 2)}\n`);
}
