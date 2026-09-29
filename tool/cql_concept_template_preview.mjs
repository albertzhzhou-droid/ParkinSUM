#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

import {
  CqlTranslator,
  LibraryManager,
  ModelManager,
  createModelInfoProvider,
  stringAsSource,
} from '@cqframework/cql/cql-to-elm';
import { SystemModelInfoProvider } from '@cqframework/cql/cql';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const require = createRequire(import.meta.url);
const CqlExecution = require('cql-execution');
const CqlExecFhir = require('cql-exec-fhir');
const defaultTemplatePath = path.join(root, 'test/fixtures/cql_concept_template_v2.synthetic.json');
const modelInfoPath = path.join(root, 'node_modules/cql-exec-fhir/lib/modelInfos/fhir-modelinfo-4.0.1.xml');
const schemaUri = 'parkinsum.cql-concept-template-draft/2';
const cqlVersion = '5.3.0';
const fhirModelVersion = '2.1.6';
const fhirVersion = '4.0.1';
const fhirModelCanonical = `http://hl7.org/fhir/Library/FHIR-ModelInfo|${fhirVersion}`;
const cqlNamespaceUrl = 'https://example.org/fhir';
const observationProfile = 'http://hl7.org/fhir/StructureDefinition/Observation';
const patientProfile = 'http://hl7.org/fhir/StructureDefinition/Patient';
const patientSubjectType = {
  coding: [{
    system: 'http://hl7.org/fhir/resource-types',
    code: 'Patient',
    display: 'Patient',
  }],
};
const comparisonOperators = new Map([
  ['greater-than', { cql: '>', elm: 'Greater', compare: (value, bound) => value > bound }],
  ['greater-than-or-equal', { cql: '>=', elm: 'GreaterOrEqual', compare: (value, bound) => value >= bound }],
  ['equal-to', { cql: '=', elm: 'Equal', compare: (value, bound) => value === bound }],
  ['less-than-or-equal', { cql: '<=', elm: 'LessOrEqual', compare: (value, bound) => value <= bound }],
  ['less-than', { cql: '<', elm: 'Less', compare: (value, bound) => value < bound }],
]);
const expectedUnresolvedTerminologyWarning = 'CqlSemanticException: Could not resolve membership operator for terminology target of the retrieve.';

function requireContract(condition, code) {
  if (!condition) throw new Error(code);
}

function exactKeys(value, keys) {
  return value !== null
    && typeof value === 'object'
    && !Array.isArray(value)
    && Object.keys(value).sort().join('\0') === [...keys].sort().join('\0');
}

function validateTemplate(template) {
  requireContract(exactKeys(template, [
    'schemaVersion', 'templateId', 'templateVersion', 'valueSet', 'modifier',
  ]), 'cql_template_shape_invalid');
  requireContract(template.schemaVersion === 2, 'cql_template_schema_version_unsupported');
  requireContract(
    typeof template.templateId === 'string'
      && template.templateId.length >= 3
      && template.templateId.length <= 63
      && /^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/.test(template.templateId),
    'cql_template_id_invalid',
  );
  requireContract(
    typeof template.templateVersion === 'string'
      && /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/.test(template.templateVersion),
    'cql_template_version_invalid',
  );
  requireContract(exactKeys(template.valueSet, ['url', 'version']), 'cql_template_value_set_shape_invalid');
  requireContract(
    typeof template.valueSet.url === 'string'
      && /^https:\/\/[A-Za-z0-9.-]+(?:\/[A-Za-z0-9._~/-]*)?$/.test(template.valueSet.url),
    'cql_template_value_set_url_invalid',
  );
  requireContract(
    typeof template.valueSet.version === 'string'
      && /^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$/.test(template.valueSet.version),
    'cql_template_value_set_version_invalid',
  );
  requireContract(
    exactKeys(template.modifier, ['kind', 'operator', 'threshold'])
      && template.modifier.kind === 'count-comparison',
    'cql_template_modifier_unsupported',
  );
  requireContract(comparisonOperators.has(template.modifier.operator), 'cql_template_comparison_operator_unsupported');
  requireContract(
    Number.isSafeInteger(template.modifier.threshold)
      && template.modifier.threshold >= 0
      && template.modifier.threshold <= 1000,
    'cql_template_count_threshold_invalid',
  );
  return template;
}

