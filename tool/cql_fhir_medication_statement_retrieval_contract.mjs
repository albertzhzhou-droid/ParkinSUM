import assert from 'node:assert/strict';

const statementCase = ({ id, patientId, statementId, status, subjectId, outcomes }) => {
  const entries = [{ resource: { resourceType: 'Patient', id: patientId } }];
  if (statementId !== null) {
    entries.push({
      resource: {
        resourceType: 'MedicationStatement',
        id: statementId,
        status,
        medicationCodeableConcept: { text: 'Synthetic medication placeholder' },
        subject: { reference: `Patient/${subjectId}` },
      },
    });
  }
  return {
    id,
    patientContextId: patientId,
    expectedOutcomes: outcomes,
    bundle: { resourceType: 'Bundle', type: 'collection', entry: entries },
  };
};

const outcomes = ({
  any = true,
  active = false,
  stopped = false,
  unknown = false,
  notTaken = false,
  completed = false,
  enteredInError = false,
  intended = false,
  onHold = false,
} = {}) => ({
  hasAnyStatement: any,
  hasActiveStatement: active,
  hasStoppedStatement: stopped,
  hasUnknownStatement: unknown,
  hasNotTakenStatement: notTaken,
  hasCompletedStatement: completed,
  hasEnteredInErrorStatement: enteredInError,
  hasIntendedStatement: intended,
  hasOnHoldStatement: onHold,
});

export const fixedMedicationStatementCorpus = {
  schemaVersion: 1,
  scope: 'synthetic-fhir-r4-medication-statement-retrieval',
  fhirVersion: '4.0.1',
  context: 'Patient',
  expression: 'exists([MedicationStatement]) and exact status.value retrieval predicates',
  cases: [
    statementCase({
      id: 'active_statement',
      patientId: 'synthetic-patient-active',
      statementId: 'synthetic-medication-statement-active',
      status: 'active',
      subjectId: 'synthetic-patient-active',
      outcomes: outcomes({ active: true }),
    }),
    statementCase({
      id: 'completed_statement',
      patientId: 'synthetic-patient-completed',
      statementId: 'synthetic-medication-statement-completed',
      status: 'completed',
      subjectId: 'synthetic-patient-completed',
      outcomes: outcomes({ completed: true }),
    }),
    statementCase({
      id: 'entered_in_error_statement',
      patientId: 'synthetic-patient-entered-in-error',
      statementId: 'synthetic-medication-statement-entered-in-error',
      status: 'entered-in-error',
      subjectId: 'synthetic-patient-entered-in-error',
      outcomes: outcomes({ enteredInError: true }),
    }),
    statementCase({
      id: 'intended_statement',
      patientId: 'synthetic-patient-intended',
      statementId: 'synthetic-medication-statement-intended',
      status: 'intended',
      subjectId: 'synthetic-patient-intended',
      outcomes: outcomes({ intended: true }),
    }),
    statementCase({
      id: 'stopped_statement',
      patientId: 'synthetic-patient-stopped',
      statementId: 'synthetic-medication-statement-stopped',
      status: 'stopped',
      subjectId: 'synthetic-patient-stopped',
      outcomes: outcomes({ stopped: true }),
    }),
    statementCase({
      id: 'unknown_statement',
      patientId: 'synthetic-patient-unknown',
      statementId: 'synthetic-medication-statement-unknown',
      status: 'unknown',
      subjectId: 'synthetic-patient-unknown',
      outcomes: outcomes({ unknown: true }),
    }),
    statementCase({
      id: 'not_taken_statement',
      patientId: 'synthetic-patient-not-taken',
      statementId: 'synthetic-medication-statement-not-taken',
      status: 'not-taken',
      subjectId: 'synthetic-patient-not-taken',
      outcomes: outcomes({ notTaken: true }),
    }),
    statementCase({
      id: 'on_hold_statement',
      patientId: 'synthetic-patient-on-hold',
      statementId: 'synthetic-medication-statement-on-hold',
      status: 'on-hold',
      subjectId: 'synthetic-patient-on-hold',
      outcomes: outcomes({ onHold: true }),
    }),
    statementCase({
      id: 'no_statement',
      patientId: 'synthetic-patient-empty',
      statementId: null,
      status: null,
      subjectId: null,
      outcomes: outcomes({ any: false }),
    }),
    statementCase({
      id: 'foreign_subject_statement',
      patientId: 'synthetic-patient-isolation',
      statementId: 'synthetic-medication-statement-foreign',
      status: 'active',
      subjectId: 'synthetic-patient-other',
      outcomes: outcomes({ any: false }),
    }),
  ],
};

