import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { assertCqfJvmLockfile } from './cqf_jvm_cql_differential.mjs';

const INPUT_PREFIX = 'PARKINSUM_CQF_JVM_TEMPLATE_INPUT';
const META_PREFIX = 'PARKINSUM_CQF_JVM_TEMPLATE_META';
const RESULT_PREFIX = 'PARKINSUM_CQF_JVM_TEMPLATE_RESULT';
export const fixedTemplateOperators = [
  'greater-than',
  'greater-than-or-equal',
  'equal-to',
  'less-than-or-equal',
  'less-than',
];

const encode = (value) => Buffer.from(value, 'utf8').toString('base64');

function decode(value, label) {
  if (typeof value !== 'string' || value.length === 0 || !/^[A-Za-z0-9+/]*={0,2}$/.test(value)) {
    throw new Error(`${label} is not canonical base64`);
  }
  const decoded = Buffer.from(value, 'base64').toString('utf8');
  if (encode(decoded) !== value) throw new Error(`${label} is not canonical UTF-8 base64`);
  return decoded;
}

function literal(value) {
  return `'${value.replaceAll("'", "''")}'`;
}

function expectedCqlSource(template, operator) {
  const cqlOperator = new Map([
    ['greater-than', '>'],
    ['greater-than-or-equal', '>='],
    ['equal-to', '='],
    ['less-than-or-equal', '<='],
    ['less-than', '<'],
  ]).get(operator);
  if (cqlOperator === undefined) throw new Error('CQF JVM CQL template comparator is unsupported');
  return [
    `library ${cqlLibraryName(template.templateId)} version ${literal(template.templateVersion)}`,
    "using FHIR version '4.0.1'",
    `valueset "Template Codes": ${literal(template.valueSet.url)} version ${literal(template.valueSet.version)}`,
    'context Patient',
    `define TemplateResult: Count([Observation: code in "Template Codes"]) ${cqlOperator} ${template.modifier.threshold}`,
    '',
  ].join('\n');
}

function cqlLibraryName(templateId) {
  return templateId.split('-')
    .map((segment) => `${segment[0].toUpperCase()}${segment.slice(1)}`)
    .join('');
}

export function encodeCqfJvmTemplateInputs(template, previews) {
  if (!Array.isArray(previews) || previews.length !== fixedTemplateOperators.length) {
    throw new Error('CQF JVM template comparison requires the five fixed comparator previews');
  }
  if (template?.schemaVersion !== 2 || template?.modifier?.kind !== 'count-comparison' ||
      !Number.isSafeInteger(template.modifier.threshold) || template.modifier.threshold < 0 ||
      template.modifier.threshold > 1_000) {
    throw new Error('CQF JVM template input is outside the versioned count-comparison contract');
  }
  return previews.map((preview, index) => {
    const operator = fixedTemplateOperators[index];
    if (preview?.status !== 'draft-synthetic-checked' ||
        preview.templateIdentity?.id !== template.templateId ||
        preview.templateIdentity?.version !== template.templateVersion ||
        preview.syntheticEvaluation?.status !== 'passed' ||
        preview.generatedCql !== expectedCqlSource(template, operator)) {
      throw new Error(`CQF JVM template preview is not the fixed ${operator} variant`);
    }
    const fields = [
      INPUT_PREFIX,
      encode(template.templateId),
      encode(template.templateVersion),
      encode(template.valueSet.url),
      encode(template.valueSet.version),
      encode(operator),
      String(template.modifier.threshold),
      encode(preview.generatedCql),
    ];
    return `${fields.join('\t')}\n`;
  }).join('');
}

