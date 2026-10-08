/// Local source/provenance registry for the mechanistic engine.
///
/// Mirrors `Bibliographies.md`. Every model assumption used by the engine
/// must list one or more `sourceId` strings from this registry. There is NO
/// live citation fetching at runtime — citations are versioned with the code.
library;

enum ModelEvidenceLevel {
  label, // direct drug-label grounding
  mechanism, // peer-reviewed mechanism citation
  regulatoryGuidance, // FDA / regulator guidance
  prototypeHeuristic, // numeric magnitude is illustrative only
}

enum ModelSourceType {
  officialLabel,
  primaryHumanStudy,
  consensusStandard,
  review,
  modelPaper,
  regulatoryGuidance,
  internalSafetyBoundary,
  // Laboratory food-chemistry measurement (no human participants).
  analyticalStudy,
  // Published food-composition reference dataset.
  referenceDataset,
}

class ModelAssumption {
  final String sourceId;
  final String title;
  final ModelSourceType sourceType;
  final String mechanismSupported;
  final String limitation;
  final String citationText;
  final ModelEvidenceLevel evidenceLevel;
  final String lastReviewed;

  const ModelAssumption({
    required this.sourceId,
    required this.title,
    required this.sourceType,
    required this.mechanismSupported,
    required this.limitation,
    required this.citationText,
    required this.evidenceLevel,
    required this.lastReviewed,
  });

  Map<String, dynamic> toJson() => {
    'source_id': sourceId,
    'title': title,
    'source_type': sourceType.name,
    'mechanism_supported': mechanismSupported,
    'limitation': limitation,
    'citation_text': citationText,
    'evidence_level': evidenceLevel.name,
    'last_reviewed': lastReviewed,
  };
}

/// Static in-memory registry.
class ModelAssumptionRegistry {
  static const ModelAssumption sinemetLabel = ModelAssumption(
    sourceId: 'src.dailymed.sinemet.label',
    title: 'DailyMed — SINEMET (carbidopa/levodopa) tablet label',
    sourceType: ModelSourceType.officialLabel,
    mechanismSupported:
        'Levodopa absorption depends on small-intestinal arrival; '
        'high-protein meals may delay absorption; strength is expressed in mg.',
    limitation: 'Label is descriptive; not patient-specific.',
    citationText:
        'U.S. NLM. SINEMET (carbidopa and levodopa) tablet label. DailyMed.',
    evidenceLevel: ModelEvidenceLevel.label,
    lastReviewed: '2026-08-17',
  );

  static const ModelAssumption sinemetExtendedLabel = ModelAssumption(
    sourceId: 'src.dailymed.sinemet.extended.label',
    title:
        'DailyMed — Carbidopa/Levodopa extended-release capsule label (current product-specific labeling)',
    sourceType: ModelSourceType.officialLabel,
    mechanismSupported:
        'For the labeled extended-release capsule, a high-fat, high-calorie '
        'meal may delay levodopa absorption by about two hours; high-protein '
        'food may decrease absorption.',
    limitation:
        'Product-specific label evidence; the magnitude must not be transferred '
        'to every extended-release tablet or capsule.',
    citationText:
        'U.S. NLM. Carbidopa and levodopa extended-release capsule label. '
        'DailyMed setid 9ac804f1-7e15-48bc-8ae9-25181a629dd4.',
    evidenceLevel: ModelEvidenceLevel.label,
    lastReviewed: '2026-08-17',
  );

  static const ModelAssumption apdaLevodopaFood = ModelAssumption(
    sourceId: 'src.apda.levodopa.food',
    title: 'APDA — Interactions between Levodopa and Food',
    sourceType: ModelSourceType.review,
    mechanismSupported:
        'Plain-language summary of levodopa/food/protein interactions for '
        'patient education.',
    limitation: 'Not a primary source; aligns with label-derived mechanism.',
    citationText:
        'American Parkinson Disease Association. Interactions between '
        'Levodopa and Food. APDA.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-05-27',
  );

  static const ModelAssumption npjParkinsonResistance = ModelAssumption(
    sourceId: 'src.npj.peripheral.resistance.2022',
    title:
        'Mechanisms of peripheral levodopa resistance in Parkinson\'s disease',
    sourceType: ModelSourceType.review,
    mechanismSupported:
        'Peripheral resistance mechanisms including LNAA competition and '
        'gastric emptying influence on levodopa availability.',
    limitation: 'Review summarizes population-level mechanism.',
    citationText:
        'Salat D., Tolosa E. Mechanisms of peripheral levodopa resistance in '
        'Parkinson\'s disease. npj Parkinson\'s Disease 8:56, 2022.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-05-27',
  );

  static const ModelAssumption nuttLnaa = ModelAssumption(
    sourceId: 'src.nutt.lnaa.1989',
    title:
        'Influence of fluctuations of plasma LNAAs on the clinical response '
        'to levodopa',
    sourceType: ModelSourceType.primaryHumanStudy,
    mechanismSupported:
        'Eleven participants were observed hourly on a normal hospital diet. '
        'The study tested whether plasma LNAA variation explained fluctuating '
        'levodopa response.',
    limitation:
        'Important negative finding: normal-diet LNAA fluctuations were not an '
        'important contributor for most participants. Small observational '
        'sample; it neither supports a universal penalty nor a patient predictor.',
    citationText:
        'Nutt J.G. et al. Influence of fluctuations of plasma LNAAs with '
        'normal diets on the clinical response to levodopa. J Neurol '
        'Neurosurg Psychiatry 52(4):481–487, 1989.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-08-17',
  );

