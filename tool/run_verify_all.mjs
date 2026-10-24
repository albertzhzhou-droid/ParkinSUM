#!/usr/bin/env node
// The existing 56 offline gates, now with owned child supervision and explicit
// producer contracts. Interrupted, absent, stale or malformed evidence cannot
// become a pass. Console-only checks are described as console contracts.
import { randomUUID } from 'node:crypto';
import { existsSync, readFileSync, unlinkSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { outputDeclaration, reportPasses } from './verification_output_contracts.mjs';
import { atomicJson, artifactIdentity, captureInputs, collectToolchain, declaredEnvironment, digestObject, localPath, supervise } from './verification_runtime.mjs';

export const VERIFY_REPORT_SCHEMA_VERSION = 2;
export const VERIFY_REPORT_SCHEMA = 'parkinsum.verification-suite-report/2';
export const VERIFY_CHECKPOINT_SCHEMA = 'parkinsum.verification-checkpoint/2';
export const GATES = [
  { id: 'copy_compile', script: 'copy:compile', what: 'Explanation copy compiles (0 blocker)' },
  { id: 'localization_lint', script: 'localization:lint', what: 'Localization safety lint (full i18n dictionary)' },
  { id: 'dose_expression_grammar', script: 'dose:grammar', what: 'Dose-expression grammar differential conformance (Dart + JavaScript)' },
  { id: 'rxnorm_release_identity', script: 'rxnorm:release-identity:check', what: 'Pinned RxNorm release identity, scope, terms, and no-ingestion boundary' },
  { id: 'infoods_tagname_source_identity', script: 'infoods:source-identity:check', what: 'FAO/INFOODS tagname-page currency, completeness hold, and no-mapping boundary' },
  { id: 'dose_confirmation', script: 'dose:confirmation', what: 'Administration-dose confirmation receipt and reconciliation mutations' },
  { id: 'assertion_reconciliation', script: 'assertion:reconciliation', what: 'Medication assertion source, time, conflict, and acknowledgement mutations' },
  { id: 'gastric_structures', script: 'gastric:structures', what: 'Observable-matched gastric structural uncertainty and fit authorization' },
  { id: 'gastric_precision', script: 'gastric:precision', what: 'Independent high-precision gastric shadow-model reference' },
  { id: 'physiology_reality', script: 'physiology:reality', what: 'Physiology reference reality checks against published human data, fixture freshness, and Dart/Python agreement' },
  { id: 'mechanistic_replay', script: 'mechanistic:replay', what: 'Mechanistic replay' },
  { id: 'mechanistic_invariants', script: 'mechanistic:invariants', what: 'Mathematical invariant, unit, dose-input, and visible coverage gate' },
  { id: 'mechanistic_ledger_authorization', script: 'mechanistic:ledger-authorization', what: 'Exact production-input ledger binding and fail-closed mutation gate' },
  { id: 'mechanistic_lossless_replay', script: 'mechanistic:lossless-replay', what: 'Lossless replay envelopes, independent cross-runtime canonicalization and pinned rule/history/DST conformance' },
  { id: 'portable_schema_migration', script: 'portable:schema-migration', what: 'Frozen portable-schema validators, deterministic migration receipts, and independent cross-runtime conformance' },
  { id: 'portable_schema_fuzz', script: 'portable:schema-fuzz', what: 'Fixed-seed portable-schema parser differential campaign and corpus-level privacy-reviewed synthetic regression corpus' },
  { id: 'algorithm_dependency_compatibility', script: 'algorithm:dependency-compatibility', what: 'Exact analyzer lock, stable 67-root identity, session consistency, and fail-closed compatibility HOLD gate' },
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

// Pin the reporter: GitHub Actions otherwise selects a different summary format
// from the strict Flutter completion contract used below.
export const GOLDEN_GATE = { id: 'committed_goldens', what: 'Committed golden drift check (cross-commit)', command: 'flutter', args: ['test', '--reporter=expanded', 'test/goldens_test.dart'] };

export function defaultGates(skipGoldens = false) {
  return (skipGoldens ? GATES : [...GATES, GOLDEN_GATE]).map((gate) => {
    const declaration = outputDeclaration(gate.id);
    const args = gate.args ?? ['run', '--silent', gate.script];
    return { ...gate, command: gate.command ?? 'npm', args: declaration.reportArgument ? [...args, '--', declaration.reportArgument] : args, output: declaration };
  });
}

function validGate(gate) {
  if (!/^[a-z0-9_]+$/.test(gate.id) || typeof gate.command !== 'string' || !Array.isArray(gate.args) || gate.args.some((arg) => typeof arg !== 'string')) throw new Error('Invalid gate command identity');
  if (!['json_files', 'console_test', 'metadata_console'].includes(gate.output?.mode) || !Array.isArray(gate.output.reports)) throw new Error(`Gate lacks an explicit output mode: ${gate.id}`);
  if (gate.output.mode === 'json_files' && !gate.output.reports.length) throw new Error(`Gate has no declared producer: ${gate.id}`);
  if (Object.hasOwn(gate.output, 'completion') && (!gate.output.completion || gate.output.mode !== 'console_test' || gate.output.completion.protocol !== 'flutter_test_summary_v1' || !Number.isSafeInteger(gate.output.completion.minimum_passed) || gate.output.completion.minimum_passed <= 0)) throw new Error(`Unsupported console completion contract: ${gate.id}`);
  for (const report of gate.output.reports) if (!/^build\/[a-zA-Z0-9_./-]+\.json$/.test(report.path) || report.path.split('/').includes('..')) throw new Error('Unsafe report declaration');
}

export function validateConsoleCompletion(cwd, gate, execution, logPath) {
  if (!gate.output.completion) return null;
  if (execution?.log_truncated !== false) return { passed: false, reason: 'console_log_incomplete' };
  const text = readFileSync(localPath(cwd, logPath), 'utf8').replace(/\x1b\[[0-?]*[ -/]*[@-~]/g, '');
  const summaries = [...text.matchAll(/(?:\d+:)+\d+\s+\+(\d+)(?:\s+~(\d+))?(?:\s+-(\d+))?:/g)];
  if (summaries.some(row => Number(row[3] ?? 0) !== 0)) return { passed: false, reason: 'console_reported_test_failure' };
  if (!text.includes('All tests passed!') || !summaries.length) return { passed: false, reason: 'console_test_completion_missing' };
  const last = summaries.at(-1);
  const counts = { passed: Number(last[1]), skipped: Number(last[2] ?? 0), failed: Number(last[3] ?? 0) };
  if (counts.passed < gate.output.completion.minimum_passed || counts.skipped !== 0) return { passed: false, reason: 'console_test_count_incomplete', counts };
  return { passed: true, reason: null, counts };
}

export function gateIdentity(gate, source, toolchain, environment, options) {
  return digestObject({ source_sha256: source.sha256, toolchain, environment, command: gate.command, args: gate.args, output: gate.output,
    timeout_ms: options.timeoutMs, cleanup_grace_ms: options.cleanupGraceMs, max_log_bytes: options.maxLogBytes });
}

export function validateReports(cwd, gate) {
  return gate.output.reports.map((contract) => {
    const artifact = artifactIdentity(cwd, contract.path);
    if (artifact.bytes > 32 * 1024 * 1024) throw new Error(`Oversized report: ${contract.path}`);
    const value = JSON.parse(readFileSync(localPath(cwd, contract.path), 'utf8'));
    if (!reportPasses(value, contract)) throw new Error(`Report failed its declared predicate/schema: ${contract.path}`);
    if (contract.predicate === 'fhir_structure') {
      const stem = gate.id;
      const fixture = `test/fixtures/${stem}.json`;
      const fixtureBytes = readFileSync(localPath(cwd, fixture));
      // Content identity is checked independently of the producer's status.
      if (value.fixtureSha256 !== (awaitlessSha(fixtureBytes))) throw new Error('FHIR fixture identity mismatch');
    }
    return artifact;
  });
}

// Kept outside report adapters so fixture hashes do not depend on a producer.
import { sha256 as awaitlessSha } from './verification_runtime.mjs';

export function reusable(cwd, previous, gate, inputSha256) {
  if (!previous || previous.status !== 'pass' || previous.input_identity_sha256 !== inputSha256 || previous.output_mode !== gate.output.mode) return false;
  try {
    if (gate.output.completion) {
      if (artifactIdentity(cwd, previous.log_path).sha256 !== previous.log_artifact?.sha256 || validateConsoleCompletion(cwd, gate, previous.execution, previous.log_path)?.passed !== true) return false;
    }
    const current = validateReports(cwd, gate);
    return current.length === previous.artifacts?.length && current.every((artifact, index) => artifact.sha256 === previous.artifacts[index].sha256 && artifact.path === previous.artifacts[index].path);
  } catch { return false; }
}

export async function runVerification({ cwd = process.cwd(), gates = defaultGates(), sourceFiles, toolchain, environment = declaredEnvironment(),
  timeoutMs = 900000, cleanupGraceMs = 1000, maxLogBytes = 1024 * 1024, resumePath, attachSignals = true, signal, onCheckpoint } = {}) {
  if (!gates.length || new Set(gates.map((gate) => gate.id)).size !== gates.length) throw new Error('Gate inventory is empty or duplicated');
  gates.forEach(validGate);
  for (const [name, number] of Object.entries({ timeoutMs, cleanupGraceMs, maxLogBytes })) if (!Number.isSafeInteger(number) || number <= 0) throw new Error(`Invalid ${name}`);
  const source = captureInputs(cwd, sourceFiles);
  const runId = randomUUID();
  const runDirectory = `build/verify_all/runs/${runId}`;
  const checkpointPath = `${runDirectory}/checkpoint.json`;
  let prior = null;
  if (resumePath) {
    if (!/^build\/verify_all\/runs\/[a-f0-9-]+\/checkpoint\.json$/.test(resumePath)) throw new Error('Resume requires an explicit local checkpoint path');
    prior = JSON.parse(readFileSync(localPath(cwd, resumePath), 'utf8'));
    if (prior.schema !== VERIFY_CHECKPOINT_SCHEMA || !Array.isArray(prior.gates)) throw new Error('Unsupported resume checkpoint');
  }
  const controller = new AbortController();
  const externalAbort = () => controller.abort(signal.reason ?? 'interrupted');
  signal?.addEventListener('abort', externalAbort, { once: true });
  if (signal?.aborted) externalAbort();
  const sigint = () => controller.abort('SIGINT');
  const sigterm = () => controller.abort('SIGTERM');
  if (attachSignals) { process.on('SIGINT', sigint); process.on('SIGTERM', sigterm); }
  const results = gates.map((gate) => ({ id: gate.id, what: gate.what ?? gate.id, status: 'not_run', reason: 'pending', output_mode: gate.output.mode, artifacts: [] }));
  let toolchainError = null;
  const capturedToolchain = toolchain ?? await collectToolchain(cwd, controller.signal).catch((error) => { toolchainError = error.message; return null; });
  const options = { timeoutMs, cleanupGraceMs, maxLogBytes };
  const checkpoint = () => ({ schema: VERIFY_CHECKPOINT_SCHEMA, schema_version: 2, run_id: runId, resumed_from_run_id: prior?.run_id ?? null,
    source, toolchain: capturedToolchain, environment, options, inventory: gates.map((gate) => ({ id: gate.id, command: gate.command, args: gate.args, output: gate.output })),
    interrupted: controller.signal.aborted, interruption: controller.signal.reason ?? null, toolchain_error: toolchainError, gates: results });
  const save = () => {
    const value = checkpoint();
    atomicJson(localPath(cwd, checkpointPath), value);
    atomicJson(localPath(cwd, 'build/verify_all/latest_checkpoint.json'), { schema: 'parkinsum.verification-checkpoint-pointer/1', run_id: runId, path: checkpointPath });
    onCheckpoint?.(value);
  };
  const sourceUnchanged = () => {
    try { return captureInputs(cwd, sourceFiles).sha256 === source.sha256; }
    catch { return false; }
  };
  try {
    save();
    for (let index = 0; index < gates.length; index += 1) {
      const gate = gates[index];
      const result = results[index];
      if (controller.signal.aborted || toolchainError) { result.reason = toolchainError ? 'toolchain_unavailable' : 'interrupted_before_execution'; continue; }
      if (!sourceUnchanged()) { result.reason = 'source_changed_before_execution'; controller.abort('source_changed'); continue; }
      const inputIdentity = gateIdentity(gate, source, capturedToolchain, environment, options);
      result.input_identity_sha256 = inputIdentity;
      const previous = prior?.gates.find((entry) => entry.id === gate.id);
      if (reusable(cwd, previous, gate, inputIdentity)) {
        Object.assign(result, { ...previous, reused_from_run_id: prior.run_id, detail: 'Reused only after identical declared input/toolchain/command/output and artifact validation.' });
        save();
        continue;
      }
      if (previous) result.previous_result_reused = false;
      // Remove only the exact declared generated JSON files. A pre-existing pass
      // can never satisfy a producer which exits without writing this run.
      try {
        for (const contract of gate.output.reports) {
          const target = localPath(cwd, contract.path);
          if (existsSync(target)) unlinkSync(target);
        }
        result.status = 'running';
        result.reason = null;
        result.log_path = `${runDirectory}/${gate.id}.log`;
        save();
        const execution = await supervise(gate.command, gate.args, { cwd, logPath: localPath(cwd, result.log_path), ...options, signal: controller.signal });
        result.execution = execution;
        result.log_artifact = artifactIdentity(cwd, result.log_path);
        result.status = execution.spawn_error ? 'missing_tool' : execution.termination ? (execution.termination === 'timeout' ? 'timeout' : 'interrupted') : execution.exit_code === 0 ? 'pass' : 'failed';
        result.reason = execution.spawn_error?.code ?? execution.termination ?? (execution.exit_code === 0 ? null : 'nonzero_exit');
        if (!sourceUnchanged()) { result.status = 'source_changed'; result.reason = 'source_changed_during_execution'; controller.abort('source_changed'); }
        if (result.status === 'pass') {
          result.completion_validation = validateConsoleCompletion(cwd, gate, execution, result.log_path);
          if (result.completion_validation?.passed === false) { result.status = 'failed'; result.reason = result.completion_validation.reason; }
        }
        if (result.status === 'pass') {
          try { result.artifacts = validateReports(cwd, gate); }
          catch (error) { result.status = 'missing_or_invalid_report'; result.reason = error.message; }
        }
      } catch (error) {
        result.status = 'runner_error'; result.reason = error.message; controller.abort('runner_error');
      }
      result.detail = gate.output.mode === 'json_files' ? 'Declared producer reports required and validated.' : 'Console contract only; no producer machine report is claimed.';
      save();
    }
    // Later gates may regenerate shared outputs. Any incompatible overwrite
    // invalidates the earlier result before composing the final evidence.
    for (let index = 0; index < gates.length; index += 1) {
      const result = results[index];
      if (result.status === 'pass' && !reusable(cwd, result, gates[index], result.input_identity_sha256)) { result.status = 'artifact_changed'; result.reason = 'producer_artifact_changed_after_gate'; }
    }
    if (!sourceUnchanged()) {
      for (const result of results) if (result.status === 'pass') { result.status = 'source_changed'; result.reason = 'source_changed_before_summary'; }
    }
    save();
    const report = { $schema: VERIFY_REPORT_SCHEMA, report_type: 'parkinsum_verify_all', schema_version: VERIFY_REPORT_SCHEMA_VERSION, run_id: runId, checkpoint_path: checkpointPath, checkpoint_sha256: artifactIdentity(cwd, checkpointPath).sha256,
      input_identity_sha256: digestObject({ source, toolchain: capturedToolchain, environment, inventory: checkpoint().inventory, options }),
      source, toolchain: capturedToolchain, environment, options, inventory: checkpoint().inventory,
      gate_count: results.length, pass: results.every((result) => result.status === 'pass'), failed_gate_ids: results.filter((result) => result.status !== 'pass').map((result) => result.id),
      goldens_included: gates.some((gate) => gate.id === 'committed_goldens'), interrupted: controller.signal.aborted,
      interruption: controller.signal.reason ?? null, toolchain_error: toolchainError, gates: results,
      not_clinically_calibrated: true, synthetic_demo_data_only: true, no_medical_advice: true,
      boundary: 'Offline synthetic engineering/console contract verification only. Legitimate HOLDs remain; no clinical qualification, independent scientific review, deployment or approval is implied.' };
    atomicJson(localPath(cwd, `${runDirectory}/report.json`), report);
    atomicJson(localPath(cwd, 'build/verify_all/latest.json'), report);
    writeFileSync(localPath(cwd, 'build/verify_all/latest.md'), [
      '# Verification summary', '', `Run: ${runId}`, `Declared gates: ${report.gate_count}. Complete pass: ${report.pass}.`,
      `Checkpoint: ${checkpointPath}`, '', '| Gate | Output mode | Status |', '| --- | --- | --- |',
      ...results.map((result) => `| ${result.id} | ${result.output_mode} | ${result.status} |`), '', report.boundary, '',
    ].join('\n'));
    return report;
  } finally {
    signal?.removeEventListener('abort', externalAbort);
    if (attachSignals) { process.off('SIGINT', sigint); process.off('SIGTERM', sigterm); }
  }
}

export async function main(argv = process.argv.slice(2)) {
  const known = /^(--list|--skip-goldens|--resume(?:=.+)?|--gate-timeout-ms=\d+|--cleanup-grace-ms=\d+|--max-log-bytes=\d+)$/;
  if (argv.some((arg) => !known.test(arg))) throw new Error('Unknown verification argument');
  const gates = defaultGates(argv.includes('--skip-goldens'));
  if (argv.includes('--list')) { for (const gate of gates) console.log(`${gate.id}\t${gate.command} ${gate.args.join(' ')}\t${gate.output.mode}`); return; }
  const numeric = (name, fallback) => Number(argv.find((arg) => arg.startsWith(`--${name}=`))?.split('=')[1] ?? fallback);
  const resume = argv.find((arg) => arg.startsWith('--resume'));
  const resumePath = resume === '--resume' ? JSON.parse(readFileSync('build/verify_all/latest_checkpoint.json', 'utf8')).path : resume?.slice('--resume='.length);
  const printed = new Map();
  const report = await runVerification({ gates, resumePath, timeoutMs: numeric('gate-timeout-ms', 900000), cleanupGraceMs: numeric('cleanup-grace-ms', 1000), maxLogBytes: numeric('max-log-bytes', 1048576),
    onCheckpoint: (checkpoint) => { for (const gate of checkpoint.gates) if (!['not_run', 'running'].includes(gate.status) && printed.get(gate.id) !== gate.status) { printed.set(gate.id, gate.status); process.stdout.write(`${gate.id}: ${gate.status}\n`); } } });
  console.log(`${report.pass ? 'All gates passed' : 'Verification incomplete/failed'}: ${report.gate_count} declared gates. Report: build/verify_all/latest.json`);
  process.exitCode = report.pass ? 0 : report.interruption === 'SIGINT' ? 130 : report.interruption === 'SIGTERM' ? 143 : 1;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) main().catch((error) => { console.error(error.message); process.exitCode = 1; });
