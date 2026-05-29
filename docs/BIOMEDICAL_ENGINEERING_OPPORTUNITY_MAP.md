# Biomedical Engineering Opportunity Map

> Research-and-planning document. Identifies **safe, source-grounded**
> engineering opportunities to make ParkinSUM Companion's production-style
> pipeline more realistic, testable, and evidence-linked. This is a map, not an
> implementation. Nothing here changes the project's intended use.

## 1. Executive summary

ParkinSUM Companion is an **educational / research prototype** that demonstrates
a production-style food + medication data chain and a deterministic, explainable
mechanistic conflict engine. Prior passes already delivered: componentized meal
composition, a parameterized component-level gastric-emptying model, a sampled
levodopa absorption-opportunity *openness* profile, an LNAA competition layer
(actual-fields + proxy + dose-relative + partial handling), provenance-scored
candidate metadata, a multi-dose time axis, and a provenance-tagged scoring
parameter set with an enforced "conflict-dominant" invariant.

This map surveys authoritative, open or legally accessible biomedical, nutrition,
drug-label, data-standard, and Parkinson-mechanism sources and proposes the next
**non-clinical** opportunities, grouped into six themes:

- **A. Drug-label importer realism** — SPL/SmPC section-level provenance,
  release-type/dose-form/combination-product extraction, RxNorm/ATC identity.
- **B. Nutrition importer realism** — FDC Foundation Foods provenance metadata
  (sample n, analytical method, basis), fuller amino-acid arrays, FAO/INFOODS
  tagname + missingness flags, prepared/raw/branded distinction.
- **C. Mechanistic model realism (remaining)** — enteral-feeding educational
  scenario, iron/mineral co-event educational trace, MAO-B/tyramine educational
  caution (only if source-supported), ER/controlled-release stress tests.
- **D. Replay & validation robustness** — source-quality perturbation tests,
  missingness stress suite, counterfactual pairs, clinical-calibration guardrail
  regression tests.
- **E. Biomedical-engineering showcase** — an *optional, separate, synthetic*
  wearable/gait time-series replay layer (architecture demo only; no PD
  detection, no monitoring).
- **F. Data standards** — FHIR-inspired MedicationKnowledge / NutritionIntake /
  Observation mappings, OMOP/RxNorm identity alignment, FAIR-aligned source
  registry + API/license review checklist.

The single highest-value safe upgrades are **D (validation robustness)** and the
**clinical-calibration guardrail regression test** — they harden the safety
boundary and showcase biomedical-informatics rigor with near-zero risk.

## 2. Safety boundary reminder

This software is **not a medical device** and provides **no** diagnosis,
treatment, medication timing, diet decisions, patient-care guidance, or clinical
decision support. Every opportunity below MUST preserve all of the following
(see `CLAUDE.md`, `DISCLAIMER.md`, `docs/PUBLIC_DEMO_BOUNDARY.md`):

- Outputs stay **non-prescriptive, reviewable, evidence-linked, educational**.
- **Synthetic / public sample data only.** No real patient data, medication
  schedules, symptoms, identifiers, credentials, tokens, UIDs, PHI, or local
  paths.
- Medication dose passes through **only** from the user's explicit entry — never
  invented, inferred from a bare number, normalized, or privately defaulted.
- Missing data stays **missing** (never silently 0); uncertainty is reported.
- No claim of clinical validation/calibration; the model is **not clinically
  calibrated**.
- No live ingestion without opt-in + per-source license review.
- AI never enters the deterministic conflict engine as a source of truth.

Reference for the boundary: the U.S. FDA Clinical Decision Support Software
guidance describes four criteria distinguishing non-device CDS. ParkinSUM is
positioned as an educational prototype, not a CDS product; the relevant
engineering takeaway is to keep outputs transparent, reviewable, and
non-driving-of-clinical-action, and to avoid acquiring/analyzing patient signals
for a clinical purpose.

## 3. Source inventory

Access legend: `open_access` · `public_api` (no key) · `api_key` (key required)
· `downloadable` · `license_review` (account/terms review) · `citation_only`
· `fixture_suitable` (a synthetic fixture can model the public schema shape)
· `not_usable`.

