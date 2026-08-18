import '../entities/absorption_opportunity.dart';
import '../entities/algorithm_component_identity_witness.dart';
import '../entities/amino_acid_competition.dart';
import '../entities/amino_acid_profile.dart';
import '../entities/nutrient_derivation.dart';
import '../entities/gastric_emptying_profile.dart';
import '../entities/meal_composition.dart';
import '../entities/protein_source.dart';
import '../entities/time_axis_events.dart';

/// Educational proxy for amino-acid competition pressure timeline.
///
/// Approach:
///   1. Pressure peaks where the gastric emptying profile is releasing the
///      most protein into the small intestine (i.e. roughly during the
///      meal's peak emptying window).
///   2. Pressure amplitude scales with total protein grams (relative to a
///      moderate reference of ~20 g) and is multiplied by an effective
///      LNAA load factor that depends on protein-source type
///      (`ProteinSourceType` per food component).
///   3. The competition score is the overlap of this pressure timeline
///      with the absorption opportunity window.
///   4. If protein data are missing, return `unknown` band with widened
///      uncertainty. If protein-source data are missing, the load factor
///      defaults to `unknown` (1.0) and the uncertainty band widens by
///      one step.
class AminoAcidCompetitionModel with RegisteredAlgorithmComponentIdentity {
  static const double referenceProteinG = 20.0;
  static const int sampleStrideMinutes = 5;

  static const List<String> _baseSourceRefs = [
    'src.nutt.lnaa.1989',
    'src.nutt.onoff.1984',
    'src.npj.peripheral.resistance.2022',
    'src.cereda.protein.2017',
    'src.advances.nutrition.2021',
    'src.lnaa.plantvanimal.2023',
    'src.internal.prototype.heuristic',
  ];

