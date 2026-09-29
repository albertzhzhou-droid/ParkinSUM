# Mechanistic invariant and unit gate: research and implementation boundary

Date reviewed: 2026-09-02

## Decision

ParkinSUM now exposes a versioned, read-only mathematical invariant and unit report in the Algorithm Observatory. Twenty-three digest-bound specifications combine 15 fixed-scenario/provider checks, five black-box medication-dose probes, one black-box legacy food-recommendation scorer probe, one black-box production FDC amino-acid extraction probe, and one black-box production catalog-candidate projection probe. Schema v2 publishes the exact probe-to-algorithm bindings and requires every result to match both its declared probe and that probe's authorized algorithm IDs, so relabeling a passing check cannot manufacture coverage. Every specification declares its observable, algorithm IDs, canonical unit, absolute tolerance, method, source identities, result, and failure codes.

The current report records 23/23 passing specifications and is bound to
canonical configuration `2026.09.02-v40`
(`56cf755398784e7067c32bc1eb1d197f2b2c737868b6b015aaa431018959ceaf`)
and registered algorithm source bundle
`fc9eebdaa016136f558f4a07c7c0b70254092633a25ca1bf26312a104a9d4bdf`.

This is implementation and calculation verification. It does not establish biological validity, clinical accuracy, a patient prediction, benefit, regulatory acceptance, or medical advice. The report never changes a score, rank, reminder, record, or recommendation.

## Evidence boundary

The [FDA final guidance on computational modeling and simulation credibility](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/assessing-credibility-computational-modeling-and-simulation-medical-device-submissions) separates code verification, calculation verification, and validation evidence within a context-of-use and risk-informed framework. ParkinSUM therefore reports invariant and independent-vector results separately from scientific validation, model qualification, human-factors evidence, regulatory review, and external approval.

