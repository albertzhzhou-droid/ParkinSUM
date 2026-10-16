# Importer and food/medication source details

Review date: 2026-09-29 (America/Toronto). Implementation is local and uncommitted.
This review changes source handling, not medication doses or patient-specific
nutrition advice. Synthetic assertions are engineering evidence.

## Verified source semantics and implementation

| Source finding | Implemented behavior | Independent check |
| --- | --- | --- |
| FDC Foundation composition is on an edible 100 g basis; portions have source-specific gram weights | CSV `food_portion` and `measure_unit` now join on exact food/unit IDs, using the same evidence object as JSON. Exact table basenames prevent `input_food.csv` from masquerading as `food.csv`. | Synthetic 2 g/100 g stays 2 g/100 g on import; a separate opt-in 150 g preview has expected 3 g. |
| FDC may encode a below-quantification observation as zero with a positive LOQ | Retain a strict less-than interval. Point-only candidates receive unknown for that field. Censored amino acids remain partial and never become measured zeros. | 0 with LOQ 0.03 produces [0,0.03), no point estimate; measured 0 without LOQ remains exact. |
| Nutrient values and units must support the declared attribute | Reject invalid, negative, nonfinite values, invalid LOQ and wrong units from promoted observations, preserving audit reasons. Missing/censored values are marked in direct FoodItem projections. Energy kcal and water grams remain distinct. | Wrong protein mg, negative, NaN and invalid LOQ do not become model inputs. |
| Duplicate nutrient rows and multiple source revisions require a reviewed selection decision | Retain distinct row evidence. Duplicate attributes do not become a resolved fact on import. Catalog projection withholds a point when exact rows or source identities are ambiguous. | Two exact protein rows remain two observations with no selected point; an older exact row plus a newer censored row cannot silently reuse the older value. |
| An SPL set identifies a label family; document ID, version and effective time identify its revision | Preserve root document metadata, raw XML SHA-256, active-ingredient strengths and actual section codes. Source-document and section identities include content, preserving revisions. A missing version is explicitly unknown. | Same set, different version retains product ID and changes document/section identity. |
| Active ingredient classes and inactive ingredients are different | Exclude explicit inactive ingredients from drug concept names; retain source numerator/denominator values and units for active ingredients as evidence only. | Synthetic 95 mg per 1 unit remains a label strength; cellulose does not join the generic name. |
| Multiple routes/forms in one source are ambiguous for a single projected product | Keep route/form unspecified when distinct source values disagree. | Oral plus intravenous cannot silently choose oral. |

Food source-document and observation IDs now also bind the imported food-object
content digest. Existing app food/product IDs remain stable. Reimporting a changed
source yields new evidence IDs; old evidence is not relabeled as the new revision.
Hashes establish content identity, not publisher authentication. Root effective
date is stored at UTC day precision; the literal SPL time is retained separately.

The drug detail page exposes retained label version/date, ingredient strength and
source URL. Missing legacy metadata is visible as “Not provided.” Raw label
strength is not an administered dose, and free-text parsing does not activate rules.

## Sources read

- [USDA Foundation documentation](https://fdc.nal.usda.gov/Foundation_Foods_Documentation/): edible basis, portion formula and LOQ encoding.
- [FDC download field dictionary](https://fdc.nal.usda.gov/portal-data/external/dataDictionary): portion and measurement tables.
- [FDC API guide](https://fdc.nal.usda.gov/api-guide/): authoritative data types and source access.
- [FDA drug listing instructions](https://www.fda.gov/drugs/drug-registration-and-listing-instructions/how-list-drug): document ID, effective date and version update.
- [FDA SPL validation procedures](https://www.fda.gov/media/86156/download): ACTIB/ACTIM/ACTIR versus IACT ingredient classes.
- [FDA SPL resources](https://www.fda.gov/industry/fda-data-standards-advisory-board/structured-product-labeling-resources): source-format references.

## Verification and remaining research

`importer_source_semantics_test.dart`, `p0_importers_test.dart`,
`food_portion_composition_projection_test.dart` and
`amino_acid_extraction_test.dart` passed the targeted importer checks; final
integration totals are recorded in the upgrade plan and timeline.
Additional catalog UI/projection checks are recorded in the upgrade plan and
the canonical evolution timeline after integration.

This iteration does not bulk-download a new food/drug database or assume live
metadata has passed manual review. Previously persisted evidence has not been
rewritten. Multi-product SPL separation, reviewed product-specific label fact
extraction, duplicate nutrient reconciliation, publisher archive attestation,
and review of an actual refreshed catalogue remain distinct work. The current
XML title release parser still withholds an unknown release type. See
[conflict algorithm research](CONFLICT_ALGORITHM_RESEARCH_2026-09-29.md) for
formulation-specific protein/iron evidence and operational-threshold boundaries.
