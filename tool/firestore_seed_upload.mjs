#!/usr/bin/env node

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const args = parseArgs(process.argv.slice(2));
const payloadPath = args._[0] ?? 'build/firebase_seed/official_core_seed.json';
const execute = Boolean(args.execute);
const payload = JSON.parse(fs.readFileSync(payloadPath, 'utf8'));
const projectId = payload.projectId ?? 'parkinsum-companion';
const databaseId = payload.databaseId ?? '(default)';

if (!payload.documents || !Array.isArray(payload.documents)) {
  throw new Error(`Invalid payload: ${payloadPath}`);
}

console.log(`project=${projectId} database=${databaseId} documents=${payload.documents.length}`);
console.log(`snapshot=${payload.snapshotId} execute=${execute}`);
console.log(`counts=${JSON.stringify(payload.counts ?? {})}`);

if (!execute) {
  process.exit(0);
}
if (args['confirm-project'] !== projectId) {
  throw new Error(`Execute mode requires --confirm-project ${projectId}`);
}
requireSafeProjectId(projectId);
requireSafeDatabaseId(databaseId);
for (const doc of payload.documents) requireSafeDocumentPath(doc.path);
const token = loadFirebaseAccessToken();

const baseName = `projects/${projectId}/databases/${databaseId}/documents`;
const endpoint =
  `https://firestore.googleapis.com/v1/projects/${projectId}/databases/${databaseId}/documents:commit`;
const chunkSize = 400;
let committed = 0;

for (let i = 0; i < payload.documents.length; i += chunkSize) {
  const chunk = payload.documents.slice(i, i + chunkSize);
  const writes = chunk.map((doc) => ({
    update: {
      name: `${baseName}/${doc.path}`,
      fields: toFirestoreFields({
        ...doc.data,
        _synced_at_ms: Date.now(),
      }),
    },
  }));
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${token}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({ writes }),
  });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Firestore commit failed ${response.status}: ${body}`);
  }
  committed += chunk.length;
  console.log(`committed=${committed}/${payload.documents.length}`);
}

console.log('Firestore seed upload complete.');

function loadFirebaseAccessToken() {
  const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const tokenInfo = config.tokens;
  if (!tokenInfo?.access_token) {
    throw new Error('Firebase CLI access token not found. Run firebase login first.');
  }
  if (typeof tokenInfo.expires_at === 'number' && Date.now() >= tokenInfo.expires_at) {
    throw new Error('Firebase CLI access token is expired. Run a Firebase CLI command to refresh login first.');
  }
  return tokenInfo.access_token;
}

function requireSafeProjectId(value) {
  if (!/^[a-z][a-z0-9-]{4,61}[a-z0-9]$/.test(String(value))) {
    throw new Error('Invalid Firestore projectId.');
  }
}

function requireSafeDatabaseId(value) {
  if (value !== '(default)' && !/^[A-Za-z0-9._-]{1,160}$/.test(String(value))) {
    throw new Error('Invalid Firestore databaseId.');
  }
}

function requireSafeDocumentPath(value) {
  const segments = String(value ?? '').split('/');
  if (
    segments.length < 2 ||
    segments.length % 2 !== 0 ||
    segments.some((segment) => !/^[A-Za-z0-9._:-]{1,160}$/.test(segment))
  ) {
    throw new Error(`Invalid Firestore document path: ${value}`);
  }
}

function toFirestoreFields(input) {
  const fields = {};
  for (const [key, value] of Object.entries(input)) {
    if (value === undefined) continue;
    fields[key] = toFirestoreValue(value);
  }
  return fields;
}

function toFirestoreValue(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    if (Number.isInteger(value)) return { integerValue: String(value) };
    return { doubleValue: value };
  }
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(toFirestoreValue) } };
  }
  if (typeof value === 'object') {
    return { mapValue: { fields: toFirestoreFields(value) } };
  }
  return { stringValue: String(value) };
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
