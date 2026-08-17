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
| W4 | Transparency — surface `ModelAssumptionRegistry`, catalog inventory | in progress |
| W5 | Features — diagnostics i18n, post-hoc "why" view | not started |

Verification at last checkpoint: `flutter analyze` clean, `flutter test` 797
passing, `npm run verify:all` → all 10 gates pass.

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
- `tool/run_verify_all.mjs` + `npm run verify:all` — runs all 9 governance
  gates plus the golden check, composes `build/verify_all/latest.{json,md}`,
  exits non-zero on any blocker. `-- --list` prints the inventory.
- CI `governance-gates` job collapsed from ~10 steps to `npm run verify:all`
  plus a report upload, so CI and local verification cannot drift apart.
- The drift claim in `recommendation_replay_models.dart` now names the real
  committed baseline.

Injection-verified: a 1 g protein change in one scenario surfaced as
`interaction_score: 0.100 → 0.101` with the exact line; `verify:all` exits 1
when any gate fails and 0 otherwise.

## W3 — Truth fidelity (in progress)

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
next step after W5.

## W4 — Transparency (not started)

1. `lib/features/shared/mechanistic_trace_view.dart:212,255,320` renders bare
   `sourceId` strings. Resolve each through `ModelAssumptionRegistry.byId()`
   and render title + `limitation`. The registry holds 17 assumptions with
   citations and plain-text limitations and currently has **zero** references
   in `lib/features/` or `tool/` — this is the highest-leverage missing link.
2. New `lib/domain/usecases/catalog_inventory_diagnostics.dart`, following the
   shared-computation precedent of `explanation_copy_diagnostics.dart` so the
   CLI and the in-app view cannot report different numbers. Roll up by source
   family, jurisdiction, license, `sourceStatus`, and `SourceAuthorityTier`.
3. Surface it as a diagnostics card (`_Check` #4 is already an inventory-only
   precedent) using the `analytics_page.dart:435` monospace `SelectableText`
   pattern, plus a `tool/run_catalog_inventory.dart` + `.mjs` twin writing
   `build/catalog_inventory/latest.{json,md}`. Sanitize free text through the
   `evidence_graph_mermaid_renderer.dart:44` pattern before it enters a
   Markdown table cell.
4. `_CatalogShowcaseCard` (`catalog_page.dart:168`) shows the **search-result**
   count under a "Foods indexed" intent. Render `N of M shipped`.

## W5 — Features (not started)

1. `diagnostics.*` i18n keys exist only in the inline `zh/en/fr/ja` maps;
   `app_i18n_full_translations.dart` has zero coverage, so the 9 newer language
   families fall back to English. Add them, keeping safety meaning identical
   per `CLAUDE.md`.
2. Post-hoc "why" view: `MechanisticConflictTraceCard` is live-only. Use the W1
   read-back to render a past decision's trace read-only from the diagnostics
   page. This surfaces already-compiled educational copy; it introduces no new
   clinical surface.

---

## Explicitly out of scope

~22 Node `tool/*.mjs` operator scripts embed `new Date().toISOString()` and
derive output filenames from it, so they produce no diffable `latest.*`. Making
that tier deterministic is a large change to Firebase operator tooling that
reviewers of the offline showcase never run.

## Constraints carried through all five

- No clinical claims, diagnosis, treatment, dosing, timing, or dietary guidance.
- Preferred wording: "not calibrated for real care", "educational prototype",
  "synthetic/demo data only". Avoid "clinically validated",
  "clinically calibrated", "safe for you", "recommended timing".
- No scoring or engine-behaviour change.
- Every new check must be **injection-verified**: prove it fails on a real
  defect before trusting that it passes. Two of this effort's most valuable
  findings came from distrusting green signals.

## Verify

```bash
flutter analyze
flutter test
npm run verify:all
```
