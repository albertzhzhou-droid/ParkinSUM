import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import {
  DEFECTIVE_RELATION_CALIBRATION_POLICY,
  REPORT_SCHEMA,
  REPORT_SCHEMA_VERSION,
  buildSamplingReport,
  evaluateFalseAlarmCalibration,
  evaluateProductionSamplingReport,
  executableContractReportPath,
  productionSamplingReportPath,
  relationRegistryPath,
  samplingAttestationSourcePath,
  samplingPlanPath,
  samplingReportPasses,
  samplingSchemaCatalogPath,
  sha256,
  validateSamplingPlan,
  verifySamplingAttestationPins,
  xorshift32,
} from './algorithm_relation_domain_sampling.mjs';

function fixtures() {
  const plan = JSON.parse(readFileSync(samplingPlanPath, 'utf8'));
  const registry = JSON.parse(readFileSync(relationRegistryPath, 'utf8'));
  const executableReport = JSON.parse(
    readFileSync(executableContractReportPath, 'utf8'),
  );
  const productionSamplingReport = JSON.parse(
    readFileSync(productionSamplingReportPath, 'utf8'),
  );
  const schemaCatalog = JSON.parse(
    readFileSync(samplingSchemaCatalogPath, 'utf8'),
  );
  const samplerSource = readFileSync(
    'tool/algorithm_relation_domain_sampling.mjs',
  );
  return {
    plan,
    registry,
    report: buildSamplingReport({
      plan,
      registry,
      executableReport,
      productionSamplingReport,
      samplerSha256: sha256(samplerSource),
    }),
    executableReport,
    productionSamplingReport,
    schemaCatalog,
  };
}

test('sampling is deterministic and covers every declared domain partition', () => {
  const first = fixtures();
  const second = fixtures();
  assert.deepEqual(validateSamplingPlan(first.plan, first.registry), []);
  assert.equal(first.report.schema, REPORT_SCHEMA);
  assert.equal(first.report.schema_version, REPORT_SCHEMA_VERSION);
  assert.equal(first.report.passed, true);
  assert.equal(first.report.relation_count, 8);
  assert.equal(first.report.relation_passed_count, 8);
  assert.equal(first.report.case_count, 160);
  assert.equal(first.report.precondition_hold_count, 64);
  assert.equal(first.report.production_api_case_count, 96);
  assert.equal(first.report.production_independent_evaluation_count, 96);
  assert.equal(first.report.production_relation_passed_count, 96);
  assert.equal(first.report.production_precondition_hold_count, 64);
  assert.equal(first.report.production_api_invocation_count, 624);
  assert.equal(first.report.production_anchor_relation_count, 8);
  assert.equal(first.report.report_sha256, second.report.report_sha256);
  for (const relation of first.report.relations) {
    assert.equal(relation.case_count, 20);
    assert.ok(relation.unique_input_digest_count >= 20);
    assert.deepEqual(relation.partitions, {
      normal: 4,
      boundary: 4,
      missing: 4,
      malformed: 4,
      adversarial: 4,
    });
    assert.equal(relation.precondition_hold_count, 8);
    assert.equal(relation.production_api_case_count, 12);
    assert.equal(relation.production_relation_passed_count, 12);
    assert.ok(relation.production_api_invocation_count > 0);
    assert.equal(relation.mutation_killed_count, 4);
  }
});

test('invalid inputs are held and never mislabeled as product failures', () => {
  const { report } = fixtures();
  const held = report.cases.filter(
    (entry) => entry.precondition_status === 'held',
  );
  assert.equal(held.length, 64);
  assert.ok(
    held.every(
      (entry) =>
        entry.observed_status === 'held_precondition' &&
        entry.failure_codes.length === 0 &&
        entry.production_api_executed_for_case === false &&
        entry.production_api_invocation_count === 0 &&
        entry.production_independent_status === 'held_precondition' &&
        ['missing', 'malformed'].includes(entry.partition),
    ),
  );
});

test('applicable cases execute paired production APIs before independent evaluation', () => {
  const { report } = fixtures();
  const executed = report.cases.filter(
    (entry) => entry.production_api_executed_for_case === true,
  );
  assert.equal(executed.length, 96);
  assert.ok(
    executed.every(
      (entry) =>
        entry.production_api_invocation_count > 1 &&
        entry.production_independent_status === 'relation_passed' &&
        entry.production_independent_failure_codes.length === 0 &&
        /^[0-9a-f]{64}$/.test(entry.production_source_input_sha256) &&
        /^[0-9a-f]{64}$/.test(entry.production_follow_up_output_sha256),
    ),
  );
});