export function parseCqfJvmTemplateOutput(stdout, previews) {
  if (!Array.isArray(previews) || previews.length !== fixedTemplateOperators.length) {
    throw new Error('CQF JVM template output requires the five fixed comparator previews');
  }
  const expectedByKey = new Map();
  const expectedHashes = new Map();
  previews.forEach((preview, index) => {
    const operator = fixedTemplateOperators[index];
    expectedHashes.set(operator, createHash('sha256').update(preview.generatedCql, 'utf8').digest('hex'));
    for (const testCase of preview.syntheticEvaluation?.cases ?? []) {
      const key = `${operator}\0${testCase.caseId}`;
      if (expectedByKey.has(key)) throw new Error('CQF JVM template previews contain duplicate fixed case identities');
      expectedByKey.set(key, testCase);
    }
  });
  if (expectedByKey.size === 0) throw new Error('CQF JVM template comparison contains no synthetic cases');

  const meta = new Map();
  const results = new Map();
  for (const line of String(stdout).split(/\r?\n/)) {
    if (line.startsWith(`${META_PREFIX}\t`)) {
      const fields = line.split('\t');
      if (fields.length !== 4 || fields[0] !== META_PREFIX) throw new Error('CQF JVM template metadata row is malformed');
      const operator = decode(fields[1], 'CQF JVM template comparator');
      if (!fixedTemplateOperators.includes(operator) || meta.has(operator) ||
          !/^[a-f0-9]{64}$/.test(fields[2]) || fields[3] !== '4.0.1') {
        throw new Error('CQF JVM template metadata has an unexpected identity or version');
      }
      meta.set(operator, { cqlSourceSha256: fields[2], fhirVersion: fields[3] });
      continue;
    }
    if (!line.startsWith(`${RESULT_PREFIX}\t`)) continue;
    const fields = line.split('\t');
    if (fields.length !== 8 || fields[0] !== RESULT_PREFIX) throw new Error('CQF JVM template result row is malformed');
    const operator = decode(fields[1], 'CQF JVM template comparator');
    const caseId = decode(fields[2], 'CQF JVM template case ID');
    const key = `${operator}\0${caseId}`;
    if (!expectedByKey.has(key) || results.has(key) || !fixedTemplateOperators.includes(operator)) {
      throw new Error('CQF JVM template output contains an unexpected or duplicate fixed case');
    }
    const countFields = fields.slice(3, 6).concat(fields[7]);
    if (countFields.some((value) => !/^(0|[1-9][0-9]{0,3})$/.test(value)) ||
        !['true', 'false'].includes(fields[6])) {
      throw new Error(`CQF JVM template output contains invalid bounded values for ${caseId}`);
    }
    const [inputObservationCount, patientScopedObservationCount, valueSetObservationCount, foreignObservationsDropped] =
      countFields.map(Number);
    if (inputObservationCount > 1_001 || patientScopedObservationCount > inputObservationCount ||
        valueSetObservationCount > patientScopedObservationCount || foreignObservationsDropped > inputObservationCount) {
      throw new Error(`CQF JVM template output exceeds fixed observation bounds for ${caseId}`);
    }
    results.set(key, {
      operator,
      caseId,
      inputObservationCount,
      patientScopedObservationCount,
      valueSetObservationCount,
      result: fields[6] === 'true',
      foreignObservationsDropped,
    });
  }
  if (meta.size !== fixedTemplateOperators.length || results.size !== expectedByKey.size) {
    throw new Error(`CQF JVM template returned ${results.size} of ${expectedByKey.size} cases and ${meta.size} metadata rows`);
  }
  for (const operator of fixedTemplateOperators) {
    if (meta.get(operator)?.cqlSourceSha256 !== expectedHashes.get(operator)) {
      throw new Error(`CQF JVM template source digest differs from the ${operator} CQL input`);
    }
  }
  return { meta, results, expectedByKey };
}