  static const ModelAssumption nuttOnOff = ModelAssumption(
    sourceId: 'src.nutt.onoff.1984',
    title: 'The on-off phenomenon: levodopa absorption and transport',
    sourceType: ModelSourceType.primaryHumanStudy,
    mechanismSupported:
        'In nine patients with fluctuating motor state, meals reduced peak '
        'plasma levodopa by 29% and delayed absorption by 34 minutes. Selected '
        'large neutral amino acids reversed response to infused levodopa '
        'without reducing plasma levodopa.',
    limitation:
        'Very small mechanistic study in selected fluctuating patients; group '
        'effects do not calibrate an individual score or meal rule.',
    citationText:
        'Nutt JG et al. The on-off phenomenon in Parkinson\'s disease: '
        'relation to levodopa absorption and transport. N Engl J Med '
        '310:483–488, 1984. doi:10.1056/NEJM198402233100802.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-08-17',
  );

  static const ModelAssumption doiGastricLevodopa = ModelAssumption(
    sourceId: 'src.doi.ge.levodopa.2012',
    title: 'Plasma levodopa peak delay and impaired gastric emptying in PD',
    sourceType: ModelSourceType.primaryHumanStudy,
    mechanismSupported:
        'Thirty-one patients underwent levodopa pharmacokinetic and '
        '13C-octanoic-acid breath testing; delayed gastric emptying was more '
        'common in the group with a later plasma levodopa peak.',
    limitation:
        'Association in a small cohort, not proof that a modeled meal curve '
        'predicts an individual plasma peak or clinical response.',
    citationText:
        'Doi H et al. Plasma levodopa peak delay and impaired gastric emptying '
        'in Parkinson\'s disease. J Neurol Sci 319:86–88, 2012. '
        'doi:10.1016/j.jns.2012.05.010.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-08-17',
  );

  static const ModelAssumption hardoffGastricPd = ModelAssumption(
    sourceId: 'src.hardoff.ge.pd.2001',
    title: 'Gastric emptying time and motility in Parkinson\'s disease',
    sourceType: ModelSourceType.primaryHumanStudy,
    mechanismSupported:
        'Scintigraphy in 51 participants with PD and 22 controls found slower '
        'mean emptying and wide variability in the PD groups.',
    limitation:
        'Group means overlapped and clinical subgroups behaved differently; '
        'the result supports visible uncertainty, not a disease-specific constant.',
    citationText:
        'Hardoff R et al. Gastric emptying time and gastric motility in '
        'patients with Parkinson\'s disease. Mov Disord 16:1041–1047, 2001. '
        'doi:10.1002/mds.1203.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-08-17',
  );

  static const ModelAssumption siebnerEarlyTreatedGastric = ModelAssumption(
    sourceId: 'src.siebner.ge.earlypd.2022',
    title: 'Gastric emptying in medicated early Parkinson disease',
    sourceType: ModelSourceType.primaryHumanStudy,
    mechanismSupported:
        'Solid-meal scintigraphy in 15 people with early, treated Parkinson '
        'disease and matched controls found no group-level delay; only one '
        'participant with Parkinson disease met the delayed-emptying criterion.',
    limitation:
        'Small preliminary study in early disease while usual dopamine '
        'replacement continued. It does not exclude delayed emptying in other '
        'stages or contexts, but prevents treating a disease-wide delay as universal.',
    citationText:
        'Siebner TH et al. Gastric Emptying Is Not Delayed and Does Not '
        'Correlate With Attenuated Postprandial Blood Flow Increase in '
        'Medicated Patients With Early Parkinson\'s Disease. Front Neurol '
        '13:828069, 2022. doi:10.3389/fneur.2022.828069.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-08-17',
  );

  static const ModelAssumption gastricScintigraphyConsensus = ModelAssumption(
    sourceId: 'src.abell.ges.consensus.2008',
    title: 'Consensus standard for gastric emptying scintigraphy',
    sourceType: ModelSourceType.consensusStandard,
    mechanismSupported:
        'Standardizes a low-fat egg-white meal and measurements at 0, 1, 2, '
        'and 4 hours; establishes how clinical gastric emptying is measured.',
    limitation:
        'A measurement protocol, not a formula for arbitrary meals and not a '
        'basis for diagnosing delayed emptying from ParkinSUM inputs.',
    citationText:
        'Abell TL et al. Consensus recommendations for gastric emptying '
        'scintigraphy. J Nucl Med Technol 36:44–54, 2008. '
        'doi:10.2967/jnmt.107.048116.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-08-17',
  );

  static const ModelAssumption dualReleaseFoodPk = ModelAssumption(
    sourceId: 'src.crevoisier.dualrelease.food.2003',
    title: 'Food effect on dual-release levodopa pharmacokinetics',
    sourceType: ModelSourceType.primaryHumanStudy,
    mechanismSupported:
        'In a randomized two-way crossover in 19 healthy volunteers, a '
        'high-fat breakfast lowered mean Cmax and shifted mean Tmax from '
        '1.0 to 3.1 hours for one levodopa/benserazide formulation.',
    limitation:
        'Healthy volunteers and one formulation; the magnitude must not be '
        'generalized to other release products or individual patients.',
    citationText:
        'Crevoisier C et al. Effects of food on the pharmacokinetics of '
        'levodopa in a dual-release formulation. Eur J Pharm Biopharm '
        '55:71–76, 2003. PMID:12551706.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-08-17',
  );

