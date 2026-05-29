# Importer & Metadata Flow (Multi-Jurisdiction)

Educational prototype documentation. ParkinSUM is not a clinical product.
This document describes how multi-jurisdiction drug and food metadata flows
from importer to the mechanistic engine and next-meal scorer, and how source
authority, jurisdiction, language, and completeness are preserved.

## 1. Canonical metadata model

The app does not pass around bare values. Canonical, projection-surviving
metadata lives in `lib/domain/entities/source_metadata.dart`:

- `SourceDocumentMetadata` — sourceDocId, sourceSystem, jurisdiction,
  language, owner, docType, `SourceAuthorityTier`, `ReferenceTranslationStatus`,
  published/effective/updated dates, license, sourceRefs, limitationText.
- `DrugProductVariantMetadata` — activeIngredients, strengthValue/Unit,
  doseForm, route, releaseType, productIdentifier (NDC/DIN/EMA#/dm+d/PMDA/
  NMPA/local), labelSection, translationStatus, extractionConfidence,
  sourceRefs, limitationText.
- `FoodVariantMetadata` — basisType (per_100g/per_serving/per_meal/
  label_claim), servingUnit, preparationState, aminoAcidFieldsPresent,
  extractionConfidence, sourceRefs, limitationText.

The raw importer records in `cdss_records.dart` already carry most fields;
the canonical types are the *typed view that survives projection*.

## 2. Multi-jurisdiction importer architecture

The 8 concrete importers in `lib/data/datasources/remote/` already converge
on `P0ImportBundle` and are orchestrated source-agnostically by
`p0_ingestion_orchestrator.dart`. The new abstraction layer adds:

- `source_adapter.dart` — `SourceAdapterSpec` metadata contract
  (sourceSystem, jurisdiction, language, authorityTier, accessMethod,
  supportedDocumentTypes, updateCadence, licenseOrUseLimitations,
  parserConfidence, translationStatus, knownLimitations, `implemented`).
- `source_adapter_registry.dart` — specs for every source family.

## 3. Supported source families

Medication: DailyMed/US, Health Canada DPD/CA, EMA/EU, EU national
registers (spec-only), NHS dm+d/GB (spec-only), PMDA/JP, NMPA/CN
(spec-only), synthetic_demo. Food: USDA FDC/US, Ciqual/FR, China CDC/CN,
app_seed. See `Bibliographies.md` → "Multi-jurisdiction importer sources".

## 4. Source authority policy

`source_authority_scorer.dart` (`SourceAuthorityScorer`) scores 0..1:

- Official label/monograph/SmPC/package-insert in the relevant jurisdiction
  = highest.
- Official databases (DPD, dm+d, EU national register) strong for
  identity/coding; dm+d weaker for food-effect text.
- Reference translations (e.g. PMDA English index) downgraded ×0.8.
- Seed/synthetic capped at 0.3 — they **never** outrank official data
  (`seedMayOverride()` always returns false).
- Jurisdiction match modulates (closest chain entry = 1.0, GLOBAL = 0.2,
  unmatched = 0.0) but never zeroes a tier.

## 5. Cross-jurisdiction conflict policy

`classifyConflict(...)` returns `sameJurisdiction`,
`differentJurisdictionNoConflict`, `differentJurisdictionConflict`, or
`unknown`. Cross-jurisdiction differences are **preserved**, never silently
collapsed/merged.

## 6. Food nutrient metadata requirements

basisType (per_100g vs per_serving), servingUnit, preparationState
(raw/cooked/branded/generic), source system + jurisdiction + language,
extraction confidence, amino-acid field presence, sourceRefs, limitationText.
Missing basis → lower confidence (never faked completeness).

### 6a. Missing ≠ zero

Absent nutrient data is carried as **missing/unknown**, never coerced to a true
`0 g`. `FoodItem` keeps its non-nullable nutrient getters for UI compatibility
but carries the missingness in a parallel `missingNutrientFields` set (e.g.
`proteinG`, `energyKcal`, `waterG`). The candidate adapter
(`catalog_food_to_candidate.dart`) passes **null** to `FoodComponent` for any
field in that set, so the `MealCompositionNormalizer` records it in
`missingFields`, lowers `compositionCompleteness`, and the gastric-emptying
layer widens its uncertainty band. A real measured `0` (field present, value
zero) is preserved as a true zero. The projection service
(`CdssCatalogProjectionService.projectFoods`) records which observation
attributes were actually present and populates `missingNutrientFields` for the
rest.

