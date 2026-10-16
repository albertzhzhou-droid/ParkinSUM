// Explicit producer contracts. A successful engineering fixture may preserve a
// blocked disposition; no recursive search for "pass" or "blocked" is allowed.
const file = (path, key, identity, predicate = 'boolean') => ({
  path, predicate, ...(key ? { key, expected: true } : {}), identity,
});
const latest = (dir, identity, key = 'pass', predicate = 'boolean') =>
  file(`build/${dir}/latest.json`, key, identity, predicate);
const type = (report_type) => ({ report_type });
const schema = (value) => ({ schema: value });
const executable = latest('algorithm_executable_contract', schema('parkinsum.algorithm-executable-contract-report/1'), 'passed');
const migration = [
  file('build/portable_schema_migration/dart_vectors.json', 'pass', schema('parkinsum.portable-schema-migration-cross-runtime-vectors/1')),
  file('build/portable_schema_migration/node_conformance.json', 'pass', schema('parkinsum.portable-schema-migration-cross-runtime-conformance/1')),
];

export const OUTPUT_CONTRACTS = {
  copy_compile: [latest('explanation_copy', type('explanation_copy_compile'))],
  localization_lint: [latest('localization_safety_lint', type('localization_safety_lint'))],
  dose_expression_grammar: [latest('dose_expression_grammar', type('parkinsum_dose_expression_grammar_conformance'))],
  dose_confirmation: [latest('administration_dose_confirmation', type('parkinsum_administration_dose_confirmation'))],
  assertion_reconciliation: [latest('medication_assertion_reconciliation', type('parkinsum_medication_assertion_reconciliation'))],
  gastric_structures: [
    latest('gastric_structural_uncertainty', schema('parkinsum.gastric-structural-uncertainty-check/1'), 'passed'),
    latest('gastric_identifiability', schema('parkinsum.gastric-identifiability-check/1')),
  ],
  gastric_precision: [
    latest('gastric_structural_uncertainty', schema('parkinsum.gastric-structural-uncertainty-check/1'), 'passed'),
    latest('gastric_high_precision_reference', schema('parkinsum.gastric-high-precision-reference-check/1')),
  ],
  mechanistic_replay: [latest('mechanistic_replay', {}, null, 'replay')],
  mechanistic_invariants: [latest('mechanistic_model_verification', schema('parkinsum.mechanistic-model-verification-report/2'), null, 'invariants')],
  mechanistic_ledger_authorization: [latest('mechanistic_ledger_authorization', schema('parkinsum.mechanistic-ledger-authorization/1'))],
  mechanistic_lossless_replay: [
    file('build/mechanistic_replay_capsule/dart_vectors.json', 'pass', schema('parkinsum.mechanistic-replay-cross-runtime-vectors/1')),
    file('build/mechanistic_replay_capsule/node_conformance.json', 'pass', schema('parkinsum.mechanistic-replay-cross-runtime-conformance/1')),
    file('build/replay_capsule_fuzz/latest.json', 'pass', schema('parkinsum.replay-capsule-fuzz-check/1')),
    file('build/timezone_rule_research/latest.json', 'pass', schema('parkinsum.timezone-rule-research-check/1')),
  ],
  portable_schema_migration: migration,
  portable_schema_fuzz: [...migration,
    file('build/portable_schema_fuzz/dart_campaign.json', 'pass', schema('parkinsum.portable-schema-differential-fuzz-report/1')),
    file('build/portable_schema_fuzz/node_conformance.json', 'pass', schema('parkinsum.portable-schema-differential-fuzz-conformance/1')),
  ],
  algorithm_dependency_compatibility: [latest('algorithm_dependency_compatibility', { $schema: 'parkinsum.algorithm-dependency-compatibility-report/1' }, null, 'compatibility')],
  algorithm_trace_surface: [latest('algorithm_trace_surface', type('parkinsum_algorithm_trace_surface_check'))],
  algorithm_executable_contracts: [executable],
  algorithm_contract_independent_oracle: [executable, latest('algorithm_contract_independent_oracle', schema('parkinsum.algorithm-contract-independent-oracle-report/1'), 'passed')],
  algorithm_relation_domain_sampling: [executable,
    latest('algorithm_relation_production_sampling', schema('parkinsum.algorithm-relation-production-sampling-report/1'), 'passed'),
    latest('algorithm_relation_domain_sampling', schema('parkinsum.algorithm-relation-domain-sampling-report/2'), 'passed'),
  ],
  recommendation_replay: [latest('recommendation_scenario_replay', type('recommendation_scenario_replay'), null, 'recommendation'),
    latest('food_source_sensitivity', schema('parkinsum.food-source-sensitivity-check/1')),
  ],
  scenario_fuzz: [latest('synthetic_scenario_fuzzer', type('synthetic_scenario_fuzzer'), null, 'fuzz')],
  privacy_preflight: [latest('local_privacy_preflight', type('local_privacy_preflight'))],
  store_privacy_contract: [latest('store_privacy', type('parkinsum_store_privacy_contract'))],
  source_access: [latest('source_access_contract', type('source_access_contract'))],
  source_drift: [latest('source_version_drift', type('source_version_drift'))],
  contribution_route: [latest('contribution_safety_router', type('contribution_safety_router'))],
  cou_requalification: [latest('context_of_use_requalification', type('parkinsum_context_of_use_requalification'))],
  algorithm_configuration_impact: [latest('algorithm_configuration_change_impact', { $schema: 'parkinsum.algorithm-configuration-change-impact/1' }, null, 'impact_hold')],
  configuration_baseline_registry: [latest('configuration_baseline_registry', {}, null, 'baseline_hold')],
  prospective_credibility: [latest('prospective_model_credibility', type('parkinsum_prospective_model_credibility'))],
  credibility_execution: [latest('credibility_evidence_execution', type('parkinsum_credibility_evidence_execution'))],
  protocol_transparency: [latest('credibility_protocol_transparency', type('parkinsum_credibility_protocol_transparency'))],
  blinded_replication: [latest('credibility_blinded_replication', type('parkinsum_credibility_blinded_replication'))],
  statistical_analysis: [latest('credibility_statistical_analysis', type('parkinsum_credibility_statistical_analysis'))],
  randomization_interim: [latest('credibility_randomization_interim', type('parkinsum_credibility_randomization_interim_firewall'))],
  adaptive_design: [latest('credibility_adaptive_design', type('parkinsum_credibility_adaptive_design_operating_characteristics'))],
  bayesian_borrowing: [latest('credibility_bayesian_borrowing_calibration', type('parkinsum_credibility_bayesian_borrowing_and_calibration'))],
  bayesian_multisource: [latest('credibility_bayesian_multisource_model_criticism', type('parkinsum_credibility_bayesian_multisource_model_criticism'))],
  target_transportability: [latest('credibility_target_population_transportability', type('parkinsum_credibility_target_population_transportability'))],
  transport_sensitivity: [latest('credibility_transportability_sensitivity', type('parkinsum_credibility_transportability_sensitivity'))],
  evidence_currency: [latest('evidence_currency', type('parkinsum_evidence_currency'))],
  evidence_synthesis: [latest('evidence_synthesis', type('parkinsum_claim_evidence_synthesis'))],
};

