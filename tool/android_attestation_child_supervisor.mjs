import { spawn } from 'node:child_process';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const commandBarrierPath = fileURLToPath(
  new URL('./android_attestation_command_barrier.mjs', import.meta.url),
);
const commandReleaseSchema =
  'parkinsum.android-attestation-command-release/1';

const handledSignals = Object.freeze(['SIGINT', 'SIGTERM', 'SIGHUP']);
const signalExitCodes = Object.freeze({
  SIGHUP: 129,
  SIGINT: 130,
  SIGTERM: 143,
});

export class AttestationAbortError extends Error {
  constructor(signal) {
    super(`Android attestation interrupted by ${signal}`);
    this.name = 'AttestationAbortError';
    this.signal = signal;
    this.exitCode = signalExitCodes[signal] ?? 1;
  }
}

export class AndroidAttestationChildSupervisor {
  constructor({
    spawnProcess = spawn,
    sendSignal,
    processObject = process,
    platform = process.platform,
    terminationGraceMs = 10_000,
    onChildStart = async () => {},
    onChildClose = async () => {},
  } = {}) {
    if (!Number.isInteger(terminationGraceMs) || terminationGraceMs < 1) {
      throw new TypeError('terminationGraceMs must be a positive integer');
    }
    if (typeof spawnProcess !== 'function') {
      throw new TypeError('spawnProcess must be a function');
    }
    if (typeof onChildStart !== 'function' || typeof onChildClose !== 'function') {
      throw new TypeError('child lifecycle hooks must be functions');
    }
    this._spawnProcess = spawnProcess;
    this._processObject = processObject;
    this._platform = platform;
    this._terminationGraceMs = terminationGraceMs;
    this._onChildStart = onChildStart;
    this._onChildClose = onChildClose;
    this._sendSignal =
      sendSignal ??
      ((child, signal) => {
        if (this._platform !== 'win32' && Number.isInteger(child.pid)) {
          this._processObject.kill(-child.pid, signal);
        } else {
          child.kill(signal);
        }
      });
    this._active = new Set();
    this._abortError = null;
    this._terminationTimer = null;
    this._signalErrors = [];
    this._hookErrors = [];
    this._signalHandlers = new Map();
  }

  get activeCount() {
    return this._active.size;
  }

  get childrenDrained() {
    return this._active.size === 0;
  }

  get abortSignal() {
    return this._abortError?.signal ?? null;
  }

  get abortExitCode() {
    return this._abortError?.exitCode ?? null;
  }

  installSignalHandlers() {
    if (this._signalHandlers.size > 0) return;
    for (const signal of handledSignals) {
      const handler = () => this.requestAbort(signal);
      this._signalHandlers.set(signal, handler);
      this._processObject.on(signal, handler);
    }
  }

  disposeSignalHandlers() {
    for (const [signal, handler] of this._signalHandlers) {
      this._processObject.removeListener(signal, handler);
    }
    this._signalHandlers.clear();
  }

  throwIfAborted() {
    if (this._hookErrors.length > 0) {
      throw new AggregateError(
        [...this._hookErrors],
        'Android attestation child lifecycle hook failed',
      );
    }
    if (this._abortError != null) throw this._abortError;
  }

