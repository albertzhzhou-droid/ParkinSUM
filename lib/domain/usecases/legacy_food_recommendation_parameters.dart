/// Versioned configuration for the legacy food recommendation scorer.
///
/// These values preserve the historical compatibility ranking. They are
/// prototype heuristics: none is a fitted coefficient, probability, clinical
/// cutoff, predicted benefit, or medical recommendation. Keeping the selected
/// score composition, bound, threshold, and ordering contract in one immutable
/// object lets production execution, replay identity, provenance, and the
/// Algorithm Observatory refer to the same values.
library;

abstract final class LegacyFoodRecommendationParameterIds {
  static const String scoreScale = 'legacy_food.score.scale.points';
  static const String minimumScore = 'legacy_food.score.bound.minimum_points';
  static const String maximumScore = 'legacy_food.score.bound.maximum_points';

  static const String safetyWeight = 'legacy_food.score.weight.safety';
  static const String nutrientMatchWeight =
      'legacy_food.score.weight.nutrient_match';
  static const String scheduleFitWeight =
      'legacy_food.score.weight.medication_schedule_fit';
  static const String culturalAffinityWeight =
      'legacy_food.score.weight.cultural_affinity';
  static const String userPreferenceWeight =
      'legacy_food.score.weight.user_preference';
  static const String provenanceWeight = 'legacy_food.score.weight.provenance';
  static const String databaseFactCoverageWeight =
      'legacy_food.score.weight.database_fact_coverage';
  static const String timingWindowClarityWeight =
      'legacy_food.score.weight.timing_window_clarity';
  static const String regionMatchWeight =
      'legacy_food.score.weight.region_match';
  static const String fiberSupportWeight =
      'legacy_food.score.weight.fiber_support';
  static const String mealContextPenaltyWeight =
      'legacy_food.score.weight.meal_context_penalty';
  static const String contextDataGapPenaltyWeight =
      'legacy_food.score.weight.context_data_gap_penalty';
  static const String swallowingTexturePenaltyWeight =
      'legacy_food.score.weight.swallowing_texture_penalty';
  static const String fallbackPenaltyWeight =
      'legacy_food.score.weight.fallback_penalty';
  static const String repetitionPenaltyWeight =
      'legacy_food.score.weight.repetition_penalty';
  static const String drugTimingSensitivityWeight =
      'legacy_food.score.weight.drug_timing_sensitivity';

  static const String safetyCautionProteinG =
      'legacy_food.threshold.protein.safety_caution_g';
  static const String safetyHighProteinG =
      'legacy_food.threshold.protein.safety_high_g';
  static const String scheduleHighProteinG =
      'legacy_food.threshold.protein.schedule_high_g';
  static const String timingSensitivityCautionProteinG =
      'legacy_food.threshold.protein.timing_sensitivity_caution_g';
  static const String timingSensitivityHighProteinG =
      'legacy_food.threshold.protein.timing_sensitivity_high_g';
  static const String warningProteinG =
      'legacy_food.threshold.protein.warning_g';
  static const String contextPenaltyProteinG =
      'legacy_food.threshold.protein.context_penalty_g';
  static const String lowProteinReasonG =
      'legacy_food.threshold.protein.low_reason_g';
  static const String historyAverageProteinHighG =
      'legacy_food.threshold.history.average_protein_high_g';
  static const String historyLowCandidateProteinG =
      'legacy_food.threshold.history.low_candidate_protein_g';
  static const String highFiberSupportG =
      'legacy_food.threshold.fiber.high_support_g';
  static const String moderateFiberSupportG =
      'legacy_food.threshold.fiber.moderate_support_g';
  static const String nutrientFiberG =
      'legacy_food.threshold.fiber.nutrient_match_g';

  static const String maximumCandidates =
      'legacy_food.ranking.maximum_candidates';
  static const String tieBreakPolicy = 'legacy_food.structure.tie_break_policy';

