#!/usr/bin/env node
// Thin wrapper so `npm run catalog:inventory` invokes the Dart generator.
// Deterministic transparency report over the shipped seeds and registries.
// No network, no timestamps. Extra args are forwarded.

import { spawnSync } from 'node:child_process';

const result = spawnSync(
  'dart',
  ['run', 'tool/run_catalog_inventory.dart', ...process.argv.slice(2)],
  { stdio: 'inherit' },
);

process.exit(result.status ?? 1);