  CompetitionPressureTimeline build({
    required MealComposition mealComposition,
    required GastricEmptyingProfile mealEmptyingProfile,
    required AbsorptionOpportunityWindow absorptionWindow,
    required int mealStartMinute,

    /// Explicit user-entered levodopa dose in mg, when available. Used ONLY to
    /// compute the dose-relative LNAA ratio; never invented or defaulted. Null
    /// (or non-positive) leaves the dose-relative proxy unavailable.
    double? levodopaDoseMg,
  }) {
    final assumptions = <String>[
      // The modeled value is a unitless timing-overlap proxy.
      // Broader blood–brain-barrier LNAA transport competition is a cited
      // mechanism but is NOT quantified here.
      'ldopa.protein.lnaa_competition_intestinal_absorption',
      'ldopa.protein.lnaa_bbb_transport_competition_not_quantified',
    ];

    if (!absorptionWindow.modelApplicable ||
        !mealEmptyingProfile.modelApplicable) {
      final reasons = List<String>.unmodifiable(<String>{
        if (!absorptionWindow.modelApplicable) ...[
          'competition.absorption_opportunity_not_applicable',
          ...absorptionWindow.effectiveApplicabilityReasons,
        ],
        if (!mealEmptyingProfile.modelApplicable) ...[
          'competition.gastric_emptying_not_applicable',
          ...mealEmptyingProfile.effectiveApplicabilityReasons,
        ],
      });
      return CompetitionPressureTimeline(
        availability: _mergeUpstreamAvailability(
          absorptionWindow.availability,
          mealEmptyingProfile.availability,
        ),
        applicabilityReasons: reasons,
        samples: const [],
        peakMinute: absorptionWindow.window.startMinute,
        peakPressure: 0,
        overlapWithAbsorptionWindow: 0,
        competitionBand: CompetitionBand.unknown,
        uncertaintyBand: UncertaintyBand.veryWide,
        assumptions: List.unmodifiable([
          ...assumptions,
          'aa.competition.model_not_applicable',
        ]),
        sourceRefs: _baseSourceRefs,
      );
    }

    final opennessIntegrityReasons = _opennessIntegrityReasons(
      absorptionWindow,
    );
    if (opennessIntegrityReasons.isNotEmpty) {
      return CompetitionPressureTimeline(
        availability: MechanisticProviderAvailability.blockedIntegrity,
        applicabilityReasons: opennessIntegrityReasons,
        samples: const [],
        peakMinute: absorptionWindow.window.startMinute,
        peakPressure: 0,
        overlapWithAbsorptionWindow: 0,
        competitionBand: CompetitionBand.unknown,
        uncertaintyBand: UncertaintyBand.veryWide,
        assumptions: List.unmodifiable([
          ...assumptions,
          'aa.competition.absorption_openness_integrity_blocked',
        ]),
        sourceRefs: _baseSourceRefs,
      );
    }

    if (mealComposition.proteinGrams == null) {
      return CompetitionPressureTimeline(
        availability: MechanisticProviderAvailability.insufficient,
        applicabilityReasons: const ['competition.protein_grams_missing'],
        samples: const [],
        peakMinute: mealEmptyingProfile.peakEmptyingWindow.startMinute,
        peakPressure: 0,
        overlapWithAbsorptionWindow: 0,
        competitionBand: CompetitionBand.unknown,
        uncertaintyBand: UncertaintyBand.veryWide,
        assumptions: List.unmodifiable([
          ...assumptions,
          'protein_grams_missing',
        ]),
        sourceRefs: _baseSourceRefs,
        lnaaSummary: const CompetitionLnaaSummary(
          effectiveLoadFactor: 1.0,
          sourcesPresent: [],
          isPrototypeHeuristic: true,
          uncertaintyWidened: true,
          sourceRefs: _baseSourceRefs,
          dataMode: AminoAcidDataMode.unknown,
        ),
      );
    }

    final lnaa = _computeLnaaLoad(mealComposition, levodopaDoseMg);
    assumptions.add(switch (lnaa.dataMode) {
      AminoAcidDataMode.actualAminoAcidFields =>
        'aa.lnaa.actual_fields_complete_protein_coverage '
            '(effective ${lnaa.effectiveLoadFactor.toStringAsFixed(2)})',
      AminoAcidDataMode.hybridActualAndProteinSourceProxy =>
        'aa.lnaa.hybrid_actual_and_protein_source_proxy '
            '(effective ${lnaa.effectiveLoadFactor.toStringAsFixed(2)})',
      AminoAcidDataMode.proteinSourceProxy =>
        'aa.lnaa.source_type_load_factor '
            '(effective ${lnaa.effectiveLoadFactor.toStringAsFixed(2)})',
      AminoAcidDataMode.unknown =>
        'aa.lnaa.unknown_load_factor '
            '(effective ${lnaa.effectiveLoadFactor.toStringAsFixed(2)})',
    });
    if (lnaa.uncertaintyWidened) {
      assumptions.add('aa.lnaa.unknown_source_widened_uncertainty');
    }
    if (lnaa.partialAminoAcidData) {
      assumptions.add(
        'aa.lnaa.partial_amino_acid_coverage_widened_uncertainty',
      );
    }
    if (lnaa.dataMode == AminoAcidDataMode.hybridActualAndProteinSourceProxy) {
      assumptions.add(
        'aa.lnaa.hybrid_whole_meal_absolute_and_dose_relative_unavailable',
      );
    }
    final tier = lnaa.aminoAcidConfidenceTier;
    if (tier != null) {
      assumptions.add('aa.lnaa.fdc_nutrient_confidence_tier ($tier)');
      if (tier != 'analytical') {
        assumptions.add(
          'aa.lnaa.non_analytical_provenance_widened_uncertainty',
        );
      }
    }
    if (lnaa.dataMode == AminoAcidDataMode.actualAminoAcidFields) {
      if (lnaa.doseRelativeAvailable) {
        assumptions.add('aa.lnaa.dose_relative_ratio_from_user_entered_dose');
      } else {
        assumptions.add('lnaa.dose_relative_unavailable_no_explicit_dose');
      }
    }

    final proteinAmplitudeBase =
        (mealComposition.proteinGrams! / referenceProteinG).clamp(0.0, 2.0);
    final proteinAmplitude = (proteinAmplitudeBase * lnaa.effectiveLoadFactor)
        .clamp(0.0, 2.0);

    final startMin = mealStartMinute;
    final endMin = mealEmptyingProfile.mostlyEmptiedWindow.endMinute;
    final arrivalSamples = <({int minute, double rate})>[];
    var peakArrivalRate = 0.0;
    for (var t = startMin; t <= endMin; t += sampleStrideMinutes) {
      final rate = mealEmptyingProfile.intestinalArrivalRateAt(
        t - mealStartMinute,
      );
      arrivalSamples.add((minute: t, rate: rate));
      if (rate > peakArrivalRate) peakArrivalRate = rate;
    }

    // `intestinalArrivalRateAt` is a fraction-per-minute (typically a small
    // number such as 0.005). Comparing it directly with 0..1 competition-band
    // thresholds made the pressure scale effectively degenerate. Preserve its
    // evidence-informed *shape*, normalize that shape to its own peak, then
    // apply the bounded protein/LNAA load amplitude. The result is an explicit
    // unitless relative pressure, not concentration or transport probability.
    final loadAmplitude = (proteinAmplitude / 2.0).clamp(0.0, 1.0);
    assumptions.add('aa.competition.arrival_shape_peak_normalized');
    assumptions.add('aa.competition.load_amplitude_bounded_0_1');

    final samples = <CompetitionPressureSample>[];
    var peakMinute = startMin;
    var peakPressure = 0.0;

    for (final arrival in arrivalSamples) {
      final relativeArrival = peakArrivalRate <= 0
          ? 0.0
          : arrival.rate / peakArrivalRate;
      final pressure = (relativeArrival * loadAmplitude).clamp(0.0, 1.0);
      samples.add(
        CompetitionPressureSample(minute: arrival.minute, pressure: pressure),
      );
      if (pressure > peakPressure) {
        peakPressure = pressure;
        peakMinute = arrival.minute;
      }
    }

    // Overlap integral: competition pressure weighted by the COMPLETE
    // absorption-opportunity grid (Σ pressure·openness / Σ openness).
    // Pressure is deterministically linearly interpolated within its sampled
    // support and is exactly zero outside that support. Including every
    // absorption-grid point in the denominator makes a short intersection
    // score lower than otherwise identical pressure spanning the full window;
    // it is not a conditional mean over intersection-only samples. An
    // available upstream result without a structurally valid openness curve
    // is blocked above; no flat profile is invented. Result is unitless [0,1].
    var weightedSum = 0.0;
    var weightTotal = 0.0;
    for (final minute in _completeWindowGrid(absorptionWindow.window)) {
      final weight = absorptionWindow.opennessAt(minute);
      if (weight <= 0) continue;
      weightedSum += _pressureAt(samples, minute) * weight;
      weightTotal += weight;
    }
    final overlap = weightTotal == 0 ? 0.0 : weightedSum / weightTotal;
    assumptions.add('ldopa.absorption.openness_weighted_overlap');
    assumptions.add('aa.competition.outside_pressure_support_zero');

    final band = _toBand(overlap);
    final uncertainty = _toUncertainty(
      compositionCompleteness: mealComposition.compositionCompleteness,
      emptyingUncertainty: mealEmptyingProfile.uncertaintyBand,
      lnaaUncertaintyWidened: lnaa.uncertaintyWidened,
    );

    if (mealComposition.compositionCompleteness < 0.7) {
      assumptions.add('competition.uncertainty_widened_by_meal_incompleteness');
    }

    return CompetitionPressureTimeline(
      samples: List.unmodifiable(samples),
      peakMinute: peakMinute,
      peakPressure: peakPressure,
      overlapWithAbsorptionWindow: overlap,
      competitionBand: band,
      uncertaintyBand: uncertainty,
      assumptions: List.unmodifiable(assumptions),
      sourceRefs: _baseSourceRefs,
      lnaaSummary: lnaa,
    );
  }

