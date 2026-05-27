import '../entities/absorption_opportunity.dart';
import '../entities/amino_acid_competition.dart';
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
  }) {
    final assumptions = <String>['ldopa.protein.lnaa_competition'];

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
        ),
      );
    }

    final lnaa = _computeLnaaLoad(mealComposition);
    assumptions.add(
        'aa.lnaa.source_type_load_factor (effective ${lnaa.effectiveLoadFactor.toStringAsFixed(2)})');
    if (lnaa.uncertaintyWidened) {
      assumptions.add('aa.lnaa.unknown_source_widened_uncertainty');
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

    // Overlap integral: average competition pressure within the absorption
    // opportunity window. Result is in [0, 1].
    var insideCount = 0;
    var insideSum = 0.0;
    for (final s in samples) {
      if (absorptionWindow.window.contains(s.minute)) {
        insideCount += 1;
        insideSum += s.pressure;
      }
    }
    final overlap = insideCount == 0 ? 0.0 : insideSum / insideCount;

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

  /// Returns a `CompetitionLnaaSummary` describing the weighted-average
  /// LNAA load factor across the meal's components. If components are not
  /// available, falls back to `unknown` with widened uncertainty.
  CompetitionLnaaSummary _computeLnaaLoad(MealComposition composition) {
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
      );
    }

    final effective = weightedFactor / totalProtein;
    return CompetitionLnaaSummary(
      effectiveLoadFactor: effective,
      sourcesPresent: sources.toList(growable: false),
      isPrototypeHeuristic: true,
      uncertaintyWidened: unknownProteinSeen,
      sourceRefs: refs.toList(growable: false),
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
