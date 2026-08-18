import fs from 'node:fs';
import test, { after, afterEach, before } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const projectId = 'parkinsum-rules-semantic-test';
let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync('firestore.rules', 'utf8'),
      host: process.env.FIRESTORE_EMULATOR_HOST?.split(':')[0] ?? '127.0.0.1',
      port: Number(process.env.FIRESTORE_EMULATOR_HOST?.split(':')[1] ?? 8080),
    },
  });
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

after(async () => {
  await testEnv.cleanup();
});

function intake(overrides = {}) {
  return {
    id: 'intake_1',
    schemaVersion: 1,
    drugId: 'levodopa_100',
    takenAt: '2026-08-17T12:00:00.000Z',
    takenAtIso: '2026-08-17T12:00:00.000Z',
    dosageNote: 'one tablet',
    doseAmount: 100,
    doseUnit: 'mg',
    dosageForm: 'tablet',
    route: 'oral',
    releaseType: 'immediate',
    productSelection: {
      packId: 'pack_1',
      identifierSystem: 'DIN',
      identifierValue: '01234567',
      displayName: 'Levodopa 100 mg tablet',
      labelerName: 'Example labeler',
      strengthDisplay: '100 mg',
      packageDescription: '100 tablets',
      doseBasisIngredient: 'levodopa',
      unitQuantity: 100,
      unitLabel: 'tablet',
    },
    ...overrides,
  };
}

test('owner can create and read a fully structured intake', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  const reference = doc(alice, 'users/alice/intakes/intake_1');

  await assertSucceeds(setDoc(reference, intake()));
  await assertSucceeds(getDoc(reference));
});

test('cross-user and unauthenticated intake access is denied', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  const bob = testEnv.authenticatedContext('bob').firestore();
  const anonymous = testEnv.unauthenticatedContext().firestore();
  const path = 'users/alice/intakes/intake_1';

  await assertSucceeds(setDoc(doc(alice, path), intake()));

  await assertFails(
    setDoc(doc(bob, path), intake()),
  );
  await assertFails(getDoc(doc(bob, path)));
  await assertFails(getDocs(collection(bob, 'users/alice/intakes')));
  await assertFails(getDoc(doc(anonymous, path)));
});

test('malformed structured products, unsafe amounts, and extra fields fail closed', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  const basePath = 'users/alice/intakes';

  await assertFails(
    setDoc(doc(alice, `${basePath}/bad_product`),
      intake({
        id: 'bad_product',
        productSelection: {
          ...intake().productSelection,
          identifierValue: '',
        },
      }),
    ),
  );
  await assertFails(
    setDoc(
      doc(alice, `${basePath}/bad_amount`),
      intake({ id: 'bad_amount', doseAmount: -1 }),
    ),
  );
  await assertFails(
    setDoc(
      doc(alice, `${basePath}/extra_field`),
      intake({ id: 'extra_field', unexpected: 'not allowed' }),
    ),
  );
});

test('clinical audit is owner-bound and append-only', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  const bob = testEnv.authenticatedContext('bob').firestore();
  const reference = doc(alice, 'users/alice/clinical_audits/audit_1');

  await assertSucceeds(
    setDoc(reference, {
      type: 'meal_check',
      patient_id: 'alice',
      decision_path: 'deterministic_cdss',
    }),
  );
  await assertSucceeds(getDoc(reference));
  await assertFails(
    getDoc(doc(bob, 'users/alice/clinical_audits/audit_1')),
  );
  await assertFails(
    getDocs(collection(bob, 'users/alice/clinical_audits')),
  );
  await assertFails(updateDoc(reference, { decision_path: 'rewritten' }));
});

