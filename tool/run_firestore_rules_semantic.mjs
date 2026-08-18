import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

export function parseJavaMajor(versionOutput) {
  const match = String(versionOutput).match(/version\s+"(\d+)(?:\.(\d+))?/i);
  if (!match) return null;
  const first = Number(match[1]);
  const second = Number(match[2]);
  if (!Number.isInteger(first)) return null;
  return first === 1 && Number.isInteger(second) ? second : first;
}

export function chooseJava21(candidates, probe) {
  for (const candidate of candidates) {
    const result = probe(candidate);
    if (result?.major >= 21) return { ...candidate, ...result };
  }
  return null;
}

function uniqueCandidates(candidates) {
  const seen = new Set();
  return candidates.filter((candidate) => {
    const key = `${candidate.home ?? ''}|${candidate.executable}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function javaExecutable(home) {
  return path.join(home, 'bin', process.platform === 'win32' ? 'java.exe' : 'java');
}

function macOsJava21Home() {
  if (process.platform !== 'darwin') return null;
  const result = spawnSync('/usr/libexec/java_home', ['-v', '21'], {
    encoding: 'utf8',
  });
  return result.status === 0 ? result.stdout.trim() : null;
}

function runtimeCandidates() {
  const homes = [
    process.env.PARKINSUM_JAVA_HOME,
    process.env.JAVA_HOME,
    macOsJava21Home(),
  ];

  if (process.platform === 'darwin') {
    homes.push(
      '/Applications/Android Studio.app/Contents/jbr/Contents/Home',
      '/Applications/Android Studio Preview.app/Contents/jbr/Contents/Home',
    );
  } else if (process.platform === 'linux') {
    homes.push('/opt/android-studio/jbr', '/usr/lib/jvm/temurin-21-jdk-amd64');
  } else if (process.platform === 'win32') {
    const programFiles = process.env.ProgramFiles ?? 'C:\\Program Files';
    homes.push(path.join(programFiles, 'Android', 'Android Studio', 'jbr'));
  }

  return uniqueCandidates([
    ...homes
      .filter((home) => typeof home === 'string' && home.trim().length > 0)
      .map((home) => ({ home, executable: javaExecutable(home) })),
    { home: null, executable: process.platform === 'win32' ? 'java.exe' : 'java' },
  ]);
}

function probeJava(candidate) {
  if (candidate.home && !fs.existsSync(candidate.executable)) return null;
  const result = spawnSync(candidate.executable, ['-version'], {
    encoding: 'utf8',
  });
  if (result.error || result.status !== 0) return null;
  const output = `${result.stdout ?? ''}\n${result.stderr ?? ''}`;
  const major = parseJavaMajor(output);
  return major == null ? null : { major, versionOutput: output.trim() };
}

export function resolveJava21() {
  return chooseJava21(runtimeCandidates(), probeJava);
}

export function firebaseEmulatorInvocation({
  root = projectRoot,
  nodeExecutable = process.execPath,
} = {}) {
  const cliEntrypoint = path.join(
    root,
    'node_modules',
    'firebase-tools',
    'lib',
    'bin',
    'firebase.js',
  );
  return {
    executable: nodeExecutable,
    cliEntrypoint,
    args: [
      cliEntrypoint,
      'emulators:exec',
      '--project',
      'parkinsum-rules-semantic-test',
      '--only',
      'firestore',
      'node tool/run_firestore_rules_semantic_suite.mjs',
    ],
    shell: false,
  };
}

function run() {
  const runtime = resolveJava21();
  if (!runtime) {
    console.error(
      'Firestore Emulator requires Java 21+. Set PARKINSUM_JAVA_HOME or '
        + 'JAVA_HOME to a JDK 21 runtime (Android Studio JBR is supported).',
    );
    process.exitCode = 2;
    return;
  }

  const invocation = firebaseEmulatorInvocation();
  if (!fs.existsSync(invocation.cliEntrypoint)) {
    console.error('Firebase CLI is missing. Run npm ci before npm run rules:test.');
    process.exitCode = 2;
    return;
  }

  const env = {
    ...process.env,
    FIREBASE_CLI_DISABLE_UPDATE_CHECK: 'true',
  };
  if (runtime.home) {
    env.JAVA_HOME = runtime.home;
    env.PATH = `${path.join(runtime.home, 'bin')}${path.delimiter}${env.PATH ?? ''}`;
  }

  console.log(`Using Java ${runtime.major} for Firestore Emulator.`);
  const result = spawnSync(
    invocation.executable,
    invocation.args,
    {
      cwd: projectRoot,
      env,
      stdio: 'inherit',
      shell: invocation.shell,
    },
  );

  if (result.error) {
    console.error(result.error.message);
    process.exitCode = 2;
    return;
  }
  process.exitCode = result.status ?? 2;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  run();
}
