import assert from 'node:assert/strict';
import test from 'node:test';

import {
  readAndValidateUpgradeQueue,
  validateUpgradeQueue,
} from './complete_app_upgrade_queue_check.mjs';

function requiredItem(queue, id) {
  const item = queue.items.find((candidate) => candidate.id === id);
  assert.ok(item, `missing queue item ${id}`);
  return item;
}

test('committed complete-app queue passes its contract', () => {
  const { queue, failures } = readAndValidateUpgradeQueue();
  assert.deepEqual(failures, []);
  assert.ok(queue.items.some((item) => item.status === 'research_required'));
  assert.ok(queue.items.some((item) => item.status === 'external_dependency'));
});

test('structural uncertainty is observable-matched and identifiability-gated', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(
    queue,
    'mechanistic_structural_uncertainty_shadow_models',
  );
  const contract = [item.currentGap, ...item.acceptanceCriteria]
    .join(' ')
    .toLowerCase();
  for (const term of [
    'elashoff power-exponential',
    'modified power-exponential',
    'linear-exponential',
    'explicit-lag',
    'double-weibull',
    'observable',
    'identifi',
    'profile-likelihood',
    'held-out',
  ]) {
    assert.ok(contract.includes(term), `missing structural gate: ${term}`);
  }
  assert.deepEqual(item.dependencies, ['unit_aware_mechanistic_event_ledger']);
});

test('complete-model queue preserves provenance, event, and dataset lineage', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const config = requiredItem(queue, 'algorithm_configuration_identity_digest');
  const ledger = requiredItem(queue, 'unit_aware_mechanistic_event_ledger');
  const governance = requiredItem(queue, 'calibration_dataset_governance');
  const calibration = requiredItem(queue, 'prospective_clinical_calibration');

  const configContract = config.acceptanceCriteria.join(' ').toLowerCase();
  for (const term of [
    'structure/formula id',
    'canonical unit',
    'literature-derived',
    'calibration-dataset',
    'configuration digest',
  ]) {
    assert.ok(configContract.includes(term), `missing provenance gate: ${term}`);
  }

  assert.ok(
    ledger.dependencies.includes('algorithm_configuration_identity_digest'),
  );
  assert.ok(
    ledger.dependencies.includes('mechanistic_model_invariant_and_unit_gate'),
  );
  assert.match(ledger.acceptanceCriteria.join(' '), /dose, meal, observation/);
  assert.match(ledger.acceptanceCriteria.join(' '), /canonical ledger digest/);

  assert.ok(governance.dependencies.includes('unit_aware_mechanistic_event_ledger'));
  assert.ok(governance.dependencies.includes('server_authoritative_provenance'));
  assert.match(
    governance.acceptanceCriteria.join(' '),
    /subject, site, and time/i,
  );
  assert.match(governance.acceptanceCriteria.join(' '), /raw participant data/);
  assert.ok(calibration.dependencies.includes('calibration_dataset_governance'));
  assert.ok(
    calibration.dependencies.includes(
      'mechanistic_structural_uncertainty_shadow_models',
    ),
  );
  assert.match(calibration.acceptanceCriteria.join(' '), /separate claimed layers/);
});

