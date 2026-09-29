import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { spawn } from 'node:child_process';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import {
  AndroidAttestationLeaseIntegrityError,
  AndroidAttestationLeaseOwnershipError,
  AndroidAttestationLeaseUnavailableError,
  acquireAndroidAttestationExclusiveLease,
  androidAttestationLeaseSchema,
  createPosixProcessIdentityProbe,
  processIdentityProbeStatuses,
} from './android_attestation_exclusive_lease.mjs';

function digest(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function identity(pid, startIdentity, role = 'process') {
  return {
    pid,
    hostname: 'lease-test-host',
    bootIdentity: 'boot-test-1',
    startIdentity,
    processGroupId: pid,
    role,
  };
}

function fakeProbe(initialIdentity) {
  const statuses = new Map();
  return {
    provider: 'test-exact-identity-v1',
    supportsStaleReclaim: true,
    current: initialIdentity,
    statuses,
    async captureIdentity(pid, { processGroupId = null, role = 'child-process' } = {}) {
      return {
        ...identity(pid, `captured-${pid}`, role),
        processGroupId,
      };
    },
    async currentIdentity() {
      return this.current;
    },
    async probe(candidate) {
      return {
        status:
          statuses.get(candidate.startIdentity) ??
          processIdentityProbeStatuses.liveExact,
      };
    },
  };
}

async function fixture(t) {
  const parent = await fs.mkdtemp(path.join(os.tmpdir(), 'parkinsum-lease-test-'));
  const lockRoot = path.join(parent, 'private-lock-root');
  const clock = { value: 1_000, nowMs() { return this.value; } };
  const probe = fakeProbe(identity(101, 'owner-a', 'lease-owner'));
  t.after(async () => {
    await fs.rm(parent, { recursive: true, force: true });
  });
  return { parent, lockRoot, clock, probe };
}

function options(fixtureValue, overrides = {}) {
  return {
    lockRoot: fixtureValue.lockRoot,
    resourceKeys: [
      { kind: 'build-output', key: 'build/app' },
      { kind: 'android-device', key: 'emulator-5556' },
    ],
    runId: 'reminder-test-0001',
    parameters: { buildMode: 'debug', isolatedApplicationId: true },
    staleAfterMs: 100,
    dependencies: {
      platform: 'linux',
      clock: fixtureValue.clock,
      processProbe: fixtureValue.probe,
    },
    ...overrides,
  };
}

async function readJson(filePath) {
  return JSON.parse(await fs.readFile(filePath, 'utf8'));
}

async function replaceJson(filePath, mutate) {
  const value = await readJson(filePath);
  mutate(value);
  await fs.writeFile(filePath, `${JSON.stringify(value)}\n`, { mode: 0o600 });
}

function livePath(lockRoot, resourceKey) {
  return path.join(lockRoot, 'locks', digest(resourceKey));
}

function waitForLine(stream, expected, timeoutMs = 10_000) {
  return new Promise((resolve, reject) => {
    let buffered = '';
    const timeout = setTimeout(
      () => reject(new Error(`Timed out waiting for child output: ${expected}`)),
      timeoutMs,
    );
    const onData = (chunk) => {
      buffered += chunk.toString();
      if (buffered.split(/\r?\n/).includes(expected)) {
        clearTimeout(timeout);
        stream.off('data', onData);
        resolve();
      }
    };
    stream.on('data', onData);
  });
}

test('atomic candidates serialize two contenders and release permits the next owner', async (t) => {
  const f = await fixture(t);
  const first = await acquireAndroidAttestationExclusiveLease(options(f));
  f.probe.current = identity(202, 'owner-b', 'lease-owner');

  await assert.rejects(
    acquireAndroidAttestationExclusiveLease(options(f, { runId: 'reminder-test-0002' })),
    AndroidAttestationLeaseUnavailableError,
  );
  await first.release();
  const second = await acquireAndroidAttestationExclusiveLease(
    options(f, { runId: 'reminder-test-0003' }),
  );
  await second.release();
});

test('a real child process excludes a competing parent process', async (t) => {
  const f = await fixture(t);
  const moduleUrl = new URL(
    './android_attestation_exclusive_lease.mjs',
    import.meta.url,
  ).href;
  const childSource = `
    import { acquireAndroidAttestationExclusiveLease } from ${JSON.stringify(moduleUrl)};
    const lease = await acquireAndroidAttestationExclusiveLease({
      lockRoot: process.argv[1],
      resourceKeys: [{ kind: 'multiprocess', key: 'shared-build-output' }],
      runId: 'child-process-run-01',
      staleAfterMs: 30000,
    });
    console.log('ACQUIRED');
    process.stdin.once('data', async () => {
      await lease.release();
      console.log('RELEASED');
      setTimeout(() => process.exit(0), 10);
    });
  `;
  const child = spawn(
    process.execPath,
    ['--input-type=module', '--eval', childSource, f.lockRoot],
    { stdio: ['pipe', 'pipe', 'pipe'] },
  );
  let childStderr = '';
  child.stderr.on('data', (chunk) => {
    childStderr += chunk.toString();
  });
  t.after(() => {
    if (child.exitCode === null) child.kill('SIGKILL');
  });
  await waitForLine(child.stdout, 'ACQUIRED');

  await assert.rejects(
    acquireAndroidAttestationExclusiveLease(
      options(f, {
        runId: 'parent-process-run-01',
        resourceKeys: [{ kind: 'multiprocess', key: 'shared-build-output' }],
      }),
    ),
    AndroidAttestationLeaseUnavailableError,
  );
  const releasedLine = waitForLine(child.stdout, 'RELEASED');
  child.stdin.end('release\n');
  await releasedLine;
  const exitCode = await new Promise((resolve) => child.once('exit', resolve));
  assert.equal(exitCode, 0, childStderr);
});

test('sorted multi-resource acquisition rejects an intersecting set without leaking earlier locks', async (t) => {
  const f = await fixture(t);
  const first = await acquireAndroidAttestationExclusiveLease(
    options(f, {
      resourceKeys: [
        { kind: 'second', key: 'resource-b' },
        { kind: 'first', key: 'resource-a' },
      ],
    }),
  );
  f.probe.current = identity(203, 'owner-c', 'lease-owner');
  await assert.rejects(
    acquireAndroidAttestationExclusiveLease(
      options(f, {
        runId: 'reminder-test-0004',
        resourceKeys: [
          { kind: 'third', key: 'resource-c' },
          { kind: 'overlap', key: 'resource-b' },
        ],
      }),
    ),
    AndroidAttestationLeaseUnavailableError,
  );

  const independent = await acquireAndroidAttestationExclusiveLease(
    options(f, {
      runId: 'reminder-test-0005',
      resourceKeys: [{ kind: 'third', key: 'resource-c' }],
    }),
  );
  await independent.release();
  await first.release();
});

test('fresh stale-threshold lock and stale exact-live owner are never reclaimed', async (t) => {
  const f = await fixture(t);
  await acquireAndroidAttestationExclusiveLease(options(f));
  f.probe.current = identity(204, 'owner-d', 'lease-owner');

  f.clock.value = 1_050;
  await assert.rejects(
    acquireAndroidAttestationExclusiveLease(options(f, { runId: 'reminder-test-0006' })),
    AndroidAttestationLeaseUnavailableError,
  );

  f.clock.value = 1_500;
  f.probe.statuses.set('owner-a', processIdentityProbeStatuses.liveExact);
  await assert.rejects(
    acquireAndroidAttestationExclusiveLease(options(f, { runId: 'reminder-test-0007' })),
    AndroidAttestationLeaseUnavailableError,
  );
});

test('stale lock is reclaimed only after exact owner death and every child death', async (t) => {
  const f = await fixture(t);
  const child = identity(301, 'child-a', 'flutter-child');
  const first = await acquireAndroidAttestationExclusiveLease(options(f));
  await first.registerChild(child);
  f.clock.value = 2_000;
  f.probe.current = identity(205, 'owner-e', 'lease-owner');
  f.probe.statuses.set('owner-a', processIdentityProbeStatuses.dead);
  f.probe.statuses.set('child-a', processIdentityProbeStatuses.liveExact);

  await assert.rejects(
    acquireAndroidAttestationExclusiveLease(options(f, { runId: 'reminder-test-0008' })),
    AndroidAttestationLeaseUnavailableError,
  );
  f.probe.statuses.set('child-a', processIdentityProbeStatuses.dead);
  const replacement = await acquireAndroidAttestationExclusiveLease(
    options(f, { runId: 'reminder-test-0009' }),
  );
  assert.equal(replacement.evidence().reclaimCount, 2);
  await replacement.release();
});

test('PID reuse with a confirmed start-identity mismatch permits stale reclaim', async (t) => {
  const f = await fixture(t);
  await acquireAndroidAttestationExclusiveLease(
    options(f, { resourceKeys: [{ kind: 'build', key: 'reuse-resource' }] }),
  );
  f.clock.value = 2_000;
  f.probe.current = identity(101, 'owner-a-reused', 'lease-owner');
  f.probe.statuses.set('owner-a', processIdentityProbeStatuses.mismatch);
  const replacement = await acquireAndroidAttestationExclusiveLease(
    options(f, {
      runId: 'reminder-test-0010',
      resourceKeys: [{ kind: 'build', key: 'reuse-resource' }],
    }),
  );
  assert.equal(replacement.evidence().reclaimCount, 1);
  await replacement.release();
});

test('unknown process result fails closed even for an old heartbeat', async (t) => {
  const f = await fixture(t);
  await acquireAndroidAttestationExclusiveLease(options(f));
  f.clock.value = 2_000;
  f.probe.current = identity(206, 'owner-f', 'lease-owner');
  f.probe.statuses.set('owner-a', processIdentityProbeStatuses.unknown);
  await assert.rejects(
    acquireAndroidAttestationExclusiveLease(options(f, { runId: 'reminder-test-0011' })),
    AndroidAttestationLeaseIntegrityError,
  );
});

test('heartbeat renewal racing stale reclaim invalidates the reclaim snapshot', async (t) => {
  const f = await fixture(t);
  const first = await acquireAndroidAttestationExclusiveLease(options(f));
  f.clock.value = 2_000;
  f.probe.current = identity(207, 'owner-g', 'lease-owner');
  f.probe.statuses.set('owner-a', processIdentityProbeStatuses.dead);

  await assert.rejects(
    acquireAndroidAttestationExclusiveLease(
      options(f, {
        runId: 'reminder-test-0012',
        dependencies: {
          platform: 'linux',
          clock: f.clock,
          processProbe: f.probe,
          hooks: {
            async beforeReclaimRename() {
              await first.heartbeat();
            },
          },
        },
      }),
    ),
    AndroidAttestationLeaseIntegrityError,
  );
  await first.release();
});

test('token mismatch fails assertOwned and blocks a second acquisition', async (t) => {
  const f = await fixture(t);
  const lease = await acquireAndroidAttestationExclusiveLease(
    options(f, { resourceKeys: [{ kind: 'build', key: 'token-resource' }] }),
  );
  const ownerPath = path.join(livePath(f.lockRoot, 'token-resource'), 'owner.json');
  await replaceJson(ownerPath, (owner) => {
    owner.token = 'f'.repeat(64);
  });
  await assert.rejects(lease.assertOwned(), AndroidAttestationLeaseIntegrityError);
  f.clock.value = 2_000;
  f.probe.statuses.set('owner-a', processIdentityProbeStatuses.dead);
  await assert.rejects(
    acquireAndroidAttestationExclusiveLease(
      options(f, {
        runId: 'reminder-test-0013',
        resourceKeys: [{ kind: 'build', key: 'token-resource' }],
      }),
    ),
    AndroidAttestationLeaseIntegrityError,
  );
});

test('ordinary files, symlink locks, and unknown schemas all fail closed', async (t) => {
  const f = await fixture(t);
  await fs.mkdir(path.join(f.lockRoot, 'locks'), { recursive: true, mode: 0o700 });
  await fs.mkdir(path.join(f.lockRoot, 'candidates'), { mode: 0o700 });
  await fs.mkdir(path.join(f.lockRoot, 'quarantine'), { mode: 0o700 });
  await fs.mkdir(path.join(f.lockRoot, 'releases'), { mode: 0o700 });
  const fileResource = 'ordinary-file-resource';
  await fs.writeFile(livePath(f.lockRoot, fileResource), 'not a directory');
  await assert.rejects(
    acquireAndroidAttestationExclusiveLease(
      options(f, { resourceKeys: [{ kind: 'file', key: fileResource }] }),
    ),
    AndroidAttestationLeaseIntegrityError,
  );

  const symlinkResource = 'symlink-resource';
  await fs.symlink(
    livePath(f.lockRoot, fileResource),
    livePath(f.lockRoot, symlinkResource),
  );
  await assert.rejects(
    acquireAndroidAttestationExclusiveLease(
      options(f, {
        runId: 'reminder-test-0014',
        resourceKeys: [{ kind: 'symlink', key: symlinkResource }],
      }),
    ),
    AndroidAttestationLeaseIntegrityError,
  );

  const schemaResource = 'schema-resource';
  const lease = await acquireAndroidAttestationExclusiveLease(
    options(f, {
      runId: 'reminder-test-0015',
      resourceKeys: [{ kind: 'schema', key: schemaResource }],
    }),
  );
  await replaceJson(
    path.join(livePath(f.lockRoot, schemaResource), 'owner.json'),
    (owner) => {
      owner.schema = `${androidAttestationLeaseSchema}-future`;
    },
  );
  await assert.rejects(lease.assertOwned(), AndroidAttestationLeaseIntegrityError);
});

test('an unresolved quarantine or release transition blocks reacquisition', async (t) => {
  const f = await fixture(t);
  const resourceKey = 'transition-resource';
  const resourceDigest = digest(resourceKey);
  await fs.mkdir(path.join(f.lockRoot, 'locks'), { recursive: true, mode: 0o700 });
  await fs.mkdir(path.join(f.lockRoot, 'candidates'), { mode: 0o700 });
  await fs.mkdir(path.join(f.lockRoot, 'quarantine'), { mode: 0o700 });
  await fs.mkdir(path.join(f.lockRoot, 'releases'), { mode: 0o700 });
  await fs.mkdir(
    path.join(f.lockRoot, 'quarantine', `${resourceDigest}.${'a'.repeat(64)}`),
    { mode: 0o700 },
  );
  await assert.rejects(
    acquireAndroidAttestationExclusiveLease(
      options(f, {
        runId: 'reminder-test-0016',
        resourceKeys: [{ kind: 'transition', key: resourceKey }],
      }),
    ),
    AndroidAttestationLeaseIntegrityError,
  );
});

test('release mismatch is retained and restored instead of being deleted', async (t) => {
  const f = await fixture(t);
  const resourceKey = 'release-race-resource';
  let tampered = false;
  const lease = await acquireAndroidAttestationExclusiveLease(
    options(f, {
      resourceKeys: [{ kind: 'release', key: resourceKey }],
      dependencies: {
        platform: 'linux',
        clock: f.clock,
        processProbe: f.probe,
        hooks: {
          async afterReleaseRename({ releasePath }) {
            if (tampered) return;
            tampered = true;
            await replaceJson(path.join(releasePath, 'owner.json'), (owner) => {
              owner.token = 'e'.repeat(64);
            });
          },
        },
      },
    }),
  );
  await assert.rejects(lease.release(), AndroidAttestationLeaseIntegrityError);
  const restored = await fs.lstat(livePath(f.lockRoot, resourceKey));
  assert.equal(restored.isDirectory(), true);
});

test('checkpoints, child removal, and evidence expose digests without raw tokens', async (t) => {
  const f = await fixture(t);
  const lease = await acquireAndroidAttestationExclusiveLease(options(f));
  const child = await lease.registerChildProcess({
    pid: 401,
    processGroupId: 401,
    role: 'gradle-child',
  });
  assert.equal(child.startIdentity, 'captured-401');
  await lease.checkpoint('apk-built', { apkDigest: 'a'.repeat(64) });
  await lease.removeChild(child);
  const evidence = lease.evidence();
  assert.equal(evidence.resources.length, 2);
  assert.deepEqual(
    evidence.resources.map((resource) => resource.kind),
    ['build-output', 'android-device'],
  );
  assert.match(evidence.resources[0].tokenDigest, /^[0-9a-f]{64}$/);
  assert.match(evidence.owner.processIdentityDigest, /^[0-9a-f]{64}$/);
  assert.equal(evidence.owner.childIdentityCount, 0);
  assert.equal(evidence.checkpoints.length, 1);
  assert.deepEqual(evidence.isolation, {
    privateLockRootVerified: true,
    sortedResourceAcquisitionVerified: true,
    tokenAndInodeOwnershipVerified: true,
  });
  assert.equal(JSON.stringify(evidence).includes('owner-a'), false);
  const releasedEvidence = await lease.release();
  assert.equal(releasedEvidence.isolation.tokenAndInodeOwnershipVerified, false);
});

test('default Darwin provider advertises no stale reclaim authorization', () => {
  const provider = createPosixProcessIdentityProbe({
    platform: 'darwin',
    hostname: () => 'lease-test-host',
  });
  assert.equal(provider.provider, 'darwin-no-stale-reclaim-v1');
  assert.equal(provider.supportsStaleReclaim, false);
});

test('Darwin identity capture uses an unverified nonce without claiming reclaim strength', async () => {
  const provider = createPosixProcessIdentityProbe({
    platform: 'darwin',
    hostname: () => 'lease-test-host',
  });
  const captured = await provider.captureIdentity(777, {
    processGroupId: 777,
    role: 'flutter-child',
  });
  assert.equal(captured.bootIdentity, 'darwin-no-reclaim');
  assert.match(
    captured.startIdentity,
    /^darwin-unverified-process-nonce:[0-9a-f]{64}$/,
  );
  assert.equal(
    (await provider.probe(captured)).status,
    processIdentityProbeStatuses.unknown,
  );
});

test('background heartbeat failure is captured and retains every lock fail-closed', async (t) => {
  const f = await fixture(t);
  const resourceKey = 'background-heartbeat-resource';
  let injected = false;
  const lease = await acquireAndroidAttestationExclusiveLease(
    options(f, {
      resourceKeys: [{ kind: 'heartbeat', key: resourceKey }],
      dependencies: {
        platform: 'linux',
        clock: f.clock,
        processProbe: f.probe,
        hooks: {
          async beforeAtomicJsonRename({ directory, fileName }) {
            if (injected || fileName !== 'heartbeat.json') return;
            injected = true;
            await replaceJson(path.join(directory, 'owner.json'), (owner) => {
              owner.token = 'd'.repeat(64);
            });
          },
        },
      },
    }),
  );
  lease.startHeartbeat({ intervalMs: 10 });
  await new Promise((resolve) => setTimeout(resolve, 40));
  await assert.rejects(lease.assertOwned(), AndroidAttestationLeaseOwnershipError);
  await assert.rejects(lease.stopHeartbeat(), AndroidAttestationLeaseOwnershipError);
  await assert.rejects(lease.release(), AndroidAttestationLeaseOwnershipError);
  assert.equal(
    (await fs.lstat(livePath(f.lockRoot, resourceKey))).isDirectory(),
    true,
  );
});

test('private lockRoot rejects group/other permissions', async (t) => {
  const f = await fixture(t);
  await fs.mkdir(f.lockRoot, { mode: 0o755 });
  await fs.chmod(f.lockRoot, 0o755);
  await assert.rejects(
    acquireAndroidAttestationExclusiveLease(options(f)),
    AndroidAttestationLeaseIntegrityError,
  );
});

test('lockRoot rejects a writable non-sticky parent directory', async (t) => {
  const f = await fixture(t);
  await fs.chmod(f.parent, 0o777);
  await assert.rejects(
    acquireAndroidAttestationExclusiveLease(options(f)),
    /writable without sticky-bit protection/,
  );
});
