import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { projectCqlDifferentialInformationCard } from './cds_hooks_cql_outcome_projection.mjs';
import { buildFhirCqlHooksProjectionReport } from './cds_hooks_fhir_cql_retrieval_projection.mjs';
import { buildFhirObservationCqlHooksProjectionReport } from './cds_hooks_fhir_observation_projection.mjs';
import {
  runCqfJvmDifferential,
  runCqfJvmFhirDifferential,
} from './cqf_jvm_cql_differential.mjs';
import { runCqfJvmObservationTerminologyDifferential } from './cqf_jvm_observation_terminology_differential.mjs';
import { runCqfJvmMedicationStatementDifferential } from './cqf_jvm_medication_statement_retrieval_differential.mjs';
import { runCqfJvmMedicationRequestDifferential } from './cqf_jvm_medication_request_retrieval_differential.mjs';
import { runCqfJvmMedicationDispenseDifferential } from './cqf_jvm_medication_dispense_retrieval_differential.mjs';
import { runCqfJvmMedicationAdministrationDifferential } from './cqf_jvm_medication_administration_retrieval_differential.mjs';
import { runCqfJvmAllergyIntoleranceDifferential } from './cqf_jvm_allergy_intolerance_retrieval_differential.mjs';
import { runCqfJvmConditionStatusDifferential } from './cqf_jvm_condition_status_retrieval_differential.mjs';
import { runConditionRetrievalDifferential } from './cql_fhir_condition_retrieval.mjs';
import { runMedicationDispenseRetrievalDifferential } from './cql_fhir_medication_dispense_retrieval.mjs';
import { runMedicationAdministrationRetrievalDifferential } from './cql_fhir_medication_administration_retrieval.mjs';
import { runAllergyIntoleranceRetrievalDifferential } from './cql_fhir_allergy_intolerance_retrieval.mjs';
import { runConditionStatusRetrievalDifferential } from './cql_fhir_condition_status_retrieval.mjs';
import { runObservationRetrievalDifferential } from './cql_fhir_observation_retrieval_differential.mjs';
import { runMedicationStatementRetrievalDifferential } from './cql_fhir_medication_statement_retrieval.mjs';
import { validateMedicationStatementCorpus } from './cql_fhir_medication_statement_retrieval_contract.mjs';
import { runMedicationRequestRetrievalDifferential } from './cql_fhir_medication_request_retrieval.mjs';
import { validateMedicationRequestCorpus } from './cql_fhir_medication_request_retrieval_contract.mjs';
import { validateMedicationDispenseCorpus } from './cql_fhir_medication_dispense_retrieval_contract.mjs';
import { validateMedicationAdministrationCorpus } from './cql_fhir_medication_administration_retrieval_contract.mjs';
import { validateAllergyIntoleranceCorpus } from './cql_fhir_allergy_intolerance_retrieval_contract.mjs';
import { validateConditionStatusCorpus } from './cql_fhir_condition_status_retrieval_contract.mjs';
import {
  CqlTranslator,
  LibraryManager,
  ModelManager,
  createLibrarySourceProvider,
  stringAsSource,
} from '@cqframework/cql/cql-to-elm';
import { SystemModelInfoProvider } from '@cqframework/cql/cql';
import { CqlEngine, Environment, EvaluationParams } from '@cqframework/cql/engine';

const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const require = createRequire(import.meta.url);
const CqlExecution = require('cql-execution');
const packageJson = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8'));
const corpusPath = resolve(root, 'test/fixtures/cql_rule_differential_corpus.json');
const fhirCorpusPath = resolve(root, 'test/fixtures/cql_fhir_r4_retrieval_corpus.json');
const fhirArtifactBindingPath = resolve(root, 'test/fixtures/cql_fhir_r4_artifact_binding.json');
const fhirObservationCorpusPath = resolve(root, 'test/fixtures/cql_fhir_r4_observation_retrieval_corpus.json');
const fhirMedicationStatementCorpusPath = resolve(root, 'test/fixtures/cql_fhir_r4_medication_statement_retrieval_corpus.json');
const fhirMedicationRequestCorpusPath = resolve(root, 'test/fixtures/cql_fhir_r4_medication_request_retrieval_corpus.json');
const fhirMedicationDispenseCorpusPath = resolve(root, 'test/fixtures/cql_fhir_r4_medication_dispense_retrieval_corpus.json');
const fhirMedicationAdministrationCorpusPath = resolve(root, 'test/fixtures/cql_fhir_r4_medication_administration_retrieval_corpus.json');
const fhirAllergyIntoleranceCorpusPath = resolve(root, 'test/fixtures/cql_fhir_r4_allergy_intolerance_retrieval_corpus.json');
const fhirConditionStatusCorpusPath = resolve(root, 'test/fixtures/cql_fhir_r4_condition_status_retrieval_corpus.json');
const corpus = JSON.parse(readFileSync(corpusPath, 'utf8'));
if (corpus.schemaVersion !== 2 || corpus.scope !== 'synthetic-engineering-comparison' || !Array.isArray(corpus.cases)) {
  throw new Error('Unsupported CQL differential corpus contract.');
}
const corpusSha256 = createHash('sha256').update(readFileSync(corpusPath)).digest('hex');
const fhirCorpus = JSON.parse(readFileSync(fhirCorpusPath, 'utf8'));
if (fhirCorpus.schemaVersion !== 2 || fhirCorpus.scope !== 'synthetic-fhir-r4-retrieval' ||
    fhirCorpus.fhirVersion !== '4.0.1' || fhirCorpus.context !== 'Patient' ||
    fhirCorpus.expression !== 'exists([Condition])' || !Array.isArray(fhirCorpus.cases) || fhirCorpus.cases.length !== 3) {
  throw new Error('Unsupported synthetic FHIR R4 retrieval corpus contract.');
}
const fhirCorpusSha256 = createHash('sha256').update(readFileSync(fhirCorpusPath)).digest('hex');
const fhirObservationCorpus = JSON.parse(readFileSync(fhirObservationCorpusPath, 'utf8'));
const expectedFHIRObservationCaseIds = [
  'observation_present',
  'observation_absent',
  'observation_foreign_subject',
  'observation_non_member_code',
  'observation_foreign_code_system',
  'observation_system_version_mismatch',
];
if (fhirObservationCorpus.schemaVersion !== 2 ||
    fhirObservationCorpus.scope !== 'synthetic-fhir-r4-observation-retrieval-and-local-terminology' ||
    fhirObservationCorpus.fhirVersion !== '4.0.1' || fhirObservationCorpus.context !== 'Patient' ||
    fhirObservationCorpus.expression !== 'exists([Observation]) + code in Synthetic Observation Codes' ||
    !Array.isArray(fhirObservationCorpus.cases) || fhirObservationCorpus.cases.length !== expectedFHIRObservationCaseIds.length ||
    fhirObservationCorpus.cases.some((testCase, index) => testCase.id !== expectedFHIRObservationCaseIds[index])) {
  throw new Error('Unsupported fixed synthetic FHIR Observation terminology corpus contract.');
}
const fhirObservationCorpusSha256 = createHash('sha256')
  .update(readFileSync(fhirObservationCorpusPath))
  .digest('hex');
const fhirMedicationStatementCorpus = validateMedicationStatementCorpus(
  JSON.parse(readFileSync(fhirMedicationStatementCorpusPath, 'utf8')),
);
const fhirMedicationStatementCorpusSha256 = createHash('sha256')
  .update(readFileSync(fhirMedicationStatementCorpusPath))
  .digest('hex');
const fhirMedicationRequestCorpus = validateMedicationRequestCorpus(
  JSON.parse(readFileSync(fhirMedicationRequestCorpusPath, 'utf8')),
);
const fhirMedicationRequestCorpusSha256 = createHash('sha256')
  .update(readFileSync(fhirMedicationRequestCorpusPath))
  .digest('hex');
const fhirMedicationDispenseCorpus = validateMedicationDispenseCorpus(
  JSON.parse(readFileSync(fhirMedicationDispenseCorpusPath, 'utf8')),
);
const fhirMedicationDispenseCorpusSha256 = createHash('sha256')
  .update(readFileSync(fhirMedicationDispenseCorpusPath))
  .digest('hex');
const fhirMedicationAdministrationCorpus = validateMedicationAdministrationCorpus(
  JSON.parse(readFileSync(fhirMedicationAdministrationCorpusPath, 'utf8')),
);
const fhirMedicationAdministrationCorpusSha256 = createHash('sha256')
  .update(readFileSync(fhirMedicationAdministrationCorpusPath))
  .digest('hex');
const fhirAllergyIntoleranceCorpus = validateAllergyIntoleranceCorpus(
  JSON.parse(readFileSync(fhirAllergyIntoleranceCorpusPath, 'utf8')),
);
const fhirAllergyIntoleranceCorpusSha256 = createHash('sha256')
  .update(readFileSync(fhirAllergyIntoleranceCorpusPath))
  .digest('hex');
const fhirConditionStatusCorpus = validateConditionStatusCorpus(
  JSON.parse(readFileSync(fhirConditionStatusCorpusPath, 'utf8')),
);
const fhirConditionStatusCorpusSha256 = createHash('sha256')
  .update(readFileSync(fhirConditionStatusCorpusPath))
  .digest('hex');
const fhirArtifactBindingSha256 = createHash('sha256')
  .update(readFileSync(fhirArtifactBindingPath))
  .digest('hex');
const cqlPackage = '@cqframework/cql@5.3.0';
const cqlJvmPackage = 'org.cqframework:engine@5.3.0';
const cqlExecutionPackage = `cql-execution@${packageJson.devDependencies['cql-execution']}`;
const expectedGoogleCqlPackage = 'github.com/google/cql@v0.0.3-0.20260814184421-b9169ccd54a3';

function sameBooleanMap(left, right) {
  if (!left || !right || typeof left !== 'object' || typeof right !== 'object' ||
      Object.keys(left).length !== Object.keys(right).length) return false;
  return Object.entries(right).every(([key, value]) => left[key] === value);
}

function runDart() {
  const dart = process.env.DART_BIN || 'dart';
  const result = spawnSync(
    dart,
    [
      '--suppress-analytics',
      'run',
      '--verbosity=error',
      'tool/run_cql_rule_differential_dart.dart',
      corpusPath,
    ],
    {
      cwd: root,
      encoding: 'utf8',
      maxBuffer: 1024 * 1024,
      env: { ...process.env, DASH__SUPPRESS_ANALYTICS: 'true' },
    },
  );
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`Dart runtime comparison failed (${result.status}):\n${result.stderr || result.stdout}`);
  }
  const lines = result.stdout.trim().split(/\r?\n/);
  return JSON.parse(lines.at(-1));
}

