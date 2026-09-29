import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import {
  assertPopulationPreviewDependencyPins,
  buildSyntheticQuestionnairePopulationPreview,
  mapInitialExpressionResultToQuestionnaireItem,
} from './cql_sdc_questionnaire_population_preview.mjs';

const fixtureBytes = readFileSync(new URL('../test/fixtures/cql_fhir_r4_artifact_binding.json', import.meta.url));
const questionnaire = JSON.parse(fixtureBytes.toString('utf8')).entry
  .map((entry) => entry.resource)
  .find((resource) => resource.resourceType === 'Questionnaire');
const questionnaireCanonical = `${questionnaire.url}|${questionnaire.version}`;

test('evaluates the two fixed Questionnaire initialExpressions through the pinned CQF CQL engine', () => {
  const report = buildSyntheticQuestionnairePopulationPreview();
  assert.equal(report.schemaVersion, 3);
  assert.equal(report.scope, 'synthetic-fhir-r4-sdc-populate-operation-subset');
  assert.equal(report.status, 'passed');
  assert.equal(report.fhirVersion, '4.0.1');
  assert.deepEqual(report.operation, {
    name: 'Questionnaire/$populate',
    executionMode: 'bounded-local-subset',
  });
  assert.deepEqual(report.operationInput, {
    resourceType: 'Parameters',
    acceptedParameter: 'questionnaire',
    questionnaireResolution: 'fixed-local-canonical',
  });
  assert.equal(report.questionnaireItemCount, 2);
  assert.equal(report.evaluatedInitialExpressionCount, 2);
  assert.deepEqual(report.previewAnswers, [
    { linkId: 'synthetic-baseline', valueBoolean: true },
    { linkId: 'synthetic-alternative', valueBoolean: false },
  ]);
  assert.deepEqual(report.engine, {
    package: '@cqframework/cql',
    version: '5.3.0',
    libraryVersion: '1.0.0',
  });
  assert.deepEqual(report.operationOutput, {
    resourceType: 'Parameters',
    parameter: [{
      name: 'response',
      resource: {
        resourceType: 'QuestionnaireResponse',
        questionnaire: 'https://example.org/fhir/Questionnaire/ParkinSUMSyntheticQuestionnaire|1.0.0',
        status: 'in-progress',
        item: [
          { linkId: 'synthetic-baseline', answer: [{ valueBoolean: true }] },
          { linkId: 'synthetic-alternative', answer: [{ valueBoolean: false }] },
        ],
      },
    }],
  });
  assert.deepEqual(report.boundaries, {
    remoteFhirEndpointCalled: false,
    patientResourceProvided: false,
    networkRequests: 0,
    populatedAnswersRequireHumanReview: true,
    clinicalLogicOrValidityClaim: false,
  });
});

test('accepts a direct Questionnaire resource only when it matches the pinned artifact exactly', () => {
  const requestParameters = {
    resourceType: 'Parameters',
    parameter: [{ name: 'questionnaire', resource: questionnaire }],
  };
  const report = buildSyntheticQuestionnairePopulationPreview({ requestParameters });
  assert.equal(report.operationInput.questionnaireResolution, 'fixed-local-questionnaire-resource');

  const changedQuestionnaire = structuredClone(questionnaire);
  changedQuestionnaire.subjectType = ['Group'];
  assert.throws(
    () => buildSyntheticQuestionnairePopulationPreview({
      requestParameters: {
        resourceType: 'Parameters',
        parameter: [{ name: 'questionnaire', resource: changedQuestionnaire }],
      },
    }),
    /synthetic_questionnaire_populate_resource_unresolved/,
  );
});

test('accepts only the exact local Questionnaire reference', () => {
  const report = buildSyntheticQuestionnairePopulationPreview({
    requestParameters: {
      resourceType: 'Parameters',
      parameter: [{
        name: 'questionnaire',
        valueReference: { reference: 'Questionnaire/synthetic-cql-questionnaire' },
      }],
    },
  });
  assert.equal(report.operationInput.questionnaireResolution, 'fixed-local-reference');
  assert.throws(
    () => buildSyntheticQuestionnairePopulationPreview({
      requestParameters: {
        resourceType: 'Parameters',
        parameter: [{ name: 'questionnaire', valueReference: { reference: 'Questionnaire/other' } }],
      },
    }),
    /synthetic_questionnaire_populate_reference_unresolved/,
  );
});

