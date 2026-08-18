import '../../algorithm_sdk/algorithm_component_graph_identity.dart';
import '../../algorithm_sdk/algorithm_configuration_identity.dart';
import '../entities/mechanistic_candidate_score.dart';
import '../entities/algorithm_descriptor.dart';
import '../entities/algorithm_trace_node.dart';
import '../entities/gastric_emptying_parameters.dart';
import '../entities/mechanistic_conflict_result.dart';
import '../entities/mechanistic_event_ledger.dart';
import '../entities/meal_composition.dart';
import '../entities/protein_source.dart';
import '../entities/time_axis_events.dart';
import 'meal_composition_normalizer.dart';
import 'mechanistic_conflict_engine.dart';
import 'mechanistic_event_ledger_builder.dart';
import 'mechanistic_next_meal_scorer.dart';
import 'medication_entry_validator.dart';
import 'time_axis_builder.dart';

enum ObservatoryScenario { mixedReference, highFatProtein, incompleteData }

/// Immutable output for the UI. Every chart is derived from the same real
/// engine invocation; the observatory never carries a second toy formula.
class AlgorithmObservatorySnapshot {
  final ObservatoryScenario scenario;
  final TimeAxisConflictContext context;
  final MealComposition composition;
  final MechanisticConflictResult conflict;
  final List<MechanisticCandidateScore> candidateScores;
  final GastricEmptyingParameterSet gastricParameters;
  final AlgorithmConfigurationIdentity configurationIdentity;
  final AlgorithmTraceNode explanationTree;
  final MechanisticEventLedger eventLedger;

  const AlgorithmObservatorySnapshot({
    required this.scenario,
    required this.context,
    required this.composition,
    required this.conflict,
    required this.candidateScores,
    required this.gastricParameters,
    required this.configurationIdentity,
    required this.explanationTree,
    required this.eventLedger,
  });
}

/// Builds deterministic, non-personal demonstration traces with the production
/// models. The fixed anchor makes screenshots and tests replayable.
class AlgorithmObservatoryService {
  static const AlgorithmTraceProviderContract traceProviderContract =
      AlgorithmTraceProviderContract(
        providerId: AlgorithmTraceProviderIds.productionObservatorySnapshot,
        algorithmIds: [
          'meal_composition_normalizer',
          'gastric_emptying',
          'levodopa_absorption_opportunity',
          'amino_acid_competition',
          'mechanistic_conflict',
          'mechanistic_candidate_scorer',
        ],
      );

  final MealCompositionNormalizer normalizer;
  final MedicationEntryValidator medicationValidator;
  final TimeAxisBuilder timeAxisBuilder;
  final MechanisticConflictEngine conflictEngine;
  final MechanisticNextMealScorer candidateScorer;
  late final AlgorithmConfigurationIdentity configurationIdentity;

  AlgorithmObservatoryService({
    MealCompositionNormalizer? normalizer,
    MedicationEntryValidator? medicationValidator,
    TimeAxisBuilder? timeAxisBuilder,
    MechanisticConflictEngine? conflictEngine,
    MechanisticNextMealScorer? candidateScorer,
    AlgorithmConfigurationIdentity? configurationIdentity,
  }) : normalizer = normalizer ?? MealCompositionNormalizer(),
       medicationValidator = medicationValidator ?? MedicationEntryValidator(),
       timeAxisBuilder = timeAxisBuilder ?? TimeAxisBuilder(),
       conflictEngine = conflictEngine ?? MechanisticConflictEngine(),
       candidateScorer =
           candidateScorer ??
           MechanisticNextMealScorer(engine: conflictEngine) {
    final hasInjectedComponent =
        normalizer != null ||
        medicationValidator != null ||
        timeAxisBuilder != null ||
        conflictEngine != null ||
        candidateScorer != null;
    if (hasInjectedComponent && configurationIdentity == null) {
      throw ArgumentError(
        'Every injected Observatory component requires an explicit matching '
        'AlgorithmConfigurationIdentity.',
      );
    }
    this.configurationIdentity =
        configurationIdentity ??
        AlgorithmConfigurationIdentity.defaults(
          gastricParameters:
              this.conflictEngine.gastricEmptyingModel.parameters,
          scoringParameters: this.candidateScorer.scoringParameters,
        );
    AlgorithmComponentGraphIdentityValidator.validateExecutionGraph(
      medicationValidator: this.medicationValidator,
      normalizer: this.normalizer,
      timeAxisBuilder: this.timeAxisBuilder,
      conflictEngine: this.conflictEngine,
      candidateScorer: this.candidateScorer,
      identity: this.configurationIdentity,
      graphLabel: 'algorithmObservatory',
    );
  }

