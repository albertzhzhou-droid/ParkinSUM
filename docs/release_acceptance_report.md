# ParkinSUM CDSS Release Acceptance Report

Date: 2026-05-01, updated 2026-05-22

Scope: final production_candidate acceptance record for the CDSS release
readiness loop. This report records the automated checks that passed and the
remaining operator steps before a real production publish.

2026-05-22 P0 continuation: stage official curated seed acceptance and upload
now have a concrete record at
`build/acceptance_reports/p0_stage_real_data_acceptance_20260522.md`. The P0
completion summary is `docs/p0_completion_report_20260522.md`.

## Production candidate capability summary

The current CDSS production_candidate path supports:

- source_document and provenance based ingestion boundaries.
- staging/promote separation for imported knowledge records.
- concept_variant_crosswalk first resolution with legacy fallback warnings.
- database rule_registry loading, validation, runtime compilation, and fallback
  seed behavior when database rules are unavailable.
- RuntimeRuleEngine rule traces with matched, suppressed, missing field, source
  refs, same-band escalation, and provenance tie-break metadata.
- FactConflictEngine accepted/rejected rationale and conflict audit output.
- release readiness blockers and warnings for production_candidate checks.
- human_review_ticket persistence and status flow: open, resolved, ignored.
- publish guard with explicit override reason recorded in distribution manifest.
- release artifacts including release_readiness.json, conflict_rationale.json,
  rule_trace.json, version_diff.json, and snapshot_manifest.json.
- cdss_record_history backed version diff and rollback summary reporting.
- web backend capability warnings for lightweight or non-transactional storage.

## Completed release drill loop

The implemented release drill covers:

1. Run production_candidate readiness for a target snapshot.
2. Surface blocking issues, warnings, review ticket counts, sample ticket ids,
   artifact durability, and rollback target.
3. Block publish when high-severity review tickets are open.
4. Allow progression after operator marks tickets resolved or ignored.
5. Allow override publish only with a non-empty override reason.
6. Record override reason in the snapshot distribution manifest.
7. Include version_diff and rollback summary in release artifacts.
8. Report non-durable artifact fallback and web backend warnings.

## Readiness coverage

Blocking checks include:

- missing source documents, facts, or rule registry rows.
- invalid rule_registry rows.
- missing crosswalk for active variants.
- unresolved conflicts.
- open high-severity human review tickets.
- missing release artifacts.
- failed imports for the snapshot.
- orphan resolved facts or missing source document provenance.

Warnings include:

- non-durable artifact fallback.
- non-transactional or lightweight web backend storage.
- fallback region jurisdiction map.
- stale rule versions.
- resumable imports.
- legacy variant string fallback.
- missing observations or label section coverage gaps.

## Review ticket, override, manifest, and rollback support

Review tickets are created for readiness conditions that require operator
attention, including unresolved conflicts, invalid rules, and missing active
variant crosswalks. Resolved and ignored tickets no longer block the
production_candidate gate.

Publish guard behavior:

- Without override, blocking readiness issues create a failed distribution and
  prevent publish.
- With override, publish can proceed only when an explicit override reason is
  supplied.
- The override reason is stored in the distribution manifest under
  `publish_guard.override_reason`.

Rollback and comparison support:

- version_diff.json lists added, changed, retired, and active records.
- rollback summary records rollback target or parent, restored fact/rule/runtime
  counts, retired record count, and active count after rollback.

## Conservative importer boundaries

The release gate preserves the conservative data policy:

- DPD, EMA, PMDA, FDC, and Ciqual raw/free-text fields are not force-structured.
- FDC foodPortions remain audit/raw payload information; no FDC portion table is
  introduced.
- DailyMed `package_description` is not parsed into package dimensions,
  quantity, or unit fields.
- Uncertain or unverified official-source fields remain in source_document raw
  payload, provenance, audit output, or readiness gaps rather than primary fact
  tables.

## Web backend warning

The web backend remains a lightweight/non-transactional capability compared with
native SQLite. The production_candidate path does not hide this limitation:
readiness reports and operator UI must surface backend capability warnings when
web/localStorage/shared-preferences style storage or non-durable artifacts are
used.

## Automated validation completed

All final validation commands completed successfully.

```text
flutter analyze
Result: PASS. No issues found.

flutter test test/p0_importers_test.dart --concurrency=1
Result: PASS. All tests passed.

flutter test test/p0_importers_test.dart --concurrency=1
Result: PASS. All tests passed.

flutter test test/knowledge_base_release_service_test.dart
Result: PASS. All tests passed.

flutter test test/clinical_decision_support_service_test.dart test/runtime_rule_engine_test.dart test/database_backed_meal_check_usecase_test.dart
Result: PASS. All tests passed.
```

## Still required operator steps with real official data

Before a real production publish, an operator must:

1. Import the intended official-source data set and record source family, run id,
   snapshot id, and backend.
2. Run production_candidate readiness on the resulting snapshot.
3. Review all blocking issues, warnings, sample ids, review ticket summaries,
   artifact durability, and rollback target.
4. Resolve or ignore open high-severity review tickets with reviewer name,
   reason, and timestamp.
5. Confirm manifest artifacts exist and are durable for the chosen backend.
6. Confirm version_diff.json and rollback summary match the intended release.
7. Confirm web backend warnings are acknowledged if publishing through web
   fallback storage.
8. Use override only for an explicitly accepted temporary gap and record the
   exact override reason.

P0 stage status:

- Current curated official seed acceptance: completed for stage.
- Stage seed upload: completed, 504/504 documents.
- Stage post-upload rules/read probe: PASS.
- Reviewer sign-off: still pending.
- Prod official-data publish: not performed in this P0 pass.

## Accepted risks to record at release time

- Web backend storage is not transactionally equivalent to native SQLite; this
  is accepted only when the readiness warning is visible and acknowledged.
- Importer long-text and uncertain official-source fields intentionally remain
  conservative audit/raw payload data until a separate schema decision promotes
  them.
- Review tickets provide an auditable operator queue, but they are not a full
  multi-approver release management system.

## Acceptance status

Automated validation is complete. The project is ready to enter
production_candidate human acceptance using real official-source data, subject
to the operator steps and accepted-risk recording above.
