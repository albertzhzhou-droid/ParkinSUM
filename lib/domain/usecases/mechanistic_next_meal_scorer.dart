import '../entities/mechanistic_candidate_score.dart';
import '../entities/mechanistic_conflict_result.dart';
import '../entities/meal_composition.dart';
import '../entities/rule_explanation.dart';
import '../entities/time_axis_events.dart';
import 'mechanistic_conflict_engine.dart';
import 'meal_composition_normalizer.dart';

/// Description of a candidate food the recommender may evaluate. The caller
/// (UI / orchestrator) is responsible for sourcing these from the regional
/// food library; the scorer does not pick foods for the user.
class CandidateFood {
  final String id;
  final String name;
  final String regionalFoodLibraryRef;
  final List<FoodComponent> components;
  final MealPhysicalForm declaredPhysicalForm;

  const CandidateFood({
    required this.id,
    required this.name,
    required this.regionalFoodLibraryRef,
    required this.components,
    this.declaredPhysicalForm = MealPhysicalForm.unknown,
  });
}

/// Evaluates next-meal candidates inside a user-defined time window.
///
/// Critical contract: the scorer NEVER picks the window. If the window or
/// medication context is missing, every candidate returns
/// `insufficient_context`.
class MechanisticNextMealScorer {
  final MechanisticConflictEngine engine;
  final MealCompositionNormalizer normalizer;

  MechanisticNextMealScorer({
    MechanisticConflictEngine? engine,
    MealCompositionNormalizer? normalizer,
  })  : engine = engine ?? MechanisticConflictEngine(),
        normalizer = normalizer ?? MealCompositionNormalizer();

  List<MechanisticCandidateScore> score({
    required TimeAxisConflictContext baseContext,
    required Map<String, MealComposition> baseMealCompositionsById,
    required List<CandidateFood> candidates,
    UserDefinedMealWindow? userDefinedWindow,
  }) {
    final window = userDefinedWindow ?? baseContext.userDefinedWindow;
    if (window == null) {
      return candidates
          .map((c) => _insufficient(c,
              window: _placeholderWindow(),
              reason: 'user_defined_window_missing'))
          .toList(growable: false);
    }
    if (baseContext.medicationEvents.isEmpty) {
      return candidates
          .map((c) => _insufficient(c,
              window: window, reason: 'medication_context_invalid'))
          .toList(growable: false);
    }

    final scores = <MechanisticCandidateScore>[];
    for (final candidate in candidates) {
      scores.add(_scoreOne(
        candidate: candidate,
        baseContext: baseContext,
        baseMealCompositionsById: baseMealCompositionsById,
        userDefinedWindow: window,
      ));
    }

    // Rank ascending by conflict overlap (lower modeled overlap = better
    // match within the user's window).
    scores.sort((a, b) {
      final byOverlap =
          a.conflictOverlapScore.compareTo(b.conflictOverlapScore);
      if (byOverlap != 0) return byOverlap;
      return b.nutritionDataCompleteness.compareTo(a.nutritionDataCompleteness);
    });
    return List.unmodifiable(scores);
  }

