import '../entities/absorption_opportunity.dart';
import '../entities/algorithm_component_identity_witness.dart';
import '../entities/amino_acid_competition.dart';
import '../entities/gastric_emptying_profile.dart';
import '../entities/mechanistic_conflict_result.dart';
import '../entities/mechanistic_medication_applicability.dart';
import '../entities/meal_composition.dart';
import '../entities/rule_explanation.dart';
import '../entities/time_axis_events.dart';
import '../entities/gastric_emptying_parameters.dart';
import 'amino_acid_competition_model.dart';
import 'gastric_emptying_model.dart';
import 'levodopa_absorption_opportunity_model.dart';
import 'meal_composition_normalizer.dart';
import 'medication_entry_validator.dart';

/// Top-level deterministic composer.
///
/// Inputs: a `TimeAxisConflictContext` plus a map from `compositionId` to
/// `MealComposition`. The engine never invents either; if context is
/// insufficient it returns an `insufficient*` result with a structured
/// explanation rather than a number.
class MechanisticConflictEngine with RegisteredAlgorithmComponentIdentity {
  static const MechanisticMedicationApplicabilityPolicy _applicabilityPolicy =
      MechanisticMedicationApplicabilityPolicy();
  static final MedicationEntryValidator _medicationEntryValidator =
      MedicationEntryValidator();

  final GastricEmptyingModel gastricEmptyingModel;
  final LevodopaAbsorptionOpportunityModel absorptionModel;
  final AminoAcidCompetitionModel competitionModel;

  MechanisticConflictEngine({
    GastricEmptyingModel? gastricEmptyingModel,
    LevodopaAbsorptionOpportunityModel? absorptionModel,
    AminoAcidCompetitionModel? competitionModel,
    GastricEmptyingParameterSet? gastricEmptyingParameters,
  }) : gastricEmptyingModel =
           gastricEmptyingModel ??
           GastricEmptyingModel(parameters: gastricEmptyingParameters),
       absorptionModel =
           absorptionModel ?? LevodopaAbsorptionOpportunityModel(),
       competitionModel = competitionModel ?? AminoAcidCompetitionModel();

