import { spawnSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';

const SCHEMA = 'parkinsum.gastric-high-precision-reference-check/1';
const PRECISION = 60n;
const SCALE = 10n ** PRECISION;
const LN2 = fromDecimal(
  '0.693147180559945309417232121458176568075500134360255254120680',
);
const BASE_TOLERANCE = fromDecimal('0.000000000005');

const dart = spawnSync(
  'dart',
  ['run', 'tool/run_gastric_structural_uncertainty_check.dart'],
  { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] },
);
if (dart.status !== 0) {
  process.stderr.write(dart.stdout ?? '');
  process.stderr.write(dart.stderr ?? '');
  throw new Error('Dart gastric structural gate did not produce a valid fixture.');
}

const fixture = JSON.parse(
  readFileSync('build/gastric_structural_uncertainty/latest.json', 'utf8'),
);
if (fixture.passed !== true || !Array.isArray(fixture.reference_vectors)) {
  throw new Error('Gastric structural fixture is missing or not passing.');
}

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

const report = {
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

mkdirSync('build/gastric_high_precision_reference', { recursive: true });
writeFileSync(
  'build/gastric_high_precision_reference/latest.json',
  `${JSON.stringify(report, null, 2)}\n`,
);
writeFileSync(
  'build/gastric_high_precision_reference/latest.md',
  [
    '# Gastric high-precision reference check',
    '',
    `**Result:** ${passed ? 'PASS' : 'FAILED'}`,
    '',
    `Structures: ${report.structure_count}`,
    `Reference cases: ${report.case_count}`,
    `Failed cases: ${report.failed_case_count}`,
    `Mutation detected: ${mutationDetected ? 'yes' : 'NO'}`,
    '',
    '## Boundary',
    '',
    report.boundary,
    '',
  ].join('\n'),
);

process.stdout.write(
  `Gastric high-precision reference: ${passed ? 'PASS' : 'FAILED'}; `
    + `${cases.length} cases; ${fixture.reference_vectors.length} structures.\n`,
);
if (!passed) process.exitCode = 1;

function evaluate(kind, p, minute) {
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

function fromDecimal(input) {
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
  if (!Number.isInteger(exponent)) throw new Error(`Invalid decimal: ${input}`);
  const [whole = '0', fraction = ''] = mantissa.split('.');
  const digits = `${whole}${fraction}`.replace(/^0+(?=\d)/, '') || '0';
  const power = Number(PRECISION) + exponent - fraction.length;
  if (power >= 0) return sign * BigInt(digits) * 10n ** BigInt(power);
  const divisor = 10n ** BigInt(-power);
  return sign * roundDivide(BigInt(digits), divisor);
}

function toDecimal(value, places) {
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
