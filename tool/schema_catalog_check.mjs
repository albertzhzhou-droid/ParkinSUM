#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const modulePath = fileURLToPath(import.meta.url);
const defaultRepoRoot = path.dirname(path.dirname(modulePath));
const defaultCatalogPath = 'config/schema_catalog.json';
const supportedCatalogVersion = 2;

const schemaIdPattern = /^parkinsum\.[a-z0-9.-]+$/;
const safeDartIdentifierPattern = /^[A-Za-z_][A-Za-z0-9_]*$/;
const supportedVersionStatuses = new Set([
  'versioned',
  'semantic-versioned',
  'unversioned',
]);
const supportedSurfaceKinds = new Set([
  'public-envelope',
  'nested-public-contract',
  'persisted-envelope',
  'database-schema',
  'persisted-boundary',
  'runtime-contract',
  'governance-artifact',
]);
const supportedEvidenceKinds = new Set([
  'schema-uri',
  'dart-int-constant',
  'dart-json-int-field',
  'dart-json-int-guard',
  'dart-named-int-argument',
  'versioned-string',
  'dart-named-string-argument',
  'dart-string-constant',
]);

// This registry is deliberately independent of the JSON catalog and contains
// no version numbers. It is the minimum production/public surface set that the
// central catalog must continue to acknowledge. Versions are extracted from
// their declared source evidence below, so this registry cannot silently become a second version
// authority.
export const requiredSchemaSurfaces = Object.freeze([
  ['parkinsum.administration-dose-expression', 'lib/domain/usecases/dosage_note_parser.dart'],
  ['parkinsum.protein-trend-aggregation', 'lib/domain/usecases/get_protein_trend_usecase.dart'],
  ['parkinsum.food-rank-sensitivity-assessment', 'lib/domain/entities/food_rank_sensitivity_assessment.dart'],
  ['parkinsum.fhir-r4-medication-intake-statement', 'lib/domain/usecases/fhir_r4_medication_intake_statement_mapper.dart'],
  ['parkinsum.synthetic-rule-test-suite-checkpoint', 'lib/domain/entities/rule_test_suite.dart'],
  ['parkinsum.fhir-r4-bp-mapper', 'lib/domain/usecases/fhir_r4_blood_pressure_mapper.dart'],
  ['parkinsum.fhir-r4-observation-import-preview', 'lib/domain/entities/fhir_r4_observation_import_preview.dart'],
  ['parkinsum.fhir-r4-bp-collection-mapper', 'lib/domain/usecases/fhir_r4_blood_pressure_collection_mapper.dart'],
  ['parkinsum.fhir-r4-medication-statement-collection', 'lib/domain/usecases/fhir_r4_medication_statement_collection_mapper.dart'],
  ['parkinsum.fhir-r4-medication-statement-import-preview', 'lib/domain/entities/fhir_r4_medication_statement_import_preview.dart'],
  ['parkinsum.fhir-r4-medication-request-import-preview', 'lib/domain/entities/fhir_r4_medication_request_import_preview.dart'],
  ['parkinsum.fhir-r4-allergy-intolerance-import-preview', 'lib/domain/entities/fhir_r4_allergy_intolerance_import_preview.dart'],
  ['parkinsum.fhir-r4-condition-import-preview', 'lib/domain/entities/fhir_r4_condition_import_preview.dart'],
  ['parkinsum.fhir-r4-encounter-import-preview', 'lib/domain/entities/fhir_r4_encounter_import_preview.dart'],
  ['parkinsum.fhir-r4-medication-administration-import-preview', 'lib/domain/entities/fhir_r4_medication_administration_import_preview.dart'],
  ['parkinsum.fhir-r4-medication-dispense-import-preview', 'lib/domain/entities/fhir_r4_medication_dispense_import_preview.dart'],
  ['parkinsum.fhir-r4-personal-collection', 'lib/domain/usecases/fhir_r4_personal_observation_collection_mapper.dart'],
  ['parkinsum.fhir-r4-symptom-motor-collection', 'lib/domain/usecases/fhir_r4_symptom_motor_observation_mapper.dart'],
  ['parkinsum.fhir-r4-symptom-motor-mapper', 'lib/domain/usecases/fhir_r4_symptom_motor_observation_mapper.dart'],
  ['parkinsum.fhir-r5-dose-quantity-preview', 'lib/domain/entities/fhir_r5_dose_quantity_preview.dart'],
  ['parkinsum.fhir-r5-dose-quantity-preview-profile', 'lib/domain/entities/fhir_r5_dose_quantity_preview.dart'],
  ['parkinsum.fhir-r5-medication-product-preview', 'lib/domain/entities/fhir_r5_medication_product_preview.dart'],
  ['parkinsum.fhir-r5-medication-product-preview-profile', 'lib/domain/entities/fhir_r5_medication_product_preview.dart'],
  ['parkinsum.fhir-r5-nutrition-intake-preview', 'lib/domain/usecases/fhir_r5_nutrition_intake_mapper.dart'],
  ['parkinsum.openfda-strength-expression-parse-result', 'lib/domain/entities/openfda_strength_expression.dart'],
  ['parkinsum.openfda-strength-expression-source-manifest', 'lib/domain/entities/openfda_strength_expression_source_manifest.dart'],
  ['parkinsum.food-composition-candidate-set-snapshot', 'lib/domain/entities/food_composition_candidate_set_snapshot.dart'],
  ['parkinsum.food-portion-composition-projection', 'lib/domain/entities/food_portion_composition_projection.dart'],
  ['parkinsum.cdss-food-projection-query-audit', 'lib/domain/usecases/cdss_catalog_projection_service.dart'],
  ['parkinsum.knowledge-approval', 'lib/domain/entities/knowledge_approval_envelope.dart'],
  ['parkinsum.knowledge-governance-state', 'lib/domain/entities/knowledge_governance_state.dart'],
  ['parkinsum.knowledge-pack', 'lib/domain/entities/knowledge_pack.dart'],
  ['parkinsum.algorithm-evaluation', 'lib/algorithm_sdk/parkinsum_algorithm_sdk.dart'],
  ['parkinsum.algorithm-configuration', 'lib/algorithm_sdk/algorithm_configuration_identity.dart'],
  ['parkinsum.levodopa-absorption-opportunity-parameters', 'lib/domain/entities/levodopa_absorption_opportunity_parameters.dart'],
  ['parkinsum.levodopa-absorption-generator-structure', 'lib/domain/usecases/levodopa_absorption_opportunity_model.dart'],
  ['parkinsum.absorption-opportunity-output-contract', 'lib/domain/entities/absorption_opportunity.dart'],
  ['parkinsum.algorithm-trace-surface-manifest', 'lib/domain/entities/algorithm_descriptor.dart'],
  ['parkinsum.algorithm-result-root-manifest', 'lib/domain/entities/algorithm_result_root_manifest.dart'],
  ['parkinsum.algorithm-dependency-compatibility-report', 'lib/domain/entities/algorithm_dependency_compatibility.dart'],
  ['parkinsum.algorithm-observatory-snapshot', 'lib/domain/usecases/algorithm_observatory_service.dart'],
  ['parkinsum.signed-capability-manifest', 'lib/domain/entities/signed_capability_manifest.dart'],
  ['parkinsum.capability-activation-state', 'lib/core/services/capability_rollout_service.dart'],
  ['parkinsum.mechanistic-applicability-manifest', 'lib/domain/entities/mechanistic_medication_applicability.dart'],
  ['parkinsum.context-of-use-requalification-ledger', 'lib/domain/entities/context_of_use_requalification.dart'],
  ['parkinsum.prospective-model-credibility-plan', 'lib/domain/entities/prospective_model_credibility_plan.dart'],
  ['parkinsum.credibility-evidence-execution-attestation', 'lib/domain/entities/credibility_evidence_execution_attestation.dart'],
  ['parkinsum.credibility-protocol-transparency-ledger', 'lib/domain/entities/credibility_protocol_transparency_ledger.dart'],
  ['parkinsum.credibility-blinded-replication-package', 'lib/domain/entities/credibility_blinded_replication.dart'],
  ['parkinsum.synthetic-replication-output', 'lib/domain/entities/credibility_blinded_replication.dart'],
  ['parkinsum.credibility-statistical-analysis-package', 'lib/domain/entities/credibility_statistical_analysis.dart'],
  ['parkinsum.credibility-randomization-interim-firewall-package', 'lib/domain/entities/credibility_randomization_interim_firewall.dart'],
  ['parkinsum.credibility-adaptive-design-simulation-package', 'lib/domain/entities/credibility_adaptive_design_simulation.dart'],
  ['parkinsum.credibility-bayesian-borrowing-calibration-package', 'lib/domain/entities/credibility_bayesian_borrowing_calibration.dart'],
  ['parkinsum.credibility-bayesian-multisource-model-criticism-package', 'lib/domain/entities/credibility_bayesian_multisource_model_criticism.dart'],
  ['parkinsum.credibility-target-population-transportability-package', 'lib/domain/entities/credibility_target_population_transportability.dart'],
  ['parkinsum.credibility-transportability-sensitivity-package', 'lib/domain/entities/credibility_transportability_sensitivity.dart'],
  ['parkinsum.xorshift32-box-muller', 'lib/domain/usecases/adaptive_design_operating_characteristics_simulator.dart'],
  ['parkinsum.evidence-currency-registry', 'lib/domain/entities/evidence_currency.dart'],
  ['parkinsum.evidence-currency-runtime-binding', 'lib/domain/entities/evidence_currency.dart'],
  ['parkinsum.claim-evidence-synthesis-registry', 'lib/domain/entities/evidence_synthesis.dart'],
  ['parkinsum.mechanistic-numerical-oracle', 'lib/domain/usecases/algorithm_numerical_verification_oracle.dart'],
  ['parkinsum.mechanistic-model-verification-report', 'lib/domain/usecases/mechanistic_model_verification_gate.dart'],
  ['parkinsum.algorithm-executable-contract-report', 'lib/domain/usecases/algorithm_executable_contract_gate.dart'],
  ['parkinsum.algorithm-contract-relation-registry', 'lib/domain/entities/algorithm_contract_independent_oracle_attestation.dart'],
  ['parkinsum.algorithm-contract-independent-oracle-report', 'lib/domain/entities/algorithm_contract_independent_oracle_attestation.dart'],
  ['parkinsum.algorithm-relation-domain-sampling-plan', 'lib/domain/entities/algorithm_relation_domain_sampling_attestation.dart'],
  ['parkinsum.algorithm-relation-domain-sampling-report', 'lib/domain/entities/algorithm_relation_domain_sampling_attestation.dart'],
  ['parkinsum.defective-relation-calibration-policy', 'lib/domain/entities/algorithm_relation_domain_sampling_attestation.dart'],
  ['parkinsum.algorithm-relation-production-sampling-report', 'lib/domain/entities/algorithm_relation_domain_sampling_attestation.dart'],
  ['parkinsum.mechanistic-event-ledger', 'lib/domain/entities/mechanistic_event_ledger.dart'],
  ['parkinsum.personal-observation-event-ledger', 'lib/domain/entities/personal_observation_event_ledger.dart'],
  ['parkinsum.local-time-resolution', 'lib/domain/entities/local_time_resolution.dart'],
  ['parkinsum.mechanistic-ledger-authorization', 'lib/domain/usecases/mechanistic_event_ledger_authorization.dart'],
  ['parkinsum.mechanistic-ledger-input-binding', 'lib/domain/entities/mechanistic_event_ledger.dart'],
  ['parkinsum.mechanistic-replay-capsule', 'lib/domain/entities/mechanistic_replay_capsule.dart'],
  ['parkinsum.jcs-safe-lossless-scalars', 'lib/domain/entities/mechanistic_replay_capsule.dart'],
  ['parkinsum.mechanistic-replay-cross-runtime-vectors', 'lib/domain/entities/mechanistic_replay_capsule.dart'],
  ['parkinsum.mechanistic-replay-cross-runtime-conformance', 'lib/domain/entities/mechanistic_replay_capsule.dart'],
  ['parkinsum.gastric-structural-uncertainty-report', 'lib/domain/entities/gastric_structural_uncertainty.dart'],
  ['parkinsum.gastric-high-precision-reference-check', 'lib/domain/entities/gastric_high_precision_reference_contract.dart'],
  ['parkinsum.algorithm-fitted-parameter-identity', 'lib/algorithm_sdk/algorithm_parameter_provenance.dart'],
  ['parkinsum.algorithm-parameter-provenance', 'lib/algorithm_sdk/algorithm_parameter_provenance.dart'],
  ['parkinsum.algorithm-parameter-manifest', 'lib/algorithm_sdk/algorithm_parameter_provenance.dart'],
  ['parkinsum.algorithm-configuration-coverage', 'lib/algorithm_sdk/algorithm_parameter_provenance.dart'],
  ['parkinsum.algorithm-configuration-completeness-witness', 'lib/algorithm_sdk/algorithm_parameter_provenance.dart'],
  ['parkinsum.algorithm-configuration-change-impact', 'lib/domain/entities/algorithm_configuration_change_impact.dart'],
  ['parkinsum.configuration-baseline-promotion-receipt', 'lib/domain/entities/configuration_baseline_registry.dart'],
  ['parkinsum.configuration-baseline-registry', 'lib/domain/entities/configuration_baseline_registry.dart'],
  ['parkinsum.cdss-rule-logic', 'lib/algorithm_sdk/algorithm_parameter_provenance.dart'],
  ['parkinsum.gastric-emptying-configuration', 'lib/domain/usecases/gastric_emptying_model.dart'],
  ['parkinsum.gastric-emptying-generator-structure', 'lib/domain/usecases/gastric_emptying_model.dart'],
  ['parkinsum.gastric-emptying-output-contract', 'lib/domain/entities/gastric_emptying_profile.dart'],
  ['parkinsum.gastric-parameter-set', 'lib/domain/entities/gastric_emptying_parameters.dart'],
  ['parkinsum.algorithm-trace-node', 'lib/domain/entities/algorithm_trace_node.dart'],
  ['parkinsum.synthetic-rule-test-case', 'lib/domain/entities/rule_test_case.dart'],
  ['parkinsum.synthetic-rule-test-pack', 'lib/domain/entities/rule_test_case.dart'],
  ['parkinsum.synthetic-rule-test-report', 'lib/domain/usecases/synthetic_rule_test_runner.dart'],
  ['parkinsum.synthetic-rule-test-suite', 'lib/domain/entities/rule_test_suite.dart'],
  ['parkinsum.synthetic-rule-test-suite-report', 'lib/domain/usecases/synthetic_rule_test_suite_runner.dart'],
  ['parkinsum.rule-set-structural-diff', 'lib/domain/entities/rule_set_diff.dart'],
  ['parkinsum.care-workspace', 'lib/core/services/care_workspace_service.dart'],
  ['parkinsum.decision-support-followup-ledger', 'lib/domain/entities/decision_support_followup.dart'],
  ['parkinsum.personal-observation', 'lib/domain/entities/personal_observation.dart'],
  ['parkinsum.personal-log-handoff', 'lib/domain/usecases/personal_log_handoff_summary_service.dart'],
  ['parkinsum.personal-log-handoff-semantic-document', 'lib/domain/usecases/personal_log_handoff_summary_service.dart'],
  ['parkinsum.privacy-safe-support-bundle', 'lib/domain/usecases/privacy_safe_support_bundle_service.dart'],
  ['parkinsum.operational-observability-envelope', 'lib/domain/entities/operational_observability.dart'],
  ['parkinsum.purpose-bound-consent-receipt', 'lib/core/models/purpose_bound_consent.dart'],
  ['parkinsum.recoverable-user-event-history', 'lib/core/models/recoverable_user_event.dart'],
  ['parkinsum.recoverable-event-restore-impact', 'lib/domain/usecases/recoverable_event_restore_impact_service.dart'],
  ['parkinsum.restore-relationship-graph', 'lib/domain/usecases/recoverable_event_restore_impact_service.dart'],
  ['parkinsum.restore-impact-account', 'lib/domain/usecases/recoverable_event_restore_impact_service.dart'],
  ['parkinsum.user-portable-data-package', 'lib/domain/usecases/user_portable_data_package_service.dart'],
  ['parkinsum.portable-schema-migration-registry', 'lib/domain/entities/portable_schema_migration.dart'],
  ['parkinsum.portable-schema-migration-receipt', 'lib/domain/entities/portable_schema_migration.dart'],
  ['parkinsum.portable-schema-migration-cross-runtime-vectors', 'lib/domain/entities/portable_schema_migration.dart'],
  ['parkinsum.portable-schema-migration-cross-runtime-conformance', 'lib/domain/entities/portable_schema_migration.dart'],
  ['parkinsum.portable-schema-differential-fuzz-plan', 'lib/domain/entities/portable_schema_migration.dart'],
  ['parkinsum.portable-schema-fuzz-regression-corpus', 'lib/domain/entities/portable_schema_migration.dart'],
  ['parkinsum.portable-schema-differential-fuzz-report', 'lib/domain/entities/portable_schema_migration.dart'],
  ['parkinsum.portable-schema-differential-fuzz-conformance', 'lib/domain/entities/portable_schema_migration.dart'],
  ['parkinsum.portable-owner-token', 'lib/core/services/portable_data_owner_scope_service.dart'],
  ['parkinsum.portable-owner-secret-envelope', 'lib/core/services/portable_data_owner_scope_service.dart'],
  ['parkinsum.protected-secret-store', 'lib/core/security/protected_secret_store.dart'],
  ['parkinsum.atomic-onboarding-commit', 'lib/core/models/atomic_onboarding_commit.dart'],
  ['parkinsum.intake-record', 'lib/core/models/intake.dart'],
  ['parkinsum.administration-dose-confirmation', 'lib/core/models/administration_dose_confirmation.dart'],
  ['parkinsum.medication-package-dose-derivation', 'lib/core/models/medication_product_pack.dart'],
  ['parkinsum.administration-dose-record-binding', 'lib/core/models/administration_dose_confirmation.dart'],
  ['parkinsum.dose-expression-parse-result', 'lib/domain/entities/dose_expression.dart'],
  ['parkinsum.versioned-dose-unit-mapping', 'lib/domain/entities/versioned_dose_unit_mapping.dart'],
  ['parkinsum.medication-assertion', 'lib/domain/entities/medication_assertion_reconciliation.dart'],
  ['parkinsum.medication-reconciliation-decision', 'lib/domain/entities/medication_assertion_reconciliation.dart'],
  ['parkinsum.medication-assertion-conflict-graph', 'lib/domain/usecases/medication_assertion_reconciliation_service.dart'],
  ['parkinsum.medication-assertion-bitemporal-projection', 'lib/domain/usecases/medication_assertion_reconciliation_service.dart'],
  ['parkinsum.medication-reconciliation-envelope', 'lib/core/models/intake.dart'],
  ['parkinsum.reminder-activation-inbox', 'lib/core/services/reminder_activation_inbox.dart'],
  ['parkinsum.reminder-plan', 'lib/domain/entities/user_logging_reminder.dart'],
  ['parkinsum.reminder-notification-payload', 'lib/core/services/reminder_notification_payload.dart'],
  ['parkinsum.reminder-notification-presentation', 'lib/core/services/reminder_notification_privacy_policy.dart'],
  ['parkinsum.reminder-notification-capability-matrix', 'lib/core/services/reminder_notification_capability_matrix.dart'],
  ['parkinsum.reminder-delivery-readiness', 'lib/core/services/reminder_notification_capability_matrix.dart'],
  ['parkinsum.android-reminder-run-attestation', 'lib/core/services/reminder_notification_run_attestation.dart'],
  ['parkinsum.android-reminder-execution-isolation', 'lib/core/services/reminder_notification_run_attestation.dart'],
  ['parkinsum.android-reminder-integration-observation', 'lib/core/services/reminder_notification_run_attestation.dart'],
  ['parkinsum.reminder-schedule-manifest', 'lib/core/services/reminder_schedule_manifest.dart'],
  ['parkinsum.app-database-native', 'lib/core/db/app_database_native.dart'],
  ['parkinsum.app-database-web-user-state', 'lib/core/db/app_database_web.dart'],
  ['parkinsum.app-database-web-record-sets', 'lib/core/db/app_database_web.dart'],
  ['parkinsum.app-database-firestore', 'lib/core/db/app_database_firestore.dart'],
  ['parkinsum.cdss-database-native', 'lib/core/db/cdss_database_native.dart'],
  ['parkinsum.cdss-database-web', 'lib/core/db/cdss_database_web.dart'],
  ['parkinsum.cdss-database-firestore', 'lib/core/db/cdss_database_firestore.dart'],
  ['parkinsum.android-gradle-runtime-dependency-graph', 'lib/domain/entities/product_upgrade_queue.dart'],
  ['parkinsum.engine-snapshot-record', 'lib/domain/entities/cdss_records.dart'],
  ['parkinsum.complete-app-upgrade-queue', 'lib/domain/entities/product_upgrade_queue.dart'],
  ['parkinsum.open-source-drift-review-ledger', 'tool/open_source_drift_decision_ledger.mjs'],
  ['parkinsum.open-source-drift-review-decision', 'tool/open_source_drift_decision_ledger.mjs'],
  ['parkinsum.open-source-influence-inventory', 'lib/domain/entities/product_upgrade_queue.dart'],
  ['parkinsum.open-source-release-evidence', 'lib/domain/entities/product_upgrade_queue.dart'],
  ['parkinsum.rxnorm-release-identity', 'tool/rxnorm_release_identity.mjs'],
  ['parkinsum.infoods-tagname-source-identity', 'tool/infoods_tagname_source_identity.mjs'],
  ['parkinsum.catalog-version-change-diff', 'lib/domain/entities/catalog_version_change_diff.dart'],
  ['parkinsum.synthetic-cds-hooks-challenge', 'lib/domain/usecases/synthetic_cds_hooks_challenge_service.dart'],
  ['parkinsum.cql-concept-template-draft', 'tool/cql_concept_template_preview.mjs'],
].map(([id, source]) => Object.freeze({ id, source })));

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function isSafeRelativeDartPath(value) {
  if (typeof value !== 'string' || value.length === 0) return false;
  if (path.isAbsolute(value) || value.includes('\\')) return false;
  const normalized = path.posix.normalize(value);
  return (
    normalized === value &&
    !normalized.startsWith('../') &&
    normalized.startsWith('lib/') &&
    normalized.endsWith('.dart')
  );
}

