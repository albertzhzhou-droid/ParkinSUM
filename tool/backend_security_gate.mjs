#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const repoRoot = process.cwd();
const checks = [
  checkAppCheck(),
  checkHostingHeaders(),
  checkFirestoreRules(),
  checkLocalAiEndpointGuard(),
  checkAndroidBackupPolicy(),
  checkRepoSecrets(),
];

let failed = 0;
for (const check of checks.flat()) {
  if (check.pass) {
    console.log(`PASS ${check.name}`);
  } else {
    failed += 1;
    console.error(`FAIL ${check.name}${check.detail ? `: ${check.detail}` : ''}`);
  }
}

if (failed > 0) {
  console.error(`Backend security gate failed: ${failed}/${checks.flat().length}`);
  process.exit(1);
}

console.log(`Backend security gate passed: ${checks.flat().length}/${checks.flat().length}`);

function checkAppCheck() {
  const pubspec = readText('pubspec.yaml');
  const backend = readText('lib/core/services/firebase_backend.dart');
  return [
    {
      name: 'firebase_app_check dependency is installed',
      pass: /firebase_app_check:\s*\^?0\./.test(pubspec),
    },
    {
      name: 'Firebase backend supports App Check activation',
      pass:
        backend.includes('FirebaseAppCheck.instance.activate') &&
        backend.includes('PARKINSUM_FIREBASE_APP_CHECK') &&
        backend.includes('PARKINSUM_RECAPTCHA_SITE_KEY'),
    },
    {
      name: 'App Check uses production attestation providers',
      pass:
        backend.includes('AndroidPlayIntegrityProvider') &&
        backend.includes('AppleAppAttestWithDeviceCheckFallbackProvider') &&
        backend.includes('ReCaptchaV3Provider'),
    },
  ];
}

function checkHostingHeaders() {
  const config = JSON.parse(readText('firebase.json'));
  const headers = (config.hosting?.headers ?? []).flatMap((entry) => entry.headers ?? []);
  const byKey = new Map(headers.map((header) => [header.key, String(header.value)]));
  const csp = byKey.get('Content-Security-Policy') ?? '';
  return [
    {
      name: 'Hosting has Content-Security-Policy',
      pass:
        csp.includes("default-src 'self'") &&
        csp.includes("frame-ancestors 'none'") &&
        csp.includes('firebaseappcheck.googleapis.com'),
    },
    {
      name: 'Hosting has HSTS',
      pass: (byKey.get('Strict-Transport-Security') ?? '').includes('max-age=31536000'),
    },
    {
      name: 'Hosting has anti-sniffing and frame protection headers',
      pass:
        byKey.get('X-Content-Type-Options') === 'nosniff' &&
        byKey.get('X-Frame-Options') === 'DENY',
    },
    {
      name: 'Hosting has restrictive browser capability policy',
      pass: (byKey.get('Permissions-Policy') ?? '').includes('camera=()'),
    },
  ];
}

function checkFirestoreRules() {
  const rules = readText('firestore.rules');
  return [
    {
      name: 'Rules do not allow blanket users/{uid} writes',
      pass:
        !/match\s+\/users\/\{uid\}\/\{document=\*\*\}/.test(rules) &&
        !/allow\s+read,\s*write:\s*if\s+isOwner\(uid\);/.test(rules),
    },
    {
      name: 'Profile and audit writes are bound to auth uid',
      pass:
        /validProfile\(uid\)[\s\S]*request\.resource\.data\.patientId\s*==\s*uid/.test(rules) &&
        /validClinicalAudit\(uid,\s*auditId\)[\s\S]*request\.resource\.data\.patient_id\s*==\s*uid/.test(rules),
    },
    {
      name: 'Runtime collections use field validators',
      pass:
        /validMeal\(mealId\)/.test(rules) &&
        /validIntake\(intakeId\)/.test(rules) &&
        /validActiveDrug\(drugId\)/.test(rules) &&
        /validKv\(key\)/.test(rules),
    },
    {
      name: 'Catalog writes require admin/importer and schema gate',
      pass: /allow\s+write:\s*if\s+isAdminOrImporter\(\)\s*&&\s*validAppCatalogWrite\(table,\s*rowId\);/.test(rules),
    },
    {
      name: 'Top-level cdss_tables and fallback remain denied',
      pass:
        /match\s+\/cdss_tables\/\{table\}\/rows\/\{rowId\}[\s\S]*allow\s+read,\s*write:\s*if\s+false/.test(rules) &&
        /match\s+\/\{document=\*\*\}[\s\S]*allow\s+read,\s*write:\s*if\s+false/.test(rules),
    },
  ];
}

function checkLocalAiEndpointGuard() {
  const source = readText('lib/domain/usecases/local_ai_recommendation_adapter.dart');
  return [
    {
      name: 'Local AI endpoints require http/https loopback without credentials or redirects',
      pass:
        source.includes("scheme != 'http' && scheme != 'https'") &&
        source.includes('uri.userInfo.isNotEmpty') &&
        source.includes('uri.hasQuery') &&
        source.includes('uri.hasFragment') &&
        source.includes("host == '::1'"),
    },
  ];
}

function checkAndroidBackupPolicy() {
  const manifest = readText('android/app/src/main/AndroidManifest.xml');
  return [
    {
      name: 'Android app backup is disabled for local health data',
      pass:
        manifest.includes('android:allowBackup="false"') &&
        manifest.includes('android:fullBackupContent="false"'),
    },
  ];
}

function checkRepoSecrets() {
  const findings = [];
  for (const filePath of walk(repoRoot)) {
    const rel = path.relative(repoRoot, filePath);
    if (isSkipped(rel)) continue;
    const text = readFileIfText(filePath);
    if (text == null) continue;
    if (/-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/.test(text)) {
      findings.push(`${rel}: private key material`);
    }
    if (/eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}/.test(text)) {
      findings.push(`${rel}: JWT-like token`);
    }
  }
  return [
    {
      name: 'Repository contains no private keys or JWT-like tokens',
      pass: findings.length === 0,
      detail: findings.slice(0, 5).join('; '),
    },
  ];
}

function readText(filePath) {
  return fs.readFileSync(path.join(repoRoot, filePath), 'utf8');
}

function readFileIfText(filePath) {
  const stat = fs.statSync(filePath);
  if (stat.size > 1024 * 1024) return null;
  const buffer = fs.readFileSync(filePath);
  if (buffer.includes(0)) return null;
  return buffer.toString('utf8');
}

function* walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      yield* walk(fullPath);
    } else if (entry.isFile()) {
      yield fullPath;
    }
  }
}

function isSkipped(relPath) {
  const parts = relPath.split(path.sep);
  return [
    '.dart_tool',
    '.firebase',
    '.git',
    '.idea',
    'build',
    'node_modules',
  ].some((part) => parts.includes(part));
}
