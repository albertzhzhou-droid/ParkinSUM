#!/usr/bin/env node
// Thin npm wrapper for the deterministic, no-network source-access checker.

import { spawnSync } from 'node:child_process';

const result = spawnSync(
  'dart',
  ['run', 'tool/run_source_access_contract_check.dart', ...process.argv.slice(2)],
  { stdio: 'inherit' },
);

process.exit(result.status ?? 1);
