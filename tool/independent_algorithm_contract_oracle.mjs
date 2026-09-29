#!/usr/bin/env node

import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

export const registryPath = 'config/algorithm_contract_relation_registry.json';
export const executableReportPath =
  'build/algorithm_executable_contract/latest.json';
export const outputPath =
  'build/algorithm_contract_independent_oracle/latest.json';
export const attestationSourcePath =
  'lib/domain/entities/algorithm_contract_independent_oracle_attestation.dart';

const REPORT_SCHEMA =
  'parkinsum.algorithm-contract-independent-oracle-report/1';
const REGISTRY_SCHEMA = 'parkinsum.algorithm-contract-relation-registry/1';
const SUPPORTED_EVALUATORS = new Set([
  'equal_sorted_paths_and_missing_fields',
  'catalog_permutation_and_abstention',
  'strict_authority_order_and_conflict',
  'jurisdiction_prefix_and_equivalent_fire_count',
  'valid_compile_and_missing_identity_rejection',
  'fact_order_and_scope_preservation',
  'recommendation_set_and_fallback_preservation',
  'local_ai_whitelist_consent_and_endpoint_confinement',
]);
const TERMINAL_BLOCK_EVENTS = new Set([
  'withdraw',
  'timeout',
  'cancel',
  'capability_revoke',
]);

export function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value !== null && typeof value === 'object') {
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, canonicalize(value[key])]),
    );
  }
  return value;
}

export function canonicalJson(value) {
  return JSON.stringify(canonicalize(value));
}

export function sha256(value) {
  const bytes =
    typeof value === 'string' || Buffer.isBuffer(value)
      ? value
      : canonicalJson(value);
  return createHash('sha256').update(bytes).digest('hex');
}

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function isSha256(value) {
  return typeof value === 'string' && /^[0-9a-f]{64}$/.test(value);
}

function finiteTree(value) {
  if (typeof value === 'number') return Number.isFinite(value);
  if (Array.isArray(value)) return value.every(finiteTree);
  if (isObject(value)) return Object.values(value).every(finiteTree);
  return true;
}

function uniqueStrings(value) {
  return (
    Array.isArray(value) &&
    value.every((entry) => typeof entry === 'string') &&
    new Set(value).size === value.length
  );
}

function sameStringSet(left, right) {
  if (!uniqueStrings(left) || !uniqueStrings(right)) return false;
  return (
    left.length === right.length &&
    [...left].sort().every((entry, index) => entry === [...right].sort()[index])
  );
}

function requireKeys(observation, keys) {
  return isObject(observation) && keys.every((key) => key in observation);
}

