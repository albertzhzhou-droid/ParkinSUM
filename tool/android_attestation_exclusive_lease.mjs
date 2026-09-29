import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';

export const androidAttestationLeaseSchema =
  'parkinsum.android-attestation-exclusive-lease/1';

export const processIdentityProbeStatuses = Object.freeze({
  liveExact: 'live_exact',
  dead: 'dead',
  mismatch: 'identity_mismatch',
  unknown: 'unknown',
});

const ownerFileName = 'owner.json';
const heartbeatFileName = 'heartbeat.json';
const tokenPattern = /^[0-9a-f]{64}$/;
const digestPattern = /^[0-9a-f]{64}$/;
const runIdPattern = /^[A-Za-z0-9][A-Za-z0-9_-]{7,95}$/;

export class AndroidAttestationLeaseError extends Error {
  constructor(message, code, details = {}) {
    super(message);
    this.name = this.constructor.name;
    this.code = code;
    this.details = details;
  }
}

export class AndroidAttestationLeaseUnavailableError extends AndroidAttestationLeaseError {}
export class AndroidAttestationLeaseIntegrityError extends AndroidAttestationLeaseError {}
export class AndroidAttestationLeaseOwnershipError extends AndroidAttestationLeaseError {}

export class AndroidAttestationProcessIdentityDisappearedError extends Error {
  constructor(pid, cause) {
    super(`Process ${pid} disappeared before identity capture`, { cause });
    this.name = 'AndroidAttestationProcessIdentityDisappearedError';
    this.code = 'PROCESS_IDENTITY_DISAPPEARED';
    this.pid = pid;
  }
}

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function isPlainObject(value) {
  return (
    value !== null &&
    typeof value === 'object' &&
    !Array.isArray(value) &&
    (Object.getPrototypeOf(value) === Object.prototype ||
      Object.getPrototypeOf(value) === null)
  );
}

function canonicalize(value, context = 'value') {
  if (
    value === null ||
    typeof value === 'string' ||
    typeof value === 'boolean'
  ) {
    return value;
  }
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (Array.isArray(value)) {
    return value.map((item, index) => canonicalize(item, `${context}[${index}]`));
  }
  if (isPlainObject(value)) {
    const result = {};
    for (const key of Object.keys(value).sort()) {
      if (!key || typeof value[key] === 'undefined') {
        throw new TypeError(`${context} contains an invalid property ${key}`);
      }
      result[key] = canonicalize(value[key], `${context}.${key}`);
    }
    return result;
  }
  throw new TypeError(`${context} must contain only finite JSON values`);
}

function canonicalJson(value) {
  return JSON.stringify(canonicalize(value));
}

function digestJson(value) {
  return sha256(canonicalJson(value));
}

function compareStrings(left, right) {
  return left < right ? -1 : left > right ? 1 : 0;
}

function ownKeysExactly(value, expected) {
  if (!isPlainObject(value)) return false;
  const actual = Object.keys(value).sort();
  return (
    actual.length === expected.length &&
    actual.every((key, index) => key === [...expected].sort()[index])
  );
}

function assertNonEmptyString(value, context, maxLength = 4096) {
  if (
    typeof value !== 'string' ||
    value.length === 0 ||
    value.length > maxLength ||
    /[\0\r\n]/.test(value)
  ) {
    throw new TypeError(`${context} must be a bounded non-empty string`);
  }
  return value;
}

function normalizeIdentity(value, context = 'process identity') {
  if (!isPlainObject(value)) {
    throw new TypeError(`${context} must be an object`);
  }
  const allowed = [
    'pid',
    'hostname',
    'bootIdentity',
    'startIdentity',
    'processGroupId',
    'role',
  ];
  if (Object.keys(value).some((key) => !allowed.includes(key))) {
    throw new TypeError(`${context} contains unknown fields`);
  }
  if (!Number.isSafeInteger(value.pid) || value.pid <= 0) {
    throw new TypeError(`${context}.pid must be a positive integer`);
  }
  const processGroupId = value.processGroupId ?? null;
  if (
    processGroupId !== null &&
    (!Number.isSafeInteger(processGroupId) || processGroupId <= 0)
  ) {
    throw new TypeError(`${context}.processGroupId must be null or positive`);
  }
  const role = value.role ?? 'process';
  return {
    pid: value.pid,
    hostname: assertNonEmptyString(value.hostname, `${context}.hostname`, 255),
    bootIdentity: assertNonEmptyString(
      value.bootIdentity,
      `${context}.bootIdentity`,
      512,
    ),
    startIdentity: assertNonEmptyString(
      value.startIdentity,
      `${context}.startIdentity`,
      512,
    ),
    processGroupId,
    role: assertNonEmptyString(role, `${context}.role`, 128),
  };
}

function identityKey(identity) {
  return canonicalJson(identity);
}

async function readLinuxBootIdentity() {
  return (await fs.readFile('/proc/sys/kernel/random/boot_id', 'utf8')).trim();
}

async function readLinuxStartIdentity(pid) {
  let stat;
  try {
    stat = await fs.readFile(`/proc/${pid}/stat`, 'utf8');
  } catch (error) {
    if (error?.code === 'ENOENT' || error?.code === 'ESRCH') {
      throw new AndroidAttestationProcessIdentityDisappearedError(pid, error);
    }
    throw error;
  }
  const closeParen = stat.lastIndexOf(')');
  if (closeParen < 0) throw new Error('malformed /proc stat');
  const fieldsAfterCommand = stat.slice(closeParen + 2).trim().split(/\s+/);
  // starttime is field 22; the suffix begins at field 3.
  const startTime = fieldsAfterCommand[19];
  if (!/^[0-9]+$/.test(startTime ?? '')) {
    throw new Error('missing process start ticks');
  }
  return `linux-proc-start-ticks:${startTime}`;
}

