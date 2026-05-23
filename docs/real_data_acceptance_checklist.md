# Real Official Data Acceptance Checklist

Automated tests are not enough for production_candidate acceptance. This
checklist is for the operator pass that uses the intended real official-source
data.

## Acceptance Record

- Release candidate: `p0_stage_curated_seed_20260522`
- Date: 2026-05-22
- Operator: `zhouzhenghang`
- Reviewer: pending clinical/domain reviewer
- Backend: Firebase stage
- Firebase project/database: `parkinsum-companion-stage` / `(default)`
- Source family: `P0_OFFICIAL_SEED`
- Import run id: `ingest_firebase_seed_p0_core_v1`
- Snapshot id: `firebase_seed_p0_core_v1`
- Parent snapshot id: none recorded
- Artifact storage location:
  `build/acceptance_reports/p0_stage_real_data_acceptance_20260522.md`,
  `build/firebase_seed/stage_official_core_seed.json`

P0 stage acceptance summary:

- seed sha256:
  `70f5fc58fe8e05bba574ddd9d79ed70b2a4b33210b9d8b416eaff019eda54f95`
- documents: 504
- stage upload: 504/504 committed
- readiness blockers: 0
- readiness warnings: 2
- review tickets: 0
- publish guard: can proceed to reviewer acceptance
- remaining reviewer blocker: clinical/domain sign-off
- remaining public-release blocker: privacy/support contact

## 1. Import Evidence

- [ ] Official source URL or file location recorded.
- [ ] Source organization recorded.
- [ ] Jurisdiction recorded.
- [ ] Source publication/effective date recorded when available.
- [ ] License or reuse note recorded.
- [ ] Checksum or durable file reference recorded when available.
- [ ] Importer version or commit/reference recorded.
- [ ] Import log reviewed.
- [ ] Failed rows reviewed.
- [ ] Retry/resume status reviewed.

## 2. Provenance and Conservative Parsing

- [ ] `source_document` rows exist for imported evidence.
- [ ] Promoted facts reference source documents.
- [ ] Orphan facts are absent or recorded as blockers.
- [ ] Raw/free-text official fields remain raw/audit data unless promoted by
      an explicit schema decision.
- [ ] DailyMed package descriptions did not produce fabricated quantity,
      dimension, or unit fields.
- [ ] Parser limitations are captured in audit/readiness output.
- [ ] Confidence or limitation reasons are readable to an operator.

## 3. Readiness Drill

Run the production_candidate readiness drill for the snapshot and record:

- Blocking count:
- Warning count:
- Sample blocking ids:
- Sample warning ids:
- Review ticket count:
- Open high-severity ticket count:
- Artifact durability:
- Rollback target:
- Publish guard status:
- Override reason, if any:

Acceptance checks:

- [ ] No unresolved conflicts remain unless explicitly accepted and recorded.
- [ ] No invalid active rule_registry rows remain.
- [ ] No missing crosswalk for active variants remains unless accepted and
      recorded.
- [ ] No failed imports remain for the target snapshot.
- [ ] Required release artifacts are present.
- [ ] Backend capability warnings are visible.
- [ ] Artifact durability warnings are visible when applicable.

## 4. Review Ticket Decisions

For every high-severity ticket:

- Ticket id:
- Decision: resolved / ignored / blocker retained
- Reviewer:
- Reason:
- Timestamp:
- Evidence link or note:

Release may proceed only if high-severity tickets are resolved or ignored with
explicit rationale, or if a documented override is accepted.

## 5. Recommendation Spot Checks

Spot-check representative meal/medication cases:

- [ ] Levodopa/protein timing case.
- [ ] MAOI/tyramine caution case.
- [ ] Mineral/dairy timing case.
- [ ] Low-risk or no-conflict case.
- [ ] Missing food data case.
- [ ] Missing medication variant/crosswalk case.
- [ ] Localized copy in the intended release language.

For each spot check, record:

- Inputs:
- Output severity/risk:
- Recommendation text:
- Evidence/source references:
- Rule trace:
- Any warning or fallback:
- Reviewer decision:

Acceptance criteria:

- Recommendation copy is fluent and fully rendered.
- No placeholders or template tokens are visible.
- Reasons are clinically readable and not contradictory.
- Missing evidence produces cautious language.
- The user can inspect the basis for the recommendation.

## 6. Firebase Account Isolation

Use two real test accounts.

- User A uid:
- User B uid:

Checks:

- [ ] User A can read/write only user A private data.
- [ ] User B can read/write only user B private data.
- [ ] User B cannot read user A clinical audits or private records.
- [ ] Unauthenticated private writes fail.
- [ ] Shared catalog reads require sign-in.
- [ ] Shared catalog writes require admin/importer claims.
- [ ] Top-level `cdss_tables` access is denied.

## 7. Rollback and Diff

- [ ] `version_diff.json` reviewed.
- [ ] Added records reviewed.
- [ ] Changed records reviewed.
- [ ] Retired records reviewed.
- [ ] Rollback target recorded.
- [ ] Restored counts reviewed.
- [ ] Retired count reviewed.
- [ ] Active count after rollback reviewed.
- [ ] Operator confirms rollback summary matches intended release behavior.

## Final Decision

Choose one:

- [ ] Hold release.
- [ ] Publish production_candidate.
- [ ] Publish with documented override.

Final notes:

- Decision owner:
- Decision time:
- Accepted risks:
- Required post-release follow-up:
