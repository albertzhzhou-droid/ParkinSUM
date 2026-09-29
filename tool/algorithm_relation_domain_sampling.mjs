#!/usr/bin/env node

import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import {
  applyJsonPointerMutation,
  canonicalJson,
  evaluateRelation,
  sha256,
  validateRegistry,
} from './independent_algorithm_contract_oracle.mjs';

export { sha256 };

export const samplingPlanPath =
  'config/algorithm_relation_domain_sampling_plan.json';
export const relationRegistryPath =
  'config/algorithm_contract_relation_registry.json';
export const executableContractReportPath =
  'build/algorithm_executable_contract/latest.json';
export const productionSamplingReportPath =
  'build/algorithm_relation_production_sampling/latest.json';
export const samplingOutputPath =
  'build/algorithm_relation_domain_sampling/latest.json';
export const samplingAttestationSourcePath =
  'lib/domain/entities/algorithm_relation_domain_sampling_attestation.dart';
export const samplingSchemaCatalogPath = 'config/schema_catalog.json';

const PLAN_SCHEMA = 'parkinsum.algorithm-relation-domain-sampling-plan/2';
export const REPORT_SCHEMA =
  'parkinsum.algorithm-relation-domain-sampling-report/2';
export const REPORT_SCHEMA_VERSION = 2;
const PRODUCTION_REPORT_SCHEMA =
  'parkinsum.algorithm-relation-production-sampling-report/1';
export const DEFECTIVE_RELATION_CALIBRATION_POLICY = Object.freeze({
  schema: 'parkinsum.defective-relation-calibration-policy/1',
  scope: 'deliberately_defective_relation_fixture_decisions',
  metricKind: 'defective_relation_diagnostic_exposure',
  expectedFixtureCount: 3,
  expectedRejectedCount: 3,
  expectedExposureCount: 96,
  expectedApplicableDecisionCount: 128,
  expectedRateNumerator: 3,
  expectedRateDenominator: 4,
  productionFalsePositiveRateStatus: 'not_estimated',
  clinicalErrorRateStatus: 'not_applicable',
  decisionRule:
    'reject_each_fixture_on_its_declared_failure_mode_and_match_locked_aggregate',
});
const REQUIRED_PARTITIONS = [
  'normal',
  'boundary',
  'missing',
  'malformed',
  'adversarial',
];

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function isNonNegativeInteger(value) {
  return Number.isSafeInteger(value) && value >= 0;
}

function clone(value) {
  return structuredClone(value);
}

function rotate(values, amount) {
  if (!Array.isArray(values) || values.length < 2) return values;
  const offset = amount % values.length;
  return [...values.slice(offset), ...values.slice(0, offset)];
}

export function xorshift32(seed) {
  let state = seed >>> 0;
  return () => {
    state ^= state << 13;
    state ^= state >>> 17;
    state ^= state << 5;
    return state >>> 0;
  };
}

export function validateSamplingPlan(plan, registry) {
  const failures = [];
  if (!isObject(plan)) return ['sampling_plan.not_object'];
  if (plan.$schema !== PLAN_SCHEMA || plan.schemaVersion !== 2) {
    failures.push('sampling_plan.schema_unsupported');
  }
  if (
    !isObject(plan.generator) ||
    plan.generator.algorithm !== 'xorshift32' ||
    plan.generator.executionLayer !==
      'dart-production-api-plus-independent-observation-ir' ||
    plan.generator.realHealthDataAllowed !== false
  ) {
    failures.push('sampling_plan.generator_boundary_invalid');
  }
  if (
    canonicalJson(plan.partitions) !== canonicalJson(REQUIRED_PARTITIONS) ||
    plan.invalidInputDisposition !== 'held_precondition_not_product_failure'
  ) {
    failures.push('sampling_plan.partition_contract_invalid');
  }
  if (
    typeof plan.boundary !== 'string' ||
    !plan.boundary.includes(
      'do not establish exhaustive production-domain coverage',
    )
  ) {
    failures.push('sampling_plan.boundary_missing');
  }
  const registryIds = (registry.relations ?? []).map((entry) => entry.id).sort();
  const profiles = Array.isArray(plan.relations) ? plan.relations : [];
  const planIds = profiles.map((entry) => entry?.relationId).sort();
  if (canonicalJson(registryIds) !== canonicalJson(planIds)) {
    failures.push('sampling_plan.relation_membership_drift');
  }
  for (const profile of profiles) {
    const id = profile?.relationId ?? 'unknown';
    if (
      typeof profile?.generatorId !== 'string' ||
      typeof profile?.generatorVersion !== 'string' ||
      !Array.isArray(profile?.seeds) ||
      profile.seeds.length !== 4 ||
      new Set(profile.seeds).size !== profile.seeds.length ||
      !profile.seeds.every(Number.isSafeInteger)
    ) {
      failures.push(`sampling_plan.generator_profile_invalid.${id}`);
    }
    for (const field of [
      'precondition',
      'preconditionBoundary',
      'shrinkStrategy',
    ]) {
      if (typeof profile?.[field] !== 'string' || profile[field].trim() === '') {
        failures.push(`sampling_plan.${field}_missing.${id}`);
      }
    }
    if (profile?.minimumDiversityBudget !== 20) {
      failures.push(`sampling_plan.diversity_budget_invalid.${id}`);
    }
  }
  const falseClasses = new Set(
    (plan.falseRelationFixtures ?? []).map((entry) => entry?.class),
  );
  for (const required of ['over_broad', 'under_specified', 'contradictory']) {
    if (!falseClasses.has(required)) {
      failures.push(`sampling_plan.false_relation_missing.${required}`);
    }
  }
  return [...new Set(failures)].sort();
}