function isMissingProcessError(error) {
  return (
    error instanceof AndroidAttestationProcessIdentityDisappearedError ||
    error?.code === 'ENOENT' ||
    error?.code === 'ESRCH' ||
    (typeof error?.stderr === 'string' && /no such process/i.test(error.stderr))
  );
}

export function createPosixProcessIdentityProbe({
  platform = process.platform,
  hostname = os.hostname,
} = {}) {
  if (platform !== 'linux' && platform !== 'darwin') {
    throw new Error(`Unsupported lease platform: ${platform}`);
  }
  const bootReader = readLinuxBootIdentity;
  const startReader = readLinuxStartIdentity;
  const provider = {
    provider:
      platform === 'linux'
        ? 'linux-boot-id-proc-starttime-v1'
        : 'darwin-no-stale-reclaim-v1',
    supportsStaleReclaim: platform === 'linux',
    async captureIdentity(
      pid,
      { processGroupId = null, role = 'child-process' } = {},
    ) {
      if (!Number.isSafeInteger(pid) || pid <= 0) {
        throw new TypeError('pid must be a positive integer');
      }
      if (platform === 'darwin') {
        // This is an ownership correlation nonce, not evidence that can ever
        // authorize PID-based stale reclaim.
        return normalizeIdentity({
          pid,
          hostname: hostname(),
          bootIdentity: 'darwin-no-reclaim',
          startIdentity: `darwin-unverified-process-nonce:${crypto.randomBytes(32).toString('hex')}`,
          processGroupId,
          role,
        });
      }
      return normalizeIdentity({
        pid,
        hostname: hostname(),
        startIdentity: await startReader(pid),
        bootIdentity: await bootReader(),
        processGroupId,
        role,
      });
    },
    async currentIdentity() {
      return this.captureIdentity(process.pid, { role: 'lease-owner' });
    },
    async probe(inputIdentity) {
      const identity = normalizeIdentity(inputIdentity);
      if (identity.hostname !== hostname()) {
        return { status: processIdentityProbeStatuses.unknown };
      }
      // macOS `ps lstart` is wall-clock text with insufficient identity
      // strength to exclude PID ABA. It may be recorded for ownership
      // evidence, but the default Darwin provider must never authorize stale
      // reclaim from it.
      if (platform === 'darwin') {
        return { status: processIdentityProbeStatuses.unknown };
      }
      let currentBoot;
      try {
        currentBoot = await bootReader();
      } catch {
        return { status: processIdentityProbeStatuses.unknown };
      }
      if (currentBoot !== identity.bootIdentity) {
        return { status: processIdentityProbeStatuses.mismatch };
      }
      try {
        const observedStart = await startReader(identity.pid);
        return {
          status:
            observedStart === identity.startIdentity
              ? processIdentityProbeStatuses.liveExact
              : processIdentityProbeStatuses.mismatch,
        };
      } catch (error) {
        return {
          status: isMissingProcessError(error)
            ? processIdentityProbeStatuses.dead
            : processIdentityProbeStatuses.unknown,
        };
      }
    },
  };
  return provider;
}

function normalizeResources(resourceKeys) {
  if (!Array.isArray(resourceKeys) || resourceKeys.length === 0) {
    throw new TypeError('resourceKeys must be a non-empty array');
  }
  const resources = resourceKeys.map((entry, index) => {
    const objectEntry = typeof entry === 'string' ? { key: entry } : entry;
    if (!isPlainObject(objectEntry)) {
      throw new TypeError(`resourceKeys[${index}] must be a string or object`);
    }
    if (Object.keys(objectEntry).some((key) => !['kind', 'key'].includes(key))) {
      throw new TypeError(`resourceKeys[${index}] contains unknown fields`);
    }
    const key = assertNonEmptyString(
      objectEntry.key,
      `resourceKeys[${index}].key`,
      8192,
    );
    const kind = assertNonEmptyString(
      objectEntry.kind ?? 'resource',
      `resourceKeys[${index}].kind`,
      128,
    );
    return { kind, key, digest: sha256(key) };
  });
  resources.sort((left, right) =>
    left.key === right.key
      ? compareStrings(left.kind, right.kind)
      : compareStrings(left.key, right.key),
  );
  for (let index = 1; index < resources.length; index += 1) {
    if (resources[index - 1].key === resources[index].key) {
      throw new TypeError(`Duplicate resource key: ${resources[index].key}`);
    }
  }
  return resources;
}

function validateRunId(runId) {
  if (typeof runId !== 'string' || !runIdPattern.test(runId)) {
    throw new TypeError('runId must match the 8-96 character run ID contract');
  }
  return runId;
}

function statIdentity(stat) {
  return { dev: String(stat.dev), ino: String(stat.ino) };
}

function sameStatIdentity(left, right) {
  return left.dev === right.dev && left.ino === right.ino;
}

function integrity(message, details = {}) {
  return new AndroidAttestationLeaseIntegrityError(
    message,
    'LEASE_INTEGRITY_FAILURE',
    details,
  );
}

function unavailable(message, details = {}) {
  return new AndroidAttestationLeaseUnavailableError(
    message,
    'LEASE_UNAVAILABLE',
    details,
  );
}

