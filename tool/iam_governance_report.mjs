#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const args = parseArgs(process.argv.slice(2));
const releaseId = args['release-id'] ?? `iam_governance_${timestamp()}`;
const output =
  args.output ?? path.join('build', 'operator_reports', `${releaseId}_iam_governance.json`);
const markdownOutput = output.replace(/\.json$/, '.md');

const projects = {
  dev: 'parkinsum-companion-dev',
  stage: 'parkinsum-companion-stage',
  prod: 'parkinsum-companion',
};
const serviceAccounts = {
  stageOperator: {
    project: projects.stage,
    email: 'parkinsum-stage-operator@parkinsum-companion-stage.iam.gserviceaccount.com',
    requiredProjectRoles: [
      'roles/firebaseauth.admin',
      'roles/datastore.user',
      'roles/datastore.importExportAdmin',
      'roles/logging.viewer',
      'roles/errorreporting.viewer',
      'roles/monitoring.viewer',
    ],
    bucket: 'gs://parkinsum-companion-stage-p0-backups',
    requiredBucketRole: 'roles/storage.objectAdmin',
  },
  prodOperator: {
    project: projects.prod,
    email: 'parkinsum-prod-operator@parkinsum-companion.iam.gserviceaccount.com',
    requiredProjectRoles: [
      'roles/firebaseauth.viewer',
      'roles/datastore.importExportAdmin',
      'roles/logging.viewer',
      'roles/errorreporting.viewer',
      'roles/monitoring.viewer',
    ],
    bucket: 'gs://parkinsum-prod-backups',
    requiredBucketRole: 'roles/storage.objectAdmin',
  },
  prodBreakglass: {
    project: projects.prod,
    email: 'parkinsum-prod-breakglass@parkinsum-companion.iam.gserviceaccount.com',
    requiredProjectRoles: [],
    note:
      'Plan requested parkinsum-prod-breakglass-operator, but Google service account IDs have a 30-character limit. The effective account is parkinsum-prod-breakglass.',
  },
};

const projectPolicies = Object.fromEntries(
  Object.entries(projects).map(([env, project]) => [env, getProjectPolicy(project)]),
);
const bucketPolicies = Object.fromEntries(
  Object.values(serviceAccounts)
    .filter((account) => account.bucket)
    .map((account) => [account.bucket, getBucketPolicy(account.bucket)]),
);
const serviceAccountStates = Object.fromEntries(
  Object.entries(serviceAccounts).map(([name, account]) => [name, describeServiceAccount(account)]),
);

const checks = [
  ...Object.entries(serviceAccounts).map(([name, account]) => ({
    name: `${name}_exists`,
    pass: Boolean(serviceAccountStates[name]?.email),
    detail: account.email,
  })),
  ...roleChecks(),
  ...bucketChecks(),
  {
    name: 'no_service_account_keys_created_by_report',
    pass: true,
    detail: 'This report does not create or export private keys; use ADC or impersonation.',
  },
];

const report = {
  reportType: 'iam_governance_report',
  generatedAt: new Date().toISOString(),
  releaseId,
  projects,
  ownerEditorSummary: Object.fromEntries(
    Object.entries(projectPolicies).map(([env, policy]) => [env, summarizeOwnerEditor(policy)]),
  ),
  serviceAccounts,
  serviceAccountStates,
  checks,
  credentialPolicy: {
    privateKeys: 'forbidden',
    defaultAuth: 'ADC or service account impersonation',
    rotation: 'Review operator access every internal release and rotate/remove credentials immediately after device loss or operator departure.',
    deviceLoss:
      'Revoke refresh tokens, remove IAM bindings for affected principals, disable compromised service accounts if applicable, and record the incident in operator audit.',
    offboarding:
      'Remove user principal from Firebase/GCP IAM, revoke local ADC credentials, review custom claims, and rotate any exposed local token files.',
  },
  pass: checks.every((check) => check.pass),
};

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, `${JSON.stringify(report, null, 2)}\n`);
fs.writeFileSync(markdownOutput, renderMarkdown(report));
console.log(JSON.stringify({ output, markdownOutput, pass: report.pass }, null, 2));
if (!report.pass) process.exit(1);

function roleChecks() {
  const results = [];
  for (const [name, account] of Object.entries(serviceAccounts)) {
    const env = Object.entries(projects).find(([, project]) => project === account.project)?.[0];
    const policy = projectPolicies[env];
    for (const role of account.requiredProjectRoles) {
      results.push({
        name: `${name}_${role.replaceAll('/', '_')}`,
        pass: hasBinding(policy, role, `serviceAccount:${account.email}`),
        detail: account.email,
      });
    }
  }
  return results;
}

function bucketChecks() {
  return Object.entries(serviceAccounts)
    .filter(([, account]) => account.bucket)
    .map(([name, account]) => ({
      name: `${name}_bucket_${account.requiredBucketRole.replaceAll('/', '_')}`,
      pass: hasBinding(
        bucketPolicies[account.bucket],
        account.requiredBucketRole,
        `serviceAccount:${account.email}`,
      ),
      detail: account.bucket,
    }));
}

function getProjectPolicy(project) {
  return runJson('gcloud', ['projects', 'get-iam-policy', project, '--format=json']);
}

function getBucketPolicy(bucket) {
  return runJson('gcloud', ['storage', 'buckets', 'get-iam-policy', bucket, '--format=json']);
}

function describeServiceAccount(account) {
  try {
    return runJson('gcloud', [
      'iam',
      'service-accounts',
      'describe',
      account.email,
      `--project=${account.project}`,
      '--format=json',
    ]);
  } catch (error) {
    return { email: null, error: error.message };
  }
}

function summarizeOwnerEditor(policy) {
  return {
    owners: membersForRole(policy, 'roles/owner'),
    editors: membersForRole(policy, 'roles/editor'),
  };
}

function membersForRole(policy, role) {
  return policy.bindings?.find((binding) => binding.role === role)?.members ?? [];
}

function hasBinding(policy, role, member) {
  return Boolean(policy.bindings?.some((binding) =>
    binding.role === role && binding.members?.includes(member),
  ));
}

function runJson(command, argv) {
  return JSON.parse(execFileSync(command, argv, { encoding: 'utf8', maxBuffer: 1024 * 1024 * 8 }));
}

function renderMarkdown(report) {
  return `# IAM Governance Report

Release id: ${report.releaseId}
Generated at: ${report.generatedAt}
Result: ${report.pass ? 'PASS' : 'FAIL'}

## Owner / Editor Summary

| Env | Owners | Editors |
| --- | --- | --- |
${Object.entries(report.ownerEditorSummary)
  .map(([env, summary]) =>
    `| ${env} | ${summary.owners.join('<br>') || 'none'} | ${summary.editors.join('<br>') || 'none'} |`)
  .join('\n')}

## Operator Service Accounts

| Name | Email | Project |
| --- | --- | --- |
${Object.entries(report.serviceAccounts)
  .map(([name, account]) => `| ${name} | \`${account.email}\` | \`${account.project}\` |`)
  .join('\n')}

## Checks

| Check | Result |
| --- | --- |
${report.checks.map((check) => `| ${check.name} | ${check.pass ? 'PASS' : 'FAIL'} |`).join('\n')}

## Credential Policy

- Private keys: ${report.credentialPolicy.privateKeys}
- Default auth: ${report.credentialPolicy.defaultAuth}
- Rotation: ${report.credentialPolicy.rotation}
- Device loss: ${report.credentialPolicy.deviceLoss}
- Offboarding: ${report.credentialPolicy.offboarding}
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
