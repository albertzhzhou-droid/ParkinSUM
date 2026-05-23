#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const args = parseArgs(process.argv.slice(2));
const command = args._[0];
const environment = normalizeEnvironment(args.env ?? process.env.PARKINSUM_ENV ?? 'stage');
const projectId =
  args.project ??
  process.env.PARKINSUM_FIREBASE_PROJECT_ID ??
  process.env.FIREBASE_PROJECT_ID ??
  defaultProjectForEnvironment(environment);
const operator = args.operator ?? process.env.USER ?? 'unknown_operator';
const dryRun = !args.execute;
const auditLogPath =
  args['audit-log'] ?? 'build/operator_audit/operator_audit.jsonl';

if (!command || args.help) {
  usage();
  process.exit(command ? 0 : 2);
}

try {
  let result;
  switch (command) {
    case 'claims':
      result = await runClaims();
      break;
    case 'user-export':
      result = await runUserExport();
      break;
    case 'user-delete':
      result = await runUserDelete();
      break;
    case 'user-write-probe':
      result = await runUserWriteProbe();
      break;
    case 'backup-command':
      result = await runBackupCommand();
      break;
    default:
      throw new Error(`Unknown command: ${command}`);
  }
  writeAudit({
    action: command,
    environment,
    projectId,
    uid: args.uid ?? null,
    operator,
    dryRun,
    result,
  });
  console.log(JSON.stringify(result, null, 2));
} catch (error) {
  writeAudit({
    action: command ?? 'unknown',
    environment,
    projectId,
    uid: args.uid ?? null,
    operator,
    dryRun,
    error: error.message,
  });
  console.error(error.message);
  process.exit(1);
}

function usage() {
  console.log(`Usage:
  node tool/firebase_ops.mjs claims --uid <uid> --claim admin|cdssImporter --mode set|clear [--env stage] [--project <id>] [--execute --confirm <uid> --confirm-project <id>]
  node tool/firebase_ops.mjs user-export --uid <uid> [--output build/user_exports/<uid>.json] [--execute --confirm <uid> --confirm-project <id>]
  node tool/firebase_ops.mjs user-write-probe --uid <uid> [--execute --confirm <uid> --confirm-project <id>]
  node tool/firebase_ops.mjs user-delete --uid <uid> [--delete-auth] [--execute --confirm <uid> --confirm-project <id>]
  node tool/firebase_ops.mjs backup-command --release-id <id> --bucket gs://<bucket/path> [--env prod] [--project <id>]

Defaults:
  All privileged or destructive commands are dry-run unless --execute is passed.
  Execute mode requires --confirm <uid> for uid-scoped commands and --confirm-project <projectId>.
  Credentials are loaded by firebase-admin from ADC or GOOGLE_APPLICATION_CREDENTIALS.
`);
}

async function runClaims() {
  const uid = required(args.uid, '--uid');
  const claim = required(args.claim, '--claim');
  const mode = required(args.mode, '--mode');
  if (!['admin', 'cdssImporter'].includes(claim)) {
    throw new Error('--claim must be admin or cdssImporter');
  }
  if (!['set', 'clear'].includes(mode)) {
    throw new Error('--mode must be set or clear');
  }
  requireUidConfirmation(uid);
  requireProjectConfirmation();

  const desiredValue = mode === 'set';
  const summary = {
    command: 'claims',
    environment,
    projectId,
    uid,
    claim,
    mode,
    dryRun,
  };
  if (dryRun) return summary;

  const { auth } = await adminClients();
  const user = await auth.getUser(uid);
  const currentClaims = user.customClaims ?? {};
  const nextClaims = { ...currentClaims };
  if (desiredValue) {
    nextClaims[claim] = true;
  } else {
    delete nextClaims[claim];
  }
  await auth.setCustomUserClaims(uid, nextClaims);
  return {
    ...summary,
    previousClaims: maskClaims(currentClaims),
    nextClaims: maskClaims(nextClaims),
  };
}

async function runUserExport() {
  const uid = required(args.uid, '--uid');
  const output =
    args.output ?? path.join('build', 'user_exports', `${safeSegment(uid)}.json`);
  requireUidConfirmation(uid);
  requireProjectConfirmation();

  const summary = {
    command: 'user-export',
    environment,
    projectId,
    uid,
    output,
    scope: `users/${uid}`,
    dryRun,
  };
  if (dryRun) return summary;

  const { firestore } = await adminClients();
  const data = await exportDocumentTree(firestore.doc(`users/${uid}`));
  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.writeFileSync(
    output,
    `${JSON.stringify({
      projectId,
      environment,
      uid,
      exportedAt: new Date().toISOString(),
      scope: `users/${uid}`,
      data,
    }, null, 2)}\n`,
  );
  return {
    ...summary,
    documents: countExportedDocuments(data),
  };
}

async function runUserWriteProbe() {
  const uid = required(args.uid, '--uid');
  const runId = args['run-id'] ?? `user_rights_${Date.now()}`;
  requireUidConfirmation(uid);
  requireProjectConfirmation();

  const summary = {
    command: 'user-write-probe',
    environment,
    projectId,
    uid,
    path: `users/${uid}/app_meta/${runId}`,
    dryRun,
  };
  if (dryRun) return summary;

  const { firestore } = await adminClients();
  await firestore.doc(`users/${uid}/app_meta/${runId}`).set({
    probe_run_id: runId,
    created_at: new Date().toISOString(),
    purpose: 'P0 user data export/delete drill',
  });
  return {
    ...summary,
    written: true,
  };
}

