#!/usr/bin/env node
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { createRequire } from 'node:module';
import { isDeepStrictEqual } from 'node:util';

import {
  CqlTranslator,
  LibraryManager,
  ModelManager,
  createLibrarySourceProvider,
  createModelInfoProvider,
  stringAsSource,
} from '@cqframework/cql/cql-to-elm';
import { SystemModelInfoProvider } from '@cqframework/cql/cql';
import { CqlEngine, Environment, EvaluationParams } from '@cqframework/cql/engine';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const fixturePath = path.join(root, 'test/fixtures/cql_fhir_r4_artifact_binding.json');
const expectedFixtureSha256 = '01594567851f65cf12417a8059b16616be52bc70c60b1eb9f5966171efd6172a';
const expectedCqlVersion = '5.3.0';
const expectedFhirModelPackageVersion = '2.1.6';
const initialExpressionUrl = 'http://hl7.org/fhir/uv/sdc/StructureDefinition/sdc-questionnaire-initialExpression';
const cqfLibraryUrl = 'http://hl7.org/fhir/StructureDefinition/cqf-library';
const primaryLibraryName = 'SyntheticQuestionnaireLogic';
const expectedExpressions = [
  { linkId: 'synthetic-baseline', expression: 'Synthetic Baseline' },
  { linkId: 'synthetic-alternative', expression: 'Synthetic Alternative' },
];

const require = createRequire(import.meta.url);

function requireContract(condition, code) {
  if (!condition) throw new Error(code);
}

function exactKeys(value, keys) {
  return value !== null
    && typeof value === 'object'
    && !Array.isArray(value)
    && Object.keys(value).sort().join('\0') === [...keys].sort().join('\0');
}

export function assertPopulationPreviewDependencyPins(dependencyPins) {
  requireContract(
    dependencyPins?.cql === expectedCqlVersion,
    'unreviewed_cqf_cql_dependency_version',
  );
  requireContract(
    dependencyPins?.fhirModel === expectedFhirModelPackageVersion,
    'unreviewed_fhir_model_dependency_version',
  );
}

export function mapInitialExpressionResultToQuestionnaireItem(linkId, value) {
  requireContract(typeof linkId === 'string' && linkId.length > 0, 'synthetic_questionnaire_link_id_invalid');
  if (value === null || value === undefined) return { linkId };
  requireContract(typeof value === 'boolean', 'synthetic_questionnaire_initial_expression_not_boolean');
  return { linkId, answer: [{ valueBoolean: value }] };
}

function checkDependencyPins() {
  const packageJson = JSON.parse(readFileSync(path.join(root, 'package.json'), 'utf8'));
  assertPopulationPreviewDependencyPins({
    cql: packageJson.devDependencies?.['@cqframework/cql'],
    fhirModel: packageJson.devDependencies?.['cql-exec-fhir'],
  });
}

