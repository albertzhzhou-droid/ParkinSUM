import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:parkinsum_companion/core/models/interaction_result.dart';
import 'package:parkinsum_companion/domain/entities/absorption_opportunity.dart';
import 'package:parkinsum_companion/domain/entities/amino_acid_competition.dart';
import 'package:parkinsum_companion/domain/entities/amino_acid_profile.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_candidate_score.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_conflict_result.dart';
import 'package:parkinsum_companion/domain/entities/gastric_emptying_profile.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/features/shared/mechanistic_trace_view.dart';

void main() {
  test('fromJson populates score, severity, confidence, drivers, and refs '
      'label', () {
    final view = MechanisticTraceViewModel.fromJson({
      'result_availability': 'available',
      'has_modeled_output': true,
      'interaction_type': 'aminoAcidCompetitionProxy',
      'interaction_score': 0.32,
      'severity_band': 'moderate',
      'confidence_band': 'medium',
      'primary_drivers': ['amino_acid_competition_proxy_moderate'],
      'modeled_timeline_windows': [
        {'start_minute': 0, 'end_minute': 90},
      ],
      'uncertainty_reasons': ['meal_composition_incomplete'],
      'limitation_text': 'Educational only.',
      'safety_boundary': RuleExplanation.defaultSafetyBoundary,
      'not_advice_text': RuleExplanation.defaultNotAdvice,
      'source_refs': ['src.dailymed.sinemet.label'],
      ..._validAvailableProviderWireBundle('trace-score'),
      ..._validPerEventWire(0.32),
    });
    expect(view.scoreText, '0.32');
    expect(view.severityLabel, 'moderate');
    expect(view.confidenceLabel, 'medium');
    expect(view.insufficientContext, isFalse);
    expect(
      view.primaryDrivers,
      contains('amino_acid_competition_proxy_moderate'),
    );
    expect(view.sourceRefsLabel, contains('Sources (1)'));
  });

  test('no banned substrings appear in formatted output', () {
    final view = MechanisticTraceViewModel.fromJson({
      'result_availability': 'available',
      'has_modeled_output': true,
      'interaction_type': 'noModeledInteraction',
      'interaction_score': 0.0,
      'severity_band': 'none',
      'confidence_band': 'high',
      'primary_drivers': [],
      'modeled_timeline_windows': [
        {'start_minute': 0, 'end_minute': 90},
      ],
      'uncertainty_reasons': [],
      'limitation_text': 'Educational only.',
      'safety_boundary': RuleExplanation.defaultSafetyBoundary,
      'not_advice_text': RuleExplanation.defaultNotAdvice,
      'source_refs': [],
      ..._validAvailableProviderWireBundle('trace-copy'),
      ..._validPerEventWire(0),
    });
    final blob = [
      view.scoreText,
      view.severityLabel,
      view.confidenceLabel,
      view.limitationText,
      view.safetyBoundary,
      view.notAdviceText,
      view.sourceRefsLabel,
    ].join(' ');
    expect(findBannedSubstrings(blob), isEmpty);
  });

  test('empty source refs label says "none recorded"', () {
    final view = MechanisticTraceViewModel.fromJson({
      'result_availability': 'available',
      'has_modeled_output': true,
      'interaction_type': 'noModeledInteraction',
      'interaction_score': 0.0,
      'severity_band': 'none',
      'confidence_band': 'high',
      'primary_drivers': [],
      'modeled_timeline_windows': [
        {'start_minute': 0, 'end_minute': 90},
      ],
      'uncertainty_reasons': [],
      'limitation_text': '',
      'safety_boundary': RuleExplanation.defaultSafetyBoundary,
      'not_advice_text': RuleExplanation.defaultNotAdvice,
      'source_refs': [],
      ..._validAvailableProviderWireBundle('trace-sources'),
      ..._validPerEventWire(0),
    });
    expect(view.sourceRefsLabel, contains('none recorded'));
  });

  testWidgets(
    'known unsupported medication renders not-applicable without a zero score',
    (tester) async {
      final result = MechanisticConflictResult.notApplicable(
        id: 'synthetic:unsupported-medication',
        reason: MechanisticInteractionType.insufficientMedicationContext,
        reasonCodes: const [
          'medication.active_ingredient(levodopa)',
          'medication.route(oral)',
        ],
        sourceRefs: const ['src.dailymed.sinemet.label'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MechanisticConflictTraceCard(typedResult: result),
          ),
        ),
      );

      expect(find.textContaining('Model not applicable'), findsOneWidget);
      expect(find.textContaining('Interaction score 0.00'), findsNothing);

      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      expect(find.text('status not applicable'), findsOneWidget);
      expect(find.text('score 0.00'), findsNothing);
      expect(find.textContaining('confidence insufficient'), findsNothing);
      expect(
        find.textContaining('medication.active_ingredient(levodopa)'),
        findsOneWidget,
      );
    },
  );

  testWidgets('insufficient and integrity-blocked states remain distinct', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final insufficient = MechanisticConflictResult.insufficientContext(
      id: 'synthetic:missing-meal',
      reason: MechanisticInteractionType.insufficientMealContext,
      missingInputs: const ['meal_composition'],
      sourceRefs: const [],
    );
    final blocked = MechanisticConflictResult.blockedIntegrity(
      id: 'synthetic:blocked-integrity',
      reason: MechanisticInteractionType.insufficientMedicationContext,
      integrityReasons: const ['configuration_digest_mismatch'],
      sourceRefs: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MechanisticConflictTraceCard(typedResult: insufficient),
              MechanisticConflictTraceCard(typedResult: blocked),
            ],
          ),
        ),
      ),
    );

    expect(find.textContaining('Model abstained'), findsOneWidget);
    expect(find.textContaining('insufficient meal context'), findsOneWidget);
    expect(find.textContaining('Model blocked'), findsOneWidget);
    expect(find.textContaining('integrity check failed'), findsOneWidget);
    expect(find.textContaining('Interaction score 0.00'), findsNothing);
    expect(find.textContaining('confidence insufficient'), findsNothing);

    for (final tile in find.byType(ExpansionTile).evaluate()) {
      await tester.tap(find.byWidget(tile.widget));
      await tester.pumpAndSettle();
    }
    expect(find.text('status insufficient data'), findsOneWidget);
    expect(find.text('status integrity blocked'), findsOneWidget);
    expect(find.textContaining('score 0.00'), findsNothing);
  });

  test(
    'malicious abstention payload cannot smuggle modeled output into UI',
    () {
      final view = MechanisticTraceViewModel.fromJson({
        'result_availability': 'notApplicable',
        'has_modeled_output': false,
        'interaction_type': 'insufficientMedicationContext',
        'interaction_score': 0.91,
        'severity_band': 'high',
        'confidence_band': 'high',
        'primary_drivers': ['fabricated_driver'],
        'modeled_timeline_windows': [
          {'start_minute': 10, 'end_minute': 10},
        ],
        'abstention_reasons': ['known_outside_supported_domain'],
        'source_refs': <String>[],
      });

      expect(view.availability, MechanisticResultAvailability.notApplicable);
      expect(view.hasModeledOutput, isFalse);
      expect(view.scoreText, '—');
      expect(view.severityLabel, '—');
      expect(view.confidenceLabel, '—');
      expect(view.primaryDrivers, isEmpty);
      expect(view.modeledWindowsLabel, isEmpty);
      expect(view.missingInputs, ['known_outside_supported_domain']);
    },
  );

  test('contradictory availability markers are integrity-blocked', () {
    final view = MechanisticTraceViewModel.fromJson({
      'result_availability': 'available',
      'has_modeled_output': false,
      'interaction_score': 0.4,
      'severity_band': 'moderate',
      'confidence_band': 'high',
      'source_refs': <String>[],
    });

    expect(view.availability, MechanisticResultAvailability.blockedIntegrity);
    expect(view.scoreText, '—');
    expect(view.missingInputs, [
      'mechanistic_result.integrity_contract_invalid',
    ]);
  });

  test('malformed trace field types fail closed without throwing', () {
    late MechanisticTraceViewModel view;

    expect(
      () => view = MechanisticTraceViewModel.fromJson({
        'result_availability': 'available',
        'has_modeled_output': true,
        'interaction_score': '0.80',
        'severity_band': 7,
        'confidence_band': 'high',
        'primary_drivers': <String, String>{'driver': 'fabricated'},
        'modeled_timeline_windows': '10-20',
        'source_refs': <String, String>{
          'id': 'src.internal.prototype.heuristic',
        },
      }),
      returnsNormally,
    );
    expect(view.availability, MechanisticResultAvailability.blockedIntegrity);
    expect(view.hasModeledOutput, isFalse);
    expect(view.scoreText, '—');
    expect(view.severityLabel, '—');
    expect(view.confidenceLabel, '—');
    expect(view.primaryDrivers, isEmpty);
    expect(view.modeledWindowsLabel, isEmpty);
    expect(view.statusLabel, 'integrity blocked');
  });

  test('available trace cross-field contradictions are integrity-blocked', () {
    Map<String, dynamic> validPayload() => {
      'result_availability': 'available',
      'has_modeled_output': true,
      'interaction_type': 'foodLevodopaTimingOverlap',
      'interaction_score': 0.2,
      'severity_band': 'moderate',
      'confidence_band': 'medium',
      'primary_drivers': <String>[],
      'modeled_timeline_windows': [
        {'start_minute': 10, 'end_minute': 100},
      ],
      'uncertainty_reasons': <String>[],
      'source_refs': <String>[],
      ..._validAvailableProviderWireBundle('trace-cross-field'),
      ..._validPerEventWire(0.2),
    };

    final payloads = <Map<String, dynamic>>[
      {...validPayload(), 'interaction_type': 'fabricatedInteraction'},
      {...validPayload(), 'interaction_score': 0.95, 'severity_band': 'none'},
      {...validPayload(), 'confidence_band': 'insufficient'},
      {...validPayload(), 'primary_drivers': null},
      {...validPayload(), 'modeled_timeline_windows': null},
      {
        ...validPayload(),
        'modeled_timeline_windows': [
          {'start_minute': 10, 'end_minute': 10},
        ],
      },
    ];

    for (final payload in payloads) {
      final view = MechanisticTraceViewModel.fromJson(payload);
      expect(view.availability, MechanisticResultAvailability.blockedIntegrity);
      expect(view.hasModeledOutput, isFalse);
      expect(view.scoreText, '—');
      expect(view.severityLabel, '—');
      expect(view.confidenceLabel, '—');
      expect(view.primaryDrivers, isEmpty);
      expect(view.modeledWindowsLabel, isEmpty);
    }
  });

  test('missing typed availability markers never infer modeled output', () {
    final payloads = <Map<String, dynamic>>[
      {
        'interaction_score': 0.8,
        'severity_band': 'high',
        'confidence_band': 'high',
      },
      {
        'result_availability': 'available',
        'interaction_score': 0.8,
        'severity_band': 'high',
        'confidence_band': 'high',
      },
      {
        'has_modeled_output': true,
        'interaction_score': 0.8,
        'severity_band': 'high',
        'confidence_band': 'high',
      },
    ];

    for (final payload in payloads) {
      final view = MechanisticTraceViewModel.fromJson(payload);
      expect(view.availability, MechanisticResultAvailability.blockedIntegrity);
      expect(view.hasModeledOutput, isFalse);
      expect(view.scoreText, '—');
      expect(view.severityLabel, '—');
      expect(view.confidenceLabel, '—');
    }
  });

  testWidgets('candidate abstentions render exact typed status without zero', (
    tester,
  ) async {
    MechanisticCandidateScore abstention(
      String id,
      MechanisticResultAvailability availability,
    ) => MechanisticCandidateScore.abstention(
      candidateFoodId: id,
      candidateName: id,
      regionalFoodLibraryRef: 'synthetic',
      userDefinedWindow: const UserDefinedMealWindow(
        window: TimelineWindow(startMinute: 10, endMinute: 20),
        source: 'test',
      ),
      availability: availability,
      explanation: const ['No modeled candidate output.'],
      sourceRefs: const [],
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      notAdviceText: RuleExplanation.defaultNotAdvice,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MechanisticCandidateScoreLine(
                score: abstention(
                  'outside domain',
                  MechanisticResultAvailability.notApplicable,
                ),
              ),
              MechanisticCandidateScoreLine(
                score: abstention(
                  'missing input',
                  MechanisticResultAvailability.insufficient,
                ),
              ),
              MechanisticCandidateScoreLine(
                score: abstention(
                  'integrity failure',
                  MechanisticResultAvailability.blockedIntegrity,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('status not applicable'), findsOneWidget);
    expect(find.text('status insufficient data'), findsOneWidget);
    expect(find.text('status integrity blocked'), findsOneWidget);
    expect(find.textContaining('conf insufficient'), findsNothing);
    expect(find.textContaining('worst 0%'), findsNothing);
    expect(find.textContaining('samples 0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('valid typed result with nested providers roundtrips as available', () {
    final typed = MechanisticConflictResult(
      id: 'typed-roundtrip',
      interactionType: MechanisticInteractionType.foodLevodopaTimingOverlap,
      interactionScore: 0.2,
      severityBand: SeverityBand.moderate,
      confidenceBand: ConfidenceBand.medium,
      primaryDrivers: const ['synthetic_driver'],
      modeledTimelineWindows: const [
        TimelineWindow(startMinute: 0, endMinute: 30),
        TimelineWindow(startMinute: 10, endMinute: 20),
      ],
      uncertaintyReasons: const [],
      sourceRefs: const [],
      limitationText: MechanisticExplanation.defaultLimitation,
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      notAdviceText: RuleExplanation.defaultNotAdvice,
      explanation: const MechanisticExplanation(
        resultId: 'typed-roundtrip',
        layerTraces: [],
        inputFieldsUsed: [],
        missingOrUncertainInputs: [],
        sourceRefs: [],
        limitationText: MechanisticExplanation.defaultLimitation,
        safetyBoundary: RuleExplanation.defaultSafetyBoundary,
        notAdviceText: RuleExplanation.defaultNotAdvice,
      ),
      primaryEmptyingProfile: const GastricEmptyingProfile(
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
      ),
      absorptionOpportunityWindow: const AbsorptionOpportunityWindow(
        medicationEventId: 'dose',
        window: TimelineWindow(startMinute: 10, endMinute: 20),
        peakMinute: 15,
        delayedArrivalLikelihood: DelayedArrivalLikelihood.low,
        uncertaintyBand: UncertaintyBand.narrow,
        assumptions: [],
        missingInputs: [],
        sourceRefs: [],
        opennessProfile: [
          AbsorptionOpennessSample(minute: 10, openness: 0.2),
          AbsorptionOpennessSample(minute: 15, openness: 0.8),
          AbsorptionOpennessSample(minute: 20, openness: 0.3),
        ],
      ),
      competitionTimeline: const CompetitionPressureTimeline(
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
      ),
      perEventTraces: const [
        MechanisticPerEventTrace(
          medicationEventId: 'dose',
          medicationMinute: 10,
          isLevodopa: true,
          releaseType: 'immediate',
          interactionScore: 0.2,
          competitionBand: 'low',
          delayedArrivalLikelihood: 'low',
          isPrimary: true,
          sourceRefs: [],
          uncertaintyReasons: [],
        ),
      ],
    );

    expect(
      typed.hasModeledOutput,
      isTrue,
      reason: typed.structuralIntegrityReasons.join(', '),
    );
    final view = MechanisticTraceViewModel.fromJson(typed.toJson());
    expect(view.availability, MechanisticResultAvailability.available);
    expect(view.scoreText, '0.20');
    expect(view.modeledWindowsLabel, isNotEmpty);
  });

  test(
    'persisted per-event and nested-provider contradictions fail closed',
    () {
      final valid = _validAvailablePersistedPayload();
      final validTrace = _validPerEventTrace(0.2);
      final validGastric =
          valid['primary_emptying_profile'] as Map<dynamic, dynamic>;
      final validAbsorption =
          valid['absorption_opportunity_window'] as Map<dynamic, dynamic>;
      final validCompetition =
          valid['competition_timeline'] as Map<dynamic, dynamic>;
      final validLnaa =
          validCompetition['lnaa_summary'] as Map<dynamic, dynamic>;
      final payloads = <Map<String, dynamic>>[
        {...valid}..remove('per_event_count'),
        {...valid}..remove('primary_emptying_profile'),
        {...valid}..remove('absorption_opportunity_window'),
        {...valid}..remove('competition_timeline'),
        {...valid, 'per_event_count': 2},
        {
          ...valid,
          'primary_emptying_profile': {
            ...validGastric,
            'aggregate_lag_minutes': 1.0,
          },
        },
        {
          ...valid,
          'primary_emptying_profile': {
            ...validGastric,
            'peak_emptying_window': const {'start_minute': 0, 'end_minute': 91},
          },
        },
        {
          ...valid,
          'primary_emptying_profile': {
            ...validGastric,
            'mostly_emptied_window': const {
              'start_minute': 1,
              'end_minute': 241,
            },
          },
        },
        {
          ...valid,
          'primary_emptying_profile': {
            ...validGastric,
            'mostly_emptied_window': const {
              'start_minute': 0,
              'end_minute': 241,
            },
          },
        },
        {
          ...valid,
          'competition_timeline': {
            ...validCompetition,
            'competition_band': 'none',
          },
        },
        {
          ...valid,
          'per_event_count': 2,
          'per_event_traces': [
            validTrace,
            {...validTrace, 'is_primary': false},
          ],
        },
        {
          ...valid,
          'explanation': {'result_id': 'different-result'},
        },
        {
          ...valid,
          'absorption_opportunity_window': {
            ...validAbsorption,
            'medication_event_id': 'different-dose',
          },
        },
        {
          ...valid,
          'absorption_opportunity_window': {
            ...validAbsorption,
            'openness_profile': const [
              {'minute': 10, 'openness': 0.0},
              {'minute': 15, 'openness': 0.0},
              {'minute': 20, 'openness': 0.0},
            ],
            'peak_openness': 0.0,
          },
        },
        {
          ...valid,
          'competition_timeline': {
            ...validCompetition,
            'lnaa_summary': {
              ...validLnaa,
              'effective_load_factor': 1.1,
              'data_mode': 'unknown',
              'sources_present': const ['unknown'],
              'uncertainty_widened': true,
              'partial_amino_acid_data': false,
              'actual_amino_acid_protein_coverage_fraction': null,
            },
          },
        },
        {
          ...valid,
          'competition_timeline': {
            ...validCompetition,
            'lnaa_summary': {...validLnaa, 'effective_load_factor': 2.0},
          },
        },
        {
          ...valid,
          'per_event_traces': [
            {...validTrace, 'release_type': 'extended'},
          ],
        },
        {
          ...valid,
          'per_event_count': 2,
          'per_event_traces': [
            _validPerEventTrace(0.1, id: 'primary'),
            _validPerEventTrace(0.2, id: 'maximum', isPrimary: false),
          ],
        },
        {
          ...valid,
          'primary_emptying_profile': {
            'result_availability': 'blockedIntegrity',
            'has_modeled_output': false,
            'model_applicable': false,
          },
        },
        {
          ...valid,
          'primary_emptying_profile': {
            'result_availability': 'available',
            'has_modeled_output': true,
            'model_applicable': true,
            'component_profiles': <Map<String, dynamic>>[],
            'aggregate_lag_minutes': 0,
            'peak_emptying_window': {'start_minute': 0, 'end_minute': 30},
            'mostly_emptied_window': {'start_minute': 0, 'end_minute': 180},
            'time_scale_sensitivity_fraction': 0.2,
          },
        },
        {
          ...valid,
          'absorption_opportunity_window': {
            'result_availability': 'available',
            'has_modeled_output': true,
            'model_applicable': true,
            'window': {'start_minute': 10, 'end_minute': 20},
            'peak_minute': 15,
            'openness_profile': <Map<String, dynamic>>[],
            'peak_openness': 0.8,
          },
        },
        {
          ...valid,
          'competition_timeline': {
            'result_availability': 'available',
            'has_modeled_output': true,
            'model_applicable': true,
            'samples': <Map<String, dynamic>>[],
            'peak_minute': 20,
            'peak_pressure': 0.2,
            'overlap_with_absorption_window': 0.2,
            'competition_band': 'low',
          },
        },
      ];

      for (final payload in payloads) {
        final view = MechanisticTraceViewModel.fromJson(payload);
        expect(
          view.availability,
          MechanisticResultAvailability.blockedIntegrity,
        );
        expect(view.scoreText, '—');
        expect(view.severityLabel, '—');
        expect(view.confidenceLabel, '—');
        expect(view.primaryDrivers, isEmpty);
        expect(view.modeledWindowsLabel, isEmpty);
      }
    },
  );

  testWidgets('invalid persisted provider shape renders no numbers or charts', (
    tester,
  ) async {
    final payload = _validAvailablePersistedPayload();
    final competition =
        payload['competition_timeline'] as Map<dynamic, dynamic>;
    final lnaa = competition['lnaa_summary'] as Map<dynamic, dynamic>;
    payload['competition_timeline'] = {
      ...competition,
      'lnaa_summary': {
        ...lnaa,
        'effective_load_factor': 1.1,
        'data_mode': 'unknown',
        'sources_present': const ['unknown'],
        'uncertainty_widened': true,
        'partial_amino_acid_data': false,
        'actual_amino_acid_protein_coverage_fraction': null,
      },
    };
    final result = InteractionResult(
      mealId: 'meal',
      status: InteractionStatus.ok,
      summary: 'synthetic',
      issues: const [],
      generatedAt: DateTime.utc(2026, 1, 1),
      score: 0,
      mechanisticTraceJson: payload,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MechanisticConflictTraceCard(result: result)),
      ),
    );

    expect(find.textContaining('Model blocked'), findsOneWidget);
    expect(find.textContaining('Interaction score 0.20'), findsNothing);
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    expect(find.text('status integrity blocked'), findsOneWidget);
    expect(find.textContaining('score 0.20'), findsNothing);
    expect(find.text('Modeled timeline windows'), findsNothing);
    expect(find.text('Primary modeled drivers'), findsNothing);
    expect(find.text('Gastric residence sensitivity'), findsNothing);
  });

  testWidgets(
    'derived persisted contradictions render blocked without numbers or charts',
    (tester) async {
      final valid = _validAvailablePersistedPayload();
      final gastric =
          valid['primary_emptying_profile'] as Map<dynamic, dynamic>;
      final competition =
          valid['competition_timeline'] as Map<dynamic, dynamic>;
      final payloads = <Map<String, dynamic>>[
        {
          ...valid,
          'primary_emptying_profile': {
            ...gastric,
            'aggregate_lag_minutes': 999.0,
          },
        },
        {
          ...valid,
          'competition_timeline': {...competition, 'competition_band': 'none'},
        },
      ];

      for (final payload in payloads) {
        final result = InteractionResult(
          mealId: 'meal',
          status: InteractionStatus.ok,
          summary: 'synthetic',
          issues: const [],
          generatedAt: DateTime.utc(2026, 1, 1),
          score: 0,
          mechanisticTraceJson: payload,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: MechanisticConflictTraceCard(result: result)),
          ),
        );

        expect(find.textContaining('Model blocked'), findsOneWidget);
        expect(find.textContaining('Interaction score 0.20'), findsNothing);
        await tester.tap(find.byType(ExpansionTile));
        await tester.pumpAndSettle();
        expect(find.text('status integrity blocked'), findsOneWidget);
        expect(find.textContaining('score 0.20'), findsNothing);
        expect(find.text('Modeled timeline windows'), findsNothing);
        expect(find.text('Primary modeled drivers'), findsNothing);
        expect(find.text('Gastric residence sensitivity'), findsNothing);
      }
    },
  );

  testWidgets('missing meal macros render an abstention status, never zero', (
    tester,
  ) async {
    final result = MechanisticConflictResult.insufficientContext(
      id: 'synthetic:missing-macros',
      reason: MechanisticInteractionType.insufficientMealContext,
      missingInputs: const ['meal_composition(c1).protein_grams'],
      sourceRefs: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MechanisticConflictTraceCard(typedResult: result)),
      ),
    );
    expect(find.textContaining('Model abstained'), findsOneWidget);
    expect(find.textContaining('Interaction score 0'), findsNothing);

    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    expect(find.text('status insufficient data'), findsOneWidget);
    expect(
      find.textContaining('meal_composition(c1).protein_grams'),
      findsOneWidget,
    );
    expect(find.textContaining('score 0'), findsNothing);
    expect(find.textContaining('confidence insufficient'), findsNothing);
  });

  testWidgets(
    'contradictory typed result is integrity-blocked and renders no chart',
    (tester) async {
      final result = MechanisticConflictResult(
        id: 'synthetic:empty-window-with-curve',
        interactionType: MechanisticInteractionType.noModeledInteraction,
        interactionScore: 0,
        severityBand: SeverityBand.none,
        confidenceBand: ConfidenceBand.high,
        primaryDrivers: const [],
        modeledTimelineWindows: const [],
        uncertaintyReasons: const [],
        sourceRefs: const [],
        limitationText: MechanisticExplanation.defaultLimitation,
        safetyBoundary: RuleExplanation.defaultSafetyBoundary,
        notAdviceText: RuleExplanation.defaultNotAdvice,
        explanation: const MechanisticExplanation(
          resultId: 'synthetic:empty-window-with-curve',
          layerTraces: [],
          inputFieldsUsed: [],
          missingOrUncertainInputs: [],
          sourceRefs: [],
          limitationText: MechanisticExplanation.defaultLimitation,
          safetyBoundary: RuleExplanation.defaultSafetyBoundary,
          notAdviceText: RuleExplanation.defaultNotAdvice,
        ),
        primaryEmptyingProfile: const GastricEmptyingProfile(
          mealId: 'synthetic:meal',
          componentProfiles: [
            EmptyingComponentProfile(
              componentId: 'synthetic:solid',
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
          peakEmptyingWindow: TimelineWindow(startMinute: 0, endMinute: 30),
          mostlyEmptiedWindow: TimelineWindow(startMinute: 0, endMinute: 180),
          timeScaleSensitivityFraction: 0.2,
        ),
      );

      expect(
        result.availability,
        MechanisticResultAvailability.blockedIntegrity,
      );
      expect(result.hasModeledOutput, isFalse);
      expect(result.toJson()['interaction_score'], isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MechanisticConflictTraceCard(typedResult: result),
          ),
        ),
      );
      expect(find.textContaining('Model blocked'), findsOneWidget);

      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      expect(find.text('status integrity blocked'), findsOneWidget);
      expect(find.text('Gastric residence sensitivity'), findsNothing);
      expect(find.textContaining('overlap '), findsNothing);
    },
  );
}

