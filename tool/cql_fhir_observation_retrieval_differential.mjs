#!/usr/bin/env node
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

import {
  CqlTranslator,
  LibraryManager,
  ModelManager,
  createLibrarySourceProvider,
  createModelInfoProvider,
  stringAsSource,
} from '@cqframework/cql/cql-to-elm';
import { SystemModelInfoProvider } from '@cqframework/cql/cql';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const fixturePath = path.join(root, 'test/fixtures/cql_fhir_r4_observation_retrieval_corpus.json');
const fixtureBytes = readFileSync(fixturePath);
const fixture = JSON.parse(fixtureBytes.toString('utf8'));
const packageJson = JSON.parse(readFileSync(path.join(root, 'package.json'), 'utf8'));
const require = createRequire(import.meta.url);
const CqlExecution = require('cql-execution');
const CqlExecFhir = require('cql-exec-fhir');

const libraryName = 'ParkinSUM_FHIR_Observation_Retrieval';
const syntheticValueSet = {
  id: 'urn:oid:1.2.3.4.5.6.7',
  version: '2026-09',
  system: 'urn:parkinsum:synthetic-test',
  systemVersion: 'v1',
  code: 'observation-in-set',
};
const cqlSource = [
  `library ${libraryName} version '1.0.0'`,
  "using FHIR version '4.0.1'",
  `valueset "Synthetic Observation Codes": '${syntheticValueSet.id}' version '${syntheticValueSet.version}'`,
  'context Patient',
  'define Result: exists([Observation])',
  'define CodeInSyntheticValueSet: exists([Observation: code in "Synthetic Observation Codes"])',
  '',
].join('\n');

export const fixedCorpus = {
  schemaVersion: 2,
  scope: 'synthetic-fhir-r4-observation-retrieval-and-local-terminology',
  fhirVersion: '4.0.1',
  context: 'Patient',
  expression: 'exists([Observation]) + code in Synthetic Observation Codes',
  cases: [
    {
      id: 'observation_present',
      patientContextId: 'synthetic-patient-present',
      expectedResult: true,
      expectedRuntimeValueSetMembership: true,
      expectedVersionAwareMembership: true,
      bundle: {
        resourceType: 'Bundle',
        type: 'collection',
        entry: [
          { resource: { resourceType: 'Patient', id: 'synthetic-patient-present' } },
          {
            resource: {
              resourceType: 'Observation',
              id: 'synthetic-observation-present',
              status: 'final',
              code: {
                coding: [{
                  system: syntheticValueSet.system,
                  version: syntheticValueSet.systemVersion,
                  code: syntheticValueSet.code,
                }],
              },
              subject: { reference: 'Patient/synthetic-patient-present' },
            },
          },
        ],
      },
    },
    {
      id: 'observation_absent',
      patientContextId: 'synthetic-patient-empty',
      expectedResult: false,
      expectedRuntimeValueSetMembership: false,
      expectedVersionAwareMembership: false,
      bundle: {
        resourceType: 'Bundle',
        type: 'collection',
        entry: [{ resource: { resourceType: 'Patient', id: 'synthetic-patient-empty' } }],
      },
    },
    {
      id: 'observation_foreign_subject',
      patientContextId: 'synthetic-patient-empty',
      expectedResult: false,
      expectedRuntimeValueSetMembership: false,
      expectedVersionAwareMembership: false,
      bundle: {
        resourceType: 'Bundle',
        type: 'collection',
        entry: [
          { resource: { resourceType: 'Patient', id: 'synthetic-patient-empty' } },
          {
            resource: {
              resourceType: 'Observation',
              id: 'synthetic-observation-foreign',
              status: 'final',
              code: {
                coding: [{
                  system: syntheticValueSet.system,
                  version: syntheticValueSet.systemVersion,
                  code: syntheticValueSet.code,
                }],
              },
              subject: { reference: 'Patient/synthetic-patient-other' },
            },
          },
        ],
      },
    },
    {
      id: 'observation_non_member_code',
      patientContextId: 'synthetic-patient-non-member',
      expectedResult: true,
      expectedRuntimeValueSetMembership: false,
      expectedVersionAwareMembership: false,
      bundle: {
        resourceType: 'Bundle',
        type: 'collection',
        entry: [
          { resource: { resourceType: 'Patient', id: 'synthetic-patient-non-member' } },
          {
            resource: {
              resourceType: 'Observation',
              id: 'synthetic-observation-non-member',
              status: 'final',
              code: {
                coding: [{
                  system: syntheticValueSet.system,
                  version: syntheticValueSet.systemVersion,
                  code: 'observation-outside-set',
                }],
              },
              subject: { reference: 'Patient/synthetic-patient-non-member' },
            },
          },
        ],
      },
    },
    {
      id: 'observation_foreign_code_system',
      patientContextId: 'synthetic-patient-other-system',
      expectedResult: true,
      expectedRuntimeValueSetMembership: false,
      expectedVersionAwareMembership: false,
      bundle: {
        resourceType: 'Bundle',
        type: 'collection',
        entry: [
          { resource: { resourceType: 'Patient', id: 'synthetic-patient-other-system' } },
          {
            resource: {
              resourceType: 'Observation',
              id: 'synthetic-observation-other-system',
              status: 'final',
              code: {
                coding: [{
                  system: 'urn:parkinsum:synthetic-other',
                  version: syntheticValueSet.systemVersion,
                  code: syntheticValueSet.code,
                }],
              },
              subject: { reference: 'Patient/synthetic-patient-other-system' },
            },
          },
        ],
      },
    },
    {
      id: 'observation_system_version_mismatch',
      patientContextId: 'synthetic-patient-version-mismatch',
      expectedResult: true,
      expectedRuntimeValueSetMembership: true,
      expectedVersionAwareMembership: false,
      bundle: {
        resourceType: 'Bundle',
        type: 'collection',
        entry: [
          { resource: { resourceType: 'Patient', id: 'synthetic-patient-version-mismatch' } },
          {
            resource: {
              resourceType: 'Observation',
              id: 'synthetic-observation-version-mismatch',
              status: 'final',
              code: {
                coding: [{
                  system: syntheticValueSet.system,
                  version: 'v2',
                  code: syntheticValueSet.code,
                }],
              },
              subject: { reference: 'Patient/synthetic-patient-version-mismatch' },
            },
          },
        ],
      },
    },
  ],
};

