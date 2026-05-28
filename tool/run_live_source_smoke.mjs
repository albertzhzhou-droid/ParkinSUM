#!/usr/bin/env node
// Thin wrapper so `npm run live:smoke` invokes the Dart live-source smoke.
// Opt-in only; without PARKINSUM_ENABLE_LIVE_SOURCE_SMOKE=1 it safely skips.
// Never fetches clinical advice; never stores raw payloads.

import { spawnSync } from 'node:child_process';

const result = spawnSync(
  'dart',
  ['run', 'tool/run_live_source_smoke.dart', ...process.argv.slice(2)],
  { stdio: 'inherit' },
);

process.exit(result.status ?? 1);
