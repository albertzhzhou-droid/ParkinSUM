import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';

const RESULT_PREFIX = 'PARKINSUM_CQF_JVM_RESULT';
const EXPECTED_CASE_LIMIT = 32;
const LOCKED_ARTIFACTS = [
  'org.cqframework:engine:5.3.0',
  'org.cqframework:engine-fhir:5.3.0',
  'org.cqframework:engine-fhir-jvm:5.3.0',
  'org.cqframework:engine-jvm:5.3.0',
  'org.cqframework:quick:5.3.0',
  'org.cqframework:cql-to-elm-jvm:5.3.0',
  'org.slf4j:slf4j-nop:2.0.13',
];

const EXPECTED_FHIR_RESOURCES = {
  condition_present: {
    patient: { resourceType: 'Patient', id: 'synthetic-patient-present' },
    patientContextId: 'synthetic-patient-present',
    expectedCql: 'true',
    condition: {
      resourceType: 'Condition',
      id: 'synthetic-condition-present',
      subject: { reference: 'Patient/synthetic-patient-present' },
      code: {
        coding: [{
          system: 'urn:parkinsum:synthetic-test',
          code: 'condition-placeholder',
          display: 'Synthetic test-only placeholder',
        }],
      },
    },
  },
  condition_absent: {
    patient: { resourceType: 'Patient', id: 'synthetic-patient-empty' },
    patientContextId: 'synthetic-patient-empty',
    expectedCql: 'false',
    condition: null,
  },
  condition_foreign_patient: {
    patient: { resourceType: 'Patient', id: 'synthetic-patient-empty' },
    patientContextId: 'synthetic-patient-empty',
    expectedCql: 'false',
    condition: {
      resourceType: 'Condition',
      id: 'synthetic-condition-foreign',
      subject: { reference: 'Patient/synthetic-patient-other' },
      code: {
        coding: [{
          system: 'urn:parkinsum:synthetic-test',
          code: 'condition-placeholder',
          display: 'Synthetic test-only placeholder',
        }],
      },
    },
  },
};

function encode(value) {
  return Buffer.from(value, 'utf8').toString('base64');
}

function decode(value, label) {
  if (typeof value !== 'string' || value.length === 0 || !/^[A-Za-z0-9+/]*={0,2}$/.test(value)) {
    throw new Error(`${label} is not canonical base64`);
  }
  const decoded = Buffer.from(value, 'base64').toString('utf8');
  if (Buffer.from(decoded, 'utf8').toString('base64') !== value) {
    throw new Error(`${label} is not canonical UTF-8 base64`);
  }
  return decoded;
}

function encodeList(values) {
  return values.length === 0 ? '-' : values.map(encode).join(',');
}

function decodeList(value, label) {
  if (value === '-') return [];
  if (value.length === 0) throw new Error(`${label} is empty; use '-' for an empty list`);
  return value.split(',').map((item) => decode(item, label));
}

export function encodeCqfJvmCases(cases) {
  if (!Array.isArray(cases) || cases.length === 0 || cases.length > EXPECTED_CASE_LIMIT) {
    throw new Error('CQF JVM case count is outside the bounded input contract');
  }
  const ids = new Set();
  return cases.map(({ id, cql }) => {
    if (typeof id !== 'string' || !/^[A-Za-z][A-Za-z0-9_]{0,79}$/.test(id) || ids.has(id)) {
      throw new Error('CQF JVM cases require unique, bounded identifiers');
    }
    if (typeof cql !== 'string' || cql.trim() === '' || /[\r\n]/.test(cql)) {
      throw new Error(`CQF JVM CQL input is invalid for ${id}`);
    }
    ids.add(id);
    return `${encode(id)}\t${encode(cql)}\n`;
  }).join('');
}

