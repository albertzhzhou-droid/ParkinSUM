#!/usr/bin/env node
// Runs every deterministic governance gate plus the committed-golden drift
// check, and composes the results into build/verify_all/latest.{json,md}.
//
// Usage:
//   npm run verify:all              # all gates, non-zero exit on any blocker
//   npm run verify:all -- --list    # print the gate list and exit 0
//   npm run verify:all -- --skip-goldens
//
// Why this exists: the gates were previously reachable only as ~10 separate CI
// steps. There was no single command a reviewer could run and no composed
// output — just a green check and scattered logs. Every gate here is offline,
// synthetic-data only, and exits non-zero on a blocker, so this is a real
// ratchet rather than a summary.
//
// The composed report is timestamp-free, matching the other artifacts in this
// repo, so regenerated reports diff cleanly. A gate that did not run is
// recorded as `missing_artifact` — never as a pass.
//
// Educational/research prototype. Synthetic data only. Not medical advice.

import { spawnSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';

const MISSING = 'missing_artifact';

/** Every gate runs offline against synthetic fixtures. */
const GATES = [
  { id: 'copy_compile', script: 'copy:compile', what: 'Explanation copy compiles (0 blocker)' },
  { id: 'localization_lint', script: 'localization:lint', what: 'Localization safety lint (full i18n dictionary)' },
  { id: 'dose_expression_grammar', script: 'dose:grammar', what: 'Dose-expression grammar differential conformance (Dart + JavaScript)' },
  { id: 'rxnorm_release_identity', script: 'rxnorm:release-identity:check', what: 'Pinned RxNorm release identity, scope, terms, and no-ingestion boundary' },
  { id: 'infoods_tagname_source_identity', script: 'infoods:source-identity:check', what: 'FAO/INFOODS tagname-page currency, completeness hold, and no-mapping boundary' },
  { id: 'dose_confirmation', script: 'dose:confirmation', what: 'Administration-dose confirmation receipt and reconciliation mutations' },
  { id: 'assertion_reconciliation', script: 'assertion:reconciliation', what: 'Medication assertion source, time, conflict, and acknowledgement mutations' },
  { id: 'gastric_structures', script: 'gastric:structures', what: 'Observable-matched gastric structural uncertainty and fit authorization' },
  { id: 'gastric_precision', script: 'gastric:precision', what: 'Independent high-precision gastric shadow-model reference' },
  { id: 'mechanistic_replay', script: 'mechanistic:replay', what: 'Mechanistic replay' },
  { id: 'mechanistic_invariants', script: 'mechanistic:invariants', what: 'Mathematical invariant, unit, dose-input, and visible coverage gate' },
  { id: 'mechanistic_ledger_authorization', script: 'mechanistic:ledger-authorization', what: 'Exact production-input ledger binding and fail-closed mutation gate' },
  { id: 'mechanistic_lossless_replay', script: 'mechanistic:lossless-replay', what: 'Lossless mechanistic replay capsule and independent cross-runtime canonicalization' },
  { id: 'portable_schema_migration', script: 'portable:schema-migration', what: 'Frozen portable-schema validators, deterministic migration receipts, and independent cross-runtime conformance' },
  { id: 'portable_schema_fuzz', script: 'portable:schema-fuzz', what: 'Fixed-seed portable-schema parser differential campaign and corpus-level privacy-reviewed synthetic regression corpus' },
  { id: 'algorithm_dependency_compatibility', script: 'algorithm:dependency-compatibility', what: 'Exact analyzer lock, stable 65-root identity, session consistency, and fail-closed compatibility HOLD gate' },
  { id: 'algorithm_trace_surface', script: 'algorithm:trace-surface', what: 'Versioned production-trace provider, fixture, route, UI-surface, and static-only disposition manifest' },
  { id: 'algorithm_executable_contracts', script: 'algorithm:contracts', what: 'Non-numerical executable contracts and metamorphic mutations' },
  { id: 'algorithm_contract_independent_oracle', script: 'algorithm:contracts:independent', what: 'Independent cross-runtime relation, mutation, and scheduler oracle' },
  { id: 'algorithm_relation_domain_sampling', script: 'algorithm:contracts:sampling', what: 'Deterministic relation-IR sampling, precondition HOLD, mutation, and false-alarm calibration' },
  { id: 'recommendation_replay', script: 'recommend:replay', what: 'Local AI scenario replay (candidate-set invariant)' },
  { id: 'scenario_fuzz', script: 'scenario:fuzz', what: 'Synthetic scenario fuzzer' },
  { id: 'privacy_preflight', script: 'privacy:preflight', what: 'Local privacy preflight' },
  { id: 'store_privacy_contract', script: 'privacy:store', what: 'Store privacy declaration drift contract' },
  { id: 'web_reflow_contract', script: 'accessibility:web-reflow:test', what: 'Web release-artifact reflow probe fail-closed contract' },
  { id: 'wasm_hosting_contract', script: 'wasm:hosting-attestation:test', what: 'Wasm hosting and platform-selection fail-closed contract' },
  { id: 'android_reminder_attestation_contract', script: 'reminder:android-attestation:test', what: 'Android reminder artifact-bound attestation fail-closed contract' },
  { id: 'open_source_influence', script: 'open-source:firewall', what: 'Open-source influence and license firewall' },
  { id: 'open_source_drift_proposal_contract', script: 'open-source:drift-proposal:test', what: 'Read-only upstream metadata drift proposal contract' },
  { id: 'open_source_drift_decision_ledger_contract', script: 'open-source:drift-ledger:test', what: 'Append-only human review chain and accepted drift-baseline binding' },
  { id: 'fhir_r5_cpg_apply_contract', script: 'fhir:r5:cpg-apply-contract', what: 'Fixed synthetic FHIR R5 PlanDefinition/$apply structure-only contract' },
  { id: 'fhir_r5_activitydefinition_apply_contract', script: 'fhir:r5:activitydefinition-apply-contract', what: 'Fixed synthetic FHIR R5 ActivityDefinition/$apply direct-result structure contract' },
  { id: 'fhir_r5_plandefinition_data_requirements_contract', script: 'fhir:r5:plandefinition-data-requirements-contract', what: 'Fixed synthetic FHIR R5 PlanDefinition/$data-requirements direct module-definition Library contract' },
  { id: 'fhir_r5_validator_runner_contract', script: 'fhir:r5:cpg-apply:validator:test', what: 'Pinned HL7 FHIR R5 validator invocation, version, and three-resource result-summary contract (no CLI execution)' },
  { id: 'source_access', script: 'source:access', what: 'Source access contract check' },
  { id: 'source_drift', script: 'source:drift', what: 'Source version drift check' },
  { id: 'contribution_route', script: 'contribution:route', what: 'Contribution safety router' },
  { id: 'schema_contract', script: 'schema:contract', what: 'Central schema catalog, version, and source-discovery contract' },
  { id: 'cou_requalification', script: 'cou:requalification', what: 'Context-of-use change and requalification ledger' },
  { id: 'algorithm_configuration_impact', script: 'algorithm:configuration-impact', what: 'Configuration semantic difference, impact graph, replay, and requalification matrix' },
  { id: 'configuration_baseline_registry', script: 'configuration:baseline', what: 'Append-only signed configuration baseline promotion and rollback registry' },
  { id: 'prospective_credibility', script: 'credibility:prospective', what: 'Prospective model credibility and post-study adequacy gate' },
  { id: 'credibility_execution', script: 'credibility:execution', what: 'Credibility-evidence split independence and leakage mutation gate' },
  { id: 'protocol_transparency', script: 'credibility:transparency', what: 'Protocol amendment, deviation, correction and result-transparency ledger' },
  { id: 'blinded_replication', script: 'credibility:replication', what: 'Blinded independent replication capsule and discrepancy adjudication' },
  { id: 'statistical_analysis', script: 'credibility:statistics', what: 'Statistical analysis, error control, and uncertainty governance' },
  { id: 'randomization_interim', script: 'credibility:randomization', what: 'Randomization, allocation concealment, and interim-access firewall' },
  { id: 'adaptive_design', script: 'credibility:adaptive', what: 'Adaptive-design operating characteristics and decision-rule calibration' },
  { id: 'bayesian_borrowing', script: 'credibility:bayesian', what: 'Bayesian prior, borrowing conflict, and posterior-decision calibration' },
  { id: 'bayesian_multisource', script: 'credibility:multisource', what: 'Bayesian multi-source transportability, model criticism, and independent replication' },
  { id: 'target_transportability', script: 'credibility:transportability', what: 'Target-population identification, overlap, doubly robust estimation, and independent replication' },
  { id: 'transport_sensitivity', script: 'credibility:transport-sensitivity', what: 'Target-transportability bias functions, global sensitivity, partial identification, and independent replication' },
  { id: 'evidence_currency', script: 'evidence:currency', what: 'Evidence currency, correction, retraction and sunset gate' },
  { id: 'evidence_synthesis', script: 'evidence:synthesis', what: 'Claim evidence contradiction and synthesis adjudication' },
];

/**
 * The cross-commit drift ratchet. Listing `verify:all` as "all gates" while
 * skipping the goldens would be precisely the kind of overclaim these checks
 * exist to prevent, so it runs by default.
 */
const GOLDEN_GATE = {
  id: 'committed_goldens',
  what: 'Committed golden drift check (cross-commit)',
  command: 'flutter',
  args: ['test', 'test/goldens_test.dart'],
};

const argv = process.argv.slice(2);
const skipGoldens = argv.includes('--skip-goldens');

if (argv.includes('--list')) {
  for (const gate of GATES) console.log(`${gate.id}\tnpm run ${gate.script}`);
  if (!skipGoldens) console.log(`${GOLDEN_GATE.id}\tflutter test test/goldens_test.dart`);
  process.exit(0);
}

/** Runs one gate, capturing its status without letting a crash pass as success. */
function runGate(gate) {
  const command = gate.command ?? 'npm';
  const args = gate.args ?? ['run', '--silent', gate.script];
  const result = spawnSync(command, args, { encoding: 'utf8' });

  // A spawn that never produced an exit status did not pass — it did not run.
  if (result.error || result.status === null) {
    return {
      id: gate.id,
      what: gate.what,
      status: MISSING,
      exit_code: null,
      detail: result.error ? String(result.error.message) : 'no exit status',
    };
  }

  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`.trim();
  const lines = output.split('\n').filter((line) => line.trim().length > 0);
  return {
    id: gate.id,
    what: gate.what,
    status: result.status === 0 ? 'pass' : 'FAILED',
    exit_code: result.status,
    // Last meaningful line only: enough to identify the failure without
    // pasting an entire gate log into a committed report.
    detail: lines.length > 0 ? lines[lines.length - 1] : '(no output)',
  };
}

const gatesToRun = skipGoldens ? GATES : [...GATES, GOLDEN_GATE];
const results = [];
for (const gate of gatesToRun) {
  process.stdout.write(`• ${gate.what} … `);
  const result = runGate(gate);
  results.push(result);
  console.log(result.status);
}

const failed = results.filter((r) => r.status !== 'pass');
const pass = failed.length === 0;

const report = {
  report_type: 'parkinsum_verify_all',
  // Deliberately timestamp-free so regenerated reports diff cleanly.
  gate_count: results.length,
  pass,
  failed_gate_ids: failed.map((r) => r.id),
  goldens_included: !skipGoldens,
  gates: results,
  not_clinically_calibrated: true,
  synthetic_demo_data_only: true,
  no_medical_advice: true,
  safety_boundary:
    'Do not change medication, diet, or timing based on this app. Review ' +
    'with a qualified clinician before making health decisions.',
  not_advice_text:
    'This is an educational prototype output. It is not medical advice and ' +
    'must not be used to make medication, dietary, or timing decisions.',
};

const markdown = [
  '# Verification summary',
  '',
  'Every gate below is deterministic, offline, and runs on synthetic/demo data',
  'only. This is an educational prototype and is not calibrated for real care.',
  '',
  `**Result:** ${pass ? 'all gates passed' : `${failed.length} gate(s) failed`}`,
  `**Goldens included:** ${skipGoldens ? 'no (--skip-goldens)' : 'yes'}`,
  '',
  '| Gate | Status | Detail |',
  '| --- | --- | --- |',
  ...results.map(
    (r) => `| ${r.what} | ${r.status} | ${String(r.detail).replaceAll('|', '\\|')} |`,
  ),
  '',
  '## Reproduce',
  '',
  '```bash',
  'npm run verify:all',
  '```',
  '',
  '## Safety boundary',
  '',
  report.safety_boundary,
  '',
  report.not_advice_text,
  '',
].join('\n');

mkdirSync('build/verify_all', { recursive: true });
writeFileSync('build/verify_all/latest.json', `${JSON.stringify(report, null, 2)}\n`);
writeFileSync('build/verify_all/latest.md', markdown);

console.log('');
console.log(
  pass
    ? `All ${results.length} gates passed.`
    : `${failed.length} of ${results.length} gates failed: ${failed.map((r) => r.id).join(', ')}`,
);
console.log('Report: build/verify_all/latest.json');
console.log('Report: build/verify_all/latest.md');

process.exit(pass ? 0 : 1);
