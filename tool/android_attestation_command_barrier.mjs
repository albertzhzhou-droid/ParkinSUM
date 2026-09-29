#!/usr/bin/env node

import { spawn } from 'node:child_process';
import process from 'node:process';

const releaseSchema = 'parkinsum.android-attestation-command-release/1';
const signalExitCodes = Object.freeze({
  SIGHUP: 129,
  SIGINT: 130,
  SIGTERM: 143,
});

let target = null;
let released = false;
let pendingSignal = null;

function disconnectIpc() {
  if (process.connected) process.disconnect();
}

function finishWithoutTarget(signal) {
  process.exitCode = signalExitCodes[signal] ?? 1;
  disconnectIpc();
}

for (const signal of Object.keys(signalExitCodes)) {
  process.on(signal, () => {
    pendingSignal ??= signal;
    if (target == null) {
      finishWithoutTarget(signal);
      return;
    }
    try {
      target.kill(signal);
    } catch (error) {
      if (error?.code !== 'ESRCH') throw error;
    }
  });
}

process.once('disconnect', () => {
  if (!released && target == null) finishWithoutTarget('SIGTERM');
});

process.once('message', (message) => {
  if (
    released ||
    message?.schema !== releaseSchema ||
    typeof message.command !== 'string' ||
    message.command.length === 0 ||
    !Array.isArray(message.args) ||
    message.args.some((value) => typeof value !== 'string')
  ) {
    process.stderr.write('Invalid Android attestation command release\n');
    process.exitCode = 70;
    disconnectIpc();
    return;
  }
  released = true;
  if (pendingSignal != null) {
    finishWithoutTarget(pendingSignal);
    return;
  }
  target = spawn(message.command, message.args, {
    cwd: process.cwd(),
    env: process.env,
    detached: false,
    stdio: ['ignore', 'inherit', 'inherit'],
  });
  let spawnError = null;
  target.once('error', (error) => {
    spawnError = error;
    process.stderr.write(`${error.stack ?? error.message}\n`);
  });
  target.once('close', (code, signal) => {
    target = null;
    if (spawnError != null) process.exitCode = 71;
    else if (signal != null) process.exitCode = signalExitCodes[signal] ?? 1;
    else process.exitCode = code ?? 1;
    disconnectIpc();
  });
  disconnectIpc();
});
