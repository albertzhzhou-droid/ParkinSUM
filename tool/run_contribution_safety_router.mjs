#!/usr/bin/env node
// Thin wrapper so `npm run contribution:route` invokes the Dart router.
// Deterministic repository-governance helper: classifies diff risk, suggests
// labels, and generates a reviewer checklist. NOT AI code review, NOT a
// medical/legal reviewer, and does NOT replace human review. Extra args are
// forwarded (e.g. --base <ref> --head <ref> --strict).

import { spawnSync } from 'node:child_process';

const result = spawnSync(
  'dart',
  ['run', 'tool/run_contribution_safety_router.dart', ...process.argv.slice(2)],
  { stdio: 'inherit' },
);

process.exit(result.status ?? 1);
