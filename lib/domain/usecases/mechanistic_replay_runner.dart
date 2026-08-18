import 'dart:convert';

import '../../algorithm_sdk/algorithm_component_graph_identity.dart';
import '../../algorithm_sdk/algorithm_configuration_identity.dart';
import '../../core/constants/mechanistic_replay_scenarios.dart';
import '../entities/amino_acid_competition.dart';
import '../entities/mechanistic_candidate_score.dart';
import '../entities/mechanistic_conflict_result.dart';
import '../entities/medication_entry_validation.dart';
import '../entities/meal_composition.dart';
import '../entities/rule_explanation.dart';
import '../entities/time_axis_events.dart';
import 'meal_composition_normalizer.dart';
import 'mechanistic_conflict_engine.dart';
import 'mechanistic_next_meal_scorer.dart';
import 'medication_entry_validator.dart';
import 'time_axis_builder.dart';

/// Per-scenario report row.
class MechanisticReplayCaseReport {
  final String scenarioId;
  final String title;
  final String medicationContextValidity;
  final double mealContextCompleteness;
  final String gastricEmptyingProfileSummary;
  final TimelineWindow? absorptionOpportunityWindow;
  final String resultAvailability;
  final bool hasModeledOutput;
  final List<String> abstentionReasons;
  final String? aminoAcidCompetitionBand;
  final double? interactionScore;
  final String? severityBand;
  final String? confidenceBand;
  final List<String> triggeredMechanisms;
  final List<String> blockedMechanisms;
  final List<String> sourceRefs;
  final String limitationText;
  final String safetyBoundary;
  final List<String> bannedPhraseHits;
  final List<MechanisticCandidateScore>? nextMealRecommendationResult;
  final CompetitionLnaaSummary? competitionLnaaSummary;
  final String rankerUsed;
  final List<int> sampledWindowOffsets;
  // Top-candidate-derived fields (null when no candidates scored).
  final double? topFinalCandidateScore;
  final double? topProteinRedistributionScore;
  final String? topProteinWindowRole;
  final double? topNutritionAdequacyContribution;
  final double? topSourceAuthorityScore;
  final double? topJurisdictionMatchScore;
  final String? topCandidateSourceSystem;
  final String? aminoAcidDataMode;
  final List<String> aminoAcidNutrientIds;
  // Production-readiness guardrail fields (constant for this educational build).
  final String sourceImplementationStatus;
  final bool liveFetchEnabled;
  final String licenseReviewStatus;
  final bool canSupportMechanismEvidenceAlone;
  final String clinicalCalibrationStatus;
  // Dosage + multi-dose transparency (Obj 6/7). `userEnteredDosage` reflects
  // exactly what the user supplied (free-text or strength+unit); it is never a
  // private default. `dosageContextComplete` is true only when the first
  // medication entry validated to a complete dose context. `perEventCount` is
  // the number of doses evaluated on the multi-dose time axis.
  final String userEnteredDosage;
  final bool dosageContextComplete;
  final int perEventCount;
  // Upgraded-chain transparency (#7): componentized meal composition, gastric
  // phase assumptions, absorption openness-profile summary, LNAA
  // actual/hybrid/proxy detail, and the active scoring parameter set.
  final int mealComponentCount;
  final List<String> gastricEmptyingAssumptions;
  final int absorptionOpennessSampleCount;
  final double? absorptionPeakOpenness;
  final bool partialAminoAcidData;
  final double? competingLnaaGrams;
  final bool doseRelativeLnaaAvailable;
  final double? doseRelativeLnaaRatio;
  final String? aminoAcidConfidenceTier;
  final String scoringParameterSetId;
  // Medication section provenance + release extraction (CDSS→context bridge).
  // Sourced from the first validated medication context's metadata; null/empty
  // when no CDSS metadata was attached. Provenance only — never a dose.
  final String? medicationSourceSystem;
  final String? medicationSourceDocId;
  final String? medicationSourceVersion;
  final int medicationLabelSectionRefCount;
  final String? medicationReleaseType;
  final String? medicationReleaseTypeSource;
  final String? medicationDoseForm;
  final String? medicationRoute;
  final List<String> medicationCombinationComponents;
  final String dosageSource;
  final String? medicationMetadataCompleteness;
  final List<String> medicationMissingFields;
  final bool pass;
  final String? failureReason;