function isSha256(value) {
  return typeof value === 'string' && /^[0-9a-f]{64}$/.test(value);
}

export function evaluateProductionSamplingReport({
  report,
  plan,
  registry,
  executableReport,
}) {
  const failures = [];
  const evaluations = new Map();
  if (!isObject(report)) {
    return { failures: ['production_sampling.report_not_object'], evaluations };
  }
  if (
    report.schema !== PRODUCTION_REPORT_SCHEMA ||
    report.schema_version !== 1 ||
    report.passed !== true
  ) {
    failures.push('production_sampling.report_invalid');
  }
  if (
    report.plan_sha256 !== sha256(plan) ||
    report.relation_registry_sha256 !== sha256(registry)
  ) {
    failures.push('production_sampling.input_identity_drift');
  }
  if (
    report.configuration_sha256 !== executableReport.configuration_sha256 ||
    report.source_bundle_sha256 !== executableReport.source_bundle_sha256
  ) {
    failures.push('production_sampling.production_identity_drift');
  }
  if (
    !isSha256(report.runner_sha256) ||
    !isSha256(report.executor_sha256) ||
    !isSha256(report.report_sha256)
  ) {
    failures.push('production_sampling.evidence_identity_invalid');
  } else {
    const { report_sha256: declaredReportSha256, ...unsignedReport } = report;
    if (declaredReportSha256 !== sha256(unsignedReport)) {
      failures.push('production_sampling.report_identity_drift');
    }
  }
  if (
    report.relation_count !== 8 ||
    report.relation_passed_count !== 8 ||
    report.case_count !== 160 ||
    report.production_api_case_count !== 96 ||
    report.paired_production_execution_count !== 96 ||
    report.precondition_hold_count !== 64 ||
    !(report.production_api_invocation_count > 0) ||
    report.independent_relation_evaluation_count !== 0 ||
    report.real_health_data_used !== false
  ) {
    failures.push('production_sampling.aggregate_contract_drift');
  }
  const relationsById = new Map(
    (registry.relations ?? []).map((entry) => [entry.id, entry]),
  );
  const cases = Array.isArray(report.cases) ? report.cases : [];
  if (cases.length !== 160) failures.push('production_sampling.case_count_drift');
  const caseIds = new Set();
  for (const entry of cases) {
    const id = entry?.id ?? 'unknown';
    if (caseIds.has(id)) failures.push(`production_sampling.case_duplicate.${id}`);
    caseIds.add(id);
    const relation = relationsById.get(entry?.relation_id);
    if (!relation || !REQUIRED_PARTITIONS.includes(entry?.partition)) {
      failures.push(`production_sampling.case_membership_invalid.${id}`);
      continue;
    }
    const held = ['missing', 'malformed'].includes(entry.partition);
    const invocationCount = entry.production_api_invocation_count;
    if (held) {
      if (
        entry.precondition_status !== 'held' ||
        entry.production_api_executed_for_case !== false ||
        invocationCount !== 0 ||
        entry.execution_status !== 'held_precondition' ||
        entry.relation_observation !== null
      ) {
        failures.push(`production_sampling.hold_contract_violated.${id}`);
      }
      evaluations.set(id, {
        status: 'held_precondition',
        failure_codes: [],
      });
      continue;
    }
    const observation = entry.relation_observation;
    const identityFields = [
      entry.source_input_sha256,
      entry.follow_up_input_sha256,
      entry.source_output_sha256,
      entry.follow_up_output_sha256,
      entry.relation_observation_sha256,
    ];
    if (
      entry.precondition_status !== 'met' ||
      entry.production_api_executed_for_case !== true ||
      !(entry.source_api_invocation_count > 0) ||
      !(entry.follow_up_api_invocation_count > 0) ||
      !(invocationCount > 1) ||
      entry.execution_status !== 'executed_pending_independent_oracle' ||
      !isObject(observation) ||
      !identityFields.every(isSha256) ||
      entry.relation_observation_sha256 !== sha256(observation)
    ) {
      failures.push(`production_sampling.execution_contract_violated.${id}`);
      evaluations.set(id, {
        status: 'failed_execution_contract',
        failure_codes: ['oracle.production_execution_contract_invalid'],
      });
      continue;
    }
    const relationFailures = evaluateRelation(relation, observation);
    const status = relationFailures.length === 0
      ? 'relation_passed'
      : 'relation_failed';
    evaluations.set(id, {
      status,
      failure_codes: relationFailures,
    });
    if (relationFailures.length > 0) {
      failures.push(`production_sampling.relation_failed.${id}`);
    }
  }
  return {
    failures: [...new Set(failures)].sort(),
    evaluations,
  };
}

function safeBoundaryObservation(relation, base, seed) {
  const output = clone(base);
  const random = xorshift32(seed);
  const token = random() % 100000;
  switch (relation.evaluator) {
    case 'equal_sorted_paths_and_missing_fields':
      output.forward_paths = rotate(output.forward_paths, 1);
      output.reversed_missing_fields = rotate(
        output.reversed_missing_fields,
        1,
      );
      break;
    case 'catalog_permutation_and_abstention':
      output.forward_top_candidate_id = `food:synthetic.sample.${token}`;
      output.reversed_top_candidate_id = output.forward_top_candidate_id;
      break;
    case 'strict_authority_order_and_conflict': {
      const delta = (token % 20) / 1000;
      output.official_exact_score = 0.98 - delta;
      output.official_foreign_score = 0.58 - delta;
      output.synthetic_score = 0.08 - delta / 2;
      break;
    }
    case 'jurisdiction_prefix_and_equivalent_fire_count':
      output.jurisdiction_chain = [
        output.jurisdiction_chain[0],
        `SYNTHETIC_REGION_${token}`,
        ...output.jurisdiction_chain.slice(1),
      ];
      output.mg_rule_ids = [`contract.sample.${token}.mg`];
      output.gram_rule_ids = [`contract.sample.${token}.g`];
      break;
    case 'valid_compile_and_missing_identity_rejection':
      output.valid_rule_id = `synthetic.sample.${token}`;
      break;
    case 'fact_order_and_scope_preservation':
      output.sampling_scope_token = `synthetic.scope.${token}`;
      break;
    case 'recommendation_set_and_fallback_preservation':
      output.ranking_pairs = output.ranking_pairs.map((pair, index) => ({
        ...pair,
        observed_ranking: rotate(pair.observed_ranking, (token + index) % 3),
      }));
      break;
    case 'local_ai_whitelist_consent_and_endpoint_confinement':
      output.hybrid_ranking_pairs = output.hybrid_ranking_pairs.map(
        (pair, index) => ({
          ...pair,
          observed_ranking: rotate(pair.observed_ranking, (token + index) % 3),
        }),
      );
      break;
    default:
      throw new Error(`unsupported boundary generator ${relation.evaluator}`);
  }
  return output;
}

function generatedCase({ relation, profile, base, partition, seed, seedIndex }) {
  const sourceInput = {
    relation_id: relation.id,
    generator_id: profile.generatorId,
    generator_version: profile.generatorVersion,
    partition,
    seed,
    synthetic: true,
  };
  let observation = clone(base);
  let expected = 'relation_passed';
  let precondition = 'met';
  let mutationId = null;
  let transformation = 'identity';
  if (partition === 'boundary') {
    transformation = 'valid_boundary_permutation';
    observation = safeBoundaryObservation(relation, base, seed);
  } else if (partition === 'missing') {
    transformation = 'remove_required_observation_key';
    delete observation[relation.observationRequiredKeys[0]];
    expected = 'held_precondition';
    precondition = 'held';
  } else if (partition === 'malformed') {
    transformation = 'malform_required_observation_key';
    observation[relation.observationRequiredKeys[0]] = null;
    expected = 'held_precondition';
    precondition = 'held';
  } else if (partition === 'adversarial') {
    const mutation = relation.mutationOperators[
      seedIndex % relation.mutationOperators.length
    ];
    mutationId = mutation.id;
    transformation = `reviewed_mutation:${mutation.id}`;
    observation = applyJsonPointerMutation(base, mutation);
    expected = 'mutation_killed';
  }
  const failures = precondition === 'held'
    ? []
    : evaluateRelation(relation, observation);
  const status = precondition === 'held'
    ? 'held_precondition'
    : failures.length === 0
      ? 'relation_passed'
      : 'mutation_killed';
  const shrinkPath = status === 'mutation_killed'
    ? [transformation, profile.shrinkStrategy]
    : [];
  return {
    id: `${relation.id}.${partition}.${seed}`,
    relation_id: relation.id,
    algorithm_id: relation.algorithmId,
    generator_id: profile.generatorId,
    generator_version: profile.generatorVersion,
    seed,
    partition,
    synthetic: true,
    production_api_executed_for_case: false,
    source_input_sha256: sha256(sourceInput),
    follow_up_input_sha256: sha256({ ...sourceInput, transformation }),
    transformation,
    mutation_id: mutationId,
    source_output_sha256: sha256(base),
    follow_up_output_sha256: sha256(observation),
    precondition_status: precondition,
    expected_status: expected,
    observed_status: status,
    failure_codes: failures,
    shrink_path: shrinkPath,
  };
}