  AlgorithmObservatorySnapshot build(ObservatoryScenario scenario) {
    final components = _componentsFor(scenario);
    final composition = normalizer.normalize(
      mealId: 'observatory_meal',
      components: components,
      declaredPhysicalForm: scenario == ObservatoryScenario.incompleteData
          ? MealPhysicalForm.unknown
          : MealPhysicalForm.mixed,
    );

    final anchor = DateTime.utc(2026, 1, 1, 8);
    final medication = medicationValidator.validate(
      const RawMedicationEntry(
        activeIngredients: ['carbidopa', 'levodopa'],
        drugProductVariant: 'synthetic:observatory-ir',
        strength: 100,
        unit: 'mg',
        form: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        jurisdiction: 'US',
        sourceDocId: 'synthetic:observatory',
        labelSection: 'clinical_pharmacology',
        extractionConfidence: 1,
      ),
    );
    final mealStart = anchor;
    final medicationTime = anchor.add(
      Duration(
        minutes: scenario == ObservatoryScenario.incompleteData ? 75 : 35,
      ),
    );
    final window = UserDefinedMealWindow(
      window: TimelineWindow(
        startMinute: dateTimeToMinute(anchor.add(const Duration(hours: 2))),
        endMinute: dateTimeToMinute(
          anchor.add(const Duration(hours: 3, minutes: 30)),
        ),
      ),
      source: 'synthetic_observatory_fixture',
    );
    final context = timeAxisBuilder.build(
      now: anchor,
      medicationInputs: [
        MedicationTimelineInput(
          id: 'observatory_dose',
          takenAt: medicationTime,
          medicationContext: medication,
        ),
      ],
      mealInputs: [
        MealTimelineInput(
          id: 'observatory_meal_event',
          startedAt: mealStart,
          compositionId: composition.id,
          physicalForm: composition.mealPhysicalForm,
        ),
      ],
      userDefinedWindow: window,
    );
    final conflict = conflictEngine.evaluate(
      context: context,
      mealCompositionsById: {composition.id: composition},
      resultId: 'observatory_${scenario.name}',
    );
    final candidateScores = candidateScorer.score(
      baseContext: context,
      baseMealCompositionsById: {composition.id: composition},
      candidates: _candidates,
      userDefinedWindow: window,
      candidateMetadata: {
        'oats': CandidateMetadata(
          completeness: 1,
          authorityScore: 0.8,
          jurisdictionMatchScore: 1,
          provenanceQuality: 0.8,
          jurisdiction: 'US',
        ),
        'yogurt': CandidateMetadata(
          completeness: 1,
          authorityScore: 0.8,
          jurisdictionMatchScore: 1,
          provenanceQuality: 0.8,
          jurisdiction: 'US',
        ),
      },
    );
    final gastricParameters = conflictEngine.gastricEmptyingModel.parameters;
    final eventLedger = const MechanisticEventLedgerBuilder().build(
      ledgerId: 'observatory_${scenario.name}_ledger',
      context: context,
      mealCompositionsById: {composition.id: composition},
      configurationDigest: configurationIdentity.sha256Digest,
      createdAtUtc: anchor,
      sourceId: 'synthetic:observatory',
      revisionId: 'observatory_fixture_v1',
      synthetic: true,
    );
    return AlgorithmObservatorySnapshot(
      scenario: scenario,
      context: context,
      composition: composition,
      conflict: conflict,
      candidateScores: candidateScores,
      gastricParameters: gastricParameters,
      configurationIdentity: configurationIdentity,
      explanationTree: _buildExplanationTree(
        context: context,
        composition: composition,
        conflict: conflict,
        candidateScores: candidateScores,
      ),
      eventLedger: eventLedger,
    );
  }

