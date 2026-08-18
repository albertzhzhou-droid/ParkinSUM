import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/absorption_opportunity.dart';
import 'package:parkinsum_companion/domain/entities/amino_acid_competition.dart';
import 'package:parkinsum_companion/domain/entities/amino_acid_profile.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_candidate_score.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_conflict_result.dart';
import 'package:parkinsum_companion/domain/entities/gastric_emptying_profile.dart';
import 'package:parkinsum_companion/domain/entities/protein_distribution.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';

void main() {
  test('available zero is distinguishable from every typed abstention', () {
    final available = _validConflictResult(
      id: 'available-zero',
      score: 0,
      confidenceBand: ConfidenceBand.medium,
      interactionType: MechanisticInteractionType.noModeledInteraction,
    );
    final notApplicable = MechanisticConflictResult.notApplicable(
      id: 'not-applicable',
      reason: MechanisticInteractionType.insufficientMedicationContext,
      reasonCodes: const ['known_outside_supported_domain'],
      sourceRefs: const [],
    );
    final insufficient = MechanisticConflictResult.insufficientContext(
      id: 'insufficient',
      reason: MechanisticInteractionType.insufficientMealContext,
      missingInputs: const ['meal_composition'],
      sourceRefs: const [],
    );
    final blocked = MechanisticConflictResult.blockedIntegrity(
      id: 'blocked',
      reason: MechanisticInteractionType.insufficientMedicationContext,
      integrityReasons: const ['configuration_digest_mismatch'],
      sourceRefs: const [],
    );

    expect(available.availability, MechanisticResultAvailability.available);
    expect(available.hasModeledOutput, isTrue);
    expect(available.modeledInteractionScore, 0);
    expect(available.toJson()['interaction_score'], 0);
    expect(available.toJson()['severity_band'], 'none');
    expect(available.toJson()['confidence_band'], 'medium');

    expect(
      [
        notApplicable,
        insufficient,
        blocked,
      ].map((result) => result.availability),
      [
        MechanisticResultAvailability.notApplicable,
        MechanisticResultAvailability.insufficient,
        MechanisticResultAvailability.blockedIntegrity,
      ],
    );
    for (final result in [notApplicable, insufficient, blocked]) {
      final wire = result.toJson();
      expect(result.hasModeledOutput, isFalse);
      expect(result.modeledInteractionScore, isNull);
      expect(result.modeledSeverityBand, isNull);
      expect(result.modeledConfidenceBand, isNull);
      expect(wire['has_modeled_output'], isFalse);
      expect(wire['interaction_score'], isNull);
      expect(wire['severity_band'], isNull);
      expect(wire['confidence_band'], isNull);
      expect(wire['modeled_timeline_windows'], isEmpty);
      expect(wire['primary_emptying_profile'], isNull);
      expect(wire['absorption_opportunity_window'], isNull);
      expect(wire['competition_timeline'], isNull);
      expect(wire['per_event_count'], 0);
      expect(wire['per_event_traces'], isEmpty);
      expect(wire['abstention_reasons'], isNotEmpty);
    }
  });

  test('public result constructor blocks an empty modeled window contract', () {
    final result = MechanisticConflictResult(
      id: 'ordinary-producer',
      interactionType: MechanisticInteractionType.noModeledInteraction,
      interactionScore: 0,
      severityBand: SeverityBand.none,
      confidenceBand: ConfidenceBand.high,
      primaryDrivers: [],
      modeledTimelineWindows: [],
      uncertaintyReasons: [],
      sourceRefs: [],
      limitationText: '',
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      notAdviceText: RuleExplanation.defaultNotAdvice,
      explanation: MechanisticExplanation(
        resultId: 'ordinary-producer',
        layerTraces: [],
        inputFieldsUsed: [],
        missingOrUncertainInputs: [],
        sourceRefs: [],
        limitationText: '',
        safetyBoundary: RuleExplanation.defaultSafetyBoundary,
        notAdviceText: RuleExplanation.defaultNotAdvice,
      ),
      primaryEmptyingProfile: _validGastricProfile(),
      absorptionOpportunityWindow: _validAbsorptionWindow(),
      competitionTimeline: _validCompetitionTimeline(),
      perEventTraces: [_perEventTrace(score: 0)],
    );

    expect(result.availability, MechanisticResultAvailability.blockedIntegrity);
    expect(result.hasModeledOutput, isFalse);
    expect(result.toJson()['interaction_score'], isNull);
  });

  test('an abstained nested provider blocks the whole available result', () {
    final result = MechanisticConflictResult(
      id: 'nested-provider-abstained',
      interactionType: MechanisticInteractionType.noModeledInteraction,
      interactionScore: 0,
      severityBand: SeverityBand.none,
      confidenceBand: ConfidenceBand.high,
      primaryDrivers: [],
      modeledTimelineWindows: [TimelineWindow(startMinute: 10, endMinute: 20)],
      uncertaintyReasons: [],
      sourceRefs: [],
      limitationText: '',
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      notAdviceText: RuleExplanation.defaultNotAdvice,
      explanation: MechanisticExplanation(
        resultId: 'nested-provider-abstained',
        layerTraces: [],
        inputFieldsUsed: [],
        missingOrUncertainInputs: [],
        sourceRefs: [],
        limitationText: '',
        safetyBoundary: RuleExplanation.defaultSafetyBoundary,
        notAdviceText: RuleExplanation.defaultNotAdvice,
      ),
      primaryEmptyingProfile: GastricEmptyingProfile(
        mealId: 'abstained-meal',
        availability: MechanisticProviderAvailability.blockedIntegrity,
        applicabilityReasons: ['gastric.profile.integrity_failure'],
        componentProfiles: [],
        uncertaintyBand: UncertaintyBand.veryWide,
        assumptions: [],
        missingInputs: [],
        sourceRefs: [],
        aggregateLagMinutes: 0,
        peakEmptyingWindow: TimelineWindow(startMinute: 0, endMinute: 0),
        mostlyEmptiedWindow: TimelineWindow(startMinute: 0, endMinute: 0),
        timeScaleSensitivityFraction: 0,
      ),
      absorptionOpportunityWindow: _validAbsorptionWindow(),
      competitionTimeline: _validCompetitionTimeline(),
      perEventTraces: [_perEventTrace(score: 0)],
    );

    final wire = result.toJson();
    expect(result.availability, MechanisticResultAvailability.blockedIntegrity);
    expect(result.hasModeledOutput, isFalse);
    expect(wire['result_availability'], 'blockedIntegrity');
    expect(wire['interaction_score'], isNull);
    expect(wire['primary_emptying_profile'], isNull);
  });

  test(
    'insufficient candidate wire suppresses every modeled numeric field',
    () {
      final candidate = MechanisticCandidateScore.abstention(
        candidateFoodId: 'candidate',
        candidateName: 'Candidate',
        regionalFoodLibraryRef: 'synthetic',
        userDefinedWindow: const UserDefinedMealWindow(
          window: TimelineWindow(startMinute: 10, endMinute: 20),
          source: 'test',
        ),
        availability: MechanisticResultAvailability.insufficient,
        explanation: ['upstream model unavailable'],
        sourceRefs: const [],
        safetyBoundary: RuleExplanation.defaultSafetyBoundary,
        notAdviceText: RuleExplanation.defaultNotAdvice,
      );

      final wire = candidate.toJson();
      expect(candidate.hasModeledOutput, isFalse);
      expect(candidate.modeledFinalCandidateScore, isNull);
      expect(candidate.modeledSampleCount, isNull);
      expect(wire['result_availability'], 'insufficient');
      expect(wire['has_modeled_output'], isFalse);
      for (final key in [
        'model_compatibility_score',
        'conflict_overlap_score',
        'uncertainty_penalty',
        'nutrition_data_completeness',
        'confidence_band',
        'sample_count',
        'best_sampled_offset_minutes',
        'worst_case_conflict_overlap_score',
        'best_case_conflict_overlap_score',
        'average_conflict_overlap_score',
        'selected_conservative_score',
        'protein_distribution',
        'protein_redistribution_score',
        'nutrition_adequacy_contribution',
        'metadata_completeness_score',
        'source_authority_score',
        'jurisdiction_match_score',
        'provenance_quality_score',
        'final_candidate_score',
      ]) {
        expect(wire[key], isNull, reason: key);
      }
      expect(wire['sampled_window_summary'], isEmpty);
      expect(wire['explanation'], ['upstream model unavailable']);
    },
  );

  test('candidate abstention factory rejects an available status', () {
    expect(
      () => MechanisticCandidateScore.abstention(
        candidateFoodId: 'candidate',
        candidateName: 'Candidate',
        regionalFoodLibraryRef: 'synthetic',
        userDefinedWindow: const UserDefinedMealWindow(
          window: TimelineWindow(startMinute: 10, endMinute: 20),
          source: 'test',
        ),
        availability: MechanisticResultAvailability.available,
        explanation: const [],
        sourceRefs: const [],
        safetyBoundary: RuleExplanation.defaultSafetyBoundary,
        notAdviceText: RuleExplanation.defaultNotAdvice,
      ),
      throwsArgumentError,
    );
  });

  test('candidate and nested upstream availability must agree at runtime', () {
    const window = UserDefinedMealWindow(
      window: TimelineWindow(startMinute: 10, endMinute: 20),
      source: 'test',
    );
    final availableUpstream = _availableUpstream();
    final insufficientUpstream = MechanisticConflictResult.insufficientContext(
      id: 'upstream-insufficient',
      reason: MechanisticInteractionType.insufficientMealContext,
      missingInputs: const ['meal_composition'],
      sourceRefs: const [],
    );

    expect(
      () => MechanisticCandidateScore.abstention(
        candidateFoodId: 'candidate',
        candidateName: 'Candidate',
        regionalFoodLibraryRef: 'synthetic',
        userDefinedWindow: window,
        availability: MechanisticResultAvailability.insufficient,
        explanation: const ['abstained'],
        sourceRefs: const [],
        safetyBoundary: RuleExplanation.defaultSafetyBoundary,
        notAdviceText: RuleExplanation.defaultNotAdvice,
        upstreamResult: availableUpstream,
      ),
      throwsArgumentError,
    );
    final mismatchedAvailable = MechanisticCandidateScore(
      candidateFoodId: 'candidate',
      candidateName: 'Candidate',
      regionalFoodLibraryRef: 'synthetic',
      userDefinedWindow: window,
      modelCompatibilityScore: 0.8,
      conflictOverlapScore: 0.2,
      uncertaintyPenalty: 0.1,
      nutritionDataCompleteness: 1,
      confidenceBand: ConfidenceBand.medium,
      explanation: const ['modeled'],
      sourceRefs: const [],
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      notAdviceText: RuleExplanation.defaultNotAdvice,
      upstreamResult: insufficientUpstream,
    );
    expect(
      mismatchedAvailable.availability,
      MechanisticResultAvailability.blockedIntegrity,
    );
    expect(mismatchedAvailable.toJson()['upstream_result'], isNull);
    expect(mismatchedAvailable.toJson()['final_candidate_score'], isNull);
    expect(
      () => MechanisticCandidateScore.abstention(
        candidateFoodId: 'candidate',
        candidateName: 'Candidate',
        regionalFoodLibraryRef: 'synthetic',
        userDefinedWindow: window,
        availability: MechanisticResultAvailability.notApplicable,
        explanation: const ['outside domain'],
        sourceRefs: const [],
        safetyBoundary: RuleExplanation.defaultSafetyBoundary,
        notAdviceText: RuleExplanation.defaultNotAdvice,
        upstreamResult: insufficientUpstream,
      ),
      throwsArgumentError,
    );

    final matchingAbstention = MechanisticCandidateScore.abstention(
      candidateFoodId: 'candidate',
      candidateName: 'Candidate',
      regionalFoodLibraryRef: 'synthetic',
      userDefinedWindow: window,
      availability: MechanisticResultAvailability.insufficient,
      explanation: const ['abstained'],
      sourceRefs: const [],
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      notAdviceText: RuleExplanation.defaultNotAdvice,
      upstreamResult: insufficientUpstream,
    );
    final upstreamWire =
        matchingAbstention.toJson()['upstream_result'] as Map<String, dynamic>;
    expect(upstreamWire['result_availability'], 'insufficient');
    expect(upstreamWire['interaction_score'], isNull);
    expect(upstreamWire['modeled_timeline_windows'], isEmpty);
  });

  test(
    'malformed available candidates fail closed before JSON or UI output',
    () {
      final fixtures = <String, MechanisticCandidateScore>{
        'NaN final score': _availableCandidate(finalScore: double.nan),
        'out-of-range overlap': _availableCandidate(conflictOverlap: 1.2),
        'infinite metadata': _availableCandidate(
          metadataCompleteness: double.infinity,
        ),
        'insufficient confidence': _availableCandidate(
          confidenceBand: ConfidenceBand.insufficient,
        ),
        'zero samples': _availableCandidate(sampleCount: 0, samples: const []),
        'sample summary mismatch': _availableCandidate(
          sampleCount: 2,
          samples: const [
            MechanisticCandidateSampleSummary(
              offsetMinutes: 0,
              conflictOverlap: 0.2,
              confidenceBand: 'medium',
            ),
          ],
        ),
        'NaN sample': _availableCandidate(
          samples: [
            const MechanisticCandidateSampleSummary(
              offsetMinutes: 0,
              conflictOverlap: 0.2,
              confidenceBand: 'medium',
            ),
            MechanisticCandidateSampleSummary(
              offsetMinutes: 10,
              conflictOverlap: double.nan,
              confidenceBand: 'medium',
            ),
          ],
        ),
        'zero-width window': _availableCandidate(
          window: const UserDefinedMealWindow(
            window: TimelineWindow(startMinute: 10, endMinute: 10),
            source: 'test',
          ),
        ),
        'missing upstream': _availableCandidate(includeUpstream: false),
        'upstream score mismatch': _availableCandidate(upstreamScore: 0.2),
        'upstream confidence mismatch': _availableCandidate(
          upstreamConfidenceBand: ConfidenceBand.low,
        ),
        'unrelated upstream identity': _availableCandidate(
          upstreamId: 'cand_other_10',
        ),
      };

      for (final fixture in fixtures.entries) {
        final candidate = fixture.value;
        final wire = candidate.toJson();
        expect(
          candidate.availability,
          MechanisticResultAvailability.blockedIntegrity,
          reason: fixture.key,
        );
        expect(candidate.hasModeledOutput, isFalse, reason: fixture.key);
        expect(candidate.structuralIntegrityReasons, isNotEmpty);
        expect(wire['result_availability'], 'blockedIntegrity');
        expect(wire['has_modeled_output'], isFalse);
        expect(wire['final_candidate_score'], isNull);
        expect(wire['conflict_overlap_score'], isNull);
        expect(wire['metadata_completeness_score'], isNull);
        expect(wire['sample_count'], isNull);
        expect(wire['sampled_window_summary'], isEmpty);
        expect(wire['protein_distribution'], isNull);
        expect(() => jsonEncode(wire), returnsNormally, reason: fixture.key);
      }
    },
  );

  test('a structurally coherent candidate remains available', () {
    final candidate = _availableCandidate();

    expect(candidate.availability, MechanisticResultAvailability.available);
    expect(candidate.structuralIntegrityReasons, isEmpty);
    expect(candidate.hasModeledOutput, isTrue);
    expect(candidate.toJson()['sample_count'], 2);
    expect(() => jsonEncode(candidate.toJson()), returnsNormally);
  });

  test(
    'malformed per-event traces block the whole result and JSON is safe',
    () {
      final fixtures = <String, List<MechanisticPerEventTrace>>{
        'NaN score': [_perEventTrace(score: double.nan)],
        'duplicate IDs': [
          _perEventTrace(id: 'dose', score: 0.4),
          _perEventTrace(id: 'dose', score: 0.2, isPrimary: false),
        ],
        'empty ID': [_perEventTrace(id: '', score: 0.4)],
        'no primary': [_perEventTrace(score: 0.4, isPrimary: false)],
        'primary does not carry maximum': [
          _perEventTrace(id: 'primary', score: 0.2),
          _perEventTrace(id: 'maximum', score: 0.4, isPrimary: false),
        ],
        'negative provenance count': [
          _perEventTrace(score: 0.4, combinationComponentCount: -1),
        ],
      };

      for (final fixture in fixtures.entries) {
        final result = _resultWithPerEventTraces(fixture.value);
        final wire = result.toJson();
        expect(
          result.availability,
          MechanisticResultAvailability.blockedIntegrity,
          reason: fixture.key,
        );
        expect(result.hasModeledOutput, isFalse, reason: fixture.key);
        expect(result.structuralIntegrityReasons, isNotEmpty);
        expect(wire['result_availability'], 'blockedIntegrity');
        expect(wire['interaction_score'], isNull);
        expect(wire['severity_band'], isNull);
        expect(wire['confidence_band'], isNull);
        expect(wire['per_event_count'], 0);
        expect(wire['per_event_traces'], isEmpty);
        expect(() => jsonEncode(wire), returnsNormally, reason: fixture.key);
      }
    },
  );

  test(
    'available result requires bound providers, explanation, and IR trace',
    () {
      final fixtures = <String, MechanisticConflictResult>{
        'missing gastric provider': _validConflictResult(
          id: 'missing-gastric',
          score: 0.2,
          confidenceBand: ConfidenceBand.medium,
          includeGastric: false,
        ),
        'missing absorption provider': _validConflictResult(
          id: 'missing-absorption',
          score: 0.2,
          confidenceBand: ConfidenceBand.medium,
          includeAbsorption: false,
        ),
        'missing competition provider': _validConflictResult(
          id: 'missing-competition',
          score: 0.2,
          confidenceBand: ConfidenceBand.medium,
          includeCompetition: false,
        ),
        'explanation result mismatch': _validConflictResult(
          id: 'explanation-owner',
          score: 0.2,
          confidenceBand: ConfidenceBand.medium,
          explanationResultId: 'different-result',
        ),
        'absorption primary mismatch': _validConflictResult(
          id: 'absorption-owner',
          score: 0.2,
          confidenceBand: ConfidenceBand.medium,
          absorptionMedicationEventId: 'different-dose',
        ),
        'non-IR per-event release': _validConflictResult(
          id: 'extended-release',
          score: 0.2,
          confidenceBand: ConfidenceBand.medium,
          releaseType: 'extended',
        ),
      };

      for (final fixture in fixtures.entries) {
        final result = fixture.value;
        final wire = result.toJson();
        expect(
          result.availability,
          MechanisticResultAvailability.blockedIntegrity,
          reason: fixture.key,
        );
        expect(result.hasModeledOutput, isFalse, reason: fixture.key);
        expect(result.structuralIntegrityReasons, isNotEmpty);
        expect(wire['interaction_score'], isNull);
        expect(wire['severity_band'], isNull);
        expect(wire['confidence_band'], isNull);
        expect(wire['primary_emptying_profile'], isNull);
        expect(wire['absorption_opportunity_window'], isNull);
        expect(wire['competition_timeline'], isNull);
        expect(wire['per_event_traces'], isEmpty);
        expect(() => jsonEncode(wire), returnsNormally, reason: fixture.key);
      }
    },
  );
}