test('production report tampering fails the independent oracle closed', () => {
  const { plan, registry, executableReport, productionSamplingReport } =
    fixtures();
  const tampered = structuredClone(productionSamplingReport);
  const target = tampered.cases.find(
    (entry) => entry.relation_id === 'catalog_resolution.input_permutation' &&
      entry.partition === 'normal',
  );
  target.relation_observation.reversed_top_candidate_id = 'food:tampered';
  const result = evaluateProductionSamplingReport({
    report: tampered,
    plan,
    registry,
    executableReport,
  });
  assert.ok(
    result.failures.includes('production_sampling.report_identity_drift'),
  );
  assert.ok(
    result.failures.some((entry) =>
      entry.startsWith('production_sampling.execution_contract_violated.'),
    ),
  );
});

test('reviewed mutations are killed and classifications remain enumerable', () => {
  const { report } = fixtures();
  assert.equal(report.mutation_case_count, 32);
  assert.equal(report.mutation_killed_count, 32);
  assert.equal(report.mutation_survivor_count, 0);
  assert.equal(report.equivalent_mutation_count, 0);
  assert.equal(report.unreachable_mutation_count, 0);
  assert.equal(report.invalid_mutation_count, 0);
  const strata = new Set(
    report.cases
      .filter((entry) => entry.partition === 'adversarial')
      .map(
        (entry) =>
          `${entry.relation_id}:${entry.mutation_id}:${entry.partition}:${entry.seed}`,
      ),
  );
  assert.equal(strata.size, 32);
});

test('defective relations expose false alarms or surviving mutations', () => {
  const { report } = fixtures();
  assert.equal(report.false_relation_fixture_count, 3);
  assert.equal(report.false_relation_rejected_count, 3);
  assert.equal(report.false_alarm_count, 96);
  assert.equal(report.false_alarm_denominator, 128);
  assert.equal(report.false_alarm_rate, 0.75);
  assert.equal(report.false_alarm_calibration_passed, true);
  assert.deepEqual(report.defective_relation_calibration_policy, {
    schema: DEFECTIVE_RELATION_CALIBRATION_POLICY.schema,
    scope: DEFECTIVE_RELATION_CALIBRATION_POLICY.scope,
    metric_kind: DEFECTIVE_RELATION_CALIBRATION_POLICY.metricKind,
    production_false_positive_rate_status:
      DEFECTIVE_RELATION_CALIBRATION_POLICY.productionFalsePositiveRateStatus,
    clinical_error_rate_status:
      DEFECTIVE_RELATION_CALIBRATION_POLICY.clinicalErrorRateStatus,
    decision_rule: DEFECTIVE_RELATION_CALIBRATION_POLICY.decisionRule,
  });
  assert.deepEqual(evaluateFalseAlarmCalibration(report), []);
  assert.equal(samplingReportPasses(report), true);
  const byClass = new Map(
    report.false_relation_fixtures.map((entry) => [entry.class, entry]),
  );
  assert.ok(byClass.get('over_broad').false_alarm_count > 0);
  assert.ok(byClass.get('under_specified').mutation_survivor_count > 0);
  assert.equal(
    byClass.get('contradictory').false_alarm_count,
    byClass.get('contradictory').evaluated_case_count,
  );
});

test('locked defective-relation calibration fails closed on count and denominator drift', () => {
  const { report } = fixtures();
  const mutations = [
    [
      'count',
      (candidate) => {
        candidate.false_alarm_count = 95;
      },
    ],
    [
      'denominator',
      (candidate) => {
        candidate.false_alarm_denominator = 127;
      },
    ],
    [
      'negative',
      (candidate) => {
        candidate.false_alarm_count = -1;
      },
    ],
    [
      'non_integer',
      (candidate) => {
        candidate.false_alarm_count = 95.5;
      },
    ],
    [
      'missing',
      (candidate) => {
        delete candidate.false_alarm_count;
      },
    ],
    [
      'greater_than_denominator',
      (candidate) => {
        candidate.false_alarm_count = 129;
      },
    ],
    [
      'forged_rate',
      (candidate) => {
        candidate.false_alarm_count = 95;
        candidate.false_alarm_rate = 0.75;
      },
    ],
    [
      'over_broad_fixture',
      (candidate) => {
        candidate.false_relation_fixtures.find(
          (entry) => entry.class === 'over_broad',
        ).false_alarm_count = 31;
        candidate.false_alarm_count = 95;
        candidate.false_alarm_rate = 95 / 128;
      },
    ],
  ];
  for (const [name, mutate] of mutations) {
    const candidate = structuredClone(report);
    mutate(candidate);
    assert.notDeepEqual(evaluateFalseAlarmCalibration(candidate), [], name);
    assert.equal(samplingReportPasses(candidate), false, name);
  }
});

