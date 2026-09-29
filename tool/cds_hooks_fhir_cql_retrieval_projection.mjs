// Test-only bridge from the fixed FHIR R4 retrieval corpus to information-only
// CDS Hooks responses. Patient and resource identifiers never enter the result.
import { validateInformationOnlyResponse } from './cds_hooks_information_card_contract.mjs';

const expectedCases = new Map([
  ['condition_present', 'true'],
  ['condition_absent', 'false'],
  ['condition_foreign_patient', 'false'],
]);
const allowedResults = new Set(['true', 'false']);
const diagnosticCodes = new Set(['criterion_not_met']);
const digestPattern = /^[0-9a-f]{64}$/;
const GOOGLE_CQL_PACKAGE =
  'github.com/google/cql@v0.0.3-0.20260814184421-b9169ccd54a3';
const CQF_JVM_ENGINE = 'org.cqframework:engine@5.3.0';
const CQF_JVM_FHIR_ARTIFACT = 'org.cqframework:engine-fhir@5.3.0';
const sourceRefs = Object.freeze([
  'test/fixtures/cql_fhir_r4_retrieval_corpus.json',
  'docs/CQL_RULE_DIFFERENTIAL.md',
  'docs/CDSS_OPEN_SOURCE_LANDSCAPE_2026-09-22.md',
]);

export function buildFhirCqlHooksProjectionReport({
  corpus,
  googleCqlRows,
  cqfJvmRows,
  googleCqlPackage,
  cqfJvmEngine,
  cqfJvmFhirArtifact,
  corpusDigest,
}) {
  requireRecord(corpus, 'corpus');
  if (corpus.schemaVersion !== 2 ||
      corpus.scope !== 'synthetic-fhir-r4-retrieval' ||
      corpus.fhirVersion !== '4.0.1' ||
      corpus.context !== 'Patient' ||
      corpus.expression !== 'exists([Condition])' ||
      !Array.isArray(corpus.cases) ||
      JSON.stringify(corpus.cases.map((testCase) => testCase?.id)) !==
        JSON.stringify([...expectedCases.keys()])) {
    throw new Error('FHIR/CQL projection report requires the exact fixed retrieval corpus.');
  }
  const googleRows = exactRows(googleCqlRows, 'Google CQL rows');
  const cqfJvmRowsById = exactRows(cqfJvmRows, 'CQF JVM rows');
  const results = corpus.cases.map((testCase) => {
    const google = googleRows.get(testCase.id);
    const cqfJvm = cqfJvmRowsById.get(testCase.id);
    if (!google || !cqfJvm) {
      throw new Error(`FHIR/CQL report is missing a parity row for ${testCase.id}.`);
    }
    const response = projectFhirCqlRetrievalInformationCard({
      testCase,
      googleCqlResult: google.result,
      googleCqlErrors: google.errors ?? [],
      googleCqlWarnings: google.warnings ?? [],
      cqfJvmResult: cqfJvm.result,
      cqfJvmErrors: cqfJvm.errors,
      cqfJvmWarnings: cqfJvm.warnings,
      googleCqlPackage,
      cqfJvmEngine,
      cqfJvmFhirArtifact,
      corpusDigest,
    });
    return {
      id: testCase.id,
      cqlResult: testCase.expectedCql,
      engineOutcomeRelation: 'same',
      diagnosticRelation: 'same',
      cardsReturned: response.cards.length,
      responseLevelExtension: response.extension?.[
        'org.parkinsum.fhir-cql-retrieval-response'
      ] ?? null,
      informationCard: response.cards[0] ?? null,
    };
  });
  const report = {
    schemaVersion: 1,
    status: 'passed',
    fhirVersion: corpus.fhirVersion,
    context: corpus.context,
    expression: corpus.expression,
    corpusSha256: corpusDigest,
    caseCount: results.length,
    engineOutcomeParityCount: results.filter(
      (row) => row.engineOutcomeRelation === 'same',
    ).length,
    diagnosticParityCount: results.filter(
      (row) => row.diagnosticRelation === 'same',
    ).length,
    informationCardCount: results.filter(
      (row) => row.informationCard !== null,
    ).length,
    emptyCardsCount: results.filter((row) => row.cardsReturned === 0).length,
    results,
  };
  if (report.caseCount !== 3 ||
      report.engineOutcomeParityCount !== 3 ||
      report.diagnosticParityCount !== 3 ||
      report.informationCardCount !== 1 ||
      report.emptyCardsCount !== 2) {
    throw new Error('FHIR/CQL projection report does not match its fixed contract.');
  }
  return report;
}

