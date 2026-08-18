import 'amino_acid_profile.dart' show AminoAcidDataMode;
import 'gastric_emptying_profile.dart'
    show MechanisticProviderAvailability, UncertaintyBand;
import 'protein_source.dart';

enum CompetitionBand { none, low, moderate, high, unknown }

/// Exact deterministic classification used by the production competition
/// provider and persisted-wire coherence checks. Invalid inputs remain
/// unknown; this helper verifies implementation identity, not biological risk.
CompetitionBand competitionBandForOverlap(double overlap) {
  if (!overlap.isFinite || overlap < 0 || overlap > 1) {
    return CompetitionBand.unknown;
  }
  if (overlap <= 0) return CompetitionBand.none;
  if (overlap < 0.1) return CompetitionBand.low;
  if (overlap < 0.25) return CompetitionBand.moderate;
  return CompetitionBand.high;
}

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
  /// actual amino-acid fields cover the whole positive-protein meal. Null in
  /// hybrid/proxy/unknown mode (missing ≠ zero — a proxy does not measure
  /// whole-meal grams).
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
  /// present, a contributing profile was unusable, or actual profiles covered
  /// only part of the meal's positive protein. Partial coverage always widens
  /// uncertainty and never exposes a pseudo-precise whole-meal LNAA total.
  final bool partialAminoAcidData;

  /// Fraction of known positive protein grams covered by complete, usable
  /// actual amino-acid profiles. `1` is required for
  /// [AminoAcidDataMode.actualAminoAcidFields]; hybrid mode is strictly between
  /// zero and one. This is a data-coverage trace, not a confidence interval.
  final double? actualAminoAcidProteinCoverageFraction;

  /// Conservative "weakest-wins" FDC provenance tier across the contributing
  /// amino-acid profiles (analytical / calculated / imputedOrAssumed / unknown),
  /// or null when no FDC derivation provenance is available. A weaker-than-
  /// analytical tier widens uncertainty. Educational provenance signal only —
  /// NOT a measurement-uncertainty or clinical-accuracy estimate.
  final String? aminoAcidConfidenceTier;

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
    this.actualAminoAcidProteinCoverageFraction,
    this.aminoAcidConfidenceTier,
  });

  /// Checks that the nested summary matches one of the data paths the
  /// production model can actually emit. This is a wire-integrity contract,
  /// not a claim that the illustrative load factors are biologically valid.
  List<String> get structuralIntegrityReasons {
    final reasons = <String>{};
    if (!effectiveLoadFactor.isFinite ||
        effectiveLoadFactor < 0.5 ||
        effectiveLoadFactor > 1.5) {
      reasons.add('competition.profile_lnaa_load_factor_out_of_domain');
    }

    final numericValues = <double?>[
      competingLnaaGrams,
      competingLnaaGramsPerServing,
      doseRelativeLnaaRatio,
    ];
    if (numericValues.whereType<double>().any(
      (value) => !value.isFinite || value < 0,
    )) {
      reasons.add('competition.profile_lnaa_numeric_invalid');
    }
    final coverage = actualAminoAcidProteinCoverageFraction;
    if (coverage != null &&
        (!coverage.isFinite || coverage < 0 || coverage > 1)) {
      reasons.add('competition.profile_lnaa_coverage_invalid');
    }
    if (doseRelativeAvailable != (doseRelativeLnaaRatio != null)) {
      reasons.add('competition.profile_lnaa_dose_relative_inconsistent');
    }

    final hasAbsoluteValues =
        competingLnaaGrams != null ||
        competingLnaaGramsPerServing != null ||
        doseRelativeLnaaRatio != null ||
        doseRelativeAvailable;
    switch (dataMode) {
      case AminoAcidDataMode.actualAminoAcidFields:
        if (coverage == null || (coverage - 1).abs() > 1e-12) {
          reasons.add('competition.profile_lnaa_actual_coverage_invalid');
        }
        if (partialAminoAcidData || competingLnaaGrams == null) {
          reasons.add('competition.profile_lnaa_actual_shape_invalid');
        }
        if (sourcesPresent.isNotEmpty) {
          reasons.add('competition.profile_lnaa_actual_proxy_sources_present');
        }
      case AminoAcidDataMode.hybridActualAndProteinSourceProxy:
        if (coverage == null || coverage <= 0 || coverage >= 1) {
          reasons.add('competition.profile_lnaa_hybrid_coverage_invalid');
        }
        if (!partialAminoAcidData ||
            !uncertaintyWidened ||
            hasAbsoluteValues ||
            aminoAcidConfidenceTier != null ||
            sourcesPresent.isEmpty) {
          reasons.add('competition.profile_lnaa_hybrid_shape_invalid');
        }
      case AminoAcidDataMode.proteinSourceProxy:
        if (coverage == null || coverage.abs() > 1e-12) {
          reasons.add('competition.profile_lnaa_proxy_coverage_invalid');
        }
        if (hasAbsoluteValues ||
            aminoAcidNutrientIds.isNotEmpty ||
            aminoAcidConfidenceTier != null) {
          reasons.add('competition.profile_lnaa_proxy_shape_invalid');
        }
      case AminoAcidDataMode.unknown:
        final exactUnknownSources =
            sourcesPresent.length == 1 &&
            sourcesPresent.single == ProteinSourceType.unknown;
        if ((effectiveLoadFactor - 1).abs() > 1e-12 ||
            !uncertaintyWidened ||
            partialAminoAcidData ||
            coverage != null ||
            hasAbsoluteValues ||
            aminoAcidNutrientIds.isNotEmpty ||
            aminoAcidConfidenceTier != null ||
            !exactUnknownSources) {
          reasons.add('competition.profile_lnaa_unknown_shape_invalid');
        }
    }
    return List.unmodifiable(reasons);
  }

  Map<String, dynamic> toJson() => {
    'effective_load_factor': effectiveLoadFactor,
    'sources_present': sourcesPresent
        .map((s) => s.name)
        .toList(growable: false),
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
    'actual_amino_acid_protein_coverage_fraction':
        actualAminoAcidProteinCoverageFraction,
    'amino_acid_confidence_tier': aminoAcidConfidenceTier,
  };
}

