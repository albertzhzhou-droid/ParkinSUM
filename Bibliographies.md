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
| `aa.lnaa.source_type_load_factor` | The LNAA-competition proxy multiplies the protein amplitude by a coarse load factor that depends on the protein source type (animal protein generally carries higher LNAA per gram than plant protein). Direction is supported; magnitude is illustrative. This proxy is used **only as a fallback** when actual per-food amino-acid fields are absent; when `FoodComponent.aminoAcidProfile` is present the LNAA layer uses the actual fields instead (`AminoAcidDataMode.actualAminoAcidFields`). | [4], [5], [6], [7], [13] | `prototype_heuristic` | The load factors are direction-only educational approximations. Implemented in `lib/domain/entities/protein_source.dart`; actual-fields path in `amino_acid_competition_model.dart`. |
| `ge.params.parameter_set_centralized` | Gastric-emptying numeric values are now consolidated in `GastricEmptyingParameterSet.literatureInformedDefault()` with per-parameter `sourceRefs`, `confidence`, and `limitation`. | [9], [10] | `internal_safety_boundary` | Centralization is implementation-only; no clinical claim. |
| `catalog.projection_wiring` | The runtime food repository is augmented at app boot with foods projected from CDSS observations (`CdssCatalogProjectionService.projectFoods()`) so the mechanistic next-meal scorer can rank catalog-backed candidates, not only synthetic replay scenarios. | (implementation note) | `internal_safety_boundary` | Best-effort: failures fall back gracefully to the seed/persisted catalog. |
| `fdc.amino_acid_field_availability` | USDA FoodData Central exposes amino-acid nutrient numbers. Verified mapping used by ParkinSUM: **501 tryptophan, 502 threonine, 503 isoleucine, 504 leucine, 505 lysine, 506 methionine, 507 cystine, 508 phenylalanine, 509 tyrosine, 510 valine, 512 histidine**. The FDC importer now extracts the LNAA-relevant subset (number-priority, name fallback, mg→g normalization, missing-unit marked `partial`) and feeds `FoodComponent.aminoAcidProfile`; the LNAA layer prefers these actual fields over the protein-source proxy. | [12] | `mechanism` | Documentation of upstream-data availability + extraction; no clinical inference. Implemented: `lib/data/datasources/remote/amino_acid_extractor.dart`. |
| `protein.redistribution.not_global_minimization` | The next-meal scorer models protein *redistribution* (penalize protein only during modeled high-overlap windows; allow it in low-overlap windows; preserve a nutrition-adequacy proxy) instead of globally minimizing protein. | [6], [7], [13], [20], [21] | `peer_reviewed_review` (direction); `prototype_heuristic` (magnitudes) | Educational objective; protein-redistribution diets are not nutritionally complete and require professional supervision. Implemented: `protein_distribution_model.dart`. |
| `source.authority.cross_jurisdiction_policy` | Deterministic source-authority scoring: official-in-jurisdiction highest; dictionaries strong for identity not food-effect; reference translations downgraded; seed/synthetic never overrides official; cross-jurisdiction conflicts preserved. | [14]–[19] | `official_database` (direction); `prototype_heuristic` (weights) | Educational heuristic, not a regulatory ranking. Implemented: `source_authority_scorer.dart`. |
| `metadata.completeness_gate` | No unit → no dose; no ingredient → no drug context; no dose-form/release → limited PK; no provenance → no evidence-linked explanation; no jurisdiction → unknown-jurisdiction behavior; incomplete → widen uncertainty. | [11], [14]–[19] | `regulatory_guidance` (direction) | Implemented: `metadata_completeness_gate.dart`. |
| `meal_history.componentized_composition` | Historical meals are modeled as one `FoodComponent` per logged item (joined to catalog `FoodItem` for physical form, energy, and amino-acid provenance) instead of a single `unknown` aggregate. Missing catalog data stays null (never 0). | (implementation note) | `internal_safety_boundary` | Improves gastric/LNAA fidelity; no clinical claim. Implemented: `next_meal_recommendation_orchestrator.dart`, `catalog_food_to_candidate.dart`. |
| `ge.highfat_highcal.uncertainty_widening` | High-fat (fat ≥ threshold fraction of kcal) and high-calorie (≥ `highcal.fraction_threshold` × reference kcal) meals widen the gastric-emptying uncertainty band, mirroring the fiber/overlap boosts. | [9], [10] | `prototype_heuristic` | Direction (fat + caloric load slow and disperse emptying) is supported; integer-step magnitudes are illustrative. Implemented: `gastric_emptying_parameters.dart`, `gastric_emptying_model.dart`. |
| `ldopa.absorption.openness_profile` | The levodopa absorption opportunity is sampled as a deterministic openness curve (0..1) over the window: IR rises sharply to a full-openness peak then decays; ER/controlled is flatter and longer. Incomplete meal context flattens the curve. Candidate competition overlap is openness-weighted. | [1], [2], [8] | `prototype_heuristic` | Educational shape only — NOT blood concentration, NOT PK/PD calibration. Implemented: `levodopa_absorption_opportunity_model.dart`, `absorption_opportunity.dart`. |
| `lnaa.absolute_grams_and_dose_relative` | When actual amino-acid fields are present the model exposes absolute competing LNAA grams (and per-serving), and a dose-relative ratio (g LNAA per 100 mg levodopa) **only** when an explicit user-entered dose is available — never an invented dose. Partial amino-acid data (some of the six LNAA, or unit-ambiguous values) is flagged and widens uncertainty. Intestinal-absorption competition is distinguished from broader BBB transport competition (cited, not quantified). | [1], [3], [4], [5], [6], [7] | `mechanism` (direction); `prototype_heuristic` (magnitude) | No dose is fabricated; dose-relative ratio is unavailable when dose is missing/non-explicit. Implemented: `amino_acid_competition_model.dart`, `amino_acid_competition.dart`. |
| `score.weights.parameter_set` | Next-meal candidate scoring weights are centralized in `NextMealScoringParameterSet` with per-weight `sourceRefs`, evidence level, and limitation. The invariant `conflictRemainsDominant` keeps modeled conflict overlap (and uncertainty) dominant so provenance/metadata can never outrank a high modeled conflict overlap; it is **enforced** — the `MechanisticNextMealScorer` constructor throws `ArgumentError` for a non-dominant weight set rather than silently degrading ranking safety. | [1], [3], [4], [5], [6], [7] | `mechanism` (conflict/redistribution direction); `prototype_heuristic` (weight magnitudes) | Weights are illustrative, not fitted coefficients. Surfaced in replay via `scoring_parameter_set_id`. Implemented: `next_meal_scoring_parameters.dart`, `mechanistic_next_meal_scorer.dart`. |

