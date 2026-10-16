#!/usr/bin/env node
import { randomUUID } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import yaml from 'js-yaml';
import { VERIFY_CHECKPOINT_SCHEMA, VERIFY_REPORT_SCHEMA_VERSION, VERIFY_REPORT_SCHEMA, defaultGates, gateIdentity, reusable } from './run_verify_all.mjs';
import { atomicJson, artifactIdentity, captureInputs, collectToolchain, declaredEnvironment, digestObject, localPath, sha256, supervise } from './verification_runtime.mjs';

export const DELIVERY_INDEX_SCHEMA_VERSION = 2;
export const DELIVERY_INDEX_SCHEMA = 'parkinsum.upgrade-delivery-index/2';
export const WEB_BUILD_RECEIPT_SCHEMA_VERSION = 1;
export const WEB_BUILD_RECEIPT_SCHEMA = 'parkinsum.web-build-receipt/1';
export const FORMAL_APP_JOURNEY_SCHEMA = 'parkinsum.formal-app-journey/1';
const BENCHMARK_TARGET = 'lib/main_personal_log_view_benchmark.dart';
const BENCHMARK_W31_RECEIPT_PATH = 'build/mega_upgrade/w31_formal_journey.json';
const FORMAL_APP_JOURNEY_CHECKS = [
  'formal_entry_release', 'persistent_services_backend', 'meal_create_edit',
  'tab_reopen_persistence', 'portable_export_integrity', 'restore_inspect_confirm',
  'restore_undo', 'report_export', 'insights_to_timeline',
];
const GENERATOR_PATH = 'tool/generate_upgrade_delivery_index.mjs';
const RECEIPT_PATH = 'build/upgrade_delivery/build_receipt.json';
const VERIFICATION_PATH = 'build/verify_all/latest.json';
const INDEX_PATH = 'build/upgrade_delivery/latest.json';
const same = (left, right) => digestObject(left) === digestObject(right);

function readJson(cwd, path, maxBytes = 32 * 1024 * 1024) {
  const identity = artifactIdentity(cwd, path);
  if (identity.bytes > maxBytes) throw new Error(`Oversized evidence: ${path}`);
  return { identity, value: JSON.parse(readFileSync(localPath(cwd, path), 'utf8')) };
}

export function canonicalToolchainSha256(toolchain) {
  const canonical = (value) => {
    if (Array.isArray(value)) return value.map(canonical);
    if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map((key) => [key, canonical(value[key])]));
    return value;
  };
  return sha256(JSON.stringify(canonical(toolchain)));
}

function requireBenchmarkReceiptArgument(target, path) {
  if (target === BENCHMARK_TARGET && path !== BENCHMARK_W31_RECEIPT_PATH) throw new Error('Benchmark target requires the exact formal W31 receipt path');
  if (target !== BENCHMARK_TARGET && path) throw new Error('Benchmark W31 receipt/flags are forbidden on other targets');
}

function benchmarkBinding(cwd, path, source, toolchain) {
  requireBenchmarkReceiptArgument(BENCHMARK_TARGET, path);
  const { identity, value } = readJson(cwd, path, 1048576);
  if (value.$schema !== FORMAL_APP_JOURNEY_SCHEMA || value.status !== 'verified' || value.target !== 'lib/main.dart') throw new Error('Formal W31 root-observed receipt is missing, held or unsupported');
  if (value.working_source_sha256 !== source.sha256) throw Object.assign(new Error('Formal W31 receipt source is stale'), { code: 'W31_SOURCE_STALE' });
  if (typeof value.build_id !== 'string' || !value.build_id.length || !/^[a-f0-9]{64}$/.test(value.web_main_sha256 ?? '')) throw new Error('Formal W31 receipt lacks its observed build/binary identity');
  if (!value.checks || typeof value.checks !== 'object' || Array.isArray(value.checks) || !FORMAL_APP_JOURNEY_CHECKS.every((key) => value.checks[key] === true)) throw new Error('Formal W31 receipt lacks all nine required observed checks');
  return { w31_receipt: identity, dart_defines: [
    'PARKINSUM_W31_BASELINE_VERIFIED=true',
    `PARKINSUM_W31_RECEIPT=${BENCHMARK_W31_RECEIPT_PATH}`,
    `PARKINSUM_BENCHMARK_INPUT_SHA256=${source.sha256}`,
    `PARKINSUM_BENCHMARK_TOOLCHAIN=${canonicalToolchainSha256(toolchain)}`,
  ], scope: 'The root-observed formal UI journey receipt authorizes this engineering benchmark build only. Tab close/reopen does not prove OS/process-kill recovery, multi-tab isolation or mobile behavior. No benchmark measurement, production performance approval or clinical qualification is asserted.' };
}

