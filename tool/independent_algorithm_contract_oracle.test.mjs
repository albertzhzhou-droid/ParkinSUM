import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import {
  applyJsonPointerMutation,
  attestationSourcePath,
  buildIndependentReport,
  canonicalJson,
  evaluateRelation,
  evaluateScheduler,
  executableReportPath,
  registryPath,
  sha256,
  validateRegistry,
  verifyAttestationPins,
} from './independent_algorithm_contract_oracle.mjs';

function fixtures() {
  const registry = JSON.parse(readFileSync(registryPath, 'utf8'));
  const executableReport = JSON.parse(
    readFileSync(executableReportPath, 'utf8'),
  );
  const oracleSource = readFileSync(
    'tool/independent_algorithm_contract_oracle.mjs',
  );
  return {
    registry,
    executableReport,
    oracleSource,
    report: buildIndependentReport({
      registry,
      executableReport,
      oracleSha256: sha256(oracleSource),
    }),
  };
}

test('independent runtime verifies all relations, mutations, false relations, and scheduler cases', () => {
  const { report } = fixtures();
  assert.equal(report.passed, true, report.integrity_failure_codes.join('\n'));
  assert.equal(report.relation_count, 8);
  assert.equal(report.relation_passed_count, 8);
  assert.equal(report.mutation_count, 16);
  assert.equal(report.mutation_killed_count, 16);
  assert.equal(report.mutation_survivor_count, 0);
  assert.equal(report.invalid_relation_fixture_count, 3);
  assert.equal(report.invalid_relation_rejected_count, 3);
  assert.equal(report.scheduler_case_count, 6);
  assert.equal(report.scheduler_passed_count, 6);
  assert.match(report.boundary, /do not establish scientific truth/);
});

test('every IR mutation fails only its target relation', () => {
  const { registry, executableReport } = fixtures();
  const observations = new Map(
    executableReport.checks.map((entry) => [entry.spec.id, entry.observation]),
  );
  for (const relation of registry.relations) {
    assert.deepEqual(
      evaluateRelation(relation, observations.get(relation.id)),
      [],
      relation.id,
    );
    for (const mutation of relation.mutationOperators) {
      const mutated = applyJsonPointerMutation(
        observations.get(relation.id),
        mutation,
      );
      assert.notDeepEqual(
        evaluateRelation(relation, mutated),
        [],
        `${relation.id}:${mutation.id}`,
      );
      for (const other of registry.relations) {
        if (other.id === relation.id) continue;
        assert.deepEqual(
          evaluateRelation(other, observations.get(other.id)),
          [],
          `${other.id} changed with ${mutation.id}`,
        );
      }
    }
  }
});

test('weak or malformed relation registries fail closed', () => {
  const { registry } = fixtures();
  assert.deepEqual(validateRegistry(registry), []);

  const unsupported = structuredClone(registry);
  unsupported.relations[0].evaluator = 'always_pass';
  assert.ok(
    validateRegistry(unsupported).some((entry) =>
      entry.startsWith('registry.evaluator_unsupported'),
    ),
  );

  const duplicate = structuredClone(registry);
  duplicate.relations[1].id = duplicate.relations[0].id;
  assert.ok(validateRegistry(duplicate).includes('registry.relation_duplicate'));

  const noRisks = structuredClone(registry);
  noRisks.relations[2].knownFalseRelationRisks = [];
  assert.ok(
    validateRegistry(noRisks).some((entry) =>
      entry.startsWith('registry.knownFalseRelationRisks_missing'),
    ),
  );
});

test('terminal async events remain blocked regardless of completion order', () => {
  assert.equal(evaluateScheduler(['complete']), 'passed');
  for (const events of [
    ['withdraw', 'complete'],
    ['complete', 'withdraw'],
    ['timeout', 'complete'],
    ['cancel', 'complete'],
    ['capability_revoke', 'complete'],
    ['complete', 'unknown'],
  ]) {
    assert.equal(evaluateScheduler(events), 'blocked', events.join(','));
  }
});

test('committed Dart attestation pins exact independent evidence', () => {
  const { report } = fixtures();
  const source = readFileSync(attestationSourcePath, 'utf8');
  assert.deepEqual(verifyAttestationPins(report, source), []);

  const stale = source.replace(
    report.registry_sha256,
    '0'.repeat(64),
  );
  assert.deepEqual(verifyAttestationPins(report, stale), [
    'attestation.registry_pin_drift',
  ]);
});

test('oracle is byte-stable and imports no production implementation', () => {
  const first = fixtures();
  const second = fixtures();
  assert.equal(sha256(Buffer.from('byte identity', 'utf8')), sha256('byte identity'));
  assert.equal(canonicalJson(first.report), canonicalJson(second.report));
  assert.equal(first.report.report_sha256, second.report.report_sha256);
  const source = first.oracleSource.toString('utf8');
  assert.doesNotMatch(source, /package:parkinsum|from ['"]\.\.\/lib|fetch\s*\(/);
});
