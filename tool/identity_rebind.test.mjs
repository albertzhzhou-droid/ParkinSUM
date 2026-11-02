import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { test } from 'node:test';
import {
  FILES, QUEUE_ITEMS, bindChainPins, bumpExecutionTest, bumpIdentity, bumpLedger, bumpLedgerTest, bumpQueue, bumpReleaseProbe, bumpVersionConst,
  chainCheckpoint, chainPinRow, checkpointProvenance, dartStringLiterals, lastLedgerRecordVariable, numberWords, ownRebind, parseArgs, parseChain,
  parseVersion, pinnedCheckpoints, queueSentences, readConst, readIntConst, refreshQueueDigests, refreshReplayGolden, refreshTestLiterals,
} from './identity_rebind.mjs';

const files = Object.fromEntries(Object.entries(FILES).map(([key, path]) => [key, readFileSync(path, 'utf8')]));
const version = readConst(files.identity, 'defaultVersion');
const { prefix, number } = parseVersion(version);
const priorRecordCount = lastLedgerRecordVariable(files.ledger).names.length;
const fakeConfiguration = 'c'.repeat(64);
const fakeBundle = 'b'.repeat(64);
const ctx = { fromNumber: number, toNumber: number + 1, fromVersion: version, toVersion: `${prefix}-v${number + 1}`, priorRecordCount,
  title: 'example change', reason: 'binds an example change; stored results are unchanged', recordedAtUtc: '2026-10-21T00:00:00.000Z', newConfigurationSha256: fakeConfiguration };

test('number words cover the ledger range', () => {
  assert.equal(numberWords(29), 'twenty-nine');
  assert.equal(numberWords(30), 'thirty');
  assert.equal(numberWords(41), 'forty-one');
  assert.throws(() => numberWords(100));
});

test('Dart string literals stay within 80 columns and preserve the text', () => {
  const text = `The v99 candidate binds "quoted" text, a dollar $value and a backslash \\ with ${'long words '.repeat(20)}end`;
  const literal = dartStringLiterals(text, '          ');
  for (const line of literal.split('\n')) assert(line.length <= 80, line);
  const decoded = literal.split('\n').map((line) => line.trim().slice(1, -1)).join('').replace(/\\(.)/g, '$1');
  assert.equal(decoded, text.replace(/\s+/g, ' '));
});

test('the current tree is a bound identity the rebind can read', () => {
  for (const path of Object.values(FILES)) assert(existsSync(path), path);
  const chain = parseChain(files.chain);
  assert(chainCheckpoint(chain, number), `the v${number} bump left its governance-chain checkpoint`);
  assert.equal(chain.at(-1).entry_kind, 'record');
  assert.equal(chain.at(-1).identity_version, number);
  assert.equal(readIntConst(files.chainPins, 'expectedEntryCount'), chain.length);
  assert.equal(readConst(files.chainPins, 'expectedHeadSha256'), chain.at(-1).entry_sha256);
  assert.deepEqual(pinnedCheckpoints(files.chainPins), chain.filter((entry) => entry.entry_kind === 'checkpoint').map((entry) => ({
    before_identity_version: entry.before_identity_version, record_count: entry.record_count, snapshot_sha256: entry.snapshot_sha256, entry_sha256: entry.entry_sha256 })));
  assert(!existsSync(`test/fixtures/governance_history_before_v${number}.json`), 'history lives in the chain, not in fixtures');
  assert.equal(readConst(files.execution, 'expectedConfigurationSha256'), readConst(files.ledger, 'expectedCurrentConfigurationSha256'));
  assert.equal(readConst(files.plan, 'expectedConfigurationSha256'), readConst(files.ledger, 'expectedCurrentConfigurationSha256'));
  assert.equal(readConst(files.impact, 'currentFixtureSha256Pin'), readConst(files.ledger, 'expectedCurrentConfigurationSha256'));
  const queue = JSON.parse(files.queue);
  for (const id of Object.values(QUEUE_ITEMS)) assert(queue.items.find((item) => item.id === id).currentGap.startsWith(`The current v${number} candidate `), id);
});

