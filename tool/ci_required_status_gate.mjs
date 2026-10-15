import {fileURLToPath} from 'node:url';
import {resolve} from 'node:path';

export const REQUIRED_JOB_IDS = Object.freeze([
  'quick-checks', 'flutter', 'node-preflight', 'governance-gates',
]);

export function inspectRequiredJobResults(needs) {
  const errors = [];
  if (needs === null || typeof needs !== 'object' || Array.isArray(needs)) {
    return {pass: false, errors: ['Expected the complete needs object.']};
  }
  const keys = Object.keys(needs);
  for (const id of keys) {
    if (!REQUIRED_JOB_IDS.includes(id)) errors.push(`Undeclared prerequisite: ${id}`);
  }
  for (const id of REQUIRED_JOB_IDS) {
    const job = Object.hasOwn(needs, id) ? needs[id] : null;
    if (job === null || typeof job !== 'object' || Array.isArray(job)) {
      errors.push(`Missing or invalid prerequisite: ${id}`);
    } else if (job.result !== 'success') {
      errors.push(`Prerequisite did not succeed: ${id} (${String(job.result)})`);
    }
  }
  return {pass: errors.length === 0, errors};
}

export function main(environment = process.env) {
  const raw = environment.PARKINSUM_CI_JOB_RESULTS;
  if (typeof raw !== 'string' || raw.length === 0 || raw.length > 1024 * 1024) {
    console.error('Required CI prerequisite results are missing or over budget.');
    return 1;
  }
  let needs;
  try {
    needs = JSON.parse(raw);
  } catch {
    console.error('Required CI prerequisite results are invalid JSON.');
    return 1;
  }
  const result = inspectRequiredJobResults(needs);
  if (!result.pass) {
    result.errors.forEach(error => console.error(error));
    return 1;
  }
  console.log(`All ${REQUIRED_JOB_IDS.length} required CI prerequisites succeeded.`);
  return 0;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = main();
}
