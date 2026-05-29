import 'dart:convert';

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
  final String aminoAcidCompetitionBand;
  final double interactionScore;
  final String severityBand;
  final String confidenceBand;
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
  // phase assumptions, absorption openness-profile summary, LNAA actual-vs-proxy
  // detail, and the active scoring parameter set.
  final int mealComponentCount;
  final List<String> gastricEmptyingAssumptions;
  final int absorptionOpennessSampleCount;
  final double? absorptionPeakOpenness;
  final bool partialAminoAcidData;
  final double? competingLnaaGrams;
  final bool doseRelativeLnaaAvailable;
  final double? doseRelativeLnaaRatio;
  final String scoringParameterSetId;
  final bool pass;
  final String? failureReason;

  const MechanisticReplayCaseReport({
    required this.scenarioId,
    required this.title,
    required this.medicationContextValidity,
    required this.mealContextCompleteness,
    required this.gastricEmptyingProfileSummary,
    required this.absorptionOpportunityWindow,
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
    this.scoringParameterSetId = 'none',
  });

  Map<String, dynamic> toJson() => {
        'scenario_id': scenarioId,
        'title': title,
        'medication_context_validity': medicationContextValidity,
        'meal_context_completeness': mealContextCompleteness,
        'gastric_emptying_profile_summary': gastricEmptyingProfileSummary,
        'absorption_opportunity_window': absorptionOpportunityWindow?.toJson(),
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
        'next_meal_recommendation_result':
            nextMealRecommendationResult?.map((e) => e.toJson()).toList(),
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
        'can_support_mechanism_evidence_alone':
            canSupportMechanismEvidenceAlone,
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
        'scoring_parameter_set_id': scoringParameterSetId,
        'pass': pass,
        'failure_reason': failureReason,
      };
}

class MechanisticReplayRunReport {
  final String generatedAtIso;
  final List<MechanisticReplayCaseReport> cases;

  const MechanisticReplayRunReport({
    required this.generatedAtIso,
    required this.cases,
  });

  bool get allPassed => cases.every((c) => c.pass);
  int get passedCount => cases.where((c) => c.pass).length;
  int get totalCount => cases.length;

  Map<String, dynamic> toJson() => {
        'generated_at': generatedAtIso,
        'passed': passedCount,
        'total': totalCount,
        'cases': cases.map((c) => c.toJson()).toList(growable: false),
      };

  String toMarkdown() {
    final buf = StringBuffer()
      ..writeln('# Mechanistic Replay Report')
      ..writeln()
      ..writeln('Generated: $generatedAtIso')
      ..writeln()
      ..writeln('**$passedCount / $totalCount scenarios passed.**')
      ..writeln();
    for (final c in cases) {
      buf
        ..writeln('## ${c.scenarioId} — ${c.title}')
        ..writeln('- pass: ${c.pass}')
        ..writeln(
            '- interaction_score: ${c.interactionScore.toStringAsFixed(3)}')
        ..writeln('- severity_band: ${c.severityBand}')
        ..writeln('- confidence_band: ${c.confidenceBand}')
        ..writeln(
            '- amino_acid_competition_band: ${c.aminoAcidCompetitionBand}')
        ..writeln('- gastric_emptying: ${c.gastricEmptyingProfileSummary}')
        ..writeln('- banned_phrase_hits: ${c.bannedPhraseHits.length}')
        ..writeln();
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

  MechanisticReplayRunner({
    MedicationEntryValidator? validator,
    MealCompositionNormalizer? normalizer,
    TimeAxisBuilder? timeAxisBuilder,
    MechanisticConflictEngine? engine,
    MechanisticNextMealScorer? scorer,
  })  : validator = validator ?? MedicationEntryValidator(),
        normalizer = normalizer ?? MealCompositionNormalizer(),
        timeAxisBuilder = timeAxisBuilder ?? TimeAxisBuilder(),
        engine = engine ?? MechanisticConflictEngine(),
        scorer = scorer ?? MechanisticNextMealScorer();

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
      cases: List.unmodifiable(cases),
    );
  }