export function validateRegistry(registry) {
  const failures = [];
  if (!isObject(registry)) return ['registry.not_object'];
  if (registry.$schema !== REGISTRY_SCHEMA || registry.schemaVersion !== 1) {
    failures.push('registry.schema_unsupported');
  }
  if (
    typeof registry.registryId !== 'string' ||
    !registry.registryId.startsWith('parkinsum.')
  ) {
    failures.push('registry.identity_invalid');
  }
  if (
    typeof registry.boundary !== 'string' ||
    !registry.boundary.includes('do not establish scientific truth')
  ) {
    failures.push('registry.boundary_missing');
  }
  const reviewed = Date.parse(registry.reviewedAtUtc);
  const expires = Date.parse(registry.expiresAtUtc);
  if (!Number.isFinite(reviewed) || !Number.isFinite(expires) || expires <= reviewed) {
    failures.push('registry.review_window_invalid');
  }
  if (!Array.isArray(registry.relations) || registry.relations.length !== 8) {
    failures.push('registry.relation_count_invalid');
    return failures;
  }
  const relationIds = new Set();
  const algorithmIds = new Set();
  const mutationIds = new Set();
  for (const relation of registry.relations) {
    if (!isObject(relation) || typeof relation.id !== 'string') {
      failures.push('registry.relation_identity_invalid');
      continue;
    }
    if (relationIds.has(relation.id)) failures.push('registry.relation_duplicate');
    relationIds.add(relation.id);
    if (typeof relation.algorithmId !== 'string') {
      failures.push(`registry.algorithm_identity_invalid.${relation.id}`);
    } else {
      if (algorithmIds.has(relation.algorithmId)) {
        failures.push(`registry.algorithm_duplicate.${relation.id}`);
      }
      algorithmIds.add(relation.algorithmId);
    }
    if (!SUPPORTED_EVALUATORS.has(relation.evaluator)) {
      failures.push(`registry.evaluator_unsupported.${relation.id}`);
    }
    for (const field of [
      'inputDomainPreconditions',
      'observationRequiredKeys',
      'sourceIds',
      'knownFalseRelationRisks',
      'mutationOperators',
    ]) {
      if (!Array.isArray(relation[field]) || relation[field].length === 0) {
        failures.push(`registry.${field}_missing.${relation.id}`);
      }
    }
    for (const field of ['transformation', 'expectedRelation', 'rationale']) {
      if (typeof relation[field] !== 'string' || relation[field].trim() === '') {
        failures.push(`registry.${field}_missing.${relation.id}`);
      }
    }
    for (const mutation of relation.mutationOperators ?? []) {
      if (
        !isObject(mutation) ||
        typeof mutation.id !== 'string' ||
        typeof mutation.target !== 'string' ||
        !mutation.target.startsWith('/') ||
        typeof mutation.class !== 'string'
      ) {
        failures.push(`registry.mutation_invalid.${relation.id}`);
        continue;
      }
      if (mutationIds.has(mutation.id)) failures.push('registry.mutation_duplicate');
      mutationIds.add(mutation.id);
    }
  }
  if (!Array.isArray(registry.schedulerCases) || registry.schedulerCases.length < 5) {
    failures.push('registry.scheduler_cases_missing');
  }
  return [...new Set(failures)].sort();
}

function evaluateRankingPairs(pairs) {
  return (
    Array.isArray(pairs) &&
    pairs.length > 0 &&
    pairs.every(
      (pair) =>
        isObject(pair) &&
        typeof pair.case_id === 'string' &&
        sameStringSet(pair.deterministic_ranking, pair.observed_ranking),
    )
  );
}