function ownership(message, details = {}) {
  return new AndroidAttestationLeaseOwnershipError(
    message,
    'LEASE_OWNERSHIP_LOST',
    details,
  );
}

async function ensurePrivateDirectory(directory, { create = false } = {}) {
  if (create) await fs.mkdir(directory, { recursive: true, mode: 0o700 });
  const stat = await fs.lstat(directory);
  if (stat.isSymbolicLink() || !stat.isDirectory()) {
    throw integrity(`Lease directory is not a real directory: ${directory}`);
  }
  if ((stat.mode & 0o077) !== 0) {
    throw integrity(`Lease directory is not private (mode must be 0700): ${directory}`);
  }
  if (typeof process.getuid === 'function' && stat.uid !== process.getuid()) {
    throw integrity(`Lease directory is not owned by the current user: ${directory}`);
  }
  return statIdentity(stat);
}

async function ensureSecureLockRootParent(lockRoot) {
  const parent = path.dirname(lockRoot);
  const stat = await fs.lstat(parent);
  if (stat.isSymbolicLink() || !stat.isDirectory()) {
    throw integrity(`Lease root parent is not a real directory: ${parent}`);
  }
  const writableByGroupOrOther = (stat.mode & 0o022) !== 0;
  const sticky = (stat.mode & 0o1000) !== 0;
  if (writableByGroupOrOther && !sticky) {
    throw integrity(
      `Lease root parent is writable without sticky-bit protection: ${parent}`,
    );
  }
}

async function writeExclusiveJson(filePath, value) {
  const handle = await fs.open(filePath, 'wx', 0o600);
  try {
    await handle.writeFile(`${canonicalJson(value)}\n`, 'utf8');
    await handle.sync();
  } finally {
    await handle.close();
  }
}

async function readRegularJson(filePath, context) {
  let handle;
  try {
    handle = await fs.open(
      filePath,
      fs.constants.O_RDONLY | fs.constants.O_NOFOLLOW,
    );
    const stat = await handle.stat();
    if (!stat.isFile()) throw integrity(`${context} is not a regular file`);
    const text = await handle.readFile('utf8');
    const value = JSON.parse(text);
    return { value, digest: sha256(canonicalJson(value)) };
  } catch (error) {
    if (error instanceof AndroidAttestationLeaseError) throw error;
    throw integrity(`Cannot read ${context}`, { cause: error?.code ?? 'invalid' });
  } finally {
    await handle?.close();
  }
}

function validateOwner(owner, expectedDigest = null) {
  const expectedKeys = [
    'schema',
    'token',
    'pid',
    'hostname',
    'ownerIdentity',
    'childIdentities',
    'runId',
    'resourceKind',
    'resourceDigest',
    'resourceSetDigest',
    'resourceSetDigests',
    'parameters',
    'acquiredAtMs',
    'ownerRevision',
    'processProbeProvider',
  ];
  if (!ownKeysExactly(owner, expectedKeys)) {
    throw integrity('Lease owner has unknown or missing fields');
  }
  if (owner.schema !== androidAttestationLeaseSchema) {
    throw integrity(`Unknown lease owner schema: ${String(owner.schema)}`);
  }
  if (!tokenPattern.test(owner.token ?? '')) throw integrity('Invalid owner token');
  const ownerIdentity = normalizeIdentity(owner.ownerIdentity, 'ownerIdentity');
  if (
    owner.pid !== ownerIdentity.pid ||
    owner.hostname !== ownerIdentity.hostname
  ) {
    throw integrity('Owner PID/hostname disagree with the exact identity');
  }
  if (!Array.isArray(owner.childIdentities)) {
    throw integrity('childIdentities must be an array');
  }
  const children = owner.childIdentities.map((identity, index) =>
    normalizeIdentity(identity, `childIdentities[${index}]`),
  );
  const childKeys = children.map(identityKey);
  if (new Set(childKeys).size !== childKeys.length) {
    throw integrity('childIdentities contains duplicates');
  }
  validateRunId(owner.runId);
  assertNonEmptyString(owner.resourceKind, 'resourceKind', 128);
  if (!digestPattern.test(owner.resourceDigest ?? '')) {
    throw integrity('Invalid resource digest');
  }
  if (expectedDigest !== null && owner.resourceDigest !== expectedDigest) {
    throw integrity('Resource digest does not match the lock path');
  }
  if (!digestPattern.test(owner.resourceSetDigest ?? '')) {
    throw integrity('Invalid resource-set digest');
  }
  if (
    !Array.isArray(owner.resourceSetDigests) ||
    owner.resourceSetDigests.length === 0 ||
    owner.resourceSetDigests.some((digest) => !digestPattern.test(digest)) ||
    [...owner.resourceSetDigests].sort().some(
      (digest, index) => digest !== owner.resourceSetDigests[index],
    ) ||
    new Set(owner.resourceSetDigests).size !== owner.resourceSetDigests.length ||
    digestJson(owner.resourceSetDigests) !== owner.resourceSetDigest
  ) {
    throw integrity('Invalid resource-set digest binding');
  }
  canonicalize(owner.parameters, 'parameters');
  if (!Number.isSafeInteger(owner.acquiredAtMs) || owner.acquiredAtMs < 0) {
    throw integrity('Invalid acquisition time');
  }
  if (!Number.isSafeInteger(owner.ownerRevision) || owner.ownerRevision < 0) {
    throw integrity('Invalid owner revision');
  }
  assertNonEmptyString(owner.processProbeProvider, 'processProbeProvider', 256);
  return { ...owner, ownerIdentity, childIdentities: children };
}