MechanisticConflictResult _availableUpstream() => _validConflictResult(
  id: 'upstream-available',
  score: 0,
  confidenceBand: ConfidenceBand.medium,
  interactionType: MechanisticInteractionType.noModeledInteraction,
);

MechanisticCandidateScore _availableCandidate({
  double finalScore = 0.7,
  double conflictOverlap = 0.4,
  double metadataCompleteness = 0.8,
  ConfidenceBand confidenceBand = ConfidenceBand.medium,
  int sampleCount = 2,
  List<MechanisticCandidateSampleSummary>? samples,
  UserDefinedMealWindow window = const UserDefinedMealWindow(
    window: TimelineWindow(startMinute: 10, endMinute: 20),
    source: 'test',
  ),
  bool includeUpstream = true,
  String upstreamId = 'cand_candidate_10',
  double? upstreamScore,
  ConfidenceBand? upstreamConfidenceBand,
}) => MechanisticCandidateScore(
  candidateFoodId: 'candidate',
  candidateName: 'Candidate',
  regionalFoodLibraryRef: 'synthetic',
  userDefinedWindow: window,
  modelCompatibilityScore: 0.6,
  conflictOverlapScore: conflictOverlap,
  uncertaintyPenalty: 0.1,
  nutritionDataCompleteness: 0.9,
  confidenceBand: confidenceBand,
  explanation: const ['modeled'],
  sourceRefs: const [],
  safetyBoundary: RuleExplanation.defaultSafetyBoundary,
  notAdviceText: RuleExplanation.defaultNotAdvice,
  upstreamResult: includeUpstream
      ? _validConflictResult(
          id: upstreamId,
          score: upstreamScore ?? conflictOverlap,
          confidenceBand: upstreamConfidenceBand ?? confidenceBand,
        )
      : null,
  sampleCount: sampleCount,
  bestSampledOffsetMinutes: 0,
  worstCaseConflictOverlapScore: 0.4,
  bestCaseConflictOverlapScore: 0.2,
  averageConflictOverlapScore: 0.3,
  selectedConservativeScore: 0.4,
  sampledWindowSummary:
      samples ??
      const [
        MechanisticCandidateSampleSummary(
          offsetMinutes: 0,
          conflictOverlap: 0.2,
          confidenceBand: 'medium',
        ),
        MechanisticCandidateSampleSummary(
          offsetMinutes: 10,
          conflictOverlap: 0.4,
          confidenceBand: 'medium',
        ),
      ],
  proteinDistribution: const ProteinDistributionTrace(
    windowRole: ProteinWindowRole.sensitiveLevodopaOverlapWindow,
    redistributionScore: 0.6,
    nutritionAdequacyContribution: 0.5,
    optimizationActive: true,
    objectiveDescription: 'synthetic',
  ),
  proteinRedistributionScore: 0.6,
  nutritionAdequacyContribution: 0.5,
  metadataCompletenessScore: metadataCompleteness,
  sourceAuthorityScore: 0.7,
  jurisdictionMatchScore: 0.8,
  provenanceQualityScore: 0.75,
  finalCandidateScore: finalScore,
  sourceSystem: 'synthetic',
  jurisdiction: 'US',
  scoringParameterSetId: 'synthetic.v1',
);

