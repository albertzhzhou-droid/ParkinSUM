#!/usr/bin/env node
// Thin wrapper so `npm run mechanistic:replay` invokes the Dart runner.
// Synthetic inputs only. Not medical advice.

import { spawnSync } from 'node:child_process';

const result = spawnSync('dart', ['run', 'tool/run_mechanistic_replay.dart'], {
  stdio: 'inherit',
});

process.exit(result.status ?? 1);