async function runUserDelete() {
  const uid = required(args.uid, '--uid');
  const deleteAuth = Boolean(args['delete-auth']);
  requireUidConfirmation(uid);
  requireProjectConfirmation();

  const summary = {
    command: 'user-delete',
    environment,
    projectId,
    uid,
    firestoreScope: `users/${uid}`,
    deleteAuth,
    dryRun,
  };
  if (dryRun) return summary;

  const { auth, firestore } = await adminClients();
  const deletedFirestoreDocuments = await deleteDocumentTree(
    firestore.doc(`users/${uid}`),
  );
  let authDeleted = false;
  if (deleteAuth) {
    await auth.deleteUser(uid);
    authDeleted = true;
  }
  return {
    ...summary,
    deletedFirestoreDocuments,
    authDeleted,
  };
}

async function runBackupCommand() {
  const releaseId = required(args['release-id'], '--release-id');
  const bucket = required(args.bucket, '--bucket');
  if (!bucket.startsWith('gs://')) {
    throw new Error('--bucket must start with gs://');
  }
  const normalizedBucket = bucket.replace(/\/+$/, '');
  const exportPath = `${normalizedBucket}/parkinsum/${safeSegment(releaseId)}`;
  const firebaseCommand =
    `firebase firestore:export ${exportPath} --project ${projectId}`;
  return {
    command: 'backup-command',
    environment,
    projectId,
    releaseId,
    exportPath,
    firebaseCommand,
    dryRun: true,
  };
}

async function adminClients() {
  const [{ initializeApp, getApps, applicationDefault }, { getAuth }, { getFirestore }] =
    await Promise.all([
      import('firebase-admin/app'),
      import('firebase-admin/auth'),
      import('firebase-admin/firestore'),
    ]);
  const app = getApps()[0] ?? initializeApp({
    credential: applicationDefault(),
    projectId,
  });
  return {
    auth: getAuth(app),
    firestore: getFirestore(app),
  };
}

async function exportDocumentTree(docRef) {
  const snap = await docRef.get();
  const collections = await docRef.listCollections();
  const childCollections = {};
  for (const collection of collections) {
    const childDocs = await collection.get();
    childCollections[collection.id] = {};
    for (const childDoc of childDocs.docs) {
      childCollections[collection.id][childDoc.id] = await exportDocumentTree(
        childDoc.ref,
      );
    }
  }
  return {
    path: docRef.path,
    exists: snap.exists,
    data: snap.exists ? snap.data() : null,
    collections: childCollections,
  };
}

async function deleteDocumentTree(docRef) {
  let deleted = 0;
  const collections = await docRef.listCollections();
  for (const collection of collections) {
    const childDocs = await collection.get();
    for (const childDoc of childDocs.docs) {
      deleted += await deleteDocumentTree(childDoc.ref);
    }
  }
  const snap = await docRef.get();
  if (snap.exists) {
    await docRef.delete();
    deleted += 1;
  }
  return deleted;
}

function countExportedDocuments(node) {
  let count = node.exists ? 1 : 0;
  for (const collection of Object.values(node.collections ?? {})) {
    for (const child of Object.values(collection)) {
      count += countExportedDocuments(child);
    }
  }
  return count;
}

function requireUidConfirmation(uid) {
  if (dryRun) return;
  if (args.confirm !== uid) {
    throw new Error(`Execute mode requires --confirm ${uid}`);
  }
}

function requireProjectConfirmation() {
  if (dryRun) return;
  if (args['confirm-project'] !== projectId) {
    throw new Error(`Execute mode requires --confirm-project ${projectId}`);
  }
}

function writeAudit(record) {
  const entry = {
    timestamp: new Date().toISOString(),
    environment,
    projectId,
    operator,
    ...record,
  };
  fs.mkdirSync(path.dirname(auditLogPath), { recursive: true });
  fs.appendFileSync(auditLogPath, `${JSON.stringify(entry)}\n`);
}

function maskClaims(claims) {
  return {
    admin: claims.admin === true,
    cdssImporter: claims.cdssImporter === true,
  };
}

function parseArgs(argv) {
  const parsed = { _: [] };
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith('--')) {
      parsed._.push(token);
      continue;
    }
    const key = token.slice(2);
    const next = argv[i + 1];
    if (next == null || next.startsWith('--')) {
      parsed[key] = true;
    } else {
      parsed[key] = next;
      i += 1;
    }
  }
  return parsed;
}

function required(value, flag) {
  if (value == null || value === true || String(value).trim() === '') {
    throw new Error(`${flag} is required`);
  }
  return String(value).trim();
}

function normalizeEnvironment(value) {
  const normalized = String(value).trim().toLowerCase();
  if (!['dev', 'stage', 'prod'].includes(normalized)) {
    throw new Error(`Invalid environment: ${value}. Use dev, stage, or prod.`);
  }
  return normalized;
}

function defaultProjectForEnvironment(env) {
  if (env === 'dev') return 'parkinsum-companion-dev';
  if (env === 'stage') return 'parkinsum-companion-stage';
  return 'parkinsum-companion';
}

function safeSegment(value) {
  return String(value).replace(/[^a-zA-Z0-9._-]/g, '_');
}