export function webBuildParameters(target = 'lib/main.dart', benchmark = null) {
  if (!/^(lib|tool)\/[A-Za-z0-9_./-]+\.dart$/.test(target) || target.split('/').includes('..')) throw new Error('Build target must be an explicitly declared local lib/tool Dart source');
  if (benchmark && target !== BENCHMARK_TARGET) throw new Error('Benchmark flags are forbidden on other targets');
  return { target, mode: 'release', backend: 'local', web_resources_cdn: false, ...(benchmark ? { benchmark } : {}) };
}

export function webBuildCommand(parameters) {
  if (parameters.benchmark) {
    if (parameters.target !== BENCHMARK_TARGET) throw new Error('Benchmark flags are forbidden on other targets');
    const defines = parameters.benchmark.dart_defines;
    if (!Array.isArray(defines) || defines.length !== 4
        || defines[0] !== 'PARKINSUM_W31_BASELINE_VERIFIED=true'
        || defines[1] !== `PARKINSUM_W31_RECEIPT=${BENCHMARK_W31_RECEIPT_PATH}`
        || !/^PARKINSUM_BENCHMARK_INPUT_SHA256=[a-f0-9]{64}$/.test(defines[2])
        || !/^PARKINSUM_BENCHMARK_TOOLCHAIN=[a-f0-9]{64}$/.test(defines[3])) throw new Error('Only four fixed benchmark compile flags are permitted');
  }
  return { command: 'flutter', args: ['build', 'web', '--release', `--target=${parameters.target}`, '--no-web-resources-cdn', '--dart-define=PARKINSUM_BACKEND=local',
    ...(parameters.benchmark?.dart_defines ?? []).map((value) => `--dart-define=${value}`)] };
}

function webArtifacts(cwd) {
  const root = 'build/web';
  if (!existsSync(localPath(cwd, root))) return [];
  const visit = (path) => readdirSync(localPath(cwd, path), { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name)).flatMap((entry) => {
    const child = `${path}/${entry.name}`;
    if (entry.isSymbolicLink()) throw new Error(`Build symlink refused: ${child}`);
    return entry.isDirectory() ? visit(child) : [artifactIdentity(cwd, child)];
  });
  return visit(root).sort((a, b) => a.path.localeCompare(b.path));
}

function hasWebEntrypoint(artifacts) {
  const paths = new Set(artifacts.map((artifact) => artifact.path));
  return paths.has('build/web/index.html') && paths.has('build/web/flutter_bootstrap.js')
    && (paths.has('build/web/main.dart.js') || paths.has('build/web/main.dart.wasm'));
}

