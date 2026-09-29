import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  medicationDispenseCqlSource,
  medicationDispenseOutcomeKeys,
  scopeMedicationDispenseBundle,
  validateMedicationDispenseCorpus,
} from './cql_fhir_medication_dispense_retrieval_contract.mjs';
import {
  CqlTranslator,
  LibraryManager,
  ModelManager,
  createModelInfoProvider,
  stringAsSource,
} from '@cqframework/cql/cql-to-elm';
import { SystemModelInfoProvider } from '@cqframework/cql/cql';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const fixturePath = path.join(root, 'test/fixtures/cql_fhir_r4_medication_dispense_retrieval_corpus.json');
const fixtureBytes = readFileSync(fixturePath);
const fixture = validateMedicationDispenseCorpus(JSON.parse(fixtureBytes.toString('utf8')));
const packageJson = JSON.parse(readFileSync(path.join(root, 'package.json'), 'utf8'));
const require = createRequire(import.meta.url);
const CqlExecution = require('cql-execution');
const CqlExecFhir = require('cql-exec-fhir');
const libraryName = 'ParkinSUM_FHIR_MedicationDispense_Retrieval';

function compileMedicationDispenseLibrary() {
  const versionPins = {
    '@cqframework/cql': '5.3.0',
    'cql-exec-fhir': '2.1.6',
    'cql-execution': '3.3.2',
  };
  for (const [dependency, expectedVersion] of Object.entries(versionPins)) {
    if (packageJson.devDependencies?.[dependency] !== expectedVersion) {
      throw new Error('unreviewed_dependency_version:' + dependency);
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
  const translator = CqlTranslator.fromText(medicationDispenseCqlSource, libraryManager);
  const errors = translator.errors.asJsReadonlyArrayView();
  if (errors.length > 0 || translator.toELM() == null) {
    throw new Error('fhir_medication_dispense_cql_translation:' + errors.map(String).join('; '));
  }
  return new CqlExecution.Executor(new CqlExecution.Library(JSON.parse(translator.toJson())));
}

async function evaluateCase(executor, testCase) {
  const scoped = scopeMedicationDispenseBundle(testCase.bundle, testCase.patientContextId);
  const patientSource = CqlExecFhir.PatientSource.FHIRv401();
  if (patientSource.version !== '4.0.1') throw new Error('unexpected_fhir_patient_source_version');
  patientSource.loadBundles([scoped.bundle]);
  const evaluation = await executor.exec(patientSource);
  const patients = Object.values(evaluation.patientResults ?? {});
  if (patients.length !== 1) throw new Error('fhir_medication_dispense_patient_count:' + testCase.id);

  const outcomes = {};
  for (const name of medicationDispenseOutcomeKeys) {
    const expressionName = name[0].toUpperCase() + name.slice(1);
    if (typeof patients[0]?.[expressionName] !== 'boolean') {
      throw new Error('fhir_medication_dispense_result_shape:' + testCase.id + ':' + expressionName);
    }
    outcomes[name] = patients[0][expressionName];
  }
  return {
    id: testCase.id,
    expectedOutcomes: testCase.expectedOutcomes,
    outcomes,
    foreignDispensesDropped: scoped.foreignDispensesDropped,
    outcomeMatched: JSON.stringify(outcomes) === JSON.stringify(testCase.expectedOutcomes),
  };
}

export async function runMedicationDispenseRetrievalDifferential() {
  validateMedicationDispenseCorpus(fixture);
  const executor = compileMedicationDispenseLibrary();
  const cases = [];
  for (const testCase of fixture.cases) {
    const result = await evaluateCase(executor, testCase);
    if (!result.outcomeMatched) {
      throw new Error('fhir_medication_dispense_cql_expectation_mismatch:' + testCase.id);
    }
    cases.push(result);
  }
  return {
    schemaVersion: 1,
    scope: fixture.scope,
    fhirVersion: fixture.fhirVersion,
    context: fixture.context,
    cqlSourceSha256: createHash('sha256').update(medicationDispenseCqlSource).digest('hex'),
    fixtureSha256: createHash('sha256').update(fixtureBytes).digest('hex'),
    translator: '@cqframework/cql@' + packageJson.devDependencies['@cqframework/cql'],
    executionPath: 'cql-execution@' + packageJson.devDependencies['cql-execution'] +
      ' + cql-exec-fhir@' + packageJson.devDependencies['cql-exec-fhir'],
    resultNames: medicationDispenseOutcomeKeys,
    caseCount: cases.length,
    outcomeParityCount: cases.filter((testCase) => testCase.outcomeMatched).length,
    cases,
    networkRequestMade: false,
    realPatientDataUsed: false,
  };
}

export { fixture as medicationDispenseFixture };

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.stdout.write(JSON.stringify(await runMedicationDispenseRetrievalDifferential(), null, 2) + '\n');
}
