# Open-source CDSS landscape and bounded transfer plan — reviewed 2026-09-29

## Scope

This is a focused review of additional clinical decision-support software
patterns relevant to ParkinSUM's existing synthetic CQL workbench, FHIR R4
export, and educational rule explanations. It adds architecture and test
references only. The projects below are pinned in
`config/open_source_influence_inventory.json`. All remain `concept_only`
except the CQF CQL translator/JVM engine, its JavaScript execution and FHIR
data-source packages, and Google CQL/FHIR Go tools, which are separately
classified as development-linked test dependencies. The CQF VSAC terminology
adapter remains concept-only because its API refresh path requires a UMLS key
and network access. The development-linked exceptions authorize only pinned
developer checks; they do not authorize application linkage or release
distribution. No upstream code, model, clinical rule, dataset, visual asset,
terminology expansion, or generated artifact is checked into app assets or
distributed in a release; the npm packages remain lockfile-pinned development
dependencies.

ParkinSUM remains a local-first education and research prototype. It is not an
EHR or a clinical service host. None of these projects validates ParkinSUM's
logic or makes its output clinical advice.

## Projects reviewed

| Project | What it contributes | License and reviewed revision | Transfer decision |
|---|---|---|---|
| [AHRQ CDS CQL Services](https://github.com/AHRQ-CDS/AHRQ-CDS-Connect-CQL-SERVICES/commit/72932fd7a8ca279afc72beb55c30aad772a58d53) | Separates CQL execution from a CDS Hooks 2.0 transport; maps named CQL expressions to source-labelled cards and keeps errors/warnings at response level. Its repository documents missing-prefetch behavior and FHIR model support. | Apache-2.0; `master` at `72932fd7a8ca279afc72beb55c30aad772a58d53`; latest listed release is v3.2.0. | Study expression-to-explanation provenance and synthetic contract tests only. Its README says it does not validate request JWTs and documents HTTP-only operation, so it must not be deployed as-is with patient data. AHRQ reports that the legacy CDS Connect repository and authoring tool went offline in 2025 and that further development moved to the HL7 CDS Connect Community Edition / CQL Studio; treat this repository as a historical implementation reference. |
| [AHRQ CQL Testing Framework](https://github.com/AHRQ-CDS/CQL-Testing-Framework/commit/60aae55fbab5cb7ad5aea8039e33148e42653954) | Developer-facing test tooling for YAML-defined expected results from FHIR-based CQL; the README documents DSTU2/STU3/R4, actual-versus-expected diffs, JSON and FHIR Bundle exports, and optional Postman tests for CQL Hooks. | Root `LICENSE` and GitHub report Apache-2.0; `master` pinned to `60aae55fbab5cb7ad5aea8039e33148e42653954`; `package.json` reports version 2.6.1. | Concept-only test-workflow reference. Example CQL, FHIR fixtures, and the VSAC value-set cache each have a separate unresolved `NOASSERTION` asset hold; no code, rule, fixture, value set, or FHIR data was transferred. |
| [PRANA — acute-care and anesthesia tools](https://github.com/hodanesthtmcvns-stack/jk/tree/11fd6cd52d561c428682866b70b187bcb18e7c40) | The README lists offline single-file HTML tools for NEWS2 triage, adult/pediatric ICU mortality scores, sepsis support, ventilation/PEEP, laboratory alerts, delirium, and inpatient insulin titration. It describes the tools as clinical support and education, with professional judgement and institutional protocols remaining in control. | Root `LICENSE` is GNU GPL version 3 and GitHub detects GPL-3.0; `main` at `11fd6cd52d561c428682866b70b187bcb18e7c40`. | Concept-only architecture reference. No independent clinical validation was established. Embedded scores, algorithms, and guideline-derived content have a separate unresolved clinical-rule asset hold; no code or clinical content was transferred. |
| [Two-stage conformal Parkinson medication prediction (MLHC 2025)](https://proceedings.mlr.press/v298/diaz-rincon25a.html) — [pinned implementation](https://github.com/rdiazrincon/two-stage_conformal_pd/commit/4f9fbcd537b9bb0592638e843d9ca018fc34e681) | A classifier first predicts whether medication needs change; conformal regression estimates the levodopa-equivalent daily-dose change over several time horizons. The paper reports 631 UF Health inpatient admissions from 2011–2021. | Root `LICENSE.md` and GitHub identify BSD-3-Clause-Clear; `master` at `4f9fbcd537b9bb0592638e843d9ca018fc34e681`, with a named copyright holder. | Historical research-method reference only. The pinned tree contains metric JSON, figures, and a notebook; no patient-row cohort file is present. These saved result assets remain a separate unresolved report-license hold. No code, cohort data, figures, or results were transferred. |
| [CASCADE Conformal Prediction](https://arxiv.org/abs/2605.20468) — [pinned implementation](https://github.com/rdiazrincon/cascade_conformal_pd/commit/840ae293ac05dadb0d13d08c032c7db4bcf4ab21) | Research prototype for two-stage Parkinson medication-management estimates: Venn-Abers uncertainty from a change-needed classifier scales conformal intervals for downstream levodopa-equivalent daily-dose changes. The paper reports one 631-admission UF Health cohort; its raw EHR data is not shared. | GitHub identifies BSD-3-Clause-Clear at `840ae293ac05dadb0d13d08c032c7db4bcf4ab21`; the pinned `LICENSE` still contains `[2026] [XYZ]` copyright placeholders, so no reuse rights are inferred. | Concept-only uncertainty-handling reference. Four notebooks contain training/evaluation code and saved results; the referenced `data_1Y.csv` is absent. Data and report outputs have separate unresolved asset holds. No code, model, cohort data, result table, or clinical rule was transferred. |
| [CQF Ruler](https://github.com/cqframework/cqf-ruler/commit/fec88ddc762b67b61a30b6c0433882e9cff9708a) | HAPI FHIR server plugins for FHIR Clinical Reasoning, knowledge-artefact hosting, and CDS Hooks-compatible services. | Apache-2.0; `master` at `fec88ddc762b67b61a30b6c0433882e9cff9708a`. | Follow the migration boundary: the project says core Clinical Reasoning operations have moved into HAPI/Clinical Reasoning, while CDS Hooks discovery/service work remains in progress. Do not add a separate server to the patient-facing app. |
| [CDS Hooks Sandbox](https://github.com/cds-hooks/sandbox/commit/60b985a4d50b46d62d1ef4fa3a3be955a5e2a185) | A mock-EHR and developer panel for exercising workflow hooks and inspecting service requests and responses. | Apache-2.0; `master` at `60b985a4d50b46d62d1ef4fa3a3be955a5e2a185`. | Reuse the testing idea only. Keep any future conformance work synthetic and local; do not import its UI or connect it to personal records. |
| [CDS4CPM Implementation Guide](https://github.com/cqframework/cds4cpm/tree/e73c2d2953aaad08f09428a6e70d5a07c5c7db31) | FHIR Implementation Guide for chronic-pain decision support and shared decision-making. The pinned README says its system design document is a work in progress and lists CDS Hooks deployment and EHR writeback among open design questions. | Apache-2.0 declared and GitHub-detected; `master` at `e73c2d2953aaad08f09428a6e70d5a07c5c7db31`; repository metadata reports last push 2024-05-07. | Compare system and knowledge-artifact boundaries only. The guide's clinical content and bundled archive were not reviewed or transferred; its domain and unfinished design decisions do not establish ParkinSUM suitability. |
| [CDS4CPM Sandbox](https://github.com/DBCG/cds4cpm-sandbox/tree/9266b4137e47d7a84553b3040dfc2c12e9e6d3f9) | Docker-orchestrated reference linking patient-facing MyPain, provider-facing PainManager, CQF-Ruler as a FHIR store, and a SMART launcher. | Apache-2.0 declared and GitHub-detected; `master` at `9266b4137e47d7a84553b3040dfc2c12e9e6d3f9`; repository metadata reports last push 2023-08-02. | Historical architecture reference only. The pinned README instructs disabling browser web security for testing and points to a sample-patient bundle; those data and deployment instructions were not exercised or transferred. |
| [CAREPATH CDS Specifications](https://github.com/srdc/carepath-cds-specifications/tree/82839d8ef5f3d23306beaf072790cb08a379e4fa) | The pinned tree contains 65 JSON service definitions, 13 Excel specifications, and 349 Mustache card templates. Its README says the specifications derive from the CAREPATH consensus guideline; the [study report](https://www.frontiersin.org/journals/medicine/articles/10.3389/fmed.2024.1386689/full) describes 65 CDS Hooks endpoints with FHIRPath rules and templated cards. | Apache-2.0 declared in `LICENSE` and GitHub-detected; `main` pinned to `82839d8ef5f3d23306beaf072790cb08a379e4fa` (2024-04-24). | Architecture and API-contract reference only. Guideline-derived specifications, service rules, and card content retain a separate unresolved asset-license hold; no code, rule, card, terminology, or data was transferred. |
| [SNOMED-CT FHIR CDS Service Demonstrator](https://github.com/IHTSDO/snomed-fhir-cds-service/tree/be6b5e6a8d636636cdef55310073857c92880574) | Java/FHIR R4 demonstration exposing CDS Hooks v2 medication-safety services plus diabetes and hypertension pathways. The README describes SNOMED CT value-set selectors, spreadsheet-authored rules, and three-valued `true`/`false`/`unknown` evaluation. | Pinned `LICENSE.md` declares Apache-2.0; GitHub metadata reports `NOASSERTION`; `master` at `be6b5e6a8d636636cdef55310073857c92880574`; last push 2026-08-24. | The README explicitly calls this a demonstration, not a production rule engine. Compare service discovery, rule authoring, and unknown-state handling only. The bundled rule tables and SNOMED terminology assets were not reviewed; their content licensing and suitability require separate review. |
| [SRDC SMART CDS](https://github.com/srdc/smart-on-fhir-cds/commit/89ddcfb7347c5b51aa55de8296e472d571addf65) | Scala CDS Hooks server example built on the onFHIR CDS library. Its README shows service discovery, per-service FHIR prefetch templates, request-supplied or server-fetched prefetch, and card suggestions/actions. | GitHub reports GPL-3.0; `main` at `89ddcfb7347c5b51aa55de8296e472d571addf65` (2026-08-27). The pinned repository includes `NOTICE.txt`: QRISK3 is LGPL-3.0-or-later with a required displayed/accessibly linked disclaimer, ADVANCE is CC BY 4.0, ACC/AHA material is CC BY-NC-ND 3.0, and SCORE2 cites ESC studies. | Study discovery, prefetch, and card contracts only. The README identifies this as a demonstration, not for real-world clinical decisions. Per-asset terms differ from the repository license; no rule, coefficient, model, clinical content, source, or asset was transferred. |
| [TRICC](https://github.com/SwissTPH/tricc/tree/b8ee6dc4a9f0e89372f59beb6d076684bc070f81) | Clinical flowchart authoring and digital-form generation with XLSForm/CHT strategies; the README marks OpenMRS support as under development and FHIR output as untested. | MPL-2.0 declared and GitHub-detected; `develop` at `b8ee6dc4a9f0e89372f59beb6d076684bc070f81`; repository metadata reports last push 2026-09-22. | Compare authoring and output-contract boundaries only. No flowchart, clinical rule, output, or source was reviewed or transferred; the README's FHIR limitation remains explicit. |
| [CQF Clinical Reasoning](https://github.com/cqframework/clinical-reasoning/commit/0d58353526c3508cc1ab252e8e8fa6201650536a) | Java/FHIR modules for clinical reasoning operations and CQL evaluation patterns. | Apache-2.0; `main` at `0d58353526c3508cc1ab252e8e8fa6201650536a`. | Study operation boundaries and FHIR-native service architecture. This is server-side Java infrastructure, not a Flutter library or a validation oracle for ParkinSUM's nutrition rules. |
| [Reason Framework](https://github.com/reason-healthcare/reason-framework/commit/2e8d91daf360f184e6c98f700031414829c64921) | TypeScript FHIR + CQL monorepo with FHIR R5 `ActivityDefinition/$apply` and `PlanDefinition/$apply`, a CDS Hooks/FHIR operation service, CPG review UI, and Cucumber integration-test support. | GitHub reports MIT; `main` at `2e8d91daf360f184e6c98f700031414829c64921` (2026-06-25). | Concept-only. The pinned README describes R5 service operations, while ParkinSUM's current synthetic artifact checks target FHIR R4. Study a separate R5 synthetic-contract path only; do not add a service, guideline content, or patient data to the local-first app. |
| [LangCare MCP FHIR](https://github.com/langcare/langcare-mcp-fhir/commit/d3651b3c8cb940be47c5f376255dded4035a14b8) | Agent-facing FHIR R4 MCP connector with search/read/create/update tools and a README-described 40+ clinical workflow guide library. It is infrastructure plus authored workflow instructions, not an independently evaluated decision engine. | Root `LICENSE` is MIT and GitHub labels it MIT; `main` at `d3651b3c8cb940be47c5f376255dded4035a14b8` (2026-02-21). | Concept-only. The `skills/` workflow content remains a separate unresolved `NOASSERTION` asset hold. No connector, workflow guide, clinical rule, data, or patient content was transferred; no clinical-performance claim is made. |
| [MD2SKILL](https://github.com/dromlakhani/MD2SKILL/commit/1e539eba7bff01b3a0a9abd3bd314398b42d2b89) | Guideline-derived clinical prompt library; the pinned README advertises 888 skills across 11 specialties in `SKILL.md` and system-prompt formats. The count is a repository claim, not independently validated coverage. | `main` at `1e539eba7bff01b3a0a9abd3bd314398b42d2b89` (2026-08-28). The README claims MIT, but the pinned root listing has no separate `LICENSE`; repository status remains `NOASSERTION` / unresolved. | Concept-only candidate, not confirmed open-source software or a deterministic CDSS engine. The `skills/` clinical prompt library has a separate unresolved `NOASSERTION` asset hold. No prompt, guideline text, code, or patient data was transferred; clinical validation was not established. |
| [CQF cql-execution](https://github.com/cqframework/cql-execution/tree/v3.3.2) | JavaScript execution of translated ELM, used here as a second runtime for a narrow synthetic CQL corpus. | Apache-2.0; release `v3.3.2`, commit `1991335e7ad490a8db88a05dd7f03dc3eecbda6d`. | A pinned development-only runtime now cross-checks the same nine ELM expressions as `@cqframework/cql`. It is a second executor, not an independent translator; partial CQL support, JavaScript number precision, and no built-in FHIR model or terminology provider constrain the result. |
| [CQF cql-exec-fhir](https://github.com/cqframework/cql-exec-fhir/tree/f3f9a968d597e2f029533a9e5cb1e6a643f2f69a) | JavaScript FHIR data source for `cql-execution`; accepts one local FHIR Bundle per patient and supports FHIR 4.0.1 R4, without querying a FHIR server. | Apache-2.0; release `v2.1.6`, commit `f3f9a968d597e2f029533a9e5cb1e6a643f2f69a`. | Used only in a pinned local synthetic Observation retrieval check. Source inspection and a regression test show that `PatientSource` selects resources by type/profile but does not filter `Observation.subject`; the harness removes foreign-subject resources before evaluation. No FHIR server, EHR, or patient data is involved. |
| [CQF cql-exec-vsac](https://github.com/cqframework/cql-exec-vsac/tree/fe7c19cc3e51095ec050b60486598023afa3ac98) | Optional terminology adapter for CQF CQL ValueSets, including local cache lookup and VSAC-backed refresh. | Apache-2.0; release `v2.2.0`, commit `fe7c19cc3e51095ec050b60486598023afa3ac98`. | Concept-only. The VSAC refresh flow requires a UMLS API key and network access; neither the package, endpoint, key, cache, nor terminology content is used here. A separate synthetic check uses only an in-memory local `CodeService`. |
| [CQF CQL JVM engine](https://github.com/cqframework/clinical_quality_language) | Java/JVM translation and evaluation through the platform-specific artifacts selected by `org.cqframework:engine@5.3.0`. | Apache-2.0; source commit `88693baefa482ec6f189c90113cfe1f3f4ce9d31`; Maven Central publishes the pinned engine artifact. | A development-only Gradle runner checks all nine fixed literal results and diagnostic lists against CQF JavaScript. These artifacts share the same upstream implementation family, so this is JVM/platform parity, not an independent engine, FHIR test, or clinical validation. The exact runtime dependency graph is locked and excluded from release dependencies. |
| [CQF CQL Studio](https://github.com/cqframework/cql-studio/commit/d2d6b678f0e7c7e23df9b5165a3fc42d6f4a5816) | An IDE-style workflow for authoring and testing CQL/FHIR knowledge artifacts. | Apache-2.0 declared in its README; GitHub detected SPDX is `NOASSERTION`; `master` at `d2d6b678f0e7c7e23df9b5165a3fc42d6f4a5816`. | Use as a workflow reference only. Its broader suite includes server, database, authentication, and FHIR services, with optional AI/MCP components; none is adopted. Verify licensing directly before any future transfer. |
| [Google CQL](https://github.com/google/cql/commit/b9169ccd54a3a8b0ac928aff338b9f7d6a4b163a) | Experimental Go CQL parser and interpreter aimed at large-scale FHIR data processing. | Apache-2.0; `main` at `b9169ccd54a3a8b0ac928aff338b9f7d6a4b163a`; module resolved as `v0.0.3-0.20260814184421-b9169ccd54a3`. | Development-only nine-case literal differential, three-case Condition retrieval, and six-case Observation/ValueSet differential. The local Observation route records that this pinned interpreter omits `Coding.version` in terminology matching; partial language support and no ELM import/export remain. It is not a production-compatible runtime or application dependency. |
| [OpenMRS Drools Module](https://github.com/openmrs/openmrs-module-drools/commit/fd63af4dd7994759e74fb13a5bf9c896537c8ab9) | OpenMRS-integrated Java CDS engine for patient flags, alerts, task lists, and rule-driven forms/recommendations. | MPL-2.0; `main` at `fd63af4dd7994759e74fb13a5bf9c896537c8ab9`. | Study the work-queue and rule-output lifecycle only. The README requires Java 11+, OpenMRS Platform 2.6+, and Drools 9.44+; it is a server module and is not a Flutter dependency or a portable rule-pack format. |
| [OpenEMR Clinical Decision Rules](https://github.com/openemr/openemr/commit/e01d65b33858e82c11892471001dd3d9963a27bf) | EHR-integrated clinical decision rules with reminder/report flows, rule citations, developer and funding fields, release metadata, web references, and current-action logging. | GPL-3.0 declared in the source; GitHub labels the repository GPL-3.0; `master` at `e01d65b33858e82c11892471001dd3d9963a27bf` (2026-09-10). | Study rule-provenance disclosure and audit presentation only. No PHP code, patient data, clinical rule content, or alert behavior was transferred. |
| [DIKB Evidence Analytics](https://github.com/dbmi-pitt/DIKB-Evidence-analytics/tree/9ffd629db30c41ced224ff2afdf132ce9276ae3f) | Evidence-focused drug-interaction knowledge base for pharmacoepidemiology and clinical decision support; its README describes separate assertion/evidence records with support, opposition, and assumption links. | The README says licensing varies by subproject (GNU GPL, Apache-2.0, or MIT); no repository-wide SPDX was verified. `master` pinned to `9ffd629db30c41ced224ff2afdf132ce9276ae3f`. | Mixed-license architecture reference only; individual source and evidence assets were not reviewed. Study explicit evidence relationships, but transfer no code, interaction rule, dataset, or clinical claim. |
| [GREvaluator](https://github.com/CEOsys/grevaluator/tree/769ad73ae6e715d989c652fed9f8bd9b66206cf4) | Docker-based prototype integrating clinical guideline recommendations with real-time clinical data; developed in the CEOsys living-evidence project. | Root `COPYING` is GNU AGPL version 3 and GitHub reports AGPL-3.0; `master` pinned to `769ad73ae6e715d989c652fed9f8bd9b66206cf4` (2023-05-30). | Documentation-only, concept-only architecture reference. The README says setup generates secrets and sample patient data; neither was run or reviewed. No source, guideline asset, sample data, or clinical recommendation was transferred. |
| [OpenCDS Core](https://bitbucket.org/opencds/opencds/commits/c14c8d8313737c23fe9f4fece56b0322355bce6d) | Java decision-support engine; the official overview lists CDS Hooks/FHIR and HL7 DSS/vMR client patterns, with Java and Drools rules. It lists CQL as future support. | `LICENSE.txt` at the pinned revision declares Apache-2.0; Bitbucket provides no machine-detected SPDX value here; `master` at `c14c8d8313737c23fe9f4fece56b0322355bce6d`. | Compare engine/client and adapter boundaries only. No engine, rule, client, or clinical content was transferred; confirm current CQL status from source before any future implementation work. |
| [OpenCDS examples](https://bitbucket.org/opencds/opencds-example/commits/322a775f08e11e66206160d828ae417179513528) | The pinned root tree lists CDS Hooks service, KnowledgeModule, FHIR R4 KnowledgeModule, and pre/post-processing plugin examples. | The pinned `pom.xml` declares Apache-2.0; Bitbucket provides no machine-detected SPDX value here; `master` at `322a775f08e11e66206160d828ae417179513528`. | Treat the module names as architecture leads only. Example rules and adapters were not audited or transferred. |
| [openTriage](https://github.com/dnspangler/openTriage/tree/7644ca32c7c4ee19de57f70173630bde74de3471) | Docker-hosted Python REST inference service with pluggable input/model/output frameworks and an optional Shiny explanation view; the pinned README describes prehospital risk-score and NEWS2 examples. | GPL-3.0 declared and GitHub-detected; `master` at `7644ca32c7c4ee19de57f70173630bde74de3471`. GitHub repository metadata reports the last push as 2025-05-07. | Study framework and API boundaries only. It is a research/trial-oriented risk-score service, not a ParkinSUM nutrition/medication engine. No model, dataset, endpoint, or source was transferred; require separate GPL compatibility and security reviews before any reuse. |
| [Arden2ByteCode](https://github.com/PLRI/arden2bytecode/tree/9263f86944a5ebab2a8e5b038d534107d735c806) | Arden Syntax 2.5 compiler/runtime translating MLMs to JVM bytecode; the README lists an unimplemented Include statement and two unchecked language/version conditions. | Root license declares GPL-3.0-only for the whole compiler and includes a separate Apache-2.0 JewelCLI notice; GitHub detected SPDX is `NOASSERTION`; `master` at `9263f86944a5ebab2a8e5b038d534107d735c806`. | Compare the language-version and execution-context boundary only. Other dependency notices and security posture were not audited; no compiler, MLM, or code was transferred. |
| [openEHR GDL tools](https://github.com/openEHR/gdl-tools/tree/15911c891dfae363c60f81e47cbbd10b257c038f) | Java-based GDL parser/editor tooling with Maven artifacts and a desktop editor. | `LICENSE.txt` declares MPL-2.0; GitHub detected SPDX is `NOASSERTION`; `master` at `15911c891dfae363c60f81e47cbbd10b257c038f`. | Study authoring/parser boundaries only. Its compatibility relationship to the separately documented GDL2 Editor is unverified; no code or guideline was transferred. |
| [openEHR GDL guideline models](https://github.com/openEHR/gdl-guideline-models/tree/f11cfd534d6fb4bd5def85b0c96d6ed17a5defe0) | A catalog of openEHR archetypes and GDL guideline examples; the pinned README lists 740 CDS examples. | Apache-2.0 declared and GitHub-detected at repository level; `master` at `f11cfd534d6fb4bd5def85b0c96d6ed17a5defe0`. | The repository explicitly limits its examples to demonstration and says they must not be used for medical decisions. No guideline, archetype, or rule content was reviewed or transferred. |
| [GenPRES](https://github.com/informedica/GenPRES/tree/9ab8234577075808c7a79475058790cbf37f43de) | Generic medication-order entry across prescribing, preparation, and administration workflows, initially aimed at the Dutch setting. | GPL-3.0 declared and GitHub-detected; `master` at `9ab8234577075808c7a79475058790cbf37f43de`. | Study order-entry and dose workflow boundaries only. Its README requires appropriate validation and regulatory approval before direct clinical use and says the full medication cache is not freely distributable. No app code, cache, or medication rule was transferred. |
| [Arcwell](https://github.com/arcweb/arcwell/tree/4be1ed002249b397698e1c588b1bbc81a0c28346) | Open clinical-research platform architecture with pathway/CDSS examples and administration tooling. | Apache-2.0 declared and GitHub-detected; `develop` at `4be1ed002249b397698e1c588b1bbc81a0c28346`. | Compare research-platform boundaries only. The pinned README places the FHIR bridge and embedded EHR on the roadmap; they are not current capabilities. No source, service, or clinical content was transferred. |
| [NutriKen](https://github.com/abrangel/Nutriken/tree/5eb45263b5478192f5452c474336f463829ef1ea) | Research-oriented clinical nutrition and medication/nutrient information workflow. | Root `LICENSE` is MIT and GitHub detects MIT; `main` at `5eb45263b5478192f5452c474336f463829ef1ea`. | Concept-only pending resolution: the README adds “academic and research” scope language that is absent from the standard MIT grant. External data and DrugBank access require separate review. No code, rules, or data were transferred. |
| [Food-drug interaction detector](https://github.com/nexorin9/food-drug-interaction-detector/tree/c2147d44ae774681042530310a3fdb247ff176fb) | A README-described rule-based meal/medication interaction detector with CLI and REST entry points. | One commit at `c2147d44ae774681042530310a3fdb247ff176fb`; GitHub reports no license and the pinned tree has no `LICENSE` file. | Source-available lead only; open-source status is unconfirmed. Keep it unresolved and concept-only. No rule, code, or data was transferred. |

## Asset-license gate update — 2026-09-24

The influence inventory now separately holds 20 clinical-rule, data, model, report, and terminology asset categories across 15 pinned repositories. This covers the SNOMED CDS demonstrator’s rules and terminology, the openEHR guideline examples, OpenCDS example rules, the SRDC model/rule assets with distinct NOTICE terms, and the existing OSP model/data/report records. Each remains concept-only with unresolved asset-level terms; repository SPDX is not carried over to knowledge or data assets. The offline transfer gate requires separate, pinned asset evidence before any such content can be copied, linked, derived, vendored, or added as a development dependency.

### FHIR R5 CPG apply-result contract probe

The pinned [Reason Framework README](https://github.com/reason-healthcare/reason-framework/blob/2e8d91daf360f184e6c98f700031414829c64921/README.md) documents FHIR R5 `ActivityDefinition/$apply` and `PlanDefinition/$apply`, a CDS Hooks/FHIR operation service, a review UI, and Cucumber-based integration-test support. HL7 defines PlanDefinition's `return` as `0..*` Bundles, one per subject; the operation response therefore uses a `Parameters` wrapper with one `return` part in this fixed one-subject fixture. Each Bundle starts with a RequestOrchestration. The ActivityDefinition operation returns the resource type named by `ActivityDefinition.kind` directly because its result is `1..1`. ParkinSUM also checks the companion R5 `PlanDefinition/$data-requirements` response: HL7 defines one `Library` return, which is returned directly, and the fixed synthetic Library must identify as `module-definition` while retaining one versioned dependency, one Boolean output parameter, and one Observation data requirement. These schema-v1 checks validate fixed operation-result shapes only; they do not execute `$apply`, `$data-requirements`, CQL, or dependency aggregation. The optional `npm run fhir:r5:cpg-apply:validate` command submits all three synthetic results to the checksum-pinned HL7 Validator CLI 6.10.4 with FHIR 5.0.0 selected and terminology-server lookup disabled. It requires Java 11 or newer and may download the official R5 core package when it is absent from the local cache. The app never invokes the optional CLI; `verify:all` runs only local contract tests. This validator path has not run on the current host, which has Java 8 and no configured validator JAR or cached R5 core package. These checks do not establish general FHIR conformance, clinical validity, safety, or interoperability. The Reason Framework remains a pinned concept-only reference; no upstream code or clinical artifact was transferred.

## Newly transferred authoring pattern

The [HL7 Common CQL Assets for FHIR authoring guide](https://hl7.org/fhir/us/cql/2.0.0/en/authoring.html)
describes a versioned `cqf-library` link from a Questionnaire, SDC Patient
launch context, and item `initialExpression` titles that resolve to definitions
in the primary CQL Library. The HL7 [CQL conformance requirements](https://hl7.org/fhir/uv/cql/conformance.html)
also require computable Libraries to declare `relatedArtifact` dependencies for
their CQL includes and data models, and to use `Library.parameter` for input
parameters and the output name/type of every top-level CQL expression, plus
`Library.dataRequirement` entries for CQL retrieves. The CQL guide maps retrieve
data types to FHIR resource types, template identifiers to profiles, and CQL
context to the data-requirement subject. This is an HL7 implementation guide,
not another software repository in the influence inventory; its published
v2.0.0 is informative guidance based on FHIR R4.0.1.

The official [CPG Computable Plan Definition](https://hl7.org/fhir/uv/cpg/StructureDefinition-cpg-computableplandefinition.html)
profile also describes `PlanDefinition.library` as the logic used by a plan
and its `action.condition.expression` as Boolean-valued. The fixed local
contract now binds one synthetic PlanDefinition to the exact versioned CQL
Library and resolves its two Condition/Observation applicability expressions.
FHIR R4 lists
[`text/cql`](https://hl7.org/fhir/R4/valueset-expression-language.html) as an
expression language; this fixture makes no full-profile conformance claim.

ParkinSUM transfers these artifact relationships into `npm run cql:diff` as
one fixed synthetic Bundle parsed with Google CQL's FHIR model. A Questionnaire
and a PlanDefinition each bind to the same exact-version primary Library; its
two applicability conditions resolve to Boolean CQL definitions.
The primary Library imports one exact-version synthetic
shared Library and declares both that dependency and the FHIR 4.0.1 ModelInfo
dependency. The shared Library declares its ModelInfo dependency. The check
parses both source libraries together, resolves two definitions through the
include alias, and catches `relatedArtifact`, canonical/version, embedded
content, Patient-context, and definition-link drift. Each Library also declares
every top-level definition once as an optional scalar Boolean output parameter;
the checker matches its name and FHIR type to the parsed CQL definition and
Boolean result. It parses each library and maps its fixed Patient, Condition, and
Observation retrieves to exact FHIR `dataRequirement` type, profile, and subject
fields; the primary has Patient, Condition, and Observation requirements and its
included library has Patient. The fixture adds a manufactured Observation, and
the local harness scopes it to the fixed synthetic Patient. The schema-v8
artifact contract declares six output parameters, four data requirements, the
PlanDefinition-to-Library binding, six single-condition scenarios, and nine
paired Condition/Observation outcomes under same-kind AND semantics.
A separate
six-case Observation/ValueSet differential runs through JavaScript, Google CQL
Go and CQF JVM; the schema-v12 report adds a CDS Hooks projection that withholds
its card when the pinned providers disagree on `Coding.version`. The pinned
local model backs the ModelInfo canonical; nothing is fetched at runtime. It
does not adopt CQL Studio's application stack, connect to an EHR or FHIR
endpoint, or fetch external libraries. A separate schema-v3 developer harness
implements a fixed local subset of `Questionnaire/$populate`: it evaluates the
two Boolean `initialExpression` bindings in the pinned CQF CQL engine and
returns a FHIR R4 `Parameters` output containing an in-progress
`QuestionnaireResponse`, the exact Questionnaire canonical, and two synthetic
Boolean answers. The input must name the exact pinned Questionnaire through
its versioned canonical, exact `Reference`, or identical resource; subject/context/data parameters
and altered Questionnaires fail closed. No Patient resource is supplied and
the response has no subject. The SDC operation's populated answers require human review; an empty
expression result for a Boolean item must remain unanswered rather than
become false ([SDC Form Population](https://hl7.org/fhir/uv/sdc/STU4/en/populate.html)).
This fixed local operation subset makes no remote call and is not an SDC or
FHIR conformance claim. Its `Parameters.parameter[name=response]` envelope
follows the published [SDC `$populate` operation definition](https://hl7.org/fhir/uv/sdc/STU4/en/OperationDefinition-Questionnaire-populate.html).

The separate `npm run cql:fhir:observation` check compiles
`exists([Observation])` and a ValueSet-filtered Observation retrieve with
`@cqframework/cql@5.3.0`, then executes six fixed FHIR R4.0.1 synthetic Bundles
through `cql-execution@3.3.2` and `cql-exec-fhir@2.1.6`. The cases include
presence/absence, foreign-subject filtering, non-member code, wrong code
system, and a code-system version mismatch. Only an in-memory synthetic
`CodeService` expands the test ValueSet. The pinned JavaScript runtime ignores
`Coding.version` when matching codes, so the mismatch case records runtime
membership `true` and the fixture's version-aware test expectation `false`. The check
confirms the upstream JavaScript FHIR provider itself returns the
foreign-subject Observation when passed the raw Bundle, so that filter remains
an explicit harness responsibility. This is a local smoke test only; it does
not establish terminology, patient-isolation, general FHIR/CQL conformance, or
clinical correctness. The report contains outcomes and fixture/source digests,
not patient/resource IDs, clinical codes, or Bundle content.

The companion `npm run cql:fhir:observation:jvm` check evaluates the same six
strict fixtures through CQF JVM CQL 5.3.0. Its fixed in-memory
`TerminologyProvider` compares code, system, and system version; a bounded
retrieve provider applies the fixed Patient context and supplies the synthetic
Observation values. It checks both direct CQL `Code in ValueSet` and a
ValueSet-filtered Observation retrieve. The JavaScript `v2` membership of
`true` and JVM membership of `false` are reported as a difference between
configured local providers; they do not establish normative behavior or
cross-engine conformance. Arbitrary FHIR Coding extraction, terminology
expansion, and clinical use remain outside this probe.

The same six bundles now also run through Google CQL's pinned Go parser and
interpreter with its local FHIR 4.0.1 model, a fixed in-memory ValueSet
expansion, and a bounded subject-reference filter. Google CQL matches the
JavaScript membership result in all six cases and the configured CQF JVM
provider in five. For the `Coding.version: v2` case, Google and JavaScript
return membership while the version-aware JVM provider does not. Inspection
of the pinned Google interpreter shows that `Coding.version` is not forwarded
to the terminology provider. This records implementation behavior for these
local providers, not a FHIR/CQL terminology rule or conformance result.

The current openEHR GDL2 specification is stable at CDS Release 2.0.1, while
GDL version 1 is retired. The documented GDL2 Editor is an open-source Java
tool; do not assume the separately pinned `gdl-tools` repository is the same
implementation or that its README demonstrates current GDL2 compatibility.

The [CDS Hooks v2.0.1 specification](https://cds-hooks.hl7.org/STU2/)
defines workflow-triggered services and information, suggestion, and app-link cards.
Suggestion cards can populate changes in the host clinician interface, and
`systemActions` can propose automatic changes. That workflow is built for an
EHR/CDS client and is not a fit for direct activation in ParkinSUM. Its
extension convention reserves a custom `extension` object and recommends
globally unique names for pre-coordinated extension data. Its
[security guidance](https://cds-hooks.org/security-considerations/) calls for
trusted-service allowlists, minimal short-lived FHIR authorization, JWT
verification, and careful handling of tokens. Any future network integration
would require a separately reviewed client/server trust and privacy design.

## Concrete addition in this worktree

A local engineering sandbox is now reachable from the diagnostics page. It
offers three fixed, code-owned synthetic contexts and runs the existing
in-memory baseline rule engine only after the user selects “Run locally”. The
output is either one information-only card or an empty `cards` response; it
can be inspected as the exact generated response envelope in an expandable,
read-only JSON panel, including the empty response. It does not accept
patient/free-text input, read account or saved health records, or call a CDS
service, EHR, or network endpoint.

The separate synthetic rule test workbench can also run schema-validated
synthetic cases against an imported, content-bound rule pack. Each rule
explanation now has an expandable preview of its own information-only response
envelope, produced from that run's matching rule trace. If the trace cannot
pass the existing projection contract, the workbench marks the preview
unavailable. This is a local authoring aid; it does not alter the clinical
runtime, call a service, or enable the imported rules.

The published [CDS Hooks v2.0.1 discovery contract](https://cds-hooks.hl7.org/STU2/#discovery)
defines a `services` array whose entries require `id`, `hook`, and `description`;
`title` is recommended and `prefetch` is optional. The local contract runner
checks only one fixed synthetic `patient-view` entry and additionally requires
its bounded title and description. It rejects extra services, unknown fields,
prefetch templates, and endpoint fields. It validates a local fixture only:
it does not resolve or invoke a service or make a network request.

The CDS Hooks v2 subset contract requires a non-empty summary shorter than 140
Unicode code points, `indicator: info`, and a source label. It rejects request
context, FHIR authorization and prefetch data, `systemActions`, suggestions,
app links, warning/critical indicators, unsafe source URLs, and unknown card
fields. It allows exactly one reviewed namespaced rule-trace extension with a
strict versioned schema. An empty `cards` array remains a valid no-guidance
response.

The domain projector consumes the existing `RuleExplanation` plus its
original rule-trace row. It carries per-rule and
rule-pack versions, source references, fields used, missing-input codes, and a
domain-separated input digest. The original `not_matched` trace remains visible;
when required inputs are missing, its separate interpreted `resultState` is
`unknown`, and the explanation explicitly says this is not a negative result.
Explicit `unknown`, `missing_input`, and `unsupported_input` statuses remain
distinct; an unrecognized status is rejected. A supplied governed package
digest is optional and must be a SHA-256 value.

The fixture and engine tests use only synthetic context and contain no raw
input values or person/account identifiers. An input digest is stable and
unsalted, so it is pseudonymous and not anonymization; it must never be treated
as safe to export for real data. The diagnostics route is separate from the
production patient-rule path. The sandbox opens no network connection, does
not run CQL, and does not serve CDS Hooks requests.

A separate `npm run cql:diff` gate compiles and evaluates the nine fixed
synthetic CQL expressions with pinned `@cqframework/cql@5.3.0`, runs that
translator's generated ELM through `cql-execution@3.3.2`, directly parses and
evaluates the authored source through pinned Google CQL
`v0.0.3-0.20260814184421-b9169ccd54a3`, and checks the same source through the
pinned CQF JVM engine 5.3.0. ParkinSUM's Dart runtime evaluates the paired
manufactured contexts. All four CQL paths agree on the nine three-valued
outcomes and all nine `Errors`/`Warnings` lists. Google CQL's direct source
path adds an independent parser and interpreter; it does not consume ELM from
the CQF translator. CQF's JVM and JavaScript paths share the same upstream
implementation family, so the JVM check measures platform parity only.

The same command now runs a separate FHIR R4.0.1 retrieval comparison through
Google CQL's local Bundle retriever, the pinned CQF JavaScript translator and
FHIR Patient source, and the CQF JVM `engine-fhir` parser/engine using its
pinned `quick` model-info provider. The schema-v2 corpus contains
exactly three code-owned collection Bundles in Patient context and evaluates
only `exists([Condition])`: one matching Condition, one synthetic Patient with
no Condition, and one Condition whose subject names another synthetic Patient.
Each local harness scopes Condition retrieval to the declared Patient context;
the outcomes are `true`, `false`, and `false`, with matching authored diagnostic
lists and **3/3** three-runtime outcome parity; Google CQL and CQF JVM retain
**3/3** diagnostic parity. The Go runner, JavaScript contract, and JVM input
adapter reject resource and case drift
before evaluation; the integrated report stores both case-level results and
the fixture digest, never Bundle contents. This probe is separate from the
nine-case four-path literal comparison and does not run through the Dart
runtime. After all three Condition paths agree, the
integrated schema-v12 report projects the fixed outcomes through a separate
versioned CDS Hooks response contract: the matching synthetic Condition case
produces one `info` card, while the patient-only and foreign-subject cases
produce empty `cards` arrays with a bounded `criterion_not_met` response
warning. The extension binds the fixed case, Patient context, FHIR/CQL
versions, exact engine identities, parity and corpus digest without including
Patient IDs or Bundle content. This follows the CDS Hooks v2 information-card
and no-guidance response shape, but remains an offline development projection,
not a service or patient recommendation ([CDS Hooks v2.0.1](https://cds-hooks.hl7.org/STU2/)).

The schema-v12 development report adds a separate projection for the six
fixed synthetic FHIR R4 Observation/ValueSet cases. It emits one information
card only for unanimous `true`, four empty no-guidance responses for unanimous
`false`, and withholds a card with an `engine_disagreement` error for the
version-mismatch case where the pinned JavaScript and Google CQL providers
report membership but the configured version-aware CQF JVM provider does not.
The response contains only fixed case labels, Boolean provider results,
versioned engine identities, and the fixture digest. The focused response-contract tests, JavaScript Observation check, and six-case
CQF JVM check pass. The complete pinned schema-v14 cross-runtime gate also
passes with Go 1.26.8 and Android Studio JDK 21; this records a provider-specific difference, not FHIR
terminology conformance, clinical advice, or an application-runtime feature.

A true result produces one information-only card; false and unknown results
return an empty `cards` list plus a strict
`org.parkinsum.cql-differential-response` extension with response-level warning
or error codes. The extension keeps diagnostics available without a card and
records the two CQF JavaScript runtime identities, case, and corpus digest.
The Google parser and CQF JVM platform-parity and FHIR retrieval identities are
recorded and compared in the developer report, not added to the card contract. This mirrors
an AHRQ CQL Services authoring pattern; the
local namespace is not a general CDS Hooks profile. The CQL result stays
separate from the Dart candidate match. Missing-dose and missing-time unknowns
retain their review flags; the unsupported-unit case remains unknown even
when Dart reports no candidate match and no missing-field review. Unknown is
never collapsed to a negative result. Three cards and six response-level
diagnostic envelopes pass the local contract. The CQL author's guide defines
`null` as unknown in Boolean evaluation; this is an engineering test, not a
clinical rule evaluation.

A further developer-only probe covers ten fixed FHIR R4 MedicationStatement
cases across Google CQL Go, CQF JavaScript, and CQF JVM: all eight status codes
(`active`, `completed`, `entered-in-error`, `intended`, `stopped`, `unknown`,
`not-taken`, and `on-hold`), no statement, and a statement whose subject is
another synthetic Patient. All three paths agree on the nine Boolean
retrieval/status outcomes, and each scoped retriever drops the foreign-subject
statement. The fixture contains only a text placeholder for medication and
carries no medication code or dose. FHIR defines MedicationStatement as
reported medication-use information; it does not assert that administration
occurred, which is represented separately by MedicationAdministration ([FHIR
R4 MedicationStatement](https://hl7.org/fhir/R4/medicationstatement.html)).
This probe is not an app route, reconciliation workflow, decision rule, or
general FHIR/CQL conformance result. Its integrated schema-v14 run passes.

A separate developer-only comparison extends this local FHIR retrieval work to MedicationRequest,
which represents an order/request rather than reported medication use. Its
18 fixed cases probe all eight `status` codes and all eight separate `intent`
codes, plus no request and a foreign-subject request. The pinned Google CQL Go,
CQF JavaScript, and CQF JVM paths compare the same Boolean retrieval outcomes;
each narrow local harness drops the foreign-subject request. The composite
schema-v14 report retains only case labels, outcomes, runtime identities and
the fixture digest. This adds no live exchange, drug coding, terminology call,
prescription validation, or clinical rule. See the [FHIR R4 MedicationRequest
definition](https://hl7.org/fhir/R4/medicationrequest.html).

The cql-execution executor implements only a declared subset of CQL, uses
JavaScript numbers (with their precision limits), and has no built-in FHIR
data model or terminology provider. The Observation harness supplies only an
in-memory synthetic `CodeService`; its pinned code matcher ignores
`Coding.version`. Google CQL is experimental, has partial
language support and no ELM import/export; its documented FHIR support is
limited to FHIR 4.0.1 and Patient context. The CQF JVM retrieval path uses the
pinned FHIR model-info and JSON parser modules but fixed local providers for
the three Condition, six Observation, ten MedicationStatement, and 18
MedicationRequest synthetic fixtures. These smoke tests
demonstrate narrow retrieval expressions and subject-reference filters over
synthetic Bundles only. They do not establish
Bundle validation, patient-context isolation for arbitrary inputs, external
terminology-service behavior, general version-aware terminology matching, provider
integration, general-purpose compatibility, or production
use. All external runtimes are development-only; the Go and Gradle/JVM
dependencies are explicitly excluded from release dependency declarations
and artifacts.

The local sandbox and CQL runner remain engineering evidence. The CQL runner
has no application route, EHR/CDS service call, remote FHIR access, or real
data. Its FHIR projections use only fixed synthetic Bundles and withhold cards
on the pinned `Coding.version` engine disagreement. The complete
`npm run --silent cql:diff` gate passes with Go 1.26.8 and Android Studio
JDK 21, generating a schema-v14 composite report with both medication-resource
retrieval comparisons. The sandbox output is not a
production CDS Hooks response and does not establish general FHIR/CQL
conformance, interoperability certification, or clinical safety. Run the
contract checks with `npm run cds:hooks:test` and the integrated report with
`npm run --silent cql:diff`.

### SMART sandbox discovery and synthetic standalone-launch preflight

The diagnostics page also has a separate debug-only live discovery probe for
the public SMART Health IT R4 sandbox. It runs only after an explicit tap and
sends one bodyless HTTPS request to the exact R4
`/.well-known/smart-configuration` URL. The source egress gate limits that
request to the fixed host, path, port, method and public-metadata data class;
it denies query strings and redirects and reads at most 64 KiB. The response
parser checks that the authorization and token endpoints remain on the sandbox
host. It requires the SMART App Launch 2.2 `grant_types_supported`,
`capabilities` and `code_challenge_methods_supported` arrays; checks for
`authorization_code` and PKCE S256 while surfacing any `plain` advertisement
as incompatible; and reports `response_types_supported.code` when that
recommended array is present. It requires an authorization endpoint
when an authorization-code or launch capability is advertised. The page keeps
only selected capability and scope booleans in memory. The probe sends no
account, Patient, resource or token values. It does not open
an authorization flow, request consent, exchange tokens or read FHIR data.
This gives a real metadata request path, while a live sandbox response still
needs to be captured in a connected debug environment before claiming observed
compatibility ([SMART Health IT developer documentation](https://docs.smarthealthit.org/)).

An offline developer gate validates a fixed schema-v3 synthetic SMART App
Launch 2.2.0 / FHIR R4 fixture and emits a schema-v4 report. It binds the FHIR
base URL to the spec-defined `/.well-known/smart-configuration` path and models
an HTTP 200 `application/json` discovery response without fetching it. The
validator checks the required token endpoint, grant types, capabilities, and
PKCE metadata; requires the authorization endpoint when launch is advertised;
requires the app's minimum read-only scopes and capabilities; rejects `plain`
PKCE; and requires `issuer` plus `jwks_uri` when `sso-openid-connect` is
advertised. Metadata URLs must be absolute HTTPS URLs without userinfo or
fragments. Unknown metadata extensions are ignored, but unknown fields in the
pinned fixture fail closed. The response summary omits full discovered endpoint
URLs. These checks follow the [SMART App Launch v2.2.0 conformance metadata
requirements](https://hl7.org/fhir/smart-app-launch/STU2.2/conformance.html).
The in-memory request uses a public client, authorization-code response, exact
registered callback, SMART standalone patient-access capability set, `aud`
matching the FHIR base, PKCE S256, and only `launch/patient` plus
`patient/Observation.rs`.

The tool generates successful and `access_denied` callback URLs in memory,
then validates the exact registered callback and exact echo of the transient
state. Its synthetic negative cases reject mismatched or repeated state, an
unregistered callback path, a missing code/error result, and simultaneous
`code` and `error`. The report exposes only validation booleans: no generated
state, challenge, verifier, synthetic authorization code, or OAuth error
detail is returned or persisted. SMART requires a client to validate the state
on return to its redirect URI and tie it securely to the current session
([SMART authorization flow](https://hl7.org/fhir/smart-app-launch/STU2.2/app-launch.html));
OAuth 2.0 defines both code/state and error/state response forms
([RFC 6749 section 4.1](https://www.rfc-editor.org/rfc/rfc6749.html#section-4.1)).

This remains a fixed local contract check: no discovery fetch, browser
navigation, real callback input, token exchange, FHIR read/write, or
application route is involved. It does not establish actual SMART
interoperability, patient-context isolation, clinical validity, or
certification. Run it with `npm run smart:launch:preflight:test`.

### Medication identity and dose separation

The development-only `parkinsum.fhir-r5-medication-product-preview/3`
projects product and ingredient displays from both a text view and an
opt-in `MedicationProductPack` source snapshot. Only the latter may emit
`Medication.ingredient.strengthQuantity`, and only when the raw decimal lexeme
matches the parsed positive value, the source unit exactly matches `g`, `mg`,
or `ug`, the source host matches a supported openFDA or Health Canada importer,
the denominator is absent or numeric one without a unit, and the dosage form
is exactly `tablet`. For openFDA, this projection additionally requires one
exact match in a local source manifest built from the same snapshot bytes as
the product catalog, matching NDC, ingredient index/name, and raw strength.
The preview binds the asset SHA-256 plus product ID, SPL ID, parser-result
digest, and row digest. These hashes prove local byte and row identity only;
they do not verify FDA data or currentness. Health Canada retains the existing
host and identifier checks because no corresponding local snapshot manifest
is added. Other forms, concentration denominators, explicit
denominator units, aliases, unsupported units and mismatches remain in local
evidence. FHIR R5 defines ingredient strength as a Ratio or Quantity when the
denominator is assumed to be one tablet; UCUM labels `{tbl}` as a non-unit
example, so it is not used as a tablet code
([FHIR R5 Medication definitions](https://hl7.org/fhir/R5/medication-definitions.html),
[UCUM specification](https://ucum.org/ucum)).

The schema-v3 profile manifest binds the FHIR Core 5.0.0 and UCUM 2.2/license 1.1
references plus a bounded Medication path ledger. It does not redistribute a
UCUM table or parser or establish license clearance. The preview binds
available product identifiers and source URL outside the Medication
fragment; a full upstream response digest is not supplied by the importer.
Exchange and algorithm use remain ineligible. This complements the separate
confirmed-dose Dosage fragment and creates no RxNorm mapping, complete FHIR
resource/profile, independent validator result, patient event, or clinical
recommendation.

The saved-intake timeline now opens a local preview from each medication
record. AppState rechecks the owner-bound dose receipt and medication-assertion
graph; a held result shows no numeric quantity. A projected view displays only
the exact `doseQuantity` value, display unit, system, and preview code, plus
local fields omitted from the fragment. It labels the result as partial, has no
copy/save/send action, and hides its contents if the account or intake revision
changes. This is an inspection view, not a FHIR R5 exchange feature.

Engineering Diagnostics now provides a read-only page for searching the
bundled product rows and inspecting the selected source URL, importer timestamp,
source asset and manifest hashes, raw strength, projection evidence, and
content-addressed preview JSON. The page uses the existing offline asset
(snapshot marker `2026-08-17T04:12:16.084Z`); it performs no live fetch,
persistence, FHIR validation, or algorithm call. Widget tests cover the
diagnostics route, an exact local row binding for a projected tablet quantity,
and a liquid strength that remains held. This makes the existing product
projection inspectable without strengthening its source or clinical claims.

An adjacent `parkinsum.openfda-strength-expression-parse-result/1` contract
now keeps openFDA NDC strength text intact and exposes a limited lexical
parse over the pinned local snapshot (213 ingredient rows). A bare `/1` has
no inferred unit; unit-bearing denominators such as `/5mL` and `/24h` remain
untyped source text. The preview uses the parser result's exact raw source
string and digest only to require a unique local openFDA row match; the parser
assigns no UCUM or FHIR strength semantics and does not feed algorithms.
openFDA defines this source field as a string and
warns that API results are unvalidated; FDA also says directory inclusion is
not approval or verification ([openFDA NDC field reference](https://open.fda.gov/fields/drugndc_reference.pdf),
[openFDA API result guidance](https://open.fda.gov/apis/drug/ndc/understanding-the-api-results/),
[FDA verification limitation](https://www.fda.gov/drugs/enforcement-activities-fda/unapproved-drugs)).
The versioned source manifest binds each row to its source asset digest,
product NDC/product ID, SPL ID, ingredient index, and ingredient name. It
keeps the snapshot a research fixture, not a verified medication catalog.

### Local package-strength derivation trace (CDSS-117)

The timeline package-dose calculator now produces the optional
`parkinsum.medication-package-dose-derivation/1` trace. The selected product
snapshot carries its source system, URL and retrieval time; the trace keeps the
exact ingredient-strength text and parsed numerator/denominator, how the
denominator was handled, the confirmed tablet/capsule/caplet quantity, formula
identity and result. The existing dose-confirmation receipt hashes that full
snapshot. The timeline displays the arithmetic and warns when the source did
not state a denominator. Editing the dose note clears the calculation trace
before a typed value can be confirmed.

The calculation is limited to recognized discrete dosage forms. It holds
volume denominators, unsupported forms and a denominator unit that conflicts
with the product form; it does not convert concentration to mass. An absent
denominator is recorded as an assumption, not rewritten as source evidence.
The separate FHIR preview now uses the narrower exact-tablet subset described
above. FHIR R5 permits `Medication.ingredient.strength[x]` as a `Quantity` when
the denominator is assumed to be one tablet, while FDA's listing guidance
distinguishes oral solids with an `each` denominator from liquids expressed by
volume; the app implements only its narrower tablet/capsule/caplet subset
([FHIR R5 Medication definitions](https://hl7.org/fhir/R5/medication-definitions.html),
[FDA strength conversion guidance](https://www.fda.gov/drugs/electronic-drug-registration-and-listing-system-edrls/strength-conversion-drug-listing)).
This closes a bounded provenance and arithmetic gap while the broader P0
remains `research_required`: source records are not independently verified,
the selected metadata has no full raw-response content hash, terminology and
license review remain open, and no full FHIR profile/validator or governed
algorithm identity binding is claimed. The local trace is not clinical
validation, prescription checking, or evidence of actual administration.

## Remaining expansion boundary

### Bounded food-composition rank stress trace

The next-meal result now carries a transient source-range sensitivity report
bound to the exact app-assembled candidate snapshot. For strictly matched
protein/fiber point and range observations, it replays endpoints and values
around existing score, decision, and reason thresholds through the production
deterministic ranker and next-meal-window transform. The report identifies
possible rank swaps, display-set membership changes, and candidate-level score,
decision, explanation, or feature changes. Unsupported evidence, point/range
conflicts, candidate-order mismatches, AI reranking, and over-budget scenario
sets remain explicitly unassessed. It does not infer probabilities or change
production order or safety gates. This is an application-side extension of the
food-composition research gate; no upstream CDSS code, rules, models, or data
were imported. The checked-in P0 bootstrap seed has no protein/fiber `range`
qualifier (brewed coffee's protein is `<0.5`), so synthetic tests demonstrate
the mechanics but do not show a changed ranking for the default seed catalog.
Full ranking stability, catalog and food-match identity,
preparation/portion conversion, sample uncertainty, and prospective utility
remain open.

The NextMeal page and dashboard now withhold score-ordered candidate cards when
the sensitivity report is missing, stale for the current candidate snapshot,
or detects a pair-order or displayed-set change in tested scenarios. The
explicit page also withholds ranking explanations and position-aligned model
trace rows. The assessment summary remains visible, and the underlying
deterministic result, audit, and upstream decision gates are unchanged. A
matching no-change report still leaves the full rank-stability question open;
this display hold is not a ranker retirement decision or clinical validation.

The FDC importer now preserves a supplied nutrient `amount` as the existing
exact point and records finite source `min`/`max` values as separate,
unselected range evidence when `data_points` is absent or positive. It retains
sample count, median, standard error, derivation/source codes, and related
metadata in the source-document audit; zero sample count is not promoted, and
standard error is not converted into a probability interval. USDA describes
these minima and maxima as observed sample extrema, not confidence limits
([FDC Help](https://fdc.nal.usda.gov/help/), [data dictionary](https://fdc.nal.usda.gov/portal-data/external/dataDictionary)).
This local importer extension is covered by fixtures only; no live source
catalog was imported or copied into the repository, and the built-in P0 seed
still has no protein/fiber ranges.

### Fifth concrete implementation — offline catalog-version diff

`CatalogVersionChangeDiffService` adds a local comparator for two caller-
supplied medication catalog record-set captures. It separates unchanged and
added codes from explicit retirement, replacement, split, merge, ambiguous,
and unresolved cases, preserving the old code/display alongside candidate
identities and evidence references. It never maps by display-name similarity.
Its SHA-256 is an integrity identity rather than a signature; caller-declared
review/license states are not authenticated, and the captures are not verified
publisher releases. The Data Integrity page now accepts these capture and
evidence JSON objects for an ephemeral local comparison. It recomputes capture
digests, rejects unknown fields, shows category counts and at most 20 changed
codes, and clears the result after any input edit. A separate explicit action
scans current active medication selections and the in-memory intake list for
exact old source-code tokens with matching source system and jurisdiction,
then shows aggregate counts only. Neither active selections nor intake rows
bind a catalog release, so matches are potential references rather than
confirmed affected records; multiple changed-code matches remain unattributed.
Relevant owner-state changes clear the scan result. No mapping is applied and
production algorithm eligibility does not change. No RxNorm rows or crosswalks
were transferred.

For a caller-asserted food-catalog diff, a separate action now matches exact
`FoodItem.sourceFoodCode` values and saved meal-line `foodId` references through
the current local food catalog, requiring the same source system and
jurisdiction. The preview returns only aggregate food-entry, meal-line, and
meal counts; it reads no serving quantities and expires when account, source
food identity, or meal-line identity changes. Food and meal records do not bind
the compared release, so these matches also remain potential references.

The comparison still lacks complete verified publisher snapshots,
release-bound confirmed affected records, owner-bound expected-revision
confirmation, durable rollback/audit links, and runtime algorithm abstention
for unresolved medication or food mappings. The Data Integrity preview reports
only the caller-supplied subset and exact-token counts; it does not establish
catalog completeness or terminology conformance.

The synthetic rule-result-to-card mapping now has a local diagnostics
workbench. Suggestion cards, `systemActions`, real patient payloads, remote
FHIR prefetch, SMART launch, production CDS services, and clinical rule
activation remain outside scope until the product context, source governance,
security model, and independent review are established.

## Additional systems to evaluate

[OpenMRS Drools](https://github.com/openmrs/openmrs-module-drools) documents
rule outputs for flags, alerts, tasks, and forms. This is a useful comparison
for how a CDSS routes rule results into user work, but ParkinSUM's engine is a
local educational prototype with different data and deployment boundaries.
The current source is pinned in the concept-only inventory; no Drools runtime,
OpenMRS data model, patient alert, or clinical recommendation was imported.
ParkinSUM's existing `HumanReviewTicketRecord` worklist is explicitly limited
to release/runtime governance blockers and lacks assignment, permission, and
multi-reviewer workflows; it should not be described as an OpenMRS-style
per-patient alert queue (`lib/domain/entities/cdss_records.dart`).

The OpenMRS comparison is now reflected only as a local workflow convenience:
CareWorkspace lets the account holder filter current prompts into open,
unread/review-needed, and snoozed views, or inspect all prompts including
history. Each view preserves the existing newest-first chronology. This does
not create OpenMRS-style patient flags, alerts, assignments, or clinician task
lists; the filters describe owner-recorded workflow state and do not imply
clinical urgency or priority.

[OpenEMR](https://github.com/openemr/openemr/commit/e01d65b33858e82c11892471001dd3d9963a27bf)
provides another EHR-integrated clinical decision-rule reference. Its pinned
`library/clinical_rules.php` reads bibliographic citation, developer, funding
source, release version, web reference, and linked-CDS metadata for a rule,
and its reminder path logs the current action set against prior state. The
GPL-3.0 repository is concept-only here. The local synthetic Rule Audit Trail
and CareWorkspace follow-up history now share a local source-reference
projection. The audit view expands each attached source ID into the existing
registry's title, organization, type, jurisdiction, dates, URL, status, and
license note; the follow-up view shows the same details when its ID resolves in
the local food or clinical-evidence registries. Both preserve reference order
and leave unresolved IDs visible without guessed metadata. This does not fetch
sources, create patient alerts, or verify that a citation supports a rule or
applies to an individual.

The medication source-review page now adds a separate, read-only historical
evidence view. The account holder selects an event time and a knowledge-time
cutoff in UTC; later assertion and review-decision details stay hidden, and a
changed source graph invalidates the projection. This work extends provenance
inspection only. Schema v3 labels aggregate quarantine markers without an
independent knowledge time as unresolved, excludes them from the historical
graph, and warns that the projection is incomplete rather than assigning a
backfilled time. The current dose-result gate continues to block quarantined
evidence. This does not create an EHR-style reminder engine, resolve a
conflict, or change the gate.

The [OpenCDS project overview](https://www.opencds.org/) currently describes a
Java engine, CDS Hooks/FHIR and HL7 DSS/vMR client options, and CQL as future
support. Its [resources page](https://www.opencds.org/pages/resources) points to
the two Bitbucket projects pinned above. The core's pinned `LICENSE.txt` and
the examples' pinned Maven POM both declare Apache-2.0; Bitbucket did not return
a machine-detected SPDX value, so both records remain declared-only. This is a
useful comparison for service and adapter boundaries, not evidence that OpenCDS
currently executes CQL or can be deployed inside ParkinSUM. Source-level
security, build, dependency, and rule-content review remain open.

[CDS4CPM](https://github.com/cqframework/cds4cpm/tree/e73c2d2953aaad08f09428a6e70d5a07c5c7db31)
adds a chronic-pain shared-decision-making implementation guide, while its
[DBCG sandbox](https://github.com/DBCG/cds4cpm-sandbox/tree/9266b4137e47d7a84553b3040dfc2c12e9e6d3f9)
documents how MyPain, PainManager, CQF-Ruler, and a SMART launcher fit together.
The guide's system-design document is explicitly unfinished, and the sandbox
README describes disabling browser web security and loading a sample-patient
bundle. This is useful system-boundary evidence only: no patient bundle,
service, SMART configuration, pain-management content, or source was reviewed
or transferred.

The [SNOMED-CT FHIR CDS Service Demonstrator](https://github.com/IHTSDO/snomed-fhir-cds-service/tree/be6b5e6a8d636636cdef55310073857c92880574)
is a more direct comparison for a rule-driven service: the pinned README
describes medication-order and allergy hooks as well as diagnostic pathways,
with three-valued handling of unknown observations. It explicitly labels the
software a demonstration. Its root `LICENSE.md` declares Apache-2.0 while
GitHub reports `NOASSERTION`; the spreadsheet rule tables, terminology assets,
and any SNOMED content permissions were not reviewed, so only the software
license signal is recorded here.

[SwissTPH/TRICC](https://github.com/SwissTPH/tricc/tree/b8ee6dc4a9f0e89372f59beb6d076684bc070f81)
adds a visual clinical-flow authoring path that generates digital forms for
several platforms. The pinned README lists OpenMRS output as under development
and FHIR output as untested. Its MPL-2.0 project license and active repository
make it a useful authoring-workflow reference, but do not establish that any
generated clinical pathway is suitable for ParkinSUM.

[GenPRES](https://github.com/informedica/GenPRES/tree/9ab8234577075808c7a79475058790cbf37f43de)
adds a medication-order workflow comparison spanning prescribing, preparation,
and administration. Its GPL-3.0 software license does not cover the complete
medication cache, which the README says cannot be freely distributed; the
project also says direct clinical use requires appropriate validation and
regulatory approval. Only the workflow boundary is relevant here.

[Arcwell](https://github.com/arcweb/arcwell/tree/4be1ed002249b397698e1c588b1bbc81a0c28346)
offers a clinical-research platform architecture. Its current repository
contains server, admin, and example components, while the README places an
FHIR bridge and embedded EHR on the roadmap. Those planned integrations are
not evidence of a current FHIR connector or production CDSS deployment.

[NutriKen](https://github.com/abrangel/Nutriken/tree/5eb45263b5478192f5452c474336f463829ef1ea)
is a closer domain reference for nutrition and medication-related research.
The root license is standard MIT, but the README narrows its stated scope to
academic/research use; this conflict needs maintainer/legal resolution before
any transfer. The README also points to external data and DrugBank access, so
those assets require their own rights and provenance checks.

The [food-drug interaction detector](https://github.com/nexorin9/food-drug-interaction-detector/tree/c2147d44ae774681042530310a3fdb247ff176fb)
is a useful search lead for meal/medication rule workflows, but its pinned
repository has one commit and no license file. It is therefore recorded as
unresolved source-available material, not confirmed open-source software, and
no code or interaction rule is reused.

### Additional discovery leads with open pin or rights questions

The [Microsoft Azure Healthcare Digital Quality CQL SDK](https://github.com/microsoft/azure-healthcare-digital-quality-cql-sdk)
is pinned at commit
[`c2f1335543d0e385104a42e028fc10141b729a9f`](https://github.com/microsoft/azure-healthcare-digital-quality-cql-sdk/commit/c2f1335543d0e385104a42e028fc10141b729a9f)
as an adjacent execution-engine reference, not a standalone CDSS. Its pinned
[README](https://github.com/microsoft/azure-healthcare-digital-quality-cql-sdk/blob/c2f1335543d0e385104a42e028fc10141b729a9f/README.md)
describes SDK 0.7.0 compiling CQL/ELM to parameterized PostgreSQL SQL over
FHIR R4 JSONB and lists CMS122v11, CMS165v9, and ePC-02 measure examples. The
pinned [LICENSE](https://github.com/microsoft/azure-healthcare-digital-quality-cql-sdk/blob/c2f1335543d0e385104a42e028fc10141b729a9f/LICENSE)
declares MIT for the SDK source; the README explicitly excludes third-party
measure specifications, ValueSets, and code systems from that grant. The
inventory keeps the SDK concept-only and holds `measures/`, test fixtures, and
PostgreSQL terminology assets in three separate unresolved categories. The
repository's account of its Firely/NCQA lineage and listed features are not
local execution evidence. It may inform a future synthetic cross-engine
experiment, but is not a point-of-care PlanDefinition service or a Flutter
dependency. No SDK code, measure content, ValueSet, fixture, or FHIR data was
transferred or executed locally.

The [AHRQ CDS Connect Authoring Tool](https://github.com/AHRQ-CDS/AHRQ-CDS-Connect-Authoring-Tool)
is an additional historical authoring lead. Its current repository page describes
concept templates with modifiers such as “most recent” and value comparisons,
and its root README declares Apache-2.0. AHRQ states that the hosted CDS Connect
Repository and Authoring Tool went offline on April 28, 2025; further work moved
to the HL7 CDS Connect Community Edition and CQL Studio. The repository's exact
current commit could not be resolved in this review, so this lead is intentionally
outside the pinned influence inventory. The transferable idea is a typed,
versioned authoring template that makes each modifier reviewable before CQL
generation. ParkinSUM now implements a first developer-only template kind that
binds an explicit versioned ValueSet and integer count modifier to Patient and
Observation data requirements, then compiles the generated CQL to ELM. It is a
synthetic draft preview only; it does not resolve terminology, evaluate rules,
persist or activate a Library, or run in the app. See
`tool/cql_concept_template_preview.mjs` and
`docs/CQL_RULE_DIFFERENTIAL.md`. The historical AHRQ source remains an
unpinned reference; no upstream code, CQL, rules, or artifacts were
transferred.


The [Reason Framework](https://github.com/reason-healthcare/reason-framework)
is a pinned, MIT-licensed architecture reference for R5 CPG execution and CDS
service workflows. Its latest reviewed commit is
`2e8d91daf360f184e6c98f700031414829c64921`; it is included in the concept-only
inventory. The README's R5 `PlanDefinition/$apply` and test-support structure
motivates the bounded synthetic contract probe above. No code, guideline,
terminology, test fixture, or patient data was transferred.

**ARIA (Wiqi Lee)** is pinned in the influence inventory at [commit `719693b93f9b9b32c1da8169caa1073e5bd816c3`](https://github.com/wiqilee/ARIA/commit/719693b93f9b9b32c1da8169caa1073e5bd816c3). Its repository page reports MIT; the pinned tree contains `mcp-server/src/data/beers_stopp.json` and `renal_dosing.json`, whose clinical-rule and data terms remain separate unresolved holds. Its README also names a hosted Gemini model and external data sources. These project claims are not independent clinical validation; no code, data, model output, or recommendation was transferred.

**MD2SKILL** is now pinned at [commit `1e539eba7bff01b3a0a9abd3bd314398b42d2b89`](https://github.com/dromlakhani/MD2SKILL/commit/1e539eba7bff01b3a0a9abd3bd314398b42d2b89). Its [README](https://github.com/dromlakhani/MD2SKILL/blob/1e539eba7bff01b3a0a9abd3bd314398b42d2b89/README.md) advertises 888 guideline-derived prompt skills across 11 specialties and claims MIT, but the pinned public root listing has no separate `LICENSE` file. The repository therefore remains `NOASSERTION` / unresolved, and `skills/` has its own unresolved clinical-rule asset hold. It is recorded as a concept-only lead, not confirmed open-source software or a deterministic CDSS engine. The advertised skill count and clinical workflow content have not been independently validated; no prompt or guideline-derived content was transferred.

Arden2ByteCode and the two openEHR repositories above now have exact source
pins and repository-level license evidence in the concept-only inventory.
That pinning does not replace review of Arden2ByteCode's remaining dependency
notices, establish that `gdl-tools` implements current GDL2, or authorize use
of any GDL clinical-content example.

The timeline also supports a bounded, owner-controlled FHIR R4 collection for
account-entered symptoms and self-reported motor states. The implementation
uses the FHIR R4 `Observation`, `Bundle`, and `dataAbsentReason` structures;
its project-specific codes are not LOINC or SNOMED CT mappings, and are not
published terminology resources. Collection entries use fresh random UUID
fullUrls instead of local record IDs. This fills a local interoperability gap
without importing code or clinical content from any reviewed CDSS project.
Structural validation covers six manufactured Observation states and the
collection Bundle using the pinned HL7 validator; terminology lookup is
disabled, so this is not general FHIR conformance or clinical validation. See
[`FHIR_R4_SYMPTOM_MOTOR_OBSERVATIONS.md`](FHIR_R4_SYMPTOM_MOTOR_OBSERVATIONS.md).

The timeline now also combines its bounded blood-pressure and symptom/motor
windows in one owner-controlled FHIR R4 `Bundle.type=collection` preview, using
one manually supplied Patient reference across every Observation. This adds a
local handoff format without contacting an EHR or changing the existing
SMART-on-FHIR sandbox boundary. The combined mapper and validator checks are
documented in
[`FHIR_R4_PERSONAL_OBSERVATION_COLLECTION.md`](FHIR_R4_PERSONAL_OBSERVATION_COLLECTION.md).

The CareWorkspace also previews account-entered medication discussion items as a
bounded FHIR R4 `Bundle.type=collection` of `MedicationStatement` resources.
The account owner supplies a Patient reference; local record and recorder IDs,
ingredient labels, categories, and questions are omitted, and no medication
codes are invented. The status is still an unverified account entry, so the UI
warns that receiving systems may treat it as a medication-use statement and
requires separate explicit copy. This closes a local handoff gap; it does not
add medication reconciliation, Patient resolution, or EHR exchange. The pinned
HL7 validator gate includes synthetic statement and collection resources among
eleven FHIR R4 core checks with terminology lookup disabled. See
[`FHIR_R4_OWNER_REPORTED_MEDICATION_STATEMENTS.md`](FHIR_R4_OWNER_REPORTED_MEDICATION_STATEMENTS.md) and the [FHIR R4 MedicationStatement specification](https://hl7.org/fhir/R4/medicationstatement.html).

The medication timeline now has a per-entry FHIR R4 MedicationStatement
preview. It exports the selected event only, keeps status `unknown`, maps the
catalog label and original dosage note as text without coding or parsing, and
requires an explicit Patient reference before local preview and separate
clipboard copy. It omits the app's parsed amount/unit and any assertion time
that was not recorded. A saved UTC DateTime retains its full timestamp; a local
DateTime without its original offset is reduced to date precision. The resource
includes a generated note that identifies the entry as user-entered and
unverified. This is a report, not evidence of a verified administration or
current regimen, and it does not contact an EHR. See
[`FHIR_R4_TIMELINE_MEDICATION_INTAKE.md`](FHIR_R4_TIMELINE_MEDICATION_INTAKE.md),
the [FHIR R4 MedicationStatement resource](https://hl7.org/fhir/R4/medicationstatement.html),
and the [FHIR R4 dateTime datatype](https://hl7.org/fhir/R4/datatypes.html#dateTime).

A separate diagnostics page now accepts a single FHIR R4 MedicationStatement or bounded collection Bundle for an offline input preview. It binds a caller-declared release, jurisdiction and exact Patient reference; keeps source status and date precision as reported; hashes the exact pasted bytes; and holds unknown or unprojected fields. Medication coding is unresolved and dosage text is not parsed. The page does not persist or send the input, resolve identity, validate a profile or establish medication use. See [`FHIR_R4_MEDICATION_STATEMENT_IMPORT_PREVIEW.md`](FHIR_R4_MEDICATION_STATEMENT_IMPORT_PREVIEW.md).

A companion diagnostics page previews one FHIR R4 MedicationRequest or a
separate collection Bundle. It retains the required request status and intent
as distinct source fields, plus exact Patient scope and lexical `authoredOn`
precision; `entered-in-error`, `doNotPerform`, and any known-but-unprojected or
unknown fields remain held. Medication reference and dosage text are not
resolved or parsed. FHIR defines this resource as a request in a workflow, not
evidence that medication was dispensed, administered, or taken. The page is
memory-only and never feeds a CDSS rule. See
[`FHIR_R4_MEDICATION_REQUEST_IMPORT_PREVIEW.md`](FHIR_R4_MEDICATION_REQUEST_IMPORT_PREVIEW.md)
and the [FHIR R4 MedicationRequest specification](https://hl7.org/fhir/R4/medicationrequest.html).

A separate local diagnostics preview now projects selected fields from one
FHIR R4 `AllergyIntolerance` or a collection Bundle. It keeps
`clinicalStatus` and `verificationStatus` as separate source-reported concepts,
preserves terminology and date strings without lookup or normalization, and
holds `entered-in-error`, mismatched Patient scope, invalid status/choice
constraints, and unknown or unprojected fields. FHIR defines this resource as
a patient-specific susceptibility record with distinct clinical and
verification statuses; the preview makes no allergy, causality, safety, or
conformance determination and never feeds a CDSS rule. See the
[FHIR R4 AllergyIntolerance preview contract](FHIR_R4_ALLERGY_INTOLERANCE_IMPORT_PREVIEW.md),
the [FHIR R4 AllergyIntolerance specification](https://hl7.org/fhir/R4/allergyintolerance.html),
and its [clinical-status](https://hl7.org/fhir/R4/valueset-allergyintolerance-clinical.html)
and [verification-status](https://hl7.org/fhir/R4/valueset-allergyintolerance-verification.html)
value sets. This adds one offline data surface to the broader open-source CDSS
comparison; it does not adopt the SNOMED demonstrator's rule tables or
terminology assets, whose separate review boundary remains in force.

## References

- [SMART App Launch v2.2.0 — launch and authorization](https://hl7.org/fhir/smart-app-launch/STU2.2/app-launch.html)
- [SMART App Launch v2.2.0 — scopes and launch context](https://hl7.org/fhir/smart-app-launch/STU2.2/scopes-and-launch-context.html)
- [SMART App Launch v2.2.0 — conformance and discovery metadata](https://hl7.org/fhir/smart-app-launch/STU2.2/conformance.html)
- [RFC 6749 — OAuth 2.0 Authorization Framework](https://www.rfc-editor.org/rfc/rfc6749.html)
- [AHRQ CQL Services README and license](https://github.com/AHRQ-CDS/AHRQ-CDS-Connect-CQL-SERVICES)
- [AHRQ CQL Testing Framework pinned README](https://github.com/AHRQ-CDS/CQL-Testing-Framework/blob/60aae55fbab5cb7ad5aea8039e33148e42653954/README.md)
- [AHRQ CQL Testing Framework pinned Apache-2.0 license](https://github.com/AHRQ-CDS/CQL-Testing-Framework/blob/60aae55fbab5cb7ad5aea8039e33148e42653954/LICENSE)
- [AHRQ CQL Testing Framework pinned package metadata](https://github.com/AHRQ-CDS/CQL-Testing-Framework/blob/60aae55fbab5cb7ad5aea8039e33148e42653954/package.json)
- [AHRQ CQL Testing Framework pinned commit](https://github.com/AHRQ-CDS/CQL-Testing-Framework/commit/60aae55fbab5cb7ad5aea8039e33148e42653954)
- [PRANA pinned README](https://github.com/hodanesthtmcvns-stack/jk/blob/11fd6cd52d561c428682866b70b187bcb18e7c40/README.md)
- [PRANA pinned GNU GPL-3.0 license](https://github.com/hodanesthtmcvns-stack/jk/blob/11fd6cd52d561c428682866b70b187bcb18e7c40/LICENSE)
- [PRANA pinned commit](https://github.com/hodanesthtmcvns-stack/jk/commit/11fd6cd52d561c428682866b70b187bcb18e7c40)
- [Two-stage Parkinson medication prediction MLHC 2025 paper](https://proceedings.mlr.press/v298/diaz-rincon25a.html)
- [Two-stage pinned README](https://github.com/rdiazrincon/two-stage_conformal_pd/blob/4f9fbcd537b9bb0592638e843d9ca018fc34e681/README.md)
- [Two-stage pinned Clear BSD license](https://github.com/rdiazrincon/two-stage_conformal_pd/blob/4f9fbcd537b9bb0592638e843d9ca018fc34e681/LICENSE.md)
- [Two-stage pinned notebook](https://github.com/rdiazrincon/two-stage_conformal_pd/blob/4f9fbcd537b9bb0592638e843d9ca018fc34e681/two_stage_conformal_pd.ipynb)
- [CASCADE Conformal Prediction arXiv paper](https://arxiv.org/abs/2605.20468)
- [CASCADE pinned README](https://github.com/rdiazrincon/cascade_conformal_pd/blob/840ae293ac05dadb0d13d08c032c7db4bcf4ab21/README.md)
- [CASCADE pinned Clear BSD license](https://github.com/rdiazrincon/cascade_conformal_pd/blob/840ae293ac05dadb0d13d08c032c7db4bcf4ab21/LICENSE)
- [CASCADE pinned notebook](https://github.com/rdiazrincon/cascade_conformal_pd/blob/840ae293ac05dadb0d13d08c032c7db4bcf4ab21/cascade_conformal_pd_final.ipynb)
- [University of Florida workshop acceptance and cohort summary](https://neuroscience.ufl.edu/2026/07/08/ricardo-diaz-rincon-presents-ai-research-on-parkinsons-care-at-icml-2026/)
- [HL7 CQL reference implementations](https://cql.hl7.org/10-c-referenceimplementations.html)
- [AHRQ status of CDS Connect and CQL Studio](https://digital.ahrq.gov/health-it-tools-and-resources/clinical-decision-support-cds)
- [CQF Ruler and operation migration table](https://github.com/cqframework/cqf-ruler)
- [CDS Hooks Sandbox](https://github.com/cds-hooks/sandbox)
- [CDS4CPM Implementation Guide pinned README](https://github.com/cqframework/cds4cpm/blob/e73c2d2953aaad08f09428a6e70d5a07c5c7db31/README.md)
- [CDS4CPM Implementation Guide pinned license](https://github.com/cqframework/cds4cpm/blob/e73c2d2953aaad08f09428a6e70d5a07c5c7db31/LICENSE)
- [CDS4CPM Sandbox pinned README](https://github.com/DBCG/cds4cpm-sandbox/blob/9266b4137e47d7a84553b3040dfc2c12e9e6d3f9/README.md)
- [CDS4CPM Sandbox pinned license](https://github.com/DBCG/cds4cpm-sandbox/blob/9266b4137e47d7a84553b3040dfc2c12e9e6d3f9/LICENSE)
- [SNOMED-CT FHIR CDS Service Demonstrator pinned README](https://github.com/IHTSDO/snomed-fhir-cds-service/blob/be6b5e6a8d636636cdef55310073857c92880574/README.md)
- [SNOMED-CT FHIR CDS Service Demonstrator pinned license](https://github.com/IHTSDO/snomed-fhir-cds-service/blob/be6b5e6a8d636636cdef55310073857c92880574/LICENSE.md)
- [SRDC SMART CDS pinned README](https://github.com/srdc/smart-on-fhir-cds/blob/89ddcfb7347c5b51aa55de8296e472d571addf65/README.md)
- [SRDC SMART CDS pinned repository license](https://github.com/srdc/smart-on-fhir-cds/blob/89ddcfb7347c5b51aa55de8296e472d571addf65/LICENSE.txt)
- [SRDC SMART CDS pinned NOTICE and bundled asset terms](https://github.com/srdc/smart-on-fhir-cds/blob/89ddcfb7347c5b51aa55de8296e472d571addf65/NOTICE.txt)
- [SwissTPH/TRICC pinned README](https://github.com/SwissTPH/tricc/blob/b8ee6dc4a9f0e89372f59beb6d076684bc070f81/README.md)
- [SwissTPH/TRICC pinned license](https://github.com/SwissTPH/tricc/blob/b8ee6dc4a9f0e89372f59beb6d076684bc070f81/LICENSE)
- [CQF Clinical Reasoning](https://github.com/cqframework/clinical-reasoning)
- [Reason Framework pinned README](https://github.com/reason-healthcare/reason-framework/blob/2e8d91daf360f184e6c98f700031414829c64921/README.md)
- [Reason Framework pinned license](https://github.com/reason-healthcare/reason-framework/blob/2e8d91daf360f184e6c98f700031414829c64921/LICENSE)
- [Reason Framework pinned commit](https://github.com/reason-healthcare/reason-framework/commit/2e8d91daf360f184e6c98f700031414829c64921)
- [Microsoft Azure Healthcare Digital Quality CQL SDK](https://github.com/microsoft/azure-healthcare-digital-quality-cql-sdk)
- [Microsoft CQL SDK license and measure-content boundary](https://github.com/microsoft/azure-healthcare-digital-quality-cql-sdk/blob/main/README.md)
- [CQF cql-execution v3.3.2](https://github.com/cqframework/cql-execution/releases/tag/v3.3.2)
- [CQF CQL Studio](https://github.com/cqframework/cql-studio)
- [Google CQL](https://github.com/google/cql)
- [Using CQL with FHIR conformance requirements](https://hl7.org/fhir/uv/cql/conformance.html)
- [HL7 SDC STU 4 — Form Population](https://hl7.org/fhir/uv/sdc/STU4/en/populate.html)
- [HL7 SDC STU 4 — Questionnaire `$populate` operation](https://hl7.org/fhir/uv/sdc/STU4/en/OperationDefinition-Questionnaire-populate.html)
- [OpenMRS Drools module and license](https://github.com/openmrs/openmrs-module-drools)
- [OpenMRS Drools module README](https://github.com/openmrs/openmrs-module-drools/blob/main/README.md)
- [OpenEMR Clinical Decision Rules pinned source](https://github.com/openemr/openemr/blob/e01d65b33858e82c11892471001dd3d9963a27bf/library/clinical_rules.php)
- [OpenEMR pinned GPL-3.0 license](https://github.com/openemr/openemr/blob/e01d65b33858e82c11892471001dd3d9963a27bf/LICENSE)
- [OpenCDS official project site](https://www.opencds.org/)
- [OpenCDS source repository index](https://www.opencds.org/pages/resources)
- [OpenCDS Core pinned source](https://bitbucket.org/opencds/opencds/commits/c14c8d8313737c23fe9f4fece56b0322355bce6d)
- [OpenCDS Core pinned license](https://bitbucket.org/opencds/opencds/src/c14c8d8313737c23fe9f4fece56b0322355bce6d/LICENSE.txt)
- [OpenCDS examples pinned source](https://bitbucket.org/opencds/opencds-example/commits/322a775f08e11e66206160d828ae417179513528)
- [OpenCDS examples pinned Maven POM](https://bitbucket.org/opencds/opencds-example/src/322a775f08e11e66206160d828ae417179513528/pom.xml)
- [openTriage pinned source and README](https://github.com/dnspangler/openTriage/tree/7644ca32c7c4ee19de57f70173630bde74de3471)
- [openTriage pinned GPL-3.0 license](https://github.com/dnspangler/openTriage/blob/7644ca32c7c4ee19de57f70173630bde74de3471/LICENSE)
- [Arden2ByteCode official repository](https://github.com/PLRI/arden2bytecode)
- [Arden2ByteCode pinned README](https://github.com/PLRI/arden2bytecode/blob/9263f86944a5ebab2a8e5b038d534107d735c806/README.md)
- [Arden2ByteCode pinned license notice](https://github.com/PLRI/arden2bytecode/blob/9263f86944a5ebab2a8e5b038d534107d735c806/LICENSE.md)
- [PLRI Arden2ByteCode project page](https://plri.github.io/arden2bytecode/)
- [Arden2ByteCode custom execution context documentation](https://plri.github.io/arden2bytecode/docs/custom-execution-context/)
- [openEHR GDL2 stable specification](https://specifications.openehr.org/releases/CDS/latest/GDL2.html)
- [GDL2 Editor overview](https://gdl-lang.org/the-project/tools/)
- [openEHR GDL tooling repository](https://github.com/openEHR/gdl-tools)
- [openEHR GDL tooling pinned README](https://github.com/openEHR/gdl-tools/blob/15911c891dfae363c60f81e47cbbd10b257c038f/README.md)
- [openEHR GDL tooling pinned license](https://github.com/openEHR/gdl-tools/blob/15911c891dfae363c60f81e47cbbd10b257c038f/LICENSE.txt)
- [openEHR guideline-model repository](https://github.com/openEHR/gdl-guideline-models)
- [openEHR guideline-model pinned README](https://github.com/openEHR/gdl-guideline-models/blob/f11cfd534d6fb4bd5def85b0c96d6ed17a5defe0/README.md)
- [openEHR guideline-model pinned license](https://github.com/openEHR/gdl-guideline-models/blob/f11cfd534d6fb4bd5def85b0c96d6ed17a5defe0/LICENSE)
- [GenPRES pinned README](https://github.com/informedica/GenPRES/blob/9ab8234577075808c7a79475058790cbf37f43de/README.md)
- [GenPRES pinned GPL-3.0 license](https://github.com/informedica/GenPRES/blob/9ab8234577075808c7a79475058790cbf37f43de/LICENSE)
- [Arcwell pinned README](https://github.com/arcweb/arcwell/blob/4be1ed002249b397698e1c588b1bbc81a0c28346/README.md)
- [Arcwell pinned Apache-2.0 license](https://github.com/arcweb/arcwell/blob/4be1ed002249b397698e1c588b1bbc81a0c28346/LICENSE)
- [NutriKen pinned README](https://github.com/abrangel/Nutriken/blob/5eb45263b5478192f5452c474336f463829ef1ea/README.md)
- [NutriKen pinned root license](https://github.com/abrangel/Nutriken/blob/5eb45263b5478192f5452c474336f463829ef1ea/LICENSE)
- [Food-drug detector pinned commit](https://github.com/nexorin9/food-drug-interaction-detector/commit/c2147d44ae774681042530310a3fdb247ff176fb)
- [Food-drug detector pinned README](https://github.com/nexorin9/food-drug-interaction-detector/blob/c2147d44ae774681042530310a3fdb247ff176fb/README.md)
- [CDS Hooks v2.0.1 specification and extensions](https://cds-hooks.hl7.org/STU2/)
- [CDS Hooks security considerations](https://cds-hooks.org/security-considerations/)


## Medication-safety and Parkinson extensions — reviewed 2026-09-25

The following seven repositories were pinned at their current main commits and added to the influence inventory. Four have a declared, machine-detected repository license, one has a declared license without a detected SPDX result, and two are public source repositories without a root license. All seven remain concept_only; no code, rules, data, models, terminology, or UI assets were transferred.

| Project | Reviewed contribution and limits | Pinned repository terms and disposition |
|---|---|---|
| [PharmExpert V1](https://github.com/AnnaKazarian13/pharmexpert-drug-interactions/tree/facf0f5ad4404482a3163915699ad9fa45869692) | Pairwise drug-interaction lookup with severity, source links, and an explicit “not found is not safe” boundary. Its README says it has no dose, route, or patient-factor engine. | Repository code is MIT. Its pinned [data guide](https://github.com/AnnaKazarian13/pharmexpert-drug-interactions/blob/facf0f5ad4404482a3163915699ad9fa45869692/data/DATA.md) declares DDInter 2.0 data CC BY-NC-SA 4.0 and lists separate ONC mappings and DailyMed overrides. Clinical-rule and data assets stay separately unresolved. |
| [DrugInteract](https://github.com/robinson-vidva/DrugInteract/tree/1d1f4129c623c49add57e3634fcea2a00771fbe6) | Education-only, client-side pairwise lookup that normalizes names through RxNorm and searches openFDA labeling sections 4, 5, and 7. Five lookup states distinguish missing labels, unrecognized drugs, transient failures, and “no interaction mentioned”; it gives no severity grade or clinical recommendation. | Pinned repository code is MIT. Its [data guide](https://github.com/robinson-vidva/DrugInteract/blob/1d1f4129c623c49add57e3634fcea2a00771fbe6/DATA_LICENSE.md) states no dataset is bundled and documents public-domain U.S. government API sources and attribution. No data or source is transferred. |
| [OpenMRS DDI knowledge base](https://github.com/pbiondich/openmrs-ddi-knowledge-base/tree/7e2bd2c245bd33550ca1b14951d6955767026775) | A DDInter-derived knowledge base with RxNorm normalization, a CIEL crosswalk, and a separately named derived tier. Its [healthcare disclaimer](https://github.com/pbiondich/openmrs-ddi-knowledge-base/blob/7e2bd2c245bd33550ca1b14951d6955767026775/HEALTHCARE_DISCLAIMER.md) says coverage is incomplete, missing pairs are knowledge gaps, and severity has not been independently revalidated for a specific patient. | Root LICENSE declares MPL-2.0 with the OpenMRS Healthcare Disclaimer. The pinned [attribution file](https://github.com/pbiondich/openmrs-ddi-knowledge-base/blob/7e2bd2c245bd33550ca1b14951d6955767026775/ATTRIBUTION.md) identifies DDInter terms and says CIEL crosswalk permission is for OpenMRS-supporting work. Rule, data, and terminology assets remain NOASSERTION and not reviewed. |
| [ARIA](https://github.com/wiqilee/ARIA/tree/719693b93f9b9b32c1da8169caa1073e5bd816c3) | A polypharmacy prototype whose README describes interaction graphs, risk timelines, and deprescribing output. It uses a hosted Gemini model and external data sources; its claims are not independent clinical validation. | Repository LICENSE is MIT. The pinned mcp-server/src/data directory contains beers_stopp.json and renal_dosing.json; clinical-rule and data asset terms are separate unresolved holds. |
| [Parkinson Helper](https://github.com/parkinsonhelper/parkinson-helper/tree/540235dcbef2891bdeebc9b05e20c9a0c7c16e34) | An iOS MVP for user-configured medication schedules, tasks, and blood-pressure tracking. It is an adjacent self-management comparator, not a clinical interaction or recommendation engine. | MIT at the pinned revision. The README claims local Core Data storage; privacy behavior was not independently tested. |
| [Parkinson progression CDSS candidate](https://github.com/Andreater/parkinson_cdss/tree/bfe2c677ea5a9a42322a14f466564e56f8f8b9ad) | An exploratory PPMI/Verily smartwatch analysis that predicts MDS-UPDRS progression. Its README reports no statistically significant improvement over baseline (p > 0.05) and says the available follow-up was insufficient. | No root LICENSE at the pinned commit, so it is not confirmed open source. PPMI [data access](https://bank.ppmi-info.org/access-data-specimens/download-data) requires an application and signed [Data Use Agreement](https://www.ppmi-info.org/sites/default/files/docs/ppmi-data-use-agreement.pdf); no cohort data or model was transferred. |
| [NeuroLynk AI candidate](https://github.com/nishnarudkar/NeuroLynk-AI/tree/9f12bbedcc3fac5bbde118ecfc9097ecc6227490) | A hackathon-described Parkinson speech-screening pipeline using 753 vocal features, XGBoost/SHAP, an LLM summary, and a FHIR R4 DiagnosticReport. The repository description is not clinical validation. | No root LICENSE at the pinned commit. Its data and models directories have separate unresolved asset holds; source, model, and data redistribution rights are unconfirmed. |

### FastEval Parkinsonism — video motor-assessment workflow reference — reviewed 2026-09-29

| Project | Reviewed contribution and limits | Pinned terms and disposition |
|---|---|---|
| [FastEval Parkinsonism](https://github.com/yuyuan871111/fast_eval_Parkinsonism/tree/5e7b08ecc8495f9c9a69bba7d224fad69f6fbd16) | The pinned README describes video-based finger-tapping, hand-keypoint prediction, severity estimation, a report, and a separate Hand Predictor API. The 2024 study evaluates finger tapping; this is a motor-assessment workflow reference, not an independently validated ParkinSUM feature or diagnostic claim. The README says tests are not implemented. | The paper identifies the source code as Apache-2.0. The repository's `src/lib/hand_predictor/utils/saved_models` contents retain a separate unresolved `NOASSERTION` model-asset hold. The paper says original videos are not public and access requires author permission, institutional approval, and a proposal. No source, model, or video was copied or executed. |

### Fully Open Meditron — LLM-CDSS pipeline reference — reviewed 2026-09-29

| Project | Reviewed contribution and limits | Pinned terms and disposition |
|---|---|---|
| [Fully Open Meditron](https://github.com/EPFLiGHT/FullyOpenMeditron/tree/65d23a58df15cffdc151fd366083cbe4e49615be) | Its README describes a research pipeline for question, guideline, and clinical-vignette corpus generation, decontamination, model fine-tuning, and medical-benchmark/pairwise-judge evaluation. The README citation field is TODO; project-reported evaluation claims were not independently verified and do not establish clinical validity. | The pinned root LICENSE is Apache-2.0 for repository code. The README separately says the corpus uses a research-use license and models/data are not approved for clinical deployment. Data and listed model releases have separate unresolved `NOASSERTION` asset holds. Concept-only pipeline reference; no source, data, weights, or result assets were transferred or executed. |

### ClinCalc — clinical-calculator engine reference — reviewed 2026-09-29

| Project | Reviewed contribution and limits | Pinned terms and disposition |
|---|---|---|
| [ClinCalc](https://github.com/pacharanero/clincalc/tree/6ed6201b7321cca179053907aaa7baacb2659355) | Its pinned README describes a single Rust scoring engine surfaced through CLI, REST, MCP, and Python, with primary-literature citations, typed schemas, per-calculator license metadata, and published-vector tests. The README limits the project to development, research, education, and evaluation; it says it is not a finished medical device or a standalone basis for individual-patient care decisions. This is a reusable architecture reference, not a Parkinson-specific CDSS or validated ParkinSUM feature. | The pinned root [LICENSE](https://github.com/pacharanero/clincalc/blob/6ed6201b7321cca179053907aaa7baacb2659355/LICENSE) is AGPLv3 text; [Cargo.toml](https://github.com/pacharanero/clincalc/blob/6ed6201b7321cca179053907aaa7baacb2659355/Cargo.toml) declares the compound expression `AGPL-3.0-or-later AND LGPL-3.0-or-later`. The README identifies QRISK3/QFracture as LGPL derivatives and clinical references as CC-BY-SA-4.0, with separate per-calculator license metadata. Because the inventory accepts one SPDX identifier per repository, the mixed repository license remains `NOASSERTION`; its calculator modules have a separate unresolved clinical-rule asset hold. No source, score, test vector, or clinical content was copied or executed. |

The project-wide influence inventory now has 99 pinned repositories: 96 GitHub, two Bitbucket, and one GitLab. Recent CDSS additions include the Microsoft Azure Healthcare Digital Quality CQL SDK as an MIT concept-only execution-engine reference at `c2f1335543d0e385104a42e028fc10141b729a9f`, with separate unresolved holds for its measure examples, test fixtures, and terminology assets; FastEval Parkinsonism as an Apache-2.0 video-based finger-tapping motor-assessment workflow reference with a separate unresolved model-asset hold and non-public study videos; Fully Open Meditron as an Apache-2.0 code reference for an LLM-CDSS corpus-generation, training, and evaluation pipeline with research-use corpus terms and separate unresolved data/model holds; the AHRQ CQL Testing Framework as an Apache-2.0 developer-tool reference with separate unresolved holds for example CQL, FHIR fixtures, and the VSAC cache; the 2025 MLHC two-stage conformal Parkinson medication paper and its 2026 CASCADE successor as method references whose saved result assets remain held; DIKB Evidence Analytics as a mixed-license evidence-provenance reference; GREvaluator as an AGPL-3.0 guideline-evaluation prototype; CAREPATH CDS Specifications as an Apache-2.0 service-definition repository with a separate unresolved clinical-rule asset hold; ClinicClaw as a research/demo FHIR workflow reference with development-mode authentication and unresolved policy/data asset holds; ConGaIT as a proof-of-concept Parkinson gait contestability reference with separate unresolved clinical-decision, data, model, and figure asset holds; LangCare as an MIT FHIR MCP connector with an unresolved clinical-skill asset hold; and MD2SKILL as a pinned guideline-derived prompt-library lead whose README claims MIT but whose root license remains unresolved. All remain concept-only. LangCare's workflow guides were not reviewed for clinical correctness; README claims do not establish performance or safe use. Both Parkinson methods use the same reported 631-admission UF Health cohort lineage; the 2025 repository has a named Clear BSD copyright holder, while the 2026 CASCADE LICENSE retains placeholders. These research reports do not establish clinical validity, external validation, cohort access, or rights to reuse saved outputs. OpenClinical PROformajs was added in an earlier increment. The earlier three typography-provenance sources—Vercel Geist, Adobe Source Serif, and Google Fonts—remain separate from CDSS coverage. The wider inventory has 89 concept-only entries, 15 unresolved repository licenses, and 60 separately tracked asset categories across 38 repositories; 58 clinical-rule, data, model, report, and terminology holds across 36 repositories remain unresolved. The two font-family records have local OFL-1.1 evidence and exact path mappings, while Source Serif reserved-font-name resolution and overall release approval remain open. This source-coverage change does not authorize clinical use.

### Da Vinci burden-reduction provider and payer references — reviewed 2026-09-26

| Project | Reviewed contribution and limits | Pinned terms and disposition |
|---|---|---|
| [Da Vinci BR Provider](https://github.com/HL7-DaVinci/br-provider/tree/9a3215241308467496a98efc020d89b621c1ac35) | The pinned README describes a provider-side HAPI FHIR JPA server implementing CRD, DTR, and PAS workflow reference behavior. This is an interoperability/workflow comparator, not Parkinson nutrition decision support or clinical validation. | GitHub reports MIT at the pinned revision. Added as `concept_only`; only README-level API/workflow concepts are recorded. |
| [Da Vinci BR Payer](https://github.com/HL7-DaVinci/br-payer/tree/5afe15b8afa4450c8f28fe1df2fcf4834accce24) | The pinned README describes payer-side CRD through CDS Hooks, DTR `$questionnaire-package`/`$next-question`, and PAS `$submit`/`$inquire` plus subscriptions. Its pinned [AGENTS.md](https://github.com/HL7-DaVinci/br-payer/blob/5afe15b8afa4450c8f28fe1df2fcf4834accce24/AGENTS.md) describes versioned CQL and FHIR Library/PlanDefinition content in `library/` and generation of test scenarios from that metadata. The local synthetic PlanDefinition now binds to its exact versioned CQL Library and generates six bounded applicability scenarios from its two supported Condition/Observation retrieve definitions; this demonstrates the extension pattern only. | GitHub reports Apache-2.0 for repository code. Clinical-rule assets are separately recorded as `NOASSERTION` and not reviewed; the inventory does not infer their terms from the repository license. Added as `concept_only`; no rules, CQL, FHIR artifacts, test fixtures, or data were transferred. |

These two projects expand the landscape on the provider/payer workflow side while leaving the Parkinson-specific evidence gap intact. The local synthetic artifact binds two PlanDefinition conditions to the exact versioned Library, exercises their Condition/Observation retrieves, and checks the nine paired outcomes under FHIR R4's same-kind AND semantics; it does not import payer coverage rules or claim clinical validation for these demonstrations.

### Additional CDSS references — reviewed 2026-09-26

| Project | Reviewed architecture and evidence boundary | Pinned license and disposition |
|---|---|---|
| [SPICE 2.0 server](https://github.com/Medtronic-LABS/spice-2.0-server/tree/bdc06bbdd855aa65f0692df9218eeb0102bf74b5) | The README describes a population-health backend with separate CQL, FHIR-mapper, offline, notification, authentication, and user services. This is a README-level modularity reference; implementation files, deployment behavior, and clinical rules were not reviewed. | BSD-3-Clause at `bdc06bbdd855aa65f0692df9218eeb0102bf74b5` (`main`, latest listed commit 2025-03-12); `concept_only`. |
| [ClinicClaw](https://github.com/Chesterguan/cliniclaw/tree/fe1378817c730f4de4fa6b4d92f95ed7fc49ce2e) | Its pinned README describes eight FHIR R4 workflows with OPA allow/deny/approval gates, pluggable LLMs, and hash-chained audit. It labels v0.1.0 a research/demo, says authentication is dev-mode passthrough and forbids real-patient deployment; its benchmark results are self-reported and were not independently verified. | Apache-2.0 detected at `fe1378817c730f4de4fa6b4d92f95ed7fc49ce2e` (`main`). Clinical-policy and Synthea FHIR data assets have separate unresolved `NOASSERTION` holds. `concept_only`; no code, policy, fixture, benchmark result, or model output was transferred. |
| [ClinicDx](https://github.com/ClinicDx/ClinicDx/tree/1e329e903f297942160184dbf484874c33bd5e52) | Its README describes hybrid BM25/semantic knowledge retrieval with intent reranking and FHIR R4/OpenMRS integration. The research note reports held-out synthetic evaluation, knowledge-base coverage gaps, and no formal clinical validation; prospective validation remains open. | CC-BY-4.0 at `1e329e903f297942160184dbf484874c33bd5e52` (`main`, 2026-03-16). Separately distributed model weights, guideline knowledge-base content, and clinical-rule assets remain `NOASSERTION` and not reviewed. `concept_only`; no code, weights, rules, or data were transferred. |

### Parkinson contestability and gait CDSS reference — reviewed 2026-09-27

| Project | Reviewed architecture and evidence boundary | Pinned license and disposition |
|---|---|---|
| [ConGaIT](https://github.com/hungdothanh/Con-GaIT/tree/3101558fa527cc3092cb2f7970a4d3ba78808b2d) | Its README presents a Parkinson gait dashboard with 10-second gait windows, CNN Hoehn-and-Yahr staging, LRP explanations, and clinician contest-and-justify interactions. It also describes sending structured feedback to an LLM API and tells users to place an API key in `config.py`; that setup and the model were not executed or security-reviewed. This is a proof-of-concept contestability/UI pattern, not clinical validation or a ParkinSUM rule. | GitHub labels the repository MIT at `3101558fa527cc3092cb2f7970a4d3ba78808b2d` (`main`). Clinical-decision logic, dataset, model weights, and figures have separate unresolved `NOASSERTION` asset holds. `concept_only`; no source, prompt, model, data, or figure was transferred. |

### Agent-facing FHIR workflow reference — reviewed 2026-09-29

| Project | Reviewed architecture and evidence boundary | Pinned license and disposition |
|---|---|---|
| [LangCare MCP FHIR](https://github.com/langcare/langcare-mcp-fhir/tree/d3651b3c8cb940be47c5f376255dded4035a14b8) | Its pinned README describes a FHIR R4 MCP server exposing search, read, create, and update tools, plus 40+ agent-agnostic workflow guides across eight categories. It is a patient-data connector with a prompt/workflow library, not an independently evaluated clinical decision engine; its guide content and safety claims were not clinically reviewed. | The pinned root `LICENSE` is MIT and GitHub labels the repository MIT. The `skills/` clinical workflow library has a separate unresolved `NOASSERTION` / `not_reviewed` asset hold. `concept_only`; no server, skill, clinical rule, data, or patient content was transferred. |

### OpenClinical PROformajs — reviewed 2026-09-27

| Project | Reviewed architecture and evidence boundary | Pinned license and disposition |
|---|---|---|
| [PROformajs](https://gitlab.com/openclinical/proformajs/-/tree/642e8559ab67cfdc11ef156b96f4af13bbc62548) | The pinned README describes a JavaScript engine for PROforma decision protocols. Its design-time protocol/task tree is distinct from a serializable runtime enactment; the pinned [rewinder](https://gitlab.com/openclinical/proformajs/-/blob/642e8559ab67cfdc11ef156b96f4af13bbc62548/src/rewinder.js) supports inspecting prior enactment state and replaying timestamped actions. The README's sample output labels an older version (`0.7.1`), while pinned [package metadata](https://gitlab.com/openclinical/proformajs/-/blob/642e8559ab67cfdc11ef156b96f4af13bbc62548/package.json) says `0.27.1`; the sample output is not treated as current. | The package declares GPL-3.0, while the repository detector returns `NOASSERTION`; the README describes GPLv3/commercial dual licensing. Example clinical-rule assets under the pinned [`etc/`](https://gitlab.com/openclinical/proformajs/-/tree/642e8559ab67cfdc11ef156b96f4af13bbc62548/etc) tree were not reviewed and remain a separate `NOASSERTION` hold. `concept_only`; no engine code, protocol, rule, or example was transferred. |

### First concrete implementation — explicit label-text mention workbench

The diagnostics workbench applies a narrow interaction-pattern idea from DrugInteract without copying its code or data: a user can enter two generic names, explicitly consent to sending them in two requests to the public openFDA Drug Label API, and inspect up to five returned labels per name. The screen performs literal matching for the other entered name across returned `drug_interactions`, `contraindications`, `boxed_warning`, `warnings`, and `warnings_and_cautions` fields and their table variants, retaining each original API field name beside its text. A match is only a text location in a source label; the screen does not normalize names, infer pairwise safety, grade severity, or make a recommendation. A missing text match is not a negative interaction finding. The API supports fielded label searches and documents that its results are unvalidated and should not guide medical-care decisions ([endpoint guide](https://open.fda.gov/apis/drug/label/how-to-use-the-endpoint/), [searchable fields](https://open.fda.gov/apis/drug/label/searchable-fields/), [understanding results](https://open.fda.gov/apis/drug/label/understanding-the-api-results/)).

For each displayed label record, the page also lists the exact source field names where the other entered name appears as literal text, while retaining all returned selected-field text for context. This identifies the location of the match without assigning a clinical meaning to that field. For a returned row with a valid SPL Set ID and version, the page also constructs a copy-only link to that exact-version label in DailyMed; copying the URL makes no request. Opening it outside the app is a separate user action that sends the public label identifier and ordinary network metadata to DailyMed. DailyMed documents the exact-version `drugInfo.cfm?setid=…&version=…` form ([official announcement](https://dailymed.nlm.nih.gov/dailymed/dailymed-announcements-details.cfm?date=2019-09-19)); openFDA defines `set_id` as stable across label revisions and `id` as revision-specific ([field reference](https://open.fda.gov/fields/druglabel_reference.pdf)).

This is an opt-in research interface, not a production CDSS capability. The two names and ordinary network metadata leave the device for the FDA query; the app reads no saved medication or account state and does not persist or log the query or response. Results remain in page memory only for display. Returned coverage can be incomplete, and openFDA name harmonization does not guarantee that every label is represented. Source terms and release-specific privacy/native-network review remain open. No open-source clinical rule, dataset, model, or DrugInteract asset was imported.

### Second concrete implementation — separate RxNorm lexical candidates

The same diagnostics page now offers a separate, opt-in RxNav `approximateTerm` query for the two manually entered terms. It asks for active concepts (`option=1`) and a coarse ten-entry target, caps display at 20 named candidates, and shows only rows whose source is `RXNORM`. RxNav documents that names may be omitted for restricted source vocabularies, that `maxEntries` may return more rows to avoid splitting a rank, and that ranks order lexical matches; the app therefore drops the API match score and treats rank as search ordering only. Candidates remain an ambiguous, user-inspected list; none is preselected or silently substituted. A separate step now lets the user deliberately select two exact candidate display strings for an openFDA label-text lookup. This is a handoff of search text only, not medication-identity matching, and it does not infer an interaction. An empty display is not evidence that a term or medication is absent ([RxNorm approximate-match API](https://lhncbc-portal.lhcaws-prod-pub.nlm.nih.gov/RxNav/APIs/api-RxNorm.getApproximateMatch.html)).

This second live flow has its own consent and exact application-layer egress rule for `rxnav.nlm.nih.gov/REST/approximateTerm.json`, with only `term`, `maxEntries`, and `option`, no authorization header, redirects, or request body, and a 256 KiB response cap. It sends no account or saved medication state; the query and result remain in page memory and are not cached. The screen includes NLM's requested attribution. The page limits each screen instance to one two-name query per second, while NLM's terms state a limit of 20 requests per second per IP and recommend 12–24 hour caching; the app's local delay cannot enforce a shared-IP limit, and the no-cache choice avoids retaining typed medication searches ([RxNav Terms of Service](https://lhncbc-portal.lhcaws-prod-pub.nlm.nih.gov/RxNav/TermsofService.html)). This remains research-only and is not an RxNorm mapping, medication reconciliation, or production CDSS capability. No DrugInteract code, dataset, API score, or clinical rule was transferred.

### Third concrete implementation — selected RxNorm concept properties

After inspecting the approximate-name results, a separate consent and a
candidate-specific button can request the NLM `getRxConceptProperties`
endpoint for one RxCUI that appeared in the most recent candidate response.
The exact HTTPS path is constructed only after numeric RxCUI validation and is
bound as a concrete exact path in the application egress evaluator; the
versioned manifest records the numeric-path template. The request has no
query, credential, or body, and its response is capped at 16 KiB. The result
shows the returned concept name, TTY, synonym, language, suppression marker,
and retrieval time in page memory. It does not resend the typed name, select
the candidate as the user's medication, create an RxNorm mapping, or feed any
rule. The API documents that this endpoint covers active RxNorm concepts and
returns no properties element when an RxCUI is not in its current active data
set; the UI preserves that narrow state and does not call it retired or absent
([RxNorm concept properties API](https://lhncbc-portal.lhcaws-prod-pub.nlm.nih.gov/RxNav/APIs/api-RxNorm.getRxConceptProperties.html)).

This remains current terminology metadata, not evidence that the concept is
the user's medication, a product/ingredient/form/strength mapping, or a
release-pinned terminology row. The separate action and consent keep this
identifier disclosure distinct from the original name lookup, and editing
either entered name clears the property preview. No terminology rows, mapping
data, or clinical rules were imported.

### Fourth concrete implementation — manually selected RxNorm names for FDA label text

The user may select one display name from each of the two RxNorm candidate lists, then separately consent to a second, two-request openFDA lookup using those exact strings in quoted `openfda.generic_name` searches. The input boxes remain unchanged, and each candidate stays labelled as lexical search text rather than confirmed medication identity. Candidate strings outside the existing bounded ASCII query grammar are not selectable in this path. The FDA receives the two selected names and ordinary network metadata; it receives no RxCUI, original typed term, account state, or saved medication data. A dedicated purpose and data class keep these requests separate from the manually entered-name lookup in the egress policy and privacy contract. The result now locates literal mentions across the returned interaction, contraindication, boxed-warning, and warning fields while showing the source field; missing records or text are not negative interaction findings, and no severity, recommendation, or rule input is produced. openFDA documents fielded search syntax and quoted phrase queries ([label endpoint guide](https://open.fda.gov/apis/drug/label/how-to-use-the-endpoint/), [query syntax](https://open.fda.gov/apis/query-syntax/)). No DrugInteract source, code, dataset, or interaction rules were copied.

### Fifth concrete implementation — selected RxNorm concept history status

The candidate inspector now has a third, separately consented action for one RxCUI returned by the most recent name search. It calls only the exact RxNav `getRxcuiHistoryStatus` path, sends no original name or query parameters, and caps the response at 64 KiB. The bounded page-memory preview shows the NLM-reported status, release bounds, current/active dates and, for a remapped concept, up to 20 replacement rows with their names, term types and active flags. The endpoint documents the `Active`, `Obsolete`, `Remapped`, `Quantified`, `NotCurrent` and `Unknown` status values; NLM's status-change note explains the added historical distinctions and that a remapped concept can have replacement concepts ([official history/status API](https://lhncbc.nlm.nih.gov/RxNav/APIs/api-RxNorm.getRxcuiHistoryStatus.html), [NLM status-change note](https://lhncbc.nlm.nih.gov/RxNav/news/HistoryStatus-Changes-202303.html)).

Replacement RxCUIs remain unselected candidates; the app never follows them, changes a medication record, confirms identity, or supplies terminology history to a clinical rule. The copy explicitly distinguishes `NotCurrent` from proof that a medicine is absent, and describes `Unknown` only as RxNorm release history. This keeps the new surface useful for manually resolving stale terminology while preserving the project’s open P0 requirements for governed, release-pinned mappings, independent verification, and medication-identity review. The lookup has a dedicated purpose and data class in the egress manifest, store privacy contract, and source registry; editing either entered name clears the preview. No RxNorm archive or mapping rows, open-source rules, or clinical assets were imported.

### Sixth concrete implementation — FHIR R4 Condition source preview

The Engineering Diagnostics workbench now accepts one FHIR R4 `Condition` or
a bounded collection Bundle. It binds a caller-declared FHIR release,
jurisdiction, and exact Patient reference; retains source code/category fields,
lexical dates, and distinct clinical and verification statuses; and holds
unmapped fields plus selected R4 status inconsistencies. It makes no
terminology request, persistence change, diagnosis conclusion, or CDSS rule
call. This adds a read-only source surface alongside medication and allergy
previews, inspired by the FHIR/diagnosis data boundaries visible in the
SNOMED-CT demonstrator; no demonstrator code, spreadsheet, terminology, or
clinical rule was transferred. The preview is not a general FHIR validator or
a verified problem list. See
[`FHIR_R4_CONDITION_IMPORT_PREVIEW.md`](FHIR_R4_CONDITION_IMPORT_PREVIEW.md)
and the [FHIR R4 Condition specification](https://hl7.org/fhir/R4/condition.html).

### Seventh concrete implementation — MedicationAdministration source preview

Engineering Diagnostics now previews one FHIR R4 `MedicationAdministration`
or a bounded collection Bundle. It keeps the event's source status, medication
coding and effective time distinct from MedicationRequest orders and
MedicationStatement reports. `entered-in-error`, Patient mismatches, dosage,
and any other unknown or unprojected fields remain held; the input stays in
memory and cannot enter a CDSS rule. FHIR defines this resource as a workflow
event describing medication consumption or administration, but a pasted
record is not proof that a dose was administered or taken. No terminology,
clinical content, or code was transferred from the reviewed projects. See
[`FHIR_R4_MEDICATION_ADMINISTRATION_IMPORT_PREVIEW.md`](FHIR_R4_MEDICATION_ADMINISTRATION_IMPORT_PREVIEW.md)
and the [FHIR R4 MedicationAdministration specification](https://hl7.org/fhir/R4/medicationadministration.html).

### Eighth concrete implementation — MedicationDispense source preview

Engineering Diagnostics now previews one FHIR R4 MedicationDispense or a
bounded collection Bundle. It preserves the dispense source status, medication
coding, category/type/reason, reported quantity and days supply, and lexical
preparation and handover times. These fields remain source claims: a supply or
handover event does not prove pickup, use, or adherence. Unknown or
unprojected fields, including dosage instructions and medication references,
stay held; the input remains in memory and cannot enter a CDSS rule. FHIR
separates MedicationDispense supply events from MedicationRequest orders,
MedicationAdministration events, and MedicationStatement reports. This
extends the local interoperability surface without importing an external
project's code, terminology, dataset, or clinical rules. See
[FHIR_R4_MEDICATION_DISPENSE_IMPORT_PREVIEW.md](FHIR_R4_MEDICATION_DISPENSE_IMPORT_PREVIEW.md)
and the [FHIR R4 MedicationDispense specification](https://hl7.org/fhir/R4/medicationdispense.html).

### Ninth concrete implementation — MedicationDispense CQL retrieval differential

The development-only CQL gate now has a fixed 11-case FHIR R4 MedicationDispense
corpus. Google CQL, the pinned CQF JavaScript translator/executor, and the CQF
JVM engine evaluate resource presence and all nine status predicates in a
declared Patient context; an absent dispense and a foreign-subject dispense
exercise the negative and scope-filter paths. Reports retain case labels,
outcomes, engine identities, and the fixture digest, while omitting resource
contents and synthetic identifiers. The schema-v16 composite runner added the
JVM comparison. The schema-v17 composite for this MedicationDispense increment
passed on
2026-09-26 with the isolated Go 1.26.8 toolchain, direct Dart VM execution, and
Java 17 compilation against the cached CQF dependency classpath; temporary
launchers bypassed this host's restricted Gradle lock service and Dart package
hooks, so the official Gradle task launcher remains unverified. This is bounded
development evidence, not FHIR or CQL conformance, dispensing accuracy, pickup,
medication use, adherence, or clinical decision support. See
[the differential contract](CQL_RULE_DIFFERENTIAL.md) and [FHIR R4
MedicationDispense](https://hl7.org/fhir/R4/medicationdispense.html).

### Tenth concrete implementation — MedicationAdministration CQL retrieval differential

The same development-only gate now includes nine fixed synthetic FHIR R4
MedicationAdministration cases: all seven resource statuses, no resource, and
a resource whose subject is outside the declared Patient context. Google CQL
parses the authored CQL source; the pinned CQF JavaScript and JVM paths check
the same existence and exact-status predicates. All three paths match the
expected Booleans and drop the foreign-subject resource. The case report keeps
only labels, Boolean outcomes, engine identities, and the fixture digest. CQF
JavaScript and JVM share one implementation family, so their agreement is
platform evidence. This does not validate doses, prove administration or use,
measure adherence, provide a clinical recommendation, or establish general
FHIR/CQL conformance. No external CDSS code, clinical rule, terminology, or
patient dataset was added. See [the differential contract](CQL_RULE_DIFFERENTIAL.md)
and [FHIR R4 MedicationAdministration](https://hl7.org/fhir/R4/medicationadministration.html).

### Eleventh concrete implementation — AllergyIntolerance CQL retrieval differential

The development-only CQL gate now includes six fixed synthetic FHIR R4
AllergyIntolerance cases. They cover all three `clinicalStatus` values and all
four `verificationStatus` values, including `entered-in-error` without
`clinicalStatus`, alongside absent-resource and foreign-Patient cases. Google
CQL, the pinned CQF JavaScript translator/executor, and CQF JVM match the same
eight Boolean retrieval predicates and each filter the foreign resource. The
complete schema-v19 `npm run cql:diff` passed on 2026-09-26 using the isolated
Go toolchain, direct Dart VM, and Java 17 with cached CQF dependencies; temporary
launchers bypassed this host's Gradle lock service and Dart package hooks, so
the official Gradle task launcher remains unverified. The report contains fixed
case labels, Boolean outcomes, engine identities, and the fixture digest only.
FHIR R4 treats AllergyIntolerance as an individual's susceptibility to a
substance, separate from circumstance-based drug-food interactions. This
retrieval check makes no allergy, interaction, or safety interpretation. No
upstream CDSS rules, terminology content, or patient datasets were copied. See
[the differential contract](CQL_RULE_DIFFERENTIAL.md) and the official [FHIR R4
AllergyIntolerance resource](https://hl7.org/fhir/R4/allergyintolerance.html)
with its [clinical status](https://hl7.org/fhir/R4/valueset-allergyintolerance-clinical.html)
and [verification status](https://hl7.org/fhir/R4/valueset-allergyintolerance-verification.html)
value sets.

### Twelfth concrete implementation — Condition status CQL retrieval differential

The FHIR R4 development gate now tests the six `Condition.clinicalStatus`
codes and the six `Condition.verificationStatus` codes independently in a
nine-case fixed corpus. It includes `entered-in-error` without
`clinicalStatus`, absence, and a foreign-Patient subject. Google CQL Go, CQF
JavaScript, and CQF JVM match all thirteen Boolean predicates and filter the
foreign resource. The complete schema-v20 `npm run cql:diff` passed with the
isolated Go, Dart VM, and Java/JVM toolchains; the custom launcher used for this
host's restricted Gradle environment means the official Gradle task launch
remains unverified. The report projects only case labels, Boolean outcomes,
engine identities, and a corpus digest. It does not interpret diagnoses,
resolve terminology, or move any result into app algorithms. The status codes
and `entered-in-error` invariant follow the official [FHIR R4 Condition
resource](https://hl7.org/fhir/R4/condition.html), [clinical status value
set](https://hl7.org/fhir/R4/valueset-condition-clinical.html), and
[verification status value set](https://hl7.org/fhir/R4/valueset-condition-ver-status.html).
No upstream CDSS rules, terminology tables, or patient data were transferred.

### Thirteenth concrete implementation — PlanDefinition-to-CQL binding

The fixed FHIR R4 artifact probe now includes one synthetic PlanDefinition
alongside the Questionnaire and two Libraries. It pins the exact versioned
primary Library and one `applicability` condition whose `text/cql` expression
resolves to a Boolean definition by title. The schema-v6 artifact report records
the binding identity, resolved condition, and generated applicability outcomes
without emitting CQL source or FHIR resource contents. This follows the [HL7 CPG Computable Plan Definition
profile](https://hl7.org/fhir/uv/cpg/StructureDefinition-cpg-computableplandefinition.html)
and the FHIR R4 [`text/cql` expression language](https://hl7.org/fhir/R4/valueset-expression-language.html).
It is a strict synthetic authoring-pattern check, not a clinical plan, CQL/FHIR
conformance result, app route, or validated Parkinson decision.

### Fourteenth concrete implementation — PlanDefinition-derived synthetic scenarios

The bound applicability title now drives a narrowly supported scenario
generator. It recognizes the exact Patient-context `exists([Condition])`
definition only after the primary Library's parsed retrieve and matching
Patient-scoped `dataRequirement` have passed validation. The checker creates
three local FHIR R4 Bundles: one matching Condition, no Condition, and one
foreign-subject Condition. The expected Boolean results are true, false, and
false; the foreign resource is filtered before evaluation. Any unsupported
expression shape or retrieve type fails closed. Schema-v6 reports only the
three bounded labels, expected/observed Booleans, match flags, and a drop count;
it excludes generated Patient and resource identifiers, CQL source, and Bundle
content. This is scenario-generation evidence for one synthetic expression,
not clinical rule validation, generalized PlanDefinition execution, or FHIR/CQL
conformance.

### Sixteenth concrete implementation — Combined PlanDefinition applicability conditions

The fixed PlanDefinition now binds both existing Boolean definitions:
`Synthetic Condition Present` and `Synthetic Observation Present`. The generator
derives each retrieve type from the referenced CQL definition and checks that
the primary Library declares the matching Patient-scoped `dataRequirement`.
It creates three scenarios per definition—matching, absent, and foreign-subject—
while retaining the other placeholder resource so unrelated Library outputs
remain exercised. All six outcomes must match: true for each matching resource,
false when the target resource is absent, and false after filtering the foreign
resource. The schema-v8 report identifies the condition title and resource type
for each of the six bounded single-condition outcomes without emitting generated
IDs, CQL source, or Bundles. It adds all nine paired Condition/Observation
states: matching, absent, or foreign-subject for each resource. Both CQL
predicates are evaluated in each state, then their Boolean conjunction is
checked against the expected action applicability. This follows FHIR R4's
[same-kind AND rule for multiple action conditions](https://hl7.org/fhir/R4/plandefinition-definitions.html).
Only these two fixed existence predicates are supported; this does not establish
general PlanDefinition execution, FHIR/CQL conformance, or clinical validation.

### Seventeenth concrete implementation — Local evidence-source metadata search

The diagnostics workspace now searches the existing evidence-source registry
locally with a deterministic, field-weighted BM25-style lexical ranker over
title, organization, source family, document type, jurisdiction, language, and
license note. Results show source identity and matched terms only. Raw payloads,
URLs, checksums, patient records, and clinical rule content are excluded; the
query remains in page memory and is neither persisted nor sent over the network.
This transfers only a small part of ClinicDx's README-level retrieval idea: it is
metadata-only lexical finding, not full-text or semantic retrieval, intent
reranking, or knowledge-base integration. Result order is not evidence quality
or clinical applicability, and no match does not establish that evidence is
absent. No rule or recommendation behavior changes.

The result card now also joins each source to the existing evidence-currency
registry only by exact source ID. It shows each linked claim's source revision,
locally recorded as-of status, review method, observed/review times, and notice
identifier separately from lexical ordering. An unmatched source is explicitly
unassessed; a registry-integrity failure withholds status details. A status
observed after the requested as-of time is treated as unknown by the evidence
gate and cannot be used for an earlier snapshot. This is an offline projection
of reviewed registry data, not a live correction check, evidence-quality grade,
clinical applicability assessment, or provider-disablement attestation.

### Eighteenth concrete implementation — Owner-scoped FHIR R5 meal preview

The timeline now offers a local preview of one selected account-owned meal as a
FHIR R5 `NutritionIntake`-shaped resource. The owner supplies the exact Patient
reference. The resource keeps status `unknown`, emits food names and the app's
food-category labels as uncoded text, and carries the recorded gram amount; it
omits internal meal/food identifiers and derived nutrient totals. A user-entered
time is emitted with a timezone only when the stored timestamp retains one;
otherwise it is date-only. Default and migrated times are omitted. The preview
expires when the account or source meal changes and reaches the clipboard only
after an explicit copy action. It performs no persistence, network request,
or algorithm call.

This narrow preview follows the R5 resource's required status, subject, and
consumed-item shape, but is not a profile-validated or official-validator result.
The base resource is Trial Use; text-only food identity is not terminology
coding, an explicit gram amount does not establish food composition, and the
preview does not verify that a meal was fully consumed or establish clinical
interoperability. See the official [FHIR R5 NutritionIntake
resource](https://hl7.org/fhir/R5/nutritionintake.html), [R5 datatypes and
dateTime precision](https://hl7.org/fhir/R5/datatypes.html), and the FHIR
inspired-view boundary in the [next-wave research note](COMPLETE_APP_NEXT_WAVE_RESEARCH_2026-08-17.md).


### Nineteenth concrete implementation — Synthetic multi-service CDS Hooks dispatch plan

The development tooling now checks a second, intentionally separate discovery
fixture with four synthetic service definitions across `patient-view` and
`order-select`. It rejects duplicate or malformed service IDs, unsupported
hooks, unknown fields, and unbounded service lists. For either supported hook,
the report contains only the matching service IDs in fixture order, bounded
counts, and the fixture digest. It does not resolve endpoints, execute services,
read FHIR resources, or combine responses. This extends the one-service
discovery check with a local dispatch-planning contract inspired by the
multi-service shape described in CAREPATH; its guideline-derived rules,
templates, and clinical content are not used. The contract is synthetic
engineering evidence, not CDS Hooks conformance or clinical validation. See
the official [CDS Hooks v2 specification](https://cds-hooks.hl7.org/STU2/), the
[CAREPATH specifications repository](https://github.com/srdc/carepath-cds-specifications),
and the peer-reviewed [CAREPATH implementation report](https://doi.org/10.3389/fmed.2024.1386689.s002).


### Twentieth concrete implementation — In-app multi-service hook preview

The fixed four-entry metadata registry now also backs a bilingual selector in
the existing engineering diagnostics sandbox. Choosing `patient-view` or
`order-select` displays only the matching service IDs, in registry order. A
Dart test compares the app registry with the JSON dispatch-contract fixture so
the in-app view and command-line contract cannot silently drift. The existing
single-fixture rule-engine run remains a separate action and is not presented
as execution of any registry service. This preview does not resolve endpoints,
invoke services, build prefetch requests, read FHIR data, merge cards, or change
clinical rules. It is a local developer aid, not CDS Hooks conformance or
clinical validation. See the official [CDS Hooks v2 specification](https://cds-hooks.hl7.org/STU2/).


### Twenty-first concrete implementation — Service-scoped CDS Hooks prefetch planning

The four fixed services now declare two small, synthetic prefetch templates
each: a Patient read and a bounded Condition search, both using only the
`{{context.patientId}}` token. For a selected hook, the local planner groups
only byte-identical query templates and retains every requesting service's own
prefetch key. This follows the CDS Hooks v2.0.1 discovery shape and its rule
that prefetch is service-specific; the specification also permits a client to
optimize repeated templates across services. The UI displays the unresolved
templates and service-key assignments without replacing tokens or creating a
FHIR request or resource payload. This verifies a fixed planning contract,
not authorization, query execution, result partitioning in a data plane,
general FHIR search validity, CDS Hooks conformance, or clinical safety. See
the official [CDS Hooks v2.0.1 prefetch guidance](https://cds-hooks.hl7.org/STU2/),
[Patient View context](https://cds-hooks.hl7.org/hooks/patient-view.html), and
[Order Select context](https://cds-hooks.hl7.org/hooks/order-select.html).


### Twenty-second concrete implementation — Fixed synthetic Patient context preview

The bilingual sandbox now shows each approved relative FHIR path after
substituting only the code-owned `synthetic-patient-001` value for one
`{{context.patientId}}` token. The ID is checked against the FHIR R4 `id`
character and 1–64 character length boundary. The app has no field for a
caller-supplied ID, and the preview never sends a request or creates a resource
payload. This demonstrates fixed template binding only; it does not validate
arbitrary FHIR searches, authorization, CDS Hooks conformance, or clinical
behavior. CDS Hooks Patient View and Order Select define `patientId` in their
hook contexts; see the official [CDS Hooks v2.0.1 specification](https://cds-hooks.hl7.org/STU2/),
[Patient View context](https://cds-hooks.hl7.org/hooks/patient-view.html),
[Order Select context](https://cds-hooks.hl7.org/hooks/order-select.html), and
[FHIR R4 id datatype](https://hl7.org/fhir/R4/datatypes.html).


### Twenty-third concrete implementation — Per-service prefetch key-to-path bindings

The multi-service sandbox now also shows a service-first view of the fixed
prefetch plan. For each service registered to the selected hook, it maps only
that service's declared prefetch keys to the approved relative paths; repeated
templates may share a query plan while the key mappings remain separate. The
view contains no returned resource data and builds no service request payload.
CDS Hooks says prefetch data for one service must not be provided to another;
this preview makes the metadata boundary inspectable but does not implement or
prove runtime authorization or data isolation, FHIR query execution, or CDS
Hooks conformance. See the official [CDS Hooks v2.0.1 prefetch guidance](https://cds-hooks.hl7.org/STU2/),
[Patient View context](https://cds-hooks.hl7.org/hooks/patient-view.html), and
[Order Select context](https://cds-hooks.hl7.org/hooks/order-select.html).


### Twenty-fourth concrete implementation — Fixed synthetic FHIR prefetch payloads

The sandbox and offline report now map each service's own prefetch keys to one
fixed, minimal FHIR R4 `Patient` resource and one empty `Condition` searchset
`Bundle`. The Patient contains only its code-owned synthetic id; the Bundle has
`total: 0` and no entries. These fixtures exercise the shape and per-service
key mapping of the optional CDS Hooks `prefetch` object. Nothing is fetched,
posted, persisted, or passed to the rule engine. The empty Bundle is only a
test fixture and says nothing about any person's condition status. CDS Hooks
v2 permits an empty searchset Bundle as a prefetch result; FHIR R4 defines the
resource and Bundle structures. See [CDS Hooks v2.0.1 prefetch guidance](https://cds-hooks.hl7.org/STU2/),
[FHIR R4 Patient](https://hl7.org/fhir/R4/patient.html), and
[FHIR R4 Bundle](https://hl7.org/fhir/R4/bundle.html). This is a strict local
fixture contract, not FHIR conformance, actual query execution, authorization,
runtime data isolation, CDS Hooks conformance, or clinical validation.

### Twenty-fifth concrete implementation — Hook-specific request envelope previews

The offline sandbox and contract report now assemble one request-body preview for
all four fixed services. `patient-view` carries its required synthetic `userId`
and `patientId`; `order-select` also carries a fixed `selections` reference and a
one-entry `draftOrders` collection Bundle with a code-free, draft
`ServiceRequest` placeholder. Each envelope contains only the matching
service's fixed prefetch keys. UUID-shaped `hookInstance` values are static
display tokens, not unique runtime identifiers. The preview omits `fhirServer`
and `fhirAuthorization`, and is never sent. The order placeholder is not a real
order or recommendation. CDS Hooks defines the request envelope and each hook's
context; FHIR R4 defines the ServiceRequest and Bundle structures. See the
official [CDS Hooks v2.0.1 specification](https://cds-hooks.hl7.org/STU2/),
[Patient View context](https://cds-hooks.hl7.org/hooks/patient-view.html),
[Order Select context](https://cds-hooks.hl7.org/hooks/order-select.html),
[FHIR R4 ServiceRequest](https://hl7.org/fhir/R4/servicerequest.html), and
[FHIR R4 Bundle](https://hl7.org/fhir/R4/bundle.html). This is a fixed local
shape exercise, not full FHIR or CDS Hooks conformance, transport, authorization,
runtime service isolation, or clinical validation.

### Twenty-sixth concrete implementation — Prefetch missingness semantics

A separate schema-v1 fixture now assigns one outcome state to each service key
for both hooks. Service A receives the fixed Patient resource and an empty
Condition searchset Bundle; service B receives `subject: null` for its satisfied
Patient read and omits `problem-list` because that prefetch was not satisfied.
The UI labels and request maps preserve the difference: an empty searchset is a
satisfied search with zero matches, `null` is a present key with no resource
value, and an omitted key is absent from the `prefetch` object. CDS Hooks v2
allows the client to satisfy only some templates, requires an unsatisfied key
to be omitted, requires `null` when no data is available for a key, and allows a
search result to be a zero-entry searchset Bundle. No query is executed and no
state is interpreted clinically. See the official [CDS Hooks v2.0.1 prefetch
guidance](https://cds-hooks.hl7.org/STU2/). This is a fixed contract preview,
not evidence of a live service's missing-data behavior, runtime authorization,
service isolation, FHIR conformance, or CDS Hooks conformance.

### Twenty-seventh concrete implementation — Portable synthetic rule-suite checkpoints

The rule-test workbench can now pause after a completed synthetic case and
export a schema-v1 checkpoint for a later local run. The checkpoint binds the
suite ID and content digest, selected rule-pack identity, execution mode, and
ordered completed-case report digests. Resume replays the completed prefix
through the current engine and checks each digest before it runs the remaining
cases; a changed suite, rule pack, mode, prefix, or replayed report fails
closed. The portable JSON contains case IDs and digests rather than case
inputs or full reports, and it is not automatically stored.

medAL-suite's consultation workflow provides a pause-and-resume interaction
pattern; this is a workflow reference only. No medAL code, rule content, or
case data is copied. The feature remains an isolated local synthetic testing
aid: it does not read patient records, transmit data, make clinical
conclusions, activate rules, or establish clinical validation. See the
official [medAL-suite overview](https://medal-suite.com/).

### Twenty-eighth concrete implementation — Per-service CDS Hooks response previews

The multi-service sandbox now previews one response for each fixed registered
service under the selected hook. One service fixture returns a single
`indicator: info` card with a fixed nonclinical summary; its peer returns
`{"cards": []}` to represent no guidance. The view keeps each response
attached to its service ID and does not merge cards or claim an endpoint was
called. CDS Hooks v2.0.1 defines the required response `cards` array and
permits an empty array when a service has no guidance. This fixed synthetic
shape exercise is not a client aggregation policy, live service result, full
CDS Hooks conformance test, or clinical behavior. See the official
[CDS Hooks v2.0.1 response contract](https://cds-hooks.hl7.org/STU2/#response).

### Twenty-ninth concrete implementation — versioned protocol and enactment replay

The sandbox now keeps a versioned, code-owned protocol definition separate
from a fixed enactment preview for each selected hook. Each service contributes
four deterministic events in registry order: service match, prefetch plan,
request preview, and response preview. A replay checkpoint reconstructs an
immutable event prefix and identifies the next event; it does not advance a
service or mutate the preview instance. The bilingual panel can replay from
zero through the complete sequence, and the serialized preview includes only
protocol identity, service IDs, fixed field names, response state, and card
count.

This applies only the protocol/enactment separation and rewind/replay
architecture documented by [OpenClinical PROformajs](https://gitlab.com/openclinical/proformajs/-/tree/642e8559ab67cfdc11ef156b96f4af13bbc62548)
and its pinned [rewinder implementation](https://gitlab.com/openclinical/proformajs/-/blob/642e8559ab67cfdc11ef156b96f4af13bbc62548/src/rewinder.js).
No upstream engine or protocol is copied. The preview makes no service call,
does not read a patient record, persists nothing, and does not aggregate
responses or activate a rule. It is an interaction-pattern exercise, not a
runtime enactment, clinical workflow, CDS Hooks conformance test, or clinical
validation.

### Thirtieth concrete implementation — explicit study-dependency graph

The claim-evidence registry can now record an undirected, source-referenced
dependency edge between two findings. It distinguishes shared cohorts,
overlapping participants, shared publications or datasets, and secondary
analyses. The adjudicator unions these edges transitively with the existing
independence-group assignments before counting independent evidence families;
suspected or unresolved links are conservatively coalesced and held for review.
Self-links, duplicate/reversed edges, missing source references, and endpoints
that do not exist in the body fail closed. Canonical edge identity sorts the
finding IDs, so reversing an edge does not change the synthesis digest. The
Observatory exposes each dependent component and its declared links.

This addresses an evidence-provenance pattern found in the pinned
[DIKB Evidence Analytics README](https://github.com/dbmi-pitt/DIKB-Evidence-analytics/blob/9ffd629db30c41ced224ff2afdf132ce9276ae3f/README),
which describes explicit links among assertions, supporting/opposing evidence,
and assumptions. DIKB's README says licensing varies by subproject, so it is
recorded as mixed-license and concept-only; no source, interaction rule, or
evidence data was copied. These synthetic declarations do not establish that
two real studies overlap or are independent, grade evidence, alter a model,
change a recommendation, or support a patient-specific conclusion.

### Thirty-first concrete implementation — FHIR R4 Encounter context preview

Engineering Diagnostics now accepts one synthetic or de-identified FHIR R4
Encounter, or a bounded collection Bundle. It binds the preview to declared
FHIR 4.0.1, a two-letter jurisdiction code, and the caller's exact Patient
reference; preserves the source status, class Coding fields, and lexical
period endpoints; and withholds `entered-in-error`, Patient mismatches, invalid
values, and every known-but-unprojected or unknown field. The source Patient
reference is not shown. The Encounter status vocabulary follows the official
[FHIR R4 Encounter resource](https://hl7.org/fhir/R4/encounter.html) and
[Encounter status value set](https://hl7.org/fhir/R4/valueset-encounter-status.html).

This expands the project's offline interoperability review surface alongside
the source-mapped medication, Condition, AllergyIntolerance, and Observation
previews. It does not validate an Encounter profile, infer a care setting,
perform terminology lookup, write back to an EHR, or feed a ParkinSUM rule.

### Thirty-second concrete implementation — FHIR R4 Encounter status CQL differential

A fixed synthetic corpus now exercises all nine R4 `Encounter.status` values,
an absent Encounter, and one foreign-Patient Encounter through exact
`Encounter.status` CQL predicates. The same expected Boolean results are
checked by the pinned CQF JavaScript translator/execution path and CQF/JVM
5.3.0. The output retains only case labels and Boolean outcomes; fixture
identifiers stay out of the report. This is a retrieval and patient-scope
contract check, not Encounter validation or clinical interpretation. FHIR R4
states that status alone does not define admission; the differential makes no
such inference, does not touch application algorithms, and performs no
network request or persistence ([Encounter resource](https://hl7.org/fhir/R4/encounter.html),
[Encounter status value set](https://hl7.org/fhir/R4/valueset-encounter-status.html)).

### Thirty-third concrete implementation — synthetic card challenge-and-justify preview

The CDS Hooks sandbox now lets a reviewer challenge its one fixed synthetic
information card by selecting a reason and entering a bounded rationale. The
schema-v1 preview binds the current synthetic input digest and canonical card
SHA-256. It exists only in the diagnostics page's memory, clears when the
reason, rationale or scenario changes, and does not change the card or rule outcome.
The panel warns users not to enter real health or personal data.

This transfers only the contest-and-justify interaction pattern described by
the pinned [ConGaIT README and repository](https://github.com/hungdothanh/Con-GaIT/tree/3101558fa527cc3092cb2f7970a4d3ba78808b2d).
No ConGaIT source, prompt, model, clinical decision, dataset, or figure is
used. No feedback leaves the page or enters an external API. This engineering
prototype does not establish human-factors evidence, clinician workflow
utility, clinical or model validity, CDS Hooks conformance, or a production
feedback system.

### Thirty-fourth concrete implementation — JVM differential for CQL concept templates

The versioned Observation-count template now runs its exact generated CQL
through both the pinned CQF JavaScript translator/executor and CQF JVM 5.3.0.
One bounded offline run checks all five comparator operators against the same
threshold boundaries, non-member code, and foreign-subject cases. A source hash
binds each JVM result to its JavaScript-generated CQL; both paths use fixed
synthetic records and a local in-memory ValueSet expansion. This adds a second
runtime check for the authoring prototype, not an independent CQL
implementation, FHIR validation, terminology service, or clinical validation.

### Thirty-fifth concrete implementation — Versioned CQL Library dependencies

The concept-template artifact advances to output schema v2. Its CQL library
name is derived from a strict template slug without underscores, and the
Library canonical ends with that same name. `relatedArtifact` now records exact
`depends-on` canonicals for the FHIR 4.0.1 ModelInfo Library and the input's
versioned ValueSet; the sole top-level expression is paired with its Boolean
output parameter. This applies selected [HL7 CQL authoring requirements](https://hl7.org/fhir/uv/cql/conformance.html)
to the local draft while leaving it experimental and without a full FHIR/CQL
conformance claim.

### Thirty-sixth concrete implementation — Owner-selected observations per visit report

The care workspace now lets the account holder include or omit each of the
latest 128 locally stored observations for one visit-preparation report. The
default remains all selected; the report and concise agenda disclose the
selection and omission count, while the records remain stored and no rule or
clinical interpretation uses the selection. Future-dated records are counted
separately before applying the owner's selection. This is a local report
control informed by the project's broader patient-data review workflow, not
an adoption of upstream code or a claim of clinical decision support validity.

### Upstream drift review ledger — 2026-09-28

The metadata-only drift workflow now has a separate human-decision schema and
append-only SHA-256 chain. Every decision binds to one exact proposal digest,
the inventory digest, a source identity, reviewer-entered identity and time,
rationale, change classification, and HTTPS evidence references. Accepted,
rejected, deferred, and revoked events remain visible; a baseline artifact is
projected only when the latest decision for every source is accepted, and the
next collector run verifies that artifact against the complete ledger. No
upstream source files, rules, models, data, or reports are downloaded.

This chain detects edits against a retained digest anchor but does not
authenticate a reviewer or establish legal, scientific, clinical, or release
approval. The repository still has no committed baseline or review ledger, and
the workflow has not yet been run against live provider metadata. The P1 drift
revalidation queue item remains open.
