# Bibliographies

This file records the authoritative sources behind ParkinSUM Companion's
educational mechanistic conflict engine. Citations are in **MLA** format.

ParkinSUM is an educational research prototype. The sources below are used to
*anchor mechanism explanations* in the simulation layer. They are not used to
claim clinical validation, dosing accuracy, or patient applicability. Several
quantitative model parameters are explicitly tagged **"prototype heuristic"** in
`lib/domain/usecases/model_assumption_registry.dart` because they are not
patient-calibrated.

## Bibliography (MLA)

1. U.S. National Library of Medicine. *SINEMET — Carbidopa and Levodopa Tablet
   Label.* DailyMed, National Institutes of Health,
   https://dailymed.nlm.nih.gov/dailymed/lookup.cfm?setid=9b17b028-964a-473c-823d-81423535bd66.
   Accessed 27 May 2026.

2. U.S. National Library of Medicine. *Carbidopa and Levodopa Tablet, Extended
   Release — Label.* DailyMed, National Institutes of Health,
   https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=aa5028d6-fd0a-4cf1-b708-c93bb2a7c76a.
   Accessed 27 May 2026.

3. American Parkinson Disease Association. "Interactions between Levodopa and
   Food — What to Avoid." *APDA Parkinson's Disease Information & Resources*,
   https://www.apdaparkinson.org/article/levodopa-dosing-and-food-intake/.
   Accessed 27 May 2026.

4. Salat, David, and Eduardo Tolosa. "Mechanisms of Peripheral Levodopa
   Resistance in Parkinson's Disease." *npj Parkinson's Disease*, vol. 8, 2022,
   article 56. *Nature*,
   https://www.nature.com/articles/s41531-022-00321-y. Accessed 27 May 2026.

5. Nutt, John G., et al. "Influence of Fluctuations of Plasma Large Neutral
   Amino Acids with Normal Diets on the Clinical Response to Levodopa."
   *Journal of Neurology, Neurosurgery, and Psychiatry*, vol. 52, no. 4, 1989,
   pp. 481–87. PMC,
   https://www.ncbi.nlm.nih.gov/pmc/articles/PMC1032296/. Accessed 27 May 2026.

6. Cereda, Emanuele, et al. "Protein-Restricted Diets for Ameliorating Motor
   Fluctuations in Parkinson's Disease." *Frontiers in Aging Neuroscience*,
   vol. 9, 2017, article 206.
   https://www.frontiersin.org/journals/aging-neuroscience/articles/10.3389/fnagi.2017.00206/full.
   Accessed 27 May 2026.

7. Boelens Keun, John T., et al. "Dietary Approaches to Improve Efficacy and
   Control Side Effects of Levodopa Therapy in Parkinson's Disease: A
   Systematic Review." *Advances in Nutrition*, vol. 12, no. 6, 2021,
   pp. 2265–87.
   https://academic.oup.com/advances/article/12/6/2265/6296104.
   Accessed 27 May 2026.

8. Contin, Manuela, and Paolo Martinelli. "Pharmacokinetics of Levodopa."
   *Journal of Neurology*, vol. 257, suppl. 2, 2010, pp. 253–61.
   *Springer Nature*,
   https://link.springer.com/article/10.1007/s00415-006-3009-3.
   Accessed 27 May 2026.

9. Cremonini, Filippo, et al. "Comparison of Calculations to Estimate Gastric
   Emptying Half-Time of Solids in Humans." *Neurogastroenterology & Motility*,
   vol. 21, no. 3, 2009, pp. 247–54. PMC,
   https://pmc.ncbi.nlm.nih.gov/articles/PMC3484235/. Accessed 27 May 2026.

10. Hens, Bart, et al. "Impact of Food Physical Properties on Oral Drug
    Absorption: A Comprehensive Review." *Pharmaceutics*, vol. 16, no. 12,
    2024, article 1605. PMC,
    https://pmc.ncbi.nlm.nih.gov/articles/PMC11745047/.
    Accessed 27 May 2026.

11. U.S. Food and Drug Administration. *Clinical Decision Support Software:
    Guidance for Industry and Food and Drug Administration Staff.* Federal
    Register, 28 Sept. 2022,
    https://www.federalregister.gov/documents/2022/09/28/2022-20993/clinical-decision-support-software-guidance-for-industry-and-food-and-drug-administration-staff.
    Accessed 27 May 2026.

12. U.S. Department of Agriculture, Agricultural Research Service. *FDC
    Nutrient Data OpenAPI Documentation.* USDA FoodData Central,
    https://fdc.nal.usda.gov/api-spec/fdc_api.html. Accessed 27 May 2026.

13. Virmani, Tuhin, et al. "To Restrict or Not to Restrict? Practical
    Considerations for Optimizing Dietary Protein Interactions on Levodopa
    Absorption in Parkinson's Disease." *npj Parkinson's Disease*, vol. 9,
    no. 1, 2023, article 87. PMC,
    https://pmc.ncbi.nlm.nih.gov/articles/PMC10290638/.
    Accessed 27 May 2026.

