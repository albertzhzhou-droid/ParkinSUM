import '../entities/absorption_opportunity.dart';
import '../entities/amino_acid_competition.dart';
import '../entities/gastric_emptying_profile.dart';
import '../entities/mechanistic_conflict_result.dart';
import '../entities/meal_composition.dart';
import '../entities/rule_explanation.dart';
import '../entities/time_axis_events.dart';
import '../entities/gastric_emptying_parameters.dart';
import 'amino_acid_competition_model.dart';
import 'gastric_emptying_model.dart';
import 'levodopa_absorption_opportunity_model.dart';

/// Top-level deterministic composer.
///
/// Inputs: a `TimeAxisConflictContext` plus a map from `compositionId` to
/// `MealComposition`. The engine never invents either; if context is
/// insufficient it returns an `insufficient*` result with a structured
/// explanation rather than a number.
class MechanisticConflictEngine {
  final GastricEmptyingModel gastricEmptyingModel;
  final LevodopaAbsorptionOpportunityModel absorptionModel;
  final AminoAcidCompetitionModel competitionModel;

  MechanisticConflictEngine({
    GastricEmptyingModel? gastricEmptyingModel,
    LevodopaAbsorptionOpportunityModel? absorptionModel,
    AminoAcidCompetitionModel? competitionModel,
    GastricEmptyingParameterSet? gastricEmptyingParameters,
  })  : gastricEmptyingModel = gastricEmptyingModel ??
            GastricEmptyingModel(parameters: gastricEmptyingParameters),
        absorptionModel =
            absorptionModel ?? LevodopaAbsorptionOpportunityModel(),
        competitionModel = competitionModel ?? AminoAcidCompetitionModel();

  MechanisticConflictResult evaluate({
    required TimeAxisConflictContext context,
    required Map<String, MealComposition> mealCompositionsById,
    String resultId = 'mechanistic_result',
  }) {
    // No valid medication event = insufficient medication context.
    if (context.medicationEvents.isEmpty) {
      return MechanisticConflictResult.insufficientContext(
        id: resultId,
        reason: MechanisticInteractionType.insufficientMedicationContext,
        missingInputs: const ['medication_timeline_event'],
        sourceRefs: const [
          'src.dailymed.sinemet.label',
          'src.fda.cds.guidance.2022',
        ],
      );
    }

    // Levodopa-specific scoring: ONLY levodopa events drive the food-levodopa
    // interaction score. Non-levodopa events (e.g. iron, MAO-B inhibitors) are
    // excluded here — they are handled by other rule layers, not this PK proxy.
    final levodopaEvents = context.medicationEvents
        .where((e) => e.isLevodopaContext)
        .toList(growable: false);
    final scoringEvents = levodopaEvents.isNotEmpty
        ? levodopaEvents
        : <MedicationTimelineEvent>[context.medicationEvents.first];

    // The primary single-dose window for the no-meal path uses the first
    // scoring event (deterministic order is preserved by the time-axis builder).
    final med = scoringEvents.first;

    // No meal event = no food-medication interaction modeled.
    if (context.mealEvents.isEmpty) {
      final absorption =
          absorptionModel.build(medication: med, overlappingMealProfile: null);
      final explanation = _buildExplanation(
        resultId: resultId,
        layerTraces: [
          _trace('time_axis', ['medication_event'], const ['no_meal_overlap'],
              'no meal', 'No meal events on the timeline.'),
          _trace(
              'absorption_opportunity',
              ['medication.release_type', 'medication.minute'],
              absorption.assumptions,
              absorption.uncertaintyBand.name,
              'Absorption opportunity window built from medication event '
                  'without an overlapping meal profile.'),
        ],
        inputFieldsUsed: const [
          'medication_events[0]',
        ],
        missingInputs: ['meal_events'],
        sourceRefs: absorption.sourceRefs,
      );
      return MechanisticConflictResult(
        id: resultId,
        interactionType: MechanisticInteractionType.noModeledInteraction,
        interactionScore: 0.0,
        severityBand: SeverityBand.none,
        confidenceBand: ConfidenceBand.medium,
        primaryDrivers: const ['no_meal_overlap'],
        modeledTimelineWindows: [absorption.window],
        uncertaintyReasons: const ['no_overlapping_meal_profile'],
        sourceRefs: absorption.sourceRefs,
        limitationText: MechanisticExplanation.defaultLimitation,
        safetyBoundary: RuleExplanation.defaultSafetyBoundary,
        notAdviceText: RuleExplanation.defaultNotAdvice,
        explanation: explanation,
        primaryEmptyingProfile: null,
        absorptionOpportunityWindow: absorption,
        competitionTimeline: null,
      );
    }

    // Multi-dose time axis: evaluate EACH levodopa dose independently against
    // the meal timeline, then aggregate with deterministic MAX-OVERLAP — the
    // highest-overlap dose drives the primary score (a high-overlap dose is
    // never averaged away by lower-overlap doses).
    final evaluations = <_MedEventEvaluation>[];
    final missingCompositionIds = <String>{};
    for (final event in scoringEvents) {
      final eval = _evaluateMedicationEvent(
        med: event,
        context: context,
        mealCompositionsById: mealCompositionsById,
      );
      if (eval == null) {
        // Record which meal composition was unavailable for this dose.
        final mealForEvent = _primaryMealFor(event, context);
        if (mealForEvent != null) {
          missingCompositionIds.add(mealForEvent.compositionId);
        }
        continue;
      }
      evaluations.add(eval);
    }

    if (evaluations.isEmpty) {
      return MechanisticConflictResult.insufficientContext(
        id: resultId,
        reason: MechanisticInteractionType.insufficientMealContext,
        missingInputs: missingCompositionIds
            .map((id) => 'meal_composition($id)')
            .toList(growable: false),
        sourceRefs: const ['src.hens.foodphysical.2024'],
      );
    }

    // Deterministic max-overlap selection. Ties broken by earliest dose minute
    // so the result is stable.
    evaluations.sort((a, b) {
      final byScore = b.interactionScore.compareTo(a.interactionScore);
      if (byScore != 0) return byScore;
      return a.med.minute.compareTo(b.med.minute);
    });
    final primary = evaluations.first;

    // Build per-event traces (kept in deterministic dose-time order).
    final perEventOrdered = [...evaluations]
      ..sort((a, b) => a.med.minute.compareTo(b.med.minute));
    final perEventTraces = perEventOrdered
        .map((e) => MechanisticPerEventTrace(
              medicationEventId: e.med.id,
              medicationMinute: e.med.minute,
              isLevodopa: e.med.isLevodopaContext,
              releaseType: e.med.context.releaseType,
              interactionScore: e.interactionScore,
              competitionBand: e.competition.competitionBand.name,
              delayedArrivalLikelihood:
                  e.absorption.delayedArrivalLikelihood.name,
              isPrimary: identical(e, primary),
              sourceRefs: <String>{
                ...e.emptyingProfile.sourceRefs,
                ...e.absorption.sourceRefs,
                ...e.competition.sourceRefs,
              }.toList(growable: false),
              uncertaintyReasons: <String>[
                if (e.emptyingProfile.uncertaintyBand != UncertaintyBand.narrow)
                  'gastric_emptying_${e.emptyingProfile.uncertaintyBand.name}',
                ...e.absorption.missingInputs
                    .map((m) => 'absorption_missing:$m'),
              ],
            ))
        .toList(growable: false);

    final composition = primary.composition;
    final residual = primary.residual;
    final emptyingProfile = primary.emptyingProfile;
    final absorption = primary.absorption;
    final competition = primary.competition;
    final interactionScore = primary.interactionScore;

    final severity = _severity(interactionScore, competition.competitionBand,
        absorption.delayedArrivalLikelihood);

    final confidence = _confidence(
      compositionCompleteness: composition.compositionCompleteness,
      emptyingUncertainty: emptyingProfile.uncertaintyBand,
      missingTimelineFields: context.missingFields.length,
      competitionUnknown:
          competition.competitionBand == CompetitionBand.unknown,
    );

    final drivers = <String>[];
    if (competition.competitionBand == CompetitionBand.high) {
      drivers.add('amino_acid_competition_proxy_high');
    } else if (competition.competitionBand == CompetitionBand.moderate) {
      drivers.add('amino_acid_competition_proxy_moderate');
    }
    if (absorption.delayedArrivalLikelihood == DelayedArrivalLikelihood.high) {
      drivers.add('delayed_gastric_arrival_high');
    } else if (absorption.delayedArrivalLikelihood ==
        DelayedArrivalLikelihood.moderate) {
      drivers.add('delayed_gastric_arrival_moderate');
    }
    if (residual > 0.3) drivers.add('overlapping_meal_residual_stomach_load');

    final interactionType = drivers.contains('delayed_gastric_arrival_high')
        ? MechanisticInteractionType.delayedGastricArrival
        : (competition.competitionBand == CompetitionBand.high ||
                competition.competitionBand == CompetitionBand.moderate)
            ? MechanisticInteractionType.aminoAcidCompetitionProxy
            : (interactionScore > 0.05)
                ? MechanisticInteractionType.foodLevodopaTimingOverlap
                : MechanisticInteractionType.noModeledInteraction;

    final uncertaintyReasons = <String>[
      if (composition.compositionCompleteness < 0.99)
        'meal_composition_incomplete',
      if (emptyingProfile.uncertaintyBand != UncertaintyBand.narrow)
        'gastric_emptying_uncertainty_${emptyingProfile.uncertaintyBand.name}',
      if (residual > 0.1) 'overlapping_meal_residual_load',
      if (absorption.missingInputs.isNotEmpty)
        ...absorption.missingInputs.map((m) => 'absorption_missing:$m'),
    ];

    final sourceRefs = <String>{
      ...emptyingProfile.sourceRefs,
      ...absorption.sourceRefs,
      ...competition.sourceRefs,
    }.toList(growable: false);

    final explanation = _buildExplanation(
      resultId: resultId,
      layerTraces: [
        _trace(
            'meal_composition',
            [
              'meal_composition.protein_grams',
              'meal_composition.fat_grams',
              'meal_composition.fiber_grams',
              'meal_composition.total_calories'
            ],
            [
              'composition_completeness=${composition.compositionCompleteness.toStringAsFixed(2)}'
            ],
            composition.compositionCompleteness < 1.0
                ? 'composition_incomplete'
                : 'composition_complete',
            'Meal composition normalized; bands and missing fields recorded.'),
        _trace(
            'gastric_emptying',
            [
              'meal_composition.fat',
              'meal_composition.fiber',
              'meal_composition.calories',
              'overlapping_meals'
            ],
            emptyingProfile.assumptions,
            emptyingProfile.uncertaintyBand.name,
            'Gastric emptying profile built per-component; modifiers applied.'),
        _trace(
            'absorption_opportunity',
            [
              'medication.release_type',
              'medication.minute',
              'gastric_emptying_profile.residual'
            ],
            absorption.assumptions,
            absorption.uncertaintyBand.name,
            'Absorption opportunity window estimated.'),
        _trace(
            'amino_acid_competition',
            [
              'meal_composition.protein_grams',
              'gastric_emptying_profile.arrival_rate'
            ],
            competition.assumptions,
            competition.uncertaintyBand.name,
            'Competition pressure timeline integrated over absorption window.'),
      ],
      inputFieldsUsed: const [
        'medication_events[0].context',
        'meal_events[primary]',
        'meal_composition',
        'overlapping_meal_events',
      ],
      missingInputs: [
        ...context.missingFields,
        ...composition.missingFields,
        ...emptyingProfile.missingInputs,
      ],
      sourceRefs: sourceRefs,
    );

    return MechanisticConflictResult(
      id: resultId,
      interactionType: interactionType,
      interactionScore: interactionScore,
      severityBand: severity,
      confidenceBand: confidence,
      primaryDrivers: List.unmodifiable(drivers),
      modeledTimelineWindows: List.unmodifiable([
        emptyingProfile.peakEmptyingWindow,
        absorption.window,
      ]),
      uncertaintyReasons: List.unmodifiable(uncertaintyReasons),
      sourceRefs: sourceRefs,
      limitationText: MechanisticExplanation.defaultLimitation,
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      notAdviceText: RuleExplanation.defaultNotAdvice,
      explanation: explanation,
      primaryEmptyingProfile: emptyingProfile,
      absorptionOpportunityWindow: absorption,
      competitionTimeline: competition,
      perEventTraces: perEventTraces,
    );
  }

