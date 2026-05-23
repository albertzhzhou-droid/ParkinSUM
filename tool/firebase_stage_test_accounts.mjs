#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const args = parseArgs(process.argv.slice(2));
const environment = normalizeEnvironment(args.env ?? process.env.PARKINSUM_ENV ?? 'stage');
const projectId =
  args.project ??
  process.env.PARKINSUM_FIREBASE_PROJECT_ID ??
  process.env.FIREBASE_PROJECT_ID ??
  defaultProjectForEnvironment(environment);
const apiKey = required(args['api-key'] ?? process.env.PARKINSUM_FIREBASE_API_KEY, '--api-key');
const operator = args.operator ?? process.env.USER ?? 'unknown_operator';
const dryRun = !args.execute;
const auditLogPath = args['audit-log'] ?? 'build/operator_audit/operator_audit.jsonl';
const outputPath =
  args.output ?? path.join('build', 'operator_tokens', `${environment}_test_tokens.json`);

if (args.help) {
  usage();
  process.exit(0);
}

try {
  requireProjectConfirmation();
  const runId = args['run-id'] ?? `stage_${Date.now()}`;
  const password = args.password ?? `ParkinSUM-${runId}-T3st!`;
  const accounts = [
    {
      role: 'userA',
      email: args['user-a-email'] ?? `parkinsum.stage.user-a+${runId}@example.com`,
      claims: {},
    },
    {
      role: 'userB',
      email: args['user-b-email'] ?? `parkinsum.stage.user-b+${runId}@example.com`,
      claims: {},
    },
    {
      role: 'importer',
      email: args['importer-email'] ?? `parkinsum.stage.importer+${runId}@example.com`,
      claims: { cdssImporter: true },
    },
    {
      role: 'admin',
      email: args['admin-email'] ?? `parkinsum.stage.admin+${runId}@example.com`,
      claims: { admin: true },
    },
    {
      role: 'disposable',
      email: args['disposable-email'] ?? `parkinsum.stage.disposable+${runId}@example.com`,
      claims: {},
    },
  ];

  const summary = {
    command: 'stage-test-accounts',
    environment,
    projectId,
    dryRun,
    output: outputPath,
    accounts: accounts.map((account) => ({
      role: account.role,
      email: account.email,
      claims: maskClaims(account.claims),
    })),
  };
  if (dryRun) {
    writeAudit({ ...summary, tokenFileWritten: false });
    console.log(JSON.stringify(summary, null, 2));
    process.exit(0);
  }

  const { auth } = await adminClients();
  const created = [];
  for (const account of accounts) {
    const user = await ensureUser(auth, account.email, password, account.role);
    await auth.setCustomUserClaims(user.uid, account.claims);
    const signIn = await signInWithPassword(account.email, password);
    created.push({
      role: account.role,
      uid: user.uid,
      email: account.email,
      claims: maskClaims(account.claims),
      idToken: signIn.idToken,
      refreshToken: signIn.refreshToken,
    });
  }

  const payload = {
    environment,
    projectId,
    createdAt: new Date().toISOString(),
    runId,
    accounts: created,
  };
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, `${JSON.stringify(payload, null, 2)}\n`, {
    mode: 0o600,
  });
  try {
    fs.chmodSync(outputPath, 0o600);
  } catch (_) {
    // Best-effort on filesystems that do not preserve POSIX modes.
  }

  const result = {
    ...summary,
    accounts: created.map((account) => ({
      role: account.role,
      uid: account.uid,
      email: account.email,
      claims: account.claims,
      idTokenWritten: true,
      refreshTokenWritten: true,
    })),
    tokenFileWritten: true,
  };
  writeAudit(result);
  console.log(JSON.stringify(result, null, 2));
} catch (error) {
  writeAudit({
    command: 'stage-test-accounts',
    environment,
    projectId,
    dryRun,
    error: error.message,
  });
  console.error(error.message);
  process.exit(1);
}

function usage() {
  console.log(`Usage:
  node tool/firebase_stage_test_accounts.mjs --env stage --project parkinsum-companion-stage --api-key <webApiKey> [--execute --confirm-project parkinsum-companion-stage]

Creates userA, userB, importer, admin, and disposable test accounts in stage,
assigns importer/admin claims, signs each account in, and writes ID/refresh
tokens to build/.
`);
}

async function adminClients() {
  const [{ initializeApp, getApps, applicationDefault }, { getAuth }] =
    await Promise.all([
      import('firebase-admin/app'),
      import('firebase-admin/auth'),
    ]);
  const app = getApps()[0] ?? initializeApp({
    credential: applicationDefault(),
    projectId,
  });
  return { auth: getAuth(app) };
}

async function ensureUser(auth, email, password, role) {
  try {
    const user = await auth.getUserByEmail(email);
    await auth.updateUser(user.uid, {
      password,
      emailVerified: true,
      displayName: `ParkinSUM Stage ${role}`,
      disabled: false,
    });
    return user;
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    return auth.createUser({
      email,
      password,
      emailVerified: true,
      displayName: `ParkinSUM Stage ${role}`,
      disabled: false,
    });
  }
}

async function signInWithPassword(email, password) {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        email,
        password,
        returnSecureToken: true,
      }),
    },
  );
  const json = await response.json();
  if (!response.ok) {
    throw new Error(`signInWithPassword failed for ${email}: ${JSON.stringify(json)}`);
  }
  return {
    idToken: json.idToken,
    refreshToken: json.refreshToken,
  };
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