## Model assumptions mapped to sources

Each row maps a quantitative assumption used inside the educational model to
its closest supporting source. Where the literature does not directly support
the chosen numeric, the assumption is tagged **prototype_heuristic** and the
source is cited only for *mechanism direction*.

| Assumption ID | Assumption (educational simulation) | Source refs | Confidence | Limitation |
| --- | --- | --- | --- | --- |
| `ge.solid.lag.10_30` | Solid meals have a gastric emptying lag of roughly 10–30 minutes before linear emptying begins. | [9], [10] | `mechanism` | Population variability; not patient-calibrated. |
| `ge.solid.half.60_120` | Solid meals have a half-emptying time in the 60–120 minute range under reference conditions. | [9] | `mechanism` | Wide inter-subject variance reported (~24% CV). |
| `ge.liquid.fast` | Liquids empty without a meaningful lag and faster than solids. | [9], [10] | `mechanism` | Mixed meals diverge from pure-liquid kinetics. |
| `ge.fat.slowdown.1_5x` | Meals with ≥30% kcal from fat are modeled with ~1.5× longer half-emptying. | [10] | `prototype_heuristic` | Multiplier is illustrative, not patient-fitted. |
| `ge.fiber.uncertainty` | High-fiber meals widen the model's uncertainty band rather than asserting precision. | [10] | `prototype_heuristic` | Direction supported; magnitude is illustrative. |
| `ge.size.linear_scale` | Half-emptying scales linearly with total kcal vs a 400 kcal reference. | [9] | `prototype_heuristic` | Real kinetics are non-linear; included only as monotonic direction. |
| `ge.overlap.cumulate` | When a second meal arrives before the first is mostly emptied, model treats stomach load as cumulative and widens uncertainty. | [9], [10] | `mechanism` | No patient-fitted multi-meal model used. |
| `ldopa.absorption.small_intestine` | Levodopa absorption opportunity depends on small-intestinal arrival; delayed gastric emptying delays opportunity. | [1], [2], [8] | `label` | Label-supported direction; magnitude not patient-specific. |
| `ldopa.protein.lnaa_competition` | Dietary LNAAs from protein compete with levodopa for transport. | [1], [3], [4], [5], [6], [7] | `label` + `mechanism` | Competition magnitude varies by individual diet and PK state. |
| `ldopa.dose.mg_unit_required` | Carbidopa/levodopa strength is specified in mg; bare numbers are not analyzable doses. | [1], [2] | `label` | Direct label grounding. |
| `cds.intended_use.non_clinical` | This software is an educational prototype and not a clinical decision tool; outputs are non-prescriptive and reviewable. | [11] | `regulatory_guidance` | Aligns with the spirit of CDS criterion 4. |
| `aa.lnaa.source_type_load_factor` | The LNAA-competition proxy multiplies the protein amplitude by a coarse load factor that depends on the protein source type (animal protein generally carries higher LNAA per gram than plant protein). Direction is supported; magnitude is illustrative. | [4], [5], [6], [7], [13] | `prototype_heuristic` | ParkinSUM does not yet capture amino-acid composition per food. The load factors are direction-only educational approximations. Implemented in `lib/domain/entities/protein_source.dart`. |
| `ge.params.parameter_set_centralized` | Gastric-emptying numeric values are now consolidated in `GastricEmptyingParameterSet.literatureInformedDefault()` with per-parameter `sourceRefs`, `confidence`, and `limitation`. | [9], [10] | `internal_safety_boundary` | Centralization is implementation-only; no clinical claim. |
| `catalog.projection_wiring` | The runtime food repository is augmented at app boot with foods projected from CDSS observations (`CdssCatalogProjectionService.projectFoods()`) so the mechanistic next-meal scorer can rank catalog-backed candidates, not only synthetic replay scenarios. | (implementation note) | `internal_safety_boundary` | Best-effort: failures fall back gracefully to the seed/persisted catalog. |
| `fdc.amino_acid_field_availability` | USDA FoodData Central exposes amino-acid nutrient numbers (e.g. 505 leucine, 509 phenylalanine, 511 valine). ParkinSUM's FDC importer does not extract these today; the LNAA layer is structured to consume them when added. | [12] | `mechanism` | Documentation of upstream-data availability only; no clinical inference. |

## Notes on usage

- Every `MechanisticConflictResult.sourceRefs[]` value is a `sourceId` from
  `model_assumption_registry.dart`, which in turn cites one or more entries
  above.
- The replay runner (`tool/run_mechanistic_replay.dart`) embeds these `sourceId`
  strings in its JSON output so reviewers can trace any modeled output back to
  the bibliography entry.
- This file is updated whenever a new mechanism citation is added. It is not a
  clinical evidence registry.
