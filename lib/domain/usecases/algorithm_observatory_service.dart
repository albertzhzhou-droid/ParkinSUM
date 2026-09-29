import '../../algorithm_sdk/algorithm_component_graph_identity.dart';
import '../../algorithm_sdk/algorithm_configuration_identity.dart';
import '../../core/models/food_item.dart';
import '../../core/models/meal.dart';
import '../entities/mechanistic_candidate_score.dart';
import '../entities/algorithm_descriptor.dart';
import '../entities/algorithm_trace_node.dart';
import '../entities/dose_expression.dart';
import '../entities/gastric_emptying_parameters.dart';
import '../entities/gastric_structural_uncertainty.dart';
import '../entities/input_quality.dart';
import '../entities/medication_entry_validation.dart';
import '../entities/mechanistic_conflict_result.dart';
import '../entities/mechanistic_event_ledger.dart';
import '../entities/mechanistic_replay_capsule.dart';
import '../entities/meal_composition.dart';
import '../entities/protein_distribution.dart';
import '../entities/protein_source.dart';
import '../entities/time_axis_events.dart';
import 'dosage_note_parser.dart';
import 'meal_composition_normalizer.dart';
import 'mechanistic_conflict_engine.dart';
import 'mechanistic_event_ledger_authorization.dart';
import 'mechanistic_event_ledger_builder.dart';
import 'mechanistic_replay_capsule_service.dart';
import 'mechanistic_next_meal_scorer.dart';
import 'medication_entry_validator.dart';
import 'input_quality_gate.dart';
import 'gastric_structural_uncertainty_service.dart';
import 'get_protein_trend_usecase.dart';
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
  final MechanisticLedgerAuthorizationAssessment ledgerAuthorization;
  final MechanisticReplayCapsule replayCapsule;
  final GastricStructuralUncertaintyReport? gastricStructuralUncertainty;

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
    required this.ledgerAuthorization,
    required this.replayCapsule,
    required this.gastricStructuralUncertainty,
  });
}

/// Builds deterministic, non-personal demonstration traces with the production
/// models. The fixed anchor makes screenshots and tests replayable.
class AlgorithmObservatoryService {
  static const AlgorithmTraceProviderContract
  traceProviderContract = AlgorithmTraceProviderContract(
    providerId: AlgorithmTraceProviderIds.productionObservatorySnapshot,
    algorithmIds: [
      'meal_composition_normalizer',
      'medication_entry_validator',
      'input_quality_gate',
      'time_axis_builder',
      'gastric_emptying',
      'levodopa_absorption_opportunity',
      'amino_acid_competition',
      'mechanistic_conflict',
      'mechanistic_candidate_scorer',
      'mechanistic_lossless_replay_capsule',
      'protein_trend',
      'dosage_note_parser',
      'gastric_structural_uncertainty_shadow_ensemble',
      'protein_distribution',
    ],
    fixtureSchema: 'parkinsum.algorithm-observatory-snapshot/1',
    fixtureRevision: 'synthetic-observatory-v5',
    lifecycle:
        'register_eager_snapshot_for_each_declared_scenario;dispose_immutable_value_not_applicable',
    routeId: 'app-tools.observatory',
    routeSourcePath: 'lib/features/main_shell/app_destinations.dart',
    providerSourcePath:
        'lib/domain/usecases/algorithm_observatory_service.dart',
    uiSurfaceKeysByAlgorithm: {
      'meal_composition_normalizer': 'observatory-explanation-tree',
      'medication_entry_validator': 'observatory-explanation-tree',
      'input_quality_gate': 'observatory-explanation-tree',
      'time_axis_builder': 'observatory-explanation-tree',
      'gastric_emptying': 'chart-panel-gastric-emptying',
      'levodopa_absorption_opportunity': 'chart-panel-absorption-competition',
      'amino_acid_competition': 'chart-panel-absorption-competition',
      'mechanistic_conflict': 'observatory-conflict-panel',
      'mechanistic_candidate_scorer': 'observatory-candidate-panel',
      'mechanistic_lossless_replay_capsule':
          'observatory-mechanistic-lossless-replay-capsule',
      'protein_trend': 'observatory-explanation-tree',
      'dosage_note_parser': 'observatory-explanation-tree',
      'gastric_structural_uncertainty_shadow_ensemble':
          'chart-panel-gastric-structural-uncertainty',
      'protein_distribution': 'observatory-explanation-tree',
    },
    executableTestPaths: [
      'test/algorithm_observatory_service_test.dart',
      'test/algorithm_registry_coverage_test.dart',
      'test/algorithm_observatory_page_test.dart',
      'test/mechanistic_replay_capsule_test.dart',
    ],
  );