  MechanisticCandidateScore _scoreOne({
    required CandidateFood candidate,
    required TimeAxisConflictContext baseContext,
    required Map<String, MealComposition> baseMealCompositionsById,
    required UserDefinedMealWindow userDefinedWindow,
  }) {
    final composition = normalizer.normalize(
      mealId: 'candidate_${candidate.id}',
      components: candidate.components,
      declaredPhysicalForm: candidate.declaredPhysicalForm,
    );

    // Build hypothetical timelines at window start and midpoint; pick the
    // worse-overlap of the two to keep the score conservative without
    // searching the entire continuum.
    final candidateA = _hypotheticalContext(
      baseContext: baseContext,
      candidate: candidate,
      compositionId: composition.id,
      candidateMinute: userDefinedWindow.window.startMinute,
    );
    final candidateB = _hypotheticalContext(
      baseContext: baseContext,
      candidate: candidate,
      compositionId: composition.id,
      candidateMinute: userDefinedWindow.midpointMinute,
    );

    final mergedCompositions = <String, MealComposition>{
      ...baseMealCompositionsById,
      composition.id: composition,
    };

    final resultA = engine.evaluate(
      context: candidateA,
      mealCompositionsById: mergedCompositions,
      resultId: 'cand_${candidate.id}_start',
    );
    final resultB = engine.evaluate(
      context: candidateB,
      mealCompositionsById: mergedCompositions,
      resultId: 'cand_${candidate.id}_mid',
    );

    final worse = resultA.interactionScore >= resultB.interactionScore
        ? resultA
        : resultB;

    final overlap = worse.interactionScore;
    final uncertaintyPenalty = switch (worse.confidenceBand) {
      ConfidenceBand.high => 0.0,
      ConfidenceBand.medium => 0.1,
      ConfidenceBand.low => 0.25,
      ConfidenceBand.insufficient => 0.5,
    };
    final compatibility =
        (1.0 - overlap - 0.2 * uncertaintyPenalty).clamp(0.0, 1.0);

    final explanation = <String>[
      'Within the time window you provided, this candidate has a modeled '
          'overlap of ${(overlap * 100).toStringAsFixed(0)}% with the levodopa '
          'absorption opportunity in the educational simulation.',
      'Modeled meal physical form: ${composition.mealPhysicalForm.name}.',
      'Composition completeness: '
          '${(composition.compositionCompleteness * 100).toStringAsFixed(0)}%.',
      if (worse.primaryDrivers.isNotEmpty)
        'Primary modeled drivers: ${worse.primaryDrivers.join(', ')}.',
      'This is not dietary, medication, or clinical advice.',
    ];

    return MechanisticCandidateScore(
      candidateFoodId: candidate.id,
      candidateName: candidate.name,
      regionalFoodLibraryRef: candidate.regionalFoodLibraryRef,
      userDefinedWindow: userDefinedWindow,
      modelCompatibilityScore: compatibility,
      conflictOverlapScore: overlap,
      uncertaintyPenalty: uncertaintyPenalty,
      nutritionDataCompleteness: composition.compositionCompleteness,
      confidenceBand: worse.confidenceBand,
      explanation: List.unmodifiable(explanation),
      sourceRefs: worse.sourceRefs,
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      notAdviceText: RuleExplanation.defaultNotAdvice,
      upstreamResult: worse,
      insufficientContext: false,
    );
  }

  MechanisticCandidateScore _insufficient(
    CandidateFood candidate, {
    required UserDefinedMealWindow window,
    required String reason,
  }) {
    return MechanisticCandidateScore(
      candidateFoodId: candidate.id,
      candidateName: candidate.name,
      regionalFoodLibraryRef: candidate.regionalFoodLibraryRef,
      userDefinedWindow: window,
      modelCompatibilityScore: 0.0,
      conflictOverlapScore: 0.0,
      uncertaintyPenalty: 1.0,
      nutritionDataCompleteness: 0.0,
      confidenceBand: ConfidenceBand.insufficient,
      explanation: [
        'The next-meal recommender does not produce a score for this '
            'candidate because: $reason.',
        'This is not dietary, medication, or clinical advice.',
      ],
      sourceRefs: const [
        'src.dailymed.sinemet.label',
        'src.fda.cds.guidance.2022',
      ],
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      notAdviceText: RuleExplanation.defaultNotAdvice,
      insufficientContext: true,
    );
  }

  UserDefinedMealWindow _placeholderWindow() => const UserDefinedMealWindow(
        window: TimelineWindow(startMinute: 0, endMinute: 0),
        source: 'placeholder_no_user_window',
      );

  TimeAxisConflictContext _hypotheticalContext({
    required TimeAxisConflictContext baseContext,
    required CandidateFood candidate,
    required String compositionId,
    required int candidateMinute,
  }) {
    final mealEvents = [
      ...baseContext.mealEvents,
      MealTimelineEvent(
        id: 'hypothetical_${candidate.id}_$candidateMinute',
        minute: candidateMinute,
        compositionId: compositionId,
        physicalForm: candidate.declaredPhysicalForm,
      ),
    ];
    return TimeAxisConflictContext(
      referenceMinute: baseContext.referenceMinute,
      medicationEvents: baseContext.medicationEvents,
      mealEvents: mealEvents,
      foodComponentEvents: baseContext.foodComponentEvents,
      userDefinedWindow: baseContext.userDefinedWindow,
      missingFields: baseContext.missingFields,
    );
  }
}