function cqlStringLiteral(value) {
  return `'${value.replaceAll("'", "''")}'`;
}

function cqlLibraryName(templateId) {
  return templateId.split('-')
    .map((segment) => `${segment[0].toUpperCase()}${segment.slice(1)}`)
    .join('');
}

function buildCqlSource(template) {
  const libraryName = cqlLibraryName(template.templateId);
  const operator = comparisonOperators.get(template.modifier.operator);
  return [
    `library ${libraryName} version ${cqlStringLiteral(template.templateVersion)}`,
    `using FHIR version ${cqlStringLiteral(fhirVersion)}`,
    `valueset "Template Codes": ${cqlStringLiteral(template.valueSet.url)} version ${cqlStringLiteral(template.valueSet.version)}`,
    'context Patient',
    `define TemplateResult: Count([Observation: code in "Template Codes"]) ${operator.cql} ${template.modifier.threshold}`,
    '',
  ].join('\n');
}

function buildDataRequirements(template) {
  return [
    {
      type: 'Patient',
      profile: [patientProfile],
      subjectCodeableConcept: structuredClone(patientSubjectType),
    },
    {
      type: 'Observation',
      profile: [observationProfile],
      subjectCodeableConcept: structuredClone(patientSubjectType),
      mustSupport: ['code', 'subject'],
      codeFilter: [{
        path: 'code',
        valueSet: `${template.valueSet.url}|${template.valueSet.version}`,
      }],
    },
  ];
}

function compileCql(cqlSource) {
  const packageJson = JSON.parse(readFileSync(path.join(root, 'package.json'), 'utf8'));
  requireContract(packageJson.devDependencies?.['@cqframework/cql'] === cqlVersion, 'unreviewed_cqf_cql_dependency_version');
  requireContract(packageJson.devDependencies?.['cql-exec-fhir'] === fhirModelVersion, 'unreviewed_fhir_model_dependency_version');

  const modelInfoXml = readFileSync(modelInfoPath, 'utf8');
  const modelManager = new ModelManager();
  modelManager.modelInfoLoader.registerModelInfoProvider(new SystemModelInfoProvider());
  modelManager.modelInfoLoader.registerModelInfoProvider(createModelInfoProvider((name, namespace, version) => (
    name === 'FHIR' && version === fhirVersion ? stringAsSource(modelInfoXml) : null
  )));
  const translator = CqlTranslator.fromText(cqlSource, new LibraryManager(modelManager));
  const errors = translator.errors.asJsReadonlyArrayView();
  const warnings = translator.warnings.asJsReadonlyArrayView();
  requireContract(errors.length === 0 && translator.toELM() !== null, 'cql_template_translation_failed');
  requireContract(
    warnings.length === 1 && String(warnings[0]) === expectedUnresolvedTerminologyWarning,
    'cql_template_translation_warning_unreviewed',
  );
  return {
    elm: JSON.parse(translator.toJson()),
  };
}

function collectRetrieves(value, output = []) {
  if (value === null || typeof value !== 'object') return output;
  if (value.type === 'Retrieve') output.push(value);
  for (const child of Object.values(value)) {
    if (Array.isArray(child)) child.forEach((item) => collectRetrieves(item, output));
    else collectRetrieves(child, output);
  }
  return output;
}

