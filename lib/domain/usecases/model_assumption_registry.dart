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
    lastReviewed: '2026-05-27',
  );

  static const ModelAssumption sinemetExtendedLabel = ModelAssumption(
    sourceId: 'src.dailymed.sinemet.extended.label',
    title: 'DailyMed — Carbidopa/Levodopa extended-release tablet label',
    sourceType: ModelSourceType.officialLabel,
    mechanismSupported:
        'Extended-release formulation alters release kinetics relative to '
        'immediate-release; food effect documented.',
    limitation: 'Label is descriptive; not patient-specific.',
    citationText:
        'U.S. NLM. Carbidopa/levodopa extended-release tablet label. DailyMed.',
    evidenceLevel: ModelEvidenceLevel.label,
    lastReviewed: '2026-05-27',
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
    title: 'Influence of fluctuations of plasma LNAAs on the clinical response '
        'to levodopa',
    sourceType: ModelSourceType.review,
    mechanismSupported:
        'Plasma LNAA fluctuations from normal diets can modulate clinical '
        'response to levodopa.',
    limitation: 'Population-level finding; not a per-patient predictor.',
    citationText:
        'Nutt J.G. et al. Influence of fluctuations of plasma LNAAs with '
        'normal diets on the clinical response to levodopa. J Neurol '
        'Neurosurg Psychiatry 52(4):481–487, 1989.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-05-27',
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
    title: 'Dietary approaches to improve efficacy and control side effects of '
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
    sourceId: 'src.camilleri.ge.halftime.2009',
    title: 'Calculations to estimate gastric emptying half-time of solids in '
        'humans',
    sourceType: ModelSourceType.modelPaper,
    mechanismSupported:
        'Methods and reference ranges for gastric emptying half-times and '
        'inter-subject variation.',
    limitation: 'Population-level; ParkinSUM uses for direction not exact PK.',
    citationText:
        'Cremonini F. et al. Comparison of calculations to estimate gastric '
        'emptying half-time of solids in humans. Neurogastroenterology & '
        'Motility 21(3):247–254, 2009.',
    evidenceLevel: ModelEvidenceLevel.mechanism,
    lastReviewed: '2026-05-27',
  );

  static const ModelAssumption foodPhysicalProperties = ModelAssumption(
    sourceId: 'src.hens.foodphysical.2024',
    title: 'Impact of food physical properties on oral drug absorption '
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
    ceredaProteinRestricted,
    advancesNutritionLevodopa,
    levodopaPk,
    gastricEmptyingHalfTime,
    foodPhysicalProperties,
    fdaCdsGuidance,
    internalPrototypeHeuristic,
  ];

  static ModelAssumption? byId(String sourceId) {
    for (final a in all) {
      if (a.sourceId == sourceId) return a;
    }
    return null;
  }
}
