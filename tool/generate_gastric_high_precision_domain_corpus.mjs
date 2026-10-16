// Reproducible manufactured INPUTS. This file imports no production model and
// produces no expected numerical output apart from hand-derived 0/1/half anchors.
import { mkdirSync, writeFileSync } from 'node:fs';
const schema = 'parkinsum.gastric-high-precision-domain-corpus/1';
const seed = 20260930;
let state = seed >>> 0;
const next = limit => { state = (Math.imul(1664525, state) + 1013904223) >>> 0; return state % limit; };
const cases = [];
const commonMinutes = [0, 1, 10, 30, 60, 120, 480, 10080];
const add = (case_id, kind, parameters, options = {}) => cases.push({
  case_id, kind, parameters, minutes: commonMinutes, expected_status: 'supported', ...options,
});
const components = (fraction = '1', lag = '30', half = '45') => ({
  'production.a.fraction': fraction, 'production.a.lag': lag, 'production.a.half': half,
});
add('component_lag_boundary', 'productionComponentLagExponential', components(),
  { minutes: [0, 29, 30, 31, 75, 10080], analytic_anchors: { 0: '1', 30: '1', 75: '0.5' } });
add('component_zero_weight', 'productionComponentLagExponential', {
  ...components('0', '1440', '0.000001'),
  'production.b.fraction': '1', 'production.b.lag': '0', 'production.b.half': '60',
}, { analytic_anchors: { 0: '1', 60: '0.5' } });
add('component_fast_limit', 'productionComponentLagExponential', components('1', '0', '0.000001'));
add('component_slow_limit', 'productionComponentLagExponential', components('1', '0', '1000000'));
add('elashoff_half_anchor', 'elashoffPowerExponential', { 'elashoff.t50': '60', 'elashoff.beta': '1' },
  { analytic_anchors: { 0: '1', 60: '0.5' } });
add('elashoff_fast_shape_limit', 'elashoffPowerExponential', { 'elashoff.t50': '0.000001', 'elashoff.beta': '8' });
add('elashoff_slow_shape_limit', 'elashoffPowerExponential', { 'elashoff.t50': '1000000', 'elashoff.beta': '0.05' });
add('siegel_exponential_degenerate', 'siegelModifiedPowerExponential', { 'siegel.k': '0.01', 'siegel.beta': '1' },
  { analytic_anchors: { 0: '1' } });
add('siegel_cancellation_boundary', 'siegelModifiedPowerExponential', { 'siegel.k': '0.000001', 'siegel.beta': '0.05' });
add('siegel_fast_limit', 'siegelModifiedPowerExponential', { 'siegel.k': '4', 'siegel.beta': '8' });
add('lag_before_at_after', 'explicitLagExponential', { 'lag_exp.lag': '30', 'lag_exp.half': '45' },
  { minutes: [0, 29, 30, 31, 75, 10080], analytic_anchors: { 30: '1', 75: '0.5' } });
add('lag_max_boundary', 'explicitLagExponential', { 'lag_exp.lag': '1440', 'lag_exp.half': '0.000001' },
  { minutes: [0, 1439, 1440, 1441, 10080], analytic_anchors: { 1440: '1' } });
add('volume_zero_degenerate', 'linearExponentialVolume', { 'linexp.v0': '0', 'linexp.kappa': '2', 'linexp.time': '0.000001' },
  { analytic_anchors: { 0: '0', 1: '0', 10080: '0' } });
add('volume_max_initial', 'linearExponentialVolume', { 'linexp.v0': '2000', 'linexp.kappa': '2', 'linexp.time': '1000000' },
  { analytic_anchors: { 0: '2000' } });
