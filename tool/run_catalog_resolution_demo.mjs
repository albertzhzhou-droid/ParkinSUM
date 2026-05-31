#!/usr/bin/env node
// Thin wrapper so `npm run catalog:resolve` invokes the Dart demo.
// Runs the CatalogResolutionEngine over fixed synthetic queries. Returns
// candidates + uncertainty; not a recommendation engine, infers no user dose,
// and does not silently guess. Extra args are forwarded.

import { spawnSync } from 'node:child_process';

const result = spawnSync(
  'dart',
  ['run', 'tool/run_catalog_resolution_demo.dart', ...process.argv.slice(2)],
  { stdio: 'inherit' },
);

process.exit(result.status ?? 1);
