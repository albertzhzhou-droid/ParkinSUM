#!/usr/bin/env node

import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const fixturePath = new URL('../test/fixtures/fhir_r5_cpg_apply_contract.json', import.meta.url);
const planCanonical = 'https://example.org/fhir/PlanDefinition/ParkinSUMSyntheticR5Plan';
const planVersion = '1.0.0';
const syntheticSubject = 'Patient/synthetic-r5-subject';
const resultFullUrl = 'urn:uuid:6e6c7b46-2be3-4cc3-8356-6c6ce44e7a1c';

function reject(message) {
  throw new Error(`FHIR R5 PlanDefinition/$apply contract rejected: ${message}`);
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

export function validateFhirR5CpgApplyFixture(fixture) {
  requireExactKeys(fixture, ['schemaVersion', 'fhirVersion', 'operation', 'request', 'response'], 'fixture');
  requireCondition(fixture.schemaVersion === 1, 'fixture schemaVersion must equal 1');
  requireCondition(fixture.fhirVersion === '5.0.0', 'fixture must pin FHIR R5 5.0.0');
  requireCondition(fixture.operation === 'PlanDefinition/$apply', 'operation must be PlanDefinition/$apply');

  const request = fixture.request;
  requireExactKeys(request, ['resourceType', 'parameter'], 'request');
  requireCondition(request.resourceType === 'Parameters', 'request must be a FHIR Parameters resource');
  requireCondition(Array.isArray(request.parameter) && request.parameter.length === 2, 'request must have exactly two parameters');
  const planParameter = request.parameter.find((parameter) => parameter?.name === 'planDefinition');
  const subjectParameter = request.parameter.find((parameter) => parameter?.name === 'subject');
  requireCondition(planParameter !== undefined && subjectParameter !== undefined, 'request must bind one planDefinition and one subject');
  requireCondition(new Set(request.parameter.map((parameter) => parameter?.name)).size === 2, 'request parameter names must be unique');

  requireExactKeys(planParameter, ['name', 'resource'], 'planDefinition parameter');
  requireCondition(planParameter.name === 'planDefinition', 'planDefinition parameter name is invalid');
  const plan = planParameter.resource;
  requireExactKeys(plan, ['resourceType', 'id', 'url', 'version', 'status'], 'PlanDefinition');
  requireCondition(plan.resourceType === 'PlanDefinition', 'planDefinition parameter must contain a PlanDefinition');
  requireCondition(plan.id === 'synthetic-r5-plan', 'PlanDefinition id must be the fixed synthetic id');
  requireCondition(plan.url === planCanonical, 'PlanDefinition canonical must match the fixed fixture');
  requireCondition(plan.version === planVersion, 'PlanDefinition version must equal 1.0.0');
  requireCondition(plan.status === 'draft', 'PlanDefinition status must be draft');

  requireExactKeys(subjectParameter, ['name', 'valueReference'], 'subject parameter');
  requireCondition(subjectParameter.name === 'subject', 'subject parameter name is invalid');
  requireExactKeys(subjectParameter.valueReference, ['reference'], 'subject Reference');
  requireCondition(subjectParameter.valueReference.reference === syntheticSubject, 'subject must use the fixed synthetic Patient reference');

  const operationResponse = fixture.response;
  requireCondition(
    operationResponse !== null && typeof operationResponse === 'object' && !Array.isArray(operationResponse),
    'response Parameters must be an object',
  );
  requireCondition(operationResponse.resourceType === 'Parameters', 'response must wrap repeating return Bundles in Parameters');
  requireExactKeys(operationResponse, ['resourceType', 'parameter'], 'response Parameters');
  const returnParameter = requireOne(operationResponse.parameter, 'response Parameters.parameter');
  requireExactKeys(returnParameter, ['name', 'resource'], 'response return parameter');
  requireCondition(returnParameter.name === 'return', 'response parameter name must be return');

  const bundle = returnParameter.resource;
  requireExactKeys(bundle, ['resourceType', 'type', 'entry'], 'response Bundle');
  requireCondition(bundle.resourceType === 'Bundle', 'response must be a Bundle');
  requireCondition(bundle.type === 'collection', 'response Bundle must use type=collection');
  const entry = requireOne(bundle.entry, 'response Bundle.entry');
  requireExactKeys(entry, ['fullUrl', 'resource'], 'response Bundle.entry[0]');
  requireCondition(entry.fullUrl === resultFullUrl, 'response Bundle entry must use the fixed unique synthetic fullUrl');
  const orchestration = entry.resource;
  requireExactKeys(
    orchestration,
    ['resourceType', 'id', 'instantiatesCanonical', 'status', 'intent', 'subject'],
    'RequestOrchestration',
  );
  requireCondition(orchestration.resourceType === 'RequestOrchestration', 'first Bundle entry must be a RequestOrchestration');
  requireCondition(orchestration.id === 'synthetic-r5-result', 'RequestOrchestration id must be fixed and synthetic');
  requireCondition(
    JSON.stringify(orchestration.instantiatesCanonical) === JSON.stringify([`${planCanonical}|${planVersion}`]),
    'RequestOrchestration must reference the exact versioned PlanDefinition canonical',
  );
  requireCondition(orchestration.status === 'draft', 'RequestOrchestration status must be draft');
  requireCondition(orchestration.intent === 'proposal', 'RequestOrchestration intent must be proposal');
  requireExactKeys(orchestration.subject, ['reference'], 'RequestOrchestration.subject');
  requireCondition(orchestration.subject.reference === syntheticSubject, 'RequestOrchestration subject must match the request subject');

  return {
    requestParameterCount: 2,
    requestSubjectCount: 1,
    responseParameterCount: 1,
    returnedBundleCount: 1,
    returnedBundleEntryCount: 1,
    requestOrchestrationCount: 1,
    proposedActionCount: 0,
    createdOrUpdatedResourceCount: 0,
  };
}

export function buildFhirR5CpgApplyReport(fixture, fixtureBytes) {
  const counts = validateFhirR5CpgApplyFixture(fixture);
  return {
    schemaVersion: 1,
    status: 'passed',
    fhirVersion: '5.0.0',
    operation: 'PlanDefinition/$apply',
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
  process.stdout.write(`${JSON.stringify(buildFhirR5CpgApplyReport(fixture, fixtureBytes), null, 2)}\n`);
}
