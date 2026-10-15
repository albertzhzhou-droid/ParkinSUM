// W14 receipt for actual production consumer tests. No expected values are
// generated here: manually authored tests and W17 expectations are inputs.
import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';

const testPaths = [
  'test/nutrient_evidence_adjudication_test.dart',
  'test/qualified_nutrient_point_selection_test.dart',
  'test/importer_source_semantics_test.dart',
  'test/catalog_revision_semantics_test.dart',
  'test/meal_protein_missingness_rule_test.dart',
];
const dartSources = directory => readdirSync(directory, { withFileTypes: true }).flatMap(entry =>
  entry.isDirectory() ? dartSources(`${directory}/${entry.name}`)
    : entry.name.endsWith('.dart') ? [`${directory}/${entry.name}`] : []);
// Bind consumers, models, source/config identities and their entire conservative
// lib scope; a prior passing test log must not attest a changed consumer graph.
const inputPaths = [
  ...dartSources('lib').sort(),
  'tool/nutrient_evidence_adjudication_check.mjs',
  'tool/public_source_small_corpus_check.mjs',
  'test/fixtures/public_source_small_corpus/manifest.json',
  'test/fixtures/public_source_small_corpus/extracted_fields.json',
  'test/fixtures/public_source_small_corpus/expectations.json',
  ...testPaths,
];
const sha256 = value => createHash('sha256').update(value).digest('hex');
const inputIdentities = Object.fromEntries(inputPaths.map(path => [path, sha256(readFileSync(path))]));
const run = spawnSync(process.env.FLUTTER_BIN ?? 'flutter',
  ['test', '--no-pub', '--reporter', 'expanded', ...testPaths], { encoding: 'utf8' });
const output = `${run.stdout ?? ''}${run.stderr ?? ''}${run.error?.message ?? ''}`;
const counts = [...output.matchAll(/\+(\d+)(?:\s+-\d+)?:/g)].map(m => Number(m[1]));
const report = {
  schema: 'parkinsum.nutrient-evidence-adjudication-check/1',
  pass: run.status === 0 && output.includes('All tests passed!'),
  process_exit_code: run.status,
  passed_test_count: counts.length ? Math.max(...counts) : 0,
  expected_values_source: 'preauthored_tests_and_public_excerpt_field_table',
  clinical_validation: 'HOLD',
  full_sample_mean_verification: 'HOLD',
  source_response_sha256: null,
  production_source_identity_scope: 'all_lib_dart_sources_including_consumers_models_and_configuration',
  input_sha256: inputIdentities,
  input_identity_sha256: sha256(JSON.stringify(inputIdentities)),
  test_output_sha256: sha256(output),
};
report.report_digest = sha256(JSON.stringify(report));
const outputDir = resolve('build/nutrient_evidence_adjudication');
mkdirSync(outputDir, { recursive: true });
writeFileSync(`${outputDir}/latest.log`, output);
writeFileSync(`${outputDir}/latest.json`, `${JSON.stringify(report, null, 2)}\n`);
console.log(`W14 ${report.pass ? 'PASS' : 'FAIL'} ${report.passed_test_count} tests; input=${report.input_identity_sha256}`);
if (!report.pass) process.exitCode = 1;