| sourceId | Source | Owner | Category | Access | Fixture-suitable | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `src.dailymed.spl.webservices.v2` | DailyMed SPL Web Services v2 (`/spls`, `/spls/{SETID}`, `/spls/{SETID}/history`) | U.S. NLM | Drug label | `public_api` (no key; public domain — review terms), `downloadable` (ZIP/XML/JSON) | Yes | Section-level SPL + label version/effective date + history. Already fixture-tested + opt-in smoke. |
| `src.fda.spl.standard` | FDA Structured Product Labeling standard + LOINC section codes | U.S. FDA | Drug label | `citation_only` / `downloadable` (spec) | Yes | Defines SPL section identity (LOINC); basis for section provenance. |
| `src.rxnorm.rxnav.api` | RxNorm + RxNav/RxClass REST API (RxCUI, ATCPROD→ATC L1–4) | U.S. NLM | Drug identity/coding | `public_api` (review terms) | Yes | Identity normalization + ATC class only; **not** a food-effect source. Currently `spec_only` in the app. |
| `src.hc.dpd.api` | Health Canada Drug Product Database + monographs | Health Canada | Drug label | `public_api` / `downloadable` (open-data terms review) | Yes | Food-effect text often in monograph PDFs. Already fixture-tested. |
| `src.ema.epi.fhir` | EMA EPAR / ePI (FHIR) / SmPC | European Medicines Agency | Drug label | `downloadable` (reuse-terms review) | Yes | SmPC text supports mechanism evidence. Already fixture-tested. |
| `src.nhs.dmd.trud` | NHS dm+d (TRUD XML / NHS Terminology Server FHIR) | NHSBSA / NHS England | Drug identity/coding | `license_review` (dm+d + SNOMED CT licensing) | Yes | Identity/coding-strong; not a complete food-effect label source. |
| `src.pmda.package_insert` | PMDA package inserts / review reports | PMDA (Japan) | Drug label | `license_review` (terms) | Yes | Japanese authoritative; English index reference-only. |
| `src.nmpa.label` | NMPA drug approval / label | NMPA (China) | Drug label | `license_review` (terms) | Yes | Chinese authoritative; English mapping reference-only; prototype only, NOT live-verified. |
| `src.usda.fdc.api` | USDA FoodData Central REST API + OpenAPI spec | USDA ARS | Food composition | `api_key` (key required for live) | Yes | SR Legacy, Foundation, FNDDS, Branded. Amino-acid nutrient numbers extracted today. |
| `src.usda.fdc.foundation_docs` | FDC Foundation Foods Documentation (Apr 2024) | USDA ARS | Food composition metadata | `open_access` (downloadable PDF) | Yes | Foundation Foods carry **sample count, location, dates, analytical method** + derivation metadata — direct provenance source. |
| `src.fao.infoods` | FAO/INFOODS component identifiers (tagnames) + guidelines (conversions, data evaluation, food matching) | FAO | Food composition standard | `open_access` (downloadable) | Yes (spec) | ~800 component identifiers encoding method/expression/definition; basis for nutrient basis + missingness/confidence flags. |
| `src.ciqual.anses` | Ciqual food composition table | ANSES (France) | Food composition | `downloadable` (reuse-terms review) | Yes | French-language codes. Already fixture-tested. |
| `src.cnf.hc` | Canadian Nutrient File | Health Canada | Food composition | `downloadable` (open-data terms review) | Yes | Citation/fixture candidate; not yet wired. |
| `src.hl7.fhir.r5` | HL7 FHIR R5: MedicationKnowledge, NutritionIntake, Observation | HL7 International | Data standard | `open_access` (spec) | Yes (schema shape) | Target schemas for internal metadata mapping; NutritionIntake is the nutrition-specific resource (R5+/R6 ballot). |
| `src.ohdsi.omop.cdm` | OHDSI OMOP Common Data Model + standardized vocabularies | OHDSI | Data standard | `open_access` (spec) | Yes (concept mapping) | Person-centric observational standard; useful for concept-id mapping demos only (no patient data). |
| `src.fair.principles.2016` | FAIR Guiding Principles (Wilkinson et al. 2016, *Scientific Data*) | Wilkinson et al. | Data standard | `open_access` (DOI 10.1038/sdata.2016.18) | n/a | Findable/Accessible/Interoperable/Reusable; basis for source registry + provenance documentation. |
| `src.fda.cds.guidance` | FDA Clinical Decision Support Software guidance (final 2022; updated final issued 29 Jan 2026) | U.S. FDA | Safety / regulatory | `open_access` | n/a | Four Cures-Act criteria for non-device CDS; informs the safety boundary. **Cite the current 2026 final guidance as authoritative; 2022 is its lineage.** |
| `src.leta.gi_barriers.2023` | Leta et al., "Gastrointestinal barriers to levodopa transport and absorption in PD," *Eur. J. Neurol.* 2023 | Leta et al. | Mechanism review | `open_access` (eScholarship / institutional copies) | n/a | LNAA transport saturation, gastric emptying, GI dysfunction; mechanism direction only. |
| `src.npj.protein_restrict.2023` | "To restrict or not to restrict? ... dietary protein interactions on levodopa absorption," *npj Parkinson's Disease* 2023 | npj Parkinson's Disease | Mechanism review | `open_access` | n/a | Protein redistribution considerations; educational direction, NOT dietary advice. |
| `src.daphnet.fog` | Daphnet Freezing of Gait dataset | Bachlin et al. (UCI ML Repository) | Wearable time-series | `open_access` (CC BY 4.0, downloadable) | Synthetic-shape only | 10 PD subjects, ankle/knee/trunk accelerometers, 64 Hz. **Demo-shape only; no PD detection claims.** |
| `src.weargait.pd` | WearGait-PD open-access wearables dataset for gait in PD | (open-access dataset) | Wearable time-series | `open_access` (review terms) | Synthetic-shape only | Additional gait-in-PD reference; architecture demo only. |

