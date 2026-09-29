import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import { buildCqlConceptTemplatePreview } from './cql_concept_template_preview.mjs';
import { assertCqfJvmLockfile } from './cqf_jvm_cql_differential.mjs';
import {
  encodeCqfJvmTemplateInputs,
  fixedTemplateOperators,
  parseCqfJvmTemplateOutput,
} from './cqf_jvm_cql_template_differential.mjs';

const template = JSON.parse(readFileSync(
  new URL('../test/fixtures/cql_concept_template_v2.synthetic.json', import.meta.url),
  'utf8',
));
const encode = (value) => Buffer.from(value, 'utf8').toString('base64');

async function buildPreviews() {
  const previews = [];
  for (const operator of fixedTemplateOperators) {
    previews.push(await buildCqlConceptTemplatePreview({
      ...template,
      modifier: { ...template.modifier, operator },
    }));
  }
  return previews;
}

function fixedOutput(previews) {
  const metadata = previews.map((preview, index) => [
    'PARKINSUM_CQF_JVM_TEMPLATE_META',
    encode(fixedTemplateOperators[index]),
    createHash('sha256').update(preview.generatedCql, 'utf8').digest('hex'),
    '4.0.1',
  ].join('\t'));
  const rows = previews.flatMap((preview, index) => preview.syntheticEvaluation.cases.map((testCase) => [
    'PARKINSUM_CQF_JVM_TEMPLATE_RESULT',
    encode(fixedTemplateOperators[index]),
    encode(testCase.caseId),
    testCase.inputObservationCount,
    testCase.patientScopedObservationCount,
    testCase.valueSetObservationCount,
    testCase.result,
    testCase.foreignObservationsDropped,
  ].join('\t')));
  return [...metadata, ...rows].join('\n');
}

test('CQF JVM input binds exactly five generated comparator sources to one template', async () => {
  const previews = await buildPreviews();
  const input = encodeCqfJvmTemplateInputs(template, previews);
  const lines = input.trimEnd().split('\n');
  assert.equal(lines.length, 5);
  assert.deepEqual(lines.map((line) => line.split('\t').slice(0, 6).map((field, index) => (
    index === 0 || index === 6 ? field : Buffer.from(field, 'base64').toString('utf8')
  ))), fixedTemplateOperators.map((operator) => [
    'PARKINSUM_CQF_JVM_TEMPLATE_INPUT',
    template.templateId,
    template.templateVersion,
    template.valueSet.url,
    template.valueSet.version,
    operator,
  ]));
  const changed = structuredClone(previews);
  changed[2].generatedCql += 'define Unreviewed: true\n';
  assert.throws(() => encodeCqfJvmTemplateInputs(template, changed), /fixed equal-to variant/);
});

test('CQF JVM output parser requires source digests and every fixed case for each comparator', async () => {
  const previews = await buildPreviews();
  const parsed = parseCqfJvmTemplateOutput(fixedOutput(previews), previews);
  assert.equal(parsed.meta.size, 5);
  assert.equal(parsed.results.size, 30);
  for (const operator of fixedTemplateOperators) {
    assert.equal(parsed.meta.get(operator).fhirVersion, '4.0.1');
    for (const testCase of previews[fixedTemplateOperators.indexOf(operator)].syntheticEvaluation.cases) {
      const result = parsed.results.get(`${operator}\0${testCase.caseId}`);
      assert.equal(result.result, testCase.result);
      assert.equal(result.valueSetObservationCount, testCase.valueSetObservationCount);
      assert.equal(result.foreignObservationsDropped, testCase.foreignObservationsDropped);
    }
  }
  assert.throws(() => parseCqfJvmTemplateOutput(fixedOutput(previews).replace(/(PARKINSUM_CQF_JVM_TEMPLATE_META\t[^\t]+\t)[a-f0-9]{64}/, '$1' + '0'.repeat(64)), previews), /source digest/);
  assert.throws(() => parseCqfJvmTemplateOutput(fixedOutput(previews).split('\n').slice(1).join('\n'), previews), /metadata rows/);
  assert.throws(() => parseCqfJvmTemplateOutput(`${fixedOutput(previews)}\n${fixedOutput(previews).split('\n').at(-1)}`, previews), /duplicate/);
});

test('CQF JVM template differential uses only the repository-pinned engine modules', () => {
  const lock = readFileSync(new URL('./cqf_jvm_cql_differential/gradle.lockfile', import.meta.url), 'utf8');
  assert.equal(assertCqfJvmLockfile(lock).length, 7);
});
