# Biomedical Standards Conformance Scorecard

> Research-and-planning artifact. Scores ParkinSUM Companion's **current**
> data/metadata model against recognized biomedical-informatics standards and
> authoritative source schemas, with **code evidence** for every row and a
> concrete, bounded delta to advance each gap. This is a gap analysis, not an
> implementation, and it changes nothing about the project's intended use.
>
> Companion documents: `docs/BIOMEDICAL_ENGINEERING_OPPORTUNITY_MAP.md` (what to
> build), `docs/BIOMEDICAL_TRACEABILITY_MATRIX.md` (opportunity↔source↔test↔
> safety), `docs/design/SPIKE_FDC_FOUNDATION_PROVENANCE.md` (the top item, fully
> specified), `docs/BIOMEDICAL_ENGINEERING_BACKLOG.md` (issue-ready tasks).

## 0. Why this document exists (gap vs. the prior pass)

The first opportunity-map pass surveyed sources and proposed work, but it never
measured **where the current code already stands** against the standards it
cited. Without a baseline, "map toward FHIR" and "align to FAIR" are
aspirations, not engineering tasks. This scorecard fixes that: it reads the
shipped entities/usecases, assigns an honest conformance level, and states the
exact next increment. It is deliberately conservative about claims — see §2.

## 1. Safety boundary reminder

ParkinSUM is an **educational / research prototype**, **not a medical device**,
and provides no diagnosis, treatment, medication timing, diet decisions,
patient-care guidance, or clinical decision support. This scorecard implies **no
clinical validation or standards certification**. Specifically:

- "Aligned" below means *internal model + a clearly-labeled, **inspired,
  non-conformant** view* — never a certified/conformant FHIR/OMOP artifact.
- Any FHIR-inspired mapping MUST omit `subject`/Patient and all PHI: ParkinSUM
  models synthetic food/medication metadata, **not** a patient record.
- Provenance/identity work is metadata only; it never adds dose/timing
  inference, and dose still passes through only from explicit user entry.
- Missing source data stays missing (never 0); uncertainty is reported.

## 2. Scoring scale (honest by construction)

| Level | Symbol | Meaning |
| --- | --- | --- |
| Absent | ⬜ | The construct is not represented in the model. |
| Inspired-Partial | 🟡 | Internal fields capture **some** of the construct's intent; no standard-shaped serialization/view. |
| Inspired-Aligned | 🟢 | Internal model captures the intent **and** a clearly-labeled "*-inspired, non-conformant*" view/serialization exists, with tests. |

There is **deliberately no "Conformant / Certified" level.** ParkinSUM does not
claim conformance to FHIR, OMOP, SPL, or any standard, and must not. The ceiling
of this scorecard is 🟢 *Inspired-Aligned*.

## 3. Scorecard summary

| # | Standard / construct | Current | Target (safe ceiling) | Opportunity | Backlog |
| --- | --- | --- | --- | --- | --- |
| S1 | HL7 FHIR R5 **MedicationKnowledge** | 🟡 | 🟢 | OPP-F1 | #8 |
| S2 | HL7 FHIR R5 **NutritionIntake** | 🟡 | 🟢 | OPP-F2 | #9 |
| S3 | HL7 FHIR R5 **Observation** (nutrient) | ⬜ | 🟡 | OPP-F2 | #9 |
| S4 | **FDA SPL** + LOINC section identity | 🟡 | 🟢 | OPP-A1 | #1 |
| S5 | **USDA FDC** FoodNutrient provenance (derivation/dataPoints/dataType) | 🟡 | 🟢 | OPP-B1 / OPP-B2 | #2 + spike |
| S6 | **FAO/INFOODS** component identifiers (tagnames) | ⬜ | 🟡 | OPP-B3 | (map) |
| S7 | **RxNorm / ATC** identity coding | ⬜ | 🟡 | OPP-A3 | (map) |
| S8 | **OMOP CDM** concept identity (non-patient) | ⬜ | 🟡 | OPP-F1/F2 adjunct | (map) |
| S9 | **FAIR** principles (source provenance) | 🟡 | 🟢 | OPP-F3 / OPP-D4 | #11, #12 |

