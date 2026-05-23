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
const releaseId = args['release-id'] ?? `operator_gate_${environment}_${timestamp()}`;
const output =
  args.output ?? path.join('build', 'operator_reports', `${releaseId}_operator_gate.json`);
const markdownOutput = output.replace(/\.json$/, '.md');
const readOnly = Boolean(args['read-only']) || environment === 'prod';
const retainedEvidence = Boolean(args['retained-evidence']);
const retainedReleaseId =
  args['retained-release-id'] ??
  (environment === 'prod'
    ? 'p0p1_prod_full_structure_20260522'
    : 'p0p1_stage_full_structure_20260522');
const finalSignoff = readJsonOrNull('build/clinical_review/final_signoff_package_20260522.json');

const checks = [];
checks.push(runNodeCheck('production_structure', ['tool/production_structure_check.mjs', '--release-id', releaseId]));
checks.push(runNodeCheck('rules_contract', ['tool/firestore_rules_contract_check.mjs']));
checks.push(validateJson('stage_release_manifest', 'build/release_manifests/p0_stage_20260522T000753Z.json'));
checks.push(validateJson('prod_release_manifest', 'build/release_manifests/p0_prod_20260522T001247Z.json'));
checks.push(validateJson('real_data_acceptance', 'build/acceptance_reports/p0_stage_real_data_acceptance_20260522.json'));
checks.push(validateFinalSignoff());
checks.push(validateBrowserPublicSmoke());
checks.push(
  retainedEvidence
    ? validateRetainedReport('hosting_smoke_retained', path.join('build', 'browser_smoke', `${retainedReleaseId}_hosting_smoke.json`))
    : runNodeCheck('hosting_smoke', ['tool/hosting_smoke.mjs', '--release-id', releaseId]),
);
checks.push(runNodeCheck('backup_command', [
  'tool/firebase_ops.mjs',
  'backup-command',
  '--env',
  environment,
  '--project',
  projectId,
  '--release-id',
  releaseId,
  '--bucket',
  environment === 'prod'
    ? 'gs://parkinsum-prod-backups'
    : 'gs://parkinsum-companion-stage-p0-backups',
]));
checks.push(
  retainedEvidence
    ? validateRetainedReport('backup_prereq_retained', retainedBackupPrereqPath(), { allowBlockedNoBilling: false })
    : runNodeCheck('backup_prereq', [
      'tool/backup_prereq_check.mjs',
      '--env',
      environment,
      '--project',
      projectId,
      '--release-id',
      releaseId,
    ]),
);
checks.push(retainedEvidence ? validateRetainedLiveProbe() : runLiveProbe());
checks.push(
  retainedEvidence
    ? validateRetainedReport('authenticated_e2e_smoke_retained', path.join('build', 'e2e_smoke', `${retainedReleaseId}_authenticated_e2e.json`))
    : runAuthenticatedE2eSmoke(),
);
checks.push(
  retainedEvidence
    ? validateRetainedReport('audit_summary_retained', path.join('build', 'operator_reports', `${retainedReleaseId}_audit_summary.json`))
    : runNodeCheck('audit_summary', ['tool/operator_audit_summary.mjs', '--release-id', releaseId]),
);
checks.push(
  retainedEvidence
    ? validateRetainedReport('monitoring_gate_retained', retainedMonitoringGatePath())
    : runNodeCheck('monitoring_gate', [
      'tool/monitoring_gate.mjs',
      '--env',
      environment,
      '--project',
      projectId,
      '--release-id',
      releaseId,
    ]),
);
checks.push(
  retainedEvidence
    ? validateRetainedReport('clinical_engine_gate_retained', path.join('build', 'clinical_review', `${retainedReleaseId}_clinical_engine_gate.json`))
    : runNodeCheck('clinical_engine_gate', ['tool/clinical_engine_gate.mjs', '--release-id', releaseId]),
);
checks.push(
  retainedEvidence
    ? validateRetainedReport('clinical_review_retained', path.join('build', 'clinical_review', `${retainedReleaseId}_clinical_review.json`))
    : runNodeCheck('clinical_review', ['tool/clinical_review_report.mjs', '--release-id', releaseId]),
);

