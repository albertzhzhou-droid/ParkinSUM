#!/usr/bin/env node
// Thin wrapper so `npm run release:snapshot` invokes the Dart generator.
// Composes existing synthetic verification artifacts; not medical advice.
// Extra args are forwarded (e.g. --analyze=clean --test-count=460 --firestore=13/13).

import { spawnSync } from 'node:child_process';

const result = spawnSync(
  'dart',
  ['run', 'tool/run_release_snapshot.dart', ...process.argv.slice(2)],
  { stdio: 'inherit' },
);

process.exit(result.status ?? 1);