  async launch(command, args, options = {}) {
    const {
      allowDuringAbort = false,
      executionBarrier = false,
      onSpawn,
      ...spawnOptions
    } = options;
    if (typeof allowDuringAbort !== 'boolean') {
      throw new TypeError('allowDuringAbort must be a boolean');
    }
    if (!allowDuringAbort) {
      this.throwIfAborted();
    } else if (this._hookErrors.length > 0) {
      throw new AggregateError(
        [...this._hookErrors],
        'Android attestation child lifecycle hook failed',
      );
    }
    if (onSpawn != null && typeof onSpawn !== 'function') {
      throw new TypeError('onSpawn must be a function');
    }
    if (typeof executionBarrier !== 'boolean') {
      throw new TypeError('executionBarrier must be a boolean');
    }
    if (executionBarrier && this._platform === 'win32') {
      throw new Error('executionBarrier requires a POSIX host');
    }
    if (spawnOptions.detached == null && this._platform !== 'win32') {
      spawnOptions.detached = true;
    }
    let launchedCommand = command;
    let launchedArgs = args;
    if (executionBarrier) {
      if (
        !Array.isArray(spawnOptions.stdio) ||
        spawnOptions.stdio.length !== 3
      ) {
        throw new TypeError(
          'executionBarrier requires an explicit three-entry stdio array',
        );
      }
      launchedCommand = process.execPath;
      launchedArgs = [commandBarrierPath];
      spawnOptions.stdio = [...spawnOptions.stdio, 'ipc'];
    }
    const child = this._spawnProcess(
      launchedCommand,
      launchedArgs,
      spawnOptions,
    );
    onSpawn?.(child);
    const record = {
      child,
      command,
      args: [...args],
      pid: child.pid ?? null,
      spawnError: null,
      closed: false,
      allowDuringAbort,
      executionBarrier,
      barrierReleased: false,
      completion: null,
    };
    record.completion = new Promise((resolve, reject) => {
      child.once('error', (error) => {
        record.spawnError = error;
      });
      child.once('close', (code, signal) => {
        record.closed = true;
        Promise.resolve(this._onChildClose(record))
          .catch((error) => {
            this._hookErrors.push(error);
            throw error;
          })
          .then(
            () => resolve({ code, signal, spawnError: record.spawnError }),
            reject,
          )
          .finally(() => {
            this._active.delete(record);
            if (this._active.size === 0) this._clearTerminationTimer();
          });
      });
    });
    this._active.add(record);
    try {
      await this._onChildStart(record);
      if (
        executionBarrier &&
        (this._abortError == null || allowDuringAbort)
      ) {
        await this._releaseExecutionBarrier(record);
      }
    } catch (error) {
      this._hookErrors.push(error);
      this.requestAbort('SIGTERM');
      await Promise.allSettled([record.completion]);
      throw error;
    }
    if (this._abortError != null) {
      if (allowDuringAbort) this._ensureTerminationTimer();
      else this._signalChildren('SIGTERM');
    }
    return record;
  }

  requestAbort(signal = 'SIGTERM') {
    if (!handledSignals.includes(signal)) {
      throw new TypeError(`unsupported shutdown signal: ${signal}`);
    }
    if (this._abortError == null) {
      this._abortError = new AttestationAbortError(signal);
      this._signalChildren('SIGTERM', { preserveAbortCleanup: true });
      this._ensureTerminationTimer();
      return;
    }
    this._signalChildren('SIGKILL');
  }

  async drain() {
    while (this._active.size > 0) {
      const completions = [...this._active].map((record) => record.completion);
      await Promise.allSettled(completions);
    }
    this._clearTerminationTimer();
    if (this._hookErrors.length > 0 || this._signalErrors.length > 0) {
      throw new AggregateError(
        [...this._hookErrors, ...this._signalErrors],
        'Android attestation child supervision failed',
      );
    }
  }

  _signalChildren(signal, { preserveAbortCleanup = false } = {}) {
    for (const record of this._active) {
      if (record.closed) continue;
      if (preserveAbortCleanup && record.allowDuringAbort) continue;
      try {
        this._sendSignal(record.child, signal, record);
      } catch (error) {
        if (error?.code !== 'ESRCH') this._signalErrors.push(error);
      }
    }
  }

  async _releaseExecutionBarrier(record) {
    if (record.closed || record.child.connected !== true) {
      throw new Error(
        `Android attestation command barrier closed before release: ${record.command}`,
      );
    }
    await new Promise((resolve, reject) => {
      record.child.send(
        {
          schema: commandReleaseSchema,
          command: record.command,
          args: record.args,
        },
        (error) => {
          if (error != null) reject(error);
          else resolve();
        },
      );
    });
    record.barrierReleased = true;
  }

  _ensureTerminationTimer() {
    if (this._active.size === 0 || this._terminationTimer != null) return;
    this._terminationTimer = setTimeout(() => {
      this._terminationTimer = null;
      this._signalChildren('SIGKILL');
    }, this._terminationGraceMs);
    this._terminationTimer.unref?.();
  }

  _clearTerminationTimer() {
    if (this._terminationTimer != null) {
      clearTimeout(this._terminationTimer);
      this._terminationTimer = null;
    }
  }
}

export function signalExitCode(signal) {
  return signalExitCodes[signal] ?? 1;
}