  static const Set<String> numeric = {
    scoreScale,
    minimumScore,
    maximumScore,
    safetyWeight,
    nutrientMatchWeight,
    scheduleFitWeight,
    culturalAffinityWeight,
    userPreferenceWeight,
    provenanceWeight,
    databaseFactCoverageWeight,
    timingWindowClarityWeight,
    regionMatchWeight,
    fiberSupportWeight,
    mealContextPenaltyWeight,
    contextDataGapPenaltyWeight,
    swallowingTexturePenaltyWeight,
    fallbackPenaltyWeight,
    repetitionPenaltyWeight,
    drugTimingSensitivityWeight,
    safetyCautionProteinG,
    safetyHighProteinG,
    scheduleHighProteinG,
    timingSensitivityCautionProteinG,
    timingSensitivityHighProteinG,
    warningProteinG,
    contextPenaltyProteinG,
    lowProteinReasonG,
    historyAverageProteinHighG,
    historyLowCandidateProteinG,
    highFiberSupportG,
    moderateFiberSupportG,
    nutrientFiberG,
    maximumCandidates,
  };
}

/// Explicit source-system scoring used by the legacy compatibility ranker.
/// These are prototype heuristics about metadata lineage, not measurements of
/// food quality, evidence certainty, or clinical trustworthiness.
abstract final class LegacyFoodRecommendationProvenancePolicy {
  static const String parameterId =
      'legacy_food.provenance.source_system_score_policy';
  static const String formulaId =
      'legacy-food.provenance.source-system-score-map/1';
  static const String unit = 'canonical_json';
  static const String transformId = 'identity-json/1';
  static const List<String> sourceRefs = ['src.internal.prototype.heuristic'];
  static const String limitation =
      'Lineage-label compatibility weights only. They do not measure source '
      'accuracy, evidence quality, food composition correctness, or clinical '
      'validity.';

  /// Preserve the existing scorer's exact source labels and uppercase-only
  /// normalization while making the mapping inspectable and digest-bound.
  static const Map<String, double> knownSourceSystemScores = {
    'CIQUAL': 0.95,
    'DAILYMED': 0.95,
    'DPD': 0.95,
    'FDC': 0.95,
    'HEALTH_CANADA_DPD': 0.95,
    'LOCAL_SEED': 0.55,
    'USDA_FDC': 0.95,
  };
  static const double unknownWithFoodCodeScore = 0.85;
  static const double unknownWithoutFoodCodeScore = 0.6;

  static Map<String, dynamic> get canonicalValue => {
    'normalization': 'uppercase_without_trimming',
    'known_source_system_scores': {
      for (final key in knownSourceSystemScores.keys.toList()..sort())
        key: knownSourceSystemScores[key],
    },
    'unknown_with_source_food_code': unknownWithFoodCodeScore,
    'unknown_without_source_food_code': unknownWithoutFoodCodeScore,
  };

  static Map<String, dynamic> toJson({required String reviewDate}) => {
    'id': parameterId,
    'formula_id': formulaId,
    'unit': unit,
    'value': canonicalValue,
    'source_refs': sourceRefs,
    'provenance_status': 'prototypeHeuristic',
    'reviewed_at': reviewDate,
    'limitation': limitation,
  };

  static double scoreFor({
    required String sourceSystem,
    required bool hasSourceFoodCode,
  }) =>
      knownSourceSystemScores[sourceSystem.toUpperCase()] ??
      (hasSourceFoodCode
          ? unknownWithFoodCodeScore
          : unknownWithoutFoodCodeScore);
}

final class LegacyFoodRecommendationScalar {
  final String id;
  final String label;
  final String formulaId;
  final String unit;
  final double value;
  final double minimum;
  final double maximum;
  final List<String> sourceRefs;
  final String limitation;

  LegacyFoodRecommendationScalar({
    required this.id,
    required this.label,
    required this.formulaId,
    required this.unit,
    required this.value,
    required this.minimum,
    required this.maximum,
    required List<String> sourceRefs,
    required this.limitation,
  }) : sourceRefs = List<String>.unmodifiable(sourceRefs);

  LegacyFoodRecommendationScalar copyWithValue(double nextValue) =>
      LegacyFoodRecommendationScalar(
        id: id,
        label: label,
        formulaId: formulaId,
        unit: unit,
        value: nextValue,
        minimum: minimum,
        maximum: maximum,
        sourceRefs: sourceRefs,
        limitation: limitation,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'formula_id': formulaId,
    'unit': unit,
    'value': value,
    'minimum': minimum,
    'maximum': maximum,
    'source_refs': sourceRefs,
    'provenance_status': 'prototypeHeuristic',
    'limitation': limitation,
  };
}

