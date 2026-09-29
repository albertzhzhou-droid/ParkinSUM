import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import {
  buildValidatorArgs,
  buildValidatorReport,
  parseJavaMajorVersion,
  parseValidatorSummary,
  runFhirR5CpgApplyValidator,
  VALIDATOR_TARGETS,
  VALIDATOR_RELEASE,
  VALIDATOR_SHA256,
} from './run_fhir_r5_cpg_apply_validator.mjs';

const fixture = JSON.parse(
  fs.readFileSync(new URL('../test/fixtures/fhir_r5_cpg_apply_contract.json', import.meta.url), 'utf8'),
);
const activityFixture = JSON.parse(
  fs.readFileSync(new URL('../test/fixtures/fhir_r5_activitydefinition_apply_contract.json', import.meta.url), 'utf8'),
);
const dataRequirementsFixture = JSON.parse(
  fs.readFileSync(new URL('../test/fixtures/fhir_r5_plandefinition_data_requirements_contract.json', import.meta.url), 'utf8'),
);

test('official CLI invocation pins FHIR R5 and disables terminology-server lookup', () => {
  assert.equal(VALIDATOR_RELEASE, '6.10.4');
  assert.equal(VALIDATOR_SHA256, '1106b9d58f9e363e47bea7c4fc065841e5fc91fe9d062775c3bfdd212bd653cc');
  assert.deepEqual(buildValidatorArgs('/tmp/validator_cli.jar', '/tmp/apply result.json'), [
    '-jar',
    '/tmp/validator_cli.jar',
    '/tmp/apply result.json',
    '-version',
    '5.0.0',
    '-tx',
    'n/a',
  ]);
});

test('optional validator covers both R5 $apply shapes and the direct data-requirements Library', () => {
  assert.deepEqual(VALIDATOR_TARGETS, [
    { id: 'planDefinition', operation: 'PlanDefinition/$apply', resourceType: 'Parameters' },
    { id: 'activityDefinition', operation: 'ActivityDefinition/$apply', resourceType: 'RequestOrchestration' },
    { id: 'planDefinitionDataRequirements', operation: 'PlanDefinition/$data-requirements', resourceType: 'Library' },
  ]);
  const report = buildValidatorReport({
    targetId: 'activityDefinition',
    fixture: activityFixture,
    validatorSha256: VALIDATOR_SHA256,
    output: `FHIR Validation tool Version ${VALIDATOR_RELEASE}\nSuccess: 0 errors, 1 warning, 2 notes`,
    exitCode: 0,
  });
  assert.equal(report.operation, 'ActivityDefinition/$apply');
  assert.equal(report.resourceType, 'RequestOrchestration');
  assert.equal(report.returnedRequestOrchestrationCount, 1);
  assert.equal(report.proposedActionCount, 0);
  assert.equal(report.warnings, 1);
  assert.equal(report.notes, 2);
  assert.equal(report.cpgApplyExecuted, false);
  assert.equal(report.dataRequirementsOperationExecuted, false);
  assert.doesNotMatch(JSON.stringify(report), /synthetic-r5-subject|ParkinSUMSyntheticR5Activity/);
});

test('validator runner submits all three redacted resources and removes mode-restricted temp files', async () => {
  const submitted = [];
  const fakeSpawn = (_java, args) => {
    if (args[0] !== '-jar') return { status: 0, stdout: 'openjdk version "17.0.11"', stderr: '' };
    const resourcePath = args[2];
    const stats = fs.statSync(resourcePath);
    assert.equal(stats.mode & 0o777, 0o600);
    submitted.push({
      resourcePath,
      args,
      resource: JSON.parse(fs.readFileSync(resourcePath, 'utf8')),
    });
    return {
      status: 0,
      stdout: `FHIR Validation tool Version ${VALIDATOR_RELEASE}\nSuccess: 0 errors, 1 warnings, 2 notes`,
      stderr: '',
    };
  };
  const report = await runFhirR5CpgApplyValidator({
    args: ['--validator=/tmp/fixed-validator.jar'],
    env: { JAVA_BIN: 'java-17' },
    spawn: fakeSpawn,
    exists: () => true,
    hashFile: async () => VALIDATOR_SHA256,
  });

  assert.equal(report.status, 'passed');
  assert.equal(report.schemaVersion, 3);
  assert.equal(report.javaMajorVersion, 17);
  assert.equal(report.validatedResourceCount, 3);
  assert.deepEqual([report.errors, report.warnings, report.notes], [0, 3, 6]);
  assert.deepEqual(submitted.map(({ resource }) => resource.resourceType), ['Parameters', 'RequestOrchestration', 'Library']);
  assert.equal(submitted[0].resource.parameter[0].resource.resourceType, 'Bundle');
  assert.equal(submitted[2].resource.type.coding[0].code, 'module-definition');
  assert.equal(report.dataRequirementsOperationExecuted, false);
  assert.ok(submitted.every(({ args }) => args.slice(-4).join(' ') === '-version 5.0.0 -tx n/a'));
  assert.ok(submitted.every(({ resourcePath }) => !fs.existsSync(resourcePath)));
});