  AlgorithmTraceNode _buildExplanationTree({
    required TimeAxisConflictContext context,
    required MealComposition composition,
    required MechanisticConflictResult conflict,
    required List<MechanisticCandidateScore> candidateScores,
  }) {
    final emptying = conflict.primaryEmptyingProfile;
    final absorption = conflict.absorptionOpportunityWindow;
    final competition = conflict.competitionTimeline;
    final primaryMealMinute = emptying == null
        ? null
        : context.mealEvents
              .firstWhere((event) => event.id == emptying.mealId)
              .minute;
    final primaryDoseMinute = absorption == null
        ? null
        : context.medicationEvents
              .firstWhere((event) => event.id == absorption.medicationEventId)
              .minute;
    final modeledScore = conflict.modeledInteractionScore;
    final modeledSeverity = conflict.modeledSeverityBand;
    return AlgorithmTraceNode(
      id: 'mechanistic_conflict',
      algorithmId: 'mechanistic_conflict',
      providerId: traceProviderContract.providerId,
      label: 'Mechanistic conflict composition',
      inputs: [
        '${conflict.perEventTraces.length} medication event trace(s)',
        '${composition.foodComponents.length} meal component(s)',
      ],
      output: modeledScore == null || modeledSeverity == null
          ? 'status ${conflict.availability.name}; no modeled output'
          : 'overlap ${(modeledScore * 100).toStringAsFixed(1)}%; '
                'severity ${modeledSeverity.name}; '
                'confidence ${conflict.confidenceBand.name}',
      sourceRefs: conflict.sourceRefs,
      limitation: conflict.limitationText,
      children: [
        AlgorithmTraceNode(
          id: 'meal_composition_normalizer',
          algorithmId: 'meal_composition_normalizer',
          providerId: traceProviderContract.providerId,
          label: 'Normalize meal composition',
          inputs: [
            'physical form ${composition.mealPhysicalForm.name}',
            'protein ${composition.proteinGrams?.toStringAsFixed(1) ?? 'missing'} g',
            'missing ${composition.missingFields.isEmpty ? 'none' : composition.missingFields.join(', ')}',
          ],
          output:
              'completeness ${(composition.compositionCompleteness * 100).round()}%',
          sourceRefs: const ['src.hens.foodphysical.2024'],
          limitation:
              'Normalization preserves missingness; it does not infer a clinical measurement.',
        ),
        if (emptying != null)
          AlgorithmTraceNode(
            id: 'gastric_emptying',
            algorithmId: 'gastric_emptying',
            providerId: traceProviderContract.providerId,
            label: 'Model gastric residence and arrival',
            inputs: [
              '${emptying.componentProfiles.length} component curve(s)',
              'aggregate lag ${emptying.aggregateLagMinutes.toStringAsFixed(0)} min',
              'uncertainty ${emptying.uncertaintyBand.name}',
            ],
            output:
                'mostly-emptied window ${_relativeWindowLabel(emptying.mostlyEmptiedWindow, primaryMealMinute!, 'meal start')}',
            sourceRefs: emptying.sourceRefs,
            limitation:
                'Sensitivity curve only; it is not an individual gastric-emptying test.',
          ),
        if (absorption != null)
          AlgorithmTraceNode(
            id: 'levodopa_absorption_opportunity',
            algorithmId: 'levodopa_absorption_opportunity',
            providerId: traceProviderContract.providerId,
            label: 'Build levodopa opportunity window',
            inputs: [
              '${absorption.opennessProfile.length} openness samples',
              'uncertainty ${absorption.uncertaintyBand.name}',
            ],
            output:
                'opportunity window ${_relativeWindowLabel(absorption.window, primaryDoseMinute!, 'dose')}; '
                'peak ${_relativeMinuteLabel(absorption.peakMinute, primaryDoseMinute, 'dose')}; '
                'delayed-arrival ${absorption.delayedArrivalLikelihood.name}',
            sourceRefs: absorption.sourceRefs,
            limitation:
                'Unitless openness is not absorbed fraction, concentration, or clinical response.',
          ),
        if (competition != null)
          AlgorithmTraceNode(
            id: 'amino_acid_competition',
            algorithmId: 'amino_acid_competition',
            providerId: traceProviderContract.providerId,
            label: 'Estimate LNAA competition pressure',
            inputs: [
              'protein ${composition.proteinGrams?.toStringAsFixed(1) ?? 'missing'} g',
              'data mode ${competition.lnaaSummary?.dataMode.name ?? 'unknown'}',
            ],
            output:
                'overlap ${(competition.overlapWithAbsorptionWindow * 100).toStringAsFixed(1)}%; band ${competition.competitionBand.name}',
            sourceRefs: competition.sourceRefs,
            limitation:
                'Pressure is a bounded proxy; normal-diet variation is not assumed to create a universal strong effect.',
          ),
        AlgorithmTraceNode(
          id: 'mechanistic_candidate_scorer',
          algorithmId: 'mechanistic_candidate_scorer',
          providerId: traceProviderContract.providerId,
          label: 'Compare candidate trace fixtures',
          inputs: [
            '${candidateScores.length} candidate trace fixture(s)',
            'analysis-only comparison; no production recommendation reorder',
          ],
          output: candidateScores.isEmpty
              ? 'no candidate trace fixtures'
              : '${candidateScores.where((score) => score.hasModeledOutput).length} modeled trace(s); '
                    'statuses ${candidateScores.map((score) => score.availability.name).toSet().join(', ')}',
          sourceRefs: conflict.sourceRefs,
          limitation:
              'This diagnostic comparison uses only supplied fixtures. It does not reorder production recommendations or choose a treatment time.',
          children: [
            for (final score in candidateScores)
              AlgorithmTraceNode(
                id: 'candidate_${score.candidateFoodId}',
                label: score.candidateName,
                inputs: !score.hasModeledOutput
                    ? ['upstream result unavailable']
                    : [
                        'worst conflict ${(score.modeledWorstCaseConflictOverlapScore! * 100).round()}%',
                        'protein redistribution ${(score.modeledProteinRedistributionScore! * 100).round()}%',
                        'provenance ${(score.modeledProvenanceQualityScore! * 100).round()}%',
                      ],
                output: !score.hasModeledOutput
                    ? 'status ${score.availability.name}; no modeled candidate score'
                    : 'final compatibility ${(score.modeledFinalCandidateScore! * 100).round()}%',
                sourceRefs: score.sourceRefs,
                limitation: score.notAdviceText,
              ),
          ],
        ),
      ],
    );
  }

