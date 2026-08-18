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
    name: 'no blanket owner write on users/{uid} subtree',
    pass:
      !/match\s+\/users\/\{uid\}\/\{document=\*\*\}/s.test(rules) &&
      !/allow\s+read,\s*write:\s*if\s+isOwner\(uid\);/s.test(rules),
  },
  {
    name: 'profile writes bind patientId to auth uid',
    pass:
      /function\s+validProfile\(uid\)[\s\S]*request\.resource\.data\.patientId\s*==\s*uid/s.test(rules),
  },
  {
    name: 'runtime patient collections use explicit validators',
    pass:
      /match\s+\/profile\/\{profileId\}[\s\S]*validProfile\(uid\)/s.test(rules) &&
      /match\s+\/meals\/\{mealId\}[\s\S]*validMeal\(mealId\)/s.test(rules) &&
      /match\s+\/intakes\/\{intakeId\}[\s\S]*validIntake\(intakeId\)/s.test(rules) &&
      /match\s+\/active_drugs\/\{drugId\}[\s\S]*validActiveDrug\(drugId\)/s.test(rules),
  },
  {
    name: 'onboarding completion metadata is owner-bound and terminal',
    pass:
      /function\s+validAppMeta\(uid,\s*key\)[\s\S]*request\.resource\.data\.stage\s*==\s*'committed'/s.test(rules) &&
      /request\.resource\.data\.schema_version\s*==\s*1/.test(rules) &&
      /request\.resource\.data\.owner_uid\s*==\s*uid/.test(rules) &&
      /request\.resource\.data\.purpose\s*==\s*'atomic_onboarding_commit'/.test(rules),
  },
  {
    name: 'structured intake fields are bounded by an explicit nested schema',
    pass:
      /function\s+validIntake\(intakeId\)[\s\S]*'doseAmount'[\s\S]*'productSelection'/s.test(rules) &&
      /function\s+validMedicationProductSelection\(value\)[\s\S]*value\.keys\(\)\.hasOnly/s.test(rules) &&
      /request\.resource\.data\.doseAmount\s*>\s*0/.test(rules) &&
      /validMedicationProductSelection\(request\.resource\.data\.productSelection\)/.test(rules),
  },
  {
    name: 'clinical audits are create-only and uid-bound',
    pass:
      /function\s+validClinicalAudit\(uid,\s*auditId\)[\s\S]*request\.resource\.data\.patient_id\s*==\s*uid/s.test(rules) &&
      /match\s+\/clinical_audits\/\{auditId\}[\s\S]*allow\s+create:\s*if\s+isOwner\(uid\)\s*&&\s*validClinicalAudit\(uid,\s*auditId\);[\s\S]*allow\s+update,\s*delete:\s*if\s+false;/s.test(rules),
  },
  {
    name: 'record history is owner-bound, schema-checked, and append-only',
    pass:
      /function\s+validRecordHistory\(historyId\)[\s\S]*request\.resource\.data\.schema_version\s*==\s*1/s.test(rules) &&
      /request\.resource\.data\.created_at\s*==\s*request\.time/.test(rules) &&
      /match\s+\/record_history\/\{historyId\}[\s\S]*allow\s+create:\s*if\s+isOwner\(uid\)\s*&&\s*validRecordHistory\(historyId\);[\s\S]*allow\s+update,\s*delete:\s*if\s+false;/s.test(rules),
  },
  {
    name: 'user-scoped cdss_tables are owner-read-only',
    pass:
      /match\s+\/cdss_tables\/\{table\}\/rows\/\{rowId\}\s*\{\s*allow\s+read:\s*if\s+isOwner\(uid\)\s*&&\s*safeId\(table\)\s*&&\s*safeId\(rowId\);\s*allow\s+write:\s*if\s+false;/s.test(rules),
  },
  {
    name: 'app_catalog read requires signed-in user',
    pass:
      /match\s+\/app_catalog\/\{table\}\/rows\/\{rowId\}\s*\{\s*allow\s+read:\s*if\s+signedIn\(\);/s.test(rules),
  },
  {
    name: 'app_catalog write requires admin/importer and schema gate',
    pass:
      /match\s+\/app_catalog\/\{table\}\/rows\/\{rowId\}[\s\S]*allow\s+write:\s*if\s+isAdminOrImporter\(\)\s*&&\s*validAppCatalogWrite\(table,\s*rowId\);/s.test(rules),
  },
  {
    name: 'app_catalog schema gate uses per-table allowlists',
    pass:
      /table\s*==\s*'foods'\s*&&\s*validFoodCatalogRow\(rowId\)/.test(rules) &&
      /table\s*==\s*'medications'\s*&&\s*validMedicationCatalogRow\(rowId\)/.test(rules) &&
      /table\s*==\s*'interaction_rules'\s*&&\s*validInteractionRuleCatalogRow\(rowId\)/.test(rules) &&
      /function\s+validLiveProbeCatalogRow\(\)[\s\S]*keys\(\)\.hasOnly\(\['probe'\]\)/s.test(rules),
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