  MechanisticConflictResult evaluate({
    required TimeAxisConflictContext context,
    required Map<String, MealComposition> mealCompositionsById,
    String resultId = 'mechanistic_result',
    String? preferredMealId,
  }) {
    final directTimelineIntegrity = _timelineIdentityIntegrityReasons(context);
    final timelineIdentityFailures = <String>{
      ...context.missingFields.where(
        (field) =>
            field.startsWith('timeline.event_id_collision') ||
            field.startsWith('medication.event_id_duplicate') ||
            field.startsWith('meal.event_id_duplicate'),
      ),
      ...directTimelineIntegrity.integrityReasons,
    }.toList(growable: false)..sort();
    if (timelineIdentityFailures.isNotEmpty) {
      return MechanisticConflictResult.blockedIntegrity(
        id: resultId,
        reason: MechanisticInteractionType.insufficientMedicationContext,
        integrityReasons: timelineIdentityFailures,
        sourceRefs: const [
          'src.fda.cds.guidance.2022',
          'src.internal.prototype.heuristic',
        ],
      );
    }

    // The time-axis builder intentionally drops events whose context or time
    // is unusable. If even one such medication event or meal timestamp exists,
    // the remaining events are not a complete interaction timeline: the
    // omitted event could be the highest-overlap one. Fail closed before
    // applicability selection or curve construction.
    final blockingTimelineFields = <String>{
      ...context.missingFields.where(
        (field) =>
            field.startsWith('medication.') ||
            field.startsWith('meal.') ||
            field.startsWith('timeline.'),
      ),
      ...directTimelineIntegrity.missingReasons,
    }.toList(growable: false)..sort();
    if (blockingTimelineFields.isNotEmpty) {
      final hasMealBlocker = blockingTimelineFields.any(
        (field) => field.startsWith('meal.') || field.startsWith('timeline.'),
      );
      final hasMedicationBlocker = blockingTimelineFields.any(
        (field) =>
            field.startsWith('medication.') || field.startsWith('timeline.'),
      );
      return MechanisticConflictResult.insufficientContext(
        id: resultId,
        reason: hasMedicationBlocker
            ? MechanisticInteractionType.insufficientMedicationContext
            : MechanisticInteractionType.insufficientMealContext,
        missingInputs: blockingTimelineFields,
        sourceRefs: [
          if (hasMedicationBlocker) ...[
            'src.dailymed.sinemet.label',
            'src.fda.cds.guidance.2022',
          ],
          if (hasMealBlocker) 'src.hens.foodphysical.2024',
        ],
      );
    }

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

    final normalizedMedicationIntegrityFailures = <String>{};
    for (final event in context.medicationEvents) {
      normalizedMedicationIntegrityFailures.addAll(
        _normalizedMedicationIntegrityReasons(event),
      );
    }
    if (normalizedMedicationIntegrityFailures.isNotEmpty) {
      final reasons = normalizedMedicationIntegrityFailures.toList(
        growable: false,
      )..sort();
      return MechanisticConflictResult.blockedIntegrity(
        id: resultId,
        reason: MechanisticInteractionType.insufficientMedicationContext,
        integrityReasons: reasons,
        sourceRefs: const [
          'src.dailymed.sinemet.label',
          'src.fda.cds.guidance.2022',
        ],
      );
    }

    // Levodopa-specific scoring: ONLY levodopa events drive the food-levodopa
    // interaction score. Non-levodopa events (e.g. iron, MAO-B inhibitors) are
    // excluded here — they are handled by other rule layers, not this PK proxy.
    final medicationApplicability = _applicabilityPolicy.evaluateContexts(
      context.medicationEvents.map((event) => event.context),
    );
    if (!medicationApplicability.applicable) {
      const sourceRefs = [
        'src.dailymed.sinemet.label',
        'src.fda.cds.guidance.2022',
      ];
      if (medicationApplicability.status ==
          MechanisticMedicationApplicabilityStatus.notApplicable) {
        return MechanisticConflictResult.notApplicable(
          id: resultId,
          reason: MechanisticInteractionType.insufficientMedicationContext,
          reasonCodes: medicationApplicability.reasonCodes,
          sourceRefs: sourceRefs,
        );
      }
      return MechanisticConflictResult.insufficientContext(
        id: resultId,
        reason: MechanisticInteractionType.insufficientMedicationContext,
        missingInputs: medicationApplicability.reasonCodes,
        sourceRefs: sourceRefs,
      );
    }

    final scoringEvents = context.medicationEvents
        .where((e) => e.isLevodopaContext)
        .toList(growable: false);

    // An explicitly requested meal must exist. Candidate scoring uses this to
    // bind each hypothetical meal to its evaluation rather than silently
    // falling back to a historical meal outside the ordinary lookahead window.
    if (preferredMealId != null &&
        !context.mealEvents.any((meal) => meal.id == preferredMealId)) {
      return MechanisticConflictResult.insufficientContext(
        id: resultId,
        reason: MechanisticInteractionType.insufficientMealContext,
        missingInputs: ['meal_event($preferredMealId)'],
        sourceRefs: const ['src.hens.foodphysical.2024'],
      );
    }

    // Absence of a recorded meal is missing context, not evidence that no
    // food-medication interaction exists. Abstain without building a curve.
    if (context.mealEvents.isEmpty) {
      return MechanisticConflictResult.insufficientContext(
        id: resultId,
        reason: MechanisticInteractionType.insufficientMealContext,
        missingInputs: const ['meal_events'],
        sourceRefs: const ['src.hens.foodphysical.2024'],
      );
    }

    // Resolve the complete set of meal compositions that can affect any
    // applicable dose before invoking a numerical layer. This includes each
    // dose's target meal, its residual predecessors, and the already-started
    // meal context that may affect the dose-time absorption window. A future
    // target meal can contribute competition after it starts, but can never be
    // treated as stomach contents at the earlier medication time.
    // Missing/empty compositions are unknown evidence, not zero intake, so one
    // unusable relevant meal makes the whole timeline insufficient.
    final relevantMealEvents = <String, MealTimelineEvent>{};
    final primaryMealIds = <String>{};
    final missingDoseTimeContexts = <String>{};
    void includeMealAndResidualPredecessors(MealTimelineEvent target) {
      relevantMealEvents[target.id] = target;
      for (final meal in context.mealEvents) {
        if (meal.minute < target.minute) {
          relevantMealEvents[meal.id] = meal;
        }
      }
    }

    for (final event in scoringEvents) {
      final primaryMeal = _primaryMealFor(
        event,
        context,
        preferredMealId: preferredMealId,
      );
      if (primaryMeal == null) continue;
      primaryMealIds.add(primaryMeal.id);
      includeMealAndResidualPredecessors(primaryMeal);
      final doseTimeMeal = _absorptionMealFor(event, context);
      if (doseTimeMeal == null) {
        missingDoseTimeContexts.add('dose_time_meal_context(${event.id})');
      } else {
        includeMealAndResidualPredecessors(doseTimeMeal);
      }
    }
    final unusableMealInputs = <String>{...missingDoseTimeContexts};
    final integrityFailures = <String>{};
    final canonicalMealCompositionsById = <String, MealComposition>{};
    for (final meal in relevantMealEvents.values) {
      final composition = mealCompositionsById[meal.compositionId];
      if (composition == null) {
        unusableMealInputs.add('meal_composition(${meal.compositionId})');
        continue;
      }
      final integrityReasons = _mealCompositionIntegrityReasons(
        composition,
        expectedId: meal.compositionId,
      );
      if (integrityReasons.isNotEmpty) {
        integrityFailures.addAll(
          integrityReasons.map(
            (reason) => 'meal_composition(${meal.compositionId}).$reason',
          ),
        );
        continue;
      }
      final canonicalComposition = _canonicalCompositionSnapshot(composition);
      canonicalMealCompositionsById[meal.compositionId] = canonicalComposition;
      if (canonicalComposition.foodComponents.isEmpty) {
        unusableMealInputs.add(
          'meal_composition(${meal.compositionId}).food_components',
        );
      }
      if (canonicalComposition.compositionCompleteness <= 0) {
        unusableMealInputs.add(
          'meal_composition(${meal.compositionId}).composition_completeness',
        );
      }
      final protein = canonicalComposition.proteinGrams;
      if (primaryMealIds.contains(meal.id) && protein == null) {
        unusableMealInputs.add(
          'meal_composition(${meal.compositionId}).protein_grams',
        );
      }
    }
    if (integrityFailures.isNotEmpty) {
      final integrityReasons = integrityFailures.toList(growable: false)
        ..sort();
      return MechanisticConflictResult.blockedIntegrity(
        id: resultId,
        reason: MechanisticInteractionType.insufficientMealContext,
        integrityReasons: integrityReasons,
        sourceRefs: const [
          'src.fda.cds.guidance.2022',
          'src.internal.prototype.heuristic',
        ],
      );
    }
    if (unusableMealInputs.isNotEmpty) {
      final missingInputs = unusableMealInputs.toList(growable: false)..sort();
      return MechanisticConflictResult.insufficientContext(
        id: resultId,
        reason: MechanisticInteractionType.insufficientMealContext,
        missingInputs: missingInputs,
        sourceRefs: const ['src.hens.foodphysical.2024'],
      );
    }

    // A recorded meal can supply dose-time gastric context only while the
    // model's own structural residence horizon still contains the dose. An
    // arbitrarily old meal does not prove that no unrecorded food occurred in
    // the intervening interval and therefore cannot be treated as fasting.
    final staleDoseTimeContexts = <String>{};
    for (final event in scoringEvents) {
      final doseTimeMeal = _absorptionMealFor(event, context);
      if (doseTimeMeal == null) continue;
      final composition =
          canonicalMealCompositionsById[doseTimeMeal.compositionId];
      if (composition == null) continue;
      final residual = _residualLoadBeforeMeal(
        target: doseTimeMeal,
        context: context,
        mealCompositionsById: canonicalMealCompositionsById,
      );
      if (residual == null) continue;
      final profile = gastricEmptyingModel.build(
        mealId: doseTimeMeal.id,
        mealStartMinute: doseTimeMeal.minute,
        composition: composition,
        overlappingResidualLoad: residual,
      );
      if (event.minute > profile.mostlyEmptiedWindow.endMinute) {
        staleDoseTimeContexts.add(
          'dose_time_meal_context_stale(${event.id},${doseTimeMeal.id})',
        );
      }
    }
    if (staleDoseTimeContexts.isNotEmpty) {
      final missingInputs = staleDoseTimeContexts.toList(growable: false)
        ..sort();
      return MechanisticConflictResult.insufficientContext(
        id: resultId,
        reason: MechanisticInteractionType.insufficientMealContext,
        missingInputs: missingInputs,
        sourceRefs: const ['src.hens.foodphysical.2024'],
      );
    }

    // Multi-dose time axis: evaluate EACH levodopa dose independently against
    // the meal timeline, then aggregate with deterministic MAX-OVERLAP — the
    // highest-overlap dose drives the primary score (a high-overlap dose is
    // never averaged away by lower-overlap doses).
    final evaluations = <_MedEventEvaluation>[];
    for (final event in scoringEvents) {
      final eval = _evaluateMedicationEvent(
        med: event,
        context: context,
        mealCompositionsById: canonicalMealCompositionsById,
        preferredMealId: preferredMealId,
      );
      if (eval == null) {
        // Defensive fail-closed fallback. The unified preflight above should
        // have resolved every relevant primary composition, but never skip an
        // unexpected missing evaluation and continue with a partial timeline.
        final mealForEvent = _primaryMealFor(
          event,
          context,
          preferredMealId: preferredMealId,
        );
        return MechanisticConflictResult.insufficientContext(
          id: resultId,
          reason: MechanisticInteractionType.insufficientMealContext,
          missingInputs: [
            if (mealForEvent == null)
              'meal_event'
            else
              'meal_composition(${mealForEvent.compositionId})',
          ],
          sourceRefs: const ['src.hens.foodphysical.2024'],
        );
      }
      final providerAvailability = _mergeProviderAvailability([
        eval.emptyingProfile.availability,
        eval.absorption.availability,
        eval.competition.availability,
      ]);
      if (providerAvailability != MechanisticProviderAvailability.available) {
        final reasons = <String>{
          ...eval.emptyingProfile.applicabilityReasons,
          ...eval.absorption.applicabilityReasons,
          ...eval.competition.applicabilityReasons,
        }.toList(growable: false)..sort();
        final sourceRefs = <String>{
          ...eval.emptyingProfile.sourceRefs,
          ...eval.absorption.sourceRefs,
          ...eval.competition.sourceRefs,
        }.toList(growable: false)..sort();
        if (providerAvailability ==
            MechanisticProviderAvailability.blockedIntegrity) {
          return MechanisticConflictResult.blockedIntegrity(
            id: resultId,
            reason: MechanisticInteractionType.insufficientMealContext,
            integrityReasons: reasons,
            sourceRefs: sourceRefs,
          );
        }
        if (providerAvailability ==
            MechanisticProviderAvailability.notApplicable) {
          return MechanisticConflictResult.notApplicable(
            id: resultId,
            reason: MechanisticInteractionType.insufficientMealContext,
            reasonCodes: reasons,
            sourceRefs: sourceRefs,
          );
        }
        return MechanisticConflictResult.insufficientContext(
          id: resultId,
          reason: MechanisticInteractionType.insufficientMealContext,
          missingInputs: reasons,
          sourceRefs: sourceRefs,
        );
      }
      if (eval.competition.competitionBand == CompetitionBand.unknown) {
        return MechanisticConflictResult.insufficientContext(
          id: resultId,
          reason: MechanisticInteractionType.insufficientMealContext,
          missingInputs: <String>{
            'amino_acid_competition.unknown',
            ...eval.composition.missingFields.map(
              (field) => 'meal_composition(${eval.composition.id}).$field',
            ),
          }.toList(growable: false)..sort(),
          sourceRefs: eval.competition.sourceRefs,
        );
      }
      evaluations.add(eval);
    }

    if (evaluations.isEmpty) {
      return MechanisticConflictResult.insufficientContext(
        id: resultId,
        reason: MechanisticInteractionType.insufficientMealContext,
        missingInputs: const ['meal_evaluation'],
        sourceRefs: const ['src.hens.foodphysical.2024'],
      );
    }

    // Deterministic max-overlap selection. Ties broken by earliest dose minute
    // so the result is stable.
    evaluations.sort((a, b) {
      final byScore = b.interactionScore.compareTo(a.interactionScore);
      if (byScore != 0) return byScore;
      final byMinute = a.med.minute.compareTo(b.med.minute);
      return byMinute != 0 ? byMinute : a.med.id.compareTo(b.med.id);
    });
    final primary = evaluations.first;

    // Build per-event traces (kept in deterministic dose-time order).
    final perEventOrdered = [...evaluations]
      ..sort((a, b) {
        final byMinute = a.med.minute.compareTo(b.med.minute);
        return byMinute != 0 ? byMinute : a.med.id.compareTo(b.med.id);
      });
    final perEventTraces = perEventOrdered
        .map(
          (e) => MechanisticPerEventTrace(
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
              if (e.absorption.uncertaintyBand != UncertaintyBand.narrow)
                'absorption_${e.absorption.uncertaintyBand.name}',
              if (e.competition.uncertaintyBand != UncertaintyBand.narrow)
                'competition_${e.competition.uncertaintyBand.name}',
              ...e.absorption.missingInputs.map((m) => 'absorption_missing:$m'),
            ],
            // Medication provenance bridged from CDSS metadata (when present;
            // null/0/false otherwise). Provenance only — never a dose.
            releaseTypeSource: e.med.context.metadata?.releaseTypeSource,
            doseForm: e.med.context.metadata?.doseForm,
            route: e.med.context.metadata?.route,
            levodopaComponentPresent:
                e.med.context.metadata?.levodopaComponent != null,
            combinationComponentCount:
                e.med.context.metadata?.combinationComponents.length ?? 0,
            labelSectionRefCount:
                e.med.context.metadata?.labelSectionRefs.length ?? 0,
            medicationSourceSystem: e.med.context.metadata?.sourceSystem,
            medicationSourceDocId: e.med.context.metadata?.sourceDocId,
            medicationMetadataCompleteness:
                e.med.context.metadata?.metadataCompleteness,
          ),
        )
        .toList(growable: false);

