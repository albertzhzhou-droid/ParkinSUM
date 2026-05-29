# Biomedical Engineering Backlog

Issue-ready tasks derived from `docs/BIOMEDICAL_ENGINEERING_OPPORTUNITY_MAP.md`.
Every item stays inside ParkinSUM's educational-prototype boundary: synthetic /
public-schema data only, non-prescriptive, evidence-linked, no clinical
calibration, no real patient data, no hidden dosage defaults. Each item is
written so it can be pasted into a GitHub issue.

Common safety boundary (applies to all): educational simulation only; not a
medical device; no diagnosis/treatment/timing/diet advice; dose passes through
only from explicit user entry; missing ≠ zero; no live ingestion without opt-in
+ license review; AI never decides inside the conflict engine.

---

## 1. Improve SPL/SmPC section-level importer provenance
- **Motivation:** Food-effect and release behavior live in specific labeled
  sections; capturing section identity + label version + effective date makes
  provenance auditable and citable. (OPP-A1)
- **Source basis:** DailyMed SPL Web Services v2; FDA SPL standard (LOINC
  section codes); EMA ePI/SmPC.
- **Scope:** Extend SPL/SmPC fixture parsers to record section LOINC code, set
  id, label version, effective date, per-section provenance → flow into
  `SourceDocumentMetadata` / `DrugProductVariantMetadata` and explanation
  `sourceRefs`.
- **Files likely affected:** `lib/data/datasources/remote/*` SPL adapters,
  `lib/domain/entities/source_metadata.dart`, medication-context trace.
- **Tests required:** fixture parser tests (synthetic SPL) asserting
  section/version/date extraction + provenance in trace; banned-phrase scan.
- **Acceptance:** section LOINC + version + effective date present in trace for
  a synthetic SPL; missing → recorded missing, never guessed.
- **Safety boundary:** metadata only; mechanism evidence still needs explicit
  label text; no dose/timing inference.
- **Not in scope:** live ingestion; production parser; clinical interpretation.
- **Labels:** `importer`, `provenance`, `medication`, `P1`.
- **Depends on:** none.

## 2. Expand FoodData Central amino-acid extraction to real-schema coverage
- **Motivation:** Broaden actual amino-acid coverage to reduce proxy fallbacks
  and capture per-nutrient basis/unit. (OPP-B2)
- **Source basis:** USDA FDC API + Foundation Foods Documentation (Apr 2024).
- **Scope:** Extend `AminoAcidExtractor` + fixtures to the full FDC amino-acid
  nutrient-number set with mg→g normalization, per-nutrient basis, and partial
  flagging.
- **Files likely affected:** `lib/data/datasources/remote/amino_acid_extractor.dart`,
  `lib/domain/entities/amino_acid_profile.dart`, FDC fixtures, tests.
- **Tests required:** realistic FDC fixture covering full LNAA set; assert
  actual-fields mode, partial handling, missing≠zero.
- **Acceptance:** all LNAA nutrient numbers parsed when present; partial → widen
  uncertainty; absent → null.
- **Safety boundary:** no fabricated amino-acid values.
- **Not in scope:** live API ingestion (key required).
- **Labels:** `importer`, `nutrition`, `P1`.
- **Depends on:** none (extends existing tested seam).

## 3. Add source-quality perturbation replay tests
- **Motivation:** Demonstrate graceful degradation and that conflict overlap
  stays dominant as provenance/authority worsens. (OPP-D1)
- **Source basis:** FAIR principles (provenance rigor); internal scorer.
- **Scope:** Add replay scenario pairs identical except for source
  authority/provenance; assert ordering + invariant behavior.
- **Files likely affected:** `lib/core/constants/mechanistic_replay_scenarios.dart`,
  `test/mechanistic_replay_runner_test.dart`.
- **Tests required:** the scenarios themselves + assertions.
- **Acceptance:** lower-authority variant never outranks a high-conflict
  candidate; deterministic order.
- **Safety boundary:** tests only; no behavior change.
- **Not in scope:** changing scoring weights.
- **Labels:** `replay`, `validation`, `P1`.
- **Depends on:** none.

## 4. Add missingness stress-test replay suite
- **Motivation:** Prove "missing ≠ zero" end-to-end and that completeness +
  uncertainty respond correctly. (OPP-D2)
