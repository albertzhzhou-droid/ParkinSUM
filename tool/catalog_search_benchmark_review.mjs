import assert from 'node:assert/strict';
import {readFileSync, writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {resolve} from 'node:path';

export const PLAN_SCHEMA = 'parkinsum.catalog-search-benchmark-plan/1';
export const BENCHMARK_SCHEMA = 'parkinsum.catalog-search-benchmark/1';
export const REVIEW_SCHEMA = 'parkinsum.catalog-search-benchmark-independent-review/1';
const hash = value => createHash('sha256').update(value).digest('hex');
const jsonHash = value => hash(JSON.stringify(value));
const key = (query, limit) => JSON.stringify([query, limit]);

function distribution(samples, count) {
  assert(Array.isArray(samples) && samples.length === count);
  assert(samples.every(value => Number.isInteger(value) && value >= 0));
  const sorted = [...samples].sort((a, b) => a - b);
  return {median_us: sorted[Math.floor(sorted.length / 2)], p95_nearest_rank_us: sorted[Math.ceil(sorted.length * 0.95) - 1], raw_samples_us: samples};
}

export function reviewBenchmark(plan, report) {
  assert.equal(plan.schema, PLAN_SCHEMA);
  assert.equal(report.schema, BENCHMARK_SCHEMA);
  assert.equal(report.pass, true);
  assert.equal(plan.warmups, 2);
  assert.equal(plan.measured_repeats, 7);
  assert.deepEqual(plan.sizes, [100, 1000, 10000, 50000]);
  assert(Number.isInteger(plan.seed));
  assert.equal(plan.queries.length, 12);
  assert.equal(new Set(plan.queries).size, 12);
  assert.deepEqual(plan.limits, [null, 20]);
  assert.equal(plan.raw_canonical_pairs.length, 5);
  assert(plan.raw_canonical_pairs.every(pair => Array.isArray(pair) && pair.length === 2 && pair.every(value => typeof value === 'string' && value.length > 0)));
  assert.equal(report.rows.length, plan.sizes.length);
  const rows = [];
  for (let position = 0; position < plan.sizes.length; position++) {
    const row = report.rows[position];
    const size = plan.sizes[position];
    assert.equal(row.size, size);
    const raw = [];
    const canonical = [];
    for (let i = 0; i < size; i++) {
      const pair = plan.raw_canonical_pairs[(i + plan.seed) % plan.raw_canonical_pairs.length];
      const suffix = `marker${String(i % 97).padStart(3, '0')} id${String(i).padStart(6, '0')}`;
      raw.push(`${pair[0]} ${suffix}`);
      canonical.push(`${pair[1]} ${suffix}`);
    }
    assert.equal(row.raw_fixture_sha256, jsonHash(raw));
    assert.equal(row.canonical_fixture_sha256, jsonHash(canonical));
    assert(Number.isInteger(row.construction_us) && row.construction_us >= 0);
    assert(Number.isInteger(row.process_rss_before) && row.process_rss_before >= 0);
    assert(Number.isInteger(row.process_rss_after) && row.process_rss_after >= 0);
    const queries = new Map(row.queries.map(query => [key(query.query, query.limit), query]));
    assert.equal(queries.size, plan.queries.length * plan.limits.length);
    assert.equal(row.queries.length, queries.size);
    const measured = [];
    for (const query of plan.queries) for (const limit of plan.limits) {
      const observed = queries.get(key(query, limit));
      assert(observed);
      // Canonical texts are declared independently before either implementation
      // run. This oracle never imports or invokes the production normalizer.
      let expected = canonical.flatMap((text, i) => text.includes(query.toLowerCase()) ? [i] : []);
      if (limit !== null) expected = expected.slice(0, limit);
      assert.equal(observed.expected_count, expected.length);
      assert.equal(observed.actual_count, expected.length);
      assert.equal(observed.expected_ids_sha256, jsonHash(expected));
      assert.equal(observed.actual_ids_sha256, jsonHash(expected));
      assert.equal(observed.matches_independent, true);
      distribution(observed.index_warmup_samples_us, plan.warmups);
      distribution(observed.linear_warmup_samples_us, plan.warmups);
      measured.push({query, limit, result_count: expected.length, index: distribution(observed.index_samples_us, plan.measured_repeats), independent_linear: distribution(observed.linear_samples_us, plan.measured_repeats), index_raw_warmup_samples_us: observed.index_warmup_samples_us, independent_linear_raw_warmup_samples_us: observed.linear_warmup_samples_us});
    }
    rows.push({size, constructor_single_observation_us: row.construction_us, process_rss_before: row.process_rss_before, process_rss_after: row.process_rss_after, queries: measured});
  }
  return rows;
}

export function main() {
  const planBytes = readFileSync('config/catalog_search_benchmark_plan.json');
  const reportBytes = readFileSync('build/catalog_search_benchmark/latest.json');
  const plan = JSON.parse(planBytes);
  const report = JSON.parse(reportBytes);
  assert.equal(report.plan_sha256, hash(planBytes));
  assert.equal(report.source_file_sha256['lib/core/analysis/catalog_search_index.dart'], hash(readFileSync('lib/core/analysis/catalog_search_index.dart')));
  assert.equal(report.source_file_sha256['tool/run_catalog_search_benchmark.dart'], hash(readFileSync('tool/run_catalog_search_benchmark.dart')));
  const rows = reviewBenchmark(plan, report);
  const result = {schema: REVIEW_SCHEMA, pass: true, reviewed_at_utc: new Date().toISOString(), actual_report_sha256: hash(reportBytes), plan_sha256: hash(planBytes), source_file_sha256: report.source_file_sha256, rows, boundary: 'Direct Dart JIT index timing with complete actual warmup/sample records and independently regenerated exact result hashes. Process RSS is not isolated heap. No release UI, browser, native-device, energy, scientific-ranking or universal speedup qualification.'};
  writeFileSync('build/catalog_search_benchmark/independent_review.json', `${JSON.stringify(result, null, 2)}\n`);
  console.log(JSON.stringify({pass: true, sizes: rows.map(row => row.size), independently_verified_query_groups: rows.reduce((sum, row) => sum + row.queries.length, 0)}));
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