The [BIPM SI Brochure](https://www.bipm.org/en/publications/si-brochure/) supplies the metrology boundary: a quantity and its unit must remain explicit, and a quantity equation should not change meaning when an equivalent unit representation is used. The gate currently verifies only a closed local subset: mass in mg, energy in kcal, duration in minutes, and fraction as a unit-one quantity. This is not a claim that the app implements the full SI system.

The [UCUM specification](https://ucum.org/ucum) distinguishes unit syntax, equality, commensurability, dimensions, special units, and arbitrary units. ParkinSUM uses this only to motivate a future typed quantity kernel. The app does not currently implement or claim UCUM conformance, and the [UCUM license](https://ucum.org/license) must be reviewed before incorporating specification tables, parser code, or derived artifacts.

USDA's [Foundation Foods documentation](https://fdc.nal.usda.gov/Foundation_Foods_Documentation/) states that absent nutrient values may reflect nutrients that were not analyzed, rather than measured zero, and documents Foundation values on a 100 g basis. The [Global Branded Food Products Database documentation](https://fdc.nal.usda.gov/GBFPD_Documentation/) describes standardization to 100 g or 100 mL; the [FoodData Central API specification](https://fdc.nal.usda.gov/api-spec/fdc_api.html) defines the transport surface consumed by the local adapter. Accordingly, the AAE-001 contract preserves a present, finite, non-negative true zero, converts only recognized `g` and `mg` mass units to canonical grams under the narrow [BIPM SI](https://www.bipm.org/en/publications/si-brochure/) boundary, and holds a semantic field as null when its unit is missing or unknown, its value is invalid/non-finite/negative, or duplicate rows compete for that field. Neither a missing value nor a held value is silently converted to zero.

The catalog-candidate projection contract carries that truth boundary into a
logged serving. For a declared source value `V` in grams per 100 g and a finite,
non-negative serving mass `W` in grams, the projected nutrient amount is
`N=(V×W)/100`. Gram-based scaling is authorized only for the exact
`per_100g` basis. A `per_100mL` value is a volume-basis quantity and is held,
not guessed to be mass-basis data, because the projection has no declared
density or other mass-volume relation. Source-missing markers override stored
numeric placeholders, while a present true zero remains zero; unknown or
missing basis/unit, invalid source values, and invalid serving quantities yield
null rather than a fabricated amount.

## Implemented report

The report covers:

1. normalized nutrient bounds and explicit missingness;
2. canonical event-ledger dimensions and selected equivalent conversions;
3. finite, bounded, monotone normalized gastric retention and mass complementarity;
4. discrete arrival-rate integration against cumulative emptied fraction;
5. ordered faster, central, and slower retention sensitivity curves;
6. absorption-opportunity sample, window, range, and peak coherence;
7. LNAA-pressure sample, peak, overlap, and ordinal-threshold coherence;
8. conflict and candidate-score structural coherence;
9. fail-closed incomplete-input behavior where unknown is not zero;
10. the separate 19-vector analytic numerical oracle;
11. medication-entry normalization round trips, exact four-predicate model applicability, and applicability-manifest identity;
12. protein-redistribution trace presence, bounds, identity, and numeric absence on abstention;
13. one canonical cross-scenario algorithm configuration, source bundle, parameter-provenance manifest, registry manifest, and gastric parameter identity;
14. six gastric structures against their declared normalized-retention, absolute-volume, or pellet-retention observable domains;
15. gastric structural-fit authorization, production-output isolation, and numeric absence in held domains;
16. typed administration-dose expression, exact unit conversion, and separation from intake product/formulation metadata;
17. explicitly confirmed package-unit multiplication, combination-pack identity, finite-positive bounds, ratio holds, and overflow rejection;
18. medication-metadata completeness across complete, missing-unit, non-finite, non-positive, and bounded-weight vectors;
19. input-quality separation between parseable administration quantity, product strength, and result eligibility;
20. the combined confirmation-receipt, assertion-conflict, and as-of result gate across unconfirmed, exact 100 mg, conflicting, future-evidence, mass-conversion, and volume-without-concentration vectors;
21. the production legacy food-recommendation scorer's exact manufactured points, protein-threshold neighborhoods, bounded 0..100 heuristic score, descending top-five output, input-permutation behavior, and stable food-ID tie break;
22. the production FDC amino-acid extractor's nutrient-number precedence, deterministic row-order behavior, exact `mg`→`g` conversion, preservation of true zero, fail-closed null/partial handling for missing or unknown units, invalid values, and duplicate semantic fields, and retention of a partial audit profile when the only competing-LNAA observation is held;
23. the production catalog-candidate projection's source-missing-marker precedence, preservation of unmarked true zero, exact `per_100g` serving conversion, source identity retention, zero-serving behavior, and fail-closed holds for `per_serving`, unknown, or volume bases and invalid source or serving values.

The production-facing gate covers 22 of 63 (22/63) registered algorithms, including the time-axis unit boundary, observable-specific gastric structural shadow ensemble, dose parser, intake context, package calculator, metadata/input-quality gates, confirmation receipt, assertion reconciliation, `legacy_food_recommendations`, the FDC amino-acid extractor, and catalog-candidate projection. The other 41 remain explicitly `notCovered` in the same UI. Existing deeper tests retain unit metamorphisms, threshold neighborhoods, component permutation, invalid and Unicode signs, leading decimals, non-finite values, malformed weights, deterministic food-ID tie ordering, FDC row permutation and duplicate-field vectors, serving-basis and missing-marker vectors, and deliberate formula mutations. Observation mutations prove that the comparator/report fails closed when captured values are altered; direct production tests, rather than those observation mutations, establish that parser, package calculator, metadata, input-quality, result-use, legacy scoring, FDC extraction, and candidate projection implementations reject or preserve their targeted defect classes. The FDC production path carries a valid extracted profile through `FdcP0Importer` into the import bundle and catalog projection that produces `FoodItem`; the source-adapter registry separately declares the adapter's authority and known fail-closed limitation. The FHIR-inspired NutritionIntake mapper emits a complete actual-amino-acid summary only when the unit and basis are recognized, all six competing LNAAs are present and finite/non-negative, and the protein-bound check is valid. Otherwise the summary remains partial or absent, never fake-complete. An intravenous context paired with stale modeled output fails the visible applicability specification, one altered scenario configuration fails configuration identity without falsely failing the unchanged conflict calculation, a relabeled passing specification cannot claim an algorithm outside its probe binding, and a separate 60-decimal-digit Node reference checks 42 manufactured values across all six gastric structures without sharing Dart binary64 arithmetic.

## Medication expression and terminology boundary

The [HL7 FHIR R5 Dosage datatype](https://hl7.org/fhir/R5/dosage.html) separates dose, rate, route, timing, maximum dose, and free-text instructions instead of treating them as one interchangeable string. [FHIR Quantity](https://hl7.org/fhir/R5/datatypes.html#Quantity) further separates display unit, system, code, comparator, and value; display text alone cannot be assumed to be a valid computation code.

The [FDA dosage-form and route terminology page](https://www.fda.gov/industry/data-standards-advisory-board/dosage-form-and-route-administration) states that FDA uses Structured Product Labeling terminology and also warns that no single globally centralized dose-form terminology exists. The [FDA SPL resources](https://www.fda.gov/industry/fda-data-standards-advisory-board/structured-product-labeling-resources) are therefore a jurisdiction-specific terminology source, not evidence that a local alias is globally interoperable.

UCUM distinguishes case-sensitive and case-insensitive representations, commensurability, and full versus limited conformance. ParkinSUM's current narrow parser is now parse-result schema v1 / grammar v2 with a typed administration-quantity AST, 28 differential vectors, and a local confirmation receipt. It still is not a UCUM validator, FDA SPL binding, RxNorm release binding, or FHIR conformance layer. The grammar intentionally holds comparator, range, rate, maximum, count, concentration, route, form, release, and ambiguous locale/Unicode forms. This gap is separate from the broader terminology firewall because it concerns executable parsing and the exact boundary between product or ingredient strength, medication amount per administration, daily regimen, and volume.

## Gastric observable scope

The monotonicity rule is intentionally scoped to normalized retention. Human gastric-emptying studies use different meals, states, modalities, endpoints, and model structures. For example, Hou et al. compared linear, power-exponential, and modified power-exponential fits to four-hour scintigraphic observations, while Bürmen et al. compared lag-exponential, Weibull, and double-Weibull descriptions of fasting pellet emptying. These studies support model-form uncertainty and observable-specific checks; they do not validate one universal ParkinSUM curve or individual parameters.

- [Hou et al. 2010, PMID 20649756](https://pubmed.ncbi.nlm.nih.gov/20649756/)
- [Bürmen et al. 2009, PMID 19337822](https://pubmed.ncbi.nlm.nih.gov/19337822/)

An absolute gastric-volume model can exhibit behavior, including secretion-related volume change, that a normalized-retention invariant must not reject out of context. Observable identity remains part of every future specification.

## Known limits

- The invariant report and production models run in the same Dart binary64 environment.
- Some structural checks intentionally reuse public production entity validators; the independent numerical oracle remains a separate evidence layer.
- Twenty-two algorithms are covered by the production-facing gate, not the entire 63-algorithm registry; 41 remain explicitly not covered.
- Fixed synthetic scenarios do not establish population coverage, calibration, identifiability, transportability, or patient-level validity.
- Current unit fields are still largely runtime values and strings, so dimension errors are rejected at boundaries rather than made unrepresentable by the type system.
- The AAE-001 and catalog-candidate projection probes do not provide a repository-wide typed quantity algebra, prove that every importer emits correct missing markers and basis metadata, independently reproduce the result outside the project, or establish biological or clinical validity.

## Queued next steps

`dimensionally_typed_algorithm_quantity_kernel` has been added to the complete-app queue with score 20 and `research_required` status. It will investigate a closed compile-time quantity algebra, canonical serialization, configuration-digest binding, property and mutation tests, and a separately reviewed UCUM subset. It depends on completion of the invariant gate, configuration identity, unit-aware event ledger, and independent numerical oracle.

`medication_dose_expression_grammar_and_differential_conformance` remains score 30 and `research_required`. Its first slice now provides parse-result schema v1 / grammar v2, a typed single administration-quantity AST, 28 Dart/JavaScript differential vectors, and confirmation receipt binding. The remaining work expands comparator, range, rate, maximum, count, strength, concentration, route, form and release semantics; property/adversarial fuzzing; and Web/Firestore, offline, cross-device and independently implemented receipt evidence. Passing remains engineering input-safety evidence, not clinical or FHIR/UCUM conformance.

`structured_medication_dose_semantics_ucum_rxnorm_fhir_profile` has been added with score 20, P0 priority, and `research_required` status. It requires a content-addressed FHIR R5 profile/validator package, reviewed UCUM subset and license disposition, exact RxNorm release/checksum/source-license manifest, and explicit derivation graphs separating `Dosage.doseAndRate.dose[x]` medication amount per administration from `Medication.ingredient.strength[x]`, package amount, frequency, route, form, and release. Standards-shaped transport, a valid RXCUI, or unit conversion will never establish dose appropriateness, actual administration, adherence, prescription validity, or clinical correctness.
