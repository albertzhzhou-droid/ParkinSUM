# Configuration identity rebind at merge time

Educational/research prototype. Synthetic/demo data only. A rebind is
engineering change control: it records that the software identity moved. It adds
no evidence, review, validation or approval, and every evidence hold stays in
force.

## What a rebind is

Every change to a registered algorithm source or to a result-affecting
parameter changes the registered-source bundle and the canonical configuration
digest in `lib/algorithm_sdk/algorithm_configuration_identity.dart`. The
governance records then have to move with it. The hand-made v80 → v81 rebind
(commit `20fc7f6`) shows the full set, and `npm run identity:rebind` performs
exactly that set:

| File | Change |
| --- | --- |
| `lib/algorithm_sdk/algorithm_configuration_identity.dart` | `defaultVersion` vN → vN+1 with a one-sentence comment; actual registered-source bundle digest |
| `lib/domain/entities/context_of_use_requalification.dart` | ledger version +1; `historicalVNConfigurationSha256` keeps the old digest; one appended blocked `software_identity_candidate_rebind` record copying the previous record's evidence decisions |
| `config/governance_ledger.jsonl` | two appended lines: a checkpoint naming the complete vN ledger (record count, snapshot digest, base commit, title and reason) and the new record; nothing earlier is rewritten |
| `lib/domain/entities/governance_ledger_chain.dart` | chain pins: `expectedEntryCount`, `expectedHeadSha256` and one appended `GovernanceLedgerCheckpointPin` linking the checkpoint to `historicalVNConfigurationSha256` |
| `lib/domain/entities/prospective_model_credibility_plan.dart`, `credibility_evidence_execution_attestation.dart` | plan and attestation versions +1, new configuration (and bundle) digest |
| `lib/domain/usecases/algorithm_configuration_change_impact_service.dart` | both independent fixture pins |
| `lib/domain/entities/algorithm_contract_independent_oracle_attestation.dart`, `algorithm_relation_domain_sampling_attestation.dart` | pins re-printed by the oracle and sampling tools (`--print-pins`) |
| `config/complete_app_upgrade_queue.json` | the four identity, ledger, plan and attestation sentences; the old sentence becomes "Previous candidate history" |
| `tool/web_user_state_capacity_release_probe.dart` | expected version |
| `test/context_of_use_requalification_test.dart`, `test/credibility_evidence_execution_attestation_test.dart`, `test/prospective_model_credibility_plan_test.dart` | counts, version and digests (no test is added per bump) |
| `test/goldens/mechanistic_replay.md` | the header line that names the identity (only that line) |