  /// Observatory traces cross a presentation/export boundary: production
  /// models retain canonical UTC epoch minutes for ordering, while trace text
  /// must state elapsed time from the event that gives it meaning.
  String _relativeWindowLabel(
    TimelineWindow window,
    int anchorMinute,
    String anchorLabel,
  ) {
    final start = window.startMinute - anchorMinute;
    final end = window.endMinute - anchorMinute;
    if (start >= 0 && end >= 0) {
      return '$start–$end min after $anchorLabel';
    }
    if (start <= 0 && end <= 0) {
      return '${start.abs()}–${end.abs()} min before $anchorLabel';
    }
    return '${_relativeMinuteLabel(window.startMinute, anchorMinute, anchorLabel)} '
        'to ${_relativeMinuteLabel(window.endMinute, anchorMinute, anchorLabel)}';
  }

  String _relativeMinuteLabel(
    int minute,
    int anchorMinute,
    String anchorLabel,
  ) {
    final delta = minute - anchorMinute;
    if (delta == 0) return 'at $anchorLabel';
    return delta > 0
        ? '$delta min after $anchorLabel'
        : '${delta.abs()} min before $anchorLabel';
  }

  List<FoodComponent> _componentsFor(ObservatoryScenario scenario) {
    switch (scenario) {
      case ObservatoryScenario.mixedReference:
        return const [
          FoodComponent(
            id: 'oatmeal',
            name: 'Oatmeal',
            physicalForm: MealPhysicalForm.solid,
            proteinGrams: 8,
            fatGrams: 5,
            fiberGrams: 6,
            carbohydrateGrams: 42,
            calories: 250,
            portionGrams: 240,
            sourceDocId: 'synthetic:observatory',
            proteinSource: ProteinSourceType.grain,
          ),
          FoodComponent(
            id: 'water',
            name: 'Water',
            physicalForm: MealPhysicalForm.liquid,
            proteinGrams: 0,
            fatGrams: 0,
            fiberGrams: 0,
            carbohydrateGrams: 0,
            calories: 0,
            portionGrams: 240,
            sourceDocId: 'synthetic:observatory',
          ),
        ];
      case ObservatoryScenario.highFatProtein:
        return const [
          FoodComponent(
            id: 'high_load',
            name: 'High-fat mixed meal',
            physicalForm: MealPhysicalForm.solid,
            proteinGrams: 35,
            fatGrams: 30,
            fiberGrams: 4,
            carbohydrateGrams: 55,
            calories: 650,
            portionGrams: 420,
            sourceDocId: 'synthetic:observatory',
            proteinSource: ProteinSourceType.mixed,
          ),
        ];
      case ObservatoryScenario.incompleteData:
        return const [
          FoodComponent(
            id: 'incomplete',
            name: 'Incomplete catalog item',
            physicalForm: MealPhysicalForm.unknown,
            proteinGrams: 18,
            fatGrams: null,
            fiberGrams: null,
            carbohydrateGrams: null,
            calories: null,
            portionGrams: null,
            sourceDocId: null,
            proteinSource: ProteinSourceType.unknown,
          ),
        ];
    }
  }