  const MechanisticReplayCaseReport({
    required this.scenarioId,
    required this.title,
    required this.medicationContextValidity,
    required this.mealContextCompleteness,
    required this.gastricEmptyingProfileSummary,
    required this.absorptionOpportunityWindow,
    required this.resultAvailability,
    required this.hasModeledOutput,
    required this.abstentionReasons,
    required this.aminoAcidCompetitionBand,
    required this.interactionScore,
    required this.severityBand,
    required this.confidenceBand,
    required this.triggeredMechanisms,
    required this.blockedMechanisms,
    required this.sourceRefs,
    required this.limitationText,
    required this.safetyBoundary,
    required this.bannedPhraseHits,
    required this.nextMealRecommendationResult,
    required this.pass,
    required this.failureReason,
    this.competitionLnaaSummary,
    this.rankerUsed = 'mechanistic_engine_only',
    this.sampledWindowOffsets = const [],
    this.topFinalCandidateScore,
    this.topProteinRedistributionScore,
    this.topProteinWindowRole,
    this.topNutritionAdequacyContribution,
    this.topSourceAuthorityScore,
    this.topJurisdictionMatchScore,
    this.topCandidateSourceSystem,
    this.aminoAcidDataMode,
    this.aminoAcidNutrientIds = const [],
    this.sourceImplementationStatus = 'fixture_tested',
    this.liveFetchEnabled = false,
    this.licenseReviewStatus = 'future_work',
    this.canSupportMechanismEvidenceAlone = false,
    this.clinicalCalibrationStatus = 'not_clinically_calibrated',
    this.userEnteredDosage = 'none',
    this.dosageContextComplete = false,
    this.perEventCount = 0,
    this.mealComponentCount = 0,
    this.gastricEmptyingAssumptions = const [],
    this.absorptionOpennessSampleCount = 0,
    this.absorptionPeakOpenness,
    this.partialAminoAcidData = false,
    this.competingLnaaGrams,
    this.doseRelativeLnaaAvailable = false,
    this.doseRelativeLnaaRatio,
    this.aminoAcidConfidenceTier,
    this.scoringParameterSetId = 'none',
    this.medicationSourceSystem,
    this.medicationSourceDocId,
    this.medicationSourceVersion,
    this.medicationLabelSectionRefCount = 0,
    this.medicationReleaseType,
    this.medicationReleaseTypeSource,
    this.medicationDoseForm,
    this.medicationRoute,
    this.medicationCombinationComponents = const [],
    this.dosageSource = 'none',
    this.medicationMetadataCompleteness,
    this.medicationMissingFields = const [],
  });

