import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';

import { assertCqfJvmLockfile } from './cqf_jvm_cql_differential.mjs';
import {
  allergyIntoleranceOutcomeKeys,
  fixedAllergyIntoleranceCorpus,
  scopeAllergyIntoleranceBundle,
  validateAllergyIntoleranceCorpus,
} from './cql_fhir_allergy_intolerance_retrieval_contract.mjs';

const RESULT_PREFIX = 'PARKINSUM_CQF_JVM_ALLERGY_INTOLERANCE_RESULT';
const EXPECTED_CASE_IDS = fixedAllergyIntoleranceCorpus.cases.map((testCase) => testCase.id);

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

export function encodeCqfJvmAllergyIntoleranceCases(value) {
  validateAllergyIntoleranceCorpus(value);
  return value.cases.map((testCase) => {
    const resources = testCase.bundle.entry.map((entry) => entry.resource);
    const patients = resources.filter((resource) => resource.resourceType === 'Patient');
    const allergies = resources.filter((resource) => resource.resourceType === 'AllergyIntolerance');
    if (patients.length !== 1 || allergies.length > 1) {
      throw new Error('CQF JVM AllergyIntolerance input is outside the fixed one-Patient, optional-resource contract');
    }
    return [
      encode(testCase.id),
      encode(testCase.patientContextId),
      encode(JSON.stringify(patients[0])),
      allergies.length === 0 ? '-' : encode(JSON.stringify(allergies[0])),
    ].join('\t') + '\n';
  }).join('');
}

export function parseCqfJvmAllergyIntoleranceOutput(stdout) {
  const rows = new Map();
  for (const line of String(stdout).split(/\r?\n/)) {
    if (!line.startsWith(`${RESULT_PREFIX}\t`)) continue;
    const fields = line.split('\t');
    if (fields.length !== 3 + allergyIntoleranceOutcomeKeys.length || fields[0] !== RESULT_PREFIX) {
      throw new Error('CQF JVM AllergyIntolerance output row does not match the fixed protocol');
    }
    const id = decode(fields[1], 'CQF JVM AllergyIntolerance case ID');
    if (!EXPECTED_CASE_IDS.includes(id) || rows.has(id)) {
      throw new Error(`CQF JVM AllergyIntolerance output has an unexpected or duplicate case: ${id}`);
    }
    if (!/^(0|1)$/.test(fields[2])) {
      throw new Error(`CQF JVM AllergyIntolerance foreign-subject count is invalid for ${id}`);
    }
    const outcomes = {};
    for (const [index, name] of allergyIntoleranceOutcomeKeys.entries()) {
      if (!['true', 'false'].includes(fields[index + 3])) {
        throw new Error(`CQF JVM AllergyIntolerance output contains an invalid outcome for ${id}`);
      }
      outcomes[name] = fields[index + 3] === 'true';
    }
    rows.set(id, {
      id,
      foreignAllergyIntolerancesDropped: Number(fields[2]),
      outcomes,
    });
  }
  if (rows.size !== EXPECTED_CASE_IDS.length || EXPECTED_CASE_IDS.some((id) => !rows.has(id))) {
    throw new Error(`CQF JVM AllergyIntolerance returned ${rows.size} rows for ${EXPECTED_CASE_IDS.length} fixed cases`);
  }
  return rows;
}