- **Source basis:** FDC Foundation Foods docs (what is commonly missing);
  internal normalizer.
- **Scope:** Scenarios dropping protein/calories/portion/amino-acid fields;
  assert `missingFields`, lowered completeness, widened uncertainty.
- **Files likely affected:** `mechanistic_replay_scenarios.dart`,
  `test/mechanistic_replay_runner_test.dart`.
- **Tests required:** replay assertions.
- **Acceptance:** missing inputs surface as missing (not 0) and lower
  confidence; no fabricated values.
- **Safety boundary:** tests only.
- **Not in scope:** new model behavior.
- **Labels:** `replay`, `validation`, `data-quality`, `P1`.
- **Depends on:** none.

## 5. Add enteral feeding educational scenario
- **Motivation:** Continuous/bolus enteral feeding changes protein delivery +
  gastric context; model as a separate educational scenario. (OPP-C1)
- **Source basis:** Leta et al. 2023 (GI barriers); npj PD 2023 (protein).
- **Scope:** Synthetic enteral replay scenarios (continuous vs bolus) + an
  educational trace note; no timing/schedule recommendation.
- **Files likely affected:** `mechanistic_replay_scenarios.dart`,
  DB-backed usecase enteral context (already present), tests.
- **Tests required:** replay scenario assertions + banned-phrase scan.
- **Acceptance:** scenario runs, carries source refs + caution, no prescriptive
  copy.
- **Safety boundary:** educational caution only; "review with a qualified
  professional".
- **Not in scope:** feeding schedule advice; dosing.
- **Labels:** `mechanistic-model`, `replay`, `P1`.
- **Depends on:** none (placeholder shipped this pass; expand next).

## 6. Add iron/mineral co-event educational trace
- **Motivation:** Iron can chelate levodopa and reduce absorption; add a
  non-levodopa co-event educational caution. (OPP-C2)
- **Source basis:** Leta et al. 2023 + a dedicated, verified iron–levodopa
  interaction citation (**must be added before implementation**).
- **Scope:** Educational caution trace string + replay scenario for an iron
  co-event; no quantitative interaction score.
- **Files likely affected:** `mechanistic_conflict_engine.dart` (co-event
  trace), `mechanistic_replay_scenarios.dart`, tests, `Bibliographies.md`.
- **Tests required:** replay scenario + safety-phrase test.
- **Acceptance:** caution appears only when source-backed; non-prescriptive.
- **Safety boundary:** educational caution only; not a timing rule.
- **Not in scope:** dose adjustment advice.
- **Labels:** `mechanistic-model`, `needs-citation`, `P2`.
- **Depends on:** verified iron-interaction citation.

## 7. Add MAO-B / tyramine educational caution (only if properly sourced)
- **Motivation:** Provide a precisely-sourced, non-prescriptive caution where
  supported. (OPP-C3)
- **Source basis:** MAO-B inhibitor label (SmPC/SPL) + verified tyramine
  reference (**must be added before implementation**).
- **Scope:** Caution copy + replay scenario, gated on source presence.
- **Files likely affected:** caution copy module, replay scenarios, tests,
  `Bibliographies.md`.
- **Tests required:** safety-phrase test; source-presence gate test.
- **Acceptance:** no caution without a verified source; no diet rule implied.
- **Safety boundary:** must not imply a diet restriction; educational only.
- **Not in scope:** dietary prescription; non-selective MAOI generalization.
- **Labels:** `mechanistic-model`, `needs-citation`, `safety`, `P2`.
- **Depends on:** verified MAO-B/tyramine citation.

## 8. Add FHIR-inspired medication metadata mapping
- **Motivation:** Demonstrate interoperability literacy by mapping internal
  medication metadata toward a MedicationKnowledge-like shape. (OPP-F1)
- **Source basis:** HL7 FHIR R5 MedicationKnowledge; RxNorm/ATC.
- **Scope:** A `toFhirLikeMedicationKnowledge()` serialization view over
  `DrugProductVariantMetadata` (educational, explicitly non-conformant).
- **Files likely affected:** new mapper file under `lib/domain/`, doc, test.
- **Tests required:** mapper unit test on synthetic metadata.
- **Acceptance:** deterministic mapping; labeled "FHIR-inspired, not a
  conformant resource".
