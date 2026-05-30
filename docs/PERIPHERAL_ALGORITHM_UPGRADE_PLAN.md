# Peripheral Support Algorithm Upgrade Plan

Educational/research prototype. Synthetic/demo data only. Not medical advice,
not clinically calibrated, and carries no clinical-validation claim.

## 1. Executive summary

ParkinSUM Companion's **core mechanistic scoring is considered stable** for now
(deterministic time-axis conflict engine, multi-dose traces, replay suite). The
next wave of work targets **peripheral support algorithms** — components that sit
*around* the engine and protect **input quality, explainability, source
governance, testing, privacy, localization, contribution safety, and public
demonstration**.

None of these peripheral algorithms add clinical advice, dosage inference,
diagnosis, monitoring, prediction, or any medical recommendation. They make the
existing educational system more **trustworthy, reviewable, reproducible, and
safe to show publicly** — without changing what the engine concludes.

## 2. Current system baseline

Already shipped (see `docs/CAPABILITY_MATRIX.md`):

- Deterministic **mechanistic replay** (41 synthetic scenarios, banned-phrase scanned).
- **Source-quality perturbation report** (deterministic provenance analysis).
- Local **EvidenceTraceBundle** (non-FHIR pairing of the two inspired views).
- **FHIR-inspired** NutritionIntake + MedicationKnowledge views (`inspired_not_conformant`).
- Conservative **LOINC section-code** trace.
- **FDC nutrient provenance tier** → metadata completeness.
- **Metadata completeness gate** + **source-authority scoring**.
- **Multi-dose medication trace**; **missing ≠ true zero**; **dose passthrough**
  (no hidden dosage inference).
- **Public preflight** + **Firestore rules contract** guardrails.

These are the substrate the peripheral algorithms compose, gate, and report on.

## 3. Safety boundary

ParkinSUM Companion is an educational/research prototype, **not a medical
device**. It does not provide diagnosis, treatment, medication timing, dose
guidance, diet decisions, patient-care guidance, patient monitoring, or clinical
decision support. Every peripheral algorithm below must remain **deterministic,
testable, evidence-linked, non-prescriptive, synthetic/demo-data safe, not
clinically calibrated**, with **no PHI**, **no patient/subject/encounter
semantics**, **no LLM inside the conflict engine**, **no hidden medication dosage
inference**, and **no medical advice**. See §14 (What not to build) and
`docs/PUBLIC_DEMO_BOUNDARY.md`.

## 4. Branch strategy

- `harden-medication-context-and-rule-evidence` is **no longer** the base branch
  for this new series of peripheral support-algorithm work.
- **`peripheral-algorithm-integration`** is the new long-lived base branch,
  created from the then-current `harden-medication-context-and-rule-evidence`
  state.
- All future peripheral feature branches **branch from**
  `peripheral-algorithm-integration`.
- All future peripheral PRs **target** `peripheral-algorithm-integration` unless
  explicitly instructed otherwise.
- This planning document is delivered on `peripheral-algorithm-upgrade-plan`
  (branched from the new base) and its PR targets the new base.

## 5. Design principles

1. **Deterministic** — same inputs → same outputs; no clock/network/LLM in logic.
2. **Additive & peripheral** — no edits to the core mechanistic scoring,
   importers, model constants, or Firebase rules.
3. **Evidence-linked** — reuse `sourceRefs`, the model assumption registry, and
   existing provenance fields; never mint unsupported facts.
4. **Compose, don't recompute** — prefer parsing existing artifacts
   (replay/source-quality/evidence-bundle JSON) over re-running the engine.
5. **`missing_artifact` over fabrication** — if an input artifact is absent, say
   so; never invent numbers or results.
6. **Scanner-safe wording** — avoid the preflight banned phrases; use
   "not clinically calibrated" / "carries no clinical-validation claim" /
   "source-quality signal" / "modeled overlap".
7. **Test-first determinism** — pure units, injectable fakes, fixture parsing;
   no flaky tests that shell out to slow commands.
8. **Non-prescriptive by construction** — every user-facing string flows through
   safety copy + a banned-phrase scan.

## 6. Upgrade taxonomy

