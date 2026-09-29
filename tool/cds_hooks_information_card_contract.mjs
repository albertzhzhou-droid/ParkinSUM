#!/usr/bin/env node

// Test-only CDS Hooks v2.0 subset for synthetic, information-only cards.
// This module never opens a network connection or handles a hook request.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const allowedResponseFields = new Set(['cards', 'extension']);
const allowedCardFields = new Set([
  'uuid',
  'summary',
  'detail',
  'indicator',
  'source',
  'extension',
]);
const traceExtensionName = 'org.parkinsum.cdss-rule-trace';
const cqlExtensionName = 'org.parkinsum.cql-differential';
const cqlResponseExtensionName = 'org.parkinsum.cql-differential-response';
const fhirCqlExtensionName = 'org.parkinsum.fhir-cql-retrieval';
const fhirCqlResponseExtensionName = 'org.parkinsum.fhir-cql-retrieval-response';
const fhirObservationCqlExtensionName = 'org.parkinsum.fhir-observation-cql';
const fhirObservationCqlResponseExtensionName = 'org.parkinsum.fhir-observation-cql-response';
const fhirCqlCases = new Map([
  ['condition_present', 'true'],
  ['condition_absent', 'false'],
  ['condition_foreign_patient', 'false'],
]);
const fhirCqlExtensionFields = new Set([
  'schemaVersion',
  'caseId',
  'fhirVersion',
  'context',
  'cqlExpression',
  'cqlResult',
  'googleCqlPackage',
  'cqfJvmEngine',
  'cqfJvmFhirArtifact',
  'engineOutcomeRelation',
  'diagnosticRelation',
  'corpusDigest',
  'sourceRefs',
]);
const fhirCqlResponseExtensionFields = new Set([
  ...fhirCqlExtensionFields,
  'errors',
  'warnings',
]);
const fhirCqlSourceRefs = [
  'test/fixtures/cql_fhir_r4_retrieval_corpus.json',
  'docs/CQL_RULE_DIFFERENTIAL.md',
  'docs/CDSS_OPEN_SOURCE_LANDSCAPE_2026-09-22.md',
];
const fhirCqlDiagnosticCodes = new Set(['criterion_not_met']);
const fhirObservationCqlCases = new Map([
  ['observation_present', [true, true, true]],
  ['observation_absent', [false, false, false]],
  ['observation_foreign_subject', [false, false, false]],
  ['observation_non_member_code', [false, false, false]],
  ['observation_foreign_code_system', [false, false, false]],
  ['observation_system_version_mismatch', [true, true, false]],
]);
const fhirObservationCqlExtensionFields = new Set([
  'schemaVersion',
  'caseId',
  'fhirVersion',
  'context',
  'cqlExpression',
  'googleCqlMembership',
  'javaScriptMembership',
  'cqfJvmMembership',
  'googleCqlPackage',
  'javaScriptExecutionPath',
  'cqfJvmEngine',
  'cqfJvmFhirArtifact',
  'engineOutcomeRelation',
  'diagnosticRelation',
  'projectedResult',
  'corpusDigest',
  'sourceRefs',
]);
const fhirObservationCqlResponseExtensionFields = new Set([
  ...fhirObservationCqlExtensionFields,
  'errors',
  'warnings',
]);
const fhirObservationCqlSourceRefs = [
  'test/fixtures/cql_fhir_r4_observation_retrieval_corpus.json',
  'docs/CQL_RULE_DIFFERENTIAL.md',
  'docs/CDSS_OPEN_SOURCE_LANDSCAPE_2026-09-22.md',
];
const fhirObservationCqlErrorCodes = new Set(['engine_disagreement']);
const fhirObservationCqlWarningCodes = new Set(['criterion_not_met']);
const cqlResponseExtensionFields = new Set([
  'schemaVersion',
  'caseId',
  'cqlResult',
  'cqlPackage',
  'cqlExecutionPackage',
  'corpusDigest',
  'errors',
  'warnings',
  'sourceRefs',
]);
const cqlResponseErrorCodes = new Set(['evaluation_indeterminate']);
const cqlResponseWarningCodes = new Set(['criterion_not_met']);
const cqlResponseSourceRefs = [
  'test/fixtures/cql_rule_differential_corpus.json',
  'docs/CQL_RULE_DIFFERENTIAL.md',
  'docs/CDSS_OPEN_SOURCE_LANDSCAPE_2026-09-22.md',
];
const traceExtensionFields = new Set([
  'schemaVersion',
  'ruleId',
  'ruleVersion',
  'rulePackVersion',
  'rulePackDigest',
  'inputDigest',
  'traceDecision',
  'resultState',
  'inputCompleteness',
  'inputFieldsUsed',
  'sourceRefs',
  'missingOrUncertainInputs',
  'evidenceStrength',
  'outputType',
  'displayCopySource',
]);
const traceStates = new Set([
  'matched',
  'not_matched',
  'suppressed',
  'not_applicable_jurisdiction',
  'unknown',
  'missing_input',
  'unsupported_input',
  'invalid_context',
]);
const cqlExtensionFields = new Set([
  'schemaVersion',
  'caseId',
  'caseClass',
  'ruleId',
  'ruleVersion',
  'rulePackVersion',
  'cqlPackage',
  'cqlExecutionPackage',
  'corpusDigest',
  'inputDigest',
  'cqlResult',
  'independentCqlResult',
  'cqlEngineRelation',
  'dartRuntimeMatch',
  'missingFields',
  'inputCompleteness',
  'reviewRecommended',
  'relation',
  'sourceRefs',
]);
const cqlClasses = new Set([
  'truth_value',
  'unit_boundary',
  'unsupported_unit',
  'date_boundary',
  'date_missing',
]);
const sha256Pattern = /^[0-9a-f]{64}$/;
const actionFields = new Set([
  'links',
  'overrideReasons',
  'selectionBehavior',
  'suggestions',
]);
const requestContextFields = new Set([
  'context',
  'fhirAuthorization',
  'fhirServer',
  'prefetch',
]);
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function isRecord(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function add(findings, code, pathName) {
  findings.push({ code, path: pathName });
}

function validateSourceUrl(value, findings) {
  if (typeof value !== 'string' || value.trim() === '') {
    add(findings, 'invalid_source_url', 'cards[].source.url');
    return;
  }
  try {
    const parsed = new URL(value);
    if (
      parsed.protocol !== 'https:' ||
      parsed.username !== '' ||
      parsed.password !== '' ||
      parsed.search !== '' ||
      parsed.hash !== ''
    ) {
      add(findings, 'unsafe_source_url', 'cards[].source.url');
    }
  } catch {
    add(findings, 'invalid_source_url', 'cards[].source.url');
  }
}

function validateTraceExtension(value, findings, cardPath, cardCount) {
  const extensionPath = cardPath + '.extension';
  if (!isRecord(value)) {
    add(findings, 'invalid_card_extension', extensionPath);
    return;
  }
  const names = Object.keys(value);
  if (names.length !== 1) {
    add(findings, 'unsupported_extension_namespace', extensionPath);
    return;
  }
  const namespace = names[0];
  if (namespace === cqlExtensionName) {
    validateCqlExtension(value[namespace], findings, extensionPath + '.' + namespace);
    return;
  }
  if (namespace === fhirCqlExtensionName) {
    validateFhirCqlExtension(
      value[namespace], findings, extensionPath + '.' + namespace, false,
    );
    return;
  }
  if (namespace === fhirObservationCqlExtensionName) {
    validateFhirObservationCqlExtension(
      value[namespace], findings, extensionPath + '.' + namespace, false, cardCount,
    );
    return;
  }
  if (namespace !== traceExtensionName) {
    add(findings, 'unsupported_extension_namespace', extensionPath);
    return;
  }
  const trace = value[namespace];
  const tracePath = extensionPath + '.' + namespace;
  if (!isRecord(trace)) {
    add(findings, 'invalid_trace_extension', tracePath);
    return;
  }
  for (const field of Object.keys(trace)) {
    if (!traceExtensionFields.has(field)) {
      add(findings, 'unsupported_trace_extension_field', tracePath + '.' + field);
    }
  }
  const requiredTextFields = [
    'schemaVersion',
    'ruleId',
    'ruleVersion',
    'rulePackVersion',
    'inputDigest',
    'traceDecision',
    'resultState',
    'inputCompleteness',
    'evidenceStrength',
    'outputType',
  ];
  for (const field of requiredTextFields) {
    if (typeof trace[field] !== 'string' || trace[field].trim() === '') {
      add(findings, 'trace_extension_text_required', tracePath + '.' + field);
    }
  }
  if (trace.schemaVersion !== '1.0.0') {
    add(findings, 'unsupported_trace_extension_schema', tracePath + '.schemaVersion');
  }
  if (trace.displayCopySource !== undefined &&
      (typeof trace.displayCopySource !== 'string' ||
       trace.displayCopySource.trim() === '')) {
    add(findings, 'invalid_copy_source', tracePath + '.displayCopySource');
  }
  if (typeof trace.inputDigest === 'string' && !sha256Pattern.test(trace.inputDigest)) {
    add(findings, 'invalid_input_digest', tracePath + '.inputDigest');
  }
  if (trace.rulePackDigest !== undefined &&
      (typeof trace.rulePackDigest !== 'string' ||
       !sha256Pattern.test(trace.rulePackDigest))) {
    add(findings, 'invalid_rule_pack_digest', tracePath + '.rulePackDigest');
  }
  if (typeof trace.traceDecision === 'string' && !traceStates.has(trace.traceDecision)) {
    add(findings, 'unsupported_trace_decision', tracePath + '.traceDecision');
  }
  if (typeof trace.resultState === 'string' && !traceStates.has(trace.resultState)) {
    add(findings, 'unsupported_result_state', tracePath + '.resultState');
  }
  if (!['complete', 'incomplete'].includes(trace.inputCompleteness)) {
    add(findings, 'invalid_input_completeness', tracePath + '.inputCompleteness');
  }
  for (const field of [
    'inputFieldsUsed',
    'sourceRefs',
    'missingOrUncertainInputs',
  ]) {
    if (!Array.isArray(trace[field]) ||
        trace[field].length > 64 ||
        trace[field].some((item) => typeof item !== 'string' ||
          item.trim() === '' || [...item].length > 256)) {
      add(findings, 'invalid_trace_extension_list', tracePath + '.' + field);
    }
  }
  if (Array.isArray(trace.missingOrUncertainInputs)) {
    const incomplete = trace.missingOrUncertainInputs.length > 0;
    if ((trace.inputCompleteness === 'incomplete') !== incomplete) {
      add(findings, 'input_completeness_mismatch', tracePath + '.inputCompleteness');
    }
    const expectedState = trace.traceDecision === 'not_matched' && incomplete
      ? 'unknown'
      : trace.traceDecision;
    if (trace.resultState !== expectedState) {
      add(findings, 'trace_result_state_mismatch', tracePath + '.resultState');
    }
    if (trace.traceDecision === 'missing_input' && !incomplete) {
      add(findings, 'missing_state_without_fields', tracePath + '.missingOrUncertainInputs');
    }
  }
  if (!['label', 'mechanism', 'analogy', 'insufficient'].includes(trace.evidenceStrength)) {
    add(findings, 'invalid_evidence_strength', tracePath + '.evidenceStrength');
  }
  if (!['educationalInfo', 'educationalCaution', 'invalidContext'].includes(trace.outputType)) {
    add(findings, 'invalid_explanation_output_type', tracePath + '.outputType');
  }
}

function validateCqlExtension(value, findings, tracePath) {
  if (!isRecord(value)) {
    add(findings, 'invalid_cql_extension', tracePath);
    return;
  }
  for (const field of Object.keys(value)) {
    if (!cqlExtensionFields.has(field)) {
      add(findings, 'unsupported_cql_extension_field', tracePath + '.' + field);
    }
  }
  for (const field of [
    'schemaVersion',
    'caseId',
    'caseClass',
    'ruleId',
    'ruleVersion',
    'rulePackVersion',
    'cqlPackage',
    'cqlExecutionPackage',
    'corpusDigest',
    'inputDigest',
    'cqlResult',
    'independentCqlResult',
    'cqlEngineRelation',
    'inputCompleteness',
    'relation',
  ]) {
    if (typeof value[field] !== 'string' || value[field].trim() === '') {
      add(findings, 'cql_extension_text_required', tracePath + '.' + field);
    }
  }
  if (value.schemaVersion !== '1.0.0') {
    add(findings, 'unsupported_cql_extension_schema', tracePath + '.schemaVersion');
  }
  if (typeof value.caseId === 'string' &&
      !/^[a-z0-9][a-z0-9._-]{0,127}$/.test(value.caseId)) {
    add(findings, 'invalid_cql_case_id', tracePath + '.caseId');
  }
  if (typeof value.caseClass === 'string' && !cqlClasses.has(value.caseClass)) {
    add(findings, 'invalid_cql_case_class', tracePath + '.caseClass');
  }
  if (value.ruleId !== `cql-diff.${value.caseId}`) {
    add(findings, 'cql_rule_id_mismatch', tracePath + '.ruleId');
  }
  if (typeof value.cqlPackage === 'string' &&
      !/^@cqframework\/cql@[0-9]+\.[0-9]+\.[0-9]+$/.test(value.cqlPackage)) {
    add(findings, 'invalid_cql_package_identity', tracePath + '.cqlPackage');
  }
  if (typeof value.cqlExecutionPackage === 'string' &&
      !/^cql-execution@[0-9]+\.[0-9]+\.[0-9]+$/.test(value.cqlExecutionPackage)) {
    add(findings, 'invalid_cql_execution_package_identity', tracePath + '.cqlExecutionPackage');
  }
  for (const field of ['corpusDigest', 'inputDigest']) {
    if (typeof value[field] === 'string' && !sha256Pattern.test(value[field])) {
      add(findings, 'invalid_cql_digest', tracePath + '.' + field);
    }
  }
  if (!['true', 'false', 'unknown'].includes(value.cqlResult)) {
    add(findings, 'invalid_cql_result', tracePath + '.cqlResult');
  }
  if (!['true', 'false', 'unknown'].includes(value.independentCqlResult)) {
    add(findings, 'invalid_independent_cql_result', tracePath + '.independentCqlResult');
  }
  const expectedCqlEngineRelation = value.cqlResult === value.independentCqlResult
    ? 'same'
    : 'documented-semantic-difference';
  if (value.cqlEngineRelation !== expectedCqlEngineRelation) {
    add(findings, 'cql_engine_relation_mismatch', tracePath + '.cqlEngineRelation');
  }
  if (typeof value.dartRuntimeMatch !== 'boolean' ||
      typeof value.reviewRecommended !== 'boolean') {
    add(findings, 'invalid_cql_runtime_result', tracePath);
  }
  for (const field of ['missingFields', 'sourceRefs']) {
    if (!Array.isArray(value[field]) ||
        value[field].length > 64 ||
        value[field].some((item) => typeof item !== 'string' ||
          item.trim() === '' || [...item].length > 256)) {
      add(findings, 'invalid_cql_extension_list', tracePath + '.' + field);
    }
  }
  if (Array.isArray(value.sourceRefs) && value.sourceRefs.length === 0) {
    add(findings, 'cql_source_refs_required', tracePath + '.sourceRefs');
  }
  if (Array.isArray(value.missingFields)) {
    const incomplete = value.missingFields.length > 0;
    if ((value.inputCompleteness === 'incomplete') !== incomplete) {
      add(findings, 'cql_input_completeness_mismatch', tracePath + '.inputCompleteness');
    }
    if (value.reviewRecommended !== incomplete) {
      add(findings, 'cql_review_flag_mismatch', tracePath + '.reviewRecommended');
    }
    if (['true', 'false', 'unknown'].includes(value.cqlResult) &&
        typeof value.dartRuntimeMatch === 'boolean') {
      const expectedRelation = value.cqlResult ===
          (value.dartRuntimeMatch ? 'true' : 'false')
        ? 'same'
        : value.reviewRecommended && value.cqlResult === 'unknown' &&
            !value.dartRuntimeMatch
          ? 'unknown-escalated-to-review'
          : 'documented-semantic-difference';
      if (value.relation !== expectedRelation) {
        add(findings, 'cql_relation_mismatch', tracePath + '.relation');
      }
    }
  }
  if (![
    'same',
    'unknown-escalated-to-review',
    'documented-semantic-difference',
  ].includes(value.relation)) {
    add(findings, 'invalid_cql_relation', tracePath + '.relation');
  }
}

function validateCqlResponseExtension(value, findings, responsePath, cards) {
  const extensionPath = responsePath + '.extension';
  if (!isRecord(value)) {
    add(findings, 'invalid_response_extension', extensionPath);
    return;
  }
  const namespaces = Object.keys(value);
  if (namespaces.length === 1 &&
      namespaces[0] === fhirObservationCqlResponseExtensionName) {
    validateFhirObservationCqlExtension(
      value[namespaces[0]], findings,
      extensionPath + '.' + namespaces[0], true, cards,
    );
    return;
  }
  if (namespaces.length === 1 && namespaces[0] === fhirCqlResponseExtensionName) {
    validateFhirCqlResponseExtension(
      value[namespaces[0]], findings, extensionPath + '.' + namespaces[0], cards,
    );
    return;
  }
  if (namespaces.length !== 1 || namespaces[0] !== cqlResponseExtensionName) {
    add(findings, 'unsupported_response_extension_namespace', extensionPath);
    return;
  }
  const body = value[cqlResponseExtensionName];
  const bodyPath = extensionPath + '.' + cqlResponseExtensionName;
  if (!isRecord(body)) {
    add(findings, 'invalid_cql_response_extension', bodyPath);
    return;
  }
  for (const field of Object.keys(body)) {
    if (!cqlResponseExtensionFields.has(field)) {
      add(findings, 'unsupported_cql_response_extension_field', bodyPath + '.' + field);
    }
  }
  for (const field of [
    'schemaVersion',
    'caseId',
    'cqlResult',
    'cqlPackage',
    'cqlExecutionPackage',
    'corpusDigest',
  ]) {
    if (typeof body[field] !== 'string' || body[field].trim() === '') {
      add(findings, 'cql_response_extension_text_required', bodyPath + '.' + field);
    }
  }
  if (body.schemaVersion !== '1.0.0') {
    add(findings, 'unsupported_cql_response_extension_schema', bodyPath + '.schemaVersion');
  }
  if (typeof body.caseId === 'string' && !/^[a-z0-9][a-z0-9._-]{0,127}$/.test(body.caseId)) {
    add(findings, 'invalid_cql_response_case_id', bodyPath + '.caseId');
  }
  if (!['true', 'false', 'unknown'].includes(body.cqlResult)) {
    add(findings, 'invalid_cql_response_result', bodyPath + '.cqlResult');
  }
  if (typeof body.cqlPackage === 'string' &&
      !/^@cqframework\/cql@[0-9]+\.[0-9]+\.[0-9]+$/.test(body.cqlPackage)) {
    add(findings, 'invalid_cql_response_package_identity', bodyPath + '.cqlPackage');
  }
  if (typeof body.cqlExecutionPackage === 'string' &&
      !/^cql-execution@[0-9]+\.[0-9]+\.[0-9]+$/.test(body.cqlExecutionPackage)) {
    add(findings, 'invalid_cql_response_execution_package_identity', bodyPath + '.cqlExecutionPackage');
  }
  if (typeof body.corpusDigest === 'string' && !sha256Pattern.test(body.corpusDigest)) {
    add(findings, 'invalid_cql_response_digest', bodyPath + '.corpusDigest');
  }

  for (const [field, codes] of [
    ['errors', cqlResponseErrorCodes],
    ['warnings', cqlResponseWarningCodes],
  ]) {
    const list = body[field];
    if (!Array.isArray(list) || list.length > 1 ||
        list.some((code) => typeof code !== 'string' || !codes.has(code))) {
      add(findings, 'invalid_cql_response_diagnostic_list', bodyPath + '.' + field);
    }
  }
  if (Array.isArray(body.errors) && Array.isArray(body.warnings) &&
      body.errors.length === 0 && body.warnings.length === 0) {
    add(findings, 'empty_cql_response_extension', bodyPath);
  }
  if (JSON.stringify(body.sourceRefs) !== JSON.stringify(cqlResponseSourceRefs)) {
    add(findings, 'invalid_cql_response_source_refs', bodyPath + '.sourceRefs');
  }
  if (body.cqlResult !== 'true' && Array.isArray(cards) && cards.length !== 0) {
    add(findings, 'cql_response_card_result_mismatch', bodyPath + '.cqlResult');
  }
  if (['true', 'false', 'unknown'].includes(body.cqlResult) &&
      Array.isArray(body.errors) && Array.isArray(body.warnings)) {
    const expectedErrors = body.cqlResult === 'unknown'
      ? ['evaluation_indeterminate']
      : [];
    const expectedWarnings = body.cqlResult === 'false'
      ? ['criterion_not_met']
      : [];
    if (JSON.stringify(body.errors) !== JSON.stringify(expectedErrors)) {
      add(findings, 'cql_response_errors_mismatch', bodyPath + '.errors');
    }
    if (JSON.stringify(body.warnings) !== JSON.stringify(expectedWarnings)) {
      add(findings, 'cql_response_warnings_mismatch', bodyPath + '.warnings');
    }
  }
  if (Array.isArray(cards) && cards.length > 0) {
    for (const [index, card] of cards.entries()) {
      const cardCaseId = card?.extension?.[cqlExtensionName]?.caseId;
      if (cardCaseId !== undefined && cardCaseId !== body.caseId) {
        add(findings, 'cql_response_card_case_mismatch', `cards[${index}]`);
      }
    }
  }
}

function validateFhirCqlExtension(value, findings, extensionPath, response, cards) {
  if (!isRecord(value)) {
    add(findings, response ? 'invalid_fhir_cql_response_extension' : 'invalid_fhir_cql_extension', extensionPath);
    return;
  }
  const allowedFields = response
    ? fhirCqlResponseExtensionFields
    : fhirCqlExtensionFields;
  for (const field of Object.keys(value)) {
    if (!allowedFields.has(field)) {
      add(findings, 'unsupported_fhir_cql_extension_field', extensionPath + '.' + field);
    }
  }
  for (const field of [
    'schemaVersion',
    'caseId',
    'fhirVersion',
    'context',
    'cqlExpression',
    'cqlResult',
    'googleCqlPackage',
    'cqfJvmEngine',
    'cqfJvmFhirArtifact',
    'engineOutcomeRelation',
    'diagnosticRelation',
    'corpusDigest',
  ]) {
    if (typeof value[field] !== 'string' || value[field].trim() === '') {
      add(findings, 'fhir_cql_extension_text_required', extensionPath + '.' + field);
    }
  }
  if (value.schemaVersion !== '1.0.0') {
    add(findings, 'unsupported_fhir_cql_extension_schema', extensionPath + '.schemaVersion');
  }
  if (typeof value.caseId === 'string' && !fhirCqlCases.has(value.caseId)) {
    add(findings, 'invalid_fhir_cql_case_id', extensionPath + '.caseId');
  }
  if (typeof value.fhirVersion === 'string' && value.fhirVersion !== '4.0.1') {
    add(findings, 'invalid_fhir_cql_fhir_version', extensionPath + '.fhirVersion');
  }
  if (typeof value.context === 'string' && value.context !== 'Patient') {
    add(findings, 'invalid_fhir_cql_context', extensionPath + '.context');
  }
  if (typeof value.cqlExpression === 'string' && value.cqlExpression !== 'exists([Condition])') {
    add(findings, 'invalid_fhir_cql_expression', extensionPath + '.cqlExpression');
  }
  if (typeof value.cqlResult === 'string' &&
      value.cqlResult !== fhirCqlCases.get(value.caseId)) {
    add(findings, 'fhir_cql_case_result_mismatch', extensionPath + '.cqlResult');
  }
  if (typeof value.googleCqlPackage === 'string' &&
      value.googleCqlPackage !== 'github.com/google/cql@v0.0.3-0.20260814184421-b9169ccd54a3') {
    add(findings, 'invalid_fhir_cql_google_engine', extensionPath + '.googleCqlPackage');
  }
  if (typeof value.cqfJvmEngine === 'string' &&
      value.cqfJvmEngine !== 'org.cqframework:engine@5.3.0') {
    add(findings, 'invalid_fhir_cql_cqf_engine', extensionPath + '.cqfJvmEngine');
  }
  if (typeof value.cqfJvmFhirArtifact === 'string' &&
      value.cqfJvmFhirArtifact !== 'org.cqframework:engine-fhir@5.3.0') {
    add(findings, 'invalid_fhir_cql_cqf_fhir_artifact', extensionPath + '.cqfJvmFhirArtifact');
  }
  if (value.engineOutcomeRelation !== 'same') {
    add(findings, 'fhir_cql_engine_outcome_mismatch', extensionPath + '.engineOutcomeRelation');
  }
  if (value.diagnosticRelation !== 'same') {
    add(findings, 'fhir_cql_diagnostic_mismatch', extensionPath + '.diagnosticRelation');
  }
  if (typeof value.corpusDigest === 'string' && !sha256Pattern.test(value.corpusDigest)) {
    add(findings, 'invalid_fhir_cql_corpus_digest', extensionPath + '.corpusDigest');
  }
  if (JSON.stringify(value.sourceRefs) !== JSON.stringify(fhirCqlSourceRefs)) {
    add(findings, 'invalid_fhir_cql_source_refs', extensionPath + '.sourceRefs');
  }

  if (!response) {
    if (value.caseId !== 'condition_present' || value.cqlResult !== 'true') {
      add(findings, 'fhir_cql_card_result_mismatch', extensionPath);
    }
    return;
  }
  if (value.caseId === 'condition_present' || value.cqlResult !== 'false') {
    add(findings, 'fhir_cql_response_case_mismatch', extensionPath);
  }
  if (Array.isArray(cards) && cards.length !== 0) {
    add(findings, 'fhir_cql_response_card_result_mismatch', extensionPath);
  }
  for (const [field, expected] of [
    ['errors', []],
    ['warnings', ['criterion_not_met']],
  ]) {
    const codes = value[field];
    if (!Array.isArray(codes) || codes.length > 1 ||
        codes.some((code) => typeof code !== 'string' || !fhirCqlDiagnosticCodes.has(code)) ||
        JSON.stringify(codes) !== JSON.stringify(expected)) {
      add(findings, 'invalid_fhir_cql_response_diagnostics', extensionPath + '.' + field);
    }
  }
}

function validateFhirCqlResponseExtension(value, findings, extensionPath, cards) {
  validateFhirCqlExtension(value, findings, extensionPath, true, cards);
}

function validateFhirObservationCqlExtension(value, findings, extensionPath, response, cards) {
  if (!isRecord(value)) {
    add(findings, 'invalid_fhir_observation_cql_extension', extensionPath);
    return;
  }
  const allowedFields = response
    ? fhirObservationCqlResponseExtensionFields
    : fhirObservationCqlExtensionFields;
  for (const field of Object.keys(value)) {
    if (!allowedFields.has(field)) {
      add(findings, 'unsupported_fhir_observation_cql_extension_field', extensionPath + '.' + field);
    }
  }
  for (const field of [
    'schemaVersion', 'caseId', 'fhirVersion', 'context', 'cqlExpression',
    'googleCqlPackage', 'javaScriptExecutionPath', 'cqfJvmEngine',
    'cqfJvmFhirArtifact', 'engineOutcomeRelation', 'diagnosticRelation',
    'projectedResult', 'corpusDigest',
  ]) {
    if (typeof value[field] !== 'string' || value[field].trim() === '') {
      add(findings, 'fhir_observation_cql_text_required', extensionPath + '.' + field);
    }
  }
  if (value.schemaVersion !== '1.0.0') {
    add(findings, 'unsupported_fhir_observation_cql_schema', extensionPath + '.schemaVersion');
  }
  const expected = fhirObservationCqlCases.get(value.caseId);
  if (!expected) {
    add(findings, 'invalid_fhir_observation_cql_case_id', extensionPath + '.caseId');
    return;
  }
  if (value.fhirVersion !== '4.0.1') {
    add(findings, 'invalid_fhir_observation_cql_fhir_version', extensionPath + '.fhirVersion');
  }
  if (value.context !== 'Patient') {
    add(findings, 'invalid_fhir_observation_cql_context', extensionPath + '.context');
  }
  if (value.cqlExpression !== 'exists([Observation: code in "Synthetic Observation Codes"])') {
    add(findings, 'invalid_fhir_observation_cql_expression', extensionPath + '.cqlExpression');
  }
  if (value.googleCqlPackage !== 'github.com/google/cql@v0.0.3-0.20260814184421-b9169ccd54a3') {
    add(findings, 'invalid_fhir_observation_cql_google_engine', extensionPath + '.googleCqlPackage');
  }
  if (value.javaScriptExecutionPath !== 'cql-execution@3.3.2 + cql-exec-fhir@2.1.6') {
    add(findings, 'invalid_fhir_observation_cql_javascript_engine', extensionPath + '.javaScriptExecutionPath');
  }
  if (value.cqfJvmEngine !== 'org.cqframework:engine@5.3.0' ||
      value.cqfJvmFhirArtifact !== 'org.cqframework:engine-fhir@5.3.0') {
    add(findings, 'invalid_fhir_observation_cql_cqf_engine', extensionPath + '.cqfJvmEngine');
  }
  const actual = [
    value.googleCqlMembership,
    value.javaScriptMembership,
    value.cqfJvmMembership,
  ];
  if (actual.some((item) => typeof item !== 'boolean') ||
      JSON.stringify(actual) !== JSON.stringify(expected)) {
    add(findings, 'fhir_observation_cql_provider_outcome_mismatch', extensionPath);
  }
  const same = actual.every((item) => item === actual[0]);
  const expectedResult = same ? String(actual[0]) : 'unknown';
  if (value.engineOutcomeRelation !==
      (same ? 'same' : 'documented-provider-difference')) {
    add(findings, 'fhir_observation_cql_engine_relation_mismatch', extensionPath + '.engineOutcomeRelation');
  }
  if (value.diagnosticRelation !== 'same') {
    add(findings, 'fhir_observation_cql_diagnostic_relation_mismatch', extensionPath + '.diagnosticRelation');
  }
  if (value.projectedResult !== expectedResult) {
    add(findings, 'fhir_observation_cql_projected_result_mismatch', extensionPath + '.projectedResult');
  }
  if (typeof value.corpusDigest === 'string' && !sha256Pattern.test(value.corpusDigest)) {
    add(findings, 'invalid_fhir_observation_cql_corpus_digest', extensionPath + '.corpusDigest');
  }
  if (JSON.stringify(value.sourceRefs) !== JSON.stringify(fhirObservationCqlSourceRefs)) {
    add(findings, 'invalid_fhir_observation_cql_source_refs', extensionPath + '.sourceRefs');
  }

  if (!response) {
    if (value.caseId !== 'observation_present' || value.projectedResult !== 'true' ||
        cards !== 1) {
      add(findings, 'fhir_observation_cql_card_result_mismatch', extensionPath);
    }
    return;
  }
  if (value.projectedResult === 'true' || !Array.isArray(cards) || cards.length !== 0) {
    add(findings, 'fhir_observation_cql_response_card_mismatch', extensionPath);
  }
  for (const [field, codes, expectedCodes] of [
    ['errors', fhirObservationCqlErrorCodes,
      expectedResult === 'unknown' ? ['engine_disagreement'] : []],
    ['warnings', fhirObservationCqlWarningCodes,
      expectedResult === 'false' ? ['criterion_not_met'] : []],
  ]) {
    const actualCodes = value[field];
    if (!Array.isArray(actualCodes) || actualCodes.length > 1 ||
        actualCodes.some((code) => typeof code !== 'string' || !codes.has(code)) ||
        JSON.stringify(actualCodes) !== JSON.stringify(expectedCodes)) {
      add(findings, 'invalid_fhir_observation_cql_response_diagnostics', extensionPath + '.' + field);
    }
  }
}

export function validateInformationOnlyResponse(response) {
  const findings = [];
  if (!isRecord(response)) {
    return { valid: false, findings: [{ code: 'invalid_response_object', path: '$' }] };
  }

  for (const field of Object.keys(response)) {
    if (allowedResponseFields.has(field)) continue;
    if (field === 'systemActions') {
      add(findings, 'auto_action_disallowed', field);
    } else if (requestContextFields.has(field)) {
      add(findings, 'request_context_disallowed', field);
    } else {
      add(findings, 'unsupported_response_field', field);
    }
  }
  if (!Array.isArray(response.cards)) {
    add(findings, 'cards_required_array', 'cards');
    return { valid: false, findings };
  }
  if (response.extension !== undefined) {
    validateCqlResponseExtension(response.extension, findings, '$', response.cards);
  }

  response.cards.forEach((card, index) => {
    const cardPath = 'cards[' + index + ']';
    if (!isRecord(card)) {
      add(findings, 'invalid_card_object', cardPath);
      return;
    }
    for (const field of Object.keys(card)) {
      if (allowedCardFields.has(field)) continue;
      if (actionFields.has(field)) {
        add(findings, 'actionable_content_disallowed', cardPath + '.' + field);
      } else {
        add(findings, 'unsupported_card_field', cardPath + '.' + field);
      }
    }
    if (card.extension !== undefined) {
      validateTraceExtension(card.extension, findings, cardPath, response.cards.length);
    }
    if (typeof card.summary !== 'string' || card.summary.trim() === '') {
      add(findings, 'summary_required', cardPath + '.summary');
    } else if ([...card.summary].length >= 140) {
      add(findings, 'summary_too_long', cardPath + '.summary');
    }
    if (card.indicator !== 'info') {
      add(findings, 'information_indicator_required', cardPath + '.indicator');
    }
    if (card.detail !== undefined && typeof card.detail !== 'string') {
      add(findings, 'invalid_detail', cardPath + '.detail');
    }
    if (card.uuid !== undefined &&
        (typeof card.uuid !== 'string' || !uuidPattern.test(card.uuid))) {
      add(findings, 'invalid_card_uuid', cardPath + '.uuid');
    }
    if (!isRecord(card.source)) {
      add(findings, 'source_required', cardPath + '.source');
      return;
    }
    for (const field of Object.keys(card.source)) {
      if (field !== 'label' && field !== 'url') {
        add(findings, 'unsupported_source_field', cardPath + '.source.' + field);
      }
    }
    if (typeof card.source.label !== 'string' || card.source.label.trim() === '') {
      add(findings, 'source_label_required', cardPath + '.source.label');
    }
    if (card.source.url !== undefined) {
      validateSourceUrl(card.source.url, findings);
    }
  });

  return { valid: findings.length === 0, findings };
}

function runFixture() {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const fixturePath = path.join(
    root,
    'test/fixtures/cds_hooks_information_card.synthetic.json',
  );
  const response = JSON.parse(fs.readFileSync(fixturePath, 'utf8'));
  const result = validateInformationOnlyResponse(response);
  if (!result.valid) {
    process.stderr.write(JSON.stringify(result.findings, null, 2) + '\n');
    process.exitCode = 1;
    return;
  }
  process.stdout.write(
    'PASS synthetic CDS Hooks v2 information-only response contract\n',
  );
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  runFixture();
}