export function parseCqfJvmOutput(stdout, expectedCases) {
  if (!Array.isArray(expectedCases) || expectedCases.length === 0) {
    throw new Error('CQF JVM expected-case contract is empty');
  }
  const expectedIds = new Set(expectedCases.map((testCase) => testCase.id));
  if (expectedIds.size !== expectedCases.length) {
    throw new Error('CQF JVM expected-case identities are duplicated');
  }
  const rows = new Map();
  for (const line of String(stdout).split(/\r?\n/)) {
    if (!line.startsWith(`${RESULT_PREFIX}\t`)) continue;
    const fields = line.split('\t');
    if (fields.length !== 5 || fields[0] !== RESULT_PREFIX) {
      throw new Error('CQF JVM output row does not match the result protocol');
    }
    const id = decode(fields[1], 'CQF JVM case ID');
    if (!expectedIds.has(id) || rows.has(id)) {
      throw new Error(`CQF JVM output contains an unexpected or duplicate case: ${id}`);
    }
    if (!['true', 'false', 'unknown'].includes(fields[2])) {
      throw new Error(`CQF JVM outcome is invalid for ${id}`);
    }
    const errors = decodeList(fields[3], 'CQF JVM Errors');
    const warnings = decodeList(fields[4], 'CQF JVM Warnings');
    for (const [label, diagnostics] of [['Errors', errors], ['Warnings', warnings]]) {
      if (diagnostics.length > 1 || diagnostics.some((item) => item.trim() === '')) {
        throw new Error(`CQF JVM ${label} exceed the bounded diagnostic contract for ${id}`);
      }
    }
    rows.set(id, { id, result: fields[2], errors, warnings });
  }
  if (rows.size !== expectedCases.length) {
    throw new Error(`CQF JVM returned ${rows.size} rows for ${expectedCases.length} fixed cases`);
  }
  return rows;
}

export function assertCqfJvmLockfile(lockText) {
  const lockLines = new Set(String(lockText).split(/\r?\n/));
  const missing = LOCKED_ARTIFACTS.filter((coordinate) =>
    ![...lockLines].some((line) => line.startsWith(`${coordinate}=`) && line.includes('runtimeClasspath')),
  );
  if (missing.length > 0) {
    throw new Error(`CQF JVM Gradle lockfile is missing pinned runtime modules: ${missing.join(', ')}`);
  }
  return LOCKED_ARTIFACTS;
}

export function encodeCqfJvmFhirCases(corpus) {
  if (corpus?.schemaVersion !== 2 || corpus.scope !== 'synthetic-fhir-r4-retrieval' ||
      corpus.fhirVersion !== '4.0.1' || corpus.context !== 'Patient' ||
      corpus.expression !== 'exists([Condition])' || !Array.isArray(corpus.cases) ||
      corpus.cases.length !== 3) {
    throw new Error('CQF JVM FHIR input does not match the fixed synthetic R4 corpus contract');
  }
  const expectedIds = Object.keys(EXPECTED_FHIR_RESOURCES);
  return corpus.cases.map((testCase, index) => {
    const expected = EXPECTED_FHIR_RESOURCES[expectedIds[index]];
    if (!testCase || testCase.id !== expectedIds[index] ||
        testCase.patientContextId !== expected.patientContextId ||
        testCase.expectedCql !== expected.expectedCql ||
        JSON.stringify(testCase.expectedResponseErrors) !== '[]' ||
        JSON.stringify(testCase.expectedResponseWarnings) !== (expected.expectedCql === 'true' ? '[]' : '["criterion_not_met"]') ||
        testCase.bundle?.resourceType !== 'Bundle' || testCase.bundle.type !== 'collection' ||
        !Array.isArray(testCase.bundle.entry)) {
      throw new Error('CQF JVM FHIR case does not match its fixed corpus expectation');
    }
    const resources = testCase.bundle.entry.map((entry) => entry?.resource);
    const patients = resources.filter((resource) => resource?.resourceType === 'Patient');
    const conditions = resources.filter((resource) => resource?.resourceType === 'Condition');
    if (resources.some((resource) => !resource || !['Patient', 'Condition'].includes(resource.resourceType)) ||
        patients.length !== 1 || conditions.length !== (expected.condition ? 1 : 0) ||
        JSON.stringify(patients[0]) !== JSON.stringify(expected.patient) ||
        JSON.stringify(conditions[0] ?? null) !== JSON.stringify(expected.condition)) {
      throw new Error('CQF JVM FHIR resources are outside the three fixed synthetic bundles');
    }
    return `${encode(testCase.id)}\t${encode(testCase.patientContextId)}\t${encode(JSON.stringify(patients[0]))}\t${expected.condition ? encode(JSON.stringify(conditions[0])) : '-'}\n`;
  }).join('');
}

