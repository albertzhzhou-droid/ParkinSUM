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
| S1 | HL7 FHIR R5 **MedicationKnowledge** | 🟢 | 🟢 | OPP-F1 ✅ | #8 (**view shipped**) |
| S2 | HL7 FHIR R5 **NutritionIntake** | 🟢 | 🟢 | OPP-F2 ✅ | #9 (**shipped**) |
| S3 | HL7 FHIR R5 **Observation** (nutrient) | ⬜ | 🟡 | OPP-F2 | #9 |
| S4 | **FDA SPL** + LOINC section identity | 🟢 | 🟢 | OPP-A1/A2 ✅ | #1 (**bridge shipped**) |
| S5 | **USDA FDC** FoodNutrient provenance (derivation/dataPoints/dataType) | 🟢 | 🟢 | OPP-B1 ✅ / OPP-B2 | #2 + spike (**B1 shipped**) |
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

### S1 — HL7 FHIR R5 MedicationKnowledge — 🟢 Inspired-Aligned (MK view shipped)

- **Standard:** `MedicationKnowledge` = "Information about a medication that is
  used to support knowledge" (HL7 FHIR R5). Key elements: `code`,
  `doseForm`, `ingredient` (item + strength), `definitional`, `monograph`,
  `relatedMedicationKnowledge`, `regulatory`.