| Area | Peripheral algorithms |
| --- | --- |
| Input quality | P1 InputQualityGate |
| Catalog resolution | P2 CatalogResolutionEngine |
| Source governance | P3 SourceVersionDriftChecker, P9 SourceAccessContractChecker |
| Evidence & reproducibility | P4 EvidenceGraphBuilder |
| Testing & fuzzing | P5 SyntheticScenarioFuzzer |
| Explanation copy | P6 ExplanationCopyCompiler / SafeCopyTemplateRegistry |
| Localization | P7 LocalizationSafetyLint |
| Privacy & security | P8 LocalPrivacyPreflight |
| Public demonstration | P10 PublicDemoWalkthroughGenerator |
| Contribution safety | P11 ContributionSafetyRouter |
| Release automation | P12 ReleaseSnapshotGenerator |

## 7. Prioritized roadmap (recommended order)

1. **P12 ReleaseSnapshotGenerator** — immediate public-showcase value; composes
   existing outputs; lowest clinical risk.
2. **P10 PublicDemoWalkthroughGenerator** — immediate showcase value; composes
   existing synthetic artifacts.
3. **P4 EvidenceGraphBuilder** — builds directly on EvidenceTraceBundle/replay.
4. **P5 SyntheticScenarioFuzzer** — improves regression protection of the gates.
5. **P7 LocalizationSafetyLint** — safety/governance over existing i18n dictionaries.
6. **P9 SourceAccessContractChecker** — machine-readable source governance.
7. **P8 LocalPrivacyPreflight** — extends the privacy/security guardrail.
8. **P6 ExplanationCopyCompiler** — centralizes safe copy (enables P7 fully).
9. **P1 InputQualityGate** — touches product flow; sequence later.
10. **P2 CatalogResolutionEngine** — touches product flow; later.
11. **P3 SourceVersionDriftChecker** — depends on P9 registry; later.
12. **P11 ContributionSafetyRouter** — most useful once contribution volume grows.

Rationale: P12/P10 give immediate, low-risk showcase value by composing what
already exists. P4 leverages the EvidenceTraceBundle. P5 hardens regression
coverage. P7/P8/P9 strengthen safety/governance. P1/P2/P3 are more likely to
touch live product flows and should follow once the surrounding tooling is in
place. P11 scales with contributors.

## 8. Structured P-list

> Template per item: id · title · problem · why it matters · inputs · outputs ·
> files likely affected · implementation approach · tests required · safety
> boundary · not in scope · priority · complexity · risk · recommended PR ·
> dependencies · acceptance criteria.

### P1 — InputQualityGate / MealMedicationEntryQualityScorer
- **Problem:** dirty meal/medication input can reach mechanistic scoring without
  a single, inspectable pre-engine quality verdict.
- **Why it matters:** protects the core engine and makes "why was this
  insufficient" explicit and testable.
- **Inputs:** medication dose value+unit, `dosageSource`, unitless-dose flag,
  drug-variant presence, releaseType, route/doseForm, user-defined meal window,
  food portion basis, missing-nutrient set, true-zero-vs-missing,
  `sourceRefs`, metadata completeness, provenance tier, source authority,
  localization-readiness of warnings.
- **Outputs:** one grade — `complete` / `sufficient` / `partial` /
  `insufficient` / `invalid` — with per-signal reasons. **No medical advice.**
- **Files likely affected:** new `lib/domain/usecases/input_quality_gate.dart`
  (+ entity); reuses `medication_entry_validator.dart`,
  `metadata_completeness_gate.dart`, `source_authority_scorer.dart`,
  `meal_composition_normalizer.dart`.
- **Implementation approach:** pure aggregator that composes existing gate
  outputs into one grade + reasons; no new scoring math.
- **Tests:** grade ordering; unitless dose → not `complete`; true-0 vs missing;
  missing window → blocked; banned-phrase scan over reasons.
- **Safety boundary:** quality verdict only; never a clinical/intake judgment.
- **Not in scope:** dose inference; advice; changing engine behavior.
- **Priority:** medium · **Complexity:** medium · **Risk:** medium (touches flow).
- **Recommended PR:** `peripheral-input-quality-gate`.
- **Dependencies:** existing validators/gates (present).
- **Acceptance:** deterministic grade + reasons; no advice; regression-safe.

### P2 — CatalogResolutionEngine
- **Problem:** user-facing food/drug names aren't resolved into source-backed
  catalog candidates with explicit uncertainty.
- **Why it matters:** prevents silent guessing; surfaces candidate ambiguity.
- **Inputs:** raw name, locale, regional/multilingual synonyms, brand/generic
  maps, combination-product hints, release-type hints.
