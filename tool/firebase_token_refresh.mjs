#!/usr/bin/env node
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const args = parseArgs(process.argv.slice(2));
const input = required(args.input, '--input');
const role = required(args.role, '--role');
const output = args.output ?? input;
const environment = normalizeEnvironment(args.env ?? process.env.PARKINSUM_ENV ?? 'stage');
const projectId =
  args.project ??
  process.env.PARKINSUM_FIREBASE_PROJECT_ID ??
  process.env.FIREBASE_PROJECT_ID ??
  defaultProjectForEnvironment(environment);
const apiKey = required(
  args['api-key'] ??
    process.env.PARKINSUM_FIREBASE_API_KEY ??
    inferFirebaseWebApiKey(environment, projectId),
  '--api-key',
);

if (args.help) {
  usage();
  process.exit(0);
}

const payload = JSON.parse(fs.readFileSync(input, 'utf8'));
const account = payload.accounts?.find((entry) => entry.role === role);
if (!account) {
  throw new Error(`Role not found in token file: ${role}`);
}
if (!args['reset-password'] && !account.refreshToken) {
  throw new Error(`Role ${role} has no refreshToken in token file.`);
}

const refreshed = args['reset-password']
  ? await resetPasswordAndSignIn(account)
  : await refreshIdToken(account.refreshToken);
account.idToken = refreshed.idToken;
account.refreshToken = refreshed.refreshToken ?? account.refreshToken;
account.refreshedAt = new Date().toISOString();

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, `${JSON.stringify(payload, null, 2)}\n`, { mode: 0o600 });
try {
  fs.chmodSync(output, 0o600);
} catch (_) {
  // Best-effort on filesystems that do not preserve POSIX modes.
}

console.log(JSON.stringify({
  command: 'firebase-token-refresh',
  input,
  output,
  role,
  uidHash: hashValue(account.uid),
  email: account.email ? redactEmail(account.email) : undefined,
  refreshedAt: account.refreshedAt,
  idTokenWritten: true,
}, null, 2));

function usage() {
  console.log(`Usage:
  node tool/firebase_token_refresh.mjs --input build/operator_tokens/stage_test_tokens.json --role importer --api-key <webApiKey>

Refreshes one role's ID token in the local operator token file after claims
are set or cleared. The token file stays under build/ and should not be
committed.

Use --reset-password after claim removal when a provider refresh token still
returns a cached pre-removal ID token.
`);
}

async function resetPasswordAndSignIn(account) {
  if (!account.email) {
    throw new Error(`Role ${role} has no email in token file.`);
  }
  const password = args.password ?? `ParkinSUM-refresh-${Date.now()}-T3st!`;
  const [{ initializeApp, getApps, applicationDefault }, { getAuth }] =
    await Promise.all([
      import('firebase-admin/app'),
      import('firebase-admin/auth'),
    ]);
  const app = getApps()[0] ?? initializeApp({
    credential: applicationDefault(),
    projectId,
  });
  await getAuth(app).updateUser(account.uid, {
    password,
    disabled: false,
  });
  return signInWithPassword(account.email, password);
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
    throw new Error(
      `signInWithPassword failed for ${redactEmail(email)}: ${JSON.stringify(json)}`,
    );
  }
  return {
    idToken: json.idToken,
    refreshToken: json.refreshToken,
  };
}

async function refreshIdToken(refreshToken) {
  const response = await fetch(
    `https://securetoken.googleapis.com/v1/token?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'refresh_token',
        refresh_token: refreshToken,
      }),
    },
  );
  const json = await response.json();
  if (!response.ok) {
    throw new Error(`Token refresh failed: ${JSON.stringify(json)}`);
  }
  return {
    idToken: json.id_token,
    refreshToken: json.refresh_token,
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

function redactEmail(email) {
  const [local, domain] = String(email).split('@');
  if (!domain) return '[EMAIL_REDACTED]';
  return `${local.slice(0, 2)}***@${domain}`;
}

function hashValue(value) {
  return `sha256:${crypto.createHash('sha256').update(String(value)).digest('hex').slice(0, 12)}`;
}