function isSafeRelativeGovernanceToolPath(value) {
  if (typeof value !== 'string' || value.length === 0) return false;
  if (path.isAbsolute(value) || value.includes('\\')) return false;
  const normalized = path.posix.normalize(value);
  return (
    normalized === value &&
    !normalized.startsWith('../') &&
    normalized.startsWith('tool/') &&
    normalized.endsWith('.mjs')
  );
}

function listDartFiles(root) {
  const libRoot = path.join(root, 'lib');
  if (!fs.existsSync(libRoot)) return [];
  const found = [];
  const visit = (directory) => {
    const entries = fs.readdirSync(directory, { withFileTypes: true });
    entries.sort((left, right) => left.name.localeCompare(right.name));
    for (const entry of entries) {
      const absolute = path.join(directory, entry.name);
      if (entry.isDirectory()) visit(absolute);
      if (entry.isFile() && entry.name.endsWith('.dart')) {
        found.push(path.relative(root, absolute).split(path.sep).join('/'));
      }
    }
  };
  visit(libRoot);
  return found;
}

function sourceText(repoRoot, source, failures, label, surfaceKind) {
  const allowedDartSource = isSafeRelativeDartPath(source);
  const allowedGovernanceTool =
    surfaceKind === 'governance-artifact' &&
    isSafeRelativeGovernanceToolPath(source);
  if (!allowedDartSource && !allowedGovernanceTool) {
    failures.push(
      label +
        ' source must be a normalized relative lib/*.dart path ' +
        '(tool/*.mjs is allowed only for governance-artifact): ' +
        source,
    );
    return null;
  }
  const absolute = path.join(repoRoot, source);
  if (!fs.existsSync(absolute) || !fs.statSync(absolute).isFile()) {
    failures.push(label + ' source does not exist: ' + source);
    return null;
  }
  return fs.readFileSync(absolute, 'utf8');
}

