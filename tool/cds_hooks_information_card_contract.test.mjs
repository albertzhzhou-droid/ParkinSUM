import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import { validateInformationOnlyResponse } from './cds_hooks_information_card_contract.mjs';

const fixture = JSON.parse(
  fs.readFileSync(
    'test/fixtures/cds_hooks_information_card.synthetic.json',
    'utf8',
  ),
);

function codes(response) {
  return validateInformationOnlyResponse(response).findings.map((item) => item.code);
}

test('synthetic information-only fixture satisfies the bounded v2 card contract', () => {
  assert.deepEqual(validateInformationOnlyResponse(fixture), {
    valid: true,
    findings: [],
  });
});

test('an empty card list is a valid no-guidance response', () => {
  assert.deepEqual(validateInformationOnlyResponse({ cards: [] }), {
    valid: true,
    findings: [],
  });
});

test('response-level CQL diagnostics are valid with no cards and strictly bounded', () => {
  const response = {
    cards: [],
    extension: {
      'org.parkinsum.cql-differential-response': {
        schemaVersion: '1.0.0',
        caseId: 'dose_unknown',
        cqlResult: 'unknown',
        cqlPackage: '@cqframework/cql@5.3.0',
        cqlExecutionPackage: 'cql-execution@3.3.2',
        corpusDigest: 'a'.repeat(64),
        errors: ['evaluation_indeterminate'],
        warnings: [],
        sourceRefs: [
          'test/fixtures/cql_rule_differential_corpus.json',
          'docs/CQL_RULE_DIFFERENTIAL.md',
          'docs/CDSS_OPEN_SOURCE_LANDSCAPE_2026-09-22.md',
        ],
      },
    },
  };
  assert.deepEqual(validateInformationOnlyResponse(response), {
    valid: true,
    findings: [],
  });

  const unknownNamespace = structuredClone(response);
  unknownNamespace.extension = { 'example.org/unreviewed': {} };
  assert(codes(unknownNamespace).includes('unsupported_response_extension_namespace'));

  const unknownField = structuredClone(response);
  unknownField.extension['org.parkinsum.cql-differential-response'].patientId =
    'synthetic-patient';
  assert(codes(unknownField).includes('unsupported_cql_response_extension_field'));

  const incorrectMeaning = structuredClone(response);
  incorrectMeaning.extension['org.parkinsum.cql-differential-response'].errors = [];
  assert(codes(incorrectMeaning).includes('cql_response_errors_mismatch'));
});

test('missing cards and non-object responses fail closed', () => {
  assert(codes({}).includes('cards_required_array'));
  assert(codes(null).includes('invalid_response_object'));
  assert(codes({ cards: [null] }).includes('invalid_card_object'));
});

test('request context and automatic system actions are excluded', () => {
  const result = codes({
    cards: [],
    context: { patientId: 'synthetic-id' },
    fhirAuthorization: { access_token: 'synthetic-token' },
    systemActions: [],
  });
  assert(result.includes('request_context_disallowed'));
  assert(result.includes('auto_action_disallowed'));
});

test('cards cannot contain suggestions, app links, or other actionable fields', () => {
  const card = structuredClone(fixture.cards[0]);
  card.suggestions = [{ label: 'Apply change' }];
  card.links = [{ label: 'Launch app', url: 'https://example.org' }];
  assert(codes({ cards: [card] }).includes('actionable_content_disallowed'));
});

test('only an informational indicator and a summary shorter than 140 code points pass', () => {
  const warning = structuredClone(fixture);
  warning.cards[0].indicator = 'warning';
  assert(codes(warning).includes('information_indicator_required'));

  const long = structuredClone(fixture);
  long.cards[0].summary = '😀'.repeat(140);
  assert(codes(long).includes('summary_too_long'));
});

