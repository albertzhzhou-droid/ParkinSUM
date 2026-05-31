#!/usr/bin/env node
// Thin wrapper so `npm run input:quality` invokes the Dart demo.
// Runs the InputQualityGate over deterministic synthetic cases. Input/context-
// completeness assessment only; not medical advice, not a recommendation
// engine, and not clinically calibrated. Extra args are forwarded.

import { spawnSync } from 'node:child_process';

const result = spawnSync(
  'dart',
  ['run', 'tool/run_input_quality_demo.dart', ...process.argv.slice(2)],
  { stdio: 'inherit' },
);

process.exit(result.status ?? 1);
