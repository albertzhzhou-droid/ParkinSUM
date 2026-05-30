#!/usr/bin/env node
// Thin wrapper so `npm run evidence:graph` invokes the Dart generator.
// Composes existing synthetic artifacts into a local evidence graph; not medical advice.

import { spawnSync } from 'node:child_process';

const result = spawnSync(
  'dart',
  ['run', 'tool/generate_evidence_graph.dart'],
  { stdio: 'inherit' },
);

process.exit(result.status ?? 1);