  static const ModelAssumption ceredaProteinRestricted = ModelAssumption(
    sourceId: 'src.cereda.protein.2017',
    title: 'Protein-restricted diets for motor fluctuations in PD',
    sourceType: ModelSourceType.review,
    mechanismSupported:
        'Protein-restricted diets are studied as a population-level strategy '
        'for motor fluctuations; protein-levodopa interaction is supported.',
    limitation:
        'Not a prescription pattern for individuals; ParkinSUM uses for '
        'mechanism direction only.',
    citationText:
        'Cereda E. et al. Protein-restricted diets for ameliorating motor '
        'fluctuations in Parkinson\'s disease. Front Aging Neurosci 9:206, '
        '2017.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-05-27',
  );

  static const ModelAssumption advancesNutritionLevodopa = ModelAssumption(
    sourceId: 'src.advances.nutrition.2021',
    title:
        'Dietary approaches to improve efficacy and control side effects of '
        'levodopa therapy',
    sourceType: ModelSourceType.review,
    mechanismSupported:
        'Systematic review of dietary interactions with levodopa therapy.',
    limitation: 'Review; not clinical decision support.',
    citationText:
        'Boelens Keun J.T. et al. Dietary approaches to improve efficacy and '
        'control side effects of levodopa therapy in PD: a systematic review. '
        'Adv Nutr 12(6):2265–2287, 2021.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-05-27',
  );

  static const ModelAssumption levodopaPk = ModelAssumption(
    sourceId: 'src.contin.levodopa.pk.2010',
    title: 'Pharmacokinetics of L-dopa',
    sourceType: ModelSourceType.review,
    mechanismSupported:
        'Mechanism review of levodopa pharmacokinetics including absorption '
        'site and food-related delay.',
    limitation: 'Population-level pharmacokinetics, not patient prediction.',
    citationText:
        'Contin M., Martinelli P. Pharmacokinetics of levodopa. J Neurol '
        '257(suppl 2):253–261, 2010.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-05-27',
  );

  static const ModelAssumption gastricEmptyingHalfTime = ModelAssumption(
    sourceId: 'src.zinsmeister.ge.halftime.2012',
    title:
        'Calculations to estimate gastric emptying half-time of solids in '
        'humans',
    sourceType: ModelSourceType.modelPaper,
    mechanismSupported:
        'Methods and reference ranges for gastric emptying half-times and '
        'inter-subject variation.',
    limitation: 'Population-level; ParkinSUM uses for direction not exact PK.',
    citationText:
        'Zinsmeister A.R., Bharucha A.E., Camilleri M. Comparison of '
        'calculations to estimate gastric emptying half-time of solids in '
        'humans. Neurogastroenterol Motil 24(12):1142–1145, 2012. '
        'doi:10.1111/j.1365-2982.2012.01982.x.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-08-17',
  );

  static const ModelAssumption
  gastricEmptyingMeasurementVariation = ModelAssumption(
    sourceId: 'src.camilleri.ge.variation.2012',
    title:
        'Performance characteristics of scintigraphic gastric emptying '
        'measurement in healthy participants',
    sourceType: ModelSourceType.primaryHumanStudy,
    mechanismSupported:
        'Measured solid-meal half-time showed 24.5% between-participant '
        'and 23.8% within-participant coefficients of variation.',
    limitation:
        'Healthy-participant measurement variability is not a Parkinson '
        'disease distribution and does not justify a patient interval. '
        'ParkinSUM uses it only to motivate an illustrative sensitivity run.',
    citationText:
        'Camilleri M. et al. Performance characteristics of scintigraphic '
        'measurement of gastric emptying of solids in healthy participants. '
        'Neurogastroenterol Motil 24(12):1076-e562, 2012. '
        'doi:10.1111/j.1365-2982.2012.01972.x.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-08-17',
  );

  static const ModelAssumption foodPhysicalProperties = ModelAssumption(
    sourceId: 'src.hens.foodphysical.2024',
    title:
        'Impact of food physical properties on oral drug absorption '
        '(comprehensive review)',
    sourceType: ModelSourceType.review,
    mechanismSupported:
        'Food physical form, fat, fiber, and meal size modulate gastric '
        'emptying and oral drug absorption windows.',
    limitation:
        'Review summarizes population-level direction; not patient model.',
    citationText:
        'Hens B. et al. Impact of food physical properties on oral drug '
        'absorption: a comprehensive review. Pharmaceutics 16(12):1605, 2024.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-05-27',
  );

  static const ModelAssumption fdaCdsGuidance = ModelAssumption(
    sourceId: 'src.fda.cds.guidance.2022',
    title: 'FDA Clinical Decision Support Software Guidance (Final, 2022)',
    sourceType: ModelSourceType.regulatoryGuidance,
    mechanismSupported:
        'Intended-use framing for software whose output supports independent '
        'review rather than primary clinical reliance.',
    limitation: 'Regulatory framing only; not a model parameter.',
    citationText:
        'U.S. FDA. Clinical Decision Support Software: Guidance for Industry '
        'and FDA Staff. Federal Register, 28 Sep 2022.',
    evidenceLevel: ModelEvidenceLevel.regulatoryGuidance,
    lastReviewed: '2026-05-27',
  );

