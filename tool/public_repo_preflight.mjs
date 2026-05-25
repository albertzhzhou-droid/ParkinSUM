#!/usr/bin/env node

import fs from 'fs';
import path from 'path';

const root = process.cwd();
const outputDir = path.join(root, 'build', 'public_release_preflight');
const jsonPath = path.join(outputDir, 'latest.json');
const mdPath = path.join(outputDir, 'latest.md');

const supportContact = 'parkinsumservice@gmail.com';
const requiredFiles = [
  'README.md',
  'DISCLAIMER.md',
  'PUBLIC_SHOWCASE_READINESS.md',
  'SECURITY.md',
  'CONTRIBUTING.md',
  'CHANGELOG.md',
  'LICENSE',
  'docs/PUBLIC_DEMO_BOUNDARY.md',
  'docs/ARCHITECTURE.md',
  'docs/RELEASE_EVIDENCE_INDEX.md',
  'docs/demo-scenarios.md',
  'docs/release/v0.1.0-alpha-notes.md',
  'docs/release/synthetic-demo-data.md',
  'docs/release/release-checklist.md',
  '.github/ISSUE_TEMPLATE/bug_report.yml',
  '.github/ISSUE_TEMPLATE/config.yml',
  '.github/pull_request_template.md',
  '.github/workflows/public-release-preflight.yml',
];

const generatedDirs = [
  'build',
  'node_modules',
  '.dart_tool',
  'macos/Pods',
  '.firebase',
  '.pub-cache',
  'coverage',
];

const sensitiveDirs = [
  'build/operator_tokens',
  'build/user_exports',
  'build/operator_audit',
];

const sensitiveFilenamePatterns = [
  /(^|[/\\])\.env(\.|$)/,
  /service[-_]?account.*\.json$/i,
  /firebase[-_]?admin.*\.json$/i,
  /google[-_]?application[-_]?credentials.*\.json$/i,
  /credential.*\.json$/i,
  /\.(pem|p12|p8|key)$/i,
];

const textFilePattern =
  /\.(md|txt|json|yaml|yml|mjs|js|dart|sh|html|css|xml|plist|rules|lock|gitignore)$/i;
const maxScanBytes = 1024 * 1024;

const findings = [];
const oldPersonalContact = ['albertzhzhou', 'gmail.com'].join('@');

function add(severity, name, message, file = null) {
  findings.push({ severity, name, message, file });
}

function rel(filePath) {
  return path.relative(root, filePath).split(path.sep).join('/');
}

function exists(relPath) {
  return fs.existsSync(path.join(root, relPath));
}

function read(relPath) {
  return fs.readFileSync(path.join(root, relPath), 'utf8');
}