function runGoogleCql() {
  const go = process.env.GO_BIN || 'go';
  const cwd = resolve(root, 'tool/google_cql_differential');
  const tests = spawnSync(
    go,
    ['test', '-mod=readonly', './...'],
    { cwd, encoding: 'utf8', maxBuffer: 1024 * 1024 },
  );
  if (tests.error?.code === 'ENOENT') {
    throw new Error('Go 1.26 or later is required for the Google CQL check; install Go or set GO_BIN.');
  }
  if (tests.error) throw tests.error;
  if (tests.status !== 0) {
    throw new Error(`Google CQL development tests failed (${tests.status}):\n${tests.stderr || tests.stdout}`);
  }
  const result = spawnSync(
    go,
    ['run', '-mod=readonly', '.', corpusPath, fhirCorpusPath, fhirArtifactBindingPath, fhirObservationCorpusPath, fhirMedicationStatementCorpusPath, fhirMedicationRequestCorpusPath, fhirMedicationDispenseCorpusPath, fhirMedicationAdministrationCorpusPath, fhirAllergyIntoleranceCorpusPath, fhirConditionStatusCorpusPath],
    {
      cwd,
      encoding: 'utf8',
      maxBuffer: 1024 * 1024,
    },
  );
  if (result.error?.code === 'ENOENT') {
    throw new Error('Go 1.26 or later is required for the Google CQL check; install Go or set GO_BIN.');
  }
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`Google CQL runtime comparison failed (${result.status}):\n${result.stderr || result.stdout}`);
  }
  const lines = result.stdout.trim().split(/\r?\n/);
  if (lines.length === 0 || lines.at(-1) === '') {
    throw new Error('Google CQL runtime comparison returned no JSON report.');
  }
  const report = JSON.parse(lines.at(-1));
  if (report.schemaVersion !== 17 || report.status !== 'passed' || report.caseCount !== corpus.cases.length ||
      report.engine !== expectedGoogleCqlPackage || !Array.isArray(report.results)) {
    throw new Error('Google CQL runtime report does not match the pinned engine and corpus contract.');
  }
  const rows = new Map(report.results.map((row) => [row.id, row]));
  if (rows.size !== corpus.cases.length || report.results.length !== corpus.cases.length) {
    throw new Error('Google CQL result count or identities do not match the corpus.');
  }
  for (const row of report.results) {
    if (row.status !== 'passed' || row.outcomeMatched !== true || row.diagnosticsMatched !== true) {
      throw new Error(`Google CQL did not pass case ${row.id}: ${row.failure || row.status}`);
    }
  }
  const fhir = report.fhirR4Retrieval;
  const expectedFhirCases = new Map(fhirCorpus.cases.map((testCase) => [testCase.id, testCase]));
  if (!fhir || fhir.schemaVersion !== 1 || fhir.status !== 'passed' ||
      fhir.fhirVersion !== fhirCorpus.fhirVersion || fhir.context !== fhirCorpus.context ||
      fhir.expression !== fhirCorpus.expression || fhir.caseCount !== expectedFhirCases.size ||
      fhir.outcomeParityCount !== expectedFhirCases.size ||
      fhir.diagnosticParityCount !== expectedFhirCases.size || !Array.isArray(fhir.results) ||
      fhir.results.length !== expectedFhirCases.size) {
    throw new Error('Google CQL FHIR R4 retrieval report does not match the synthetic corpus contract.');
  }
  const fhirRows = new Map(fhir.results.map((row) => [row.id, row]));
  if (fhirRows.size !== expectedFhirCases.size) {
    throw new Error('Google CQL FHIR result identities do not match the synthetic corpus.');
  }
  for (const [id, testCase] of expectedFhirCases) {
    const row = fhirRows.get(id);
    if (!row || row.status !== 'passed' || row.outcomeMatched !== true ||
        row.diagnosticsMatched !== true || row.result !== testCase.expectedCql ||
        JSON.stringify(row.errors ?? []) !== JSON.stringify(testCase.expectedResponseErrors) ||
        JSON.stringify(row.warnings ?? []) !== JSON.stringify(testCase.expectedResponseWarnings)) {
      throw new Error(`Google CQL FHIR retrieval differs from the fixture for ${id}: ${row?.failure || row?.status || 'missing result'}`);
    }
  }
  const artifact = report.fhirR4ArtifactBinding;
  const expectedArtifactTitles = ['Synthetic Baseline', 'Synthetic Alternative'];
  if (!artifact || artifact.schemaVersion !== 8 || artifact.status !== 'passed' ||
      artifact.fhirVersion !== '4.0.1' || artifact.questionnaireId !== 'synthetic-cql-questionnaire' ||
      artifact.planDefinitionId !== 'synthetic-cql-plan-definition' ||
      artifact.libraryCanonical !== 'https://example.org/fhir/Library/ParkinSUMSyntheticQuestionnaireLogic|1.0.0' ||
      artifact.planDefinitionLibraryCanonical !== artifact.libraryCanonical ||
      artifact.libraryVersion !== '1.0.0' || artifact.context !== 'Patient' ||
      artifact.planDefinitionConditionCount !== 2 || artifact.boundPlanDefinitionConditionCount !== 2 ||
      JSON.stringify(artifact.planDefinitionConditionTitles) !== JSON.stringify([
        'Synthetic Condition Present',
        'Synthetic Observation Present',
      ]) ||
      artifact.expressionCount !== expectedArtifactTitles.length ||
      artifact.boundExpressionCount !== expectedArtifactTitles.length ||
      JSON.stringify(artifact.expressionTitles) !== JSON.stringify(expectedArtifactTitles) ||
      artifact.includedLibraryCount !== 1 || artifact.resolvedIncludedLibraryCount !== 1 ||
      JSON.stringify(artifact.includedLibraryCanonicals) !== JSON.stringify([
        'https://example.org/fhir/Library/ParkinSUMSyntheticQuestionnaireSharedLogic|1.0.0',
      ]) ||
      artifact.outputParameterCount !== 6 || artifact.resolvedOutputParameterCount !== 6 ||
      artifact.dataRequirementCount !== 4 || artifact.resolvedDataRequirementCount !== 4 ||
      JSON.stringify(artifact.scenarioResourceTypes) !== JSON.stringify(['Condition', 'Observation']) ||
      artifact.scenarioCount !== 6 || artifact.scenarioOutcomeMatchCount !== 6 ||
      artifact.foreignResourceDropCount !== 2 ||
      !Array.isArray(artifact.scenarios) || artifact.scenarios.length !== 6 ||
      JSON.stringify(artifact.scenarios.map((scenario) => [scenario.conditionTitle, scenario.resourceType,
        scenario.label, scenario.expectedApplicable, scenario.applicable,
        scenario.foreignResourceDropCount, scenario.outcomeMatched])) !== JSON.stringify([
        ['Synthetic Condition Present', 'Condition', 'matching_resource', true, true, 0, true],
        ['Synthetic Condition Present', 'Condition', 'resource_absent', false, false, 0, true],
        ['Synthetic Condition Present', 'Condition', 'foreign_subject_resource', false, false, 1, true],
        ['Synthetic Observation Present', 'Observation', 'matching_resource', true, true, 0, true],
        ['Synthetic Observation Present', 'Observation', 'resource_absent', false, false, 0, true],
        ['Synthetic Observation Present', 'Observation', 'foreign_subject_resource', false, false, 1, true],
      ]) ||
      artifact.actionScenarioCount !== 9 || artifact.actionScenarioOutcomeMatchCount !== 9 ||
      !Array.isArray(artifact.actionScenarios) || artifact.actionScenarios.length !== 9 ||
      JSON.stringify(artifact.actionScenarios.map((scenario) => [
        scenario.conditionScenario, scenario.observationScenario,
        scenario.conditionApplicable, scenario.observationApplicable,
        scenario.expectedActionApplicable, scenario.actionApplicable,
        scenario.foreignResourceDropCount, scenario.outcomeMatched,
      ])) !== JSON.stringify([
        ['matching_resource', 'matching_resource', true, true, true, true, 0, true],
        ['matching_resource', 'resource_absent', true, false, false, false, 0, true],
        ['matching_resource', 'foreign_subject_resource', true, false, false, false, 1, true],
        ['resource_absent', 'matching_resource', false, true, false, false, 0, true],
        ['resource_absent', 'resource_absent', false, false, false, false, 0, true],
        ['resource_absent', 'foreign_subject_resource', false, false, false, false, 1, true],
        ['foreign_subject_resource', 'matching_resource', false, true, false, false, 1, true],
        ['foreign_subject_resource', 'resource_absent', false, false, false, false, 1, true],
        ['foreign_subject_resource', 'foreign_subject_resource', false, false, false, false, 2, true],
      ]) ||
      artifact.cqlParser !== expectedGoogleCqlPackage) {
    throw new Error('Google CQL FHIR R4 Questionnaire/PlanDefinition bindings and generated scenarios do not match the synthetic artifact contract.');
  }
  const observation = report.fhirR4ObservationTerminology;
  if (!observation || observation.schemaVersion !== 1 || observation.status !== 'passed' ||
      observation.fhirVersion !== fhirObservationCorpus.fhirVersion ||
      observation.context !== fhirObservationCorpus.context ||
      observation.expression !== fhirObservationCorpus.expression ||
      observation.valueSetCanonical !== 'urn:oid:1.2.3.4.5.6.7' ||
      observation.valueSetVersion !== '2026-09' ||
      observation.caseCount !== fhirObservationCorpus.cases.length ||
      observation.outcomeParityCount !== fhirObservationCorpus.cases.length ||
      observation.runtimeMembershipParityCount !== fhirObservationCorpus.cases.length ||
      observation.versionAwareExpectationCount !== fhirObservationCorpus.cases.length - 1 ||
      !Array.isArray(observation.results) || observation.results.length !== fhirObservationCorpus.cases.length) {
    throw new Error('Google CQL FHIR R4 Observation terminology report does not match the six-case synthetic contract.');
  }
  const observationRows = new Map(observation.results.map((row) => [row.id, row]));
  if (observationRows.size !== fhirObservationCorpus.cases.length) {
    throw new Error('Google CQL Observation terminology result identities do not match the fixed corpus.');
  }
  for (const testCase of fhirObservationCorpus.cases) {
    const row = observationRows.get(testCase.id);
    const strictMembershipMatch = row?.runtimeValueSetMembership === testCase.expectedVersionAwareMembership;
    if (!row || row.status !== 'passed' || row.result !== testCase.expectedResult ||
        row.runtimeValueSetMembership !== testCase.expectedRuntimeValueSetMembership ||
        row.expectedResult !== testCase.expectedResult ||
        row.expectedRuntimeValueSetMembership !== testCase.expectedRuntimeValueSetMembership ||
        row.expectedVersionAwareMembership !== testCase.expectedVersionAwareMembership ||
        row.outcomeMatched !== true || row.runtimeMembershipMatched !== true ||
        row.versionAwareExpectationMatched !== strictMembershipMatch) {
      throw new Error(`Google CQL Observation terminology differs from the fixed corpus for ${testCase.id}: ${row?.failure || row?.status || 'missing result'}`);
    }
  }
  const versionMismatch = observationRows.get('observation_system_version_mismatch');
  if (versionMismatch.runtimeValueSetMembership !== true ||
      versionMismatch.expectedVersionAwareMembership !== false ||
      versionMismatch.versionAwareExpectationMatched !== false) {
    throw new Error('Google CQL Coding.version behavior drifted from the pinned local provider observation.');
  }
  const medicationStatement = report.fhirR4MedicationStatementRetrieval;
  const expectedMedicationCases = fhirMedicationStatementCorpus.cases;
  if (!medicationStatement || medicationStatement.schemaVersion !== 1 || medicationStatement.status !== 'passed' ||
      medicationStatement.fhirVersion !== '4.0.1' || medicationStatement.context !== 'Patient' ||
      medicationStatement.caseCount !== expectedMedicationCases.length ||
      medicationStatement.outcomeParityCount !== expectedMedicationCases.length ||
      !Array.isArray(medicationStatement.results) || medicationStatement.results.length !== expectedMedicationCases.length) {
    throw new Error('Google CQL FHIR R4 MedicationStatement report does not match the ten-case synthetic contract.');
  }
  const medicationRows = new Map(medicationStatement.results.map((row) => [row.id, row]));
  if (medicationRows.size !== expectedMedicationCases.length) {
    throw new Error('Google CQL MedicationStatement result identities do not match the fixed corpus.');
  }
  for (const testCase of expectedMedicationCases) {
    const row = medicationRows.get(testCase.id);
    const expectedForeignDrop = testCase.id === 'foreign_subject_statement' ? 1 : 0;
    if (!row || row.status !== 'passed' || row.outcomeMatched !== true ||
        JSON.stringify(row.outcomes) !== JSON.stringify(testCase.expectedOutcomes) ||
        row.foreignStatementsDropped !== expectedForeignDrop) {
      throw new Error(`Google CQL MedicationStatement retrieval differs from the fixed corpus for ${testCase.id}: ${row?.failure || row?.status || 'missing result'}`);
    }
  }
  const medicationRequest = report.fhirR4MedicationRequestRetrieval;
  const expectedRequestCases = fhirMedicationRequestCorpus.cases;
  if (!medicationRequest || medicationRequest.schemaVersion !== 1 || medicationRequest.status !== 'passed' ||
      medicationRequest.fhirVersion !== '4.0.1' || medicationRequest.context !== 'Patient' ||
      medicationRequest.caseCount !== expectedRequestCases.length ||
      medicationRequest.outcomeParityCount !== expectedRequestCases.length ||
      !Array.isArray(medicationRequest.results) || medicationRequest.results.length !== expectedRequestCases.length) {
    throw new Error('Google CQL FHIR R4 MedicationRequest report does not match the 18-case synthetic contract.');
  }
  const medicationRequestRows = new Map(medicationRequest.results.map((row) => [row.id, row]));
  if (medicationRequestRows.size !== expectedRequestCases.length) {
    throw new Error('Google CQL MedicationRequest result identities do not match the fixed corpus.');
  }
  for (const testCase of expectedRequestCases) {
    const row = medicationRequestRows.get(testCase.id);
    const expectedForeignDrop = testCase.id === 'foreign_subject_request' ? 1 : 0;
    if (!row || row.status !== 'passed' || row.outcomeMatched !== true ||
        !sameBooleanMap(row.outcomes, testCase.expectedOutcomes) ||
        row.foreignRequestsDropped !== expectedForeignDrop) {
      throw new Error(`Google CQL MedicationRequest retrieval differs from the fixed corpus for ${testCase.id}: ${row?.failure || row?.status || 'missing result'}`);
    }
  }
  const medicationDispense = report.fhirR4MedicationDispenseRetrieval;
  const expectedDispenseCases = fhirMedicationDispenseCorpus.cases;
  if (!medicationDispense || medicationDispense.schemaVersion !== 1 ||
      medicationDispense.status !== 'passed' ||
      medicationDispense.fhirVersion !== '4.0.1' ||
      medicationDispense.context !== 'Patient' ||
      medicationDispense.caseCount !== expectedDispenseCases.length ||
      medicationDispense.outcomeParityCount !== expectedDispenseCases.length ||
      !Array.isArray(medicationDispense.results) ||
      medicationDispense.results.length !== expectedDispenseCases.length) {
    throw new Error('Google CQL FHIR R4 MedicationDispense report does not match the 11-case synthetic contract.');
  }
  const medicationDispenseRows = new Map(
    medicationDispense.results.map((row) => [row.id, row]),
  );
  if (medicationDispenseRows.size !== expectedDispenseCases.length) {
    throw new Error('Google CQL MedicationDispense result identities do not match the fixed corpus.');
  }
  for (const testCase of expectedDispenseCases) {
    const row = medicationDispenseRows.get(testCase.id);
    const expectedForeignDrop = testCase.id === 'foreign_subject_dispense' ? 1 : 0;
    if (!row || row.status !== 'passed' || row.outcomeMatched !== true ||
        !sameBooleanMap(row.outcomes, testCase.expectedOutcomes) ||
        row.foreignDispensesDropped !== expectedForeignDrop) {
      throw new Error('Google CQL MedicationDispense retrieval differs from the fixed corpus for ' + testCase.id);
    }
  }
  const medicationAdministration = report.fhirR4MedicationAdministrationRetrieval;
  const expectedAdministrationCases = fhirMedicationAdministrationCorpus.cases;
  if (!medicationAdministration || medicationAdministration.schemaVersion !== 1 ||
      medicationAdministration.status !== 'passed' ||
      medicationAdministration.fhirVersion !== '4.0.1' ||
      medicationAdministration.context !== 'Patient' ||
      medicationAdministration.caseCount !== expectedAdministrationCases.length ||
      medicationAdministration.outcomeParityCount !== expectedAdministrationCases.length ||
      !Array.isArray(medicationAdministration.results) ||
      medicationAdministration.results.length !== expectedAdministrationCases.length) {
    throw new Error('Google CQL FHIR R4 MedicationAdministration report does not match the nine-case synthetic contract.');
  }
  const medicationAdministrationRows = new Map(
    medicationAdministration.results.map((row) => [row.id, row]),
  );
  if (medicationAdministrationRows.size !== expectedAdministrationCases.length) {
    throw new Error('Google CQL MedicationAdministration result identities do not match the fixed corpus.');
  }
  for (const testCase of expectedAdministrationCases) {
    const row = medicationAdministrationRows.get(testCase.id);
    const expectedForeignDrop = testCase.id === 'foreign_subject_administration' ? 1 : 0;
    if (!row || row.status !== 'passed' || row.outcomeMatched !== true ||
        !sameBooleanMap(row.outcomes, testCase.expectedOutcomes) ||
        row.foreignAdministrationsDropped !== expectedForeignDrop) {
      throw new Error('Google CQL MedicationAdministration retrieval differs from the fixed corpus for ' + testCase.id);
    }
  }
  const allergyIntolerance = report.fhirR4AllergyIntoleranceRetrieval;
  const expectedAllergyCases = fhirAllergyIntoleranceCorpus.cases;
  if (!allergyIntolerance || allergyIntolerance.schemaVersion !== 1 ||
      allergyIntolerance.status !== 'passed' || allergyIntolerance.fhirVersion !== '4.0.1' ||
      allergyIntolerance.context !== 'Patient' || allergyIntolerance.caseCount !== expectedAllergyCases.length ||
      allergyIntolerance.outcomeParityCount !== expectedAllergyCases.length ||
      !Array.isArray(allergyIntolerance.results) || allergyIntolerance.results.length !== expectedAllergyCases.length) {
    throw new Error('Google CQL FHIR R4 AllergyIntolerance report does not match the six-case synthetic contract.');
  }
  const allergyRows = new Map(allergyIntolerance.results.map((row) => [row.id, row]));
  if (allergyRows.size !== expectedAllergyCases.length) {
    throw new Error('Google CQL AllergyIntolerance result identities do not match the fixed corpus.');
  }
  for (const testCase of expectedAllergyCases) {
    const row = allergyRows.get(testCase.id);
    const expectedForeignDrop = testCase.id === 'foreign_subject_allergy_intolerance' ? 1 : 0;
    if (!row || row.status !== 'passed' || row.outcomeMatched !== true ||
        !sameBooleanMap(row.outcomes, testCase.expectedOutcomes) ||
        row.foreignAllergyIntolerancesDropped !== expectedForeignDrop) {
      throw new Error('Google CQL AllergyIntolerance retrieval differs from the fixed corpus for ' + testCase.id);
    }
  }
  const conditionStatus = report.fhirR4ConditionStatusRetrieval;
  const expectedConditionStatusCases = fhirConditionStatusCorpus.cases;
  if (!conditionStatus || conditionStatus.schemaVersion !== 1 || conditionStatus.status !== 'passed' ||
      conditionStatus.fhirVersion !== '4.0.1' || conditionStatus.context !== 'Patient' ||
      conditionStatus.caseCount !== expectedConditionStatusCases.length ||
      conditionStatus.outcomeParityCount !== expectedConditionStatusCases.length ||
      !Array.isArray(conditionStatus.results) || conditionStatus.results.length !== expectedConditionStatusCases.length) {
    throw new Error('Google CQL FHIR R4 Condition status report does not match the nine-case synthetic contract.');
  }
  const conditionStatusRows = new Map(conditionStatus.results.map((row) => [row.id, row]));
  if (conditionStatusRows.size !== expectedConditionStatusCases.length) throw new Error('Google CQL Condition status result identities do not match the fixed corpus.');
  for (const testCase of expectedConditionStatusCases) {
    const row = conditionStatusRows.get(testCase.id);
    const expectedForeignDrop = testCase.id === 'foreign_subject_condition' ? 1 : 0;
    if (!row || row.status !== 'passed' || row.outcomeMatched !== true ||
        !sameBooleanMap(row.outcomes, testCase.expectedOutcomes) || row.foreignConditionsDropped !== expectedForeignDrop) {
      throw new Error('Google CQL Condition status retrieval differs from the fixed corpus for ' + testCase.id);
    }
  }
  return {
    engine: report.engine,
    rows,
    fhir: { ...fhir, corpusSha256: fhirCorpusSha256 },
    artifactBinding: { ...artifact, corpusSha256: fhirArtifactBindingSha256 },
    observationTerminology: { ...observation, corpusSha256: fhirObservationCorpusSha256 },
    medicationStatementRetrieval: { ...medicationStatement, corpusSha256: fhirMedicationStatementCorpusSha256 },
    medicationRequestRetrieval: { ...medicationRequest, corpusSha256: fhirMedicationRequestCorpusSha256 },
    medicationDispenseRetrieval: { ...medicationDispense, corpusSha256: fhirMedicationDispenseCorpusSha256 },
    medicationAdministrationRetrieval: {
      ...medicationAdministration,
      corpusSha256: fhirMedicationAdministrationCorpusSha256,
    },
    allergyIntoleranceRetrieval: {
      ...allergyIntolerance,
      corpusSha256: fhirAllergyIntoleranceCorpusSha256,
    },
    conditionStatusRetrieval: { ...conditionStatus, corpusSha256: fhirConditionStatusCorpusSha256 },
  };
}

