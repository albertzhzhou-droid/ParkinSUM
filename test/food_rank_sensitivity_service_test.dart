import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/domain/entities/food_composition_candidate_set_snapshot.dart';
import 'package:parkinsum_companion/domain/entities/food_recommendation.dart';
import 'package:parkinsum_companion/domain/usecases/food_rank_sensitivity_service.dart';

void main() {
  final service = FoodRankSensitivityService();

  test(
    'source ranges replay score thresholds and detect an order reversal',
    () {
      final ranged = _food(
        'ranged',
        protein: 10,
        evidence: _proteinPointAndRange(point: 10, low: 0, high: 20),
      );
      final fixed = _food('fixed', protein: 12);
      final foods = <FoodItem>[ranged, fixed];
      final baseline = _rankByProtein(foods);
      final report = service.assess(
        candidateSetSnapshot: _snapshot(foods),
        candidates: foods,
        baselineRecommendations: baseline,
        proteinBreakpoints: const <double>[12, 15],
        fiberBreakpoints: const <double>[],
        evaluate: _rankByProtein,
      );

      expect(report.hasBoundedScenarios, isTrue);
      expect(report.scenariosEvaluated, greaterThan(2));
      expect(report.orderChangeObserved, isTrue);
      expect(report.possibleOrderSwaps, hasLength(1));
      expect(report.possibleOrderSwaps.single.firstCandidateId, 'fixed');
      expect(report.possibleOrderSwaps.single.secondCandidateId, 'ranged');
      expect(report.fullRankStabilityAssessed, isFalse);
      expect(
        report.unresolvedReasonCounts['point_projection_not_source_bound'],
        greaterThan(0),
      );
    },
  );

  test(
    'threshold replay exposes a decision and reason change without a swap',
    () {
      final ranged = _food(
        'ranged',
        protein: 10,
        evidence: _proteinPointAndRange(point: 10, low: 10, high: 20),
      );
      final fixed = _food('fixed', protein: 12);
      final foods = <FoodItem>[ranged, fixed];
      List<FoodRecommendation> evaluate(List<FoodItem> candidates) {
        final recommendations = candidates.map((food) {
          final caution = food.proteinG >= 15;
          return _recommendation(
            food,
            score: food.id == 'fixed' ? 12 : 10,
            decision: caution ? 'WARN' : 'ALLOW',
            reasons: caution ? const <String>['threshold_crossed'] : const [],
          );
        }).toList();
        recommendations.sort(
          (left, right) => right.score.compareTo(left.score),
        );
        return recommendations;
      }

      final report = service.assess(
        candidateSetSnapshot: _snapshot(foods),
        candidates: foods,
        baselineRecommendations: evaluate(foods),
        proteinBreakpoints: const <double>[15],
        fiberBreakpoints: const <double>[],
        evaluate: evaluate,
      );

      expect(report.orderChangeObserved, isFalse);
      expect(report.changedCandidateIds, contains('ranged'));
      expect(report.scenariosEvaluated, greaterThan(0));
    },
  );

  test('a range with a unit or source-scope mismatch is not perturbed', () {
    final evidence = _proteinPointAndRange(
      point: 10,
      low: 1,
      high: 20,
      rangeUnit: 'mg',
    );
    final food = _food('ranged', protein: 10, evidence: evidence);
    final report = service.assess(
      candidateSetSnapshot: _snapshot(<FoodItem>[food]),
      candidates: <FoodItem>[food],
      baselineRecommendations: _rankByProtein(<FoodItem>[food]),
      proteinBreakpoints: const <double>[15],
      fiberBreakpoints: const <double>[],
      evaluate: _rankByProtein,
    );

    expect(report.scenariosEvaluated, 0);
    expect(
      report.unresolvedReasonCounts['source_range_scope_or_unit_unresolved'],
      1,
    );
    expect(report.fullRankStabilityAssessed, isFalse);
  });

  test('unsupported value types and point-range conflicts fail closed', () {
    final unsupported = _food(
      'unsupported',
      protein: 10,
      evidence: _proteinPointAndRange(
        point: 10,
        low: 1,
        high: 20,
        rangeValueType: 'text',
      ),
    );
    final unsupportedReport = service.assess(
      candidateSetSnapshot: _snapshot(<FoodItem>[unsupported]),
      candidates: <FoodItem>[unsupported],
      baselineRecommendations: _rankByProtein(<FoodItem>[unsupported]),
      proteinBreakpoints: const <double>[15],
      fiberBreakpoints: const <double>[],
      evaluate: _rankByProtein,
    );
    expect(unsupportedReport.scenariosEvaluated, 0);
    expect(
      unsupportedReport
          .unresolvedReasonCounts['source_range_scope_or_unit_unresolved'],
      1,
    );

    final conflict = _food(
      'conflict',
      protein: 25,
      evidence: _proteinPointAndRange(point: 25, low: 1, high: 20),
    );
    final conflictReport = service.assess(
      candidateSetSnapshot: _snapshot(<FoodItem>[conflict]),
      candidates: <FoodItem>[conflict],
      baselineRecommendations: _rankByProtein(<FoodItem>[conflict]),
      proteinBreakpoints: const <double>[15],
      fiberBreakpoints: const <double>[],
      evaluate: _rankByProtein,
    );
    expect(conflictReport.scenariosEvaluated, 0);
    expect(
      conflictReport
          .unresolvedReasonCounts['selected_point_outside_reported_range'],
      1,
    );
  });

  test('candidate snapshot order must match the tested candidate inputs', () {
    final first = _food('first', protein: 10);
    final other = _food('other', protein: 12);
    final tested = <FoodItem>[first];
    final report = service.assess(
      candidateSetSnapshot: _snapshot(<FoodItem>[other]),
      candidates: tested,
      baselineRecommendations: _rankByProtein(tested),
      proteinBreakpoints: const <double>[15],
      fiberBreakpoints: const <double>[],
      evaluate: _rankByProtein,
    );

    expect(report.scenariosEvaluated, 0);
    expect(
      report
          .unresolvedReasonCounts['candidate_set_snapshot_candidate_order_mismatch'],
      1,
    );
  });

  test(
    'feature snapshot changes are counted even when score and copy match',
    () {
      final ranged = _food(
        'ranged',
        protein: 10,
        evidence: _proteinPointAndRange(point: 10, low: 10, high: 20),
      );
      List<FoodRecommendation> evaluate(List<FoodItem> candidates) => candidates
          .map(
            (food) => _recommendation(
              food,
              score: 10,
              featureNutrientMatch: food.proteinG >= 15 ? 0.5 : 1,
            ),
          )
          .toList();

      final report = service.assess(
        candidateSetSnapshot: _snapshot(<FoodItem>[ranged]),
        candidates: <FoodItem>[ranged],
        baselineRecommendations: evaluate(<FoodItem>[ranged]),
        proteinBreakpoints: const <double>[15],
        fiberBreakpoints: const <double>[],
        evaluate: evaluate,
      );

      expect(report.changedCandidateIds, contains('ranged'));
    },
  );

  test('scenario budget fails closed instead of sampling combinations', () {
    final first = _food(
      'first',
      protein: 10,
      evidence: _proteinPointAndRange(point: 10, low: 0, high: 30),
    );
    final second = _food(
      'second',
      protein: 10,
      evidence: _proteinPointAndRange(point: 10, low: 0, high: 30),
    );
    final foods = <FoodItem>[first, second];
    final report = service.assess(
      candidateSetSnapshot: _snapshot(foods),
      candidates: foods,
      baselineRecommendations: _rankByProtein(foods),
      proteinBreakpoints: List<double>.generate(20, (index) => index + 1),
      fiberBreakpoints: const <double>[],
      evaluate: _rankByProtein,
    );

    expect(report.scenariosEvaluated, 0);
    expect(
      report
          .unresolvedReasonCounts['scenario_count_exceeds_sensitivity_budget'],
      1,
    );
  });

  test('local AI reranking is not misreported as a heuristic stress test', () {
    final food = _food(
      'ranged',
      protein: 10,
      evidence: _proteinPointAndRange(point: 10, low: 0, high: 20),
    );
    final foods = <FoodItem>[food];
    final report = service.assess(
      candidateSetSnapshot: _snapshot(foods),
      candidates: foods,
      baselineRecommendations: _rankByProtein(foods),
      proteinBreakpoints: const <double>[15],
      fiberBreakpoints: const <double>[],
      evaluate: _rankByProtein,
      aiRerankUsed: true,
    );

    expect(report.scenariosEvaluated, 0);
    expect(report.unresolvedReasonCounts['ai_rerank_order_not_replayed'], 1);
  });
}

