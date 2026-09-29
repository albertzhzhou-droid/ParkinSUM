import assert from 'node:assert/strict';

export const medicationDispenseStatuses = Object.freeze([
  'preparation',
  'in-progress',
  'cancelled',
  'on-hold',
  'completed',
  'entered-in-error',
  'stopped',
  'declined',
  'unknown',
]);

const pascalCase = (value) => value
  .split(/[^A-Za-z0-9]+/)
  .filter(Boolean)
  .map((part) => part[0].toUpperCase() + part.slice(1))
  .join('');

export const medicationDispenseOutcomeKeys = Object.freeze([
  'hasAnyDispense',
  ...medicationDispenseStatuses.map((status) => 'hasStatus' + pascalCase(status)),
]);

function buildOutcomes(status, present) {
  return Object.fromEntries([
    ['hasAnyDispense', present],
    ...medicationDispenseStatuses.map((value) => [
      'hasStatus' + pascalCase(value),
      present && status === value,
    ]),
  ]);
}

function dispenseCase(id, status, { present = true, foreign = false } = {}) {
  const resourceSuffix = id.replaceAll('_', '-');
  const patientContextId = 'synthetic-patient-' + resourceSuffix;
  const entry = [
    { resource: { resourceType: 'Patient', id: patientContextId } },
  ];
  if (present) {
    entry.push({
      resource: {
        resourceType: 'MedicationDispense',
        id: 'synthetic-medication-dispense-' + resourceSuffix,
        status,
        medicationCodeableConcept: { text: 'Synthetic medication placeholder' },
        subject: {
          reference: 'Patient/' + (foreign ? 'synthetic-patient-other' : patientContextId),
        },
      },
    });
  }
  return {
    id,
    patientContextId,
    expectedOutcomes: buildOutcomes(status, present && !foreign),
    bundle: { resourceType: 'Bundle', type: 'collection', entry },
  };
}

export const fixedMedicationDispenseCorpus = Object.freeze({
  schemaVersion: 1,
  scope: 'synthetic-fhir-r4-medication-dispense-retrieval',
  fhirVersion: '4.0.1',
  context: 'Patient',
  expression: 'exists([MedicationDispense]) and exact status.value retrieval predicates',
  cases: [
    ...medicationDispenseStatuses.map((status) => dispenseCase(
      'status_' + status.replaceAll('-', '_') + '_dispense',
      status,
    )),
    dispenseCase('no_dispense', null, { present: false }),
    dispenseCase('foreign_subject_dispense', 'preparation', { foreign: true }),
  ],
});

export const medicationDispenseCqlSource = [
  "library ParkinSUM_FHIR_MedicationDispense_Retrieval version '1.0.0'",
  "using FHIR version '4.0.1'",
  'context Patient',
  'define HasAnyDispense: exists([MedicationDispense])',
  ...medicationDispenseStatuses.map((status) =>
    'define HasStatus' + pascalCase(status) +
    ": exists([MedicationDispense] MD where MD.status.value = '" + status + "')"),
  '',
].join('\n');

export function validateMedicationDispenseCorpus(value) {
  assert.deepStrictEqual(
    value,
    fixedMedicationDispenseCorpus,
    'unexpected fixed synthetic FHIR MedicationDispense corpus',
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

export function scopeMedicationDispenseBundle(bundle, patientContextId) {
  requireSyntheticId(patientContextId, 'patient_context');
  requireExactKeys(bundle, ['resourceType', 'type', 'entry'], 'bundle');
  assert.equal(bundle.resourceType, 'Bundle', 'bundle_resource_type');
  assert.equal(bundle.type, 'collection', 'bundle_type');
  assert.ok(Array.isArray(bundle.entry), 'bundle_entries');
  assert.ok(bundle.entry.length >= 1 && bundle.entry.length <= 2, 'bundle_entry_count');

  const patientEntries = [];
  const dispenseEntries = [];
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
    if (resource.resourceType !== 'MedicationDispense') throw new Error('unsupported_resource_type');
    requireExactKeys(
      resource,
      ['resourceType', 'id', 'status', 'medicationCodeableConcept', 'subject'],
      'medication_dispense_' + index,
    );
    requireSyntheticId(resource.id, 'medication_dispense_' + index);
    assert.ok(medicationDispenseStatuses.includes(resource.status), 'medication_dispense_status');
    requireExactKeys(
      resource.medicationCodeableConcept,
      ['text'],
      'medication_dispense_' + index + '_medication',
    );
    assert.equal(
      resource.medicationCodeableConcept.text,
      'Synthetic medication placeholder',
      'medication_placeholder',
    );
    requireExactKeys(resource.subject, ['reference'], 'medication_dispense_' + index + '_subject');
    const match = /^Patient\/(synthetic-[a-z0-9-]{1,80})$/.exec(resource.subject.reference ?? '');
    if (!match) throw new Error('medication_dispense_subject_reference');
    dispenseEntries.push(entry);
    if (ids.has(resource.id)) throw new Error('duplicate_resource_id');
    ids.add(resource.id);
  }

  if (patientEntries.length !== 1 || bundle.entry[0] !== patientEntries[0]) {
    throw new Error('bundle_patient_count_or_order');
  }
  if (dispenseEntries.length > 1 || (dispenseEntries.length === 1 && bundle.entry[1] !== dispenseEntries[0])) {
    throw new Error('bundle_medication_dispense_count_or_order');
  }

  let foreignDispensesDropped = 0;
  const entries = [...patientEntries];
  for (const entry of dispenseEntries) {
    if (entry.resource.subject.reference !== 'Patient/' + patientContextId) {
      foreignDispensesDropped += 1;
    } else {
      entries.push(entry);
    }
  }
  return {
    bundle: { ...bundle, entry: entries },
    foreignDispensesDropped,
  };
}
