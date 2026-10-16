import test from 'node:test';
import assert from 'node:assert/strict';
import { checkCorpus, readCorpus, sampleDecision, summaryDecision } from './public_source_small_corpus_check.mjs';

test('18 real extracted-field cases satisfy pre-authored expectations while completeness stays held', () => {
  const report = checkCorpus(...readCorpus());
  assert.equal(report.case_count, 18);
  assert.equal(report.spl_case_count, 8);
  assert.equal(report.fdc_case_count, 10);
  assert.equal(report.full_sample_mean_checks, 'HOLD');
});

test('changed scalar, missing field, wrong product association and false completeness fail', () => {
  for (const mutate of [
    ([, fields]) => { fields.cases.find((c) => c.case_id === 'F01').excerpt.amount = '25.7'; },
    ([, fields]) => { delete fields.cases.find((c) => c.case_id === 'D07').excerpt.routeCode; },
    ([, fields]) => { fields.cases.find((c) => c.case_id === 'D04').excerpt.products[1].active[1].numerator.value = '250'; },
    ([manifest]) => { manifest.raw_response_sha256 = 'invented_full_response_hash'; },
    ([manifest]) => { manifest.sources[0].complete_samples_verified = true; },
  ]) {
    const inputs = structuredClone(readCorpus()); mutate(inputs);
    assert.throws(() => checkCorpus(...inputs));
  }
});

test('sample censoring and summary mean use different predeclared semantics', () => {
  assert.equal(sampleDecision({ amount: '0', loq: '0.75' }), 'lt');
  assert.equal(summaryDecision({ amount: '0.00875', loq: '0.01' }), 'reported_summary_point_hold');
  assert.equal(summaryDecision({ amount: '0', loq_field_present: false }), 'reported_zero_precision_unverified');
});

test('each excerpt input schema is enforced and future versions are rejected', () => {
  for (let i = 0; i < 3; i += 1) {
    const inputs = structuredClone(readCorpus());
    inputs[i].schema = inputs[i].schema.replace('/1', '/2');
    assert.throws(() => checkCorpus(...inputs));
  }
});