- **Safety boundary:** representation only; no behavior change; synthetic data.
- **Not in scope:** a conformant FHIR server / real exchange.
- **Labels:** `standards`, `interoperability`, `P2`.
- **Depends on:** OPP-A3 (RxNorm identity) optional.

## 9. Add FHIR-inspired nutrition observation mapping
- **Motivation:** Standardize the nutrition trace toward NutritionIntake /
  Observation. (OPP-F2)
- **Source basis:** HL7 FHIR R5 NutritionIntake / Observation; FAO/INFOODS.
- **Scope:** A `toFhirLikeNutritionIntake()` / Observation serialization view
  over meal composition.
- **Files likely affected:** new mapper file, doc, test.
- **Tests required:** mapper unit test on synthetic composition.
- **Acceptance:** deterministic mapping; non-conformant label; synthetic data.
- **Safety boundary:** representation only.
- **Not in scope:** real exchange / conformance.
- **Labels:** `standards`, `interoperability`, `nutrition`, `P2`.
- **Depends on:** none.

## 10. Add open wearable/gait synthetic replay layer (non-diagnostic demo)
- **Motivation:** Showcase a time-series ingestion + feature-engineering +
  replay architecture using synthetic signals shaped like public gait datasets.
  (OPP-E1)
- **Source basis:** Daphnet Freezing of Gait (CC BY 4.0) and WearGait-PD —
  **schema/shape only**, synthetic signals generated locally.
- **Scope:** A NEW, separate module (decoupled from the conflict engine): a
  synthetic accelerometer generator + deterministic windowing/feature/replay
  pipeline + report; explicitly non-diagnostic copy.
- **Files likely affected:** new `lib/domain/usecases/wearable_*` module + tests
  + a new doc; **no** changes to medication/conflict logic.
- **Tests required:** deterministic feature tests; banned-phrase scan; explicit
  "no PD detection/monitoring" assertions.
- **Acceptance:** runs on synthetic data only; isolated from medication logic;
  no diagnostic/monitoring claims anywhere.
- **Safety boundary:** must NOT claim PD detection, monitoring readiness, or use
  real patient signals; synthetic / public-shape only.
- **Not in scope:** real device integration; any clinical inference.
- **Labels:** `biomedical-engineering`, `time-series`, `showcase`, `P3`.
- **Depends on:** none; keep fully isolated.

## 11. Add API/license review checklist for source ingestion
- **Motivation:** Required before any production ingestion; strong open-source
  governance signal. (OPP-F3)
- **Source basis:** FAIR principles; per-source terms (DailyMed public domain,
  FDC API key, dm+d/SNOMED licensing, EMA reuse terms, PMDA/NMPA terms).
- **Scope:** Add a FAIR-aligned checklist + registry rows to
  `docs/SOURCE_ACCESS_AND_LICENSES.md` (partly done this pass); optional
  registry-presence test.
- **Files likely affected:** `docs/SOURCE_ACCESS_AND_LICENSES.md`,
  `Bibliographies.md`, optional source-registry constants + test.
- **Tests required:** optional doc/registry presence test.
- **Acceptance:** every source has access type + license-review status + safety
  note; live ingestion gated behind review.
- **Safety boundary:** documentation/governance; no live ingestion enabled.
- **Not in scope:** turning on live ingestion.
- **Labels:** `governance`, `licensing`, `docs`, `P1`.
- **Depends on:** none.

## 12. Add clinical-calibration guardrail regression tests
- **Motivation:** Lock in the non-device boundary so it cannot regress.
  (OPP-D4) **(Shipped in this PR.)**
- **Source basis:** FDA Clinical Decision Support Software guidance (non-device
  CDS criteria).
- **Scope:** Regression test asserting every replay case reports
  `clinical_calibration_status == not_clinically_calibrated`,
  `live_fetch_enabled == false`, `can_support_mechanism_evidence_alone == false`
  by default, plus a banned-phrase scan over the serialized report.
- **Files likely affected:** `test/mechanistic_replay_runner_test.dart`.
- **Tests required:** the regression test itself.
- **Acceptance:** test fails if any case drops the calibration guardrail or
  enables live fetch by default.
- **Safety boundary:** directly enforces the boundary.
- **Not in scope:** changing report semantics.
- **Labels:** `safety`, `regression`, `P0`.
- **Depends on:** none.
