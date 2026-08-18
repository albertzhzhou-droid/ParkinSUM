# WIP — Evidence-Chain Hardening (handoff)

Working notes for the in-flight branch. Delete this file when all five
workstreams have landed.

**Goal:** every claim the project makes about its own evidence is either
mechanically enforced or removed. Five workstreams, auditability first.

Educational prototype only; synthetic/demo data only; not calibrated for real
care. No engine, scoring, severity, or rule-outcome behaviour is changed by any
of this work — the additions are read-only derivations and checks.

---

## Status

| # | Workstream | State |
| --- | --- | --- |
| W1 | Auditability — bridge the two explanation schemas | **done** |
| W2 | Repeatability — committed goldens + `npm run verify:all` | **done** |
| W3 | Truth fidelity — docs↔runtime ratchet, clock rename, ref coverage | **done** |
| W4 | Transparency — surface `ModelAssumptionRegistry`, catalog inventory | **done** |
| W5 | Features — diagnostics i18n, post-hoc "why" view | **done** |

Verification at last checkpoint: `flutter analyze` clean, `flutter test` 874
passing, `npm run verify:all` → all 11 gates pass.

---

## W1 — Auditability (done)

The repo carried two explanation schemas that never met. `RuleExplanation` is
the documented, safety-linted audit contract and was **never constructed
anywhere in `lib/`**; `RuntimeAuditEntry` is what the engine actually emits and
was **never read back**. Separately, `InMemoryCdssDatabase` — the backend the
public demo and replay tooling run on — had empty `async {}` audit inserts, so
its audit trail was silently discarded.

Landed:

- `lib/domain/usecases/rule_explanation_projection.dart` — pure, read-only
  projection from `RuntimeAuditEntry` + `_ruleHitTrace` rows into
  `RuleExplanation`. One row **per registry rule**, including rules that did
  not fire (the case an auditor most needs). Re-evaluates nothing.
- `EngineRunOutput.ruleExplanationsJson` carries it; the CDSS service writes
  `rule_explanations.json` into the artifact set.
- `CdssArtifactStore.readArtifactSet(id)` — the missing read side. Returns
  `null` for absent, never a fabricated empty success. Implemented on both
  backends; the inline (web) store now retains content in memory and reports
  `durable: false` honestly.
- `InMemoryCdssDatabase` retains audit records and exposes `conflictAuditLog` /
  `recommendationAuditLog`.
- `test/audit_round_trip_test.dart` (8 tests).

Injection-verified: reverting the audit insert to a no-op and filtering the
projection to fired-only both fail the suite with pointed messages.

## W2 — Repeatability (done)

Every prior determinism guard built an artifact **twice in the same process**
and compared the copies — self-consistency, not cross-commit stability. And
`build/` is gitignored, so the reviewer artifact's own instruction to "diff
against the committed report" named a baseline that did not exist.

Landed:

- `test/goldens/` — committed expected output (~92 KB total).
- `test/helpers/golden_artifact.dart` — `expectGolden` (missing golden **fails**,
  never auto-creates), first-differing-line reporting, and `digestTable` /
  `fnv1aHex` for artifacts too large to commit whole (the mechanistic replay
  JSON is ~900 KB, so it is goldened as a per-scenario digest instead).
- `test/goldens_test.dart` — 6 golden groups. Refresh with
  `UPDATE_GOLDENS=1 flutter test test/goldens_test.dart`, then **read the diff**.
- `tool/run_verify_all.mjs` + `npm run verify:all` — runs all 10 governance
  gates plus the golden check, composes `build/verify_all/latest.{json,md}`,
  exits non-zero on any blocker. `-- --list` prints the inventory.
- CI `governance-gates` job collapsed from ~10 steps to `npm run verify:all`
  plus a report upload, so CI and local verification cannot drift apart.
- The drift claim in `recommendation_replay_models.dart` now names the real
  committed baseline.

Injection-verified: a 1 g protein change in one scenario surfaced as
`interaction_score: 0.100 → 0.101` with the exact line; `verify:all` exits 1
when any gate fails and 0 otherwise.

## W3 — Truth fidelity (done)

**Correction to earlier notes:** an earlier pass reported that the docs promise
`41/41` scenarios while the code ships 42. That was wrong — the count of 42 came
from a grep that also matched the `MechanisticReplayScenario` **constructor
declaration**. There are exactly 41 registered scenarios and the documentation
is accurate. No defect existed; the ratchet below is still worth having because
nothing machine-checked the relationship.

Landed:

- `test/docs_runtime_consistency_test.dart` — parses the promised numbers back
  out of `docs/PUBLIC_VERIFICATION.md` and compares them to live runtime values
  (scenario count, replay pass count, source-quality row count, `verify:all`
  gate count, registry non-emptiness + per-assumption citation/limitation
  presence). Injection-verified: adding a 42nd scenario fails with
  "says the suite holds 41 scenarios, but mechanisticReplayScenarios holds 42".
- `docs/PUBLIC_VERIFICATION.md` — new "One command" section documenting
  `verify:all` and the golden refresh protocol.

Also landed:

- **The fabricated clock is no longer labelled as one.**
  `mechanistic_replay_runner.dart` serialized the fixed constant
  `DateTime.utc(2026,1,1,8)` under `generated_at` and rendered it as
  `Generated: <iso>` — reproducible, but showing a reader a timestamp that was
  never true. The Markdown now reads "Deterministic reference instant: … (fixed
  anchor, not the time this report was produced)", and the JSON adds
  `deterministic_reference_time` + `generated_at_is_deterministic_reference`.
  `generated_at` is **kept** because `SourceVersionDriftChecker` requires a
  valid ISO-8601 value under that key.
- **`test/source_ref_coverage_test.dart`** (5 tests) — see the finding below.

### Open finding: 11 claim-bearing copy surfaces have no provenance

`kClaimBearingCopyOutputTypes` classifies copy that asserts something about a
food, drug, or modeled interaction (`informational`, `mechanistic_explanation`)
versus pure disclaimers (`boundary`, `policy`). 11 of 25 templates are
claim-bearing legacy findings rendered by
`lib/core/analysis/interaction_engine.dart` — a hardcoded-threshold heuristic
with **no source refs in scope at all**. They have no provenance to declare.

Setting `requiresSourceRefs: true` on them was tried and **reverted**: the
compiler correctly blocks, `ExplanationCopyService.resolveForLocale` (default
`CopyCompileContext()`, no refs) then falls back, and the net effect is to
silently switch those surfaces back to pre-migration copy. That is a fix in
appearance only, so it was not kept.

Instead the gap is pinned: `knownUnsourcedClaimTemplates` in
`test/source_ref_coverage_test.dart` lists all 11 and the test fails in **both**
directions — if a new unsourced claim surface appears, or if one gains
provenance and the list is not updated.

**Closing it for real** means giving the legacy interaction engine source
references, which is engine work rather than a flag flip. That is the natural
next step now that W1-W5 have landed.

## W4 — Transparency (done)

- **Source refs resolve to citations.** `mechanistic_trace_view.dart` renders
  each ref through `ModelAssumptionRegistry.byId()` as title + `limitation`.
  Unresolvable ids are shown as themselves with an "unresolved reference"
  marker — a broken provenance link is information, and hiding it would look
  identical to having no link.
- **`catalog_inventory_diagnostics.dart`** — the aggregate that never existed:
  20 foods, 21 medications, 43 source documents, 10 rules, 25 templates, 41
  scenarios and the current assumption registry, with roll-ups by source family, jurisdiction,
  licence, and status, plus two named gaps (6 documents declared but not live;
  catalog entries still on placeholder external codes). Shared by the new
  `npm run catalog:inventory` CLI and a diagnostics card, so the two cannot
  disagree. Goldened.
- **The mislabeled count is fixed.** `_CatalogShowcaseCard` showed the current
  *search-result* count under a "Foods indexed" label; it now reads
  `N of M shipped`.

That report caught a bug in its own first draft: an allowlist of
`{active, active_reference}` classified all 22 `active_evidence` documents as
stale and reported 28 of 43 non-live when the true figure is 6. Statuses are now
classified in both directions and `catalog_inventory_test.dart` fails on any
unclassified value.

## W5 — Features (done)

- **`diagnostics.*` localized for all 13 families.** The nine newer families had
  zero coverage and silently fell back to English. `scope_body` is the
  safety-critical string, so `diagnostics_i18n_coverage_test.dart` asserts the
  substantive framing per locale and that the `{ms}` placeholder survived, not
  merely that a key exists. Injection-verified.
- **`RuleAuditTrailPage`** — the post-hoc "why" view, reachable from the
  diagnostics app bar. Renders the W1 projection: every registry rule with its
  outcome, inputs used, inputs missing, and provenance, plus the count of audit
  records the run persisted (non-zero only because W1 stopped discarding them).
  Its loader is injectable: the real evaluation awaits artifact-store I/O that
  never resolves in `testWidgets`' fake-async zone, so the test computes genuine
  engine output under `runAsync` and injects it.

## Explicitly out of scope

~22 Node `tool/*.mjs` operator scripts embed `new Date().toISOString()` and
derive output filenames from it, so they produce no diffable `latest.*`. Making
that tier deterministic is a large change to Firebase operator tooling that
reviewers of the offline showcase never run.

## Constraints carried through all five

- No clinical claims, diagnosis, treatment, dosing, timing, or dietary guidance.
- Preferred wording: "not calibrated for real care", "educational prototype",
  "synthetic/demo data only". The forbidden vocabulary is enumerated in
  `CLAUDE.md` and in `bannedExplanationSubstrings`
  (`lib/domain/entities/rule_explanation.dart`) — deliberately not restated here,
  because `public:preflight` scans docs by substring and a doc that quotes the
  banned phrases in order to forbid them trips its own gate. Those two lists are
  the authority; this file defers to them.
- No scoring or engine-behaviour change.
- Every new check must be **injection-verified**: prove it fails on a real
  defect before trusting that it passes. Two of this effort's most valuable
  findings came from distrusting green signals.

## Reviewer artifact

A shareable page telling this evidence story end to end — the four breaks, what
enforces each now, the two errors this work made, and the one-command
verification path:

<https://claude.ai/code/artifact/e6f60a38-60c5-4069-b1f1-2034cb243c5e>

It is private until shared from the page's own share menu.

## Verify

```bash
flutter analyze
flutter test
npm run verify:all
```