function validateHeartbeat(heartbeat, ownerToken) {
  if (
    !ownKeysExactly(heartbeat, [
      'schema',
      'token',
      'sequence',
      'wallTimeMs',
    ])
  ) {
    throw integrity('Heartbeat has unknown or missing fields');
  }
  if (heartbeat.schema !== androidAttestationLeaseSchema) {
    throw integrity(`Unknown heartbeat schema: ${String(heartbeat.schema)}`);
  }
  if (!tokenPattern.test(heartbeat.token ?? '') || heartbeat.token !== ownerToken) {
    throw integrity('Heartbeat token does not match its owner');
  }
  if (!Number.isSafeInteger(heartbeat.sequence) || heartbeat.sequence < 0) {
    throw integrity('Invalid heartbeat sequence');
  }
  if (!Number.isSafeInteger(heartbeat.wallTimeMs) || heartbeat.wallTimeMs < 0) {
    throw integrity('Invalid heartbeat time');
  }
  return heartbeat;
}

async function inspectLock(lockPath, expectedDigest) {
  let stat;
  try {
    stat = await fs.lstat(lockPath);
  } catch (error) {
    if (error?.code === 'ENOENT') return null;
    throw error;
  }
  if (stat.isSymbolicLink() || !stat.isDirectory()) {
    throw integrity(`Lock path is not a real directory: ${lockPath}`);
  }
  const ownerRead = await readRegularJson(
    path.join(lockPath, ownerFileName),
    'lease owner',
  );
  const owner = validateOwner(ownerRead.value, expectedDigest);
  const heartbeatRead = await readRegularJson(
    path.join(lockPath, heartbeatFileName),
    'lease heartbeat',
  );
  const heartbeat = validateHeartbeat(heartbeatRead.value, owner.token);
  const statAfter = await fs.lstat(lockPath);
  if (
    statAfter.isSymbolicLink() ||
    !statAfter.isDirectory() ||
    !sameStatIdentity(statIdentity(stat), statIdentity(statAfter))
  ) {
    throw integrity('Lock directory identity changed while it was inspected');
  }
  return {
    inode: statIdentity(stat),
    owner,
    ownerDigest: ownerRead.digest,
    heartbeat,
    heartbeatDigest: heartbeatRead.digest,
  };
}

function sameSnapshot(left, right) {
  return (
    left !== null &&
    right !== null &&
    sameStatIdentity(left.inode, right.inode) &&
    left.owner.token === right.owner.token &&
    left.ownerDigest === right.ownerDigest &&
    left.heartbeatDigest === right.heartbeatDigest
  );
}

async function atomicReplaceJson({ directory, fileName, value, token, hooks }) {
  const temporary = path.join(
    directory,
    `.${fileName}.${token}.${crypto.randomBytes(16).toString('hex')}.tmp`,
  );
  await writeExclusiveJson(temporary, value);
  try {
    await hooks?.beforeAtomicJsonRename?.({ directory, fileName, temporary });
    await fs.rename(temporary, path.join(directory, fileName));
  } finally {
    await fs.rm(temporary, { force: true });
  }
}

async function probeIdentityDefinitively(processProbe, identity) {
  let result;
  try {
    result = await processProbe.probe(identity);
  } catch {
    return processIdentityProbeStatuses.unknown;
  }
  const status = result?.status;
  return Object.values(processIdentityProbeStatuses).includes(status)
    ? status
    : processIdentityProbeStatuses.unknown;
}

async function assertOwnerAndChildrenDead(processProbe, owner) {
  const ownerStatus = await probeIdentityDefinitively(
    processProbe,
    owner.ownerIdentity,
  );
  if (ownerStatus === processIdentityProbeStatuses.liveExact) {
    throw unavailable('Exact lease owner identity is still live');
  }
  if (ownerStatus === processIdentityProbeStatuses.unknown) {
    throw integrity('Lease owner identity cannot be determined safely');
  }
  for (const child of owner.childIdentities) {
    const status = await probeIdentityDefinitively(processProbe, child);
    if (status === processIdentityProbeStatuses.liveExact) {
      throw unavailable('A registered lease child identity is still live', {
        pid: child.pid,
      });
    }
    if (status === processIdentityProbeStatuses.unknown) {
      throw integrity('A registered child identity cannot be determined safely', {
        pid: child.pid,
      });
    }
  }
}

async function restoreQuarantinedPath(quarantinePath, livePath) {
  try {
    await fs.rename(quarantinePath, livePath);
  } catch {
    // Retaining an unverified quarantine is safer than deleting it. A caller
    // receives an integrity failure and must resolve the lockRoot manually.
  }
}