// This wrapper observes its own build process. A supplied source hash or an old
// build directory cannot stand in for an execution receipt.
export async function recordWebBuild({ cwd = process.cwd(), target = 'lib/main.dart', sourceFiles, toolchain, expectedSource, benchmarkW31ReceiptPath,
  environment = declaredEnvironment(), timeoutMs = 1800000, cleanupGraceMs = 1000, maxLogBytes = 1048576,
  signal, attachSignals = true, executor = supervise } = {}) {
  const parameters = webBuildParameters(target);
  const command = webBuildCommand(parameters);
  requireBenchmarkReceiptArgument(target, benchmarkW31ReceiptPath);
  const source = captureInputs(cwd, sourceFiles);
  if (expectedSource && expectedSource !== source.sha256) throw new Error('Expected source inventory is stale before build');
  if (!source.files.some((file) => file.path === target && file.sha256)) throw new Error('Build target is absent from the declared source inventory');
  for (const value of [timeoutMs, cleanupGraceMs, maxLogBytes]) if (!Number.isSafeInteger(value) || value <= 0) throw new Error('Invalid build supervision bound');
  const controller = new AbortController();
  const externalAbort = () => controller.abort(signal.reason ?? 'interrupted');
  const sigint = () => controller.abort('SIGINT');
  const sigterm = () => controller.abort('SIGTERM');
  signal?.addEventListener('abort', externalAbort, { once: true });
  if (signal?.aborted) externalAbort();
  if (attachSignals) { process.on('SIGINT', sigint); process.on('SIGTERM', sigterm); }
  const buildId = randomUUID();
  const output = `build/upgrade_delivery/builds/${buildId}`;
  const receiptPath = `${output}/receipt.json`;
  const options = { timeoutMs, cleanupGraceMs, maxLogBytes };
  const receipt = { $schema: WEB_BUILD_RECEIPT_SCHEMA, report_type: 'parkinsum_web_build_receipt', schema_version: WEB_BUILD_RECEIPT_SCHEMA_VERSION,
    build_id: buildId, observed_at_utc: new Date().toISOString(), receipt_path: receiptPath,
    status: 'not_run', reason: null, source, source_after: null, source_stable: false,
    toolchain: null, environment, parameters, command, options,
    generator_sha256: sha256(readFileSync(localPath(cwd, GENERATOR_PATH))), execution: null, artifacts: [],
    formal_app_target: target === 'lib/main.dart',
    boundary: 'Supervised local Web release build only. Explicit harness targets remain engineering artifacts. No signature, remote CI, mobile release, clinical validation or publication is claimed.' };
  const save = () => { atomicJson(localPath(cwd, receiptPath), receipt); atomicJson(localPath(cwd, RECEIPT_PATH), receipt); };
  try {
    save();
    receipt.toolchain = toolchain ?? await collectToolchain(cwd, controller.signal);
    if (target === BENCHMARK_TARGET) {
      receipt.parameters = webBuildParameters(target, benchmarkBinding(cwd, benchmarkW31ReceiptPath, source, receipt.toolchain));
      receipt.command = webBuildCommand(receipt.parameters);
    }
    receipt.input_identity_sha256 = digestObject({ source, toolchain: receipt.toolchain, environment, command: receipt.command, parameters: receipt.parameters, options });
    if (controller.signal.aborted) { receipt.status = 'interrupted'; receipt.reason = controller.signal.reason; save(); return receipt; }
    if (captureInputs(cwd, sourceFiles).sha256 !== source.sha256) { receipt.status = 'stale'; receipt.reason = 'source_changed_before_build'; save(); return receipt; }
    // Remove only regenerable Web output before invoking this build, so a
    // successful command which produced nothing cannot attest an older binary.
    rmSync(localPath(cwd, 'build/web'), { recursive: true, force: true });
    receipt.status = 'running';
    receipt.log_path = `${output}/build.log`;
    save();
    receipt.execution = await executor(receipt.command.command, receipt.command.args, { cwd, ...options, logPath: localPath(cwd, receipt.log_path), signal: controller.signal });
    receipt.source_after = captureInputs(cwd, sourceFiles);
    receipt.source_stable = receipt.source_after.sha256 === source.sha256;
    if (!receipt.source_stable) { receipt.status = 'stale'; receipt.reason = 'source_changed_during_build'; }
    else if (receipt.execution.spawn_error || receipt.execution.termination || receipt.execution.exit_code !== 0) {
      receipt.status = 'failed'; receipt.reason = receipt.execution.spawn_error?.code ?? receipt.execution.termination ?? 'nonzero_exit';
    } else {
      if (target === BENCHMARK_TARGET && !same(receipt.parameters.benchmark, benchmarkBinding(cwd, benchmarkW31ReceiptPath, source, receipt.toolchain))) throw Object.assign(new Error('Formal W31 receipt changed during benchmark build'), { code: 'W31_RECEIPT_CHANGED' });
      receipt.artifacts = webArtifacts(cwd);
      receipt.status = hasWebEntrypoint(receipt.artifacts) ? 'built' : 'failed';
      receipt.reason = receipt.status === 'built' ? null : 'missing_generated_web_entrypoint';
    }
  } catch (error) { receipt.status = ['W31_SOURCE_STALE', 'W31_RECEIPT_CHANGED'].includes(error.code) ? 'stale' : 'failed'; receipt.reason = error.message; }
  finally {
    signal?.removeEventListener('abort', externalAbort);
    if (attachSignals) { process.off('SIGINT', sigint); process.off('SIGTERM', sigterm); }
    save();
  }
  return receipt;
}