  MechanisticReplayCaseReport _runOne(
      MechanisticReplayScenario scenario, DateTime now) {
    // Validate medications.
    final medValidations = scenario.medicationEntries
        .map(validator.validate)
        .toList(growable: false);

    final medicationInputs = <MedicationTimelineInput>[];
    for (var i = 0; i < medValidations.length; i++) {
      final v = medValidations[i];
      final offset = scenario.medicationMinutesOffsets[i].minutes;
      medicationInputs.add(MedicationTimelineInput(
        id: 'med_${scenario.scenarioId}_$i',
        takenAt: now.add(Duration(minutes: offset)),
        medicationContext: v,
      ));
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
      mealInputs.add(MealTimelineInput(
        id: m.id,
        startedAt: now.add(Duration(minutes: m.offset.minutes)),
        compositionId: comp.id,
        physicalForm: m.physicalForm,
      ));
    }

    final context = timeAxisBuilder.build(
      now: now,
      medicationInputs: medicationInputs,
      mealInputs: mealInputs,
      userDefinedWindow: scenario.userDefinedWindow == null
          ? null
          : UserDefinedMealWindow(
              window: TimelineWindow(
                startMinute: dateTimeToMinute(now) +
                    scenario.userDefinedWindow!.window.startMinute,
                endMinute: dateTimeToMinute(now) +
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
      if (result.interactionType !=
              MechanisticInteractionType.insufficientMedicationContext &&
          result.interactionType !=
              MechanisticInteractionType.insufficientMealContext) {
        failures.add(
            'expected insufficient_context but got ${result.interactionType.name}');
      }
    } else {
      // Coarse check: align expected output type with engine output.
      final outType = _classifyOutputType(result);
      if (outType != expectedType) {
        failures.add('expected $expectedType but got $outType');
      }
    }

    if (scenario.expectedSeverityFloor != null &&
        !_severityAtLeast(
            result.severityBand, scenario.expectedSeverityFloor!)) {
      failures.add('severity below expected floor');
    }
    if (scenario.expectedSeverityCeiling != null &&
        !_severityAtMost(
            result.severityBand, scenario.expectedSeverityCeiling!)) {
      failures.add('severity above expected ceiling');
    }
    if (scenario.expectedConfidenceCeiling != null &&
        !_confidenceAtMost(
            result.confidenceBand, scenario.expectedConfidenceCeiling!)) {
      failures.add('confidence above expected ceiling');
    }
    if (scenario.expectNonEmptyRecommendations &&
        (recommendations == null || recommendations.isEmpty)) {
      failures.add('expected non-empty recommendations');
    }
    if (banned.isNotEmpty) {
      failures.add('banned phrases: ${banned.join(", ")}');
    }

    final pass = failures.isEmpty;

    final firstMealCompleteness = scenario.meals.isEmpty
        ? 0.0
        : (compositionsById.values.firstWhere(
                (c) => c.id.startsWith('comp_${scenario.scenarioId}_'),
                orElse: () => compositionsById.values.first))
            .compositionCompleteness;

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
            : (firstEntry.strength != null &&
                    (firstEntry.unit ?? '').isNotEmpty)
                ? '${firstEntry.strength} ${firstEntry.unit}'
                : 'none';
    final dosageContextComplete = medValidations.isNotEmpty &&
        medValidations.first.validity == MedicationContextValidity.valid;

    // Upgraded-chain transparency (#7). LNAA detail comes from the meal-level
    // competition when a meal is present, otherwise from the top scored
    // candidate's upstream competition (candidate-only scenarios have no meal).
    final emptying = result.primaryEmptyingProfile;
    final absorptionWindow = result.absorptionOpportunityWindow;
    final lnaa = result.competitionTimeline?.lnaaSummary ??
        ((recommendations != null && recommendations.isNotEmpty)
            ? recommendations
                .first.upstreamResult?.competitionTimeline?.lnaaSummary
            : null);
    final scoringParamId = (recommendations == null || recommendations.isEmpty)
        ? 'none'
        : recommendations.first.scoringParameterSetId;

    return MechanisticReplayCaseReport(
      scenarioId: scenario.scenarioId,
      title: scenario.title,
      userEnteredDosage: userEnteredDosage,
      dosageContextComplete: dosageContextComplete,
      perEventCount: result.perEventCount,
      mealComponentCount: emptying?.componentProfiles.length ?? 0,
      gastricEmptyingAssumptions: emptying?.assumptions ?? const [],
      absorptionOpennessSampleCount:
          absorptionWindow?.opennessProfile.length ?? 0,
      absorptionPeakOpenness: absorptionWindow?.peakOpenness,
      partialAminoAcidData: lnaa?.partialAminoAcidData ?? false,
      competingLnaaGrams: lnaa?.competingLnaaGrams,
      doseRelativeLnaaAvailable: lnaa?.doseRelativeAvailable ?? false,
      doseRelativeLnaaRatio: lnaa?.doseRelativeLnaaRatio,
      scoringParameterSetId: scoringParamId,
      medicationContextValidity:
          medValidations.isEmpty ? 'none' : medValidations.first.validity.name,
      mealContextCompleteness: firstMealCompleteness,
      gastricEmptyingProfileSummary: gastricSummary,
      absorptionOpportunityWindow: result.absorptionOpportunityWindow?.window,
      aminoAcidCompetitionBand:
          result.competitionTimeline?.competitionBand.name ?? 'unknown',
      interactionScore: result.interactionScore,
      severityBand: result.severityBand.name,
      confidenceBand: result.confidenceBand.name,
      triggeredMechanisms: result.primaryDrivers,
      blockedMechanisms: scenario.expectInsufficientContext
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
      rankerUsed: recommendations == null
          ? 'mechanistic_engine_only'
          : 'mechanistic_primary_window_sampled',
      sampledWindowOffsets: (recommendations == null || recommendations.isEmpty)
          ? const []
          : recommendations.first.sampledWindowSummary
              .map((s) => s.offsetMinutes)
              .toList(growable: false),
      topFinalCandidateScore:
          (recommendations == null || recommendations.isEmpty)
              ? null
              : recommendations.first.finalCandidateScore,
      topProteinRedistributionScore:
          (recommendations == null || recommendations.isEmpty)
              ? null
              : recommendations.first.proteinRedistributionScore,
      topProteinWindowRole: (recommendations == null || recommendations.isEmpty)
          ? null
          : recommendations.first.proteinDistribution?.windowRole.name,
      topNutritionAdequacyContribution:
          (recommendations == null || recommendations.isEmpty)
              ? null
              : recommendations.first.nutritionAdequacyContribution,
      topSourceAuthorityScore:
          (recommendations == null || recommendations.isEmpty)
              ? null
              : recommendations.first.sourceAuthorityScore,
      topJurisdictionMatchScore:
          (recommendations == null || recommendations.isEmpty)
              ? null
              : recommendations.first.jurisdictionMatchScore,
      topCandidateSourceSystem:
          (recommendations == null || recommendations.isEmpty)
              ? null
              : recommendations.first.sourceSystem,
      aminoAcidDataMode: lnaa?.dataMode.name,
      aminoAcidNutrientIds: lnaa?.aminoAcidNutrientIds ?? const [],
      pass: pass,
      failureReason: pass ? null : failures.join('; '),
    );
  }

  ScenarioExpectedOutputType _classifyOutputType(MechanisticConflictResult r) {
    if (r.interactionType ==
            MechanisticInteractionType.insufficientMedicationContext ||
        r.interactionType ==
            MechanisticInteractionType.insufficientMealContext) {
      return ScenarioExpectedOutputType.insufficientContext;
    }
    if (r.interactionType == MechanisticInteractionType.noModeledInteraction) {
      return ScenarioExpectedOutputType.noModeledInteraction;
    }
    if (r.severityBand == SeverityBand.moderate ||
        r.severityBand == SeverityBand.high) {
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
