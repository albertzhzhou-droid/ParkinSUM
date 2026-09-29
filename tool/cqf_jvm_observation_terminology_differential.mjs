import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

import corpus from '../test/fixtures/cql_fhir_r4_observation_retrieval_corpus.json' with { type: 'json' };
import { assertCqfJvmLockfile } from './cqf_jvm_cql_differential.mjs';
import { runObservationRetrievalDifferential, validateObservationCorpus } from './cql_fhir_observation_retrieval_differential.mjs';

const RESULT_PREFIX = 'PARKINSUM_CQF_JVM_OBSERVATION_RESULT';
const EXPECTED_CASE_IDS = [
  'observation_present',
  'observation_absent',
  'observation_foreign_subject',
  'observation_non_member_code',
  'observation_foreign_code_system',
  'observation_system_version_mismatch',
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

export function encodeCqfJvmObservationCases(value) {
  validateObservationCorpus(value);
  return value.cases.map((testCase) => {
    const resources = testCase.bundle.entry.map((entry) => entry.resource);
    const patients = resources.filter((resource) => resource.resourceType === 'Patient');
    const observations = resources.filter((resource) => resource.resourceType === 'Observation');
    if (patients.length !== 1 || observations.length > 1) {
      throw new Error('CQF JVM Observation input is outside the fixed one-Patient, optional-Observation contract');
    }
    return [
      encode(testCase.id),
      encode(testCase.patientContextId),
      encode(JSON.stringify(patients[0])),
      observations.length === 0 ? '-' : encode(JSON.stringify(observations[0])),
    ].join('\t') + '\n';
  }).join('');
}

export function parseCqfJvmObservationOutput(stdout) {
  const rows = new Map();
  for (const line of String(stdout).split(/\r?\n/)) {
    if (!line.startsWith(`${RESULT_PREFIX}\t`)) continue;
    const fields = line.split('\t');
    if (fields.length !== 5 || fields[0] !== RESULT_PREFIX) {
      throw new Error('CQF JVM Observation output row does not match the fixed protocol');
    }
    const id = decode(fields[1], 'CQF JVM Observation case ID');
    if (!EXPECTED_CASE_IDS.includes(id) || rows.has(id)) {
      throw new Error(`CQF JVM Observation output has an unexpected or duplicate case: ${id}`);
    }
    if (fields.slice(2).some((outcome) => !['true', 'false', 'unknown'].includes(outcome))) {
      throw new Error(`CQF JVM Observation output contains an invalid outcome for ${id}`);
    }
    rows.set(id, { id, result: fields[2], codeMembership: fields[3], codeFilteredObservation: fields[4] });
  }
  if (rows.size !== EXPECTED_CASE_IDS.length || EXPECTED_CASE_IDS.some((id) => !rows.has(id))) {
    throw new Error(`CQF JVM Observation returned ${rows.size} rows for six fixed cases`);
  }
  return rows;
}

export function runCqfJvmObservationTerminologyDifferential(root, value, javaScriptReport) {
  validateObservationCorpus(value);
  if (!javaScriptReport || javaScriptReport.schemaVersion !== 2 || !Array.isArray(javaScriptReport.cases)) {
    throw new Error('The cross-runtime comparison requires the pinned JavaScript Observation report');
  }
  const fixedJsReport = javaScriptReport;
  const projectPath = resolve(root, 'tool/cqf_jvm_cql_differential');
  const lockText = readFileSync(resolve(projectPath, 'gradle.lockfile'), 'utf8');
  assertCqfJvmLockfile(lockText);
  const wrapper = process.env.PARKINSUM_CQF_JVM_GRADLE_BIN
    || resolve(root, 'android', process.platform === 'win32' ? 'gradlew.bat' : 'gradlew');
  const jbr = '/Applications/Android Studio.app/Contents/jbr/Contents/Home';
  const result = spawnSync(
    wrapper,
    ['--no-daemon', '--offline', '-p', projectPath, '--quiet', 'fhirObservationTerminologyRun'],
    {
      cwd: root,
      encoding: 'utf8',
      input: encodeCqfJvmObservationCases(value),
      maxBuffer: 4 * 1024 * 1024,
      shell: process.platform === 'win32',
      timeout: 300000,
      env: {
        ...process.env,
        JAVA_HOME: process.env.JAVA_HOME || jbr,
      },
    },
  );
  if (result.error?.code === 'ENOENT') throw new Error('The Android Gradle wrapper is required for the CQF JVM Observation check.');
  if (result.error?.code === 'ETIMEDOUT') throw new Error('The CQF JVM Observation Gradle run exceeded the five-minute bound.');
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`CQF JVM Observation differential failed (${result.status}):\n${result.stderr || result.stdout}`);
  }
  const rows = parseCqfJvmObservationOutput(result.stdout);
  const actualJsReport = fixedJsReport;
  const jsById = new Map((actualJsReport?.cases ?? []).map((testCase) => [testCase.id, testCase]));
  if (actualJsReport && (jsById.size !== EXPECTED_CASE_IDS.length || EXPECTED_CASE_IDS.some((id) => !jsById.has(id)))) {
    throw new Error('JavaScript Observation report does not contain the same six fixed cases');
  }
  const cases = value.cases.map((testCase) => {
    const row = rows.get(testCase.id);
    const expectedResult = String(testCase.expectedResult);
    const expectedMembership = String(testCase.expectedVersionAwareMembership);
    if (row.result !== expectedResult || row.codeMembership !== expectedMembership ||
        row.codeFilteredObservation !== expectedMembership) {
      throw new Error(`CQF JVM Observation results differ from the fixed fixture for ${testCase.id}`);
    }
    const jsCase = jsById.get(testCase.id);
    const javaScriptMembership = jsCase?.runtimeValueSetMembership;
    if (jsCase && (typeof javaScriptMembership !== 'boolean' ||
        jsCase.result !== testCase.expectedResult ||
        javaScriptMembership !== testCase.expectedRuntimeValueSetMembership)) {
      throw new Error(`JavaScript Observation report membership is invalid for ${testCase.id}`);
    }
    const runtimeMembershipMatchesJavascript = jsCase
      ? row.codeMembership === String(javaScriptMembership)
      : undefined;
    if (jsCase && runtimeMembershipMatchesJavascript !== (testCase.id !== 'observation_system_version_mismatch')) {
      throw new Error(`Unexpected JavaScript/JVM terminology difference for ${testCase.id}`);
    }
    return {
      id: testCase.id,
      expectedResult: testCase.expectedResult,
      result: row.result === 'true',
      expectedVersionAwareMembership: testCase.expectedVersionAwareMembership,
      cqfJvmCodeMembership: row.codeMembership === 'true',
      cqfJvmCodeFilteredObservation: row.codeFilteredObservation === 'true',
      ...(jsCase ? {
        javascriptCodeMembership: javaScriptMembership,
        runtimeMembershipMatchesJavascript,
      } : {}),
    };
  });
  const report = {
    schemaVersion: 1,
    scope: 'synthetic-fhir-r4-observation-retrieval-and-local-terminology-cross-runtime-differential',
    engine: 'org.cqframework:engine@5.3.0',
    fhirArtifact: 'org.cqframework:engine-fhir@5.3.0',
    modelInfoArtifact: 'org.cqframework:quick@5.3.0',
    terminologyProvider: 'fixed-in-memory-version-aware-synthetic-expansion',
    candidateBinding: 'coding-fields-from-exactly-validated-patient-scoped-observation-fixture',
    valueSetCanonical: 'urn:oid:1.2.3.4.5.6.7',
    valueSetVersion: '2026-09',
    caseCount: cases.length,
    expectedJavascriptMembershipDifferenceCount: 1,
    observedJavascriptMembershipDifferenceCount: cases.filter((testCase) => testCase.runtimeMembershipMatchesJavascript === false).length,
    cases,
    fixtureSha256: actualJsReport.fixtureSha256,
    networkRequestMade: false,
    realPatientDataUsed: false,
  };
  if (/synthetic-patient-|synthetic-observation-|observation-in-set|observation-outside-set|urn:parkinsum:synthetic-/i.test(JSON.stringify(report))) {
    throw new Error('CQF JVM Observation report contains fixture content outside the bounded case projection');
  }
  return report;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const root = resolve(fileURLToPath(import.meta.url), '../..');
  runObservationRetrievalDifferential().then((jsReport) => {
    const report = runCqfJvmObservationTerminologyDifferential(root, corpus, jsReport);
    process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  }).catch((error) => {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  });
}