function allowedReceipt(path) {
  return path === RECEIPT_PATH || /^build\/upgrade_delivery\/builds\/[a-f0-9-]+\/receipt\.json$/.test(path);
}

function allowedVerification(path) {
  return path === VERIFICATION_PATH || /^build\/verify_all\/runs\/[a-f0-9-]+\/report\.json$/.test(path);
}

function validateBuild(cwd, path, source, toolchain, environment, expectedTarget) {
  if (!allowedReceipt(path)) throw new Error('Build receipt is outside the explicit delivery allowlist');
  const { identity, value } = readJson(cwd, path);
  const parameters = webBuildParameters(expectedTarget, expectedTarget === BENCHMARK_TARGET ? benchmarkBinding(cwd, BENCHMARK_W31_RECEIPT_PATH, source, toolchain) : null);
  if (value.$schema !== WEB_BUILD_RECEIPT_SCHEMA || value.report_type !== 'parkinsum_web_build_receipt' || value.schema_version !== WEB_BUILD_RECEIPT_SCHEMA_VERSION || value.status !== 'built') throw new Error('Build receipt is absent, failed or unsupported');
  if (!value.build_id || value.receipt_path !== `build/upgrade_delivery/builds/${value.build_id}/receipt.json`) throw new Error('Invalid build receipt identity');
  if (!value.source_stable || !same(value.source, source) || !same(value.source_after, source)) throw new Error('Build receipt source is stale');
  if (!same(value.toolchain, toolchain) || !same(value.environment, environment)) throw new Error('Build receipt toolchain/environment is stale');
  if (!same(value.parameters, parameters) || !same(value.command, webBuildCommand(parameters))) throw new Error('Build receipt parameters/command mismatch');
  if (value.generator_sha256 !== sha256(readFileSync(localPath(cwd, GENERATOR_PATH)))) throw new Error('Build receipt generator changed');
  if (value.execution?.exit_code !== 0 || value.execution.spawn_error || value.execution.termination) throw new Error('Build execution was not successful');
  if (value.input_identity_sha256 !== digestObject({ source, toolchain, environment, command: value.command, parameters, options: value.options })) throw new Error('Build receipt input identity mismatch');
  const original = readJson(cwd, value.receipt_path);
  if (original.identity.sha256 !== identity.sha256) throw new Error('Immutable build receipt differs from selected receipt');
  const artifacts = webArtifacts(cwd);
  if (!hasWebEntrypoint(artifacts) || !same(artifacts, value.artifacts)) throw new Error('Web build artifact set changed');
  return { ...identity, status: 'current', build_id: value.build_id, input_identity_sha256: value.input_identity_sha256,
    parameters, formal_app_target: value.formal_app_target === true && expectedTarget === 'lib/main.dart', artifacts };
}