- **Outputs:** ranked candidate list with confidence, `unresolvedReasons`,
  `sourceRefs`; never a silent single guess.
- **Files likely affected:** new `lib/domain/usecases/catalog_resolution_engine.dart`;
  reuses CDSS projection + `catalog_food_to_candidate.dart`.
- **Implementation approach:** deterministic synonym/alias matching over the
  projected catalog; conservative — unresolved stays unresolved.
- **Tests:** synonym/regional/multilingual match; combination detection;
  unresolved reasons; no fabricated match; banned-phrase scan.
- **Safety boundary:** identity resolution only; no advice/selection.
- **Not in scope:** clinical equivalence claims; substitution advice.
- **Priority:** medium · **Complexity:** high · **Risk:** medium.
- **Recommended PR:** `peripheral-catalog-resolution`.
- **Dependencies:** catalog projection.
- **Acceptance:** deterministic candidates + uncertainty; no silent guess.

### P3 — SourceVersionDriftChecker
- **Problem:** stale/inconsistent source/catalog/model versions can go unnoticed.
- **Why it matters:** keeps provenance claims honest over time.
- **Inputs:** `sourceDocument` version/effectiveDate/lastChecked, importer
  projection version, model-assumption-registry version, rule-registry version,
  bibliography source status, live-smoke status.
- **Outputs:** `stale_source` / `unknown_last_checked` / `source_version_missing`
  / `projection_outdated` / `assumption_registry_drift` / `bibliography_mismatch`.
- **Files likely affected:** new `lib/domain/usecases/source_version_drift_checker.dart`;
  reads the P9 registry + model assumption registry.
- **Implementation approach:** deterministic comparison against a recorded
  baseline; report-only.
- **Tests:** each drift code; missing-version path; no false "fresh" claim.
- **Safety boundary:** governance signal only.
- **Not in scope:** auto-updating sources; live fetch.
- **Priority:** medium · **Complexity:** medium · **Risk:** low.
- **Recommended PR:** `peripheral-source-drift`.
- **Dependencies:** P9 (registry).
- **Acceptance:** deterministic drift report; missing → recorded, not hidden.

### P4 — EvidenceGraphBuilder
- **Status: shipped** (Operation 2; branch `evidence-graph-builder`):
  `lib/domain/entities/evidence_graph.dart` +
  `lib/domain/usecases/evidence_graph_builder.dart` + mermaid renderer +
  `tool/generate_evidence_graph.dart` (`npm run evidence:graph`) + tests +
  `docs/EVIDENCE_GRAPH.md`. Local graph only; not FHIR Provenance / W3C PROV;
  missing inputs → `missing_artifact` nodes.
- **Problem:** provenance is serialized as views/bundles but not as a navigable graph.
- **Why it matters:** reviewers can trace fact → source visually/programmatically.
- **Inputs:** replay report JSON and/or `EvidenceTraceBundle`.
- **Outputs:** JSON graph (nodes: source_document, observation, resolved_fact,
  food_variant, drug_variant, completeness_gate, source_authority_gate,
  mechanistic_layer, explanation_trace, replay_report, evidence_trace_bundle;
  edges: produced_by / backed_by / graded_by) + optional Mermaid. **Not a patient
  record.**
- **Files likely affected:** new `lib/domain/usecases/evidence_graph_builder.dart`;
  reuses `evidence_trace_bundle.dart` + replay JSON.
- **Implementation approach:** pure transform from existing structures; stable
  node ids; deterministic ordering.
- **Tests:** node/edge construction from a fixture bundle; Mermaid render;
  recursive key-level no-PHI scan; deterministic output.
- **Safety boundary:** provenance graph only; no patient/subject/encounter nodes.
- **Not in scope:** any patient-linkage node; clinical inference.
- **Priority:** high · **Complexity:** medium · **Risk:** low.
- **Recommended PR:** `peripheral-evidence-graph`.
- **Dependencies:** EvidenceTraceBundle (present).
- **Acceptance:** deterministic graph; PHI-free; missing input → `missing_artifact`.