> No credentials, API keys, tokens, UIDs, PHI, or local paths are recorded in
> this document or anywhere in the repo. All "fixture-suitable" entries mean a
> *synthetic* payload modeled on the public schema shape — never real data.

## 4. Opportunity matrix

Each opportunity lists: id · title · source(s) · source type · legal/access ·
biomedical rationale · app layer · implementation idea · required metadata ·
testing strategy · safety boundary · priority · complexity · risk · implement
now · reason.

### A — Drug-label importer realism

**OPP-A1 — SPL/SmPC section-level provenance**
- Sources: `src.dailymed.spl.webservices.v2`, `src.fda.spl.standard`, `src.ema.epi.fhir`
- Source type: official label + standard · Access: `public_api`/`downloadable` (terms review)
- Rationale: Food-effect and release behavior live in specific labeled sections; capturing section identity (LOINC), label version, and effective date makes provenance auditable and lets the engine cite the exact section.
- App layer: importer adapters → `SourceDocumentMetadata` / `DrugProductVariantMetadata` → explanation `sourceRefs`.
- Implementation idea: extend the SPL fixture parser to record `labelSection` (LOINC), `labelVersion`, `effectiveDate`, and per-section provenance; surface in the medication-context trace.
- Required metadata: section LOINC code, set id, version, effective date, jurisdiction.
- Testing: fixture parser test asserting section/version/date extraction + provenance flows into the trace; banned-phrase scan.
- Safety boundary: metadata only; no dose/timing inference; mechanism evidence still requires explicit label text.
- Priority **P1** · Complexity medium · Risk low · Implement now: **no** (needs fixture work) · Reason: high provenance value, bounded but more than a doc pass.

**OPP-A2 — Release-type / dose-form / combination-product extraction**
- Sources: `src.dailymed.spl.webservices.v2`, `src.ema.epi.fhir`
- Type: official label · Access: `public_api`/`downloadable`
- Rationale: IR vs ER/controlled-release and combination components (carbidopa/levodopa/entacapone) materially change the modeled absorption window; extracting them from label structure (not guessing) improves fidelity.
- App layer: importer → `DrugProductVariantMetadata.releaseType/doseForm/components` → absorption model.
- Implementation idea: parse SPL dosage-form + release-type + ingredient-strength arrays into the variant metadata; keep null when absent.
- Required metadata: dose form, release type, per-ingredient strength+unit, product identifier.
- Testing: fixtures for IR, ER, and a 3-component combo; assert release-type drives the openness profile; missing → insufficient (no guess).
- Safety: never default a release type; unknown → wider uncertainty.
- Priority **P1** · Complexity medium · Risk low · now: **no** · Reason: bounded importer work + tests.