FoodItem _food(
  String id, {
  required double protein,
  List<NutrientObservationEvidence> evidence = const [],
}) => FoodItem(
  id: id,
  name: id.toUpperCase(),
  category: FoodCategory.other,
  sourceSystem: 'TEST_FIXTURE',
  jurisdiction: 'US',
  proteinG: protein,
  carbsG: 0,
  fatG: 0,
  fiberG: 0,
  sodiumMg: 0,
  nutrientObservationEvidence: evidence,
);

List<NutrientObservationEvidence> _proteinPointAndRange({
  required double point,
  required double low,
  required double high,
  String rangeUnit = 'g',
  String pointValueType = 'numeric_interval',
  String rangeValueType = 'numeric_interval',
}) => <NutrientObservationEvidence>[
  _observation(
    id: 'protein-point',
    value: point,
    low: point,
    high: point,
    qualifier: 'exact',
    unit: 'g',
    selected: true,
    valueType: pointValueType,
  ),
  _observation(
    id: 'protein-range',
    value: null,
    low: low,
    high: high,
    qualifier: 'range',
    unit: rangeUnit,
    selected: false,
    valueType: rangeValueType,
  ),
];

NutrientObservationEvidence _observation({
  required String id,
  required double? value,
  required double? low,
  required double? high,
  required String qualifier,
  required String unit,
  required bool selected,
  String valueType = 'numeric_interval',
}) => NutrientObservationEvidence(
  observationId: id,
  domain: 'food',
  entityType: 'food_variant',
  entityKey: 'variant_1',
  attributeCode: 'protein_g',
  valueType: valueType,
  valueNum: value,
  low: low,
  high: high,
  qualifierKind: qualifier,
  rawValueText: qualifier == 'exact' ? '$value' : '$low-$high',
  unit: unit,
  basisType: 'per_100g_edible_part',
  basisAmount: 100,
  scopeHash: 'scope_1',
  sourceDocId: 'doc_1',
  recordLocator: id,
  methodCode: 'method_1',
  extractionConfidence: 1,
  selectedForLegacyPointProjection: selected,
);

