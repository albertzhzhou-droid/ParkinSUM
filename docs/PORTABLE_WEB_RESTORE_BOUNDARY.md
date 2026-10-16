# Same-owner Web restore boundary

The portable package remains schema v4. The production capability is a **same-owner merge** into the Web database aggregate. Current participating same-origin Web writers coordinate with exclusive Web Locks throughout reread, validation and publication. It restores only exported profile preferences, medication selections, intakes, and meals that can be re-exported without changing any file content. It is not a complete application backup or a cross-device/account recovery claim. The initial single-window evidence below is historical; the new bounded cross-tab protocol and actual counterexamples are recorded in [W11 research](WEB_ORIGIN_STORAGE_COORDINATION_RESEARCH_2026-10-01.md).

The page states these limits before export and restore. v4 does not contain care discussions, follow-up outcomes, self-checks, drafts, or replay/currency receipts. Packages with nonempty personal observations or reminders are held because those records are owned by other stores. Notification permission, reminder activation tokens and AI consent are never imported. Current-device consent receipts/grants/endpoints remain authoritative; source preferences that cannot round-trip under them are held.

## Implementation

`UserPortableDataPackageService.prepareLocalRestore` first runs the existing strict v4 verifier: unknown versions/fields, duplicate IDs, owner mismatch and conflicts do not write. It constructs storage-compatible records and then re-exports with the original timestamp and current reference catalogues. All eight file payloads must be canonically identical to the source. Literal zero doses normalized by legacy storage readers, stale catalogue provenance, unavailable evidence, and other lossy projections stay held. The original package bytes remain in a private local receipt, so evidence is not silently discarded.

Captured meal nutrient missingness takes precedence over later catalogue availability. A captured unknown remains null/`source_missing_not_zero` even when its catalogue row disappears or subsequently becomes known; catalogue provenance remains a reference snapshot. Legacy snapshots without either a captured marker or catalogue information remain explicitly unavailable. The compatibility numeric value does not become an assertion that an unknown value equals zero.

`PortableDataRestoreCoordinator` binds the prepared request to raw local owner, package bytes and a digest of the entire Web user-state aggregate. The page additionally binds the current opaque owner capability/revision, auth-session generation and full loaded record content, histories, catalogue revisions and reminder content. A same-ID edit invalidates the preview. Logout and a fresh bootstrap revoke old inspection/confirmation tasks even when the UID is unchanged and no widget frame occurred between them. The confirm dialog is an explicit final step; a ready dry-run is not permission to write.

`WebAppDatabase` publishes the merge and receipt as one `db.user_state.v1` value, with internal envelope schema 3 (readers retain support for schemas 1 and 2). It serializes in-process writers and compares the current digest immediately before publication. Existing records and immutable recoverable history are preserved. IDs appearing only in tombstone history also conflict; existing IDs are never overwritten. No sequential multi-store fallback is offered on native/Firebase backends.

After publication, exact persisted bytes are read back. A thrown or false acknowledgment with exact persisted bytes is treated as a committed operation. A retry with the same operation ID and unchanged after-state returns the existing receipt, including after re-instantiating the store. A true rejected write leaves the old value intact. The receipt includes the complete prior aggregate, before/after digests and original source package. Only the last receipt is retained. Exact-state undo is available to the same owner on re-entering the page; later edits hold undo instead of overwriting them. Logs report only operation stage, never package/profile/owner contents.

## Validation and remaining work

Synthetic store tests cover canonical file round-trip, captured missingness without a catalogue row and with a later-known row, immutable history preservation, duplicates, full-content stale requests, changed confirmation/bytes/owner, future version/unknown fields, cross-store holds, catalogue drift, lossy zero dose, failure before publication, lost acknowledgment/restart/idempotent retry, owner-gated receipt discovery and exact-state rollback. A widget test exercises cancel, explicit confirmation, state refresh and undo through the actual Web capability. Existing package/page/history regressions remain part of the targeted check.

At initial slice completion, the four package/restore/page/history test files passed **68 tests** and analysis of the eight changed source/test items reported no issues. The subsequent auth-session fix passed all **17 page tests**, including same-UID logout/bootstrap with no intervening frame during inspection and during the confirmation dialog, and analysis of the two affected files reported no issues. The widget flow also destroys the page, re-instantiates the Web store, re-enters the page and undoes through the persisted receipt. These results are local automated evidence, separate from the public branch's CI and the repository-wide integration suite.

These are automated fault-injection and widget results; multi-tab/process browser concurrency, actual device storage quota/termination, and native restore are not established by them. `SharedPreferences` Web uses one browser storage value here; atomic replacement within one process is the bounded guarantee. Storage failure is surfaced and never triggers a sequence of partial writes.

A full v4 restore requires a coordinated transaction/journal across the user aggregate, observation repository and reminder repository, with stable owner leases, exact source evidence/missingness preservation, crash recovery, idempotent operation receipts and explicit target-device activation consent. The current slice intentionally refuses those external stores. Adding care records/drafts/replay receipts to export needs an explicit new compatibility/schema design rather than relabeling v4 as complete.


## Real browser storage verification — 2026-09-30 (W08)

The release `tool/portable_restore_persistence_probe.dart` used production
`WebAppDatabase` and `PortableDataRestoreCoordinator` with actual browser
SharedPreferences at a fresh task-owned `http://127.0.0.1:8938/` origin.
No mock preferences or process-memory event store was used. Only fixed synthetic
data was written. Foreign storage is refused before the harness operates.

Observed passes: unconfirmed restore leaves the exact before-state digest;
real publication followed by an injected lost acknowledgment is recognized by
exact readback; closing and reopening the tab retains two meals, captured
unknown protein, one immutable history and the owner-bound receipt; all eight
file payloads round-trip canonically with occurrence and recorded times preserved;
wrong-owner receipt access is withheld; persisted exact-state undo returns one
meal, one history, no current receipt and the original digest.

The ignored evidence receipt is `build/mega_upgrade/w08_browser_probe.json`,
binding the declared source inventory, compiled JavaScript and three inspected
screenshots. This is tab lifecycle and a software acknowledgment fault, not an
OS/browser-process crash, quota failure, multi-tab, mobile, Firebase or clinical
validation. Formal `lib/main.dart` QA is separately required by W31.
