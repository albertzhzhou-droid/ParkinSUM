# Proposal: replace frozen history fixtures with one hash-chained ledger file

Status: implemented on branch `audit/governance-ledger-chain` (identity v83,
32 ledger records); see "As implemented" at the end. Engineering change control,
not evidence or review. The measurements below are from the proposal date.

## What the fixtures guarantee today

Before each identity rebind the complete context-of-use ledger is frozen into
`test/fixtures/governance_history_before_vN.json`, and
`test/context_of_use_requalification_test.dart` gains a test asserting that the
first *k* records of today's ledger still equal that file, whole JSON and
`record_sha256`. Together the files prove three things:

1. **Immutability.** No earlier record has been edited, re-hashed or reordered.
2. **Per-version snapshots.** The exact ledger that existed before each bump can
   be named and compared.
3. **Linkage.** The last frozen record's current configuration equals the pinned
   `historicalVNConfigurationSha256`.

## Measured cost (main `b4b9ea2`, identity v81, 30 ledger records)

| Measure | Value |
| --- | --- |
| Fixture files | 20 (`before_v62` … `before_v81`) |
| Lines / bytes on disk | 54,384 lines / 2,600,364 bytes |
| Gzipped | 227,121 bytes |
| Git objects for these paths (all history) | 57 blobs, 2,882,258 bytes raw, 414,315 bytes packed |
| Record copies across fixtures | 390, of only 29 distinct records (every copy of a record is identical) |
| Same records stored once, pretty-printed | 176,405 bytes (6.8 % of today's size) |
| Growth per bump | a new file of ≈ 6.6–6.9 KB × record count (last five: 6,532–6,867 bytes per added record) |
| Header shapes | 10 different key sets (`records`/`ledger_records`, `record_sha256`/`ledger_record_sha256`/`record_sha256s`, …) |
| Tests | 20 of the 30 tests in the ledger test file exist only to compare a fixture |

Because each file copies every earlier record, total size grows with the square
of the record count: at the current per-record size, 50 records would mean about
7.7 MB of fixtures and 100 records about 32 MB. Each bump also adds a ~4,000-line
file to the review diff and a new path that two parallel bumps both create
(add/add conflict), which is part of why parallel bumps conflicted in PR #163.
Run time is not the problem: reading 2.6 MB of JSON is negligible next to test
compilation.

## Proposal

One append-only file, for example `test/fixtures/governance_ledger_chain.jsonl`,
with one canonical JSON line per ledger record:

```json
{"sequence":30,"appended_at_identity":"2026.10.20-v81","record":{…record.toJson()…},"record_sha256":"…","previous_entry_sha256":"…","entry_sha256":"…"}
```

- `entry_sha256 = SHA-256(canonical JSON of the line without entry_sha256)`, and
  `previous_entry_sha256` is the previous line's `entry_sha256` (64 zeros for
  record 1). Canonical JSON means the existing
  `AlgorithmConfigurationIdentity.digestConfiguration` encoding, so Dart and
  Node agree.
- The ledger source keeps two pins: `expectedChainLength` and
  `expectedChainHeadSha256`, plus a short `chainCheckpoints` list with one
  `(identity version, length, head sha256)` triple per past bump.

One test replaces the twenty fixture tests:

1. Each chain line's `record` and `record_sha256` equal `ledger.records[i]`
   (whole JSON and digest), as today.
2. Every `previous_entry_sha256` links and every `entry_sha256` recomputes; the
   final head and length equal the pins. Editing, reordering or deleting any
   earlier line changes every later entry and the head, so it fails exactly
   where a fixture comparison fails today.
3. For each checkpoint, the running head after `length` lines equals the pinned
   head. This is the per-version snapshot: "the ledger before vN+1" is the chain
   prefix of that length, and its identity is one 64-character pin instead of a
   file.
4. The line at each checkpoint's length carries the configuration digest pinned
   in `historicalVNConfigurationSha256`, preserving the linkage check.