    final composition = primary.composition;
    final residual = primary.residual;
    final emptyingProfile = primary.emptyingProfile;
    final absorption = primary.absorption;
    final competition = primary.competition;
    final interactionScore = primary.interactionScore;

    final severity = _severity(
      interactionScore,
      competition.competitionBand,
      absorption.delayedArrivalLikelihood,
    );

    final consumedUpstreamUncertainty = _widestUncertainty([
      emptyingProfile.uncertaintyBand,
      absorption.uncertaintyBand,
      competition.uncertaintyBand,
    ]);
    final confidence = _confidence(
      compositionCompleteness: composition.compositionCompleteness,
      consumedUpstreamUncertainty: consumedUpstreamUncertainty,
      missingTimelineFields: context.missingFields.length,
      competitionUnknown:
          competition.competitionBand == CompetitionBand.unknown,
    );
    if (confidence == ConfidenceBand.insufficient) {
      return MechanisticConflictResult.insufficientContext(
        id: resultId,
        reason: MechanisticInteractionType.insufficientMealContext,
        missingInputs: <String>{
          'model_confidence.insufficient',
          ...composition.missingFields.map(
            (field) => 'meal_composition(${composition.id}).$field',
          ),
        }.toList(growable: false)..sort(),
        sourceRefs: <String>{
          ...emptyingProfile.sourceRefs,
          ...absorption.sourceRefs,
          ...competition.sourceRefs,
        }.toList(growable: false),
      );
    }

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
      if (absorption.uncertaintyBand != UncertaintyBand.narrow)
        'absorption_uncertainty_${absorption.uncertaintyBand.name}',
      if (competition.uncertaintyBand != UncertaintyBand.narrow)
        'competition_uncertainty_${competition.uncertaintyBand.name}',
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
            'meal_composition.total_calories',
          ],
          [
            'composition_completeness=${composition.compositionCompleteness.toStringAsFixed(2)}',
          ],
          composition.compositionCompleteness < 1.0
              ? 'composition_incomplete'
              : 'composition_complete',
          'Meal composition normalized; bands and missing fields recorded.',
        ),
        _trace(
          'gastric_emptying',
          [
            'meal_composition.fat',
            'meal_composition.fiber',
            'meal_composition.calories',
            'overlapping_meals',
          ],
          emptyingProfile.assumptions,
          emptyingProfile.uncertaintyBand.name,
          'Gastric emptying profile built per-component; modifiers applied.',
        ),
        _trace(
          'absorption_opportunity',
          [
            'medication.release_type',
            'medication.minute',
            'gastric_emptying_profile.residual',
          ],
          absorption.assumptions,
          absorption.uncertaintyBand.name,
          'Absorption opportunity window estimated.',
        ),
        _trace(
          'amino_acid_competition',
          [
            'meal_composition.protein_grams',
            'gastric_emptying_profile.arrival_rate',
          ],
          competition.assumptions,
          competition.uncertaintyBand.name,
          'Competition pressure timeline integrated over absorption window.',
        ),
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

  static ({Set<String> integrityReasons, Set<String> missingReasons})
  _timelineIdentityIntegrityReasons(TimeAxisConflictContext context) {
    final integrityReasons = <String>{};
    final missingReasons = <String>{};
    final medicationIds = <String>{};
    final mealIds = <String>{};

    void inspectIds(
      Iterable<TimelineEvent> events,
      String prefix,
      Set<String> ids,
    ) {
      for (final event in events) {
        final canonicalId = event.id.trim();
        if (canonicalId.isEmpty) {
          missingReasons.add('$prefix.event_id_empty');
          continue;
        }
        if (canonicalId != event.id) {
          integrityReasons.add('$prefix.event_id_not_canonical($canonicalId)');
        }
        if (!ids.add(canonicalId)) {
          integrityReasons.add('$prefix.event_id_duplicate($canonicalId)');
        }
      }
    }

    inspectIds(context.medicationEvents, 'medication', medicationIds);
    inspectIds(context.mealEvents, 'meal', mealIds);
    for (final id in medicationIds.intersection(mealIds)) {
      integrityReasons.add('timeline.event_id_collision($id)');
    }
    return (integrityReasons: integrityReasons, missingReasons: missingReasons);
  }

  static List<String> _normalizedMedicationIntegrityReasons(
    MedicationTimelineEvent event,
  ) {
    final context = event.context;
    final validation = _medicationEntryValidator.validate(
      RawMedicationEntry(
        activeIngredients: context.activeIngredients,
        drugProductVariant: context.drugProductVariant,
        form: context.form,
        route: context.route,
        releaseType: context.releaseType,
        strength: context.strength,
        unit: context.unit,
        jurisdiction: context.jurisdiction,
        sourceDocId: context.sourceDocId,
        labelSection: context.labelSection,
        extractionConfidence: context.extractionConfidence,
        medicationMetadata: context.metadata,
      ),
    );
    final reasons = <String>{
      for (final issue in validation.issues)
        'medication.normalized_context(${event.id}).${issue.code.toLowerCase()}',
    };
    final canonical = validation.normalized;
    if (canonical != null) {
      final ingredientsAreCanonical =
          context.activeIngredients.length ==
              canonical.activeIngredients.length &&
          List.generate(
            context.activeIngredients.length,
            (index) =>
                context.activeIngredients[index] ==
                canonical.activeIngredients[index],
          ).every((matches) => matches);
      if (!ingredientsAreCanonical ||
          context.drugProductVariant != canonical.drugProductVariant ||
          context.form != canonical.form ||
          context.route != canonical.route ||
          context.releaseType != canonical.releaseType ||
          context.unit != canonical.unit ||
          context.jurisdiction != canonical.jurisdiction ||
          context.sourceDocId != canonical.sourceDocId ||
          context.labelSection != canonical.labelSection) {
        reasons.add('medication.normalized_context(${event.id}).not_canonical');
      }
    }
    return reasons.toList(growable: false);
  }

  /// Latest meal whose start falls within the model lookahead window — up to
  /// 180 minutes AFTER the dose (`m.minute <= med.minute + 180`), not only
  /// meals at or before the dose. Falls back to the earliest meal when none
  /// qualify. Pure selection — no side effects.
  ///
  /// Deterministic and independent of input order: meal events are sorted by
  /// minute (ties broken by id) before selection, so an unsorted
  /// `mealEvents` list always yields the same primary meal.
  MealTimelineEvent? _primaryMealFor(
    MedicationTimelineEvent med,
    TimeAxisConflictContext context, {
    String? preferredMealId,
  }) {
    if (context.mealEvents.isEmpty) return null;
    if (preferredMealId != null) {
      for (final meal in context.mealEvents) {
        if (meal.id == preferredMealId) return meal;
      }
      return null;
    }
    final sorted = [...context.mealEvents]
      ..sort((a, b) {
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

  /// Latest meal that had actually started by the medication event. This is
  /// the only meal eligible to shift the dose-time absorption window. Future
  /// candidate meals remain eligible for downstream competition overlap but
  /// cannot causally become pre-dose gastric residual.
  MealTimelineEvent? _absorptionMealFor(
    MedicationTimelineEvent med,
    TimeAxisConflictContext context,
  ) {
    final started =
        context.mealEvents
            .where((meal) => meal.minute <= med.minute)
            .toList(growable: false)
          ..sort((a, b) {
            final byMinute = b.minute.compareTo(a.minute);
            return byMinute != 0 ? byMinute : a.id.compareTo(b.id);
          });
    return started.isEmpty ? null : started.first;
  }

  double? _residualLoadBeforeMeal({
    required MealTimelineEvent target,
    required TimeAxisConflictContext context,
    required Map<String, MealComposition> mealCompositionsById,
  }) {
    var residual = 0.0;
    for (final earlier in context.mealEvents) {
      if (earlier.id == target.id || earlier.minute >= target.minute) continue;
      final earlierComp = mealCompositionsById[earlier.compositionId];
      if (earlierComp == null) return null;
      final earlierProfile = gastricEmptyingModel.build(
        mealId: earlier.id,
        mealStartMinute: earlier.minute,
        composition: earlierComp,
      );
      residual += earlierProfile
          .remainingFractionAt(target.minute - earlier.minute)
          .clamp(0.0, 1.0);
    }
    return residual.clamp(0.0, 1.0);
  }

  /// Explicit levodopa dose in mg from a validated medication context. The
  /// validator only normalizes a context when strength + unit are explicit, so
  /// no dose is invented here. Non-mass units (e.g. ml) yield null.
  double? _explicitDoseMg(MedicationTimelineEvent med) {
    final value = med.context.strength;
    if (value <= 0) return null;
    switch (med.context.unit.toLowerCase()) {
      case 'mg':
      case 'milligram':
      case 'milligrams':
        return value;
      case 'g':
      case 'gram':
      case 'grams':
        return value * 1000.0;
      case 'mcg':
      case 'ug':
      case 'µg':
      case 'μg':
      case 'microgram':
      case 'micrograms':
        return value / 1000.0;
      default:
        return null;
    }
  }

  /// Evaluate a single dose against the meal timeline. Returns null when the
  /// dose's primary meal composition is unavailable (recorded as missing by the
  /// caller rather than fabricated).
  _MedEventEvaluation? _evaluateMedicationEvent({
    required MedicationTimelineEvent med,
    required TimeAxisConflictContext context,
    required Map<String, MealComposition> mealCompositionsById,
    String? preferredMealId,
  }) {
    final primaryMeal = _primaryMealFor(
      med,
      context,
      preferredMealId: preferredMealId,
    );
    if (primaryMeal == null) return null;
    final composition = mealCompositionsById[primaryMeal.compositionId];
    if (composition == null) return null;

    // Cumulative overlap at the target meal time (used only for that meal's
    // emptying/competition trace).
    final residual = _residualLoadBeforeMeal(
      target: primaryMeal,
      context: context,
      mealCompositionsById: mealCompositionsById,
    );
    if (residual == null) return null;

    final emptyingProfile = gastricEmptyingModel.build(
      mealId: primaryMeal.id,
      mealStartMinute: primaryMeal.minute,
      composition: composition,
      overlappingResidualLoad: residual,
    );

    // Dose-time gastric context is causally separate from the target meal.
    // Only a meal that started on/before the medication can shift absorption.
    final doseTimeMeal = _absorptionMealFor(med, context);
    GastricEmptyingProfile? doseTimeMealProfile;
    if (doseTimeMeal != null) {
      if (doseTimeMeal.id == primaryMeal.id) {
        doseTimeMealProfile = emptyingProfile;
      } else {
        final doseTimeComposition =
            mealCompositionsById[doseTimeMeal.compositionId];
        if (doseTimeComposition == null) return null;
        final doseTimeResidual = _residualLoadBeforeMeal(
          target: doseTimeMeal,
          context: context,
          mealCompositionsById: mealCompositionsById,
        );
        if (doseTimeResidual == null) return null;
        doseTimeMealProfile = gastricEmptyingModel.build(
          mealId: doseTimeMeal.id,
          mealStartMinute: doseTimeMeal.minute,
          composition: doseTimeComposition,
          overlappingResidualLoad: doseTimeResidual,
        );
      }
    }
    final absorption = absorptionModel.build(
      medication: med,
      overlappingMealProfile: doseTimeMealProfile,
    );
    final competition = competitionModel.build(
      mealComposition: composition,
      mealEmptyingProfile: emptyingProfile,
      absorptionWindow: absorption,
      mealStartMinute: primaryMeal.minute,
      // Explicit dose from the validated medication context (never invented).
      levodopaDoseMg: _explicitDoseMg(med),
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

  MealComposition _canonicalCompositionSnapshot(MealComposition composition) =>
      MealCompositionNormalizer().normalize(
        mealId: composition.id,
        components: List<FoodComponent>.of(composition.foodComponents),
        declaredPhysicalForm:
            composition.mealPhysicalForm == MealPhysicalForm.unknown
            ? null
            : composition.mealPhysicalForm,
      );

  List<String> _mealCompositionIntegrityReasons(
    MealComposition composition, {
    required String expectedId,
  }) {
    final reasons = <String>[];
    if (composition.id != expectedId || composition.id.trim().isEmpty) {
      reasons.add('id_mismatch');
    }
    void validateNonnegative(String field, double? value) {
      if (value != null && (!value.isFinite || value < 0)) {
        reasons.add('$field.invalid_numeric');
      }
    }

    validateNonnegative('total_calories', composition.totalCalories);
    validateNonnegative('protein_grams', composition.proteinGrams);
    validateNonnegative('fat_grams', composition.fatGrams);
    validateNonnegative('fiber_grams', composition.fiberGrams);
    validateNonnegative('carbohydrate_grams', composition.carbohydrateGrams);
    final liquidFraction = composition.liquidFraction;
    if (liquidFraction != null &&
        (!liquidFraction.isFinite ||
            liquidFraction < 0 ||
            liquidFraction > 1)) {
      reasons.add('liquid_fraction.invalid_numeric');
    }
    if (!composition.compositionCompleteness.isFinite ||
        composition.compositionCompleteness < 0 ||
        composition.compositionCompleteness > 1) {
      reasons.add('composition_completeness.out_of_range');
    }

    final componentIds = <String>{};
    for (final component in composition.foodComponents) {
      final componentPrefix = 'food_component(${component.id})';
      if (component.id.trim().isEmpty || !componentIds.add(component.id)) {
        reasons.add('$componentPrefix.id_empty_or_duplicate');
      }
      if (component.name.trim().isEmpty) {
        reasons.add('$componentPrefix.name_empty');
      }
      validateNonnegative(
        '$componentPrefix.protein_grams',
        component.proteinGrams,
      );
      validateNonnegative('$componentPrefix.fat_grams', component.fatGrams);
      validateNonnegative('$componentPrefix.fiber_grams', component.fiberGrams);
      validateNonnegative(
        '$componentPrefix.carbohydrate_grams',
        component.carbohydrateGrams,
      );
      validateNonnegative('$componentPrefix.calories', component.calories);
      validateNonnegative(
        '$componentPrefix.portion_grams',
        component.portionGrams,
      );
      final aminoAcids = component.aminoAcidProfile;
      if (aminoAcids != null) {
        final values = [
          aminoAcids.leucine,
          aminoAcids.isoleucine,
          aminoAcids.valine,
          aminoAcids.phenylalanine,
          aminoAcids.tyrosine,
          aminoAcids.tryptophan,
          aminoAcids.histidine,
          aminoAcids.methionine,
          aminoAcids.threonine,
          aminoAcids.lysine,
          aminoAcids.cystine,
          aminoAcids.arginine,
        ];
        if (values.any(
          (value) => value != null && (!value.isFinite || value < 0),
        )) {
          reasons.add('$componentPrefix.amino_acid_profile.invalid_numeric');
        }
      }
    }

    final canonical = _canonicalCompositionSnapshot(composition);
    bool sameNumber(double? left, double? right) {
      if (left == null || right == null) return left == right;
      if (!left.isFinite || !right.isFinite) return false;
      final scale = 1.0 + left.abs() + right.abs();
      return (left - right).abs() <= 1e-12 * scale;
    }

    final numericPairs = <String, (double?, double?)>{
      'total_calories': (composition.totalCalories, canonical.totalCalories),
      'protein_grams': (composition.proteinGrams, canonical.proteinGrams),
      'fat_grams': (composition.fatGrams, canonical.fatGrams),
      'fiber_grams': (composition.fiberGrams, canonical.fiberGrams),
      'carbohydrate_grams': (
        composition.carbohydrateGrams,
        canonical.carbohydrateGrams,
      ),
      'liquid_fraction': (composition.liquidFraction, canonical.liquidFraction),
      'composition_completeness': (
        composition.compositionCompleteness,
        canonical.compositionCompleteness,
      ),
    };
    for (final entry in numericPairs.entries) {
      if (!sameNumber(entry.value.$1, entry.value.$2)) {
        reasons.add('${entry.key}.canonical_mismatch');
      }
    }
    if (composition.mealPhysicalForm != canonical.mealPhysicalForm) {
      reasons.add('meal_physical_form.canonical_mismatch');
    }
    if (composition.portionSizeBand != canonical.portionSizeBand) {
      reasons.add('portion_size_band.canonical_mismatch');
    }
    if (composition.proteinAmountBand != canonical.proteinAmountBand) {
      reasons.add('protein_amount_band.canonical_mismatch');
    }
    if (composition.fatAmountBand != canonical.fatAmountBand) {
      reasons.add('fat_amount_band.canonical_mismatch');
    }
    if (composition.fiberAmountBand != canonical.fiberAmountBand) {
      reasons.add('fiber_amount_band.canonical_mismatch');
    }
    if (composition.calorieBand != canonical.calorieBand) {
      reasons.add('calorie_band.canonical_mismatch');
    }
    if (composition.missingFields.toSet().length !=
            composition.missingFields.length ||
        composition.missingFields
            .toSet()
            .difference(canonical.missingFields.toSet())
            .isNotEmpty ||
        canonical.missingFields
            .toSet()
            .difference(composition.missingFields.toSet())
            .isNotEmpty) {
      reasons.add('missing_fields.canonical_mismatch');
    }
    return List.unmodifiable(reasons);
  }

  SeverityBand _severity(
    double score,
    CompetitionBand competition,
    DelayedArrivalLikelihood delay,
  ) {
    if (competition == CompetitionBand.unknown) return SeverityBand.unknown;
    if (score >= 0.35) return SeverityBand.high;
    if (score >= 0.15) return SeverityBand.moderate;
    if (score > 0.0) return SeverityBand.low;
    return SeverityBand.none;
  }

  ConfidenceBand _confidence({
    required double compositionCompleteness,
    required UncertaintyBand consumedUpstreamUncertainty,
    required int missingTimelineFields,
    required bool competitionUnknown,
  }) {
    if (compositionCompleteness < 0.4) return ConfidenceBand.insufficient;
    // When the competition layer cannot be scored (e.g. protein grams
    // missing), the engine must not pretend medium confidence.
    if (competitionUnknown) return ConfidenceBand.low;
    if (missingTimelineFields >= 3) return ConfidenceBand.low;
    if (consumedUpstreamUncertainty == UncertaintyBand.veryWide) {
      return ConfidenceBand.low;
    }
    if (consumedUpstreamUncertainty == UncertaintyBand.wide) {
      return ConfidenceBand.medium;
    }
    if (compositionCompleteness < 0.85) return ConfidenceBand.medium;
    return ConfidenceBand.high;
  }

  UncertaintyBand _widestUncertainty(Iterable<UncertaintyBand> bands) => bands
      .reduce((current, next) => current.index >= next.index ? current : next);

  MechanisticProviderAvailability _mergeProviderAvailability(
    Iterable<MechanisticProviderAvailability> availabilities,
  ) {
    final values = availabilities.toSet();
    if (values.contains(MechanisticProviderAvailability.blockedIntegrity)) {
      return MechanisticProviderAvailability.blockedIntegrity;
    }
    if (values.contains(MechanisticProviderAvailability.notApplicable)) {
      return MechanisticProviderAvailability.notApplicable;
    }
    if (values.contains(MechanisticProviderAvailability.insufficient)) {
      return MechanisticProviderAvailability.insufficient;
    }
    return MechanisticProviderAvailability.available;
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
