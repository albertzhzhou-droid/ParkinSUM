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
  ];

  static ModelAssumption? byId(String sourceId) {
    for (final a in all) {
      if (a.sourceId == sourceId) return a;
    }
    return null;
  }
}