function validateCompiledElm(elm, template) {
  const library = elm.library;
  const expectedLibraryName = cqlLibraryName(template.templateId);
  requireContract(library?.identifier?.id === expectedLibraryName, 'cql_template_elm_library_identity_mismatch');
  requireContract(library.identifier.version === template.templateVersion, 'cql_template_elm_library_version_mismatch');
  requireContract(
    library.statements?.def?.length === 2
      && library.statements.def[0]?.name === 'Patient'
      && library.statements.def[0]?.expression?.type === 'SingletonFrom'
      && library.statements.def[1]?.name === 'TemplateResult',
    'cql_template_elm_top_level_definition_set_mismatch',
  );
  const result = library.statements?.def?.find((statement) => statement.name === 'TemplateResult');
  const operator = comparisonOperators.get(template.modifier.operator);
  requireContract(result?.context === 'Patient', 'cql_template_elm_context_mismatch');
  requireContract(result?.expression?.type === operator.elm, 'cql_template_elm_comparator_mismatch');
  const operands = result.expression.operand;
  requireContract(
    Array.isArray(operands)
      && operands.length === 2
      && operands[0]?.type === 'Count'
      && operands[1]?.type === 'Literal'
      && operands[1]?.value === String(template.modifier.threshold),
    'cql_template_elm_count_expression_mismatch',
  );
  const valueSet = library.valueSets?.def?.find((definition) => definition.name === 'Template Codes');
  requireContract(
    valueSet?.id === template.valueSet.url && valueSet?.version === template.valueSet.version,
    'cql_template_elm_value_set_binding_mismatch',
  );
  const retrieves = collectRetrieves(result.expression);
  requireContract(
    retrieves.length === 1
      && retrieves[0].dataType === '{http://hl7.org/fhir}Observation'
      && retrieves[0].templateId === observationProfile
      && retrieves[0].codeProperty === 'code'
      && retrieves[0].codeComparator === 'in'
      && retrieves[0].codes?.name === 'Template Codes',
    'cql_template_elm_data_retrieval_mismatch',
  );
}

function syntheticObservation(patientId, observationId, code) {
  return {
    resourceType: 'Observation',
    id: observationId,
    status: 'final',
    code: {
      coding: [{
        system: 'urn:parkinsum:synthetic-template-test',
        version: 'v1',
        code,
      }],
    },
    subject: { reference: `Patient/${patientId}` },
  };
}

function syntheticEvaluationCases(template) {
  const counts = new Set([0, template.modifier.threshold, template.modifier.threshold + 1]);
  if (template.modifier.threshold > 0) counts.add(template.modifier.threshold - 1);
  const numericCases = [...counts]
    .sort((left, right) => left - right)
    .map((count) => {
      const id = `count-${count}`;
      const patientId = `synthetic-patient-${id}`;
      return {
        id,
        expectedCount: count,
        inputObservationCount: count,
        bundle: {
          resourceType: 'Bundle',
          type: 'collection',
          entry: [
            { resource: { resourceType: 'Patient', id: patientId } },
            ...Array.from({ length: count }, (_, index) => ({
              resource: syntheticObservation(
                patientId,
                `synthetic-observation-${index + 1}`,
                'template-code-in-set',
              ),
            })),
          ],
        },
      };
    });
  const nonMemberPatientId = 'synthetic-patient-non-member';
  const foreignPatientId = 'synthetic-patient-foreign-observation';
  return [
    ...numericCases,
    {
      id: 'non-member-code',
      expectedCount: 0,
      inputObservationCount: 1,
      bundle: {
        resourceType: 'Bundle',
        type: 'collection',
        entry: [
          { resource: { resourceType: 'Patient', id: nonMemberPatientId } },
          {
            resource: syntheticObservation(
              nonMemberPatientId,
              'synthetic-observation-non-member',
              'template-code-outside-set',
            ),
          },
        ],
      },
    },
    {
      id: 'foreign-subject',
      expectedCount: 0,
      inputObservationCount: 1,
      bundle: {
        resourceType: 'Bundle',
        type: 'collection',
        entry: [
          { resource: { resourceType: 'Patient', id: foreignPatientId } },
          {
            resource: {
              ...syntheticObservation(
                'synthetic-patient-outside-context',
                'synthetic-observation-foreign',
                'template-code-in-set',
              ),
            },
          },
        ],
      },
    },
  ];
}

