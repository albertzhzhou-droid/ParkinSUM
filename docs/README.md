# ParkinSUM Companion — Documentation

ParkinSUM is an educational production-architecture prototype that explores how
meals, especially protein, may interact with levodopa timing in Parkinson's
disease. Public demos and model checks use synthetic data; owner-entered local
records can contain sensitive information. The model is not clinically
calibrated, and the project makes no clinical-validation or patient-care claim.

## Start here

| Read this | To understand |
| --- | --- |
| [Project README](../README.md) | The Paper workspace, current update, local setup, and boundaries. |
| [Project showcase](site/index.html) / [Visual wiki](wiki/index.html) | The interface and a short reviewer route. |
| [Capability matrix](CAPABILITY_MATRIX.md) | What is implemented, fixture-tested, report-only, or future work. |
| [Evidence scope](EVIDENCE_SCOPE.md) | What screenshots, fixtures, checks, and releases do and do not establish. |
| [Public verification](PUBLIC_VERIFICATION.md) | Exact checks, prerequisites, failure meaning, and evidence scope. |
| [App evolution timeline](APP_EVOLUTION_TIMELINE.md) | Dated changes, actual verification results, limitations, and rollback scopes. |
| [Next upgrade plan and implementation status](NEXT_UPGRADE_PLAN.md) | Preserved 2026-09-29 planning snapshot with actual local M0–M3 implementation status and remaining evidence boundaries. |
| [Upgrade baseline reconciliation](UPGRADE_BASELINE_RECONCILIATION.md) | Separate public GitHub, committed local, working-copy and generated evidence; dependency and issue triage. |
| [Public demo boundary](PUBLIC_DEMO_BOUNDARY.md) | What may be shown or claimed in a public demonstration. |

## App and records

- [Architecture](ARCHITECTURE.md) — UI, state, data, rules, and explanation layers.
- [Manual validation](MANUAL_VALIDATION.md) — synthetic workflow walkthroughs.
- [Portable data packages](USER_OWNED_PORTABLE_DATA_PACKAGE_RESEARCH_2026-08-17.md) — current-snapshot export, integrity, sensitive-data scope, and limitations.
- [Same-owner Web restore](PORTABLE_WEB_RESTORE_BOUNDARY.md) — explicit scoped merge/undo, fault evidence and the stores excluded from restoration.
- [Owner-reported medication statements](FHIR_R4_OWNER_REPORTED_MEDICATION_STATEMENTS.md) — the distinction between a reported record and other medication assertions.
- [Timeline medication intake](FHIR_R4_TIMELINE_MEDICATION_INTAKE.md) — explicit intake representation and export boundaries.
- [Personal observations](FHIR_R4_PERSONAL_OBSERVATION_COLLECTION.md) — observation export scope and missingness.
- [Symptom and motor observations](FHIR_R4_SYMPTOM_MOTOR_OBSERVATIONS.md) — self-reported observations, without diagnostic interpretation.
- [Structured medication discussion](STRUCTURED_MEDICATION_DISCUSSION.md) — record-based discussion preparation and its limits.

## Algorithms and explanations

- [Rule engine](RULE_ENGINE.md) — medication-context gates and source-linked explanations.
- [Mechanistic model](CONFLICT_ENGINE_MODEL.md) — literature-informed educational assumptions and the `trace_only` decision boundary.
- [Observatory design](design/ADR_ALGORITHM_OBSERVATORY.md) — production-derived traces, static contracts, and visible limitations.
- [Synthetic rule test workbench](RULE_TEST_WORKBENCH.md) — disposable rule cases, expected/actual assertions, and pack comparison.
- [Replay runner](REPLAY_RUNNER.md) — fixed synthetic cases and reproducible reports.
- [Structural uncertainty](GASTRIC_STRUCTURAL_UNCERTAINTY_SHADOW_ENSEMBLE_RESEARCH_2026-08-27.md) — shadow-model comparisons and their scope.
- [Conflict algorithm research and upgrade](CONFLICT_ALGORITHM_RESEARCH_2026-09-29.md) — fact comparability, unknown values, oral-label scope, replay transport and offline evidence receipts.

## Evidence, provenance, and sources