add('weibull_zero_mix', 'doubleWeibullPellet', {
  'double_weibull.h': '0', 'double_weibull.eta1': '60', 'double_weibull.beta1': '1',
  'double_weibull.eta2': '0.000001', 'double_weibull.beta2': '8',
}, { analytic_anchors: { 0: '1' } });
add('weibull_one_mix', 'doubleWeibullPellet', {
  'double_weibull.h': '1', 'double_weibull.eta1': '0.000001', 'double_weibull.beta1': '8',
  'double_weibull.eta2': '1000000', 'double_weibull.beta2': '0.05',
});
for (let i = 0; i < 24; i += 1) {
  const half = String(1 + next(1000)); const lag = String(next(121));
  const beta = String(50 + next(751));
  const shape = `${Math.floor(Number(beta) / 100)}.${beta.slice(-2).padStart(2, '0')}`;
  const fraction = next(1001);
  const decimalFraction = n => `${Math.floor(n / 1000)}.${String(n % 1000).padStart(3, '0')}`;
  const id = `seeded_${String(i).padStart(2, '0')}`;
  switch (i % 6) {
    case 0: add(id, 'productionComponentLagExponential', {
      ...components(decimalFraction(fraction), lag, half),
      'production.b.fraction': decimalFraction(1000 - fraction),
      'production.b.lag': '0', 'production.b.half': String(1 + next(1000)),
    }); break;
    case 1: add(id, 'elashoffPowerExponential', { 'elashoff.t50': half, 'elashoff.beta': shape }); break;
    case 2: add(id, 'siegelModifiedPowerExponential', { 'siegel.k': `0.${String(10 + next(990)).padStart(3, '0')}`, 'siegel.beta': shape }); break;
    case 3: add(id, 'explicitLagExponential', { 'lag_exp.lag': lag, 'lag_exp.half': half }); break;
    case 4: add(id, 'linearExponentialVolume', { 'linexp.v0': String(next(2001)), 'linexp.kappa': '0.5', 'linexp.time': half }); break;
    case 5: add(id, 'doubleWeibullPellet', {
      'double_weibull.h': decimalFraction(fraction), 'double_weibull.eta1': half,
      'double_weibull.beta1': shape, 'double_weibull.eta2': String(1 + next(1000)),
      'double_weibull.beta2': '1',
    }); break;
  }
}
const hold = (id, kind, parameters, reason, minutes = [1], diagnostic_only = false) =>
  add(id, kind, parameters, { minutes, expected_status: 'HOLD', expected_hold_reason: reason, diagnostic_only });
hold('siegel_small_x_diagnostic', 'siegelModifiedPowerExponential', { 'siegel.k': '0.000000001', 'siegel.beta': '0.05' }, 'siegel_cancellation_domain', [1], true);
hold('zero_denominator', 'elashoffPowerExponential', { 'elashoff.t50': '0', 'elashoff.beta': '1' }, 'parameter_domain');
hold('negative_shape', 'elashoffPowerExponential', { 'elashoff.t50': '60', 'elashoff.beta': '-1' }, 'parameter_domain');
hold('missing_parameter', 'elashoffPowerExponential', { 'elashoff.t50': '60' }, 'parameter_domain');
hold('unknown_parameter', 'elashoffPowerExponential', { 'elashoff.t50': '60', 'elashoff.beta': '1', 'unknown': '1' }, 'parameter_identity');
hold('non_finite_parameter', 'elashoffPowerExponential', { 'elashoff.t50': 'NaN', 'elashoff.beta': '1' }, 'finite_decimal_required');
hold('future_structure', 'unregisteredStructure', {}, 'unsupported_structure');
hold('fractional_minute', 'explicitLagExponential', { 'lag_exp.lag': '0', 'lag_exp.half': '60' }, 'time_domain', [0.5]);
hold('negative_minute', 'explicitLagExponential', { 'lag_exp.lag': '0', 'lag_exp.half': '60' }, 'time_domain', [-1]);
hold('outside_time_domain', 'explicitLagExponential', { 'lag_exp.lag': '0', 'lag_exp.half': '60' }, 'time_domain', [10081]);
hold('invalid_component_weights', 'productionComponentLagExponential', components('0.5'), 'component_weights');
hold('empty_components', 'productionComponentLagExponential', {}, 'component_identity');
hold('outside_mix_domain', 'doubleWeibullPellet', {
  'double_weibull.h': '1.1', 'double_weibull.eta1': '60', 'double_weibull.beta1': '1',
  'double_weibull.eta2': '120', 'double_weibull.beta2': '1',
}, 'parameter_domain');
const corpus = { schema, representation: 'manufactured_calculation_inputs', seed,
  tolerance_decimal: '0.000000000005', tolerance_scale: 'max(1, abs(independent_expected))',
  scientific_qualification: 'HOLD', clinical_calibration: 'HOLD',
  domain: { integer_minutes: [0, 10080], positive_time_scales: ['0.000001', '1000000'],
    lag_minutes: ['0', '1440'], shape: ['0.05', '8'], siegel_k: ['0.000000001', '4'],
    volume: ['0', '2000'], kappa: ['0', '2'], fractions: ['0', '1'], components: [1, 4],
    component_sum_tolerance: '0.000000000001',
    predeclared_exclusion: 'Siegel: t>0, beta<1 and k*t<1e-6 remains HOLD; cancellation diagnostic only' }, cases };
mkdirSync('test/fixtures/gastric_high_precision_domain', { recursive: true });
writeFileSync('test/fixtures/gastric_high_precision_domain/cases.json', `${JSON.stringify(corpus, null, 2)}\n`);
console.log(`Manufactured domain corpus: ${cases.length} parameter cases; seed=${seed}.`);