const technicalFailures = checks.filter((check) => check.required && !check.pass);
const report = {
  reportType: 'operator_gate',
  generatedAt: new Date().toISOString(),
  releaseId,
  environment,
  projectId,
  readOnly,
  retainedEvidence,
  retainedReleaseId: retainedEvidence ? retainedReleaseId : null,
  internalPrereleaseDecision: technicalFailures.length === 0 ? 'PASS_INTERNAL_PRIVATE_PRERELEASE' : 'BLOCKED',
  publicReleaseDecision: 'HOLD_PUBLIC_PROFESSIONAL_REVIEW_NOT_CLAIMED',
  decisionReason:
    'Internal/private prerelease passes when technical gates pass and owner/operator acceptance is recorded; public external clinical/legal professional review is not claimed.',
  checks,
  technicalPass: technicalFailures.length === 0,
  blockers: [
    'external clinical/legal professional review is not claimed by owner/operator sign-off',
    ...(environment === 'prod' && fs.existsSync('build/operator_tokens/prod_readonly_tokens.json')
      ? ['prod readonly disposable Auth test accounts are retained enabled by operator decision']
      : []),
    ...(environment === 'prod' && !fs.existsSync('build/operator_tokens/prod_readonly_tokens.json')
      ? ['prod read-only token file missing; run tool/firebase_prod_readonly_accounts.mjs']
      : []),
  ],
};

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, `${JSON.stringify(report, null, 2)}\n`);
fs.writeFileSync(markdownOutput, renderMarkdown(report));
console.log(JSON.stringify({ output, markdownOutput, technicalPass: report.technicalPass, publicReleaseDecision: report.publicReleaseDecision }, null, 2));
if (!report.technicalPass) process.exit(1);

function runLiveProbe() {
  const command = ['tool/firestore_live_probe.mjs', '--env', environment, '--project', projectId, '--run-id', `${releaseId}_live_probe`];
  if (readOnly) command.push('--read-only');
  if (environment === 'prod') {
    const tokenFile = 'build/operator_tokens/prod_readonly_tokens.json';
    if (fs.existsSync(tokenFile)) command.push('--token-file', tokenFile);
  } else {
    const tokenFile = 'build/operator_tokens/stage_test_tokens_p0.json';
    const clearedTokenFile = 'build/operator_tokens/stage_test_tokens_p0_cleared.json';
    if (fs.existsSync(tokenFile)) command.push('--token-file', tokenFile);
    if (fs.existsSync(clearedTokenFile)) command.push('--cleared-token-file', clearedTokenFile, '--skip-privileged-allow');
  }
  return runNodeCheck('firestore_live_probe', command);
}

function runAuthenticatedE2eSmoke() {
  const command = ['tool/authenticated_e2e_smoke.mjs', '--env', environment, '--project', projectId, '--release-id', releaseId];
  if (readOnly) command.push('--read-only');
  const tokenFile = environment === 'prod'
    ? 'build/operator_tokens/prod_readonly_tokens.json'
    : 'build/operator_tokens/stage_test_tokens_p0.json';
  if (fs.existsSync(tokenFile)) {
    command.push('--token-file', tokenFile);
  }
  return runNodeCheck('authenticated_e2e_smoke', command);
}

function validateRetainedLiveProbe() {
  const gatePath = path.join('build', 'operator_reports', `${retainedReleaseId}_operator_gate.json`);
  try {
    const gate = JSON.parse(fs.readFileSync(gatePath, 'utf8'));
    const liveProbe = gate.checks?.find((check) => check.name === 'firestore_live_probe');
    const pass = Boolean(liveProbe?.pass);
    return {
      name: 'firestore_live_probe_retained',
      filePath: gatePath,
      pass,
      required: true,
      retained: true,
      detail: pass
        ? 'Retained operator gate contains passing live probe evidence.'
        : 'Retained live probe evidence is missing or failed.',
    };
  } catch (error) {
    return {
      name: 'firestore_live_probe_retained',
      filePath: gatePath,
      pass: false,
      required: true,
      retained: true,
      error: error.message,
    };
  }
}

function retainedBackupPrereqPath() {
  const afterBilling = path.join(
    'build',
    'operator_reports',
    'prod_backup_after_billing_20260522_backup_prereq.json',
  );
  if (environment === 'prod' && fs.existsSync(afterBilling)) return afterBilling;
  return path.join('build', 'operator_reports', `${retainedReleaseId}_backup_prereq.json`);
}

function retainedMonitoringGatePath() {
  const internalAlerts = path.join(
    'build',
    'operator_reports',
    'internal_monitoring_alerts_20260523_monitoring_gate.json',
  );
  if (environment === 'prod' && fs.existsSync(internalAlerts)) return internalAlerts;
  const prodCloud = path.join(
    'build',
    'operator_reports',
    'prod_cloud_monitoring_20260522_monitoring_gate.json',
  );
  if (environment === 'prod' && fs.existsSync(prodCloud)) return prodCloud;
  return path.join('build', 'operator_reports', `${retainedReleaseId}_monitoring_gate.json`);
}