  static const ModelAssumption lnaaPlantVsAnimal = ModelAssumption(
    sourceId: 'src.lnaa.plantvanimal.2023',
    title:
        'To restrict or not to restrict? Practical considerations for optimizing '
        'dietary protein interactions on levodopa absorption in PD (Virmani et al.)',
    sourceType: ModelSourceType.review,
    mechanismSupported:
        'Dietary LNAA load from animal protein is generally higher per gram '
        'than from plant protein; both can affect levodopa absorption.',
    limitation:
        'Population-level direction; not a per-patient predictor and not '
        'used to claim clinical pharmacokinetics.',
    citationText:
        'Virmani T. et al. To restrict or not to restrict? Practical '
        'considerations for optimizing dietary protein interactions on '
        'levodopa absorption in PD. npj Parkinson\'s Disease 9:87, 2023.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-05-27',
  );

  static const ModelAssumption fdcAminoAcidFields = ModelAssumption(
    sourceId: 'src.fdc.api.amino_acid_fields',
    title: 'USDA FoodData Central — amino-acid nutrient fields availability',
    sourceType: ModelSourceType.officialLabel,
    mechanismSupported:
        'USDA FDC exposes amino-acid nutrient numbers using the verified '
        'mapping 501 tryptophan, 502 threonine, 503 isoleucine, 504 leucine, '
        '506 methionine, 508 phenylalanine, 509 tyrosine, 510 valine, '
        '512 histidine. ParkinSUM\'s AminoAcidExtractor extracts this LNAA set '
        '(number-priority, name fallback, mg->g normalization, partial flag) '
        'and feeds the LNAA competition layer.',
    limitation:
        'Documents upstream-data availability + extraction only; not patient '
        'calibration. Per-nutrient FDC derivation/sample-count provenance is '
        'not yet captured (see docs/design/SPIKE_FDC_FOUNDATION_PROVENANCE.md).',
    citationText:
        'USDA Agricultural Research Service. FDC Nutrient Data OpenAPI '
        'Documentation. USDA FoodData Central.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-05-29',
  );

  static const ModelAssumption pareProteinRedistribution = ModelAssumption(
    sourceId: 'src.pare.protein.redistribution.1992',
    title:
        'Protein redistribution diet in the control of motor fluctuations in '
        'Parkinson\'s disease',
    sourceType: ModelSourceType.review,
    mechanismSupported:
        'Redistributing dietary protein away from daytime toward the evening '
        'meal can ameliorate the levodopa motor response in some patients; '
        'protein is restricted (~7 g) before the evening meal in classic '
        'protein-redistribution diets.',
    limitation:
        'Protein-redistribution diets are not nutritionally complete and '
        'require professional supervision; population-level finding, not a '
        'per-patient plan. ParkinSUM uses direction only.',
    citationText:
        'Paré S. et al. Proposal for a protein redistribution diet in the '
        'control of motor fluctuations in Parkinson\'s disease. (See also '
        'systematic review, Cereda et al. 2010/2017.)',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-05-27',
  );

  static const ModelAssumption virmaniProtein = ModelAssumption(
    sourceId: 'src.virmani.protein.2023',
    title:
        'Practical considerations for optimizing dietary protein interactions '
        'on levodopa absorption in PD',
    sourceType: ModelSourceType.review,
    mechanismSupported:
        'Reviews protein-restriction vs protein-redistribution tradeoffs and '
        'nutrition-adequacy concerns for levodopa-treated patients.',
    limitation: 'Review; not clinical decision support; direction only.',
    citationText:
        'Virmani T. et al. To restrict or not to restrict? npj Parkinson\'s '
        'Disease 9:87, 2023.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-05-27',
  );

  static const ModelAssumption fdcFoundationDocs = ModelAssumption(
    sourceId: 'src.usda.fdc.foundation_docs',
    title:
        'USDA FoodData Central — Foundation Foods documentation + '
        'FoodNutrient derivation/provenance schema',
    sourceType: ModelSourceType.officialLabel,
    mechanismSupported:
        'FDC publishes per-nutrient provenance (foodNutrientDerivation '
        'code/description, foodNutrientSource, dataPoints sample count) and a '
        'food dataType (Foundation/SR Legacy/Survey/Branded). ParkinSUM maps '
        'derivation provenance to an ordinal confidence tier; a '
        'weaker-than-analytical tier widens modeled uncertainty.',
    limitation:
        'Provenance/ordinal signal only — NOT a measurement-uncertainty or '
        'clinical-accuracy estimate. Missing derivation stays missing (never '
        'raises confidence). Exact field names follow the FDC OpenAPI; '
        're-verify before any live ingestion (none today).',
    citationText:
        'USDA Agricultural Research Service. FoodData Central — Foundation '
        'Foods Documentation and FDC Nutrient Data OpenAPI (FoodNutrient '
        'derivation/source/dataPoints, food dataType).',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-05-29',
  );

  static const ModelAssumption internalPrototypeHeuristic = ModelAssumption(
    sourceId: 'src.internal.prototype.heuristic',
    title: 'ParkinSUM prototype heuristic (no patient calibration)',
    sourceType: ModelSourceType.internalSafetyBoundary,
    mechanismSupported:
        'Illustrative magnitude chosen to keep model behavior monotonic with '
        'direction supported by the cited literature.',
    limitation:
        'Numeric magnitude is NOT patient-calibrated; tagged for reviewers.',
    citationText: 'Internal — see CONFLICT_ENGINE_MODEL.md.',
    evidenceLevel: ModelEvidenceLevel.prototypeHeuristic,
    lastReviewed: '2026-05-27',
  );

