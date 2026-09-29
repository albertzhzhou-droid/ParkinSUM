import assert from 'node:assert/strict';

export const allergyIntoleranceClinicalStatuses = Object.freeze([
  'active',
  'inactive',
  'resolved',
]);

export const allergyIntoleranceVerificationStatuses = Object.freeze([
  'unconfirmed',
  'confirmed',
  'refuted',
  'entered-in-error',
]);

export const allergyIntoleranceClinicalStatusSystem =
  'http://terminology.hl7.org/CodeSystem/allergyintolerance-clinical';
export const allergyIntoleranceVerificationStatusSystem =
  'http://terminology.hl7.org/CodeSystem/allergyintolerance-verification';

const pascalCase = (value) => value
  .split(/[^A-Za-z0-9]+/)
  .filter(Boolean)
  .map((part) => part[0].toUpperCase() + part.slice(1))
  .join('');

export const allergyIntoleranceOutcomeKeys = Object.freeze([
  'hasAnyAllergyIntolerance',
  ...allergyIntoleranceClinicalStatuses.map((status) => 'hasClinicalStatus' + pascalCase(status)),
  ...allergyIntoleranceVerificationStatuses.map((status) => 'hasVerificationStatus' + pascalCase(status)),
]);

function buildOutcomes(clinicalStatus, verificationStatus, visible) {
  return Object.fromEntries([
    ['hasAnyAllergyIntolerance', visible],
    ...allergyIntoleranceClinicalStatuses.map((status) => [
      'hasClinicalStatus' + pascalCase(status),
      visible && clinicalStatus === status,
    ]),
    ...allergyIntoleranceVerificationStatuses.map((status) => [
      'hasVerificationStatus' + pascalCase(status),
      visible && verificationStatus === status,
    ]),
  ]);
}

function codeableConcept(system, code) {
  return { coding: [{ system, code }] };
}

function allergyCase(id, clinicalStatus, verificationStatus, { present = true, foreign = false } = {}) {
  const suffix = id.replaceAll('_', '-');
  const patientContextId = 'synthetic-patient-' + suffix;
  const entries = [
    { resource: { resourceType: 'Patient', id: patientContextId } },
  ];
  if (present) {
    const resource = {
      resourceType: 'AllergyIntolerance',
      id: 'synthetic-ai-' + suffix,
      verificationStatus: codeableConcept(allergyIntoleranceVerificationStatusSystem, verificationStatus),
      patient: {
        reference: 'Patient/' + (foreign ? 'synthetic-patient-other' : patientContextId),
      },
    };
    if (clinicalStatus !== null) {
      resource.clinicalStatus = codeableConcept(allergyIntoleranceClinicalStatusSystem, clinicalStatus);
    }
    entries.push({ resource });
  }
  return {
    id,
    patientContextId,
    expectedOutcomes: buildOutcomes(clinicalStatus, verificationStatus, present && !foreign),
    bundle: { resourceType: 'Bundle', type: 'collection', entry: entries },
  };
}

export const fixedAllergyIntoleranceCorpus = Object.freeze({
  schemaVersion: 1,
  scope: 'synthetic-fhir-r4-allergy-intolerance-retrieval',
  fhirVersion: '4.0.1',
  context: 'Patient',
  expression: 'exists([AllergyIntolerance]) + clinicalStatus and verificationStatus coding predicates',
  cases: [
    allergyCase('clinical_active_unconfirmed', 'active', 'unconfirmed'),
    allergyCase('clinical_inactive_confirmed', 'inactive', 'confirmed'),
    allergyCase('clinical_resolved_refuted', 'resolved', 'refuted'),
    allergyCase('verification_entered_in_error', null, 'entered-in-error'),
    allergyCase('no_allergy_intolerance', null, null, { present: false }),
    allergyCase('foreign_subject_allergy_intolerance', 'active', 'confirmed', { foreign: true }),
  ],
});

export const allergyIntoleranceCqlSource = [
  "library ParkinSUM_FHIR_AllergyIntolerance_Retrieval version '1.0.0'",
  "using FHIR version '4.0.1'",
  'context Patient',
  'define HasAnyAllergyIntolerance: exists([AllergyIntolerance])',
  ...allergyIntoleranceClinicalStatuses.map((status) =>
    'define HasClinicalStatus' + pascalCase(status) +
    ": exists([AllergyIntolerance] AI where exists(AI.clinicalStatus.coding C where C.code.value = '" + status + "'))"),
  ...allergyIntoleranceVerificationStatuses.map((status) =>
    'define HasVerificationStatus' + pascalCase(status) +
    ": exists([AllergyIntolerance] AI where exists(AI.verificationStatus.coding C where C.code.value = '" + status + "'))"),
  '',
].join('\n');

export function validateAllergyIntoleranceCorpus(value) {
  assert.deepStrictEqual(
    value,
    fixedAllergyIntoleranceCorpus,
    'unexpected fixed synthetic FHIR AllergyIntolerance corpus',
  );
  return value;
}