### P5 — SyntheticScenarioFuzzer
- **Status: shipped** (Operation 3; branch `synthetic-scenario-fuzzer`):
  `lib/domain/entities/synthetic_scenario_fuzzer.dart` +
  `lib/domain/usecases/synthetic_scenario_fuzzer.dart` (deterministic generator +
  real-code evaluator across families A–F) + `tool/run_synthetic_scenario_fuzzer.dart`
  (`npm run scenario:fuzz`) + tests + `docs/SYNTHETIC_SCENARIO_FUZZER.md`. Every
  case is evaluated with existing code; missing/unevaluated → recorded, never
  fabricated.
- **Problem:** boundary cases are covered by hand-written scenarios only.
- **Why it matters:** broadens regression protection for gates + replay.
- **Inputs:** a seed + generators for unitless/missing dose, true-0/missing
  protein, missing calories/portion, unknown releaseType, IR/ER mixed timeline,
  missing sourceRefs, official-vs-synthetic source, analytical-vs-imputed tier,
  no window, cross-jurisdiction source, unsafe-phrase regression.
- **Outputs:** pass/fail summary, unexpected ranker switch, missingness
  regression, unsafe-phrase hits, **seed used**, reproducible scenario id.
- **Files likely affected:** new `lib/domain/usecases/synthetic_scenario_fuzzer.dart`
  + `tool/run_synthetic_fuzzer.dart`; reuses validators/normalizer/scorer.
- **Implementation approach:** seeded deterministic generation; assert invariants
  (missing≠zero, conflict dominance, no banned phrases); fully synthetic.
- **Tests:** fixed seed → fixed cases; a deliberately broken invariant is caught;
  no banned phrases in generated copy.
- **Safety boundary:** synthetic stress only; no real data.
- **Not in scope:** real inputs; clinical scenarios.
- **Priority:** high · **Complexity:** medium · **Risk:** low.
- **Recommended PR:** `peripheral-scenario-fuzzer`.
- **Dependencies:** gates/replay (present).
- **Acceptance:** seeded reproducibility; invariant violations surfaced.

### P6 — ExplanationCopyCompiler / SafeCopyTemplateRegistry
- **Problem:** user-facing explanation/safety copy is spread across the codebase.
- **Why it matters:** centralizing it prevents drift into advice and enables P7.
- **Inputs:** templateId, outputType, allowed placeholders, required `sourceRefs`,
  required `limitationText`, required safety line, banned phrases, localization
  keys, fallback wording.
- **Outputs:** a validated template registry + a compiler that refuses templates
  missing safety/limitation or containing banned phrases.
- **Files likely affected:** new `lib/domain/entities/safe_copy_template_registry.dart`
  + `lib/domain/usecases/explanation_copy_compiler.dart`; reuses
  `rule_explanation.dart` (`bannedExplanationSubstrings`, default safety copy).
- **Implementation approach:** declarative registry + deterministic validation;
  no behavior change to existing emitters initially.
- **Tests:** missing-safety-line rejected; banned-phrase rejected; placeholder
  contract enforced; localization-key presence.
- **Safety boundary:** copy governance only.
- **Not in scope:** new clinical copy; AI rewriting.
- **Priority:** medium · **Complexity:** medium · **Risk:** low.
- **Recommended PR:** `peripheral-safe-copy-registry`.
- **Dependencies:** none hard; enables P7.
- **Acceptance:** unsafe templates blocked deterministically.

### P7 — LocalizationSafetyLint
- **Problem:** multilingual dictionaries can drift in safety meaning.
- **Why it matters:** translations must not become more clinically assertive.
- **Inputs:** `lib/core/i18n/app_i18n.dart` + `app_i18n_full_translations.dart`
  (English / Chinese / French / Japanese where present).
- **Outputs:** missing keys, missing safety-boundary text, translated
  advice-like phrases, missing limitation text, inconsistent fallback,
  overconfident localized phrases.
- **Files likely affected:** new `tool/run_localization_safety_lint.dart` (+ test).
- **Implementation approach:** deterministic dictionary inspection vs a key/phrase
  contract; report-only.
- **Tests:** missing-key detection; injected advice-like translation caught;
  clean dictionary passes.
- **Safety boundary:** lint only; never auto-translates clinical content.
- **Not in scope:** machine translation; new languages' content.
- **Priority:** medium · **Complexity:** medium · **Risk:** low.
- **Recommended PR:** `peripheral-localization-safety-lint`.
- **Dependencies:** P6 helps (shared phrase contract).
- **Acceptance:** deterministic lint; safety drift flagged.