async function reclaimIfProvablyAbandoned({
  livePath,
  quarantineRoot,
  resource,
  staleAfterMs,
  nowMs,
  processProbe,
  hooks,
  randomBytes,
}) {
  const first = await inspectLock(livePath, resource.digest);
  if (first === null) return { reclaimed: false, disappeared: true };
  if (nowMs - first.heartbeat.wallTimeMs <= staleAfterMs) {
    throw unavailable('Lease heartbeat is still fresh', {
      resourceDigest: resource.digest,
    });
  }
  if (processProbe.supportsStaleReclaim !== true) {
    throw integrity(
      `Process identity provider ${processProbe.provider ?? 'unknown'} cannot safely reclaim stale leases`,
    );
  }
  await assertOwnerAndChildrenDead(processProbe, first.owner);
  await hooks?.beforeReclaimRename?.({ livePath, snapshot: first });

  const second = await inspectLock(livePath, resource.digest);
  if (second === null) return { reclaimed: false, disappeared: true };
  if (!sameSnapshot(first, second)) {
    throw integrity('Lease changed during stale-reclaim authorization');
  }
  if (nowMs - second.heartbeat.wallTimeMs <= staleAfterMs) {
    throw unavailable('Lease heartbeat was renewed before stale reclaim');
  }
  await assertOwnerAndChildrenDead(processProbe, second.owner);

  const quarantinePath = path.join(
    quarantineRoot,
    `${resource.digest}.${randomBytes(32).toString('hex')}`,
  );
  try {
    await fs.rename(livePath, quarantinePath);
  } catch (error) {
    if (error?.code === 'ENOENT') return { reclaimed: false, disappeared: true };
    throw error;
  }
  await hooks?.afterReclaimRename?.({ quarantinePath, snapshot: second });
  let quarantined;
  try {
    quarantined = await inspectLock(quarantinePath, resource.digest);
  } catch (error) {
    await restoreQuarantinedPath(quarantinePath, livePath);
    throw error;
  }
  if (!sameSnapshot(second, quarantined)) {
    await restoreQuarantinedPath(quarantinePath, livePath);
    throw integrity('Quarantined lease changed before deletion');
  }
  await assertOwnerAndChildrenDead(processProbe, quarantined.owner);
  if (nowMs - quarantined.heartbeat.wallTimeMs <= staleAfterMs) {
    await restoreQuarantinedPath(quarantinePath, livePath);
    throw unavailable('Quarantined lease heartbeat is no longer stale');
  }
  let finalSnapshot;
  try {
    finalSnapshot = await inspectLock(quarantinePath, resource.digest);
  } catch (error) {
    await restoreQuarantinedPath(quarantinePath, livePath);
    throw error;
  }
  if (!sameSnapshot(quarantined, finalSnapshot)) {
    await restoreQuarantinedPath(quarantinePath, livePath);
    throw integrity('Quarantined lease changed at the deletion checkpoint');
  }
  await fs.rm(quarantinePath, { recursive: true });
  return { reclaimed: true, disappeared: false };
}

function acquisitionOwner({
  token,
  identity,
  children,
  runId,
  resource,
  resourceSetDigests,
  parameters,
  acquiredAtMs,
  processProbeProvider,
}) {
  return {
    schema: androidAttestationLeaseSchema,
    token,
    pid: identity.pid,
    hostname: identity.hostname,
    ownerIdentity: identity,
    childIdentities: children,
    runId,
    resourceKind: resource.kind,
    resourceDigest: resource.digest,
    resourceSetDigest: digestJson(resourceSetDigests),
    resourceSetDigests,
    parameters,
    acquiredAtMs,
    ownerRevision: 0,
    processProbeProvider,
  };
}

function heartbeat(token, sequence, wallTimeMs) {
  return {
    schema: androidAttestationLeaseSchema,
    token,
    sequence,
    wallTimeMs,
  };
}

async function buildCandidate({
  candidateRoot,
  candidatePath,
  owner,
  initialHeartbeat,
}) {
  await fs.mkdir(candidatePath, { mode: 0o700 });
  try {
    await writeExclusiveJson(path.join(candidatePath, ownerFileName), owner);
    await writeExclusiveJson(
      path.join(candidatePath, heartbeatFileName),
      initialHeartbeat,
    );
    await fs.mkdir(path.join(candidatePath, 'checkpoints'), { mode: 0o700 });
    await ensurePrivateDirectory(candidatePath);
    await ensurePrivateDirectory(path.join(candidatePath, 'checkpoints'));
  } catch (error) {
    await fs.rm(candidatePath, { recursive: true, force: true });
    throw error;
  }
  await ensurePrivateDirectory(candidateRoot);
}

async function assertNoUnresolvedTransitions(directories, resourceDigest) {
  const prefix = `${resourceDigest}.`;
  for (const [kind, directory] of [
    ['quarantine', directories.quarantine],
    ['release', directories.releases],
  ]) {
    const matches = (await fs.readdir(directory)).filter((entry) =>
      entry.startsWith(prefix),
    );
    if (matches.length > 0) {
      throw integrity(
        `Unresolved ${kind} transition blocks resource acquisition`,
        { resourceDigest, count: matches.length },
      );
    }
  }
}

async function acquireOne({
  directories,
  resource,
  owner,
  initialHeartbeat,
  staleAfterMs,
  nowMs,
  processProbe,
  hooks,
  randomBytes,
}) {
  let reclaimCount = 0;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    await assertNoUnresolvedTransitions(directories, resource.digest);
    const candidatePath = path.join(
      directories.candidates,
      `${resource.digest}.${owner.token}.${randomBytes(16).toString('hex')}`,
    );
    await buildCandidate({
      candidateRoot: directories.candidates,
      candidatePath,
      owner,
      initialHeartbeat,
    });
    const livePath = path.join(directories.locks, resource.digest);
    try {
      await fs.rename(candidatePath, livePath);
      const snapshot = await inspectLock(livePath, resource.digest);
      if (
        snapshot === null ||
        snapshot.owner.token !== owner.token ||
        snapshot.heartbeat.token !== owner.token
      ) {
        throw integrity('Atomic candidate acquisition did not preserve its token');
      }
      return { resource, livePath, snapshot, reclaimCount };
    } catch (error) {
      await fs.rm(candidatePath, { recursive: true, force: true });
      if (['ENOTDIR', 'EISDIR'].includes(error?.code)) {
        const existing = await inspectLock(livePath, resource.digest);
        if (existing === null) {
          throw integrity('Lock target has an invalid filesystem type');
        }
      }
      if (!['EEXIST', 'ENOTEMPTY'].includes(error?.code)) throw error;
      const result = await reclaimIfProvablyAbandoned({
        livePath,
        quarantineRoot: directories.quarantine,
        resource,
        staleAfterMs,
        nowMs,
        processProbe,
        hooks,
        randomBytes,
      });
      if (result.reclaimed) reclaimCount += 1;
    }
  }
  throw unavailable('Lease acquisition did not converge safely', {
    resourceDigest: resource.digest,
  });
}