function falseRelationResults(cases, relationsById) {
  const validCases = cases.filter((entry) =>
    ['normal', 'boundary'].includes(entry.partition),
  );
  const adversarialCases = cases.filter(
    (entry) => entry.partition === 'adversarial',
  );
  const overBroadFalseAlarms = validCases.filter(
    (entry) => entry.source_output_sha256 !== entry.follow_up_output_sha256,
  ).length;
  const contradictoryFalseAlarms = validCases.length;
  const underSpecifiedSurvivors = adversarialCases.filter((entry) => {
    const relation = relationsById.get(entry.relation_id);
    return relation.observationRequiredKeys.length > 0;
  }).length;
  return [
    {
      id: 'over_broad.deep_equality',
      class: 'over_broad',
      evaluated_case_count: validCases.length,
      false_alarm_count: overBroadFalseAlarms,
      mutation_survivor_count: 0,
      status: overBroadFalseAlarms > 0 ? 'rejected' : 'accepted_in_error',
    },
    {
      id: 'under_specified.shape_only',
      class: 'under_specified',
      evaluated_case_count: adversarialCases.length,
      false_alarm_count: 0,
      mutation_survivor_count: underSpecifiedSurvivors,
      status: underSpecifiedSurvivors > 0 ? 'rejected' : 'accepted_in_error',
    },
    {
      id: 'contradictory.always_fail',
      class: 'contradictory',
      evaluated_case_count: validCases.length,
      false_alarm_count: contradictoryFalseAlarms,
      mutation_survivor_count: 0,
      status:
        contradictoryFalseAlarms === validCases.length
          ? 'rejected'
          : 'accepted_in_error',
    },
  ];
}

export function evaluateFalseAlarmCalibration(report) {
  const failures = [];
  const policy = report?.defective_relation_calibration_policy;
  const expectedPolicy = DEFECTIVE_RELATION_CALIBRATION_POLICY;
  if (
    !isObject(policy) ||
    policy.schema !== expectedPolicy.schema ||
    policy.scope !== expectedPolicy.scope ||
    policy.metric_kind !== expectedPolicy.metricKind ||
    policy.production_false_positive_rate_status !==
      expectedPolicy.productionFalsePositiveRateStatus ||
    policy.clinical_error_rate_status !==
      expectedPolicy.clinicalErrorRateStatus ||
    policy.decision_rule !== expectedPolicy.decisionRule
  ) {
    failures.push('sampling.false_alarm_calibration_policy_drift');
  }

  const fixtures = Array.isArray(report?.false_relation_fixtures)
    ? report.false_relation_fixtures
    : [];
  const byClass = new Map();
  for (const fixture of fixtures) {
    const fixtureClass = fixture?.class;
    if (typeof fixtureClass !== 'string' || byClass.has(fixtureClass)) {
      failures.push('sampling.false_alarm_fixture_membership_drift');
      continue;
    }
    byClass.set(fixtureClass, fixture);
    if (
      !isNonNegativeInteger(fixture?.evaluated_case_count) ||
      !isNonNegativeInteger(fixture?.false_alarm_count) ||
      !isNonNegativeInteger(fixture?.mutation_survivor_count) ||
      fixture.false_alarm_count > fixture.evaluated_case_count ||
      fixture.mutation_survivor_count > fixture.evaluated_case_count
    ) {
      failures.push(
        `sampling.false_alarm_fixture_count_invalid.${fixtureClass}`,
      );
    }
  }

  const expectedClasses = ['over_broad', 'under_specified', 'contradictory'];
  if (
    fixtures.length !== expectedPolicy.expectedFixtureCount ||
    byClass.size !== expectedClasses.length ||
    expectedClasses.some((fixtureClass) => !byClass.has(fixtureClass)) ||
    [...byClass.keys()].some(
      (fixtureClass) => !expectedClasses.includes(fixtureClass),
    )
  ) {
    failures.push('sampling.false_alarm_fixture_membership_drift');
  }

  const overBroad = byClass.get('over_broad');
  if (
    overBroad?.id !== 'over_broad.deep_equality' ||
    overBroad?.evaluated_case_count !== 64 ||
    overBroad?.false_alarm_count !== 32 ||
    overBroad?.mutation_survivor_count !== 0 ||
    overBroad?.status !== 'rejected'
  ) {
    failures.push('sampling.false_alarm_over_broad_contract_drift');
  }
  const underSpecified = byClass.get('under_specified');
  if (
    underSpecified?.id !== 'under_specified.shape_only' ||
    underSpecified?.evaluated_case_count !== 32 ||
    underSpecified?.false_alarm_count !== 0 ||
    underSpecified?.mutation_survivor_count !== 32 ||
    underSpecified?.status !== 'rejected'
  ) {
    failures.push('sampling.false_alarm_under_specified_contract_drift');
  }
  const contradictory = byClass.get('contradictory');
  if (
    contradictory?.id !== 'contradictory.always_fail' ||
    contradictory?.evaluated_case_count !== 64 ||
    contradictory?.false_alarm_count !== 64 ||
    contradictory?.mutation_survivor_count !== 0 ||
    contradictory?.status !== 'rejected'
  ) {
    failures.push('sampling.false_alarm_contradictory_contract_drift');
  }

  const computedExposureCount = fixtures.reduce(
    (sum, fixture) =>
      sum +
      (isNonNegativeInteger(fixture?.false_alarm_count)
        ? fixture.false_alarm_count
        : 0),
    0,
  );
  const computedApplicableDecisionCount = fixtures.reduce(
    (sum, fixture) =>
      sum +
      (fixture?.class !== 'under_specified' &&
      isNonNegativeInteger(fixture?.evaluated_case_count)
        ? fixture.evaluated_case_count
        : 0),
    0,
  );
  const computedRejectedCount = fixtures.filter(
    (fixture) => fixture?.status === 'rejected',
  ).length;
  if (
    !isNonNegativeInteger(report?.false_relation_fixture_count) ||
    !isNonNegativeInteger(report?.false_relation_rejected_count) ||
    !isNonNegativeInteger(report?.false_alarm_count) ||
    !Number.isSafeInteger(report?.false_alarm_denominator) ||
    report.false_alarm_denominator <= 0 ||
    report.false_alarm_count > report.false_alarm_denominator ||
    report.false_relation_fixture_count !== fixtures.length ||
    report.false_relation_rejected_count !== computedRejectedCount ||
    report.false_alarm_count !== computedExposureCount ||
    report.false_alarm_denominator !== computedApplicableDecisionCount
  ) {
    failures.push('sampling.false_alarm_calibration_aggregate_drift');
  }
  if (
    report?.false_relation_fixture_count !==
      expectedPolicy.expectedFixtureCount ||
    report?.false_relation_rejected_count !==
      expectedPolicy.expectedRejectedCount ||
    report?.false_alarm_count !== expectedPolicy.expectedExposureCount ||
    report?.false_alarm_denominator !==
      expectedPolicy.expectedApplicableDecisionCount
  ) {
    failures.push('sampling.false_alarm_calibration_locked_fixture_drift');
  }
  const recomputedRate =
    isNonNegativeInteger(report?.false_alarm_count) &&
    Number.isSafeInteger(report?.false_alarm_denominator) &&
    report.false_alarm_denominator > 0
      ? report.false_alarm_count / report.false_alarm_denominator
      : null;
  if (
    typeof report?.false_alarm_rate !== 'number' ||
    !Number.isFinite(report.false_alarm_rate) ||
    report.false_alarm_rate !== recomputedRate ||
    report.false_alarm_rate !==
      expectedPolicy.expectedRateNumerator /
        expectedPolicy.expectedRateDenominator
  ) {
    failures.push('sampling.false_alarm_calibration_rate_drift');
  }
  return [...new Set(failures)].sort();
}