test('a bump reproduces the shape of the hand-made rebinds', () => {
  const identity = bumpIdentity(files.identity, ctx);
  assert.equal(readConst(identity, 'defaultVersion'), ctx.toVersion);
  assert.match(identity, new RegExp(`// v${number + 1} binds an example change; stored results are unchanged\\.\\n  static const String defaultVersion`));

  const ledger = bumpLedger(files.ledger, ctx);
  const previous = lastLedgerRecordVariable(files.ledger).last;
  assert.deepEqual(lastLedgerRecordVariable(ledger.source).names, [...lastLedgerRecordVariable(files.ledger).names, 'exampleChangeCandidateRecord']);
  assert.equal(readConst(ledger.source, `historicalV${number}ConfigurationSha256`), readConst(files.ledger, 'expectedCurrentConfigurationSha256'));
  assert.equal(readConst(ledger.source, 'expectedCurrentConfigurationSha256'), fakeConfiguration);
  assert.equal(parseVersion(readConst(ledger.source, 'ledgerVersion')).number, parseVersion(readConst(files.ledger, 'ledgerVersion')).number + 1);
  assert.equal(ledger.source.split('currentConfigurationSha256: expectedCurrentConfigurationSha256,').length - 1, 1, 'only the new record is current');
  assert.match(ledger.source, new RegExp(`sequence: ${priorRecordCount + 1},\\n      changeKind: 'software_identity_candidate_rebind',\\n      previousManifestSha256: ${previous}\\.currentManifestSha256,`));
  assert.match(ledger.source, /releaseArtifact: 'unreleased-worktree:example-change-v\d+',/);
  assert.match(ledger.source, /releaseDisposition: CouReleaseDisposition\.blockedPendingEvidence,\n      approvalSignature: null,/);
  assert.match(ledger.source, new RegExp(`All ${numberWords(priorRecordCount)} prior whole records`));

  const ledgerTest = bumpLedgerTest(files.ledgerTest, ctx);
  assert.match(ledgerTest, new RegExp(`'v${number + 1} candidate retains all ${numberWords(priorRecordCount)} historical blocked records`));
  assert.match(ledgerTest, new RegExp(`hasLength\\(${priorRecordCount + 1}\\)`));
  assert(!ledgerTest.includes('governance_history_before_v'), 'no frozen-history fixture test is added');
  assert.equal(ledgerTest.split('\n  test(').length, files.ledgerTest.split('\n  test(').length, 'no test is added per bump');

  assert.match(bumpExecutionTest(files.executionTest, ctx), new RegExp(`defaultVersion, '${ctx.toVersion}'`));
  assert.match(bumpReleaseProbe(files.releaseProbe, ctx), new RegExp(`'current v${number + 1} configuration identity'`));
  const plan = bumpVersionConst(files.plan, 'planVersion');
  const execution = bumpVersionConst(files.execution, 'attestationVersion', '2030.01.02');
  assert.equal(parseVersion(plan.to).number, parseVersion(plan.from).number + 1);
  assert.equal(parseVersion(execution.to).prefix, '2030.01.02');

  const queue = JSON.parse(bumpQueue(files.queue, { ...ctx, sentences: queueSentences({ ...ctx, configurationSha256: fakeConfiguration, sourceBundleSha256: fakeBundle, ledgerVersion: 'L', planVersion: plan.to, attestationVersion: execution.to }) }));
  const before = JSON.parse(files.queue);
  for (const id of Object.values(QUEUE_ITEMS)) {
    const gap = queue.items.find((item) => item.id === id).currentGap;
    assert(gap.startsWith(`The current v${number + 1} candidate `), id);
    assert(gap.endsWith(before.items.find((item) => item.id === id).currentGap.replace(`The current v${number} candidate `, '')), `${id} keeps its history`);
    assert(gap.includes(` Previous candidate history: The v${number} candidate `), id);
  }
});

test('digest refreshes are idempotent and a no-op on the bound tree', () => {
  const digests = { configurationSha256: readConst(files.execution, 'expectedConfigurationSha256'), sourceBundleSha256: readConst(files.execution, 'expectedAlgorithmSourceBundleSha256') };
  assert.deepEqual(refreshTestLiterals(files, digests), { executionTest: files.executionTest, planTest: files.planTest });
  assert.equal(refreshQueueDigests(files.queue, { number, ...digests }), files.queue);
  assert.equal(refreshReplayGolden(files.replayGolden, { version, configurationSha256: digests.configurationSha256 }), files.replayGolden);
  const moved = { configurationSha256: fakeConfiguration, sourceBundleSha256: fakeBundle };
  const once = refreshTestLiterals(files, moved);
  assert.deepEqual(refreshTestLiterals({ ...files, ...once }, moved), once);
  assert(once.executionTest.includes(fakeConfiguration) && once.executionTest.includes(fakeBundle) && once.planTest.includes(fakeConfiguration));
  const queue = refreshQueueDigests(files.queue, { number, ...moved });
  assert.equal(refreshQueueDigests(queue, { number, ...moved }), queue);
  const identityGap = JSON.parse(queue).items.find((item) => item.id === QUEUE_ITEMS.identity).currentGap;
  assert(identityGap.split(' Previous candidate history: ')[0].includes(fakeBundle));
  assert.equal(identityGap.split(' Previous candidate history: ').slice(1).join(), JSON.parse(files.queue).items.find((item) => item.id === QUEUE_ITEMS.identity).currentGap.split(' Previous candidate history: ').slice(1).join(), 'history digests never move');
});