  Map<String, dynamic> toJson() => {
    'scenario_id': scenarioId,
    'title': title,
    'medication_context_validity': medicationContextValidity,
    'meal_context_completeness': mealContextCompleteness,
    'gastric_emptying_profile_summary': gastricEmptyingProfileSummary,
    'absorption_opportunity_window': absorptionOpportunityWindow?.toJson(),
    'result_availability': resultAvailability,
    'has_modeled_output': hasModeledOutput,
    'abstention_reasons': abstentionReasons,
    'amino_acid_competition_band': aminoAcidCompetitionBand,
    'interaction_score': interactionScore,
    'severity_band': severityBand,
    'confidence_band': confidenceBand,
    'triggered_mechanisms': triggeredMechanisms,
    'blocked_mechanisms': blockedMechanisms,
    'source_refs': sourceRefs,
    'limitation_text': limitationText,
    'safety_boundary': safetyBoundary,
    'banned_phrase_hits': bannedPhraseHits,
    'next_meal_recommendation_result': nextMealRecommendationResult
        ?.map((e) => e.toJson())
        .toList(),
    'competition_lnaa_summary': competitionLnaaSummary?.toJson(),
    'ranker_used': rankerUsed,
    'sampled_window_offsets': sampledWindowOffsets,
    'top_final_candidate_score': topFinalCandidateScore,
    'top_protein_redistribution_score': topProteinRedistributionScore,
    'top_protein_window_role': topProteinWindowRole,
    'top_nutrition_adequacy_contribution': topNutritionAdequacyContribution,
    'top_source_authority_score': topSourceAuthorityScore,
    'top_jurisdiction_match_score': topJurisdictionMatchScore,
    'top_candidate_source_system': topCandidateSourceSystem,
    'amino_acid_data_mode': aminoAcidDataMode,
    'amino_acid_nutrient_ids': aminoAcidNutrientIds,
    'source_implementation_status': sourceImplementationStatus,
    'live_fetch_enabled': liveFetchEnabled,
    'license_review_status': licenseReviewStatus,
    'can_support_mechanism_evidence_alone': canSupportMechanismEvidenceAlone,
    'clinical_calibration_status': clinicalCalibrationStatus,
    'user_entered_dosage': userEnteredDosage,
    'dosage_context_complete': dosageContextComplete,
    'per_event_count': perEventCount,
    'meal_component_count': mealComponentCount,
    'gastric_emptying_assumptions': gastricEmptyingAssumptions,
    'absorption_openness_sample_count': absorptionOpennessSampleCount,
    'absorption_peak_openness': absorptionPeakOpenness,
    'partial_amino_acid_data': partialAminoAcidData,
    'competing_lnaa_grams': competingLnaaGrams,
    'dose_relative_lnaa_available': doseRelativeLnaaAvailable,
    'dose_relative_lnaa_ratio': doseRelativeLnaaRatio,
    'amino_acid_confidence_tier': aminoAcidConfidenceTier,
    'scoring_parameter_set_id': scoringParameterSetId,
    'medication_source_system': medicationSourceSystem,
    'medication_source_doc_id': medicationSourceDocId,
    'medication_source_version': medicationSourceVersion,
    'medication_label_section_ref_count': medicationLabelSectionRefCount,
    'medication_release_type': medicationReleaseType,
    'medication_release_type_source': medicationReleaseTypeSource,
    'medication_dose_form': medicationDoseForm,
    'medication_route': medicationRoute,
    'medication_combination_components': medicationCombinationComponents,
    'dosage_source': dosageSource,
    'medication_metadata_completeness': medicationMetadataCompleteness,
    'medication_missing_fields': medicationMissingFields,
    'pass': pass,
    'failure_reason': failureReason,
  };
}

class MechanisticReplayRunReport {
  /// The fixed reference instant the replay was anchored to — **not** the time
  /// the report was produced.
  ///
  /// Defaults to `DateTime.utc(2026, 1, 1, 8)`, which is what makes this
  /// report byte-reproducible across runs. The name is retained for the
  /// `generated_at` JSON key that `SourceVersionDriftChecker` requires; new
  /// consumers should read `deterministic_reference_time`.
  final String generatedAtIso;

  final AlgorithmConfigurationIdentity configurationIdentity;
  final List<MechanisticReplayCaseReport> cases;

  const MechanisticReplayRunReport({
    required this.generatedAtIso,
    required this.configurationIdentity,
    required this.cases,
  });

  bool get allPassed => cases.every((c) => c.pass);
  int get passedCount => cases.where((c) => c.pass).length;
  int get totalCount => cases.length;

  Map<String, dynamic> toJson() => {
    // Kept under the original key because `SourceVersionDriftChecker` requires
    // a valid ISO-8601 `generated_at` on generated artifacts. It is NOT a wall
    // clock: it is the fixed reference instant the replay is anchored to
    // (`DateTime.utc(2026, 1, 1, 8)` unless a caller overrides it), which is
    // what makes this report byte-reproducible.
    'generated_at': generatedAtIso,
    // Unambiguous alias. Consumers should prefer this one; a reader of the
    // raw JSON should not have to infer that `generated_at` is a constant.
    'deterministic_reference_time': generatedAtIso,
    'generated_at_is_deterministic_reference': true,
    'passed': passedCount,
    'total': totalCount,
    'algorithm_configuration': {
      'manifest_schema': AlgorithmConfigurationIdentity.schema,
      'id': configurationIdentity.id,
      'version': configurationIdentity.version,
      'sha256': configurationIdentity.sha256Digest,
      'reproducibility_scope':
          'engineering_replay_identity_not_biological_validation',
      'biological_validity_status': 'not_clinically_calibrated',
    },
    'cases': cases.map((c) => c.toJson()).toList(growable: false),
  };

