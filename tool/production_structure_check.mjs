#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const args = parseArgs(process.argv.slice(2));
const releaseId = args['release-id'] ?? `production_structure_${timestamp()}`;
const output =
  args.output ??
  path.join('build', 'operator_reports', `${releaseId}_production_structure.json`);
const markdownOutput = output.replace(/\.json$/, '.md');

const checks = [
  checkFirebaseRc(),
  checkFirebaseJson(),
  checkFirebaseOptions(),
  checkFirestoreFiles(),
  checkReleaseManifest('stage', 'build/release_manifests/p0_stage_20260522T000753Z.json'),
  checkReleaseManifest('prod', 'build/release_manifests/p0_prod_20260522T001247Z.json'),
  checkAcceptanceReport(),
  checkPolicyDocs(),
  checkFinalSignoffPackage(),
  checkPublicVisualSmoke(),
  checkInternalGovernanceEvidence(),
];

const failed = checks.filter((check) => !check.pass);
const report = {
  reportType: 'production_structure_check',
  generatedAt: new Date().toISOString(),
  releaseId,
  internalPrereleaseDecision: failed.length === 0 ? 'PASS_INTERNAL_PRIVATE_PRERELEASE' : 'BLOCKED',
  publicReleaseDecision: 'HOLD_PUBLIC_PROFESSIONAL_REVIEW_NOT_CLAIMED',
  checks,
  pass: failed.length === 0,
  publicBlockers: [
    'external clinical/legal professional review is not claimed by owner/operator sign-off',
  ],
};

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, `${JSON.stringify(report, null, 2)}\n`);
fs.writeFileSync(markdownOutput, renderMarkdown(report));
console.log(JSON.stringify({ output, markdownOutput, pass: report.pass }, null, 2));
if (!report.pass) process.exit(1);

function checkFirebaseRc() {
  return readJson('.firebaserc', (config) => {
    const projects = config.projects ?? {};
    return expectAll('firebaserc_env_aliases', [
      ['dev alias', projects.dev === 'parkinsum-companion-dev'],
      ['stage alias', projects.stage === 'parkinsum-companion-stage'],
      ['prod alias', projects.prod === 'parkinsum-companion'],
      ['default is not prod', projects.default !== 'parkinsum-companion'],
    ]);
  });
}

function checkFirebaseJson() {
  return readJson('firebase.json', (config) => {
    const hosting = config.hosting ?? {};
    const headers = hosting.headers ?? [];
    const headerValue = (source) =>
      headers.find((entry) => entry.source === source)?.headers?.find(
        (header) => header.key.toLowerCase() === 'cache-control',
      )?.value;
    return expectAll('firebase_hosting_config', [
      ['firestore rules path', config.firestore?.rules === 'firestore.rules'],
      ['firestore indexes path', config.firestore?.indexes === 'firestore.indexes.json'],
      ['hosting public build/web', hosting.public === 'build/web'],
      ['index no-store', headerValue('/index.html') === 'no-store, max-age=0'],
      ['root no-store', headerValue('/') === 'no-store, max-age=0'],
      [
        'asset immutable cache',
        headers.some((entry) =>
          String(entry.source).includes('js|mjs|css|wasm') &&
          entry.headers?.some((header) =>
            header.key.toLowerCase() === 'cache-control' &&
            String(header.value).includes('immutable'),
          ),
        ),
      ],
      ['spa rewrite exists', hosting.rewrites?.some((entry) => entry.source === '**' && entry.destination === '/index.html')],
    ]);
  });
}

function checkFirebaseOptions() {
  const source = fs.readFileSync('lib/firebase_options.dart', 'utf8');
  return expectAll('firebase_options_envs', [
    ['dev project constant', source.includes("developmentProjectId = 'parkinsum-companion-dev'")],
    ['stage project constant', source.includes("stagingProjectId = 'parkinsum-companion-stage'")],
    ['prod project constant', source.includes("productionProjectId = 'parkinsum-companion'")],
    ['devWeb config', /static const FirebaseOptions devWeb[\s\S]*projectId:\s*'parkinsum-companion-dev'/.test(source)],
    ['stageWeb config', /static const FirebaseOptions stageWeb[\s\S]*projectId:\s*'parkinsum-companion-stage'/.test(source)],
    ['prod web config', /static const FirebaseOptions web[\s\S]*projectId:\s*'parkinsum-companion'/.test(source)],
    ['dev non-web fail-fast', source.includes('PARKINSUM_ENV=dev are currently generated') && source.includes('for web only')],
    ['stage non-web fail-fast', source.includes('PARKINSUM_ENV=stage are currently generated') && source.includes('for web only')],
  ]);
}

