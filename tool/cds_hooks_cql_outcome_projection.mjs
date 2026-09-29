// Test-only projection of a real, synthetic CQL differential result into one
// information-only CDS Hooks card. The input digest is stable and unsalted;
// this module is restricted to the manufactured differential corpus.
import { createHash } from 'node:crypto';

import { validateInformationOnlyResponse } from './cds_hooks_information_card_contract.mjs';

const cqlResultValues = new Set(['true', 'false', 'unknown']);
const cqlEngineRelationValues = new Set([
  'same',
  'documented-semantic-difference',
]);
const relationValues = new Set([
  'same',
  'unknown-escalated-to-review',
  'documented-semantic-difference',
]);
const responseErrorCodes = new Set(['evaluation_indeterminate']);
const responseWarningCodes = new Set(['criterion_not_met']);
const digestPattern = /^[0-9a-f]{64}$/;
const responseSourceRefs = Object.freeze([
  'test/fixtures/cql_rule_differential_corpus.json',
  'docs/CQL_RULE_DIFFERENTIAL.md',
  'docs/CDSS_OPEN_SOURCE_LANDSCAPE_2026-09-22.md',
]);
const sourceRefs = Object.freeze([
  'test/fixtures/cql_rule_differential_corpus.json',
  'docs/CQL_RULE_DIFFERENTIAL.md',
]);

