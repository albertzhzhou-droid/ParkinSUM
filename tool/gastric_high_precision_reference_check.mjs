import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { spawnSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';

const SCHEMA = 'parkinsum.gastric-high-precision-reference-check/1';
const PRECISION = 60n;
const SCALE = 10n ** PRECISION;
const LN2 = fromDecimal(
  '0.693147180559945309417232121458176568075500134360255254120680',
);
const BASE_TOLERANCE = fromDecimal('0.000000000005');

export function verifyLegacyFixture(fixture) {
const cases = [];
for (const vector of fixture.reference_vectors) {
  const parameters = Object.fromEntries(
    Object.entries(vector.parameters).map(([id, value]) => [
      id,
      fromDecimal(value),
    ]),
  );
  for (const point of vector.dart_values) {
    const expected = evaluate(vector.kind, parameters, BigInt(point.minute));
    const observed = fromDecimal(point.value_decimal);
    const difference = abs(expected - observed);
    const scale = max(SCALE, abs(expected));
    const tolerance = multiply(BASE_TOLERANCE, scale);
    cases.push({
      structure_id: vector.structure_id,
      kind: vector.kind,
      observable: vector.observable,
      minute: point.minute,
      passed: difference <= tolerance,
      expected_decimal: toDecimal(expected, 24),
      dart_decimal: point.value_decimal,
      absolute_difference: toDecimal(difference, 24),
      tolerance: toDecimal(tolerance, 24),
    });
  }
}

const first = cases[0];
const mutationDelta = fromDecimal('0.001');
const mutationObserved = fromDecimal(first.dart_decimal) + mutationDelta;
const mutationExpected = fromDecimal(first.expected_decimal);
const mutationTolerance = multiply(
  BASE_TOLERANCE,
  max(SCALE, abs(mutationExpected)),
);
const mutationDetected =
  abs(mutationObserved - mutationExpected) > mutationTolerance;
const passed = cases.every((entry) => entry.passed) && mutationDetected;

return {
  schema: SCHEMA,
  pass: passed,
  arithmetic: {
    implementation: 'independent-node-bigint-fixed-decimal',
    decimal_digits: Number(PRECISION),
    transcendental_method:
      'range-reduced Taylor exp and atanh-series log with fixed-decimal rounding',
    shared_runtime_with_production: false,
  },
  source_fixture_schema: fixture.schema,
  source_report_digest: fixture.report_digest,
  configuration_digest: fixture.configuration_digest,
  structure_count: fixture.reference_vectors.length,
  case_count: cases.length,
  failed_case_count: cases.filter((entry) => !entry.passed).length,
  mutation_detected: mutationDetected,
  cases,
  boundary:
    'Independent high-precision calculation verification for manufactured '
    + 'shadow-model vectors only. Passing does not establish parameter '
    + 'identifiability, biological validity, clinical calibration, individual '
    + 'prediction, treatment guidance, or medical advice.',
};

}

export function evaluate(kind, p, minute) {
  const t = minute * SCALE;
  switch (kind) {
    case 'productionComponentLagExponential': {
      const components = new Map();
      for (const [id, value] of Object.entries(p)) {
        const match = /^production\.(.+)\.(fraction|lag|half)$/.exec(id);
        if (!match) continue;
        const component = components.get(match[1]) ?? {};
        component[match[2]] = value;
        components.set(match[1], component);
      }
      let total = 0n;
      for (const component of components.values()) {
        const retention = t <= component.lag
          ? SCALE
          : expFp(
              -divide(
                multiply(LN2, t - component.lag),
                component.half,
              ),
            );
        total += multiply(component.fraction, retention);
      }
      return total;
    }
    case 'elashoffPowerExponential': {
      const ratio = divide(t, p['elashoff.t50']);
      const shaped = powFp(ratio, p['elashoff.beta']);
      return expFp(-multiply(LN2, shaped));
    }
    case 'siegelModifiedPowerExponential': {
      const oneMinusExponential = SCALE - expFp(-multiply(p['siegel.k'], t));
      return SCALE - powFp(oneMinusExponential, p['siegel.beta']);
    }
    case 'explicitLagExponential':
      return t <= p['lag_exp.lag']
        ? SCALE
        : expFp(
            -divide(
              multiply(LN2, t - p['lag_exp.lag']),
              p['lag_exp.half'],
            ),
          );
    case 'linearExponentialVolume': {
      const linear = SCALE + divide(
        multiply(p['linexp.kappa'], t),
        p['linexp.time'],
      );
      return multiply(
        multiply(p['linexp.v0'], linear),
        expFp(-divide(t, p['linexp.time'])),
      );
    }
    case 'doubleWeibullPellet': {
      const early = expFp(
        -powFp(
          divide(t, p['double_weibull.eta1']),
          p['double_weibull.beta1'],
        ),
      );
      const late = expFp(
        -powFp(
          divide(t, p['double_weibull.eta2']),
          p['double_weibull.beta2'],
        ),
      );
      return multiply(SCALE - p['double_weibull.h'], early)
        + multiply(p['double_weibull.h'], late);
    }
    default:
      throw new Error(`Unsupported gastric structure: ${kind}`);
  }
}

function expFp(value) {
  let reduced = value;
  let squarings = 0;
  while (abs(reduced) > SCALE / 8n) {
    reduced = roundDivide(reduced, 2n);
    squarings += 1;
  }
  let term = SCALE;
  let sum = SCALE;
  for (let index = 1n; index <= 400n; index += 1n) {
    term = roundDivide(multiply(term, reduced), index);
    if (term === 0n) break;
    sum += term;
  }
  if (sum <= 0n) throw new Error('High-precision exponential underflowed.');
  for (let index = 0; index < squarings; index += 1) {
    sum = multiply(sum, sum);
  }
  return sum;
}

function logFp(value) {
  if (value <= 0n) throw new Error('High-precision logarithm domain error.');
  let normalized = value;
  let powersOfTwo = 0n;
  while (normalized > (3n * SCALE) / 2n) {
    normalized = roundDivide(normalized, 2n);
    powersOfTwo += 1n;
  }
  while (normalized < (3n * SCALE) / 4n) {
    normalized *= 2n;
    powersOfTwo -= 1n;
  }
  const z = divide(normalized - SCALE, normalized + SCALE);
  const zSquared = multiply(z, z);
  let term = z;
  let sum = z;
  for (let denominator = 3n; denominator <= 999n; denominator += 2n) {
    term = multiply(term, zSquared);
    const addition = roundDivide(term, denominator);
    if (addition === 0n) break;
    sum += addition;
  }
  return 2n * sum + powersOfTwo * LN2;
}

function powFp(base, exponent) {
  if (base === 0n) {
    if (exponent <= 0n) throw new Error('Undefined zero power.');
    return 0n;
  }
  return expFp(multiply(exponent, logFp(base)));
}

function multiply(left, right) {
  return roundDivide(left * right, SCALE);
}

function divide(left, right) {
  if (right === 0n) throw new Error('High-precision division by zero.');
  return roundDivide(left * SCALE, right);
}

function roundDivide(numerator, denominator) {
  if (denominator === 0n) throw new Error('Division by zero.');
  const quotient = numerator / denominator;
  const remainder = numerator % denominator;
  if (remainder === 0n) return quotient;
  const direction = (numerator < 0n) !== (denominator < 0n) ? -1n : 1n;
  return abs(remainder) * 2n >= abs(denominator)
    ? quotient + direction
    : quotient;
}

export function fromDecimal(input) {
  if (!/^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?$/i.test(String(input).trim()) || String(input).length > 512) {
    throw new Error(`Invalid finite decimal: ${input}`);
  }
  let text = String(input).trim().toLowerCase();
  let sign = 1n;
  if (text.startsWith('-')) {
    sign = -1n;
    text = text.slice(1);
  } else if (text.startsWith('+')) {
    text = text.slice(1);
  }
  const [mantissa, exponentText = '0'] = text.split('e');
  const exponent = Number.parseInt(exponentText, 10);
  if (!Number.isInteger(exponent) || Math.abs(exponent) > 400) throw new Error(`Invalid decimal: ${input}`);
  const [whole = '0', fraction = ''] = mantissa.split('.');
  const digits = `${whole}${fraction}`.replace(/^0+(?=\d)/, '') || '0';
  const power = Number(PRECISION) + exponent - fraction.length;
  if (power >= 0) return sign * BigInt(digits) * 10n ** BigInt(power);
  const divisor = 10n ** BigInt(-power);
  return sign * roundDivide(BigInt(digits), divisor);
}

export function toDecimal(value, places) {
  const negative = value < 0n;
  const digits = abs(value).toString().padStart(Number(PRECISION) + 1, '0');
  const whole = digits.slice(0, -Number(PRECISION));
  const fraction = digits
    .slice(-Number(PRECISION), -Number(PRECISION) + places)
    .replace(/0+$/, '');
  return `${negative ? '-' : ''}${whole}${fraction ? `.${fraction}` : ''}`;
}

function abs(value) {
  return value < 0n ? -value : value;
}

function max(left, right) {
  return left > right ? left : right;
}

export const DOMAIN_CORPUS_SCHEMA = 'parkinsum.gastric-high-precision-domain-corpus/1';
export const DOMAIN_VECTOR_SCHEMA = 'parkinsum.gastric-high-precision-domain-vectors/1';
export const DOMAIN_CORPUS_PATH = 'test/fixtures/gastric_high_precision_domain/cases.json';
export const DOMAIN_SEED = 20260930;
const sha256 = value => createHash('sha256').update(value).digest('hex');

// Frozen manufactured calculation domain, not biological parameter support.
// The cancellation exclusion was declared before any Dart vectors were run.
export function domainHoldReason(kind, parameters, minute) {
  if (!Number.isInteger(minute) || minute < 0 || minute > 10080) return 'time_domain';
  let p;
  try { p = Object.fromEntries(Object.entries(parameters).map(([k, v]) => [k, fromDecimal(v)])); }
  catch { return 'finite_decimal_required'; }
  const inRange = (key, low, high) => Object.hasOwn(p, key) &&
    p[key] >= fromDecimal(low) && p[key] <= fromDecimal(high);
  const shape = key => inRange(key, '0.05', '8');
  const scale = key => inRange(key, '0.000001', '1000000');
  let keys;
  switch (kind) {
    case 'productionComponentLagExponential': {
      const ids = new Set(Object.keys(p).map(k => /^production\.([^.]+)\.(fraction|lag|half)$/.exec(k)?.[1]));
      if (ids.has(undefined) || ids.size < 1 || ids.size > 4) return 'component_identity';
      let total = 0n;
      for (const id of ids) {
        if (!inRange(`production.${id}.fraction`, '0', '1') ||
            !inRange(`production.${id}.lag`, '0', '1440') || !scale(`production.${id}.half`)) return 'parameter_domain';
        total += p[`production.${id}.fraction`];
      }
      if (Object.keys(p).length !== ids.size * 3 || abs(total - SCALE) > fromDecimal('0.000000000001')) return 'component_weights';
      return null;
    }
    case 'elashoffPowerExponential':
      keys = ['elashoff.t50', 'elashoff.beta'];
      if (!scale(keys[0]) || !shape(keys[1])) return 'parameter_domain';
      break;
    case 'siegelModifiedPowerExponential':
      keys = ['siegel.k', 'siegel.beta'];
      if (!inRange(keys[0], '0.000000001', '4') || !shape(keys[1])) return 'parameter_domain';
      if (minute > 0 && p[keys[1]] < SCALE && p[keys[0]] * BigInt(minute) < fromDecimal('0.000001')) return 'siegel_cancellation_domain';
      break;
    case 'explicitLagExponential':
      keys = ['lag_exp.lag', 'lag_exp.half'];
      if (!inRange(keys[0], '0', '1440') || !scale(keys[1])) return 'parameter_domain';
      break;
    case 'linearExponentialVolume':
      keys = ['linexp.v0', 'linexp.kappa', 'linexp.time'];
      if (!inRange(keys[0], '0', '2000') || !inRange(keys[1], '0', '2') || !scale(keys[2])) return 'parameter_domain';
      break;
    case 'doubleWeibullPellet':
      keys = ['double_weibull.h', 'double_weibull.eta1', 'double_weibull.beta1', 'double_weibull.eta2', 'double_weibull.beta2'];
      if (!inRange(keys[0], '0', '1') || !scale(keys[1]) || !shape(keys[2]) || !scale(keys[3]) || !shape(keys[4])) return 'parameter_domain';
      break;
    default: return 'unsupported_structure';
  }
  return Object.keys(p).length === keys.length && Object.keys(p).every(k => keys.includes(k)) ? null : 'parameter_identity';
}

export function evaluateDecimal(kind, parameters, minute) {
  const p = Object.fromEntries(Object.entries(parameters).map(([key, value]) => [key, fromDecimal(value)]));
  return evaluate(kind, p, BigInt(minute));
}

export function verifyDomainFixture(corpus, fixture, corpusBytes) {
  if (corpus.schema !== DOMAIN_CORPUS_SCHEMA || fixture.schema !== DOMAIN_VECTOR_SCHEMA ||
      corpus.seed !== DOMAIN_SEED || corpus.tolerance_decimal !== '0.000000000005' ||
      fixture.input_sha256 !== sha256(corpusBytes)) throw new Error('Domain corpus/vector identity mismatch.');
  const vectors = new Map(fixture.vectors.map(v => [v.case_id, v]));
  if (vectors.size !== fixture.vectors.length || vectors.size !== corpus.cases.length) throw new Error('Domain vector coverage mismatch.');
  const cases = []; const held = []; const diagnostics = [];
  for (const input of corpus.cases) {
    const vector = vectors.get(input.case_id);
    if (!vector || vector.kind !== input.kind || JSON.stringify(vector.parameters) !== JSON.stringify(input.parameters) ||
        vector.points.length !== input.minutes.length) throw new Error(`Domain input changed: ${input.case_id}`);
    for (let i = 0; i < input.minutes.length; i += 1) {
      const minute = input.minutes[i]; const point = vector.points[i];
      const reason = domainHoldReason(input.kind, input.parameters, minute);
      if (point.minute !== minute || point.hold_reason !== reason || point.status !== (reason ? 'HOLD' : 'supported') ||
          input.expected_status !== (reason ? 'HOLD' : 'supported') ||
          (input.expected_hold_reason ?? null) !== reason) throw new Error(`Domain disposition mismatch: ${input.case_id}:${minute}`);
      if (reason) {
        held.push({ case_id: input.case_id, minute, reason, numeric_projection: 'HOLD' });
        if (!input.diagnostic_only && point.value_decimal !== null) throw new Error('Held case emitted an ordinary numeric projection.');
        if (!input.diagnostic_only) continue;
      }
      const expected = evaluateDecimal(input.kind, input.parameters, minute);
      const observed = fromDecimal(point.value_decimal);
      const difference = abs(expected - observed);
      const tolerance = multiply(BASE_TOLERANCE, max(SCALE, abs(expected)));
      const entry = { case_id: input.case_id, kind: input.kind, minute,
        expected_decimal: toDecimal(expected, 30), dart_decimal: point.value_decimal,
        absolute_difference: toDecimal(difference, 30), tolerance: toDecimal(tolerance, 30),
        passed: difference <= tolerance };
      if (input.diagnostic_only) diagnostics.push({ ...entry, outside_supported_domain: true, numeric_projection: 'HOLD' });
      else cases.push(entry);
      if (input.analytic_anchors?.[minute] !== undefined &&
          abs(expected - fromDecimal(input.analytic_anchors[minute])) > fromDecimal('1e-45')) throw new Error('Independent analytic anchor failed.');
    }
  }
  const worst = entries => entries.reduce((a, b) => !a || fromDecimal(b.absolute_difference) > fromDecimal(a.absolute_difference) ? b : a, null);
  const first = cases[0];
  const mutationDetected = abs(fromDecimal(first.dart_decimal) + fromDecimal('0.001') -
      fromDecimal(first.expected_decimal)) > fromDecimal(first.tolerance);
  const counterexampleDetected = diagnostics.length > 0 && diagnostics.some(c => !c.passed);
  return {
    pass: cases.every(c => c.passed) && mutationDetected && counterexampleDetected,
    seed: DOMAIN_SEED, input_sha256: sha256(corpusBytes),
    parameter_case_count: corpus.cases.length, supported_point_count: cases.length,
    held_point_count: held.length, failed_supported_point_count: cases.filter(c => !c.passed).length,
    worst_supported_error: worst(cases), worst_excluded_diagnostic_error: worst(diagnostics),
    manufacturing_mutation_detected: mutationDetected,
    predeclared_cancellation_counterexample_detected: counterexampleDetected,
    cases, held, diagnostics,
  };
}

function runDart(script) {
  const run = spawnSync(process.env.DART_BIN ?? 'dart', ['run', script], { encoding: 'utf8' });
  if (run.status !== 0) throw new Error(`Dart vector runner failed: ${script}\n${run.stdout ?? ''}${run.stderr ?? ''}${run.error?.message ?? ''}`);
}

function main() {
  const domainOnly = process.argv.includes('--domain-only');
  const fixtureArgument = process.argv.indexOf('--domain-fixture');
  let legacy = null;
  if (!domainOnly) {
    runDart('tool/run_gastric_structural_uncertainty_check.dart');
    const fixture = JSON.parse(readFileSync('build/gastric_structural_uncertainty/latest.json', 'utf8'));
    if (fixture.passed !== true || !Array.isArray(fixture.reference_vectors)) throw new Error('Legacy structural fixture is missing or not passing.');
    legacy = verifyLegacyFixture(fixture);
  }
  if (fixtureArgument < 0) runDart('tool/run_gastric_high_precision_domain_vectors.dart');
  const corpusBytes = readFileSync(DOMAIN_CORPUS_PATH);
  const corpus = JSON.parse(corpusBytes);
  const vectorBytes = readFileSync(fixtureArgument < 0 ? 'build/gastric_high_precision_domain_vectors/latest.json' : process.argv[fixtureArgument + 1]);
  const domain = verifyDomainFixture(corpus, JSON.parse(vectorBytes), corpusBytes);
  const report = {
    ...(legacy ?? { schema: SCHEMA, arithmetic: { implementation: 'independent-node-bigint-fixed-decimal', decimal_digits: Number(PRECISION), shared_runtime_with_production: false } }),
    pass: (legacy?.pass ?? true) && domain.pass,
    legacy_gate_included: !domainOnly,
    extended_domain: domain,
    production_vector_sha256: sha256(vectorBytes),
    reference_source_sha256: sha256(readFileSync('tool/gastric_high_precision_reference_check.mjs')),
    production_evaluator_source_sha256: sha256(readFileSync('lib/domain/usecases/gastric_structural_uncertainty_service.dart')),
    production_runner_source_sha256: sha256(readFileSync('tool/run_gastric_high_precision_domain_vectors.dart')),
    input_generator_source_sha256: sha256(readFileSync('tool/generate_gastric_high_precision_domain_corpus.mjs')),
    tolerance_policy: '5e-12 * max(1, abs(independent_expected)); frozen before production vectors',
    boundary: 'Manufactured calculation verification only. Supported-domain numerical agreement is not biological validity, identifiability, clinical calibration or treatment guidance. Excluded diagnostics retain numeric projection HOLD.',
  };
  report.report_digest = sha256(JSON.stringify(report));
  mkdirSync('build/gastric_high_precision_reference', { recursive: true });
  writeFileSync('build/gastric_high_precision_reference/latest.json', `${JSON.stringify(report, null, 2)}\n`);
  writeFileSync('build/gastric_high_precision_reference/latest.md', [
    '# Gastric high-precision reference check', '', `Result: ${report.pass ? 'PASS' : 'FAILED'}`,
    `Legacy gate included: ${report.legacy_gate_included}`, `Supported extended points: ${domain.supported_point_count}`,
    `Held points: ${domain.held_point_count}`, `Failed supported points: ${domain.failed_supported_point_count}`,
    `Worst supported absolute error: ${domain.worst_supported_error.absolute_difference}`,
    `Excluded diagnostic error: ${domain.worst_excluded_diagnostic_error.absolute_difference}`,
    '', report.boundary, '',
  ].join('\n'));
  console.log(`Gastric high-precision reference: ${report.pass ? 'PASS' : 'FAILED'}; domain=${domain.supported_point_count} supported/${domain.held_point_count} HOLD; legacy=${!domainOnly}.`);
  if (!report.pass) process.exitCode = 1;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
