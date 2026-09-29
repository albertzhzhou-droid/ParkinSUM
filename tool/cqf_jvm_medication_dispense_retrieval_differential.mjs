import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';

import { assertCqfJvmLockfile } from './cqf_jvm_cql_differential.mjs';
import {
  fixedMedicationDispenseCorpus,
  medicationDispenseOutcomeKeys,
  scopeMedicationDispenseBundle,
  validateMedicationDispenseCorpus,
} from './cql_fhir_medication_dispense_retrieval_contract.mjs';

const RESULT_PREFIX = 'PARKINSUM_CQF_JVM_MEDICATION_DISPENSE_RESULT';
const EXPECTED_CASE_IDS = fixedMedicationDispenseCorpus.cases.map((testCase) => testCase.id);

function encode(value) {
  return Buffer.from(value, 'utf8').toString('base64');
}

function decode(value, label) {
  if (typeof value !== 'string' || value.length === 0 || !/^[A-Za-z0-9+/]*={0,2}$/.test(value)) {
    throw new Error(`${label} is not canonical base64`);
  }
  const decoded = Buffer.from(value, 'base64').toString('utf8');
  if (encode(decoded) !== value) throw new Error(`${label} is not canonical UTF-8 base64`);
  return decoded;
}

export function encodeCqfJvmMedicationDispenseCases(value) {
  validateMedicationDispenseCorpus(value);
  return value.cases.map((testCase) => {
    const resources = testCase.bundle.entry.map((entry) => entry.resource);
    const patients = resources.filter((resource) => resource.resourceType === 'Patient');
    const dispenses = resources.filter((resource) => resource.resourceType === 'MedicationDispense');
    if (patients.length !== 1 || dispenses.length > 1) {
      throw new Error('CQF JVM MedicationDispense input is outside the fixed one-Patient, optional-dispense contract');
    }
    return [
      encode(testCase.id),
      encode(testCase.patientContextId),
      encode(JSON.stringify(patients[0])),
      dispenses.length === 0 ? '-' : encode(JSON.stringify(dispenses[0])),
    ].join('\t') + '\n';
  }).join('');
}

export function parseCqfJvmMedicationDispenseOutput(stdout) {
  const rows = new Map();
  for (const line of String(stdout).split(/\r?\n/)) {
    if (!line.startsWith(`${RESULT_PREFIX}\t`)) continue;
    const fields = line.split('\t');
    if (fields.length !== 3 + medicationDispenseOutcomeKeys.length || fields[0] !== RESULT_PREFIX) {
      throw new Error('CQF JVM MedicationDispense output row does not match the fixed protocol');
    }
    const id = decode(fields[1], 'CQF JVM MedicationDispense case ID');
    if (!EXPECTED_CASE_IDS.includes(id) || rows.has(id)) {
      throw new Error(`CQF JVM MedicationDispense output has an unexpected or duplicate case: ${id}`);
    }
    if (!/^(0|1)$/.test(fields[2])) {
      throw new Error(`CQF JVM MedicationDispense foreign-subject count is invalid for ${id}`);
    }
    const outcomes = {};
    for (const [index, name] of medicationDispenseOutcomeKeys.entries()) {
      if (!['true', 'false'].includes(fields[index + 3])) {
        throw new Error(`CQF JVM MedicationDispense output contains an invalid outcome for ${id}`);
      }
      outcomes[name] = fields[index + 3] === 'true';
    }
    rows.set(id, {
      id,
      foreignDispensesDropped: Number(fields[2]),
      outcomes,
    });
  }
  if (rows.size !== EXPECTED_CASE_IDS.length || EXPECTED_CASE_IDS.some((id) => !rows.has(id))) {
    throw new Error(`CQF JVM MedicationDispense returned ${rows.size} rows for ${EXPECTED_CASE_IDS.length} fixed cases`);
  }
  return rows;
}