## Multi-jurisdiction importer sources

Educational architecture only. Source families ParkinSUM is designed to
support, with provenance/authority metadata. Source rows marked
*spec-only* have no concrete parser yet; the adapter registry
(`lib/data/datasources/remote/source_adapter_registry.dart`) carries their
metadata so the architecture covers all families without hard-coding
DailyMed as the only medication source.

| Jurisdiction | Source system | Owner | Data type | Access | Language | Authority tier | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| US | DailyMed | U.S. NLM | Official SPL label | download | en | official label | implemented |
| US | RxNorm (concept normalization) | U.S. NLM | drug concept normalization | API | en | drug dictionary | future |
| CA | Health Canada DPD | Health Canada | Official DB + product monograph | API | en/fr | official database | implemented |
| EU | EMA EPAR / ePI (FHIR) | European Medicines Agency | EPAR / SmPC / ePI | download | en | official label | implemented |
| EU/EEA | National registers of authorised medicines | National competent authorities (EMA index) | SmPC / package leaflet | web page | multi | official database | spec-only |
| GB | NHS dm+d | NHSBSA / NHS England | drug dictionary (SNOMED CT) | download | en | drug dictionary | spec-only |
| JP | PMDA | PMDA | package insert / review report | web page | ja (en reference-only) | official label | implemented |
| CN | NMPA | National Medical Products Administration | drug approval / label | web page | zh | official label | spec-only |
| US | USDA FoodData Central | USDA ARS | food composition | API | en | food composition table | implemented |
| FR | Ciqual | ANSES | food composition | download | fr | food composition table | implemented |
| CN | China CDC food platform | China CDC | food composition | web page | zh | food composition table | implemented |
| — | app seed / synthetic demo | ParkinSUM | seed/synthetic | manual | en | seed/synthetic | implemented |

### Multi-jurisdiction source references (MLA)

14. NHS England Digital. *Dictionary of Medicines and Devices (dm+d).*
    NHS England, https://digital.nhs.uk/services/terminology-and-classifications/dm-d.
    Accessed 27 May 2026. (Access: NHS Terminology Server FHIR API,
    https://ontology.nhs.uk/production1/fhir/, and TRUD XML download. dm+d is
    identity/coding-strong via SNOMED CT; it is not a complete food-effect
    label source.)