MechanisticPerEventTrace _perEventTrace({
  String id = 'dose',
  double score = 0.4,
  bool isPrimary = true,
  int combinationComponentCount = 0,
  String releaseType = 'immediate',
}) => MechanisticPerEventTrace(
  medicationEventId: id,
  medicationMinute: 100,
  isLevodopa: true,
  releaseType: releaseType,
  interactionScore: score,
  competitionBand: 'none',
  delayedArrivalLikelihood: 'low',
  isPrimary: isPrimary,
  sourceRefs: const [],
  uncertaintyReasons: const [],
  combinationComponentCount: combinationComponentCount,
);

MechanisticConflictResult _resultWithPerEventTraces(
  List<MechanisticPerEventTrace> traces,
) => MechanisticConflictResult(
  id: 'per-event-adversarial',
  interactionType: MechanisticInteractionType.foodLevodopaTimingOverlap,
  interactionScore: 0.4,
  severityBand: SeverityBand.high,
  confidenceBand: ConfidenceBand.high,
  primaryDrivers: const [],
  modeledTimelineWindows: const [
    TimelineWindow(startMinute: 10, endMinute: 20),
  ],
  uncertaintyReasons: const [],
  sourceRefs: const [],
  limitationText: MechanisticExplanation.defaultLimitation,
  safetyBoundary: RuleExplanation.defaultSafetyBoundary,
  notAdviceText: RuleExplanation.defaultNotAdvice,
  explanation: const MechanisticExplanation(
    resultId: 'per-event-adversarial',
    layerTraces: [],
    inputFieldsUsed: [],
    missingOrUncertainInputs: [],
    sourceRefs: [],
    limitationText: MechanisticExplanation.defaultLimitation,
    safetyBoundary: RuleExplanation.defaultSafetyBoundary,
    notAdviceText: RuleExplanation.defaultNotAdvice,
  ),
  primaryEmptyingProfile: _validGastricProfile(),
  absorptionOpportunityWindow: _validAbsorptionWindow(),
  competitionTimeline: _validCompetitionTimeline(),
  perEventTraces: traces,
);

