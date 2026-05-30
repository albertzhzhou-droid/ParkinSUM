# Design Spike — USDA FDC Foundation-Foods nutrient provenance

> **Status: IMPLEMENTED** (core slice shipped). The fixture-side data contract,
> extractor capture, confidence-tier mapping, competition-uncertainty
> integration, replay-report surfacing, and tests below are now in the codebase
> (`nutrient_derivation.dart`, `amino_acid_profile.dart`,
> `amino_acid_extractor.dart`, `amino_acid_competition_model.dart`,
> `mechanistic_replay_runner.dart`; tests `nutrient_derivation_test.dart`,
> extended `amino_acid_extraction_test.dart` / `lnaa_competition_test.dart` /
> `mechanistic_replay_runner_test.dart`). **Deferred to a follow-up:** folding
> the tier into `FoodVariantMetadata`/`MetadataCompletenessGate` for the
> candidate-food completeness grade (the uncertainty widening is wired through
> the LNAA competition layer today), and live FDC ingestion (still opt-in only).
> Original implementation-ready specification follows.
>
> Educational / research prototype only. **Not a medical device.** Provenance
> metadata only — no dose/timing/diet inference, no clinical calibration,
> synthetic fixtures only, missing ≠ zero.

## 0. Step 0 — verify field names against the live FDC OpenAPI (required first)

The FDC schema HTML/JSON/YAML is JS-rendered and was **not fetchable** in the
planning environment, so the exact field names below are taken from the
documented FDC OpenAPI `FoodNutrient` family and **must be confirmed** against
the live spec before coding:

- FDC Nutrient Data OpenAPI: `https://fdc.nal.usda.gov/api-spec/fdc_api.html`
  (HTML), plus JSON/YAML variants linked from `https://fdc.nal.usda.gov/api-guide/`.
- Foundation Foods Documentation: `https://fdc.nal.usda.gov/Foundation_Foods_Documentation/`.

Acceptance for Step 0: a short note in the PR confirming the live field names for
`foodNutrientDerivation.code`, `foodNutrientDerivation.description`,
`foodNutrientSource`, `dataPoints`, `min`/`max`/`median`, and food-level
`dataType`. If a name differs, update the data contract before implementing.

## 1. Problem & current-state evidence

ParkinSUM's nutrition chain treats an extracted nutrient amount as a bare number
with a hard-coded basis and no indication of **how** that number was derived
(measured analytically? calculated? imputed? from how many samples?). That is
exactly the provenance the metadata-completeness gate and uncertainty model
should consume — and exactly what FDC publishes.

**Evidence from the shipped code:**

- `lib/data/datasources/remote/amino_acid_extractor.dart`
  - Extracts 9 LNAA-set nutrients by verified number (501,502,503,504,506,508,
    509,510,512) with a name fallback; normalizes mg→g; sets a single `partial`
    flag when a unit is missing/unrecognized.
  - **Hard-codes** `const basis = 'per_100g'` and `const unit = 'g'`.
  - Captures **no** derivation code, **no** `dataPoints` (sample count), **no**
    analytical method, **no** food `dataType`.
- `lib/domain/entities/amino_acid_profile.dart` — `AminoAcidProfile` has per-acid
  grams, `unit`, `basis`, `nutrientIds`, `sourceRefs`, `partial`. No per-nutrient
  derivation/confidence.
- `lib/domain/entities/source_metadata.dart` — `FoodVariantMetadata` has
  `basisType`, `servingUnit`, `preparationState`, `aminoAcidFieldsPresent`,
  `extractionConfidence`, `sourceRefs`. No FDC `dataType`, no per-nutrient
  derivation, no sample count.
- `MetadataCompletenessGate` already grades candidate-food completeness and feeds
  composition uncertainty — the natural consumer of a per-nutrient confidence
  signal.

Conformance baseline: **S5 = 🟡 Inspired-Partial**
(`docs/BIOMEDICAL_STANDARDS_CONFORMANCE_SCORECARD.md`).