const syntheticIdPattern = /^synthetic-[a-z0-9-]{1,80}$/;

function requireExactKeys(value, keys, label) {
  assert.ok(value !== null && typeof value === 'object' && !Array.isArray(value), label + '_shape');
  assert.deepEqual(Object.keys(value).sort(), [...keys].sort(), label + '_keys');
}

function requireSyntheticId(value, label) {
  assert.equal(typeof value, 'string', label + '_id_type');
  assert.match(value, syntheticIdPattern, label + '_id');
}

function validateStatusConcept(value, system, statuses, label) {
  requireExactKeys(value, ['coding'], label);
  assert.ok(Array.isArray(value.coding) && value.coding.length === 1, label + '_coding_count');
  requireExactKeys(value.coding[0], ['system', 'code'], label + '_coding');
  assert.equal(value.coding[0].system, system, label + '_system');
  assert.ok(statuses.includes(value.coding[0].code), label + '_code');
}

export function scopeAllergyIntoleranceBundle(bundle, patientContextId) {
  requireSyntheticId(patientContextId, 'patient_context');
  requireExactKeys(bundle, ['resourceType', 'type', 'entry'], 'bundle');
  assert.equal(bundle.resourceType, 'Bundle', 'bundle_resource_type');
  assert.equal(bundle.type, 'collection', 'bundle_type');
  assert.ok(Array.isArray(bundle.entry), 'bundle_entries');
  assert.ok(bundle.entry.length === 1 || bundle.entry.length === 2, 'bundle_entry_count');

  const patientEntries = [];
  const allergyEntries = [];
  const ids = new Set();
  for (const [index, entry] of bundle.entry.entries()) {
    requireExactKeys(entry, ['resource'], 'entry_' + index);
    const resource = entry.resource;
    assert.ok(resource !== null && typeof resource === 'object' && !Array.isArray(resource), 'resource_' + index);
    if (resource.resourceType === 'Patient') {
      requireExactKeys(resource, ['resourceType', 'id'], 'patient_' + index);
      requireSyntheticId(resource.id, 'patient_' + index);
      assert.equal(resource.id, patientContextId, 'patient_context_mismatch');
      patientEntries.push(entry);
      if (ids.has(resource.id)) throw new Error('duplicate_resource_id');
      ids.add(resource.id);
      continue;
    }
    if (resource.resourceType !== 'AllergyIntolerance') throw new Error('unsupported_resource_type');
    const hasClinicalStatus = Object.hasOwn(resource, 'clinicalStatus');
    requireExactKeys(
      resource,
      [
        'resourceType', 'id', 'verificationStatus', 'patient',
        ...(hasClinicalStatus ? ['clinicalStatus'] : []),
      ],
      'allergy_intolerance_' + index,
    );
    requireSyntheticId(resource.id, 'allergy_intolerance_' + index);
    validateStatusConcept(
      resource.verificationStatus,
      allergyIntoleranceVerificationStatusSystem,
      allergyIntoleranceVerificationStatuses,
      'allergy_intolerance_' + index + '_verification_status',
    );
    const verificationStatus = resource.verificationStatus.coding[0].code;
    if (verificationStatus === 'entered-in-error') {
      assert.equal(hasClinicalStatus, false, 'entered_in_error_clinical_status_absent');
    } else {
      assert.equal(hasClinicalStatus, true, 'clinical_status_required');
    }
    if (hasClinicalStatus) {
      validateStatusConcept(
        resource.clinicalStatus,
        allergyIntoleranceClinicalStatusSystem,
        allergyIntoleranceClinicalStatuses,
        'allergy_intolerance_' + index + '_clinical_status',
      );
    }
    requireExactKeys(resource.patient, ['reference'], 'allergy_intolerance_' + index + '_patient');
    const match = /^Patient\/(synthetic-[a-z0-9-]{1,80})$/.exec(resource.patient.reference ?? '');
    if (!match) throw new Error('allergy_intolerance_patient_reference');
    allergyEntries.push(entry);
    if (ids.has(resource.id)) throw new Error('duplicate_resource_id');
    ids.add(resource.id);
  }

  if (patientEntries.length !== 1 || bundle.entry[0] !== patientEntries[0]) {
    throw new Error('bundle_patient_count_or_order');
  }
  if (allergyEntries.length > 1 ||
      (allergyEntries.length === 1 && bundle.entry[1] !== allergyEntries[0])) {
    throw new Error('bundle_allergy_intolerance_count_or_order');
  }

  let foreignAllergyIntolerancesDropped = 0;
  const entries = [...patientEntries];
  for (const entry of allergyEntries) {
    if (entry.resource.patient.reference !== 'Patient/' + patientContextId) {
      foreignAllergyIntolerancesDropped += 1;
    } else {
      entries.push(entry);
    }
  }
  return {
    bundle: { ...bundle, entry: entries },
    foreignAllergyIntolerancesDropped,
  };
}
