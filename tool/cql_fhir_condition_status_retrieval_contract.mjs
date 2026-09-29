import assert from 'node:assert/strict';
import { isDeepStrictEqual } from 'node:util';

const pascalCase = (value) => value
  .split(/[^A-Za-z0-9]+/)
  .filter(Boolean)
  .map((part) => part[0].toUpperCase() + part.slice(1))
  .join('');

export const conditionClinicalStatuses = Object.freeze([
  'active', 'recurrence', 'relapse', 'inactive', 'remission', 'resolved',
]);
export const conditionVerificationStatuses = Object.freeze([
  'unconfirmed', 'provisional', 'differential', 'confirmed', 'refuted', 'entered-in-error',
]);
export const conditionClinicalStatusSystem = 'http://terminology.hl7.org/CodeSystem/condition-clinical';
export const conditionVerificationStatusSystem = 'http://terminology.hl7.org/CodeSystem/condition-ver-status';
export const conditionStatusOutcomeKeys = Object.freeze([
  'hasAnyCondition',
  ...conditionClinicalStatuses.map((status) => `hasClinicalStatus${pascalCase(status)}`),
  ...conditionVerificationStatuses.map((status) => `hasVerificationStatus${pascalCase(status)}`),
]);

export const conditionStatusCases = Object.freeze([
  { id: 'clinical_active_unconfirmed', clinicalStatus: 'active', verificationStatus: 'unconfirmed' },
  { id: 'clinical_recurrence_provisional', clinicalStatus: 'recurrence', verificationStatus: 'provisional' },
  { id: 'clinical_relapse_differential', clinicalStatus: 'relapse', verificationStatus: 'differential' },
  { id: 'clinical_inactive_confirmed', clinicalStatus: 'inactive', verificationStatus: 'confirmed' },
  { id: 'clinical_remission_refuted', clinicalStatus: 'remission', verificationStatus: 'refuted' },
  { id: 'clinical_resolved_confirmed', clinicalStatus: 'resolved', verificationStatus: 'confirmed' },
  { id: 'verification_entered_in_error', clinicalStatus: null, verificationStatus: 'entered-in-error' },
  { id: 'no_condition', clinicalStatus: null, verificationStatus: null, present: false },
  { id: 'foreign_subject_condition', clinicalStatus: 'active', verificationStatus: 'confirmed', foreign: true },
]);

const expectedOutcomes = ({ clinicalStatus, verificationStatus, visible }) => Object.fromEntries([
  ['hasAnyCondition', visible],
  ...conditionClinicalStatuses.map((status) => [
    `hasClinicalStatus${pascalCase(status)}`,
    visible && clinicalStatus === status,
  ]),
  ...conditionVerificationStatuses.map((status) => [
    `hasVerificationStatus${pascalCase(status)}`,
    visible && verificationStatus === status,
  ]),
]);

const codeableConcept = (system, code) => ({ coding: [{ system, code }] });

function statusCase(definition) {
  const suffix = definition.id.replaceAll('_', '-');
  const patientContextId = `synthetic-patient-${suffix}`;
  const present = definition.present !== false;
  const entries = [{ resource: { resourceType: 'Patient', id: patientContextId } }];
  if (present) {
    const condition = {
      resourceType: 'Condition',
      id: `synthetic-condition-${suffix}`,
      verificationStatus: codeableConcept(conditionVerificationStatusSystem, definition.verificationStatus),
      subject: {
        reference: `Patient/${definition.foreign ? 'synthetic-patient-other' : patientContextId}`,
      },
    };
    if (definition.clinicalStatus !== null) {
      condition.clinicalStatus = codeableConcept(conditionClinicalStatusSystem, definition.clinicalStatus);
    }
    entries.push({ resource: condition });
  }
  return {
    id: definition.id,
    patientContextId,
    expectedOutcomes: expectedOutcomes({
      clinicalStatus: definition.clinicalStatus,
      verificationStatus: definition.verificationStatus,
      visible: present && definition.foreign !== true,
    }),
    bundle: { resourceType: 'Bundle', type: 'collection', entry: entries },
  };
}

export const fixedConditionStatusCorpus = Object.freeze({
  schemaVersion: 1,
  scope: 'synthetic-fhir-r4-condition-status-retrieval',
  fhirVersion: '4.0.1',
  context: 'Patient',
  expression: 'exists([Condition]) + clinicalStatus and verificationStatus coding predicates',
  cases: conditionStatusCases.map(statusCase),
});

export const conditionStatusCqlSource = [
  "library ParkinSUM_FHIR_Condition_Status_Retrieval version '1.0.0'",
  "using FHIR version '4.0.1'",
  'context Patient',
  'define HasAnyCondition: exists([Condition])',
  ...conditionClinicalStatuses.map((status) =>
    `define HasClinicalStatus${pascalCase(status)}: exists([Condition] C where exists(C.clinicalStatus.coding X where X.code.value = '${status}'))`),
  ...conditionVerificationStatuses.map((status) =>
    `define HasVerificationStatus${pascalCase(status)}: exists([Condition] C where exists(C.verificationStatus.coding X where X.code.value = '${status}'))`),
  '',
].join('\n');

export function validateConditionStatusCorpus(value) {
  assert.deepStrictEqual(value, fixedConditionStatusCorpus, 'unexpected fixed synthetic FHIR Condition status corpus');
  return value;
}

export function scopeConditionStatusBundle(bundle, patientContextId) {
  const allowedBundle = fixedConditionStatusCorpus.cases.some((testCase) =>
    testCase.patientContextId === patientContextId && isDeepStrictEqual(testCase.bundle, bundle));
  if (!allowedBundle || bundle?.resourceType !== 'Bundle' || bundle.type !== 'collection' ||
      !Array.isArray(bundle.entry)) {
    throw new Error('condition_status_bundle_outside_fixed_synthetic_r4_contract');
  }
  const patient = bundle.entry[0]?.resource;
  if (patient?.resourceType !== 'Patient' || patient.id !== patientContextId) {
    throw new Error('condition_status_patient_context_mismatch');
  }
  const resources = bundle.entry.map((entry) => entry?.resource);
  const conditions = resources.filter((resource) => resource?.resourceType === 'Condition');
  if (resources.length < 1 || resources.length > 2 ||
      resources.some((resource) => !resource || !['Patient', 'Condition'].includes(resource.resourceType)) ||
      conditions.length > 1) {
    throw new Error('condition_status_resource_set_outside_fixed_contract');
  }
  const retained = conditions.filter((condition) =>
    condition.subject?.reference === `Patient/${patientContextId}`);
  return {
    bundle: {
      resourceType: 'Bundle',
      type: 'collection',
      entry: [{ resource: patient }, ...retained.map((resource) => ({ resource }))],
    },
    foreignConditionsDropped: conditions.length - retained.length,
  };
}