FoodCompositionCandidateSetSnapshot _snapshot(List<FoodItem> foods) =>
    FoodCompositionCandidateSetSnapshot.capture(
      callerCandidateFoods: foods,
      fallbackCandidateFoods: const <FoodItem>[],
      projectedFoods: const <FoodItem>[],
      mergedCandidates: foods,
      projectionQueryAudit: const <String, Object?>{
        'schema_id': 'test.synthetic-projection-query-audit/1',
      },
      builtInP0FallbackUsed: false,
      contentJurisdictionOverride: const <String>[],
      registrationRegion: 'US',
      dietProfileRegion: 'US',
      tieBreakPolicy: 'score_desc_food_id_asc',
    );

List<FoodRecommendation> _rankByProtein(List<FoodItem> foods) =>
    foods.map((food) => _recommendation(food, score: food.proteinG)).toList()
      ..sort((left, right) {
        final byScore = right.score.compareTo(left.score);
        return byScore != 0 ? byScore : left.food.id.compareTo(right.food.id);
      });

FoodRecommendation _recommendation(
  FoodItem food, {
  required double score,
  String decision = 'ALLOW',
  List<String> reasons = const <String>[],
  double featureNutrientMatch = 1,
}) => FoodRecommendation(
  food: food,
  score: score,
  reasons: reasons,
  decision: decision,
  jurisdiction: 'US',
  fallbackUsed: false,
  scoreBreakdown: <String, double>{'points': score},
  featureSnapshot: RecommendationFeatureSnapshot(
    safetyScore: 1,
    nutrientMatch: featureNutrientMatch,
    medicationScheduleFit: 1,
    culturalAffinity: 1,
    userPreferenceScore: 1,
    provenanceScore: 1,
    databaseFactCoverage: 1,
    timingWindowClarity: 1,
    drugTimingSensitivity: 0,
    fallbackPenalty: 0,
    repetitionPenalty: 0,
    fiberSupportScore: 1,
    regionMatchScore: 1,
    usedDatabaseFacts: true,
    hasPreciseTimingWindow: true,
    levodopaSensitive: false,
  ),
);