### 6b. Actual amino-acid fields

When USDA FDC amino-acid fields are available, `AminoAcidExtractor` builds an
`AminoAcidProfile` (verified nutrient-number mapping: 501 Trp, 502 Thr, 503
Ile, 504 Leu, 506 Met, 508 Phe, 509 Tyr, 510 Val, 512 His; number takes
priority over name; mg→g normalized; missing-unit values marked `partial`).
This profile is carried on `FoodItem.aminoAcidProfile` → `FoodComponent` →
the LNAA layer, which uses the actual fields
(`AminoAcidDataMode.actualAminoAcidFields`) in preference to the protein-source
proxy. Payloads without any LNAA field fall back to the proxy.

## 7. Medication metadata requirements

activeIngredient(s), strengthValue + unit, doseForm, route, releaseType,
productIdentifier, jurisdiction, language, labelSection, translationStatus,
sourceRefs, limitationText. Missing unit → no dose; missing ingredient → no
drug context; missing release type → limited/blocked PK interpretation.

## 8. Catalog projection

`CdssCatalogProjectionService.projectFoods()` / `projectDrugs()` produce the
runtime `FoodItem` / `DrugDefinition`. `AppState._augmentFoodRepoFromProjection()`
merges projected foods into the runtime repo at boot (best-effort; seed
fallback). Provenance metadata is carried alongside as
`CandidateMetadata` for the scorer.

## 9. Metadata completeness gate

`metadata_completeness_gate.dart` grades `complete` / `sufficient` /
`partial` / `insufficient` / `invalid` for medication context, candidate
food, and rule explanation. Composes with the hard `MedicationEntryValidator`
gate; adds the softer downgrade/uncertainty layer.

### 9a. Componentized meal-history join

Historical meals are modeled as one `FoodComponent` per logged `MealItem`
(`next_meal_recommendation_orchestrator._buildMealCompositions` →
`mealItemToFoodComponent`), not a single `unknown` aggregate. Each item is
joined by `foodId` to the merged catalog `FoodItem` to recover physical form
(`textureClass → MealPhysicalForm`), energy (`energyKcal`, scaled to the logged
serving), protein source, and the amino-acid profile (scaled to the serving via
`AminoAcidProfile.scaledToGrams`). Logged macros come from the item itself;
catalog data only enriches. When the catalog lacks a field it stays null and is
recorded as missing — never coerced to 0. This preserves component structure,
liquid fraction, and amino-acid provenance for the gastric/LNAA layers.

## 10. How metadata feeds the mechanistic engine

`TimeAxisConflictContext` → gastric emptying → absorption opportunity →
amino-acid competition (LNAA load by protein source) → interaction score →
`MechanisticExplanation` (carries sourceRefs, limitation, safety boundary).
`CandidateMetadata` (completeness, authority, jurisdiction match, provenance
quality) flows into `MechanisticCandidateScore`. The orchestrator builds it
per candidate from the imported source data on each `FoodItem`:
`SourceAuthorityScorer` scores authority + jurisdiction match against the
user's jurisdiction chain (`registrationRegion` + `contentJurisdictionOverride`
+ `dietProfileRegion`); `MetadataCompletenessGate` grades completeness from a
`FoodVariantMetadata`; provenance quality rewards traceable source codes, basis
type, explicit jurisdiction, and actual amino-acid fields. Official-in-
jurisdiction outranks synthetic/seed; out-of-jurisdiction official is retained
but downgraded; seed never overrides official; missing metadata → neutral
defaults (never fake-high).

## 11. How metadata feeds next-meal scoring

`MechanisticNextMealScorer` composes `finalCandidateScore` from conflict
overlap, protein-redistribution score, nutrition-adequacy contribution,
metadata completeness, source authority, jurisdiction match, provenance
quality, and uncertainty penalty. Ranking is by `finalCandidateScore` DESC.

## 12. Protein redistribution objective

`protein_distribution_model.dart` — NOT global protein minimization. Window
role is decided **primarily from modeled overlap**: high overlap → protein
penalized; low overlap → protein allowed and redistribution-compatible. A
local-hour hint only refines the *label* (evening candidate) and never
overrides overlap — a 20:00 window with active overlap is not
auto-redistribution. A nutrition-adequacy proxy keeps zero-protein from
automatically winning. Missing medication/timeline context → unknown role,
optimization off.

## 13. User-defined time window requirement