**OPP-A3 — RxNorm/RxClass identity + ATC normalization**
- Sources: `src.rxnorm.rxnav.api`
- Type: identity/coding API · Access: `public_api` (review terms)
- Rationale: Normalized RxCUI + ATC class improves cross-jurisdiction identity matching and provenance, without any clinical inference.
- App layer: crosswalk / `SourceAuthorityScorer` identity layer.
- Implementation idea: `spec_only` → fixture parser mapping a synthetic RxNav response to RxCUI + ATC L1–4 for identity display only.
- Required metadata: RxCUI, ATC code(s), tty.
- Testing: fixture test mapping synthetic RxNav JSON → identity fields; assert no food-effect/mechanism claim is derived.
- Safety: identity/coding only; explicitly not a mechanism source.
- Priority **P2** · Complexity medium · Risk low · now: **no** · Reason: identity nicety, not on the critical path.

### B — Nutrition importer realism

**OPP-B1 — FDC Foundation Foods provenance metadata**
- Sources: `src.usda.fdc.foundation_docs`, `src.usda.fdc.api`
- Type: official food composition + docs · Access: `open_access` docs / `api_key` live
- Rationale: Foundation Foods carry sample count, location, dates, and analytical method — exactly the provenance signals the metadata-completeness gate and uncertainty model should consume instead of treating a value as fully certain.
- App layer: nutrition importer → `FoodVariantMetadata` → `MetadataCompletenessGate` → composition uncertainty.
- Implementation idea: extend the FDC fixture parser to capture `derivationCode`, `foodNutrientDerivation`, sample count, and basis; map to a per-nutrient confidence flag.
- Required metadata: derivation, sample n, analytical method, basis (per_100g/per_serving), data type (Foundation/SR/FNDDS/Branded).
- Testing: fixture with derivation+sample metadata → confidence flag; missing → lower completeness.
- Safety: provenance only; never fabricate a sample/method.
- Priority **P1** · Complexity medium · Risk low · now: **no** · Reason: high evidence-linkage value; needs fixture + entity fields.

**OPP-B2 — Expand FDC amino-acid extraction to real-schema coverage**
- Sources: `src.usda.fdc.api`, `src.usda.fdc.foundation_docs`
- Type: official food composition · Access: `api_key` live / `open_access` schema
- Rationale: The LNAA layer already prefers actual amino-acid fields; broadening to the full Foundation-Foods amino-acid array (with per-nutrient unit + basis) increases coverage and reduces proxy fallbacks.
- App layer: `AminoAcidExtractor` → `AminoAcidProfile` → competition model.
- Implementation idea: extend the extractor + fixtures to all FDC amino-acid nutrient numbers with mg→g normalization and partial-field flagging (already partly present); add per-nutrient basis.
- Required metadata: nutrient number, unit, amount, basis, partial flag.
- Testing: realistic FDC fixture covering the full LNAA set; assert actual-fields mode + partial handling.
- Safety: missing amino acids stay null; partial widens uncertainty.
- Priority **P1** · Complexity low–medium · Risk low · now: **no** (fixture + extractor) · Reason: extends an existing, well-tested seam.

**OPP-B3 — FAO/INFOODS tagname + nutrient missingness/confidence flags**
- Sources: `src.fao.infoods`
- Type: international standard · Access: `open_access`
- Rationale: INFOODS tagnames encode method/expression/definition; aligning internal nutrient codes to tagnames standardizes missingness and confidence reporting across jurisdictions.
- App layer: nutrition metadata model + provenance sidecar.
- Implementation idea: add an optional `tagname` + `confidence` field to projected nutrient lines; document the mapping.
- Required metadata: INFOODS tagname, expression/definition note, confidence.
- Testing: mapping unit test (synthetic) + doc.
- Safety: documentation/standardization only.
- Priority **P2** · Complexity low · Risk low · now: **no** · Reason: standards alignment, modest payoff.

**OPP-B4 — Prepared/raw/branded distinction + component decomposition**
- Sources: `src.usda.fdc.api` (data types), `src.fao.infoods` (food matching)
- Type: official + standard · Access: `api_key`/`open_access`
- Rationale: Cooked vs raw and branded vs generic change physical form and water content, which feed gastric emptying; preserving `dataType`/`preparationState` improves realism.
- App layer: `FoodItem.preparationState`/`basisType` → `FoodComponent`.
- Implementation idea: thread `dataType`/prep state from FDC into existing `preparationState`/`basisType` fields (already present on `FoodItem`).
- Required metadata: data type, preparation state, basis.
- Testing: fixture per data type; assert form/water flow into composition.
- Safety: missing prep → unknown, not guessed.
- Priority **P2** · Complexity low · Risk low · now: **no** · Reason: incremental on existing fields.