test('open-source, backend, and device gates retain their hard boundaries', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const license = requiredItem(queue, 'open_source_pattern_license_firewall');
  const licenseContract = [license.currentGap, ...license.acceptanceCriteria].join(
    ' ',
  );
  for (const term of ['GPL-2.0', 'GPL-3.0', 'MIT', 'SPDX', 'SBOM']) {
    assert.ok(licenseContract.includes(term), `missing license gate: ${term}`);
  }
  assert.match(license.currentGap, /34 GitHub repositories/);
  assert.match(license.currentGap, /NOASSERTION/);
  const upstreamDrift = requiredItem(
    queue,
    'upstream_semantic_license_drift_revalidation',
  );
  assert.ok(
    upstreamDrift.dependencies.includes('open_source_pattern_license_firewall'),
  );
  assert.match(upstreamDrift.acceptanceCriteria.join(' '), /without mutating/);
  assert.match(upstreamDrift.acceptanceCriteria.join(' '), /NOASSERTION/);

  const backend = requiredItem(queue, 'registered_first_day_backend_conformance');
  assert.match(backend.acceptanceCriteria.join(' '), /production Auth/);
  assert.match(backend.acceptanceCriteria.join(' '), /without test-only repository/);
  assert.match(backend.acceptanceCriteria.join(' '), /cold new service graph/);

  const notification = requiredItem(
    queue,
    'notification_platform_truth_and_delivery_gate',
  );
  const notificationContract = notification.acceptanceCriteria.join(' ');
  assert.match(notificationContract, /physical-device evidence/);
  assert.match(notificationContract, /pending-request counts alone never/);
  assert.match(notificationContract, /exact-alarm eligibility/);
  assert.match(notificationContract, /daylight-saving transitions/);

  const notificationLocale = requiredItem(
    queue,
    'notification_locale_snapshot_reconciliation',
  );
  assert.ok(
    notificationLocale.dependencies.includes(
      'notification_privacy_content_controls',
    ),
  );
  assert.match(notificationLocale.currentGap, /locale snapshot/);
  assert.match(notificationLocale.acceptanceCriteria.join(' '), /copy digest/);
  assert.match(
    notificationLocale.acceptanceCriteria.join(' '),
    /running, backgrounded, and terminated/,
  );

  const attestation = requiredItem(
    queue,
    'notification_pending_identity_attestation',
  );
  assert.equal(attestation.status, 'queued');
  assert.match(attestation.currentGap, /SHA-256 payload digest/);
  assert.match(attestation.currentGap, /platform evidence has not met acceptance/);
  assert.match(attestation.currentGap, /plugin registry rather than independent/);
  assert.match(attestation.currentGap, /visible delivery remain open/);
});

test('next-wave applicability, oracle, terminology, privacy, and durability gates stay linked', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const applicability = requiredItem(
    queue,
    'runtime_model_applicability_abstention_gate',
  );
  const oracle = requiredItem(queue, 'independent_numerical_verification_oracle');
  const terminology = requiredItem(
    queue,
    'versioned_clinical_nutrition_terminology_firewall',
  );
  const privacy = requiredItem(queue, 'store_privacy_declaration_drift_gate');
  const durability = requiredItem(
    queue,
    'cross_backend_durable_mutation_protocol',
  );
  const ledger = requiredItem(queue, 'unit_aware_mechanistic_event_ledger');
  const fhir = requiredItem(queue, 'fhir_interoperability_sandbox');
  const offline = requiredItem(queue, 'offline_conflict_awareness');

  assert.match(applicability.acceptanceCriteria.join(' '), /notApplicable/);
  assert.ok(oracle.dependencies.includes(applicability.id));
  assert.match(oracle.acceptanceCriteria.join(' '), /import no production/);
  assert.ok(ledger.dependencies.includes(terminology.id));
  assert.ok(fhir.dependencies.includes(terminology.id));
  assert.match(terminology.acceptanceCriteria.join(' '), /UCUM/);
  assert.match(privacy.acceptanceCriteria.join(' '), /human approval/);
  assert.ok(offline.dependencies.includes(durability.id));
  assert.match(durability.acceptanceCriteria.join(' '), /two-tab/);
});

