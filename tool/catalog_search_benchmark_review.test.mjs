import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {reviewBenchmark, BENCHMARK_SCHEMA} from './catalog_search_benchmark_review.mjs';

const plan = JSON.parse(readFileSync('config/catalog_search_benchmark_plan.json'));
const jsonHash = value => createHash('sha256').update(JSON.stringify(value)).digest('hex');

// Manufactured report exercises the review gate only. These fixture timings
// are not observations; the separate Dart benchmark supplies all actual values.
function fixture() {
  return {schema: BENCHMARK_SCHEMA, pass: true, rows: plan.sizes.map(size => {
    const raw = [], canonical = [];
    for (let i = 0; i < size; i++) {
      const pair = plan.raw_canonical_pairs[(i + plan.seed) % 5];
      const suffix = `marker${String(i % 97).padStart(3, '0')} id${String(i).padStart(6, '0')}`;
      raw.push(`${pair[0]} ${suffix}`); canonical.push(`${pair[1]} ${suffix}`);
    }
    return {size, raw_fixture_sha256: jsonHash(raw), canonical_fixture_sha256: jsonHash(canonical), construction_us: 10, process_rss_before: 1000, process_rss_after: 900, queries: plan.queries.flatMap(query => plan.limits.map(limit => {
      let expected = canonical.flatMap((text, i) => text.includes(query.toLowerCase()) ? [i] : []);
      if (limit !== null) expected = expected.slice(0, limit);
      return {query, limit, matches_independent: true, expected_count: expected.length, actual_count: expected.length, expected_ids_sha256: jsonHash(expected), actual_ids_sha256: jsonHash(expected), index_samples_us: [7, 1, 4, 3, 2, 6, 5], linear_samples_us: [14, 2, 8, 6, 4, 12, 10], index_warmup_samples_us: [12, 9], linear_warmup_samples_us: [24, 18]};
    }))};
  })};
}

test('complete guard fixture recomputes distributions without treating RSS as heap', () => {
  const result = reviewBenchmark(plan, fixture());
  assert.equal(result.length, 4);
  assert.equal(result.flatMap(row => row.queries).length, 96);
  assert.equal(result[0].queries[0].index.median_us, 4);
  assert.equal(result[0].queries[0].index.p95_nearest_rank_us, 7);
  assert.equal(result[0].process_rss_after, 900);
});

test('wrong results, missing samples, duplicate queries and nonfinite durations reject', () => {
  const mutations = [
    report => {report.schema = 'parkinsum.catalog-search-benchmark/2';},
    report => {report.pass = false;},
    report => {report.rows.pop();},
    report => {report.rows[0].queries[0].actual_ids_sha256 = '0'.repeat(64);},
    report => {report.rows[0].queries[0].actual_count++;},
    report => {report.rows[0].queries[0].matches_independent = false;},
    report => {report.rows[0].queries[0].index_samples_us.pop();},
    report => {report.rows[0].queries[0].index_warmup_samples_us = [];},
    report => {report.rows[0].queries[0].index_samples_us[0] = NaN;},
    report => {report.rows[0].queries[1] = report.rows[0].queries[0];},
  ];
  const original = fixture();
  for (const mutate of mutations) {
    const report = structuredClone(original);
    mutate(report);
    assert.throws(() => reviewBenchmark(plan, report));
  }
});

test('empty experiments and altered repetition policies cannot claim the fixed scope', () => {
  for (const change of [value => {value.queries = [];}, value => {value.warmups = 0;}, value => {value.measured_repeats = 1;}, value => {value.limits = [null];}]) {
    const altered = structuredClone(plan);change(altered);
    assert.throws(() => reviewBenchmark(altered, fixture()));
  }
});
