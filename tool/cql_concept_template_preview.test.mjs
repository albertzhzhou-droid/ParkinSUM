import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import { buildCqlConceptTemplatePreview } from './cql_concept_template_preview.mjs';

const fixture = JSON.parse(readFileSync(
  new URL('../test/fixtures/cql_concept_template_v2.synthetic.json', import.meta.url),
  'utf8',
));

test('generates a versioned CQL Library draft and executes its typed count cases', async () => {
  const preview = await buildCqlConceptTemplatePreview(fixture);
  assert.equal(preview.schema, 'parkinsum.cql-concept-template-draft/2');
  assert.equal(preview.status, 'draft-synthetic-checked');
  assert.deepEqual(preview.translationWarnings, [
    'value_set_membership_not_resolved_without_terminology_provider',
  ]);
  assert.deepEqual(preview.templateIdentity, {
    id: 'synthetic-observation-count',
    version: '1.0.0',
  });
  assert.match(preview.generatedCql, /^library SyntheticObservationCount version '1\.0\.0'/);
  assert.match(preview.generatedCql, /Count\(\[Observation: code in "Template Codes"\]\) >= 2/);
  assert.equal(preview.libraryDraft.resourceType, 'Library');
  assert.equal(preview.libraryDraft.status, 'draft');
  assert.equal(preview.libraryDraft.experimental, true);
  assert.equal(preview.libraryDraft.version, '1.0.0');
  assert.equal(preview.libraryDraft.name, 'SyntheticObservationCount');
  assert.equal(
    preview.libraryDraft.url,
    'https://example.org/fhir/Library/SyntheticObservationCount',
  );
  assert.ok(!preview.libraryDraft.name.includes('_'));
  assert.ok(preview.libraryDraft.name.length <= 64);
  assert.deepEqual(preview.libraryDraft.parameter, [{
    name: 'TemplateResult',
    use: 'out',
    min: 0,
    max: '1',
    type: { code: 'boolean' },
  }]);
  assert.deepEqual(preview.libraryDraft.relatedArtifact, [
    {
      type: 'depends-on',
      resource: 'http://hl7.org/fhir/Library/FHIR-ModelInfo|4.0.1',
    },
    {
      type: 'depends-on',
      resource: 'https://example.org/fhir/ValueSet/SyntheticObservationCodes|2026-09',
    },
  ]);
  assert.deepEqual(preview.libraryDraft.dataRequirement, [
    {
      type: 'Patient',
      profile: ['http://hl7.org/fhir/StructureDefinition/Patient'],
      subjectCodeableConcept: {
        coding: [{
          system: 'http://hl7.org/fhir/resource-types',
          code: 'Patient',
          display: 'Patient',
        }],
      },
    },
    {
      type: 'Observation',
      profile: ['http://hl7.org/fhir/StructureDefinition/Observation'],
      subjectCodeableConcept: {
        coding: [{
          system: 'http://hl7.org/fhir/resource-types',
          code: 'Patient',
          display: 'Patient',
        }],
      },
      mustSupport: ['code', 'subject'],
      codeFilter: [{
        path: 'code',
        valueSet: 'https://example.org/fhir/ValueSet/SyntheticObservationCodes|2026-09',
      }],
    },
  ]);
  assert.equal(
    Buffer.from(preview.libraryDraft.content[0].data, 'base64').toString('utf8'),
    preview.generatedCql,
  );
  assert.deepEqual(preview.syntheticEvaluation, {
    status: 'passed',
    engine: 'cql-execution@3.3.2 + cql-exec-fhir@2.1.6',
    expansionSource: 'fixed-in-memory-synthetic-valueset',
    patientScope: 'only observations referencing the synthetic Patient are evaluated',
    caseCount: 6,
    outcomeMatchCount: 6,
    cases: [
      ['count-0', 0, 0, false, 0],
      ['count-1', 1, 1, false, 0],
      ['count-2', 2, 2, true, 0],
      ['count-3', 3, 3, true, 0],
      ['non-member-code', 1, 0, false, 0],
      ['foreign-subject', 1, 0, false, 1],
    ].map(([caseId, inputObservationCount, valueSetObservationCount, result, foreignObservationsDropped]) => ({
      caseId,
      inputObservationCount,
      patientScopedObservationCount: caseId === 'foreign-subject' ? 0 : inputObservationCount,
      valueSetObservationCount,
      expectedResult: result,
      result,
      outcomeMatched: true,
      foreignObservationsDropped,
    })),
    networkRequestMade: false,
    realPatientDataUsed: false,
  });
  assert.deepEqual(preview.boundaries, {
    templateKind: 'FHIR R4 Patient-scoped Observation ValueSet count comparison',
    cqlTranslatedToElm: true,
    cqlEvaluatedAgainstSyntheticCasesOnly: true,
    syntheticCaseCount: 6,
    fhirValidatorRun: false,
    terminologyResolved: false,
    fhirEndpointCalled: false,
    realPatientDataRead: false,
    runtimeRuleCreated: false,
    clinicalValidityClaim: false,
  });
});

