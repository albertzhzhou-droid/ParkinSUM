import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';

import { assertCqfJvmLockfile } from './cqf_jvm_cql_differential.mjs';
import { validateMedicationStatementCorpus } from './cql_fhir_medication_statement_retrieval_contract.mjs';

const RESULT_PREFIX = 'PARKINSUM_CQF_JVM_MEDICATION_STATEMENT_RESULT';
const EXPECTED_CASE_IDS = [
  'active_statement',
  'completed_statement',
  'entered_in_error_statement',
  'intended_statement',
  'stopped_statement',
  'unknown_statement',
  'not_taken_statement',
  'on_hold_statement',
  'no_statement',
  'foreign_subject_statement',
];
const OUTCOME_KEYS = [
  'hasAnyStatement',
  'hasActiveStatement',
  'hasStoppedStatement',
  'hasUnknownStatement',
  'hasNotTakenStatement',
  'hasCompletedStatement',
  'hasEnteredInErrorStatement',
  'hasIntendedStatement',
  'hasOnHoldStatement',
];

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

export function encodeCqfJvmMedicationStatementCases(value) {
  validateMedicationStatementCorpus(value);
  return value.cases.map((testCase) => {
    const resources = testCase.bundle.entry.map((entry) => entry.resource);
    const patients = resources.filter((resource) => resource.resourceType === 'Patient');
    const statements = resources.filter((resource) => resource.resourceType === 'MedicationStatement');
    if (patients.length !== 1 || statements.length > 1) {
      throw new Error('CQF JVM MedicationStatement input is outside the fixed one-Patient, optional-statement contract');
    }
    return [
      encode(testCase.id),
      encode(testCase.patientContextId),
      encode(JSON.stringify(patients[0])),
      statements.length === 0 ? '-' : encode(JSON.stringify(statements[0])),
    ].join('\t') + '\n';
  }).join('');
}

export function parseCqfJvmMedicationStatementOutput(stdout) {
  const rows = new Map();
  for (const line of String(stdout).split(/\r?\n/)) {
    if (!line.startsWith(`${RESULT_PREFIX}\t`)) continue;
    const fields = line.split('\t');
    if (fields.length !== 2 + OUTCOME_KEYS.length || fields[0] !== RESULT_PREFIX) {
      throw new Error('CQF JVM MedicationStatement output row does not match the fixed protocol');
    }
    const id = decode(fields[1], 'CQF JVM MedicationStatement case ID');
    if (!EXPECTED_CASE_IDS.includes(id) || rows.has(id)) {
      throw new Error(`CQF JVM MedicationStatement output has an unexpected or duplicate case: ${id}`);
    }
    const outcomes = {};
    for (const [index, name] of OUTCOME_KEYS.entries()) {
      if (!['true', 'false'].includes(fields[index + 2])) {
        throw new Error(`CQF JVM MedicationStatement output contains an invalid outcome for ${id}`);
      }
      outcomes[name] = fields[index + 2] === 'true';
    }
    rows.set(id, { id, outcomes });
  }
  if (rows.size !== EXPECTED_CASE_IDS.length || EXPECTED_CASE_IDS.some((id) => !rows.has(id))) {
    throw new Error(`CQF JVM MedicationStatement returned ${rows.size} rows for ${EXPECTED_CASE_IDS.length} fixed cases`);
  }
  return rows;
}

export function runCqfJvmMedicationStatementDifferential(root, value, javaScriptReport) {
  validateMedicationStatementCorpus(value);
  if (!javaScriptReport || javaScriptReport.schemaVersion !== 1 || !Array.isArray(javaScriptReport.cases)) {
    throw new Error('The cross-runtime comparison requires the pinned JavaScript MedicationStatement report');
  }
  const jsById = new Map(javaScriptReport.cases.map((testCase) => [testCase.id, testCase]));
  if (jsById.size !== EXPECTED_CASE_IDS.length || EXPECTED_CASE_IDS.some((id) => !jsById.has(id))) {
    throw new Error('JavaScript MedicationStatement report does not contain the same ten fixed cases');
  }
  const projectPath = resolve(root, 'tool/cqf_jvm_cql_differential');
  assertCqfJvmLockfile(readFileSync(resolve(projectPath, 'gradle.lockfile'), 'utf8'));
  const wrapper = process.env.PARKINSUM_CQF_JVM_GRADLE_BIN
    || resolve(root, 'android', process.platform === 'win32' ? 'gradlew.bat' : 'gradlew');
  const result = spawnSync(
    wrapper,
    ['--no-daemon', '--offline', '-p', projectPath, '--quiet', 'fhirMedicationStatementRun'],
    {
      cwd: root,
      encoding: 'utf8',
      input: encodeCqfJvmMedicationStatementCases(value),
      maxBuffer: 4 * 1024 * 1024,
      shell: process.platform === 'win32',
      timeout: 300000,
      env: {
        ...process.env,
        JAVA_HOME: process.env.JAVA_HOME || '/Applications/Android Studio.app/Contents/jbr/Contents/Home',
      },
    },
  );
  if (result.error?.code === 'ENOENT') throw new Error('The Android Gradle wrapper is required for the CQF JVM MedicationStatement check.');
  if (result.error?.code === 'ETIMEDOUT') throw new Error('The CQF JVM MedicationStatement Gradle run exceeded the five-minute bound.');
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`CQF JVM MedicationStatement differential failed (${result.status}):\n${result.stderr || result.stdout}`);
  }
  const rows = parseCqfJvmMedicationStatementOutput(result.stdout);
  const cases = value.cases.map((testCase) => {
    const row = rows.get(testCase.id);
    const jsCase = jsById.get(testCase.id);
    if (JSON.stringify(row.outcomes) !== JSON.stringify(testCase.expectedOutcomes) ||
        JSON.stringify(jsCase.outcomes) !== JSON.stringify(testCase.expectedOutcomes)) {
      throw new Error(`MedicationStatement retrieval results differ across fixed expectations for ${testCase.id}`);
    }
    return {
      id: testCase.id,
      expectedOutcomes: testCase.expectedOutcomes,
      javaScriptOutcomes: jsCase.outcomes,
      cqfJvmOutcomes: row.outcomes,
      outcomeMatched: JSON.stringify(jsCase.outcomes) === JSON.stringify(row.outcomes),
      foreignStatementsDropped: jsCase.foreignStatementsDropped,
    };
  });
  const report = {
    schemaVersion: 1,
    scope: 'synthetic-fhir-r4-medication-statement-retrieval-cross-runtime-differential',
    fhirVersion: '4.0.1',
    context: 'Patient',
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
  if (/synthetic-patient-|synthetic-medication-statement-|Synthetic medication placeholder/i.test(JSON.stringify(report))) {
    throw new Error('CQF JVM MedicationStatement report contains fixture content outside the bounded case projection');
  }
  return report;
}
