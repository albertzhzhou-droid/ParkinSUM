/// Parameter set of the physiology reference model (Stage B Dart port).
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

/// One parameter: a scalar or one value per amino acid, never both.
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
  static const String parameterSetId = 'physiology_reference_v2_prototype';
  static const String parameterSetVersion = '2026.10.20-v0';
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
      id: 'aa.digestion_absorption_half_time_min',
      scalar: 30.0,
      unit: 'min',
      status: PhysiologyParameterStatus.heuristic,
      note:
          'Digestion and absorption after the duodenum. Fast versus slow proteins differ mainly through gastric behaviour (Boirie Y et al. PNAS 1997;94:14930-5, DOI 10.1073/pnas.94.26.14930), which the stomach model carries.',
      iivCv: 0.3,
      sourceIds: ['src.boirie.fast_slow_protein.1997'],
    ),
    PhysiologyReferenceParameter(
      id: 'aa.systemic_fraction',
      perAminoAcid: {
        'leu': 0.75,
        'ile': 0.75,
        'val': 0.75,
        'phe': 0.6,
        'tyr': 0.6,
        'trp': 0.6,
        'met': 0.6,
        'his': 0.6,
      },
      unit: 'fraction',
      status: PhysiologyParameterStatus.heuristic,
      note:
          'Fraction of absorbed amino acid escaping first-pass splanchnic uptake. Branched-chain amino acids are extracted less by the liver than aromatic ones; magnitudes are illustrative and absorbed into the calibrated plasma volume.',
      sourceIds: [],
    ),
    PhysiologyReferenceParameter(
      id: 'aa.plasma_distribution_volume_l',
      scalar: 73.9,
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
  ];

  static PhysiologyReferenceParameter byId(String id) =>
      parameters.firstWhere((parameter) => parameter.id == id);
}
