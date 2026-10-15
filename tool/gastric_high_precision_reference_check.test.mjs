import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { DOMAIN_CORPUS_PATH, DOMAIN_CORPUS_SCHEMA, DOMAIN_VECTOR_SCHEMA,
  domainHoldReason, evaluateDecimal, fromDecimal, toDecimal,
  verifyDomainFixture } from './gastric_high_precision_reference_check.mjs';

test('53 predeclared domain inputs agree with independent disposition contract without running Dart', () => {
  const corpus = JSON.parse(readFileSync(DOMAIN_CORPUS_PATH));
  assert.equal(corpus.cases.length, 53);
  for (const input of corpus.cases) for (const minute of input.minutes) {
    const reason = domainHoldReason(input.kind, input.parameters, minute);
    assert.equal(reason, input.expected_hold_reason ?? null, input.case_id);
    assert.equal(reason ? 'HOLD' : 'supported', input.expected_status, input.case_id);
  }
});

test('analytic zero, one, half and degenerate anchors validate independent arithmetic', () => {
  const corpus = JSON.parse(readFileSync(DOMAIN_CORPUS_PATH));
  let count = 0;
  for (const input of corpus.cases) for (const [minute, anchor] of Object.entries(input.analytic_anchors ?? {})) {
    const value = evaluateDecimal(input.kind, input.parameters, Number(minute));
    assert.equal(toDecimal(value, 40), toDecimal(fromDecimal(anchor), 40), input.case_id);
    count += 1;
  }
  assert(count >= 10);
});

test('finite decimal parser rejects ambiguous suffixes, repeated exponents and unbounded precision inputs', () => {
  for (const input of ['NaN', 'Infinity', '1e2junk', '1e2e3', '1.2.3', '1e401', '1'.repeat(513), '', '.']) {
    assert.throws(() => fromDecimal(input), input);
  }
  assert.equal(toDecimal(fromDecimal('1e-9'), 12), '0.000000001');
  assert.equal(toDecimal(fromDecimal('-.5'), 2), '-0.5');
});

test('checker mutations use literal manufactured mock vectors, never production evidence', () => {
  const corpus = { schema: DOMAIN_CORPUS_SCHEMA, seed: 20260930,
    tolerance_decimal: '0.000000000005', cases: [
      { case_id: 'half', kind: 'explicitLagExponential', parameters: { 'lag_exp.lag': '0', 'lag_exp.half': '60' },
        minutes: [0, 60], expected_status: 'supported' },
      { case_id: 'excluded', kind: 'siegelModifiedPowerExponential', parameters: { 'siegel.k': '1e-9', 'siegel.beta': '.05' },
        minutes: [1], expected_status: 'HOLD', expected_hold_reason: 'siegel_cancellation_domain', diagnostic_only: true },
      { case_id: 'invalid', kind: 'explicitLagExponential', parameters: { 'lag_exp.lag': '0', 'lag_exp.half': '0' },
        minutes: [1], expected_status: 'HOLD', expected_hold_reason: 'parameter_domain' },
    ] };
  const bytes = Buffer.from(JSON.stringify(corpus));
  const fixture = { schema: DOMAIN_VECTOR_SCHEMA,
    input_sha256: createHash('sha256').update(bytes).digest('hex'), vectors: corpus.cases.map((input, i) => ({
      case_id: input.case_id, kind: input.kind, parameters: input.parameters,
      points: input.minutes.map(minute => ({ minute, status: input.expected_status,
        hold_reason: input.expected_hold_reason ?? null,
        value_decimal: i === 0 ? (minute === 0 ? '1' : '0.5') : i === 1 ? '1' : null })),
    })) };
  assert.equal(verifyDomainFixture(corpus, fixture, bytes).pass, true);
  const wrong = structuredClone(fixture);
  wrong.vectors[0].points[1].value_decimal = '0.501';
  const result = verifyDomainFixture(corpus, wrong, bytes);
  assert.equal(result.pass, false);
  assert.equal(result.failed_supported_point_count, 1);
  const heldValue = structuredClone(fixture);
  heldValue.vectors[2].points[0].value_decimal = '0';
  assert.throws(() => verifyDomainFixture(corpus, heldValue, bytes));
  const wrongHash = structuredClone(fixture);
  wrongHash.input_sha256 = 'invented';
  assert.throws(() => verifyDomainFixture(corpus, wrongHash, bytes));
  const future = structuredClone(fixture);
  future.schema = DOMAIN_VECTOR_SCHEMA.replace('/1', '/2');
  assert.throws(() => verifyDomainFixture(corpus, future, bytes));
});