export function samplingReportPasses(report) {
  return (
    Array.isArray(report?.integrity_failure_codes) &&
    report.integrity_failure_codes.length === 0 &&
    report.relation_count === 8 &&
    report.relation_passed_count === 8 &&
    report.case_count === 160 &&
    report.precondition_hold_count === 64 &&
    report.production_api_case_count === 96 &&
    report.production_independent_evaluation_count === 96 &&
    report.production_relation_passed_count === 96 &&
    report.production_precondition_hold_count === 64 &&
    report.production_api_invocation_count > 0 &&
    report.mutation_case_count === 32 &&
    report.mutation_survivor_count === 0 &&
    report.false_relation_rejected_count ===
      report.false_relation_fixture_count &&
    evaluateFalseAlarmCalibration(report).length === 0
  );
}

export function buildSamplingReport({
  plan,
  registry,
  executableReport,
  productionSamplingReport,
  samplerSha256,
}) {
  const integrityFailures = [
    ...validateRegistry(registry),
    ...validateSamplingPlan(plan, registry),
  ];
  if (
    executableReport?.schema !==
      'parkinsum.algorithm-executable-contract-report/1' ||
    executableReport?.schema_version !== 1 ||
    executableReport?.passed !== true
  ) {
    integrityFailures.push('sampling.production_anchor_invalid');
  }
  const productionEvaluation = evaluateProductionSamplingReport({
    report: productionSamplingReport,
    plan,
    registry,
    executableReport,
  });
  integrityFailures.push(...productionEvaluation.failures);
  const relationsById = new Map(
    registry.relations.map((entry) => [entry.id, entry]),
  );
  const observationsById = new Map(
    (executableReport.checks ?? []).map((entry) => [
      entry.spec.id,
      entry.observation,
    ]),
  );
  const cases = [];
  for (const profile of plan.relations ?? []) {
    const relation = relationsById.get(profile.relationId);
    const base = observationsById.get(profile.relationId);
    if (!relation || !base) continue;
    for (const partition of REQUIRED_PARTITIONS) {
      for (const [seedIndex, seed] of profile.seeds.entries()) {
        cases.push(
          generatedCase({
            relation,
            profile,
            base,
            partition,
            seed,
            seedIndex,
          }),
        );
      }
    }
  }
  const productionCasesById = new Map(
    (productionSamplingReport?.cases ?? []).map((entry) => [entry.id, entry]),
  );
  for (const entry of cases) {
    const productionCase = productionCasesById.get(entry.id);
    const evaluation = productionEvaluation.evaluations.get(entry.id);
    if (!productionCase || !evaluation) {
      integrityFailures.push(`sampling.production_case_missing.${entry.id}`);
      continue;
    }
    entry.production_api_executed_for_case =
      productionCase.production_api_executed_for_case;
    entry.production_api_invocation_count =
      productionCase.production_api_invocation_count;
    entry.production_source_input_sha256 =
      productionCase.source_input_sha256;
    entry.production_follow_up_input_sha256 =
      productionCase.follow_up_input_sha256;
    entry.production_source_output_sha256 =
      productionCase.source_output_sha256;
    entry.production_follow_up_output_sha256 =
      productionCase.follow_up_output_sha256;
    entry.production_relation_observation_sha256 =
      productionCase.relation_observation_sha256 ?? null;
    entry.production_independent_status = evaluation.status;
    entry.production_independent_failure_codes = evaluation.failure_codes;
  }
  for (const entry of cases) {
    if (entry.observed_status !== entry.expected_status) {
      integrityFailures.push(`sampling.case_status_mismatch.${entry.id}`);
    }
  }
  const relationSummaries = (plan.relations ?? []).map((profile) => {
    const relationCases = cases.filter(
      (entry) => entry.relation_id === profile.relationId,
    );
    const partitions = Object.fromEntries(
      REQUIRED_PARTITIONS.map((partition) => [
        partition,
        relationCases.filter((entry) => entry.partition === partition).length,
      ]),
    );
    const uniqueInputs = new Set(
      relationCases.flatMap((entry) => [
        entry.source_input_sha256,
        entry.follow_up_input_sha256,
      ]),
    ).size;
    const passed =
      relationCases.length === profile.minimumDiversityBudget &&
      uniqueInputs >= profile.minimumDiversityBudget &&
      REQUIRED_PARTITIONS.every((partition) => partitions[partition] === 4);
    if (!passed) {
      integrityFailures.push(
        `sampling.relation_diversity_incomplete.${profile.relationId}`,
      );
    }
    return {
      relation_id: profile.relationId,
      generator_id: profile.generatorId,
      generator_version: profile.generatorVersion,
      case_count: relationCases.length,
      unique_input_digest_count: uniqueInputs,
      partitions,
      precondition_hold_count: relationCases.filter(
        (entry) => entry.precondition_status === 'held',
      ).length,
      production_api_case_count: relationCases.filter(
        (entry) => entry.production_api_executed_for_case === true,
      ).length,
      production_api_invocation_count: relationCases.reduce(
        (sum, entry) => sum + (entry.production_api_invocation_count ?? 0),
        0,
      ),
      production_relation_passed_count: relationCases.filter(
        (entry) => entry.production_independent_status === 'relation_passed',
      ).length,
      mutation_killed_count: relationCases.filter(
        (entry) => entry.observed_status === 'mutation_killed',
      ).length,
      passed,
    };
  });
  const falseRelations = falseRelationResults(cases, relationsById);
  const falseRelationRejected = falseRelations.filter(
    (entry) => entry.status === 'rejected',
  ).length;
  const falseAlarmCount = falseRelations.reduce(
    (sum, entry) => sum + entry.false_alarm_count,
    0,
  );
  const falseAlarmDenominator = falseRelations.reduce(
    (sum, entry) =>
      sum +
      (entry.class === 'under_specified' ? 0 : entry.evaluated_case_count),
    0,
  );
  const preconditionHolds = cases.filter(
    (entry) => entry.precondition_status === 'held',
  ).length;
  const mutations = cases.filter((entry) => entry.partition === 'adversarial');
  const killed = mutations.filter(
    (entry) => entry.observed_status === 'mutation_killed',
  ).length;
  const productionApiCases = cases.filter(
    (entry) => entry.production_api_executed_for_case === true,
  );
  const productionRelationPassed = productionApiCases.filter(
    (entry) => entry.production_independent_status === 'relation_passed',
  ).length;
  const reportWithoutDigest = {
    schema: REPORT_SCHEMA,
    schema_version: REPORT_SCHEMA_VERSION,
    plan_sha256: sha256(plan),
    relation_registry_sha256: sha256(registry),
    sampler_sha256: samplerSha256,
    production_anchor_report_sha256: sha256(executableReport),
    production_execution_report_sha256: productionSamplingReport?.report_sha256,
    production_execution_runner_sha256: productionSamplingReport?.runner_sha256,
    production_executor_sha256: productionSamplingReport?.executor_sha256,
    executable_contract_specification_sha256:
      executableReport.specification_sha256,
    configuration_sha256: executableReport.configuration_sha256,
    source_bundle_sha256: executableReport.source_bundle_sha256,
    generator_id: plan.generator.id,
    generator_version: plan.generator.version,
    execution_layer: plan.generator.executionLayer,
    relation_count: relationSummaries.length,
    relation_passed_count: relationSummaries.filter((entry) => entry.passed)
      .length,
    case_count: cases.length,
    production_api_case_count: productionApiCases.length,
    production_api_invocation_count:
      productionSamplingReport?.production_api_invocation_count ?? 0,
    production_independent_evaluation_count: productionApiCases.length,
    production_relation_passed_count: productionRelationPassed,
    production_precondition_hold_count:
      productionSamplingReport?.precondition_hold_count ?? 0,
    production_anchor_relation_count: executableReport.passed_check_count ?? 0,
    precondition_hold_count: preconditionHolds,
    mutation_case_count: mutations.length,
    mutation_killed_count: killed,
    mutation_survivor_count: mutations.length - killed,
    equivalent_mutation_count: 0,
    unreachable_mutation_count: 0,
    invalid_mutation_count: 0,
    false_relation_fixture_count: falseRelations.length,
    false_relation_rejected_count: falseRelationRejected,
    false_alarm_count: falseAlarmCount,
    false_alarm_denominator: falseAlarmDenominator,
    false_alarm_rate: falseAlarmDenominator === 0
      ? null
      : falseAlarmCount / falseAlarmDenominator,
    defective_relation_calibration_policy: {
      schema: DEFECTIVE_RELATION_CALIBRATION_POLICY.schema,
      scope: DEFECTIVE_RELATION_CALIBRATION_POLICY.scope,
      metric_kind: DEFECTIVE_RELATION_CALIBRATION_POLICY.metricKind,
      production_false_positive_rate_status:
        DEFECTIVE_RELATION_CALIBRATION_POLICY.productionFalsePositiveRateStatus,
      clinical_error_rate_status:
        DEFECTIVE_RELATION_CALIBRATION_POLICY.clinicalErrorRateStatus,
      decision_rule: DEFECTIVE_RELATION_CALIBRATION_POLICY.decisionRule,
    },
    integrity_failure_codes: [...new Set(integrityFailures)].sort(),
    boundary: plan.boundary,
    relations: relationSummaries,
    false_relation_fixtures: falseRelations,
    cases,
  };
  const falseAlarmCalibrationFailures =
    evaluateFalseAlarmCalibration(reportWithoutDigest);
  reportWithoutDigest.integrity_failure_codes = [
    ...new Set([
      ...reportWithoutDigest.integrity_failure_codes,
      ...falseAlarmCalibrationFailures,
    ]),
  ].sort();
  reportWithoutDigest.false_alarm_calibration_passed =
    falseAlarmCalibrationFailures.length === 0;
  reportWithoutDigest.passed = samplingReportPasses(reportWithoutDigest);
  return {
    ...reportWithoutDigest,
    report_sha256: sha256(reportWithoutDigest),
  };
}