## 2. Goal & non-goals

**Goal:** capture FDC-published nutrient provenance (derivation, sample count,
data type, real basis) as **optional, nullable** metadata, map it to a
deterministic per-nutrient **confidence tier**, and let the completeness gate /
uncertainty model consume it — moving S5 to 🟢 *Inspired-Aligned*.

**Non-goals:** live FDC ingestion (API key required; stays opt-in smoke only);
changing any mechanism magnitude; any clinical/dose/timing inference; inventing
provenance when FDC omits it.

## 3. Data contract (additive, nullable)

All new fields are **optional and nullable** so existing call sites and fixtures
are unaffected and "missing ≠ zero" holds.

### 3.1 New value type — `NutrientDerivation`

```
class NutrientDerivation {           // new: domain/entities/nutrient_derivation.dart
  final String? derivationCode;      // FDC foodNutrientDerivation.code (e.g. "A", "NC", "LCCD")
  final String? derivationDescription; // human-readable
  final String? sourceCode;          // FDC foodNutrientSource.code
  final int? dataPoints;             // FDC dataPoints (sample count); null = unknown (NOT 0)
  final double? min;                 // optional FDC min
  final double? max;                 // optional FDC max
  final double? median;              // optional FDC median

  NutrientConfidenceTier get tier;   // derived; see §4
}
enum NutrientConfidenceTier { analytical, calculated, imputedOrAssumed, unknown }
```

### 3.2 `AminoAcidProfile` (additive)

- Add `String? perNutrientBasis` — replaces the hard-coded assumption when FDC
  reports a different basis; defaults to existing behavior when null.
- Add `Map<String, NutrientDerivation>? derivations` keyed by nutrient field
  name (e.g. `"leucine"`). Null/absent → unchanged behavior.

### 3.3 `FoodVariantMetadata` (additive)

- Add `String? fdcDataType` — Foundation / SR Legacy / FNDDS / Branded.
- Add `NutrientConfidenceTier? aggregateNutrientConfidence` — the weakest tier
  across present nutrients (conservative).

> Every new field is nullable. A fixture or call site that omits them behaves
> exactly as today. No field defaults to a fabricated value.

## 4. Confidence-tier mapping (deterministic, documented)

Map FDC `derivationCode` → `NutrientConfidenceTier` via a small, **sourced**
table (registry-tagged `src.usda.fdc.foundation_docs` + the OpenAPI spec):

| FDC derivation family (verify exact codes in Step 0) | Tier |
| --- | --- |
| Analytical / directly measured | `analytical` |
| Calculated from other components / recipe | `calculated` |
| Imputed / assumed / borrowed from similar food | `imputedOrAssumed` |
| Missing or unrecognized code | `unknown` |

Rules:
- `dataPoints == null` does **not** raise the tier (unknown sample count never
  implies higher confidence).
- Tier is **prototype-heuristic** mapping of provenance → an ordinal signal; it
  is **not** a measurement-uncertainty estimate and carries no clinical meaning.
- The aggregate tier on `FoodVariantMetadata` is the **weakest** present tier
  (conservative; a single imputed nutrient lowers the aggregate).

## 5. Parser & integration changes

1. **Extractor** (`amino_acid_extractor.dart`): when the FDC payload includes
   `foodNutrientDerivation` / `dataPoints` / `foodNutrientSource` per nutrient,
   build a `NutrientDerivation` and attach it to the profile's `derivations`
   map; read the food-level `dataType`; let `basis` follow the payload when
   present (fall back to `per_100g` only when absent, as today). All additive;
   the existing return contract (null when no LNAA fields) is unchanged.
2. **Completeness gate** (`metadata_completeness_gate.dart`): when an aggregate
   nutrient confidence tier is present, fold it into the existing completeness
   grade (e.g., `imputedOrAssumed`/`unknown` cannot reach the top grade). When
   absent, behavior is unchanged.