MechanisticConflictResult _validConflictResult({
  required String id,
  required double score,
  required ConfidenceBand confidenceBand,
  MechanisticInteractionType interactionType =
      MechanisticInteractionType.foodLevodopaTimingOverlap,
  bool includeGastric = true,
  bool includeAbsorption = true,
  bool includeCompetition = true,
  String? explanationResultId,
  String absorptionMedicationEventId = 'dose',
  String releaseType = 'immediate',
}) => MechanisticConflictResult(
  id: id,
  interactionType: interactionType,
  interactionScore: score,
  severityBand: score >= 0.35
      ? SeverityBand.high
      : score >= 0.15
      ? SeverityBand.moderate
      : score > 0
      ? SeverityBand.low
      : SeverityBand.none,
  confidenceBand: confidenceBand,
  primaryDrivers: const [],
  modeledTimelineWindows: const [
    TimelineWindow(startMinute: 10, endMinute: 20),
  ],
  uncertaintyReasons: const [],
  sourceRefs: const [],
  limitationText: MechanisticExplanation.defaultLimitation,
  safetyBoundary: RuleExplanation.defaultSafetyBoundary,
  notAdviceText: RuleExplanation.defaultNotAdvice,
  explanation: MechanisticExplanation(
    resultId: explanationResultId ?? id,
    layerTraces: const [],
    inputFieldsUsed: const [],
    missingOrUncertainInputs: const [],
    sourceRefs: const [],
    limitationText: MechanisticExplanation.defaultLimitation,
    safetyBoundary: RuleExplanation.defaultSafetyBoundary,
    notAdviceText: RuleExplanation.defaultNotAdvice,
  ),
  primaryEmptyingProfile: includeGastric ? _validGastricProfile() : null,
  absorptionOpportunityWindow: includeAbsorption
      ? _validAbsorptionWindow(id: absorptionMedicationEventId)
      : null,
  competitionTimeline: includeCompetition ? _validCompetitionTimeline() : null,
  perEventTraces: [_perEventTrace(score: score, releaseType: releaseType)],
);