async function evaluateCql(id, expression) {
  const libraryName = `ParkinSUM_${id.replaceAll(/[^A-Za-z0-9_]/g, '_')}`;
  const source = [
    `library ${libraryName} version '1.0.0'`,
    `define Result: ${expression}`,
    "define Errors: if Result is null then { 'evaluation_indeterminate' } else { }",
    "define Warnings: if Result is false then { 'criterion_not_met' } else { }",
    'define ErrorCount: Count(Errors)',
    'define FirstError: First(Errors)',
    'define WarningCount: Count(Warnings)',
    'define FirstWarning: First(Warnings)',
    '',
  ].join('\n');
  const modelManager = new ModelManager();
  modelManager.modelInfoLoader.registerModelInfoProvider(new SystemModelInfoProvider());
  const libraryManager = new LibraryManager(modelManager);
  libraryManager.librarySourceLoader.registerProvider(
    createLibrarySourceProvider((name) => name === libraryName ? stringAsSource(source) : null),
  );
  const translator = CqlTranslator.fromText(source, libraryManager);
  const errors = translator.errors.asJsReadonlyArrayView();
  if (errors.length > 0 || translator.toELM() == null) {
    throw new Error(`CQL translation failed for ${id}: ${errors.map(String).join('; ')}`);
  }
  const elm = JSON.parse(translator.toJson());

  const libraryParams = new EvaluationParams.LibraryParams.Builder();
  libraryParams.expressionsByName([
    'Result',
    'ErrorCount',
    'FirstError',
    'WarningCount',
    'FirstWarning',
  ]);
  const evaluationParams = new EvaluationParams.Builder();
  evaluationParams.libraryByName(libraryName, libraryParams.build());
  const results = new CqlEngine(new Environment(libraryManager)).evaluate(evaluationParams.build());
  if (results.hasExceptions()) {
    throw new Error(`CQL evaluation failed for ${id}: ${String(results.exceptions)}`);
  }
  const evaluated = results.onlyResultOrThrow;
  const cqlResult = cqlBooleanResult(
    evaluated.getByName('Result')?.value,
    `CQL result for ${id}`,
  );
  const cqlErrors = cqlListFromCountAndFirst(
    evaluated,
    'ErrorCount',
    'FirstError',
    `CQL Errors for ${id}`,
  );
  const cqlWarnings = cqlListFromCountAndFirst(
    evaluated,
    'WarningCount',
    'FirstWarning',
    `CQL Warnings for ${id}`,
  );

  const executionLibrary = new CqlExecution.Library(elm);
  const execution = new CqlExecution.Executor(executionLibrary);
  const syntheticPatientSource = new CqlExecution.PatientSource([
    { id: 'synthetic-cql-differential', recordType: 'Patient' },
  ]);
  const executionResults = await execution.exec(syntheticPatientSource);
  if (!Object.hasOwn(executionResults.unfilteredResults, 'Result')) {
    throw new Error(`Independent CQL runtime omitted Result for ${id}.`);
  }
  const executionValue = executionResults.unfilteredResults.Result;
  const independentCqlResult = cqlBooleanResult(
    executionValue,
    `Independent CQL result for ${id}`,
  );
  const independentCqlErrors = cqlTextList(
    executionResults.unfilteredResults.Errors,
    `Independent CQL Errors for ${id}`,
  );
  const independentCqlWarnings = cqlTextList(
    executionResults.unfilteredResults.Warnings,
    `Independent CQL Warnings for ${id}`,
  );
  return {
    cqlResult,
    independentCqlResult,
    cqlErrors,
    cqlWarnings,
    independentCqlErrors,
    independentCqlWarnings,
  };
}

function cqlBooleanResult(value, label) {
  if (value == null) return 'unknown';
  if (typeof value.value === 'boolean') return value.value ? 'true' : 'false';
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  throw new Error(`${label} was not Boolean: ${String(value)}`);
}

function cqlListFromCountAndFirst(result, countName, firstName, label) {
  const count = result.getByName(countName)?.value?.value;
  const first = result.getByName(firstName)?.value?.value ?? null;
  if (!Number.isInteger(count) || count < 0 || count > 1) {
    throw new Error(`${label} count must be an integer from zero through one.`);
  }
  if (count === 0 && first === null) return [];
  if (count === 1 && typeof first === 'string' && first.trim() !== '') {
    return [first];
  }
  throw new Error(`${label} list projection is inconsistent.`);
}

function cqlTextList(value, label) {
  if (!Array.isArray(value) || value.length > 1 ||
      value.some((item) => typeof item !== 'string' || item.trim() === '')) {
    throw new Error(`${label} must be a list of at most one non-empty string.`);
  }
  return value;
}