export function runCqfJvmFhirDifferential(root, corpus) {
  const projectPath = resolve(root, 'tool/cqf_jvm_cql_differential');
  const lockPath = resolve(projectPath, 'gradle.lockfile');
  const lockText = readFileSync(lockPath, 'utf8');
  assertCqfJvmLockfile(lockText);
  const wrapper = process.env.PARKINSUM_CQF_JVM_GRADLE_BIN
    || resolve(root, 'android', process.platform === 'win32' ? 'gradlew.bat' : 'gradlew');
  const cases = corpus.cases.map(({ id }) => ({ id, cql: 'exists([Condition])' }));
  const result = spawnSync(
    wrapper,
    ['--no-daemon', '-p', projectPath, '--quiet', 'fhirRun'],
    {
      cwd: root,
      encoding: 'utf8',
      input: encodeCqfJvmFhirCases(corpus),
      maxBuffer: 4 * 1024 * 1024,
      shell: process.platform === 'win32',
      timeout: 300000,
    },
  );
  if (result.error?.code === 'ENOENT') {
    throw new Error('The Android Gradle wrapper is required for the CQF JVM FHIR development check.');
  }
  if (result.error?.code === 'ETIMEDOUT') {
    throw new Error('The CQF JVM FHIR Gradle run exceeded the five-minute bound.');
  }
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`CQF JVM FHIR differential failed (${result.status}):\n${result.stderr || result.stdout}`);
  }
  const rows = parseCqfJvmOutput(result.stdout, cases);
  for (const testCase of corpus.cases) {
    const row = rows.get(testCase.id);
    if (!row || row.result !== testCase.expectedCql ||
        JSON.stringify(row.errors) !== JSON.stringify(testCase.expectedResponseErrors) ||
        JSON.stringify(row.warnings) !== JSON.stringify(testCase.expectedResponseWarnings)) {
      throw new Error(`CQF JVM FHIR result or diagnostics differ from the fixed corpus for ${testCase.id}`);
    }
  }
  return {
    engine: 'org.cqframework:engine@5.3.0',
    fhirArtifact: 'org.cqframework:engine-fhir@5.3.0',
    modelInfoArtifact: 'org.cqframework:quick@5.3.0',
    status: 'passed',
    fhirVersion: corpus.fhirVersion,
    context: corpus.context,
    expression: corpus.expression,
    caseCount: rows.size,
    outcomeParityCount: rows.size,
    diagnosticParityCount: rows.size,
    results: corpus.cases.map((testCase) => ({
      id: testCase.id,
      result: rows.get(testCase.id).result,
      errors: rows.get(testCase.id).errors,
      warnings: rows.get(testCase.id).warnings,
      outcomeMatched: true,
      diagnosticsMatched: true,
    })),
  };
}

export function runCqfJvmDifferential(root, cases) {
  const projectPath = resolve(root, 'tool/cqf_jvm_cql_differential');
  const lockPath = resolve(projectPath, 'gradle.lockfile');
  const lockText = readFileSync(lockPath, 'utf8');
  assertCqfJvmLockfile(lockText);
  const wrapper = process.env.PARKINSUM_CQF_JVM_GRADLE_BIN
    || resolve(root, 'android', process.platform === 'win32' ? 'gradlew.bat' : 'gradlew');
  const result = spawnSync(
    wrapper,
    ['--no-daemon', '-p', projectPath, '--quiet', 'run'],
    {
      cwd: root,
      encoding: 'utf8',
      input: encodeCqfJvmCases(cases),
      maxBuffer: 4 * 1024 * 1024,
      shell: process.platform === 'win32',
      timeout: 300000,
    },
  );
  if (result.error?.code === 'ENOENT') {
    throw new Error('The Android Gradle wrapper is required for the CQF JVM development check.');
  }
  if (result.error?.code === 'ETIMEDOUT') {
    throw new Error('The CQF JVM Gradle run exceeded the five-minute bound.');
  }
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(
      `CQF JVM differential failed (${result.status}):\n${result.stderr || result.stdout}`,
    );
  }
  const rows = parseCqfJvmOutput(result.stdout, cases);
  return {
    engine: 'org.cqframework:engine@5.3.0',
    jvmArtifact: 'org.cqframework:engine-jvm@5.3.0',
    translatorArtifact: 'org.cqframework:cql-to-elm-jvm@5.3.0',
    status: 'passed',
    caseCount: rows.size,
    outcomeParityCount: rows.size,
    diagnosticParityCount: rows.size,
    rows,
  };
}
