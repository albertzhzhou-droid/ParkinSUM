#!/usr/bin/env node
// Thin wrapper so `npm run copy:compile` invokes the Dart compiler.
// Deterministic copy compilation + validation over the SafeCopyTemplate
// registry. No medical advice, no clinical-calibration claim, not wired into the
// UI or scoring. Extra args are forwarded.

import { spawnSync } from 'node:child_process';

const result = spawnSync(
  'dart',
  ['run', 'tool/run_explanation_copy_compile.dart', ...process.argv.slice(2)],
  { stdio: 'inherit' },
);

process.exit(result.status ?? 1);
