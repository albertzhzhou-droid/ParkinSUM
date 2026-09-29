import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import test from 'node:test';

import { validateInformationOnlyResponse } from './cds_hooks_information_card_contract.mjs';
import { projectCqlDifferentialInformationCard } from './cds_hooks_cql_outcome_projection.mjs';

const corpus = JSON.parse(
  fs.readFileSync('test/fixtures/cql_rule_differential_corpus.json', 'utf8'),
);
const packageJson = JSON.parse(fs.readFileSync('package.json', 'utf8'));
const corpusDigest = createHash('sha256')
  .update(fs.readFileSync('test/fixtures/cql_rule_differential_corpus.json'))
  .digest('hex');
const cqlPackage = `@cqframework/cql@${packageJson.devDependencies['@cqframework/cql']}`;
const cqlExecutionPackage = `cql-execution@${packageJson.devDependencies['cql-execution']}`;

function dartResultFor(testCase) {
  const missingFields = testCase.input.dailyDoseMg === null
    ? ['dose']
    : testCase.input.drugTime === null
      ? ['time']
      : [];
  return {
    id: testCase.id,
    ruleVersion: '1.0.0',
    rulePackVersion: 'cql_differential_1',
    runtimeMatched: testCase.expectedRuntimeMatch,
    missingFields,
    reviewRecommended: testCase.expectedReview,
  };
}

function project(testCase, overrides = {}) {
  return projectCqlDifferentialInformationCard({
    testCase,
    cqlResult: testCase.expectedCql,
    independentCqlResult: testCase.expectedCql,
    dartResult: dartResultFor(testCase),
    cqlPackage,
    cqlExecutionPackage,
    corpusDigest,
    responseErrors: testCase.expectedResponseErrors,
    responseWarnings: testCase.expectedResponseWarnings,
    ...overrides,
  });
}

function cqlMetadata(response) {
  return response.cards[0].extension['org.parkinsum.cql-differential'];
}

function responseMetadata(response) {
  return response.extension?.['org.parkinsum.cql-differential-response'];
}

test('every CQL differential case maps to a card or a response-level diagnostic', () => {
  assert.equal(corpus.schemaVersion, 2);
  assert.equal(corpus.cases.length, 9);
  for (const testCase of corpus.cases) {
    const response = project(testCase);
    assert.deepEqual(validateInformationOnlyResponse(response), {
      valid: true,
      findings: [],
    });
    if (testCase.expectedCql === 'true') {
      assert.equal(response.cards.length, 1);
      const card = response.cards[0];
      const metadata = cqlMetadata(response);
      assert.equal(card.indicator, 'info');
      assert.equal(metadata.caseId, testCase.id);
      assert.equal(metadata.cqlResult, testCase.expectedCql);
      assert.equal(metadata.rulePackVersion, 'cql_differential_1');
      assert.equal(metadata.cqlPackage, '@cqframework/cql@5.3.0');
      assert.equal(metadata.cqlExecutionPackage, 'cql-execution@3.3.2');
      assert.equal(metadata.independentCqlResult, testCase.expectedCql);
      assert.equal(metadata.cqlEngineRelation, 'same');
      assert.equal(metadata.corpusDigest, corpusDigest);
      assert.equal(metadata.inputCompleteness,
        metadata.missingFields.length ? 'incomplete' : 'complete');
      assert.ok(metadata.sourceRefs.includes('test/fixtures/cql_rule_differential_corpus.json'));
      assert.equal(responseMetadata(response), undefined);
    } else {
      assert.deepEqual(response.cards, []);
      assert.equal(responseMetadata(response).caseId, testCase.id);
      assert.equal(responseMetadata(response).cqlResult, testCase.expectedCql);
      assert.deepEqual(responseMetadata(response).errors, testCase.expectedResponseErrors);
      assert.deepEqual(responseMetadata(response).warnings, testCase.expectedResponseWarnings);
    }
  }
});

