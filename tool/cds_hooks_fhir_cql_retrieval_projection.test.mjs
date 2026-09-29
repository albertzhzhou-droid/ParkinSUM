import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import test from 'node:test';

import { validateInformationOnlyResponse } from './cds_hooks_information_card_contract.mjs';
import {
  buildFhirCqlHooksProjectionReport,
  projectFhirCqlRetrievalInformationCard,
} from './cds_hooks_fhir_cql_retrieval_projection.mjs';

const corpus = JSON.parse(
  fs.readFileSync('test/fixtures/cql_fhir_r4_retrieval_corpus.json', 'utf8'),
);
const corpusDigest = createHash('sha256')
  .update(fs.readFileSync('test/fixtures/cql_fhir_r4_retrieval_corpus.json'))
  .digest('hex');
const engines = {
  googleCqlPackage: 'github.com/google/cql@v0.0.3-0.20260814184421-b9169ccd54a3',
  cqfJvmEngine: 'org.cqframework:engine@5.3.0',
  cqfJvmFhirArtifact: 'org.cqframework:engine-fhir@5.3.0',
};

function project(testCase, overrides = {}) {
  return projectFhirCqlRetrievalInformationCard({
    testCase,
    googleCqlResult: testCase.expectedCql,
    googleCqlErrors: testCase.expectedResponseErrors,
    googleCqlWarnings: testCase.expectedResponseWarnings,
    cqfJvmResult: testCase.expectedCql,
    cqfJvmErrors: testCase.expectedResponseErrors,
    cqfJvmWarnings: testCase.expectedResponseWarnings,
    ...engines,
    corpusDigest,
    ...overrides,
  });
}

function metadata(response) {
  return response.cards.length
    ? response.cards[0].extension['org.parkinsum.fhir-cql-retrieval']
    : response.extension['org.parkinsum.fhir-cql-retrieval-response'];
}

test('the fixed FHIR retrieval cases project to one information card and two no-guidance responses', () => {
  assert.equal(corpus.schemaVersion, 2);
  assert.equal(corpus.cases.length, 3);
  const responses = corpus.cases.map(project);
  assert.deepEqual(responses.map((response) => response.cards.length), [1, 0, 0]);
  for (const response of responses) {
    assert.deepEqual(validateInformationOnlyResponse(response), {
      valid: true,
      findings: [],
    });
  }
  assert.equal(metadata(responses[0]).caseId, 'condition_present');
  assert.equal(metadata(responses[0]).cqlResult, 'true');
  for (const response of responses.slice(1)) {
    assert.equal(response.extension[
      'org.parkinsum.fhir-cql-retrieval-response'
    ].cqlResult, 'false');
    assert.deepEqual(response.extension[
      'org.parkinsum.fhir-cql-retrieval-response'
    ].warnings, ['criterion_not_met']);
    assert.deepEqual(response.extension[
      'org.parkinsum.fhir-cql-retrieval-response'
    ].errors, []);
  }
});

test('the integrated projection report binds exact cross-engine rows and omits Bundle identities', () => {
  const googleCqlRows = corpus.cases.map((testCase) => ({
    id: testCase.id,
    result: testCase.expectedCql,
    errors: testCase.expectedResponseErrors,
    warnings: testCase.expectedResponseWarnings,
  }));
  const cqfJvmRows = structuredClone(googleCqlRows);
  const report = buildFhirCqlHooksProjectionReport({
    corpus,
    googleCqlRows,
    cqfJvmRows,
    ...engines,
    corpusDigest,
  });
  assert.equal(report.schemaVersion, 1);
  assert.equal(report.status, 'passed');
  assert.equal(report.caseCount, 3);
  assert.equal(report.engineOutcomeParityCount, 3);
  assert.equal(report.diagnosticParityCount, 3);
  assert.equal(report.informationCardCount, 1);
  assert.equal(report.emptyCardsCount, 2);
  const serialized = JSON.stringify(report);
  for (const testCase of corpus.cases) {
    assert.equal(serialized.includes(testCase.patientContextId), false);
  }
  assert.equal(serialized.includes('synthetic-condition-'), false);
  assert.equal(serialized.includes('condition-placeholder'), false);
  assert.throws(() => buildFhirCqlHooksProjectionReport({
    corpus,
    googleCqlRows,
    cqfJvmRows: cqfJvmRows.slice(1),
    ...engines,
    corpusDigest,
  }), /exactly three fixed cases/);
  assert.throws(() => buildFhirCqlHooksProjectionReport({
    corpus,
    googleCqlRows,
    cqfJvmRows: [cqfJvmRows[0], cqfJvmRows[1], cqfJvmRows[1]],
    ...engines,
    corpusDigest,
  }), /duplicate or unexpected/);
});

