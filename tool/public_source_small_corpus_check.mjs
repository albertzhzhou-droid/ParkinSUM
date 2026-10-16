import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const ROOT = 'test/fixtures/public_source_small_corpus';
export const MANIFEST_SCHEMA = 'parkinsum.public-source-field-corpus/1';
export const EXCERPTS_SCHEMA = 'parkinsum.public-source-field-excerpts/1';
export const EXPECTATIONS_SCHEMA = 'parkinsum.public-source-field-expectations/1';
export const REPORT_SCHEMA = 'parkinsum.public-source-field-oracle-check/1';

// Independent finite-decimal arithmetic: no production importer, model,
// numeric selector, or production-generated expectations are imported.
function decimal(value) {
  if (!/^-?\d+(?:\.\d+)?$/.test(String(value))) throw new Error('Invalid decimal');
  const negative = String(value).startsWith('-');
  const [whole, fraction = ''] = String(value).replace(/^-/, '').split('.');
  return { numerator: (negative ? -1n : 1n) * BigInt(whole + fraction), scale: 10n ** BigInt(fraction.length) };
}

function less(left, right) {
  const a = decimal(left); const b = decimal(right);
  return a.numerator * b.scale < b.numerator * a.scale;
}

function samePortionProduct(value, weight, expected) {
  const v = decimal(value); const w = decimal(weight); const e = decimal(expected);
  return v.numerator * w.numerator * e.scale === e.numerator * v.scale * w.scale * 100n;
}

function pathValue(value, path) {
  for (const key of path) {
    if (value === null || typeof value !== 'object' || !Object.hasOwn(value, key)) throw new Error(`Missing excerpt path ${path.join('.')}`);
    value = value[key];
  }
  return value;
}

export function summaryDecision(excerpt) {
  if (String(excerpt.amount) === '0' && excerpt.loq_field_present === false) return 'reported_zero_precision_unverified';
  if (excerpt.loq !== undefined && less('0', excerpt.amount) && less(excerpt.amount, excerpt.loq)) return 'reported_summary_point_hold';
  return 'reported_summary';
}

export function sampleDecision(sample) {
  return String(sample.amount) === '0' && less('0', sample.loq) ? 'lt' : 'reported_sample';
}

export function checkCorpus(manifest, fields, expectations) {
  assert.equal(manifest.schema, MANIFEST_SCHEMA);
  assert.equal(fields.schema, EXCERPTS_SCHEMA);
  assert.equal(expectations.schema, EXPECTATIONS_SCHEMA);
  assert.equal(manifest.representation, 'extracted_field_excerpt');
  assert.equal(manifest.raw_response_sha256, null);
  assert.equal(manifest.complete_raw_responses_saved, false);
  assert.equal(manifest.full_sample_mean_checks, 'HOLD');
  assert.equal(expectations.complete_sample_mean_checks, 'HOLD');
  const sources = new Map(manifest.sources.map((source) => [source.source_id, source]));
  assert.equal(sources.size, manifest.sources.length);
  for (const source of sources.values()) {
    assert.equal(source.raw_response_sha256, null);
    assert.equal(source.complete_samples_verified, false);
    assert.equal(source.dataset_snapshot_release, null);
    assert.match(source.origin_url, /^https:\/\/(?:dailymed\.nlm\.nih\.gov|api\.nal\.usda\.gov)\//);
  }
  const entries = new Map(fields.cases.map((entry) => [entry.case_id, entry]));
  assert.equal(entries.size, fields.cases.length);
  assert.equal(entries.size, 18);
  assert.equal(expectations.cases.length, entries.size);
  const covered = new Set();
  const results = [];
  for (const expected of expectations.cases) {
    assert(!covered.has(expected.case_id)); covered.add(expected.case_id);
    const entry = entries.get(expected.case_id); assert(entry);
    for (const id of entry.source_ids) assert(sources.has(id));
    const excerpt = entry.excerpt;
    for (const check of expected.checks ?? []) assert.deepEqual(pathValue(excerpt, check.path), check.equals, `${entry.case_id}:${check.path.join('.')}`);
    if (expected.products) {
      const actual = excerpt.products.map((p) => [p.ndc, p.active[0].numerator.value, p.active[1].numerator.value]);
      assert.deepEqual(actual, expected.products);
      assert.equal(new Set(excerpt.products.map((p) => p.ndc)).size, 4);
      if (expected.all_forms) assert(excerpt.products.every((p) => p.form === expected.all_forms));
    }
    if (expected.portion_protein_expected_decimal) assert(samePortionProduct(excerpt.protein_per_100g, excerpt.gramWeight, expected.portion_protein_expected_decimal));
    if (expected.different_entities) assert.notEqual(excerpt.food_summaries[0].fdcId, excerpt.food_summaries[1].fdcId);
    if (expected.summary_decision) assert.equal(summaryDecision(expected.summary_path ? excerpt[expected.summary_path] : excerpt), expected.summary_decision);
    if (expected.sample_decision) assert.equal(sampleDecision(excerpt[expected.sample_path]), expected.sample_decision);
    if (expected.complete_samples) assert.equal(expected.complete_samples, 'HOLD');
    if (expected.absence_decision) assert.equal(expected.absence_decision, 'unknown');
    results.push({ case_id: entry.case_id, verified_fields_passed: true, source_complete: false, holds: entry.holds });
  }
  return { schema: REPORT_SCHEMA, pass: true, case_count: results.length, spl_case_count: results.filter((r) => r.case_id.startsWith('D')).length, fdc_case_count: results.filter((r) => r.case_id.startsWith('F')).length, full_sample_mean_checks: 'HOLD', production_imports: false, results };
}

export function readCorpus() {
  const read = (name) => JSON.parse(readFileSync(`${ROOT}/${name}.json`, 'utf8'));
  return [read('manifest'), read('extracted_fields'), read('expectations')];
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const inputs = readCorpus();
  const report = checkCorpus(...inputs);
  report.extracted_fixture_sha256 = Object.fromEntries(['manifest', 'extracted_fields', 'expectations'].map((name) => [name, createHash('sha256').update(readFileSync(`${ROOT}/${name}.json`)).digest('hex')]));
  report.source_response_sha256 = null;
  mkdirSync('build/public_source_small_corpus', { recursive: true });
  writeFileSync('build/public_source_small_corpus/latest.json', `${JSON.stringify(report, null, 2)}\n`);
  process.stdout.write(`Public source field oracle: PASS; ${report.case_count} excerpts; complete sample means HOLD.\n`);
}
