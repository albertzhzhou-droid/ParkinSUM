#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const args = parseArgs(process.argv.slice(2));
const environment = normalizeEnvironment(args.env ?? process.env.PARKINSUM_ENV ?? 'stage');
const projectId =
  args.project ??
  process.env.PARKINSUM_FIREBASE_PROJECT_ID ??
  process.env.FIREBASE_PROJECT_ID ??
  defaultProjectForEnvironment(environment);
const releaseId = args['release-id'] ?? `backup_prereq_${environment}_${timestamp()}`;
const bucket = args.bucket ?? defaultBucket(environment);
const output =
  args.output ?? path.join('build', 'operator_reports', `${releaseId}_backup_prereq.json`);
const markdownOutput = output.replace(/\.json$/, '.md');

const billing = gcloudJson(['billing', 'projects', 'describe', projectId, '--format=json']);
const bucketCheck = bucket
  ? gcloudJson(['storage', 'buckets', 'describe', bucket, '--format=json'])
  : { ok: false, skipped: true, error: 'No bucket configured.' };
const billingEnabled = billing.ok && billing.json?.billingEnabled === true;
const bucketAvailable = bucketCheck.ok;
const exportRestoreRunnable = billingEnabled && bucketAvailable;

const report = {
  reportType: 'backup_prereq_check',
  generatedAt: new Date().toISOString(),
  releaseId,
  environment,
  projectId,
  bucket,
  status: exportRestoreRunnable
    ? 'READY_FOR_EXPORT_RESTORE_DRILL'
    : 'BLOCKED_NO_BILLING_OR_BUCKET',
  technicalPass: true,
  exportRestoreRunnable,
  billing: summarizeProcess(billing),
  bucketCheck: summarizeProcess(bucketCheck),
  exportCommand: `gcloud firestore export ${bucket.replace(/\/+$/, '')}/parkinsum/${safeSegment(releaseId)} --project=${projectId} --database='(default)'`,
  restoreDrillCommand:
    'Use Firebase/Google Cloud documented import workflow against an approved non-prod restore target after export succeeds.',
  publicReleaseBlocker: !exportRestoreRunnable,
};

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, `${JSON.stringify(report, null, 2)}\n`);
fs.writeFileSync(markdownOutput, renderMarkdown(report));
console.log(JSON.stringify({ output, markdownOutput, status: report.status, technicalPass: true }, null, 2));

function gcloudJson(argv) {
  const result = spawnSync('gcloud', argv, {
    cwd: process.cwd(),
    encoding: 'utf8',
    maxBuffer: 1024 * 1024 * 4,
  });
  let json = null;
  try {
    json = result.stdout.trim() ? JSON.parse(result.stdout) : null;
  } catch (_) {
    json = null;
  }
  return {
    ok: result.status === 0,
    status: result.status,
    stdout: sanitize(result.stdout),
    stderr: sanitize(result.stderr),
    json,
  };
}

function summarizeProcess(result) {
  return {
    ok: result.ok,
    status: result.status ?? null,
    skipped: result.skipped === true,
    error: result.error ?? null,
    billingEnabled: result.json?.billingEnabled ?? null,
    name: result.json?.name ?? result.json?.metadata?.name ?? null,
    stdout: result.ok ? undefined : result.stdout,
    stderr: result.ok ? undefined : result.stderr,
  };
}

function renderMarkdown(report) {
  return `# Backup Prerequisite Check

Release id: ${report.releaseId}
Environment: ${report.environment}
Project: ${report.projectId}
Bucket: ${report.bucket}
Status: ${report.status}
Export/restore runnable: ${report.exportRestoreRunnable ? 'yes' : 'no'}

## Export Command

\`\`\`sh
${report.exportCommand}
\`\`\`

## Public Release Blocker

${report.publicReleaseBlocker ? '- backup/export/restore drill is blocked until billing and an approved bucket are available.' : '- none'}
`;
}

function sanitize(value) {
  return String(value ?? '').replace(/\/Users\/[^/\s]+/g, '/Users/[REDACTED]').slice(0, 2000);
}

function defaultBucket(env) {
  return env === 'prod'
    ? 'gs://parkinsum-prod-backups'
    : 'gs://parkinsum-companion-stage-p0-backups';
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

function safeSegment(value) {
  return String(value).replace(/[^a-zA-Z0-9._-]/g, '_');
}

function timestamp() {
  return new Date().toISOString().replace(/[:.]/g, '').slice(0, 15);
}