  MechanisticProviderAvailability _mergeUpstreamAvailability(
    MechanisticProviderAvailability absorption,
    MechanisticProviderAvailability gastric,
  ) {
    final values = {absorption, gastric};
    if (values.contains(MechanisticProviderAvailability.blockedIntegrity)) {
      return MechanisticProviderAvailability.blockedIntegrity;
    }
    if (values.contains(MechanisticProviderAvailability.notApplicable)) {
      return MechanisticProviderAvailability.notApplicable;
    }
    return MechanisticProviderAvailability.insufficient;
  }

  List<String> _opennessIntegrityReasons(
    AbsorptionOpportunityWindow absorptionWindow,
  ) {
    final profile = absorptionWindow.opennessProfile;
    if (profile.isEmpty) {
      return const ['competition.absorption_openness_profile_empty'];
    }

    final reasons = <String>{};
    int? previousMinute;
    for (final sample in profile) {
      if (!sample.openness.isFinite) {
        reasons.add('competition.absorption_openness_nonfinite');
      } else if (sample.openness < 0 || sample.openness > 1) {
        reasons.add('competition.absorption_openness_out_of_range');
      }
      if (sample.minute < absorptionWindow.window.startMinute ||
          sample.minute > absorptionWindow.window.endMinute) {
        reasons.add('competition.absorption_openness_outside_window');
      }
      if (previousMinute != null) {
        if (sample.minute == previousMinute) {
          reasons.add('competition.absorption_openness_duplicate_minute');
        } else if (sample.minute < previousMinute) {
          reasons.add('competition.absorption_openness_non_monotonic_minutes');
        }
      }
      previousMinute = sample.minute;
    }
    if (profile.first.minute != absorptionWindow.window.startMinute ||
        profile.last.minute != absorptionWindow.window.endMinute) {
      reasons.add('competition.absorption_openness_incomplete_window_coverage');
    }
    return List.unmodifiable(reasons);
  }