function checkFirestoreFiles() {
  const rules = fs.readFileSync('firestore.rules', 'utf8');
  const indexes = fs.existsSync('firestore.indexes.json');
  return expectAll('firestore_rules_and_indexes', [
    ['rules file exists', rules.length > 0],
    ['indexes file exists', indexes],
    ['users owner-only rule', /match\s+\/users\/\{uid\}\/\{document=\*\*\}[\s\S]*allow\s+read,\s*write:\s*if\s+isOwner\(uid\)/.test(rules)],
    ['catalog signed-in read', /match\s+\/app_catalog\/\{table\}\/rows\/\{rowId\}[\s\S]*allow\s+read:\s*if\s+signedIn\(\)/.test(rules)],
    ['catalog admin importer write', /match\s+\/app_catalog\/\{table\}\/rows\/\{rowId\}[\s\S]*allow\s+write:\s*if\s+isAdminOrImporter\(\)/.test(rules)],
    ['top-level cdss denied', /match\s+\/cdss_tables\/\{table\}\/rows\/\{rowId\}[\s\S]*allow\s+read,\s*write:\s*if\s+false/.test(rules)],
    ['fallback deny-all', /match\s+\/\{document=\*\*\}[\s\S]*allow\s+read,\s*write:\s*if\s+false/.test(rules)],
  ]);
}

function checkReleaseManifest(env, filePath) {
  return readJson(filePath, (manifest) => {
    const expectedProject = env === 'stage' ? 'parkinsum-companion-stage' : 'parkinsum-companion';
    const expectedUrl = env === 'stage'
      ? 'https://parkinsum-companion-stage.web.app'
      : 'https://parkinsum-companion.web.app';
    const sourceBundle = manifest.source?.sourceBundle;
    const sourceHash = sourceBundle && fs.existsSync(sourceBundle)
      ? sha256File(sourceBundle)
      : null;
    return expectAll(`${env}_release_manifest`, [
      ['environment', manifest.environment === env],
      ['project id', manifest.firebase?.projectId === expectedProject],
      ['hosting url', manifest.firebase?.hostingUrl === expectedUrl],
      ['hosting release id', typeof manifest.firebase?.hostingCurrentRelease === 'string' && manifest.firebase.hostingCurrentRelease.includes('/releases/')],
      ['source bundle exists', typeof sourceBundle === 'string' && fs.existsSync(sourceBundle)],
      ['source bundle sha matches', sourceHash != null && sourceHash === manifest.source?.sourceBundleSha256],
      ['web artifact sha recorded', /^[a-f0-9]{64}$/.test(manifest.artifacts?.webBuildSha256 ?? '')],
      ['public release hold recorded', String(manifest.publicReleaseDecision).startsWith('HOLD')],
      ['p1 operator gate recorded', manifest.p1OperatorGate?.technicalPass === true],
    ]);
  });
}

function checkAcceptanceReport() {
  return readJson('build/acceptance_reports/p0_stage_real_data_acceptance_20260522.json', (report) =>
    expectAll('real_data_acceptance_report', [
      [
        'stage acceptance pass',
        report.acceptanceDecision === 'PASS_WITH_PUBLIC_RELEASE_BLOCKERS' ||
          report.readiness?.blockingCount === 0 ||
          report.readiness?.blockers?.length === 0,
      ],
      [
        'documents uploaded',
        report.stageUpload?.uploadedDocuments === 504 ||
          report.stageUpload?.documentCount === 504 ||
          report.documentCount === 504,
      ],
      ['snapshot id present', Boolean(report.snapshot?.snapshotId ?? report.snapshotId)],
      [
        'rollback target recorded or explicitly first snapshot',
        Boolean(report.rollback?.target ?? report.rollbackTarget) ||
          report.parentSnapshotId === null ||
          report.readiness?.rollbackTarget === null,
      ],
    ]),
  );
}

function checkPolicyDocs() {
  const privacy = fs.readFileSync('docs/privacy_policy_draft.md', 'utf8');
  const disclaimer = fs.readFileSync('docs/privacy_disclaimer_draft.md', 'utf8');
  const risks = fs.readFileSync('docs/known_risks.md', 'utf8');
  return expectAll('privacy_disclaimer_risk_docs', [
    ['privacy contact published', privacy.includes('Privacy contact: parkinsumservice@gmail.com')],
    ['support contact published', privacy.includes('Support contact: parkinsumservice@gmail.com')],
    ['in-app disclaimer entry documented', disclaimer.includes('In-app Privacy & Disclaimer entry exists')],
    ['known risks backup open', risks.includes('Backup Export and Restore') || risks.includes('Backup export and restore')],
    ['known risks prod probe open or tracked', risks.includes('Prod Live Signed-In Probe')],
    ['known risks monitoring tracked', risks.includes('Monitoring and Audit')],
  ]);
}