function readPins(source) {
  const pin = (name) => {
    const match = source.match(
      new RegExp(`static const String ${name} =\\s*'([0-9a-f]{64})'`),
    );
    return match?.[1] ?? null;
  };
  return {
    plan: pin('expectedPlanSha256'),
    registry: pin('expectedRelationRegistrySha256'),
    sampler: pin('expectedSamplerSha256'),
    anchor: pin('expectedProductionAnchorReportSha256'),
    productionReport: pin('expectedProductionExecutionReportSha256'),
    productionRunner: pin('expectedProductionExecutionRunnerSha256'),
    productionExecutor: pin('expectedProductionExecutorSha256'),
    report: pin('expectedReportSha256'),
  };
}

function readDartReportSchemaContract(source) {
  const stringMatch = source.match(
    /const String algorithmRelationDomainSamplingReportSchema\s*=\s*'([^']+)'/,
  );
  const versionMatch = source.match(
    /const int algorithmRelationDomainSamplingReportSchemaVersion\s*=\s*(\d+)\s*;/,
  );
  const calibrationPolicyMatch = source.match(
    /static const String falseAlarmCalibrationPolicySchema\s*=\s*'([^']+)'/,
  );
  return {
    schema: stringMatch?.[1] ?? null,
    version: versionMatch == null ? null : Number(versionMatch[1]),
    calibrationPolicySchema: calibrationPolicyMatch?.[1] ?? null,
  };
}