final class LegacyFoodRecommendationParameterSet {
  static const String defaultId = 'legacy_food_recommendations.compatibility';
  static const String defaultVersion = '2026.09.23-v2';
  static const String defaultLastReviewed = '2026-09-23';
  static const String scoreDescendingFoodIdAscending = 'score_desc_food_id_asc';
  static const List<String> supportedTieBreakPolicies = [
    scoreDescendingFoodIdAscending,
  ];
  static const String tieBreakLabel =
      'Descending points, then ascending stable food ID';
  static const String tieBreakFormulaId =
      'legacy-food.ranking.score-desc-food-id-asc/1';
  static const String tieBreakUnit = 'ordering_policy';
  static const List<String> tieBreakSourceRefs = [
    'src.internal.prototype.heuristic',
  ];
  static const String tieBreakLimitation =
      'Deterministic engineering ordering only. It is not evidence that a '
      'higher-ranked food is clinically safer, appropriate, or beneficial.';

  final String id;
  final String version;
  final String lastReviewed;
  final List<LegacyFoodRecommendationScalar> parameters;
  final String tieBreakPolicy;

  LegacyFoodRecommendationParameterSet({
    required this.id,
    required this.version,
    required this.lastReviewed,
    required Iterable<LegacyFoodRecommendationScalar> parameters,
    required this.tieBreakPolicy,
  }) : parameters = List<LegacyFoodRecommendationScalar>.unmodifiable(
         parameters.toList()
           ..sort((left, right) => left.id.compareTo(right.id)),
       );

