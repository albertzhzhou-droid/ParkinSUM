# Contribution Safety Router

Educational/research prototype. Synthetic/demo data only. **Not medical advice,
not clinically calibrated, and carries no clinical-validation claim.**

> **Deterministic repository-governance routing only.** It is **not** AI code
> review, **not** a medical or legal reviewer, does **not** judge clinical
> correctness, and does **not** replace human review. It helps contributors and
> reviewers avoid unsupported claims, PHI, secrets, and source-governance
> mistakes.

## 1. Purpose

`ContributionSafetyRouter` (P11) classifies a pull-request / working-tree diff
into review-risk categories from changed file paths, source references, and
safety-sensitive keywords, then emits a structured risk report, suggested
labels, and a recommended reviewer checklist with the commands to run. It routes
attention so harmless docs/test work is not over-gated while
mechanistic/importer/security/claim changes get the right scrutiny.

## 2. Safety boundary

The router adds no medical advice, no diagnosis, no dose/timing/diet guidance,
and no patient-care workflow. It introduces no patient/subject/encounter
semantics, uses no LLM, and makes no network call. It is deterministic and
advisory; a human still reviews and merges.

## 3. What it classifies

The pure router takes `ContributionChange` objects (path, change type, added
lines/content, source refs, flags); the CLI builds them from `git diff`. Each
change is mapped to one or more categories by path pattern, and its added
content is scanned for safety-sensitive keyword groups.

## 4. Risk categories

`docs_only`, `test_only`, `source_metadata`, `replay_scenario`,
`rule_explanation`, `mechanistic_model`, `importer`, `firebase_rules`,
`security_sensitive`, `localization_copy`, `evidence_artifact`,
`generated_output`, `release_governance`, `medical_claim_risk`,
`clinical_advice_risk`, `secret_risk`, `phi_risk`, `source_access_risk`,
`unknown`.

## 5. Severity model

Findings carry `info` / `warn` / `blocker`. Risk level aggregates to `low` /
`medium` / `high` / `blocker`:

- **low**: docs-only or test-only with safe content.
- **medium**: source metadata, localization, evidence/replay/release-governance,
  generated output, or any WARN finding (e.g. a source-access claim to confirm).
- **high**: importer, mechanistic-model, Firebase/security changes.
- **blocker**: a clinical-advice / medical-claim / secret / PHI keyword match on
  a non-allowlisted change.

A keyword match on an **allowlisted** detector/scanner/governance file (a file
that legitimately defines the patterns it detects) is downgraded to `info`, so
the router does not flag its own rules. `--strict` escalates WARN findings to
BLOCKER.

## 6. Suggested labels

`docs`, `tests`, `safety-review`, `source-metadata`, `replay`, `importer`,
`mechanistic-model`, `firebase-rules`, `security-sensitive`, `localization`,
`medical-claim-risk`, `secret-risk`, `phi-risk`, `needs-source-review`,
`needs-release-gates`. Labels are deterministic for a given set of categories.

## 7. Checklist generation

Each category contributes deterministic checklist items with the exact commands
to run, for example:

- **Docs**: confirm no unsupported medical/clinical claim → `npm run public:preflight`.
- **Mechanistic model**: confirm no clinical-calibration claim and that
  assumptions carry sourceRefs/limitations → `flutter test --concurrency=1`,
  `dart run tool/run_mechanistic_replay.dart`, `npm run scenario:fuzz`.
- **Importer**: confirm honest fixture/live/production status and no raw private
  export → `npm run source:access`, `npm run privacy:preflight`.
- **Localization**: keep copy non-prescriptive → `npm run localization:lint`.
- **Security/Firebase**: `npm run public:preflight`, `npm run privacy:preflight`,
  `node tool/firestore_rules_contract_check.mjs`.
- **Source metadata**: `npm run source:quality`, `npm run source:access`,
  `npm run source:drift`.
- **Evidence/release**: `npm run release:snapshot`, `npm run evidence:graph`,
  `npm run demo:walkthrough`.
- **Blocker categories**: remove secrets / PHI-like fixture data, and replace
  any clinical-advice or clinical-claim phrasing with scanner-safe boundary text.

A universal item always asks the reviewer to confirm no PHI, no real patient
data, no medical advice, and no clinical-calibration claim.

## 8. How to run

```sh
# classify the current working-tree diff vs HEAD (plus untracked files):
dart run tool/run_contribution_safety_router.dart       # or: npm run contribution:route
# classify a branch range:
dart run tool/run_contribution_safety_router.dart --base peripheral-algorithm-integration --head my-branch
# strict mode (WARN → BLOCKER):
dart run tool/run_contribution_safety_router.dart --strict
```

Exit code is `0` when there are zero BLOCKER findings, non-zero otherwise.

## 9. How to inspect the report

Reports are written under `build/contribution_safety_router/`: `latest.json`
(full categories / findings / checklist / labels) and `latest.md` (a reviewer
summary with the suggested checklist and commands).

## 10. How to interpret blockers

A blocker means a non-allowlisted change matched a clinical-advice, medical-claim,
secret, or PHI keyword group. Remove the secret/PHI, or replace the claim with
scanner-safe boundary text (e.g. "not clinically calibrated"). If the match is a
legitimate detector definition, it belongs in an allowlisted scanner file.

## 11. Relationship to the other gates

The router **routes to** the existing gates; it does not replace them:
`public:preflight`, `privacy:preflight`, the Firestore rules contract,
`source:access`, `source:drift`, `source:quality`, `localization:lint`,
`scenario:fuzz`, and the mechanistic replay. Those gates remain authoritative.

## 12. Limitations

- Deterministic path/keyword routing; not AI code review and not exhaustive.
- Does not judge clinical correctness or provide legal/compliance approval.
- Conservative keyword matching; allowlisted detector/scanner files are
  downgraded to avoid self-flagging.
- Advisory only — a human still reviews and merges.

## 13. Reviewer checklist

- [ ] The suggested labels and risk level match the actual change.
- [ ] Every BLOCKER finding is resolved (secret/PHI removed, claim made
      scanner-safe) or is a legitimate allowlisted detector definition.
- [ ] The change-type commands in the generated checklist were run.
- [ ] The report JSON is deterministic and emits no patient/subject/encounter
      keys.