### C — Mechanistic model realism (remaining)

**OPP-C1 — Enteral-feeding educational scenario (separate)**
- Sources: `src.leta.gi_barriers.2023`, `src.npj.protein_restrict.2023`, `src.dailymed.spl.webservices.v2`
- Type: mechanism review + label · Access: `open_access`
- Rationale: Continuous enteral feeding changes protein delivery and gastric context; modeling it as a *separate educational scenario* (not advice) showcases mechanism breadth.
- App layer: replay scenarios + (optional) a distinct enteral context flag already present in the DB-backed usecase.
- Implementation idea: add explicit synthetic enteral replay scenarios (continuous vs bolus) and an educational trace note; no timing recommendation.
- Required metadata: feed mode, protein g/day (synthetic), source refs.
- Testing: replay scenario assertions + banned-phrase scan.
- Safety: educational caution only; "review with a qualified professional"; no schedule.
- Priority **P1** · Complexity low · Risk low · now: **partial** (scenario placeholder safe) · Reason: scenario placeholders are safe; full modeling later.

**OPP-C2 — Iron/mineral co-event educational caution trace**
- Sources: `src.leta.gi_barriers.2023` + a dedicated iron–levodopa interaction citation (to be added)
- Type: mechanism review · Access: `open_access`
- Rationale: Iron can chelate levodopa and reduce absorption; a non-levodopa co-event educational trace adds breadth without dosing advice.
- App layer: conflict engine co-event trace (non-levodopa events already excluded from levodopa scoring).
- Implementation idea: add an educational caution trace string + replay scenario for an iron co-event; no quantitative interaction score.
- Required metadata: co-event substance, source refs, caution text.
- Testing: replay scenario + safety-phrase test.
- Safety: educational caution only; not a timing rule.
- Priority **P2** · Complexity low · Risk medium (sourcing) · now: **no** · Reason: needs a verified iron-interaction citation first.

**OPP-C3 — MAO-B / tyramine educational caution (only if sourced)**
- Sources: drug label (MAO-B inhibitor SmPC/SPL) + tyramine reference (to be verified)
- Type: official label · Access: `downloadable`
- Rationale: Selective MAO-B inhibitors at therapeutic doses generally carry a lower tyramine concern than non-selective MAOIs; any caution must be precisely sourced and non-prescriptive.
- App layer: educational caution copy + replay scenario.
- Implementation idea: add caution ONLY if a label/peer-reviewed source supports it; otherwise leave out.
- Required metadata: source refs, jurisdiction, caution text.
- Testing: safety-phrase test; source presence gate.
- Safety: must not imply a diet rule; "review with a qualified professional".
- Priority **P2** · Complexity low · Risk medium (overclaim) · now: **no** · Reason: only with verified non-prescriptive sourcing.

**OPP-C4 — ER/controlled-release multi-dose stress tests**
- Sources: `src.dailymed.spl.webservices.v2` (ER label), `src.leta.gi_barriers.2023`
- Type: label + review · Access: `open_access`
- Rationale: Strengthens the already-implemented multi-dose + openness-profile behavior under ER kinetics.
- App layer: replay scenarios + tests.
- Implementation idea: add ER multi-dose day scenarios; assert wider/flatter windows + max-overlap aggregation.
- Required metadata: release type, dose offsets (synthetic).
- Testing: replay + engine tests.
- Safety: educational simulation only.
- Priority **P2** · Complexity low · Risk low · now: **no** · Reason: extends existing tested behavior.

### D — Replay & validation robustness

**OPP-D1 — Source-quality perturbation replay tests**
- Sources: `src.fair.principles.2016` (provenance rigor), internal
- Type: standard + internal · Access: `open_access`
- Rationale: Demonstrates that ranking degrades gracefully (and conflict stays dominant) as source authority/provenance worsens — a credibility signal.
- App layer: replay runner + scorer (read-only).
- Implementation idea: scenario pairs identical except for source authority/provenance; assert ordering + `scoringParameterSetId` invariants.
- Required metadata: candidate metadata variants.
- Testing: replay assertions.
- Safety: no behavior change; tests only.
- Priority **P1** · Complexity low · Risk low · now: **no** (small but >doc) · Reason: high-value, low-risk validation.

