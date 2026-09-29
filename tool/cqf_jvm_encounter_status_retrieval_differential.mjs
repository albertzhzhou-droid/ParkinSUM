import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { assertCqfJvmLockfile } from './cqf_jvm_cql_differential.mjs';
import {
  encounterStatusOutcomeKeys,
  fixedEncounterStatusCorpus,
  scopeEncounterStatusBundle,
  validateEncounterStatusCorpus,
} from './cql_fhir_encounter_retrieval_contract.mjs';

const RESULT_PREFIX = 'PARKINSUM_CQF_JVM_ENCOUNTER_STATUS_RESULT';
const EXPECTED_CASE_IDS = fixedEncounterStatusCorpus.cases.map(({ id }) => id);
const encode = (value) => Buffer.from(value, 'utf8').toString('base64');

function decode(value, label) {
  if (typeof value !== 'string' || value.length === 0 || !/^[A-Za-z0-9+/]*={0,2}$/.test(value)) {
    throw new Error(`${label} is not canonical base64`);
  }
  const decoded = Buffer.from(value, 'base64').toString('utf8');
  if (encode(decoded) !== value) throw new Error(`${label} is not canonical UTF-8 base64`);
  return decoded;
}

export function encodeCqfJvmEncounterStatusCases(value) {
  validateEncounterStatusCorpus(value);
  return value.cases.map((testCase) => {
    const resources = testCase.bundle.entry.map(({ resource }) => resource);
    const patients = resources.filter(({ resourceType }) => resourceType === 'Patient');
    const encounters = resources.filter(({ resourceType }) => resourceType === 'Encounter');
    if (patients.length !== 1 || encounters.length > 1) {
      throw new Error('CQF JVM Encounter status input exceeds fixed resource bounds');
    }
    return [
      encode(testCase.id),
      encode(testCase.patientContextId),
      encode(JSON.stringify(patients[0])),
      encounters.length === 0 ? '-' : encode(JSON.stringify(encounters[0])),
    ].join('\t') + '\n';
  }).join('');
}

export function parseCqfJvmEncounterStatusOutput(stdout) {
  const rows = new Map();
  for (const line of String(stdout).split(/\r?\n/)) {
    if (!line.startsWith(`${RESULT_PREFIX}\t`)) continue;
    const fields = line.split('\t');
    if (fields.length !== 3 + encounterStatusOutcomeKeys.length || fields[0] !== RESULT_PREFIX) {
      throw new Error('CQF JVM Encounter status output does not match fixed protocol');
    }
    const id = decode(fields[1], 'CQF JVM Encounter status case ID');
    if (!EXPECTED_CASE_IDS.includes(id) || rows.has(id)) {
      throw new Error(`CQF JVM Encounter status output has unexpected or duplicate case: ${id}`);
    }
    if (!/^(0|1)$/.test(fields[2])) {
      throw new Error(`CQF JVM Encounter status foreign-subject count is invalid for ${id}`);
    }
    const outcomes = {};
    for (const [index, name] of encounterStatusOutcomeKeys.entries()) {
      if (!['true', 'false'].includes(fields[index + 3])) {
        throw new Error(`CQF JVM Encounter status outcome is invalid for ${id}`);
      }
      outcomes[name] = fields[index + 3] === 'true';
    }
    rows.set(id, { id, foreignEncountersDropped: Number(fields[2]), outcomes });
  }
  if (rows.size !== EXPECTED_CASE_IDS.length || EXPECTED_CASE_IDS.some((id) => !rows.has(id))) {
    throw new Error(`CQF JVM Encounter status returned ${rows.size} rows for ${EXPECTED_CASE_IDS.length} fixed cases`);
  }
  return rows;
}

