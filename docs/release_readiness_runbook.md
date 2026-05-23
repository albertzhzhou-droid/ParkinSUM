# ParkinSUM CDSS Release Readiness Runbook

This runbook covers the production_candidate readiness drill and the final
operator checks before publishing a CDSS snapshot.

## Companion launch documents

- `docs/production_release_checklist.md`: end-to-end production release
  sign-off checklist.
- `docs/environment_deployment.md`: local/Firebase modes, Firestore deployment,
  seed upload, and hosting gap.
- `docs/release_management.md`: release tags, version records, release notes,
  and artifact retention.
- `docs/firebase_project_claims.md`: dev/stage/prod Firebase project separation
  and custom-claim process.
- `docs/firebase_operations_runbook.md`: production claims, rules tests,
  backup/export, audit logging, monitoring, and user data operations.
- `docs/firebase_production_acceptance_report.md`: latest local/static
  Firebase acceptance and browser smoke result.
- `docs/rollback_runbook.md`: app, Firestore rules, and knowledge snapshot
  rollback procedure.
- `docs/known_risks.md`: launch risk register.
- `docs/real_data_acceptance_checklist.md`: operator checklist for accepting a
  real official-source snapshot.
- `docs/real_data_acceptance_report_template.md`: fillable production_candidate
  official data acceptance report.
- `docs/privacy_disclaimer_draft.md`: draft privacy notice and medical
  disclaimer text for review.
- `docs/privacy_policy_draft.md`: draft privacy policy and user-data rights
  language for review.

## Verification commands

Run these from `flutter_application_1` before a production_candidate publish:

```sh
"/Users/zhouzhenghang/Applications/Flutter SDK/flutter/bin/flutter" analyze
"/Users/zhouzhenghang/Applications/Flutter SDK/flutter/bin/flutter" test test/knowledge_base_release_service_test.dart test/clinical_decision_support_service_test.dart test/runtime_rule_engine_test.dart test/database_backed_meal_check_usecase_test.dart test/p0_importers_test.dart
node tool/firestore_rules_contract_check.mjs
```

## Readiness drill

Use the release readiness drill to exercise the operator path without changing
the published state:

1. Run the production_candidate readiness check for the target snapshot.
2. Confirm blocking issues, warnings, review ticket counts, sample ticket ids,
   artifact durability, and rollback target.
3. Resolve or ignore open high-severity review tickets only after operator
   review.
4. Re-run the readiness drill and confirm the publish guard can proceed.
5. If an override is required, provide an override reason and confirm the
   distribution manifest records it under `publish_guard.override_reason`.
6. Confirm `version_diff.json` includes rollback summary data for the target
   snapshot.

## Final pre-release drill checklist

Record one operator note for each item before final production_candidate
approval:

- Real data import completed: source family, run id, snapshot id.
- Readiness status reviewed: blocking count, warning count, sample ids.
- Blocking tickets reviewed: ticket ids, decision, reviewer, timestamp.
- Tickets resolved or ignored: reason and resolved_at recorded.
- Publish guard checked: blocked or can proceed.
- Override, if used: exact override reason recorded in distribution manifest.
- Manifest checked: artifact paths, durability, release_readiness.json,
  version_diff.json, snapshot_manifest.json.
- Rollback summary checked: rollback target, restored counts, retired count,
  active count after rollback.
- Web backend warning checked: non-transactional/lightweight storage warning is
  visible when web fallback is used.

For importer smoke/audit verification, prefer:

```sh
"/Users/zhouzhenghang/Applications/Flutter SDK/flutter/bin/flutter" test test/p0_importers_test.dart --concurrency=1
```

The importer audit smoke should be repeatable. Do not remove audit assertions to
hide order-sensitive failures.

## Production blockers

The production_candidate profile blocks publish when any of these are present:

- unresolved conflicts
- invalid rule_registry rows
- missing crosswalk for active variants
- open high-severity human review tickets
- missing required release artifacts
- failed imports for the snapshot
- orphan resolved facts or missing source documents
- missing source documents, facts, or rule registry rows

## Warnings

Warnings do not block publish by themselves, but they must be visible in the
readiness report and operator UI:

- fallback region jurisdiction map
- non-transactional or lightweight web backend capability
- non-durable artifact fallback
- stale rule versions
- resumable imports
- legacy variant string fallback
- missing observations or label section coverage gaps

## Override policy

Use override only for an explicitly accepted temporary operating gap. The
override reason must be written to the distribution manifest. Do not use
override to bypass unknown clinical logic, fabricated identifiers, or missing
source provenance.

## Rollback

Rollback uses snapshot history and `version_diff.json`/rollback summary data.
Operators should verify:

- rollback target or parent snapshot
- restored fact, rule, and runtime counts
- retired record count
- active record count after rollback
- new distribution manifest and artifact durability status

## Conservative importer boundaries

The release gate intentionally does not expand importer parsing. These remain
conservative data-policy boundaries:

- Do not force-structure DPD, EMA, PMDA, FDC, or Ciqual raw/free-text fields.
- Do not add an FDC portion table without a separate schema decision.
- Do not parse DailyMed `package_description` into package dimensions,
  quantity, or unit fields.
- Uncertain official-source fields stay in source document raw payload,
  provenance, audit output, or readiness gaps instead of primary fact tables.