### P8 — LocalPrivacyPreflight
- **Problem:** public preflight checks positioning, not local data-leak risk.
- **Why it matters:** stops PHI-like/secret content reaching the public repo.
- **Inputs:** repo tree (fixtures, configs).
- **Outputs:** findings for patient-like fixture data, PHI-like fields,
  UID/operator logs, local machine paths, raw private exports, Firebase secrets,
  API keys, tokens, real medication schedules/symptom logs/health stories.
- **Files likely affected:** new `tool/local_privacy_preflight.mjs` (complements
  `public_repo_preflight.mjs`); npm `privacy:preflight`.
- **Implementation approach:** deterministic pattern scan with an allowlist for
  known-synthetic fixtures; BLOCKER/WARN/INFO like the existing preflight.
- **Tests:** seeded fixture with a planted secret/PHI-like string is flagged;
  clean tree passes; synthetic allowlist respected.
- **Safety boundary:** scanner only; no data exfiltration.
- **Not in scope:** full security audit; runtime DLP.
- **Priority:** medium · **Complexity:** medium · **Risk:** low.
- **Recommended PR:** `peripheral-local-privacy-preflight`.
- **Dependencies:** none.
- **Acceptance:** planted risks flagged; deterministic; no false "clean" on hits.

### P9 — SourceAccessContractChecker
- **Problem:** `SOURCE_ACCESS_AND_LICENSES.md` is prose, not machine-checkable.
- **Why it matters:** keeps fixture-vs-production + license status honest.
- **Inputs:** new `tool/source_access_registry.json`
  (sourceId, owner, jurisdiction, accessMethod, requiresApiKey, requiresAccount,
  licenseReviewNeeded, implementationStatus, allowedForFixture,
  allowedForLiveSmoke, allowedForProduction, canSupportMechanismEvidenceAlone).
- **Outputs:** verification that all `sourceRefs` resolve; fixture-only sources
  aren't described as production; live-smoke sources are opt-in;
  license-review-needed flagged; unsupported sources don't silently enter
  mechanism evidence.
- **Files likely affected:** registry JSON + `tool/source_access_contract_check.mjs`;
  npm `source:contract`.
- **Implementation approach:** deterministic JSON contract check; mirrors the
  Firestore-rules-contract pattern.
- **Tests:** unresolved sourceRef flagged; production-mislabel flagged; clean
  registry passes.
- **Safety boundary:** governance only.
- **Not in scope:** changing access methods; live fetch.
- **Priority:** medium · **Complexity:** low · **Risk:** low.
- **Recommended PR:** `peripheral-source-access-contract`.
- **Dependencies:** underpins P3.
- **Acceptance:** contract violations surfaced deterministically.

### P10 — PublicDemoWalkthroughGenerator
- **Problem:** the evidence story is spread across multiple artifacts.
- **Why it matters:** one reviewable synthetic walkthrough, no advice.
- **Inputs:** replay latest JSON, source-quality latest JSON, an EvidenceTraceBundle
  fixture, capability-matrix summary, shared safety-boundary text.
- **Outputs:** `build/public_demo_walkthrough/latest.md` with synthetic input
  summary, source-quality summary, missingness summary, replay summary, evidence
  bundle summary, safety boundary, "what this does not prove". **No advice.**
- **Files likely affected:** new `tool/generate_public_demo_walkthrough.dart`
  (+ optional `.mjs` + npm `demo:walkthrough`).
- **Implementation approach:** pure generator; parses existing artifacts; missing
  → `missing_artifact`.
- **Tests:** fixture artifacts → deterministic markdown; missing-artifact path;
  banned-phrase + no-PHI scans.
- **Safety boundary:** synthetic demonstration only.
- **Not in scope:** advice; fabricated results.
- **Priority:** high · **Complexity:** low · **Risk:** low.
- **Recommended PR:** `peripheral-public-demo-walkthrough` (first batch).
- **Dependencies:** replay + source-quality + EvidenceTraceBundle (present).
- **Acceptance:** deterministic walkthrough; missing → recorded.

### P11 — ContributionSafetyRouter
- **Problem:** no automated risk classification of incoming diffs.
- **Why it matters:** routes review effort and catches risky changes early.
- **Inputs:** changed file paths + diff keywords.
- **Outputs:** category (docs_only / test_only / source_metadata /
  replay_scenario / rule_explanation / mechanistic_model / importer /
  security_sensitive / medical_claim_risk / clinical_advice_risk / secret_risk),
  required reviewer checklist, suggested labels, risk level, blocked-phrase hits.