export const CONSOLE_MODES = {
  rxnorm_release_identity: 'metadata_console', infoods_tagname_source_identity: 'metadata_console',
  open_source_influence: 'metadata_console', schema_contract: 'metadata_console',
  web_reflow_contract: 'console_test', wasm_hosting_contract: 'console_test',
  android_reminder_attestation_contract: 'console_test', open_source_drift_proposal_contract: 'console_test',
  open_source_drift_decision_ledger_contract: 'console_test', fhir_r5_validator_runner_contract: 'console_test',
  committed_goldens: 'console_test',
};

export const FHIR_OPERATIONS = {
  fhir_r5_cpg_apply_contract: 'PlanDefinition/$apply',
  fhir_r5_activitydefinition_apply_contract: 'ActivityDefinition/$apply',
  fhir_r5_plandefinition_data_requirements_contract: 'PlanDefinition/$data-requirements',
};

export function outputDeclaration(id) {
  if (OUTPUT_CONTRACTS[id]) return { mode: 'json_files', reports: OUTPUT_CONTRACTS[id] };
  if (id === 'committed_goldens') return { mode: 'console_test', reports: [], completion: { protocol: 'flutter_test_summary_v1', minimum_passed: 7 }, boundary: 'No producer machine report is emitted; the complete Flutter summary and zero reported failures are required.' };
  if (CONSOLE_MODES[id]) return { mode: CONSOLE_MODES[id], reports: [], boundary: 'No producer machine report is emitted; success is the declared console contract only.' };
  if (FHIR_OPERATIONS[id]) return { mode: 'json_files', reportArgument: `--report=build/verify_all/producers/${id}.json`, reports: [file(
    `build/verify_all/producers/${id}.json`, null,
    { schemaVersion: 1, status: 'passed', fhirVersion: '5.0.0', operation: FHIR_OPERATIONS[id], structureOnly: true,
      realPatientDataUsed: false, networkRequestMade: false, fhirValidatorUsed: false }, 'fhir_structure',
  )] };
  throw new Error(`Gate has no explicit output contract: ${id}`);
}

export function reportPasses(value, contract) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  if (!Object.entries(contract.identity ?? {}).every(([key, expected]) => value[key] === expected)) return false;
  const nonempty = (xs) => Array.isArray(xs) && xs.length > 0;
  switch (contract.predicate) {
    case 'boolean': return value[contract.key] === contract.expected;
    case 'replay': return nonempty(value.cases) && value.total === value.cases.length && value.passed === value.total && value.cases.every((entry) => entry.pass === true);
    case 'invariants': return nonempty(value.checks) && value.failed_check_count === 0 && value.passed_check_count === value.checks.length && value.checks.every((entry) => entry.passed === true);
    case 'recommendation': return nonempty(value.cases) && value.cases.every((entry) => entry.ai_preserved_candidate_set === true);
    case 'fuzz': return nonempty(value.cases) && value.failed === 0 && value.passed === value.case_count && value.case_count === value.cases.length && value.cases.every((entry) => entry.evaluation?.passed === true);
    case 'compatibility': return value.compatibility_state === 'compatibility_accepted' && Number.isInteger(value.root_count) && value.root_count > 0 && value.accepted_root_count === value.root_count;
    case 'impact_hold': return Array.isArray(value.integrity_reasons) && value.integrity_reasons.length === 0 && value.can_close_impact === false;
    case 'baseline_hold': return value.transition_accepted === false && value.transition_reason === 'verification_obligations_incomplete' && value.registry?.events?.length === 2;
    case 'fhir_structure': return /^[a-f0-9]{64}$/.test(value.fixtureSha256 ?? '') && (value.operationExecuted === false || value.cpgEngineExecuted === false);
    default: return false;
  }
}