  factory LegacyFoodRecommendationParameterSet.prototypeDefault() {
    const source = <String>['src.internal.prototype.heuristic'];
    const limitation =
        'Compatibility value retained from the prototype scorer. It is not '
        'fitted, calibrated, prospectively validated, or a clinical cutoff.';

    LegacyFoodRecommendationScalar scalar({
      required String id,
      required String label,
      required double value,
      required String unit,
      required double minimum,
      required double maximum,
      required String formulaId,
    }) => LegacyFoodRecommendationScalar(
      id: id,
      label: label,
      formulaId: formulaId,
      unit: unit,
      value: value,
      minimum: minimum,
      maximum: maximum,
      sourceRefs: source,
      limitation: limitation,
    );

    const scoreFormula = 'legacy-food.score.bounded-linear-composition/2';
    const proteinFormula = 'legacy-food.threshold.protein-branching/1';
    const fiberFormula = 'legacy-food.threshold.fiber-branching/1';
    const historyFormula = 'legacy-food.history.arithmetic-mean-branching/1';

    return LegacyFoodRecommendationParameterSet(
      id: defaultId,
      version: defaultVersion,
      lastReviewed: defaultLastReviewed,
      tieBreakPolicy: scoreDescendingFoodIdAscending,
      parameters: <LegacyFoodRecommendationScalar>[
        scalar(
          id: LegacyFoodRecommendationParameterIds.scoreScale,
          label: 'Legacy ranking point scale',
          value: 100,
          unit: 'points_per_score_unit',
          minimum: 1,
          maximum: 10000,
          formulaId: scoreFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.minimumScore,
          label: 'Minimum visible legacy ranking points',
          value: 0,
          unit: 'points',
          minimum: -10000,
          maximum: 10000,
          formulaId: 'legacy-food.score.bound/1',
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.maximumScore,
          label: 'Maximum visible legacy ranking points',
          value: 100,
          unit: 'points',
          minimum: -10000,
          maximum: 10000,
          formulaId: 'legacy-food.score.bound/1',
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.safetyWeight,
          label: 'Safety-feature weight',
          value: 0.40,
          unit: 'weight_0_1',
          minimum: 0,
          maximum: 1,
          formulaId: scoreFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.nutrientMatchWeight,
          label: 'Nutrient-match weight',
          value: 0.20,
          unit: 'weight_0_1',
          minimum: 0,
          maximum: 1,
          formulaId: scoreFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.scheduleFitWeight,
          label: 'Medication-schedule-fit weight',
          value: 0.15,
          unit: 'weight_0_1',
          minimum: 0,
          maximum: 1,
          formulaId: scoreFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.culturalAffinityWeight,
          label: 'Cultural-affinity weight',
          value: 0.10,
          unit: 'weight_0_1',
          minimum: 0,
          maximum: 1,
          formulaId: scoreFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.userPreferenceWeight,
          label: 'User-preference weight',
          value: 0.10,
          unit: 'weight_0_1',
          minimum: 0,
          maximum: 1,
          formulaId: scoreFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.provenanceWeight,
          label: 'Provenance-feature weight',
          value: 0.05,
          unit: 'weight_0_1',
          minimum: 0,
          maximum: 1,
          formulaId: scoreFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.databaseFactCoverageWeight,
          label: 'Database-fact-coverage weight',
          value: 0.03,
          unit: 'weight_0_1',
          minimum: 0,
          maximum: 1,
          formulaId: scoreFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.timingWindowClarityWeight,
          label: 'Timing-window-clarity weight',
          value: 0.02,
          unit: 'weight_0_1',
          minimum: 0,
          maximum: 1,
          formulaId: scoreFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.regionMatchWeight,
          label: 'Region-match weight',
          value: 0.02,
          unit: 'weight_0_1',
          minimum: 0,
          maximum: 1,
          formulaId: scoreFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.fiberSupportWeight,
          label: 'Fiber-support weight',
          value: 0.02,
          unit: 'weight_0_1',
          minimum: 0,
          maximum: 1,
          formulaId: scoreFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.mealContextPenaltyWeight,
          label: 'Meal-context penalty weight',
          value: 0.06,
          unit: 'weight_0_1',
          minimum: 0,
          maximum: 1,
          formulaId: scoreFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.contextDataGapPenaltyWeight,
          label: 'Context-data-gap penalty weight',
          value: 0.04,
          unit: 'weight_0_1',
          minimum: 0,
          maximum: 1,
          formulaId: scoreFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds
              .swallowingTexturePenaltyWeight,
          label: 'Swallowing-texture penalty weight',
          value: 0.08,
          unit: 'weight_0_1',
          minimum: 0,
          maximum: 1,
          formulaId: scoreFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.fallbackPenaltyWeight,
          label: 'Source-fallback penalty weight',
          value: 0.03,
          unit: 'weight_0_1',
          minimum: 0,
          maximum: 1,
          formulaId: scoreFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.repetitionPenaltyWeight,
          label: 'Recent-repetition penalty weight',
          value: 0.02,
          unit: 'weight_0_1',
          minimum: 0,
          maximum: 1,
          formulaId: scoreFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.drugTimingSensitivityWeight,
          label: 'Drug-timing-sensitivity penalty weight',
          value: 0.04,
          unit: 'weight_0_1',
          minimum: 0,
          maximum: 1,
          formulaId: scoreFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.safetyCautionProteinG,
          label: 'Protein threshold for caution-tier safety score',
          value: 15,
          unit: 'g',
          minimum: 0,
          maximum: 1000,
          formulaId: proteinFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.safetyHighProteinG,
          label: 'Protein threshold for high-tier safety score',
          value: 25,
          unit: 'g',
          minimum: 0,
          maximum: 1000,
          formulaId: proteinFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.scheduleHighProteinG,
          label: 'Protein threshold for schedule-fit branching',
          value: 20,
          unit: 'g',
          minimum: 0,
          maximum: 1000,
          formulaId: proteinFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds
              .timingSensitivityCautionProteinG,
          label: 'Protein threshold for caution timing sensitivity',
          value: 15,
          unit: 'g',
          minimum: 0,
          maximum: 1000,
          formulaId: proteinFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds
              .timingSensitivityHighProteinG,
          label: 'Protein threshold for high timing sensitivity',
          value: 20,
          unit: 'g',
          minimum: 0,
          maximum: 1000,
          formulaId: proteinFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.warningProteinG,
          label: 'Protein threshold for visible warning decision',
          value: 20,
          unit: 'g',
          minimum: 0,
          maximum: 1000,
          formulaId: proteinFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.contextPenaltyProteinG,
          label: 'Protein threshold for iron/feed context penalties',
          value: 15,
          unit: 'g',
          minimum: 0,
          maximum: 1000,
          formulaId: proteinFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.lowProteinReasonG,
          label: 'Exclusive protein threshold for low-protein reason copy',
          value: 10,
          unit: 'g',
          minimum: 0,
          maximum: 1000,
          formulaId: proteinFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.historyAverageProteinHighG,
          label: 'Exclusive high average-history protein threshold',
          value: 25,
          unit: 'g_per_logged_meal',
          minimum: 0,
          maximum: 1000,
          formulaId: historyFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.historyLowCandidateProteinG,
          label: 'Exclusive low-protein candidate threshold after high history',
          value: 8,
          unit: 'g',
          minimum: 0,
          maximum: 1000,
          formulaId: historyFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.highFiberSupportG,
          label: 'High fiber-support threshold',
          value: 4,
          unit: 'g',
          minimum: 0,
          maximum: 1000,
          formulaId: fiberFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.moderateFiberSupportG,
          label: 'Moderate fiber-support threshold',
          value: 2,
          unit: 'g',
          minimum: 0,
          maximum: 1000,
          formulaId: fiberFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.nutrientFiberG,
          label: 'Fiber threshold for nutrient-match branching',
          value: 2,
          unit: 'g',
          minimum: 0,
          maximum: 1000,
          formulaId: fiberFormula,
        ),
        scalar(
          id: LegacyFoodRecommendationParameterIds.maximumCandidates,
          label: 'Maximum number of visible legacy candidates',
          value: 5,
          unit: 'count',
          minimum: 1,
          maximum: 1000,
          formulaId: tieBreakFormulaId,
        ),
      ],
    );
  }

