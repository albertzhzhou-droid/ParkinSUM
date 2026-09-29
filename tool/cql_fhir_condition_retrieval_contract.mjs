import { isDeepStrictEqual } from 'node:util';

export const conditionCqlSource = [
  "library ParkinSUM_FHIR_Condition_Retrieval version '1.0.0'",
  "using FHIR version '4.0.1'",
  'context Patient',
  'define HasCondition: exists([Condition])',
].join('\n');

export const conditionOutcomeKeys = ['hasCondition'];

const patientPresent = { resourceType: 'Patient', id: 'synthetic-patient-present' };
const patientEmpty = { resourceType: 'Patient', id: 'synthetic-patient-empty' };
const conditionPresent = {
  resourceType: 'Condition',
  id: 'synthetic-condition-present',
  subject: { reference: 'Patient/synthetic-patient-present' },
  code: {
    coding: [{
      system: 'urn:parkinsum:synthetic-test',
      code: 'condition-placeholder',
      display: 'Synthetic test-only placeholder',
    }],
  },
};
const conditionForeign = {
  resourceType: 'Condition',
  id: 'synthetic-condition-foreign',
  subject: { reference: 'Patient/synthetic-patient-other' },
  code: {
    coding: [{
      system: 'urn:parkinsum:synthetic-test',
      code: 'condition-placeholder',
      display: 'Synthetic test-only placeholder',
    }],
  },
};

const fixedCases = [
  {
    id: 'condition_present',
    patientContextId: patientPresent.id,
    expectedCql: 'true',
    expectedResponseErrors: [],
    expectedResponseWarnings: [],
    bundle: {
      resourceType: 'Bundle',
      type: 'collection',
      entry: [{ resource: patientPresent }, { resource: conditionPresent }],
    },
  },
  {
    id: 'condition_absent',
    patientContextId: patientEmpty.id,
    expectedCql: 'false',
    expectedResponseErrors: [],
    expectedResponseWarnings: ['criterion_not_met'],
    bundle: {
      resourceType: 'Bundle',
      type: 'collection',
      entry: [{ resource: patientEmpty }],
    },
  },
  {
    id: 'condition_foreign_patient',
    patientContextId: patientEmpty.id,
    expectedCql: 'false',
    expectedResponseErrors: [],
    expectedResponseWarnings: ['criterion_not_met'],
    bundle: {
      resourceType: 'Bundle',
      type: 'collection',
      entry: [{ resource: patientEmpty }, { resource: conditionForeign }],
    },
  },
];

export const fixedConditionCorpus = {
  schemaVersion: 2,
  scope: 'synthetic-fhir-r4-retrieval',
  fhirVersion: '4.0.1',
  context: 'Patient',
  expression: 'exists([Condition])',
  cases: fixedCases,
};

export function validateConditionCorpus(corpus) {
  if (!isDeepStrictEqual(corpus, fixedConditionCorpus)) {
    throw new Error('condition_corpus_outside_fixed_synthetic_r4_contract');
  }
  return corpus;
}

export function scopeConditionBundle(bundle, patientContextId) {
  const expectedPatient = patientContextId === patientPresent.id
    ? patientPresent
    : patientContextId === patientEmpty.id ? patientEmpty : null;
  const fixedBundle = fixedCases.some((testCase) =>
    testCase.patientContextId === patientContextId && isDeepStrictEqual(testCase.bundle, bundle));
  if (!expectedPatient || !fixedBundle || bundle?.resourceType !== 'Bundle' || bundle.type !== 'collection' ||
      !Array.isArray(bundle.entry) || bundle.entry.length < 1 || bundle.entry.length > 2) {
    throw new Error('condition_bundle_outside_fixed_synthetic_r4_contract');
  }
  const resources = bundle.entry.map((entry) => entry?.resource);
  const patients = resources.filter((resource) => resource?.resourceType === 'Patient');
  const conditions = resources.filter((resource) => resource?.resourceType === 'Condition');
  if (resources.some((resource) => !resource || !['Patient', 'Condition'].includes(resource.resourceType)) ||
      patients.length !== 1 || !isDeepStrictEqual(patients[0], expectedPatient) ||
      conditions.some((resource) => !isDeepStrictEqual(resource, conditionPresent) &&
        !isDeepStrictEqual(resource, conditionForeign))) {
    throw new Error('condition_bundle_resource_outside_fixed_synthetic_r4_contract');
  }
  const retainedConditions = conditions.filter(
    (condition) => condition.subject.reference === `Patient/${patientContextId}`,
  );
  return {
    bundle: {
      resourceType: 'Bundle',
      type: 'collection',
      entry: [
        { resource: patients[0] },
        ...retainedConditions.map((resource) => ({ resource })),
      ],
    },
    foreignConditionsDropped: conditions.length - retainedConditions.length,
  };
}