test('arguments are validated before anything is touched', () => {
  assert.deepEqual(parseArgs(['--reason', 'binds x.']).reason, 'binds x');
  assert.equal(parseArgs([]).base, 'origin/main');
  assert.throws(() => parseArgs(['--reason', 'Binds x']), /lower-case/);
  assert.throws(() => parseArgs(['--reason', 'a\nb']));
  assert.throws(() => parseArgs(['--version-date', '2026-10-21']));
  assert.throws(() => parseArgs(['--unknown']));
  const pkg = JSON.parse(readFileSync('package.json', 'utf8'));
  assert.equal(pkg.scripts['identity:rebind'], 'node tool/identity_rebind.mjs');
});

test('chain pins bind the head and length and add one row per new checkpoint', () => {
  const chain = parseChain(files.chain);
  const checkpoints = chain.filter((entry) => entry.entry_kind === 'checkpoint').map((entry) => ({
    before_identity_version: entry.before_identity_version, record_count: entry.record_count, snapshot_sha256: entry.snapshot_sha256, entry_sha256: entry.entry_sha256 }));
  const pins = { entry_count: chain.length, head_sha256: chain.at(-1).entry_sha256, checkpoints };
  assert.equal(bindChainPins(files.chainPins, pins), files.chainPins, 'a no-op on the bound tree');

  const added = { before_identity_version: number + 1, record_count: priorRecordCount, snapshot_sha256: 'a'.repeat(64), entry_sha256: 'e'.repeat(64) };
  const bumped = bindChainPins(files.chainPins, { entry_count: chain.length + 2, head_sha256: 'f'.repeat(64), checkpoints: [...checkpoints, added] });
  assert.equal(readIntConst(bumped, 'expectedEntryCount'), chain.length + 2);
  assert.equal(readConst(bumped, 'expectedHeadSha256'), 'f'.repeat(64));
  assert.deepEqual(pinnedCheckpoints(bumped).at(-1), added);
  assert(bumped.includes(chainPinRow(added)));
  assert.match(chainPinRow(added), new RegExp(`historicalV${number}ConfigurationSha256`));

  const rewritten = checkpoints.map((pin, index) => index === 3 ? { ...pin, snapshot_sha256: 'b'.repeat(64) } : pin);
  assert.throws(() => bindChainPins(files.chainPins, { ...pins, checkpoints: rewritten }), /must never be rewritten/);
});

test('--reapply recovers the title and reason a branch appended to the chain', () => {
  const lines = files.chain.trimEnd().split('\n');
  const provenance = checkpointProvenance({ baseSha: '0'.repeat(40), baseVersion: version, frozenSha: fakeConfiguration, fromNumber: number, toNumber: number + 1,
    title: 'example change', reason: 'binds an example change; stored results are unchanged' });
  assert.match(provenance.boundary, new RegExp(`^Complete v${number} ledger before the v${number + 1} example change rebind;`));
  const checkpoint = JSON.stringify({ entry_kind: 'checkpoint', before_identity_version: number + 1, provenance, entry_sha256: 'c'.repeat(64) });
  const record = JSON.stringify({ entry_kind: 'record', identity_version: number + 1, entry_sha256: 'd'.repeat(64) });
  const branch = `${[...lines, checkpoint, record].join('\n')}\n`;
  assert.deepEqual(ownRebind(files.chain, branch), { title: 'example change', reason: provenance.rebind_reason, beforeIdentityVersion: number + 1 });

  // A conflicted rebase leaves markers around the two appended ranges.
  const theirs = JSON.stringify({ entry_kind: 'checkpoint', before_identity_version: number + 1, provenance: { ...provenance, rebind_title: 'other' }, entry_sha256: '9'.repeat(64) });
  const conflicted = `${[...lines, '<<<<<<< HEAD', theirs, '=======', checkpoint, record, '>>>>>>> rebind'].join('\n')}\n`;
  assert.equal(parseChain(conflicted).length, lines.length + 3);
  assert.throws(() => ownRebind(files.chain, conflicted), /found 2/);
  assert.equal(ownRebind(`${[...lines, theirs].join('\n')}\n`, conflicted).title, 'example change');
  assert.throws(() => ownRebind(files.chain, files.chain), /found 0/);
  assert.equal(parseArgs(['--reapply', 'ORIG_HEAD']).reapply, 'ORIG_HEAD');
  assert.equal(parseArgs(['--reapply', 'ORIG_HEAD']).titleGiven, undefined);
  assert.equal(parseArgs(['--title', 'x y z']).titleGiven, true);
});