function listFiles(dir) {
  const out = [];
  const stack = [dir];
  while (stack.length) {
    const current = stack.pop();
    let entries = [];
    try {
      entries = fs.readdirSync(current, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const entry of entries) {
      const full = path.join(current, entry.name);
      const relative = rel(full);
      if (entry.isDirectory()) {
        if (entry.name === '.git') continue;
        stack.push(full);
      } else if (entry.isFile()) {
        out.push({ full, relative });
      }
    }
  }
  return out;
}

function isUnder(relative, dir) {
  return relative === dir || relative.startsWith(`${dir}/`);
}

function isGenerated(relative) {
  return generatedDirs.some((dir) => isUnder(relative, dir));
}

function isSensitiveDir(relative) {
  return sensitiveDirs.some((dir) => isUnder(relative, dir));
}

function isLikelyFirebaseWebConfig(relative, content) {
  return (
    /google-services\.json$/.test(relative) ||
    /GoogleService-Info\.plist$/.test(relative) ||
    relative === 'lib/firebase_options.dart' ||
    relative === 'firebase.json'
  ) && /api[_-]?key|API_KEY|mobilesdk_app_id|GOOGLE_APP_ID/i.test(content);
}

function checkRequiredFiles() {
  for (const file of requiredFiles) {
    if (!exists(file)) {
      add('BLOCKER', 'required_file_missing', `Missing required public release file: ${file}`, file);
    }
  }
}

function checkPublicDocs() {
  if (exists('LICENSE')) {
    const license = read('LICENSE');
    if (/Apache License\s+Version 2\.0/i.test(license)) {
      add('INFO', 'apache_license_detected', 'Apache-2.0 license text is present.', 'LICENSE');
    } else {
      add('BLOCKER', 'license_not_apache_2', 'LICENSE exists but does not look like Apache-2.0.', 'LICENSE');
    }
  }

  const docsToCheck = requiredFiles.filter((file) => exists(file));
  for (const file of docsToCheck) {
    const content = read(file);
    if (content.includes(oldPersonalContact)) {
      add('BLOCKER', 'old_contact_present', 'Old personal contact appears in public-facing file.', file);
    }
  }

  const userVisible = ['README.md', 'DISCLAIMER.md', 'PUBLIC_SHOWCASE_READINESS.md', 'SECURITY.md'];
  for (const file of userVisible) {
    if (!exists(file)) continue;
    const content = read(file);
    if (!content.includes(supportContact)) {
      add('BLOCKER', 'support_contact_missing', `Public-facing file does not contain ${supportContact}.`, file);
    }
  }

  const readme = exists('README.md') ? read('README.md') : '';
  if (!/production-architecture prototype/i.test(readme)) {
    add('BLOCKER', 'readme_positioning_missing', 'README does not state production-architecture prototype positioning.', 'README.md');
  }
  const staleReadmePattern = new RegExp(
    [
      'public release remains blocked',
      'support/privacy contact is still pending',
      'clinical decision support prototype',
    ].join('|'),
    'i',
  );
  if (staleReadmePattern.test(readme)) {
    add('BLOCKER', 'stale_readme_positioning', 'README still contains stale medical-product release wording.', 'README.md');
  }

  const disclaimer = exists('DISCLAIMER.md') ? read('DISCLAIMER.md') : '';
  if (!/not a medical device/i.test(disclaimer) || !/synthetic or sample data/i.test(disclaimer)) {
    add('BLOCKER', 'disclaimer_boundary_incomplete', 'DISCLAIMER does not clearly define medical and synthetic-data boundaries.', 'DISCLAIMER.md');
  }
}

function checkHighRiskClaims(files) {
  const publicClaimFiles = files.filter(({ relative }) => {
    if (relative.startsWith('node_modules/') || relative.startsWith('macos/Pods/')) return false;
    return /(^|\/)(README|DISCLAIMER|SECURITY|CONTRIBUTING|PUBLIC_SHOWCASE_READINESS)\.md$/.test(relative) ||
      relative.startsWith('docs/') ||
      relative.startsWith('.github/');
  });

  const bannedClaims = [
    new RegExp('clinically\\s+validated', 'i'),
    new RegExp('treatment\\s+recommendation\\s+for\\s+patients', 'i'),
    new RegExp('autonomous\\s+diagnosis', 'i'),
  ];

  for (const file of publicClaimFiles) {
    if (!textFilePattern.test(file.relative)) continue;
    const stat = fs.statSync(file.full);
    if (stat.size > maxScanBytes) continue;
    const content = fs.readFileSync(file.full, 'utf8');
    for (const pattern of bannedClaims) {
      if (pattern.test(content)) {
        add('BLOCKER', 'high_risk_public_claim', `High-risk public positioning phrase matched ${pattern}.`, file.relative);
      }
    }
  }
}

function checkSensitivePaths(files) {
  for (const dir of generatedDirs) {
    if (exists(dir)) {
      add('WARN', 'generated_or_local_dir_present', `Local/generated directory is present and should not be published: ${dir}`, dir);
    }
  }

  for (const file of files) {
    if (isSensitiveDir(file.relative)) {
      add('BLOCKER', 'sensitive_local_artifact_present', 'Sensitive local operator artifact is present in the working tree.', file.relative);
      continue;
    }
    for (const pattern of sensitiveFilenamePatterns) {
      if (pattern.test(file.relative)) {
        const severity = isGenerated(file.relative) ? 'WARN' : 'BLOCKER';
        add(severity, 'sensitive_filename_present', 'Potential credential file name is present.', file.relative);
      }
    }
  }
}

function checkContentSecrets(files) {
  const privateKeyBoundary = ['-----BEGIN ', 'PRIVATE KEY-----'];
  const privateKeyBlock = new RegExp(`${privateKeyBoundary[0]}(RSA |EC |OPENSSH |)?${privateKeyBoundary[1]}`);
  const serviceAccountPrivateKey = new RegExp(`"private_key"\\s*:\\s*"${privateKeyBoundary[0]}PRIVATE KEY-----`);
  const secretPatterns = [
    { name: 'private_key_block', pattern: privateKeyBlock },
    { name: 'service_account_private_key', pattern: serviceAccountPrivateKey },
    { name: 'refresh_token_literal', pattern: /"refresh_token"\s*:\s*"[^"]{20,}"/ },
    { name: 'id_token_literal', pattern: /"idToken"\s*:\s*"eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}"/ },
    { name: 'bearer_jwt_literal', pattern: /Bearer\s+eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}/ },
  ];

  for (const file of files) {
    if (!textFilePattern.test(file.relative)) continue;
    const stat = fs.statSync(file.full);
    if (stat.size > maxScanBytes) {
      if (isGenerated(file.relative)) {
        add('WARN', 'large_generated_file_skipped', 'Large generated/local text file skipped by content scanner.', file.relative);
      }
      continue;
    }

    let content = '';
    try {
      content = fs.readFileSync(file.full, 'utf8');
    } catch {
      continue;
    }

    if (/AIza[0-9A-Za-z_-]{20,}/.test(content)) {
      if (isLikelyFirebaseWebConfig(file.relative, content)) {
        add('WARN', 'firebase_web_api_key_present', 'Firebase Web API key appears in client config; expected public Firebase config, not an admin secret.', file.relative);
      } else if (isGenerated(file.relative)) {
        add('WARN', 'generated_api_key_like_value', 'API-key-like value appears in generated/local build output.', file.relative);
      } else {
        add('BLOCKER', 'api_key_like_secret', 'API-key-like value appears outside known Firebase client config.', file.relative);
      }
    }

    for (const { name, pattern } of secretPatterns) {
      if (!pattern.test(content)) continue;
      const severity = isGenerated(file.relative) ? 'WARN' : 'BLOCKER';
      add(severity, name, `${name} matched in ${isGenerated(file.relative) ? 'generated/local' : 'repository'} file.`, file.relative);
    }
  }
}

