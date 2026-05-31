#!/usr/bin/env node
// Thin wrapper so `npm run source:drift` invokes the Dart checker.
// Provenance / release-hygiene drift checking over local files and build
// artifacts. No network. Not legal/license clearance, not clinical validation,
// not clinically calibrated, and does not prove medical correctness. Extra args
// are forwarded (e.g. --strict, --now=ISO, --staleness-days=N).

import { spawnSync } from 'node:child_process';

const result = spawnSync(
  'dart',
  ['run', 'tool/run_source_version_drift_check.dart', ...process.argv.slice(2)],
  { stdio: 'inherit' },
);

process.exit(result.status ?? 1);