function checkFinalSignoffPackage() {
  return readJson('build/clinical_review/final_signoff_package_20260522.json', (report) =>
    expectAll('final_signoff_package', [
      ['owner identity', report.signoff?.owner === 'zhouzhenghang'],
      ['owner role', report.signoff?.role === 'owner/operator'],
      ['contact email', report.signoff?.contact === 'parkinsumservice@gmail.com'],
      ['internal acceptance', report.signoff?.scope === 'internal_private_prerelease'],
      ['professional review not claimed', report.publicCaveat === 'external_clinical_legal_professional_review_not_claimed'],
    ]),
  );
}

function checkPublicVisualSmoke() {
  const filePath = fs.existsSync('build/browser_smoke/internal_contact_visual_smoke_20260523.json')
    ? 'build/browser_smoke/internal_contact_visual_smoke_20260523.json'
    : 'build/browser_smoke/public_visual_smoke_20260523.json';
  return readJson(filePath, (report) =>
    expectAll('public_visual_smoke', [
      ['visual smoke pass', report.status === 'PASS'],
      ['stage pass', String(report.targets?.stage?.status).startsWith('PASS')],
      ['prod pass', String(report.targets?.prod?.status).startsWith('PASS')],
      ['read-only', report.readOnly === true],
      ['no release-blocking console errors', report.releaseBlockingConsoleErrors === 0],
      [
        'service contact visual evidence',
        filePath.includes('internal_contact')
          ? report.targets?.stage?.visualContactVerified === true &&
            report.targets?.prod?.visualContactVerified === true
          : true,
      ],
    ]),
  );
}

function checkInternalGovernanceEvidence() {
  return expectAll('internal_governance_evidence', [
    [
      'iam governance pass',
      readPass('build/operator_reports/internal_iam_governance_20260523_iam_governance.json'),
    ],
    [
      'monitoring alert setup pass',
      readPass('build/operator_reports/internal_monitoring_alerts_20260523_monitoring_alert_setup.json'),
    ],
    [
      'monitoring alert gate pass',
      readPass('build/operator_reports/internal_monitoring_alerts_20260523_monitoring_gate.json'),
    ],
    [
      'prod readonly lifecycle pass',
      readPass('build/operator_reports/internal_prod_readonly_lifecycle_20260523_prod_readonly_lifecycle.json'),
    ],
    [
      'prod manual backup export pass',
      readPass('build/operator_reports/internal_prod_backup_export_20260523.json'),
    ],
    [
      'safety verification pass',
      readPass('build/operator_reports/internal_safety_verification_20260523.json'),
    ],
    [
      'internal release index exists',
      fs.existsSync('docs/internal_prerelease_release_index_20260523.md') &&
        fs.readFileSync('docs/internal_prerelease_release_index_20260523.md', 'utf8')
          .includes('internal_governance_20260523'),
    ],
    [
      'owner acceptance record exists',
      fs.existsSync('docs/internal_prerelease_acceptance_20260523.md') &&
        fs.readFileSync('docs/internal_prerelease_acceptance_20260523.md', 'utf8')
          .includes('parkinsumservice@gmail.com'),
    ],
  ]);
}

function readPass(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8')).pass === true;
  } catch (_) {
    return false;
  }
}

function readJson(filePath, fn) {
  try {
    const json = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    return fn(json);
  } catch (error) {
    return {
      name: path.basename(filePath),
      pass: false,
      details: [{ label: 'parse/read', pass: false, detail: error.message }],
    };
  }
}

function expectAll(name, expectations) {
  const details = expectations.map(([label, pass]) => ({ label, pass: Boolean(pass) }));
  return { name, pass: details.every((item) => item.pass), details };
}

function sha256File(filePath) {
  return crypto.createHash('sha256').update(fs.readFileSync(filePath)).digest('hex');
}

function renderMarkdown(report) {
  return `# Production Structure Check

Release id: ${report.releaseId}
Generated at: ${report.generatedAt}
Internal prerelease decision: ${report.internalPrereleaseDecision}
Public release decision: ${report.publicReleaseDecision}

| Check | Result |
| --- | --- |
${report.checks.map((check) => `| ${check.name} | ${check.pass ? 'PASS' : 'FAIL'} |`).join('\n')}

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