test('sampling plan mutations fail closed', () => {
  const { plan, registry } = fixtures();
  const realData = structuredClone(plan);
  realData.generator.realHealthDataAllowed = true;
  assert.ok(
    validateSamplingPlan(realData, registry).includes(
      'sampling_plan.generator_boundary_invalid',
    ),
  );
  const missingPartition = structuredClone(plan);
  missingPartition.partitions.pop();
  assert.ok(
    validateSamplingPlan(missingPartition, registry).includes(
      'sampling_plan.partition_contract_invalid',
    ),
  );
  const duplicateSeed = structuredClone(plan);
  duplicateSeed.relations[0].seeds[1] = duplicateSeed.relations[0].seeds[0];
  assert.ok(
    validateSamplingPlan(duplicateSeed, registry).some((entry) =>
      entry.startsWith('sampling_plan.generator_profile_invalid'),
    ),
  );
});

test('xorshift and committed attestation identities are byte stable', () => {
  const first = xorshift32(2026083101);
  const second = xorshift32(2026083101);
  assert.deepEqual(
    [first(), first(), first(), first()],
    [second(), second(), second(), second()],
  );
  const { report, schemaCatalog } = fixtures();
  const source = readFileSync(samplingAttestationSourcePath, 'utf8');
  assert.deepEqual(
    verifySamplingAttestationPins(report, source, schemaCatalog),
    [],
  );
  const stale = source.replace(report.plan_sha256, '0'.repeat(64));
  assert.deepEqual(
    verifySamplingAttestationPins(report, stale, schemaCatalog),
    ['attestation.plan_pin_drift'],
  );
});

test('report, Dart attestation, and schema catalog agree on report schema v2', () => {
  const { report, schemaCatalog } = fixtures();
  const source = readFileSync(samplingAttestationSourcePath, 'utf8');

  for (const version of [1, 3]) {
    const candidate = structuredClone(report);
    candidate.schema_version = version;
    assert.ok(
      verifySamplingAttestationPins(candidate, source, schemaCatalog).includes(
        'sampling.report_schema_unsupported',
      ),
    );
  }
  const staleDartVersion = source.replace(
    'algorithmRelationDomainSamplingReportSchemaVersion = 2',
    'algorithmRelationDomainSamplingReportSchemaVersion = 1',
  );
  assert.ok(
    verifySamplingAttestationPins(
      report,
      staleDartVersion,
      schemaCatalog,
    ).includes('attestation.report_schema_version_drift'),
  );
  const staleDartUri = source.replace(REPORT_SCHEMA, `${REPORT_SCHEMA}.stale`);
  assert.ok(
    verifySamplingAttestationPins(
      report,
      staleDartUri,
      schemaCatalog,
    ).includes('attestation.report_schema_uri_drift'),
  );
  const stalePolicyUri = source.replace(
    DEFECTIVE_RELATION_CALIBRATION_POLICY.schema,
    `${DEFECTIVE_RELATION_CALIBRATION_POLICY.schema}.stale`,
  );
  assert.ok(
    verifySamplingAttestationPins(
      report,
      stalePolicyUri,
      schemaCatalog,
    ).includes('attestation.calibration_policy_schema_uri_drift'),
  );
  const staleCatalog = structuredClone(schemaCatalog);
  staleCatalog.schemas.find(
    (entry) => entry.id === REPORT_SCHEMA.replace(/\/\d+$/, ''),
  ).currentVersion = 1;
  assert.ok(
    verifySamplingAttestationPins(report, source, staleCatalog).includes(
      'attestation.report_schema_catalog_drift',
    ),
  );
  const stalePolicyCatalog = structuredClone(schemaCatalog);
  stalePolicyCatalog.schemas.find(
    (entry) =>
      entry.id ===
      DEFECTIVE_RELATION_CALIBRATION_POLICY.schema.replace(/\/\d+$/, ''),
  ).currentVersion = 2;
  assert.ok(
    verifySamplingAttestationPins(
      report,
      source,
      stalePolicyCatalog,
    ).includes('attestation.calibration_policy_schema_catalog_drift'),
  );
});
