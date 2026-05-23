#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const args = parseArgs(process.argv.slice(2));
const environment = normalizeEnvironment(args.env ?? process.env.PARKINSUM_ENV ?? 'prod');
const projectId =
  args.project ??
  process.env.PARKINSUM_FIREBASE_PROJECT_ID ??
  process.env.FIREBASE_PROJECT_ID ??
  'parkinsum-companion';
const apiKey = required(
  args['api-key'] ??
    process.env.PARKINSUM_FIREBASE_API_KEY ??
    inferFirebaseWebApiKey(environment, projectId),
  '--api-key',
);
const operator = args.operator ?? process.env.USER ?? 'unknown_operator';
const dryRun = !args.execute;
const auditLogPath = args['audit-log'] ?? 'build/operator_audit/operator_audit.jsonl';
const outputPath =
  args.output ?? path.join('build', 'operator_tokens', 'prod_readonly_tokens.json');

if (args.help) {
  usage();
  process.exit(0);
}

try {
  if (environment !== 'prod' || projectId !== 'parkinsum-companion') {
    throw new Error('This tool is only for prod project parkinsum-companion.');
  }
  requireProjectConfirmation();
  const runId = args['run-id'] ?? `prod_readonly_${Date.now()}`;
  const password =
    args.password ??
    `ParkinSUM-prod-readonly-${crypto.randomBytes(9).toString('base64url')}-T3st!`;
  const accounts = [
    {
      role: 'userA',
      email: args['user-a-email'] ?? `parkinsum.prod.readonly-a+${runId}@example.com`,
    },
    {
      role: 'userB',
      email: args['user-b-email'] ?? `parkinsum.prod.readonly-b+${runId}@example.com`,
    },
  ];
  const summary = {
    command: 'prod-readonly-accounts',
    environment,
    projectId,
    dryRun,
    retention: 'enabled_after_probe',
    output: outputPath,
    accounts: accounts.map((account) => ({
      role: account.role,
      email: redactEmail(account.email),
      claims: { admin: false, cdssImporter: false },
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
    await auth.setCustomUserClaims(user.uid, {});
    const signIn = await signInWithPassword(account.email, password);
    created.push({
      role: account.role,
      uid: user.uid,
      uidHash: hashValue(user.uid),
      email: account.email,
      claims: { admin: false, cdssImporter: false },
      disabled: false,
      retention: 'enabled_after_probe',
      cleanupCommand:
        `node tool/firebase_ops.mjs user-delete --env prod --project parkinsum-companion --uid ${user.uid} --delete-auth --execute --confirm ${user.uid} --confirm-project parkinsum-companion`,
      idToken: signIn.idToken,
      refreshToken: signIn.refreshToken,
    });
  }

  const payload = {
    environment,
    projectId,
    createdAt: new Date().toISOString(),
    runId,
    purpose: 'prod_readonly_live_probe',
    retention: 'enabled_after_probe',
    accounts: created,
  };
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, `${JSON.stringify(payload, null, 2)}\n`, { mode: 0o600 });
  try {
    fs.chmodSync(outputPath, 0o600);
  } catch (_) {
    // Best-effort on filesystems that do not preserve POSIX modes.
  }

  const result = {
    ...summary,
    accounts: created.map((account) => ({
      role: account.role,
      uidHash: account.uidHash,
      email: redactEmail(account.email),
      claims: account.claims,
      disabled: account.disabled,
      retention: account.retention,
      cleanupCommand: redactUidInCommand(account.cleanupCommand),
      idTokenWritten: true,
      refreshTokenWritten: true,
    })),
    tokenFileWritten: true,
  };
  writeAudit(result);
  console.log(JSON.stringify(result, null, 2));
} catch (error) {
  writeAudit({
    command: 'prod-readonly-accounts',
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
  node tool/firebase_prod_readonly_accounts.mjs --env prod --project parkinsum-companion --execute --confirm-project parkinsum-companion

Creates userA/userB prod Auth test accounts with no custom claims, signs them
in, and writes local tokens to build/operator_tokens/prod_readonly_tokens.json.
It does not write Firestore and does not grant privileged claims.
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
      displayName: `ParkinSUM Prod Readonly ${role}`,
      disabled: false,
    });
    return user;
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    return auth.createUser({
      email,
      password,
      emailVerified: true,
      displayName: `ParkinSUM Prod Readonly ${role}`,
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
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    },
  );
  const json = await response.json();
  if (!response.ok) {
    throw new Error(`signInWithPassword failed for ${redactEmail(email)}: ${JSON.stringify(json)}`);
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

function inferFirebaseWebApiKey(env, expectedProjectId) {
  const optionsPath = path.join(process.cwd(), 'lib', 'firebase_options.dart');
  if (!fs.existsSync(optionsPath)) return undefined;
  const source = fs.readFileSync(optionsPath, 'utf8');
  const optionsName = env === 'dev' ? 'devWeb' : env === 'stage' ? 'stageWeb' : 'web';
  const blockMatch = source.match(
    new RegExp(`static const FirebaseOptions ${optionsName} = FirebaseOptions\\(\\s*([\\s\\S]*?)\\n\\s*\\);`),
  );
  if (!blockMatch) return undefined;
  const block = blockMatch[1];
  const projectMatch = block.match(/projectId:\s*'([^']+)'/);
  if (projectMatch && projectMatch[1] !== expectedProjectId) {
    throw new Error(
      `Firebase options project mismatch for ${env}: expected ${expectedProjectId}, found ${projectMatch[1]}.`,
    );
  }
  return block.match(/apiKey:\s*'([^']+)'/)?.[1];
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

function hashValue(value) {
  return crypto.createHash('sha256').update(String(value)).digest('hex').slice(0, 12);
}

function redactEmail(value) {
  return String(value).replace(/^(.{2}).*(@.*)$/, '$1***$2');
}

function redactUidInCommand(value) {
  return String(value).replace(/--uid\s+\S+|--confirm\s+\S+/g, (match) =>
    match.startsWith('--uid') ? '--uid [UID_REDACTED]' : '--confirm [UID_REDACTED]',
  );
}
