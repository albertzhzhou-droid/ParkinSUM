import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/domain/entities/food_composition_candidate_set_snapshot.dart';
import 'package:parkinsum_companion/domain/entities/food_rank_sensitivity_assessment.dart';
import 'package:parkinsum_companion/features/next_meal/candidate_set_snapshot_card.dart';

import 'helpers/page_test_harness.dart';

void main() {
  testWidgets('card exposes the exact candidate snapshot identity', (
    tester,
  ) async {
    final candidates = <FoodItem>[_food('food_a'), _food('food_b')];
    final snapshot = FoodCompositionCandidateSetSnapshot.capture(
      callerCandidateFoods: candidates,
      fallbackCandidateFoods: const <FoodItem>[],
      projectedFoods: const <FoodItem>[],
      mergedCandidates: candidates,
      projectionQueryAudit: const <String, Object?>{
        'schema_id': 'test.synthetic-projection-query-audit/1',
        'capture_status': 'synthetic_fixture',
      },
      builtInP0FallbackUsed: false,
      contentJurisdictionOverride: const <String>[],
      registrationRegion: 'CA',
      dietProfileRegion: 'CA',
      tieBreakPolicy: 'score_descending_food_id_ascending',
    );

    await pumpFeaturePage(
      tester,
      Scaffold(body: CandidateSetSnapshotCard(snapshot: snapshot)),
    );

    expect(find.text('Food candidate-set snapshot'), findsOneWidget);
    expect(
      find.textContaining(FoodCompositionCandidateSetSnapshot.schemaId),
      findsOneWidget,
    );
    expect(find.textContaining('2 candidates'), findsOneWidget);
    expect(find.textContaining(snapshot.sha256Digest), findsOneWidget);
    expect(
      find.textContaining('upstream catalog release and query are not pinned'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('next-meal-rank-stability-status')),
      findsOneWidget,
    );
    expect(find.text('Ranking stability: not assessed'), findsOneWidget);
    expect(
      find.textContaining('candidate swaps have not been analyzed'),
      findsOneWidget,
    );
    expectNoWidgetErrors();
  });

  testWidgets('card exposes bounded scenarios that detected an order swap', (
    tester,
  ) async {
    final candidates = <FoodItem>[_food('food_a'), _food('food_b')];
    final snapshot = FoodCompositionCandidateSetSnapshot.capture(
      callerCandidateFoods: candidates,
      fallbackCandidateFoods: const <FoodItem>[],
      projectedFoods: const <FoodItem>[],
      mergedCandidates: candidates,
      projectionQueryAudit: const <String, Object?>{
        'schema_id': 'test.synthetic-projection-query-audit/1',
      },
      builtInP0FallbackUsed: false,
      contentJurisdictionOverride: const <String>[],
      registrationRegion: 'CA',
      dietProfileRegion: 'CA',
      tieBreakPolicy: 'score_descending_food_id_ascending',
    );
    final assessment = FoodRankSensitivityAssessment(
      candidateSetSha256: snapshot.sha256Digest,
      supportedRangeFeatureCount: 1,
      scenariosEvaluated: 4,
      unresolvedReasonCounts: const <String, int>{
        'source_range_not_reported': 3,
      },
      changedCandidateIds: const <String>['food_a', 'food_b'],
      topKMembershipChangedIds: const <String>[],
      possibleOrderSwaps: const <FoodRankCandidateSwap>[
        FoodRankCandidateSwap(
          firstCandidateId: 'food_a',
          firstCandidateName: 'Apple',
          secondCandidateId: 'food_b',
          secondCandidateName: 'Bread',
        ),
      ],
    );

    await pumpFeaturePage(
      tester,
      Scaffold(
        body: CandidateSetSnapshotCard(
          snapshot: snapshot,
          rankSensitivityAssessment: assessment,
        ),
      ),
    );

    expect(
      find.text('Source-range stress test found possible order changes'),
      findsOneWidget,
    );
    expect(
      find.textContaining('4 source-range/score-threshold scenarios'),
      findsOneWidget,
    );
    expect(find.textContaining('Apple ↔ Bread'), findsOneWidget);
    expect(find.textContaining('other measurement, portion'), findsOneWidget);
    expectNoWidgetErrors();
  });

  testWidgets('changed rank evidence shows a withheld-order notice', (
    tester,
  ) async {
    await pumpFeaturePage(
      tester,
      const Scaffold(body: RankedFoodPresentationWithheldNotice()),
    );

    expect(
      find.byKey(const ValueKey('next-meal-ranked-food-presentation-withheld')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('next-meal-ranked-food-presentation-copy')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Ranked candidates are withheld'),
      findsOneWidget,
    );
    expectNoWidgetErrors();
  });

  testWidgets(
    'scenario-affected candidates receive individual uncertainty labels',
    (tester) async {
      final candidates = <FoodItem>[
        _food('food_a'),
        _food('food_b'),
        _food('food_c'),
        _food('food_d'),
      ];
      final snapshot = FoodCompositionCandidateSetSnapshot.capture(
        callerCandidateFoods: candidates,
        fallbackCandidateFoods: const <FoodItem>[],
        projectedFoods: const <FoodItem>[],
        mergedCandidates: candidates,
        projectionQueryAudit: const <String, Object?>{
          'schema_id': 'test.synthetic-projection-query-audit/1',
        },
        builtInP0FallbackUsed: false,
        contentJurisdictionOverride: const <String>[],
        registrationRegion: 'CA',
        dietProfileRegion: 'CA',
        tieBreakPolicy: 'score_descending_food_id_ascending',
      );
      final assessment = FoodRankSensitivityAssessment(
        candidateSetSha256: snapshot.sha256Digest,
        supportedRangeFeatureCount: 1,
        scenariosEvaluated: 4,
        unresolvedReasonCounts: const <String, int>{},
        changedCandidateIds: const <String>['food_a', 'food_b', 'food_c'],
        topKMembershipChangedIds: const <String>['food_c'],
        possibleOrderSwaps: const <FoodRankCandidateSwap>[
          FoodRankCandidateSwap(
            firstCandidateId: 'food_a',
            firstCandidateName: 'Apple',
            secondCandidateId: 'food_b',
            secondCandidateName: 'Bread',
          ),
        ],
      );

      await pumpFeaturePage(
        tester,
        Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final food in candidates)
                CandidateRankUncertaintyBadge(
                  candidateId: food.id,
                  candidateSetSha256: snapshot.sha256Digest,
                  assessment: assessment,
                ),
            ],
          ),
        ),
      );

      expect(
        find.byKey(
          const ValueKey('next-meal-candidate-rank-uncertainty-food_a'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('next-meal-candidate-rank-uncertainty-food_b'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('next-meal-candidate-rank-uncertainty-food_c'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('next-meal-candidate-rank-uncertainty-food_d'),
        ),
        findsNothing,
      );
      expect(
        find.text('This candidate’s position may change in tested scenarios'),
        findsNWidgets(2),
      );
      expect(
        find.text(
          'This candidate may enter or leave the displayed set in tested scenarios',
        ),
        findsOneWidget,
      );
      expectNoWidgetErrors();
    },
  );

  testWidgets('mismatched snapshot evidence does not mark a candidate', (
    tester,
  ) async {
    final candidates = <FoodItem>[_food('food_a'), _food('food_b')];
    final snapshot = FoodCompositionCandidateSetSnapshot.capture(
      callerCandidateFoods: candidates,
      fallbackCandidateFoods: const <FoodItem>[],
      projectedFoods: const <FoodItem>[],
      mergedCandidates: candidates,
      projectionQueryAudit: const <String, Object?>{
        'schema_id': 'test.synthetic-projection-query-audit/1',
      },
      builtInP0FallbackUsed: false,
      contentJurisdictionOverride: const <String>[],
      registrationRegion: 'CA',
      dietProfileRegion: 'CA',
      tieBreakPolicy: 'score_descending_food_id_ascending',
    );
    final staleAssessment = FoodRankSensitivityAssessment(
      candidateSetSha256: 'a' * 64,
      supportedRangeFeatureCount: 1,
      scenariosEvaluated: 4,
      unresolvedReasonCounts: const <String, int>{},
      changedCandidateIds: const <String>['food_a', 'food_b'],
      topKMembershipChangedIds: const <String>[],
      possibleOrderSwaps: const <FoodRankCandidateSwap>[
        FoodRankCandidateSwap(
          firstCandidateId: 'food_a',
          firstCandidateName: 'Apple',
          secondCandidateId: 'food_b',
          secondCandidateName: 'Bread',
        ),
      ],
    );

    await pumpFeaturePage(
      tester,
      Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CandidateSetSnapshotCard(
              snapshot: snapshot,
              rankSensitivityAssessment: staleAssessment,
            ),
            CandidateRankUncertaintyBadge(
              candidateId: 'food_a',
              candidateSetSha256: snapshot.sha256Digest,
              assessment: staleAssessment,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Ranking stability: not assessed'), findsOneWidget);
    expect(
      find.text('Source-range stress test found possible order changes'),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('next-meal-candidate-rank-uncertainty-food_a')),
      findsNothing,
    );
    expectNoWidgetErrors();
  });

  test('candidate snapshot copy resolves in every shipped language family', () {
    const keys = <String>[
      'next_meal.candidate_snapshot_title',
      'next_meal.candidate_snapshot_meta',
      'next_meal.candidate_snapshot_digest',
      'next_meal.candidate_snapshot_boundary',
      'next_meal.rank_stability_status',
      'next_meal.rank_stability_boundary',
      'next_meal.rank_stability_bounded_change',
      'next_meal.rank_stability_bounded_membership_change',
      'next_meal.rank_stability_bounded_no_change',
      'next_meal.rank_stability_swap_summary',
      'next_meal.rank_stability_membership_summary',
      'next_meal.rank_stability_no_swap_summary',
      'next_meal.candidate_order_may_change',
      'next_meal.candidate_membership_may_change',
      'next_meal.rank_display_withheld',
    ];
    const parameters = <String, String>{
      'schema': FoodCompositionCandidateSetSnapshot.schemaId,
      'count': '2',
      'digest': 'abc123',
      'scenarios': '4',
      'pairs': 'Apple ↔ Bread',
      'more': '',
      'changes': '2',
      'memberships': '0',
    };
    for (final family in AppI18n.translationFamilies) {
      final i18n = AppI18n.fromLocaleTag(family);
      for (final key in keys) {
        final resolved = i18n.tr(key, parameters);
        expect(resolved, isNot(key), reason: '$family is missing $key');
        expect(resolved, isNot(contains(RegExp(r'\{[A-Za-z0-9_]+\}'))));
      }
    }
  });

  test('rank presentation gate holds missing, stale, or changed evidence', () {
    final digest = 'b' * 64;
    expect(
      shouldWithholdRankedFoodPresentation(
        candidateSetSha256: digest,
        assessment: null,
      ),
      isTrue,
    );
    expect(
      shouldWithholdRankedFoodPresentation(
        candidateSetSha256: digest,
        assessment: _assessment(candidateSetSha256: 'a' * 64),
      ),
      isTrue,
    );
    expect(
      shouldWithholdRankedFoodPresentation(
        candidateSetSha256: digest,
        assessment: _assessment(
          candidateSetSha256: digest,
          swaps: const <FoodRankCandidateSwap>[
            FoodRankCandidateSwap(
              firstCandidateId: 'food_a',
              firstCandidateName: 'Apple',
              secondCandidateId: 'food_b',
              secondCandidateName: 'Bread',
            ),
          ],
        ),
      ),
      isTrue,
    );
    expect(
      shouldWithholdRankedFoodPresentation(
        candidateSetSha256: digest,
        assessment: _assessment(
          candidateSetSha256: digest,
          topKMembershipChangedIds: const <String>['food_c'],
        ),
      ),
      isTrue,
    );
    expect(
      shouldWithholdRankedFoodPresentation(
        candidateSetSha256: digest,
        assessment: _assessment(candidateSetSha256: digest),
      ),
      isFalse,
    );
  });
}

FoodRankSensitivityAssessment _assessment({
  required String candidateSetSha256,
  List<String> topKMembershipChangedIds = const <String>[],
  List<FoodRankCandidateSwap> swaps = const <FoodRankCandidateSwap>[],
}) => FoodRankSensitivityAssessment(
  candidateSetSha256: candidateSetSha256,
  supportedRangeFeatureCount: 1,
  scenariosEvaluated: 4,
  unresolvedReasonCounts: const <String, int>{},
  changedCandidateIds: const <String>[],
  topKMembershipChangedIds: topKMembershipChangedIds,
  possibleOrderSwaps: swaps,
);

FoodItem _food(String id) => FoodItem(
  id: id,
  name: id,
  category: FoodCategory.other,
  proteinG: 1,
  carbsG: 2,
  fatG: 3,
  fiberG: 0,
  sodiumMg: 0,
);