function validateVerification(cwd, path, source, toolchain, environment, inventory) {
  if (!allowedVerification(path)) throw new Error('Verification report is outside the explicit delivery allowlist');
  const { identity, value } = readJson(cwd, path);
  if (value.$schema !== VERIFY_REPORT_SCHEMA || value.report_type !== 'parkinsum_verify_all' || value.schema_version !== VERIFY_REPORT_SCHEMA_VERSION || value.pass !== true || value.interrupted || value.toolchain_error) throw new Error('Verification run is incomplete, failed or unsupported');
  if (!same(value.source, source) || !same(value.toolchain, toolchain) || !same(value.environment, environment)) throw new Error('Verification source/toolchain/environment is stale');
  const declared = inventory.map(({ id, command, args, output }) => ({ id, command, args, output }));
  if (!same(value.inventory, declared) || value.gate_count !== declared.length || value.gates?.length !== declared.length || value.failed_gate_ids?.length !== 0) throw new Error('Verification gate inventory is incomplete or changed');
  if (value.goldens_included !== inventory.some((gate) => gate.id === 'committed_goldens')) throw new Error('Verification golden inclusion mismatch');
  if (value.input_identity_sha256 !== digestObject({ source, toolchain, environment, inventory: declared, options: value.options })) throw new Error('Verification input identity mismatch');
  if (value.checkpoint_path !== `build/verify_all/runs/${value.run_id}/checkpoint.json`) throw new Error('Verification checkpoint path mismatch');
  const checkpoint = readJson(cwd, value.checkpoint_path);
  if (checkpoint.identity.sha256 !== value.checkpoint_sha256 || checkpoint.value.schema !== VERIFY_CHECKPOINT_SCHEMA
      || checkpoint.value.run_id !== value.run_id || !same(checkpoint.value.source, source)
      || !same(checkpoint.value.toolchain, toolchain) || !same(checkpoint.value.environment, environment)
      || !same(checkpoint.value.inventory, declared) || !same(checkpoint.value.options, value.options)
      || !same(checkpoint.value.gates, value.gates) || checkpoint.value.interrupted || checkpoint.value.toolchain_error) throw new Error('Verification checkpoint changed or does not match the final report');
  const immutableReport = readJson(cwd, `build/verify_all/runs/${value.run_id}/report.json`);
  if (immutableReport.identity.sha256 !== identity.sha256) throw new Error('Immutable verification run differs from selected report');
  const artifacts = [];
  inventory.forEach((gate, index) => {
    const result = value.gates[index];
    if (result.id !== gate.id || !reusable(cwd, result, gate, gateIdentity(gate, source, toolchain, environment, value.options))) throw new Error(`Verification gate/artifact is stale: ${gate.id}`);
    artifacts.push(...result.artifacts);
  });
  return { ...identity, status: 'current', run_id: value.run_id, input_identity_sha256: value.input_identity_sha256,
    checkpoint: checkpoint.identity, gate_count: value.gate_count, goldens_included: value.goldens_included,
    output_modes: value.gates.map(({ id, output_mode }) => ({ id, output_mode })), artifacts,
    scope: 'Declared offline engineering gates and explicit console/metadata contracts. No clinical PASS is inferred from legitimate HOLD or rejection fixtures.' };
}