export function runCqfJvmAllergyIntoleranceDifferential(root, value, javaScriptReport) {
  validateAllergyIntoleranceCorpus(value);
  if (!javaScriptReport || javaScriptReport.schemaVersion !== 1 || !Array.isArray(javaScriptReport.cases) ||
      javaScriptReport.fixtureSha256 !== createFixtureSha256(root)) {
    throw new Error('CQF JVM comparison requires the pinned JavaScript AllergyIntolerance report and fixture digest');
  }
  const jsById = new Map(javaScriptReport.cases.map((testCase) => [testCase.id, testCase]));
  if (jsById.size !== EXPECTED_CASE_IDS.length || EXPECTED_CASE_IDS.some((id) => !jsById.has(id))) {
    throw new Error('JavaScript AllergyIntolerance report does not contain the same six fixed cases');
  }

  const projectPath = resolve(root, 'tool/cqf_jvm_cql_differential');
  assertCqfJvmLockfile(readFileSync(resolve(projectPath, 'gradle.lockfile'), 'utf8'));
  const wrapper = process.env.PARKINSUM_CQF_JVM_GRADLE_BIN
    || resolve(root, 'android', process.platform === 'win32' ? 'gradlew.bat' : 'gradlew');
  const result = spawnSync(
    wrapper,
    ['--no-daemon', '--offline', '-p', projectPath, '--quiet', 'fhirAllergyIntoleranceRun'],
    {
      cwd: root,
      encoding: 'utf8',
      input: encodeCqfJvmAllergyIntoleranceCases(value),
      maxBuffer: 4 * 1024 * 1024,
      shell: process.platform === 'win32',
      timeout: 300000,
      env: {
        ...process.env,
        JAVA_HOME: process.env.JAVA_HOME || '/Applications/Android Studio.app/Contents/jbr/Contents/Home',
      },
    },
  );
  if (result.error?.code === 'ENOENT') throw new Error('The Android Gradle wrapper is required for the CQF JVM AllergyIntolerance check.');
  if (result.error?.code === 'ETIMEDOUT') throw new Error('The CQF JVM AllergyIntolerance Gradle run exceeded the five-minute bound.');
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`CQF JVM AllergyIntolerance differential failed (${result.status}):\n${result.stderr || result.stdout}`);
  }
  const rows = parseCqfJvmAllergyIntoleranceOutput(result.stdout);
  const cases = value.cases.map((testCase) => {
    const row = rows.get(testCase.id);
    const jsCase = jsById.get(testCase.id);
    const scoped = scopeAllergyIntoleranceBundle(testCase.bundle, testCase.patientContextId);
    if (JSON.stringify(row.outcomes) !== JSON.stringify(testCase.expectedOutcomes) ||
        JSON.stringify(jsCase.outcomes) !== JSON.stringify(testCase.expectedOutcomes) ||
        row.foreignAllergyIntolerancesDropped !== scoped.foreignAllergyIntolerancesDropped ||
        jsCase.foreignAllergyIntolerancesDropped !== scoped.foreignAllergyIntolerancesDropped) {
      throw new Error(`AllergyIntolerance retrieval or Patient scope differs across fixed expectations for ${testCase.id}`);
    }
    return {
      id: testCase.id,
      expectedOutcomes: testCase.expectedOutcomes,
      javaScriptOutcomes: jsCase.outcomes,
      cqfJvmOutcomes: row.outcomes,
      outcomeMatched: JSON.stringify(jsCase.outcomes) === JSON.stringify(row.outcomes),
      foreignAllergyIntolerancesDropped: {
        javaScript: jsCase.foreignAllergyIntolerancesDropped,
        cqfJvm: row.foreignAllergyIntolerancesDropped,
      },
    };
  });
  const report = {
    schemaVersion: 1,
    scope: 'synthetic-fhir-r4-allergy-intolerance-retrieval-cross-runtime-differential',
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
  if (/synthetic-patient-|synthetic-ai-|terminology\.hl7\.org\/CodeSystem\/allergyintolerance/i.test(JSON.stringify(report))) {
    throw new Error('CQF JVM AllergyIntolerance report contains fixture content outside the bounded case projection');
  }
  return report;
}

function createFixtureSha256(root) {
  const fixturePath = resolve(root, 'test/fixtures/cql_fhir_r4_allergy_intolerance_retrieval_corpus.json');
  return createHash('sha256').update(readFileSync(fixturePath)).digest('hex');
}

export { EXPECTED_CASE_IDS as fixedAllergyIntoleranceCaseIds };
