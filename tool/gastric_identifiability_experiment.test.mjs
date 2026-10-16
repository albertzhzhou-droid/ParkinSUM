import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';
import {validatePlan, enumerateIndependentStudy, reviewActualStudy, gridParameters, declaredMinutes, independentValue} from './gastric_identifiability_experiment.mjs';

const coarse = JSON.parse(readFileSync('config/gastric_identifiability_coarse_plan.json'));
const fine = JSON.parse(readFileSync('config/gastric_identifiability_fine_plan.json'));
const find = (rows, model, schedule) => rows.find(row => row.model_id.includes(model) && row.schedule_id === schedule);

// These fabricated vectors exercise only the review gate's rejection behavior.
// The separate required producer actually invokes the Dart model for every point.
function fabricatedStudy(plan) {
  return {models: plan.models.map(model => ({
    model_id: model.id,
    kind: model.id.includes('elashoff') ? 'elashoffPowerExponential' : 'explicitLagExponential',
    grid_candidate_count: gridParameters(model).length,
    actual_fit_disposition: 'priorFixedOnly',
    actual_fit_reasons: ['synthetic_series_cannot_authorize_fit'],
    vectors: gridParameters(model).map(parameters => ({parameters, points: declaredMinutes(plan, model).map(minute => ({minute, value: independentValue(model.id, parameters, minute)}))})),
  }))};
}

test('frozen analytic sampling expectations retain indistinguishable parameters', () => {
  for (const [plan, expected] of [[coarse, [30, 6, 25, 20]], [fine, [2091, 51, 3721, 3111]]]) {
    const rows = enumerateIndependentStudy(plan);
    assert.equal(find(rows, 'elashoff', 'zero_only').retained_candidate_count, expected[0]);
    assert.equal(find(rows, 'elashoff', 'midpoint_only').retained_candidate_count, expected[1]);
    assert.equal(find(rows, 'explicit_lag', 'zero_only').retained_candidate_count, expected[2]);
    assert.equal(find(rows, 'explicit_lag', 'prelag_plateau').retained_candidate_count, expected[3]);
  }
});

test('refinement exposes wider bounded-disturbance candidate regions', () => {
  const c = enumerateIndependentStudy(coarse);
  const f = enumerateIndependentStudy(fine);
  assert.equal(find(c, 'elashoff', 'spread_bounded_perturbation').retained_candidate_count, 1);
  assert.equal(find(c, 'explicit_lag', 'spread_bounded_perturbation').retained_candidate_count, 1);
  assert.equal(find(f, 'elashoff', 'spread_bounded_perturbation').retained_candidate_count, 7);
  assert.equal(find(f, 'explicit_lag', 'spread_bounded_perturbation').retained_candidate_count, 48);
  assert.equal(find(f, 'elashoff', 'spread_bounded_perturbation').disposition, 'non_unique_grid_recovery');
});

test('off-grid manufactured truth remains a recorded recovery failure', () => {
  for (const plan of [coarse, fine]) {
    for (const row of enumerateIndependentStudy(plan).filter(row => row.schedule_id === 'off_grid_truth')) {
      assert.equal(row.retained_candidate_count, 0);
      assert.equal(row.disposition, 'failed_grid_recovery');
      assert(row.minimum_error_candidates.every(candidate => candidate.max_absolute_error > row.max_absolute_error_bound));
    }
  }
});

test('declared seed reproduces disturbances and does not invent a probability model', () => {
  const first = enumerateIndependentStudy(coarse);
  assert.deepEqual(enumerateIndependentStudy(coarse), first);
  const changed = structuredClone(coarse);
  changed.seed++;
  const next = enumerateIndependentStudy(changed);
  assert.notDeepEqual(find(next, 'elashoff', 'spread_bounded_perturbation').points, find(first, 'elashoff', 'spread_bounded_perturbation').points);
  assert.equal(coarse.error_policy.no_optimizer_or_multistart_claim, true);
});

test('unsupported schemas, domains, duplicate candidates and changed policy reject', () => {
  const mutations = [
    plan => {plan.schema = 'parkinsum.synthetic-gastric-identifiability-plan/2';},
    plan => {plan.seed = 0.5;},
    plan => {plan.models[0].grid.beta.push(plan.models[0].grid.beta[0]);},
    plan => {plan.models[0].grid.t50[0] = -1;},
    plan => {plan.models[0].schedules[0].minutes = [1, 0];},
    plan => {plan.models[0].schedules[0].noise_amplitude = 0.01;},
    plan => {plan.error_policy.retain_all_grid_candidates_within_bound = false;},
    plan => {plan.models[0].grid.beta = Array.from({length: 129}, (_, i) => i + 1);},
  ];
  for (const mutate of mutations) {
    const plan = structuredClone(coarse);
    mutate(plan);
    assert.throws(() => validatePlan(plan));
  }
});

test('review gate accepts complete vectors only while synthetic fitting stays held', () => {
  const expected = enumerateIndependentStudy(coarse);
  const review = reviewActualStudy(coarse, expected, fabricatedStudy(coarse));
  assert.equal(review.rows.length, 10);
  assert.equal(review.maximum_absolute_difference, 0);
  assert(review.vector_value_count > 0);
  assert.deepEqual(review.rows.map(row => row.actual_dart_retained_candidate_count), expected.map(row => row.retained_candidate_count));
});

test('truncated, duplicate, nonfinite, drifting or incorrectly authorized vectors reject', () => {
  const expected = enumerateIndependentStudy(coarse);
  const mutations = [
    study => {study.models[0].vectors.pop();},
    study => {study.models[0].vectors[1] = study.models[0].vectors[0];},
    study => {study.models[0].vectors[0].points[0].value = NaN;},
    study => {study.models[0].vectors[0].points[0].value = 0.9;},
    study => {study.models[0].vectors[0].points[0].minute = 240;},
    study => {study.models[0].actual_fit_disposition = 'eligibleForResearchFit';},
    study => {study.models[0].actual_fit_reasons = [];},
    study => {study.models[0].kind = 'wrongModel';},
  ];
  for (const mutate of mutations) {
    const study = fabricatedStudy(coarse);
    mutate(study);
    assert.throws(() => reviewActualStudy(coarse, expected, study));
  }
});

test('a truncated independent retained set cannot masquerade as agreement', () => {
  const expected = enumerateIndependentStudy(coarse);
  expected[0].retained_candidates.pop();
  assert.throws(() => reviewActualStudy(coarse, expected, fabricatedStudy(coarse)));
});

test('a missing or repeated independent sampling design rejects', () => {
  const missing = enumerateIndependentStudy(coarse);
  missing.pop();
  assert.throws(() => reviewActualStudy(coarse, missing, fabricatedStudy(coarse)));
  const repeated = enumerateIndependentStudy(coarse);
  repeated[1] = repeated[0];
  assert.throws(() => reviewActualStudy(coarse, repeated, fabricatedStudy(coarse)));
});