  String toMarkdown() {
    final buf = StringBuffer()
      ..writeln('# Mechanistic Replay Report')
      ..writeln()
      // Deliberately not labelled "Generated:". The value is a fixed
      // determinism anchor, and presenting it as a production time showed
      // readers a timestamp that was never true.
      ..writeln(
        'Deterministic reference instant: $generatedAtIso '
        '(fixed anchor, not the time this report was produced)',
      )
      ..writeln()
      ..writeln(
        'Algorithm configuration: `${configurationIdentity.id}` @ '
        '`${configurationIdentity.version}` · '
        '`${configurationIdentity.sha256Digest}`',
      )
      ..writeln(
        'Scope: the digest proves engineering replay identity only; it does '
        '**not** establish biological or clinical validity.',
      )
      ..writeln()
      ..writeln('**$passedCount / $totalCount scenarios passed.**')
      ..writeln();
    for (final c in cases) {
      final interactionScore = c.interactionScore?.toStringAsFixed(3) ?? 'null';
      buf
        ..writeln('## ${c.scenarioId} — ${c.title}')
        ..writeln('- pass: ${c.pass}')
        ..writeln('- result_availability: ${c.resultAvailability}')
        ..writeln('- has_modeled_output: ${c.hasModeledOutput}')
        ..writeln('- interaction_score: $interactionScore')
        ..writeln('- severity_band: ${c.severityBand}')
        ..writeln('- confidence_band: ${c.confidenceBand}')
        ..writeln(
          '- amino_acid_competition_band: ${c.aminoAcidCompetitionBand}',
        )
        ..writeln('- gastric_emptying: ${c.gastricEmptyingProfileSummary}')
        ..writeln('- banned_phrase_hits: ${c.bannedPhraseHits.length}')
        ..writeln();
      if (c.abstentionReasons.isNotEmpty) {
        buf
          ..writeln('- abstention_reasons: ${c.abstentionReasons.join(", ")}')
          ..writeln();
      }
      if (!c.pass) {
        buf.writeln('  *failure*: ${c.failureReason}');
        buf.writeln();
      }
    }
    return buf.toString();
  }
}

class MechanisticReplayRunner {
  final MedicationEntryValidator validator;
  final MealCompositionNormalizer normalizer;
  final TimeAxisBuilder timeAxisBuilder;
  final MechanisticConflictEngine engine;
  final MechanisticNextMealScorer scorer;
  late final AlgorithmConfigurationIdentity configurationIdentity;

  MechanisticReplayRunner({
    MedicationEntryValidator? validator,
    MealCompositionNormalizer? normalizer,
    TimeAxisBuilder? timeAxisBuilder,
    MechanisticConflictEngine? engine,
    MechanisticNextMealScorer? scorer,
    AlgorithmConfigurationIdentity? configurationIdentity,
  }) : validator = validator ?? MedicationEntryValidator(),
       normalizer = normalizer ?? MealCompositionNormalizer(),
       timeAxisBuilder = timeAxisBuilder ?? TimeAxisBuilder(),
       engine = engine ?? MechanisticConflictEngine(),
       scorer = scorer ?? MechanisticNextMealScorer(engine: engine) {
    final hasInjectedComponent =
        validator != null ||
        normalizer != null ||
        timeAxisBuilder != null ||
        engine != null ||
        scorer != null;
    if (hasInjectedComponent && configurationIdentity == null) {
      throw ArgumentError(
        'Every injected replay component requires an explicit matching '
        'AlgorithmConfigurationIdentity.',
      );
    }
    this.configurationIdentity =
        configurationIdentity ??
        AlgorithmConfigurationIdentity.defaults(
          gastricParameters: this.engine.gastricEmptyingModel.parameters,
          scoringParameters: this.scorer.scoringParameters,
        );
    AlgorithmComponentGraphIdentityValidator.validateExecutionGraph(
      medicationValidator: this.validator,
      normalizer: this.normalizer,
      timeAxisBuilder: this.timeAxisBuilder,
      conflictEngine: this.engine,
      candidateScorer: this.scorer,
      identity: this.configurationIdentity,
      graphLabel: 'mechanisticReplay',
    );
  }