function checkGitignore() {
  if (!exists('.gitignore')) {
    add('BLOCKER', 'gitignore_missing', '.gitignore is missing.', '.gitignore');
    return;
  }
  const content = read('.gitignore');
  const requiredPatterns = [
    '.env',
    '.env.*',
    '*.service-account.json',
    '*service-account*.json',
    '*service_account*.json',
    'build/operator_tokens/',
    'build/user_exports/',
    'build/operator_audit/',
    'build/**/*.jsonl',
  ];
  for (const pattern of requiredPatterns) {
    if (!content.includes(pattern)) {
      add('BLOCKER', 'gitignore_pattern_missing', `.gitignore missing pattern: ${pattern}`, '.gitignore');
    }
  }
}

function addPositiveEvidence() {
  if (exists('PUBLIC_SHOWCASE_READINESS.md')) {
    add('INFO', 'public_showcase_readiness_present', 'Public showcase readiness document is present.', 'PUBLIC_SHOWCASE_READINESS.md');
  }
  if (exists('tool/firestore_rules_contract_check.mjs')) {
    add('INFO', 'firestore_rules_contract_present', 'Firestore rules contract tool is present.', 'tool/firestore_rules_contract_check.mjs');
  }
  if (exists('docs/ARCHITECTURE.md') && exists('docs/RELEASE_EVIDENCE_INDEX.md')) {
    add('INFO', 'architecture_evidence_docs_present', 'Architecture and release evidence documents are present.', 'docs/ARCHITECTURE.md');
  }
}

function writeReports(files) {
  fs.mkdirSync(outputDir, { recursive: true });
  const counts = findings.reduce(
    (acc, finding) => {
      acc[finding.severity] += 1;
      return acc;
    },
    { BLOCKER: 0, WARN: 0, INFO: 0 },
  );

  const report = {
    reportType: 'public_repo_preflight',
    generatedAt: new Date().toISOString(),
    root,
    scanScope: 'whole_working_tree',
    scannedFiles: files.length,
    counts,
    pass: counts.BLOCKER === 0,
    findings,
  };

  fs.writeFileSync(jsonPath, `${JSON.stringify(report, null, 2)}\n`);
  fs.writeFileSync(mdPath, renderMarkdown(report));
  return report;
}

function renderMarkdown(report) {
  const lines = [
    '# Public Repository Preflight',
    '',
    `Generated: ${report.generatedAt}`,
    `Scan scope: ${report.scanScope}`,
    `Scanned files: ${report.scannedFiles}`,
    `Result: ${report.pass ? 'PASS' : 'FAIL'}`,
    '',
    '| Severity | Count |',
    '| --- | ---: |',
    `| BLOCKER | ${report.counts.BLOCKER} |`,
    `| WARN | ${report.counts.WARN} |`,
    `| INFO | ${report.counts.INFO} |`,
    '',
  ];

  for (const severity of ['BLOCKER', 'WARN', 'INFO']) {
    lines.push(`## ${severity}`);
    const items = report.findings.filter((finding) => finding.severity === severity);
    if (!items.length) {
      lines.push('');
      lines.push('None.');
      lines.push('');
      continue;
    }
    lines.push('');
    lines.push('| Check | File | Message |');
    lines.push('| --- | --- | --- |');
    for (const item of items) {
      lines.push(`| ${escapeMd(item.name)} | ${escapeMd(item.file ?? '')} | ${escapeMd(item.message)} |`);
    }
    lines.push('');
  }
  return `${lines.join('\n')}\n`;
}

function escapeMd(value) {
  return String(value).replace(/\|/g, '\\|').replace(/\n/g, ' ');
}

checkRequiredFiles();
checkGitignore();
const files = listFiles(root);
checkPublicDocs();
checkHighRiskClaims(files);
checkSensitivePaths(files);
checkContentSecrets(files);
addPositiveEvidence();

const report = writeReports(files);
console.log(JSON.stringify({ pass: report.pass, counts: report.counts, report: rel(jsonPath) }, null, 2));
if (!report.pass) process.exit(1);
