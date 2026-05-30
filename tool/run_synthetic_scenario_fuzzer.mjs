#!/usr/bin/env node
// Thin wrapper so `npm run scenario:fuzz` invokes the Dart fuzzer.
// Deterministic synthetic regression/stress testing; not medical advice.
// Extra args are forwarded (e.g. --seed=2 --family=source_quality).

import { spawnSync } from 'node:child_process';

const result = spawnSync(
  'dart',
  ['run', 'tool/run_synthetic_scenario_fuzzer.dart', ...process.argv.slice(2)],
  { stdio: 'inherit' },
);

process.exit(result.status ?? 1);
