#!/usr/bin/env node

import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';

const fixtureBytes = readFileSync('test/fixtures/dose_expression_vectors.json');
const fixture = JSON.parse(fixtureBytes.toString('utf8'));
const fuzzSeed = 0x5eedc0de;
const fuzzIterations = 128;

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function held(reason, diagnostic = null) {
  return {
    status: 'held', reason, value: null, unit: null, dimension: null,
    diagnostic, mapping: null,
  };
}

function mappingProjection(rawUnit) {
  const sourceCode = rawUnit.toLowerCase();
  const table = new Map([
    ['mg', ['mg', 'mg', 1, 1, false]],
    ['milligram', ['mg', 'mg', 1, 1, true]],
    ['milligrams', ['mg', 'mg', 1, 1, true]],
    ['g', ['g', 'mg', 1000, 1, false]],
    ['gram', ['g', 'mg', 1000, 1, true]],
    ['grams', ['g', 'mg', 1000, 1, true]],
    ['mcg', ['mcg', 'mg', 1, 1000, false]],
    ['ug', ['mcg', 'mg', 1, 1000, true]],
    ['µg', ['mcg', 'mg', 1, 1000, true]],
    ['μg', ['mcg', 'mg', 1, 1000, true]],
    ['microgram', ['mcg', 'mg', 1, 1000, true]],
    ['micrograms', ['mcg', 'mg', 1, 1000, true]],
    ['ml', ['mL', 'mL', 1, 1, false]],
    ['milliliter', ['mL', 'mL', 1, 1, true]],
    ['milliliters', ['mL', 'mL', 1, 1, true]],
  ]);
  const spec = table.get(sourceCode);
  if (!spec) return null;
  const [canonicalCode, baseUnitCode, conversionNumerator, conversionDenominator, alias] = spec;
  const conversion = conversionNumerator !== conversionDenominator;
  const hasLexicalAlias = alias || rawUnit.trim() !== sourceCode;
  const mappingType = hasLexicalAlias
    ? (conversion ? 'exactAliasAndConversion' : 'exactAlias')
    : (conversion ? 'exactConversion' : 'exactIdentity');
  const dimension = baseUnitCode === 'mL' ? 'volume' : 'mass';
  return {
    sourceCode,
    sourceDisplay: rawUnit,
    canonicalCode,
    baseUnitCode,
    mappingType,
    conversionNumerator,
    conversionDenominator,
    sourceDimension: dimension,
    targetDimension: dimension,
  };
}

// Independent JavaScript reference implementation. It does not import or
// translate the Dart parser; both runtimes are compared with a neutral vector
// file so a partial-match regression cannot self-pass.
function diagnosticMapping(rawUnit, grammarDigest) {
  const compact = mappingProjection(rawUnit);
  if (!compact) return null;
  const isVolume = compact.baseUnitCode === 'mL';
  const canonicalDisplay = compact.canonicalCode === 'mL'
    ? 'milliliter'
    : compact.canonicalCode === 'g'
      ? 'gram'
      : compact.canonicalCode === 'mcg'
        ? 'microgram'
        : 'milligram';
  const evidence = {
    schema: 'parkinsum.versioned-dose-unit-mapping/1',
    sourceSystemUri: 'urn:parkinsum:dose-unit-token',
    sourceCode: compact.sourceCode,
    sourceDisplay: rawUnit,
    sourceTerminologyVersion: '2',
    canonicalSystemUri: 'urn:parkinsum:dose-unit',
    canonicalCode: compact.canonicalCode,
    canonicalDisplay,
    canonicalTerminologyVersion: '2',
    baseUnitSystemUri: 'urn:parkinsum:dose-unit',
    baseUnitCode: compact.baseUnitCode,
    baseUnitDisplay: isVolume ? 'milliliter' : 'milligram',
    baseUnitTerminologyVersion: '2',
    sourceRevision: grammarDigest,
    mappingType: compact.mappingType,
    jurisdiction: 'not_applicable_user_entered_local_vocabulary',
    reviewDate: '2026-09-23',
    licenseState: 'local_authored_no_external_asset',
    sourceDimension: compact.sourceDimension,
    targetDimension: compact.targetDimension,
    conversionNumerator: compact.conversionNumerator,
    conversionDenominator: compact.conversionDenominator,
  };
  return {
    display: rawUnit,
    system: 'urn:parkinsum:dose-unit',
    code: compact.canonicalCode,
    version: '2',
    dimension: compact.sourceDimension,
    mappingEvidence: evidence,
  };
}