Digests are never computed by the script itself. `tool/identity_rebind_probe.dart`
asks production code (the same bundle payload as
`test/parkinsum_algorithm_sdk_test.dart`, `AlgorithmConfigurationIdentity.defaults()`
and the impact service's own pin check), `tool/governance_ledger_chain.dart`
seals chain lines with `GovernanceLedgerChain` over
`ContextOfUseRequalificationLedger.current`, and the oracle and sampling pins
come from their existing `--print-pins` modes.

## The governance history chain

Before v84 every bump froze the whole ledger into a new
`test/fixtures/governance_history_before_vN.json` and added a test comparing it.
Those 22 files (v62 … v83, 3.0 MB) now live in one append-only file,
`config/governance_ledger.jsonl`, one canonical JSON line per entry:

- a `record` line per ledger record: the whole `record.toJson()`, its
  `record_sha256`, the identity version it was appended for and its sequence;
- a `checkpoint` line per bump, before the bump's record: the record count and
  `snapshot_sha256` of the ledger as it stood, plus provenance (base commit,
  configuration version and digest, boundary, and from v84 on the rebind title
  and reason). The 22 migrated checkpoints also keep each fixture's path, size,
  sha256 and key layout, and `test/governance_ledger_chain_test.dart` rebuilds
  every one of those files byte for byte from the chain.

Each line carries `previous_entry_sha256` (64 zeros for the first) and
`entry_sha256`, the SHA-256 of the line's canonical JSON without that field.
`GovernanceLedgerChain.verify` (production code, run by the ledger tests and the
`cou:requalification` gate) checks that every line is canonical, every link and
digest recomputes, every record equals the production ledger record, every
checkpoint's snapshot recomputes and links its last record to the pinned
`historicalVNConfigurationSha256`, and that the head, length and checkpoints
equal the pins in `lib/domain/entities/governance_ledger_chain.dart`. The ledger
as of any version is `snapshotAt(N)`; the ledger before a bump is
`snapshotBefore(N)`. Editing, re-hashing, reordering or deleting an earlier
line fails; so does a fully re-sealed rewrite, because the checkpoint pins and
the head no longer match. Neither the chain nor the old fixtures defend against
an author who rewrites history and its pins in one reviewed commit; code review
and git history remain that control.

## The rule: do not hand-bump on parallel branches

Two branches that each bump vN → vN+1 both edit the same governance files, so
the second merge conflicts in each of them. The history itself no longer adds a
file per bump: both branches append to the end of
`config/governance_ledger.jsonl`, so the chain conflicts on exactly one range,
the lines each branch appended. The tool regenerates that range and every other
governance edit, so never resolve these conflicts by hand. Instead:

1. **On the branch:** change the code and the tests that describe the change.
   Leave the identity, ledger, plan, attestations, queue sentences, release-probe
   version and governance chain alone in your feature commits. Until a rebind,
   the SDK bundle and attestation tests fail; that only says a rebind is due.
   For a green CI run before merging, add the rebind with the tool as a separate
   last commit, and drop and redo it whenever you rebase.
2. **At merge time:** rebase onto the merge target, rebind, commit:

   ```bash
   git fetch origin && git rebase origin/main
   ```

   ```bash
   npm run identity:rebind -- --title "plain-language result copy" --reason "binds plain-language result copy; stored scores, severities and rule decisions are unchanged"
   ```

   ```bash
   git add -A && git commit -m "Rebind configuration identity"
   ```

   Keep the rebind as its own last commit. If the target moves again before the
   merge, drop that commit (`git reset --hard HEAD~1` when it is the tip),
   rebase, and run the tool again; it will bind the next free version.
3. **Then** run `npm run verify:pr` and push.

### When the target moved under a finished rebind

The rebind records its own title and reason in its chain checkpoint, so
`--reapply <ref>` redoes it without retyping them. If another bump landed first,
the rebase stops on your rebind commit with conflicts in the governance files
and on the appended range of the chain. Skip that commit and re-apply it from
the pre-rebase tip, which git keeps as `ORIG_HEAD`:

```bash
git rebase origin/main
```

```bash
git rebase --skip
```

```bash
npm run identity:rebind -- --reapply ORIG_HEAD
```

```bash
git add -A && git commit -m "Rebind configuration identity"
```

`git rebase --skip` drops only the rebind commit; resolve any conflict in your
own feature commits as usual first. `--reapply` reads the one checkpoint that
`<ref>` appended beyond the base's chain, takes its `rebind_title` and
`rebind_reason` (an explicit `--title` or `--reason` wins), and then bumps
exactly like a fresh run: the next free version, appended after the base's
newest line. After `git reset --hard HEAD~1` the same `--reapply ORIG_HEAD`
works. A rebind made before the chain existed has no recorded title or reason;
pass them explicitly.

`--reason` completes the sentence "The vN candidate …", so it starts with a
lower-case verb. `--title` is a short noun phrase used for the ledger event, the
release-artifact name and the chain checkpoint. `--base` (default `origin/main`),
`--version-date YYYY.MM.DD`, `--recorded-at YYYY-MM-DD` and `--reapply <ref>` are
optional.

## Behaviour

- **Bump** (tree identity equals the base's vN): refuses unless HEAD contains the
  base, the governance files listed above are unchanged from the base, and some
  registered source or configuration actually changed (override the last check
  with `--allow-unchanged`). Then it performs the table above.
- **Refresh** (tree is already at vN+1 with its ledger record and chain
  checkpoint): only digests are recomputed. The chain's last record, the one
  after the newest checkpoint, is re-sealed if its digests moved; every earlier
  line is checked and left untouched. Running the tool twice changes nothing
  the second time; after further source edits it moves only the digests.
- **Verify:** afterwards it runs the nine governance test files
  (ledger, chain, plan, attestation, impact, SDK, oracle, sampling, goldens) and the
  `algorithm:contracts:independent`, `algorithm:contracts:sampling`,
  `cou:requalification`, `algorithm:configuration-impact`,
  `credibility:prospective`, `credibility:execution` and `upgrade:queue` gates.
  `--no-verify` skips that.
- **Review prompt:** pins that embed the identity (oracle report, sampling
  anchor, execution and report digests) are expected to move. If any other pin
  moves, the tool prints `REVIEW:` because an input to that gate changed on the
  branch.

A pure version bump without a source change leaves the configuration digest as
it was (the version string is not part of the digest), which is why the tool
refuses it by default.

The tool does not write prose beyond the sentences above. Add the timeline entry,
documentation and any `docs/known_risks.md` notes yourself.
