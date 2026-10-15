import assert from 'node:assert/strict';

export const PLAN_SCHEMA = 'parkinsum.synthetic-gastric-identifiability-plan/1';
export const FINE_PLAN_SCHEMA = 'parkinsum.synthetic-gastric-identifiability-fine-grid-plan/1';
export const VECTOR_SCHEMA = 'parkinsum.gastric-identifiability-vectors/1';
export const REPORT_SCHEMA = 'parkinsum.gastric-identifiability-check/1';
export const MACHINE_ROUNDING_TOLERANCE = 5e-12;

const isElashoff = id => id === 'gastric.shadow.elashoff_power_exponential.v1';
const isLag = id => id === 'gastric.shadow.explicit_lag_exponential.v1';
const parameterKey = parameters => JSON.stringify(Object.entries(parameters).sort(([a], [b]) => a.localeCompare(b)));

export function validatePlan(plan) {
  assert([PLAN_SCHEMA, FINE_PLAN_SCHEMA].includes(plan.schema));
  if (plan.schema === FINE_PLAN_SCHEMA) assert.match(plan.extends_original_plan_sha256, /^[a-f0-9]{64}$/);
  assert(Number.isInteger(plan.seed) && plan.seed >= 0 && plan.seed <= 0xffffffff);
  assert.equal(plan.models.length, 2);
  assert.deepEqual(new Set(plan.models.map(model => model.id)), new Set(['gastric.shadow.elashoff_power_exponential.v1', 'gastric.shadow.explicit_lag_exponential.v1']));
  assert.equal(plan.error_policy.noiseless_max_absolute_error, 1e-12);
  assert.equal(plan.error_policy.perturbed_max_absolute_error, 0.03);
  assert.equal(plan.error_policy.retain_all_grid_candidates_within_bound, true);
  assert.equal(plan.error_policy.no_optimizer_or_multistart_claim, true);
  assert.equal(plan.additional_failure_design.length, 1);
  for (const model of plan.models) {
    const keys = isElashoff(model.id) ? ['t50', 'beta'] : ['lag', 'half'];
    assert(isElashoff(model.id) || isLag(model.id));
    assert.deepEqual(Object.keys(model.grid), keys);
    let count = 1;
    for (const key of keys) {
      const values = model.grid[key];
      assert(Array.isArray(values) && values.length > 0 && values.length <= 128);
      assert.equal(new Set(values).size, values.length);
      assert(values.every(value => Number.isFinite(value) && (key === 'lag' ? value >= 0 : value > 0)));
      count *= values.length;
    }
    assert(count <= 10000);
    assert.deepEqual(Object.keys(model.truth), keys);
    assert(Object.values(model.truth).every(Number.isFinite));
    assert.equal(model.schedules.length, 4);
    assert.equal(new Set(model.schedules.map(schedule => schedule.id)).size, 4);
    for (const schedule of model.schedules) {
      assert(Array.isArray(schedule.minutes) && schedule.minutes.length > 0 && schedule.minutes.length <= 128);
      assert(schedule.minutes.every((minute, i) => Number.isInteger(minute) && minute >= 0 && minute <= 2400 && (i === 0 || minute > schedule.minutes[i - 1])));
      assert([0, 0.03].includes(schedule.noise_amplitude));
    }
  }
  return plan;
}

export function independentValue(id, parameters, minute) {
  assert(isElashoff(id) || isLag(id));
  return isElashoff(id)
    ? Math.exp(-Math.LN2 * Math.pow(minute / parameters.t50, parameters.beta))
    : minute <= parameters.lag ? 1 : Math.exp(-Math.LN2 * (minute - parameters.lag) / parameters.half);
}

export function gridParameters(model) {
  const keys = Object.keys(model.grid);
  return model.grid[keys[0]].flatMap(a => model.grid[keys[1]].map(b => ({[keys[0]]: a, [keys[1]]: b})));
}

export function declaredMinutes(plan, model) {
  return [...new Set([...plan.additional_failure_design[0].schedule, ...model.schedules.flatMap(schedule => schedule.minutes)])].sort((a, b) => a - b);
}

