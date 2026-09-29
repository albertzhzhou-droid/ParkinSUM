// Fixed synthetic FHIR Observation/CQL membership projection for developer tests.
// A provider disagreement always withholds the card and remains response-level.
import { validateInformationOnlyResponse } from './cds_hooks_information_card_contract.mjs';

const fixedProviderResults = new Map([
  ['observation_present', [true, true, true]],
  ['observation_absent', [false, false, false]],
  ['observation_foreign_subject', [false, false, false]],
  ['observation_non_member_code', [false, false, false]],
  ['observation_foreign_code_system', [false, false, false]],
  ['observation_system_version_mismatch', [true, true, false]],
]);
const expectedCaseIds = [...fixedProviderResults.keys()];
const allowedCaseFields = new Set([
  'id', 'googleCqlMembership', 'javaScriptMembership', 'cqfJvmMembership',
]);
const GOOGLE_CQL_PACKAGE =
  'github.com/google/cql@v0.0.3-0.20260814184421-b9169ccd54a3';
const JAVASCRIPT_EXECUTION_PATH =
  'cql-execution@3.3.2 + cql-exec-fhir@2.1.6';
const CQF_JVM_ENGINE = 'org.cqframework:engine@5.3.0';
const CQF_JVM_FHIR_ARTIFACT = 'org.cqframework:engine-fhir@5.3.0';
const corpusDigestPattern = /^[0-9a-f]{64}$/;
const sourceRefs = Object.freeze([
  'test/fixtures/cql_fhir_r4_observation_retrieval_corpus.json',
  'docs/CQL_RULE_DIFFERENTIAL.md',
  'docs/CDSS_OPEN_SOURCE_LANDSCAPE_2026-09-22.md',
]);

export function buildFhirObservationCqlHooksProjectionReport({
  cases,
  googleCqlPackage,
  javaScriptExecutionPath,
  cqfJvmEngine,
  cqfJvmFhirArtifact,
  corpusDigest,
}) {
  if (!Array.isArray(cases) || cases.length !== expectedCaseIds.length ||
      JSON.stringify(cases.map((item) => item?.id)) !== JSON.stringify(expectedCaseIds)) {
    throw new Error('Observation projection requires exactly the six fixed synthetic cases.');
  }
  const results = cases.map((item) => projectFhirObservationCqlMembership({
    ...requireProjectionCase(item),
    googleCqlPackage,
    javaScriptExecutionPath,
    cqfJvmEngine,
    cqfJvmFhirArtifact,
    corpusDigest,
  }));
  const report = {
    schemaVersion: 1,
    status: 'passed',
    fhirVersion: '4.0.1',
    context: 'Patient',
    cqlExpression: 'exists([Observation: code in "Synthetic Observation Codes"])',
    corpusSha256: corpusDigest,
    caseCount: results.length,
    agreedOutcomeCount: results.filter((row) => row.engineOutcomeRelation === 'same').length,
    diagnosticParityCount: results.filter((row) => row.diagnosticRelation === 'same').length,
    informationCardCount: results.filter((row) => row.informationCard !== null).length,
    noGuidanceCount: results.filter((row) => row.projectedResult === 'false').length,
    withheldCount: results.filter((row) => row.projectedResult === 'unknown').length,
    results,
  };
  if (report.caseCount !== 6 || report.agreedOutcomeCount !== 5 ||
      report.diagnosticParityCount !== 6 || report.informationCardCount !== 1 ||
      report.noGuidanceCount !== 4 || report.withheldCount !== 1) {
    throw new Error('Observation projection report does not match its fixed fail-closed contract.');
  }
  return report;
}

function requireProjectionCase(item) {
  if (item === null || typeof item !== 'object' || Array.isArray(item) ||
      Object.keys(item).some((field) => !allowedCaseFields.has(field))) {
    throw new TypeError('Observation projection case contains unsupported fields.');
  }
  return item;
}

export function projectFhirObservationCqlMembership({
  id,
  googleCqlMembership,
  javaScriptMembership,
  cqfJvmMembership,
  googleCqlPackage,
  javaScriptExecutionPath,
  cqfJvmEngine,
  cqfJvmFhirArtifact,
  corpusDigest,
}) {
  const expected = fixedProviderResults.get(id);
  if (!expected) throw new Error(`Case ${id} is outside the fixed Observation corpus.`);
  const actual = [googleCqlMembership, javaScriptMembership, cqfJvmMembership];
  if (actual.some((value) => typeof value !== 'boolean') ||
      JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`Pinned CQL provider outcomes drifted for fixed case ${id}.`);
  }
  if (googleCqlPackage !== GOOGLE_CQL_PACKAGE ||
      javaScriptExecutionPath !== JAVASCRIPT_EXECUTION_PATH ||
      cqfJvmEngine !== CQF_JVM_ENGINE ||
      cqfJvmFhirArtifact !== CQF_JVM_FHIR_ARTIFACT) {
    throw new Error('Observation projection engine identities do not match the pinned tools.');
  }
  if (typeof corpusDigest !== 'string' || !corpusDigestPattern.test(corpusDigest)) {
    throw new TypeError('Observation corpus digest must be a lowercase SHA-256 digest.');
  }

  const same = actual.every((value) => value === actual[0]);
  const projectedResult = same ? String(actual[0]) : 'unknown';
  const metadata = {
    schemaVersion: '1.0.0',
    caseId: id,
    fhirVersion: '4.0.1',
    context: 'Patient',
    cqlExpression: 'exists([Observation: code in "Synthetic Observation Codes"])',
    googleCqlMembership,
    javaScriptMembership,
    cqfJvmMembership,
    googleCqlPackage,
    javaScriptExecutionPath,
    cqfJvmEngine,
    cqfJvmFhirArtifact,
    engineOutcomeRelation: same ? 'same' : 'documented-provider-difference',
    diagnosticRelation: 'same',
    projectedResult,
    corpusDigest,
    sourceRefs,
  };
  const response = projectedResult === 'true'
    ? {
        cards: [{
          summary: 'Synthetic FHIR/CQL membership: true',
          detail: [
            `Fixed case: ${id}.`,
            'The three pinned development paths agree that the manufactured Observation matches the local synthetic ValueSet.',
            'This is an engineering fixture only; it is not clinical guidance or a terminology-conformance result.',
          ].join('\n\n'),
          indicator: 'info',
          source: { label: 'ParkinSUM synthetic FHIR/CQL comparison' },
          extension: { 'org.parkinsum.fhir-observation-cql': metadata },
        }],
      }
    : {
        cards: [],
        extension: {
          'org.parkinsum.fhir-observation-cql-response': {
            ...metadata,
            errors: projectedResult === 'unknown' ? ['engine_disagreement'] : [],
            warnings: projectedResult === 'false' ? ['criterion_not_met'] : [],
          },
        },
      };
  const validation = validateInformationOnlyResponse(response);
  if (!validation.valid) {
    throw new Error(
      `Generated Observation projection violates the information-only contract: ${JSON.stringify(validation.findings)}`,
    );
  }
  return {
    id,
    projectedResult,
    engineOutcomeRelation: metadata.engineOutcomeRelation,
    diagnosticRelation: metadata.diagnosticRelation,
    cardsReturned: response.cards.length,
    responseLevelExtension: response.extension?.[
      'org.parkinsum.fhir-observation-cql-response'
    ] ?? null,
    informationCard: response.cards[0] ?? null,
  };
}
