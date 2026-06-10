#!/usr/bin/env node
// Thin wrapper so `npm run recommend:replay` invokes the Dart runner.
// Synthetic inputs only; offline scripted Local AI; not medical advice.

import { spawnSync } from 'node:child_process';

const result = spawnSync(
  'dart',
  ['run', 'tool/run_recommendation_scenario_replay.dart'],
  { stdio: 'inherit' },
);

process.exit(result.status ?? 1);