**Posture reading:** the model is strongest on **FAIR provenance** (a versioned
in-code source registry, sourceRefs on every modeled assumption, and a
source-access/license doc) and on **FDC amino-acid extraction**; it is weakest on
**standard-shaped serialization** (no FHIR-inspired views yet) and **coded
identity** (no RxCUI/ATC/INFOODS/OMOP concept ids). The highest evidence-value,
lowest-risk increments are **S5 (FDC provenance)** and **S9 (FAIR guardrail
regression)** — both deepen evidence-linkage without touching the safety
boundary.

## 4. Per-standard detail (with code evidence)

### S1 — HL7 FHIR R5 MedicationKnowledge — 🟡 Inspired-Partial

- **Standard:** `MedicationKnowledge` = "Information about a medication that is
  used to support knowledge" (HL7 FHIR R5). Key elements: `code`,
  `doseForm`, `ingredient` (item + strength), `definitional`, `monograph`,
  `relatedMedicationKnowledge`, `regulatory`.
- **Current state (evidence):** `DrugProductVariantMetadata`
  (`lib/domain/entities/source_metadata.dart`) carries `genericName`,
  `activeIngredients`, `strengthValue`+`strengthUnit`, `doseForm`, `route`,
  `releaseType`, `productIdentifier` (NDC/DIN/EMA#/dm+d/PMDA/NMPA), `labelSection`,
  `sourceRefs`, `limitationText`. This captures most MedicationKnowledge *intent*
  (form, ingredient+strength, identifier) but exposes only a flat
  `toJson()` — no FHIR-shaped element names, and **no coded `code`** (no
  RxCUI/ATC).
- **Delta to 🟢:** add a `toFhirInspiredMedicationKnowledge()` view (explicitly
  "inspired, non-conformant") mapping fields → FHIR element names, plus a coded
  `code` once RxCUI/ATC identity (S7) exists. No behavior change; serialization
  only.
- **Safety:** representation only; omit any patient linkage.

### S2 — HL7 FHIR R5 NutritionIntake — 🟡 Inspired-Partial

- **Standard (verified from hl7.org):** `NutritionIntake` top-level includes
  `status`, `code`, **`subject` (Patient/Group)**, `occurrence[x]`,
  `consumedItem` (`type` = food/fluid/enteral, `nutritionProduct`, `amount`,
  **`rate`** for enteral, `notConsumed`), and `ingredientLabel` (nutrient/amount
  pairs).
- **Current state (evidence):** `MealComposition` + `FoodComponent`
  (`lib/domain/entities/meal_composition.dart`) model the *consumedItem* intent:
  `physicalForm` (solid/liquid/mixed) ≈ `consumedItem.type`, `portionGrams` ≈
  `amount`, per-nutrient grams ≈ `ingredientLabel`, and the DB-backed usecase's
  enteral-feed context ≈ `consumedItem.rate`. Componentized meal history (one
  `FoodComponent` per logged item) already exists.
- **Delta to 🟢:** add a `toFhirInspiredNutritionIntake()` view mapping to the
  verified element names — **deliberately omitting `subject`/Patient** (no PHI).
  Map `physicalForm`→`consumedItem.type`, `portionGrams`→`amount`, enteral
  context→`rate`, amino-acid/macros→`ingredientLabel`.
- **Safety (critical):** NutritionIntake is patient-centric in FHIR; the
  ParkinSUM mapping must drop `subject` and stay synthetic, or it would imply a
  patient record. Label the view "FHIR-inspired, non-conformant, no subject".

### S3 — HL7 FHIR R5 Observation (nutrient) — ⬜ Absent

- **Standard:** `Observation` = measurements/assertions (`code`, `value[x]`,
  `component`, `derivedFrom`, `method`). FHIR notes Observation is *cumbersome*
  for full nutrition detail (hence NutritionIntake) — so Observation is only a
  secondary, per-nutrient representation.
- **Current state:** nutrient values are modeled as typed fields, not as
  Observation-shaped records. No mapping.
- **Delta to 🟡:** an optional per-nutrient `toFhirInspiredObservation()` (e.g.
  protein grams as an Observation with `method` carrying the FDC derivation from
  S5). Lower priority than S2.
- **Safety:** representation only.

### S4 — FDA SPL + LOINC section identity — 🟡 Inspired-Partial

- **Standard:** SPL documents and their sections are identified by **LOINC
  document/section codes**; DailyMed SPL Web Services v2 expose `/spls/{SETID}`
  and `/spls/{SETID}/history` (set id, version, effective date).
- **Current state (evidence):** `DrugProductVariantMetadata.labelSection` is a
  single free-text string; there is no LOINC section code, no `setId`, no
  `labelVersion`, no `effectiveDate`. Adapters are `fixture_tested` (see
  `docs/SOURCE_ACCESS_AND_LICENSES.md`).
- **Delta to 🟢:** capture `sectionLoincCode`, `setId`, `labelVersion`,
  `effectiveDate` from the SPL fixture parser; surface in the medication-context
  trace so the engine can cite the exact section. Missing → recorded missing,
  never guessed.
- **Safety:** metadata/provenance only; mechanism evidence still requires
  explicit label text.

### S5 — USDA FDC FoodNutrient provenance — 🟡 Inspired-Partial

- **Standard:** the FDC OpenAPI `FoodNutrient` (non-abridged) family carries, per
  nutrient value, a derivation (`foodNutrientDerivation` with `code`/`description`
  and nested `foodNutrientSource`), `dataPoints` (sample count), and
  `min`/`max`/`median`; foods carry a `dataType` (Foundation / SR Legacy / FNDDS
  / Branded). *(Exact field names to be re-verified against the live FDC OpenAPI
  spec as step 0 of the spike — see `docs/design/SPIKE_FDC_FOUNDATION_PROVENANCE.md`.)*
- **Current state (evidence):** `AminoAcidExtractor`
  (`lib/data/datasources/remote/amino_acid_extractor.dart`) extracts 9 LNAA-set
  nutrients by **verified number** (501,502,503,504,506,508,509,510,512) with a
  name fallback, mg→g normalization, and a `partial` flag for unit-ambiguous
  values. But `basis` is **hard-coded `per_100g`**, and it captures **no**
  derivation code, sample count, analytical method, or `dataType`.
- **Delta to 🟢:** capture derivation + dataPoints + dataType into
  `FoodVariantMetadata` and a per-nutrient confidence flag consumed by
  `MetadataCompletenessGate`; let `basis` be data-driven, not assumed. This is
  the fully-specified spike.
- **Safety:** provenance only; never fabricate a sample count or method; missing
  → lower completeness, not higher confidence.

### S6 — FAO/INFOODS component identifiers (tagnames) — ⬜ Absent

- **Standard:** INFOODS defines ~800 component identifiers ("tagnames") encoding
  method/expression/definition (e.g., `PROCNT` for protein, `FAT` for fat),
  enabling cross-table comparability.
- **Current state:** internal nutrient codes (`protein_g`, etc.) are app-local;
  no tagname alignment.
- **Delta to 🟡:** add an optional `tagname` to projected nutrient lines + a
  documented mapping; standardizes missingness/confidence reporting.
- **Safety:** documentation/standardization only.

### S7 — RxNorm / ATC identity coding — ⬜ Absent

- **Standard:** RxNorm RxCUI normalized drug identity; RxNav/RxClass `ATCPROD`
  maps products to ATC L1–4.
- **Current state (evidence):** RxNorm is `spec_only` in
  `docs/SOURCE_ACCESS_AND_LICENSES.md`; `productIdentifier` holds
  jurisdiction-local ids only; no RxCUI/ATC.
- **Delta to 🟡:** a fixture parser mapping a synthetic RxNav response → RxCUI +
  ATC for identity display only (explicitly **not** a mechanism source).
- **Safety:** identity/coding only.

### S8 — OMOP CDM concept identity (non-patient) — ⬜ Absent

- **Standard:** OHDSI OMOP CDM is a person-centric observational model with
  standardized vocabularies (concept_id). ParkinSUM has a concept-variant
  crosswalk in its CDSS tables but no OMOP concept_id mapping.
- **Current state:** crosswalk exists (`cdss_catalog_projection_service.dart`
  consumes `concept_variant_crosswalk`); no OMOP concept ids.
- **Delta to 🟡:** a **vocabulary-only** concept-id mapping demo (no person
  table, no patient data) showing identity interoperability. OMOP's
  person-centric tables are explicitly **out of scope** (PHI territory).
- **Safety:** identity demo only; never instantiate person/observation_period.

### S9 — FAIR principles (source provenance) — 🟡 Inspired-Partial

- **Standard:** FAIR = Findable / Accessible / Interoperable / Reusable
  (Wilkinson et al. 2016, *Scientific Data*, DOI 10.1038/sdata.2016.18).
- **Current state (evidence):** **Findable/Reusable** are partly met —
  `ModelAssumptionRegistry` (`lib/domain/usecases/model_assumption_registry.dart`)
  gives every modeled assumption a stable `sourceId`, citation text, evidence
  level, and `lastReviewed` date; `SOURCE_ACCESS_AND_LICENSES.md` records access
  + license-review status. **Interoperable** is weaker (no machine-readable
  license tags / persistent DOIs in-model).
- **Delta to 🟢:** (a) a **traceability guard test** asserting every sourceRef
  the mechanism layer emits resolves in the registry (shipped this pass — see
  §6); (b) machine-readable license/access tags per source; (c) the
  clinical-calibration guardrail regression (backlog #12).
- **Safety:** governance/provenance; gates live ingestion behind review.

## 5. Aggregate deltas, sequenced

1. **Now (safe, this pass):** S9 traceability guard test + stale-entry
   correction (shipped); this scorecard + traceability matrix + FDC spike.
2. **Next (bounded importer/test):** S5 FDC provenance (spike), S4 SPL section
   identity, plus the missingness/perturbation replay suites.
3. **Then (standards views):** S1/S2/S3 FHIR-inspired serializations (no
   subject), S7 RxNorm/ATC identity, S6 INFOODS tagnames, S8 OMOP concept demo.

## 6. What shipped in this pass (evidence)

- **S9 traceability guard** — `test/source_ref_traceability_test.dart` asserts
  every `sourceRef` emitted by the mechanism layer (conflict engine, gastric
  model, absorption model, amino-acid competition, protein-distribution model,
  scoring parameter set) resolves to a `ModelAssumptionRegistry` entry with
  citation text. This enforces FAIR "Reusable/Interoperable" at the test gate:
  the engine cannot emit an unresolvable evidence reference.
- **Stale registry correction** — `src.fdc.api.amino_acid_fields` in
  `model_assumption_registry.dart` previously claimed the wrong nutrient numbers
  ("505 leucine, 509 phenylalanine, 511 valine") and that the importer "does not
  currently extract these fields." Both are now false (the amino-number fix
  shipped earlier; the extractor does extract them). Corrected to the verified
  mapping and current capability.

## 7. Out of scope / rejected (unchanged from boundary)

- ❌ Certified/conformant FHIR/OMOP artifacts or a real exchange endpoint.
- ❌ Any `subject`/Patient linkage, person table, or real patient data.
- ❌ Coded identity used to drive any clinical/dose/timing inference.
- ❌ Treating standards alignment as clinical validation.