  final MealCompositionNormalizer normalizer;
  final MedicationEntryValidator medicationValidator;
  final TimeAxisBuilder timeAxisBuilder;
  final MechanisticConflictEngine conflictEngine;
  final MechanisticNextMealScorer candidateScorer;
  final GastricStructuralUncertaintyService gastricStructuralUncertaintyService;
  final MechanisticLedgerAuthorizer ledgerAuthorizer;
  final MechanisticReplayCapsuleRoundTripper replayRoundTripper;
  late final AlgorithmConfigurationIdentity configurationIdentity;

  AlgorithmObservatoryService({
    MealCompositionNormalizer? normalizer,
    MedicationEntryValidator? medicationValidator,
    TimeAxisBuilder? timeAxisBuilder,
    MechanisticConflictEngine? conflictEngine,
    MechanisticNextMealScorer? candidateScorer,
    GastricStructuralUncertaintyService? gastricStructuralUncertaintyService,
    MechanisticLedgerAuthorizer? ledgerAuthorizer,
    MechanisticReplayCapsuleRoundTripper? replayRoundTripper,
    AlgorithmConfigurationIdentity? configurationIdentity,
  }) : normalizer = normalizer ?? MealCompositionNormalizer(),
       medicationValidator = medicationValidator ?? MedicationEntryValidator(),
       timeAxisBuilder = timeAxisBuilder ?? TimeAxisBuilder(),
       conflictEngine = conflictEngine ?? MechanisticConflictEngine(),
       candidateScorer =
           candidateScorer ?? MechanisticNextMealScorer(engine: conflictEngine),
       gastricStructuralUncertaintyService =
           gastricStructuralUncertaintyService ??
           const GastricStructuralUncertaintyService(),
       ledgerAuthorizer =
           ledgerAuthorizer ??
           const MechanisticEventLedgerAuthorizationService(),
       replayRoundTripper =
           replayRoundTripper ?? const MechanisticReplayCapsuleService() {
    final hasInjectedComponent =
        normalizer != null ||
        medicationValidator != null ||
        timeAxisBuilder != null ||
        conflictEngine != null ||
        candidateScorer != null ||
        gastricStructuralUncertaintyService != null ||
        ledgerAuthorizer != null ||
        replayRoundTripper != null;
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
          absorptionParameters: this.conflictEngine.absorptionModel.parameters,
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
    // Keep evidence-currency evaluation stable for this synthetic replay while
    // the production engine uses a caller-supplied or current assessment time.
    final evidenceAsOfUtc = DateTime.utc(2026, 8, 19);
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
    final inputQuality =
        InputQualityGate(medicationValidator: medicationValidator).evaluate(
          InputQualityGateInput(
            medicationValidation: medication,
            productStrengthMetadataOnly: true,
            mealComposition: composition,
            candidateMetadataPresent: true,
            userDefinedWindow: window,
          ),
        );
    final gastricParameters = conflictEngine.gastricEmptyingModel.parameters;
    final compositions = <String, MealComposition>{composition.id: composition};
    final eventLedger = const MechanisticEventLedgerBuilder().build(
      ledgerId: 'observatory_${scenario.name}_ledger',
      context: context,
      mealCompositionsById: compositions,
      configurationDigest: configurationIdentity.sha256Digest,
      createdAtUtc: anchor,
      sourceId: 'synthetic:observatory',
      revisionId: 'observatory_fixture_v1',
      synthetic: true,
    );
    final replay = replayRoundTripper.captureAndRestore(
      capsuleId: 'observatory_${scenario.name}_replay',
      generatedAtUtc: anchor,
      ledger: eventLedger,
      context: context,
      mealCompositionsById: compositions,
      expectedConfigurationSha256: configurationIdentity.sha256Digest,
    );
    final authorization = ledgerAuthorizer.authorize(
      ledger: replay.restored.ledger,
      context: replay.restored.context,
      mealCompositionsById: replay.restored.mealCompositionsById,
      expectedConfigurationSha256: configurationIdentity.sha256Digest,
    );
    final authorizedView = authorization.view;
    final conflict = authorizedView == null
        ? MechanisticConflictResult.blockedIntegrity(
            id: 'observatory_${scenario.name}',
            reason: MechanisticInteractionType.insufficientMealContext,
            integrityReasons: authorization.assessment.findings,
            sourceRefs: const [mechanisticLedgerAuthorizationSchema],
          )
        : conflictEngine.evaluate(
            context: authorizedView.context,
            mealCompositionsById: authorizedView.mealCompositionsById,
            resultId: 'observatory_${scenario.name}',
            evidenceAsOfUtc: evidenceAsOfUtc,
          );
    final candidateScores = authorizedView == null
        ? const <MechanisticCandidateScore>[]
        : candidateScorer.score(
            baseContext: authorizedView.context,
            baseMealCompositionsById: authorizedView.mealCompositionsById,
            candidates: _candidates,
            userDefinedWindow: window,
            evidenceAsOfUtc: evidenceAsOfUtc,
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
    final primaryEmptyingProfile = conflict.primaryEmptyingProfile;
    final gastricStructuralUncertainty =
        primaryEmptyingProfile == null ||
            !primaryEmptyingProfile.hasModeledOutput
        ? null
        : gastricStructuralUncertaintyService.build(
            reportId: 'observatory_${scenario.name}_gastric_structures',
            generatedAtUtc: anchor,
            eventLedger: replay.restored.ledger,
            productionProfile: primaryEmptyingProfile,
            physicalForm: composition.mealPhysicalForm,
          );
    return AlgorithmObservatorySnapshot(
      scenario: scenario,
      context: replay.restored.context,
      composition: replay.restored.mealCompositionsById[composition.id]!,
      conflict: conflict,
      candidateScores: candidateScores,
      gastricParameters: gastricParameters,
      configurationIdentity: configurationIdentity,
      explanationTree: _buildExplanationTree(
        context: replay.restored.context,
        composition: replay.restored.mealCompositionsById[composition.id]!,
        conflict: conflict,
        candidateScores: candidateScores,
        medicationValidation: medication,
        inputQuality: inputQuality,
        replayCapsule: replay.capsule,
        gastricStructuralUncertainty: gastricStructuralUncertainty,
      ),
      eventLedger: replay.restored.ledger,
      ledgerAuthorization: authorization.assessment,
      replayCapsule: replay.capsule,
      gastricStructuralUncertainty: gastricStructuralUncertainty,
    );
  }

  AlgorithmTraceNode _buildExplanationTree({
    required TimeAxisConflictContext context,
    required MealComposition composition,
    required MechanisticConflictResult conflict,
    required List<MechanisticCandidateScore> candidateScores,
    required MedicationContextValidationResult medicationValidation,
    required MealMedicationInputQualityResult inputQuality,
    required MechanisticReplayCapsule replayCapsule,
    required GastricStructuralUncertaintyReport? gastricStructuralUncertainty,
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
          id: 'mechanistic_lossless_replay_capsule',
          algorithmId: 'mechanistic_lossless_replay_capsule',
          providerId: traceProviderContract.providerId,
          label: 'Reconstruct complete mechanistic input',
          inputs: const [
            'schema-v2 ledger',
            'complete time-axis context',
            'complete meal-composition map',
          ],
          output:
              'lossless round trip ${replayCapsule.capsuleSha256.substring(0, 12)}…',
          sourceRefs: const [mechanisticReplayCapsuleSchema],
          limitation:
              'Replay equality is engineering integrity evidence, not biological or clinical validity.',
        ),
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
        _inputQualityTrace(inputQuality),
        _medicationEntryValidationTrace(medicationValidation),
        _dosageNoteParserTrace(),
        _timeAxisTrace(context),
        _proteinTrendTrace(),
        _proteinDistributionTrace(candidateScores),
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
        _gastricStructuralUncertaintyTrace(
          report: gastricStructuralUncertainty,
          conflictAvailability: conflict.availability.name,
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

  AlgorithmTraceNode _inputQualityTrace(
    MealMedicationInputQualityResult assessment,
  ) {
    final dimensionSummary = assessment.dimensionScores
        .map((dimension) => '${dimension.dimension}=${dimension.status}')
        .join('; ');
    return AlgorithmTraceNode(
      id: 'input_quality_gate',
      algorithmId: 'input_quality_gate',
      providerId: traceProviderContract.providerId,
      label: 'Assess synthetic context completeness',
      inputs: [
        '${assessment.dimensionScores.length} context-quality dimensions',
        dimensionSummary,
        'product strength treated as metadata, not an intake dose',
      ],
      output:
          '${assessment.overallStatus}; completeness '
          '${(assessment.overallScore * 100).round()}%; '
          '${assessment.mechanisticPrimaryEligible ? 'gate eligible' : 'gate held'}; '
          '${assessment.blockerCount} blocker(s); '
          '${assessment.fallbackReasons.length} fallback reason(s)',
      sourceRefs: const [],
      limitation:
          'Exact result from the input-completeness assessment on fixed '
          'synthetic inputs. The product-strength-only case is held because '
          'no intake dose is supplied. This standalone assessment is not '
          'used to authorize or veto the other Observatory traces and is not '
          'medical advice or clinical validation.',
    );
  }

  AlgorithmTraceNode _medicationEntryValidationTrace(
    MedicationContextValidationResult validation,
  ) {
    final normalized = validation.normalized;
    final contextFields = normalized == null
        ? 'normalized context absent'
        : '${normalized.activeIngredients.length} ingredient token(s); '
              'strength/unit, product variant, form, route, and release type present';
    return AlgorithmTraceNode(
      id: 'medication_entry_validator',
      algorithmId: 'medication_entry_validator',
      providerId: traceProviderContract.providerId,
      label: 'Validate synthetic medication context',
      inputs: ['fixed synthetic structured entry', contextFields],
      output:
          '${validation.validity.name}; '
          '${validation.eligibleForRuleEvaluation ? 'eligible for educational model input' : 'held from educational model input'}; '
          '${validation.issues.length} validation issue(s)',
      sourceRefs: const [],
      limitation:
          'This is the validator result for a fixed synthetic entry. '
          'Structural eligibility does not verify real-world medication '
          'identity, prescription validity, or clinical appropriateness.',
    );
  }

  AlgorithmTraceNode _timeAxisTrace(TimeAxisConflictContext context) {
    final anchorMinute = context.mealEvents.isEmpty
        ? context.referenceMinute
        : context.mealEvents.first.minute;
    String relativeMinute(int minute) {
      final offset = minute - anchorMinute;
      final signedOffset = offset > 0 ? '+$offset' : '$offset';
      return '$signedOffset min';
    }

    String offsets(Iterable<int> minutes) {
      final values = minutes.map(relativeMinute).toList(growable: false);
      return values.isEmpty ? 'none' : values.join(', ');
    }

    final eventSummary =
        'meals ${offsets(context.mealEvents.map((event) => event.minute))}; '
        'medications ${offsets(context.medicationEvents.map((event) => event.minute))}; '
        'food components ${offsets(context.foodComponentEvents.map((event) => event.minute))}';
    final window = context.userDefinedWindow?.window;
    final windowSummary = window == null
        ? 'no caller-defined window'
        : 'caller window ${relativeMinute(window.startMinute)} to '
              '${relativeMinute(window.endMinute)}';

    return AlgorithmTraceNode(
      id: 'time_axis_builder',
      algorithmId: 'time_axis_builder',
      providerId: traceProviderContract.providerId,
      label: 'Build deterministic time axis',
      inputs: [
        '${context.mealEvents.length} meal event(s)',
        '${context.medicationEvents.length} medication event(s)',
        '${context.foodComponentEvents.length} food component event(s)',
        context.userDefinedWindow == null
            ? 'caller-defined window absent'
            : 'caller-defined window present',
        'missing or rejected input field count ${context.missingFields.length}',
      ],
      output: 'relative event offsets: $eventSummary; $windowSummary',
      sourceRefs: const [],
      limitation:
          'Fixed synthetic scenario only. Offsets are relative; absolute '
          'timestamps and event identifiers are omitted. Missing or rejected '
          'inputs are counted, not inferred or repaired. This is not '
          'patient-specific timing or a clinical recommendation.',
    );
  }

  AlgorithmTraceNode _proteinTrendTrace() {
    final anchor = DateTime.utc(2026, 1, 1, 12);
    Meal syntheticMeal({
      required String fixtureId,
      required DateTime eatenAt,
      required double proteinGrams,
      DateTime? recordedAt,
      DateTime? occurredAt,
      DateTime? occurredRangeStart,
    }) => Meal(
      id: 'synthetic:protein-trend:$fixtureId',
      eatenAt: eatenAt,
      recordedAt: recordedAt,
      occurredAt: occurredAt,
      occurredRangeStart: occurredRangeStart,
      title: 'Synthetic protein trend fixture',
      items: [
        MealItem(
          foodId: 'synthetic:protein-trend-item:$fixtureId',
          foodName: 'synthetic fixture item',
          foodCategory: FoodCategory.other,
          quantityFactor: 1,
          foodTags: const [],
          proteinPer100g: proteinGrams,
          carbsPer100g: 0,
          fatPer100g: 0,
          fiberPer100g: 0,
          sodiumPer100g: 0,
        ),
      ],
    );

    // Input order is intentionally different from effective occurrence order.
    final meals = [
      syntheticMeal(
        fixtureId: 'eaten-at-fallback',
        eatenAt: anchor.add(const Duration(days: 3)),
        recordedAt: anchor.add(const Duration(days: 3, hours: 1)),
        proteinGrams: 30,
      ),
      syntheticMeal(
        fixtureId: 'occurred-at',
        eatenAt: anchor.add(const Duration(days: 4)),
        recordedAt: anchor.add(const Duration(days: 4, hours: 2)),
        occurredAt: anchor.add(const Duration(days: 1)),
        proteinGrams: 10,
      ),
      syntheticMeal(
        fixtureId: 'range-start',
        eatenAt: anchor.add(const Duration(days: 4)),
        recordedAt: anchor.add(const Duration(days: 4, hours: 1)),
        occurredRangeStart: anchor.add(const Duration(days: 2)),
        proteinGrams: 20,
      ),
    ];
    final useCase = GetProteinTrendUseCase();
    final points = useCase.call(meals);
    final firstTime = points.first.time;
    final offsets = points
        .map((point) {
          final relativeDay = point.time.difference(firstTime).inDays;
          return '${relativeDay}d:${point.protein.toStringAsFixed(1)}g';
        })
        .join(' → ');

    return AlgorithmTraceNode(
      id: 'protein_trend',
      algorithmId: 'protein_trend',
      providerId: traceProviderContract.providerId,
      label: 'Aggregate synthetic meal-protein trend',
      inputs: const [
        '3 fixed synthetic Meal rows; totals use Meal.computeTotals()',
        'effective time precedence: occurredAt → range start → eatenAt',
        'meal IDs, titles, food names, and absolute timestamps omitted',
      ],
      output:
          '${points.length} chronologically sorted point(s); relative series '
          '$offsets; arithmetic mean '
          '${useCase.averageProtein(meals).toStringAsFixed(1)} g per meal',
      sourceRefs: const [],
      limitation:
          'This calls the production aggregation on fixed synthetic inputs. '
          'The descriptive per-meal series is not a dietary adequacy target, '
          'clinical interpretation, or recommendation.',
    );
  }

  AlgorithmTraceNode _proteinDistributionTrace(
    List<MechanisticCandidateScore> candidateScores,
  ) {
    const limitation =
        'This read-only projection uses protein-distribution outputs already '
        'computed by the production candidate scorer on fixed synthetic '
        'fixtures. It is not dietary advice, a daily protein target, clinical '
        'validation, or a recommendation, and it does not alter scores or '
        'ranking.';
    final traced = <({int index, ProteinDistributionTrace result})>[];
    var held = 0;
    for (var index = 0; index < candidateScores.length; index++) {
      final score = candidateScores[index];
      final result = score.modeledProteinDistribution;
      if (result == null || !result.optimizationActive) {
        held++;
        continue;
      }
      traced.add((index: index + 1, result: result));
    }
    final roles = <String, int>{};
    for (final entry in traced) {
      roles.update(
        entry.result.windowRole.name,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    final roleSummary = roles.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    final redistributionMean = traced.isEmpty
        ? null
        : traced
                  .map((entry) => entry.result.redistributionScore)
                  .reduce((left, right) => left + right) /
              traced.length;
    final adequacyMean = traced.isEmpty
        ? null
        : traced
                  .map((entry) => entry.result.nutritionAdequacyContribution)
                  .reduce((left, right) => left + right) /
              traced.length;

    return AlgorithmTraceNode(
      id: 'protein_distribution',
      algorithmId: 'protein_distribution',
      providerId: traceProviderContract.providerId,
      label: 'Inspect protein redistribution model outputs',
      inputs: [
        '${candidateScores.length} fixed synthetic candidate result(s) from the production scorer',
        '${traced.length} modeled result(s); $held held or unavailable',
        'candidate names, identifiers, catalog references, protein grams, and absolute timestamps omitted',
        'projects stored production outputs; it does not recompute or feed ranking',
      ],
      output: traced.isEmpty
          ? 'not run; no modeled production protein-distribution output'
          : '${traced.length} modeled result(s); roles '
                '${roleSummary.map((entry) => '${entry.key}=${entry.value}').join(', ')}; '
                'mean redistribution ${(redistributionMean! * 100).toStringAsFixed(1)}%; '
                'mean adequacy contribution ${(adequacyMean! * 100).toStringAsFixed(1)}%',
      sourceRefs: const [],
      limitation: limitation,
      children: [
        for (final entry in traced)
          AlgorithmTraceNode(
            id: 'synthetic_candidate_${entry.index}',
            label: 'Fixed synthetic candidate ${entry.index}',
            inputs: const [
              'candidate identity and protein input withheld',
              'role derives primarily from modeled overlap; hour only refines the low-overlap label',
            ],
            output:
                'role ${entry.result.windowRole.name}; '
                'redistribution ${(entry.result.redistributionScore * 100).toStringAsFixed(1)}%; '
                'adequacy contribution ${(entry.result.nutritionAdequacyContribution * 100).toStringAsFixed(1)}%',
            sourceRefs: const [],
            limitation: limitation,
          ),
      ],
    );
  }

  AlgorithmTraceNode _dosageNoteParserTrace() {
    final parser = DosageNoteParser();
    // These arbitrary syntax tokens exercise parser dispositions only. Their
    // raw strings and parsed quantities are deliberately excluded from trace.
    final results = [
      parser.inspect('7 mg'),
      parser.inspect('2-4 mg'),
      parser.inspect('~7 mg'),
      parser.inspect('1 mg and 2 mg'),
      parser.inspect(''),
    ];
    final accepted = results
        .where((result) => result.status == DoseExpressionParseStatus.accepted)
        .length;
    final empty = results
        .where((result) => result.status == DoseExpressionParseStatus.empty)
        .length;
    final held = results
        .where((result) => result.status == DoseExpressionParseStatus.held)
        .length;
    final reasonCounts = <String, int>{};
    for (final result in results) {
      final reason = result.primaryReasonCode;
      if (reason != null) {
        reasonCounts.update(reason, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    final reasonSummary = reasonCounts.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));

    return AlgorithmTraceNode(
      id: 'dosage_note_parser',
      algorithmId: 'dosage_note_parser',
      providerId: traceProviderContract.providerId,
      label: 'Inspect fixed dose-expression syntax examples',
      inputs: const [
        '5 fixed synthetic parser cases; raw strings and quantities withheld',
        'one exact quantity, one range, one comparator, multiple values, and empty input',
        'standalone parser probe; not the medication context used by other traces',
      ],
      output:
          'grammar v${DosageNoteParser.grammarVersion}; ${results.length} cases; '
          'accepted $accepted, empty $empty, held $held; reason counts '
          '${reasonSummary.map((entry) => '${entry.key}=${entry.value}').join(', ')}',
      sourceRefs: const [],
      limitation:
          'This executes the production parser on fixed synthetic syntax only. '
          'Acceptance means local grammar recognition, not medication identity, '
          'prescription validity, dose appropriateness, or confirmed administration. '
          'This standalone probe does not feed the other Observatory traces.',
    );
  }

  AlgorithmTraceNode _gastricStructuralUncertaintyTrace({
    required GastricStructuralUncertaintyReport? report,
    required String conflictAvailability,
  }) {
    const algorithmId = 'gastric_structural_uncertainty_shadow_ensemble';
    const limitation =
        'Read-only model-form sensitivity does not alter the production curve '
        'or authorize fitting. It is not an ensemble accuracy gain, individual '
        'test, confidence interval, plasma concentration, symptom prediction, '
        'or clinical validation.';
    if (report == null) {
      return AlgorithmTraceNode(
        id: algorithmId,
        algorithmId: algorithmId,
        providerId: traceProviderContract.providerId,
        label: 'Synthetic gastric structure-sensitivity diagnostic',
        inputs: [
          'production gastric profile unavailable',
          'conflict availability $conflictAvailability',
        ],
        output:
            'not run; no modeled primary gastric profile; no shadow trajectory was generated',
        sourceRefs: [],
        limitation: limitation,
      );
    }

    final comparableCount = report.trajectories
        .where(
          (trajectory) =>
              trajectory.availability ==
              GastricTrajectoryAvailability.available,
        )
        .length;
    final heldCount = report.trajectories.length - comparableCount;
    final integrityReasons = report.integrityReasons;
    final sourceRefs = <String>{
      ...report.observationSeries.sourceIds,
      ...report.trajectories.expand(
        (trajectory) => trajectory.structure.evidenceSourceIds,
      ),
    }.toList()..sort();
    return AlgorithmTraceNode(
      id: algorithmId,
      algorithmId: algorithmId,
      providerId: traceProviderContract.providerId,
      label: 'Synthetic gastric structure-sensitivity diagnostic',
      inputs: [
        'observable ${report.observationSeries.observable.name}',
        'modality ${report.observationSeries.modality.name}',
        '${report.observationSeries.points.length} fixed synthetic observation points',
        'production output ${report.productionOutputDigestBefore == report.productionOutputDigestAfter ? 'unchanged' : 'changed'}',
      ],
      output: integrityReasons.isNotEmpty
          ? 'held: report integrity ${integrityReasons.join(', ')}'
          : '$comparableCount/${report.trajectories.length} observable-matched structures; '
                '$heldCount held by the observable gate; '
                'report ${report.sha256Digest.substring(0, 12)}…',
      sourceRefs: sourceRefs,
      limitation: limitation,
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
