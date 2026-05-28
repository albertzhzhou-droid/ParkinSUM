/// Protein-redistribution objective types for the educational next-meal
/// scorer.
///
/// ParkinSUM does NOT globally minimize protein. The educational objective is
/// *redistribution*: protein-containing foods are penalized only in windows
/// the model estimates to overlap the levodopa absorption opportunity, and
/// are allowed (not rewarded into prescription) in lower-overlap windows. A
/// non-clinical nutrition-adequacy proxy prevents zero-protein from
/// automatically winning. This is an educational simulation, not a meal plan.
///
/// Window role is determined PRIMARILY from modeled overlap — never from a
/// hard-coded clock value. A 20:00 window with active modeled overlap is not
/// redistribution-compatible; a 20:00 window with low overlap is.
library;

enum ProteinWindowRole {
  sensitiveLevodopaOverlapWindow,
  lowerOverlapLaterWindow,
  eveningRedistributionCandidateWindow,
  unknownWindowRole,
}

/// Context handed to the protein-distribution model.
class ProteinDistributionContext {
  /// Modeled overlap (0..1) between the candidate meal and the levodopa
  /// absorption opportunity, from the mechanistic engine.
  final double modeledOverlap;

  /// Optional local hour-of-day hint (0..23) for the candidate window's
  /// midpoint. May *inform* the role label but never overrides overlap.
  final int? localHourHint;

  /// Whether a valid medication + timeline context exists. When false the
  /// role is `unknownWindowRole` and no redistribution optimization runs.
  final bool medicationContextValid;

  /// Candidate protein grams (null when unknown).
  final double? candidateProteinGrams;

  const ProteinDistributionContext({
    required this.modeledOverlap,
    required this.localHourHint,
    required this.medicationContextValid,
    required this.candidateProteinGrams,
  });
}

/// Non-clinical nutrition-adequacy proxy. Rewards a meal that contributes
/// *some* protein toward daily adequacy so the recommender does not collapse
/// to "always pick zero protein". Educational only.
class NutritionAdequacyProxy {
  final double contribution; // 0..1
  final String basis;
  final List<String> sourceRefs;

  const NutritionAdequacyProxy({
    required this.contribution,
    required this.basis,
    required this.sourceRefs,
  });

  Map<String, dynamic> toJson() => {
        'contribution': contribution,
        'basis': basis,
        'source_refs': sourceRefs,
      };
}

class ProteinRedistributionScore {
  final ProteinWindowRole windowRole;

  /// 0..1, higher = more redistribution-compatible for this candidate in
  /// this window. NOT a recommendation to eat; a modeled compatibility proxy.
  final double redistributionScore;

  /// Penalty applied for protein during a high-overlap window (0..1).
  final double overlapProteinPenalty;

  final NutritionAdequacyProxy adequacy;
  final List<String> assumptions;
  final List<String> sourceRefs;
  final bool optimizationActive;

  const ProteinRedistributionScore({
    required this.windowRole,
    required this.redistributionScore,
    required this.overlapProteinPenalty,
    required this.adequacy,
    required this.assumptions,
    required this.sourceRefs,
    required this.optimizationActive,
  });

  Map<String, dynamic> toJson() => {
        'window_role': windowRole.name,
        'redistribution_score': redistributionScore,
        'overlap_protein_penalty': overlapProteinPenalty,
        'adequacy': adequacy.toJson(),
        'assumptions': assumptions,
        'source_refs': sourceRefs,
        'optimization_active': optimizationActive,
      };
}

/// Compact trace object surfaced in the candidate score / UI.
class ProteinDistributionTrace {
  final ProteinWindowRole windowRole;
  final double redistributionScore;
  final double nutritionAdequacyContribution;
  final bool optimizationActive;
  final String objectiveDescription;

  const ProteinDistributionTrace({
    required this.windowRole,
    required this.redistributionScore,
    required this.nutritionAdequacyContribution,
    required this.optimizationActive,
    required this.objectiveDescription,
  });

  Map<String, dynamic> toJson() => {
        'window_role': windowRole.name,
        'redistribution_score': redistributionScore,
        'nutrition_adequacy_contribution': nutritionAdequacyContribution,
        'optimization_active': optimizationActive,
        'objective_description': objectiveDescription,
      };
}
