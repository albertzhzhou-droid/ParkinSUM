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

  /// Absolute competing LNAA grams summed across the meal's components, when
  /// actual amino-acid fields are present. Null in proxy/unknown mode
  /// (missing ≠ zero — the proxy does not measure grams).
  final double? competingLnaaGrams;

  /// Competing LNAA grams expressed per gram of the meal serving, when both
  /// the actual grams and total portion mass are known. Null otherwise.
  final double? competingLnaaGramsPerServing;

  /// Competing LNAA grams relative to the user-entered levodopa dose
  /// (g LNAA per 100 mg levodopa). Populated ONLY when actual LNAA grams AND
  /// an explicit user-entered dose are both available — never with an invented
  /// dose. Null when [doseRelativeAvailable] is false.
  final double? doseRelativeLnaaRatio;

  /// True only when an explicit levodopa dose was supplied AND actual LNAA
  /// grams were computed, so the dose-relative ratio is meaningful.
  final bool doseRelativeAvailable;

  /// True when some — but not all — of the six competing LNAA fields are
  /// present (or a contributing profile was unit-ambiguous). Partial actual
  /// data widens uncertainty rather than being trusted as fully narrow.
  final bool partialAminoAcidData;

  const CompetitionLnaaSummary({
    required this.effectiveLoadFactor,
    required this.sourcesPresent,
    required this.isPrototypeHeuristic,
    required this.uncertaintyWidened,
    required this.sourceRefs,
    this.dataMode = AminoAcidDataMode.proteinSourceProxy,
    this.aminoAcidNutrientIds = const [],
    this.competingLnaaGrams,
    this.competingLnaaGramsPerServing,
    this.doseRelativeLnaaRatio,
    this.doseRelativeAvailable = false,
    this.partialAminoAcidData = false,
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
        'competing_lnaa_grams': competingLnaaGrams,
        'competing_lnaa_grams_per_serving': competingLnaaGramsPerServing,
        'dose_relative_lnaa_ratio': doseRelativeLnaaRatio,
        'dose_relative_available': doseRelativeAvailable,
        'partial_amino_acid_data': partialAminoAcidData,
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