const dartResults = new Map(runDart().map((row) => [row.id, row]));
if (dartResults.size !== corpus.cases.length) throw new Error('Dart result count does not match the corpus.');
const {
  engine: googleCqlPackage,
  rows: googleCqlResults,
  fhir: googleCqlFhirR4Retrieval,
  artifactBinding: googleCqlFhirR4ArtifactBinding,
  observationTerminology: googleCqlFhirR4ObservationTerminology,
  medicationStatementRetrieval: googleCqlFhirR4MedicationStatementRetrieval,
  medicationRequestRetrieval: googleCqlFhirR4MedicationRequestRetrieval,
  medicationDispenseRetrieval: googleCqlFhirR4MedicationDispenseRetrieval,
  medicationAdministrationRetrieval: googleCqlFhirR4MedicationAdministrationRetrieval,
  allergyIntoleranceRetrieval: googleCqlFhirR4AllergyIntoleranceRetrieval,
  conditionStatusRetrieval: googleCqlFhirR4ConditionStatusRetrieval,
} = runGoogleCql();
const cqlJvmRun = runCqfJvmDifferential(root, corpus.cases);
if (cqlJvmRun.status !== 'passed' || cqlJvmRun.caseCount !== corpus.cases.length) {
  throw new Error('CQF JVM report does not match the pinned engine and fixed corpus contract.');
}
const cqlJvmResults = cqlJvmRun.rows;
const cqfJvmFhirR4RetrievalRun = runCqfJvmFhirDifferential(root, fhirCorpus);
const fhirConditionJavaScriptRun = await runConditionRetrievalDifferential();
if (fhirConditionJavaScriptRun.schemaVersion !== 1 ||
    fhirConditionJavaScriptRun.fixtureSha256 !== fhirCorpusSha256 ||
    fhirConditionJavaScriptRun.cases.length !== fhirCorpus.cases.length) {
  throw new Error('JavaScript FHIR Condition report does not match the fixed corpus digest and case count.');
}
const googleFhirRows = new Map(googleCqlFhirR4Retrieval.results.map((row) => [row.id, row]));
const cqfJvmFhirRows = new Map(cqfJvmFhirR4RetrievalRun.results.map((row) => [row.id, row]));
const conditionJavaScriptRows = new Map(fhirConditionJavaScriptRun.cases.map((row) => [row.id, row]));
const conditionRetrievalCases = fhirCorpus.cases.map((testCase) => {
  const google = googleFhirRows.get(testCase.id);
  const javaScript = conditionJavaScriptRows.get(testCase.id);
  const cqfJvm = cqfJvmFhirRows.get(testCase.id);
  const expected = testCase.expectedCql === 'true';
  if (!google || !javaScript || !cqfJvm || !['true', 'false'].includes(google.result) ||
      !['true', 'false'].includes(cqfJvm.result) || javaScript.outcomeMatched !== true) {
    throw new Error(`FHIR Condition three-runtime result shape drift for ${testCase.id}.`);
  }
  const googleResult = google.result === 'true';
  const javaScriptResult = javaScript.outcomes?.hasCondition;
  const cqfJvmResult = cqfJvm.result === 'true';
  if (googleResult !== expected || javaScriptResult !== expected || cqfJvmResult !== expected) {
    throw new Error(`FHIR Condition three-runtime result drift for ${testCase.id}.`);
  }
  return {
    id: testCase.id,
    expectedResult: expected,
    googleCqlResult: googleResult,
    cqfJavaScriptResult: javaScriptResult,
    cqfJvmResult,
    outcomeParity: googleResult === javaScriptResult && javaScriptResult === cqfJvmResult,
  };
});
const conditionRetrievalDifferential = {
  schemaVersion: 1,
  scope: 'synthetic-fhir-r4-condition-three-runtime-differential',
  fhirVersion: fhirCorpus.fhirVersion,
  context: fhirCorpus.context,
  expression: fhirCorpus.expression,
  engines: {
    googleCql: googleCqlPackage,
    cqfJavaScript: fhirConditionJavaScriptRun.executionPath,
    cqfJvm: cqfJvmFhirR4RetrievalRun.engine,
  },
  fixtureSha256: fhirCorpusSha256,
  caseCount: conditionRetrievalCases.length,
  outcomeParityCount: conditionRetrievalCases.filter((row) => row.outcomeParity).length,
  javaScriptForeignConditionsDropped: fhirConditionJavaScriptRun.cases
    .reduce((count, row) => count + row.foreignConditionsDropped, 0),
  cases: conditionRetrievalCases,
  networkRequestMade: false,
  realPatientDataUsed: false,
};
if (conditionRetrievalDifferential.caseCount !== fhirCorpus.cases.length ||
    conditionRetrievalDifferential.outcomeParityCount !== fhirCorpus.cases.length ||
    conditionRetrievalDifferential.javaScriptForeignConditionsDropped !== 1) {
  throw new Error('FHIR Condition three-runtime report does not match the fixed corpus contract.');
}
const fhirCrossEngineRelations = fhirCorpus.cases.map((testCase) => {
  const google = googleFhirRows.get(testCase.id);
  const cqfJvm = cqfJvmFhirRows.get(testCase.id);
  return {
    id: testCase.id,
    outcomeMatched: google?.result === cqfJvm?.result,
    diagnosticsMatched: JSON.stringify(google?.errors ?? []) === JSON.stringify(cqfJvm?.errors ?? []) &&
      JSON.stringify(google?.warnings ?? []) === JSON.stringify(cqfJvm?.warnings ?? []),
  };
});
const fhirRelationsById = new Map(fhirCrossEngineRelations.map((row) => [row.id, row]));
const cqfJvmFhirR4Retrieval = {
  ...cqfJvmFhirR4RetrievalRun,
  corpusSha256: fhirCorpusSha256,
  crossEngineOutcomeParityCount: fhirCrossEngineRelations.filter((row) => row.outcomeMatched).length,
  crossEngineDiagnosticParityCount: fhirCrossEngineRelations.filter((row) => row.diagnosticsMatched).length,
  results: cqfJvmFhirR4RetrievalRun.results.map((row) => ({
    ...row,
    crossEngineOutcomeMatched: fhirRelationsById.get(row.id)?.outcomeMatched === true,
    crossEngineDiagnosticsMatched: fhirRelationsById.get(row.id)?.diagnosticsMatched === true,
  })),
};
if (cqfJvmFhirR4Retrieval.status !== 'passed' ||
    cqfJvmFhirR4Retrieval.caseCount !== fhirCorpus.cases.length ||
    cqfJvmFhirR4Retrieval.outcomeParityCount !== fhirCorpus.cases.length ||
    cqfJvmFhirR4Retrieval.diagnosticParityCount !== fhirCorpus.cases.length ||
    cqfJvmFhirR4Retrieval.crossEngineOutcomeParityCount !== fhirCorpus.cases.length ||
    cqfJvmFhirR4Retrieval.crossEngineDiagnosticParityCount !== fhirCorpus.cases.length) {
  throw new Error('CQF JVM FHIR R4 report does not match the fixed synthetic corpus contract.');
}
const fhirCqlHooksProjection = buildFhirCqlHooksProjectionReport({
  corpus: fhirCorpus,
  googleCqlRows: googleCqlFhirR4Retrieval.results,
  cqfJvmRows: cqfJvmFhirR4RetrievalRun.results,
  googleCqlPackage,
  cqfJvmEngine: cqfJvmFhirR4RetrievalRun.engine,
  cqfJvmFhirArtifact: cqfJvmFhirR4RetrievalRun.fhirArtifact,
  corpusDigest: fhirCorpusSha256,
});

const fhirObservationJavaScriptRun = await runObservationRetrievalDifferential();
if (fhirObservationJavaScriptRun.schemaVersion !== 2 ||
    fhirObservationJavaScriptRun.fixtureSha256 !== fhirObservationCorpusSha256 ||
    fhirObservationJavaScriptRun.cases.length !== fhirObservationCorpus.cases.length) {
  throw new Error('JavaScript FHIR Observation report does not match the fixed corpus digest and case count.');
}
const fhirObservationCqfJvmRun = runCqfJvmObservationTerminologyDifferential(
  root,
  fhirObservationCorpus,
  fhirObservationJavaScriptRun,
);
if (fhirObservationCqfJvmRun.schemaVersion !== 1 ||
    fhirObservationCqfJvmRun.caseCount !== fhirObservationCorpus.cases.length ||
    fhirObservationCqfJvmRun.fixtureSha256 !== fhirObservationCorpusSha256) {
  throw new Error('CQF JVM FHIR Observation report does not match the fixed corpus digest and case count.');
}
const fhirObservationGoRows = new Map(
  googleCqlFhirR4ObservationTerminology.results.map((row) => [row.id, row]),
);
const fhirObservationJavaScriptRows = new Map(
  fhirObservationJavaScriptRun.cases.map((row) => [row.id, row]),
);
const fhirObservationCqfJvmRows = new Map(
  fhirObservationCqfJvmRun.cases.map((row) => [row.id, row]),
);
const fhirObservationTerminologyCases = fhirObservationCorpus.cases.map((testCase) => {
  const google = fhirObservationGoRows.get(testCase.id);
  const javascript = fhirObservationJavaScriptRows.get(testCase.id);
  const cqfJvm = fhirObservationCqfJvmRows.get(testCase.id);
  if (!google || !javascript || !cqfJvm ||
      google.result !== testCase.expectedResult || javascript.result !== testCase.expectedResult ||
      cqfJvm.result !== testCase.expectedResult ||
      google.runtimeValueSetMembership !== testCase.expectedRuntimeValueSetMembership ||
      javascript.runtimeValueSetMembership !== testCase.expectedRuntimeValueSetMembership ||
      cqfJvm.cqfJvmCodeMembership !== testCase.expectedVersionAwareMembership) {
    throw new Error(`FHIR Observation cross-runtime result drift for ${testCase.id}.`);
  }
  return {
    id: testCase.id,
    expectedResult: testCase.expectedResult,
    resultParity: google.result === javascript.result && javascript.result === cqfJvm.result,
    expectedRuntimeValueSetMembership: testCase.expectedRuntimeValueSetMembership,
    expectedVersionAwareMembership: testCase.expectedVersionAwareMembership,
    googleCqlMembership: google.runtimeValueSetMembership,
    javaScriptMembership: javascript.runtimeValueSetMembership,
    cqfJvmMembership: cqfJvm.cqfJvmCodeMembership,
    googleMatchesJavaScript: google.runtimeValueSetMembership === javascript.runtimeValueSetMembership,
    googleMatchesCqfJvm: google.runtimeValueSetMembership === cqfJvm.cqfJvmCodeMembership,
    javaScriptMatchesCqfJvm: javascript.runtimeValueSetMembership === cqfJvm.cqfJvmCodeMembership,
    googleMatchesVersionAwareExpectation: google.versionAwareExpectationMatched,
    javaScriptMatchesVersionAwareExpectation:
      javascript.runtimeValueSetMembership === testCase.expectedVersionAwareMembership,
    cqfJvmMatchesVersionAwareExpectation:
      cqfJvm.cqfJvmCodeMembership === testCase.expectedVersionAwareMembership,
  };
});
const fhirObservationTerminologyDifferential = {
  schemaVersion: 1,
  scope: 'synthetic-fhir-r4-observation-terminology-cross-runtime-differential',
  fhirVersion: fhirObservationCorpus.fhirVersion,
  context: fhirObservationCorpus.context,
  valueSetCanonical: googleCqlFhirR4ObservationTerminology.valueSetCanonical,
  valueSetVersion: googleCqlFhirR4ObservationTerminology.valueSetVersion,
  fixtureSha256: fhirObservationCorpusSha256,
  engines: {
    googleCql: expectedGoogleCqlPackage,
    javaScript: fhirObservationJavaScriptRun.executionPath,
    cqfJvm: fhirObservationCqfJvmRun.engine,
  },
  caseCount: fhirObservationTerminologyCases.length,
  outcomeParityCount: fhirObservationTerminologyCases.filter((row) => row.resultParity).length,
  googleJavaScriptMembershipParityCount:
    fhirObservationTerminologyCases.filter((row) => row.googleMatchesJavaScript).length,
  googleCqfJvmMembershipParityCount:
    fhirObservationTerminologyCases.filter((row) => row.googleMatchesCqfJvm).length,
  googleVersionAwareExpectationCount:
    fhirObservationTerminologyCases.filter((row) => row.googleMatchesVersionAwareExpectation).length,
  javaScriptVersionAwareExpectationCount:
    fhirObservationTerminologyCases.filter((row) => row.javaScriptMatchesVersionAwareExpectation).length,
  cqfJvmVersionAwareExpectationCount:
    fhirObservationTerminologyCases.filter((row) => row.cqfJvmMatchesVersionAwareExpectation).length,
  results: fhirObservationTerminologyCases,
};
if (fhirObservationTerminologyDifferential.outcomeParityCount !== fhirObservationCorpus.cases.length ||
    fhirObservationTerminologyDifferential.googleJavaScriptMembershipParityCount !== fhirObservationCorpus.cases.length ||
    fhirObservationTerminologyDifferential.googleCqfJvmMembershipParityCount !== fhirObservationCorpus.cases.length - 1 ||
    fhirObservationTerminologyDifferential.googleVersionAwareExpectationCount !== fhirObservationCorpus.cases.length - 1 ||
    fhirObservationTerminologyDifferential.javaScriptVersionAwareExpectationCount !== fhirObservationCorpus.cases.length - 1 ||
    fhirObservationTerminologyDifferential.cqfJvmVersionAwareExpectationCount !== fhirObservationCorpus.cases.length) {
  throw new Error('FHIR Observation terminology cross-runtime parity counts differ from the pinned provider contract.');
}
if (/synthetic-patient-|synthetic-observation-|observation-in-set|observation-outside-set|urn:parkinsum:synthetic-/i
  .test(JSON.stringify(fhirObservationTerminologyDifferential))) {
  throw new Error('FHIR Observation cross-runtime report contains a fixture identifier or code.');
}
const fhirObservationCqlHooksProjection = buildFhirObservationCqlHooksProjectionReport({
  cases: fhirObservationTerminologyCases.map((row) => ({
    id: row.id,
    googleCqlMembership: row.googleCqlMembership,
    javaScriptMembership: row.javaScriptMembership,
    cqfJvmMembership: row.cqfJvmMembership,
  })),
  googleCqlPackage: expectedGoogleCqlPackage,
  javaScriptExecutionPath: fhirObservationJavaScriptRun.executionPath,
  cqfJvmEngine: fhirObservationCqfJvmRun.engine,
  cqfJvmFhirArtifact: fhirObservationCqfJvmRun.fhirArtifact,
  corpusDigest: fhirObservationCorpusSha256,
});
if (fhirObservationCqlHooksProjection.corpusSha256 !== fhirObservationCorpusSha256 ||
    /synthetic-patient-|synthetic-observation-|observation-in-set|observation-outside-set|urn:parkinsum:synthetic-/i
      .test(JSON.stringify(fhirObservationCqlHooksProjection))) {
  throw new Error('FHIR Observation CDS Hooks projection does not match the fixed safe report contract.');
}

