#!/usr/bin/env node
// Thin wrapper so `npm run recommend:replay` invokes the Dart runner.
// Synthetic inputs only; offline scripted Local AI; not medical advice.

import { spawnSync } from 'node:child_process';

const result = spawnSync(
  'dart',
  ['run', 'tool/run_recommendation_scenario_replay.dart'],
  { stdio: 'inherit' },
);

if (result.status !== 0) process.exit(result.status ?? 1);
const reviewTests = spawnSync('node', ['--test', 'tool/food_source_sensitivity_review.test.mjs'], {stdio: 'inherit'});
if (reviewTests.status !== 0) process.exit(reviewTests.status ?? 1);
const sensitivity = spawnSync('node', ['tool/run_food_source_sensitivity_check.mjs'], {stdio: 'inherit'});
process.exit(sensitivity.status ?? 1);