test('supports each comparator and checks its below, at, above, and exclusion outcomes', async () => {
  const cases = [
    ['greater-than', ' > 2'],
    ['greater-than-or-equal', ' >= 2'],
    ['equal-to', ' = 2'],
    ['less-than-or-equal', ' <= 2'],
    ['less-than', ' < 2'],
  ];
  const expectedResults = {
    'greater-than': [false, false, false, true, false, false],
    'greater-than-or-equal': [false, false, true, true, false, false],
    'equal-to': [false, false, true, false, false, false],
    'less-than-or-equal': [true, true, true, false, true, true],
    'less-than': [true, true, false, false, true, true],
  };
  for (const [operator, expected] of cases) {
    const preview = await buildCqlConceptTemplatePreview({
      ...fixture,
      modifier: { ...fixture.modifier, operator },
    });
    assert.ok(preview.generatedCql.includes(expected), `${operator} should be emitted explicitly`);
    assert.deepEqual(
      preview.syntheticEvaluation.cases.map((testCase) => testCase.result),
      expectedResults[operator],
      `${operator} should execute with the expected boundary outcomes`,
    );
  }
});

test('threshold zero is executable and remains a count comparison', async () => {
  const preview = await buildCqlConceptTemplatePreview({
    ...fixture,
    modifier: { ...fixture.modifier, threshold: 0 },
  });
  assert.deepEqual(
    preview.syntheticEvaluation.cases.map((testCase) => testCase.result),
    [true, true, true, true],
  );
});

test('maximum supported threshold keeps generated patient data bounded', async () => {
  const preview = await buildCqlConceptTemplatePreview({
    ...fixture,
    modifier: { ...fixture.modifier, threshold: 1000 },
  });
  const exact = preview.syntheticEvaluation.cases.find(
    (testCase) => testCase.caseId === 'count-1000',
  );
  const above = preview.syntheticEvaluation.cases.find(
    (testCase) => testCase.caseId === 'count-1001',
  );
  assert.ok(preview.syntheticEvaluation.caseCount <= 6);
  assert.equal(exact?.result, true);
  assert.equal(above?.result, true);
  assert.equal(above?.patientScopedObservationCount, 1001);
});

test('rejects unsupported schema, resource concepts, modifiers, operators, and unsafe ValueSet identities', async () => {
  const invalid = [
    [{ ...fixture, schemaVersion: 1 }, /cql_template_schema_version_unsupported/],
    [{ ...fixture, unexpected: true }, /cql_template_shape_invalid/],
    [{ ...fixture, templateId: 'bad id' }, /cql_template_id_invalid/],
    [{ ...fixture, templateId: 'bad--id' }, /cql_template_id_invalid/],
    [{ ...fixture, templateId: 'bad-' }, /cql_template_id_invalid/],
    [{ ...fixture, templateVersion: '1.0' }, /cql_template_version_invalid/],
    [{ ...fixture, valueSet: { ...fixture.valueSet, version: 'release 2026-09' } }, /cql_template_value_set_version_invalid/],
    [{ ...fixture, valueSet: { ...fixture.valueSet, url: "https://example.org/x'\ndefine Evil: true" } }, /cql_template_value_set_url_invalid/],
    [{ ...fixture, modifier: { ...fixture.modifier, kind: 'latest-by-effective' } }, /cql_template_modifier_unsupported/],
    [{ ...fixture, modifier: { ...fixture.modifier, operator: 'approximately' } }, /cql_template_comparison_operator_unsupported/],
    [{ ...fixture, modifier: { ...fixture.modifier, threshold: 2.5 } }, /cql_template_count_threshold_invalid/],
  ];
  for (const [template, error] of invalid) {
    await assert.rejects(buildCqlConceptTemplatePreview(template), error);
  }
});

test('emits byte-stable CQL, Library drafts, and case results for the same template version', async () => {
  const first = await buildCqlConceptTemplatePreview(fixture);
  const second = await buildCqlConceptTemplatePreview(structuredClone(fixture));
  assert.equal(first.generatedCql, second.generatedCql);
  assert.deepEqual(first.libraryDraft, second.libraryDraft);
  assert.deepEqual(first.syntheticEvaluation, second.syntheticEvaluation);
});