`identity:rebind` would append one line, add one checkpoint and update the two
pins instead of writing a new fixture: about 7 KB and 3 lines per bump, linear
growth, no new file path.

## Guarantees compared

| Guarantee | Frozen fixtures | Hash chain |
| --- | --- | --- |
| Earlier records unchanged (JSON and digest) | yes, per file | yes, per line, plus chained digests |
| Ledger as of each past bump | a file per bump | chain prefix plus one pinned head per bump |
| Linkage to historical configuration digests | yes | yes |
| Tamper evidence if the test itself is edited | none; fixture and test can be edited together | same; the pins can be edited together. Neither design defends against an author rewriting history in one reviewed commit; code review and git history remain that control |
| Size | quadratic (2.6 MB now) | linear (~180 KB now) |
| New paths per bump | one | none |

## Migration (one reviewed commit)

1. Generate the chain from the current ledger (30 records) with a probe like
   `tool/identity_rebind_probe.dart --ledger`.
2. For each of the 20 fixtures, check that its records are exactly the chain
   prefix of that length (true today: the 390 copies collapse to 29 distinct
   records) and record its checkpoint `(version, length, head)` and the
   fixture's own sha256 in the commit message for provenance.
3. Replace the 20 fixture tests with the single chain test; run it, the full
   ledger test file and `npm run verify:pr`.
4. Delete the 20 fixtures and teach `identity:rebind` to append instead.
5. Keep the deleted fixtures recoverable from git history; nothing about the
   historical records themselves changes.

## As implemented

Implemented at identity v83 with 32 records and 22 fixtures (`before_v62` …
`before_v83`, 62,883 lines, 3,010,226 bytes). Differences from the proposal above:

- **Location and shape.** The chain is `config/governance_ledger.jsonl` (54
  lines, 203,190 bytes, 6.7 % of the fixtures; a bump appends two lines, about
  6 KB). Version boundaries are lines of the chain itself: a `checkpoint` line
  before each bump's record carries the snapshot digest and record count of the
  ledger before the bump and the fixture header as normalized provenance. `record` lines carry
  `identity_version`, so `snapshotAt(N)` names the ledger as of any vN and
  `snapshotBefore(N)` the ledger before a bump.
- **Pins.** `lib/domain/entities/governance_ledger_chain.dart` pins the length,
  the head and, per checkpoint, the record count, snapshot digest, checkpoint
  `entry_sha256` and the `historicalVNConfigurationSha256` its last record must
  carry. Records 19–21 now reference new `historicalV70`–`V72` constants (values
  unchanged) so every checkpoint links to a pin.
- **Verification in production code.** `GovernanceLedgerChain.verify` runs in
  `test/governance_ledger_chain_test.dart` and in the `cou:requalification`
  gate, which now fails when the chain fails. Reasons name the offending line.
  Negative tests cover an edited line, an edited and re-hashed line, a fully
  re-sealed rewrite, reordering, deletion of a record, a checkpoint or the
  newest line, a broken link, non-canonical or malformed lines, a wrong
  linkage pin and a duplicated checkpoint.
- **Lossless migration.** Each migrated checkpoint keeps the fixture's path,
  size, sha256 and key layout (the 10 header shapes map onto one provenance
  shape), and the test rebuilds all 22 fixtures byte for byte from the chain and
  checks their sha256. The commit that adds the chain keeps the fixtures and
  their 22 tests and proves both agree; the next commit deletes them. The 22
  fixture tests are replaced by 22 chain tests (see the timeline entry for the
  measured run).
- **Rebind.** `npm run identity:rebind` appends a checkpoint and a record and
  updates the pins instead of writing a fixture and a test. `--reapply <ref>`
  redoes a dropped rebind from the title and reason its checkpoint recorded;
  docs/IDENTITY_REBIND.md documents the merge workflow.