Map<String, dynamic> _validAvailablePersistedPayload() => {
  'result_availability': 'available',
  'has_modeled_output': true,
  'interaction_type': 'foodLevodopaTimingOverlap',
  'interaction_score': 0.2,
  'severity_band': 'moderate',
  'confidence_band': 'medium',
  'primary_drivers': <String>['synthetic_driver'],
  'modeled_timeline_windows': [
    {'start_minute': 10, 'end_minute': 100},
  ],
  'uncertainty_reasons': <String>[],
  'source_refs': <String>[],
  ..._validAvailableProviderWireBundle('persisted-valid'),
  ..._validPerEventWire(0.2),
};

Map<String, dynamic> _validAvailableProviderWireBundle(String id) => {
  'id': id,
  'explanation': {'result_id': id},
  'primary_emptying_profile': const GastricEmptyingProfile(
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
  ).toJson(),
  'absorption_opportunity_window': const AbsorptionOpportunityWindow(
    medicationEventId: 'dose',
    window: TimelineWindow(startMinute: 10, endMinute: 20),
    peakMinute: 15,
    delayedArrivalLikelihood: DelayedArrivalLikelihood.low,
    uncertaintyBand: UncertaintyBand.narrow,
    assumptions: [],
    missingInputs: [],
    sourceRefs: [],
    opennessProfile: [
      AbsorptionOpennessSample(minute: 10, openness: 0.2),
      AbsorptionOpennessSample(minute: 15, openness: 0.8),
      AbsorptionOpennessSample(minute: 20, openness: 0.3),
    ],
  ).toJson(),
  'competition_timeline': const CompetitionPressureTimeline(
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
  ).toJson(),
};

Map<String, dynamic> _validPerEventWire(double score) => {
  'per_event_count': 1,
  'per_event_traces': [_validPerEventTrace(score)],
};

Map<String, dynamic> _validPerEventTrace(
  double score, {
  String id = 'dose',
  bool isPrimary = true,
}) => {
  'medication_event_id': id,
  'medication_minute': 10,
  'is_levodopa': true,
  'release_type': 'immediate',
  'interaction_score': score,
  'competition_band': score == 0 ? 'none' : 'low',
  'delayed_arrival_likelihood': 'low',
  'is_primary': isPrimary,
  'source_refs': <String>[],
  'uncertainty_reasons': <String>[],
  'combination_component_count': 0,
  'label_section_ref_count': 0,
};