3. **Uncertainty:** a lower confidence tier widens composition/competition
   uncertainty by one step (mirrors the existing partial-amino-acid widening),
   tagged as a prototype heuristic. No magnitude in the mechanism layer changes.
4. **Trace/report:** surface `fdcDataType`, `aggregateNutrientConfidence`, and
   per-nutrient `derivationCode` in the existing food-variant trace and (where a
   candidate is scored) the replay report — additive JSON keys only.

## 6. Test matrix (synthetic fixtures only)

| # | Fixture | Asserts |
| --- | --- | --- |
| T1 | Foundation food, analytical derivation, dataPoints=12 | tier `analytical`; dataType `Foundation`; derivation surfaced |
| T2 | Calculated derivation | tier `calculated` |
| T3 | Imputed/assumed derivation | tier `imputedOrAssumed`; aggregate confidence lowered; uncertainty widened |
| T4 | Missing derivation block entirely | tier `unknown`; **no fabricated** sample count (`dataPoints == null`); completeness lowered, not raised |
| T5 | Mixed nutrients (one analytical, one imputed) | aggregate tier = weakest (`imputedOrAssumed`) |
| T6 | Non-`per_100g` basis present in payload | `perNutrientBasis` reflects payload; no silent `per_100g` assumption |
| T7 | Legacy fixture (no provenance fields at all) | identical output to today (regression: additive only) |
| T8 | `sourceRef` resolves | `src.usda.fdc.foundation_docs` present in registry (traceability guard) |
| T9 | Banned-phrase scan | serialized trace carries no prescriptive/clinical phrasing |

All fixtures are **synthetic payloads shaped on the public FDC schema** — never
real FDC exports, never an API key.

## 7. Acceptance criteria

- A synthetic Foundation-food fixture yields derivation + dataPoints + dataType
  in the food-variant trace; a missing derivation is recorded **missing**
  (`null`), never as 0 or a guessed method.
- Confidence tier is deterministic and conservative (weakest-wins aggregate;
  unknown sample count never raises confidence).
- Lower tier lowers completeness and widens uncertainty; absent provenance leaves
  current behavior unchanged (T7 regression green).
- Every new `sourceRef` resolves in `ModelAssumptionRegistry` (traceability guard
  green); banned-phrase scan clean.
- `dart format` + `flutter analyze` clean; full suite + replay green.

## 8. Rollout

- Purely additive + opt-in: no live ingestion. The opt-in live smoke harness
  stays metadata-only and never stores raw payloads.
- No flag needed (nullable fields are inert until a fixture/parser supplies
  them), but the PR should land extractor + entity + gate + tests together so the
  new fields are exercised on day one.

## 9. Safety analysis

- **Missing ≠ zero:** every provenance field is nullable; tests T4/T7 lock that a
  missing derivation lowers (never raises) confidence and is never fabricated.
- **No clinical claim:** confidence tier is an ordinal provenance signal, not a
  measurement-uncertainty or clinical-accuracy estimate; documented as a
  prototype heuristic with `src.usda.fdc.foundation_docs`.
- **No dose/timing/diet inference:** nutrition-side metadata only; the medication
  dose passthrough invariant is untouched.
- **Provenance integrity:** new `sourceRef` gated by the traceability guard.

## 10. Out of scope (this spike)

- Live FDC ingestion / production parser (key + license review required).
- Non-LNAA nutrient derivation beyond what the completeness gate consumes.
- Any change to gastric/absorption/LNAA magnitudes.
- INFOODS tagname alignment (separate item, OPP-B3).

## 11. Effort & sequencing

- **Effort:** medium (1 new value type + 2 additive entity fields + extractor
  branch + gate fold-in + ~9 fixture tests). No refactor of existing seams.
- **Sequence:** unblocks **OPP-B2** (fuller amino-acid coverage reuses the same
  `derivations`/`basis` plumbing) and strengthens **OPP-D2** (missingness suite
  gains a provenance dimension).
- **Dependencies:** none hard; Step 0 field-name verification gates coding.
