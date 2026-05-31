# Catalog Resolution Engine

Educational/research prototype. Synthetic/demo data only. **Not medical advice,
not clinically calibrated, and carries no clinical-validation claim.**

> **Catalog resolution returns candidates + uncertainty — never a
> recommendation.** It does **not** tell the user what to eat or what medication
> to take, **does not** infer a user intake dose, and **does not** silently
> guess. Dose-like query text (e.g. `25/100`) is **query evidence**, not a user
> intake dose. Product strength is product metadata, not an intake dose.

## 1. Purpose

`CatalogResolutionEngine` (P2) resolves a user-facing food or drug string into
ranked, **source-backed** candidate records with confidence, match type,
`sourceRefs`, jurisdiction/locale context, ambiguity warnings, and unresolved
reasons. It gives the rest of the system a structured, inspectable answer to
"what catalog item(s) might this string refer to, and how sure are we?" without
overclaiming.

## 2. Safety boundary

The engine adds no medical advice, no diagnosis, no treatment/dose/timing/diet
instruction, and no patient-care workflow. It introduces no patient/subject/
encounter semantics and uses no LLM. It is deterministic, not clinically
calibrated, and carries no clinical-validation claim.

## 3. What catalog resolution does

- Normalizes the query (lowercasing, whitespace/punctuation/full-width folding,
  while preserving CJK and dose-like strings).
- Matches against in-memory `FoodItem` and `DrugDefinition` catalogs (the engine
  never reads files directly).
- Produces ranked `CatalogResolutionCandidate`s with a deterministic confidence
  score and band, the match type, provenance, and per-candidate warnings.
- Classifies the overall result as `resolved` / `ambiguous` / `partial` /
  `unresolved` / `invalid`.

## 4. What it does not do

- It does not recommend a food or medication, or any action.
- It does not infer a user intake dose from dose-like text.
- It does not fabricate `sourceRefs`, `metadataCompleteness`, or
  `sourceAuthorityScore`.
- It does not silently pick one overconfident answer for ambiguous input.
- It does not invent a translation when no localized name/alias exists.

## 5. Food resolution strategy

Exact display name → normalized name → source identifier → localized name /
synonym (from aliases or an optional localization dictionary / synonym map) →
conservative fuzzy token overlap. Candidates carry `foodItemId`, `category`,
`portionBasis`, `nutrientCompleteness`, and `nutrientProvenanceTier` when
available.

## 6. Drug resolution strategy

Exact generic name → source identifier → brand name → alias (localized/synonym)
→ combination-product component match → single active-ingredient match →
release-type hint adjustment → conservative fuzzy fallback. Candidates preserve
`brandName`, `genericName`, `activeIngredients`, `combinationComponents`,
`doseForm`, `route`, `releaseType`, and `releaseTypeSource`. Combination
products keep their components split (carbidopa/levodopa is never collapsed).

## 7. Ambiguity and unresolved handling

- **Ambiguous**: the top two candidates are within a small confidence delta, or
  the query matches both the food and drug catalogs. Alternatives are returned;
  no single answer is forced.
- **Partial**: the best candidate is a generic/active-ingredient/fuzzy match or
  is below the resolve threshold — it requires structured confirmation.
- **Unresolved**: nothing clears the keep threshold; unresolved reasons are
  recorded.
- **Invalid**: empty query.

## 8. Confidence scoring

Simple, deterministic, non-ML. Match type sets a base score (exact/source-id
highest, brand/generic/localized/synonym/combination medium-high, active
ingredient medium, fuzzy low). Penalties apply for jurisdiction mismatch,
missing `sourceRefs`, and low metadata completeness; a release-type hint match
adds a small bonus and a mismatch a penalty. Bands: `high` ≥ 0.8, `medium` ≥
0.6, `low` ≥ 0.4, else `unknown`.

## 9. Source / provenance handling

`sourceRefs` are derived only from real catalog fields (`sourceSystem` +
`sourceFoodCode`/`sourceProductCode`); when absent they stay empty and lower
confidence. `sourceAuthorityScore` is a deterministic source-system heuristic in
which **synthetic/seed sources are capped well below official systems** (a seed
exact-name match can be a confident *name* match but never an official-authority
source).

## 10. Localization handling

Localized names resolve via real `aliases` (CJK preserved) or an optional
localization dictionary. When neither provides a localized form, the engine
returns `unresolved` rather than inventing a translation.

## 11. Brand / generic / combination / release-type handling

Brand and generic names match distinctly; combination products preserve their
component list; a release-type hint (IR / ER / CR / controlled / extended /
immediate) rewards the matching variant and penalizes the mismatching one so an
"levodopa CR" query ranks the controlled-release product above the
immediate-release one — without recommending either.

## 12. Dose-like string boundary

A dose-like token such as `25/100` or `100mg` is preserved in the normalized
query as **evidence of what the user typed**. It is never parsed into a
candidate `strengths` value or any user intake dose. Downstream validators
(e.g. `MedicationEntryValidator`) still require an explicit, separately entered
dose — a resolved candidate alone never creates a hidden dose.

## 13. How to test

```sh
flutter test --concurrency=1 test/catalog_resolution_engine_test.dart
# optional deterministic demo:
dart run tool/run_catalog_resolution_demo.dart   # or: npm run catalog:resolve
```

The suite uses small synthetic catalogs (no app run) and covers exact/localized/
synonym/brand/generic/combination matches, release-type distinction, dose-like
preservation, jurisdiction/sourceRefs penalties, ambiguity/unresolved/invalid,
deterministic JSON, no-advice copy, no-PHI keys, and that a resolved candidate
passes to the existing validator without creating a hidden dose.

## 14. Future integration

A future PR could feed resolved candidates into the InputQualityGate (P1) and
the catalog-to-candidate projection — always as structured input requiring
confirmation, never as an auto-selected recommendation. UI wiring is out of
scope here.

## 15. Reviewer checklist

- [ ] No advice / "eat this" / "take this medication" / dose / timing phrasing.
- [ ] Dose-like text stays query evidence; candidate `strengths` is not invented.
- [ ] Combination components are preserved, never collapsed.
- [ ] Ambiguous input returns alternatives, not one overconfident answer.
- [ ] Unknown input is `unresolved` with reasons (no fabricated match).
- [ ] `sourceRefs` / authority come from catalogs; synthetic/seed ≠ official.
- [ ] No localized translation is invented when no alias/dictionary entry exists.
- [ ] JSON is deterministic and emits no patient/subject/encounter keys.
