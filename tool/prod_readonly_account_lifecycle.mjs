#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { initializeApp, applicationDefault, getApps, deleteApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

const args = parseArgs(process.argv.slice(2));
const project = args.project ?? 'parkinsum-companion';
const releaseId = args['release-id'] ?? `prod_readonly_lifecycle_${timestamp()}`;
const tokenFile = args['token-file'] ?? path.join('build', 'operator_tokens', 'prod_readonly_tokens.json');
const output =
  args.output ?? path.join('build', 'operator_reports', `${releaseId}_prod_readonly_lifecycle.json`);
const markdownOutput = output.replace(/\.json$/, '.md');
const nextReviewDate = args['next-review-date'] ?? '2026-06-23';

if (!fs.existsSync(tokenFile)) {
  throw new Error(`Missing token file: ${tokenFile}`);
}

const tokenData = JSON.parse(fs.readFileSync(tokenFile, 'utf8'));
const app = initializeApp({ credential: applicationDefault(), projectId: project }, `lifecycle-${Date.now()}`);
const auth = getAuth(app);
const accounts = [];

for (const account of tokenData.accounts ?? []) {
  const user = await auth.getUser(account.uid);
  accounts.push({
    role: account.role,
    uidHash: hash(account.uid),
    emailHash: user.email ? hash(user.email) : null,
    disabled: user.disabled,
    customClaims: user.customClaims ?? {},
    createdAt: user.metadata?.creationTime ?? null,
    lastSignInAt: user.metadata?.lastSignInTime ?? null,
    retainedStatus: 'enabled_after_readonly_probe',
    purpose: 'prod_readonly_firestore_rules_and_catalog_probe',
    cleanupCommand:
      `node tool/firebase_ops.mjs user-delete --env prod --project ${project} --uid <${account.role}_uid> --operator zhouzhenghang --execute --confirm <${account.role}_uid> --confirm-project ${project} --delete-auth`,
  });
}

await deleteApp(app);
for (const existing of getApps()) {
  if (existing.name === app.name) await deleteApp(existing);
}

const report = {
  reportType: 'prod_readonly_account_lifecycle',
  generatedAt: new Date().toISOString(),
  releaseId,
  project,
  tokenFile,
  accounts,
  retentionReason:
    'Retained enabled by owner/operator decision to support repeatable prod read-only live probes without prod writes or custom claims.',
  nextReviewDate,
  cleanupPolicy:
    'Delete retained readonly Auth accounts when no longer needed for internal prerelease evidence, or immediately if token exposure is suspected. Do not grant custom claims to these accounts.',
  pass:
    accounts.length >= 2 &&
    accounts.every((account) => account.disabled === false && Object.keys(account.customClaims).length === 0),
};

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, `${JSON.stringify(report, null, 2)}\n`);
fs.writeFileSync(markdownOutput, renderMarkdown(report));
console.log(JSON.stringify({ output, markdownOutput, pass: report.pass }, null, 2));
if (!report.pass) process.exit(1);

function hash(value) {
  return crypto.createHash('sha256').update(String(value)).digest('hex').slice(0, 12);
}

function renderMarkdown(report) {
  return `# Prod Readonly Account Lifecycle

Release id: ${report.releaseId}
Generated at: ${report.generatedAt}
Project: ${report.project}
Result: ${report.pass ? 'PASS' : 'FAIL'}

Retention reason: ${report.retentionReason}

Next review date: ${report.nextReviewDate}

| Role | UID hash | Disabled | Custom claims |
| --- | --- | --- | --- |
${report.accounts
  .map((account) =>
    `| ${account.role} | \`${account.uidHash}\` | ${account.disabled} | ${JSON.stringify(account.customClaims)} |`)
  .join('\n')}

Cleanup policy: ${report.cleanupPolicy}
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

function timestamp() {
  return new Date().toISOString().replace(/[:.]/g, '').slice(0, 15);
}