function scopeSyntheticBundle(bundle, patientId, caseId) {
  requireContract(
    bundle?.resourceType === 'Bundle'
      && bundle.type === 'collection'
      && Array.isArray(bundle.entry),
    `cql_template_synthetic_bundle_invalid:${caseId}`,
  );
  const patients = bundle.entry
    .map((entry) => entry?.resource)
    .filter((resource) => resource?.resourceType === 'Patient');
  requireContract(
    patients.length === 1 && patients[0].id === patientId,
    `cql_template_synthetic_patient_context_invalid:${caseId}`,
  );
  const scopedEntries = [{ resource: patients[0] }];
  let foreignObservationsDropped = 0;
  for (const entry of bundle.entry) {
    const resource = entry?.resource;
    if (resource?.resourceType === 'Patient') continue;
    requireContract(
      resource?.resourceType === 'Observation'
        && typeof resource.id === 'string'
        && resource.subject?.reference?.startsWith('Patient/'),
      `cql_template_synthetic_observation_invalid:${caseId}`,
    );
    if (resource.subject.reference === `Patient/${patientId}`) {
      scopedEntries.push(entry);
    } else {
      foreignObservationsDropped++;
    }
  }
  return {
    bundle: { ...bundle, entry: scopedEntries },
    foreignObservationsDropped,
    patientScopedObservationCount: scopedEntries.length - 1,
  };
}

async function evaluateSyntheticTemplate(elm, template) {
  const packageJson = JSON.parse(readFileSync(path.join(root, 'package.json'), 'utf8'));
  requireContract(
    packageJson.devDependencies?.['cql-execution'] === '3.3.2'
      && packageJson.devDependencies?.['cql-exec-fhir'] === fhirModelVersion,
    'unreviewed_cql_execution_dependency_version',
  );
  const codeService = new CqlExecution.CodeService({
    [template.valueSet.url]: {
      [template.valueSet.version]: [{
        code: 'template-code-in-set',
        system: 'urn:parkinsum:synthetic-template-test',
        version: 'v1',
      }],
    },
  });
  const executor = new CqlExecution.Executor(
    new CqlExecution.Library(elm),
    codeService,
  );
  const compare = comparisonOperators.get(template.modifier.operator).compare;
  const cases = [];
  for (const testCase of syntheticEvaluationCases(template)) {
    const patientId = testCase.bundle.entry
      .map((entry) => entry.resource)
      .find((resource) => resource.resourceType === 'Patient')?.id;
    const scoped = scopeSyntheticBundle(testCase.bundle, patientId, testCase.id);
    const patientSource = CqlExecFhir.PatientSource.FHIRv401();
    requireContract(
      patientSource.version === fhirVersion,
      'unreviewed_cql_fhir_patient_source_version',
    );
    patientSource.loadBundles([scoped.bundle]);
    const evaluation = await executor.exec(patientSource);
    const results = Object.values(evaluation.patientResults ?? {});
    requireContract(
      results.length === 1 && typeof results[0]?.TemplateResult === 'boolean',
      `cql_template_synthetic_result_shape_invalid:${testCase.id}`,
    );
    const result = results[0].TemplateResult;
    const expectedResult = compare(testCase.expectedCount, template.modifier.threshold);
    requireContract(
      result === expectedResult,
      `cql_template_synthetic_outcome_mismatch:${testCase.id}`,
    );
    cases.push({
      caseId: testCase.id,
      inputObservationCount: testCase.inputObservationCount,
      patientScopedObservationCount: scoped.patientScopedObservationCount,
      valueSetObservationCount: testCase.expectedCount,
      expectedResult,
      result,
      outcomeMatched: result === expectedResult,
      foreignObservationsDropped: scoped.foreignObservationsDropped,
    });
  }
  return {
    status: 'passed',
    engine: `cql-execution@${packageJson.devDependencies['cql-execution']} + cql-exec-fhir@${fhirModelVersion}`,
    expansionSource: 'fixed-in-memory-synthetic-valueset',
    patientScope: 'only observations referencing the synthetic Patient are evaluated',
    caseCount: cases.length,
    outcomeMatchCount: cases.filter((testCase) => testCase.outcomeMatched).length,
    cases,
    networkRequestMade: false,
    realPatientDataUsed: false,
  };
}