  Iterable<int> _completeWindowGrid(TimelineWindow window) sync* {
    for (
      var minute = window.startMinute;
      minute <= window.endMinute;
      minute += sampleStrideMinutes
    ) {
      yield minute;
    }
    if ((window.endMinute - window.startMinute) % sampleStrideMinutes != 0) {
      yield window.endMinute;
    }
  }

  double _pressureAt(List<CompetitionPressureSample> samples, int minute) {
    if (samples.isEmpty ||
        minute < samples.first.minute ||
        minute > samples.last.minute) {
      return 0.0;
    }
    if (minute == samples.first.minute) return samples.first.pressure;
    for (var index = 0; index < samples.length - 1; index++) {
      final left = samples[index];
      final right = samples[index + 1];
      if (minute == right.minute) return right.pressure;
      if (minute > left.minute && minute < right.minute) {
        final fraction = (minute - left.minute) / (right.minute - left.minute);
        return left.pressure + fraction * (right.pressure - left.pressure);
      }
    }
    return 0.0;
  }

  /// Returns a `CompetitionLnaaSummary`. Pure actual mode requires complete,
  /// usable amino-acid fields for every positive-protein component. Partial
  /// meal coverage is an explicit hybrid: covered components use actual fields
  /// and every uncovered component uses its declared protein-source proxy.
  /// Whole-meal absolute and dose-relative LNAA values stay unavailable in
  /// hybrid mode because they were not measured for the whole meal.
  CompetitionLnaaSummary _computeLnaaLoad(
    MealComposition composition,
    double? levodopaDoseMg,
  ) {
    final components = composition.foodComponents;
    final proteinComponents = components
        .where((component) {
          final protein = component.proteinGrams;
          return protein != null && protein.isFinite && protein > 0;
        })
        .toList(growable: false);
    if (proteinComponents.isEmpty) {
      final unknown = ProteinSourceLnaaRegistry.factorFor(
        ProteinSourceType.unknown,
      );
      return CompetitionLnaaSummary(
        effectiveLoadFactor: unknown.loadFactor,
        sourcesPresent: const [ProteinSourceType.unknown],
        isPrototypeHeuristic: true,
        uncertaintyWidened: true,
        sourceRefs: unknown.sourceRefs,
        dataMode: AminoAcidDataMode.unknown,
        actualAminoAcidProteinCoverageFraction: null,
      );
    }

    final completeProfiles = <FoodComponent, AminoAcidProfile>{};
    var unusableProfileSeen = false;
    for (final component in proteinComponents) {
      final profile = _completeServingProfile(component);
      if (profile != null) {
        completeProfiles[component] = profile;
      } else if (component.aminoAcidProfile != null) {
        unusableProfileSeen = true;
      }
    }

    if (completeProfiles.isNotEmpty) {
      const referenceLnaaFractionOfProtein = 0.45;
      var totalProtein = 0.0;
      var weighted = 0.0;
      var totalCompetingLnaaGrams = 0.0;
      var actualProteinGrams = 0.0;
      var totalServingGrams = 0.0;
      var allHavePortion = true;
      final ids = <String>{};
      final refs = <String>{'src.fdc.api.amino_acid_fields'};
      final proxySources = <ProteinSourceType>{};
      NutrientConfidenceTier? aggregateTier;

      for (final c in proteinComponents) {
        final p = c.proteinGrams!;
        totalProtein += p;
        final profile = completeProfiles[c];
        if (profile != null) {
          final lnaa = profile.competingLnaaGrams!;
          final fraction = (lnaa / p).clamp(0.0, 1.0);
          final factor = (fraction / referenceLnaaFractionOfProtein).clamp(
            0.5,
            1.5,
          );
          actualProteinGrams += p;
          weighted += p * factor;
          totalCompetingLnaaGrams += lnaa;
          if (c.portionGrams != null) {
            totalServingGrams += c.portionGrams!;
          } else {
            allHavePortion = false;
          }
          ids.addAll(profile.nutrientIds);
          refs.addAll(profile.sourceRefs);

          final tier = profile.aggregateConfidenceTier;
          if (tier != null &&
              (aggregateTier == null ||
                  nutrientConfidenceRank(tier) >
                      nutrientConfidenceRank(aggregateTier))) {
            aggregateTier = tier;
          }
        } else {
          final proxy = ProteinSourceLnaaRegistry.factorFor(c.proteinSource);
          weighted += p * proxy.loadFactor;
          proxySources.add(c.proteinSource);
          refs.addAll(proxy.sourceRefs);
        }
      }
      final effective = weighted / totalProtein;
      final coverage = actualProteinGrams / totalProtein;
      final pureActual = completeProfiles.length == proteinComponents.length;

      // FDC nutrient provenance: weakest-wins confidence tier across the
      // contributing profiles. A weaker-than-analytical tier (calculated /
      // imputed / unknown) widens uncertainty — exactly like partial data — so
      // calculated/imputed nutrient values are never treated as fully narrow.
      final tierWidens =
          aggregateTier != null && tierWidensUncertainty(aggregateTier);
      if (aggregateTier != null) {
        refs.add('src.usda.fdc.foundation_docs');
      }

      // Dose-relative ratio (g competing LNAA per 100 mg levodopa) is available
      // only when actual fields cover the whole meal and an explicit dose was
      // entered. Hybrid totals are deliberately null rather than pretending
      // the proxy measured amino-acid grams.
      final doseAvailable =
          pureActual && levodopaDoseMg != null && levodopaDoseMg > 0;
      final doseRelative = doseAvailable
          ? totalCompetingLnaaGrams / (levodopaDoseMg / 100.0)
          : null;

      return CompetitionLnaaSummary(
        effectiveLoadFactor: effective,
        sourcesPresent: pureActual
            ? const []
            : proxySources.toList(growable: false),
        isPrototypeHeuristic: true,
        // Hybrid coverage always widens structural uncertainty by at least one
        // band; weak nutrient derivation provenance also widens pure actual.
        uncertaintyWidened: !pureActual || tierWidens,
        sourceRefs: refs.toList(growable: false),
        dataMode: pureActual
            ? AminoAcidDataMode.actualAminoAcidFields
            : AminoAcidDataMode.hybridActualAndProteinSourceProxy,
        aminoAcidNutrientIds: ids.toList(growable: false),
        competingLnaaGrams: pureActual ? totalCompetingLnaaGrams : null,
        competingLnaaGramsPerServing:
            (pureActual && allHavePortion && totalServingGrams > 0)
            ? totalCompetingLnaaGrams
            : null,
        doseRelativeLnaaRatio: doseRelative,
        doseRelativeAvailable: doseAvailable,
        partialAminoAcidData: !pureActual,
        actualAminoAcidProteinCoverageFraction: coverage,
        aminoAcidConfidenceTier: pureActual ? aggregateTier?.name : null,
      );
    }

    var totalProtein = 0.0;
    var weightedFactor = 0.0;
    final sources = <ProteinSourceType>{};
    var unknownProteinSeen = false;
    final refs = <String>{};

    for (final c in proteinComponents) {
      final p = c.proteinGrams!;
      final factor = ProteinSourceLnaaRegistry.factorFor(c.proteinSource);
      totalProtein += p;
      weightedFactor += p * factor.loadFactor;
      sources.add(c.proteinSource);
      refs.addAll(factor.sourceRefs);
      if (c.proteinSource == ProteinSourceType.unknown) {
        unknownProteinSeen = true;
      }
    }

    if (totalProtein <= 0) {
      final unknown = ProteinSourceLnaaRegistry.factorFor(
        ProteinSourceType.unknown,
      );
      return CompetitionLnaaSummary(
        effectiveLoadFactor: unknown.loadFactor,
        sourcesPresent: const [ProteinSourceType.unknown],
        isPrototypeHeuristic: true,
        uncertaintyWidened: true,
        sourceRefs: unknown.sourceRefs,
        dataMode: AminoAcidDataMode.unknown,
      );
    }

    final effective = weightedFactor / totalProtein;
    return CompetitionLnaaSummary(
      effectiveLoadFactor: effective,
      sourcesPresent: sources.toList(growable: false),
      isPrototypeHeuristic: true,
      uncertaintyWidened: unknownProteinSeen || unusableProfileSeen,
      sourceRefs: refs.toList(growable: false),
      dataMode: AminoAcidDataMode.proteinSourceProxy,
      partialAminoAcidData: unusableProfileSeen,
      actualAminoAcidProteinCoverageFraction: 0,
    );
  }