test('complete-app user ownership queue keeps recovery, handoff, consent, support, and catalog boundaries distinct', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const history = requiredItem(queue, 'recoverable_user_event_history');
  const restoreImpact = requiredItem(
    queue,
    'relationship_aware_restore_impact_preview',
  );
  const historyCheckpoints = requiredItem(
    queue,
    'tamper_evident_user_event_history_checkpoints',
  );
  const handoff = requiredItem(queue, 'personal_log_handoff_summary');
  const consent = requiredItem(queue, 'purpose_bound_consent_receipts');
  const consentComprehension = requiredItem(
    queue,
    'consent_notice_comprehension_and_localization_gate',
  );
  const support = requiredItem(queue, 'privacy_safe_support_bundle');
  const supportCase = requiredItem(
    queue,
    'user_controlled_support_case_workflow',
  );
  const catalog = requiredItem(queue, 'catalog_change_reconciliation_center');
  const accessibleDocument = requiredItem(
    queue,
    'accessible_searchable_multiscript_document_export',
  );

  assert.ok(
    history.dependencies.includes('cross_backend_durable_mutation_protocol'),
  );
  assert.match(history.acceptanceCriteria.join(' '), /tombstoned records/);
  assert.match(history.currentGap, /never silently overwritten/);
  assert.ok(restoreImpact.dependencies.includes(history.id));
  assert.match(restoreImpact.acceptanceCriteria.join(' '), /recomputed/);
  assert.match(restoreImpact.acceptanceCriteria.join(' '), /stale preview/);
  assert.ok(historyCheckpoints.dependencies.includes(history.id));
  assert.match(historyCheckpoints.acceptanceCriteria.join(' '), /split-view/);
  assert.match(
    historyCheckpoints.acceptanceCriteria.join(' '),
    /do not establish Certificate Transparency conformance/,
  );
  assert.match(handoff.currentGap, /machine-oriented JSON snapshot/);
  assert.match(handoff.currentGap, /raster image rather than tagged\/searchable/);
  assert.match(handoff.acceptanceCriteria.join(' '), /not a medical record/);
  assert.ok(accessibleDocument.dependencies.includes(handoff.id));
  assert.match(
    accessibleDocument.acceptanceCriteria.join(' '),
    /tagged PDF structure tree/,
  );
  assert.match(
    accessibleDocument.acceptanceCriteria.join(' '),
    /validator pass is never described as clinical/,
  );
  assert.equal(consent.status, 'queued');
  assert.match(consent.acceptanceCriteria.join(' '), /defaults to denied/);
  assert.match(consent.currentGap, /schema-v1 append-style receipt ledger/);
  assert.equal(consentComprehension.status, 'research_required');
  assert.ok(consentComprehension.dependencies.includes(consent.id));
  assert.match(
    consentComprehension.acceptanceCriteria.join(' '),
    /defaults to denied/,
  );
  assert.match(support.acceptanceCriteria.join(' '), /raw exceptions/);
  assert.match(support.currentGap, /Unknown counts remain null/);
  assert.match(support.currentGap, /without an upload path/);
  assert.equal(supportCase.status, 'research_required');
  assert.ok(supportCase.dependencies.includes(support.id));
  assert.ok(supportCase.dependencies.includes(consent.id));
  assert.match(supportCase.acceptanceCriteria.join(' '), /explicitly start and stop/);
  assert.match(supportCase.acceptanceCriteria.join(' '), /never reclassified as machine-safe/);
  assert.match(supportCase.acceptanceCriteria.join(' '), /No destination opens/);
  assert.ok(
    catalog.dependencies.includes(
      'versioned_clinical_nutrition_terminology_firewall',
    ),
  );
  assert.match(catalog.acceptanceCriteria.join(' '), /force affected algorithms to abstain/);
});

test('operations, performance, rollout, and supply-chain gates retain complete-app boundaries', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const observability = requiredItem(
    queue,
    'privacy_preserving_operational_observability',
  );
  const performance = requiredItem(
    queue,
    'cross_platform_performance_energy_budget',
  );
  const rollout = requiredItem(queue, 'signed_capability_rollout_kill_switch');
  const attestation = requiredItem(
    queue,
    'reproducible_release_sbom_attestation',
  );

  const observabilityContract = observability.acceptanceCriteria.join(' ');
  assert.match(observabilityContract, /defaults to disabled/);
  assert.match(observabilityContract, /stable account hash/);
  assert.ok(
    observability.dependencies.includes('purpose_bound_consent_receipts'),
  );

  const performanceContract = performance.acceptanceCriteria.join(' ');
  assert.match(performanceContract, /physical Android and iOS devices/);
  assert.match(performanceContract, /emulator numbers cannot satisfy/);
  assert.ok(
    performance.dependencies.includes('artifact_level_black_box_journeys'),
  );

  const rolloutContract = rollout.acceptanceCriteria.join(' ');
  assert.match(rolloutContract, /conservative local default/);
  assert.match(rolloutContract, /cannot remotely alter clinical-algorithm/);
  assert.ok(
    rollout.dependencies.includes('algorithm_configuration_identity_digest'),
  );

  const attestationContract = attestation.acceptanceCriteria.join(' ');
  assert.match(attestationContract, /CycloneDX or SPDX SBOM/);
  assert.match(attestationContract, /offline verification bundle/);
  assert.match(attestationContract, /never presented as scientific/);
});