export function evaluateRelation(relation, observation) {
  const failures = [];
  if (!isObject(relation) || !SUPPORTED_EVALUATORS.has(relation.evaluator)) {
    return ['oracle.relation_unsupported'];
  }
  if (!requireKeys(observation, relation.observationRequiredKeys)) {
    failures.push('oracle.observation_shape_invalid');
  }
  if (!finiteTree(observation)) failures.push('oracle.observation_non_finite');
  if (failures.length > 0) return failures;

  switch (relation.evaluator) {
    case 'equal_sorted_paths_and_missing_fields':
      if (
        !sameStringSet(observation.forward_paths, observation.reversed_paths) ||
        !sameStringSet(
          observation.forward_missing_fields,
          observation.reversed_missing_fields,
        ) ||
        observation.permutation_preserved !== true
      ) {
        failures.push('oracle.path_or_missing_permutation_violated');
      }
      break;
    case 'catalog_permutation_and_abstention':
      if (
        observation.forward_top_candidate_id !==
          observation.reversed_top_candidate_id ||
        observation.forward_status !== observation.reversed_status ||
        observation.forward_status !== 'resolved' ||
        observation.empty_query_status !== 'invalid' ||
        observation.permutation_preserved !== true
      ) {
        failures.push('oracle.catalog_permutation_or_abstention_violated');
      }
      break;
    case 'strict_authority_order_and_conflict':
      if (
        !(observation.official_exact_score > observation.official_foreign_score) ||
        !(observation.official_foreign_score > observation.synthetic_score) ||
        observation.strict_order !== true ||
        observation.seed_override !== false ||
        observation.cross_jurisdiction_conflict !==
          'differentJurisdictionConflict'
      ) {
        failures.push('oracle.authority_order_or_conflict_violated');
      }
      break;
    case 'jurisdiction_prefix_and_equivalent_fire_count':
      if (
        !uniqueStrings(observation.jurisdiction_chain) ||
        observation.jurisdiction_chain[0] !== 'US_DB' ||
        observation.jurisdiction_source !== 'database_region_jurisdiction_map' ||
        !uniqueStrings(observation.mg_rule_ids) ||
        !uniqueStrings(observation.gram_rule_ids) ||
        observation.mg_rule_ids.length !== 1 ||
        observation.gram_rule_ids.length !== 1 ||
        observation.equivalent_fire_count !== true
      ) {
        failures.push('oracle.jurisdiction_or_unit_equivalence_violated');
      }
      break;
    case 'valid_compile_and_missing_identity_rejection':
      if (
        observation.valid_count !== 1 ||
        typeof observation.valid_rule_id !== 'string' ||
        observation.valid_rule_id.length === 0 ||
        observation.missing_identity_rejected !== true
      ) {
        failures.push('oracle.registry_schema_rejection_violated');
      }
      break;
    case 'fact_order_and_scope_preservation':
      if (
        observation.forward !== 'contradiction' ||
        observation.reversed !== 'contradiction' ||
        observation.permutation_preserved !== true ||
        observation.different_scope !== 'coexistVariant'
      ) {
        failures.push('oracle.fact_order_or_scope_violated');
      }
      break;
    case 'recommendation_set_and_fallback_preservation': {
      const pairs = observation.ranking_pairs;
      const pathByCase = new Map(
        Array.isArray(pairs)
          ? pairs.map((pair) => [pair.case_id, pair.decision_path])
          : [],
      );
      const paths = Array.isArray(observation.decision_paths)
        ? [...observation.decision_paths].sort()
        : [];
      const derivedPaths = Array.from(pathByCase, ([id, path]) => `${id}:${path}`).sort();
      const blockedCases = [
        'replay_missing_medication_time_or_dose',
        'replay_safety_gate_blocks_local_ai',
      ];
      if (
        observation.case_count !== 5 ||
        observation.candidate_sets_preserved !== true ||
        !evaluateRankingPairs(pairs) ||
        canonicalJson(paths) !== canonicalJson(derivedPaths) ||
        blockedCases.some((id) => pathByCase.get(id) === 'hybrid_local_ai')
      ) {
        failures.push('oracle.recommendation_set_or_fallback_violated');
      }
      break;
    }
    case 'local_ai_whitelist_consent_and_endpoint_confinement':
      if (
        observation.candidate_sets_preserved !== true ||
        observation.hybrid_case_count !== observation.hybrid_ranking_pairs.length ||
        observation.hybrid_case_count !== 2 ||
        !evaluateRankingPairs(observation.hybrid_ranking_pairs) ||
        observation.consent_withdrawn_available !== false ||
        observation.consent_withdrawn_skipped !== true ||
        observation.consent_withdrawn_transport_calls !== 0 ||
        observation.remote_endpoint_available !== false ||
        observation.remote_endpoint_transport_calls !== 0
      ) {
        failures.push('oracle.local_ai_confinement_violated');
      }
      break;
  }
  return failures;
}

function clone(value) {
  return structuredClone(value);
}

export function applyJsonPointerMutation(value, mutation) {
  const output = clone(value);
  const segments = mutation.target
    .split('/')
    .slice(1)
    .map((segment) => segment.replaceAll('~1', '/').replaceAll('~0', '~'));
  if (segments.length === 0) throw new Error('empty mutation target');
  let cursor = output;
  for (const segment of segments.slice(0, -1)) {
    if (cursor === null || typeof cursor !== 'object' || !(segment in cursor)) {
      throw new Error(`missing mutation target ${mutation.target}`);
    }
    cursor = cursor[segment];
  }
  const leaf = segments.at(-1);
  if (cursor === null || typeof cursor !== 'object' || !(leaf in cursor)) {
    throw new Error(`missing mutation target ${mutation.target}`);
  }
  cursor[leaf] = clone(mutation.replacement);
  return output;
}

export function evaluateScheduler(events) {
  if (!Array.isArray(events) || events.length === 0) return 'blocked';
  let completed = false;
  let blocked = false;
  for (const event of events) {
    if (TERMINAL_BLOCK_EVENTS.has(event)) blocked = true;
    else if (event === 'complete') completed = true;
    else return 'blocked';
  }
  return completed && !blocked ? 'passed' : 'blocked';
}