test('CQL unknown stays unknown for both missing-input and unsupported-unit differences', () => {
  const missing = corpus.cases.find((testCase) => testCase.id === 'dose_unknown');
  const missingResponse = project(missing);
  assert.deepEqual(missingResponse.cards, []);
  assert.equal(responseMetadata(missingResponse).cqlResult, 'unknown');
  assert.deepEqual(responseMetadata(missingResponse).errors, ['evaluation_indeterminate']);
  assert.deepEqual(responseMetadata(missingResponse).warnings, []);

  const unsupported = corpus.cases.find((testCase) => testCase.id === 'unit_unsupported');
  const unsupportedResponse = project(unsupported);
  assert.deepEqual(unsupportedResponse.cards, []);
  assert.equal(responseMetadata(unsupportedResponse).cqlResult, 'unknown');
  assert.deepEqual(responseMetadata(unsupportedResponse).errors, ['evaluation_indeterminate']);
  assert.deepEqual(responseMetadata(unsupportedResponse).warnings, []);
});

test('cards carry a stable digest and no raw synthetic input values', () => {
  const testCase = corpus.cases.find((item) => item.id === 'time_exactly_60_minutes');
  const card = project(testCase).cards[0];
  const metadata = card.extension['org.parkinsum.cql-differential'];
  assert.match(metadata.inputDigest, /^[0-9a-f]{64}$/);
  assert.equal(metadata.inputDigest,
    cqlMetadata(project(testCase)).inputDigest);
  assert.equal(card.detail.includes('2026-09-20T09:00:00.000Z'), false);
  assert.equal(card.detail.includes('2026-09-20T08:00:00.000Z'), false);
  assert.match(card.detail, /not clinical guidance or medical advice/);
});

test('mismatched outcomes and malformed runtime provenance are rejected', () => {
  const testCase = corpus.cases.find((item) => item.id === 'dose_unknown');
  assert.throws(
    () => projectCqlDifferentialInformationCard({
      testCase,
      cqlResult: 'false',
      independentCqlResult: 'unknown',
      dartResult: dartResultFor(testCase),
      cqlPackage,
      cqlExecutionPackage,
      corpusDigest,
      responseErrors: testCase.expectedResponseErrors,
      responseWarnings: testCase.expectedResponseWarnings,
    }),
    /disagrees with the fixed case/,
  );

  const malformedDart = {
    ...dartResultFor(testCase),
    missingFields: [],
  };
  assert.throws(
    () => projectCqlDifferentialInformationCard({
      testCase,
      cqlResult: 'unknown',
      independentCqlResult: 'unknown',
      dartResult: malformedDart,
      cqlPackage,
      cqlExecutionPackage,
      corpusDigest,
      responseErrors: testCase.expectedResponseErrors,
      responseWarnings: testCase.expectedResponseWarnings,
    }),
    /disagrees with the fixed case/,
  );

  assert.throws(() => project(testCase, { corpusDigest: 'bad' }), /SHA-256/);
  assert.throws(() => project(testCase, { independentCqlResult: 'not_matched' }), /Independent CQL result/);
  assert.throws(() => project(testCase, { cqlExecutionPackage: 'cql-execution@latest' }), /exact semantic versions/);
});

test('the CQL card contract rejects state, completeness, engine relation, and identity drift', () => {
  const response = project(corpus.cases.find((item) => item.id === 'dose_true'));
  const metadata = cqlMetadata(response);

  for (const [field, value, finding] of [
    ['cqlResult', 'not_matched', 'invalid_cql_result'],
    ['independentCqlResult', 'not_matched', 'invalid_independent_cql_result'],
    ['cqlEngineRelation', 'documented-semantic-difference', 'cql_engine_relation_mismatch'],
    ['inputCompleteness', 'incomplete', 'cql_input_completeness_mismatch'],
    ['relation', 'unknown-escalated-to-review', 'cql_relation_mismatch'],
    ['ruleId', 'patient-123', 'cql_rule_id_mismatch'],
  ]) {
    const mutated = structuredClone(response);
    cqlMetadata(mutated)[field] = value;
    const result = validateInformationOnlyResponse(mutated);
    assert.equal(result.valid, false);
    assert(result.findings.some((item) => item.code === finding), finding);
  }
});

test('response diagnostics survive an empty cards result and carry no input values', () => {
  for (const testCase of corpus.cases.filter((item) => item.expectedCql !== 'true')) {
    const response = project(testCase);
    assert.deepEqual(response.cards, []);
    assert.equal(validateInformationOnlyResponse(response).valid, true);
    assert.equal(JSON.stringify(response.extension).includes('dailyDoseMg'), false);
    assert.equal(JSON.stringify(response.extension).includes('2026-09-20T'), false);
  }
});
