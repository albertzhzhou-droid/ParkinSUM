#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const args = parseArgs(process.argv.slice(2));
const environment = args.env ?? process.env.PARKINSUM_ENV ?? 'prod';
const projectId =
  args.project ??
  process.env.PARKINSUM_FIREBASE_PROJECT_ID ??
  process.env.FIREBASE_PROJECT_ID ??
  defaultProjectForEnvironment(environment);
const releaseId =
  args['release-id'] ?? `p0_${environment}_${new Date().toISOString().replace(/[:.]/g, '-')}`;
const output =
  args.output ?? path.join('build', 'release_manifests', `${releaseId}.json`);
const pubspec = fs.readFileSync('pubspec.yaml', 'utf8');
const version = /version:\s*([^\s]+)/.exec(pubspec)?.[1] ?? 'unknown';

const manifest = {
  releaseId,
  generatedAt: new Date().toISOString(),
  app: {
    name: 'ParkinSUM Companion',
    version,
  },
  environment,
  firebase: {
    projectId,
    backendMode: 'firebase',
    hostingPublicDir: 'build/web',
    hostingUrl: args['hosting-url'] ?? defaultHostingUrl(projectId),
    hostingCurrentRelease: args['hosting-current-release'] ?? null,
    hostingPreviousRelease: args['hosting-previous-release'] ?? null,
  },
  source: {
    gitReference: readGitReference(),
    sourceBundle: args['source-bundle'] ?? null,
    sourceBundleSha256: args['source-bundle-sha256'] ?? null,
    sourceBundleId: args['source-bundle-id'] ?? null,
  },
  checks: {
    analyzer: args.analyzer ?? 'not_recorded',
    firebaseUserBindingTest: args['firebase-user-binding-test'] ?? 'not_recorded',
    firestoreRulesContract: args['firestore-rules-contract'] ?? 'not_recorded',
    webBuild: args['web-build'] ?? 'not_recorded',
    browserSmoke: args['browser-smoke'] ?? 'not_recorded',
  },
  artifacts: {
    webBuild: 'build/web',
    webBuildSha256: args['web-build-sha256'] ?? hashDirectoryIfExists('build/web'),
    releaseManifest: output,
    operatorAuditLog: args['audit-log'] ?? 'build/operator_audit/operator_audit.jsonl',
    backupExportPath: args['backup-export-path'] ?? null,
  },
  snapshot: {
    snapshotId: args['snapshot-id'] ?? null,
    importRunId: args['import-run-id'] ?? null,
    sourceFamily: args['source-family'] ?? null,
  },
  remainingLiveChecks: [
    'stage/prod Firestore user A/B rule probes',
    'admin and cdssImporter claim grant/removal verification',
    'Firestore backup export to controlled bucket',
    'test uid user data export drill',
    'test uid user data deletion drill',
    'real official data production_candidate acceptance',
  ],
  blockers: parseList(args.blockers),
};

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, `${JSON.stringify(manifest, null, 2)}\n`);
console.log(output);

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

function defaultProjectForEnvironment(env) {
  if (env === 'dev') return 'parkinsum-companion-dev';
  if (env === 'stage') return 'parkinsum-companion-stage';
  return 'parkinsum-companion';
}

function defaultHostingUrl(project) {
  return `https://${project}.web.app`;
}

function readGitReference() {
  try {
    const head = fs.readFileSync('.git/HEAD', 'utf8').trim();
    if (head.startsWith('ref: ')) {
      const refPath = path.join('.git', head.slice(5));
      if (fs.existsSync(refPath)) {
        return {
          ref: head.slice(5),
          commit: fs.readFileSync(refPath, 'utf8').trim(),
        };
      }
      return { ref: head.slice(5), commit: null };
    }
    return { ref: null, commit: head };
  } catch (_) {
    return {
      ref: null,
      commit: null,
      note: 'No git metadata available in this checkout.',
    };
  }
}

function hashDirectoryIfExists(directory) {
  if (!fs.existsSync(directory)) return null;
  const hash = crypto.createHash('sha256');
  for (const filePath of listFiles(directory).sort()) {
    const relativePath = path.relative(directory, filePath);
    hash.update(relativePath);
    hash.update('\0');
    hash.update(fs.readFileSync(filePath));
    hash.update('\0');
  }
  return hash.digest('hex');
}

function listFiles(directory) {
  const entries = fs.readdirSync(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const next = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      files.push(...listFiles(next));
    } else if (entry.isFile()) {
      files.push(next);
    }
  }
  return files;
}

function parseList(value) {
  if (!value || value === true) return [];
  return String(value)
    .split(',')
    .map((entry) => entry.trim())
    .filter(Boolean);
}