- **Current state (evidence):** a local **FHIR-inspired, PHI-free**
  `FhirInspiredMedicationKnowledgeView`
  (`lib/domain/entities/fhir_inspired_medication_knowledge_view.dart`) +
  `FhirInspiredMedicationKnowledgeMapper`
  (`lib/domain/usecases/fhir_inspired_medication_knowledge_mapper.dart`) maps the
  engine-facing `MechanisticMedicationMetadata` (PR #33 bridge) into a clearly
  labeled serialization view: product id, active ingredients, combination
  components (carbidopa + levodopa preserved), product strengths, dose form,
  route, release type + source, source-document id/version/effective date, label
  section refs, sourceRefs, metadata completeness, limitation text. Marked
  `inspired_not_conformant` + `no_patient_no_administration_no_phi`. Tested in
  `test/fhir_inspired_medication_knowledge_view_test.dart` (recursive key-level
  no-PHI/clinical-key scan; banned-phrase scan; determinism).
- **Residual (not blocking 🟢):** no coded `code` — RxCUI/ATC identity (S7) is
  still future work, so the view carries names/keys, not a discrete drug code;
  the `section_code` slot currently carries the CDSS section key, not a discrete
  LOINC code (S4 residual). Mapping reflects FHIR *intent*, not conformance.
- **Safety:** representation only; **omits** patient/subject/encounter/
  practitioner/careTeam/MedicationRequest/MedicationAdministration/
  dosageInstruction/timing/prescription. **Product strength is product
  metadata, never a user intake dose** (tagged `product_label_metadata`); the
  view has no field for a user-taken dose, frequency, or timing. Not clinically
  calibrated; no clinical interoperability.

### S2 — HL7 FHIR R5 NutritionIntake — 🟢 Inspired-Aligned (F2 shipped)

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
- **Shipped (F2):** `FhirInspiredNutritionIntakeView` +
  `FhirInspiredNutritionIntakeMapper`
  (`lib/domain/entities/fhir_inspired_nutrition_intake_view.dart`,
  `lib/domain/usecases/fhir_inspired_nutrition_intake_mapper.dart`) serialize a
  `MealComposition` to a local, deterministic, **FHIR-inspired** view:
  `food_components` (≈ consumedItem), `nutrient_summary` (≈ ingredientLabel),
  `amino_acid_summary` + provenance, missingness, and sourceRefs. It is marked
  `conformance_status = inspired_not_conformant` and
  `phi_policy = subject_omitted_no_phi`, reuses the shared non-prescriptive
  safety copy, and carries `not_clinically_calibrated = true`.
- **Safety (critical, enforced):** the view **deliberately omits** `subject`,
  patient/encounter/practitioner/care-team/diagnosis/treatment, and any
  patient-record semantics — it never constructs a Patient/Reference/Encounter.
  A recursive key-level test asserts no patient-linkage keys are emitted. This
  is FHIR-*inspired*, **not** FHIR-conformant, and implies no clinical
  interoperability.

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

### S4 — FDA SPL + LOINC section identity — 🟢 Inspired-Aligned (A1/A2 shipped)

- **Standard:** SPL documents and their sections are identified by **LOINC
  document/section codes**; DailyMed SPL Web Services v2 expose `/spls/{SETID}`
  and `/spls/{SETID}/history` (set id, version, effective date).
- **Current state (evidence):** the CDSS record layer
  (`DrugLabelSectionRecord`: `sectionId`/`sectionKey`/`sectionTitle`/
  `sourceDocId`; `DrugProductVariantRecord`: `releaseType`/`route`/`dosageForm`/
  `labelVersion`) is now **bridged into the mechanistic context** via
  `MedicationContextMetadataAdapter` →
  `MechanisticMedicationMetadata.labelSectionRefs` →
  `NormalizedMedicationContext.metadata`. The per-event trace and replay report
  surface `medication_source_system`, `medication_source_doc_id`,
  `medication_source_version`, `medication_label_section_ref_count`,
  `medication_release_type` + `medication_release_type_source`, and combination
  components (carbidopa + levodopa). The engine can therefore cite the exact
  source section/version backing a product. Adapters remain `fixture_tested`
  (synthetic CDSS-style fixtures, not live ingestion; see
  `docs/SOURCE_ACCESS_AND_LICENSES.md`).
- **LOINC section codes (conservative, partial):** the FHIR-inspired
  MedicationKnowledge view now also maps the CDSS section key/title to a discrete
  **LOINC document-section code** via `LabelSectionCodeMapper`
  (`lib/domain/usecases/label_section_code_mapper.dart`) — a const table of nine
  well-known, verified FDA SPL headings (e.g. dosage and administration
  `34068-7`, warnings and precautions `43685-7`; source `src.fda.spl.standard`).
  Section refs expose `loinc_code` / `loinc_display` / `loinc_mapping_confidence`
  alongside the preserved `section_code` (original key).
- **Residual (not blocking 🟢):** mapping is conservative — sections outside the
  known table stay `unknown` (LOINC null, never guessed); deriving codes directly
  from a live SPL `<code>` element remains future work. Missing LOINC/provenance
  → recorded missing, never fabricated, and does **not** invalidate section
  provenance.
- **Safety:** metadata/provenance only; product strength never becomes an intake
  dose (the analyzable dose still comes solely from the user-facing dosage
  path); mechanism evidence still requires explicit label text.

### S5 — USDA FDC FoodNutrient provenance — 🟢 Inspired-Aligned (B1 shipped)

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
- **Shipped (B1):** `AminoAcidExtractor` now captures per-nutrient
  `foodNutrientDerivation` / `dataPoints` / `foodNutrientSource` and food
  `dataType`, and `basis` follows the payload when present.
  `NutrientDerivation` (new entity) maps the derivation to an ordinal
  `NutrientConfidenceTier` (analytical / calculated / imputedOrAssumed /
  unknown); `AminoAcidProfile.aggregateConfidenceTier` is a conservative
  weakest-wins aggregate. The LNAA competition layer surfaces
  `aminoAcidConfidenceTier` and **widens uncertainty for any
  weaker-than-analytical tier** (mirrors partial handling); the replay report
  surfaces it. Missing derivation stays null (never raises confidence).
- **Follow-up shipped:** the tier is now folded into
  `MetadataCompletenessGate.scoreCandidateFood` (a calculated/imputed/unknown
  tier downgrades the candidate-food completeness grade and blocks the top
  `complete` grade), and the FDC amino-acid block is captured more fully
  (lysine/cystine/arginine added for representation completeness; competing-LNAA
  math unchanged).
- **Safety:** provenance only; never fabricate a sample count or method; missing
  → never higher confidence.

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