  /// Returns a complete profile expressed for this serving, or null when using
  /// the values would mix incompatible units/bases or treat missing LNAA fields
  /// as zero. Zero-protein components are filtered before this method and do
  /// not require an amino-acid profile.
  AminoAcidProfile? _completeServingProfile(FoodComponent component) {
    final raw = component.aminoAcidProfile;
    if (raw == null || raw.partial || raw.unit.trim().toLowerCase() != 'g') {
      return null;
    }

    final AminoAcidProfile profile;
    if (raw.basis == 'per_serving') {
      profile = raw;
    } else if (raw.basis == 'per_100g') {
      final portion = component.portionGrams;
      if (portion == null || !portion.isFinite || portion <= 0) return null;
      profile = raw.scaledToGrams(portion);
    } else {
      return null;
    }

    final values = [
      profile.leucine,
      profile.isoleucine,
      profile.valine,
      profile.phenylalanine,
      profile.tyrosine,
      profile.tryptophan,
    ];
    if (values.any((value) => value == null || !value.isFinite || value < 0)) {
      return null;
    }
    final total = profile.competingLnaaGrams!;
    final protein = component.proteinGrams!;
    if (!total.isFinite || total < 0 || total > protein) return null;
    return profile;
  }

  CompetitionBand _toBand(double overlap) {
    if (overlap <= 0) return CompetitionBand.none;
    if (overlap < 0.1) return CompetitionBand.low;
    if (overlap < 0.25) return CompetitionBand.moderate;
    return CompetitionBand.high;
  }

  UncertaintyBand _toUncertainty({
    required double compositionCompleteness,
    required UncertaintyBand emptyingUncertainty,
    required bool lnaaUncertaintyWidened,
  }) {
    final order = [
      UncertaintyBand.narrow,
      UncertaintyBand.moderate,
      UncertaintyBand.wide,
      UncertaintyBand.veryWide,
    ];
    var idx = order.indexOf(emptyingUncertainty);
    if (compositionCompleteness < 0.99) idx += 1;
    if (compositionCompleteness < 0.5) idx += 1;
    if (lnaaUncertaintyWidened) idx += 1;
    return order[idx.clamp(0, order.length - 1)];
  }
}