  static const List<CandidateFood> _candidates = [
    CandidateFood(
      id: 'oats',
      name: 'Oats and fruit fixture',
      regionalFoodLibraryRef: 'synthetic:observatory',
      declaredPhysicalForm: MealPhysicalForm.solid,
      components: [
        FoodComponent(
          id: 'oats_component',
          name: 'Oats and fruit',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: 7,
          fatGrams: 4,
          fiberGrams: 7,
          carbohydrateGrams: 48,
          calories: 270,
          portionGrams: 260,
          sourceDocId: 'synthetic:observatory',
          proteinSource: ProteinSourceType.grain,
        ),
      ],
    ),
    CandidateFood(
      id: 'yogurt',
      name: 'Yogurt fixture',
      regionalFoodLibraryRef: 'synthetic:observatory',
      declaredPhysicalForm: MealPhysicalForm.mixed,
      components: [
        FoodComponent(
          id: 'yogurt_component',
          name: 'Yogurt',
          physicalForm: MealPhysicalForm.mixed,
          proteinGrams: 20,
          fatGrams: 4,
          fiberGrams: 0,
          carbohydrateGrams: 14,
          calories: 170,
          portionGrams: 200,
          sourceDocId: 'synthetic:observatory',
          proteinSource: ProteinSourceType.dairy,
        ),
      ],
    ),
  ];
}