  MechanisticReplayRunReport run({
    List<MechanisticReplayScenario> scenarios = mechanisticReplayScenarios,
    DateTime? referenceTime,
  }) {
    final now = referenceTime ?? DateTime.utc(2026, 1, 1, 8, 0);
    final cases = <MechanisticReplayCaseReport>[];
    for (final s in scenarios) {
      cases.add(_runOne(s, now));
    }
    return MechanisticReplayRunReport(
      generatedAtIso: now.toIso8601String(),
      configurationIdentity: configurationIdentity,
      cases: List.unmodifiable(cases),
    );
  }

  MechanisticReplayCaseReport _runOne(
    MechanisticReplayScenario scenario,
    DateTime now,
  ) {
    // Validate medications.
    final medValidations = scenario.medicationEntries
        .map(validator.validate)
        .toList(growable: false);

    final medicationInputs = <MedicationTimelineInput>[];
    for (var i = 0; i < medValidations.length; i++) {
      final v = medValidations[i];
      final offset = scenario.medicationMinutesOffsets[i].minutes;
      medicationInputs.add(
        MedicationTimelineInput(
          id: 'med_${scenario.scenarioId}_$i',
          takenAt: now.add(Duration(minutes: offset)),
          medicationContext: v,
        ),
      );
    }

    // Normalize meal compositions.
    final compositionsById = <String, MealComposition>{};
    final mealInputs = <MealTimelineInput>[];
    for (final m in scenario.meals) {
      final comp = normalizer.normalize(
        mealId: 'comp_${scenario.scenarioId}_${m.id}',
        components: m.components,
        declaredPhysicalForm: m.physicalForm,
      );
      compositionsById[comp.id] = comp;
      mealInputs.add(
        MealTimelineInput(
          id: m.id,
          startedAt: now.add(Duration(minutes: m.offset.minutes)),
          compositionId: comp.id,
          physicalForm: m.physicalForm,
        ),
      );
    }

    final context = timeAxisBuilder.build(
      now: now,
      medicationInputs: medicationInputs,
      mealInputs: mealInputs,
      userDefinedWindow: scenario.userDefinedWindow == null
          ? null
          : UserDefinedMealWindow(
              window: TimelineWindow(
                startMinute:
                    dateTimeToMinute(now) +
                    scenario.userDefinedWindow!.window.startMinute,
                endMinute:
                    dateTimeToMinute(now) +
                    scenario.userDefinedWindow!.window.endMinute,
              ),
              source: scenario.userDefinedWindow!.source,
            ),
    );

    final result = engine.evaluate(
      context: context,
      mealCompositionsById: compositionsById,
      resultId: scenario.scenarioId,
    );

    List<MechanisticCandidateScore>? recommendations;
    if (scenario.candidateFoods.isNotEmpty) {
      recommendations = scorer.score(
        baseContext: context,
        baseMealCompositionsById: compositionsById,
        candidates: scenario.candidateFoods,
        userDefinedWindow: context.userDefinedWindow,
      );
    }

    // Aggregate banned-phrase scan.
    final allCopy = <String>[
      result.limitationText,
      result.safetyBoundary,
      result.notAdviceText,
      ...result.explanation.layerTraces.map((t) => t.description),
      ...result.explanation.layerTraces.expand((t) => t.assumptionsApplied),
      ...?recommendations?.expand((r) => r.explanation),
    ].join(' ');
    final banned = findBannedSubstrings(allCopy);

    // Determine pass/fail.
    final failures = <String>[];

    final expectedType = scenario.expectedOutputType;
    final isInsufficient = scenario.expectInsufficientContext;
    if (isInsufficient) {
      if (result.hasModeledOutput ||
          (result.interactionType !=
                  MechanisticInteractionType.insufficientMedicationContext &&
              result.interactionType !=
                  MechanisticInteractionType.insufficientMealContext)) {
        failures.add(
          'expected typed abstention but got '
          '${result.availability.name}/${result.interactionType.name}',
        );
      }
    } else {
      // Coarse check: align expected output type with engine output.
      final outType = _classifyOutputType(result);
      if (outType != expectedType) {
        failures.add('expected $expectedType but got $outType');
      }
    }

    final modeledSeverity = result.modeledSeverityBand;
    final modeledConfidence = result.modeledConfidenceBand;
    if (scenario.expectedSeverityFloor != null) {
      if (modeledSeverity == null ||
          !_severityAtLeast(modeledSeverity, scenario.expectedSeverityFloor!)) {
        failures.add('severity unavailable or below expected floor');
      }
    }
    if (scenario.expectedSeverityCeiling != null) {
      if (modeledSeverity == null ||
          !_severityAtMost(
            modeledSeverity,
            scenario.expectedSeverityCeiling!,
          )) {
        failures.add('severity unavailable or above expected ceiling');
      }
    }
    if (scenario.expectedConfidenceCeiling != null) {
      if (modeledConfidence == null ||
          !_confidenceAtMost(
            modeledConfidence,
            scenario.expectedConfidenceCeiling!,
          )) {
        failures.add('confidence unavailable or above expected ceiling');
      }
    }
    if (scenario.expectNonEmptyRecommendations &&
        (recommendations == null || recommendations.isEmpty)) {
      // This assertion is deliberately about row availability, not modeled
      // scores. A candidate can be returned as a typed abstention so its
      // missing predicates remain inspectable without leaking numeric output.
      failures.add('expected non-empty recommendation records');
    }
    if (banned.isNotEmpty) {
      failures.add('banned phrases: ${banned.join(", ")}');
    }

    final pass = failures.isEmpty;

    final firstMealCompleteness = scenario.meals.isEmpty
        ? 0.0
        : (compositionsById.values.firstWhere(
            (c) => c.id.startsWith('comp_${scenario.scenarioId}_'),
            orElse: () => compositionsById.values.first,
          )).compositionCompleteness;

    final gastricSummary = result.primaryEmptyingProfile == null
        ? 'no_profile'
        : 'lag=${result.primaryEmptyingProfile!.aggregateLagMinutes.toStringAsFixed(0)}min uncertainty=${result.primaryEmptyingProfile!.uncertaintyBand.name}';

    // Surface exactly what the user supplied as a dose — free-text if present,
    // otherwise the structured strength+unit. Never a private default.
    final firstEntry = scenario.medicationEntries.isEmpty
        ? null
        : scenario.medicationEntries.first;
    final userEnteredDosage = firstEntry == null
        ? 'none'
        : (firstEntry.freeText != null &&
              firstEntry.freeText!.trim().isNotEmpty)
        ? firstEntry.freeText!.trim()
        : (firstEntry.strength != null && (firstEntry.unit ?? '').isNotEmpty)
        ? '${firstEntry.strength} ${firstEntry.unit}'
        : 'none';
    final dosageContextComplete =
        medValidations.isNotEmpty &&
        medValidations.first.validity == MedicationContextValidity.valid;

    // Upgraded-chain transparency (#7). LNAA detail comes from the meal-level
    // competition when a meal is present, otherwise from the top scored
    // candidate's upstream competition (candidate-only scenarios have no meal).
    final emptying = result.primaryEmptyingProfile;
    final absorptionWindow = result.absorptionOpportunityWindow;
    final firstRecommendation =
        recommendations != null && recommendations.isNotEmpty
        ? recommendations.first
        : null;
    final modeledRecommendation =
        firstRecommendation != null && firstRecommendation.hasModeledOutput
        ? firstRecommendation
        : null;
    final candidateUpstreamResult = firstRecommendation?.upstreamResult;
    final lnaa = result.hasModeledOutput
        ? result.competitionTimeline?.lnaaSummary
        : (modeledRecommendation != null &&
              candidateUpstreamResult?.hasModeledOutput == true)
        ? candidateUpstreamResult?.competitionTimeline?.lnaaSummary
        : null;
    final scoringParamId =
        modeledRecommendation?.scoringParameterSetId ?? 'none';

    final abstentionReasons = result.isAbstention
        ? List<String>.unmodifiable(<String>{
            ...result.uncertaintyReasons,
            ...result.explanation.missingOrUncertainInputs,
          })
        : const <String>[];

    // Medication section provenance + release extraction, bridged from the
    // first validated medication context's CDSS metadata (when attached).
    final medMeta = medValidations.isEmpty
        ? null
        : medValidations.first.normalized?.metadata;
    final firstReleaseType = medValidations.isEmpty
        ? null
        : medValidations.first.normalized?.releaseType;
    // dosageSource records WHERE the analyzable dose came from — never a
    // fabricated default. 'user_or_variant_strength' only when dose context is
    // complete; otherwise 'insufficient'/'none'. Product metadata never fills it.
    final dosageSource = firstEntry == null
        ? 'none'
        : (dosageContextComplete ? 'user_or_variant_strength' : 'insufficient');

    return MechanisticReplayCaseReport(
      scenarioId: scenario.scenarioId,
      title: scenario.title,
      userEnteredDosage: userEnteredDosage,
      dosageContextComplete: dosageContextComplete,
      perEventCount: result.perEventCount,
      medicationSourceSystem: medMeta?.sourceSystem,
      medicationSourceDocId: medMeta?.sourceDocId,
      medicationSourceVersion: medMeta?.sourceDocVersion,
      medicationLabelSectionRefCount: medMeta?.labelSectionRefs.length ?? 0,
      medicationReleaseType: medMeta?.releaseType ?? firstReleaseType,
      medicationReleaseTypeSource: medMeta?.releaseTypeSource,
      medicationDoseForm: medMeta?.doseForm,
      medicationRoute: medMeta?.route,
      medicationCombinationComponents:
          medMeta?.components
              .map((c) => c.ingredientName)
              .toList(growable: false) ??
          const [],
      dosageSource: dosageSource,
      medicationMetadataCompleteness: medMeta?.metadataCompleteness,
      medicationMissingFields: medMeta?.missingFields ?? const [],
      mealComponentCount: emptying?.componentProfiles.length ?? 0,
      gastricEmptyingAssumptions: emptying?.assumptions ?? const [],
      absorptionOpennessSampleCount:
          absorptionWindow?.opennessProfile.length ?? 0,
      absorptionPeakOpenness: absorptionWindow?.peakOpenness,
      partialAminoAcidData: lnaa?.partialAminoAcidData ?? false,
      aminoAcidConfidenceTier: lnaa?.aminoAcidConfidenceTier,
      competingLnaaGrams: lnaa?.competingLnaaGrams,
      doseRelativeLnaaAvailable: lnaa?.doseRelativeAvailable ?? false,
      doseRelativeLnaaRatio: lnaa?.doseRelativeLnaaRatio,
      scoringParameterSetId: scoringParamId,
      medicationContextValidity: medValidations.isEmpty
          ? 'none'
          : medValidations.first.validity.name,
      mealContextCompleteness: firstMealCompleteness,
      gastricEmptyingProfileSummary: gastricSummary,
      absorptionOpportunityWindow: result.absorptionOpportunityWindow?.window,
      resultAvailability: result.availability.name,
      hasModeledOutput: result.hasModeledOutput,
      abstentionReasons: abstentionReasons,
      aminoAcidCompetitionBand: result.hasModeledOutput
          ? result.competitionTimeline?.competitionBand.name ?? 'unknown'
          : null,
      interactionScore: result.modeledInteractionScore,
      severityBand: result.modeledSeverityBand?.name,
      confidenceBand: result.modeledConfidenceBand?.name,
      triggeredMechanisms: result.primaryDrivers,
      blockedMechanisms: result.isAbstention
          ? const [
              'food_levodopa_timing_overlap',
              'amino_acid_competition_proxy',
              'delayed_gastric_arrival',
            ]
          : const [],
      sourceRefs: result.sourceRefs,
      limitationText: result.limitationText,
      safetyBoundary: result.safetyBoundary,
      bannedPhraseHits: banned,
      nextMealRecommendationResult: recommendations,
      competitionLnaaSummary: lnaa,
      rankerUsed:
          result.isAbstention ||
              (recommendations != null && modeledRecommendation == null)
          ? 'none_model_abstained'
          : recommendations == null
          ? 'mechanistic_engine_only'
          : 'mechanistic_trace_only_window_sampled',
      sampledWindowOffsets: modeledRecommendation == null
          ? const []
          : modeledRecommendation.sampledWindowSummary
                .map((s) => s.offsetMinutes)
                .toList(growable: false),
      topFinalCandidateScore: modeledRecommendation?.finalCandidateScore,
      topProteinRedistributionScore:
          modeledRecommendation?.proteinRedistributionScore,
      topProteinWindowRole:
          modeledRecommendation?.proteinDistribution?.windowRole.name,
      topNutritionAdequacyContribution:
          modeledRecommendation?.nutritionAdequacyContribution,
      topSourceAuthorityScore: modeledRecommendation?.sourceAuthorityScore,
      topJurisdictionMatchScore: modeledRecommendation?.jurisdictionMatchScore,
      topCandidateSourceSystem: modeledRecommendation?.sourceSystem,
      aminoAcidDataMode: lnaa?.dataMode.name,
      aminoAcidNutrientIds: lnaa?.aminoAcidNutrientIds ?? const [],
      pass: pass,
      failureReason: pass ? null : failures.join('; '),
    );
  }