/// Discretized competition-pressure timeline. A single sample is the
/// model's estimate of relative amino-acid presence at the absorption
/// site at a given minute.
class CompetitionPressureSample {
  final int minute;
  final double pressure; // 0..1, unitless educational proxy

  const CompetitionPressureSample({
    required this.minute,
    required this.pressure,
  });

  Map<String, dynamic> toJson() => {'minute': minute, 'pressure': pressure};
}

/// Educational proxy for amino-acid competition pressure with levodopa
/// transport. NOT a pharmacokinetic prediction.
class CompetitionPressureTimeline {
  /// Explicit four-state provider output contract. Legacy numeric sentinels
  /// remain in memory for source compatibility but are serialized as null,
  /// never as modeled zeroes, for every abstention state.
  final MechanisticProviderAvailability _declaredAvailability;
  final List<String> applicabilityReasons;
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
    MechanisticProviderAvailability availability =
        MechanisticProviderAvailability.available,
    this.applicabilityReasons = const [],
    required this.samples,
    required this.peakMinute,
    required this.peakPressure,
    required this.overlapWithAbsorptionWindow,
    required this.competitionBand,
    required this.uncertaintyBand,
    required this.assumptions,
    required this.sourceRefs,
    this.lnaaSummary,
  }) : _declaredAvailability = availability;

  /// A declared available state is executable only when the sampled curve,
  /// peak, overlap, and nested LNAA numerics are structurally coherent.
  MechanisticProviderAvailability get availability {
    if (_declaredAvailability == MechanisticProviderAvailability.available &&
        structuralIntegrityReasons.isNotEmpty) {
      return MechanisticProviderAvailability.blockedIntegrity;
    }
    return _declaredAvailability;
  }

  List<String> get effectiveApplicabilityReasons => List.unmodifiable({
    ...applicabilityReasons,
    if (_declaredAvailability == MechanisticProviderAvailability.available)
      ...structuralIntegrityReasons,
  });

  List<String> get structuralIntegrityReasons {
    final reasons = <String>{};
    if (samples.isEmpty) {
      reasons.add('competition.profile_samples_empty');
    }
    if (!peakPressure.isFinite) {
      reasons.add('competition.profile_peak_nonfinite');
    } else if (peakPressure < 0 || peakPressure > 1) {
      reasons.add('competition.profile_peak_out_of_range');
    }
    if (!overlapWithAbsorptionWindow.isFinite) {
      reasons.add('competition.profile_overlap_nonfinite');
    } else if (overlapWithAbsorptionWindow < 0 ||
        overlapWithAbsorptionWindow > 1) {
      reasons.add('competition.profile_overlap_out_of_range');
    }
    if (competitionBand == CompetitionBand.unknown) {
      reasons.add('competition.profile_band_unknown');
    } else if (competitionBand !=
        competitionBandForOverlap(overlapWithAbsorptionWindow)) {
      reasons.add('competition.profile_band_overlap_inconsistent');
    }

    int? previousMinute;
    var maximumPressure = double.negativeInfinity;
    for (final sample in samples) {
      if (!sample.pressure.isFinite) {
        reasons.add('competition.profile_pressure_nonfinite');
      } else {
        if (sample.pressure < 0 || sample.pressure > 1) {
          reasons.add('competition.profile_pressure_out_of_range');
        }
        if (sample.pressure > maximumPressure) {
          maximumPressure = sample.pressure;
        }
      }
      if (previousMinute != null) {
        if (sample.minute == previousMinute) {
          reasons.add('competition.profile_sample_minute_duplicate');
        } else if (sample.minute < previousMinute) {
          reasons.add('competition.profile_sample_minutes_nonmonotonic');
        }
      }
      previousMinute = sample.minute;
    }
    if (samples.isNotEmpty &&
        (!maximumPressure.isFinite ||
            (peakPressure - maximumPressure).abs() > 1e-12 ||
            !samples.any(
              (sample) =>
                  sample.minute == peakMinute &&
                  sample.pressure.isFinite &&
                  (sample.pressure - peakPressure).abs() <= 1e-12,
            ))) {
      reasons.add('competition.profile_peak_inconsistent');
    }
    final summary = lnaaSummary;
    if (summary == null) {
      reasons.add('competition.profile_lnaa_summary_missing');
    } else {
      reasons.addAll(summary.structuralIntegrityReasons);
      if (summary.dataMode == AminoAcidDataMode.unknown &&
          (peakPressure.abs() > 1e-12 ||
              overlapWithAbsorptionWindow.abs() > 1e-12 ||
              samples.any((sample) => sample.pressure.abs() > 1e-12))) {
        reasons.add('competition.profile_lnaa_unknown_nonzero_output');
      }
    }
    return List.unmodifiable(reasons);
  }

  bool get modelApplicable =>
      availability == MechanisticProviderAvailability.available;

  bool get hasModeledOutput => modelApplicable;

  Map<String, dynamic> toJson() => {
    'result_availability': availability.name,
    'has_modeled_output': hasModeledOutput,
    'model_applicable': modelApplicable,
    'applicability_reasons': effectiveApplicabilityReasons,
    'samples': modelApplicable
        ? samples.map((e) => e.toJson()).toList(growable: false)
        : const <Map<String, dynamic>>[],
    'peak_minute': modelApplicable ? peakMinute : null,
    'peak_pressure': modelApplicable ? peakPressure : null,
    'overlap_with_absorption_window': modelApplicable
        ? overlapWithAbsorptionWindow
        : null,
    'competition_band': competitionBand.name,
    'uncertainty_band': uncertaintyBand.name,
    'assumptions': assumptions,
    'source_refs': sourceRefs,
    'lnaa_summary': modelApplicable ? lnaaSummary?.toJson() : null,
  };
}
