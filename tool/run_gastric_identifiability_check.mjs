import assert from 'node:assert/strict';
import {readFileSync, writeFileSync, existsSync, unlinkSync, mkdirSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {captureInputs} from './verification_runtime.mjs';
import {enumerateIndependentStudy, reviewActualStudy, VECTOR_SCHEMA, REPORT_SCHEMA, MACHINE_ROUNDING_TOLERANCE} from './gastric_identifiability_experiment.mjs';

const outputDirectory = 'build/gastric_identifiability';
const vectorPath = `${outputDirectory}/actual_vectors.json`;
const reportPath = `${outputDirectory}/latest.json`;
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const plans = ['config/gastric_identifiability_coarse_plan.json', 'config/gastric_identifiability_fine_plan.json'];
const sourceBefore = captureInputs(process.cwd());
mkdirSync(outputDirectory, {recursive: true});
for (const path of [vectorPath, reportPath]) if (existsSync(path)) unlinkSync(path);
// Freeze independent manufactured points/complete candidate sets in memory
// before invoking the actual Dart producer; actual output never creates its oracle.
const independent = plans.map(path => {
  const bytes = readFileSync(path);
  const plan = JSON.parse(bytes);
  return {path, plan, sha256: hash(bytes), rows: enumerateIndependentStudy(plan)};
});
assert.equal(independent[1].plan.extends_original_plan_sha256, independent[0].sha256);
execFileSync('dart', ['run', 'tool/run_gastric_identifiability_vectors.dart'], {stdio: 'inherit', timeout: 600000});
const vectorBytes = readFileSync(vectorPath);
const actual = JSON.parse(vectorBytes);
assert.equal(actual.schema, VECTOR_SCHEMA);
assert.equal(actual.studies.length, independent.length);
const studies = independent.map(expected => {
  const study = actual.studies.find(value => value.plan_path === expected.path);
  assert(study);
  assert.equal(study.plan_sha256, expected.sha256);
  return {plan_path: expected.path, plan_sha256: expected.sha256, ...reviewActualStudy(expected.plan, expected.rows, study)};
});
for (const [path, expected] of Object.entries(actual.source_file_sha256)) assert.equal(hash(readFileSync(path)), expected);
const sourceAfter = captureInputs(process.cwd());
assert.equal(sourceBefore.sha256, sourceAfter.sha256, 'Public input changed during actual model verification');
const report = {
  schema: REPORT_SCHEMA,
  pass: true,
  observed_at_utc: new Date().toISOString(),
  source_sha256: sourceBefore.sha256,
  actual_vectors_sha256: hash(vectorBytes),
  producer_source_file_sha256: actual.source_file_sha256,
  machine_rounding_tolerance: MACHINE_ROUNDING_TOLERANCE,
  vector_value_count: studies.reduce((sum, study) => sum + study.vector_value_count, 0),
  maximum_absolute_difference: Math.max(...studies.map(study => study.maximum_absolute_difference)),
  studies,
  synthetic_fit_authorization_remains_held: true,
  production_parameters_changed: false,
  not_clinically_calibrated: true,
  synthetic_demo_data_only: true,
  no_medical_advice: true,
  boundary: 'Manufactured finite-grid recovery and independently evaluated double-precision equations only. Grid uniqueness is not continuous identifiability. Disturbance is deterministic, not a probability model or clinical interval. Off-grid recovery failures and all retained candidates remain visible. No optimizer/multistart, fitted production parameter or clinical qualification claim.',
};
writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify({path: reportPath, pass: report.pass, vector_value_count: report.vector_value_count, maximum_absolute_difference: report.maximum_absolute_difference, rows: studies.reduce((sum, study) => sum + study.rows.length, 0)}));