function boundedSlice(text, evidence, label, failures) {
  if (evidence.anchor === undefined) return text;
  if (typeof evidence.anchor !== 'string' || evidence.anchor.length === 0) {
    failures.push(`${label} evidence anchor must be a non-empty literal string`);
    return null;
  }
  const start = text.indexOf(evidence.anchor);
  if (start < 0) {
    failures.push(`${label} evidence anchor was not found: ${evidence.anchor}`);
    return null;
  }
  if (evidence.endAnchor === undefined) return text.slice(start);
  if (typeof evidence.endAnchor !== 'string' || evidence.endAnchor.length === 0) {
    failures.push(`${label} evidence endAnchor must be a non-empty literal string`);
    return null;
  }
  const end = text.indexOf(evidence.endAnchor, start + evidence.anchor.length);
  if (end < 0) {
    failures.push(`${label} evidence endAnchor was not found: ${evidence.endAnchor}`);
    return null;
  }
  return text.slice(start, end);
}

function uniqueMatch(matches, label, failures) {
  const values = [...new Set(matches)];
  if (values.length !== 1) {
    failures.push(
      `${label} must resolve exactly one source version; found ${values.length}`,
    );
    return null;
  }
  return values[0];
}

function extractEvidenceVersion({ schema, evidence, text, failures, label }) {
  if (!evidence || typeof evidence !== 'object' || Array.isArray(evidence)) {
    failures.push(`${label} must be an object`);
    return null;
  }
  if (!supportedEvidenceKinds.has(evidence.kind)) {
    failures.push(`${label} has unsupported kind: ${evidence.kind}`);
    return null;
  }
  const bounded = boundedSlice(text, evidence, label, failures);
  if (bounded === null) return null;

  if (evidence.kind === 'schema-uri') {
    const expression = new RegExp(
      `['\"]${escapeRegex(schema.id)}\\/([1-9][0-9]*)['\"]`,
      'g',
    );
    return uniqueMatch(
      [...bounded.matchAll(expression)].map((match) => Number(match[1])),
      label,
      failures,
    );
  }

  if (evidence.kind === 'dart-int-constant') {
    if (!safeDartIdentifierPattern.test(evidence.symbol ?? '')) {
      failures.push(`${label} symbol is not a safe Dart identifier`);
      return null;
    }
    const expression = new RegExp(
      `(?:static\\s+)?const\\s+(?:int\\s+)?${escapeRegex(evidence.symbol)}\\s*=\\s*([1-9][0-9]*)\\s*;`,
      'g',
    );
    return uniqueMatch(
      [...bounded.matchAll(expression)].map((match) => Number(match[1])),
      label,
      failures,
    );
  }

  if (evidence.kind === 'dart-json-int-field') {
    if (typeof evidence.field !== 'string' || evidence.field.length === 0) {
      failures.push(`${label} field must be a non-empty string`);
      return null;
    }
    const expression = new RegExp(
      `['\"]${escapeRegex(evidence.field)}['\"]\\s*:\\s*([1-9][0-9]*)`,
      'g',
    );
    return uniqueMatch(
      [...bounded.matchAll(expression)].map((match) => Number(match[1])),
      label,
      failures,
    );
  }

  if (evidence.kind === 'dart-json-int-guard') {
    if (typeof evidence.field !== 'string' || evidence.field.length === 0) {
      failures.push(`${label} field must be a non-empty string`);
      return null;
    }
    const expression = new RegExp(
      `\\[['\"]${escapeRegex(evidence.field)}['\"]\\]\\s*!=\\s*([1-9][0-9]*)`,
      'g',
    );
    return uniqueMatch(
      [...bounded.matchAll(expression)].map((match) => Number(match[1])),
      label,
      failures,
    );
  }

  if (evidence.kind === 'dart-named-int-argument') {
    if (!safeDartIdentifierPattern.test(evidence.argument ?? '')) {
      failures.push(`${label} argument is not a safe Dart identifier`);
      return null;
    }
    const expression = new RegExp(
      `${escapeRegex(evidence.argument)}\\s*:\\s*([1-9][0-9]*)`,
      'g',
    );
    return uniqueMatch(
      [...bounded.matchAll(expression)].map((match) => Number(match[1])),
      label,
      failures,
    );
  }

  if (evidence.kind === 'versioned-string') {
    if (typeof evidence.prefix !== 'string' || evidence.prefix.length === 0) {
      failures.push(`${label} prefix must be a non-empty literal string`);
      return null;
    }
    const expression = new RegExp(`${escapeRegex(evidence.prefix)}([1-9][0-9]*)`, 'g');
    return uniqueMatch(
      [...bounded.matchAll(expression)].map((match) => Number(match[1])),
      label,
      failures,
    );
  }

  if (evidence.kind === 'dart-named-string-argument') {
    if (!safeDartIdentifierPattern.test(evidence.argument ?? '')) {
      failures.push(`${label} argument is not a safe Dart identifier`);
      return null;
    }
    const expression = new RegExp(
      `${escapeRegex(evidence.argument)}\\s*:\\s*['\"]([^'\"\\r\\n]+)['\"]`,
      'g',
    );
    return uniqueMatch(
      [...bounded.matchAll(expression)].map((match) => match[1]),
      label,
      failures,
    );
  }

  if (evidence.kind === 'dart-string-constant') {
    if (!safeDartIdentifierPattern.test(evidence.symbol ?? '')) {
      failures.push(`${label} symbol is not a safe Dart identifier`);
      return null;
    }
    const expression = new RegExp(
      `(?:static\\s+)?const\\s+(?:String\\s+)?${escapeRegex(evidence.symbol)}\\s*=\\s*['\"]([^'\"\\r\\n]+)['\"]`,
      'g',
    );
    return uniqueMatch(
      [...bounded.matchAll(expression)].map((match) => match[1]),
      label,
      failures,
    );
  }

  return null;
}

