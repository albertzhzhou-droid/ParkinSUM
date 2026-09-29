import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';

import { assertCqfJvmLockfile } from './cqf_jvm_cql_differential.mjs';
import {
  medicationRequestOutcomeKeys,
  scopeMedicationRequestBundle,
  validateMedicationRequestCorpus,
} from './cql_fhir_medication_request_retrieval_contract.mjs';

const RESULT_PREFIX = 'PARKINSUM_CQF_JVM_MEDICATION_REQUEST_RESULT';
const EXPECTED_CASE_IDS = [
  'status_active_request',
  'status_on_hold_request',
  'status_cancelled_request',
  'status_completed_request',
  'status_entered_in_error_request',
  'status_stopped_request',
  'status_draft_request',
  'status_unknown_request',
  'intent_proposal_request',
  'intent_plan_request',
  'intent_order_request',
  'intent_original_order_request',
  'intent_reflex_order_request',
  'intent_filler_order_request',
  'intent_instance_order_request',
  'intent_option_request',
  'no_request',
  'foreign_subject_request',
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

export function encodeCqfJvmMedicationRequestCases(value) {
  validateMedicationRequestCorpus(value);
  return value.cases.map((testCase) => {
    const resources = testCase.bundle.entry.map((entry) => entry.resource);
    const patients = resources.filter((resource) => resource.resourceType === 'Patient');
    const requests = resources.filter((resource) => resource.resourceType === 'MedicationRequest');
    if (patients.length !== 1 || requests.length > 1) {
      throw new Error('CQF JVM MedicationRequest input is outside the fixed one-Patient, optional-request contract');
    }
    return [
      encode(testCase.id),
      encode(testCase.patientContextId),
      encode(JSON.stringify(patients[0])),
      requests.length === 0 ? '-' : encode(JSON.stringify(requests[0])),
    ].join('\t') + '\n';
  }).join('');
}

export function parseCqfJvmMedicationRequestOutput(stdout) {
  const rows = new Map();
  for (const line of String(stdout).split(/\r?\n/)) {
    if (!line.startsWith(`${RESULT_PREFIX}\t`)) continue;
    const fields = line.split('\t');
    if (fields.length !== 3 + medicationRequestOutcomeKeys.length || fields[0] !== RESULT_PREFIX) {
      throw new Error('CQF JVM MedicationRequest output row does not match the fixed protocol');
    }
    const id = decode(fields[1], 'CQF JVM MedicationRequest case ID');
    if (!EXPECTED_CASE_IDS.includes(id) || rows.has(id)) {
      throw new Error(`CQF JVM MedicationRequest output has an unexpected or duplicate case: ${id}`);
    }
    if (!/^(0|1)$/.test(fields[2])) {
      throw new Error(`CQF JVM MedicationRequest foreign-subject count is invalid for ${id}`);
    }
    const outcomes = {};
    for (const [index, name] of medicationRequestOutcomeKeys.entries()) {
      if (!['true', 'false'].includes(fields[index + 3])) {
        throw new Error(`CQF JVM MedicationRequest output contains an invalid outcome for ${id}`);
      }
      outcomes[name] = fields[index + 3] === 'true';
    }
    rows.set(id, {
      id,
      foreignRequestsDropped: Number(fields[2]),
      outcomes,
    });
  }
  if (rows.size !== EXPECTED_CASE_IDS.length || EXPECTED_CASE_IDS.some((id) => !rows.has(id))) {
    throw new Error(`CQF JVM MedicationRequest returned ${rows.size} rows for ${EXPECTED_CASE_IDS.length} fixed cases`);
  }
  return rows;
}

export function runCqfJvmMedicationRequestDifferential(root, value, javaScriptReport) {
  validateMedicationRequestCorpus(value);
  if (!javaScriptReport || javaScriptReport.schemaVersion !== 1 || !Array.isArray(javaScriptReport.cases)) {
    throw new Error('The cross-runtime comparison requires the pinned JavaScript MedicationRequest report');
  }
  const jsById = new Map(javaScriptReport.cases.map((testCase) => [testCase.id, testCase]));
  if (jsById.size !== EXPECTED_CASE_IDS.length || EXPECTED_CASE_IDS.some((id) => !jsById.has(id))) {
    throw new Error('JavaScript MedicationRequest report does not contain the same 18 fixed cases');
  }

  const projectPath = resolve(root, 'tool/cqf_jvm_cql_differential');
  assertCqfJvmLockfile(readFileSync(resolve(projectPath, 'gradle.lockfile'), 'utf8'));
  const wrapper = process.env.PARKINSUM_CQF_JVM_GRADLE_BIN
    || resolve(root, 'android', process.platform === 'win32' ? 'gradlew.bat' : 'gradlew');
  const result = spawnSync(
    wrapper,
    ['--no-daemon', '--offline', '-p', projectPath, '--quiet', 'fhirMedicationRequestRun'],
    {
      cwd: root,
      encoding: 'utf8',
      input: encodeCqfJvmMedicationRequestCases(value),
      maxBuffer: 4 * 1024 * 1024,
      shell: process.platform === 'win32',
      timeout: 300000,
      env: {
        ...process.env,
        JAVA_HOME: process.env.JAVA_HOME || '/Applications/Android Studio.app/Contents/jbr/Contents/Home',
      },
    },
  );
  if (result.error?.code === 'ENOENT') throw new Error('The Android Gradle wrapper is required for the CQF JVM MedicationRequest check.');
  if (result.error?.code === 'ETIMEDOUT') throw new Error('The CQF JVM MedicationRequest Gradle run exceeded the five-minute bound.');
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`CQF JVM MedicationRequest differential failed (${result.status}):\n${result.stderr || result.stdout}`);
  }
  const rows = parseCqfJvmMedicationRequestOutput(result.stdout);
  const cases = value.cases.map((testCase) => {
    const row = rows.get(testCase.id);
    const jsCase = jsById.get(testCase.id);
    const scoped = scopeMedicationRequestBundle(testCase.bundle, testCase.patientContextId);
    if (JSON.stringify(row.outcomes) !== JSON.stringify(testCase.expectedOutcomes) ||
        JSON.stringify(jsCase.outcomes) !== JSON.stringify(testCase.expectedOutcomes) ||
        row.foreignRequestsDropped !== scoped.foreignRequestsDropped ||
        jsCase.foreignRequestsDropped !== scoped.foreignRequestsDropped) {
      throw new Error(`MedicationRequest retrieval or Patient scope differs across fixed expectations for ${testCase.id}`);
    }
    return {
      id: testCase.id,
      expectedOutcomes: testCase.expectedOutcomes,
      javaScriptOutcomes: jsCase.outcomes,
      cqfJvmOutcomes: row.outcomes,
      outcomeMatched: JSON.stringify(jsCase.outcomes) === JSON.stringify(row.outcomes),
      foreignRequestsDropped: {
        javaScript: jsCase.foreignRequestsDropped,
        cqfJvm: row.foreignRequestsDropped,
      },
    };
  });
  const report = {
    schemaVersion: 1,
    scope: 'synthetic-fhir-r4-medication-request-retrieval-cross-runtime-differential',
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
  if (/synthetic-patient-|synthetic-medication-request-|Synthetic medication placeholder/i.test(JSON.stringify(report))) {
    throw new Error('CQF JVM MedicationRequest report contains fixture content outside the bounded case projection');
  }
  return report;
}

export { EXPECTED_CASE_IDS as fixedMedicationRequestCaseIds };