Mechanistic-primary ranking activates only when the request carries a
`userDefinedWindow` (the user supplies it via the next-meal page window
chooser) AND confidence is medium/high AND every candidate is scored. The
engine never chooses the meal time; it ranks candidates *inside* the window
the user provided. Otherwise the legacy heuristic fallback runs and
`rankerUsed = heuristic_legacy_fallback` is surfaced.

## 14. Why the engine does not globally minimize protein

Protein-redistribution diets (Karstaedt & Pincus 1992; Cereda et al. 2010;
Virmani et al. 2023) redistribute protein away from levodopa-sensitive
windows rather than eliminating it; global minimization risks nutrition
inadequacy. ParkinSUM models the *direction* educationally and does not
prescribe a diet.

## 14b. Implemented vs future work (status)

**Implemented (fixture-tested, deterministic):**
- Concrete importers: DailyMed, Health Canada DPD, EMA, PMDA, USDA FDC,
  Ciqual, China CDC (existing) **plus a new `NmpaImporter`** that parses a
  synthetic NMPA-style payload into canonical `DrugProductVariantMetadata` +
  `SourceDocumentMetadata` (Chinese-language, reference-only translation) —
  see `test/nmpa_importer_test.dart` + `test/fixtures/importers/nmpa_levodopa_stub.json`.
- Canonical metadata fields (`source_metadata.dart`).
- `SourceAuthorityScorer` + cross-jurisdiction conflict policy.
- `MetadataCompletenessGate`.
- Protein-redistribution scoring drives the mechanistic-primary ranker
  (`finalCandidateScore`), with the legacy heuristic reordered/overridden when
  mechanistic-primary is eligible.
- Replay: **21 scenarios** with per-candidate protein/source/authority fields
  in the report.

**Now fixture-tested (concrete parsers added):**
- **NHS dm+d** (`DmdImporter`) — identity/coding parser; explicitly cannot
  supply food-effect mechanism evidence alone.
- **EU national register** (`EuNationalRegisterImporter`) — member-state
  identity parser; distinguishes register identity from full SmPC text.

**Spec-only (registry metadata, no concrete parser yet):**
- (none of the named medication families remain spec-only; remaining
  spec-only entries are future additional sources.)

**Fetch abstraction:** `SourceFetchClient` (interface) +
`HttpSourceFetchClient` (live) + `FakeSourceFetchClient` +
`FixtureSourceFetchClient` (offline, returns a structured `SourceFetchResult`
with explicit failure metadata; no fake fact on failure). Tests never touch
the network.

**Amino-acid extraction:** `AminoAcidExtractor.extractFromFdcStyle(...)` builds
an `AminoAcidProfile`; the competition model prefers actual amino-acid fields
(`actualAminoAcidFields` mode) over the protein-source proxy
(`proteinSourceProxy`), falling back to `unknown` when neither is present.

## 14c. FHIR-inspired NutritionIntake view (local, PHI-free)

`FhirInspiredNutritionIntakeMapper.fromMealComposition(...)` serializes a
`MealComposition` into a local **FHIR-inspired** view
(`FhirInspiredNutritionIntakeView`) for educational traceability and
reviewability — food components, nutrient summary, amino-acid provenance,
missingness, and sourceRefs in a NutritionIntake-shaped structure.

It is **inspired, not FHIR-conformant**: `conformance_status =
inspired_not_conformant`. HL7 FHIR `NutritionIntake` is patient-centric
(`subject` → Patient); this view **omits `subject` and all patient-linkage /
clinical fields** (no patient, encounter, practitioner, care team, diagnosis, or
treatment) and never constructs a Patient/Reference/Encounter
(`phi_policy = subject_omitted_no_phi`). It carries `not_clinically_calibrated =
true` and the shared non-prescriptive safety copy. It implies **no clinical
interoperability** and supports no diagnosis, treatment, or patient monitoring.

## 15. Future work

- Live network ingestion + real schema parsers for **dm+d** and **EU national
  registers** (specs exist today; concrete fixture parsers / live fetch are
  future work). NMPA now has a fixture-tested parser; live NMPA fetch + real
  schema remain future work.
- Per-food amino-acid array extraction from FDC/Ciqual into the LNAA layer.
- Patient-population calibration of gastric-emptying / PK parameters.
- Source-specific legal/license review before any production ingestion.

## 16. Educational-only rationale

Per FDA CDS guidance framing, ParkinSUM's outputs are reviewable, bounded,
and non-prescriptive. Nothing here is medical advice, a diagnosis, a dosing
or timing recommendation, or a claim of clinical validation.
