#!/usr/bin/env node
// Thin wrapper so `npm run privacy:preflight` invokes the Dart scanner.
// Stricter repo-hygiene / privacy-risk preflight that COMPLEMENTS
// `npm run public:preflight` (it does not replace it). Not HIPAA/GDPR/PIPEDA
// compliance, not a legal certification, not clinical validation, and does not
// prove the app is secure. Extra args are forwarded (e.g. --strict).

import { spawnSync } from 'node:child_process';

const result = spawnSync(
  'dart',
  ['run', 'tool/run_local_privacy_preflight.dart', ...process.argv.slice(2)],
  { stdio: 'inherit' },
);

process.exit(result.status ?? 1);