function expectedOwnership(record, token) {
  return {
    inode: record.snapshot.inode,
    token,
    resourceDigest: record.resource.digest,
  };
}

async function assertRecordOwned(record, token) {
  const current = await inspectLock(record.livePath, record.resource.digest);
  const expected = expectedOwnership(record, token);
  if (
    current === null ||
    current.owner.token !== expected.token ||
    !sameStatIdentity(current.inode, expected.inode)
  ) {
    throw ownership('Lease token or directory inode no longer belongs to this owner', {
      resourceDigest: record.resource.digest,
    });
  }
  return current;
}

async function releaseRecord({ record, token, releasesRoot, hooks, randomBytes }) {
  const before = await assertRecordOwned(record, token);
  await hooks?.beforeReleaseRename?.({ livePath: record.livePath, snapshot: before });
  const confirmed = await assertRecordOwned(record, token);
  if (!sameSnapshot(before, confirmed)) {
    throw ownership('Lease changed at the release checkpoint');
  }
  const releasePath = path.join(
    releasesRoot,
    `${record.resource.digest}.${randomBytes(32).toString('hex')}`,
  );
  await fs.rename(record.livePath, releasePath);
  await hooks?.afterReleaseRename?.({ releasePath, snapshot: confirmed });
  let released;
  try {
    released = await inspectLock(releasePath, record.resource.digest);
  } catch (error) {
    await restoreQuarantinedPath(releasePath, record.livePath);
    throw error;
  }
  if (!sameSnapshot(confirmed, released) || released.owner.token !== token) {
    await restoreQuarantinedPath(releasePath, record.livePath);
    throw ownership('Released lease failed its inode/token deletion checkpoint');
  }
  let finalSnapshot;
  try {
    finalSnapshot = await inspectLock(releasePath, record.resource.digest);
  } catch (error) {
    await restoreQuarantinedPath(releasePath, record.livePath);
    throw error;
  }
  if (!sameSnapshot(released, finalSnapshot)) {
    await restoreQuarantinedPath(releasePath, record.livePath);
    throw ownership('Released lease changed immediately before deletion');
  }
  await fs.rm(releasePath, { recursive: true });
}

export class AndroidAttestationExclusiveLease {
  #token;
  #records;
  #clock;
  #hooks;
  #randomBytes;
  #directories;
  #staleAfterMs;
  #probeProvider;
  #processProbe;
  #children;
  #heartbeatSequence = 0;
  #lastHeartbeatAtMs;
  #releasedAtMs = null;
  #released = false;
  #timer = null;
  #timerWork = Promise.resolve();
  #heartbeatFailure = null;
  #checkpoints = [];
  #reclaimCount;

  constructor({
    token,
    records,
    clock,
    hooks,
    randomBytes,
    directories,
    staleAfterMs,
    probeProvider,
    processProbe,
    children,
    acquiredAtMs,
    reclaimCount,
  }) {
    this.#token = token;
    this.#records = records;
    this.#clock = clock;
    this.#hooks = hooks;
    this.#randomBytes = randomBytes;
    this.#directories = directories;
    this.#staleAfterMs = staleAfterMs;
    this.#probeProvider = probeProvider;
    this.#processProbe = processProbe;
    this.#children = children;
    this.acquiredAtMs = acquiredAtMs;
    this.#lastHeartbeatAtMs = acquiredAtMs;
    this.#reclaimCount = reclaimCount;
  }

  get released() {
    return this.#released;
  }

