#!/usr/bin/env node
// Thin wrapper so `npm run source:quality` invokes the Dart report runner.
// Synthetic inputs only. Deterministic educational analysis; not medical advice.

import { spawnSync } from 'node:child_process';

const result = spawnSync(
  'dart',
  ['run', 'tool/run_source_quality_perturbation_report.dart'],
  { stdio: 'inherit' },
);

process.exit(result.status ?? 1);