  /// Most-recent meal at or before the dose time (within a 180-min lookahead),
  /// falling back to the earliest meal. Pure selection — no side effects.
  ///
  /// Deterministic and independent of input order: meal events are sorted by
  /// minute (ties broken by id) before selection, so an unsorted
  /// `mealEvents` list always yields the same primary meal.
  MealTimelineEvent? _primaryMealFor(
    MedicationTimelineEvent med,
    TimeAxisConflictContext context,
  ) {
    if (context.mealEvents.isEmpty) return null;
    final sorted = [...context.mealEvents]..sort((a, b) {
        final byMinute = a.minute.compareTo(b.minute);
        return byMinute != 0 ? byMinute : a.id.compareTo(b.id);
      });
    MealTimelineEvent? primaryMeal;
    for (final m in sorted) {
      if (m.minute <= med.minute + 180) primaryMeal = m;
    }
    // Fallback to the earliest meal (deterministic via the sort above).
    return primaryMeal ?? sorted.first;
  }

  /// Evaluate a single dose against the meal timeline. Returns null when the
  /// dose's primary meal composition is unavailable (recorded as missing by the
  /// caller rather than fabricated).
  _MedEventEvaluation? _evaluateMedicationEvent({
    required MedicationTimelineEvent med,
    required TimeAxisConflictContext context,
    required Map<String, MealComposition> mealCompositionsById,
  }) {
    final primaryMeal = _primaryMealFor(med, context);
    if (primaryMeal == null) return null;
    final composition = mealCompositionsById[primaryMeal.compositionId];
    if (composition == null) return null;

    // Cumulative overlap from earlier meals (residual stomach load).
    var residual = 0.0;
    for (final earlier in context.mealEvents) {
      if (earlier.id == primaryMeal.id) continue;
      if (earlier.minute >= primaryMeal.minute) continue;
      final earlierComp = mealCompositionsById[earlier.compositionId];
      if (earlierComp == null) continue;
      final earlierProfile = gastricEmptyingModel.build(
        mealId: earlier.id,
        mealStartMinute: earlier.minute,
        composition: earlierComp,
      );
      final tSinceEarlier = primaryMeal.minute - earlier.minute;
      residual +=
          earlierProfile.remainingFractionAt(tSinceEarlier).clamp(0.0, 1.0);
    }
    if (residual > 1.0) residual = 1.0;

    final emptyingProfile = gastricEmptyingModel.build(
      mealId: primaryMeal.id,
      mealStartMinute: primaryMeal.minute,
      composition: composition,
      overlappingResidualLoad: residual,
    );
    final absorption = absorptionModel.build(
      medication: med,
      overlappingMealProfile: emptyingProfile,
    );
    final competition = competitionModel.build(
      mealComposition: composition,
      mealEmptyingProfile: emptyingProfile,
      absorptionWindow: absorption,
      mealStartMinute: primaryMeal.minute,
    );
    final interactionScore = _composeInteractionScore(
      absorption: absorption,
      competition: competition,
      emptyingProfile: emptyingProfile,
    );
    return _MedEventEvaluation(
      med: med,
      primaryMeal: primaryMeal,
      composition: composition,
      residual: residual,
      emptyingProfile: emptyingProfile,
      absorption: absorption,
      competition: competition,
      interactionScore: interactionScore,
    );
  }

