import assert from 'node:assert/strict';

export const medicationRequestStatuses = Object.freeze([
  'active',
  'on-hold',
  'cancelled',
  'completed',
  'entered-in-error',
  'stopped',
  'draft',
  'unknown',
]);

export const medicationRequestIntents = Object.freeze([
  'proposal',
  'plan',
  'order',
  'original-order',
  'reflex-order',
  'filler-order',
  'instance-order',
  'option',
]);

const pascalCase = (value) => value
  .split(/[^A-Za-z0-9]+/)
  .filter(Boolean)
  .map((part) => part[0].toUpperCase() + part.slice(1))
  .join('');

export const medicationRequestOutcomeKeys = Object.freeze([
  'hasAnyRequest',
  ...medicationRequestStatuses.map((status) => `hasStatus${pascalCase(status)}`),
  ...medicationRequestIntents.map((intent) => `hasIntent${pascalCase(intent)}`),
]);

function buildOutcomes(status, intent, present) {
  return Object.fromEntries([
    ['hasAnyRequest', present],
    ...medicationRequestStatuses.map((value) => [
      `hasStatus${pascalCase(value)}`,
      present && status === value,
    ]),
    ...medicationRequestIntents.map((value) => [
      `hasIntent${pascalCase(value)}`,
      present && intent === value,
    ]),
  ]);
}

function requestCase(id, status, intent, { present = true, foreign = false } = {}) {
  const resourceSuffix = id.replaceAll('_', '-');
  const patientContextId = `synthetic-patient-${resourceSuffix}`;
  const entry = [
    { resource: { resourceType: 'Patient', id: patientContextId } },
  ];
  if (present) {
    entry.push({
      resource: {
        resourceType: 'MedicationRequest',
        id: `synthetic-medication-request-${resourceSuffix}`,
        status,
        intent,
        medicationCodeableConcept: { text: 'Synthetic medication placeholder' },
        subject: {
          reference: `Patient/${foreign ? 'synthetic-patient-other' : patientContextId}`,
        },
      },
    });
  }
  return {
    id,
    patientContextId,
    expectedOutcomes: buildOutcomes(status, intent, present && !foreign),
    bundle: { resourceType: 'Bundle', type: 'collection', entry },
  };
}

export const fixedMedicationRequestCorpus = Object.freeze({
  schemaVersion: 1,
  scope: 'synthetic-fhir-r4-medication-request-retrieval',
  fhirVersion: '4.0.1',
  context: 'Patient',
  expression: 'exists([MedicationRequest]) and exact status.value and intent.value retrieval predicates',
  cases: [
    ...medicationRequestStatuses.map((status) => requestCase(
      `status_${status.replaceAll('-', '_')}_request`,
      status,
      'order',
    )),
    ...medicationRequestIntents.map((intent) => requestCase(
      `intent_${intent.replaceAll('-', '_')}_request`,
      'active',
      intent,
    )),
    requestCase('no_request', null, null, { present: false }),
    requestCase('foreign_subject_request', 'active', 'order', { foreign: true }),
  ],
});

export const medicationRequestCqlSource = [
  "library ParkinSUM_FHIR_MedicationRequest_Retrieval version '1.0.0'",
  "using FHIR version '4.0.1'",
  'context Patient',
  'define HasAnyRequest: exists([MedicationRequest])',
  ...medicationRequestStatuses.map((status) =>
    `define HasStatus${pascalCase(status)}: exists([MedicationRequest] MR where MR.status.value = '${status}')`),
  ...medicationRequestIntents.map((intent) =>
    `define HasIntent${pascalCase(intent)}: exists([MedicationRequest] MR where MR.intent.value = '${intent}')`),
  '',
].join('\n');

export function validateMedicationRequestCorpus(value) {
  assert.deepStrictEqual(
    value,
    fixedMedicationRequestCorpus,
    'unexpected fixed synthetic FHIR MedicationRequest corpus',
  );
  return value;
}