  // --- Food composition interdependency layer (2026-10-08) -----------------

  static const ModelAssumption usdaSrLegacy = ModelAssumption(
    sourceId: 'src.usda.sr_legacy.2018',
    title: 'USDA FoodData Central — SR Legacy (April 2018) composition data',
    sourceType: ModelSourceType.referenceDataset,
    mechanismSupported:
        'Per-100 g composition of 224 reference foods reproduced verbatim '
        '(energy, protein, fat, carbohydrate by difference, fibre, minerals, '
        'selected vitamins). Paired raw/cooked, whole/part and fresh/dried '
        'records support tracer-based consistency checks between foods.',
    limitation:
        'Sample averages from historical analyses; cultivar, season, '
        'processing and recipe change real foods. Values describe foods, not '
        'any person, and the subset is not every food a person may eat.',
    citationText:
        'U.S. Department of Agriculture, Agricultural Research Service. '
        'FoodData Central: SR Legacy, April 2018. Retrieved via the public '
        'Hugging Face mirror ULM-DS-Lab/food-composition-matrix '
        '(usda_sr_legacy_2018_wide.csv); public domain.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-10-08',
  );

  static const ModelAssumption faoFoodEnergy = ModelAssumption(
    sourceId: 'src.fao.food_energy.2003',
    title:
        'FAO Food and Nutrition Paper 77 — Food energy: methods of analysis '
        'and conversion factors',
    sourceType: ModelSourceType.consensusStandard,
    mechanismSupported:
        'General energy conversion factors: protein and available '
        'carbohydrate 4 kcal/g, fat 9 kcal/g, dietary fibre 2 kcal/g, '
        'alcohol 7 kcal/g, organic acids about 3 kcal/g. Used to reconcile '
        'reported energy with reported macronutrients.',
    limitation:
        'Data sets also use food-specific factors, so a general-factor check '
        'needs a tolerance band; a residual flags a record for review and is '
        'not proof of an error.',
    citationText:
        'FAO. Food energy — methods of analysis and conversion factors. '
        'Report of a Technical Workshop, Rome, 3–6 December 2002. FAO Food '
        'and Nutrition Paper 77. Rome: FAO, 2003.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-10-08',
  );

  static const ModelAssumption euSaltFactor = ModelAssumption(
    sourceId: 'src.eu.reg1169.salt_factor',
    title: 'Regulation (EU) No 1169/2011, Annex I(11): salt = sodium × 2.5',
    sourceType: ModelSourceType.regulatoryGuidance,
    mechanismSupported:
        'Labelling convention converting sodium to salt equivalent.',
    limitation:
        'Labelling convention (NaCl/Na mass ratio is 2.54); it does not say '
        'all sodium comes from added salt.',
    citationText:
        'Regulation (EU) No 1169/2011 of the European Parliament and of the '
        'Council on the provision of food information to consumers, Annex I, '
        'point 11. OJ L 304, 22.11.2011.',
    evidenceLevel: ModelEvidenceLevel.regulatoryGuidance,
    lastReviewed: '2026-10-08',
  );

  static const ModelAssumption mariottiNitrogenFactors = ModelAssumption(
    sourceId: 'src.mariotti.nitrogen_protein.2008',
    title: 'Converting nitrogen into protein — beyond 6.25 and Jones\' factors',
    sourceType: ModelSourceType.review,
    mechanismSupported:
        'Food "protein" is measured nitrogen multiplied by a conversion '
        'factor; the factor convention differs between foods and sources, '
        'so cross-source protein differences can be partly definitional.',
    limitation:
        'Explains why small cross-source protein differences are expected; '
        'it does not give a per-food correction applied by ParkinSUM.',
    citationText:
        'Mariotti F., Tomé D., Mirand P.P. Converting nitrogen into '
        'protein — beyond 6.25 and Jones\' factors. Crit Rev Food Sci Nutr '
        '48(2):177-184, 2008. doi:10.1080/10408390701279749. PMID:18274971.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-10-08',
  );

  static const ModelAssumption duanFabaLdopaThermal = ModelAssumption(
    sourceId: 'src.duan.faba_ldopa_thermal.2021',
    title:
        'Effect of thermal processing on L-dopa in faba bean leaves and seeds',
    sourceType: ModelSourceType.analyticalStudy,
    mechanismSupported:
        'HPLC measured L-dopa at 24.44 (young leaves), 18.13 (old leaves) '
        'and 0.15 (mature seeds) mg/g dry weight in one accession; steaming '
        'lowered leaf L-dopa to 8.52–10.88 mg/g while seed values stayed '
        'at 0.10–0.15 mg/g after up to 1 h of dry or wet heat.',
    limitation:
        'Single accession grown in one greenhouse; dry-weight basis. It does '
        'not give the L-dopa content of a cooked serving or any absorbed '
        'amount, and it is not a basis for substituting food for medicine.',
    citationText:
        'Duan S.C., Kwon S.J., Eom S.H. Effect of Thermal Processing on '
        'Color, Phenolic Compounds, and Antioxidant Activity of Faba Bean '
        '(Vicia faba L.) Leaves and Seeds. Antioxidants (Basel) 10(8):1207, '
        '2021. doi:10.3390/antiox10081207. PMID:34439455.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-10-08',
  );

