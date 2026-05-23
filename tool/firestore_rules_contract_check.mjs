#!/usr/bin/env node
import fs from 'node:fs';

const rulesPath = process.argv[2] ?? 'firestore.rules';
const rules = fs.readFileSync(rulesPath, 'utf8');

const checks = [
  {
    name: 'signed-in helper exists',
    pass: /function\s+signedIn\(\)\s*\{\s*return\s+request\.auth\s*!=\s*null;\s*\}/s.test(rules),
  },
  {
    name: 'owner helper binds request.auth.uid to uid',
    pass: /function\s+isOwner\(uid\)\s*\{\s*return\s+signedIn\(\)\s*&&\s*request\.auth\.uid\s*==\s*uid;\s*\}/s.test(rules),
  },
  {
    name: 'admin/importer helper recognizes custom claims',
    pass:
      /request\.auth\.token\.admin\s*==\s*true/.test(rules) &&
      /request\.auth\.token\.cdssImporter\s*==\s*true/.test(rules),
  },
  {
    name: 'users/{uid} subtree is owner-only',
    pass:
      /match\s+\/users\/\{uid\}\/\{document=\*\*\}\s*\{\s*allow\s+read,\s*write:\s*if\s+isOwner\(uid\);/s.test(rules),
  },
  {
    name: 'user-scoped cdss_tables are owner-only',
    pass:
      /match\s+\/users\/\{uid\}\/cdss_tables\/\{table\}\/rows\/\{rowId\}\s*\{\s*allow\s+read,\s*write:\s*if\s+isOwner\(uid\);/s.test(rules),
  },
  {
    name: 'app_catalog read requires signed-in user',
    pass:
      /match\s+\/app_catalog\/\{table\}\/rows\/\{rowId\}\s*\{\s*allow\s+read:\s*if\s+signedIn\(\);/s.test(rules),
  },
  {
    name: 'app_catalog write requires admin/importer',
    pass:
      /match\s+\/app_catalog\/\{table\}\/rows\/\{rowId\}[\s\S]*allow\s+write:\s*if\s+isAdminOrImporter\(\);/s.test(rules),
  },
  {
    name: 'top-level cdss_tables are closed',
    pass:
      /match\s+\/cdss_tables\/\{table\}\/rows\/\{rowId\}\s*\{\s*allow\s+read,\s*write:\s*if\s+false;/s.test(rules),
  },
  {
    name: 'fallback deny-all exists',
    pass:
      /match\s+\/\{document=\*\*\}\s*\{\s*allow\s+read,\s*write:\s*if\s+false;/s.test(rules),
  },
  {
    name: 'no blanket allow-all rule',
    pass: !/allow\s+read,\s*write:\s*if\s+true\s*;/.test(rules),
  },
];

let failed = 0;
for (const check of checks) {
  if (check.pass) {
    console.log(`PASS ${check.name}`);
  } else {
    failed += 1;
    console.error(`FAIL ${check.name}`);
  }
}

if (failed > 0) {
  console.error(`Firestore rules contract failed: ${failed}/${checks.length}`);
  process.exit(1);
}

console.log(`Firestore rules contract passed: ${checks.length}/${checks.length}`);