GastricEmptyingProfile _validGastricProfile() => const GastricEmptyingProfile(
  mealId: 'meal',
  componentProfiles: [
    EmptyingComponentProfile(
      componentId: 'solid',
      physicalForm: MealPhysicalForm.solid,
      lagMinutes: 0,
      halfEmptyingMinutes: 60,
      fractionOfMeal: 1,
      appliedModifiers: [],
    ),
  ],
  uncertaintyBand: UncertaintyBand.narrow,
  assumptions: [],
  missingInputs: [],
  sourceRefs: [],
  aggregateLagMinutes: 0,
  peakEmptyingWindow: TimelineWindow(startMinute: 0, endMinute: 90),
  mostlyEmptiedWindow: TimelineWindow(startMinute: 0, endMinute: 240),
  timeScaleSensitivityFraction: 0.2,
);

AbsorptionOpportunityWindow _validAbsorptionWindow({String id = 'dose'}) =>
    AbsorptionOpportunityWindow(
      medicationEventId: id,
      window: const TimelineWindow(startMinute: 10, endMinute: 20),
      peakMinute: 15,
      delayedArrivalLikelihood: DelayedArrivalLikelihood.low,
      uncertaintyBand: UncertaintyBand.narrow,
      assumptions: const [],
      missingInputs: const [],
      sourceRefs: const [],
      opennessProfile: const [
        AbsorptionOpennessSample(minute: 10, openness: 0.2),
        AbsorptionOpennessSample(minute: 15, openness: 0.8),
        AbsorptionOpennessSample(minute: 20, openness: 0.3),
      ],
    );

CompetitionPressureTimeline _validCompetitionTimeline() =>
    const CompetitionPressureTimeline(
      samples: [
        CompetitionPressureSample(minute: 10, pressure: 0.1),
        CompetitionPressureSample(minute: 20, pressure: 0.2),
      ],
      peakMinute: 20,
      peakPressure: 0.2,
      overlapWithAbsorptionWindow: 0.2,
      competitionBand: CompetitionBand.moderate,
      uncertaintyBand: UncertaintyBand.narrow,
      assumptions: [],
      sourceRefs: [],
      lnaaSummary: CompetitionLnaaSummary(
        effectiveLoadFactor: 1,
        sourcesPresent: [],
        isPrototypeHeuristic: true,
        uncertaintyWidened: false,
        sourceRefs: [],
        dataMode: AminoAcidDataMode.proteinSourceProxy,
        actualAminoAcidProteinCoverageFraction: 0,
      ),
    );
