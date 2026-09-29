import assert from 'node:assert/strict';

export const medicationAdministrationStatuses = Object.freeze([
  'in-progress',
  'not-done',
  'on-hold',
  'completed',
  'entered-in-error',
  'stopped',
  'unknown',
]);

const pascalCase = (value) => value
  .split(/[^A-Za-z0-9]+/)
  .filter(Boolean)
  .map((part) => part[0].toUpperCase() + part.slice(1))
  .join('');

export const medicationAdministrationOutcomeKeys = Object.freeze([
  'hasAnyAdministration',
  ...medicationAdministrationStatuses.map((status) => 'hasStatus' + pascalCase(status)),
]);

function buildOutcomes(status, visible) {
  return Object.fromEntries([
    ['hasAnyAdministration', visible],
    ...medicationAdministrationStatuses.map((value) => [
      'hasStatus' + pascalCase(value),
      visible && status === value,
    ]),
  ]);
}

function administrationCase(id, status, { present = true, foreign = false } = {}) {
  const suffix = id.replaceAll('_', '-');
  const patientContextId = 'synthetic-patient-' + suffix;
  const entries = [
    { resource: { resourceType: 'Patient', id: patientContextId } },
  ];
  if (present) {
    entries.push({
      resource: {
        resourceType: 'MedicationAdministration',
        id: 'synthetic-ma-' + suffix,
        status,
        medicationCodeableConcept: { text: 'Synthetic medication placeholder' },
        subject: {
          reference: 'Patient/' + (foreign ? 'synthetic-patient-other' : patientContextId),
        },
        effectiveDateTime: '2026-01-15T12:00:00Z',
      },
    });
  }
  return {
    id,
    patientContextId,
    expectedOutcomes: buildOutcomes(status, present && !foreign),
    bundle: { resourceType: 'Bundle', type: 'collection', entry: entries },
  };
}

export const fixedMedicationAdministrationCorpus = Object.freeze({
  schemaVersion: 1,
  scope: 'synthetic-fhir-r4-medication-administration-retrieval',
  fhirVersion: '4.0.1',
  context: 'Patient',
  expression: 'exists([MedicationAdministration]) and exact status.value retrieval predicates',
  cases: [
    ...medicationAdministrationStatuses.map((status) => administrationCase(
      'status_' + status.replaceAll('-', '_') + '_administration',
      status,
    )),
    administrationCase('no_administration', null, { present: false }),
    administrationCase('foreign_subject_administration', 'in-progress', { foreign: true }),
  ],
});

export const medicationAdministrationCqlSource = [
  "library ParkinSUM_FHIR_MedicationAdministration_Retrieval version '1.0.0'",
  "using FHIR version '4.0.1'",
  'context Patient',
  'define HasAnyAdministration: exists([MedicationAdministration])',
  ...medicationAdministrationStatuses.map((status) =>
    'define HasStatus' + pascalCase(status) +
    ": exists([MedicationAdministration] MA where MA.status.value = '" + status + "')"),
  '',
].join('\n');

export function validateMedicationAdministrationCorpus(value) {
  assert.deepStrictEqual(
    value,
    fixedMedicationAdministrationCorpus,
    'unexpected fixed synthetic FHIR MedicationAdministration corpus',
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

export function scopeMedicationAdministrationBundle(bundle, patientContextId) {
  requireSyntheticId(patientContextId, 'patient_context');
  requireExactKeys(bundle, ['resourceType', 'type', 'entry'], 'bundle');
  assert.equal(bundle.resourceType, 'Bundle', 'bundle_resource_type');
  assert.equal(bundle.type, 'collection', 'bundle_type');
  assert.ok(Array.isArray(bundle.entry), 'bundle_entries');
  assert.ok(bundle.entry.length >= 1 && bundle.entry.length <= 2, 'bundle_entry_count');

  const patientEntries = [];
  const administrationEntries = [];
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
    if (resource.resourceType !== 'MedicationAdministration') throw new Error('unsupported_resource_type');
    requireExactKeys(
      resource,
      ['resourceType', 'id', 'status', 'medicationCodeableConcept', 'subject', 'effectiveDateTime'],
      'medication_administration_' + index,
    );
    requireSyntheticId(resource.id, 'medication_administration_' + index);
    assert.ok(medicationAdministrationStatuses.includes(resource.status), 'medication_administration_status');
    requireExactKeys(
      resource.medicationCodeableConcept,
      ['text'],
      'medication_administration_' + index + '_medication',
    );
    assert.equal(
      resource.medicationCodeableConcept.text,
      'Synthetic medication placeholder',
      'medication_placeholder',
    );
    requireExactKeys(resource.subject, ['reference'], 'medication_administration_' + index + '_subject');
    const match = /^Patient\/(synthetic-[a-z0-9-]{1,80})$/.exec(resource.subject.reference ?? '');
    if (!match) throw new Error('medication_administration_subject_reference');
    assert.equal(resource.effectiveDateTime, '2026-01-15T12:00:00Z', 'fixed_effective_date_time');
    administrationEntries.push(entry);
    if (ids.has(resource.id)) throw new Error('duplicate_resource_id');
    ids.add(resource.id);
  }

  if (patientEntries.length !== 1 || bundle.entry[0] !== patientEntries[0]) {
    throw new Error('bundle_patient_count_or_order');
  }
  if (administrationEntries.length > 1 ||
      (administrationEntries.length === 1 && bundle.entry[1] !== administrationEntries[0])) {
    throw new Error('bundle_medication_administration_count_or_order');
  }

  let foreignAdministrationsDropped = 0;
  const entries = [...patientEntries];
  for (const entry of administrationEntries) {
    if (entry.resource.subject.reference !== 'Patient/' + patientContextId) {
      foreignAdministrationsDropped += 1;
    } else {
      entries.push(entry);
    }
  }
  return {
    bundle: { ...bundle, entry: entries },
    foreignAdministrationsDropped,
  };
}
