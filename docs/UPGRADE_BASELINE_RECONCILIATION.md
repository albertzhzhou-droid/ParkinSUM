# Upgrade baseline reconciliation — 2026-09-29

This is a read-only GitHub reconciliation and a local implementation record. No PR was merged, issue closed, commit created, or branch pushed. The active checkout began with an edited `docs/README.md` and an untracked `docs/NEXT_UPGRADE_PLAN.md`; concurrent authorized upgrade work is not classified as technical debt.

## Distinct baselines

| Scope | Verified identity / result |
| --- | --- |
| Protected public `main` | `197519a297e6d5883dbf75dd3b0d9d55b978cfbc`; [CI success](https://github.com/albertzhzhou-droid/ParkinSUM/actions/runs/36591059932), [public preflight success](https://github.com/albertzhzhou-droid/ParkinSUM/actions/runs/36591059942) |
| Local committed HEAD | `b07c55a952a58f47f1a34835ecd07b712ddad792` |
| Active working copy | Uncommitted upgrade implementation, including importer, algorithm, meal journey and Web restore slices. It is not the public release. |
| [PR #136](https://github.com/albertzhzhou-droid/ParkinSUM/pull/136) | Open, head `f6e1a9813464cbcd9ace3838a6c283150b688a05`. Only two undici lock entries change. Its [CI run](https://github.com/albertzhzhou-droid/ParkinSUM/actions/runs/36644385108) fails the existing store-privacy lock identity check; preflight succeeds. Local repair does not change this remote result. |
| Direct-edge report | Local generated/ignored snapshot, schema 15, 65 registered roots resolved. Compatibility can pass; complete direct-edge closure still remains held. Concurrent edits require final regeneration before using its digest as release evidence. |

The probe no longer assumes 63 roots. It reconciles the expected manifest/registry identity tuples and refuses missing, duplicated, unexpected, or swapped algorithm IDs, logical root IDs and package URIs. A count alone cannot establish inventory identity. Negative cases cover additions/removals and duplicates as well as the current 65-root registry.

Final local generated snapshot after source freeze: direct-edge schema 15 resolves **65/65 roots and 477/477 lib units**, inventory reconciled, report digest `7a79d1f9757a2e2e1c069b8208ca99464dac154de46541328a68b242005b7e11`. The compatibility report passes 65/65 with digest `e2d21a9c3425c21557ddfd81b1ee4c851f7a53146f023d8143f0145d8bd4e9ff`. The reviewed trace manifest matches **14 production synthetic traces / 51 static contracts**, canonical manifest digest `67f9daf11863429788919f072954debbd71e60ab514e1b96aa07a0afa7168a40`. These artifacts remain local ignored outputs; complete closure is held. Schema catalog validation passes 169 required surfaces. Final integration passed 2,542 Flutter tests, static analysis, all 55 composed gates, six Chrome configuration-identity tests, and public preflight with zero blockers (25 warnings remain). Browser/build evidence is recorded separately in the canonical timeline and local delivery index.

## Dependency batches

The local patch updates seven development lock entries: undici `8.11.2` / `6.29.0`, hono `4.13.11`, fast-uri `3.1.8`, ip-address `10.7.2`, js-yaml `4.3.2`, and morgan `1.12.1`. The `package-lock.json` identity in `config/store_privacy_contract.json` is refreshed to `13f800e034ba75dcb421a9d932c80189f99f5493da58a14b82fcbc11cc084e97`. Application dependency declarations do not change.

- Runtime npm audit (`--omit=dev --audit-level=high`): **0 vulnerabilities**.
- Full lock audit after this batch: **10 moderate, 0 high, 0 critical**. This is not an all-dependencies-clean claim.
- Remaining chains need separate compatibility work: csv-parse `<7.0.2` via UCUM/CQL, stream-json via Firebase tooling, OpenTelemetry core via Google Cloud Pub/Sub, and qs pinned by parent tooling. Do not apply npm's suggested CQL downgrade as a security fix.
- Local store-privacy contract validation and 25 preflight/contract Node tests passed. Node 26 emitted a superstatic engine warning; CI uses Node 22.

Ten dependency PRs remain open. [#136](https://github.com/albertzhzhou-droid/ParkinSUM/pull/136), [#132](https://github.com/albertzhzhou-droid/ParkinSUM/pull/132), [#131](https://github.com/albertzhzhou-droid/ParkinSUM/pull/131), [#130](https://github.com/albertzhzhou-droid/ParkinSUM/pull/130), [#129](https://github.com/albertzhzhou-droid/ParkinSUM/pull/129) and [#126](https://github.com/albertzhzhou-droid/ParkinSUM/pull/126) match the bounded local security batch. [#134](https://github.com/albertzhzhou-droid/ParkinSUM/pull/134) updates Dart tools including analyzer and requires tool compatibility checks. [#118](https://github.com/albertzhzhou-droid/ParkinSUM/pull/118) updates Firebase tooling and must be audited as a separate batch. [#120](https://github.com/albertzhzhou-droid/ParkinSUM/pull/120) and [#119](https://github.com/albertzhzhou-droid/ParkinSUM/pull/119) are setup-java / secure-storage major-version changes and remain separate migrations.

At inspection, GitHub exposed 15 open development-dependency advisories (7 high, 8 medium). Remote advisory status has not been changed by the uncommitted local fix.

## Open issue triage

Classification is based on each issue's actual request and inspected source/tests, not its title alone. “Covered locally” does not mean a maintainer has accepted or closed the issue.

| Issue | Disposition / remaining work |
| --- | --- |
| [#2](https://github.com/albertzhzhou-droid/ParkinSUM/issues/2), alt text | Partial: general guidance and actual image alt text exist; requested dashboard/meal/context/conflict examples remain to be made explicit. |
| [#3](https://github.com/albertzhzhou-droid/ParkinSUM/issues/3), educator prompts | Pending: no dedicated educator/mentor discussion section found. |
| [#4](https://github.com/albertzhzhou-droid/ParkinSUM/issues/4), internal links | Pending: public preflight does not implement a complete offline Markdown/HTML link checker. |
| [#5](https://github.com/albertzhzhou-droid/ParkinSUM/issues/5), synthetic onboarding | Covered locally by field walkthrough and synthetic scenario documentation; no patient data validation claim. |
| [#6](https://github.com/albertzhzhou-droid/ParkinSUM/issues/6), showcase contrast | Partial: keyboard/narrow-screen review guidance exists; measured contrast note remains. |
| [#7](https://github.com/albertzhzhou-droid/ParkinSUM/issues/7), safety negative cases | Covered locally: public preflight tests distinguish explicit negation from affirmative unsafe claims. |
| [#9](https://github.com/albertzhzhou-droid/ParkinSUM/issues/9), contribution routing | Partial: backlog links exist; issue-category chooser/example is still useful. |
| [#10](https://github.com/albertzhzhou-droid/ParkinSUM/issues/10), localized safety review | Partial: en/zh/fr/ja lint exists; it explicitly does not establish translation quality or replace human review. |
| [#11](https://github.com/albertzhzhou-droid/ParkinSUM/issues/11), synthetic replay | Covered locally by scenario/replay tests and deterministic golden documentation. |
| [#12](https://github.com/albertzhzhou-droid/ParkinSUM/issues/12), contributor command outcomes | Covered locally by command/CI split, expected outcomes and permission-failure guidance. |
| [#13](https://github.com/albertzhzhou-droid/ParkinSUM/issues/13), capture checklist | Covered locally by media/demo checklist for the requested screens. Actual new video capture/publication is separate work. |

The resulting channels are: bounded npm security patch; Dart/Firebase compatibility batches; explicit major migrations; and documentation/accessibility gaps. Protected-main success, current local test results, and generated research reports remain separate evidence scopes.
