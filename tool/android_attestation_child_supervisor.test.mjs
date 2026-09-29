import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { EventEmitter } from 'node:events';
import process from 'node:process';
import { describe, test } from 'node:test';

import {
  AndroidAttestationChildSupervisor,
  AttestationAbortError,
  signalExitCode,
} from './android_attestation_child_supervisor.mjs';

class FakeChild extends EventEmitter {
  constructor(pid) {
    super();
    this.pid = pid;
  }
}

function fakeHarness(options = {}) {
  const children = [];
  const signals = [];
  const supervisor = new AndroidAttestationChildSupervisor({
    spawnProcess: () => {
      const child = new FakeChild(1000 + children.length);
      children.push(child);
      return child;
    },
    sendSignal: (_child, signal, record) => {
      signals.push({ pid: record.pid, signal });
    },
    platform: 'linux',
    terminationGraceMs: options.terminationGraceMs ?? 20,
    onChildStart: options.onChildStart,
    onChildClose: options.onChildClose,
    processObject: options.processObject ?? new EventEmitter(),
  });
  return { supervisor, children, signals };
}

describe('Android attestation child supervision', () => {
  test('error does not count as drained until close and hooks retain ordering', async () => {
    const events = [];
    const { supervisor, children } = fakeHarness({
      onChildStart: async (record) => events.push(`start:${record.pid}`),
      onChildClose: async (record) => events.push(`close:${record.pid}`),
    });
    const record = await supervisor.launch('fake', [], {});
    assert.equal(supervisor.activeCount, 1);

    const spawnError = new Error('spawn failed');
    children[0].emit('error', spawnError);
    assert.equal(supervisor.childrenDrained, false);

    children[0].emit('close', -1, null);
    assert.deepEqual(await record.completion, {
      code: -1,
      signal: null,
      spawnError,
    });
    await supervisor.drain();
    assert.equal(supervisor.childrenDrained, true);
    assert.deepEqual(events, ['start:1000', 'close:1000']);
  });

  test('first signal requests TERM, second signal escalates KILL, and new work stops', async () => {
    const { supervisor, children, signals } = fakeHarness();
    const record = await supervisor.launch('fake', [], {});

    supervisor.requestAbort('SIGINT');
    assert.deepEqual(signals, [{ pid: 1000, signal: 'SIGTERM' }]);
    assert.equal(supervisor.abortSignal, 'SIGINT');
    assert.equal(supervisor.abortExitCode, 130);
    assert.throws(() => supervisor.throwIfAborted(), AttestationAbortError);
    await assert.rejects(
      supervisor.launch('second', [], {}),
      /interrupted by SIGINT/,
    );

    supervisor.requestAbort('SIGTERM');
    assert.deepEqual(signals.at(-1), { pid: 1000, signal: 'SIGKILL' });
    children[0].emit('close', null, 'SIGKILL');
    await record.completion;
    await supervisor.drain();
  });

  test('TERM grace expiry escalates to KILL', async () => {
    const { supervisor, children, signals } = fakeHarness({
      terminationGraceMs: 5,
    });
    const record = await supervisor.launch('fake', [], {});
    supervisor.requestAbort('SIGTERM');
    await new Promise((resolve) => setTimeout(resolve, 20));
    assert.deepEqual(signals, [
      { pid: 1000, signal: 'SIGTERM' },
      { pid: 1000, signal: 'SIGKILL' },
    ]);
    children[0].emit('close', null, 'SIGKILL');
    await record.completion;
    await supervisor.drain();
  });

  test('first abort grants protected cleanup grace and second abort still kills', async () => {
    const { supervisor, children, signals } = fakeHarness({
      terminationGraceMs: 50,
    });
    const record = await supervisor.launch('adb-cleanup', [], {
      allowDuringAbort: true,
    });
    supervisor.requestAbort('SIGINT');
    assert.deepEqual(signals, []);
    supervisor.requestAbort('SIGINT');
    assert.deepEqual(signals, [{ pid: 1000, signal: 'SIGKILL' }]);
    children[0].emit('close', null, 'SIGKILL');
    await record.completion;
    await supervisor.drain();
  });

  test('first abort terminates normal work but preserves cleanup until a second abort', async () => {
    const { supervisor, children, signals } = fakeHarness({
      terminationGraceMs: 1_000,
    });
    const normal = await supervisor.launch('normal-work', [], {});
    const cleanup = await supervisor.launch('adb-cleanup', [], {
      allowDuringAbort: true,
    });

    supervisor.requestAbort('SIGINT');
    assert.deepEqual(signals, [{ pid: 1000, signal: 'SIGTERM' }]);

    supervisor.requestAbort('SIGTERM');
    assert.deepEqual(signals, [
      { pid: 1000, signal: 'SIGTERM' },
      { pid: 1000, signal: 'SIGKILL' },
      { pid: 1001, signal: 'SIGKILL' },
    ]);

    children[0].emit('close', null, 'SIGKILL');
    children[1].emit('close', null, 'SIGKILL');
    await Promise.all([normal.completion, cleanup.completion]);
    await supervisor.drain();
  });

  test('cleanup launched after abort receives a bounded grace timer', async () => {
    const { supervisor, children, signals } = fakeHarness({
      terminationGraceMs: 5,
    });
    supervisor.requestAbort('SIGTERM');
    const record = await supervisor.launch('adb-cleanup', [], {
      allowDuringAbort: true,
    });
    assert.deepEqual(signals, []);
    await new Promise((resolve) => setTimeout(resolve, 20));
    assert.deepEqual(signals, [{ pid: 1000, signal: 'SIGKILL' }]);
    children[0].emit('close', null, 'SIGKILL');
    await record.completion;
    await supervisor.drain();
  });

  test('signal handlers mark abort without forcing process exit', async () => {
    const fakeProcess = new EventEmitter();
    const { supervisor, children, signals } = fakeHarness({
      processObject: fakeProcess,
    });
    const record = await supervisor.launch('fake', [], {});
    supervisor.installSignalHandlers();
    fakeProcess.emit('SIGHUP');
    assert.equal(supervisor.abortSignal, 'SIGHUP');
    assert.deepEqual(signals, [{ pid: 1000, signal: 'SIGTERM' }]);
    supervisor.disposeSignalHandlers();
    assert.equal(fakeProcess.listenerCount('SIGHUP'), 0);
    children[0].emit('close', null, 'SIGTERM');
    await record.completion;
    await supervisor.drain();
  });

  test('child registration hook failure aborts and waits for close', async () => {
    const hookFailure = new Error('lease child registration failed');
    const { supervisor, children, signals } = fakeHarness({
      onChildStart: async () => {
        throw hookFailure;
      },
    });
    const launched = supervisor.launch('fake', [], {});
    await new Promise((resolve) => setImmediate(resolve));
    assert.deepEqual(signals, [{ pid: 1000, signal: 'SIGTERM' }]);
    children[0].emit('close', null, 'SIGTERM');
    await assert.rejects(launched, /lease child registration failed/);
    await assert.rejects(supervisor.drain(), /child supervision failed/);
  });

  test('real child is tracked through close', async () => {
    const supervisor = new AndroidAttestationChildSupervisor({
      spawnProcess: spawn,
      platform: process.platform,
    });
    const record = await supervisor.launch(
      process.execPath,
      ['-e', 'process.stdout.write("tracked")'],
      { stdio: ['ignore', 'pipe', 'pipe'] },
    );
    const output = [];
    record.child.stdout.on('data', (chunk) => output.push(chunk));
    const completed = await record.completion;
    await supervisor.drain();
    assert.equal(completed.code, 0);
    assert.equal(Buffer.concat(output).toString('utf8'), 'tracked');
    assert.equal(supervisor.childrenDrained, true);
  });

  test('synchronous spawn attachment preserves output while registration is slow', async () => {
    const output = [];
    const supervisor = new AndroidAttestationChildSupervisor({
      spawnProcess: spawn,
      platform: process.platform,
      onChildStart: async () => {
        await new Promise((resolve) => setTimeout(resolve, 30));
      },
    });
    const record = await supervisor.launch(
      process.execPath,
      ['-e', 'process.stdout.write("registered-before-return")'],
      {
        stdio: ['ignore', 'pipe', 'pipe'],
        onSpawn: (child) => {
          child.stdout.on('data', (chunk) => output.push(chunk));
        },
      },
    );
    const completed = await record.completion;
    await supervisor.drain();
    assert.equal(completed.code, 0);
    assert.equal(
      Buffer.concat(output).toString('utf8'),
      'registered-before-return',
    );
  });

  test('execution barrier does not start the target before registration finishes', async () => {
    const output = [];
    let finishRegistration;
    const registrationGate = new Promise((resolve) => {
      finishRegistration = resolve;
    });
    const supervisor = new AndroidAttestationChildSupervisor({
      spawnProcess: spawn,
      platform: process.platform,
      onChildStart: async () => registrationGate,
    });
    const launched = supervisor.launch(
      process.execPath,
      ['-e', 'process.stdout.write("released-after-registration")'],
      {
        stdio: ['ignore', 'pipe', 'pipe'],
        executionBarrier: true,
        onSpawn: (child) => {
          child.stdout.on('data', (chunk) => output.push(chunk));
        },
      },
    );
    await new Promise((resolve) => setTimeout(resolve, 30));
    assert.equal(Buffer.concat(output).length, 0);
    finishRegistration();
    const record = await launched;
    assert.equal(record.barrierReleased, true);
    const completed = await record.completion;
    await supervisor.drain();
    assert.equal(completed.code, 0);
    assert.equal(
      Buffer.concat(output).toString('utf8'),
      'released-after-registration',
    );
  });

  test('signal exit-code mapping is explicit', () => {
    assert.equal(signalExitCode('SIGHUP'), 129);
    assert.equal(signalExitCode('SIGINT'), 130);
    assert.equal(signalExitCode('SIGTERM'), 143);
    assert.equal(signalExitCode('UNKNOWN'), 1);
  });
});