function diagnosticProjectionForInput(normalized, grammarDigest) {
  const number = '[0-9]+(?:\\.[0-9]+)?';
  const unit = '(milligrams?|micrograms?|milliliters?|mcg|mg|ug|µg|μg|grams?|g|ml)';
  const comparatorMatch = new RegExp(`^(<=|>=|<|>)\\s*(${number})\\s*${unit}$`, 'iu')
    .exec(normalized);
  if (comparatorMatch) {
    const lexicalValue = comparatorMatch[2];
    const value = Number(lexicalValue);
    const unitDisplay = comparatorMatch[3];
    const mappedUnit = diagnosticMapping(unitDisplay, grammarDigest);
    if (Number.isFinite(value) && value >= 0 && mappedUnit) {
      const valueStart = comparatorMatch[0].indexOf(lexicalValue);
      const unitStart = comparatorMatch[0].length - unitDisplay.length;
      return {
        kind: 'comparatorQuantity',
        comparator: comparatorMatch[1],
        quantity: {
          lexicalValue,
          value,
          valueSpan: { start: valueStart, end: valueStart + lexicalValue.length },
          unitSpan: { start: unitStart, end: unitStart + unitDisplay.length },
          unit: mappedUnit,
        },
        lowerBound: null,
        upperBound: null,
        sourceSpan: { start: 0, end: normalized.length },
        displayText: `${comparatorMatch[1]} ${lexicalValue} ${unitDisplay}`,
        resultEligible: false,
      };
    }
  }

  const rangeMatch = new RegExp(`^(${number})\\s*(?:-|–|—|\\bto\\b)\\s*(${number})\\s*${unit}$`, 'iu')
    .exec(normalized);
  if (!rangeMatch) return null;
  const lowerText = rangeMatch[1];
  const upperText = rangeMatch[2];
  const lowerValue = Number(lowerText);
  const upperValue = Number(upperText);
  const unitDisplay = rangeMatch[3];
  const mappedUnit = diagnosticMapping(unitDisplay, grammarDigest);
  if (
    !Number.isFinite(lowerValue) || !Number.isFinite(upperValue) ||
    lowerValue < 0 || upperValue < lowerValue || !mappedUnit
  ) return null;
  const lowerStart = rangeMatch[0].indexOf(lowerText);
  const upperStart = rangeMatch[0].indexOf(upperText, lowerStart + lowerText.length);
  const unitStart = rangeMatch[0].length - unitDisplay.length;
  const quantity = (lexicalValue, value, valueStart) => ({
    lexicalValue,
    value,
    valueSpan: { start: valueStart, end: valueStart + lexicalValue.length },
    unitSpan: { start: unitStart, end: unitStart + unitDisplay.length },
    unit: mappedUnit,
  });
  return {
    kind: 'closedRange',
    comparator: null,
    quantity: null,
    lowerBound: quantity(lowerText, lowerValue, lowerStart),
    upperBound: quantity(upperText, upperValue, upperStart),
    sourceSpan: { start: 0, end: normalized.length },
    displayText: `${lowerText}–${upperText} ${unitDisplay}`,
    resultEligible: false,
  };
}

