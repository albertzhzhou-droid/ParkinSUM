#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const args = parseArgs(process.argv.slice(2));
const project = args.project ?? process.env.PARKINSUM_FIREBASE_PROJECT_ID ?? 'parkinsum-companion';
const releaseId = args['release-id'] ?? `monitoring_alert_setup_${timestamp()}`;
const contactEmail = args.email ?? 'parkinsumservice@gmail.com';
const output =
  args.output ?? path.join('build', 'operator_reports', `${releaseId}_monitoring_alert_setup.json`);
const markdownOutput = output.replace(/\.json$/, '.md');
const hostingHost = 'parkinsum-companion.web.app';
const token = execFileSync('gcloud', ['auth', 'print-access-token'], { encoding: 'utf8' }).trim();

const before = await readMonitoringState();
const channel = await ensureNotificationChannel(before.notificationChannels);
const afterChannel = await readMonitoringState();
const uptimeCheck = await ensureUptimeCheck(afterChannel.uptimeChecks);
const afterUptime = await readMonitoringState();
const uptimeAlert = await ensureUptimeAlert(afterUptime.alertPolicies, uptimeCheck, channel);
const afterUptimeAlert = await readMonitoringState();
const errorAlert = await ensureErrorAlert(afterUptimeAlert.alertPolicies, channel);
const finalState = await readMonitoringState();

const report = {
  reportType: 'monitoring_alert_setup',
  generatedAt: new Date().toISOString(),
  releaseId,
  project,
  contactEmail,
  notificationChannel: {
    name: channel.name,
    displayName: channel.displayName,
    type: channel.type,
    verificationStatus: channel.verificationStatus ?? 'UNKNOWN',
    existedBefore: before.notificationChannels.some((item) => item.name === channel.name),
  },
  uptimeCheck: {
    name: uptimeCheck.name,
    displayName: uptimeCheck.displayName,
    host: uptimeCheck.monitoredResource?.labels?.host,
    existedBefore: before.uptimeChecks.some((item) => item.name === uptimeCheck.name),
  },
  alertPolicies: {
    uptime: {
      name: uptimeAlert.name,
      displayName: uptimeAlert.displayName,
      enabled: uptimeAlert.enabled !== false,
      existedBefore: afterUptime.alertPolicies.some((item) => item.name === uptimeAlert.name),
    },
    errorLogs: {
      name: errorAlert.name,
      displayName: errorAlert.displayName,
      enabled: errorAlert.enabled !== false,
      existedBefore: afterUptimeAlert.alertPolicies.some((item) => item.name === errorAlert.name),
    },
  },
  counts: {
    notificationChannels: finalState.notificationChannels.length,
    uptimeChecks: finalState.uptimeChecks.length,
    alertPolicies: finalState.alertPolicies.length,
  },
  pass: true,
  notes: [
    channel.verificationStatus === 'VERIFIED'
      ? 'Email notification channel is verified.'
      : 'Email notification channel exists; Google may require recipient verification before delivery.',
    'No third-party analytics or Crashlytics were enabled by this setup.',
  ],
};

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, `${JSON.stringify(report, null, 2)}\n`);
fs.writeFileSync(markdownOutput, renderMarkdown(report));
console.log(JSON.stringify({ output, markdownOutput, pass: report.pass }, null, 2));

async function ensureNotificationChannel(channels) {
  const existing = channels.find((channel) =>
    channel.type === 'email' &&
    channel.labels?.email_address === contactEmail &&
    channel.enabled !== false,
  );
  if (existing) return existing;
  return apiPost('notificationChannels', {
    type: 'email',
    displayName: 'ParkinSUM service email',
    labels: { email_address: contactEmail },
    enabled: true,
  });
}

async function ensureUptimeCheck(uptimeChecks) {
  const existing = uptimeChecks.find((check) =>
    check.displayName === 'ParkinSUM prod Hosting uptime' &&
    check.monitoredResource?.labels?.host === hostingHost,
  );
  if (existing) return existing;
  return apiPost('uptimeCheckConfigs', {
    displayName: 'ParkinSUM prod Hosting uptime',
    period: '60s',
    timeout: '10s',
    monitoredResource: {
      type: 'uptime_url',
      labels: {
        project_id: project,
        host: hostingHost,
      },
    },
    httpCheck: {
      requestMethod: 'GET',
      useSsl: true,
      port: 443,
      path: '/',
      acceptedResponseStatusCodes: [{ statusClass: 'STATUS_CLASS_2XX' }],
    },
  });
}