function validateRetainedReport(name, filePath, options = {}) {
  try {
    const report = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    const inferredPass =
      (report.reportType === 'operator_audit_summary' &&
        Array.isArray(report.sanitizedSamples) &&
        Boolean(report.redactionPolicy)) ||
      (report.reportType === 'monitoring_gate' &&
        report.pass === true &&
        report.publicReleaseDecision === 'HOLD_PUBLIC_PROFESSIONAL_REVIEW_NOT_CLAIMED') ||
      ((report.reportType === 'clinical_review_report' || report.reportType === 'clinical_review') &&
        Array.isArray(report.cases) &&
        report.cases.length > 0 &&
        report.publicReleaseDecision === 'HOLD');
    const pass = Boolean(report.pass ?? report.technicalPass) ||
      inferredPass ||
      (options.allowBlockedNoBilling && report.status === 'BLOCKED_NO_BILLING_OR_BUCKET');
    return {
      name,
      filePath,
      pass,
      required: true,
      retained: true,
      status: report.status,
      publicReleaseDecision: report.publicReleaseDecision,
      detail: pass ? 'Retained report validated.' : 'Retained report is present but not passing.',
    };
  } catch (error) {
    return {
      name,
      filePath,
      pass: false,
      required: true,
      retained: true,
      error: error.message,
    };
  }
}

function runNodeCheck(name, command) {
  const result = spawnSync(process.execPath, command, {
    cwd: process.cwd(),
    encoding: 'utf8',
    maxBuffer: 1024 * 1024 * 8,
  });
  return {
    name,
    command: [path.basename(process.execPath), ...command].join(' '),
    status: result.status,
    pass: result.status === 0,
    required: true,
    stdout: sanitizeOutput(result.stdout),
    stderr: sanitizeOutput(result.stderr),
  };
}

function validateJson(name, filePath) {
  try {
    JSON.parse(fs.readFileSync(filePath, 'utf8'));
    return { name, filePath, pass: true, required: true };
  } catch (error) {
    return { name, filePath, pass: false, required: true, error: error.message };
  }
}

function validateFinalSignoff() {
  const filePath = 'build/clinical_review/final_signoff_package_20260522.json';
  const pass =
    finalSignoff?.signoff?.owner === 'zhouzhenghang' &&
    finalSignoff?.signoff?.role === 'owner/operator' &&
    finalSignoff?.signoff?.contact === 'parkinsumservice@gmail.com' &&
    finalSignoff?.signoff?.scope === 'internal_private_prerelease' &&
    finalSignoff?.signoff?.status === 'owner_accepted_internal_prerelease' &&
    finalSignoff?.publicCaveat === 'external_clinical_legal_professional_review_not_claimed';
  return {
    name: 'final_signoff_package',
    filePath,
    pass,
    required: true,
    publicReleaseDecision: finalSignoff?.publicReleaseDecision,
    detail: pass
      ? 'Owner/operator internal prerelease acceptance is recorded.'
      : 'Final signoff package is missing owner/operator acceptance.',
  };
}

function validateBrowserPublicSmoke() {
  const filePath = fs.existsSync('build/browser_smoke/internal_contact_visual_smoke_20260523.json')
    ? 'build/browser_smoke/internal_contact_visual_smoke_20260523.json'
    : fs.existsSync('build/browser_smoke/public_visual_smoke_20260523.json')
    ? 'build/browser_smoke/public_visual_smoke_20260523.json'
    : 'build/browser_smoke/p0p1_public_browser_smoke_20260522.json';
  try {
    const report = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    const pass = report.status === 'PASS' ||
      (report.targets?.stage?.status === 'PASS' && report.targets?.prod?.status === 'PASS');
    return {
      name: 'browser_public_smoke_record',
      filePath,
      pass,
      required: true,
      status: report.status,
      note:
        report.status === 'BLOCKED_BY_BROWSER_POLICY'
          ? 'Browser visual smoke was attempted but blocked by the browser automation policy; HTTP Hosting smoke remains the technical gate.'
          : undefined,
    };
  } catch (error) {
    return {
      name: 'browser_public_smoke_record',
      filePath,
      pass: false,
      required: false,
      error: error.message,
    };
  }
}

function readJsonOrNull(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch (_) {
    return null;
  }
}

function sanitizeOutput(value) {
  return String(value ?? '')
    .replace(/("?(?:idToken|refreshToken|token|authorization)"?\s*:\s*)"[^"]+"/gi, '$1"[REDACTED]"')
    .slice(0, 4000);
}

function renderMarkdown(report) {
  return `# Operator Gate Report

Release id: ${report.releaseId}
Environment: ${report.environment}
Firebase project: ${report.projectId}
Generated at: ${report.generatedAt}
Retained evidence: ${report.retainedEvidence ? report.retainedReleaseId : 'no'}
Technical pass: ${report.technicalPass ? 'PASS' : 'FAIL'}
Internal prerelease decision: ${report.internalPrereleaseDecision}
Public release decision: ${report.publicReleaseDecision}

## Checks

| Check | Result |
| --- | --- |
${report.checks.map((item) => {
  const result = item.pass ? 'PASS' : 'FAIL';
  const suffix = item.required === false ? ' (advisory)' : '';
  return `| ${item.name} | ${result}${suffix} |`;
}).join('\n')}

## Blockers

${report.blockers.map((item) => `- ${item}`).join('\n')}
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

function timestamp() {
  return new Date().toISOString().replace(/[:.]/g, '').slice(0, 15);
}
