#!/usr/bin/env node
// Thin wrapper so `npm run localization:lint` invokes the Dart lint.
// Safety/governance lint over copy + localization surfaces; not medical advice.
// Extra args are forwarded (e.g. --strict).

import { spawnSync } from 'node:child_process';

const result = spawnSync(
  'dart',
  ['run', 'tool/run_localization_safety_lint.dart', ...process.argv.slice(2)],
  { stdio: 'inherit' },
);

process.exit(result.status ?? 1);
