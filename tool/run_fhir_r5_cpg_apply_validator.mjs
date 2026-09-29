#!/usr/bin/env node

import { createHash } from 'node:crypto';
import { createReadStream, existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

import { validateFhirR5CpgApplyFixture } from './fhir_r5_cpg_apply_contract.mjs';
import { validateFhirR5ActivityDefinitionApplyFixture } from './fhir_r5_activitydefinition_apply_contract.mjs';
import { validateFhirR5PlanDefinitionDataRequirementsFixture } from './fhir_r5_plandefinition_data_requirements_contract.mjs';

export const VALIDATOR_RELEASE = '6.10.4';
export const VALIDATOR_SHA256 = '1106b9d58f9e363e47bea7c4fc065841e5fc91fe9d062775c3bfdd212bd653cc';
export const FHIR_R5_VERSION = '5.0.0';
export const VALIDATOR_TARGETS = Object.freeze([
  Object.freeze({ id: 'planDefinition', operation: 'PlanDefinition/$apply', resourceType: 'Parameters' }),
  Object.freeze({ id: 'activityDefinition', operation: 'ActivityDefinition/$apply', resourceType: 'RequestOrchestration' }),
  Object.freeze({ id: 'planDefinitionDataRequirements', operation: 'PlanDefinition/$data-requirements', resourceType: 'Library' }),
]);

const FIXTURE_PATH = new URL('../test/fixtures/fhir_r5_cpg_apply_contract.json', import.meta.url);
const ACTIVITY_FIXTURE_PATH = new URL('../test/fixtures/fhir_r5_activitydefinition_apply_contract.json', import.meta.url);
const DATA_REQUIREMENTS_FIXTURE_PATH = new URL('../test/fixtures/fhir_r5_plandefinition_data_requirements_contract.json', import.meta.url);
const PACKAGE_ID = 'hl7.fhir.r5.core#5.0.0';
const PROCESS_TIMEOUT_MS = 300_000;
const OUTPUT_LIMIT = 12_000;

export function buildValidatorArgs(jarPath, resourcePath) {
  return ['-jar', jarPath, resourcePath, '-version', FHIR_R5_VERSION, '-tx', 'n/a'];
}

export function parseValidatorSummary(output) {
  const matches = [...output.matchAll(/Success:\s*(\d+)\s+errors?(?:,\s*(\d+)\s+warnings?)?(?:,\s*(\d+)\s+notes?)?/gi)];
  if (matches.length !== 1) {
    throw new Error(`Expected one FHIR Validator summary; found ${matches.length}.`);
  }
  const [, errors, warnings = '0', notes = '0'] = matches[0];
  return {
    errors: Number(errors),
    warnings: Number(warnings),
    notes: Number(notes),
  };
}

export function parseJavaMajorVersion(output) {
  const match = output.match(/version\s+"?(\d+)(?:\.(\d+))?/i);
  if (!match) throw new Error('Unable to read Java runtime version.');
  const major = Number(match[1] === '1' ? match[2] : match[1]);
  if (!Number.isInteger(major) || major < 11) throw new Error('FHIR Validator 6.10.4 requires Java 11 or newer.');
  return major;
}

function validateTargetFixture(targetId, fixture) {
  switch (targetId) {
    case 'planDefinition':
      return validateFhirR5CpgApplyFixture(fixture);
    case 'activityDefinition':
      return validateFhirR5ActivityDefinitionApplyFixture(fixture);
    case 'planDefinitionDataRequirements':
      return validateFhirR5PlanDefinitionDataRequirementsFixture(fixture);
    default:
      throw new Error(`Unsupported FHIR R5 validator target: ${targetId}.`);
  }
}

export function buildValidatorReport({ targetId = 'planDefinition', fixture, validatorSha256, output, exitCode }) {
  const target = VALIDATOR_TARGETS.find((candidate) => candidate.id === targetId);
  if (!target) throw new Error(`Unsupported FHIR R5 validator target: ${targetId}.`);
  const fixtureCounts = validateTargetFixture(targetId, fixture);
  if (exitCode !== 0) throw new Error(`FHIR Validator exited with ${exitCode}.`);
  if (!new RegExp(`FHIR Validation tool Version ${VALIDATOR_RELEASE.replaceAll('.', '\\.')}(?:\\s|$)`).test(output)) {
    throw new Error(`FHIR Validator output did not identify release ${VALIDATOR_RELEASE}.`);
  }
  const validation = parseValidatorSummary(output);
  if (validation.errors !== 0) throw new Error(`FHIR Validator reported ${validation.errors} errors.`);
  if (validatorSha256 !== VALIDATOR_SHA256) throw new Error('FHIR Validator digest does not match the pinned release.');

  return {
    schemaVersion: 2,
    status: 'passed',
    fhirVersion: FHIR_R5_VERSION,
    fhirCorePackage: PACKAGE_ID,
    operation: target.operation,
    resourceType: target.resourceType,
    validatorRelease: VALIDATOR_RELEASE,
    validatorSha256,
    ...fixtureCounts,
    ...validation,
    terminologyServerEnabled: false,
    corePackageDownloadMayOccur: true,
    realPatientDataUsed: false,
    cpgApplyExecuted: false,
    dataRequirementsOperationExecuted: false,
  };
}

async function sha256File(path) {
  const digest = createHash('sha256');
  for await (const chunk of createReadStream(path)) digest.update(chunk);
  return digest.digest('hex');
}

function optionValue(args, prefix) {
  const value = args.find((argument) => argument.startsWith(prefix));
  return value === undefined ? undefined : value.slice(prefix.length);
}

function javaMajorVersion(java, spawn) {
  const result = spawn(java, ['-version'], { encoding: 'utf8', timeout: 10_000 });
  if (result.error || result.status !== 0) throw new Error(`Unable to inspect Java runtime${result.error ? `: ${result.error.message}` : '.'}`);
  const output = `${result.stdout ?? ''}\n${result.stderr ?? ''}`;
  return parseJavaMajorVersion(output);
}

export async function runFhirR5CpgApplyValidator({
  args = process.argv.slice(2),
  env = process.env,
  spawn = spawnSync,
  exists = existsSync,
  hashFile = sha256File,
  readFixture = (path) => readFileSync(path),
} = {}) {
  const validatorPath = optionValue(args, '--validator=') ?? env.FHIR_VALIDATOR_JAR;
  if (!validatorPath) throw new Error('Set FHIR_VALIDATOR_JAR or pass --validator=/path/to/validator_cli.jar.');
  if (!exists(validatorPath)) throw new Error(`FHIR Validator JAR not found: ${basename(validatorPath)}.`);
  const validatorSha256 = await hashFile(validatorPath);
  if (validatorSha256 !== VALIDATOR_SHA256) throw new Error('FHIR Validator digest does not match the pinned 6.10.4 release.');

  const java = env.JAVA_BIN || 'java';
  const javaMajor = javaMajorVersion(java, spawn);
  const fixtureSpecs = [
    { targetId: 'planDefinition', path: FIXTURE_PATH },
    { targetId: 'activityDefinition', path: ACTIVITY_FIXTURE_PATH },
    { targetId: 'planDefinitionDataRequirements', path: DATA_REQUIREMENTS_FIXTURE_PATH },
  ];
  const preparedFixtures = fixtureSpecs.map(({ targetId, path }) => {
    const fixtureBytes = readFixture(path);
    const fixture = JSON.parse(fixtureBytes.toString('utf8'));
    validateTargetFixture(targetId, fixture);
    return { targetId, fixtureBytes, fixture };
  });
  const temporaryDirectory = mkdtempSync(join(tmpdir(), 'parkinsum-fhir-r5-cpg-'));
  try {
    const validations = [];
    for (const { targetId, fixtureBytes, fixture } of preparedFixtures) {
      const resourcePath = join(temporaryDirectory, `${targetId}-result.json`);
      writeFileSync(resourcePath, `${JSON.stringify(fixture.response, null, 2)}\n`, { mode: 0o600 });
      const result = spawn(java, buildValidatorArgs(resolve(validatorPath), resourcePath), {
        encoding: 'utf8',
        timeout: PROCESS_TIMEOUT_MS,
        maxBuffer: 16 * 1024 * 1024,
        windowsHide: true,
      });
      const validatorOutput = `${result.stdout ?? ''}\n${result.stderr ?? ''}`;
      if (result.error) throw new Error(`FHIR Validator process failed: ${result.error.message}`);
      try {
        validations.push(buildValidatorReport({
          targetId,
          fixture,
          validatorSha256,
          output: validatorOutput,
          exitCode: result.status,
        }));
      } catch (error) {
        const detail = error instanceof Error ? error.message : 'FHIR Validator output was rejected.';
        throw new Error(`${detail}\n${validatorOutput.slice(0, OUTPUT_LIMIT)}`);
      }
    }
    return {
      schemaVersion: 3,
      status: 'passed',
      fhirVersion: FHIR_R5_VERSION,
      fhirCorePackage: PACKAGE_ID,
      validatorRelease: VALIDATOR_RELEASE,
      validatorSha256,
      javaMajorVersion: javaMajor,
      validatedResourceCount: validations.length,
      errors: validations.reduce((sum, report) => sum + report.errors, 0),
      warnings: validations.reduce((sum, report) => sum + report.warnings, 0),
      notes: validations.reduce((sum, report) => sum + report.notes, 0),
      terminologyServerEnabled: false,
      corePackageDownloadMayOccur: true,
      realPatientDataUsed: false,
      cpgApplyExecuted: false,
      dataRequirementsOperationExecuted: false,
      validations: validations.map(({ operation, resourceType, errors, warnings, notes }) => ({
        operation,
        resourceType,
        errors,
        warnings,
        notes,
      })),
    };
  } catch (error) {
    const detail = error instanceof Error ? error.message : 'unknown validator failure';
    throw new Error(detail.slice(0, OUTPUT_LIMIT));
  } finally {
    rmSync(temporaryDirectory, { recursive: true, force: true });
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  try {
    const report = await runFhirR5CpgApplyValidator();
    process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'unknown validator failure';
    process.stderr.write(`${message}\n`);
    process.exitCode = 2;
  }
}