15. European Medicines Agency. *Electronic Product Information (ePI).* EMA,
    https://www.ema.europa.eu/en/human-regulatory-overview/marketing-authorisation/product-information-requirements/electronic-product-information-epi.
    Accessed 27 May 2026.

16. European Medicines Agency. *National Registers of Authorised Medicines.*
    EMA, https://www.ema.europa.eu/en/medicines/national-registers-authorised-medicines.
    Accessed 27 May 2026.

17. Health Canada. *Drug Product Database (DPD).* Government of Canada,
    https://www.canada.ca/en/health-canada/services/drugs-health-products/drug-products/drug-product-database.html.
    Accessed 27 May 2026.

18. Pharmaceuticals and Medical Devices Agency. *PMDA — Reviews / Package
    Inserts.* PMDA, https://www.pmda.go.jp/english/. Accessed 27 May 2026.

19. National Medical Products Administration. *NMPA Database.* NMPA,
    https://english.nmpa.gov.cn/database.html. Accessed 27 May 2026.

20. Karstaedt, Patricia J., and Joseph H. Pincus. "Protein Redistribution Diet
    Remains Effective in Patients with Fluctuating Parkinsonism." *Archives of
    Neurology*, vol. 49, no. 2, 1992, pp. 149–51.
    https://pubmed.ncbi.nlm.nih.gov/1736847/. Accessed 27 May 2026.

21. Cereda, Emanuele, et al. "Low-Protein and Protein-Redistribution Diets for
    Parkinson's Disease Patients with Motor Fluctuations: A Systematic Review."
    *Movement Disorders*, vol. 25, no. 13, 2010, pp. 2021–34.
    https://pubmed.ncbi.nlm.nih.gov/20669318/. Accessed 27 May 2026.

### Future-source references (MLA)

These sources were surveyed during the biomedical-engineering opportunity
mapping pass (see `docs/BIOMEDICAL_ENGINEERING_OPPORTUNITY_MAP.md`). They are
citation/implementation candidates; none enable live ingestion today.

22. U.S. National Library of Medicine. *DailyMed RESTful Web Services, Version
    2.* National Institutes of Health,
    https://dailymed.nlm.nih.gov/dailymed/webservices-help/v2/spls_api.cfm.
    Accessed 28 May 2026.

23. U.S. Food and Drug Administration. *Structured Product Labeling (SPL)
    Resources — Prescription Drug Labeling.* FDA,
    https://www.fda.gov/industry/structured-product-labeling-resources.
    Accessed 28 May 2026.

24. U.S. National Library of Medicine. *RxNorm and RxNav / RxClass APIs.*
    National Institutes of Health, https://lhncbc.nlm.nih.gov/RxNav/.
    Accessed 28 May 2026.

25. U.S. Department of Agriculture, Agricultural Research Service. *FoodData
    Central — Foundation Foods Documentation (April 2024).* USDA,
    https://fdc.nal.usda.gov/docs/Foundation_Foods_Documentation_Apr2024.pdf.
    Accessed 28 May 2026.

26. Food and Agriculture Organization of the United Nations. *FAO/INFOODS
    Component Identifiers (Tagnames) and Guidelines (Conversions, Data
    Evaluation, Food Matching).* FAO,
    https://www.fao.org/infoods/infoods/standards-guidelines/en/.
    Accessed 28 May 2026.

27. HL7 International. *FHIR Release 5 — MedicationKnowledge, NutritionIntake,
    and Observation Resources.* HL7, https://www.hl7.org/fhir/. Accessed
    28 May 2026.

28. Observational Health Data Sciences and Informatics. *OMOP Common Data Model.*
    OHDSI, https://ohdsi.github.io/CommonDataModel/. Accessed 28 May 2026.

29. Wilkinson, Mark D., et al. "The FAIR Guiding Principles for Scientific Data
    Management and Stewardship." *Scientific Data*, vol. 3, 2016, article 160018.
    doi:10.1038/sdata.2016.18.
    https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4792175/. Accessed 28 May 2026.

30. U.S. Food and Drug Administration. *Clinical Decision Support Software —
    Guidance for Industry and FDA Staff.* FDA (final guidance, 2022; updated
    final guidance issued 29 Jan 2026),
    https://www.fda.gov/regulatory-information/search-fda-guidance-documents/clinical-decision-support-software.
    Accessed 28 May 2026.

