import { createHash, randomUUID } from 'node:crypto';
import { execFileSync, spawn } from 'node:child_process';
import { existsSync, lstatSync, mkdirSync, readFileSync, realpathSync, renameSync, writeFileSync, openSync, closeSync, writeSync } from 'node:fs';
import { dirname, isAbsolute, relative, resolve } from 'node:path';

export const sha256 = (value) => createHash('sha256').update(value).digest('hex');
export const digestObject = (value) => sha256(JSON.stringify(value));
export const INPUT_SCOPE = ['lib', 'assets', 'config', 'web', 'tool', 'test', 'integration_test', 'android', 'ios', 'macos', 'windows', 'linux', 'docs', '.github', '.gitignore', 'AGENTS.md', 'README.md', 'LICENSE', 'NOTICE', 'CONTRIBUTING.md', 'SECURITY.md', 'pubspec.yaml', 'pubspec.lock', 'package.json', 'package-lock.json', 'analysis_options.yaml'];
export const INPUT_EXCLUSIONS = ['docs/APP_EVOLUTION_TIMELINE.md', 'docs/MEGA_UPGRADE_RESULTS_2026-09-30.md'];

export function localPath(cwd, path) {
  if (typeof path !== 'string' || isAbsolute(path) || path.includes('\\') || path.split('/').includes('..')) throw new Error(`Unsafe relative path: ${path}`);
  const target = resolve(cwd, path);
  let ancestor = target;
  while (!existsSync(ancestor)) ancestor = dirname(ancestor);
  const within = relative(realpathSync(cwd), realpathSync(ancestor));
  if (within === '..' || within.startsWith('../') || isAbsolute(within)) throw new Error(`Path escapes checkout: ${path}`);
  if (existsSync(target) && lstatSync(target).isSymbolicLink()) throw new Error(`Symlinks are refused: ${path}`);
  return target;
}