function validateExecutableReport(report, registry) {
  const failures = [];
  if (
    !isObject(report) ||
    report.schema !== 'parkinsum.algorithm-executable-contract-report/1' ||
    report.schema_version !== 1
  ) {
    return ['artifact.schema_unsupported'];
  }
  for (const field of [
    'specification_sha256',
    'configuration_sha256',
    'source_bundle_sha256',
  ]) {
    if (!isSha256(report[field])) failures.push(`artifact.${field}_invalid`);
  }
  if (report.passed !== true || report.passed_check_count !== 8) {
    failures.push('artifact.not_passed');
  }
  if (!Array.isArray(report.checks) || report.checks.length !== 8) {
    failures.push('artifact.check_count_invalid');
    return failures;
  }
  const registryIds = registry.relations.map((entry) => entry.id).sort();
  const artifactIds = report.checks.map((entry) => entry?.spec?.id).sort();
  if (canonicalJson(registryIds) !== canonicalJson(artifactIds)) {
    failures.push('artifact.relation_membership_drift');
  }
  return failures;
}

function mutationResults(registry, observations) {
  const results = [];
  for (const relation of registry.relations) {
    for (const mutation of relation.mutationOperators) {
      try {
        const mutated = applyJsonPointerMutation(
          observations.get(relation.id),
          mutation,
        );
        const targetFailures = evaluateRelation(relation, mutated);
        const otherFailures = registry.relations
          .filter((candidate) => candidate.id !== relation.id)
          .flatMap((candidate) =>
            evaluateRelation(candidate, observations.get(candidate.id)),
          );
        results.push({
          id: mutation.id,
          relation_id: relation.id,
          algorithm_id: relation.algorithmId,
          class: mutation.class,
          status:
            targetFailures.length > 0 && otherFailures.length === 0
              ? 'killed'
              : 'survived',
          target_failure_codes: targetFailures,
          collateral_failure_codes: otherFailures,
        });
      } catch (error) {
        results.push({
          id: mutation.id,
          relation_id: relation.id,
          algorithm_id: relation.algorithmId,
          class: mutation.class,
          status: 'survived',
          target_failure_codes: ['oracle.mutation_not_applied'],
          collateral_failure_codes: [],
          detail: error instanceof Error ? error.message : String(error),
        });
      }
    }
  }
  return results;
}

function invalidRelationFixtures(registry) {
  const fixtures = [
    {
      id: 'unsupported_evaluator',
      mutate(value) {
        value.relations[0].evaluator = 'always_pass';
      },
    },
    {
      id: 'duplicate_relation_identity',
      mutate(value) {
        value.relations[1].id = value.relations[0].id;
      },
    },
    {
      id: 'missing_preconditions',
      mutate(value) {
        value.relations[2].inputDomainPreconditions = [];
      },
    },
  ];
  return fixtures.map((fixture) => {
    const mutated = clone(registry);
    fixture.mutate(mutated);
    const failures = validateRegistry(mutated);
    return {
      id: fixture.id,
      status: failures.length > 0 ? 'rejected' : 'accepted_in_error',
      failure_codes: failures,
    };
  });
}