function validateFixtureBytes(fixtureBytes) {
  const bytes = Buffer.from(fixtureBytes);
  const fixtureSha256 = createHash('sha256').update(bytes).digest('hex');
  requireContract(fixtureSha256 === expectedFixtureSha256, 'synthetic_questionnaire_fixture_digest_unreviewed');

  let bundle;
  try {
    bundle = JSON.parse(bytes.toString('utf8'));
  } catch {
    throw new Error('synthetic_questionnaire_fixture_json_invalid');
  }
  requireContract(exactKeys(bundle, ['resourceType', 'type', 'entry']), 'synthetic_questionnaire_bundle_shape_invalid');
  requireContract(bundle.resourceType === 'Bundle' && bundle.type === 'collection', 'synthetic_questionnaire_bundle_type_invalid');
  requireContract(Array.isArray(bundle.entry) && bundle.entry.length === 4, 'synthetic_questionnaire_bundle_entry_count_invalid');

  const expectedEntries = new Map([
    ['urn:uuid:synthetic-cql-questionnaire', 'Questionnaire'],
    ['urn:uuid:synthetic-cql-library', 'Library'],
    ['urn:uuid:synthetic-cql-shared-library', 'Library'],
    ['urn:uuid:synthetic-cql-plan-definition', 'PlanDefinition'],
  ]);
  const resourcesByTypeAndName = new Map();
  for (const entry of bundle.entry) {
    requireContract(entry && typeof entry === 'object' && !Array.isArray(entry), 'synthetic_questionnaire_bundle_entry_invalid');
    const expectedType = expectedEntries.get(entry.fullUrl);
    requireContract(expectedType && entry.resource?.resourceType === expectedType, 'synthetic_questionnaire_bundle_entry_identity_invalid');
    expectedEntries.delete(entry.fullUrl);
    const key = entry.resource.resourceType === 'Questionnaire'
      ? 'Questionnaire'
      : entry.resource.resourceType === 'PlanDefinition'
        ? 'PlanDefinition'
        : entry.resource.name;
    requireContract(!resourcesByTypeAndName.has(key), 'synthetic_questionnaire_resource_duplicated');
    resourcesByTypeAndName.set(key, entry.resource);
  }
  requireContract(expectedEntries.size === 0, 'synthetic_questionnaire_bundle_resource_missing');

  const questionnaire = resourcesByTypeAndName.get('Questionnaire');
  const primaryLibrary = resourcesByTypeAndName.get(primaryLibraryName);
  const sharedLibrary = resourcesByTypeAndName.get('SyntheticQuestionnaireSharedLogic');
  requireContract(questionnaire?.id === 'synthetic-cql-questionnaire', 'synthetic_questionnaire_identity_invalid');
  requireContract(primaryLibrary?.version === '1.0.0' && sharedLibrary?.version === '1.0.0', 'synthetic_questionnaire_library_version_invalid');
  requireContract(questionnaire.subjectType?.length === 1 && questionnaire.subjectType[0] === 'Patient', 'synthetic_questionnaire_subject_type_invalid');

  const libraryCanonical = questionnaire.extension?.find((extension) => extension.url === cqfLibraryUrl)?.valueCanonical;
  requireContract(
    libraryCanonical === `${primaryLibrary.url}|${primaryLibrary.version}`,
    'synthetic_questionnaire_library_canonical_mismatch',
  );
  requireContract(Array.isArray(questionnaire.item) && questionnaire.item.length === expectedExpressions.length, 'synthetic_questionnaire_item_count_invalid');

  const expressionByLinkId = new Map();
  for (const item of questionnaire.item) {
    requireContract(item?.type === 'boolean' && typeof item.linkId === 'string', 'synthetic_questionnaire_item_type_invalid');
    requireContract(!expressionByLinkId.has(item.linkId), 'synthetic_questionnaire_link_id_duplicated');
    const expressionExtensions = item.extension?.filter((extension) => extension.url === initialExpressionUrl) ?? [];
    requireContract(expressionExtensions.length === 1, 'synthetic_questionnaire_initial_expression_count_invalid');
    const expression = expressionExtensions[0].valueExpression;
    requireContract(expression?.language === 'text/cql' && typeof expression.expression === 'string', 'synthetic_questionnaire_initial_expression_invalid');
    expressionByLinkId.set(item.linkId, expression.expression);
  }
  for (const expected of expectedExpressions) {
    requireContract(expressionByLinkId.get(expected.linkId) === expected.expression, 'synthetic_questionnaire_initial_expression_binding_drift');
  }

  const sourceByLibraryName = new Map();
  for (const library of [primaryLibrary, sharedLibrary]) {
    requireContract(Array.isArray(library.content) && library.content.length === 1, 'synthetic_questionnaire_library_content_count_invalid');
    const content = library.content[0];
    requireContract(content.contentType === 'text/cql' && typeof content.data === 'string', 'synthetic_questionnaire_library_content_type_invalid');
    const sourceBytes = Buffer.from(content.data, 'base64');
    requireContract(sourceBytes.toString('base64') === content.data, 'synthetic_questionnaire_library_base64_invalid');
    const source = sourceBytes.toString('utf8');
    requireContract(source.startsWith(`library ${library.name} version '1.0.0'\nusing FHIR version '4.0.1'`), 'synthetic_questionnaire_library_source_identity_invalid');
    sourceByLibraryName.set(library.name, source);
  }
  requireContract(
    sourceByLibraryName.get(primaryLibraryName).includes("include SyntheticQuestionnaireSharedLogic version '1.0.0' called Shared"),
    'synthetic_questionnaire_cql_include_binding_invalid',
  );

  return { fixtureSha256, questionnaire, primaryLibrary, sourceByLibraryName };
}

function validatePopulateRequest(requestParameters, questionnaire) {
  requireContract(
    exactKeys(requestParameters, ['resourceType', 'parameter']) &&
      requestParameters.resourceType === 'Parameters' &&
      Array.isArray(requestParameters.parameter) &&
      requestParameters.parameter.length === 1,
    'synthetic_questionnaire_populate_request_shape_invalid',
  );
  const [parameter] = requestParameters.parameter;
  requireContract(
    parameter && typeof parameter === 'object' && !Array.isArray(parameter) &&
      parameter.name === 'questionnaire',
    'synthetic_questionnaire_populate_request_parameter_invalid',
  );
  const expectedCanonical = `${questionnaire.url}|${questionnaire.version}`;
  if (exactKeys(parameter, ['name', 'valueUri'])) {
    requireContract(parameter.valueUri === expectedCanonical, 'synthetic_questionnaire_populate_canonical_unresolved');
    return 'fixed-local-canonical';
  }
  if (exactKeys(parameter, ['name', 'valueReference'])) {
    const expectedReference = `${questionnaire.resourceType}/${questionnaire.id}`;
    requireContract(
      exactKeys(parameter.valueReference, ['reference']) &&
        parameter.valueReference.reference === expectedReference,
      'synthetic_questionnaire_populate_reference_unresolved',
    );
    return 'fixed-local-reference';
  }
  if (exactKeys(parameter, ['name', 'resource'])) {
    requireContract(
      parameter.resource?.resourceType === 'Questionnaire' &&
        isDeepStrictEqual(parameter.resource, questionnaire),
      'synthetic_questionnaire_populate_resource_unresolved',
    );
    return 'fixed-local-questionnaire-resource';
  }
  throw new Error('synthetic_questionnaire_populate_request_parameter_type_unsupported');
}

