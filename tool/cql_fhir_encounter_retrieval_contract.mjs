import assert from 'node:assert/strict';
import { isDeepStrictEqual } from 'node:util';

export const encounterStatuses = Object.freeze([
  'planned',
  'arrived',
  'triaged',
  'in-progress',
  'onleave',
  'finished',
  'cancelled',
  'entered-in-error',
  'unknown',
]);

const pascalCase = (value) => value
  .split(/[^A-Za-z0-9]+/)
  .filter(Boolean)
  .map((part) => part[0].toUpperCase() + part.slice(1))
  .join('');

export const encounterStatusOutcomeKeys = Object.freeze([
  'hasAnyEncounter',
  ...encounterStatuses.map((status) => `hasStatus${pascalCase(status)}`),
]);

const expectedOutcomes = (status, visible) => Object.fromEntries([
  ['hasAnyEncounter', visible],
  ...encounterStatuses.map((value) => [
    `hasStatus${pascalCase(value)}`,
    visible && status === value,
  ]),
]);

function buildCase(id, status, { present = true, foreign = false } = {}) {
  const suffix = id.replaceAll('_', '-');
  const patientContextId = `synthetic-patient-${suffix}`;
  const entry = [{ resource: { resourceType: 'Patient', id: patientContextId } }];
  if (present) {
    entry.push({
      resource: {
        resourceType: 'Encounter',
        id: `synthetic-encounter-${suffix}`,
        status,
        subject: {
          reference: `Patient/${foreign ? 'synthetic-patient-other' : patientContextId}`,
        },
      },
    });
  }
  return {
    id,
    patientContextId,
    expectedOutcomes: expectedOutcomes(status, present && !foreign),
    bundle: { resourceType: 'Bundle', type: 'collection', entry },
  };
}

const statusCases = encounterStatuses.map((status) =>
  buildCase(`status_${status.replaceAll('-', '_')}`, status));

export const fixedEncounterStatusCorpus = Object.freeze({
  schemaVersion: 1,
  scope: 'synthetic-fhir-r4-encounter-status-retrieval',
  fhirVersion: '4.0.1',
  context: 'Patient',
  expression: 'exists([Encounter]) and exact Encounter.status.value retrieval predicates',
  cases: [
    ...statusCases,
    buildCase('no_encounter', null, { present: false }),
    buildCase('foreign_subject_encounter', 'in-progress', { foreign: true }),
  ],
});

export function validateEncounterStatusCorpus(value) {
  assert.deepStrictEqual(
    value,
    fixedEncounterStatusCorpus,
    'unexpected fixed synthetic FHIR Encounter status corpus',
  );
  return value;
}

export function scopeEncounterStatusBundle(bundle, patientContextId) {
  const testCase = fixedEncounterStatusCorpus.cases.find((candidate) =>
    candidate.patientContextId === patientContextId &&
    isDeepStrictEqual(candidate.bundle, bundle));
  if (!testCase || bundle?.resourceType !== 'Bundle' || bundle.type !== 'collection' ||
      !Array.isArray(bundle.entry)) {
    throw new Error('encounter_status_bundle_outside_fixed_synthetic_r4_contract');
  }
  const patient = bundle.entry[0]?.resource;
  if (patient?.resourceType !== 'Patient' || patient.id !== patientContextId) {
    throw new Error('encounter_status_patient_context_mismatch');
  }
  const resources = bundle.entry.map((entry) => entry?.resource);
  const encounters = resources.filter((resource) => resource?.resourceType === 'Encounter');
  if (resources.length < 1 || resources.length > 2 ||
      resources.some((resource) => !resource || !['Patient', 'Encounter'].includes(resource.resourceType)) ||
      encounters.length > 1) {
    throw new Error('encounter_status_resource_set_outside_fixed_contract');
  }
  const retained = encounters.filter((encounter) =>
    encounter.subject?.reference === `Patient/${patientContextId}`);
  return {
    bundle: {
      resourceType: 'Bundle',
      type: 'collection',
      entry: [{ resource: patient }, ...retained.map((resource) => ({ resource }))],
    },
    foreignEncountersDropped: encounters.length - retained.length,
  };
}

export const encounterStatusCqlSource = [
  "library ParkinSUM_FHIR_Encounter_Status_Retrieval version '1.0.0'",
  "using FHIR version '4.0.1'",
  'context Patient',
  'define HasAnyEncounter: exists([Encounter])',
  ...encounterStatuses.map((status) =>
    `define HasStatus${pascalCase(status)}: exists([Encounter] E where E.status.value = '${status}')`),
  '',
].join('\n');