test('secret storage, implicit backup, and backend residency remain separate fail-closed contracts', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const secrets = requiredItem(
    queue,
    'device_bound_secret_storage_and_rotation',
  );
  const backup = requiredItem(
    queue,
    'platform_data_protection_and_backup_attestation',
  );
  const encryptedRecords = requiredItem(
    queue,
    'encrypted_critical_record_envelopes',
  );
  const cryptographicAgility = requiredItem(
    queue,
    'cryptographic_agility_and_deprecation_gate',
  );
  const residency = requiredItem(
    queue,
    'backend_location_retention_residency_contract',
  );

  const secretContract = secrets.acceptanceCriteria.join(' ');
  assert.match(secretContract, /attested security level/);
  assert.match(secretContract, /physical-device tests/);
  assert.ok(secrets.dependencies.includes('account_lifecycle'));
  assert.match(secrets.currentGap, /schema-v1 protected envelope/);
  assert.match(secrets.currentGap, /No platform is labeled hardware-backed/);

  const encryptedRecordContract = encryptedRecords.acceptanceCriteria.join(' ');
  assert.match(encryptedRecords.currentGap, /does not by itself provide record confidentiality/);
  assert.match(encryptedRecordContract, /unique nonces/);
  assert.match(encryptedRecordContract, /atomic old-or-new protocol/);
  assert.ok(
    encryptedRecords.dependencies.includes(
      'device_bound_secret_storage_and_rotation',
    ),
  );

  const agilityContract = cryptographicAgility.acceptanceCriteria.join(' ');
  assert.match(cryptographicAgility.currentGap, /no generated inventory/);
  assert.match(agilityContract, /allowed, transitional, deprecated, and prohibited/);
  assert.match(agilityContract, /does not claim present quantum resistance/);
  assert.ok(
    cryptographicAgility.dependencies.includes(
      'encrypted_critical_record_envelopes',
    ),
  );

  const backupContract = backup.acceptanceCriteria.join(' ');
  assert.match(backup.currentGap, /implicit platform channel/);
  assert.match(backupContract, /explicit user-owned export/);
  assert.ok(
    backup.dependencies.includes('device_bound_secret_storage_and_rotation'),
  );

  const residencyContract = residency.acceptanceCriteria.join(' ');
  assert.match(residency.currentGap, /cannot later be changed/);
  assert.match(residencyContract, /actual service state/);
  assert.match(residencyContract, /legal residency or regulatory conclusions/);
  assert.ok(
    residency.dependencies.includes('store_privacy_declaration_drift_gate'),
  );
});

test('score drift and unknown dependencies fail closed', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const mutated = structuredClone(queue);
  mutated.items[0].score += 1;
  mutated.items[0].dependencies.push('does_not_exist');
  const failures = validateUpgradeQueue(mutated);
  assert.ok(failures.some((failure) => failure.includes('does not match')));
  assert.ok(failures.some((failure) => failure.includes('unknown dependency')));
});

test('dependency cycles fail closed', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const mutated = structuredClone(queue);
  mutated.items[0].dependencies.push(mutated.items[1].id);
  mutated.items[1].dependencies.push(mutated.items[0].id);
  assert.ok(
    validateUpgradeQueue(mutated).some((failure) =>
      failure.includes('dependency cycle'),
    ),
  );
});