function buildDraftLibrary(template, cqlSource) {
  const libraryName = cqlLibraryName(template.templateId);
  const canonical = `${cqlNamespaceUrl}/Library/${libraryName}`;
  return {
    resourceType: 'Library',
    id: template.templateId,
    url: canonical,
    version: template.templateVersion,
    name: libraryName,
    status: 'draft',
    experimental: true,
    type: {
      coding: [{
        system: 'http://terminology.hl7.org/CodeSystem/library-type',
        code: 'logic-library',
      }],
    },
    parameter: [{
      name: 'TemplateResult',
      use: 'out',
      min: 0,
      max: '1',
      type: { code: 'boolean' },
    }],
    relatedArtifact: [
      { type: 'depends-on', resource: fhirModelCanonical },
      { type: 'depends-on', resource: `${template.valueSet.url}|${template.valueSet.version}` },
    ],
    dataRequirement: buildDataRequirements(template),
    content: [{
      contentType: 'text/cql',
      data: Buffer.from(cqlSource, 'utf8').toString('base64'),
    }],
  };
}

export async function buildCqlConceptTemplatePreview(templateInput) {
  const template = validateTemplate(templateInput);
  const cqlSource = buildCqlSource(template);
  const compilation = compileCql(cqlSource);
  validateCompiledElm(compilation.elm, template);
  const syntheticEvaluation = await evaluateSyntheticTemplate(compilation.elm, template);
  const draftLibrary = buildDraftLibrary(template, cqlSource);
  return {
    schema: schemaUri,
    status: 'draft-synthetic-checked',
    templateIdentity: {
      id: template.templateId,
      version: template.templateVersion,
    },
    cqlVersion,
    fhirModelVersion,
    fhirVersion,
    translationWarnings: ['value_set_membership_not_resolved_without_terminology_provider'],
    generatedCql: cqlSource,
    libraryDraft: draftLibrary,
    dataRequirementCount: draftLibrary.dataRequirement.length,
    syntheticEvaluation,
    boundaries: {
      templateKind: 'FHIR R4 Patient-scoped Observation ValueSet count comparison',
      cqlTranslatedToElm: true,
      cqlEvaluatedAgainstSyntheticCasesOnly: true,
      syntheticCaseCount: syntheticEvaluation.caseCount,
      fhirValidatorRun: false,
      terminologyResolved: false,
      fhirEndpointCalled: false,
      realPatientDataRead: false,
      runtimeRuleCreated: false,
      clinicalValidityClaim: false,
    },
  };
}

function readTemplateFromArgs(argv) {
  if (argv.length === 0) return JSON.parse(readFileSync(defaultTemplatePath, 'utf8'));
  requireContract(argv.length === 2 && argv[0] === '--template', 'cql_template_cli_usage_invalid');
  return JSON.parse(readFileSync(path.resolve(argv[1]), 'utf8'));
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const template = readTemplateFromArgs(process.argv.slice(2));
  buildCqlConceptTemplatePreview(template)
    .then((preview) => process.stdout.write(`${JSON.stringify(preview, null, 2)}\n`))
    .catch((error) => {
      process.stderr.write(`${error.message}\n`);
      process.exitCode = 1;
    });
}