test('rejects unresolved canonicals and unsupported Patient, context, or data parameters', () => {
  assert.throws(
    () => buildSyntheticQuestionnairePopulationPreview({
      requestParameters: {
        resourceType: 'Parameters',
        parameter: [{ name: 'questionnaire', valueUri: 'https://example.org/fhir/Questionnaire/other|1.0.0' }],
      },
    }),
    /synthetic_questionnaire_populate_canonical_unresolved/,
  );
  assert.throws(
    () => buildSyntheticQuestionnairePopulationPreview({
      requestParameters: {
        resourceType: 'Parameters',
        parameter: [
          { name: 'questionnaire', valueUri: questionnaireCanonical },
          { name: 'subject', valueReference: { reference: 'Patient/synthetic-1' } },
        ],
      },
    }),
    /synthetic_questionnaire_populate_request_shape_invalid/,
  );
  assert.throws(
    () => buildSyntheticQuestionnairePopulationPreview({
      requestParameters: {
        resourceType: 'Parameters',
        parameter: [
          { name: 'questionnaire', valueUri: questionnaireCanonical },
          { name: 'data', resource: { resourceType: 'Bundle', type: 'collection', entry: [] } },
        ],
      },
    }),
    /synthetic_questionnaire_populate_request_shape_invalid/,
  );
});

test('rejects fixture drift before evaluating changed or additional artifacts', () => {
  const changed = JSON.parse(fixtureBytes.toString('utf8'));
  changed.entry.push({
    fullUrl: 'urn:uuid:unexpected',
    resource: { resourceType: 'Library', name: 'Unexpected' },
  });
  assert.throws(
    () => buildSyntheticQuestionnairePopulationPreview({ fixtureBytes: Buffer.from(JSON.stringify(changed)) }),
    /synthetic_questionnaire_fixture_digest_unreviewed/,
  );
});

test('rejects unreviewed CQL and FHIR model dependency versions', () => {
  assert.throws(
    () => assertPopulationPreviewDependencyPins({ cql: '5.3.1', fhirModel: '2.1.6' }),
    /unreviewed_cqf_cql_dependency_version/,
  );
  assert.throws(
    () => assertPopulationPreviewDependencyPins({ cql: '5.3.0', fhirModel: '2.1.7' }),
    /unreviewed_fhir_model_dependency_version/,
  );
  assert.doesNotThrow(() => assertPopulationPreviewDependencyPins({ cql: '5.3.0', fhirModel: '2.1.6' }));
});

test('an empty Boolean expression stays unanswered and is never converted to false', () => {
  assert.deepEqual(
    mapInitialExpressionResultToQuestionnaireItem('synthetic-empty', null),
    { linkId: 'synthetic-empty' },
  );
  assert.deepEqual(
    mapInitialExpressionResultToQuestionnaireItem('synthetic-empty', undefined),
    { linkId: 'synthetic-empty' },
  );
  assert.deepEqual(
    mapInitialExpressionResultToQuestionnaireItem('synthetic-false', false),
    { linkId: 'synthetic-false', answer: [{ valueBoolean: false }] },
  );
  assert.throws(
    () => mapInitialExpressionResultToQuestionnaireItem('synthetic-invalid', 'false'),
    /synthetic_questionnaire_initial_expression_not_boolean/,
  );
});

test('report omits labels, CQL source, Library canonicals, and unrelated resource payloads', () => {
  const report = buildSyntheticQuestionnairePopulationPreview();
  const serialized = JSON.stringify(report);
  for (const omitted of [
    'Synthetic baseline',
    'SyntheticQuestionnaireLogic',
    'library SyntheticQuestionnaireLogic',
    'https://example.org/fhir/Library',
    'Observation',
  ]) {
    assert.equal(serialized.includes(omitted), false, `report unexpectedly contains ${omitted}`);
  }
});