  double _composeInteractionScore({
    required AbsorptionOpportunityWindow absorption,
    required CompetitionPressureTimeline competition,
    required GastricEmptyingProfile emptyingProfile,
  }) {
    final competitionContribution = competition.overlapWithAbsorptionWindow;
    var delayContribution = 0.0;
    switch (absorption.delayedArrivalLikelihood) {
      case DelayedArrivalLikelihood.high:
        delayContribution = 0.5;
        break;
      case DelayedArrivalLikelihood.moderate:
        delayContribution = 0.25;
        break;
      case DelayedArrivalLikelihood.low:
        delayContribution = 0.05;
        break;
      case DelayedArrivalLikelihood.unknown:
        delayContribution = 0.0;
        break;
    }
    final raw = 0.6 * competitionContribution + 0.4 * delayContribution;
    return raw.clamp(0.0, 1.0);
  }

  SeverityBand _severity(double score, CompetitionBand competition,
      DelayedArrivalLikelihood delay) {
    if (competition == CompetitionBand.unknown) return SeverityBand.unknown;
    if (score >= 0.35) return SeverityBand.high;
    if (score >= 0.15) return SeverityBand.moderate;
    if (score > 0.0) return SeverityBand.low;
    return SeverityBand.none;
  }

  ConfidenceBand _confidence({
    required double compositionCompleteness,
    required UncertaintyBand emptyingUncertainty,
    required int missingTimelineFields,
    required bool competitionUnknown,
  }) {
    if (compositionCompleteness < 0.4) return ConfidenceBand.insufficient;
    // When the competition layer cannot be scored (e.g. protein grams
    // missing), the engine must not pretend medium confidence.
    if (competitionUnknown) return ConfidenceBand.low;
    if (missingTimelineFields >= 3) return ConfidenceBand.low;
    if (emptyingUncertainty == UncertaintyBand.veryWide) {
      return ConfidenceBand.low;
    }
    if (emptyingUncertainty == UncertaintyBand.wide) {
      return ConfidenceBand.medium;
    }
    if (compositionCompleteness < 0.85) return ConfidenceBand.medium;
    return ConfidenceBand.high;
  }

