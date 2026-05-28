import '../entities/protein_distribution.dart';

/// Deterministic, educational protein-redistribution model.
///
/// Core principle (NOT global protein minimization):
/// - During a modeled high-overlap window → protein incurs a penalty.
/// - During a modeled low-overlap window → protein is allowed; redistribution
///   compatibility is higher; a nutrition-adequacy proxy keeps zero-protein
///   from automatically winning.
/// - Window role is decided PRIMARILY from modeled overlap; a local-hour hint
///   may nudge the *label* (e.g. flag an evening candidate window) but never
///   overrides overlap.
/// - Missing medication/timeline context → `unknownWindowRole`, optimization
///   off, no faked precision.
class ProteinDistributionModel {
  static const double highOverlapThreshold = 0.15;
  static const double lowOverlapThreshold = 0.05;
  static const int eveningHourStart = 18;

  /// Reference protein grams toward which a single meal can contribute for
  /// the educational adequacy proxy. Illustrative only.
  static const double adequacyReferenceProteinG = 20.0;

  static const List<String> _sourceRefs = [
    'src.nutt.lnaa.1989',
    'src.cereda.protein.2017',
    'src.advances.nutrition.2021',
    'src.pare.protein.redistribution.1992',
    'src.virmani.protein.2023',
    'src.internal.prototype.heuristic',
  ];

  ProteinRedistributionScore evaluate(ProteinDistributionContext ctx) {
    final assumptions = <String>[
      'protein.redistribution.not_global_minimization'
    ];

    if (!ctx.medicationContextValid) {
      return ProteinRedistributionScore(
        windowRole: ProteinWindowRole.unknownWindowRole,
        redistributionScore: 0.0,
        overlapProteinPenalty: 0.0,
        adequacy: const NutritionAdequacyProxy(
          contribution: 0.0,
          basis: 'medication_context_invalid',
          sourceRefs: _sourceRefs,
        ),
        assumptions:
            List.unmodifiable([...assumptions, 'medication_context_invalid']),
        sourceRefs: _sourceRefs,
        optimizationActive: false,
      );
    }

    final role = _windowRole(ctx);
    final protein = ctx.candidateProteinGrams ?? 0.0;
    final proteinPresence =
        (protein / adequacyReferenceProteinG).clamp(0.0, 1.0);

    // Overlap-driven protein penalty: scales with both overlap and protein.
    final overlapPenalty =
        (ctx.modeledOverlap * proteinPresence).clamp(0.0, 1.0);

    // Redistribution compatibility: high when overlap is low AND the meal
    // carries some protein (i.e. a good place to "spend" daily protein).
    double redistribution;
    switch (role) {
      case ProteinWindowRole.sensitiveLevodopaOverlapWindow:
        redistribution = (0.2 - overlapPenalty).clamp(0.0, 1.0);
        assumptions.add('protein.penalized_in_high_overlap_window');
        break;
      case ProteinWindowRole.lowerOverlapLaterWindow:
      case ProteinWindowRole.eveningRedistributionCandidateWindow:
        redistribution =
            (0.5 + 0.5 * proteinPresence - overlapPenalty).clamp(0.0, 1.0);
        assumptions.add('protein.allowed_in_low_overlap_window');
        break;
      case ProteinWindowRole.unknownWindowRole:
        redistribution = 0.0;
        break;
    }

    // Nutrition-adequacy proxy: a meal contributing some protein scores a
    // positive contribution so zero-protein doesn't automatically win.
    final adequacy = NutritionAdequacyProxy(
      contribution: proteinPresence.clamp(0.0, 1.0),
      basis: protein <= 0
          ? 'no_protein_contribution'
          : 'partial_daily_protein_contribution',
      sourceRefs: _sourceRefs,
    );

    return ProteinRedistributionScore(
      windowRole: role,
      redistributionScore: redistribution,
      overlapProteinPenalty: overlapPenalty,
      adequacy: adequacy,
      assumptions: List.unmodifiable(assumptions),
      sourceRefs: _sourceRefs,
      optimizationActive: true,
    );
  }

  ProteinWindowRole _windowRole(ProteinDistributionContext ctx) {
    if (ctx.modeledOverlap >= highOverlapThreshold) {
      return ProteinWindowRole.sensitiveLevodopaOverlapWindow;
    }
    if (ctx.modeledOverlap <= lowOverlapThreshold) {
      // Low overlap. If a local-hour hint indicates evening, label it as an
      // evening redistribution candidate; otherwise just a lower-overlap
      // later window. Overlap (not the clock) is the deciding factor for
      // being *redistribution-compatible*; the hour only refines the label.
      final hour = ctx.localHourHint;
      if (hour != null && hour >= eveningHourStart) {
        return ProteinWindowRole.eveningRedistributionCandidateWindow;
      }
      return ProteinWindowRole.lowerOverlapLaterWindow;
    }
    // Intermediate overlap: treat as lower-overlap-later (mild), not
    // sensitive, but not a strong redistribution candidate.
    return ProteinWindowRole.lowerOverlapLaterWindow;
  }

  ProteinDistributionTrace toTrace(ProteinRedistributionScore s) {
    return ProteinDistributionTrace(
      windowRole: s.windowRole,
      redistributionScore: s.redistributionScore,
      nutritionAdequacyContribution: s.adequacy.contribution,
      optimizationActive: s.optimizationActive,
      objectiveDescription:
          'Educational protein-redistribution objective: protein is modeled as '
          'less compatible during high-overlap windows and more compatible in '
          'low-overlap windows. This is not dietary or medication advice.',
    );
  }
}