async function ensureUptimeAlert(alertPolicies, uptimeCheck, channel) {
  const existing = alertPolicies.find((policy) =>
    policy.displayName === 'ParkinSUM prod Hosting uptime alert' &&
    policy.enabled !== false,
  );
  if (existing) return existing;
  const checkId = String(uptimeCheck.name).split('/').pop();
  return apiPost('alertPolicies', {
    displayName: 'ParkinSUM prod Hosting uptime alert',
    combiner: 'OR',
    enabled: true,
    notificationChannels: [channel.name],
    conditions: [
      {
        displayName: 'ParkinSUM prod Hosting uptime failed',
        conditionThreshold: {
          filter:
            `metric.type="monitoring.googleapis.com/uptime_check/check_passed" ` +
            `AND resource.type="uptime_url" AND metric.label."check_id"="${checkId}"`,
          comparison: 'COMPARISON_LT',
          thresholdValue: 1,
          duration: '180s',
          trigger: { count: 1 },
          aggregations: [
            {
              alignmentPeriod: '300s',
              perSeriesAligner: 'ALIGN_FRACTION_TRUE',
            },
          ],
        },
      },
    ],
    documentation: {
      content:
        'ParkinSUM prod Firebase Hosting did not pass uptime checks. Owner/operator must inspect Hosting, recent release, and rollback target within 24 hours.',
      mimeType: 'text/markdown',
    },
  });
}

async function ensureErrorAlert(alertPolicies, channel) {
  const existing = alertPolicies.find((policy) =>
    policy.displayName === 'ParkinSUM prod ERROR log alert' &&
    policy.enabled !== false,
  );
  if (existing) return existing;
  return apiPost('alertPolicies', {
    displayName: 'ParkinSUM prod ERROR log alert',
    combiner: 'OR',
    enabled: true,
    notificationChannels: [channel.name],
    conditions: [
      {
        displayName: 'ParkinSUM prod severity ERROR logs',
        conditionMatchedLog: {
          filter:
            'severity>=ERROR AND ' +
            '(resource.type="firebase_domain" OR resource.type="cloud_run_revision" OR resource.type="global")',
        },
      },
    ],
    alertStrategy: {
      notificationRateLimit: { period: '3600s' },
    },
    documentation: {
      content:
        'ParkinSUM prod emitted ERROR logs. Owner/operator must inspect the log entry, redact health data in any shared report, and decide whether rollback is needed.',
      mimeType: 'text/markdown',
    },
  });
}

async function readMonitoringState() {
  return {
    notificationChannels: (await apiGet('notificationChannels')).notificationChannels ?? [],
    uptimeChecks: (await apiGet('uptimeCheckConfigs')).uptimeCheckConfigs ?? [],
    alertPolicies: (await apiGet('alertPolicies')).alertPolicies ?? [],
  };
}

async function apiGet(collection) {
  const response = await fetch(`https://monitoring.googleapis.com/v3/projects/${project}/${collection}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const parsed = await response.json();
  if (!response.ok || parsed.error) {
    throw new Error(`${collection}: ${parsed.error?.message ?? response.statusText}`);
  }
  return parsed;
}

async function apiPost(collection, body) {
  const response = await fetch(`https://monitoring.googleapis.com/v3/projects/${project}/${collection}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  const parsed = await response.json();
  if (!response.ok || parsed.error) {
    throw new Error(`${collection}: ${parsed.error?.message ?? response.statusText}`);
  }
  return parsed;
}

function renderMarkdown(report) {
  return `# Monitoring Alert Setup

Release id: ${report.releaseId}
Generated at: ${report.generatedAt}
Project: ${report.project}
Contact email: ${report.contactEmail}
Result: ${report.pass ? 'PASS' : 'FAIL'}

## Notification Channel

- Name: \`${report.notificationChannel.name}\`
- Verification: \`${report.notificationChannel.verificationStatus}\`
- Existed before: ${report.notificationChannel.existedBefore}

## Uptime

- Check: \`${report.uptimeCheck.name}\`
- Host: \`${report.uptimeCheck.host}\`
- Alert policy: \`${report.alertPolicies.uptime.name}\`

## Error Logs

- Alert policy: \`${report.alertPolicies.errorLogs.name}\`

## Notes

${report.notes.map((note) => `- ${note}`).join('\n')}
`;
}

function parseArgs(argv) {
  const parsed = {};
  for (let i = 0; i < argv.length; i += 1) {
    const tokenArg = argv[i];
    if (!tokenArg.startsWith('--')) continue;
    const key = tokenArg.slice(2);
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
