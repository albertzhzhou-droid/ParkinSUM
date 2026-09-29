import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import test from 'node:test';

import { validateInformationOnlyResponse } from './cds_hooks_information_card_contract.mjs';
import {
  buildFhirObservationCqlHooksProjectionReport,
  projectFhirObservationCqlMembership,
} from './cds_hooks_fhir_observation_projection.mjs';

const fixtureBytes = fs.readFileSync(
  'test/fixtures/cql_fhir_r4_observation_retrieval_corpus.json',
);
const corpus = JSON.parse(fixtureBytes.toString('utf8'));
const corpusDigest = createHash('sha256').update(fixtureBytes).digest('hex');
const engines = {
  googleCqlPackage: 'github.com/google/cql@v0.0.3-0.20260814184421-b9169ccd54a3',
  javaScriptExecutionPath: 'cql-execution@3.3.2 + cql-exec-fhir@2.1.6',
  cqfJvmEngine: 'org.cqframework:engine@5.3.0',
  cqfJvmFhirArtifact: 'org.cqframework:engine-fhir@5.3.0',
  corpusDigest,
};

function fixedProviderCases() {
  return corpus.cases.map((testCase) => ({
    id: testCase.id,
    googleCqlMembership: testCase.expectedRuntimeValueSetMembership,
    javaScriptMembership: testCase.expectedRuntimeValueSetMembership,
    cqfJvmMembership: testCase.expectedVersionAwareMembership,
  }));
}

test('six fixed Observation cases project to one information card, four no-guidance results, and one withheld mismatch', () => {
  assert.equal(corpus.schemaVersion, 2);
  const report = buildFhirObservationCqlHooksProjectionReport({
    cases: fixedProviderCases(),
    ...engines,
  });
  assert.equal(report.schemaVersion, 1);
  assert.equal(report.caseCount, 6);
  assert.equal(report.agreedOutcomeCount, 5);
  assert.equal(report.diagnosticParityCount, 6);
  assert.equal(report.informationCardCount, 1);
  assert.equal(report.noGuidanceCount, 4);
  assert.equal(report.withheldCount, 1);
  assert.equal(report.results[0].informationCard.indicator, 'info');
  assert.equal(report.results[0].projectedResult, 'true');
  assert.deepEqual(report.results.slice(1, 5).map((row) => row.projectedResult), [
    'false', 'false', 'false', 'false',
  ]);
  assert.equal(report.results[5].projectedResult, 'unknown');
  assert.equal(report.results[5].cardsReturned, 0);
  assert.deepEqual(report.results[5].responseLevelExtension.errors, ['engine_disagreement']);
  assert.deepEqual(report.results[5].responseLevelExtension.warnings, []);
  assert.throws(() => buildFhirObservationCqlHooksProjectionReport({
    cases: casesWithExtraIdentity(),
    ...engines,
  }), /unsupported fields/);
});

test('only the fixed matching Observation case can produce an informational card', () => {
  const report = buildFhirObservationCqlHooksProjectionReport({
    cases: fixedProviderCases(),
    ...engines,
  });
  const cards = report.results.filter((row) => row.informationCard !== null);
  assert.deepEqual(cards.map((row) => row.id), ['observation_present']);
  const response = { cards: [cards[0].informationCard] };
  assert.deepEqual(validateInformationOnlyResponse(response), { valid: true, findings: [] });
  assert.equal(validateInformationOnlyResponse({
    cards: [cards[0].informationCard, cards[0].informationCard],
  }).valid, false);
  const noMatch = report.results.find((row) => row.id === 'observation_absent');
  assert.deepEqual(validateInformationOnlyResponse({
    cards: [],
    extension: { 'org.parkinsum.fhir-observation-cql-response': noMatch.responseLevelExtension },
  }), { valid: true, findings: [] });
  const mismatch = report.results.find((row) => row.id === 'observation_system_version_mismatch');
  assert.deepEqual(validateInformationOnlyResponse({
    cards: [],
    extension: { 'org.parkinsum.fhir-observation-cql-response': mismatch.responseLevelExtension },
  }), { valid: true, findings: [] });
});

function casesWithExtraIdentity() {
  return fixedProviderCases().map((row, index) => index === 0
    ? { ...row, patientContextId: 'synthetic-patient-leak' }
    : row);
}

test('the report contains no Patient, Observation, Bundle, or code values', () => {
  const report = buildFhirObservationCqlHooksProjectionReport({
    cases: fixedProviderCases(),
    ...engines,
  });
  const serialized = JSON.stringify(report);
  for (const testCase of corpus.cases) {
    assert.equal(serialized.includes(testCase.patientContextId), false);
  }
  for (const forbidden of [
    'synthetic-observation-',
    'observation-in-set',
    'observation-outside-set',
    'synthetic-patient-',
    '"resourceType":"Bundle"',
  ]) {
    assert.equal(serialized.includes(forbidden), false);
  }
  assert.equal(report.corpusSha256, corpusDigest);
});

test('provider, case, and engine drift fail closed before projection', () => {
  const cases = fixedProviderCases();
  assert.throws(() => buildFhirObservationCqlHooksProjectionReport({
    cases: cases.slice(1), ...engines,
  }), /exactly the six fixed/);
  assert.throws(() => buildFhirObservationCqlHooksProjectionReport({
    cases: cases.map((row, index) => index === 5 ? { ...row, cqfJvmMembership: true } : row),
    ...engines,
  }), /outcomes drifted/);
  assert.throws(() => buildFhirObservationCqlHooksProjectionReport({
    cases,
    ...engines,
    javaScriptExecutionPath: 'cql-execution@latest',
  }), /identities/);
  assert.throws(() => projectFhirObservationCqlMembership({
    ...cases[0], ...engines, corpusDigest: 'bad',
  }), /SHA-256/);
});

test('the response contract rejects actions, identifiers, and a card for the withheld mismatch', () => {
  const report = buildFhirObservationCqlHooksProjectionReport({
    cases: fixedProviderCases(),
    ...engines,
  });
  const mismatch = report.results[5];
  const response = {
    cards: [],
    extension: { 'org.parkinsum.fhir-observation-cql-response': mismatch.responseLevelExtension },
  };
  const rawIdentifier = structuredClone(response);
  rawIdentifier.extension['org.parkinsum.fhir-observation-cql-response'].patientContextId =
    corpus.cases[5].patientContextId;
  assert.equal(validateInformationOnlyResponse(rawIdentifier).valid, false);

  const action = structuredClone(response);
  action.systemActions = [];
  assert.equal(validateInformationOnlyResponse(action).valid, false);

  const falseCard = structuredClone(response);
  falseCard.cards = [{
    summary: 'Synthetic FHIR/CQL membership: true',
    detail: 'No result should be projected while providers disagree.',
    indicator: 'info',
    source: { label: 'ParkinSUM synthetic FHIR/CQL comparison' },
    extension: { 'org.parkinsum.fhir-observation-cql': mismatch.responseLevelExtension },
  }];
  assert.equal(validateInformationOnlyResponse(falseCard).valid, false);
});