- **Files likely affected:** new `tool/contribution_safety_router.mjs` (+ test).
- **Implementation approach:** deterministic path/keyword classifier; report-only.
- **Tests:** each category from a synthetic diff; medical-claim/secret detection;
  docs-only → low risk.
- **Safety boundary:** triage only; advisory.
- **Not in scope:** auto-merging; auto-labeling without review.
- **Priority:** low · **Complexity:** medium · **Risk:** low.
- **Recommended PR:** `peripheral-contribution-router`.
- **Dependencies:** none.
- **Acceptance:** deterministic classification + checklist.

### P12 — ReleaseSnapshotGenerator
- **Problem:** verification evidence is scattered across commands.
- **Why it matters:** one reproducible release-evidence snapshot.
- **Inputs:** existing artifact JSONs (replay, source-quality, preflight) +
  injectable counts (test count, Firestore pass count) so tests stay fast/stable.
- **Outputs:** `build/release_snapshot/latest.{md,json}` with test count, replay
  count, source-quality row count, preflight BLOCKER count, Firestore pass count,
  capability status, known limitations, and a "not clinically calibrated" line.
- **Files likely affected:** new `tool/run_release_snapshot.dart`
  (+ optional `.mjs` + npm `release:snapshot`).
- **Implementation approach:** pure composer; parses artifacts; **does not run
  slow commands inside tests**; missing inputs → `missing_artifact`.
- **Tests:** fixture artifacts + injected counts → deterministic snapshot;
  missing-artifact path; banned-phrase clean; not-calibrated line present.
- **Safety boundary:** evidence summary only.
- **Not in scope:** clinical sign-off; fabricated numbers.
- **Priority:** high · **Complexity:** low · **Risk:** low.
- **Recommended PR:** `peripheral-release-snapshot` (first batch).
- **Dependencies:** replay + source-quality + preflight (present).
- **Acceptance:** deterministic snapshot; missing → recorded, never fabricated.

## 9. Dependency map

- **P10, P12** compose existing reports (replay / source-quality / preflight /
  EvidenceTraceBundle) — no upstream code dependency.
- **P4** builds on `EvidenceTraceBundle` + replay JSON.
- **P5** exercises the existing gates/normalizer/scorer.
- **P9** underpins **P3** (drift checker reads the access registry).
- **P6** underpins **P7** (shared safe-copy/phrase contract).
- **P1** consumes the completeness gate + source authority + `dosageSource`.
- **P2** consumes the catalog projection.
- **P11** is standalone (path/keyword classifier).

## 10. PR sequencing proposal

One focused PR per P-item (or a tight pair), each branched from and targeting
`peripheral-algorithm-integration`. Suggested first pairs/sequence:

1. **Batch 1:** P12 + P10 (`peripheral-release-snapshot`,
   `peripheral-public-demo-walkthrough`).
2. P4 → P5 → P9 → P3 → P7 (with P6) → P8.
3. P1 → P2 (product-flow-touching; later).
4. P11 (when contribution volume grows).

## 11. Risk register

| Risk | Likelihood | Mitigation |
| --- | --- | --- |
| A peripheral report implies clinical use | medium | Explicit boundary text + "not clinically calibrated" line + banned-phrase scan in every generator/test. |
| Flaky tests (shelling out to slow commands) | medium | Parse existing artifacts / injectable fakes; never run replay/preflight inside unit tests. |
| Fabricated numbers when artifacts missing | low | `missing_artifact` markers, tested explicitly. |
| Doc/positioning drift trips preflight | low | Scanner-safe wording; preflight in the verification gate. |
| PHI-like content in fixtures | low | P8 privacy preflight + key-level no-PHI scans. |
| Scope creep into core engine | low | Additive-only principle; no edits to scoring/importers/rules/constants. |

## 12. Test strategy

- Pure, deterministic unit tests; fixtures over live commands.
- Every generator's output scanned with `findBannedSubstrings` and (where JSON)
  a recursive key-level no-PHI scan (`test/helpers/no_phi_json_assertions.dart`).
- `missing_artifact` paths are explicitly tested.
- Seeded reproducibility for the fuzzer (P5).
- No change to the 41-scenario replay or its count from peripheral PRs.

## 13. Documentation strategy