function screenshotInventory(cwd, source, build) {
  const provenance = [];
  const entries = [];
  const excluded = [];
  const seen = new Set();
  // Names are explicit. NEXT is retained as historical capture evidence; MEGA
  // can qualify only against the selected and revalidated formal build.
  for (const name of ['next-provenance.json', 'mega-provenance.json']) {
    const metadata = `build/upgrade_delivery/screenshots/${name}`;
    if (!existsSync(localPath(cwd, metadata))) continue;
    const { identity, value } = readJson(cwd, metadata, 1048576);
    provenance.push(identity);
    if (!Array.isArray(value.screenshots)) throw new Error('Screenshot provenance must declare its artifacts');
    for (const entry of value.screenshots) {
      if (!/^build\/upgrade_delivery\/screenshots\/[A-Za-z0-9_.-]+\.(png|jpe?g)$/.test(entry.path) || seen.has(entry.path)) throw new Error('Screenshot path is outside the explicit allowlist or duplicated');
      seen.add(entry.path);
      const actual = artifactIdentity(cwd, entry.path);
      if (actual.sha256 !== entry.sha256 || !/^[a-f0-9]{64}$/.test(entry.working_source_sha256 ?? '') || !/^[a-f0-9]{64}$/.test(entry.web_main_sha256 ?? '')) throw new Error('Screenshot identity/provenance mismatch');
      const capturedAt = entry.captured_at_utc ?? value.captured_at_utc ?? null;
      const record = { ...actual, captured_source_sha256: entry.working_source_sha256, captured_web_main_sha256: entry.web_main_sha256,
        captured_at_utc: capturedAt, captured_build_id: entry.build_id ?? null, captured_target: entry.target ?? null,
        capture_origin: entry.capture_origin ?? null, capture_tool: entry.capture_tool ?? null,
        privacy_review: entry.privacy_review ?? null, scope: entry.scope ?? null, provenance_path: metadata };
      if (name === 'next-provenance.json') {
        entries.push({ ...record, current_candidate: false, disposition: 'historical_next_capture' });
        continue;
      }
      const main = build?.artifacts.find((artifact) => artifact.path === 'build/web/main.dart.js');
      let reason = null;
      if (!build) reason = 'validated_build_unavailable';
      else if (!build.formal_app_target || build.parameters.target !== 'lib/main.dart' || entry.target !== 'lib/main.dart') reason = 'engineering_or_unbound_target';
      else if (entry.working_source_sha256 !== source.sha256) reason = 'capture_source_stale';
      else if (!main || entry.web_main_sha256 !== main.sha256) reason = 'capture_binary_mismatch';
      else if (entry.build_id !== build.build_id) reason = 'capture_build_id_mismatch';
      else if (typeof capturedAt !== 'string' || !Number.isFinite(Date.parse(capturedAt))) reason = 'capture_time_unavailable';
      if (reason) excluded.push({ ...record, reason, current_candidate: false });
      else entries.push({ ...record, current_candidate: true, disposition: 'current_formal_app_capture' });
    }
  }
  return { provenance, entries, excluded_unbound_captures: excluded, excluded_unbound_files: true,
    scope: 'NEXT captures retain their original identities. MEGA captures require the selected formal build ID, target, full declared source identity and actual main.dart.js hash. Unbound or harness captures are excluded from current evidence.' };
}

function dependencySbom(cwd, source) {
  const lock = yaml.load(readFileSync(localPath(cwd, 'pubspec.lock'), 'utf8'));
  if (!lock?.packages || typeof lock.packages !== 'object') throw new Error('Missing Flutter dependency lock package inventory');
  const entries = Object.entries(lock.packages).sort(([a], [b]) => a.localeCompare(b));
  const scope = 'Lock-derived dependency SBOM including development/build dependencies. Does not prove binary reachability, license approval, SDK contents, or publisher authenticity. Web assets and NOTICES are separately hashed in the delivery index.';
  const sbom = { spdxVersion: 'SPDX-2.3', dataLicense: 'CC0-1.0', SPDXID: 'SPDXRef-DOCUMENT', name: 'ParkinSUM Flutter locked dependencies',
    documentNamespace: `https://parkinsum.invalid/local-sbom/${source.sha256}`,
    creationInfo: { created: new Date().toISOString(), creators: ['Tool: ParkinSUM local upgrade inventory'] }, documentComment: scope,
    packages: entries.map(([name, entry]) => ({ name, SPDXID: `SPDXRef-Package-${name.replace(/[^A-Za-z0-9.-]/g, '-')}`,
      versionInfo: entry.version, downloadLocation: 'NOASSERTION', filesAnalyzed: false, licenseConcluded: 'NOASSERTION', licenseDeclared: 'NOASSERTION', copyrightText: 'NOASSERTION',
      summary: `pubspec.lock source=${entry.source}; dependency=${entry.dependency}`,
      ...(entry.description?.sha256 ? { checksums: [{ algorithm: 'SHA256', checksumValue: entry.description.sha256 }] } : {}),
      externalRefs: entry.source === 'hosted' ? [{ referenceCategory: 'PACKAGE-MANAGER', referenceType: 'purl', referenceLocator: `pkg:pub/${name}@${entry.version}` }] : [] })),
    relationships: entries.map(([name]) => ({ spdxElementId: 'SPDXRef-DOCUMENT', relationshipType: 'DESCRIBES', relatedSpdxElement: `SPDXRef-Package-${name.replace(/[^A-Za-z0-9.-]/g, '-')}` })) };
  const path = 'build/upgrade_delivery/flutter-lock.spdx.json';
  atomicJson(localPath(cwd, path), sbom);
  return { ...artifactIdentity(cwd, path), package_count: entries.length, source_lock: source.files.find((file) => file.path === 'pubspec.lock'), scope };
}

