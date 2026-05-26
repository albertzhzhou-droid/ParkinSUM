#!/usr/bin/env node
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const args = parseArgs(process.argv.slice(2));
loadTokenFileArgs(args);
const environment = normalizeEnvironment(args.env ?? process.env.PARKINSUM_ENV ?? 'stage');
const projectId =
  args.project ??
  process.env.PARKINSUM_FIREBASE_PROJECT_ID ??
  process.env.FIREBASE_PROJECT_ID ??
  defaultProjectForEnvironment(environment);
const operator = args.operator ?? process.env.USER ?? 'unknown_operator';
const readOnly = Boolean(args['read-only']);
const writeProbeAllowed =
  !readOnly &&
  (environment === 'stage' ||
    (environment === 'prod' &&
      args['allow-prod-writes'] &&
      args['confirm-project'] === projectId));
const auditLogPath =
  args['audit-log'] ?? 'build/operator_audit/operator_audit.jsonl';

if (args.help) {
  usage();
  process.exit(0);
}

const requiredTokens = ['user-a-token', 'normal-token'];
const missingTokens = requiredTokens.filter((key) => !args[key]);
if (missingTokens.length > 0) {
  const result = {
    command: 'firestore-live-probe',
    environment,
    projectId,
    readOnly,
    writeProbeAllowed,
    dryRun: true,
    missingTokens,
    message:
      'No live Firestore request was sent. Provide ID tokens to run probes.',
  };
  writeAudit(result);
  console.log(JSON.stringify(result, null, 2));
  process.exit(0);
}

const runId = args['run-id'] ?? `probe_${Date.now()}`;
const userAUid = required(args['user-a-uid'], '--user-a-uid');
const userBUid = required(args['user-b-uid'], '--user-b-uid');
const appCatalogPath = args['app-catalog-path'] ?? 'app_catalog/foods/rows/food_banana';
const userAPath = `users/${encodePathSegment(userAUid)}/app_meta/${runId}`;
const userBPath = `users/${encodePathSegment(userBUid)}/app_meta/${runId}`;
const unknownPath = `unknown_live_probe/${runId}`;
const results = [];

try {
  results.push(await requestCheck({
    name: 'unauthenticated user cannot read private app_meta',
    method: 'GET',
    documentPath: userAPath,
    expected: [401, 403],
  }));

  if (writeProbeAllowed) {
    results.push(await requestCheck({
      name: 'unauthenticated user cannot write private app_meta',
      method: 'PATCH',
      documentPath: userAPath,
      body: { fields: { probe: { stringValue: runId } } },
      expected: [401, 403],
    }));
  }

  if (writeProbeAllowed) {
    results.push(await requestCheck({
      name: 'user A writes own private app_meta',
      token: args['user-a-token'],
      method: 'PATCH',
      documentPath: userAPath,
      body: {
        fields: {
          probe_run_id: { stringValue: runId },
          owner_uid: { stringValue: userAUid },
        },
      },
      expected: [200],
    }));
  } else {
    results.push({
      name: 'user A writes own private app_meta',
      skipped: true,
      reason:
        'Write probe skipped outside stage. Use --allow-prod-writes --confirm-project for prod.',
    });
  }

  results.push(await requestCheck({
    name: 'user A cannot read user B private app_meta',
    token: args['user-a-token'],
    method: 'GET',
    documentPath: userBPath,
    expected: [403],
  }));

  if (writeProbeAllowed) {
    results.push(await requestCheck({
      name: 'user A cannot write user B private app_meta',
      token: args['user-a-token'],
      method: 'PATCH',
      documentPath: userBPath,
      body: { fields: { probe: { stringValue: runId } } },
      expected: [403],
    }));
  }

  results.push(await requestCheck({
    name: 'normal signed-in user can read app_catalog',
    token: args['normal-token'],
    method: 'GET',
    documentPath: appCatalogPath,
    expected: [200, 404],
  }));

  if (writeProbeAllowed) {
    results.push(await requestCheck({
      name: 'normal signed-in user cannot write app_catalog',
      token: args['normal-token'],
      method: 'PATCH',
      documentPath: `${appCatalogPath}_normal_write_probe_${runId}`,
      body: { fields: { probe: { stringValue: runId } } },
      expected: [403],
    }));
  }

  if (args['importer-token'] && writeProbeAllowed && !args['skip-privileged-allow']) {
    results.push(await requestCheck({
      name: 'importer can write app_catalog probe row',
      token: args['importer-token'],
      method: 'PATCH',
      documentPath: `app_catalog/live_probe/rows/${runId}`,
      body: { fields: { probe: { stringValue: runId } } },
      expected: [200],
    }));
  }

  if (args['admin-token'] && writeProbeAllowed && !args['skip-privileged-allow']) {
    results.push(await requestCheck({
      name: 'admin can write app_catalog probe row',
      token: args['admin-token'],
      method: 'PATCH',
      documentPath: `app_catalog/live_probe_admin/rows/${runId}`,
      body: { fields: { probe: { stringValue: runId } } },
      expected: [200],
    }));
  }

  if (args['cleared-importer-token'] && writeProbeAllowed) {
    results.push(await requestCheck({
      name: 'cleared importer token cannot write app_catalog',
      token: args['cleared-importer-token'],
      method: 'PATCH',
      documentPath: `app_catalog/live_probe_cleared/rows/${runId}`,
      body: { fields: { probe: { stringValue: runId } } },
      expected: [403],
    }));
  }

  if (args['cleared-admin-token'] && writeProbeAllowed) {
    results.push(await requestCheck({
      name: 'cleared admin token cannot write app_catalog',
      token: args['cleared-admin-token'],
      method: 'PATCH',
      documentPath: `app_catalog/live_probe_cleared_admin/rows/${runId}`,
      body: { fields: { probe: { stringValue: runId } } },
      expected: [403],
    }));
  }

  results.push(await requestCheck({
    name: 'top-level cdss_tables remains denied',
    token: args['normal-token'],
    method: 'GET',
    documentPath: 'cdss_tables/source_document/rows/probe',
    expected: [403],
  }));

  results.push(await requestCheck({
    name: 'fallback deny-all blocks unknown collection',
    token: args['normal-token'],
    method: 'GET',
    documentPath: unknownPath,
    expected: [403],
  }));

  const failed = results.filter((result) => result.pass === false);
  const report = {
    command: 'firestore-live-probe',
    environment,
    projectId,
    runId,
    operator,
    readOnly,
    writeProbeAllowed,
    results,
    pass: failed.length === 0,
  };
  writeAudit(report);
  console.log(JSON.stringify(report, null, 2));
  if (failed.length > 0) process.exit(1);
} catch (error) {
  const report = {
    command: 'firestore-live-probe',
    environment,
    projectId,
    runId,
    operator,
    readOnly,
    writeProbeAllowed,
    error: error.message,
    pass: false,
  };
  writeAudit(report);
  console.error(JSON.stringify(report, null, 2));
  process.exit(1);
}

