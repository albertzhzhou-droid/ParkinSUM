import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  medicationStatementCqlSource,
  medicationStatementResultNames,
  scopeMedicationStatementBundle,
  validateMedicationStatementCorpus,
} from './cql_fhir_medication_statement_retrieval_contract.mjs';
import {
  CqlTranslator,
  LibraryManager,
  ModelManager,
  createModelInfoProvider,
  stringAsSource,
} from '@cqframework/cql/cql-to-elm';
import { SystemModelInfoProvider } from '@cqframework/cql/cql';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const fixturePath = path.join(root, 'test/fixtures/cql_fhir_r4_medication_statement_retrieval_corpus.json');
const fixtureBytes = readFileSync(fixturePath);
const fixture = validateMedicationStatementCorpus(JSON.parse(fixtureBytes.toString('utf8')));
const packageJson = JSON.parse(readFileSync(path.join(root, 'package.json'), 'utf8'));
const require = createRequire(import.meta.url);
const CqlExecution = require('cql-execution');
const CqlExecFhir = require('cql-exec-fhir');
const libraryName = 'ParkinSUM_FHIR_MedicationStatement_Retrieval';
const resultNames = Object.freeze({
  hasAnyStatement: 'HasAnyStatement',
  hasActiveStatement: 'HasActiveStatement',
  hasStoppedStatement: 'HasStoppedStatement',
  hasUnknownStatement: 'HasUnknownStatement',
  hasNotTakenStatement: 'HasNotTakenStatement',
  hasCompletedStatement: 'HasCompletedStatement',
  hasEnteredInErrorStatement: 'HasEnteredInErrorStatement',
  hasIntendedStatement: 'HasIntendedStatement',
  hasOnHoldStatement: 'HasOnHoldStatement',
});

function compileMedicationStatementLibrary() {
  const versionPins = {
    '@cqframework/cql': '5.3.0',
    'cql-exec-fhir': '2.1.6',
    'cql-execution': '3.3.2',
  };
  for (const [dependency, expectedVersion] of Object.entries(versionPins)) {
    if (packageJson.devDependencies?.[dependency] !== expectedVersion) {
      throw new Error(`unreviewed_dependency_version:${dependency}`);
    }
  }

  const modelInfoPath = path.join(root, 'node_modules/cql-exec-fhir/lib/modelInfos/fhir-modelinfo-4.0.1.xml');
  const modelInfoXml = readFileSync(modelInfoPath, 'utf8');
  const modelManager = new ModelManager();
  modelManager.modelInfoLoader.registerModelInfoProvider(new SystemModelInfoProvider());
  modelManager.modelInfoLoader.registerModelInfoProvider(
    createModelInfoProvider((name, namespace, version) => (
      name === 'FHIR' && version === '4.0.1' ? stringAsSource(modelInfoXml) : null
    )),
  );
  const libraryManager = new LibraryManager(modelManager);
  const translator = CqlTranslator.fromText(medicationStatementCqlSource, libraryManager);
  const errors = translator.errors.asJsReadonlyArrayView();
  if (errors.length > 0 || translator.toELM() == null) {
    throw new Error(`fhir_medication_statement_cql_translation:${errors.map(String).join('; ')}`);
  }
  return new CqlExecution.Executor(new CqlExecution.Library(JSON.parse(translator.toJson())));
}

async function evaluateCase(executor, testCase) {
  const scoped = scopeMedicationStatementBundle(testCase.bundle, testCase.patientContextId);
  const patientSource = CqlExecFhir.PatientSource.FHIRv401();
  if (patientSource.version !== '4.0.1') throw new Error('unexpected_fhir_patient_source_version');
  patientSource.loadBundles([scoped.bundle]);
  const evaluation = await executor.exec(patientSource);
  const patients = Object.values(evaluation.patientResults ?? {});
  if (patients.length !== 1) throw new Error(`fhir_medication_statement_patient_count:${testCase.id}`);
  const outcomes = {};
  for (const [key, expressionName] of Object.entries(resultNames)) {
    if (typeof patients[0]?.[expressionName] !== 'boolean') {
      throw new Error(`fhir_medication_statement_result_shape:${testCase.id}:${expressionName}`);
    }
    outcomes[key] = patients[0][expressionName];
  }
  return {
    id: testCase.id,
    expectedOutcomes: testCase.expectedOutcomes,
    outcomes,
    foreignStatementsDropped: scoped.foreignStatementsDropped,
    outcomeMatched: JSON.stringify(outcomes) === JSON.stringify(testCase.expectedOutcomes),
  };
}

export async function runMedicationStatementRetrievalDifferential() {
  validateMedicationStatementCorpus(fixture);
  const executor = compileMedicationStatementLibrary();
  const cases = [];
  for (const testCase of fixture.cases) {
    const result = await evaluateCase(executor, testCase);
    if (!result.outcomeMatched) {
      throw new Error(`fhir_medication_statement_cql_expectation_mismatch:${testCase.id}`);
    }
    cases.push(result);
  }
  return {
    schemaVersion: 1,
    scope: fixture.scope,
    fhirVersion: fixture.fhirVersion,
    context: fixture.context,
    cqlSourceSha256: createHash('sha256').update(medicationStatementCqlSource).digest('hex'),
    fixtureSha256: createHash('sha256').update(fixtureBytes).digest('hex'),
    translator: `@cqframework/cql@${packageJson.devDependencies['@cqframework/cql']}`,
    executionPath: `cql-execution@${packageJson.devDependencies['cql-execution']} + cql-exec-fhir@${packageJson.devDependencies['cql-exec-fhir']}`,
    resultNames: medicationStatementResultNames,
    caseCount: cases.length,
    outcomeParityCount: cases.filter((testCase) => testCase.outcomeMatched).length,
    cases,
    networkRequestMade: false,
    realPatientDataUsed: false,
  };
}

export { fixture as medicationStatementFixture };
