/// Parameter set of the physiology reference model (v3 Dart port).
///
/// Mirrors `tool/physiology_reference/parameters.json` value for value, with
/// the same unit, status and source text; `physiology_reference_model_test`
/// fails if the two drift apart. Population-typical values for an educational
/// research prototype: not patient estimates, clinical cutoffs, or dosing,
/// timing or dietary advice.
library;

/// How a value was obtained. Mirrors the reference's status vocabulary.
enum PhysiologyParameterStatus {
  /// Point value taken from the cited publication.
  literature,

  /// Fitted so the model reproduces the cited calibration target; not
  /// independently validated by that target.
  calibrated,

  /// Illustrative modeling choice with a stated rationale.
  heuristic,

  /// Transcribed from a cited table that has not yet been re-checked against
  /// the primary source in this repository.
  verify,
}

/// One parameter: a scalar or a keyed table (per amino acid, per protein
/// type, or per habitual intake), never both.
final class PhysiologyReferenceParameter {
  final String id;
  final double? scalar;
  final Map<String, double>? perAminoAcid;
  final String unit;
  final PhysiologyParameterStatus status;
  final String? source;
  final String? note;

  /// Between-person coefficient of variation for seeded log-normal draws;
  /// null when the parameter is held fixed.
  final double? iivCv;
  final String? iivSource;

  /// Registered model-assumption source ids (`ModelAssumptionRegistry`).
  final List<String> sourceIds;

  const PhysiologyReferenceParameter({
    required this.id,
    this.scalar,
    this.perAminoAcid,
    required this.unit,
    required this.status,
    this.source,
    this.note,
    this.iivCv,
    this.iivSource,
    required this.sourceIds,
  }) : assert((scalar == null) != (perAminoAcid == null));

  /// The reference's JSON shape (`value` instead of scalar/perAminoAcid).
  Map<String, Object?> toReferenceJson() => {
    'id': id,
    'value': scalar ?? perAminoAcid,
    'unit': unit,
    'status': status.name,
    if (source != null) 'source': source,
    if (note != null) 'note': note,
    if (iivCv != null) 'iiv_cv': iivCv,
    if (iivSource != null) 'iiv_source': iivSource,
  };
}

final class PhysiologyReferenceParameterSet {
  static const String parameterSetId = 'physiology_reference_v3_prototype';
  static const String parameterSetVersion = '2026.10.23-v1';
  static const String boundary =
      'Educational research prototype. Population-typical values only; not '
      'patient estimates, clinical cutoffs, or dosing, timing or dietary '
      'advice.';