  List<String> get allParameterIds => List<String>.unmodifiable(
    [
      ...parameters.map((parameter) => parameter.id),
      LegacyFoodRecommendationParameterIds.tieBreakPolicy,
    ]..sort(),
  );

  double valueOf(String parameterId) {
    final matches = parameters.where(
      (parameter) => parameter.id == parameterId,
    );
    if (matches.length != 1) {
      throw StateError(
        'Expected exactly one legacy parameter "$parameterId"; found '
        '${matches.length}.',
      );
    }
    return matches.single.value;
  }

  int get maximumCandidateCount =>
      valueOf(LegacyFoodRecommendationParameterIds.maximumCandidates).toInt();

  double get minimumScore =>
      valueOf(LegacyFoodRecommendationParameterIds.minimumScore);

  double get maximumScore =>
      valueOf(LegacyFoodRecommendationParameterIds.maximumScore);

  LegacyFoodRecommendationParameterSet withValue(
    String parameterId,
    double value,
  ) {
    if (!parameters.any((parameter) => parameter.id == parameterId)) {
      throw ArgumentError.value(parameterId, 'parameterId', 'unknown ID');
    }
    return LegacyFoodRecommendationParameterSet(
      id: id,
      version: version,
      lastReviewed: lastReviewed,
      tieBreakPolicy: tieBreakPolicy,
      parameters: [
        for (final parameter in parameters)
          parameter.id == parameterId
              ? parameter.copyWithValue(value)
              : parameter,
      ],
    );
  }

  LegacyFoodRecommendationParameterSet withTieBreakPolicy(String policy) =>
      LegacyFoodRecommendationParameterSet(
        id: id,
        version: version,
        lastReviewed: lastReviewed,
        parameters: parameters,
        tieBreakPolicy: policy,
      );

  List<String> get validationErrors {
    final errors = <String>[];
    if (id.trim().isEmpty) errors.add('parameter_set_id_empty');
    if (version.trim().isEmpty) errors.add('parameter_set_version_empty');
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(lastReviewed)) {
      errors.add('parameter_set_review_date_invalid');
    }