const syntheticIdPattern = /^synthetic-[a-z0-9-]{1,80}$/;

function requireExactKeys(value, keys, label) {
  assert.ok(value !== null && typeof value === 'object' && !Array.isArray(value), `${label}_shape`);
  assert.deepEqual(Object.keys(value).sort(), [...keys].sort(), `${label}_keys`);
}

function requireSyntheticId(value, label) {
  assert.equal(typeof value, 'string', `${label}_id_type`);
  assert.match(value, syntheticIdPattern, `${label}_id`);
}

export function scopeMedicationRequestBundle(bundle, patientContextId) {
  requireSyntheticId(patientContextId, 'patient_context');
  requireExactKeys(bundle, ['resourceType', 'type', 'entry'], 'bundle');
  assert.equal(bundle.resourceType, 'Bundle', 'bundle_resource_type');
  assert.equal(bundle.type, 'collection', 'bundle_type');
  assert.ok(Array.isArray(bundle.entry), 'bundle_entries');
  assert.ok(bundle.entry.length >= 1 && bundle.entry.length <= 2, 'bundle_entry_count');

  const patientEntries = [];
  const requestEntries = [];
  const ids = new Set();
  for (const [index, entry] of bundle.entry.entries()) {
    requireExactKeys(entry, ['resource'], `entry_${index}`);
    const resource = entry.resource;
    assert.ok(resource !== null && typeof resource === 'object' && !Array.isArray(resource), `resource_${index}`);
    if (resource.resourceType === 'Patient') {
      requireExactKeys(resource, ['resourceType', 'id'], `patient_${index}`);
      requireSyntheticId(resource.id, `patient_${index}`);
      assert.equal(resource.id, patientContextId, 'patient_context_mismatch');
      patientEntries.push(entry);
      if (ids.has(resource.id)) throw new Error('duplicate_resource_id');
      ids.add(resource.id);
      continue;
    }
    if (resource.resourceType !== 'MedicationRequest') throw new Error('unsupported_resource_type');
    requireExactKeys(
      resource,
      ['resourceType', 'id', 'status', 'intent', 'medicationCodeableConcept', 'subject'],
      `medication_request_${index}`,
    );
    requireSyntheticId(resource.id, `medication_request_${index}`);
    assert.ok(medicationRequestStatuses.includes(resource.status), 'medication_request_status');
    assert.ok(medicationRequestIntents.includes(resource.intent), 'medication_request_intent');
    requireExactKeys(
      resource.medicationCodeableConcept,
      ['text'],
      `medication_request_${index}_medication`,
    );
    assert.equal(
      resource.medicationCodeableConcept.text,
      'Synthetic medication placeholder',
      'medication_placeholder',
    );
    requireExactKeys(resource.subject, ['reference'], `medication_request_${index}_subject`);
    const match = /^Patient\/(synthetic-[a-z0-9-]{1,80})$/.exec(resource.subject.reference ?? '');
    if (!match) throw new Error('medication_request_subject_reference');
    requestEntries.push(entry);
    if (ids.has(resource.id)) throw new Error('duplicate_resource_id');
    ids.add(resource.id);
  }

  if (patientEntries.length !== 1 || bundle.entry[0] !== patientEntries[0]) {
    throw new Error('bundle_patient_count_or_order');
  }
  if (requestEntries.length > 1 || (requestEntries.length === 1 && bundle.entry[1] !== requestEntries[0])) {
    throw new Error('bundle_medication_request_count_or_order');
  }

  let foreignRequestsDropped = 0;
  const entries = [...patientEntries];
  for (const entry of requestEntries) {
    if (entry.resource.subject.reference !== `Patient/${patientContextId}`) {
      foreignRequestsDropped += 1;
    } else {
      entries.push(entry);
    }
  }
  return {
    bundle: { ...bundle, entry: entries },
    foreignRequestsDropped,
  };
}