  /// Order matches the reference file; seeded draws consume random numbers
  /// in this order.
  static const List<PhysiologyReferenceParameter> parameters = [
    PhysiologyReferenceParameter(
      id: 'stomach.energy_delivery_max_kcal_per_min',
      scalar: 2.13,
      unit: 'kcal/min',
      status: PhysiologyParameterStatus.literature,
      source:
          'Brener W, Hendrix TR, McHugh PR. Gastroenterology 1983;85:76-82 (PMID 6852464): glucose solutions emptied at a calorie-constant 2.13 kcal/min at all three concentrations.',
      note:
          'Applied to the emptiable (processed) pool of every energy-containing component, liquid or solid.',
      iivSource:
          'Between-person spread of measured half-emptying in healthy adults (~24.5%); the repository\'s existing src.camilleri.ge.variation.2012 reference.',
      iivCv: 0.25,
      sourceIds: [
        'src.brener.glucose_emptying.1983',
        'src.camilleri.ge.variation.2012',
      ],
    ),
    PhysiologyReferenceParameter(
      id: 'stomach.energy_tail_half_kcal',
      scalar: 10.0,
      unit: 'kcal',
      status: PhysiologyParameterStatus.heuristic,
      note:
          'Energy left in the emptiable pool at which delivery is half of the maximum. Kept small so delivery stays near-constant through most of emptying, as Brener 1983 observed, while small loads still finish with a first-order tail.',
      sourceIds: [],
    ),
    PhysiologyReferenceParameter(
      id: 'stomach.solid_trituration_rate_per_min',
      scalar: 0.0312,
      unit: '1/min (per stage, two stages)',
      status: PhysiologyParameterStatus.calibrated,
      source:
          'Tougas G et al. Am J Gastroenterol 2000;95:1456-62 (DOI 10.1111/j.1572-0241.2000.02076.x): median solid retention 69% at 60 min, 24% at 120 min, 1.2% at 240 min for the standardized low-fat egg-substitute meal (123 healthy volunteers, 11 centres).',
      note:
          'Two first-order grinding stages in series reproduce the lag-then-linear solid emptying described by the power-exponential model (Elashoff 1982, PMID 7129034). Calibration meal energy assumed 255 kcal (consensus meal; energy to verify against Abell 2008, DOI 10.1111/j.1572-0241.2007.01636.x).',
      iivCv: 0.3,
      sourceIds: [
        'src.tougas.gastric.lowfat_controls.2000',
        'src.elashoff.gastric.powerexp.1982',
        'src.abell.ges.consensus.2008',
      ],
    ),
    PhysiologyReferenceParameter(
      id: 'stomach.fasted_liquid_half_time_min',
      scalar: 10.0,
      unit: 'min',
      status: PhysiologyParameterStatus.heuristic,
      source:
          'Brener 1983 (PMID 6852464): saline emptied rapidly and exponentially (volume-driven, open loop).',
      note:
          'Half-time for water and dissolved drug in an otherwise empty stomach. Fasting emptying varies with the migrating motor complex; the wide spread is carried as variability.',
      iivCv: 0.5,
      sourceIds: ['src.brener.glucose_emptying.1983'],
    ),
    PhysiologyReferenceParameter(
      id: 'stomach.fed_liquid_slowing_half_kcal',
      scalar: 231.4,
      unit: 'kcal',
      status: PhysiologyParameterStatus.calibrated,
      source:
          'Nutt JG et al. N Engl J Med 1984;310:483-8 (DOI 10.1056/NEJM198402233100802): meals delayed levodopa absorption by 34 minutes and reduced peak plasma levodopa by 29 per cent.',
      note:
          'Energy still in the stomach at which water and dissolved drug empty at half the fasted rate. Fitted to the 34-minute delay only; the 29% peak reduction is then an independent check. The study meal composition is not in the abstract; the calibration meal is an assumed ~500 kcal mixed breakfast.',
      iivCv: 0.4,
      sourceIds: ['src.nutt.onoff.1984'],
    ),
    PhysiologyReferenceParameter(
      id: 'levodopa.ir_dissolution_half_time_min',
      scalar: 3.0,
      unit: 'min',
      status: PhysiologyParameterStatus.heuristic,
      note:
          'Immediate-release tablet disintegration and dissolution. Controlled- and extended-release forms are not executable in v0.',
      sourceIds: [],
    ),
    PhysiologyReferenceParameter(
      id: 'levodopa.gut_absorption_half_time_min',
      scalar: 7.4,
      unit: 'min',
      status: PhysiologyParameterStatus.heuristic,
      source:
          'Othman AA, Dutta S. Br J Clin Pharmacol 2014;78:94-105 (DOI 10.1111/bcp.12324): mean absorption time ~25 min for oral levodopa-carbidopa tablets.',
      note:
          'Chosen so fasted gastric residence (half-time 10 min, mean 14.4 min) plus gut absorption (mean 10.7 min) matches the ~25 min mean absorption time.',
      iivSource:
          'Simon N et al. Eur J Clin Pharmacol 2016;72:423-30 (DOI 10.1007/s00228-016-2034-0) report 122% between-subject variability on the absorption rate constant; part of that is carried by the gastric parameters here.',
      iivCv: 0.6,
      sourceIds: [
        'src.othman.levodopa.poppk.2014',
        'src.simon.levodopa.pkpd.2016',
      ],
    ),
    PhysiologyReferenceParameter(
      id: 'levodopa.apparent_clearance_l_per_h',
      scalar: 30.0,
      unit: 'L/h',
      status: PhysiologyParameterStatus.literature,
      source:
          'Within published population estimates: 24.8 L/h (Othman & Dutta 2014, DOI 10.1111/bcp.12324) and 36.6 L/h (Simon et al. 2016, DOI 10.1007/s00228-016-2034-0), with a dopa-decarboxylase inhibitor.',
      iivSource:
          'Simon et al. 2016: 38% between-subject variability on clearance.',
      iivCv: 0.38,
      sourceIds: [
        'src.othman.levodopa.poppk.2014',
        'src.simon.levodopa.pkpd.2016',
      ],
    ),
    PhysiologyReferenceParameter(
      id: 'levodopa.apparent_volume_l',
      scalar: 65.0,
      unit: 'L',
      status: PhysiologyParameterStatus.heuristic,
      source:
          'Contin M, Martinelli P. J Neurol 2010;257 Suppl 2:S253-61 (DOI 10.1007/s00415-010-5728-8) review levodopa\'s very short plasma half-life; with carbidopa it is commonly reported near 1.5 h.',
      note:
          'One-compartment volume chosen so that CL/V gives an elimination half-life of 90 min. Published two-compartment models (Othman & Dutta 2014: Vss 131 L) are the upgrade path.',
      iivCv: 0.25,
      sourceIds: [
        'src.contin.levodopa.pk.2010',
        'src.othman.levodopa.poppk.2014',
      ],
    ),
    PhysiologyReferenceParameter(
      id: 'aa.mixed_protein_composition_g_per_g',
      perAminoAcid: {
        'leu': 0.08,
        'ile': 0.045,
        'val': 0.052,
        'phe': 0.044,
        'tyr': 0.035,
        'trp': 0.011,
        'met': 0.024,
        'his': 0.026,
      },
      unit: 'g amino acid per g protein',
      status: PhysiologyParameterStatus.heuristic,
      note:
          'Default when a food has no amino-acid profile. The six competing LNAAs sum to 0.267, the all-food median of the repository\'s FDC 2025-04-24 SR Legacy calibration (lib/core/constants/lnaa_protein_fraction_calibration_table.dart); the split between amino acids is a typical mixed-protein pattern.',
      sourceIds: ['src.usda.sr_legacy.2018'],
    ),
    PhysiologyReferenceParameter(
      id: 'aa.composition_by_protein_type_g_per_g',
      perAminoAcid: {
        'whey.leu': 0.09225,
        'whey.ile': 0.05574,
        'whey.val': 0.05403,
        'whey.phe': 0.03155,
        'whey.tyr': 0.02814,
        'whey.trp': 0.01589,
        'whey.met': 0.01868,
        'whey.his': 0.01837,
        'casein.leu': 0.10036,
        'casein.ile': 0.05315,
        'casein.val': 0.06727,
        'casein.phe': 0.05189,
        'casein.tyr': 0.05432,
        'casein.trp': 0.01322,
        'casein.met': 0.02419,
        'casein.his': 0.02932,
        'soy.leu': 0.07678,
        'soy.ile': 0.04813,
        'soy.val': 0.04643,
        'soy.phe': 0.05198,
        'soy.tyr': 0.03647,
        'soy.trp': 0.01268,
        'soy.met': 0.0128,
        'soy.his': 0.02605,
        'meat.leu': 0.08954,
        'meat.ile': 0.04888,
        'meat.val': 0.05171,
        'meat.phe': 0.04163,
        'meat.tyr': 0.03894,
        'meat.trp': 0.01184,
        'meat.met': 0.02775,
        'meat.his': 0.03821,
        'egg.leu': 0.08646,
        'egg.ile': 0.05342,
        'egg.val': 0.06831,
        'egg.phe': 0.05414,
        'egg.tyr': 0.03973,
        'egg.trp': 0.0133,
        'egg.met': 0.03025,
        'egg.his': 0.0246,
        'cereal.leu': 0.07452,
        'cereal.ile': 0.03825,
        'cereal.val': 0.05232,
        'cereal.phe': 0.05057,
        'cereal.tyr': 0.03004,
        'cereal.trp': 0.01384,
        'cereal.met': 0.01574,
        'cereal.his': 0.02091,
      },
      unit: 'g amino acid per g protein, keyed protein_type.amino_acid',
      status: PhysiologyParameterStatus.literature,
      source:
          'USDA FoodData Central SR Legacy (release 2025-04-24; public domain): whey FDC 171283 (Whey, sweet, dried); casein FDC 172179 (Cheese, cottage, creamed (casein curd)); soy FDC 174276 (Soy protein isolate); meat FDC 173407 (Beef, loin, top sirloin petite roast, lean, roasted); egg FDC 171287 (Egg, whole, raw, fresh); cereal FDC 173904 (Cereals, oats, regular and quick, dry). FDC 172179, 173407, 171287 and 173904 from tool/data/fdc_2025-04-24/food_nutrient_sr_legacy_subset.csv; FDC 171283 and 174276 from the FDC API.',
      note:
          'Amino-acid pattern used when a component states its protein type but no measured profile; each value is the food\'s amino acid divided by its protein. A measured profile always takes precedence, and \'mixed\' keeps aa.mixed_protein_composition_g_per_g. Cottage-cheese curd stands in for casein (its protein is mostly casein); oats stand in for cereal.',
      sourceIds: [
        'src.usda.fdc.full_download.2025_04_24',
        'src.fdc.api.amino_acid_fields',
      ],
    ),
    PhysiologyReferenceParameter(
      id: 'aa.true_ileal_digestibility_by_protein_type',
      perAminoAcid: {
        'mixed': 0.92,
        'whey': 0.946,
        'casein': 0.946,
        'soy': 0.91,
        'meat': 0.921,
        'egg': 0.909,
        'cereal': 0.903,
      },
      unit: 'fraction of ingested protein absorbed by the end of the ileum',
      status: PhysiologyParameterStatus.literature,
      source:
          'Human 15N ileal-intubation studies: milk protein 94.5-94.8% (Gaudichon C et al. J Nutr 1999;129:890-5, DOI 10.1093/jn/129.4.890); soy protein isolate 91% (Mariotti F et al. J Nutr 1999;129:1992-7, DOI 10.1093/jn/129.11.1992); cooked egg 90.9% (Evenepoel P et al. J Nutr 1998;128:1716-22, DOI 10.1093/jn/128.10.1716); bovine meat 94.1% (55 C, 5 min) and 90.1% (90 C, 30 min) (Oberli M et al. J Nutr 2015;145:2221-8, DOI 10.3945/jn.115.216838); wheat 90.3% (Bos C et al. Am J Clin Nutr 2005;81:87-94, DOI 10.1093/ajcn/81.1.87).',
      note:
          'Protein-level true ileal digestibility applied to every amino acid; the undigested remainder never reaches plasma. Milk protein stands in for whey and casein, the mean of the two cooking conditions for meat, and wheat for cereal. \'mixed\' (0.92) is a heuristic between the plant (~0.90) and animal (~0.92-0.95) values. Per-amino-acid digestibility (Gaudichon 2002 found lower values for several amino acids with soy) is not modeled.',
      sourceIds: [
        'src.gaudichon.milk_protein_ileal.1999',
        'src.mariotti.soy_ileal.1999',
        'src.evenepoel.egg_ileal.1998',
        'src.oberli.meat_ileal.2015',
        'src.bos.wheat_ileal.2005',
      ],
    ),
    PhysiologyReferenceParameter(
      id: 'aa.digestion_half_time_by_protein_type_min',
      perAminoAcid: {
        'mixed': 30.0,
        'whey': 15.0,
        'soy': 20.0,
        'egg': 30.0,
        'casein': 30.0,
        'cereal': 35.0,
        'meat': 40.0,
      },
      unit: 'min',
      status: PhysiologyParameterStatus.heuristic,
      source:
          'Boirie Y et al. PNAS 1997;94:14930-5 (DOI 10.1073/pnas.94.26.14930); Bos C et al. J Nutr 2003;133:1308-15 (DOI 10.1093/jn/133.5.1308): dietary amino acids peaked at 2.5 h after soy vs 3.9 h after milk protein in a mixed meal; Tang JE et al. J Appl Physiol 2009;107:987-92 (DOI 10.1152/japplphysiol.00076.2009): blood leucine rose more after whey hydrolysate than soy or casein; Pennings B et al. Am J Clin Nutr 2013;98:121-8 (DOI 10.3945/ajcn.112.051201): beef protein appears more slowly from steak than from minced beef.',
      note:
          'Digestion and absorption after the duodenum, by protein type (replaces v2\'s single 30 min half-time, kept for \'mixed\'). The order whey < soy < egg = mixed = casein < cereal < meat follows the cited comparisons; magnitudes are illustrative. Casein\'s main slowing comes from gastric coagulation (component form \'coagulating\').',
      iivCv: 0.3,
      sourceIds: [
        'src.boirie.fast_slow_protein.1997',
        'src.bos.soy_milk_kinetics.2003',
        'src.tang.whey_soy_casein.2009',
        'src.pennings.minced_beef.2013',
      ],
    ),
    PhysiologyReferenceParameter(
      id: 'aa.systemic_fraction',
      perAminoAcid: {
        'leu': 0.8,
        'ile': 0.8,
        'val': 0.8,
        'phe': 0.7,
        'tyr': 0.6,
        'trp': 0.6,
        'met': 0.6,
        'his': 0.6,
      },
      unit: 'fraction',
      status: PhysiologyParameterStatus.heuristic,
      source:
          'Matthews DE et al. Am J Physiol 1993;264:E109-18 (DOI 10.1152/ajpendo.1993.264.1.E109): the splanchnic bed sequestered 17-21% of enteral leucine and 29% of enteral phenylalanine on the first pass; Matthews DE et al. Metabolism 1999;48:1555-63 (DOI 10.1016/s0026-0495(99)90245-7): 30.7% for phenylalanine.',
      note:
          'Fraction of absorbed amino acid escaping first-pass splanchnic uptake. Leucine (0.80) and phenylalanine (0.70) follow the cited tracer studies; isoleucine and valine are assumed to behave like leucine, and tyrosine, tryptophan, methionine and histidine keep v2\'s illustrative 0.6. Absorbed into the calibrated plasma volume.',
      sourceIds: ['src.matthews.splanchnic_leu_phe.1993'],
    ),
    PhysiologyReferenceParameter(
      id: 'aa.plasma_distribution_volume_l',
      scalar: 29.3,
      unit: 'L',
      status: PhysiologyParameterStatus.calibrated,
      source:
          'Carter JH et al. Neurology 1989;39:552-6 (DOI 10.1212/wnl.39.4.552): mean plasma LNAA 732 nmol/mL on 1.6 g/kg/day protein and 640 on 0.8 g/kg/day evenly distributed; 542 on 0.8 g/kg/day restricted to the evening meal.',
      note:
          'Fitted to the two evenly distributed diets (closed-form least squares) with the relaxation half-time held at its prior; the evening-restricted diet is the independent check. Absorbs the systemic-fraction and composition heuristics, so it is an effective volume, not a measured one.',
      iivCv: 0.25,
      sourceIds: ['src.carter.protein_redistribution.1989'],
    ),
    PhysiologyReferenceParameter(
      id: 'aa.plasma_relaxation_half_time_min',
      scalar: 60.0,
      unit: 'min',
      status: PhysiologyParameterStatus.heuristic,
      note:
          'Declared prior, set before any fitting: post-meal plasma amino acids return toward fasting within a few hours. Not identifiable from the Carter daily means (any value from 45 to 180 min fits the two even diets equally well), so it is declared rather than fitted.',
      iivCv: 0.25,
      sourceIds: [],
    ),
    PhysiologyReferenceParameter(
      id: 'aa.fasting_plasma_umol_per_l',
      perAminoAcid: {
        'leu': 120.0,
        'ile': 60.0,
        'val': 220.0,
        'phe': 55.0,
        'tyr': 60.0,
        'trp': 50.0,
        'met': 25.0,
        'his': 80.0,
      },
      unit: 'umol/L',
      status: PhysiologyParameterStatus.verify,
      note:
          'Typical adult fasting plasma values (mid reference range). The six competing LNAAs sum to 565 umol/L, close to the 542 nmol/mL Carter et al. reported on a daytime-protein-restricted diet. Replace with a cited reference-range table before promotion.',
      sourceIds: [],
    ),
    PhysiologyReferenceParameter(
      id: 'aa.reference_habitual_protein_g_per_kg_day',
      scalar: 1.0,
      unit: 'g/kg/day',
      status: PhysiologyParameterStatus.heuristic,
      note:
          'Habitual protein intake at which the fasting values apply unchanged; scenarios that state no habitual intake use it.',
      sourceIds: [],
    ),
    PhysiologyReferenceParameter(
      id: 'aa.habitual_fasting_nitrogen_loss_mg_per_kg_day',
      perAminoAcid: {'0.36': 47.0, '0.77': 60.0, '1.59': 95.0, '2.31': 140.0},
      unit: 'mg N/kg/day by habitual protein intake (g/kg/day)',
      status: PhysiologyParameterStatus.literature,
      source:
          'Price GM et al. Clin Sci 1994;86:91-102 (DOI 10.1042/cs0860091): after 12 days on 0.36, 0.77, 1.59 and 2.31 g protein/kg/day, fasting nitrogen losses were 47, 60, 95 and 140 mg/kg/day; fasting amino-acid losses rose with intake ([13C]leucine).',
      note:
          'When a scenario states a habitual intake, the amino-acid relaxation rate is scaled by the fasting nitrogen loss at that intake (linear interpolation) relative to the loss at the reference intake: oxidative disposal adapts to habitual protein. The mapping from nitrogen loss to plasma relaxation is a modeling choice.',
      sourceIds: ['src.price.nitrogen_diurnal_cycling.1994'],
    ),
    PhysiologyReferenceParameter(
      id: 'bbb.km_umol_per_l',
      perAminoAcid: {
        'phe': 11.0,
        'trp': 15.0,
        'leu': 29.0,
        'met': 40.0,
        'ile': 56.0,
        'tyr': 64.0,
        'his': 100.0,
        'val': 210.0,
      },
      unit: 'umol/L',
      status: PhysiologyParameterStatus.verify,
      source:
          'Smith QR et al. J Neurochem 1987;49:1651-8 (DOI 10.1111/j.1471-4159.1987.tb01039.x): complete set of blood-brain-barrier neutral amino acid transport constants (rat, in situ perfusion). Pardridge & Choi 1986 (PMID 3519291) report human brain-capillary phenylalanine Km close to rat values.',
      note:
          'Transcribed values; re-check against the paper\'s table before promotion. Rat, anesthetized; human values may differ, so the set carries a common variability factor.',
      iivCv: 0.3,
      sourceIds: [
        'src.smith.bbb_neutral_amino_acid_kinetics.1987',
        'src.pardridge.bbb_amino_acid_transport.1986',
      ],
    ),
    PhysiologyReferenceParameter(
      id: 'insulin.default_carbohydrate_energy_share',
      scalar: 0.55,
      unit: 'fraction of non-protein energy',
      status: PhysiologyParameterStatus.heuristic,
      note:
          'Carbohydrate share of non-protein energy assumed when a component gives neither carbohydrate nor fat grams (fat supplies the rest). With fat grams, carbohydrate is the energy left after protein and fat.',
      sourceIds: [],
    ),
    PhysiologyReferenceParameter(
      id: 'insulin.carbohydrate_absorption_half_time_min',
      scalar: 15.0,
      unit: 'min',
      status: PhysiologyParameterStatus.heuristic,
      note:
          'Absorption of carbohydrate after it leaves the stomach; gastric emptying is the slower, rate-limiting step for most meals.',
      sourceIds: [],
    ),
    PhysiologyReferenceParameter(
      id: 'insulin.action_half_time_min',
      scalar: 25.0,
      unit: 'min',
      status: PhysiologyParameterStatus.heuristic,
      note:
          'Delay between carbohydrate absorption and insulin action on plasma amino acids. Declared before fitting; Shaham 2008\'s half-maximal amino-acid decline at 50-72 min is then an independent check.',
      sourceIds: [],
    ),
    PhysiologyReferenceParameter(
      id: 'insulin.half_effect_carbohydrate_g_per_min',
      scalar: 0.3,
      unit: 'g/min',
      status: PhysiologyParameterStatus.heuristic,
      note:
          'Carbohydrate absorption rate giving half the maximal insulin effect.',
      sourceIds: [],
    ),
    PhysiologyReferenceParameter(
      id: 'insulin.max_lnaa_target_reduction',
      scalar: 0.8895,
      unit: 'fraction',
      status: PhysiologyParameterStatus.calibrated,
      source:
          'Shaham O et al. Mol Syst Biol 2008;4:214 (DOI 10.1038/msb.2008.50): after 75 g oral glucose in healthy adults, plasma leucine/isoleucine fell 33% over 2 h (amino acids 14-36%), with half-maximal decline at 50-72 min.',
      note:
          'Maximal lowering of the plasma amino-acid relaxation target by insulin action, for a sensitivity of 1. Fitted to the 33% leucine/isoleucine fall at 120 min only.',
      iivSource:
          'Shaham 2008 report the leucine/isoleucine excursion as a marker that differs between individuals with insulin sensitivity; 30% is illustrative.',
      iivCv: 0.3,
      sourceIds: ['src.shaham.glucose_challenge.2008'],
    ),
    PhysiologyReferenceParameter(
      id: 'insulin.lnaa_sensitivity',
      perAminoAcid: {
        'leu': 1.0,
        'ile': 1.0,
        'val': 1.0,
        'phe': 0.5,
        'tyr': 0.5,
        'trp': 0.5,
        'met': 0.5,
        'his': 0.5,
      },
      unit: 'relative',
      status: PhysiologyParameterStatus.heuristic,
      source:
          'Shaham 2008 (DOI 10.1038/msb.2008.50): branched-chain amino acids fell most (33%); amino acids overall 14-36%. Fernstrom JD et al. Am J Clin Nutr 1979;32:1912-22 (DOI 10.1093/ajcn/32.9.1912): a protein-free diet lowered daytime plasma levels of all large neutral amino acids.',
      note:
          'Branched-chain amino acids carry the full insulin effect; the others half of it.',
      sourceIds: [
        'src.shaham.glucose_challenge.2008',
        'src.fernstrom.diurnal_lnaa_protein.1979',
      ],
    ),
  ];

  static PhysiologyReferenceParameter byId(String id) =>
      parameters.firstWhere((parameter) => parameter.id == id);
}