function evaluateInitialExpressions(sourceByLibraryName, expressions) {
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
  libraryManager.librarySourceLoader.registerProvider(
    createLibrarySourceProvider((name) => (
      sourceByLibraryName.has(name) ? stringAsSource(sourceByLibraryName.get(name)) : null
    )),
  );
  const primarySource = sourceByLibraryName.get(primaryLibraryName);
  const translator = CqlTranslator.fromText(primarySource, libraryManager);
  const translationErrors = translator.errors.asJsReadonlyArrayView();
  requireContract(translationErrors.length === 0 && translator.toELM() !== null, 'synthetic_questionnaire_cql_translation_failed');

  const libraryParams = new EvaluationParams.LibraryParams.Builder();
  libraryParams.expressionsByName(expressions.map((item) => item.expression));
  const evaluationParams = new EvaluationParams.Builder();
  evaluationParams.libraryByName(primaryLibraryName, libraryParams.build());
  const results = new CqlEngine(new Environment(libraryManager)).evaluate(evaluationParams.build());
  requireContract(!results.hasExceptions(), 'synthetic_questionnaire_cql_evaluation_failed');
  const evaluated = results.onlyResultOrThrow;
  return expressions.map((item) => {
    const value = evaluated.getByName(item.expression)?.value?.value;
    const responseItem = mapInitialExpressionResultToQuestionnaireItem(item.linkId, value);
    return responseItem.answer
      ? { linkId: item.linkId, valueBoolean: responseItem.answer[0].valueBoolean }
      : { linkId: item.linkId };
  });
}

export function buildSyntheticQuestionnairePopulationPreview({
  fixtureBytes = readFileSync(fixturePath),
  requestParameters = null,
} = {}) {
  checkDependencyPins();
  const { fixtureSha256, questionnaire, primaryLibrary, sourceByLibraryName } = validateFixtureBytes(fixtureBytes);
  const request = requestParameters ?? {
    resourceType: 'Parameters',
    parameter: [{
      name: 'questionnaire',
      valueUri: `${questionnaire.url}|${questionnaire.version}`,
    }],
  };
  const questionnaireResolution = validatePopulateRequest(request, questionnaire);
  const previewAnswers = evaluateInitialExpressions(sourceByLibraryName, expectedExpressions);
  const questionnaireResponse = {
    resourceType: 'QuestionnaireResponse',
    questionnaire: `${questionnaire.url}|${questionnaire.version}`,
    status: 'in-progress',
    item: previewAnswers.map((answer) => mapInitialExpressionResultToQuestionnaireItem(
      answer.linkId,
      answer.valueBoolean,
    )),
  };

  return {
    schemaVersion: 3,
    scope: 'synthetic-fhir-r4-sdc-populate-operation-subset',
    status: 'passed',
    fhirVersion: '4.0.1',
    operation: {
      name: 'Questionnaire/$populate',
      executionMode: 'bounded-local-subset',
    },
    operationInput: {
      resourceType: 'Parameters',
      acceptedParameter: 'questionnaire',
      questionnaireResolution,
    },
    fixtureSha256,
    questionnaireItemCount: questionnaire.item.length,
    evaluatedInitialExpressionCount: previewAnswers.length,
    previewAnswers,
    operationOutput: {
      resourceType: 'Parameters',
      parameter: [{ name: 'response', resource: questionnaireResponse }],
    },
    engine: {
      package: '@cqframework/cql',
      version: expectedCqlVersion,
      libraryVersion: primaryLibrary.version,
    },
    boundaries: {
      remoteFhirEndpointCalled: false,
      patientResourceProvided: false,
      networkRequests: 0,
      populatedAnswersRequireHumanReview: true,
      clinicalLogicOrValidityClaim: false,
    },
  };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    process.stdout.write(`${JSON.stringify(buildSyntheticQuestionnairePopulationPreview(), null, 2)}\n`);
  } catch (error) {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    process.exitCode = 1;
  }
}