  ScenarioExpectedOutputType _classifyOutputType(MechanisticConflictResult r) {
    if (!r.hasModeledOutput) {
      return ScenarioExpectedOutputType.insufficientContext;
    }
    if (r.interactionType ==
            MechanisticInteractionType.insufficientMedicationContext ||
        r.interactionType ==
            MechanisticInteractionType.insufficientMealContext) {
      return ScenarioExpectedOutputType.insufficientContext;
    }
    if (r.interactionType == MechanisticInteractionType.noModeledInteraction) {
      return ScenarioExpectedOutputType.noModeledInteraction;
    }
    final severity = r.modeledSeverityBand!;
    if (severity == SeverityBand.moderate || severity == SeverityBand.high) {
      return ScenarioExpectedOutputType.educationalCaution;
    }
    return ScenarioExpectedOutputType.educationalInfo;
  }

  bool _severityAtLeast(SeverityBand actual, SeverityBand floor) {
    const order = [
      SeverityBand.unknown,
      SeverityBand.none,
      SeverityBand.low,
      SeverityBand.moderate,
      SeverityBand.high,
    ];
    return order.indexOf(actual) >= order.indexOf(floor);
  }

  bool _severityAtMost(SeverityBand actual, SeverityBand ceiling) {
    const order = [
      SeverityBand.unknown,
      SeverityBand.none,
      SeverityBand.low,
      SeverityBand.moderate,
      SeverityBand.high,
    ];
    return order.indexOf(actual) <= order.indexOf(ceiling);
  }

  bool _confidenceAtMost(ConfidenceBand actual, ConfidenceBand ceiling) {
    const order = [
      ConfidenceBand.insufficient,
      ConfidenceBand.low,
      ConfidenceBand.medium,
      ConfidenceBand.high,
    ];
    return order.indexOf(actual) <= order.indexOf(ceiling);
  }
}

/// Helper for CLI/test consumers to serialize a report to a JSON string.
String encodeReplayReport(MechanisticReplayRunReport report) =>
    const JsonEncoder.withIndent('  ').convert(report.toJson());