test('Java runtime parser accepts Java 11+ and rejects legacy Java 8', () => {
  assert.equal(parseJavaMajorVersion('openjdk version "21.0.8" 2026-07-14'), 21);
  assert.equal(parseJavaMajorVersion('java version "11.0.24" 2024-07-16'), 11);
  assert.throws(() => parseJavaMajorVersion('java version "1.8.0_471"'), /requires Java 11 or newer/);
});

test('validator summary parser requires one summary and preserves warning counts', () => {
  assert.deepEqual(
    parseValidatorSummary('FHIR Validation tool\nSuccess: 0 errors, 2 warnings, 3 notes'),
    { errors: 0, warnings: 2, notes: 3 },
  );
  assert.throws(() => parseValidatorSummary('Success: 0 errors\nSuccess: 0 errors'), /found 2/);
  assert.throws(() => parseValidatorSummary('FHIR Validation tool completed'), /found 0/);
});

test('report binds the official validator release and omits fixture identifiers', () => {
  const report = buildValidatorReport({
    fixture,
    validatorSha256: VALIDATOR_SHA256,
    output: `FHIR Validation tool Version ${VALIDATOR_RELEASE}\nSuccess: 0 errors, 0 warnings, 0 notes`,
    exitCode: 0,
  });
  assert.equal(report.status, 'passed');
  assert.equal(report.fhirCorePackage, 'hl7.fhir.r5.core#5.0.0');
  assert.equal(report.terminologyServerEnabled, false);
  assert.equal(report.corePackageDownloadMayOccur, true);
  assert.equal(report.cpgApplyExecuted, false);
  assert.equal(report.dataRequirementsOperationExecuted, false);
  assert.equal(report.realPatientDataUsed, false);
  assert.doesNotMatch(JSON.stringify(report), /synthetic-r5-subject|ParkinSUMSyntheticR5Plan/);
});

test('validator report identifies the direct Library target without claiming operation execution', () => {
  const report = buildValidatorReport({
    targetId: 'planDefinitionDataRequirements',
    fixture: dataRequirementsFixture,
    validatorSha256: VALIDATOR_SHA256,
    output: `FHIR Validation tool Version ${VALIDATOR_RELEASE}\nSuccess: 0 errors, 0 warnings, 0 notes`,
    exitCode: 0,
  });
  assert.equal(report.operation, 'PlanDefinition/$data-requirements');
  assert.equal(report.resourceType, 'Library');
  assert.equal(report.returnedModuleDefinitionLibraryCount, 1);
  assert.equal(report.dataRequirementsOperationExecuted, false);
  assert.doesNotMatch(JSON.stringify(report), /ParkinSUMSyntheticR5DataRequirements|hasSyntheticObservation/);
});

test('rejects errors, an unpinned CLI digest, and unrecognized validator release', () => {
  const base = {
    fixture,
    validatorSha256: VALIDATOR_SHA256,
    output: `FHIR Validation tool Version ${VALIDATOR_RELEASE}\nSuccess: 1 error, 0 warnings, 0 notes`,
    exitCode: 0,
  };
  assert.throws(() => buildValidatorReport(base), /reported 1 errors/);
  assert.throws(
    () => buildValidatorReport({ ...base, validatorSha256: '0'.repeat(64), output: `FHIR Validation tool Version ${VALIDATOR_RELEASE}\nSuccess: 0 errors` }),
    /digest does not match/,
  );
  assert.throws(
    () => buildValidatorReport({ ...base, validatorSha256: VALIDATOR_SHA256, output: 'FHIR Validation tool Version 6.9.12\nSuccess: 0 errors' }),
    /did not identify release/,
  );
});