test('record history is owner-bound, strict, and append-only', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  const bob = testEnv.authenticatedContext('bob').firestore();
  const reference = doc(alice, 'users/alice/record_history/history_1');
  const row = {
    schema_version: 1,
    collection: 'intakes',
    record_id: 'intake_1',
    operation: 'set',
    created_at: serverTimestamp(),
  };

  await assertSucceeds(setDoc(reference, row));
  await assertSucceeds(getDoc(reference));
  await assertFails(
    getDoc(doc(bob, 'users/alice/record_history/history_1')),
  );
  await assertFails(
    getDocs(collection(bob, 'users/alice/record_history')),
  );
  await assertFails(updateDoc(reference, { operation: 'delete' }));
  await assertFails(deleteDoc(reference));
  await assertFails(
    setDoc(doc(bob, 'users/alice/record_history/history_2'), row),
  );
  await assertFails(
    setDoc(doc(alice, 'users/alice/record_history/history_3'), {
      ...row,
      collection: 'profile',
    }),
  );

  const recoverableHistoryId = `history_${'a'.repeat(64)}`;
  const beforeDigest = 'b'.repeat(64);
  const afterDigest = 'c'.repeat(64);
  const operationId = 'event_op_semantic_1';
  const revision = {
    schema_version: 1,
    history_id: recoverableHistoryId,
    operation_id: operationId,
    event_type: 'intake',
    record_id: 'intake_1',
    mutation_type: 'update',
    before_payload: { id: 'intake_1', dosageNote: 'before' },
    after_payload: { id: 'intake_1', dosageNote: 'after' },
    before_digest: beforeDigest,
    after_digest: afterDigest,
    recorded_at_utc: '2026-08-18T12:00:00.000Z',
    source: 'app_state',
    restores_history_id: null,
  };
  const recoverableRow = {
    schema_version: 1,
    collection: 'intakes',
    record_id: 'intake_1',
    operation: 'update',
    operation_id: operationId,
    before_digest: beforeDigest,
    after_digest: afterDigest,
    revision,
    created_at: serverTimestamp(),
  };
  const recoverablePath = `users/alice/record_history/${operationId}`;

  await assertSucceeds(setDoc(doc(alice, recoverablePath), recoverableRow));
  await assertSucceeds(getDoc(doc(alice, recoverablePath)));
  await assertFails(getDoc(doc(bob, recoverablePath)));
  await assertFails(getDocs(collection(bob, 'users/alice/record_history')));
  await assertFails(updateDoc(doc(alice, recoverablePath), {
    after_digest: 'd'.repeat(64),
  }));
  await assertFails(deleteDoc(doc(alice, recoverablePath)));
  await assertFails(
    setDoc(
      doc(alice, 'users/alice/record_history/event_op_wrong_document'),
      recoverableRow,
    ),
  );
  await assertFails(
    setDoc(doc(alice, 'users/alice/record_history/event_op_extra_field'), {
      ...recoverableRow,
      revision: { ...revision, unexpected: true },
    }),
  );
});

test('atomic onboarding marker is owner-bound and terminal', async () => {
  const alice = testEnv.authenticatedContext('alice').firestore();
  const bob = testEnv.authenticatedContext('bob').firestore();
  const reference = doc(alice, 'users/alice/app_meta/onboarded');
  const marker = {
    value: true,
    operation_id: `onboarding_v1_${'a'.repeat(64)}`,
    stage: 'committed',
    schema_version: 1,
    owner_uid: 'alice',
    created_at: serverTimestamp(),
    purpose: 'atomic_onboarding_commit',
  };

  await assertSucceeds(setDoc(reference, marker));
  await assertSucceeds(getDoc(reference));
  await assertFails(getDoc(doc(bob, 'users/alice/app_meta/onboarded')));
  await assertFails(getDocs(collection(bob, 'users/alice/app_meta')));
  await assertFails(
    setDoc(doc(bob, 'users/alice/app_meta/onboarded'), marker),
  );
  await assertFails(setDoc(reference, { ...marker, stage: 'prepared' }));
  await assertFails(setDoc(reference, { ...marker, owner_uid: 'bob' }));
});

test('catalog is signed-in readable and only privileged claims may write', async () => {
  const anonymous = testEnv.unauthenticatedContext().firestore();
  const alice = testEnv.authenticatedContext('alice').firestore();
  const importer = testEnv
    .authenticatedContext('importer', { cdssImporter: true })
    .firestore();
  const path = 'app_catalog/medications/rows/levodopa_100';
  const row = {
    id: 'levodopa_100',
    genericName: 'levodopa',
    brandNames: ['Example'],
    tags: ['levodopa'],
  };

  await assertFails(getDoc(doc(anonymous, path)));
  await assertSucceeds(getDoc(doc(alice, path)));
  await assertFails(setDoc(doc(alice, path), row));
  await assertSucceeds(setDoc(doc(importer, path), row));
});
