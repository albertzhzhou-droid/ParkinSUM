import 'gastric_emptying_profile.dart' show UncertaintyBand;

enum CompetitionBand { none, low, moderate, high, unknown }

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

  const CompetitionPressureTimeline({
    required this.samples,
    required this.peakMinute,
    required this.peakPressure,
    required this.overlapWithAbsorptionWindow,
    required this.competitionBand,
    required this.uncertaintyBand,
    required this.assumptions,
    required this.sourceRefs,
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
      };
}