  static const ModelAssumption tesoroFabaPodLdopa = ModelAssumption(
    sourceId: 'src.tesoro.faba_pod_ldopa.2024',
    title: 'Vicia faba pod valves: L-dopa content compared with seeds',
    sourceType: ModelSourceType.analyticalStudy,
    mechanismSupported:
        'LC-UV measured L-dopa at 28.65 mg/g dry weight in broad bean pod '
        'valves versus 0.76 mg/g dry weight in seeds of the same cultivar.',
    limitation:
        'One regional cultivar; dry-weight basis. Shows that L-dopa content '
        'depends strongly on plant part and variety, not a serving amount.',
    citationText:
        'Tesoro C. et al. Vicia faba L. Pod Valves: A By-Product with High '
        'Potential as an Adjuvant in the Treatment of Parkinson\'s Disease. '
        'Molecules 29(16):3943, 2024. doi:10.3390/molecules29163943. '
        'PMID:39203021.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-10-08',
  );

  static const ModelAssumption aureliMucunaLdopa = ModelAssumption(
    sourceId: 'src.aureli.mucuna_ldopa.2025',
    title:
        'Quality assessment of "naturally occurring" high-percentage L-dopa '
        'products (Mucuna pruriens)',
    sourceType: ModelSourceType.analyticalStudy,
    mechanismSupported:
        'Reports that the natural L-dopa percentage in Mucuna pruriens seeds '
        'or leaves varies from 1% to 7%, and analysed labelling accuracy of '
        'commercial L-dopa supplement products.',
    limitation:
        'Content range only; product labelling can be inaccurate, so a '
        'declared amount is not treated as a measured amount.',
    citationText:
        'Aureli F. et al. Quality assessment of "naturally occurring" '
        'high-percentage L-dopa commercial products proposed as dietary '
        'supplements on the Internet. Front Chem 13:1597784, 2025. '
        'doi:10.3389/fchem.2025.1597784. PMID:41169659.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-10-08',
  );

  static const ModelAssumption continMucunaPk = ModelAssumption(
    sourceId: 'src.contin.mucuna_pk.2015',
    title:
        'Mucuna pruriens in Parkinson disease: kinetic-dynamic comparison '
        'with standard levodopa formulations',
    sourceType: ModelSourceType.primaryHumanStudy,
    mechanismSupported:
        'In two patients, levodopa bioavailability from a Mucuna extract '
        'without a decarboxylase inhibitor was markedly lower than from '
        'standard levodopa/inhibitor formulations at a nominally equal dose.',
    limitation:
        'Two-patient case report; shows that plant L-dopa exposure is not '
        'interchangeable with a formulated dose and cannot be converted into '
        'one.',
    citationText:
        'Contin M. et al. Mucuna pruriens in Parkinson Disease: A '
        'Kinetic-Dynamic Comparison With Levodopa Standard Formulations. '
        'Clin Neuropharmacol 38(5):201-203, 2015. '
        'doi:10.1097/WNF.0000000000000098. PMID:26366963.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-10-08',
  );

  static const ModelAssumption campbellFerrousSulfate = ModelAssumption(
    sourceId: 'src.campbell.ferrous_sulfate_levodopa.1989',
    title: 'Ferrous sulfate reduces levodopa bioavailability',
    sourceType: ModelSourceType.primaryHumanStudy,
    mechanismSupported:
        'In eight healthy volunteers, 325 mg ferrous sulfate taken with '
        '250 mg levodopa lowered peak levodopa by 55% and AUC by 51%; '
        'chelation of ferric iron by levodopa is the proposed mechanism.',
    limitation:
        'Supplement-dose iron salt in healthy adults; it does not establish '
        'an effect of iron naturally present in foods, so ParkinSUM does not '
        'extrapolate it to food iron.',
    citationText:
        'Campbell N.R., Hasinoff B. Ferrous sulfate reduces levodopa '
        'bioavailability: chelation as a possible mechanism. Clin Pharmacol '
        'Ther 45(3):220-225, 1989. doi:10.1038/clpt.1989.21. PMID:2920496.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-10-08',
  );

  static const ModelAssumption hallbergCalciumIron = ModelAssumption(
    sourceId: 'src.hallberg.calcium_iron.1991',
    title:
        'Calcium: effect of different amounts on nonheme- and heme-iron '
        'absorption in humans',
    sourceType: ModelSourceType.primaryHumanStudy,
    mechanismSupported:
        'Calcium reduced iron absorption dose-dependently up to 300 mg; '
        '165 mg calcium given as milk, cheese or calcium chloride reduced '
        'absorption from a meal by 50–60%.',
    limitation:
        'Single-meal isotope studies; long-term iron status effects are '
        'smaller and individual. Used only as a co-consumption context note.',
    citationText:
        'Hallberg L. et al. Calcium: effect of different amounts on '
        'nonheme- and heme-iron absorption in humans. Am J Clin Nutr '
        '53(1):112-119, 1991. doi:10.1093/ajcn/53.1.112. PMID:1984335.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-10-08',
  );