    final seenIds = <String>{};
    for (final parameter in parameters) {
      if (parameter.id.trim().isEmpty || !seenIds.add(parameter.id)) {
        errors.add('parameter_id_empty_or_duplicate:${parameter.id}');
      }
      if (!LegacyFoodRecommendationParameterIds.numeric.contains(
        parameter.id,
      )) {
        errors.add('parameter_id_unknown:${parameter.id}');
      }
      if (parameter.label.trim().isEmpty) {
        errors.add('parameter_label_empty:${parameter.id}');
      }
      if (parameter.formulaId.trim().isEmpty) {
        errors.add('parameter_formula_empty:${parameter.id}');
      }
      if (parameter.unit.trim().isEmpty) {
        errors.add('parameter_unit_empty:${parameter.id}');
      }
      if (!parameter.minimum.isFinite ||
          !parameter.maximum.isFinite ||
          parameter.minimum > parameter.maximum) {
        errors.add('parameter_domain_invalid:${parameter.id}');
      }
      if (!parameter.value.isFinite) {
        errors.add('parameter_nonfinite:${parameter.id}');
      } else if (parameter.value < parameter.minimum ||
          parameter.value > parameter.maximum) {
        errors.add('parameter_out_of_range:${parameter.id}');
      }
      if (parameter.sourceRefs.isEmpty ||
          parameter.sourceRefs.any((source) => source.trim().isEmpty)) {
        errors.add('parameter_sources_invalid:${parameter.id}');
      }
      if (parameter.limitation.trim().isEmpty) {
        errors.add('parameter_limitation_empty:${parameter.id}');
      }
    }
    for (final requiredId in LegacyFoodRecommendationParameterIds.numeric) {
      if (!seenIds.contains(requiredId)) {
        errors.add('parameter_missing:$requiredId');
      }
    }

    double? uniqueValue(String parameterId) {
      final matches = parameters.where(
        (parameter) => parameter.id == parameterId,
      );
      return matches.length == 1 ? matches.single.value : null;
    }

    final minimum = uniqueValue(
      LegacyFoodRecommendationParameterIds.minimumScore,
    );
    final maximum = uniqueValue(
      LegacyFoodRecommendationParameterIds.maximumScore,
    );
    if (minimum != null && maximum != null && minimum >= maximum) {
      errors.add('score_bounds_not_strictly_ordered');
    }
    void requireAscending(String lowerId, String upperId, String error) {
      final lower = uniqueValue(lowerId);
      final upper = uniqueValue(upperId);
      if (lower != null && upper != null && lower >= upper) {
        errors.add(error);
      }
    }

    requireAscending(
      LegacyFoodRecommendationParameterIds.safetyCautionProteinG,
      LegacyFoodRecommendationParameterIds.safetyHighProteinG,
      'safety_protein_thresholds_not_ordered',
    );
    requireAscending(
      LegacyFoodRecommendationParameterIds.timingSensitivityCautionProteinG,
      LegacyFoodRecommendationParameterIds.timingSensitivityHighProteinG,
      'timing_sensitivity_thresholds_not_ordered',
    );
    requireAscending(
      LegacyFoodRecommendationParameterIds.moderateFiberSupportG,
      LegacyFoodRecommendationParameterIds.highFiberSupportG,
      'fiber_thresholds_not_ordered',
    );

    final maximumCandidates = uniqueValue(
      LegacyFoodRecommendationParameterIds.maximumCandidates,
    );
    if (maximumCandidates != null &&
        maximumCandidates != maximumCandidates.roundToDouble()) {
      errors.add('maximum_candidates_not_integer');
    }
    if (!supportedTieBreakPolicies.contains(tieBreakPolicy)) {
      errors.add('tie_break_policy_unsupported:$tieBreakPolicy');
    }
    return List<String>.unmodifiable(errors);
  }

  bool get isValidForExecution => validationErrors.isEmpty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'version': version,
    'last_reviewed': lastReviewed,
    'numeric_parameter_count': parameters.length,
    'parameters': parameters
        .map((parameter) => parameter.toJson())
        .toList(growable: false),
    'tie_break_policy': {
      'id': LegacyFoodRecommendationParameterIds.tieBreakPolicy,
      'label': tieBreakLabel,
      'formula_id': tieBreakFormulaId,
      'unit': tieBreakUnit,
      'value': tieBreakPolicy,
      'allowed_values': supportedTieBreakPolicies,
      'source_refs': tieBreakSourceRefs,
      'provenance_status': 'prototypeHeuristic',
      'limitation': tieBreakLimitation,
    },
    'provenance_policy': LegacyFoodRecommendationProvenancePolicy.toJson(
      reviewDate: lastReviewed,
    ),
    'boundary':
        'Legacy compatibility ranking points only; not probability, risk, '
        'confidence, predicted benefit, clinical guidance, or medical advice.',
  };
}