export function runCqfJvmTemplateDifferential(root, template, previews) {
  const input = encodeCqfJvmTemplateInputs(template, previews);
  const projectPath = resolve(root, 'tool/cqf_jvm_cql_differential');
  assertCqfJvmLockfile(readFileSync(resolve(projectPath, 'gradle.lockfile'), 'utf8'));
  const wrapper = process.env.PARKINSUM_CQF_JVM_GRADLE_BIN
    || resolve(root, 'android', process.platform === 'win32' ? 'gradlew.bat' : 'gradlew');
  const result = spawnSync(wrapper, ['--no-daemon', '--offline', '-p', projectPath, '--quiet', 'cqlTemplateRun'], {
    cwd: root,
    encoding: 'utf8',
    input,
    maxBuffer: 4 * 1024 * 1024,
    shell: process.platform === 'win32',
    timeout: 300_000,
    env: {
      ...process.env,
      JAVA_HOME: process.env.JAVA_HOME || '/Applications/Android Studio.app/Contents/jbr/Contents/Home',
    },
  });
  if (result.error?.code === 'ENOENT') throw new Error('The Android Gradle wrapper is required for the CQF JVM CQL template comparison.');
  if (result.error?.code === 'ETIMEDOUT') throw new Error('The CQF JVM CQL template run exceeded five minutes.');
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`CQF JVM CQL template differential failed (${result.status}):\n${result.stderr || result.stdout}`);
  }

  const parsed = parseCqfJvmTemplateOutput(result.stdout, previews);
  const cases = [];
  for (const [index, preview] of previews.entries()) {
    const operator = fixedTemplateOperators[index];
    const sourceSha256 = createHash('sha256').update(preview.generatedCql, 'utf8').digest('hex');
    if (parsed.meta.get(operator).cqlSourceSha256 !== sourceSha256) {
      throw new Error(`CQF JVM translated a different CQL source for ${operator}`);
    }
    for (const jsCase of preview.syntheticEvaluation.cases) {
      const jvm = parsed.results.get(`${operator}\0${jsCase.caseId}`);
      if (jvm.inputObservationCount !== jsCase.inputObservationCount ||
          jvm.patientScopedObservationCount !== jsCase.patientScopedObservationCount ||
          jvm.valueSetObservationCount !== jsCase.valueSetObservationCount ||
          jvm.foreignObservationsDropped !== jsCase.foreignObservationsDropped ||
          jvm.result !== jsCase.result || !jsCase.outcomeMatched) {
        throw new Error(`CQF JavaScript and JVM template results differ for ${operator}/${jsCase.caseId}`);
      }
      cases.push({
        operator,
        caseId: jsCase.caseId,
        inputObservationCount: jsCase.inputObservationCount,
        patientScopedObservationCount: jsCase.patientScopedObservationCount,
        valueSetObservationCount: jsCase.valueSetObservationCount,
        javaScriptResult: jsCase.result,
        cqfJvmResult: jvm.result,
        outcomeMatched: true,
        foreignObservationsDropped: jvm.foreignObservationsDropped,
      });
    }
  }
  return {
    schemaVersion: 1,
    scope: 'synthetic-fhir-r4-cql-template-javascript-jvm-differential',
    templateIdentity: { id: template.templateId, version: template.templateVersion },
    fhirVersion: '4.0.1',
    javascriptEngine: 'cql-execution@3.3.2 + cql-exec-fhir@2.1.6',
    cqfJvmEngine: 'org.cqframework:engine@5.3.0 + engine-fhir@5.3.0 + cql-to-elm-jvm@5.3.0',
    comparatorCount: fixedTemplateOperators.length,
    caseCount: cases.length,
    outcomeParityCount: cases.filter(({ outcomeMatched }) => outcomeMatched).length,
    cqlSourceSha256ByOperator: Object.fromEntries(fixedTemplateOperators.map((operator) => [
      operator,
      createHash('sha256').update(previews[fixedTemplateOperators.indexOf(operator)].generatedCql, 'utf8').digest('hex'),
    ])),
    cases,
    networkRequestMade: false,
    realPatientDataUsed: false,
  };
}

function templatePathFromArgs(argv) {
  if (argv.length === 0) return 'test/fixtures/cql_concept_template_v2.synthetic.json';
  if (argv.length !== 2 || argv[0] !== '--template') throw new Error('Usage: node tool/cqf_jvm_cql_template_differential.mjs [--template path]');
  return resolve(argv[1]);
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url))) {
  const root = resolve('.');
  const template = JSON.parse(readFileSync(templatePathFromArgs(process.argv.slice(2)), 'utf8'));
  const { buildCqlConceptTemplatePreview } = await import('./cql_concept_template_preview.mjs');
  const previews = [];
  for (const operator of fixedTemplateOperators) {
    previews.push(await buildCqlConceptTemplatePreview({
      ...template,
      modifier: { ...template.modifier, operator },
    }));
  }
  const report = runCqfJvmTemplateDifferential(root, template, previews);
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
}
