#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const supportContact = 'parkinsumservice@gmail.com';
const args = parseArgs(process.argv.slice(2));
const env = args.env ?? process.env.PARKINSUM_ENV ?? 'local';
const project = args.project ?? process.env.PARKINSUM_FIREBASE_PROJECT_ID ?? null;
const releaseId = args['release-id'] ?? `monitoring_gate_${timestamp()}`;
const output =
  args.output ?? path.join('build', 'operator_reports', `${releaseId}_monitoring_gate.json`);
const markdownOutput = output.replace(/\.json$/, '.md');
const cloudApis = project ? readEnabledCloudApis(project) : null;
const monitoringState = project ? await readMonitoringState(project) : null;
const requiredProdCloudApis = ['logging.googleapis.com', 'clouderrorreporting.googleapis.com'];

const dependencySource = ['pubspec.yaml', 'package.json']
  .filter((item) => fs.existsSync(item))
  .map((item) => fs.readFileSync(item, 'utf8'))
  .join('\n');
const bootstrapSource = ['web/index.html', 'web/flutter_bootstrap.js']
  .filter((item) => fs.existsSync(item))
  .map((item) => fs.readFileSync(item, 'utf8'))
  .join('\n');
const auditSummary = latestFile('build/operator_reports', /_audit_summary\.json$/);
const auditText = auditSummary ? fs.readFileSync(auditSummary, 'utf8') : '';
const signoff = readFinalSignoffPackage();
const checks = [
  {
    name: 'no_crashlytics_dependency',
    pass: !/firebase_crashlytics|Crashlytics/i.test(dependencySource),
  },
  {
    name: 'no_analytics_dependency',
    pass:
      !/firebase_analytics|google_analytics/i.test(dependencySource) &&
      !/GoogleAnalytics|gtag\(|dataLayer/i.test(bootstrapSource),
  },
  {
    name: 'no_third_party_monitoring_dependency',
    pass: !/sentry|bugsnag|datadog|newrelic/i.test(dependencySource),
  },
  {
    name: 'audit_summary_exists',
    pass: Boolean(auditSummary),
    detail: auditSummary,
  },
  {
    name: 'audit_summary_has_no_token_or_email_literals',
    pass:
      auditText.length > 0 &&
      !/(Bearer\s+[A-Za-z0-9._-]+|eyJ[A-Za-z0-9._-]+|[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,})/i.test(auditText),
  },
  {
    name: 'monitoring_strategy_documented',
    pass:
      fs.existsSync('docs/p1_productionization_report.md') &&
      /Cloud Logging|manual monitoring plus local operator audit/.test(
        fs.readFileSync('docs/p1_productionization_report.md', 'utf8'),
      ),
  },
  {
    name: 'prod_cloud_logging_api_enabled',
    pass: env !== 'prod' || Boolean(cloudApis?.enabled.includes('logging.googleapis.com')),
    detail: cloudApis?.error ?? project ?? 'not_requested',
  },
  {
    name: 'prod_error_reporting_api_enabled',
    pass:
      env !== 'prod' ||
      Boolean(cloudApis?.enabled.includes('clouderrorreporting.googleapis.com')),
    detail: cloudApis?.error ?? project ?? 'not_requested',
  },
  {
    name: 'monitoring_owner_recorded',
    pass:
      signoff?.signoff?.owner === 'zhouzhenghang' &&
      signoff?.signoff?.monitoringOwner === 'zhouzhenghang' &&
      signoff?.signoff?.incidentResponseOwner === 'zhouzhenghang',
    detail: signoff?.signoff?.contact ?? 'missing_signoff_package',
  },
  {
    name: 'service_contact_recorded',
    pass:
      signoff?.publicContact?.support === supportContact &&
      signoff?.publicContact?.privacy === supportContact &&
      signoff?.signoff?.contact === supportContact,
    detail: signoff?.signoff?.contact ?? 'missing_signoff_package',
  },
  {
    name: 'internal_owner_acceptance_recorded',
    pass:
      signoff?.signoff?.scope === 'internal_private_prerelease' &&
      signoff?.signoff?.status === 'owner_accepted_internal_prerelease',
    detail: signoff?.publicCaveat ?? 'missing_signoff_package',
  },
  {
    name: 'prod_notification_channel_configured',
    pass:
      env !== 'prod' ||
      Boolean(monitoringState?.notificationChannels.some((channel) =>
        channel.type === 'email' &&
        channel.labels?.email_address === supportContact &&
        channel.enabled !== false,
      )),
    detail: monitoringState?.error ?? supportContact,
  },
  {
    name: 'prod_hosting_uptime_check_configured',
    pass:
      env !== 'prod' ||
      Boolean(monitoringState?.uptimeChecks.some((check) =>
        check.displayName === 'ParkinSUM prod Hosting uptime' &&
        check.monitoredResource?.labels?.host === 'parkinsum-companion.web.app',
      )),
    detail: monitoringState?.error ?? 'https://parkinsum-companion.web.app/',
  },
  {
    name: 'prod_hosting_uptime_alert_configured',
    pass:
      env !== 'prod' ||
      Boolean(monitoringState?.alertPolicies.some((policy) =>
        policy.displayName === 'ParkinSUM prod Hosting uptime alert' &&
        policy.enabled !== false,
      )),
    detail: monitoringState?.error ?? 'ParkinSUM prod Hosting uptime alert',
  },
  {
    name: 'prod_error_log_alert_configured',
    pass:
      env !== 'prod' ||
      Boolean(monitoringState?.alertPolicies.some((policy) =>
        policy.displayName === 'ParkinSUM prod ERROR log alert' &&
        policy.enabled !== false,
      )),
    detail: monitoringState?.error ?? 'ParkinSUM prod ERROR log alert',
  },
];
const failed = checks.filter((check) => !check.pass);
const report = {
  reportType: 'monitoring_gate',
  generatedAt: new Date().toISOString(),
  env,
  project,
  releaseId,
  strategy: 'google_cloud_logging_error_reporting_operator_audit',
  cloudApis: cloudApis
    ? {
        project,
        required: requiredProdCloudApis,
        enabledRequired: requiredProdCloudApis.filter((api) => cloudApis.enabled.includes(api)),
        status: cloudApis.error ? 'ERROR' : 'VERIFIED',
        error: cloudApis.error ?? null,
      }
    : {
        project,
        required: requiredProdCloudApis,
        status: 'NOT_REQUESTED',
      },
  monitoringState: monitoringState
    ? {
        notificationChannelCount: monitoringState.notificationChannels.length,
        uptimeCheckCount: monitoringState.uptimeChecks.length,
        alertPolicyCount: monitoringState.alertPolicies.length,
        serviceContactChannel:
          monitoringState.notificationChannels.find((channel) =>
            channel.type === 'email' && channel.labels?.email_address === supportContact,
          )?.name ?? null,
        uptimeCheck:
          monitoringState.uptimeChecks.find((check) =>
            check.displayName === 'ParkinSUM prod Hosting uptime',
          )?.name ?? null,
        uptimeAlert:
          monitoringState.alertPolicies.find((policy) =>
            policy.displayName === 'ParkinSUM prod Hosting uptime alert',
          )?.name ?? null,
        errorAlert:
          monitoringState.alertPolicies.find((policy) =>
            policy.displayName === 'ParkinSUM prod ERROR log alert',
          )?.name ?? null,
        error: monitoringState.error ?? null,
      }
    : null,
  pass: failed.length === 0,
  publicReleaseDecision: 'HOLD_PUBLIC_PROFESSIONAL_REVIEW_NOT_CLAIMED',
  checks,
  publicBlockers: ['external clinical/legal professional review is not claimed by owner/operator sign-off'],
};

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, `${JSON.stringify(report, null, 2)}\n`);
fs.writeFileSync(markdownOutput, renderMarkdown(report));
console.log(JSON.stringify({ output, markdownOutput, pass: report.pass }, null, 2));
if (!report.pass) process.exit(1);