export function runCqfJvmMedicationDispenseDifferential(root, value, javaScriptReport) {
  validateMedicationDispenseCorpus(value);
  if (!javaScriptReport || javaScriptReport.schemaVersion !== 1 || !Array.isArray(javaScriptReport.cases) ||
      javaScriptReport.fixtureSha256 !== createFixtureSha256(root)) {
    throw new Error('The CQF JVM comparison requires the pinned JavaScript MedicationDispense report and fixture digest');
  }
  const jsById = new Map(javaScriptReport.cases.map((testCase) => [testCase.id, testCase]));
  if (jsById.size !== EXPECTED_CASE_IDS.length || EXPECTED_CASE_IDS.some((id) => !jsById.has(id))) {
    throw new Error('JavaScript MedicationDispense report does not contain the same 11 fixed cases');
  }

  const projectPath = resolve(root, 'tool/cqf_jvm_cql_differential');
  assertCqfJvmLockfile(readFileSync(resolve(projectPath, 'gradle.lockfile'), 'utf8'));
  const wrapper = process.env.PARKINSUM_CQF_JVM_GRADLE_BIN
    || resolve(root, 'android', process.platform === 'win32' ? 'gradlew.bat' : 'gradlew');
  const result = spawnSync(
    wrapper,
    ['--no-daemon', '--offline', '-p', projectPath, '--quiet', 'fhirMedicationDispenseRun'],
    {
      cwd: root,
      encoding: 'utf8',
      input: encodeCqfJvmMedicationDispenseCases(value),
      maxBuffer: 4 * 1024 * 1024,
      shell: process.platform === 'win32',
      timeout: 300000,
      env: {
        ...process.env,
        JAVA_HOME: process.env.JAVA_HOME || '/Applications/Android Studio.app/Contents/jbr/Contents/Home',
      },
    },
  );
  if (result.error?.code === 'ENOENT') throw new Error('The Android Gradle wrapper is required for the CQF JVM MedicationDispense check.');
  if (result.error?.code === 'ETIMEDOUT') throw new Error('The CQF JVM MedicationDispense Gradle run exceeded the five-minute bound.');
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`CQF JVM MedicationDispense differential failed (${result.status}):\n${result.stderr || result.stdout}`);
  }
  const rows = parseCqfJvmMedicationDispenseOutput(result.stdout);
  const cases = value.cases.map((testCase) => {
    const row = rows.get(testCase.id);
    const jsCase = jsById.get(testCase.id);
    const scoped = scopeMedicationDispenseBundle(testCase.bundle, testCase.patientContextId);
    if (JSON.stringify(row.outcomes) !== JSON.stringify(testCase.expectedOutcomes) ||
        JSON.stringify(jsCase.outcomes) !== JSON.stringify(testCase.expectedOutcomes) ||
        row.foreignDispensesDropped !== scoped.foreignDispensesDropped ||
        jsCase.foreignDispensesDropped !== scoped.foreignDispensesDropped) {
      throw new Error(`MedicationDispense retrieval or Patient scope differs across fixed expectations for ${testCase.id}`);
    }
    return {
      id: testCase.id,
      expectedOutcomes: testCase.expectedOutcomes,
      javaScriptOutcomes: jsCase.outcomes,
      cqfJvmOutcomes: row.outcomes,
      outcomeMatched: JSON.stringify(jsCase.outcomes) === JSON.stringify(row.outcomes),
      foreignDispensesDropped: {
        javaScript: jsCase.foreignDispensesDropped,
        cqfJvm: row.foreignDispensesDropped,
      },
    };
  });
  const report = {
    schemaVersion: 1,
    scope: 'synthetic-fhir-r4-medication-dispense-retrieval-cross-runtime-differential',
    fhirVersion: value.fhirVersion,
    context: value.context,
    engine: 'org.cqframework:engine@5.3.0',
    fhirArtifact: 'org.cqframework:engine-fhir@5.3.0',
    modelInfoArtifact: 'org.cqframework:quick@5.3.0',
    cqlSourceSha256: javaScriptReport.cqlSourceSha256,
    fixtureSha256: javaScriptReport.fixtureSha256,
    caseCount: cases.length,
    outcomeParityCount: cases.filter((testCase) => testCase.outcomeMatched).length,
    cases,
    networkRequestMade: false,
    realPatientDataUsed: false,
  };
  if (/synthetic-patient-|synthetic-medication-dispense-|Synthetic medication placeholder/i.test(JSON.stringify(report))) {
    throw new Error('CQF JVM MedicationDispense report contains fixture content outside the bounded case projection');
  }
  return report;
}

function createFixtureSha256(root) {
  const fixturePath = resolve(root, 'test/fixtures/cql_fhir_r4_medication_dispense_retrieval_corpus.json');
  return createHash('sha256').update(readFileSync(fixturePath)).digest('hex');
}

export { EXPECTED_CASE_IDS as fixedMedicationDispenseCaseIds };