function inspectReference(rawInput, grammarDigest = '') {
  const raw = String(rawInput ?? '');
  const normalized = raw.trim().replace(/\s+/gu, ' ');
  if (!normalized) {
    return {
      status: 'empty', reason: 'dose.empty', value: null, unit: null,
      dimension: null, diagnostic: null, mapping: null,
    };
  }
  if (raw.length > 256) return held('dose.too_long');
  if (/[\u0000-\u001f\u007f]/u.test(raw)) return held('dose.control_character');
  if (/\b(?:nan|inf|infinity)\b/iu.test(normalized)) return held('dose.nonfinite_literal');
  if (/[0-9](?:e|E)[+-]?[0-9]/u.test(normalized)) return held('dose.scientific_notation');
  if (/[0-9],[0-9]/u.test(normalized)) return held('dose.locale_decimal_ambiguous');
  if (/(?:^|[^0-9])[.,][0-9]/u.test(normalized)) return held('dose.leading_decimal_not_supported');
  if (/[<>=~≈]/u.test(normalized)) {
    return held(
      'dose.non_exact_comparator',
      diagnosticProjectionForInput(normalized, grammarDigest),
    );
  }
  if (/[0-9]\s*(?:-|–|—|\bto\b)\s*[0-9]/iu.test(normalized)) {
    return held(
      'dose.range_not_supported',
      diagnosticProjectionForInput(normalized, grammarDigest),
    );
  }
  if (
    /(?:^|[\s(])[+-]\s*[0-9]/u.test(normalized) ||
    /[\u2212\u2012\u2013\u2014\ufe63\uff0b\uff0d]\s*[0-9]/u.test(normalized)
  ) return held('dose.signed_value');
  if (
    /(?:\/|\bper\b)\s*(?:min|minute|h|hr|hour|day|kg|kilogram)\b/iu.test(normalized) ||
    /\b(?:min|minute|h|hr|hour|day|kg|kilogram)\s*(?:-1|⁻1)\b/iu.test(normalized)
  ) {
    return held('dose.rate_not_supported');
  }
  if (normalized.includes('/')) return held('dose.combination_or_ratio');
  if (/\b(one|two|three|four|five|six|seven|eight|nine|ten|a|an)\b/iu.test(normalized)) {
    return held('dose.word_number_ambiguous');
  }

  const numbers = [...normalized.matchAll(/[0-9]+(?:\.[0-9]+)?/gu)];
  if (numbers.length === 0) return held('dose.numeric_token_missing');
  if (numbers.length !== 1) return held('dose.multiple_numeric_tokens');

  const quantityPattern = /([0-9]+(?:\.[0-9]+)?)\s*(milligrams?|micrograms?|milliliters?|mcg|mg|ug|µg|μg|grams?|g|ml)(?![\p{L}\p{M}\p{C}])/giu;
  const unitPattern = /(?<![\p{L}\p{M}\p{C}])(milligrams?|micrograms?|milliliters?|mcg|mg|ug|µg|μg|grams?|g|ml)(?![\p{L}\p{M}\p{C}])/giu;
  const quantities = [...normalized.matchAll(quantityPattern)];
  const units = [...normalized.matchAll(unitPattern)];
  if (quantities.length !== 1 || units.length !== 1) {
    const trailing = normalized.slice(numbers[0].index + numbers[0][0].length).trimStart();
    return held(trailing && /^[A-Za-zµμ]/u.test(trailing) ? 'dose.unit_unsupported' : 'dose.unit_missing');
  }
  if (quantities[0].index !== numbers[0].index) return held('dose.partial_match_blocked');

  const value = Number(quantities[0][1]);
  if (!Number.isFinite(value) || value <= 0) return held('dose.value_invalid');
  const rawUnit = quantities[0][2].toLowerCase();
  const sourceDisplay = quantities[0][2];
  const canonical = new Map([
    ['milligram', 'mg'], ['milligrams', 'mg'],
    ['gram', 'g'], ['grams', 'g'],
    ['ug', 'mcg'], ['µg', 'mcg'], ['μg', 'mcg'],
    ['microgram', 'mcg'], ['micrograms', 'mcg'],
    ['milliliter', 'mL'], ['milliliters', 'mL'], ['ml', 'mL'],
  ]).get(rawUnit) ?? rawUnit;
  return {
    status: 'accepted',
    reason: null,
    value,
    unit: canonical,
    dimension: canonical === 'mL' ? 'volume' : 'mass',
    diagnostic: null,
    mapping: mappingProjection(sourceDisplay),
  };
}

function expectedProjection(vector, grammarDigest) {
  const normalized = String(vector.input ?? '').trim().replace(/\s+/gu, ' ');
  return {
    status: vector.status,
    reason: vector.reason ?? null,
    value: vector.value ?? null,
    unit: vector.unit ?? null,
    dimension: vector.dimension ?? null,
    diagnostic: diagnosticProjectionForInput(normalized, grammarDigest),
    mapping: vector.status === 'accepted'
      ? mappingProjection(vector.input.match(/(?:milligrams?|micrograms?|milliliters?|mcg|mg|ug|µg|μg|grams?|g|ml)/iu)?.[0] ?? '')
      : null,
  };
}

function generateMutationCases(seed, iterations) {
  let state = seed >>> 0;
  const next = () => {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    return state;
  };
  const units = [
    'mg', 'milligrams', 'g', 'grams', 'mcg', 'µg', 'μg', 'mL',
    'milliliters',
  ];
  const cases = [];
  const families = new Set();

  for (let index = 0; index < iterations; index += 1) {
    const value = (next() % 9000) + 1;
    const secondValue = value + (next() % 80) + 1;
    const groupedValue = String(value).padStart(3, '0');
    const unit = units[next() % units.length];
    const base = `${value} ${unit}`;
    const fraction = (next() % 9) + 1;
    const exponent = (next() % 5) + 1;
    const unitIndex = (next() % units.length);
    const ratioUnit = units[unitIndex] === unit ? 'mL' : units[unitIndex];
    const casesForSeed = [
      ['comparator_lt', `<${base}`, 'dose.non_exact_comparator'],
      ['comparator_lte', `<=${base}`, 'dose.non_exact_comparator'],
      ['comparator_gt', `>${base}`, 'dose.non_exact_comparator'],
      ['comparator_gte', `>=${base}`, 'dose.non_exact_comparator'],
      ['range_hyphen', `${value}-${secondValue} ${unit}`, 'dose.range_not_supported'],
      ['range_to', `${value} to ${secondValue} ${unit}`, 'dose.range_not_supported'],
      ['rate_slash', `${base}/hour`, 'dose.rate_not_supported'],
      ['rate_per', `${base} per day`, 'dose.rate_not_supported'],
      ['ratio', `${base}/${secondValue} ${ratioUnit}`, 'dose.combination_or_ratio'],
      ['hidden_second_quantity', `${base} then ${secondValue} mg`, 'dose.multiple_numeric_tokens'],
      ['duplicate_unit', `${base} ${unit}`, 'dose.unit_unsupported'],
      ['unsupported_unit', `${value} IU`, 'dose.unit_unsupported'],
      ['locale_decimal', `${value},${fraction} ${unit}`, 'dose.locale_decimal_ambiguous'],
      ['scientific_notation', `${value}e${exponent} ${unit}`, 'dose.scientific_notation'],
      ['negative_value', `-${value} ${unit}`, 'dose.signed_value'],
      ['unicode_confusable_unit', `${value} mℊ`, 'dose.unit_unsupported'],
      ['unicode_letter_confusable_suffix', `${base}ℊ`, 'dose.unit_unsupported'],
      ['unicode_combining_mark_suffix', `${base}\u0307`, 'dose.unit_unsupported'],
      ['unicode_format_suffix', `${base}\u200b`, 'dose.unit_unsupported'],
     ['unicode_bidi_control_suffix', `${base}\u202e`, 'dose.unit_unsupported'],
      ['unicode_letter_confusable_prefix', `${value} ℊmg`, 'dose.unit_missing'],
      ['locale_grouping_comma', `1,${groupedValue} ${unit}`, 'dose.locale_decimal_ambiguous'],
      ['locale_grouping_space', `1 ${groupedValue} ${unit}`, 'dose.multiple_numeric_tokens'],
      ['arabic_decimal_separator', `1\u066b${fraction} ${unit}`, 'dose.multiple_numeric_tokens'],
      ['fullwidth_decimal_separator', `1\uff0e${fraction} ${unit}`, 'dose.multiple_numeric_tokens'],
      ['arabic_indic_digits', `١٢٣ ${unit}`, 'dose.numeric_token_missing'],
      ['oversized_expression', `${base} ${'x '.repeat(130)}`, 'dose.too_long'],
      ['control_character', `${base}\u0000`, 'dose.control_character'],
    ];

    for (const [family, input, reason] of casesForSeed) {
      const id = `seed_${index.toString().padStart(3, '0')}_${family}`;
      const vector = { id, input, status: 'held', reason };
      const reference = inspectReference(input);
      if (reference.status !== 'held' || reference.reason !== reason) {
        throw new Error(
          `Mutation oracle drift for ${id}: expected held/${reason}, ` +
            `got ${reference.status}/${reference.reason}`,
        );
      }
      cases.push(vector);
      families.add(family);
    }
  }

  if (cases.length !== iterations * 28 || families.size !== 28) {
    throw new Error('Seeded mutation corpus did not cover all declared families.');
  }
  return { cases, families: [...families].sort() };
}

const fuzz = generateMutationCases(fuzzSeed, fuzzIterations);
const combinedFixture = { ...fixture, cases: [...fixture.cases, ...fuzz.cases] };
const dart = spawnSync(
  'dart',
  ['--disable-dart-dev', 'tool/run_dose_expression_vectors.dart', '--stdin'],
  {
    encoding: 'utf8',
    input: JSON.stringify(combinedFixture),
    maxBuffer: 8 * 1024 * 1024,
  },
);
if (dart.error || dart.status !== 0) {
  process.stderr.write(dart.stderr || dart.error?.message || 'Dart vector runner failed.\n');
  process.exit(dart.status ?? 1);
}

let dartReport;
try {
  dartReport = JSON.parse(dart.stdout);
} catch (error) {
  console.error(`Dart vector runner returned invalid JSON: ${error.message}`);
  process.exit(1);
}
const dartById = new Map(dartReport.results.map((result) => [result.id, result]));
const failures = [];
for (const vector of combinedFixture.cases) {
  const expected = expectedProjection(vector, dartReport.grammar_digest);
  const jsActual = inspectReference(vector.input, dartReport.grammar_digest);
  const dartActual = dartById.get(vector.id);
  if (!dartActual) {
    failures.push({ id: vector.id, runtime: 'dart', expected, actual: 'missing' });
    continue;
  }
  const dartProjection = {
    status: dartActual.status,
    reason: dartActual.reason,
    value: dartActual.value,
    unit: dartActual.unit,
    dimension: dartActual.dimension,
    diagnostic: dartActual.diagnostic,
    mapping: dartActual.mapping,
  };
  if (JSON.stringify(jsActual) !== JSON.stringify(expected)) {
    failures.push({ id: vector.id, runtime: 'javascript-reference', expected, actual: jsActual });
  }
  if (JSON.stringify(dartProjection) !== JSON.stringify(expected)) {
    failures.push({ id: vector.id, runtime: 'dart-production', expected, actual: dartProjection });
  }
}

const report = {
  report_type: 'parkinsum_dose_expression_grammar_conformance',
  schema: fixture.schema,
  vector_count: combinedFixture.cases.length,
  fixed_vector_count: fixture.cases.length,
  seeded_mutation_count: fuzz.cases.length,
  fuzz_seed: `0x${fuzzSeed.toString(16)}`,
  fuzz_iterations: fuzzIterations,
  mutation_families: fuzz.families,
  diagnostic_projection_count: dartReport.results.filter(
    (result) => result.diagnostic !== null,
  ).length,
  diagnostic_projection_kinds: dartReport.results.reduce((counts, result) => {
    if (result.diagnostic !== null) {
      const { kind } = result.diagnostic;
      counts[kind] = (counts[kind] ?? 0) + 1;
    }
    return counts;
  }, {}),
  fixed_fixture_sha256: sha256(fixtureBytes),
  mutation_corpus_sha256: sha256(JSON.stringify(fuzz.cases)),
  dart_parser_source_sha256: sha256(
    readFileSync('lib/domain/usecases/dosage_note_parser.dart'),
  ),
  local_unit_mapping_source_sha256: sha256(
    readFileSync('lib/domain/entities/versioned_dose_unit_mapping.dart'),
  ),
  javascript_reference_source_sha256: sha256(
    readFileSync('tool/dose_expression_grammar_check.mjs'),
  ),
  runtime_count: 2,
  grammar_id: dartReport.grammar_id,
  grammar_version: dartReport.grammar_version,
  grammar_digest: dartReport.grammar_digest,
  pass: failures.length === 0,
  failures,
  synthetic_only: true,
  boundary:
    'Syntax and versioned exact local unit-mapping conformance only; not UCUM, prescription, dose, administration, or clinical validation.',
};
mkdirSync('build/dose_expression_grammar', { recursive: true });
writeFileSync(
  'build/dose_expression_grammar/latest.json',
  `${JSON.stringify(report, null, 2)}\n`,
);

if (failures.length > 0) {
  console.error(`${failures.length} dose-expression conformance failure(s).`);
  process.exit(1);
}
console.log(
  `Dose-expression grammar: ${fixture.cases.length}/${fixture.cases.length} fixed vectors plus ${fuzz.cases.length}/${fuzz.cases.length} seeded mutations matched in Dart and JavaScript.`,
);
