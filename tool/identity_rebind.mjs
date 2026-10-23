#!/usr/bin/env node
// Mechanical algorithm configuration identity rebind, run at merge time.
//
// On a branch rebased onto the merge target (default origin/main) whose
// identity still equals the target's vN, it performs the bump to vN+1 exactly
// as the hand-made rebinds did (v80 -> v81 in 20fc7f6): next identity version
// with a comment, one appended blocked context-of-use ledger record, one
// checkpoint and one record appended to the hash-chained governance ledger
// (config/governance_ledger.jsonl) with its pins, the plan/attestation version
// rebinds, the queue sentences, the release-probe version and the tests that
// name them. On a tree already at vN+1 it only refreshes digests. Every digest
// comes from production code (tool/identity_rebind_probe.dart,
// tool/governance_ledger_chain.dart) or from the existing pin printers; nothing
// is re-implemented here.
import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export const FILES = Object.freeze({
  identity: 'lib/algorithm_sdk/algorithm_configuration_identity.dart',
  ledger: 'lib/domain/entities/context_of_use_requalification.dart',
  execution: 'lib/domain/entities/credibility_evidence_execution_attestation.dart',
  plan: 'lib/domain/entities/prospective_model_credibility_plan.dart',
  oracle: 'lib/domain/entities/algorithm_contract_independent_oracle_attestation.dart',
  sampling: 'lib/domain/entities/algorithm_relation_domain_sampling_attestation.dart',
  impact: 'lib/domain/usecases/algorithm_configuration_change_impact_service.dart',
  queue: 'config/complete_app_upgrade_queue.json',
  releaseProbe: 'tool/web_user_state_capacity_release_probe.dart',
  ledgerTest: 'test/context_of_use_requalification_test.dart',
  executionTest: 'test/credibility_evidence_execution_attestation_test.dart',
  planTest: 'test/prospective_model_credibility_plan_test.dart',
  replayGolden: 'test/goldens/mechanistic_replay.md',
  chain: 'config/governance_ledger.jsonl',
  chainPins: 'lib/domain/entities/governance_ledger_chain.dart',
});
export const QUEUE_ITEMS = Object.freeze({
  identity: 'algorithm_configuration_identity_digest',
  ledger: 'context_of_use_change_requalification_ledger',
  plan: 'prospective_model_credibility_plan_and_post_study_adequacy_gate',
  execution: 'credibility_evidence_split_attestation_and_leakage_mutation_gate',
});
// The tests that bind the rebound values, run after every rebind.
export const VERIFY_TESTS = [
  'test/context_of_use_requalification_test.dart', 'test/credibility_evidence_execution_attestation_test.dart',
  'test/prospective_model_credibility_plan_test.dart', 'test/algorithm_configuration_change_impact_test.dart',
  'test/parkinsum_algorithm_sdk_test.dart', 'test/algorithm_contract_independent_oracle_attestation_test.dart',
  'test/algorithm_relation_domain_sampling_attestation_test.dart', 'test/goldens_test.dart', 'test/governance_ledger_chain_test.dart',
];
export const VERIFY_SCRIPTS = ['algorithm:contracts:independent', 'algorithm:contracts:sampling', 'cou:requalification',
  'algorithm:configuration-impact', 'credibility:prospective', 'credibility:execution', 'upgrade:queue'];
const ORACLE_PINS = ['expectedRelationRegistrySha256', 'expectedIndependentOracleSha256', 'expectedExecutableSpecificationSha256', 'expectedReportSha256'];
const SAMPLING_PINS = ['expectedPlanSha256', 'expectedRelationRegistrySha256', 'expectedSamplerSha256', 'expectedProductionAnchorReportSha256',
  'expectedProductionExecutionReportSha256', 'expectedProductionExecutionRunnerSha256', 'expectedProductionExecutorSha256', 'expectedReportSha256'];
// Report digests embed the configuration identity and move on every rebind;
// any other pin moving means an input changed and deserves a reviewer's look.
const IDENTITY_BOUND_PINS = new Set(['oracle.expectedReportSha256', 'sampling.expectedProductionAnchorReportSha256', 'sampling.expectedProductionExecutionReportSha256', 'sampling.expectedReportSha256']);