  MechanisticLayerTrace _trace(
    String layer,
    List<String> inputs,
    List<String> assumptions,
    String uncertainty,
    String description,
  ) {
    return MechanisticLayerTrace(
      layer: layer,
      inputsUsed: List.unmodifiable(inputs),
      assumptionsApplied: List.unmodifiable(assumptions),
      uncertaintyContribution: uncertainty,
      description: description,
    );
  }

  MechanisticExplanation _buildExplanation({
    required String resultId,
    required List<MechanisticLayerTrace> layerTraces,
    required List<String> inputFieldsUsed,
    required Iterable<String> missingInputs,
    required List<String> sourceRefs,
  }) {
    return MechanisticExplanation(
      resultId: resultId,
      layerTraces: List.unmodifiable(layerTraces),
      inputFieldsUsed: List.unmodifiable(inputFieldsUsed),
      missingOrUncertainInputs: List.unmodifiable(missingInputs.toSet()),
      sourceRefs: List.unmodifiable(sourceRefs),
      limitationText: MechanisticExplanation.defaultLimitation,
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      notAdviceText: RuleExplanation.defaultNotAdvice,
    );
  }
}

/// Internal per-dose evaluation bundle for the multi-dose time axis.
class _MedEventEvaluation {
  final MedicationTimelineEvent med;
  final MealTimelineEvent primaryMeal;
  final MealComposition composition;
  final double residual;
  final GastricEmptyingProfile emptyingProfile;
  final AbsorptionOpportunityWindow absorption;
  final CompetitionPressureTimeline competition;
  final double interactionScore;

  const _MedEventEvaluation({
    required this.med,
    required this.primaryMeal,
    required this.composition,
    required this.residual,
    required this.emptyingProfile,
    required this.absorption,
    required this.competition,
    required this.interactionScore,
  });
}