const medicationStatementJavaScriptRun = await runMedicationStatementRetrievalDifferential();
if (medicationStatementJavaScriptRun.schemaVersion !== 1 ||
    medicationStatementJavaScriptRun.fixtureSha256 !== fhirMedicationStatementCorpusSha256 ||
    medicationStatementJavaScriptRun.cases.length !== fhirMedicationStatementCorpus.cases.length) {
  throw new Error('JavaScript FHIR MedicationStatement report does not match the fixed corpus digest and case count.');
}
const medicationStatementCqfJvmRun = runCqfJvmMedicationStatementDifferential(
  root,
  fhirMedicationStatementCorpus,
  medicationStatementJavaScriptRun,
);
if (medicationStatementCqfJvmRun.schemaVersion !== 1 ||
    medicationStatementCqfJvmRun.caseCount !== fhirMedicationStatementCorpus.cases.length ||
    medicationStatementCqfJvmRun.outcomeParityCount !== fhirMedicationStatementCorpus.cases.length ||
    medicationStatementCqfJvmRun.fixtureSha256 !== fhirMedicationStatementCorpusSha256) {
  throw new Error('CQF JVM FHIR MedicationStatement report does not match the fixed corpus digest and case count.');
}
const medicationStatementGoRows = new Map(
  googleCqlFhirR4MedicationStatementRetrieval.results.map((row) => [row.id, row]),
);
const medicationStatementJavaScriptRows = new Map(
  medicationStatementJavaScriptRun.cases.map((row) => [row.id, row]),
);
const medicationStatementCqfJvmRows = new Map(
  medicationStatementCqfJvmRun.cases.map((row) => [row.id, row]),
);
const medicationStatementDifferentialCases = fhirMedicationStatementCorpus.cases.map((testCase) => {
  const google = medicationStatementGoRows.get(testCase.id);
  const javascript = medicationStatementJavaScriptRows.get(testCase.id);
  const cqfJvm = medicationStatementCqfJvmRows.get(testCase.id);
  if (!google || !javascript || !cqfJvm ||
      JSON.stringify(google.outcomes) !== JSON.stringify(testCase.expectedOutcomes) ||
      JSON.stringify(javascript.outcomes) !== JSON.stringify(testCase.expectedOutcomes) ||
      JSON.stringify(cqfJvm.cqfJvmOutcomes) !== JSON.stringify(testCase.expectedOutcomes)) {
    throw new Error(`MedicationStatement three-runtime result drift for ${testCase.id}.`);
  }
  return {
    id: testCase.id,
    expectedOutcomes: testCase.expectedOutcomes,
    googleCqlOutcomes: google.outcomes,
    javaScriptOutcomes: javascript.outcomes,
    cqfJvmOutcomes: cqfJvm.cqfJvmOutcomes,
    outcomeParity: true,
    foreignStatementsDropped: {
      googleCql: google.foreignStatementsDropped,
      javaScript: javascript.foreignStatementsDropped,
      cqfJvm: cqfJvm.foreignStatementsDropped,
    },
  };
});
const medicationStatementRetrievalDifferential = {
  schemaVersion: 1,
  scope: 'synthetic-fhir-r4-medication-statement-retrieval-cross-runtime-differential',
  fhirVersion: fhirMedicationStatementCorpus.fhirVersion,
  context: fhirMedicationStatementCorpus.context,
  fixtureSha256: fhirMedicationStatementCorpusSha256,
  engines: {
    googleCql: expectedGoogleCqlPackage,
    javaScript: medicationStatementJavaScriptRun.executionPath,
    cqfJvm: medicationStatementCqfJvmRun.engine,
  },
  caseCount: medicationStatementDifferentialCases.length,
  outcomeParityCount: medicationStatementDifferentialCases.filter((row) => row.outcomeParity).length,
  patientIsolationCase: 'foreign_subject_statement',
  foreignSubjectDropsPerRuntime: Object.fromEntries(
    ['googleCql', 'javaScript', 'cqfJvm'].map((runtime) => [
      runtime,
      medicationStatementDifferentialCases.find((row) => row.id === 'foreign_subject_statement')
        .foreignStatementsDropped[runtime],
    ]),
  ),
  results: medicationStatementDifferentialCases,
  networkRequestMade: false,
  realPatientDataUsed: false,
};
if (medicationStatementRetrievalDifferential.outcomeParityCount !== fhirMedicationStatementCorpus.cases.length ||
    Object.values(medicationStatementRetrievalDifferential.foreignSubjectDropsPerRuntime).some((count) => count !== 1) ||
    /synthetic-patient-|synthetic-medication-statement-|Synthetic medication placeholder/i
      .test(JSON.stringify(medicationStatementRetrievalDifferential))) {
  throw new Error('MedicationStatement cross-runtime report failed parity, isolation, or projection checks.');
}

const medicationRequestJavaScriptRun = await runMedicationRequestRetrievalDifferential();
if (medicationRequestJavaScriptRun.schemaVersion !== 1 ||
    medicationRequestJavaScriptRun.fixtureSha256 !== fhirMedicationRequestCorpusSha256 ||
    medicationRequestJavaScriptRun.cases.length !== fhirMedicationRequestCorpus.cases.length) {
  throw new Error('JavaScript FHIR MedicationRequest report does not match the fixed corpus digest and case count.');
}
const medicationRequestCqfJvmRun = runCqfJvmMedicationRequestDifferential(
  root,
  fhirMedicationRequestCorpus,
  medicationRequestJavaScriptRun,
);
if (medicationRequestCqfJvmRun.schemaVersion !== 1 ||
    medicationRequestCqfJvmRun.caseCount !== fhirMedicationRequestCorpus.cases.length ||
    medicationRequestCqfJvmRun.outcomeParityCount !== fhirMedicationRequestCorpus.cases.length ||
    medicationRequestCqfJvmRun.fixtureSha256 !== fhirMedicationRequestCorpusSha256) {
  throw new Error('CQF JVM FHIR MedicationRequest report does not match the fixed corpus digest and case count.');
}
const medicationRequestGoRows = new Map(
  googleCqlFhirR4MedicationRequestRetrieval.results.map((row) => [row.id, row]),
);
const medicationRequestJavaScriptRows = new Map(
  medicationRequestJavaScriptRun.cases.map((row) => [row.id, row]),
);
const medicationRequestCqfJvmRows = new Map(
  medicationRequestCqfJvmRun.cases.map((row) => [row.id, row]),
);
const medicationRequestDifferentialCases = fhirMedicationRequestCorpus.cases.map((testCase) => {
  const google = medicationRequestGoRows.get(testCase.id);
  const javascript = medicationRequestJavaScriptRows.get(testCase.id);
  const cqfJvm = medicationRequestCqfJvmRows.get(testCase.id);
  if (!google || !javascript || !cqfJvm ||
      !sameBooleanMap(google.outcomes, testCase.expectedOutcomes) ||
      !sameBooleanMap(javascript.outcomes, testCase.expectedOutcomes) ||
      !sameBooleanMap(cqfJvm.cqfJvmOutcomes, testCase.expectedOutcomes)) {
    throw new Error(`MedicationRequest three-runtime result drift for ${testCase.id}.`);
  }
  return {
    id: testCase.id,
    expectedOutcomes: testCase.expectedOutcomes,
    googleCqlOutcomes: google.outcomes,
    javaScriptOutcomes: javascript.outcomes,
    cqfJvmOutcomes: cqfJvm.cqfJvmOutcomes,
    outcomeParity: true,
    foreignRequestsDropped: {
      googleCql: google.foreignRequestsDropped,
      javaScript: javascript.foreignRequestsDropped,
      cqfJvm: cqfJvm.foreignRequestsDropped.cqfJvm,
    },
  };
});
const medicationRequestRetrievalDifferential = {
  schemaVersion: 1,
  scope: 'synthetic-fhir-r4-medication-request-retrieval-cross-runtime-differential',
  fhirVersion: fhirMedicationRequestCorpus.fhirVersion,
  context: fhirMedicationRequestCorpus.context,
  fixtureSha256: fhirMedicationRequestCorpusSha256,
  engines: {
    googleCql: expectedGoogleCqlPackage,
    javaScript: medicationRequestJavaScriptRun.executionPath,
    cqfJvm: medicationRequestCqfJvmRun.engine,
  },
  caseCount: medicationRequestDifferentialCases.length,
  outcomeParityCount: medicationRequestDifferentialCases.filter((row) => row.outcomeParity).length,
  patientIsolationCase: 'foreign_subject_request',
  foreignSubjectDropsPerRuntime: Object.fromEntries(
    ['googleCql', 'javaScript', 'cqfJvm'].map((runtime) => [
      runtime,
      medicationRequestDifferentialCases.find((row) => row.id === 'foreign_subject_request')
        .foreignRequestsDropped[runtime],
    ]),
  ),
  results: medicationRequestDifferentialCases,
  networkRequestMade: false,
  realPatientDataUsed: false,
};
if (medicationRequestRetrievalDifferential.outcomeParityCount !== fhirMedicationRequestCorpus.cases.length ||
    Object.values(medicationRequestRetrievalDifferential.foreignSubjectDropsPerRuntime).some((count) => count !== 1) ||
    /synthetic-patient-|synthetic-medication-request-|Synthetic medication placeholder/i
      .test(JSON.stringify(medicationRequestRetrievalDifferential))) {
  throw new Error('MedicationRequest cross-runtime report failed parity, isolation, or projection checks.');
}