export const medicationStatementCqlSource = [
  "library ParkinSUM_FHIR_MedicationStatement_Retrieval version '1.0.0'",
  "using FHIR version '4.0.1'",
  'context Patient',
  'define HasAnyStatement: exists([MedicationStatement])',
  "define HasActiveStatement: exists([MedicationStatement] MS where MS.status.value = 'active')",
  "define HasStoppedStatement: exists([MedicationStatement] MS where MS.status.value = 'stopped')",
  "define HasUnknownStatement: exists([MedicationStatement] MS where MS.status.value = 'unknown')",
  "define HasNotTakenStatement: exists([MedicationStatement] MS where MS.status.value = 'not-taken')",
  "define HasCompletedStatement: exists([MedicationStatement] MS where MS.status.value = 'completed')",
  "define HasEnteredInErrorStatement: exists([MedicationStatement] MS where MS.status.value = 'entered-in-error')",
  "define HasIntendedStatement: exists([MedicationStatement] MS where MS.status.value = 'intended')",
  "define HasOnHoldStatement: exists([MedicationStatement] MS where MS.status.value = 'on-hold')",
  '',
].join('\n');

export const medicationStatementResultNames = Object.freeze([
  'HasAnyStatement',
  'HasActiveStatement',
  'HasStoppedStatement',
  'HasUnknownStatement',
  'HasNotTakenStatement',
  'HasCompletedStatement',
  'HasEnteredInErrorStatement',
  'HasIntendedStatement',
  'HasOnHoldStatement',
]);

const syntheticIdPattern = /^synthetic-[a-z0-9-]{1,60}$/;
const supportedStatuses = new Set([
  'active', 'completed', 'entered-in-error', 'intended', 'stopped', 'on-hold', 'unknown', 'not-taken',
]);

function requireExactKeys(value, keys, label) {
  assert.ok(value !== null && typeof value === 'object' && !Array.isArray(value), `${label}_shape`);
  assert.deepEqual(Object.keys(value).sort(), [...keys].sort(), `${label}_keys`);
}

function requireSyntheticId(value, label) {
  assert.equal(typeof value, 'string', `${label}_id_type`);
  assert.match(value, syntheticIdPattern, `${label}_id`);
}

export function validateMedicationStatementCorpus(value) {
  assert.deepStrictEqual(
    value,
    fixedMedicationStatementCorpus,
    'unexpected fixed synthetic FHIR MedicationStatement corpus',
  );
  return value;
}

export function scopeMedicationStatementBundle(bundle, patientContextId) {
  requireSyntheticId(patientContextId, 'patient_context');
  requireExactKeys(bundle, ['resourceType', 'type', 'entry'], 'bundle');
  assert.equal(bundle.resourceType, 'Bundle', 'bundle_resource_type');
  assert.equal(bundle.type, 'collection', 'bundle_type');
  assert.ok(Array.isArray(bundle.entry), 'bundle_entries');
  assert.ok(bundle.entry.length >= 1 && bundle.entry.length <= 2, 'bundle_entry_count');

  const ids = new Set();
  const patientEntries = [];
  const statementEntries = [];
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
    if (resource.resourceType !== 'MedicationStatement') throw new Error('unsupported_resource_type');
    requireExactKeys(
      resource,
      ['resourceType', 'id', 'status', 'medicationCodeableConcept', 'subject'],
      `medication_statement_${index}`,
    );
    requireSyntheticId(resource.id, `medication_statement_${index}`);
    if (!supportedStatuses.has(resource.status)) throw new Error('medication_statement_status');
    requireExactKeys(
      resource.medicationCodeableConcept,
      ['text'],
      `medication_statement_${index}_medication`,
    );
    assert.equal(
      resource.medicationCodeableConcept.text,
      'Synthetic medication placeholder',
      'medication_placeholder',
    );
    requireExactKeys(resource.subject, ['reference'], `medication_statement_${index}_subject`);
    const match = /^Patient\/(synthetic-[a-z0-9-]{1,60})$/.exec(resource.subject.reference ?? '');
    if (!match) throw new Error('medication_statement_subject_reference');
    statementEntries.push(entry);
    if (ids.has(resource.id)) throw new Error('duplicate_resource_id');
    ids.add(resource.id);
  }
  if (patientEntries.length !== 1 || bundle.entry[0] !== patientEntries[0]) {
    throw new Error('bundle_patient_count_or_order');
  }
  if (statementEntries.length > 1 || (statementEntries.length === 1 && bundle.entry[1] !== statementEntries[0])) {
    throw new Error('bundle_medication_statement_count_or_order');
  }

  const entries = [...patientEntries];
  let foreignStatementsDropped = 0;
  for (const entry of statementEntries) {
    if (entry.resource.subject.reference !== `Patient/${patientContextId}`) {
      foreignStatementsDropped += 1;
    } else {
      entries.push(entry);
    }
  }
  return {
    bundle: { resourceType: 'Bundle', type: 'collection', entry: entries },
    foreignStatementsDropped,
  };
}
