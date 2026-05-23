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
const readOnly = Boolean(args['read-only']) || environment === 'prod';
const releaseId = args['release-id'] ?? `authenticated_e2e_${environment}_${timestamp()}`;
const output =
  args.output ?? path.join('build', 'e2e_smoke', `${releaseId}_authenticated_e2e.json`);
const markdownOutput = output.replace(/\.json$/, '.md');
const tokenFile =
  args['token-file'] ??
  (environment === 'prod'
    ? 'build/operator_tokens/prod_readonly_tokens.json'
    : 'build/operator_tokens/stage_test_tokens_p0.json');

const tokenPayload = JSON.parse(fs.readFileSync(tokenFile, 'utf8'));
const userA = byRole(tokenPayload, 'userA');
const userB = byRole(tokenPayload, 'userB');
if (!userA?.idToken || !userA?.uid || !userB?.idToken || !userB?.uid) {
  throw new Error(`Token file must contain userA/userB uid and idToken: ${tokenFile}`);
}

const results = [];
results.push(await requestCheck({
  name: 'unauthenticated private read denied',
  method: 'GET',
  documentPath: `users/${encodePathSegment(userA.uid)}/meals/${releaseId}`,
  expected: [401, 403],
}));
results.push(await requestCheck({
  name: 'user A cannot read user B private meal',
  token: userA.idToken,
  method: 'GET',
  documentPath: `users/${encodePathSegment(userB.uid)}/meals/${releaseId}`,
  expected: [403],
}));
results.push(await requestCheck({
  name: 'signed-in user can read app catalog',
  token: userA.idToken,
  method: 'GET',
  documentPath: args['app-catalog-path'] ?? 'app_catalog/foods/rows/food_banana',
  expected: [200, 404],
}));

if (!readOnly) {
  const userBase = `users/${encodePathSegment(userA.uid)}`;
  results.push(await requestCheck({
    name: 'stage user A writes minimal meal',
    token: userA.idToken,
    method: 'PATCH',
    documentPath: `${userBase}/meals/${releaseId}`,
    expected: [200],
    body: {
      fields: {
        title: { stringValue: 'E2E smoke meal' },
        source: { stringValue: 'authenticated_e2e_smoke' },
        release_id: { stringValue: releaseId },
      },
    },
  }));
  results.push(await requestCheck({
    name: 'stage user A writes minimal intake',
    token: userA.idToken,
    method: 'PATCH',
    documentPath: `${userBase}/intakes/${releaseId}`,
    expected: [200],
    body: {
      fields: {
        drug_id: { stringValue: 'drug_levodopa_carbidopa' },
        source: { stringValue: 'authenticated_e2e_smoke' },
        release_id: { stringValue: releaseId },
      },
    },
  }));
  results.push(await requestCheck({
    name: 'stage user A writes minimal clinical audit',
    token: userA.idToken,
    method: 'PATCH',
    documentPath: `${userBase}/clinical_audits/${releaseId}`,
    expected: [200],
    body: {
      fields: {
        type: { stringValue: 'e2e_smoke_audit' },
        release_id: { stringValue: releaseId },
        redaction_contract: { stringValue: 'no health detail in operator report' },
      },
    },
  }));
  results.push(await requestCheck({
    name: 'stage user A reads own smoke meal',
    token: userA.idToken,
    method: 'GET',
    documentPath: `${userBase}/meals/${releaseId}`,
    expected: [200],
  }));
}

results.push(await requestCheck({
  name: 'fallback deny-all blocks unknown collection',
  token: userA.idToken,
  method: 'GET',
  documentPath: `unknown_e2e_smoke/${releaseId}`,
  expected: [403],
}));

const failed = results.filter((result) => result.pass === false);
const report = {
  reportType: 'authenticated_e2e_smoke',
  generatedAt: new Date().toISOString(),
  releaseId,
  environment,
  projectId,
  tokenFile,
  readOnly,
  writeProbeAllowed: !readOnly,
  pass: failed.length === 0,
  results,
};

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, `${JSON.stringify(report, null, 2)}\n`);
fs.writeFileSync(markdownOutput, renderMarkdown(report));
console.log(JSON.stringify({ output, markdownOutput, pass: report.pass, readOnly }, null, 2));
if (!report.pass) process.exit(1);

async function requestCheck({ name, token, method, documentPath, expected, body }) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${documentPath}`;
  const headers = { 'content-type': 'application/json' };
  if (token) headers.authorization = `Bearer ${token}`;
  const response = await fetch(url, {
    method,
    headers,
    body: body == null ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  return {
    name,
    method,
    documentPath: redactPath(documentPath),
    status: response.status,
    expected,
    pass: expected.includes(response.status),
    responseExcerpt: text.slice(0, 180),
  };
}

function byRole(payload, role) {
  return payload.accounts?.find((account) => account.role === role);
}

function renderMarkdown(report) {
  return `# Authenticated E2E Smoke

Release id: ${report.releaseId}
Environment: ${report.environment}
Project: ${report.projectId}
Read-only: ${report.readOnly}
Result: ${report.pass ? 'PASS' : 'FAIL'}

| Check | Result | Status |
| --- | --- | --- |
${report.results.map((item) => `| ${item.name} | ${item.pass ? 'PASS' : 'FAIL'} | ${item.status} |`).join('\n')}
`;
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

function encodePathSegment(value) {
  return encodeURIComponent(String(value));
}

function redactPath(value) {
  return String(value).replace(/users\/([^/]+)/g, (_match, uid) => `users/${uid.slice(0, 6)}...`);
}

function timestamp() {
  return new Date().toISOString().replace(/[:.]/g, '').slice(0, 15);
}
