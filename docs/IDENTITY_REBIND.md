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
| `test/fixtures/governance_history_before_vN+1.json` | every prior ledger record and record digest, read through production code |
| `lib/domain/entities/prospective_model_credibility_plan.dart`, `credibility_evidence_execution_attestation.dart` | plan and attestation versions +1, new configuration (and bundle) digest |
| `lib/domain/usecases/algorithm_configuration_change_impact_service.dart` | both independent fixture pins |
| `lib/domain/entities/algorithm_contract_independent_oracle_attestation.dart`, `algorithm_relation_domain_sampling_attestation.dart` | pins re-printed by the oracle and sampling tools (`--print-pins`) |
| `config/complete_app_upgrade_queue.json` | the four identity, ledger, plan and attestation sentences; the old sentence becomes "Previous candidate history" |
| `tool/web_user_state_capacity_release_probe.dart` | expected version |
| `test/context_of_use_requalification_test.dart`, `test/credibility_evidence_execution_attestation_test.dart`, `test/prospective_model_credibility_plan_test.dart` | counts, version, digests and one new frozen-history test |
| `test/goldens/mechanistic_replay.md` | the header line that names the identity (only that line) |

Digests are never computed by the script itself. `tool/identity_rebind_probe.dart`
asks production code (the same bundle payload as
`test/parkinsum_algorithm_sdk_test.dart`, `AlgorithmConfigurationIdentity.defaults()`,
the impact service's own pin check and `ContextOfUseRequalificationLedger.current`),
and the oracle and sampling pins come from their existing `--print-pins` modes.

## The rule: do not hand-bump on parallel branches

Two branches that each bump vN → vN+1 both edit the same thirteen files and both
add `governance_history_before_vN+1.json`, so the second merge conflicts
everywhere and has to be redone by hand. Instead:

1. **On the branch:** change the code and the tests that describe the change.
   Leave the identity, ledger, plan, attestations, queue sentences, release-probe
   version and frozen fixtures alone in your feature commits. Until a rebind,
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

`--reason` completes the sentence "The vN candidate …", so it starts with a
lower-case verb. `--title` is a short noun phrase used for the ledger event, the
release-artifact name and the fixture boundary. `--base` (default `origin/main`),
`--version-date YYYY.MM.DD` and `--recorded-at YYYY-MM-DD` are optional.

## Behaviour

- **Bump** (tree identity equals the base's vN): refuses unless HEAD contains the
  base, the governance files listed above are unchanged from the base, and some
  registered source or configuration actually changed (override the last check
  with `--allow-unchanged`). Then it performs the table above.
- **Refresh** (tree is already at vN+1 with its ledger record and fixture): only
  digests are recomputed. Running the tool twice changes nothing the second
  time; after further source edits it moves only the digests.
- **Verify:** afterwards it runs the eight governance test files
  (ledger, plan, attestation, impact, SDK, oracle, sampling, goldens) and the
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