export async function generateDeliveryIndex({ cwd = process.cwd(), sourceFiles, toolchain, environment = declaredEnvironment(),
  expectedSource, expectedTarget = 'lib/main.dart', buildReceiptPath, verificationPath, verificationInventory = defaultGates(), gitMetadata } = {}) {
  const source = captureInputs(cwd, sourceFiles);
  const reasons = [];
  const capture = async (operation) => { try { return await operation(); } catch (error) { reasons.push(error.message); return null; } };
  const capturedToolchain = toolchain ?? await capture(() => collectToolchain(cwd));
  if (expectedSource && expectedSource !== source.sha256) reasons.push('Expected source inventory is stale');
  const generatorSha = sha256(readFileSync(localPath(cwd, GENERATOR_PATH)));
  const build = buildReceiptPath ? await capture(() => validateBuild(cwd, buildReceiptPath, source, capturedToolchain, environment, expectedTarget)) : null;
  const verification = verificationPath ? await capture(() => validateVerification(cwd, verificationPath, source, capturedToolchain, environment, verificationInventory)) : null;
  const screenshots = await capture(() => screenshotInventory(cwd, source, build));
  const sbom = await capture(() => dependencySbom(cwd, source));
  // Re-read selected producer receipts after collection. No asynchronous
  // operation can leave an earlier artifact check as the final acceptance.
  if (build) await capture(() => validateBuild(cwd, buildReceiptPath, source, capturedToolchain, environment, expectedTarget));
  if (verification) await capture(() => validateVerification(cwd, verificationPath, source, capturedToolchain, environment, verificationInventory));
  if (captureInputs(cwd, sourceFiles).sha256 !== source.sha256) reasons.push('Source changed while collecting delivery evidence');
  const git = (...args) => execFileSync('git', args, { cwd, encoding: 'utf8' }).trim();
  const metadata = gitMetadata ?? { committed_head: git('rev-parse', 'HEAD'), committed_tree: git('rev-parse', 'HEAD^{tree}'), working_tree_dirty: git('status', '--porcelain').length > 0 };
  const requestedEvidence = Boolean(buildReceiptPath || verificationPath);
  const report = { $schema: DELIVERY_INDEX_SCHEMA, report_type: 'parkinsum_upgrade_delivery_index', schema_version: DELIVERY_INDEX_SCHEMA_VERSION,
    observed_at_utc: new Date().toISOString(), source: { ...metadata, ...source, working_source_sha256: source.sha256, source_file_count: source.files.length,
      scope_description: 'Declared code, assets, configuration, tools, tests, fixtures, locks, platform/bootstrap inputs and static reference metadata. Excludes generated build/checkpoint/log/index outputs, ignored private data and the implementation timeline.' },
    toolchain: capturedToolchain, environment, generator_sha256: generatorSha,
    requested_evidence: { expected_source_sha256: expectedSource ?? null, build_receipt_path: buildReceiptPath ?? null, verification_path: verificationPath ?? null, expected_target: expectedTarget },
    disposition: reasons.length ? 'refused' : build && verification && build.formal_app_target ? 'current_local_engineering_candidate' : 'inventory_only',
    current_candidate_evidence: reasons.length === 0 && Boolean(build?.formal_app_target && verification), refusal_reasons: reasons,
    build_receipt: build, verification, web_release: build?.artifacts ?? [], licenses: (build?.artifacts ?? []).filter((artifact) => artifact.path === 'build/web/assets/NOTICES'),
    dependency_sbom: sbom, screenshots,
    missing_evidence: [!buildReceiptPath && 'supervised_web_build_receipt', !verificationPath && 'complete_verification_run', build && !build.formal_app_target && 'formal_app_build_target'].filter(Boolean),
    boundary: 'Local uncommitted engineering candidate only. Console modes have no producer report. Existing screenshots retain their historical identities. No mobile binary, external review, clinical qualification, store approval, signature or publication is claimed.' };
  atomicJson(localPath(cwd, INDEX_PATH), report);
  writeFileSync(localPath(cwd, 'build/upgrade_delivery/latest.md'), [
    '# Local upgrade delivery evidence', '', `Disposition: **${report.disposition}**. Current candidate evidence: **${report.current_candidate_evidence}**.`,
    `Working input SHA-256: \`${source.sha256}\` (${source.files.length} files).`, '',
    `Supervised Web receipt: **${build?.status ?? 'absent/refused'}**. Verification: **${verification?.status ?? 'absent/refused'}**.`,
    `Web artifacts: **${report.web_release.length}**. Historical captures: **${screenshots?.entries.length ?? 0}**.`,
    `Lock-derived SPDX: **${sbom?.package_count ?? 'unavailable'}** packages including development/build dependencies; license conclusions remain NOASSERTION.`, '',
    ...reasons.map((reason) => `- Refused: ${reason}`), '', report.boundary, '',
  ].join('\n'));
  return { report, requestedEvidence };
}