const medicationDispenseJavaScriptRun = await runMedicationDispenseRetrievalDifferential();
if (medicationDispenseJavaScriptRun.schemaVersion !== 1 ||
    medicationDispenseJavaScriptRun.fixtureSha256 !== fhirMedicationDispenseCorpusSha256 ||
    medicationDispenseJavaScriptRun.caseCount !== fhirMedicationDispenseCorpus.cases.length ||
    medicationDispenseJavaScriptRun.outcomeParityCount !== fhirMedicationDispenseCorpus.cases.length ||
    medicationDispenseJavaScriptRun.cases.length !== fhirMedicationDispenseCorpus.cases.length) {
  throw new Error('CQF JavaScript FHIR MedicationDispense report does not match the fixed corpus digest and case count.');
}
const medicationDispenseCqfJvmRun = runCqfJvmMedicationDispenseDifferential(
  root,
  fhirMedicationDispenseCorpus,
  medicationDispenseJavaScriptRun,
);
if (medicationDispenseCqfJvmRun.schemaVersion !== 1 ||
    medicationDispenseCqfJvmRun.caseCount !== fhirMedicationDispenseCorpus.cases.length ||
    medicationDispenseCqfJvmRun.outcomeParityCount !== fhirMedicationDispenseCorpus.cases.length ||
    medicationDispenseCqfJvmRun.fixtureSha256 !== fhirMedicationDispenseCorpusSha256) {
  throw new Error('CQF JVM FHIR MedicationDispense report does not match the fixed corpus digest and case count.');
}
const medicationDispenseGoRows = new Map(
  googleCqlFhirR4MedicationDispenseRetrieval.results.map((row) => [row.id, row]),
);
const medicationDispenseJavaScriptRows = new Map(
  medicationDispenseJavaScriptRun.cases.map((row) => [row.id, row]),
);
const medicationDispenseCqfJvmRows = new Map(
  medicationDispenseCqfJvmRun.cases.map((row) => [row.id, row]),
);
const medicationDispenseDifferentialCases = fhirMedicationDispenseCorpus.cases.map((testCase) => {
  const google = medicationDispenseGoRows.get(testCase.id);
  const javascript = medicationDispenseJavaScriptRows.get(testCase.id);
  const cqfJvm = medicationDispenseCqfJvmRows.get(testCase.id);
  const expectedForeignDrop = testCase.id === 'foreign_subject_dispense' ? 1 : 0;
  if (!google || !javascript || !cqfJvm ||
      !sameBooleanMap(google.outcomes, testCase.expectedOutcomes) ||
      !sameBooleanMap(javascript.outcomes, testCase.expectedOutcomes) ||
      !sameBooleanMap(cqfJvm.cqfJvmOutcomes, testCase.expectedOutcomes) ||
      google.foreignDispensesDropped !== expectedForeignDrop ||
      javascript.foreignDispensesDropped !== expectedForeignDrop ||
      cqfJvm.foreignDispensesDropped.cqfJvm !== expectedForeignDrop) {
    throw new Error(`MedicationDispense cross-runtime result drift for ${testCase.id}.`);
  }
  return {
    id: testCase.id,
    expectedOutcomes: testCase.expectedOutcomes,
    googleCqlOutcomes: google.outcomes,
    javaScriptOutcomes: javascript.outcomes,
    cqfJvmOutcomes: cqfJvm.cqfJvmOutcomes,
    outcomeParity: sameBooleanMap(google.outcomes, javascript.outcomes) &&
      sameBooleanMap(javascript.outcomes, cqfJvm.cqfJvmOutcomes),
    foreignDispensesDropped: {
      googleCql: google.foreignDispensesDropped,
      javaScript: javascript.foreignDispensesDropped,
      cqfJvm: cqfJvm.foreignDispensesDropped.cqfJvm,
    },
  };
});
const medicationDispenseRetrievalDifferential = {
  schemaVersion: 1,
  scope: 'synthetic-fhir-r4-medication-dispense-retrieval-cross-runtime-differential',
  fhirVersion: fhirMedicationDispenseCorpus.fhirVersion,
  context: fhirMedicationDispenseCorpus.context,
  fixtureSha256: fhirMedicationDispenseCorpusSha256,
  engines: {
    googleCql: expectedGoogleCqlPackage,
    cqfJavaScriptTranslator: medicationDispenseJavaScriptRun.translator,
    cqfJavaScriptExecution: medicationDispenseJavaScriptRun.executionPath,
    cqfJvm: medicationDispenseCqfJvmRun.engine,
  },
  caseCount: medicationDispenseDifferentialCases.length,
  outcomeParityCount: medicationDispenseDifferentialCases.filter((row) => row.outcomeParity).length,
  patientIsolationCase: 'foreign_subject_dispense',
  foreignSubjectDropsPerRuntime: Object.fromEntries(
    ['googleCql', 'javaScript', 'cqfJvm'].map((runtime) => [
      runtime,
      medicationDispenseDifferentialCases.find((row) => row.id === 'foreign_subject_dispense')
        .foreignDispensesDropped[runtime],
    ]),
  ),
  results: medicationDispenseDifferentialCases,
  networkRequestMade: false,
  realPatientDataUsed: false,
};
if (medicationDispenseRetrievalDifferential.outcomeParityCount !== fhirMedicationDispenseCorpus.cases.length ||
    Object.values(medicationDispenseRetrievalDifferential.foreignSubjectDropsPerRuntime).some((count) => count !== 1) ||
    /synthetic-patient-|synthetic-medication-dispense-|Synthetic medication placeholder/i
      .test(JSON.stringify(medicationDispenseRetrievalDifferential))) {
  throw new Error('MedicationDispense cross-runtime report failed parity, isolation, or projection checks.');
}

const medicationAdministrationJavaScriptRun = await runMedicationAdministrationRetrievalDifferential();
if (medicationAdministrationJavaScriptRun.schemaVersion !== 1 ||
    medicationAdministrationJavaScriptRun.fixtureSha256 !== fhirMedicationAdministrationCorpusSha256 ||
    medicationAdministrationJavaScriptRun.caseCount !== fhirMedicationAdministrationCorpus.cases.length ||
    medicationAdministrationJavaScriptRun.outcomeParityCount !== fhirMedicationAdministrationCorpus.cases.length ||
    medicationAdministrationJavaScriptRun.cases.length !== fhirMedicationAdministrationCorpus.cases.length) {
  throw new Error('CQF JavaScript FHIR MedicationAdministration report does not match the fixed corpus digest and case count.');
}
const medicationAdministrationCqfJvmRun = runCqfJvmMedicationAdministrationDifferential(
  root,
  fhirMedicationAdministrationCorpus,
  medicationAdministrationJavaScriptRun,
);
if (medicationAdministrationCqfJvmRun.schemaVersion !== 1 ||
    medicationAdministrationCqfJvmRun.caseCount !== fhirMedicationAdministrationCorpus.cases.length ||
    medicationAdministrationCqfJvmRun.outcomeParityCount !== fhirMedicationAdministrationCorpus.cases.length ||
    medicationAdministrationCqfJvmRun.fixtureSha256 !== fhirMedicationAdministrationCorpusSha256) {
  throw new Error('CQF JVM FHIR MedicationAdministration report does not match the fixed corpus digest and case count.');
}
const medicationAdministrationGoRows = new Map(
  googleCqlFhirR4MedicationAdministrationRetrieval.results.map((row) => [row.id, row]),
);
const medicationAdministrationJavaScriptRows = new Map(
  medicationAdministrationJavaScriptRun.cases.map((row) => [row.id, row]),
);
const medicationAdministrationCqfJvmRows = new Map(
  medicationAdministrationCqfJvmRun.cases.map((row) => [row.id, row]),
);
const medicationAdministrationDifferentialCases = fhirMedicationAdministrationCorpus.cases.map((testCase) => {
  const google = medicationAdministrationGoRows.get(testCase.id);
  const javascript = medicationAdministrationJavaScriptRows.get(testCase.id);
  const cqfJvm = medicationAdministrationCqfJvmRows.get(testCase.id);
  const expectedForeignDrop = testCase.id === 'foreign_subject_administration' ? 1 : 0;
  if (!google || !javascript || !cqfJvm ||
      !sameBooleanMap(google.outcomes, testCase.expectedOutcomes) ||
      !sameBooleanMap(javascript.outcomes, testCase.expectedOutcomes) ||
      !sameBooleanMap(cqfJvm.cqfJvmOutcomes, testCase.expectedOutcomes) ||
      google.foreignAdministrationsDropped !== expectedForeignDrop ||
      javascript.foreignAdministrationsDropped !== expectedForeignDrop ||
      cqfJvm.foreignAdministrationsDropped.cqfJvm !== expectedForeignDrop) {
    throw new Error(`MedicationAdministration cross-runtime result drift for ${testCase.id}.`);
  }
  return {
    id: testCase.id,
    expectedOutcomes: testCase.expectedOutcomes,
    googleCqlOutcomes: google.outcomes,
    javaScriptOutcomes: javascript.outcomes,
    cqfJvmOutcomes: cqfJvm.cqfJvmOutcomes,
    outcomeParity: sameBooleanMap(google.outcomes, javascript.outcomes) &&
      sameBooleanMap(javascript.outcomes, cqfJvm.cqfJvmOutcomes),
    foreignAdministrationsDropped: {
      googleCql: google.foreignAdministrationsDropped,
      javaScript: javascript.foreignAdministrationsDropped,
      cqfJvm: cqfJvm.foreignAdministrationsDropped.cqfJvm,
    },
  };
});
const medicationAdministrationRetrievalDifferential = {
  schemaVersion: 1,
  scope: 'synthetic-fhir-r4-medication-administration-retrieval-cross-runtime-differential',
  fhirVersion: fhirMedicationAdministrationCorpus.fhirVersion,
  context: fhirMedicationAdministrationCorpus.context,
  fixtureSha256: fhirMedicationAdministrationCorpusSha256,
  engines: {
    googleCql: expectedGoogleCqlPackage,
    cqfJavaScriptTranslator: medicationAdministrationJavaScriptRun.translator,
    cqfJavaScriptExecution: medicationAdministrationJavaScriptRun.executionPath,
    cqfJvm: medicationAdministrationCqfJvmRun.engine,
  },
  caseCount: medicationAdministrationDifferentialCases.length,
  outcomeParityCount: medicationAdministrationDifferentialCases.filter((row) => row.outcomeParity).length,
  patientIsolationCase: 'foreign_subject_administration',
  foreignSubjectDropsPerRuntime: Object.fromEntries(
    ['googleCql', 'javaScript', 'cqfJvm'].map((runtime) => [
      runtime,
      medicationAdministrationDifferentialCases.find((row) => row.id === 'foreign_subject_administration')
        .foreignAdministrationsDropped[runtime],
    ]),
  ),
  results: medicationAdministrationDifferentialCases,
  networkRequestMade: false,
  realPatientDataUsed: false,
};
if (medicationAdministrationRetrievalDifferential.outcomeParityCount !== fhirMedicationAdministrationCorpus.cases.length ||
    Object.values(medicationAdministrationRetrievalDifferential.foreignSubjectDropsPerRuntime).some((count) => count !== 1) ||
    /synthetic-patient-|synthetic-ma-|Synthetic medication placeholder|2026-01-15T12:00:00Z/i
      .test(JSON.stringify(medicationAdministrationRetrievalDifferential))) {
  throw new Error('MedicationAdministration cross-runtime report failed parity, isolation, or projection checks.');
}

const allergyIntoleranceJavaScriptRun = await runAllergyIntoleranceRetrievalDifferential();
if (allergyIntoleranceJavaScriptRun.schemaVersion !== 1 ||
    allergyIntoleranceJavaScriptRun.fixtureSha256 !== fhirAllergyIntoleranceCorpusSha256 ||
    allergyIntoleranceJavaScriptRun.caseCount !== fhirAllergyIntoleranceCorpus.cases.length ||
    allergyIntoleranceJavaScriptRun.outcomeParityCount !== fhirAllergyIntoleranceCorpus.cases.length ||
    allergyIntoleranceJavaScriptRun.cases.length !== fhirAllergyIntoleranceCorpus.cases.length) {
  throw new Error('CQF JavaScript FHIR AllergyIntolerance report does not match the fixed corpus digest and case count.');
}
const allergyIntoleranceCqfJvmRun = runCqfJvmAllergyIntoleranceDifferential(
  root,
  fhirAllergyIntoleranceCorpus,
  allergyIntoleranceJavaScriptRun,
);
if (allergyIntoleranceCqfJvmRun.schemaVersion !== 1 ||
    allergyIntoleranceCqfJvmRun.caseCount !== fhirAllergyIntoleranceCorpus.cases.length ||
    allergyIntoleranceCqfJvmRun.outcomeParityCount !== fhirAllergyIntoleranceCorpus.cases.length ||
    allergyIntoleranceCqfJvmRun.fixtureSha256 !== fhirAllergyIntoleranceCorpusSha256) {
  throw new Error('CQF JVM FHIR AllergyIntolerance report does not match the fixed corpus digest and case count.');
}
const allergyIntoleranceGoRows = new Map(
  googleCqlFhirR4AllergyIntoleranceRetrieval.results.map((row) => [row.id, row]),
);
const allergyIntoleranceJavaScriptRows = new Map(
  allergyIntoleranceJavaScriptRun.cases.map((row) => [row.id, row]),
);
const allergyIntoleranceCqfJvmRows = new Map(
  allergyIntoleranceCqfJvmRun.cases.map((row) => [row.id, row]),
);
const allergyIntoleranceDifferentialCases = fhirAllergyIntoleranceCorpus.cases.map((testCase) => {
  const google = allergyIntoleranceGoRows.get(testCase.id);
  const javaScript = allergyIntoleranceJavaScriptRows.get(testCase.id);
  const cqfJvm = allergyIntoleranceCqfJvmRows.get(testCase.id);
  const expectedForeignDrop = testCase.id === 'foreign_subject_allergy_intolerance' ? 1 : 0;
  if (!google || !javaScript || !cqfJvm ||
      !sameBooleanMap(google.outcomes, testCase.expectedOutcomes) ||
      !sameBooleanMap(javaScript.outcomes, testCase.expectedOutcomes) ||
      !sameBooleanMap(cqfJvm.cqfJvmOutcomes, testCase.expectedOutcomes) ||
      google.foreignAllergyIntolerancesDropped !== expectedForeignDrop ||
      javaScript.foreignAllergyIntolerancesDropped !== expectedForeignDrop ||
      cqfJvm.foreignAllergyIntolerancesDropped.cqfJvm !== expectedForeignDrop) {
    throw new Error(`AllergyIntolerance cross-runtime result drift for ${testCase.id}.`);
  }
  return {
    id: testCase.id,
    expectedOutcomes: testCase.expectedOutcomes,
    googleCqlOutcomes: google.outcomes,
    javaScriptOutcomes: javaScript.outcomes,
    cqfJvmOutcomes: cqfJvm.cqfJvmOutcomes,
    outcomeParity: sameBooleanMap(google.outcomes, javaScript.outcomes) &&
      sameBooleanMap(javaScript.outcomes, cqfJvm.cqfJvmOutcomes),
    foreignAllergyIntolerancesDropped: {
      googleCql: google.foreignAllergyIntolerancesDropped,
      javaScript: javaScript.foreignAllergyIntolerancesDropped,
      cqfJvm: cqfJvm.foreignAllergyIntolerancesDropped.cqfJvm,
    },
  };
});
const allergyIntoleranceRetrievalDifferential = {
  schemaVersion: 1,
  scope: 'synthetic-fhir-r4-allergy-intolerance-retrieval-cross-runtime-differential',
  fhirVersion: fhirAllergyIntoleranceCorpus.fhirVersion,
  context: fhirAllergyIntoleranceCorpus.context,
  fixtureSha256: fhirAllergyIntoleranceCorpusSha256,
  engines: {
    googleCql: expectedGoogleCqlPackage,
    cqfJavaScriptTranslator: allergyIntoleranceJavaScriptRun.translator,
    cqfJavaScriptExecution: allergyIntoleranceJavaScriptRun.executionPath,
    cqfJvm: allergyIntoleranceCqfJvmRun.engine,
  },
  caseCount: allergyIntoleranceDifferentialCases.length,
  outcomeParityCount: allergyIntoleranceDifferentialCases.filter((row) => row.outcomeParity).length,
  patientIsolationCase: 'foreign_subject_allergy_intolerance',
  foreignSubjectDropsPerRuntime: Object.fromEntries(
    ['googleCql', 'javaScript', 'cqfJvm'].map((runtime) => [
      runtime,
      allergyIntoleranceDifferentialCases.find((row) => row.id === 'foreign_subject_allergy_intolerance')
        .foreignAllergyIntolerancesDropped[runtime],
    ]),
  ),
  results: allergyIntoleranceDifferentialCases,
  networkRequestMade: false,
  realPatientDataUsed: false,
};
if (allergyIntoleranceRetrievalDifferential.outcomeParityCount !== fhirAllergyIntoleranceCorpus.cases.length ||
    Object.values(allergyIntoleranceRetrievalDifferential.foreignSubjectDropsPerRuntime).some((count) => count !== 1) ||
    /synthetic-patient-|synthetic-ai-|terminology\.hl7\.org\/CodeSystem\/allergyintolerance/i
      .test(JSON.stringify(allergyIntoleranceRetrievalDifferential))) {
  throw new Error('AllergyIntolerance cross-runtime report failed parity, isolation, or projection checks.');
}