const ONES = ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen'];
const TENS = ['', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'];
export function numberWords(value) {
  if (!Number.isInteger(value) || value < 0 || value > 99) throw new Error(`No wording for ${value}`);
  if (value < 20) return ONES[value];
  return value % 10 ? `${TENS[Math.floor(value / 10)]}-${ONES[value % 10]}` : TENS[value / 10];
}

export function parseVersion(version) {
  const match = /^(\d{4}\.\d{2}\.\d{2})-v(\d+)$/.exec(version);
  if (!match) throw new Error(`Unrecognised version ${version}`);
  return { prefix: match[1], number: Number(match[2]) };
}
const nextVersion = (version, prefix) => { const parsed = parseVersion(version); return `${prefix ?? parsed.prefix}-v${parsed.number + 1}`; };

const escapeRegExp = (text) => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
export function readConst(source, name) {
  const match = new RegExp(`static const String ${name} =\\s*'([^']*)';`).exec(source);
  if (!match) throw new Error(`Missing constant ${name}`);
  return match[1];
}
export function replaceConst(source, name, value) {
  const pattern = new RegExp(`(static const String ${name} =\\s*')([^']*)(';)`, 'g');
  const matches = source.match(pattern) ?? [];
  if (matches.length !== 1) throw new Error(`Expected one constant ${name}, found ${matches.length}`);
  return source.replace(pattern, (_, head, __, tail) => `${head}${value}${tail}`);
}
export function readIntConst(source, name) {
  const match = new RegExp(`static const int ${name} = (\\d+);`).exec(source);
  if (!match) throw new Error(`Missing constant ${name}`);
  return Number(match[1]);
}
export function replaceIntConst(source, name, value) {
  const pattern = new RegExp(`(static const int ${name} = )\\d+(;)`, 'g');
  const matches = source.match(pattern) ?? [];
  if (matches.length !== 1) throw new Error(`Expected one constant ${name}, found ${matches.length}`);
  return source.replace(pattern, (_, head, tail) => `${head}${value}${tail}`);
}
export function replaceOnce(source, from, to, label) {
  const count = source.split(from).length - 1;
  if (count !== 1) throw new Error(`${label}: expected exactly one ${JSON.stringify(from)}, found ${count}`);
  return source.replace(from, () => to);
}

function wrapWords(text, width) {
  const lines = [];
  let line = '';
  for (const word of text.split(/\s+/).filter(Boolean)) {
    if (line && line.length + 1 + word.length > width) { lines.push(line); line = word; }
    else line = line ? `${line} ${word}` : word;
  }
  if (line) lines.push(line);
  return lines;
}
export function dartComment(text, indent = '  ', width = 80) {
  return wrapWords(text, width - indent.length - 3).map((line) => `${indent}// ${line}`).join('\n');
}
const escapeDart = (text) => text.replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\$/g, '\\$');
// Adjacent single-quoted literals in the house style: every piece but the last
// keeps its trailing space inside the quotes, and no line passes 80 columns.
export function dartStringLiterals(text, indent, width = 80) {
  const words = text.split(/\s+/).filter(Boolean).map(escapeDart);
  const pieces = [];
  let piece = '';
  for (const word of words) {
    const candidate = piece ? `${piece} ${word}` : word;
    if (piece && indent.length + candidate.length + 3 > width) { pieces.push(`${piece} `); piece = word; }
    else piece = candidate;
  }
  pieces.push(piece);
  return pieces.map((entry) => `${indent}'${entry}'`).join('\n');
}
export const slugify = (text) => text.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
const camel = (slug) => slug.split('-').map((part, index) => index ? part[0].toUpperCase() + part.slice(1) : part).join('');

// ---- Bump transforms (pure text in, text out) ----

export function bumpIdentity(source, { toVersion, reason }) {
  const fromVersion = readConst(source, 'defaultVersion');
  const { number } = parseVersion(toVersion);
  const declaration = '  static const String defaultVersion =';
  const comment = `${dartComment(`v${number} ${reason}.`)}\n`;
  let next = replaceOnce(source, declaration, `${comment}${declaration}`, 'identity version declaration');
  next = replaceConst(next, 'defaultVersion', toVersion);
  if (fromVersion === toVersion) throw new Error('Identity version did not advance');
  return next;
}

