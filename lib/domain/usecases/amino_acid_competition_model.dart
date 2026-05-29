import '../entities/absorption_opportunity.dart';
import '../entities/amino_acid_competition.dart';
import '../entities/amino_acid_profile.dart' show AminoAcidDataMode;
import '../entities/gastric_emptying_profile.dart';
import '../entities/meal_composition.dart';
import '../entities/protein_source.dart';

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
class AminoAcidCompetitionModel {
  static const double referenceProteinG = 20.0;
  static const int sampleStrideMinutes = 5;

  static const List<String> _baseSourceRefs = [
    'src.nutt.lnaa.1989',
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
      // The modeled overlap is an intestinal-absorption competition proxy.
      // Broader blood–brain-barrier LNAA transport competition is a cited
      // mechanism but is NOT quantified here.
      'ldopa.protein.lnaa_competition_intestinal_absorption',
      'ldopa.protein.lnaa_bbb_transport_competition_not_quantified',
    ];

    if (mealComposition.proteinGrams == null) {
      return CompetitionPressureTimeline(
        samples: const [],
        peakMinute: mealEmptyingProfile.peakEmptyingWindow.startMinute,
        peakPressure: 0,
        overlapWithAbsorptionWindow: 0,
        competitionBand: CompetitionBand.unknown,
        uncertaintyBand: UncertaintyBand.veryWide,
        assumptions:
            List.unmodifiable([...assumptions, 'protein_grams_missing']),
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
    assumptions.add(
        'aa.lnaa.source_type_load_factor (effective ${lnaa.effectiveLoadFactor.toStringAsFixed(2)})');
    if (lnaa.uncertaintyWidened) {
      assumptions.add('aa.lnaa.unknown_source_widened_uncertainty');
    }
    if (lnaa.partialAminoAcidData) {
      assumptions.add('aa.lnaa.partial_amino_acid_fields_widened_uncertainty');
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
    final proteinAmplitude =
        (proteinAmplitudeBase * lnaa.effectiveLoadFactor).clamp(0.0, 2.0);

    final samples = <CompetitionPressureSample>[];
    final startMin = mealStartMinute;
    final endMin = mealEmptyingProfile.mostlyEmptiedWindow.endMinute;
    var peakMinute = startMin;
    var peakPressure = 0.0;

    for (var t = startMin; t <= endMin; t += sampleStrideMinutes) {
      final tSinceMeal = t - mealStartMinute;
      final arrivalRate =
          mealEmptyingProfile.intestinalArrivalRateAt(tSinceMeal);
      // Pressure proxy: arrival rate (which already reflects fat/fiber/size
      // modifiers) modulated by protein-amplitude * LNAA-load-factor.
      final pressure = (arrivalRate * proteinAmplitude).clamp(0.0, 1.0);
      samples.add(CompetitionPressureSample(minute: t, pressure: pressure));
      if (pressure > peakPressure) {
        peakPressure = pressure;
        peakMinute = t;
      }
    }

    // Overlap integral: competition pressure weighted by the absorption
    // opportunity OPENNESS curve (Σ pressure·openness / Σ openness), so
    // pressure arriving near the peak opportunity counts more than pressure at
    // the window edges. Falls back to a flat in-window average when no openness
    // profile is available (compatibility). Result is in [0, 1].
    final hasProfile = absorptionWindow.opennessProfile.isNotEmpty;
    double overlap;
    if (hasProfile) {
      var weightedSum = 0.0;
      var weightTotal = 0.0;
      for (final s in samples) {
        final w = absorptionWindow.opennessAt(s.minute);
        if (w <= 0) continue;
        weightedSum += s.pressure * w;
        weightTotal += w;
      }
      overlap = weightTotal == 0 ? 0.0 : weightedSum / weightTotal;
      assumptions.add('ldopa.absorption.openness_weighted_overlap');
    } else {
      var insideCount = 0;
      var insideSum = 0.0;
      for (final s in samples) {
        if (absorptionWindow.window.contains(s.minute)) {
          insideCount += 1;
          insideSum += s.pressure;
        }
      }
      overlap = insideCount == 0 ? 0.0 : insideSum / insideCount;
    }

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

  /// Returns a `CompetitionLnaaSummary`. Prefers ACTUAL per-food amino-acid
  /// fields (narrower uncertainty) when any component carries an
  /// `AminoAcidProfile`; otherwise falls back to the protein-source proxy;
  /// otherwise `unknown` with widened uncertainty.
  CompetitionLnaaSummary _computeLnaaLoad(
      MealComposition composition, double? levodopaDoseMg) {
    final components = composition.foodComponents;
    if (components.isEmpty) {
      final unknown =
          ProteinSourceLnaaRegistry.factorFor(ProteinSourceType.unknown);
      return CompetitionLnaaSummary(
        effectiveLoadFactor: unknown.loadFactor,
        sourcesPresent: const [ProteinSourceType.unknown],
        isPrototypeHeuristic: true,
        uncertaintyWidened: true,
        sourceRefs: unknown.sourceRefs,
        dataMode: AminoAcidDataMode.unknown,
      );
    }

    // Preferred path: actual amino-acid fields. Compute a protein-weighted
    // LNAA *fraction* (competing LNAA grams / protein grams) and scale it
    // against a reference fraction (~0.45 of protein for a balanced animal
    // protein) to get a load factor comparable to the proxy. Prototype
    // magnitude; direction supported by the cited literature.
    final aaComponents = components
        .where((c) =>
            c.aminoAcidProfile != null &&
            c.aminoAcidProfile!.competingLnaaGrams != null &&
            (c.proteinGrams ?? 0) > 0)
        .toList(growable: false);
    if (aaComponents.isNotEmpty) {
      const referenceLnaaFractionOfProtein = 0.45;
      var totalProtein = 0.0;
      var weighted = 0.0;
      var totalCompetingLnaaGrams = 0.0;
      var totalServingGrams = 0.0;
      var allHavePortion = true;
      var partial = false;
      final ids = <String>{};
      final refs = <String>{'src.fdc.api.amino_acid_fields'};
      for (final c in aaComponents) {
        final p = c.proteinGrams!;
        final profile = c.aminoAcidProfile!;
        final lnaa = profile.competingLnaaGrams!;
        final fraction = (lnaa / p).clamp(0.0, 1.0);
        final factor =
            (fraction / referenceLnaaFractionOfProtein).clamp(0.5, 1.5);
        totalProtein += p;
        weighted += p * factor;
        totalCompetingLnaaGrams += lnaa;
        if (c.portionGrams != null) {
          totalServingGrams += c.portionGrams!;
        } else {
          allHavePortion = false;
        }
        // Partial when unit-ambiguous or only some of the six LNAA present.
        if (profile.partial || profile.hasPartialLnaaFields) partial = true;
        ids.addAll(profile.nutrientIds);
        refs.addAll(profile.sourceRefs);
      }
      final effective = totalProtein > 0 ? weighted / totalProtein : 1.0;

      // Dose-relative ratio (g competing LNAA per 100 mg levodopa) ONLY when an
      // explicit user-entered dose is available — never invented.
      final doseAvailable = levodopaDoseMg != null && levodopaDoseMg > 0;
      final doseRelative = doseAvailable
          ? totalCompetingLnaaGrams / (levodopaDoseMg / 100.0)
          : null;

      return CompetitionLnaaSummary(
        effectiveLoadFactor: effective,
        sourcesPresent: const [],
        isPrototypeHeuristic: true,
        // Partial actual data is NOT treated as fully narrow uncertainty.
        uncertaintyWidened: partial,
        sourceRefs: refs.toList(growable: false),
        dataMode: AminoAcidDataMode.actualAminoAcidFields,
        aminoAcidNutrientIds: ids.toList(growable: false),
        competingLnaaGrams: totalCompetingLnaaGrams,
        competingLnaaGramsPerServing: (allHavePortion && totalServingGrams > 0)
            ? totalCompetingLnaaGrams
            : null,
        doseRelativeLnaaRatio: doseRelative,
        doseRelativeAvailable: doseAvailable,
        partialAminoAcidData: partial,
      );
    }

    var totalProtein = 0.0;
    var weightedFactor = 0.0;
    final sources = <ProteinSourceType>{};
    var unknownProteinSeen = false;
    final refs = <String>{};

    for (final c in components) {
      final p = c.proteinGrams;
      if (p == null || p <= 0) continue;
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
      final unknown =
          ProteinSourceLnaaRegistry.factorFor(ProteinSourceType.unknown);
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
      uncertaintyWidened: unknownProteinSeen,
      sourceRefs: refs.toList(growable: false),
      dataMode: AminoAcidDataMode.proteinSourceProxy,
    );
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