function latestFile(dir, pattern) {
  if (!fs.existsSync(dir)) return null;
  const files = fs.readdirSync(dir)
    .filter((file) => pattern.test(file))
    .map((file) => path.join(dir, file))
    .sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);
  return files[0] ?? null;
}

function readEnabledCloudApis(projectId) {
  try {
    const stdout = execFileSync(
      'gcloud',
      [
        'services',
        'list',
        '--enabled',
        `--project=${projectId}`,
        '--filter=NAME:(logging.googleapis.com OR clouderrorreporting.googleapis.com)',
        '--format=value(config.name)',
      ],
      { encoding: 'utf8' },
    );
    return {
      enabled: stdout
        .split(/\r?\n/)
        .map((line) => line.trim())
        .filter(Boolean),
    };
  } catch (error) {
    return {
      enabled: [],
      error: error.message,
    };
  }
}

async function readMonitoringState(projectId) {
  try {
    return {
      notificationChannels:
        (await monitoringApiGet(projectId, 'notificationChannels')).notificationChannels ?? [],
      uptimeChecks: (await monitoringApiGet(projectId, 'uptimeCheckConfigs')).uptimeCheckConfigs ?? [],
      alertPolicies: (await monitoringApiGet(projectId, 'alertPolicies')).alertPolicies ?? [],
    };
  } catch (error) {
    return {
      notificationChannels: [],
      uptimeChecks: [],
      alertPolicies: [],
      error: error.message,
    };
  }
}

async function monitoringApiGet(projectId, collection) {
  const token = execFileSync('gcloud', ['auth', 'print-access-token'], { encoding: 'utf8' }).trim();
  const response = await fetch(
    `https://monitoring.googleapis.com/v3/projects/${projectId}/${collection}`,
    { headers: { Authorization: `Bearer ${token}` } },
  );
  const parsed = await response.json();
  if (parsed.error) {
    throw new Error(`${collection}: ${parsed.error.message}`);
  }
  return parsed;
}

function readFinalSignoffPackage() {
  const filePath = 'build/clinical_review/final_signoff_package_20260522.json';
  if (!fs.existsSync(filePath)) return null;
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch (_) {
    return null;
  }
}

function renderMarkdown(report) {
  return `# Monitoring Gate

Release id: ${report.releaseId}
Environment: ${report.env}
Project: ${report.project ?? 'not requested'}
Strategy: ${report.strategy}
Result: ${report.pass ? 'PASS' : 'FAIL'}
Public release decision: ${report.publicReleaseDecision}

## Cloud APIs

Status: ${report.cloudApis.status}
Required: ${report.cloudApis.required.join(', ')}
Enabled required: ${report.cloudApis.enabledRequired?.join(', ') ?? 'not checked'}

| Check | Result |
| --- | --- |
${report.checks.map((item) => `| ${item.name} | ${item.pass ? 'PASS' : 'FAIL'} |`).join('\n')}

## Public Blockers

${report.publicBlockers.map((item) => `- ${item}`).join('\n')}
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