- [Evidence demo guide](EVIDENCE_AND_TRACEABILITY_DEMO_GUIDE.md) — an end-to-end evidence walkthrough.
- [Evidence Trace Bundle](EVIDENCE_TRACE_BUNDLE.md) — the local artifact, explicitly distinct from a FHIR Bundle.
- [Importer metadata flow](IMPORTER_METADATA_FLOW.md) — source authority, jurisdiction, completeness, and missingness.
- [Importer and food/medication source details](IMPORTER_DATA_RESEARCH_2026-09-29.md) — FDC basis/portion/LOQ semantics and SPL document/ingredient evidence, with remaining research.
- [Source-quality perturbation report](SOURCE_QUALITY_PERTURBATION_REPORT.md) — effects of changing source metadata in synthetic cases.
- [Bibliography](../Bibliographies.md) — sources behind educational model assumptions.
- [Source access and licenses](SOURCE_ACCESS_AND_LICENSES.md) — access methods and unresolved reuse review.
- [Open-source influence firewall](OPEN_SOURCE_INFLUENCE_FIREWALL_RESEARCH_2026-08-18.md) — concept references, transferred artifacts, and separate asset holds.
- [Open-source release evidence](OPEN_SOURCE_RELEASE_EVIDENCE.md) — bounded dependency/artifact evidence.

## Standards experiments and research

- [CQL differentials](CQL_RULE_DIFFERENTIAL.md) — fixed-corpus development experiments and cross-runtime disagreements.
- [Biomedical standards scorecard](BIOMEDICAL_STANDARDS_CONFORMANCE_SCORECARD.md) — scoped implementation evidence and conformance gaps.
- [Biomedical traceability matrix](BIOMEDICAL_TRACEABILITY_MATRIX.md) — source-to-implementation-and-test links.
- [Opportunity map](BIOMEDICAL_ENGINEERING_OPPORTUNITY_MAP.md) / [Backlog](BIOMEDICAL_ENGINEERING_BACKLOG.md) — planned research and implementation work.
- [Peripheral algorithm plan](PERIPHERAL_ALGORITHM_UPGRADE_PLAN.md) — review-oriented quality, provenance, privacy, and release tooling.

Research documents can contain proposed work as well as implemented slices.
Read their boundaries and the capability matrix before describing a feature as
available. A passing synthetic test does not establish broad standards
conformance, real-world interoperability, or clinical correctness.

## Public media and releases

- [Screenshot provenance](assets/screenshots/README.md) — current and historical captures, review status, and retired media.
- [Media capture checklist](media-capture-checklist.md) — synthetic-state and full-image privacy review.
- [Web upgrade demo script](WEB_UPGRADE_DEMO_SCRIPT.md) — isolated, resettable synthetic meal journey and local build/evidence steps.
- [Upgrade delivery index generator](../tool/generate_upgrade_delivery_index.mjs) — hashes the working app-source inventory and caller-verified Web build; generated outputs are local evidence.
- [Changelog](../CHANGELOG.md) — development updates and versioned release history.
- [Public showcase readiness](../PUBLIC_SHOWCASE_READINESS.md) — public-repository gates.
- [Release evidence index](RELEASE_EVIDENCE_INDEX.md) / [Release checklist](release/release-checklist.md) — artifact and release review entry points.
- [Known risks](known_risks.md) — recorded unresolved concerns.

Operator runbooks for Firebase, IAM, production acceptance, and rollback remain
internal validation material. Their presence does not establish a public
production deployment or readiness for clinical use.

- [来源份量、匹配替代与启发式参数敏感性研究](FOOD_SOURCE_JOINT_AND_HEURISTIC_SENSITIVITY_RESEARCH_2026-10-01.md)：有限情景实际排序、方法身份修复与独立反例。

- [Replay capsule 有界差异与缩减研究](REPLAY_CAPSULE_BOUNDED_DIFFERENTIAL_RESEARCH_2026-10-01.md)

- [离线时间规则与 DST 回放研究](PINNED_TIMEZONE_AND_DST_REPLAY_RESEARCH_2026-10-01.md)

- [Evidence currency 历史回执持久化](EVIDENCE_CURRENCY_HISTORY_PERSISTENCE_RESEARCH_2026-10-01.md)

- [派生结果来源失效研究](DERIVED_RESULT_SOURCE_INVALIDATION_RESEARCH_2026-10-01.md)

- [变形关系实际编译变异研究](RELATION_CONTRIBUTION_COMPILED_MUTATION_RESEARCH_2026-10-01.md)
- [三个结果入口有界依赖研究](BOUNDED_RESULT_SINK_DEPENDENCY_RESEARCH_2026-10-01.md)
- [Android 与 Apple 平台迁移研究](NATIVE_PLATFORM_MIGRATION_RESEARCH_2026-10-01.md)：工具链、SwiftPM、UIScene、提醒登记与合成原生存储的分别验收。
- [最终候选元数据核对](FINAL_CANDIDATE_METADATA_RECONCILIATION_2026-10-02.md)：保留两项原失败，独立核对完整算法展示清单、报告依赖与精确字体家族授权。