function hasExactKeys(value, keys) {
  return value !== null
    && typeof value === 'object'
    && !Array.isArray(value)
    && Object.keys(value).sort().join('\0') === [...keys].sort().join('\0');
}

function requireExactKeys(value, keys, label) {
  if (!hasExactKeys(value, keys)) throw new Error(`${label}_shape`);
}

function requireSyntheticId(value, label) {
  if (typeof value !== 'string' || !/^synthetic-[a-z0-9-]{1,60}$/.test(value)) {
    throw new Error(`${label}_id`);
  }
}

export function validateObservationCorpus(value) {
  assert.deepStrictEqual(value, fixedCorpus, 'unexpected fixed synthetic FHIR Observation corpus');
  return value;
}

export function scopeBundleToPatientContext(bundle, patientContextId) {
  requireSyntheticId(patientContextId, 'patient_context');
  requireExactKeys(bundle, ['resourceType', 'type', 'entry'], 'bundle');
  if (bundle.resourceType !== 'Bundle' || bundle.type !== 'collection' || !Array.isArray(bundle.entry)) {
    throw new Error('bundle_contract');
  }

  const seenIds = new Set();
  let patientCount = 0;
  let foreignObservationsDropped = 0;
  const entries = [];
  for (const [index, entry] of bundle.entry.entries()) {
    requireExactKeys(entry, ['resource'], `entry_${index}`);
    const resource = entry.resource;
    if (resource?.resourceType === 'Patient') {
      requireExactKeys(resource, ['resourceType', 'id'], `patient_${index}`);
      requireSyntheticId(resource.id, `patient_${index}`);
      if (resource.id !== patientContextId) throw new Error('patient_context_mismatch');
      patientCount += 1;
      if (seenIds.has(resource.id)) throw new Error('duplicate_resource_id');
      seenIds.add(resource.id);
      entries.push({ resource: structuredClone(resource) });
      continue;
    }
    if (resource?.resourceType !== 'Observation') throw new Error('unsupported_resource_type');
    requireExactKeys(resource, ['resourceType', 'id', 'status', 'code', 'subject'], `observation_${index}`);
    requireSyntheticId(resource.id, `observation_${index}`);
    if (resource.status !== 'final') throw new Error('observation_status');
    requireExactKeys(resource.code, ['coding'], `observation_${index}_code`);
    if (!Array.isArray(resource.code.coding) || resource.code.coding.length !== 1) {
      throw new Error('observation_code_coding');
    }
    requireExactKeys(resource.code.coding[0], ['system', 'version', 'code'], `observation_${index}_coding`);
    if (typeof resource.code.coding[0].system !== 'string'
      || !/^urn:parkinsum:synthetic-[a-z-]{1,40}$/.test(resource.code.coding[0].system)
      || !/^v[1-9][0-9]{0,2}$/.test(resource.code.coding[0].version)
      || !/^observation-[a-z-]{1,40}$/.test(resource.code.coding[0].code)) {
      throw new Error('observation_code');
    }
    requireExactKeys(resource.subject, ['reference'], `observation_${index}_subject`);
    const match = /^Patient\/(synthetic-[a-z0-9-]{1,60})$/.exec(resource.subject.reference ?? '');
    if (!match) throw new Error('observation_subject_reference');
    if (seenIds.has(resource.id)) throw new Error('duplicate_resource_id');
    seenIds.add(resource.id);
    if (match[1] !== patientContextId) {
      foreignObservationsDropped += 1;
      continue;
    }
    entries.push({ resource: structuredClone(resource) });
  }
  if (patientCount !== 1) throw new Error('bundle_patient_count');

  return {
    bundle: { resourceType: 'Bundle', type: 'collection', entry: entries },
    foreignObservationsDropped,
  };
}

function compileObservationLibrary() {
  const versionPins = {
    '@cqframework/cql': '5.3.0',
    'cql-exec-fhir': '2.1.6',
    'cql-execution': '3.3.2',
  };
  for (const [dependency, expectedVersion] of Object.entries(versionPins)) {
    if (packageJson.devDependencies?.[dependency] !== expectedVersion) {
      throw new Error(`unreviewed_dependency_version:${dependency}`);
    }
  }

  const modelInfoPath = path.join(root, 'node_modules/cql-exec-fhir/lib/modelInfos/fhir-modelinfo-4.0.1.xml');
  const modelInfoXml = readFileSync(modelInfoPath, 'utf8');
  const modelManager = new ModelManager();
  modelManager.modelInfoLoader.registerModelInfoProvider(new SystemModelInfoProvider());
  modelManager.modelInfoLoader.registerModelInfoProvider(
    createModelInfoProvider((name, namespace, version) => (
      name === 'FHIR' && version === '4.0.1' ? stringAsSource(modelInfoXml) : null
    )),
  );
  const libraryManager = new LibraryManager(modelManager);
  libraryManager.librarySourceLoader.registerProvider(
    createLibrarySourceProvider((name) => name === libraryName ? stringAsSource(cqlSource) : null),
  );
  const translator = CqlTranslator.fromText(cqlSource, libraryManager);
  const errors = translator.errors.asJsReadonlyArrayView();
  if (errors.length > 0 || translator.toELM() == null) {
    throw new Error(`fhir_observation_cql_translation:${errors.map(String).join('; ')}`);
  }
  const codeService = new CqlExecution.CodeService({
    [syntheticValueSet.id]: {
      [syntheticValueSet.version]: [{
        code: syntheticValueSet.code,
        system: syntheticValueSet.system,
        version: syntheticValueSet.systemVersion,
      }],
    },
  });
  return new CqlExecution.Executor(new CqlExecution.Library(JSON.parse(translator.toJson())), codeService);
}

async function evaluateCase(executor, testCase) {
  const scoped = scopeBundleToPatientContext(testCase.bundle, testCase.patientContextId);
  const patientSource = CqlExecFhir.PatientSource.FHIRv401();
  if (patientSource.version !== '4.0.1') throw new Error('unexpected_fhir_patient_source_version');
  patientSource.loadBundles([scoped.bundle]);
  const evaluation = await executor.exec(patientSource);
  const patients = Object.values(evaluation.patientResults ?? {});
  if (patients.length !== 1
    || typeof patients[0]?.Result !== 'boolean'
    || typeof patients[0]?.CodeInSyntheticValueSet !== 'boolean') {
    throw new Error(`fhir_observation_cql_result_shape:${testCase.id}`);
  }
  return {
    id: testCase.id,
    expectedResult: testCase.expectedResult,
    result: patients[0].Result,
    expectedRuntimeValueSetMembership: testCase.expectedRuntimeValueSetMembership,
    runtimeValueSetMembership: patients[0].CodeInSyntheticValueSet,
    expectedVersionAwareMembership: testCase.expectedVersionAwareMembership,
    foreignObservationsDropped: scoped.foreignObservationsDropped,
  };
}

export async function runObservationRetrievalDifferential() {
  validateObservationCorpus(fixture);
  const executor = compileObservationLibrary();
  const cases = [];
  for (const testCase of fixture.cases) {
    const result = await evaluateCase(executor, testCase);
    if (result.result !== result.expectedResult) {
      throw new Error(`fhir_observation_cql_expectation_mismatch:${testCase.id}`);
    }
    if (result.runtimeValueSetMembership !== result.expectedRuntimeValueSetMembership) {
      throw new Error(`fhir_observation_cql_terminology_expectation_mismatch:${testCase.id}`);
    }
    cases.push(result);
  }
  return {
    schemaVersion: 2,
    scope: fixture.scope,
    fhirVersion: fixture.fhirVersion,
    context: fixture.context,
    cqlExpression: fixture.expression,
    terminology: {
      valueSetCanonical: syntheticValueSet.id,
      valueSetVersion: syntheticValueSet.version,
      expansionSource: 'fixed-local-synthetic-code-service',
      codingSystemVersionComparedByRuntime: false,
    },
    translator: `@cqframework/cql@${packageJson.devDependencies['@cqframework/cql']}`,
    executionPath: `cql-execution@${packageJson.devDependencies['cql-execution']} + cql-exec-fhir@${packageJson.devDependencies['cql-exec-fhir']}`,
    cases,
    fixtureSha256: createHash('sha256').update(fixtureBytes).digest('hex'),
    cqlSourceSha256: createHash('sha256').update(cqlSource).digest('hex'),
    networkRequestMade: false,
    realPatientDataUsed: false,
  };
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  runObservationRetrievalDifferential()
    .then((report) => process.stdout.write(`${JSON.stringify(report, null, 2)}\n`))
    .catch((error) => {
      process.stderr.write(`${error.message}\n`);
      process.exitCode = 1;
    });
}