test('source attribution is mandatory and optional URLs must be safe HTTPS URLs', () => {
  const missing = structuredClone(fixture);
  missing.cards[0].source.label = '   ';
  assert(codes(missing).includes('source_label_required'));

  for (const url of [
    'javascript:alert(1)',
    'https://user:password@example.org/guidance',
    'https://example.org/guidance?access_token=synthetic',
    'https://example.org/guidance#patient',
  ]) {
    const unsafe = structuredClone(fixture);
    unsafe.cards[0].source.url = url;
    assert(codes(unsafe).includes('unsafe_source_url'));
  }
});

test('the namespaced trace extension preserves an incomplete outcome as unknown', () => {
  const trace = fixture.cards[0].extension['org.parkinsum.cdss-rule-trace'];
  assert.equal(trace.traceDecision, 'not_matched');
  assert.equal(trace.resultState, 'unknown');
  assert.equal(trace.inputCompleteness, 'incomplete');
  assert.deepEqual(trace.missingOrUncertainInputs, ['meal.total_protein_g']);
  assert.deepEqual(validateInformationOnlyResponse(fixture), {
    valid: true,
    findings: [],
  });
});

test('unrecognized extension namespaces, fields, states, and digests fail closed', () => {
  const namespace = structuredClone(fixture);
  namespace.cards[0].extension = { 'example.org/unreviewed': {} };
  assert(codes(namespace).includes('unsupported_extension_namespace'));

  const unknownField = structuredClone(fixture);
  unknownField.cards[0].extension['org.parkinsum.cdss-rule-trace'].patientId =
    'synthetic-patient';
  assert(codes(unknownField).includes('unsupported_trace_extension_field'));

  const unknownState = structuredClone(fixture);
  unknownState.cards[0].extension['org.parkinsum.cdss-rule-trace'].traceDecision =
    'negative';
  assert(codes(unknownState).includes('unsupported_trace_decision'));

  const mismatchedState = structuredClone(fixture);
  mismatchedState.cards[0].extension['org.parkinsum.cdss-rule-trace'].resultState =
    'not_matched';
  assert(codes(mismatchedState).includes('trace_result_state_mismatch'));

  const malformedDigest = structuredClone(fixture);
  malformedDigest.cards[0].extension['org.parkinsum.cdss-rule-trace'].inputDigest =
    'not-a-digest';
  assert(codes(malformedDigest).includes('invalid_input_digest'));

  const validPackDigest = structuredClone(fixture);
  validPackDigest.cards[0].extension['org.parkinsum.cdss-rule-trace']
    .rulePackDigest = 'c'.repeat(64);
  assert.deepEqual(validateInformationOnlyResponse(validPackDigest), {
    valid: true,
    findings: [],
  });

  const invalidPackDigest = structuredClone(fixture);
  invalidPackDigest.cards[0].extension['org.parkinsum.cdss-rule-trace']
    .rulePackDigest = 'not-a-digest';
  assert(codes(invalidPackDigest).includes('invalid_rule_pack_digest'));
});

test('incomplete inputs cannot be encoded as a complete non-match', () => {
  const inconsistent = structuredClone(fixture);
  const trace = inconsistent.cards[0].extension['org.parkinsum.cdss-rule-trace'];
  trace.resultState = 'not_matched';
  trace.inputCompleteness = 'complete';
  assert(codes(inconsistent).includes('input_completeness_mismatch'));
  assert(codes(inconsistent).includes('trace_result_state_mismatch'));
});

test('a missing-input state requires named missing fields and copy source may be absent', () => {
  const missingState = structuredClone(fixture);
  const trace = missingState.cards[0].extension['org.parkinsum.cdss-rule-trace'];
  trace.traceDecision = 'missing_input';
  trace.resultState = 'missing_input';
  trace.inputCompleteness = 'complete';
  trace.missingOrUncertainInputs = [];
  assert(codes(missingState).includes('missing_state_without_fields'));

  const noCopyKey = structuredClone(fixture);
  delete noCopyKey.cards[0].extension['org.parkinsum.cdss-rule-trace']
    .displayCopySource;
  assert.deepEqual(validateInformationOnlyResponse(noCopyKey), {
    valid: true,
    findings: [],
  });
});