  async assertOwned() {
    if (this.#heartbeatFailure !== null) {
      throw ownership('Background lease heartbeat failed; ownership is no longer trusted', {
        cause:
          this.#heartbeatFailure?.code ??
          this.#heartbeatFailure?.name ??
          'heartbeat_failure',
      });
    }
    if (this.#released) throw ownership('Lease has already been released');
    const snapshots = [];
    for (const record of this.#records) {
      snapshots.push(await assertRecordOwned(record, this.#token));
    }
    return snapshots.map((snapshot) => ({
      resourceDigest: snapshot.owner.resourceDigest,
      inode: snapshot.inode,
      ownerDigest: snapshot.ownerDigest,
      heartbeatDigest: snapshot.heartbeatDigest,
    }));
  }

  async heartbeat() {
    await this.assertOwned();
    const sequence = this.#heartbeatSequence + 1;
    const wallTimeMs = this.#clock.nowMs();
    if (
      !Number.isSafeInteger(wallTimeMs) ||
      wallTimeMs < this.#lastHeartbeatAtMs
    ) {
      throw ownership('Heartbeat clock is invalid or moved backwards');
    }
    const nextHeartbeat = heartbeat(this.#token, sequence, wallTimeMs);
    for (const record of this.#records) {
      const before = await assertRecordOwned(record, this.#token);
      await atomicReplaceJson({
        directory: record.livePath,
        fileName: heartbeatFileName,
        value: nextHeartbeat,
        token: this.#token,
        hooks: this.#hooks,
      });
      const after = await assertRecordOwned(record, this.#token);
      if (!sameStatIdentity(before.inode, after.inode)) {
        throw ownership('Lease inode changed during heartbeat');
      }
      record.snapshot = after;
    }
    this.#heartbeatSequence = sequence;
    this.#lastHeartbeatAtMs = wallTimeMs;
    await this.assertOwned();
    return { sequence, wallTimeMs };
  }

  startHeartbeat({ intervalMs } = {}) {
    if (!Number.isSafeInteger(intervalMs) || intervalMs <= 0) {
      throw new TypeError('intervalMs must be a positive integer');
    }
    if (intervalMs * 2 >= this.#staleAfterMs) {
      throw new TypeError('intervalMs must be less than half staleAfterMs');
    }
    if (this.#timer !== null) throw new Error('Heartbeat timer is already running');
    if (this.#heartbeatFailure !== null) {
      throw ownership('A failed heartbeat timer cannot be restarted');
    }
    this.#timer = setInterval(() => {
      this.#timerWork = this.#timerWork
        .then(async () => {
          if (this.#heartbeatFailure === null) await this.heartbeat();
        })
        .catch((error) => {
          this.#heartbeatFailure = error;
          if (this.#timer !== null) clearInterval(this.#timer);
          this.#timer = null;
        });
    }, intervalMs);
    this.#timer.unref?.();
  }

  async stopHeartbeat() {
    if (this.#timer !== null) clearInterval(this.#timer);
    this.#timer = null;
    await this.#timerWork;
    if (this.#heartbeatFailure !== null) {
      throw ownership('Background lease heartbeat failed; lease retained fail-closed', {
        cause:
          this.#heartbeatFailure?.code ??
          this.#heartbeatFailure?.name ??
          'heartbeat_failure',
      });
    }
  }

  async captureChildIdentity({ pid, processGroupId = null, role = 'child-process' }) {
    if (typeof this.#processProbe.captureIdentity !== 'function') {
      throw new TypeError(
        'The configured processProbe cannot capture child identities',
      );
    }
    return normalizeIdentity(
      await this.#processProbe.captureIdentity(pid, { processGroupId, role }),
      'captured child identity',
    );
  }

  async registerChildProcess(input) {
    const identity = await this.captureChildIdentity(input);
    await this.registerChild(identity);
    return identity;
  }

  async #replaceChildren(children) {
    await this.heartbeat();
    for (const record of this.#records) {
      const before = await assertRecordOwned(record, this.#token);
      const nextOwner = {
        ...before.owner,
        childIdentities: children,
        ownerRevision: before.owner.ownerRevision + 1,
      };
      await atomicReplaceJson({
        directory: record.livePath,
        fileName: ownerFileName,
        value: nextOwner,
        token: this.#token,
        hooks: this.#hooks,
      });
      const after = await assertRecordOwned(record, this.#token);
      if (!sameStatIdentity(before.inode, after.inode)) {
        throw ownership('Lease inode changed while registering child identities');
      }
      record.snapshot = after;
    }
    this.#children = children;
    await this.heartbeat();
  }

  async registerChild(inputIdentity) {
    const identity = normalizeIdentity(inputIdentity, 'child identity');
    if (this.#children.some((candidate) => identityKey(candidate) === identityKey(identity))) {
      return this.evidence();
    }
    await this.#replaceChildren(
      [...this.#children, identity].sort((left, right) =>
        compareStrings(identityKey(left), identityKey(right)),
      ),
    );
    return this.evidence();
  }

  async removeChild(inputIdentity) {
    const identity = normalizeIdentity(inputIdentity, 'child identity');
    const key = identityKey(identity);
    const children = this.#children.filter(
      (candidate) => identityKey(candidate) !== key,
    );
    if (children.length === this.#children.length) {
      throw ownership('Cannot remove an unregistered child identity');
    }
    await this.#replaceChildren(children);
    return this.evidence();
  }

  async checkpoint(label, details = {}) {
    assertNonEmptyString(label, 'checkpoint label', 256);
    const normalizedDetails = canonicalize(details, 'checkpoint details');
    await this.assertOwned();
    const checkpoint = {
      sequence: this.#checkpoints.length + 1,
      label,
      wallTimeMs: this.#clock.nowMs(),
      detailsDigest: digestJson(normalizedDetails),
    };
    const fileName = `${String(checkpoint.sequence).padStart(6, '0')}-${sha256(label).slice(0, 16)}.json`;
    for (const record of this.#records) {
      await writeExclusiveJson(
        path.join(record.livePath, 'checkpoints', fileName),
        { ...checkpoint, token: this.#token },
      );
      await assertRecordOwned(record, this.#token);
    }
    this.#checkpoints.push(checkpoint);
    return checkpoint;
  }

  evidence() {
    const tokenDigest = sha256(this.#token);
    return {
      schema: androidAttestationLeaseSchema,
      resources: this.#records.map((record) => ({
        kind: record.resource.kind,
        digest: record.resource.digest,
        tokenDigest,
        ownerDigest: record.snapshot.ownerDigest,
      })),
      owner: {
        digest: digestJson(
          this.#records.map((record) => record.snapshot.ownerDigest).sort(),
        ),
        processIdentityDigest: digestJson(
          this.#records[0].snapshot.owner.ownerIdentity,
        ),
        processProbeProvider: this.#probeProvider,
        childIdentityCount: this.#children.length,
      },
      timing: {
        acquiredAtMs: this.acquiredAtMs,
        lastHeartbeatAtMs: this.#lastHeartbeatAtMs,
        releasedAtMs: this.#releasedAtMs,
        staleAfterMs: this.#staleAfterMs,
      },
      reclaimCount: this.#reclaimCount,
      checkpoints: this.#checkpoints.map((checkpoint) => ({ ...checkpoint })),
      isolation: {
        privateLockRootVerified: true,
        sortedResourceAcquisitionVerified: true,
        tokenAndInodeOwnershipVerified: !this.#released,
      },
    };
  }

  async release() {
    if (this.#released) throw ownership('Lease has already been released');
    await this.stopHeartbeat();
    await this.assertOwned();
    for (const record of [...this.#records].reverse()) {
      await releaseRecord({
        record,
        token: this.#token,
        releasesRoot: this.#directories.releases,
        hooks: this.#hooks,
        randomBytes: this.#randomBytes,
      });
    }
    this.#releasedAtMs = this.#clock.nowMs();
    this.#released = true;
    return this.evidence();
  }
}

export async function acquireAndroidAttestationExclusiveLease({
  lockRoot,
  resourceKeys,
  runId,
  parameters = {},
  childIdentities = [],
  staleAfterMs = 120_000,
  dependencies = {},
} = {}) {
  const platform = dependencies.platform ?? process.platform;
  if (platform !== 'darwin' && platform !== 'linux') {
    throw new Error(`Android attestation lease requires darwin/linux, got ${platform}`);
  }
  if (typeof lockRoot !== 'string' || !path.isAbsolute(lockRoot)) {
    throw new TypeError('lockRoot must be an absolute path');
  }
  if (!Number.isSafeInteger(staleAfterMs) || staleAfterMs <= 0) {
    throw new TypeError('staleAfterMs must be a positive integer');
  }
  const resources = normalizeResources(resourceKeys);
  const normalizedRunId = validateRunId(runId);
  const normalizedParameters = canonicalize(parameters, 'parameters');
  const children = childIdentities
    .map((identity, index) => normalizeIdentity(identity, `childIdentities[${index}]`))
    .sort((left, right) =>
      compareStrings(identityKey(left), identityKey(right)),
    );
  if (new Set(children.map(identityKey)).size !== children.length) {
    throw new TypeError('childIdentities contains duplicates');
  }
  const clock = dependencies.clock ?? { nowMs: () => Date.now() };
  if (typeof clock.nowMs !== 'function') {
    throw new TypeError('dependencies.clock.nowMs is required');
  }
  const processProbe =
    dependencies.processProbe ?? createPosixProcessIdentityProbe({ platform });
  if (
    typeof processProbe.currentIdentity !== 'function' ||
    typeof processProbe.probe !== 'function'
  ) {
    throw new TypeError('processProbe must expose currentIdentity() and probe()');
  }
  const processProbeProvider = assertNonEmptyString(
    processProbe.provider ?? 'injected-process-probe',
    'processProbe.provider',
    256,
  );
  const randomBytes = dependencies.randomBytes ?? crypto.randomBytes;
  const hooks = dependencies.hooks ?? {};
  const acquiredAtMs = clock.nowMs();
  if (!Number.isSafeInteger(acquiredAtMs) || acquiredAtMs < 0) {
    throw new TypeError('clock.nowMs() must return a non-negative integer');
  }
  const identity = normalizeIdentity(await processProbe.currentIdentity());
  const token = randomBytes(32);
  if (!Buffer.isBuffer(token) || token.length !== 32) {
    throw new TypeError('randomBytes(32) must return exactly 32 bytes');
  }
  const tokenHex = token.toString('hex');

  await ensureSecureLockRootParent(lockRoot);
  await ensurePrivateDirectory(lockRoot, { create: true });
  const directories = {
    locks: path.join(lockRoot, 'locks'),
    candidates: path.join(lockRoot, 'candidates'),
    quarantine: path.join(lockRoot, 'quarantine'),
    releases: path.join(lockRoot, 'releases'),
  };
  for (const directory of Object.values(directories)) {
    await ensurePrivateDirectory(directory, { create: true });
  }

  const resourceSetDigests = resources.map((resource) => resource.digest).sort();
  const initialHeartbeat = heartbeat(tokenHex, 0, acquiredAtMs);
  const records = [];
  let reclaimCount = 0;
  try {
    for (const resource of resources) {
      const owner = acquisitionOwner({
        token: tokenHex,
        identity,
        children,
        runId: normalizedRunId,
        resource,
        resourceSetDigests,
        parameters: normalizedParameters,
        acquiredAtMs,
        processProbeProvider,
      });
      const record = await acquireOne({
        directories,
        resource,
        owner,
        initialHeartbeat,
        staleAfterMs,
        nowMs: acquiredAtMs,
        processProbe,
        hooks,
        randomBytes,
      });
      records.push(record);
      reclaimCount += record.reclaimCount;
    }
  } catch (error) {
    for (const record of [...records].reverse()) {
      try {
        await releaseRecord({
          record,
          token: tokenHex,
          releasesRoot: directories.releases,
          hooks: {},
          randomBytes,
        });
      } catch {
        // Preserve a lock with uncertain ownership. The original acquisition
        // failure remains the actionable error and no unsafe deletion occurs.
      }
    }
    throw error;
  }

  return new AndroidAttestationExclusiveLease({
    token: tokenHex,
    records,
    clock,
    hooks,
    randomBytes,
    directories,
    staleAfterMs,
    probeProvider: processProbeProvider,
    processProbe,
    children,
    acquiredAtMs,
    reclaimCount,
  });
}