  static const ModelAssumption zijpTeaIron = ModelAssumption(
    sourceId: 'src.zijp.tea_iron.2000',
    title: 'Effect of tea and other dietary factors on iron absorption',
    sourceType: ModelSourceType.review,
    mechanismSupported:
        'Ascorbic acid and meat, fish and poultry enhance non-heme iron '
        'absorption; polyphenols in tea and coffee, phytate and calcium '
        'inhibit it; heme iron is little affected by these factors.',
    limitation:
        'Review of meal studies; enhancers present in mixed diets can '
        'offset inhibitors. Context only, not an iron-status prediction.',
    citationText:
        'Zijp I.M., Korver O., Tijburg L.B. Effect of tea and other dietary '
        'factors on iron absorption. Crit Rev Food Sci Nutr 40(5):371-398, '
        '2000. doi:10.1080/10408690091189194. PMID:11029010.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-10-08',
  );

  static const ModelAssumption cookReddyAscorbate = ModelAssumption(
    sourceId: 'src.cook_reddy.ascorbate_iron.2001',
    title:
        'Effect of ascorbic acid intake on nonheme-iron absorption from a '
        'complete diet',
    sourceType: ModelSourceType.primaryHumanStudy,
    mechanismSupported:
        'Over 5-day complete-diet periods (vitamin C 51–247 mg/d), mean '
        'non-heme iron absorption did not differ significantly, in contrast '
        'with the pronounced single-meal effect.',
    limitation:
        'Twelve participants; shows that single-meal enhancement does not '
        'translate directly into whole-diet effects.',
    citationText:
        'Cook J.D., Reddy M.B. Effect of ascorbic acid intake on '
        'nonheme-iron absorption from a complete diet. Am J Clin Nutr '
        '73(1):93-98, 2001. doi:10.1093/ajcn/73.1.93. PMID:11124756.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-10-08',
  );

  static const ModelAssumption nagayamaAscorbateLevodopa = ModelAssumption(
    sourceId: 'src.nagayama.ascorbate_levodopa.2004',
    title:
        'Effect of ascorbic acid on the pharmacokinetics of levodopa in '
        'elderly patients with Parkinson disease',
    sourceType: ModelSourceType.primaryHumanStudy,
    mechanismSupported:
        'Adding 200 mg ascorbic acid to 100/10 mg levodopa/carbidopa did not '
        'change pharmacokinetics across all 67 participants; AUC and Cmax '
        'rose only in the 25 with low baseline AUC.',
    limitation:
        'Supplement dose, subgroup finding; ParkinSUM does not convert food '
        'vitamin C into any levodopa adjustment.',
    citationText:
        'Nagayama H. et al. The effect of ascorbic acid on the '
        'pharmacokinetics of levodopa in elderly patients with Parkinson '
        'disease. Clin Neuropharmacol 27(6):270-273, 2004. '
        'doi:10.1097/01.wnf.0000150865.21759.bc. PMID:15613930.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-10-08',
  );

  static const ModelAssumption demarcaidaRasagilineTyramine = ModelAssumption(
    sourceId: 'src.demarcaida.rasagiline_tyramine.2006',
    title:
        'Tyramine administration in Parkinson disease patients treated '
        'with the selective MAO-B inhibitor rasagiline',
    sourceType: ModelSourceType.primaryHumanStudy,
    mechanismSupported:
        'Tyramine challenges of 50–75 mg in 110 participants produced no '
        'clinically significant pressor reaction at rasagiline 0.5–2 mg/day.',
    limitation:
        'Applies to the studied drug and doses; tyramine content of foods '
        'is highly variable and is not quantified per food by ParkinSUM.',
    citationText:
        'deMarcaida J.A. et al. Effects of tyramine administration in '
        'Parkinson\'s disease patients treated with selective MAO-B '
        'inhibitor rasagiline. Mov Disord 21(10):1716-1721, 2006. '
        'doi:10.1002/mds.21048. PMID:16856145.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-10-08',
  );

  static const ModelAssumption shulmanTyramineSoy = ModelAssumption(
    sourceId: 'src.shulman.tyramine_soy.1999',
    title:
        'Refining the MAOI diet: tyramine content of pizzas and soy '
        'products',
    sourceType: ModelSourceType.analyticalStudy,
    mechanismSupported:
        'HPLC found marked variability in soy products, including high '
        'tyramine in one soy sauce and clinically relevant levels in tofu '
        'stored for a week.',
    limitation:
        'Product- and storage-specific measurements; supports "variable, '
        'storage-dependent" rather than a fixed per-food value.',
    citationText:
        'Shulman K.I., Walker S.E. Refining the MAOI diet: tyramine content '
        'of pizzas and soy products. J Clin Psychiatry 60(3):191-193, 1999. '
        'PMID:10192596.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-10-08',
  );

  static const ModelAssumption astarloaFiberLevodopa = ModelAssumption(
    sourceId: 'src.astarloa.fiber_levodopa.1992',
    title:
        'Clinical and pharmacokinetic effects of a diet rich in insoluble '
        'fiber on Parkinson disease',
    sourceType: ModelSourceType.primaryHumanStudy,
    mechanismSupported:
        'In constipated patients, an insoluble-fibre-rich diet was '
        'associated with higher early plasma L-dopa and better motor scores.',
    limitation:
        'Small clinical study in constipated patients; direction differs '
        'from fibre-related gastric-emptying uncertainty and is context only.',
    citationText:
        'Astarloa R. et al. Clinical and pharmacokinetic effects of a diet '
        'rich in insoluble fiber on Parkinson disease. Clin Neuropharmacol '
        '15(5):375-380, 1992. doi:10.1097/00002826-199210000-00004. '
        'PMID:1330307.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-10-08',
  );

  // --- Product-level food and medication reference data (2026-10-08) -------