export function projectCqlDifferentialInformationCard({
  testCase,
  cqlResult,
  independentCqlResult,
  dartResult,
  cqlPackage,
  cqlExecutionPackage,
  corpusDigest,
  responseErrors,
  responseWarnings,
}) {
  requireRecord(testCase, 'testCase');
  requireRecord(dartResult, 'dartResult');
  const caseId = requireText(testCase.id, 'case id');
  const caseClass = requireText(testCase.class, 'case class');
  const ruleVersion = requireText(dartResult.ruleVersion, 'rule version');
  const rulePackVersion = requireText(
    dartResult.rulePackVersion,
    'rule-pack version',
  );
  const packageIdentity = requireText(cqlPackage, 'CQL package identity');
  const independentPackageIdentity = requireText(
    cqlExecutionPackage,
    'independent CQL package identity',
  );
  const corpusHash = requireDigest(corpusDigest, 'corpus digest');
  if (!cqlResultValues.has(cqlResult)) {
    throw new TypeError('CQL result must be true, false, or unknown.');
  }
  if (!cqlResultValues.has(independentCqlResult)) {
    throw new TypeError('Independent CQL result must be true, false, or unknown.');
  }
  if (!/^@cqframework\/cql@[0-9]+\.[0-9]+\.[0-9]+$/.test(packageIdentity) ||
      !/^cql-execution@[0-9]+\.[0-9]+\.[0-9]+$/.test(independentPackageIdentity)) {
    throw new TypeError('CQL engine package identities must be exact semantic versions.');
  }
  if (testCase.expectedCql !== cqlResult) {
    throw new Error(`CQL result disagrees with the fixed case ${caseId}.`);
  }
  const errors = requireDiagnosticCodes(
    responseErrors,
    responseErrorCodes,
    'response errors',
  );
  const warnings = requireDiagnosticCodes(
    responseWarnings,
    responseWarningCodes,
    'response warnings',
  );
  if (JSON.stringify(errors) !== JSON.stringify(testCase.expectedResponseErrors) ||
      JSON.stringify(warnings) !== JSON.stringify(testCase.expectedResponseWarnings)) {
    throw new Error(`Response diagnostics disagree with the fixed case ${caseId}.`);
  }
  if (dartResult.id !== caseId) {
    throw new Error('Dart result and CQL case identifiers disagree.');
  }
  if (typeof dartResult.runtimeMatched !== 'boolean' ||
      typeof dartResult.reviewRecommended !== 'boolean' ||
      !Array.isArray(dartResult.missingFields) ||
      dartResult.missingFields.length > 64 ||
      dartResult.missingFields.some((field) =>
        typeof field !== 'string' || field.trim() === '' || [...field].length > 256)) {
    throw new TypeError('Dart synthetic result is malformed.');
  }
  if (dartResult.runtimeMatched !== testCase.expectedRuntimeMatch ||
      dartResult.reviewRecommended !== testCase.expectedReview ||
      dartResult.reviewRecommended !== (dartResult.missingFields.length > 0)) {
    throw new Error(`Dart result disagrees with the fixed case ${caseId}.`);
  }

  const relation = cqlResult === (dartResult.runtimeMatched ? 'true' : 'false')
    ? 'same'
    : dartResult.reviewRecommended && cqlResult === 'unknown' &&
        !dartResult.runtimeMatched
      ? 'unknown-escalated-to-review'
      : 'documented-semantic-difference';
  const cqlEngineRelation = cqlResult === independentCqlResult
    ? 'same'
    : 'documented-semantic-difference';
  if (!cqlEngineRelationValues.has(cqlEngineRelation)) {
    throw new Error(`Unsupported CQL engine relation for ${caseId}.`);
  }
  if (!relationValues.has(relation)) {
    throw new Error(`Unsupported differential relation for ${caseId}.`);
  }

  const inputDigest = createHash('sha256')
    .update(canonicalJson(testCase.input))
    .digest('hex');
  const missingFields = [...dartResult.missingFields];
  const card = {
    summary: `Synthetic CQL evaluation: ${cqlResult}`,
    detail: [
      `Differential case: ${caseId} (${caseClass}).`,
      `CQL result: ${cqlResult}.`,
      `Independent CQL engine result (${independentPackageIdentity}): ${independentCqlResult}.`,
      `CQL engine relation: ${cqlEngineRelation}.`,
      `Dart candidate matched: ${dartResult.runtimeMatched}.`,
      `Dart missing-field codes: ${missingFields.length
        ? missingFields.join(', ')
        : 'none'}.`,
      `Engine relation: ${relation}.`,
      'Synthetic engineering comparison only; this is not clinical guidance or medical advice.',
    ].join('\n\n'),
    indicator: 'info',
    source: {
      label: 'ParkinSUM synthetic CQL differential',
    },
    extension: {
      'org.parkinsum.cql-differential': {
        schemaVersion: '1.0.0',
        caseId,
        caseClass,
        ruleId: `cql-diff.${caseId}`,
        ruleVersion,
        rulePackVersion,
        cqlPackage: packageIdentity,
        cqlExecutionPackage: independentPackageIdentity,
        corpusDigest: corpusHash,
        inputDigest,
        cqlResult,
        independentCqlResult,
        cqlEngineRelation,
        dartRuntimeMatch: dartResult.runtimeMatched,
        missingFields,
        inputCompleteness: missingFields.length ? 'incomplete' : 'complete',
        reviewRecommended: dartResult.reviewRecommended,
        relation,
        sourceRefs,
      },
    },
  };
  const response = {
    cards: cqlResult === 'true' ? [card] : [],
  };
  if (errors.length > 0 || warnings.length > 0) {
    response.extension = {
      'org.parkinsum.cql-differential-response': {
        schemaVersion: '1.0.0',
        caseId,
        cqlResult,
        cqlPackage: packageIdentity,
        cqlExecutionPackage: independentPackageIdentity,
        corpusDigest: corpusHash,
        errors,
        warnings,
        sourceRefs: responseSourceRefs,
      },
    };
  }
  const validation = validateInformationOnlyResponse(response);
  if (!validation.valid) {
    throw new Error(
      `Generated CQL card violates the information-only contract: ${JSON.stringify(validation.findings)}`,
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

function requireDigest(value, field) {
  const digest = requireText(value, field);
  if (!digestPattern.test(digest)) {
    throw new TypeError(`${field} must be a lowercase SHA-256 digest.`);
  }
  return digest;
}

function requireDiagnosticCodes(value, allowedCodes, field) {
  if (!Array.isArray(value) || value.length > 1 ||
      value.some((code) => typeof code !== 'string' || !allowedCodes.has(code))) {
    throw new TypeError(`${field} must contain only reviewed synthetic diagnostic codes.`);
  }
  return [...value];
}

function canonicalJson(value) {
  if (value === null || typeof value === 'string' || typeof value === 'boolean') {
    return JSON.stringify(value);
  }
  if (typeof value === 'number' && Number.isFinite(value)) {
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    return '[' + value.map(canonicalJson).join(',') + ']';
  }
  if (value !== null && typeof value === 'object') {
    return '{' + Object.keys(value).sort().map((key) =>
      JSON.stringify(key) + ':' + canonicalJson(value[key])).join(',') + '}';
  }
  throw new TypeError('CQL case input must be canonical JSON data.');
}