function discoverSchemaUris(repoRoot, dartFiles) {
  const discovered = [];
  const expression = /['\"](parkinsum\.[a-z0-9.-]+)\/([1-9][0-9]*)['\"]/g;
  for (const source of dartFiles) {
    const text = fs.readFileSync(path.join(repoRoot, source), 'utf8');
    for (const match of text.matchAll(expression)) {
      discovered.push({ source, id: match[1], version: Number(match[2]) });
    }
  }
  return discovered;
}

function discoverNamedSchemaVersionConstants(repoRoot, dartFiles) {
  const discovered = [];
  const expression =
    /(?:static\s+)?const\s+(?:int\s+)?([A-Za-z_][A-Za-z0-9_]*(?:SchemaVersion|schemaVersion)|_schemaVersion)\s*=\s*([1-9][0-9]*)\s*;/g;
  for (const source of dartFiles) {
    const text = fs.readFileSync(path.join(repoRoot, source), 'utf8');
    for (const match of text.matchAll(expression)) {
      discovered.push({ source, symbol: match[1], version: Number(match[2]) });
    }
  }
  return discovered;
}

export function validateSchemaCatalog(catalog, { repoRoot = defaultRepoRoot } = {}) {
  const failures = [];
  if (!catalog || typeof catalog !== 'object' || Array.isArray(catalog)) {
    return ['catalog root must be an object'];
  }
  if (catalog.catalogVersion !== supportedCatalogVersion) {
    failures.push(`catalogVersion must be ${supportedCatalogVersion}`);
  }
  if (typeof catalog.boundary !== 'string' || catalog.boundary.trim().length < 40) {
    failures.push('catalog boundary must state the catalog limits');
  } else {
    const boundary = catalog.boundary.toLowerCase();
    for (const term of ['migration', 'compatibility', 'deployed']) {
      if (!boundary.includes(term)) {
        failures.push(`catalog boundary must explicitly limit ${term} claims`);
      }
    }
  }
  const schemas = Array.isArray(catalog.schemas) ? catalog.schemas : [];
  if (schemas.length === 0) {
    failures.push('schemas must be a non-empty array');
  }

  const ids = new Set();
  const entriesById = new Map();
  const claimedConstants = new Map();
  for (const [index, schema] of schemas.entries()) {
    const label = `schemas[${index}]`;
    if (!schema || typeof schema !== 'object' || Array.isArray(schema)) {
      failures.push(`${label} must be an object`);
      continue;
    }
    if (!schemaIdPattern.test(schema.id ?? '')) {
      failures.push(`${label} has invalid schema id: ${schema.id}`);
    }
    if (ids.has(schema.id)) failures.push(`duplicate schema id: ${schema.id}`);
    ids.add(schema.id);
    entriesById.set(schema.id, schema);
    if (!supportedSurfaceKinds.has(schema.surfaceKind)) {
      failures.push(`${schema.id} has unsupported surfaceKind: ${schema.surfaceKind}`);
    }
    if (!supportedVersionStatuses.has(schema.versionStatus)) {
      failures.push(`${schema.id} has unsupported versionStatus: ${schema.versionStatus}`);
    }
    if (!String(schema.compatibility ?? '').trim()) {
      failures.push(`${schema.id} compatibility policy is missing`);
    }
    const primaryText = sourceText(
      repoRoot,
      schema.source,
      failures,
      schema.id,
      schema.surfaceKind,
    );
    if (schema.versionStatus === 'versioned') {
      if (!Number.isInteger(schema.currentVersion) || schema.currentVersion < 1) {
        failures.push(`${schema.id} currentVersion must be a positive integer`);
      }
      const legacyVersions = schema.acceptedLegacyVersions ?? [];
      if (!Array.isArray(legacyVersions)) {
        failures.push(`${schema.id} acceptedLegacyVersions must be an array`);
      } else {
        const uniqueLegacyVersions = new Set();
        for (const version of legacyVersions) {
          if (
            !Number.isInteger(version) ||
            version < 1 ||
            version >= schema.currentVersion ||
            uniqueLegacyVersions.has(version)
          ) {
            failures.push(
              `${schema.id} acceptedLegacyVersions must be unique positive integers below currentVersion`,
            );
            break;
          }
          uniqueLegacyVersions.add(version);
        }
      }
    } else if (schema.versionStatus === 'semantic-versioned') {
      if (
        typeof schema.currentVersion !== 'string' ||
        !/^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$/.test(schema.currentVersion)
      ) {
        failures.push(`${schema.id} currentVersion must be a safe semantic identifier`);
      }
      if (
        schema.schemaUriVersion !== undefined &&
        (!Number.isInteger(schema.schemaUriVersion) || schema.schemaUriVersion < 1)
      ) {
        failures.push(`${schema.id} schemaUriVersion must be a positive integer`);
      }
    } else if (schema.versionStatus === 'unversioned' && schema.currentVersion !== null) {
      failures.push(`${schema.id} unversioned surfaces must use currentVersion null`);
    }

    if (schema.versionStatus === 'unversioned') {
      if (!Array.isArray(schema.versionEvidence) || schema.versionEvidence.length !== 0) {
        failures.push(`${schema.id} unversioned surfaces cannot claim versionEvidence`);
      }
      if (typeof schema.surfaceMarker !== 'string' || schema.surfaceMarker.length === 0) {
        failures.push(`${schema.id} unversioned surfaceMarker is missing`);
      } else if (primaryText !== null && !primaryText.includes(schema.surfaceMarker)) {
        failures.push(`${schema.id} surfaceMarker was not found in ${schema.source}`);
      }
      continue;
    }

    if (!Array.isArray(schema.versionEvidence) || schema.versionEvidence.length === 0) {
      failures.push(`${schema.id} versionEvidence must be a non-empty array`);
      continue;
    }
    for (const [evidenceIndex, evidence] of schema.versionEvidence.entries()) {
      const evidenceLabel = `${schema.id} versionEvidence[${evidenceIndex}]`;
      const evidenceSource = evidence?.source ?? schema.source;
      const text =
        evidenceSource === schema.source
          ? primaryText
          : sourceText(
              repoRoot,
              evidenceSource,
              failures,
              evidenceLabel,
              schema.surfaceKind,
            );
      if (text === null) continue;
      const extracted = extractEvidenceVersion({
        schema,
        evidence,
        text,
        failures,
        label: evidenceLabel,
      });
      const catalogVersionField = evidence.catalogVersionField ?? 'currentVersion';
      if (!['currentVersion', 'schemaUriVersion'].includes(catalogVersionField)) {
        failures.push(`${evidenceLabel} catalogVersionField is unsupported`);
        continue;
      }
      if (
        catalogVersionField === 'schemaUriVersion' &&
        schema.versionStatus !== 'semantic-versioned'
      ) {
        failures.push(
          `${evidenceLabel} schemaUriVersion evidence requires semantic-versioned status`,
        );
        continue;
      }
      const expectedVersion = schema[catalogVersionField];
      if (expectedVersion === undefined) {
        failures.push(`${evidenceLabel} catalog field ${catalogVersionField} is missing`);
        continue;
      }
      if (extracted !== null && extracted !== expectedVersion) {
        failures.push(
          `${evidenceLabel} source version ${JSON.stringify(extracted)} ` +
            `does not match catalog ${JSON.stringify(expectedVersion)}`,
        );
      }
      if (evidence.kind === 'dart-int-constant') {
        const key = `${evidenceSource}:${evidence.symbol}`;
        const owners = claimedConstants.get(key) ?? [];
        owners.push(schema.id);
        claimedConstants.set(key, owners);
      }
    }
  }

  for (const required of requiredSchemaSurfaces) {
    const entry = entriesById.get(required.id);
    if (!entry) {
      failures.push(`required schema surface is missing: ${required.id}`);
    } else if (entry.source !== required.source) {
      failures.push(
        `${required.id} required source is ${required.source}, catalog has ${entry.source}`,
      );
    }
  }

  const dartFiles = listDartFiles(repoRoot);
  const discoveredUris = discoverSchemaUris(repoRoot, dartFiles);
  for (const discovered of discoveredUris) {
    const entry = entriesById.get(discovered.id);
    if (!entry) {
      failures.push(
        `discovered schema URI is not cataloged: ${discovered.id}/${discovered.version} in ${discovered.source}`,
      );
      continue;
    }
    const acceptedVersions =
      entry.versionStatus === 'semantic-versioned'
        ? new Set([entry.schemaUriVersion])
        : new Set([
            entry.currentVersion,
            ...(entry.acceptedLegacyVersions ?? []),
          ]);
    if (
      !['versioned', 'semantic-versioned'].includes(entry.versionStatus) ||
      !acceptedVersions.has(discovered.version)
    ) {
      failures.push(
        `discovered schema URI ${discovered.id}/${discovered.version} disagrees with catalog`,
      );
    }
  }

  const discoveredConstants = discoverNamedSchemaVersionConstants(repoRoot, dartFiles);
  for (const discovered of discoveredConstants) {
    const key = `${discovered.source}:${discovered.symbol}`;
    const owners = claimedConstants.get(key) ?? [];
    if (owners.length === 0) {
      failures.push(
        `discovered schema-version constant is not cataloged: ${key}=${discovered.version}`,
      );
    } else if (owners.length > 1) {
      failures.push(
        `schema-version constant is claimed by multiple catalog entries: ${key} (${owners.join(', ')})`,
      );
    }
  }

  return failures;
}

export function readAndValidateSchemaCatalog({
  repoRoot = defaultRepoRoot,
  catalogPath = defaultCatalogPath,
} = {}) {
  const absoluteCatalogPath = path.join(repoRoot, catalogPath);
  let catalog;
  try {
    catalog = JSON.parse(fs.readFileSync(absoluteCatalogPath, 'utf8'));
  } catch (error) {
    return {
      catalog: null,
      failures: [`catalog cannot be read as JSON: ${error.message}`],
    };
  }
  return { catalog, failures: validateSchemaCatalog(catalog, { repoRoot }) };
}

function main() {
  const { catalog, failures } = readAndValidateSchemaCatalog();
  if (failures.length > 0) {
    for (const failure of failures) process.stderr.write(`FAIL ${failure}\n`);
    process.exitCode = 1;
    return;
  }
  const versioned = catalog.schemas.filter(
    (schema) => schema.versionStatus !== 'unversioned',
  ).length;
  const unversioned = catalog.schemas.length - versioned;
  process.stdout.write(
    `Schema catalog passed: ${catalog.schemas.length} required surfaces ` +
      `(${versioned} versioned, ${unversioned} explicitly unversioned)\n`,
  );
}

if (process.argv[1] && path.resolve(process.argv[1]) === modulePath) main();