test('the foreign-subject Condition remains outside the declared Patient result', () => {
  const testCase = corpus.cases.find((item) => item.id === 'condition_foreign_patient');
  const response = project(testCase);
  assert.deepEqual(response.cards, []);
  assert.equal(metadata(response).cqlResult, 'false');
  assert.equal(JSON.stringify(response).includes(testCase.patientContextId), false);
  assert.equal(JSON.stringify(response).includes('synthetic-patient-other'), false);
  assert.equal(JSON.stringify(response).includes('synthetic-condition-foreign'), false);
  assert.equal(JSON.stringify(response).includes('condition-placeholder'), false);
});

test('responses retain only fixed case identity and engine evidence, never Bundle fields', () => {
  for (const testCase of corpus.cases) {
    const response = project(testCase);
    const serialized = JSON.stringify(response);
    assert.equal(serialized.includes(testCase.patientContextId), false);
    assert.equal(serialized.includes('synthetic-condition-'), false);
    assert.equal(serialized.includes('urn:parkinsum:synthetic-test'), false);
    assert.equal(metadata(response).corpusDigest, corpusDigest);
    assert.equal(metadata(response).engineOutcomeRelation, 'same');
    assert.equal(metadata(response).diagnosticRelation, 'same');
  }
});

test('engine drift, diagnostic drift, unknown cases, and malformed digests fail closed', () => {
  const testCase = corpus.cases[0];
  assert.throws(() => project(testCase, { cqfJvmResult: 'false' }), /disagree/);
  assert.throws(() => project(testCase, { googleCqlWarnings: ['unsupported_diagnostic'] }), /reviewed synthetic diagnostic/);
  assert.throws(() => project(testCase, { cqfJvmErrors: ['unexpected'] }), /reviewed synthetic diagnostic/);
  assert.throws(() => project(testCase, { googleCqlPackage: 'google-cql@latest' }), /identities/);
  assert.throws(() => project(testCase, { corpusDigest: 'bad' }), /SHA-256/);
  assert.throws(() => project({ ...testCase, id: 'unknown_case' }), /outside the fixed/);
});

test('the response contract rejects raw FHIR identity, outcome, and extension drift', () => {
  const trueResponse = project(corpus.cases[0]);
  const rawPatient = structuredClone(trueResponse);
  metadata(rawPatient).patientContextId = corpus.cases[0].patientContextId;
  assert.equal(validateInformationOnlyResponse(rawPatient).valid, false);

  const falseResponse = project(corpus.cases[1]);
  const falseAsCard = structuredClone(falseResponse);
  falseAsCard.cards = [{
    summary: 'Synthetic FHIR/CQL retrieval: false',
    detail: 'test',
    indicator: 'info',
    source: { label: 'test' },
    extension: {
      'org.parkinsum.fhir-cql-retrieval': {
        ...metadata(falseAsCard),
        caseId: 'condition_present',
        cqlResult: 'false',
      },
    },
  }];
  assert.equal(validateInformationOnlyResponse(falseAsCard).valid, false);

  const addedAction = structuredClone(trueResponse);
  addedAction.cards[0].suggestions = [];
  const validation = validateInformationOnlyResponse(addedAction);
  assert.equal(validation.valid, false);
  assert(validation.findings.some((finding) => finding.code === 'actionable_content_disallowed'));
});
