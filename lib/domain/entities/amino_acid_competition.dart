import 'amino_acid_profile.dart' show AminoAcidDataMode;
import 'gastric_emptying_profile.dart' show UncertaintyBand;
import 'protein_source.dart';

enum CompetitionBand { none, low, moderate, high, unknown }

/// LNAA summary attached to the competition timeline so reviewers can see
/// which protein-source assumptions modulated the proxy. Educational only.
class CompetitionLnaaSummary {
  final double effectiveLoadFactor;
  final List<ProteinSourceType> sourcesPresent;
  final bool isPrototypeHeuristic;
  final bool uncertaintyWidened;
  final List<String> sourceRefs;

  /// Which data path produced the LNAA load.
  final AminoAcidDataMode dataMode;

  /// Upstream amino-acid nutrient ids when actual fields were used.
  final List<String> aminoAcidNutrientIds;

  const CompetitionLnaaSummary({
    required this.effectiveLoadFactor,
    required this.sourcesPresent,
    required this.isPrototypeHeuristic,
    required this.uncertaintyWidened,
    required this.sourceRefs,
    this.dataMode = AminoAcidDataMode.proteinSourceProxy,
    this.aminoAcidNutrientIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'effective_load_factor': effectiveLoadFactor,
        'sources_present':
            sourcesPresent.map((s) => s.name).toList(growable: false),
        'is_prototype_heuristic': isPrototypeHeuristic,
        'uncertainty_widened': uncertaintyWidened,
        'source_refs': sourceRefs,
        'data_mode': dataMode.name,
        'amino_acid_nutrient_ids': aminoAcidNutrientIds,
      };
}

/// Discretized competition-pressure timeline. A single sample is the
/// model's estimate of relative amino-acid presence at the absorption
/// site at a given minute.
class CompetitionPressureSample {
  final int minute;
  final double pressure; // 0..1, unitless educational proxy

  const CompetitionPressureSample(
      {required this.minute, required this.pressure});

  Map<String, dynamic> toJson() => {'minute': minute, 'pressure': pressure};
}

/// Educational proxy for amino-acid competition pressure with levodopa
/// transport. NOT a pharmacokinetic prediction.
class CompetitionPressureTimeline {
  final List<CompetitionPressureSample> samples;
  final int peakMinute;
  final double peakPressure;
  final double overlapWithAbsorptionWindow; // 0..1 integral
  final CompetitionBand competitionBand;
  final UncertaintyBand uncertaintyBand;
  final List<String> assumptions;
  final List<String> sourceRefs;
  final CompetitionLnaaSummary? lnaaSummary;

  const CompetitionPressureTimeline({
    required this.samples,
    required this.peakMinute,
    required this.peakPressure,
    required this.overlapWithAbsorptionWindow,
    required this.competitionBand,
    required this.uncertaintyBand,
    required this.assumptions,
    required this.sourceRefs,
    this.lnaaSummary,
  });

  Map<String, dynamic> toJson() => {
        'samples': samples.map((e) => e.toJson()).toList(growable: false),
        'peak_minute': peakMinute,
        'peak_pressure': peakPressure,
        'overlap_with_absorption_window': overlapWithAbsorptionWindow,
        'competition_band': competitionBand.name,
        'uncertainty_band': uncertaintyBand.name,
        'assumptions': assumptions,
        'source_refs': sourceRefs,
        'lnaa_summary': lnaaSummary?.toJson(),
      };
}