const conditionStatusJavaScriptRun = await runConditionStatusRetrievalDifferential();
if (conditionStatusJavaScriptRun.schemaVersion !== 1 ||
    conditionStatusJavaScriptRun.fixtureSha256 !== fhirConditionStatusCorpusSha256 ||
    conditionStatusJavaScriptRun.caseCount !== fhirConditionStatusCorpus.cases.length ||
    conditionStatusJavaScriptRun.outcomeParityCount !== fhirConditionStatusCorpus.cases.length) {
  throw new Error('CQF JavaScript Condition status report differs from the fixed corpus and digest.');
}
const conditionStatusCqfJvmRun = runCqfJvmConditionStatusDifferential(
  root,
  fhirConditionStatusCorpus,
  conditionStatusJavaScriptRun,
);
if (conditionStatusCqfJvmRun.schemaVersion !== 1 ||
    conditionStatusCqfJvmRun.caseCount !== fhirConditionStatusCorpus.cases.length ||
    conditionStatusCqfJvmRun.outcomeParityCount !== fhirConditionStatusCorpus.cases.length ||
    conditionStatusCqfJvmRun.fixtureSha256 !== fhirConditionStatusCorpusSha256) {
  throw new Error('CQF JVM Condition status report differs from the fixed corpus and digest.');
}
const conditionStatusGoRows = new Map(
  googleCqlFhirR4ConditionStatusRetrieval.results.map((row) => [row.id, row]),
);
const conditionStatusJavaScriptRows = new Map(
  conditionStatusJavaScriptRun.cases.map((row) => [row.id, row]),
);
const conditionStatusCqfJvmRows = new Map(
  conditionStatusCqfJvmRun.cases.map((row) => [row.id, row]),
);
const conditionStatusDifferentialCases = fhirConditionStatusCorpus.cases.map((testCase) => {
  const google = conditionStatusGoRows.get(testCase.id);
  const javaScript = conditionStatusJavaScriptRows.get(testCase.id);
  const cqfJvm = conditionStatusCqfJvmRows.get(testCase.id);
  const expectedForeignDrop = testCase.id === 'foreign_subject_condition' ? 1 : 0;
  if (!google || !javaScript || !cqfJvm ||
      !sameBooleanMap(google.outcomes, testCase.expectedOutcomes) ||
      !sameBooleanMap(javaScript.outcomes, testCase.expectedOutcomes) ||
      !sameBooleanMap(cqfJvm.cqfJvmOutcomes, testCase.expectedOutcomes) ||
      google.foreignConditionsDropped !== expectedForeignDrop ||
      javaScript.foreignConditionsDropped !== expectedForeignDrop ||
      cqfJvm.foreignConditionsDropped.cqfJvm !== expectedForeignDrop) {
    throw new Error(`Condition status cross-runtime result drift for ${testCase.id}.`);
  }
  const outcomeParity = sameBooleanMap(google.outcomes, javaScript.outcomes) &&
    sameBooleanMap(google.outcomes, cqfJvm.cqfJvmOutcomes);
  if (!outcomeParity) throw new Error(`Condition status engines disagree for ${testCase.id}.`);
  return {
    id: testCase.id,
    expectedOutcomes: testCase.expectedOutcomes,
    googleCqlOutcomes: google.outcomes,
    javaScriptOutcomes: javaScript.outcomes,
    cqfJvmOutcomes: cqfJvm.cqfJvmOutcomes,
    outcomeParity,
    foreignConditionsDropped: {
      googleCql: google.foreignConditionsDropped,
      javaScript: javaScript.foreignConditionsDropped,
      cqfJvm: cqfJvm.foreignConditionsDropped.cqfJvm,
    },
  };
});
const conditionStatusRetrievalDifferential = {
  schemaVersion: 1,
  scope: 'synthetic-fhir-r4-condition-status-retrieval-cross-runtime-differential',
  fhirVersion: fhirConditionStatusCorpus.fhirVersion,
  context: fhirConditionStatusCorpus.context,
  fixtureSha256: fhirConditionStatusCorpusSha256,
  engines: {
    googleCql: expectedGoogleCqlPackage,
    cqfJavaScriptTranslator: conditionStatusJavaScriptRun.translator,
    cqfJavaScriptExecution: conditionStatusJavaScriptRun.executionPath,
    cqfJvm: conditionStatusCqfJvmRun.engine,
  },
  caseCount: conditionStatusDifferentialCases.length,
  outcomeParityCount: conditionStatusDifferentialCases.filter((row) => row.outcomeParity).length,
  patientIsolationCase: 'foreign_subject_condition',
  foreignSubjectDropsPerRuntime: Object.fromEntries(
    ['googleCql', 'javaScript', 'cqfJvm'].map((runtime) => [
      runtime,
      conditionStatusDifferentialCases.find((row) => row.id === 'foreign_subject_condition')
        .foreignConditionsDropped[runtime],
    ]),
  ),
  results: conditionStatusDifferentialCases,
  networkRequestMade: false,
  realPatientDataUsed: false,
};
if (conditionStatusRetrievalDifferential.outcomeParityCount !== fhirConditionStatusCorpus.cases.length ||
    Object.values(conditionStatusRetrievalDifferential.foreignSubjectDropsPerRuntime).some((count) => count !== 1) ||
    /synthetic-patient-|synthetic-condition-|terminology\.hl7\.org\/CodeSystem\/condition-(clinical|ver-status)/i
      .test(JSON.stringify(conditionStatusRetrievalDifferential))) {
  throw new Error('Condition status differential failed parity, isolation, or projection checks.');
}

const results = [];
for (const testCase of corpus.cases) {
  const dart = dartResults.get(testCase.id);
  if (!dart) throw new Error(`Missing Dart result for ${testCase.id}.`);
  const googleCql = googleCqlResults.get(testCase.id);
  if (!googleCql) throw new Error(`Missing Google CQL result for ${testCase.id}.`);
  const cqlJvm = cqlJvmResults.get(testCase.id);
  if (!cqlJvm) throw new Error(`Missing CQF JVM result for ${testCase.id}.`);
  const {
    cqlResult,
    independentCqlResult,
    cqlErrors,
    cqlWarnings,
    independentCqlErrors,
    independentCqlWarnings,
  } = await evaluateCql(testCase.id, testCase.cql);
  const runtimeMatch = dart.runtimeMatched === true;
  const reviewRecommended = dart.reviewRecommended === true;
  const failures = [];
  if (cqlResult !== testCase.expectedCql) failures.push(`CQL expected ${testCase.expectedCql}, got ${cqlResult}`);
  if (independentCqlResult !== testCase.expectedCql) failures.push(`cql-execution expected ${testCase.expectedCql}, got ${independentCqlResult}`);
  if (googleCql.result !== testCase.expectedCql) failures.push(`Google CQL expected ${testCase.expectedCql}, got ${googleCql.result}`);
  if (cqlJvm.result !== testCase.expectedCql) failures.push(`CQF JVM expected ${testCase.expectedCql}, got ${cqlJvm.result}`);
  if (googleCql.result !== cqlResult || googleCql.result !== independentCqlResult) failures.push(`Google CQL result differs from the JavaScript CQL runtimes`);
  if (cqlJvm.result !== cqlResult) failures.push('CQF JVM result differs from the CQF JavaScript runtime');
  if (JSON.stringify(cqlErrors) !== JSON.stringify(testCase.expectedResponseErrors)) failures.push(`CQL Errors expected ${JSON.stringify(testCase.expectedResponseErrors)}, got ${JSON.stringify(cqlErrors)}`);
  if (JSON.stringify(cqlWarnings) !== JSON.stringify(testCase.expectedResponseWarnings)) failures.push(`CQL Warnings expected ${JSON.stringify(testCase.expectedResponseWarnings)}, got ${JSON.stringify(cqlWarnings)}`);
  if (JSON.stringify(independentCqlErrors) !== JSON.stringify(testCase.expectedResponseErrors)) failures.push(`cql-execution Errors expected ${JSON.stringify(testCase.expectedResponseErrors)}, got ${JSON.stringify(independentCqlErrors)}`);
  if (JSON.stringify(independentCqlWarnings) !== JSON.stringify(testCase.expectedResponseWarnings)) failures.push(`cql-execution Warnings expected ${JSON.stringify(testCase.expectedResponseWarnings)}, got ${JSON.stringify(independentCqlWarnings)}`);
  if (JSON.stringify(googleCql.errors ?? []) !== JSON.stringify(testCase.expectedResponseErrors)) failures.push(`Google CQL Errors expected ${JSON.stringify(testCase.expectedResponseErrors)}, got ${JSON.stringify(googleCql.errors ?? [])}`);
  if (JSON.stringify(googleCql.warnings ?? []) !== JSON.stringify(testCase.expectedResponseWarnings)) failures.push(`Google CQL Warnings expected ${JSON.stringify(testCase.expectedResponseWarnings)}, got ${JSON.stringify(googleCql.warnings ?? [])}`);
  if (JSON.stringify(cqlJvm.errors) !== JSON.stringify(testCase.expectedResponseErrors)) failures.push(`CQF JVM Errors expected ${JSON.stringify(testCase.expectedResponseErrors)}, got ${JSON.stringify(cqlJvm.errors)}`);
  if (JSON.stringify(cqlJvm.warnings) !== JSON.stringify(testCase.expectedResponseWarnings)) failures.push(`CQF JVM Warnings expected ${JSON.stringify(testCase.expectedResponseWarnings)}, got ${JSON.stringify(cqlJvm.warnings)}`);
  if (JSON.stringify(googleCql.errors ?? []) !== JSON.stringify(cqlErrors) || JSON.stringify(googleCql.errors ?? []) !== JSON.stringify(independentCqlErrors)) failures.push('Google CQL Errors differ from a JavaScript CQL runtime');
  if (JSON.stringify(googleCql.warnings ?? []) !== JSON.stringify(cqlWarnings) || JSON.stringify(googleCql.warnings ?? []) !== JSON.stringify(independentCqlWarnings)) failures.push('Google CQL Warnings differ from a JavaScript CQL runtime');
  if (JSON.stringify(cqlJvm.errors) !== JSON.stringify(cqlErrors) || JSON.stringify(cqlJvm.warnings) !== JSON.stringify(cqlWarnings)) failures.push('CQF JVM diagnostics differ from the CQF JavaScript runtime');
  if (runtimeMatch !== testCase.expectedRuntimeMatch) failures.push(`Dart expected match ${testCase.expectedRuntimeMatch}, got ${runtimeMatch}`);
  if (reviewRecommended !== testCase.expectedReview) failures.push(`Dart expected review ${testCase.expectedReview}, got ${reviewRecommended}`);
  if (failures.length) throw new Error(`${testCase.id}: ${failures.join('; ')}`);

  const relation = cqlResult === (runtimeMatch ? 'true' : 'false')
    ? 'same'
    : reviewRecommended && cqlResult === 'unknown' && !runtimeMatch
      ? 'unknown-escalated-to-review'
      : 'documented-semantic-difference';
  const cqlEngineRelation = cqlResult === independentCqlResult
    ? 'same'
    : 'documented-semantic-difference';
  const cqfJvmEngineRelation = cqlJvm.result === cqlResult
    ? 'same'
    : 'documented-semantic-difference';
  const cqfJvmDiagnosticRelation =
      JSON.stringify(cqlJvm.errors) === JSON.stringify(cqlErrors) &&
      JSON.stringify(cqlJvm.warnings) === JSON.stringify(cqlWarnings)
    ? 'same'
    : 'documented-semantic-difference';
  const googleCqlEngineRelation = googleCql.result === cqlResult &&
      googleCql.result === independentCqlResult
    ? 'same'
    : 'documented-semantic-difference';
  const googleCqlDiagnosticRelation =
      JSON.stringify(googleCql.errors ?? []) === JSON.stringify(cqlErrors) &&
      JSON.stringify(googleCql.errors ?? []) === JSON.stringify(independentCqlErrors) &&
      JSON.stringify(googleCql.warnings ?? []) === JSON.stringify(cqlWarnings) &&
      JSON.stringify(googleCql.warnings ?? []) === JSON.stringify(independentCqlWarnings)
    ? 'same'
    : 'documented-semantic-difference';
  const informationResponse = projectCqlDifferentialInformationCard({
    testCase,
    cqlResult,
    independentCqlResult,
    responseErrors: cqlErrors,
    responseWarnings: cqlWarnings,
    dartResult: dart,
    cqlPackage,
    cqlExecutionPackage,
    corpusDigest: corpusSha256,
  });
  results.push({
    id: testCase.id,
    class: testCase.class,
    cql: cqlResult,
    cqlExecution: independentCqlResult,
    cqlEngineRelation,
    cqlJvm: cqlJvm.result,
    cqlJvmEngineRelation: cqfJvmEngineRelation,
    cqlJvmErrors: cqlJvm.errors,
    cqlJvmWarnings: cqlJvm.warnings,
    cqlJvmDiagnosticRelation: cqfJvmDiagnosticRelation,
    googleCql: googleCql.result,
    googleCqlPackage,
    googleCqlEngineRelation,
    googleCqlErrors: googleCql.errors ?? [],
    googleCqlWarnings: googleCql.warnings ?? [],
    googleCqlDiagnosticRelation,
    dartRuntimeMatch: runtimeMatch,
    missingFields: dart.missingFields,
    reviewRecommended,
    relation,
    responseErrors: cqlErrors,
    responseWarnings: cqlWarnings,
    independentResponseErrors: independentCqlErrors,
    independentResponseWarnings: independentCqlWarnings,
    responseDiagnosticRelation: googleCqlDiagnosticRelation === 'same' ? 'same' : 'documented-semantic-difference',
    responseLevelExtension: informationResponse.extension?.[
      'org.parkinsum.cql-differential-response'
    ] ?? null,
    cardsReturned: informationResponse.cards.length,
    informationCard: informationResponse.cards[0] ?? null,
  });
}