export function lastLedgerRecordVariable(source) {
  const block = /return ContextOfUseRequalificationLedger\._\([\s\S]*?records: \[([\s\S]*?)\],/.exec(source);
  if (!block) throw new Error('Ledger records list not found');
  const names = block[1].split(',').map((name) => name.trim()).filter(Boolean);
  return { names, last: names.at(-1) };
}

export function bumpLedger(source, ctx) {
  const { fromNumber, toNumber, newConfigurationSha256, priorRecordCount, title, reason, recordedAtUtc, versionPrefix } = ctx;
  const oldCurrent = readConst(source, 'expectedCurrentConfigurationSha256');
  const historical = `historicalV${fromNumber}ConfigurationSha256`;
  if (source.includes(`static const String ${historical}`)) throw new Error(`${historical} already exists`);
  const { names, last } = lastLedgerRecordVariable(source);
  if (names.length !== priorRecordCount) throw new Error(`Ledger lists ${names.length} records, expected ${priorRecordCount}`);
  let variable = `${camel(slugify(title))}CandidateRecord`;
  if (names.includes(variable) || source.includes(` ${variable} =`)) variable = `${variable.replace(/CandidateRecord$/, '')}V${toNumber}CandidateRecord`;
  let next = replaceConst(source, 'ledgerVersion', nextVersion(readConst(source, 'ledgerVersion'), versionPrefix));
  next = replaceConst(next, 'expectedCurrentConfigurationSha256', newConfigurationSha256);
  next = replaceOnce(next, `      '${newConfigurationSha256}';\n`, `      '${newConfigurationSha256}';\n  static const String ${historical} =\n      '${oldCurrent}';\n`, 'historical configuration constant');
  next = replaceOnce(next, 'currentConfigurationSha256: expectedCurrentConfigurationSha256,', `currentConfigurationSha256: ${historical},`, 'previous latest record');
  const boundary = `The v${toNumber} candidate ${reason}. All ${numberWords(priorRecordCount)} prior whole records and their digests remain exact. The change supplies no new scientific evidence, independent review, clinical qualification, authenticated approval or release acceptance. All evidence holds and blocked promotion remain in force.`;
  const copy = (field) => `      ${field}: ${last}.${field},`;
  const record = [
    `    final ${variable} = ContextOfUseRequalificationRecord(`,
    `      sequence: ${priorRecordCount + 1},`,
    `      changeKind: 'software_identity_candidate_rebind',`,
    `      previousManifestSha256: ${last}.currentManifestSha256,`,
    `      previousConfigurationSha256: ${last}.currentConfigurationSha256,`,
    '      currentManifestSha256: expectedCurrentManifestSha256,',
    '      currentConfigurationSha256: expectedCurrentConfigurationSha256,',
    ...['evidenceCurrencyRegistrySha256', 'evidenceSynthesisRegistrySha256', 'semanticDiffSha256', 'affectedProviderIds', 'affectedPredicateIds', 'changeClasses', 'modelRisk', 'questionOfInterest', 'contextOfUse'].map(copy),
    "      author: 'automated-local-software-integration',",
    `      recordedAtUtc: '${recordedAtUtc}',`,
    `      releaseArtifact: 'unreleased-worktree:${slugify(title)}-v${toNumber}',`,
    copy('evidenceDecisions'),
    '      releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,',
    '      approvalSignature: null,',
    '      decisionBoundary:',
    `${dartStringLiterals(boundary, '          ')},`,
    '    );',
  ].join('\n');
  next = replaceOnce(next, '    return ContextOfUseRequalificationLedger._(', `${record}\n    return ContextOfUseRequalificationLedger._(`, 'ledger return');
  next = replaceOnce(next, `        ${last},\n      ],`, `        ${last},\n        ${variable},\n      ],`, 'ledger records list');
  return { source: next, variable, historical, previousConfigurationSha256: oldCurrent };
}

export function bumpVersionConst(source, name, versionPrefix) {
  const from = readConst(source, name);
  const to = nextVersion(from, versionPrefix);
  return { source: replaceConst(source, name, to), from, to };
}

export function bumpLedgerTest(source, { fromNumber, toNumber, priorRecordCount: count }) {
  let next = replaceOnce(source, `'v${fromNumber} candidate retains all ${numberWords(count - 1)} historical blocked records without new approval'`,
    `'v${toNumber} candidate retains all ${numberWords(count)} historical blocked records without new approval'`, 'ledger test title');
  next = replaceOnce(next, `expect(ledger.records, hasLength(${count}));`, `expect(ledger.records, hasLength(${count + 1}));`, 'ledger length');
  next = replaceOnce(next, `expect(candidate.sequence, ${count});`, `expect(candidate.sequence, ${count + 1});`, 'candidate sequence');
  return replaceOnce(next, `ledger.records[${count - 2}].currentConfigurationSha256,`, `ledger.records[${count - 1}].currentConfigurationSha256,`, 'candidate predecessor');
}

export function bumpExecutionTest(source, { fromNumber, toNumber, fromVersion, toVersion }) {
  let next = replaceOnce(source, `'synthetic fixture pins exact v${fromNumber} software identity without qualification'`, `'synthetic fixture pins exact v${toNumber} software identity without qualification'`, 'execution test title');
  return replaceOnce(next, `expect(AlgorithmConfigurationIdentity.defaultVersion, '${fromVersion}');`, `expect(AlgorithmConfigurationIdentity.defaultVersion, '${toVersion}');`, 'execution test version');
}

export function bumpReleaseProbe(source, { fromNumber, toNumber, fromVersion, toVersion }) {
  return replaceOnce(source, `'${fromVersion}',\n        'current v${fromNumber} configuration identity',`, `'${toVersion}',\n        'current v${toNumber} configuration identity',`, 'release probe version');
}

export function queueSentences({ reason, title, configurationSha256, sourceBundleSha256, ledgerVersion, planVersion, attestationVersion, priorRecordCount }) {
  return {
    identity: `${reason}, with configuration SHA-256 ${configurationSha256} and registered source bundle SHA-256 ${sourceBundleSha256}.`,
    ledger: `uses ledger ${ledgerVersion}, preserves all ${numberWords(priorRecordCount)} prior whole records and hashes, and appends one blocked software-identity event for ${title}. It supplies no new scientific evidence, independent review, authenticated approval or publication acceptance.`,
    plan: `uses prospective plan ${planVersion} bound to the new software identity. Its prospective decision stays blocked, post-study adequacy stays notAssessed, and original synthetic timestamps remain unchanged.`,
    execution: `uses execution attestation ${attestationVersion} bound to prospective plan ${planVersion} and the new configuration/source bundle. Synthetic evidence and all scientific-use holds remain unchanged; this rebind does not attest new independent review.`,
  };
}

export function bumpQueue(text, { fromNumber, toNumber, sentences }) {
  const queue = JSON.parse(text);
  for (const [key, id] of Object.entries(QUEUE_ITEMS)) {
    const item = queue.items.find((entry) => entry.id === id);
    const head = `The current v${fromNumber} candidate `;
    if (!item?.currentGap.startsWith(head)) throw new Error(`Queue item ${id} does not start with "${head}"`);
    item.currentGap = `The current v${toNumber} candidate ${sentences[key]} Previous candidate history: The v${fromNumber} candidate ${item.currentGap.slice(head.length)}`;
  }
  return `${JSON.stringify(queue, null, 2)}\n`;
}

// ---- Governance ledger chain (lines and digests come from production code) ----

// JSON Lines without any hashing: the tool only reads what the Dart chain wrote.
export function parseChain(text) {
  return text.split('\n').filter((line) => line && !/^(<{7}|={7}|>{7}|\|{7})( |$)/.test(line)).map((line) => JSON.parse(line));
}
export const chainCheckpoint = (entries, beforeIdentityVersion) =>
  entries.find((entry) => entry.entry_kind === 'checkpoint' && entry.before_identity_version === beforeIdentityVersion);

// The provenance a bump records in its checkpoint; title and reason let
// --reapply redo the same bump on a newer base.
export function checkpointProvenance({ baseSha, baseVersion, frozenSha, fromNumber, toNumber, title, reason }) {
  return { source_commit: baseSha, source_configuration_version: baseVersion, source_configuration_sha256: frozenSha,
    boundary: `Complete v${fromNumber} ledger before the v${toNumber} ${title} rebind; no new validation, evidence or review is asserted.`,
    rebind_title: title, rebind_reason: reason };
}

// The rebind a branch appended: its checkpoint entries that the base lacks.
export function ownRebind(baseChainText, branchChainText) {
  const known = new Set(parseChain(baseChainText).map((entry) => entry.entry_sha256));
  const own = parseChain(branchChainText).filter((entry) => entry.entry_kind === 'checkpoint' && !known.has(entry.entry_sha256));
  if (own.length !== 1) throw new Error(`Expected one checkpoint of this branch beyond the base chain, found ${own.length}`);
  const { rebind_title: title, rebind_reason: reason } = own[0].provenance ?? {};
  if (!title || !reason) throw new Error(`The v${own[0].before_identity_version} checkpoint records no rebind title and reason; pass --title and --reason`);
  return { title, reason, beforeIdentityVersion: own[0].before_identity_version };
}

export function chainPinRow({ before_identity_version: before, record_count: count, snapshot_sha256: snapshot, entry_sha256: entry }) {
  return ['    GovernanceLedgerCheckpointPin(', `      beforeIdentityVersion: ${before},`, `      recordCount: ${count},`,
    `      snapshotSha256: '${snapshot}',`, `      entrySha256: '${entry}',`,
    `      lastConfigurationSha256: ContextOfUseRequalificationLedger.historicalV${before - 1}ConfigurationSha256,`, '    ),'].join('\n');
}
export function pinnedCheckpoints(source) {
  return [...source.matchAll(/GovernanceLedgerCheckpointPin\(\s*beforeIdentityVersion: (\d+),\s*recordCount: (\d+),\s*snapshotSha256:\s*'([0-9a-f]{64})',\s*entrySha256:\s*'([0-9a-f]{64})',/g)]
    .map(([, before, count, snapshot, entry]) => ({ before_identity_version: Number(before), record_count: Number(count), snapshot_sha256: snapshot, entry_sha256: entry }));
}

// Binds the chain pins: head and length always, plus a row for every new
// checkpoint. A pinned checkpoint that moved means history was rewritten.
export function bindChainPins(source, pins) {
  const pinned = new Map(pinnedCheckpoints(source).map((pin) => [pin.before_identity_version, pin]));
  const rows = [];
  for (const checkpoint of pins.checkpoints) {
    const existing = pinned.get(checkpoint.before_identity_version);
    if (!existing) rows.push(chainPinRow(checkpoint));
    else if (JSON.stringify(existing) !== JSON.stringify(checkpoint)) throw new Error(`The pinned v${checkpoint.before_identity_version} checkpoint changed; earlier chain history must never be rewritten`);
  }
  let next = replaceIntConst(source, 'expectedEntryCount', pins.entry_count);
  next = replaceConst(next, 'expectedHeadSha256', pins.head_sha256);
  if (!rows.length) return next;
  const open = 'static const List<GovernanceLedgerCheckpointPin> checkpointPins = [';
  const start = next.indexOf(open);
  const end = next.indexOf('\n  ];', start);
  if (start < 0 || end < 0) throw new Error('checkpointPins list not found');
  return `${next.slice(0, end)}\n${rows.join('\n')}${next.slice(end)}`;
}

// ---- Digest refresh (both modes; a no-op when already bound) ----

export function refreshQueueDigests(text, { number, configurationSha256, sourceBundleSha256 }) {
  const queue = JSON.parse(text);
  const item = queue.items.find((entry) => entry.id === QUEUE_ITEMS.identity);
  const [current, ...history] = item.currentGap.split(' Previous candidate history: ');
  if (!current.startsWith(`The current v${number} candidate `)) throw new Error(`Queue identity item is not at v${number}`);
  const updated = current.replace(/configuration SHA-256 [0-9a-f]{64}/, `configuration SHA-256 ${configurationSha256}`)
    .replace(/registered source bundle SHA-256 [0-9a-f]{64}/, `registered source bundle SHA-256 ${sourceBundleSha256}`);
  item.currentGap = [updated, ...history].join(' Previous candidate history: ');
  return `${JSON.stringify(queue, null, 2)}\n`;
}

export function refreshTestLiterals(files, { configurationSha256, sourceBundleSha256 }) {
  const execution = files.executionTest
    .replace(/(const expectedConfiguration =\s*')[0-9a-f]{64}(';)/, `$1${configurationSha256}$2`)
    .replace(/(const expectedSourceBundle =\s*')[0-9a-f]{64}(';)/, `$1${sourceBundleSha256}$2`);
  const plan = files.planTest.replace(/(plan\.configurationSha256,\s*')[0-9a-f]{64}(',)/, `$1${configurationSha256}$2`);
  return { executionTest: execution, planTest: plan };
}

export function refreshReplayGolden(text, { version, configurationSha256 }) {
  return text.replace(/^(Algorithm configuration: `[^`]+` @ )`[^`]+` · `[0-9a-f]{64}`$/m, `$1\`${version}\` · \`${configurationSha256}\``);
}

// ---- Side effects ----

function git(args, cwd) { return execFileSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim(); }
function run(command, args, cwd, { env, quiet = false } = {}) {
  const result = spawnSync(command, args, { cwd, env: env ?? process.env, encoding: 'utf8', maxBuffer: 256 * 1024 * 1024, stdio: ['ignore', 'pipe', 'pipe'] });
  if (result.error || result.status !== 0) {
    const output = `${result.stdout ?? ''}${result.stderr ?? ''}`.trim().split('\n').slice(-40).join('\n');
    throw new Error(`${command} ${args.join(' ')} failed (${result.error?.code ?? result.status})\n${output}`);
  }
  if (!quiet) process.stdout.write('.');
  return result.stdout;
}
function probe(cwd, flags = []) {
  const output = run('dart', ['run', 'tool/identity_rebind_probe.dart', ...flags], cwd, { quiet: true });
  const start = output.lastIndexOf('{"version"');
  if (start < 0) throw new Error('identity_rebind_probe.dart printed no result');
  return JSON.parse(output.slice(start));
}
function chainTool(cwd, args) {
  const output = run('dart', ['run', 'tool/governance_ledger_chain.dart', ...args], cwd, { quiet: true });
  return JSON.parse(output.trim().split('\n').at(-1));
}
function printedPins(output) {
  const start = output.lastIndexOf('{\n  "expected');
  if (start < 0) throw new Error('Pin printer emitted no pins');
  return JSON.parse(output.slice(start));
}

const USAGE = `Usage: npm run identity:rebind -- --reason "<clause>" [options]
  --reason "<clause>"      what this identity binds, lower-case, completing "The vN candidate …"
                           (e.g. "binds plain-language result copy; stored scores are unchanged")
  --title "<noun phrase>"  short name for the ledger event, release artifact and chain checkpoint
                           (default "software identity rebind")
  --base <ref>             merge target the branch is rebased onto (default origin/main)
  --version-date YYYY.MM.DD  date prefix for the new identity, ledger, plan and attestation versions
                           (default: keep each current prefix)
  --recorded-at YYYY-MM-DD  ledger record date (default: today, UTC)
  --no-verify              skip the governance tests and gates run after the rebind
  --allow-unchanged        bump even though no registered source or configuration changed
  --reapply <ref>          redo the rebind that <ref> carries (e.g. ORIG_HEAD after a rebase that dropped
                           it): title and reason are read from its appended governance-chain checkpoint
Bumps base vN to vN+1 when the tree is still at vN; when the tree is already at vN+1 it only
refreshes digests, so running it again is a no-op unless sources changed.`;

export function parseArgs(argv) {
  const options = { base: 'origin/main', title: 'software identity rebind', verify: true };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    const value = () => { const next = argv[++index]; if (next === undefined) throw new Error(`${arg} needs a value`); return next; };
    if (arg === '--reason') options.reason = value();
    else if (arg === '--title') { options.title = value(); options.titleGiven = true; }
    else if (arg === '--base') options.base = value();
    else if (arg === '--version-date') options.versionDate = value();
    else if (arg === '--recorded-at') options.recordedAt = value();
    else if (arg === '--no-verify') options.verify = false;
    else if (arg === '--allow-unchanged') options.allowUnchanged = true;
    else if (arg === '--reapply') options.reapply = value();
    else if (arg === '--help') options.help = true;
    else throw new Error(`Unknown argument ${arg}`);
  }
  if (options.reason !== undefined) {
    options.reason = options.reason.trim().replace(/\.$/, '');
    if (!options.reason || /\n/.test(options.reason) || options.reason.length > 600) throw new Error('--reason must be one non-empty line of at most 600 characters');
    if (/^[A-Z]/.test(options.reason) && !/^[A-Z]{2}/.test(options.reason)) throw new Error('--reason continues "The vN candidate …"; start it with a lower-case verb such as "binds"');
  }
  options.title = options.title.trim();
  if (!/^[a-z0-9][a-z0-9 ,.'/-]{2,80}$/i.test(options.title)) throw new Error('--title must be a short plain noun phrase');
  if (options.versionDate && !/^\d{4}\.\d{2}\.\d{2}$/.test(options.versionDate)) throw new Error('--version-date must look like 2026.10.21');
  if (options.recordedAt && !/^\d{4}-\d{2}-\d{2}$/.test(options.recordedAt)) throw new Error('--recorded-at must look like 2026-10-21');
  return options;
}

export async function rebind(options, { cwd = process.cwd(), log = (line) => console.log(line) } = {}) {
  const read = (key) => readFileSync(resolve(cwd, FILES[key]), 'utf8');
  const write = (path, text) => { const target = resolve(cwd, path); if (!existsSync(target) || readFileSync(target, 'utf8') !== text) { writeFileSync(target, text); changed.add(path); } };
  const changed = new Set();
  const baseSha = git(['rev-parse', '--verify', `${options.base}^{commit}`], cwd);
  try { git(['merge-base', '--is-ancestor', baseSha, 'HEAD'], cwd); }
  catch { throw new Error(`HEAD does not contain ${options.base} (${baseSha.slice(0, 7)}). Rebase onto it first; the bump must sit on the latest merge target.`); }
  const baseVersion = readConst(git(['show', `${baseSha}:${FILES.identity}`], cwd), 'defaultVersion');
  const treeVersion = readConst(read('identity'), 'defaultVersion');
  const base = parseVersion(baseVersion);
  const tree = parseVersion(treeVersion);
  let mode;
  if (tree.number === base.number) mode = 'bump';
  else if (tree.number === base.number + 1) mode = 'refresh';
  else throw new Error(`Tree identity ${treeVersion} is neither ${options.base}'s ${baseVersion} nor the next version. Restore the governance files from ${options.base} and rerun.`);
  log(`identity:rebind ${mode === 'bump' ? `bump ${baseVersion} -> v${base.number + 1}` : `refresh digests of ${treeVersion}`} (base ${options.base} ${baseSha.slice(0, 7)})`);
  const toNumber = base.number + 1;

  if (options.reapply) {
    if (mode !== 'bump') throw new Error(`--reapply needs the governance files at ${options.base}'s ${baseVersion}; drop the old rebind commit first.`);
    const own = ownRebind(git(['show', `${baseSha}:${FILES.chain}`], cwd), git(['show', `${options.reapply}:${FILES.chain}`], cwd));
    if (!options.reason) options.reason = own.reason;
    if (!options.titleGiven) options.title = own.title;
    log(`  reapplying "${options.title}" (recorded for v${own.beforeIdentityVersion} in ${options.reapply}) as v${toNumber}`);
  }

  if (mode === 'bump') {
    if (!options.reason) throw new Error('A bump needs --reason "<clause>".');
    // The identity file itself may carry legitimate branch edits (implementation
    // digests); its version already equals the base, which is what matters.
    const handEdited = Object.entries(FILES).filter(([key]) => !['identity', 'queue', 'replayGolden'].includes(key))
      .map(([, path]) => path).filter((path) => spawnSync('git', ['diff', '--quiet', baseSha, '--', path], { cwd }).status !== 0);
    const baseQueue = JSON.parse(git(['show', `${baseSha}:${FILES.queue}`], cwd));
    const treeQueue = JSON.parse(read('queue'));
    for (const id of Object.values(QUEUE_ITEMS)) if (baseQueue.items.find((item) => item.id === id)?.currentGap !== treeQueue.items.find((item) => item.id === id)?.currentGap) handEdited.push(`${FILES.queue} (${id})`);
    if (handEdited.length) throw new Error(`These governance files differ from ${options.base}; branches must not hand-bump the identity:\n  ${handEdited.join('\n  ')}\nRestore them (git checkout ${options.base} -- <files>) and rerun.`);
    if (chainCheckpoint(parseChain(read('chain')), toNumber)) throw new Error(`${FILES.chain} already marks the v${toNumber} bump`);

    // 1. Mark the bump in the governance chain: one checkpoint naming the
    //    complete current ledger, sealed by production code.
    const before = probe(cwd);
    const ledgerSource = read('ledger');
    const frozenSha = readConst(ledgerSource, 'expectedCurrentConfigurationSha256');
    if (before.pinned_source_bundle_sha256 === before.source_bundle_sha256 && before.configuration_sha256 === frozenSha && !options.allowUnchanged) {
      throw new Error('No registered algorithm source or configuration changed since the base identity, so a bump would only add an empty ledger record. Pass --allow-unchanged to bump anyway.');
    }
    const provenance = checkpointProvenance({ baseSha, baseVersion, frozenSha, fromNumber: base.number, toNumber, title: options.title, reason: options.reason });
    const marked = chainTool(cwd, ['checkpoint', '--before-version', String(toNumber), '--provenance', JSON.stringify(provenance)]);
    changed.add(FILES.chain);
    const priorRecordCount = marked.record_count;

    // 2. Advance the identity and bind the actual registered-source bundle.
    const toVersion = `${options.versionDate ?? base.prefix}-v${toNumber}`;
    let identity = bumpIdentity(read('identity'), { toVersion, reason: options.reason });
    identity = replaceConst(identity, 'registeredAlgorithmSourceBundleSha256', before.source_bundle_sha256);
    write(FILES.identity, identity);
    const after = probe(cwd, ['--impact']);

    // 3. Rebind the governance records to the new identity.
    const recordedAtUtc = `${options.recordedAt ?? new Date().toISOString().slice(0, 10)}T00:00:00.000Z`;
    const ctx = { fromNumber: base.number, toNumber, fromVersion: baseVersion, toVersion, priorRecordCount, title: options.title, reason: options.reason, recordedAtUtc, versionPrefix: options.versionDate, newConfigurationSha256: after.configuration_sha256 };
    const ledger = bumpLedger(ledgerSource, ctx);
    write(FILES.ledger, ledger.source);
    const plan = bumpVersionConst(read('plan'), 'planVersion', options.versionDate);
    write(FILES.plan, plan.source);
    const execution = bumpVersionConst(read('execution'), 'attestationVersion', options.versionDate);
    write(FILES.execution, execution.source);
    write(FILES.queue, bumpQueue(read('queue'), { fromNumber: base.number, toNumber, sentences: queueSentences({ ...ctx, configurationSha256: after.configuration_sha256, sourceBundleSha256: after.source_bundle_sha256,
      ledgerVersion: readConst(ledger.source, 'ledgerVersion'), planVersion: plan.to, attestationVersion: execution.to }) }));
    write(FILES.releaseProbe, bumpReleaseProbe(read('releaseProbe'), ctx));
    write(FILES.ledgerTest, bumpLedgerTest(read('ledgerTest'), ctx));
    write(FILES.executionTest, bumpExecutionTest(read('executionTest'), ctx));
    log(`  ledger record ${priorRecordCount + 1} (${ledger.variable}); the v${toNumber} checkpoint names the ${priorRecordCount} prior records in ${FILES.chain}`);
    log(`  plan ${plan.from} -> ${plan.to}; attestation ${execution.from} -> ${execution.to}`);
  } else {
    const ledgerSource = read('ledger');
    if (!new RegExp(`static const String historicalV${base.number}ConfigurationSha256`).test(ledgerSource) || !chainCheckpoint(parseChain(read('chain')), toNumber)) {
      throw new Error(`Tree is at ${treeVersion} but lacks the v${toNumber} ledger rebind or its ${FILES.chain} checkpoint; it was not produced by this tool.`);
    }
    if (options.reason) log('  already bound; --reason is not re-applied (edit the prose by hand if it must change)');
  }

  // 4. Refresh every digest from production code and the pin printers.
  const current = probe(cwd);
  if (current.pinned_source_bundle_sha256 !== current.source_bundle_sha256) write(FILES.identity, replaceConst(read('identity'), 'registeredAlgorithmSourceBundleSha256', current.source_bundle_sha256));
  const bound = probe(cwd, ['--impact']);
  const digests = { configurationSha256: bound.configuration_sha256, sourceBundleSha256: bound.source_bundle_sha256 };
  write(FILES.ledger, replaceConst(read('ledger'), 'expectedCurrentConfigurationSha256', digests.configurationSha256));
  // The new record follows the last checkpoint; only that tail is rewritten.
  const chainBefore = read('chain');
  const chainPins = chainTool(cwd, ['sync']);
  if (read('chain') !== chainBefore) changed.add(FILES.chain);
  write(FILES.chainPins, bindChainPins(read('chainPins'), chainPins));
  write(FILES.plan, replaceConst(read('plan'), 'expectedConfigurationSha256', digests.configurationSha256));
  write(FILES.execution, replaceConst(replaceConst(read('execution'), 'expectedConfigurationSha256', digests.configurationSha256), 'expectedAlgorithmSourceBundleSha256', digests.sourceBundleSha256));
  write(FILES.impact, replaceConst(replaceConst(read('impact'), 'baselineFixtureSha256Pin', bound.impact_baseline_sha256), 'currentFixtureSha256Pin', digests.configurationSha256));
  const tests = refreshTestLiterals({ executionTest: read('executionTest'), planTest: read('planTest') }, digests);
  write(FILES.executionTest, tests.executionTest);
  write(FILES.planTest, tests.planTest);
  write(FILES.queue, refreshQueueDigests(read('queue'), { number: toNumber, ...digests }));
  write(FILES.replayGolden, refreshReplayGolden(read('replayGolden'), { version: bound.version, configurationSha256: digests.configurationSha256 }));
  const movedPins = [];
  const repin = (key, names, output) => {
    const pins = printedPins(output);
    let source = read(key);
    for (const name of names) {
      if (readConst(source, name) === pins[name]) continue;
      source = replaceConst(source, name, pins[name]);
      movedPins.push(`${key}.${name}`);
    }
    write(FILES[key], source);
  };
  run('dart', ['run', 'tool/run_algorithm_executable_contract_check.dart'], cwd);
  repin('oracle', ORACLE_PINS, run('node', ['tool/independent_algorithm_contract_oracle.mjs', '--print-pins'], cwd));
  run('dart', ['run', 'tool/run_algorithm_relation_production_sampling.dart'], cwd);
  repin('sampling', SAMPLING_PINS, run('node', ['tool/algorithm_relation_domain_sampling.mjs', '--print-pins'], cwd));
  const dartFiles = [...changed].filter((path) => path.endsWith('.dart'));
  if (dartFiles.length) run('dart', ['format', ...dartFiles], cwd);
  process.stdout.write('\n');
  log(`  ${bound.version}: configuration ${digests.configurationSha256}`);
  log(`  registered source bundle ${digests.sourceBundleSha256}; impact baseline ${bound.impact_baseline_sha256}`);
  const unexpected = movedPins.filter((pin) => !IDENTITY_BOUND_PINS.has(pin));
  if (movedPins.length) log(`  re-pinned ${movedPins.join(', ')}`);
  if (unexpected.length) log(`  REVIEW: ${unexpected.join(', ')} moved; these do not depend on the identity, so an input to that gate changed on this branch.`);
  log(changed.size ? `  changed ${changed.size} files:\n    ${[...changed].sort().join('\n    ')}` : '  nothing to change: the tree is already bound');

  if (options.verify) {
    log('  verifying with the existing governance tests and gates …');
    run('flutter', ['test', ...VERIFY_TESTS], cwd);
    for (const script of VERIFY_SCRIPTS) run('npm', ['run', '--silent', script], cwd);
    process.stdout.write('\n');
    log(`  verified: ${VERIFY_TESTS.length} test files and ${VERIFY_SCRIPTS.length} gates pass`);
  }
  return { mode, version: bound.version, digests, changed: [...changed].sort(), movedPins, unexpectedPins: unexpected };
}

export async function main(argv = process.argv.slice(2)) {
  let options;
  try { options = parseArgs(argv); }
  catch (error) { console.error(`${error.message}\n${USAGE}`); return 2; }
  if (options.help) { console.log(USAGE); return 0; }
  try { await rebind(options); return 0; }
  catch (error) { console.error(`\nidentity:rebind failed: ${error.message}`); return 1; }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) main().then((code) => { process.exitCode = code; });