export function buildIndependentReport({ registry, executableReport, oracleSha256 }) {
  const integrityFailures = [
    ...validateRegistry(registry),
    ...validateExecutableReport(executableReport, registry),
  ];
  const checksById = new Map(
    (executableReport.checks ?? []).map((entry) => [entry.spec.id, entry]),
  );
  const observations = new Map(
    Array.from(checksById, ([id, entry]) => [id, entry.observation]),
  );
  const relations = (registry.relations ?? []).map((relation) => {
    const failures = evaluateRelation(relation, observations.get(relation.id));
    return {
      id: relation.id,
      algorithm_id: relation.algorithmId,
      evaluator: relation.evaluator,
      status: failures.length === 0 ? 'passed' : 'failed',
      failure_codes: failures,
    };
  });
  const mutations = mutationResults(registry, observations);
  const invalidRelations = invalidRelationFixtures(registry);
  const schedulerCases = (registry.schedulerCases ?? []).map((entry) => {
    const observed = evaluateScheduler(entry.events);
    return {
      id: entry.id,
      expected_status: entry.expectedStatus,
      observed_status: observed,
      status: observed === entry.expectedStatus ? 'passed' : 'failed',
    };
  });
  const killed = mutations.filter((entry) => entry.status === 'killed').length;
  const survivors = mutations.length - killed;
  const relationPassed = relations.filter((entry) => entry.status === 'passed').length;
  const invalidRejected = invalidRelations.filter(
    (entry) => entry.status === 'rejected',
  ).length;
  const schedulerPassed = schedulerCases.filter(
    (entry) => entry.status === 'passed',
  ).length;
  const reportWithoutDigest = {
    schema: REPORT_SCHEMA,
    schema_version: 1,
    registry_sha256: sha256(registry),
    oracle_sha256: oracleSha256,
    executable_contract_specification_sha256:
      executableReport.specification_sha256,
    configuration_sha256: executableReport.configuration_sha256,
    source_bundle_sha256: executableReport.source_bundle_sha256,
    relation_count: relations.length,
    relation_passed_count: relationPassed,
    mutation_count: mutations.length,
    mutation_killed_count: killed,
    mutation_survivor_count: survivors,
    invalid_relation_fixture_count: invalidRelations.length,
    invalid_relation_rejected_count: invalidRejected,
    scheduler_case_count: schedulerCases.length,
    scheduler_passed_count: schedulerPassed,
    integrity_failure_codes: [...new Set(integrityFailures)].sort(),
    passed:
      integrityFailures.length === 0 &&
      relationPassed === relations.length &&
      mutations.length > 0 &&
      survivors === 0 &&
      invalidRejected === invalidRelations.length &&
      schedulerPassed === schedulerCases.length,
    boundary: registry.boundary,
    relations,
    mutations,
    invalid_relation_fixtures: invalidRelations,
    scheduler_cases: schedulerCases,
  };
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
    registry: pin('expectedRelationRegistrySha256'),
    oracle: pin('expectedIndependentOracleSha256'),
    specification: pin('expectedExecutableSpecificationSha256'),
    report: pin('expectedReportSha256'),
  };
}

export function verifyAttestationPins(report, source) {
  const pins = readPins(source);
  const failures = [];
  for (const [field, actual] of [
    ['registry', report.registry_sha256],
    ['oracle', report.oracle_sha256],
    ['specification', report.executable_contract_specification_sha256],
    ['report', report.report_sha256],
  ]) {
    if (pins[field] !== actual) failures.push(`attestation.${field}_pin_drift`);
  }
  return failures;
}

function run() {
  const registry = JSON.parse(readFileSync(registryPath, 'utf8'));
  const executableReport = JSON.parse(readFileSync(executableReportPath, 'utf8'));
  const oracleSource = readFileSync(fileURLToPath(import.meta.url));
  const oracleSha256 = sha256(oracleSource);
  const report = buildIndependentReport({
    registry,
    executableReport,
    oracleSha256,
  });
  const printPins = process.argv.includes('--print-pins');
  const pinFailures = printPins
    ? []
    : verifyAttestationPins(report, readFileSync(attestationSourcePath, 'utf8'));
  report.integrity_failure_codes = [
    ...new Set([...report.integrity_failure_codes, ...pinFailures]),
  ].sort();
  if (pinFailures.length > 0) report.passed = false;
  mkdirSync('build/algorithm_contract_independent_oracle', { recursive: true });
  writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`);
  console.log(
    `Independent algorithm-contract oracle: ${report.relation_passed_count}/${report.relation_count} relations; ` +
      `${report.mutation_killed_count}/${report.mutation_count} mutations killed; ` +
      `${report.scheduler_passed_count}/${report.scheduler_case_count} scheduler cases; ` +
      `survivors=${report.mutation_survivor_count}; artifact=${outputPath}`,
  );
  if (printPins) {
    console.log(
      JSON.stringify(
        {
          expectedRelationRegistrySha256: report.registry_sha256,
          expectedIndependentOracleSha256: report.oracle_sha256,
          expectedExecutableSpecificationSha256:
            report.executable_contract_specification_sha256,
          expectedReportSha256: report.report_sha256,
        },
        null,
        2,
      ),
    );
  }
  if (!report.passed) {
    for (const failure of report.integrity_failure_codes) console.error(failure);
    for (const relation of report.relations.filter((entry) => entry.status !== 'passed')) {
      console.error(`${relation.id}: ${relation.failure_codes.join(', ')}`);
    }
    process.exitCode = 1;
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) run();