export function verifySamplingAttestationPins(report, source, schemaCatalog) {
  const pins = readPins(source);
  const failures = [];
  if (
    report?.schema !== REPORT_SCHEMA ||
    report?.schema_version !== REPORT_SCHEMA_VERSION
  ) {
    failures.push('sampling.report_schema_unsupported');
  }
  const dartContract = readDartReportSchemaContract(source);
  if (dartContract.schema !== REPORT_SCHEMA) {
    failures.push('attestation.report_schema_uri_drift');
  }
  if (dartContract.version !== REPORT_SCHEMA_VERSION) {
    failures.push('attestation.report_schema_version_drift');
  }
  if (
    dartContract.calibrationPolicySchema !==
    DEFECTIVE_RELATION_CALIBRATION_POLICY.schema
  ) {
    failures.push('attestation.calibration_policy_schema_uri_drift');
  }
  const catalogEntry = schemaCatalog?.schemas?.find(
    (entry) => entry?.id === REPORT_SCHEMA.replace(/\/\d+$/, ''),
  );
  if (
    !catalogEntry ||
    catalogEntry.currentVersion !== REPORT_SCHEMA_VERSION ||
    `${catalogEntry.id}/${catalogEntry.currentVersion}` !== REPORT_SCHEMA ||
    catalogEntry.source !== samplingAttestationSourcePath
  ) {
    failures.push('attestation.report_schema_catalog_drift');
  }
  const calibrationPolicyCatalogEntry = schemaCatalog?.schemas?.find(
    (entry) =>
      entry?.id ===
      DEFECTIVE_RELATION_CALIBRATION_POLICY.schema.replace(/\/\d+$/, ''),
  );
  if (
    !calibrationPolicyCatalogEntry ||
    `${calibrationPolicyCatalogEntry.id}/${
      calibrationPolicyCatalogEntry.currentVersion
    }` !==
      DEFECTIVE_RELATION_CALIBRATION_POLICY.schema ||
    calibrationPolicyCatalogEntry.source !== samplingAttestationSourcePath
  ) {
    failures.push('attestation.calibration_policy_schema_catalog_drift');
  }
  for (const [field, actual] of [
    ['plan', report.plan_sha256],
    ['registry', report.relation_registry_sha256],
    ['sampler', report.sampler_sha256],
    ['anchor', report.production_anchor_report_sha256],
    ['productionReport', report.production_execution_report_sha256],
    ['productionRunner', report.production_execution_runner_sha256],
    ['productionExecutor', report.production_executor_sha256],
    ['report', report.report_sha256],
  ]) {
    if (pins[field] !== actual) failures.push(`attestation.${field}_pin_drift`);
  }
  return failures;
}