const report = {
  schemaVersion: 24,
  status: 'passed',
  scope: corpus.scope,
  cqlPackage,
  cqlJvmPackage,
  cqlJvmRuntime: {
    status: cqlJvmRun.status,
    engine: cqlJvmRun.engine,
    jvmArtifact: cqlJvmRun.jvmArtifact,
    translatorArtifact: cqlJvmRun.translatorArtifact,
    caseCount: cqlJvmRun.caseCount,
    outcomeParityCount: results.filter((row) => row.cqlJvmEngineRelation === 'same').length,
    diagnosticParityCount: results.filter((row) => row.cqlJvmDiagnosticRelation === 'same').length,
  },
  cqlExecutionPackage,
  googleCqlPackage,
  googleCqlFhirR4Retrieval,
  googleCqlFhirR4ArtifactBinding,
  googleCqlFhirR4ObservationTerminology,
  googleCqlFhirR4MedicationStatementRetrieval,
  googleCqlFhirR4MedicationRequestRetrieval,
  googleCqlFhirR4MedicationDispenseRetrieval,
  googleCqlFhirR4MedicationAdministrationRetrieval,
  googleCqlFhirR4AllergyIntoleranceRetrieval,
  googleCqlFhirR4ConditionStatusRetrieval,
  cqfJvmMedicationDispenseRetrieval: medicationDispenseCqfJvmRun,
  cqfJvmMedicationAdministrationRetrieval: medicationAdministrationCqfJvmRun,
  cqfJvmAllergyIntoleranceRetrieval: allergyIntoleranceCqfJvmRun,
  cqfJvmConditionStatusRetrieval: conditionStatusCqfJvmRun,
  cqfJvmFhirR4Retrieval,
  conditionRetrievalDifferential,
  fhirObservationTerminologyDifferential,
  medicationStatementRetrievalDifferential,
  medicationRequestRetrievalDifferential,
  medicationDispenseRetrievalDifferential,
  medicationAdministrationRetrievalDifferential,
  allergyIntoleranceRetrievalDifferential,
  conditionStatusRetrievalDifferential,
  fhirObservationCqlHooksProjection,
  fhirCqlHooksProjection,
  corpusSha256,
  cardProjectionStatus: 'passed',
  informationCardCount: results.filter((row) => row.informationCard !== null).length,
  responseDiagnosticCount: results.filter((row) => row.responseLevelExtension !== null).length,
  responseErrorCount: results.reduce((count, row) => count + row.responseErrors.length, 0),
  responseWarningCount: results.reduce((count, row) => count + row.responseWarnings.length, 0),
  responseDiagnosticParityCount: results.filter(
    (row) => row.responseDiagnosticRelation === 'same',
  ).length,
  responseDiagnosticDifferences: results.filter(
    (row) => row.responseDiagnosticRelation !== 'same',
  ).length,
  caseCount: results.length,
  cqlEngineParityCount: results.filter((row) => row.cqlEngineRelation === 'same').length,
  cqlEngineDifferences: results.filter((row) => row.cqlEngineRelation !== 'same').length,
  googleCqlEngineParityCount: results.filter((row) => row.googleCqlEngineRelation === 'same').length,
  googleCqlEngineDifferences: results.filter((row) => row.googleCqlEngineRelation !== 'same').length,
  googleCqlDiagnosticParityCount: results.filter((row) => row.googleCqlDiagnosticRelation === 'same').length,
  googleCqlDiagnosticDifferences: results.filter((row) => row.googleCqlDiagnosticRelation !== 'same').length,
  cqfJvmEngineParityCount: results.filter((row) => row.cqlJvmEngineRelation === 'same').length,
  cqfJvmEngineDifferences: results.filter((row) => row.cqlJvmEngineRelation !== 'same').length,
  cqfJvmDiagnosticParityCount: results.filter((row) => row.cqlJvmDiagnosticRelation === 'same').length,
  cqfJvmDiagnosticDifferences: results.filter((row) => row.cqlJvmDiagnosticRelation !== 'same').length,
  parityCount: results.filter((row) => row.relation === 'same').length,
  expectedSemanticDifferences: results.filter((row) => row.relation !== 'same').length,
  results,
  limitations: [
    'The nine-case comparison uses manufactured literals only; CQF JavaScript and JVM artifacts share the same upstream implementation family, so the JVM path is platform parity evidence rather than an independent CQL implementation. A separate three-case synthetic FHIR R4 Patient-context Condition existence probe runs through Google CQL and CQF JVM.',
    'CQL conversion vector expresses the local mg/day-to-g threshold conversion arithmetically; it is not a general UCUM service test.',
    'The Dart engine is two-valued at candidate matching; its production missing-input guard may escalate selected missing values to REQUIRE_REVIEW.',
    'An unsupported rule unit returns no Dart match without a missing-field escalation in this narrow prototype path; the divergence is retained as an explicit limitation.',
    'The CQF JavaScript compiler/runtime package is an experimental JavaScript API; this gate is engineering evidence only.',
    'The CQF JVM checks use the pinned Apache-2.0 engine only in development tooling; the FHIR probe is limited to three fixed local synthetic bundles and has no terminology service, application runtime route, or real patient data in this gate.',
    'cql-execution supports a declared subset of CQL and has documented JavaScript Number precision limitations; this fixed Boolean corpus does not test terminology or FHIR data-model providers.',
    'Google CQL is an experimental Go engine with partial CQL and FHIR support; it directly parses source here because it has no ELM import/export. Its FHIR probes use only fixed local synthetic Bundles and narrow subject-reference filters. The six-case Observation route resolves one local synthetic ValueSet; the pinned interpreter passes system and code to its terminology provider but omits FHIR Coding.version. It therefore agrees with the JavaScript route on six membership outcomes and the version-aware CQF JVM route on five; the sole mismatch is the fixed v2 case. This is pinned-provider behavior, not terminology, FHIR, or CQL conformance or arbitrary patient-context isolation.',
    'The FHIR CQL artifact contract contains one fixed synthetic Questionnaire and two embedded Libraries; it verifies versioned cqf-library and relatedArtifact links, CQL-derived FHIR Patient and Condition dataRequirement mappings, the included Library version, Patient launch context, output parameter declarations for all five fixed Boolean definitions, and two initialExpression definition names using Google CQL FHIR R4 model info. It resolves only this local one-level synthetic package and does not validate arbitrary FHIR resources, run Questionnaire/$populate, fetch external libraries, or establish clinical behavior.',
    'The separate three-case FHIR retrieval report now feeds a versioned, local CDS Hooks information-only projection after Google CQL and CQF JVM outcome and diagnostic parity; the matching synthetic Condition case yields one info card, while the no-match and foreign-subject cases return empty cards with a response-level warning. This projection emits no Patient or resource identifiers and is not an application route or clinical recommendation.',
    'A separate six-case FHIR Observation ValueSet-membership projection yields one information-only card only when the three pinned development engines agree true, four empty no-guidance responses when they agree false, and an empty response with an engine_disagreement error when their fixed Coding.version behavior differs. This is provider-specific synthetic test output, not terminology conformance or clinical advice.',
    'A ten-case synthetic FHIR R4 MedicationStatement retrieval probe covers all eight R4 status codes plus absent and foreign-subject resources through pinned Go and CQF-family JavaScript/JVM paths. Patient-scoped retrieval drops the one foreign-subject statement in every path. The report contains only fixed case labels and Boolean outcomes; it is development evidence, not FHIR/CQL conformance, medication reconciliation, decision support, or clinical behavior.',
    'An 18-case synthetic FHIR R4 MedicationRequest retrieval probe covers each of the eight R4 status values and eight intent values, plus absent and foreign-subject requests, through pinned Go and CQF-family JavaScript/JVM paths. Patient-scoped retrieval drops the one foreign-subject request in every path. Status and intent remain separate; the report contains fixed case labels and Boolean outcomes only and is not FHIR/CQL conformance, prescription validation, medication reconciliation, decision support, or clinical behavior.',
    'An 11-case synthetic FHIR R4 MedicationDispense retrieval probe covers all nine R4 status values, absent and foreign-subject cases through pinned Google CQL Go, CQF JavaScript, and CQF JVM paths. Each narrow local retriever drops the foreign-subject dispense and matches the expected Boolean outcomes. The report contains fixed case labels, outcomes and fixture digest only; it is not FHIR/CQL conformance, dispensing accuracy, pickup, medication use, adherence, or clinical decision support.',
    'A nine-case synthetic FHIR R4 MedicationAdministration retrieval probe covers all seven R4 status values, absence, and a foreign-subject resource through pinned Google CQL Go, CQF JavaScript, and CQF JVM paths. Each narrow local retriever drops the foreign-subject resource and matches the expected Boolean outcomes. The report contains fixed case labels, outcomes and fixture digest only; it is not FHIR/CQL conformance, dose or administration validation, proof of medication use, adherence, or clinical decision support.',
    'A six-case synthetic FHIR R4 AllergyIntolerance retrieval probe covers all three clinicalStatus values, all four verificationStatus values including the required entered-in-error omission of clinicalStatus, absence, and a foreign-Patient reference through pinned Google CQL Go, CQF JavaScript, and CQF JVM paths. Each narrow local retriever drops the foreign resource and matches every expected Boolean outcome. The report contains fixed case labels, outcomes and fixture digest only; it is not FHIR/CQL conformance, terminology validation, allergy interpretation, interaction checking, or clinical decision support.',
    'A nine-case synthetic FHIR R4 Condition retrieval probe covers all six clinicalStatus and six verificationStatus codes, entered-in-error without clinicalStatus, absence, and foreign-Patient filtering through pinned Google CQL Go, CQF JavaScript, and CQF JVM paths. Reports contain only fixed case labels, Boolean outcomes, and fixture digest; they do not evaluate clinical meaning, terminology, diagnosis, or treatment.',
  ],
};
process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