export function enumerateIndependentStudy(input) {
  const plan = validatePlan(input);
  const observe = (model, schedule, truth = model.truth) => {
    let state = plan.seed >>> 0;
    const points = schedule.minutes.map(minute => {
      state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
      const disturbance = ((state % 2001) - 1000) / 1000 * schedule.noise_amplitude;
      const unperturbed = independentValue(model.id, truth, minute);
      return {minute, unperturbed, declared_disturbance: disturbance, value: Math.max(0, Math.min(1, unperturbed + disturbance))};
    });
    const bound = schedule.noise_amplitude ? plan.error_policy.perturbed_max_absolute_error : plan.error_policy.noiseless_max_absolute_error;
    const candidates = gridParameters(model).map(parameters => {
      const errors = points.map(point => independentValue(model.id, parameters, point.minute) - point.value);
      return {parameters, max_absolute_error: Math.max(...errors.map(Math.abs)), rmse: Math.sqrt(errors.reduce((sum, error) => sum + error * error, 0) / errors.length)};
    });
    const retained = candidates.filter(candidate => candidate.max_absolute_error <= bound);
    if (schedule.exact_expected_candidate_count !== null && schedule.exact_expected_candidate_count !== undefined) assert.equal(retained.length, schedule.exact_expected_candidate_count, `${model.id}/${schedule.id} analytic count`);
    return {model_id: model.id, schedule_id: schedule.id, manufactured_truth: truth, points, max_absolute_error_bound: bound, grid_candidate_count: candidates.length, retained_candidate_count: retained.length, retained_candidates: retained, minimum_error_candidates: [...candidates].sort((a, b) => a.max_absolute_error - b.max_absolute_error).slice(0, 3), disposition: retained.length === 0 ? 'failed_grid_recovery' : retained.length === 1 ? 'unique_only_within_declared_grid' : 'non_unique_grid_recovery', analytic_expected_count: schedule.exact_expected_candidate_count ?? null};
  };
  const rows = plan.models.flatMap(model => model.schedules.map(schedule => observe(model, schedule)));
  for (const model of plan.models) {
    const failure = plan.additional_failure_design[0];
    rows.push(observe(model, {id: failure.id, minutes: failure.schedule, noise_amplitude: 0, exact_expected_candidate_count: 0}, isElashoff(model.id) ? failure.elashoff_truth : failure.lag_exp_truth));
  }
  return rows;
}

export function reviewActualStudy(plan, independentRows, study) {
  validatePlan(plan);
  const expectedKeys = plan.models.flatMap(model => [...model.schedules.map(schedule => schedule.id), plan.additional_failure_design[0].id].map(id => `${model.id}/${id}`));
  assert.deepEqual(independentRows.map(row => `${row.model_id}/${row.schedule_id}`).sort(), [...expectedKeys].sort(), 'Complete independent sampling designs are required');
  assert.equal(study.models.length, plan.models.length);
  let valueCount = 0;
  let maximumDifference = 0;
  const rows = [];
  for (const declared of plan.models) {
    const model = study.models.find(value => value.model_id === declared.id);
    assert(model, `Missing actual model ${declared.id}`);
    assert.equal(model.kind, isElashoff(declared.id) ? 'elashoffPowerExponential' : 'explicitLagExponential');
    assert.equal(model.actual_fit_disposition, 'priorFixedOnly');
    assert(model.actual_fit_reasons.includes('synthetic_series_cannot_authorize_fit'));
    const parameters = gridParameters(declared);
    const minutes = declaredMinutes(plan, declared);
    assert.equal(model.grid_candidate_count, parameters.length);
    assert.equal(model.vectors.length, parameters.length);
    for (let i = 0; i < parameters.length; i++) {
      const vector = model.vectors[i];
      assert.deepEqual(vector.parameters, parameters[i]);
      assert.deepEqual(vector.points.map(point => point.minute), minutes);
      for (const point of vector.points) {
        assert(Number.isFinite(point.value) && point.value >= 0 && point.value <= 1);
        const difference = Math.abs(point.value - independentValue(declared.id, parameters[i], point.minute));
        assert(difference <= MACHINE_ROUNDING_TOLERANCE, `Model value drift ${declared.id}/${i}/${point.minute}`);
        valueCount++;
        maximumDifference = Math.max(maximumDifference, difference);
      }
    }
    for (const expected of independentRows.filter(row => row.model_id === declared.id)) {
      const candidates = model.vectors.map(vector => {
        const errors = expected.points.map(point => vector.points.find(value => value.minute === point.minute).value - point.value);
        return {parameters: vector.parameters, max_absolute_error: Math.max(...errors.map(Math.abs)), rmse: Math.sqrt(errors.reduce((sum, error) => sum + error * error, 0) / errors.length)};
      });
      const retained = candidates.filter(candidate => candidate.max_absolute_error <= expected.max_absolute_error_bound);
      assert.deepEqual(retained.map(candidate => parameterKey(candidate.parameters)).sort(), expected.retained_candidates.map(candidate => parameterKey(candidate.parameters)).sort(), `${declared.id}/${expected.schedule_id} complete retained set`);
      rows.push({...expected, actual_dart_retained_candidate_count: retained.length, actual_dart_retained_candidates: retained, actual_dart_minimum_error_candidates: [...candidates].sort((a, b) => a.max_absolute_error - b.max_absolute_error).slice(0, 3)});
    }
  }
  assert.equal(rows.length, independentRows.length);
  const ordered = independentRows.map(expected => rows.find(row => row.model_id === expected.model_id && row.schedule_id === expected.schedule_id));
  return {rows: ordered, vector_value_count: valueCount, maximum_absolute_difference: maximumDifference};
}