export function runCqfJvmEncounterStatusDifferential(root, value, javaScriptReport) {
  validateEncounterStatusCorpus(value);
  const fixtureSha256 = createFixtureSha256(root);
  if (!javaScriptReport || javaScriptReport.schemaVersion !== 1 ||
      !Array.isArray(javaScriptReport.cases) || javaScriptReport.fixtureSha256 !== fixtureSha256) {
    throw new Error('CQF JVM comparison requires the pinned JavaScript Encounter status report and fixture digest');
  }
  const jsById = new Map(javaScriptReport.cases.map((row) => [row.id, row]));
  if (jsById.size !== EXPECTED_CASE_IDS.length || EXPECTED_CASE_IDS.some((id) => !jsById.has(id))) {
    throw new Error('JavaScript Encounter status report differs from fixed cases');
  }
  const projectPath = resolve(root, 'tool/cqf_jvm_cql_differential');
  assertCqfJvmLockfile(readFileSync(resolve(projectPath, 'gradle.lockfile'), 'utf8'));
  const wrapper = process.env.PARKINSUM_CQF_JVM_GRADLE_BIN ||
    resolve(root, 'android', process.platform === 'win32' ? 'gradlew.bat' : 'gradlew');
  const result = spawnSync(wrapper, ['--no-daemon', '--offline', '-p', projectPath, '--quiet', 'fhirEncounterStatusRun'], {
    cwd: root,
    encoding: 'utf8',
    input: encodeCqfJvmEncounterStatusCases(value),
    maxBuffer: 4 * 1024 * 1024,
    shell: process.platform === 'win32',
    timeout: 300000,
    env: { ...process.env, JAVA_HOME: process.env.JAVA_HOME || '/Applications/Android Studio.app/Contents/jbr/Contents/Home' },
  });
  if (result.error?.code === 'ENOENT') throw new Error('The Android Gradle wrapper is required for the CQF JVM Encounter status check.');
  if (result.error?.code === 'ETIMEDOUT') throw new Error('The CQF JVM Encounter status Gradle run exceeded five minutes.');
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`CQF JVM Encounter status differential failed (${result.status}):\n${result.stderr || result.stdout}`);
  const rows = parseCqfJvmEncounterStatusOutput(result.stdout);
  const cases = value.cases.map((testCase) => {
    const jvm = rows.get(testCase.id);
    const js = jsById.get(testCase.id);
    const scoped = scopeEncounterStatusBundle(testCase.bundle, testCase.patientContextId);
    if (JSON.stringify(jvm.outcomes) !== JSON.stringify(testCase.expectedOutcomes) ||
        JSON.stringify(js.outcomes) !== JSON.stringify(testCase.expectedOutcomes) ||
        jvm.foreignEncountersDropped !== scoped.foreignEncountersDropped ||
        js.foreignEncountersDropped !== scoped.foreignEncountersDropped) {
      throw new Error(`Encounter status retrieval or Patient scope differs from fixed expectations for ${testCase.id}`);
    }
    return {
      id: testCase.id,
      expectedOutcomes: testCase.expectedOutcomes,
      javaScriptOutcomes: js.outcomes,
      cqfJvmOutcomes: jvm.outcomes,
      outcomeMatched: JSON.stringify(js.outcomes) === JSON.stringify(jvm.outcomes),
      foreignEncountersDropped: {
        javaScript: js.foreignEncountersDropped,
        cqfJvm: jvm.foreignEncountersDropped,
      },
    };
  });
  const report = {
    schemaVersion: 1,
    scope: 'synthetic-fhir-r4-encounter-status-retrieval-javascript-jvm-differential',
    fhirVersion: value.fhirVersion,
    context: value.context,
    engine: 'org.cqframework:engine@5.3.0',
    fhirArtifact: 'org.cqframework:engine-fhir@5.3.0',
    modelInfoArtifact: 'org.cqframework:quick@5.3.0',
    cqlSourceSha256: javaScriptReport.cqlSourceSha256,
    fixtureSha256,
    caseCount: cases.length,
    outcomeParityCount: cases.filter(({ outcomeMatched }) => outcomeMatched).length,
    cases,
    networkRequestMade: false,
    realPatientDataUsed: false,
  };
  if (/synthetic-patient-|synthetic-encounter-/i.test(JSON.stringify(report))) {
    throw new Error('CQF JVM Encounter status report contains fixture identifiers outside its bounded projection');
  }
  return report;
}

function createFixtureSha256(root) {
  return createHash('sha256').update(readFileSync(resolve(
    root,
    'test/fixtures/cql_fhir_r4_encounter_status_retrieval_corpus.json',
  ))).digest('hex');
}

export { EXPECTED_CASE_IDS as fixedEncounterStatusCaseIds };

if (process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url))) {
  const root = resolve('.');
  const { runEncounterStatusRetrievalDifferential } = await import('./cql_fhir_encounter_retrieval.mjs');
  const javaScriptReport = await runEncounterStatusRetrievalDifferential();
  const report = runCqfJvmEncounterStatusDifferential(root, fixedEncounterStatusCorpus, javaScriptReport);
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
}