export function atomicJson(path, value) {
  mkdirSync(dirname(path), { recursive: true });
  const temporary = `${path}.${randomUUID()}.tmp`;
  writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`, { flag: 'wx' });
  renameSync(temporary, path);
}

export function sourcePaths(cwd) {
  return [...new Set(execFileSync('git', ['ls-files', '-z', '--cached', '--others', '--exclude-standard', '--', ...INPUT_SCOPE], { cwd, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 }).split('\0').filter(Boolean))].filter((path) => !INPUT_EXCLUSIONS.includes(path)).sort();
}

// File-provider placeholders can report a positive size while a failed content
// download returns no bytes. Never turn that read into a source/artifact hash.
function completeFileBytes(target, label, readFile) {
  const before = lstatSync(target, { bigint: true });
  if (!before.isFile()) throw new Error(`Not a regular evidence file: ${label}`);
  const bytes = readFile(target);
  const after = lstatSync(target, { bigint: true });
  if (BigInt(bytes.length) !== before.size || BigInt(bytes.length) !== after.size) {
    throw Object.assign(new Error(`Incomplete file content: ${label}`), { code: 'FILE_CONTENT_INCOMPLETE' });
  }
  if (before.dev !== after.dev || before.ino !== after.ino || before.mtimeNs !== after.mtimeNs || before.ctimeNs !== after.ctimeNs) {
    throw Object.assign(new Error(`File changed during evidence capture: ${label}`), { code: 'FILE_CHANGED_DURING_CAPTURE' });
  }
  return bytes;
}

export function captureInputs(cwd, declaredPaths = sourcePaths(cwd), { readFile = readFileSync } = {}) {
  const paths = [...new Set(declaredPaths)].filter((path) => !INPUT_EXCLUSIONS.includes(path)).sort();
  if (!paths.length) throw new Error('Input inventory is empty');
  // Missing inputs are represented rather than silently omitted. Generated
  // checkpoint/log/index outputs are never part of this source inventory.
  const files = paths.map((path) => {
    if (path.startsWith('build/') || path.startsWith('node_modules/') || path.startsWith('.git/')) throw new Error(`Generated/private input is not allowed: ${path}`);
    const target = localPath(cwd, path);
    return { path, sha256: existsSync(target) ? sha256(completeFileBytes(target, path, readFile)) : null };
  });
  return { scope: INPUT_SCOPE, exclusions: INPUT_EXCLUSIONS, files, sha256: digestObject(files) };
}

export function artifactIdentity(cwd, path, { readFile = readFileSync } = {}) {
  if (!path.startsWith('build/')) throw new Error(`Artifact path is outside build: ${path}`);
  const target = localPath(cwd, path);
  if (!existsSync(target) || !lstatSync(target).isFile()) throw new Error(`Missing artifact: ${path}`);
  const bytes = completeFileBytes(target, path, readFile);
  return { path, bytes: bytes.length, sha256: sha256(bytes) };
}

const delay = (ms) => new Promise((resolveDelay) => setTimeout(resolveDelay, ms));

// Own one detached POSIX process group. Signals never target other sessions or
// toolchain processes. Log bytes are bounded independently from report bytes.
export async function supervise(command, args, { cwd, logPath, timeoutMs = 900000, cleanupGraceMs = 1000, maxLogBytes = 1024 * 1024, signal, env = process.env } = {}) {
  let child;
  let written = 0;
  let truncated = false;
  let termination = null;
  let cleanup = null;
  let closed = false;
  let descriptor;
  if (logPath) {
    mkdirSync(dirname(logPath), { recursive: true });
    descriptor = openSync(logPath, 'wx');
  }
  const chunks = [];
  const append = (data) => {
    const bytes = Buffer.from(data);
    const remaining = Math.max(0, maxLogBytes - written);
    if (bytes.length > remaining) truncated = true;
    if (remaining) {
      const kept = bytes.subarray(0, remaining);
      if (descriptor !== undefined) writeSync(descriptor, kept);
      else chunks.push(kept);
      written += kept.length;
    }
  };
  let timer;
  let abortListener;
  let spawnError;
  let cleanupSignalResult = null;
  let exitCode = null;
  let exitSignal = null;
  const kill = (name) => {
    if (!child?.pid) return 'no_child';
    try {
      if (process.platform === 'win32') child.kill(name);
      else process.kill(-child.pid, name);
      return 'signal_sent';
    } catch (error) { if (error.code !== 'ESRCH') append(`cleanup:${error.code}\n`); return error.code === 'ESRCH' ? 'group_absent' : 'failed'; }
  };
  const terminate = (reason) => {
    if (termination) return;
    termination = reason;
    kill('SIGTERM');
    cleanup = (async () => {
      await delay(cleanupGraceMs);
      // Even if the leader closed, descendants can remain in its group.
      cleanupSignalResult = kill('SIGKILL');
    })();
  };
  const completion = new Promise((resolveCompletion) => {
    try { child = spawn(command, args, { cwd, env, detached: process.platform !== 'win32', stdio: ['ignore', 'pipe', 'pipe'] }); }
    catch (error) { spawnError = error; resolveCompletion(); return; }
    child.stdout.on('data', append);
    child.stderr.on('data', append);
    child.once('error', (error) => { spawnError = error; });
    child.once('close', (code, sig) => { closed = true; exitCode = code; exitSignal = sig; resolveCompletion(); });
    timer = setTimeout(() => terminate('timeout'), timeoutMs);
    abortListener = () => terminate(signal.reason ?? 'interrupted');
    signal?.addEventListener('abort', abortListener, { once: true });
    if (signal?.aborted) abortListener();
  });
  // A broken close notification cannot hold cleanup indefinitely.
  while (!closed && !spawnError && !termination) await Promise.race([completion, delay(25)]);
  if (cleanup) {
    await cleanup;
    await Promise.race([completion, delay(500)]);
  } else await completion;
  clearTimeout(timer);
  if (abortListener) signal?.removeEventListener('abort', abortListener);
  child?.stdout?.destroy();
  child?.stderr?.destroy();
  child?.unref();
  if (descriptor !== undefined) closeSync(descriptor);
  return { exit_code: exitCode, signal: exitSignal, termination, spawn_error: spawnError ? { code: spawnError.code, message: spawnError.message } : null,
    log_bytes: written, log_truncated: truncated, output: descriptor === undefined ? Buffer.concat(chunks).toString('utf8') : undefined,
    cleanup_scope: process.platform === 'win32' ? 'leader_only_windows_unqualified' : 'owned_posix_process_group',
    cleanup_completed: !termination || (closed && cleanupSignalResult !== 'failed'), cleanup_signal_result: cleanupSignalResult, close_observed: closed };
}

export async function collectToolchain(cwd, signal) {
  const values = { node: { version: process.version, executable: process.execPath }, platform: process.platform, arch: process.arch };
  for (const [name, args] of [['npm', ['--version']], ['dart', ['--version']], ['flutter', ['--version', '--machine']]]) {
    const result = await supervise(name, args, { cwd, timeoutMs: 30000, cleanupGraceMs: 250, maxLogBytes: 65536, signal });
    if (result.spawn_error || result.termination || result.exit_code !== 0) throw new Error(`Toolchain unavailable: ${name}`);
    values[name] = result.output.trim();
  }
  return values;
}

export function declaredEnvironment(env = process.env) {
  const names = [...new Set([
    'CI', 'TZ', 'LANG', 'LC_ALL', 'SOURCE_DATE_EPOCH', 'NODE_OPTIONS', 'DART_VM_OPTIONS',
    'FLUTTER_ROOT', 'PUB_CACHE', 'PUB_HOSTED_URL', 'FLUTTER_STORAGE_BASE_URL', 'JAVA_HOME',
    ...Object.keys(env).filter((name) => /^npm_config_/i.test(name) && !/(token|auth|password|secret)/i.test(name)),
  ])].sort();
  return { PATH: env.PATH ?? '', PARKINSUM_EVIDENCE_CURRENCY_AS_OF_UTC: env.PARKINSUM_EVIDENCE_CURRENCY_AS_OF_UTC ?? null,
    runtime_option_sha256: Object.fromEntries(names.map((name) => [name, env[name] === undefined ? null : sha256(env[name])])),
    scope: 'Declared standard runtime/locale/cache and non-credential npm_config options; values are hashed, not exported. Credential values are not inventoried. This is not a hermetic environment or an encryption claim.' };
}