function usage() {
  console.log(`Usage:
  node tool/firestore_live_probe.mjs --env stage --project <project> \\
    --user-a-uid <uidA> --user-b-uid <uidB> \\
    --user-a-token <idTokenA> --normal-token <idTokenNormal> \\
    [--user-b-token <idTokenB>] \\
    [--importer-token <idTokenImporter>] [--admin-token <idTokenAdmin>] \\
    [--cleared-importer-token <idTokenAfterClaimClear>] [--cleared-admin-token <idTokenAfterClaimClear>]

  node tool/firestore_live_probe.mjs --env stage --project <project> \\
    --token-file build/operator_tokens/stage_test_tokens.json

  node tool/firestore_live_probe.mjs --env prod --project <project> --read-only \\
    --token-file build/operator_tokens/prod_readonly_tokens.json

Read-only mode skips every write probe.
Prod write probes are skipped unless --allow-prod-writes --confirm-project <project> is supplied.
`);
}

async function requestCheck({ name, token, method, documentPath, expected, body }) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${documentPath}`;
  const headers = {
    'content-type': 'application/json',
  };
  if (token) {
    headers.authorization = `Bearer ${token}`;
  }
  const response = await fetch(url, {
    method,
    headers,
    body: body == null ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  const pass = expected.includes(response.status);
  return {
    name,
    method,
    documentPath: redactFirestorePath(documentPath),
    status: response.status,
    expected,
    pass,
    responseExcerpt: redactText(text.slice(0, 240)),
  };
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
  fs.appendFileSync(auditLogPath, `${JSON.stringify(sanitizeAudit(entry))}\n`);
}

function parseArgs(argv) {
  const parsed = {};
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith('--')) continue;
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

function loadTokenFileArgs(parsed) {
  if (parsed['token-file']) {
    const payload = JSON.parse(fs.readFileSync(parsed['token-file'], 'utf8'));
    const byRole = role => payload.accounts?.find(account => account.role === role);
    const userA = byRole('userA');
    const userB = byRole('userB');
    const importer = byRole('importer');
    const admin = byRole('admin');
    parsed['user-a-uid'] ??= userA?.uid;
    parsed['user-b-uid'] ??= userB?.uid;
    parsed['user-a-token'] ??= userA?.idToken;
    parsed['user-b-token'] ??= userB?.idToken;
    parsed['normal-token'] ??= userA?.idToken;
    parsed['importer-token'] ??= importer?.idToken;
    parsed['admin-token'] ??= admin?.idToken;
  }
  if (parsed['cleared-token-file']) {
    const payload = JSON.parse(fs.readFileSync(parsed['cleared-token-file'], 'utf8'));
    const byRole = role => payload.accounts?.find(account => account.role === role);
    parsed['cleared-importer-token'] ??= byRole('importer')?.idToken;
    parsed['cleared-admin-token'] ??= byRole('admin')?.idToken;
  }
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

function encodePathSegment(segment) {
  return encodeURIComponent(segment).replaceAll('%2F', '_');
}

function sanitizeAudit(value, key = '') {
  if (Array.isArray(value)) {
    return value.map((item) => sanitizeAudit(item, key));
  }
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([entryKey, entryValue]) => [
        entryKey,
        sanitizeAudit(entryValue, entryKey),
      ]),
    );
  }
  if (typeof value !== 'string') return value;
  if (/token$/i.test(key)) return '[REDACTED]';
  if (/uid$/i.test(key)) return hashValue(value);
  if (key === 'documentPath' || key === 'path' || key === 'scope') {
    return redactFirestorePath(value);
  }
  return redactText(value);
}

function redactFirestorePath(value) {
  return String(value).replace(/users\/([^/\s]+)/g, (_match, uid) => {
    return `users/${hashValue(decodeURIComponent(uid))}`;
  });
}

function redactText(value) {
  return String(value)
    .replace(/users\/([^/\s"'\\]+)/g, (_match, uid) => {
      return `users/${hashValue(decodeURIComponent(uid))}`;
    })
    .replace(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)?/g, '[JWT_REDACTED]')
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, '[EMAIL_REDACTED]');
}

function hashValue(value) {
  return `sha256:${crypto.createHash('sha256').update(String(value)).digest('hex').slice(0, 12)}`;
}