export async function main(argv = process.argv.slice(2)) {
  if (argv.some((arg) => !/^(--build-web|--target=.+|--expected-source=[a-f0-9]{64}|--build-receipt=.+|--verification=.+|--build-timeout-ms=\d+|--benchmark-w31-receipt=.+)$/.test(arg))) throw new Error('Unknown delivery argument');
  if (new Set(argv.map((arg) => arg.split('=')[0])).size !== argv.length) throw new Error('Duplicate delivery argument');
  const value = (name) => argv.find((arg) => arg.startsWith(`--${name}=`))?.slice(name.length + 3);
  const target = value('target') ?? 'lib/main.dart';
  webBuildParameters(target);
  if (argv.includes('--build-web')) {
    if (value('build-receipt') || value('verification')) throw new Error('Build execution and evidence composition are separate invocations');
    const receipt = await recordWebBuild({ target, benchmarkW31ReceiptPath: value('benchmark-w31-receipt'), expectedSource: value('expected-source'), timeoutMs: Number(value('build-timeout-ms') ?? 1800000) });
    console.log(JSON.stringify({ buildId: receipt.build_id, status: receipt.status, reason: receipt.reason, receipt: receipt.receipt_path }));
    process.exitCode = receipt.status === 'built' ? 0 : 1;
    return;
  }
  if (value('benchmark-w31-receipt')) throw new Error('Benchmark W31 receipt option requires --build-web');
  const { report, requestedEvidence } = await generateDeliveryIndex({ expectedSource: value('expected-source'), expectedTarget: target,
    buildReceiptPath: value('build-receipt'), verificationPath: value('verification') });
  console.log(JSON.stringify({ sourceDigest: report.source.sha256, sourceFileCount: report.source.files.length, disposition: report.disposition,
    currentCandidateEvidence: report.current_candidate_evidence, webArtifacts: report.web_release.length, screenshots: report.screenshots?.entries.length ?? 0, report: INDEX_PATH }));
  process.exitCode = report.disposition === 'refused' || (requestedEvidence && !report.current_candidate_evidence) ? 1 : 0;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) main().catch((error) => { console.error(error.message); process.exitCode = 1; });