**OPP-D2 — Missingness stress-test replay suite**
- Sources: internal + `src.usda.fdc.foundation_docs` (what's commonly missing)
- Type: internal + docs · Access: `open_access`
- Rationale: Proves "missing ≠ zero" end-to-end and that completeness/uncertainty respond correctly.
- App layer: replay runner.
- Implementation idea: scenarios dropping protein/calories/portion/AA fields; assert missingFields + lowered confidence.
- Testing: replay assertions.
- Safety: tests only.
- Priority **P1** · Complexity low · Risk low · now: **no** · Reason: strong correctness guarantee.

**OPP-D3 — Counterfactual scenario pairs + uncertainty perturbation**
- Sources: internal
- Type: internal · Access: n/a
- Rationale: A/B fixtures (one variable changed) make the model's behavior legible and regression-safe.
- App layer: replay runner.
- Implementation idea: paired scenarios (e.g., liquid vs solid, IR vs ER) with asserted directional differences.
- Testing: replay assertions.
- Safety: tests only.
- Priority **P2** · Complexity low · Risk low · now: **no** · Reason: nice-to-have legibility.

**OPP-D4 — Clinical-calibration guardrail regression tests**
- Sources: `src.fda.cds.guidance`
- Type: regulatory guidance · Access: `open_access`
- Rationale: Locks in the non-device boundary: every replay case must report `not_clinically_calibrated`, `liveFetchEnabled == false`, and must not claim mechanism evidence it cannot support.
- App layer: replay runner test (read-only).
- Implementation idea: a regression test asserting the guardrail fields across all cases + a banned-phrase scan.
- Testing: this IS the test.
- Safety: directly enforces the boundary.
- Priority **P0** · Complexity low · Risk low · Implement now: **YES** · Reason: pure safety regression, bounded, no production code change.

### E — Biomedical-engineering showcase

**OPP-E1 — Optional synthetic wearable/gait time-series replay layer**
- Sources: `src.daphnet.fog` (CC BY 4.0), `src.weargait.pd`
- Type: open dataset (schema only) · Access: `open_access`
- Rationale: Demonstrates a time-series ingestion + feature-engineering + replay architecture (windowing, resampling, feature extraction) using **synthetic** signals shaped like public gait datasets — a biomedical-engineering credibility showcase.
- App layer: a NEW, **separate** module, fully decoupled from the conflict engine.
- Implementation idea: a synthetic accelerometer generator + deterministic feature/replay pipeline + report; clearly labeled non-diagnostic.
- Required metadata: synthetic signal spec, sampling rate, window config, dataset-shape citation.
- Testing: deterministic feature tests + banned-phrase scan; explicit "no PD detection/monitoring" assertions in copy.
- Safety: **must not** claim PD detection, monitoring readiness, or use real patient signals; synthetic/public-shape only; isolated from medication logic.
- Priority **P3** · Complexity high · Risk medium · now: **no** · Reason: large, separate; valuable showcase but must be carefully bounded.

### F — Data standards

**OPP-F1 — FHIR-inspired MedicationKnowledge metadata mapping**
- Sources: `src.hl7.fhir.r5`, `src.rxnorm.rxnav.api`
- Type: data standard · Access: `open_access`
- Rationale: Mapping internal medication metadata toward a MedicationKnowledge-like shape demonstrates interoperability literacy and FAIR alignment.
- App layer: a serialization view over `DrugProductVariantMetadata` (no behavior change).
- Implementation idea: a `toFhirLikeMedicationKnowledge()` mapper (educational, not a conformant resource) + doc.
- Required metadata: code (RxCUI/ATC), doseForm, ingredient+strength, sourceRefs.
- Testing: mapper unit test on synthetic metadata.
- Safety: representation only; explicitly "FHIR-inspired, not a conformant resource".
- Priority **P2** · Complexity medium · Risk low · now: **no** · Reason: showcase value, not on critical path.

**OPP-F2 — FHIR-inspired NutritionIntake / Observation mapping**
- Sources: `src.hl7.fhir.r5`, `src.fao.infoods`
- Type: data standard · Access: `open_access`
- Rationale: NutritionIntake (R5+) is the nutrition-specific resource; an inspired mapping standardizes the nutrition trace.
- App layer: serialization view over meal composition (no behavior change).
- Implementation idea: a `toFhirLikeNutritionIntake()`/Observation mapper + doc.
- Testing: mapper unit test on synthetic composition.
- Safety: representation only; synthetic data.
- Priority **P2** · Complexity medium · Risk low · now: **no** · Reason: showcase value.

**OPP-F3 — FAIR-aligned source registry + API/license review checklist**
- Sources: `src.fair.principles.2016`, all source terms
- Type: standard + governance · Access: `open_access`
- Rationale: A documented, FAIR-aligned source registry + a per-source API/license review checklist is required *before* any production ingestion and is a strong open-source governance signal.
- App layer: docs (`SOURCE_ACCESS_AND_LICENSES.md`) + optional registry constants.
- Implementation idea: add a license/API review checklist section + registry rows (done in part this pass).
- Testing: doc; optional registry presence test.
- Safety: gates live ingestion behind review.
- Priority **P1** · Complexity low · Risk low · now: **partial (doc rows added)** · Reason: governance, low risk.

## 5. Recommended implementation phases

- **Phase α (now, this pass — safe/doc/test only):** OPP-D4 guardrail regression
  test; OPP-F3 source-registry rows + checklist; bibliography + this map +
  backlog. (Implemented in this PR.)
- **Phase β (next, bounded importer/test work):** OPP-B1, OPP-B2 (FDC provenance
  + fuller amino-acids), OPP-D1, OPP-D2 (perturbation + missingness suites),
  OPP-C1 (enteral scenario placeholders → full).
- **Phase γ (label realism + standards):** OPP-A1, OPP-A2 (SPL section
  provenance + release/combination), OPP-F1, OPP-F2 (FHIR-inspired mappings),
  OPP-A3 (RxNorm identity), OPP-B3/B4.
- **Phase δ (showcase, carefully bounded):** OPP-E1 synthetic wearable/gait
  replay layer (separate module, non-diagnostic); OPP-C2/C3 only with verified,
  non-prescriptive sourcing.

## 6. Rejected / unsafe ideas

- ❌ Any patient-specific dose, timing, or diet recommendation. (Crosses the
  boundary.)
- ❌ Real patient data ingestion, real medication schedules, or wearable
  monitoring of real users. (PHI / device territory.)
- ❌ PD detection / diagnosis / symptom prediction from gait or any signal. (The
  wearable layer is synthetic, architectural, explicitly non-diagnostic.)
- ❌ Clinical calibration / PK-PD prediction / blood-concentration estimation.
- ❌ Hidden/default medication dosage; inferring a dose from a bare number.
- ❌ LLM/AI as a decision-maker inside the deterministic conflict engine.
- ❌ Live source ingestion without opt-in + per-source license review.
- ❌ Presenting any output as "safe", "recommended", or "clinically optimized".

## 7. Testability requirements

- Every new modeled assumption needs a `sourceId` in
  `model_assumption_registry.dart` mapped to `Bibliographies.md`.
- New importer fields need a fixture parser test over **synthetic** payloads
  shaped on the public schema; missing fields must stay null (never 0).
- New replay scenarios use **explicit synthetic data** and assert expected
  output type / severity / confidence / provenance + a banned-phrase scan.
- Safety regressions (calibration, live-fetch-off, dose passthrough,
  missing≠zero) must have dedicated tests.
- Determinism: identical inputs → identical outputs; no input-order dependence.

## 8. Bibliography update requirements

`Bibliographies.md` gains a **"Potential future model/data-flow sources"**
section with, per source: `sourceId`, title, owner/publisher, year, URL/DOI,
access type, implementation status (already used / implementation candidate /
citation only / not usable), limitation, and safety note. Only verifiable
sources are added (see §3). The current FDA CDS final guidance (2026, superseding
2022) is cited as the authoritative boundary reference.

## 9. Open issues to create

See `docs/BIOMEDICAL_ENGINEERING_BACKLOG.md` for issue-ready items (1–12),
each with motivation, source basis, scope, files, tests, acceptance criteria,
safety boundary, not-in-scope, labels, and dependencies. The backlog maps 1:1
onto the opportunities above.