31. Leta, Valentina, et al. "Gastrointestinal Barriers to Levodopa Transport and
    Absorption in Parkinson's Disease." *European Journal of Neurology*, vol. 30,
    no. 5, 2023, pp. 1465–80.
    https://onlinelibrary.wiley.com/doi/10.1111/ene.15734. Accessed 28 May 2026.

32. Bächlin, Marc, et al. *Daphnet Freezing of Gait Dataset.* UCI Machine
    Learning Repository, 2010 (CC BY 4.0),
    https://archive.ics.uci.edu/dataset/245/daphnet+freezing+of+gait.
    Accessed 28 May 2026.

## Potential future model/data-flow sources

Registry of surveyed sources for future, *non-clinical* model/data-flow work.
Status ∈ {already used, implementation candidate, citation only, not usable}.
No source enables live ingestion without per-source license review.

| sourceId | Title | Owner / publisher | Year | URL/DOI | Access | Status | Limitation | Safety note |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `src.dailymed.spl.webservices.v2` | DailyMed SPL Web Services v2 | U.S. NLM | 2024+ | dailymed.nlm.nih.gov/dailymed/webservices-help/v2 | public API, no key (public domain; review terms) | already used (fixture + opt-in smoke) | section/version extraction not yet wired | Metadata only; mechanism needs explicit label text. |
| `src.fda.spl.standard` | FDA SPL / labeling resources (LOINC sections) | U.S. FDA | current | fda.gov/industry/structured-product-labeling-resources | citation / downloadable spec | citation only | spec, not a parser | Section identity only; no dose inference. |
| `src.rxnorm.rxnav.api` | RxNorm + RxNav/RxClass (RxCUI, ATC) | U.S. NLM | current | lhncbc.nlm.nih.gov/RxNav | public API (review terms) | implementation candidate | identity/coding only | Not a food-effect / mechanism source. |
| `src.usda.fdc.foundation_docs` | FDC Foundation Foods Documentation | USDA ARS | 2024 | fdc.nal.usda.gov/docs/Foundation_Foods_Documentation_Apr2024.pdf | open access (download) | implementation candidate | live values need API key | Provenance metadata only; never fabricate samples/methods. |
| `src.fao.infoods` | FAO/INFOODS tagnames + guidelines | FAO | 2011–2015 | fao.org/infoods | open access (download) | citation only | spec; mapping effort needed | Standardizes basis/missingness; no advice. |
| `src.hl7.fhir.r5` | FHIR R5 MedicationKnowledge / NutritionIntake / Observation | HL7 International | R5 (2023) | hl7.org/fhir | open access (spec) | implementation candidate | mappings would be "inspired", not conformant | Representation only; synthetic data. |
| `src.ohdsi.omop.cdm` | OMOP Common Data Model | OHDSI | current | ohdsi.github.io/CommonDataModel | open access (spec) | citation only | concept mapping demo only | No patient data; identity mapping only. |
| `src.fair.principles.2016` | FAIR Guiding Principles | Wilkinson et al. | 2016 | doi:10.1038/sdata.2016.18 | open access | citation only | governance guidance | Documentation/governance only. |
| `src.fda.cds.guidance` | FDA Clinical Decision Support Software guidance | U.S. FDA | 2022; updated 2026 | fda.gov/.../clinical-decision-support-software | open access | citation only (boundary) | regulatory guidance, not code | Defines the non-device boundary to preserve. |
| `src.leta.gi_barriers.2023` | GI barriers to levodopa transport/absorption | Leta et al., *Eur. J. Neurol.* | 2023 | doi:10.1111/ene.15734 | open access (institutional copies) | citation only | mechanism direction only | Educational direction; not dosing/diet advice. |
| `src.daphnet.fog` | Daphnet Freezing of Gait dataset | Bächlin et al. (UCI) | 2010 | archive.ics.uci.edu/dataset/245 | open access (CC BY 4.0) | implementation candidate (synthetic-shape only) | demo architecture only | No PD detection/monitoring; synthetic signals only. |
| `src.weargait.pd` | WearGait-PD wearables dataset | open-access dataset | 2024+ | (open-access; review terms) | open access (review) | citation only | additional gait reference | Architecture demo only; non-diagnostic. |

## Notes on usage

- Every `MechanisticConflictResult.sourceRefs[]` value is a `sourceId` from
  `model_assumption_registry.dart`, which in turn cites one or more entries
  above.
- The replay runner (`tool/run_mechanistic_replay.dart`) embeds these `sourceId`
  strings in its JSON output so reviewers can trace any modeled output back to
  the bibliography entry.
- This file is updated whenever a new mechanism citation is added. It is not a
  clinical evidence registry.