Each batch updates `docs/CAPABILITY_MATRIX.md` (status row),
`docs/PUBLIC_VERIFICATION.md` (new command), and
`docs/EVIDENCE_AND_TRACEABILITY_DEMO_GUIDE.md` (how to inspect the new artifact),
plus this plan's status. Wording stays scanner-safe. New npm scripts are
documented only after they exist.

## 14. What not to build

No clinical advice; no dosage inference or defaults; no medication-timing or diet
instructions; no diagnosis, treatment plans, monitoring, or clinical prediction;
no LLM inside the conflict engine; no live production ingestion; no PHI / patient
/ subject / encounter semantics; no FHIR-conformance claim; no unsupported
medical rules; no real patient data or schedules.

## 15. First implementation batch proposal (P12 + P10)

> **Status: shipped.** P12 + P10 are implemented on
> `release-snapshot-and-demo-walkthrough` (lib generators +
> `tool/run_release_snapshot.dart` / `tool/generate_public_demo_walkthrough.dart`
> + `.mjs` wrappers + npm `release:snapshot` / `demo:walkthrough` + tests +
> docs). Both compose existing artifacts, report `missing_artifact` rather than
> fabricating, and stay banned-phrase + PHI-clean. See `docs/CAPABILITY_MATRIX.md`.

Chosen because they are **high-showcase, low-clinical-risk**, and mostly
**compose existing outputs** rather than changing core logic.

**P12 ReleaseSnapshotGenerator** — `tool/run_release_snapshot.dart` (+ optional
`.mjs`, npm `release:snapshot`). Parses `build/mechanistic_replay/latest.json`
(`passed`/`total`), `build/source_quality_perturbation/latest.json` (`rows`
length), `build/public_release_preflight/latest.json` (`counts.BLOCKER`); accepts
injectable test/Firestore counts so tests stay fast. Emits
`build/release_snapshot/latest.{md,json}` with the counts, capability status,
known limitations, and a "not clinically calibrated" line. Missing inputs →
`missing_artifact`. Test: fixture artifacts + injected counts → deterministic
snapshot; missing-artifact path; banned-phrase clean.

**P10 PublicDemoWalkthroughGenerator** — `tool/generate_public_demo_walkthrough.dart`
(+ optional `.mjs`, npm `demo:walkthrough`). Consumes replay + source-quality
latest JSON, an EvidenceTraceBundle fixture, the capability-matrix summary, and
shared safety-boundary text; emits `build/public_demo_walkthrough/latest.md`
(synthetic input / source-quality / missingness / replay / evidence-bundle
summaries + safety boundary + "what this does not prove"). Missing artifacts →
`missing_artifact`. Test: fixture artifacts → deterministic markdown;
missing-artifact path; banned-phrase + no-PHI scans.

Both ship as their **own** PRs against `peripheral-algorithm-integration`, after
explicit approval of a separate implementation plan.

## 16. Source-backed rationale

These peripheral algorithms are grounded in established external guidance, while
ParkinSUM remains educational-only and makes no conformance claim:

- **FDA Clinical Decision Support guidance** (Bibliographies.md #11) — supports
  keeping outputs **non-prescriptive and intended-use-constrained**; the input
  gate (P1), copy compiler (P6), and walkthrough (P10) all reinforce that the
  prototype is not device CDS.
- **HL7 FHIR R5 Provenance** (hl7.org/fhir/R5/provenance.html) — informs the
  **traceability/reproducibility** ideas behind the evidence graph (P4),
  snapshot (P12), and source contracts (P9); ParkinSUM stays **non-FHIR-conformant**
  (its views/bundles are `inspired_not_conformant` / local).
- **USDA FoodData Central API** (Bibliographies.md #12) — supports
  **nutrient-data integration**, but source quality still matters → P3 drift and
  P9 access contracts keep fixture-vs-production honest.
- **OWASP MASVS** incl. **MASVS-PRIVACY** (mas.owasp.org) — supports a stronger
  **privacy/security preflight** (P8) and contribution risk routing (P11).
- **FAIR data principles** (Wilkinson et al. 2016, *Scientific Data*,
  DOI 10.1038/sdata.2016.18; cited in the scorecard S9) — support
  **machine-readable source and evidence traceability** (P4, P9, P12).

No new clinical sources are introduced; these references bound the *peripheral*
(governance / provenance / safety) layer, not any medical claim.
