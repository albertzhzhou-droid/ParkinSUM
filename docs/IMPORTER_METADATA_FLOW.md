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

## 10. How metadata feeds the mechanistic engine

`TimeAxisConflictContext` → gastric emptying → absorption opportunity →
amino-acid competition (LNAA load by protein source) → interaction score →
`MechanisticExplanation` (carries sourceRefs, limitation, safety boundary).
`CandidateMetadata` (completeness, authority, jurisdiction match, provenance
quality) flows into `MechanisticCandidateScore`.

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

## 15. Future work

- Live network ingestion + real schema parsers for dm+d / NMPA / EU national
  registers (specs exist today; concrete fixture parsers / live fetch are
  future work).
- Per-food amino-acid array extraction from FDC/Ciqual into the LNAA layer.
- Patient-population calibration of gastric-emptying / PK parameters.

## 16. Educational-only rationale

Per FDA CDS guidance framing, ParkinSUM's outputs are reviewable, bounded,
and non-prescriptive. Nothing here is medical advice, a diagnosis, a dosing
or timing recommendation, or a claim of clinical validation.