  static const ModelAssumption handbook74Energy = ModelAssumption(
    sourceId: 'src.merrill_watt.handbook74.1973',
    title:
        'Agriculture Handbook No. 74 — Energy value of foods: basis and '
        'derivation',
    sourceType: ModelSourceType.consensusStandard,
    mechanismSupported:
        'Food-specific energy conversion factors (the FDC calorie conversion '
        'factors) and the 6.93 kcal/g factor for ethyl alcohol, used to '
        'reconcile reported energy with reported proximates.',
    limitation:
        'Factors describe food records, not digestion in any person. A '
        'residual flags a record for review and is not proof of an error.',
    citationText:
        'Merrill A.L., Watt B.K. Energy Value of Foods: Basis and Derivation. '
        'Agriculture Handbook No. 74. Washington, DC: USDA, 1955; slightly '
        'revised 1973.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-10-08',
  );

  static const ModelAssumption usdaFdcRelease2025 = ModelAssumption(
    sourceId: 'src.usda.fdc.full_download.2025_04_24',
    title:
        'USDA FoodData Central — full CSV download, release 2025-04-24 '
        '(nutrient definitions and conversion factors)',
    sourceType: ModelSourceType.referenceDataset,
    mechanismSupported:
        'Official nutrient ids, legacy numbers, names and units used by the '
        'importer, and the per-food nitrogen-to-protein and calorie '
        'conversion factors used by the composition identity audit.',
    limitation:
        'Retrieved through a third-party mirror and pinned by SHA-256; '
        'definitions and factors can change in later FDC releases.',
    citationText:
        'U.S. Department of Agriculture, Agricultural Research Service. '
        'FoodData Central, full download of all data types, April 2025 '
        '(release 2025-04-24). Retrieved via the Hugging Face mirror '
        'yvfu/FoodData_Central_csv_2025-04-24; public domain.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-10-08',
  );

  static const ModelAssumption usdaFndds20172018 = ModelAssumption(
    sourceId: 'src.usda.fndds.2017_2018',
    title: 'USDA Food and Nutrient Database for Dietary Studies 2017-2018',
    sourceType: ModelSourceType.referenceDataset,
    mechanismSupported:
        'Per-100 g composition of mixed dishes and prepared foods that SR '
        'Legacy does not describe, used verbatim for seed catalog foods.',
    limitation:
        'FNDDS values are computed from recipes and ingredient records, not '
        'analysed directly; a dish named alike may differ from a regional '
        'recipe, so non-identical matches are marked as proxies.',
    citationText:
        'U.S. Department of Agriculture, Agricultural Research Service, Food '
        'Surveys Research Group. Food and Nutrient Database for Dietary '
        'Studies 2017-2018 (FoodData Central Survey foods). Retrieved via the '
        'Hugging Face mirror tramzel/fndds; public domain.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-10-08',
  );

  static const ModelAssumption nlmRxnorm20241202 = ModelAssumption(
    sourceId: 'src.nlm.rxnorm.2024_12_02',
    title:
        'NLM RxNorm, release of 2 December 2024 (Current Prescribable '
        'Content)',
    sourceType: ModelSourceType.referenceDataset,
    mechanismSupported:
        'Ingredient (IN) and clinical drug (SCD) concepts, FDA UNII codes and '
        'linked NDC products that give catalog medications verified '
        'identities and dose-form release types.',
    limitation:
        'Identity and coding data only; no dose, schedule or recommendation '
        'is derived. Concepts can be retired or remapped in later releases.',
    citationText:
        'U.S. National Library of Medicine. RxNorm, release of 2 December '
        '2024, Current Prescribable Content (RXNCONSO.RRF). Retrieved via the '
        'Hugging Face mirror OnDeviceMedNotes/nih-rxnorm-dec-2-2024.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-10-08',
  );

  static const List<ModelAssumption> all = [
    sinemetLabel,
    sinemetExtendedLabel,
    apdaLevodopaFood,
    npjParkinsonResistance,
    nuttLnaa,
    nuttOnOff,
    doiGastricLevodopa,
    hardoffGastricPd,
    siebnerEarlyTreatedGastric,
    gastricScintigraphyConsensus,
    dualReleaseFoodPk,
    ceredaProteinRestricted,
    advancesNutritionLevodopa,
    levodopaPk,
    gastricEmptyingHalfTime,
    gastricEmptyingMeasurementVariation,
    foodPhysicalProperties,
    fdaCdsGuidance,
    lnaaPlantVsAnimal,
    fdcAminoAcidFields,
    pareProteinRedistribution,
    virmaniProtein,
    fdcFoundationDocs,
    internalPrototypeHeuristic,
    usdaSrLegacy,
    faoFoodEnergy,
    euSaltFactor,
    mariottiNitrogenFactors,
    duanFabaLdopaThermal,
    tesoroFabaPodLdopa,
    aureliMucunaLdopa,
    continMucunaPk,
    campbellFerrousSulfate,
    hallbergCalciumIron,
    zijpTeaIron,
    cookReddyAscorbate,
    nagayamaAscorbateLevodopa,
    demarcaidaRasagilineTyramine,
    shulmanTyramineSoy,
    astarloaFiberLevodopa,
    handbook74Energy,
    usdaFdcRelease2025,
    usdaFndds20172018,
    nlmRxnorm20241202,
  ];

  static ModelAssumption? byId(String sourceId) {
    for (final a in all) {
      if (a.sourceId == sourceId) return a;
    }
    return null;
  }
}