function run() {
  const plan = JSON.parse(readFileSync(samplingPlanPath, 'utf8'));
  const registry = JSON.parse(readFileSync(relationRegistryPath, 'utf8'));
  const executableReport = JSON.parse(
    readFileSync(executableContractReportPath, 'utf8'),
  );
  const productionSamplingReport = JSON.parse(
    readFileSync(productionSamplingReportPath, 'utf8'),
  );
  const samplerSource = readFileSync(fileURLToPath(import.meta.url));
  const report = buildSamplingReport({
    plan,
    registry,
    executableReport,
    productionSamplingReport,
    samplerSha256: sha256(samplerSource),
  });
  const printPins = process.argv.includes('--print-pins');
  const pinFailures = printPins
    ? []
    : verifySamplingAttestationPins(
        report,
        readFileSync(samplingAttestationSourcePath, 'utf8'),
        JSON.parse(readFileSync(samplingSchemaCatalogPath, 'utf8')),
      );
  report.integrity_failure_codes = [
    ...new Set([...report.integrity_failure_codes, ...pinFailures]),
  ].sort();
  if (pinFailures.length > 0) report.passed = false;
  mkdirSync('build/algorithm_relation_domain_sampling', { recursive: true });
  writeFileSync(samplingOutputPath, `${JSON.stringify(report, null, 2)}\n`);
  console.log(
    `Algorithm relation IR sampling: ${report.relation_passed_count}/${report.relation_count} relations; ` +
      `${report.case_count} cases; holds=${report.precondition_hold_count}; ` +
      `mutations=${report.mutation_killed_count}/${report.mutation_case_count}; ` +
      `false-relations=${report.false_relation_rejected_count}/${report.false_relation_fixture_count}; ` +
      `production=${report.production_relation_passed_count}/${report.production_api_case_count} cases, ` +
      `${report.production_api_invocation_count} invocations; artifact=${samplingOutputPath}`,
  );
  if (printPins) {
    console.log(
      JSON.stringify(
        {
          expectedPlanSha256: report.plan_sha256,
          expectedRelationRegistrySha256: report.relation_registry_sha256,
          expectedSamplerSha256: report.sampler_sha256,
          expectedProductionAnchorReportSha256:
            report.production_anchor_report_sha256,
          expectedProductionExecutionReportSha256:
            report.production_execution_report_sha256,
          expectedProductionExecutionRunnerSha256:
            report.production_execution_runner_sha256,
          expectedProductionExecutorSha256:
            report.production_executor_sha256,
          expectedReportSha256: report.report_sha256,
        },
        null,
        2,
      ),
    );
  }
  if (!report.passed) {
    for (const failure of report.integrity_failure_codes) console.error(failure);
    process.exitCode = 1;
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) run();
