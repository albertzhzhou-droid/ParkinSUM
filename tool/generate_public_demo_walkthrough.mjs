#!/usr/bin/env node
// Thin wrapper so `npm run demo:walkthrough` invokes the Dart generator.
// Composes existing synthetic artifacts into a reviewer walkthrough; not medical advice.

import { spawnSync } from 'node:child_process';

const result = spawnSync(
  'dart',
  ['run', 'tool/generate_public_demo_walkthrough.dart'],
  { stdio: 'inherit' },
);

process.exit(result.status ?? 1);
