# ParkinSUM Companion — Documentation

ParkinSUM is an educational production-architecture prototype. Public demos and
model checks use synthetic data; owner-entered local records can contain
sensitive information. The model is not clinically calibrated, and the project
makes no clinical-validation or patient-care claim.

## Start here

| Read this | To understand |
| --- | --- |
| [Project README](../README.md) | The Paper workspace, current update, local setup, and boundaries. |
| [Project showcase](site/index.html) / [Visual wiki](wiki/index.html) | The interface and a short reviewer route. |
| [Capability matrix](CAPABILITY_MATRIX.md) | What is implemented, fixture-tested, report-only, or future work. |
| [Public verification](PUBLIC_VERIFICATION.md) | Exact checks, prerequisites, failure meaning, and evidence scope. |
| [App evolution timeline](APP_EVOLUTION_TIMELINE.md) | Dated changes, actual verification results, limitations, and rollback scopes. |
| [Public demo boundary](PUBLIC_DEMO_BOUNDARY.md) | What may be shown or claimed in a public demonstration. |

## App and records

- [Architecture](ARCHITECTURE.md) — UI, state, data, rules, and explanation layers.
- [Manual validation](MANUAL_VALIDATION.md) — synthetic workflow walkthroughs.
- [Portable data packages](USER_OWNED_PORTABLE_DATA_PACKAGE_RESEARCH_2026-08-17.md) — current-snapshot export, integrity, sensitive-data scope, and limitations.
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

## Evidence, provenance, and sources

- [Evidence demo guide](EVIDENCE_AND_TRACEABILITY_DEMO_GUIDE.md) — an end-to-end evidence walkthrough.
- [Evidence Trace Bundle](EVIDENCE_TRACE_BUNDLE.md) — the local artifact, explicitly distinct from a FHIR Bundle.
- [Importer metadata flow](IMPORTER_METADATA_FLOW.md) — source authority, jurisdiction, completeness, and missingness.
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
- [Changelog](../CHANGELOG.md) — development updates and versioned release history.
- [Public showcase readiness](../PUBLIC_SHOWCASE_READINESS.md) — public-repository gates.
- [Release evidence index](RELEASE_EVIDENCE_INDEX.md) / [Release checklist](release/release-checklist.md) — artifact and release review entry points.
- [Known risks](known_risks.md) — recorded unresolved concerns.

Operator runbooks for Firebase, IAM, production acceptance, and rollback remain
internal validation material. Their presence does not establish a public
production deployment or readiness for clinical use.