export function projectFhirCqlRetrievalInformationCard({
  testCase,
  googleCqlResult,
  googleCqlErrors,
  googleCqlWarnings,
  cqfJvmResult,
  cqfJvmErrors,
  cqfJvmWarnings,
  googleCqlPackage,
  cqfJvmEngine,
  cqfJvmFhirArtifact,
  corpusDigest,
}) {
  requireRecord(testCase, 'testCase');
  const caseId = requireText(testCase.id, 'case id');
  const expectedResult = expectedCases.get(caseId);
  if (!expectedResult || testCase.expectedCql !== expectedResult) {
    throw new Error(`Case ${caseId} is outside the fixed FHIR retrieval corpus.`);
  }
  if (typeof testCase.patientContextId !== 'string' ||
      !/^synthetic-patient-[a-z0-9-]{1,80}$/.test(testCase.patientContextId)) {
    throw new TypeError('FHIR retrieval case must have a fixed synthetic Patient context.');
  }
  if (googleCqlResult !== expectedResult || cqfJvmResult !== expectedResult) {
    throw new Error(`CQL engines disagree with fixed FHIR case ${caseId}.`);
  }
  if (!allowedResults.has(googleCqlResult) || !allowedResults.has(cqfJvmResult)) {
    throw new TypeError('FHIR CQL result must be true or false for this fixed corpus.');
  }
  const expectedErrors = [];
  const expectedWarnings = expectedResult === 'false' ? ['criterion_not_met'] : [];
  const googleErrors = requireDiagnostics(googleCqlErrors, 'Google CQL errors');
  const jvmErrors = requireDiagnostics(cqfJvmErrors, 'CQF JVM errors');
  const googleWarnings = requireDiagnostics(googleCqlWarnings, 'Google CQL warnings');
  const jvmWarnings = requireDiagnostics(cqfJvmWarnings, 'CQF JVM warnings');
  for (const [label, actual] of [
    ['Google CQL errors', googleErrors],
    ['CQF JVM errors', jvmErrors],
    ['Google CQL warnings', googleWarnings],
    ['CQF JVM warnings', jvmWarnings],
  ]) {
    const expected = label.endsWith('errors') ? expectedErrors : expectedWarnings;
    if (JSON.stringify(actual) !== JSON.stringify(expected)) {
      throw new Error(`${label} disagree with fixed FHIR case ${caseId}.`);
    }
  }
  if (googleCqlPackage !== GOOGLE_CQL_PACKAGE ||
      cqfJvmEngine !== CQF_JVM_ENGINE ||
      cqfJvmFhirArtifact !== CQF_JVM_FHIR_ARTIFACT) {
    throw new Error('FHIR CQL projection engine identities do not match the pinned tools.');
  }
  if (typeof corpusDigest !== 'string' || !digestPattern.test(corpusDigest)) {
    throw new TypeError('FHIR corpus digest must be a lowercase SHA-256 digest.');
  }

  const metadata = {
    schemaVersion: '1.0.0',
    caseId,
    fhirVersion: '4.0.1',
    context: 'Patient',
    cqlExpression: 'exists([Condition])',
    cqlResult: expectedResult,
    googleCqlPackage,
    cqfJvmEngine,
    cqfJvmFhirArtifact,
    engineOutcomeRelation: 'same',
    diagnosticRelation: 'same',
    corpusDigest,
    sourceRefs,
  };
  const response = expectedResult === 'true'
    ? {
        cards: [{
          summary: 'Synthetic FHIR/CQL retrieval: true',
          detail: [
            `Fixed case: ${caseId}.`,
            'The FHIR R4.0.1 Patient-context expression `exists([Condition])` returned true in both pinned development engines.',
            'Manufactured engineering fixture only; this is not clinical guidance.',
          ].join('\n\n'),
          indicator: 'info',
          source: { label: 'ParkinSUM synthetic FHIR/CQL comparison' },
          extension: { 'org.parkinsum.fhir-cql-retrieval': metadata },
        }],
      }
    : {
        cards: [],
        extension: {
          'org.parkinsum.fhir-cql-retrieval-response': {
            ...metadata,
            errors: expectedErrors,
            warnings: expectedWarnings,
          },
        },
      };
  const validation = validateInformationOnlyResponse(response);
  if (!validation.valid) {
    throw new Error(
      `Generated FHIR/CQL card violates the information-only contract: ${JSON.stringify(validation.findings)}`,
    );
  }
  return response;
}

function requireRecord(value, field) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new TypeError(`${field} must be an object.`);
  }
}

function requireText(value, field) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new TypeError(`${field} is required.`);
  }
  return value;
}

function requireDiagnostics(value, label) {
  if (!Array.isArray(value) || value.length > 1 ||
      value.some((item) => typeof item !== 'string' || !diagnosticCodes.has(item))) {
    throw new TypeError(`${label} must contain only reviewed synthetic diagnostic codes.`);
  }
  return [...value];
}

function exactRows(rows, label) {
  if (!Array.isArray(rows) || rows.length !== expectedCases.size) {
    throw new TypeError(`${label} must contain exactly three fixed cases.`);
  }
  const byId = new Map();
  for (const row of rows) {
    requireRecord(row, `${label} row`);
    if (typeof row.id !== 'string' ||
        !expectedCases.has(row.id) || byId.has(row.id)) {
      throw new Error(`${label} has a duplicate or unexpected case identity.`);
    }
    byId.set(row.id, row);
  }
  if (byId.size !== expectedCases.size) {
    throw new Error(`${label} is missing a fixed case.`);
  }
  return byId;
}
