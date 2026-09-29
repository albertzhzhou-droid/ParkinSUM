import '../../core/models/food_item.dart';
import '../entities/food_composition_candidate_set_snapshot.dart';
import '../entities/food_rank_sensitivity_assessment.dart';
import '../entities/food_recommendation.dart';

/// Runs the production heuristic scorer over a bounded set of source-reported
/// protein/fiber intervals. It never creates a probability distribution and
/// refuses to treat unbound or incompatible observations as score inputs.
class FoodRankSensitivityService {
  const FoodRankSensitivityService();

  static const int maximumCandidates = 250;
  static const int maximumScenarios = 128;
  static const List<String> _scoreFields = <String>['proteinG', 'fiberG'];
  static const Set<String> _numericValueTypes = <String>{
    'numeric',
    'numeric_interval',
  };

  FoodRankSensitivityAssessment assess({
    required FoodCompositionCandidateSetSnapshot candidateSetSnapshot,
    required List<FoodItem> candidates,
    required List<FoodRecommendation> baselineRecommendations,
    required List<double> proteinBreakpoints,
    required List<double> fiberBreakpoints,
    required List<FoodRecommendation> Function(List<FoodItem>) evaluate,
    bool aiRerankUsed = false,
  }) {
    final unresolved = <String, int>{};
    void hold(String reason, [int count = 1]) {
      unresolved[reason] = (unresolved[reason] ?? 0) + count;
    }

    if (aiRerankUsed) {
      hold('ai_rerank_order_not_replayed');
      return _assessment(
        candidateSetSnapshot,
        ranges: 0,
        scenarios: 0,
        unresolved: unresolved,
      );
    }
    if (!_sameStringList(
      candidateSetSnapshot.orderedCandidateIds,
      candidates.map((food) => food.id).toList(growable: false),
    )) {
      hold('candidate_set_snapshot_candidate_order_mismatch');
      return _assessment(
        candidateSetSnapshot,
        ranges: 0,
        scenarios: 0,
        unresolved: unresolved,
      );
    }
    if (candidates.length > maximumCandidates) {
      hold('candidate_count_exceeds_sensitivity_budget');
      return _assessment(
        candidateSetSnapshot,
        ranges: 0,
        scenarios: 0,
        unresolved: unresolved,
      );
    }

    final seenIds = <String>{};
    for (final food in candidates) {
      if (!seenIds.add(food.id)) hold('duplicate_candidate_id');
    }
    if (unresolved.containsKey('duplicate_candidate_id')) {
      return _assessment(
        candidateSetSnapshot,
        ranges: 0,
        scenarios: 0,
        unresolved: unresolved,
      );
    }

    final dimensions = <_RangeDimension>[];
    for (var foodIndex = 0; foodIndex < candidates.length; foodIndex++) {
      final food = candidates[foodIndex];
      for (final field in _scoreFields) {
        final nutrientCode = _nutrientCode(field);
        final interval = _supportedRange(
          food: food,
          field: field,
          nutrientCode: nutrientCode,
          unresolved: unresolved,
        );
        if (interval == null) continue;
        final point = _pointValue(food, field);
        final breakpoints = field == 'proteinG'
            ? proteinBreakpoints
            : fiberBreakpoints;
        final representatives = _representativeValues(
          low: interval.low,
          high: interval.high,
          currentPoint: point,
          breakpoints: breakpoints,
        );
        if (representatives.length <= 1) {
          hold('zero_width_source_range');
          continue;
        }
        dimensions.add(
          _RangeDimension(
            foodIndex: foodIndex,
            field: field,
            values: representatives,
          ),
        );
      }
    }

    if (dimensions.isEmpty) {
      hold('no_usable_source_supported_score_ranges');
      return _assessment(
        candidateSetSnapshot,
        ranges: 0,
        scenarios: 0,
        unresolved: unresolved,
      );
    }

    var scenarioBudget = 1;
    for (final dimension in dimensions) {
      if (scenarioBudget > maximumScenarios ~/ dimension.values.length) {
        hold('scenario_count_exceeds_sensitivity_budget');
        return _assessment(
          candidateSetSnapshot,
          ranges: dimensions.length,
          scenarios: 0,
          unresolved: unresolved,
        );
      }
      scenarioBudget *= dimension.values.length;
    }

    // An exact point without a source-reported range is not treated as exact
    // measurement certainty. Record these gaps while still testing any other
    // strictly bound ranges that are available.
    for (final food in candidates) {
      for (final field in _scoreFields) {
        final hasRange = dimensions.any(
          (dimension) =>
              candidates[dimension.foodIndex].id == food.id &&
              dimension.field == field,
        );
        if (!hasRange) hold('score_input_range_not_available');
      }
    }

    final baselineById = <String, FoodRecommendation>{};
    for (final recommendation in baselineRecommendations) {
      if (baselineById.containsKey(recommendation.food.id)) {
        hold('duplicate_baseline_candidate_id');
      }
      baselineById[recommendation.food.id] = recommendation;
    }
    if (unresolved.containsKey('duplicate_baseline_candidate_id')) {
      return _assessment(
        candidateSetSnapshot,
        ranges: dimensions.length,
        scenarios: 0,
        unresolved: unresolved,
      );
    }

    final baselineOrder = baselineRecommendations
        .map((recommendation) => recommendation.food.id)
        .toList(growable: false);
    final swaps = <FoodRankCandidateSwap>{};
    final changedCandidateIds = <String>{};
    final topKMembershipChangedIds = <String>{};
    final positions = <double>[];
    var scenariosEvaluated = 0;
    var invalidScenarioOutput = false;

    void evaluateScenario() {
      if (invalidScenarioOutput) return;
      final valuesByFood = <int, Map<String, double>>{};
      for (var index = 0; index < dimensions.length; index++) {
        final dimension = dimensions[index];
        valuesByFood.putIfAbsent(
          dimension.foodIndex,
          () => <String, double>{},
        )[dimension.field] = positions[index]
            .toDouble();
      }
      final scenarioFoods = List<FoodItem>.generate(candidates.length, (index) {
        final overrides = valuesByFood[index];
        return overrides == null
            ? candidates[index]
            : _withNutrients(candidates[index], overrides);
      }, growable: false);
      final scenarioRecommendations = evaluate(scenarioFoods);
      final scenarioIds = scenarioRecommendations
          .map((recommendation) => recommendation.food.id)
          .toList(growable: false);
      if (scenarioIds.toSet().length != scenarioIds.length) {
        hold('duplicate_scenario_candidate_id');
        invalidScenarioOutput = true;
        return;
      }
      scenariosEvaluated += 1;

      final scenarioById = <String, FoodRecommendation>{
        for (final recommendation in scenarioRecommendations)
          recommendation.food.id: recommendation,
      };
      final scenarioOrder = scenarioRecommendations
          .map((recommendation) => recommendation.food.id)
          .toList(growable: false);
      final baselineSet = baselineById.keys.toSet();
      final scenarioSet = scenarioById.keys.toSet();
      topKMembershipChangedIds
        ..addAll(baselineSet.difference(scenarioSet))
        ..addAll(scenarioSet.difference(baselineSet));

      for (final candidateId in baselineSet.union(scenarioSet)) {
        final baseline = baselineById[candidateId];
        final scenario = scenarioById[candidateId];
        if (baseline == null || scenario == null) {
          changedCandidateIds.add(candidateId);
          continue;
        }
        if (_recommendationChanged(baseline, scenario)) {
          changedCandidateIds.add(candidateId);
        }
      }

      final scenarioPositions = <String, int>{
        for (var index = 0; index < scenarioOrder.length; index++)
          scenarioOrder[index]: index,
      };
      for (var leftIndex = 0; leftIndex < baselineOrder.length; leftIndex++) {
        for (
          var rightIndex = leftIndex + 1;
          rightIndex < baselineOrder.length;
          rightIndex++
        ) {
          final leftId = baselineOrder[leftIndex];
          final rightId = baselineOrder[rightIndex];
          final leftScenario = scenarioPositions[leftId];
          final rightScenario = scenarioPositions[rightId];
          if (leftScenario != null &&
              rightScenario != null &&
              leftScenario > rightScenario) {
            swaps.add(
              FoodRankCandidateSwap(
                firstCandidateId: leftId,
                firstCandidateName: _candidateName(candidates, leftId),
                secondCandidateId: rightId,
                secondCandidateName: _candidateName(candidates, rightId),
              ),
            );
            changedCandidateIds
              ..add(leftId)
              ..add(rightId);
          }
        }
      }
    }

    void visitDimension(int index) {
      if (invalidScenarioOutput) return;
      if (index == dimensions.length) {
        evaluateScenario();
        return;
      }
      for (final value in dimensions[index].values) {
        if (value.isFinite) {
          if (positions.length == index) {
            positions.add(value);
          } else {
            positions[index] = value;
          }
          visitDimension(index + 1);
        }
      }
    }

    visitDimension(0);
    if (invalidScenarioOutput) {
      return _assessment(
        candidateSetSnapshot,
        ranges: dimensions.length,
        scenarios: 0,
        unresolved: unresolved,
      );
    }
    return FoodRankSensitivityAssessment(
      candidateSetSha256: candidateSetSnapshot.sha256Digest,
      supportedRangeFeatureCount: dimensions.length,
      scenariosEvaluated: scenariosEvaluated,
      unresolvedReasonCounts: unresolved,
      changedCandidateIds: changedCandidateIds.toList(growable: false),
      topKMembershipChangedIds: topKMembershipChangedIds.toList(
        growable: false,
      ),
      possibleOrderSwaps: swaps.toList(growable: false),
    );
  }

  _SupportedRange? _supportedRange({
    required FoodItem food,
    required String field,
    required String nutrientCode,
    required Map<String, int> unresolved,
  }) {
    if (food.isNutrientMissing(field)) {
      _increment(unresolved, 'score_input_missing');
      return null;
    }
    final matching = food.nutrientObservationEvidence
        .where((evidence) => evidence.attributeCode == nutrientCode)
        .toList(growable: false);
    final selected = matching
        .where((evidence) => evidence.selectedForLegacyPointProjection)
        .toList(growable: false);
    if (selected.length != 1 ||
        selected.single.qualifierKind != 'exact' ||
        !_hasNumericValueType(selected.single) ||
        selected.single.valueNum == null ||
        !selected.single.valueNum!.isFinite ||
        selected.single.valueNum != _pointValue(food, field)) {
      _increment(unresolved, 'point_projection_not_source_bound');
      return null;
    }
    final pointEvidence = selected.single;
    if (!_supportedUnitAndBasis(pointEvidence)) {
      _increment(unresolved, 'point_projection_unit_or_basis_unverified');
      return null;
    }

    final ranges = matching
        .where((evidence) => evidence.qualifierKind == 'range')
        .toList(growable: false);
    if (ranges.isEmpty) {
      _increment(unresolved, 'source_range_not_reported');
      return null;
    }
    if (ranges.any(
      (range) =>
          !_sameScope(pointEvidence, range) ||
          !_hasNumericValueType(range) ||
          !_supportedUnitAndBasis(range) ||
          range.low == null ||
          range.high == null ||
          !range.low!.isFinite ||
          !range.high!.isFinite ||
          range.low! < 0 ||
          range.low! > range.high!,
    )) {
      _increment(unresolved, 'source_range_scope_or_unit_unresolved');
      return null;
    }
    final low = ranges
        .map((range) => range.low!)
        .reduce((left, right) => left < right ? left : right);
    final high = ranges
        .map((range) => range.high!)
        .reduce((left, right) => left > right ? left : right);
    final point = _pointValue(food, field);
    if (point < low || point > high) {
      _increment(unresolved, 'selected_point_outside_reported_range');
      return null;
    }
    return _SupportedRange(low: low, high: high);
  }

  bool _hasNumericValueType(NutrientObservationEvidence evidence) =>
      _numericValueTypes.contains(evidence.valueType?.trim().toLowerCase());

  bool _sameScope(
    NutrientObservationEvidence point,
    NutrientObservationEvidence range,
  ) =>
      point.domain == range.domain &&
      point.entityType == range.entityType &&
      point.entityKey == range.entityKey &&
      point.attributeCode == range.attributeCode &&
      point.sourceDocId != null &&
      point.sourceDocId!.isNotEmpty &&
      point.sourceDocId == range.sourceDocId &&
      point.scopeHash != null &&
      point.scopeHash!.isNotEmpty &&
      point.scopeHash == range.scopeHash &&
      point.unit?.trim().toLowerCase() == range.unit?.trim().toLowerCase() &&
      point.basisType?.trim().toLowerCase() ==
          range.basisType?.trim().toLowerCase() &&
      point.basisAmount == range.basisAmount &&
      point.methodCode == range.methodCode;

  bool _supportedUnitAndBasis(NutrientObservationEvidence evidence) {
    final unit = evidence.unit?.trim().toLowerCase();
    final basis = evidence.basisType?.trim().toLowerCase();
    return unit == 'g' &&
        (basis == 'per_100g' || basis == 'per_100g_edible_part') &&
        evidence.basisAmount == 100;
  }

  List<double> _representativeValues({
    required double low,
    required double high,
    required double currentPoint,
    required List<double> breakpoints,
  }) {
    final boundaries = <double>{low, high};
    for (final breakpoint in breakpoints) {
      if (breakpoint.isFinite && breakpoint >= low && breakpoint <= high) {
        boundaries.add(breakpoint);
      }
    }
    final sortedBoundaries = boundaries.toList()..sort();
    final values = <double>{...sortedBoundaries};
    for (var index = 0; index + 1 < sortedBoundaries.length; index++) {
      final left = sortedBoundaries[index];
      final right = sortedBoundaries[index + 1];
      if (right > left) values.add(left + (right - left) / 2);
    }
    if (currentPoint.isFinite && currentPoint >= low && currentPoint <= high) {
      values.add(currentPoint);
    }
    return values.toList()..sort();
  }

  bool _recommendationChanged(
    FoodRecommendation baseline,
    FoodRecommendation scenario,
  ) {
    if (baseline.score != scenario.score ||
        baseline.decision != scenario.decision ||
        baseline.jurisdiction != scenario.jurisdiction ||
        baseline.fallbackUsed != scenario.fallbackUsed ||
        !_sameStringList(baseline.reasons, scenario.reasons) ||
        !_sameJsonValue(
          baseline.featureSnapshot.toJson(),
          scenario.featureSnapshot.toJson(),
        ) ||
        baseline.scoreBreakdown.length != scenario.scoreBreakdown.length) {
      return true;
    }
    for (final entry in baseline.scoreBreakdown.entries) {
      if (scenario.scoreBreakdown[entry.key] != entry.value) return true;
    }
    return false;
  }

  bool _sameStringList(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  bool _sameJsonValue(Object? left, Object? right) {
    if (left is List && right is List) {
      if (left.length != right.length) return false;
      for (var index = 0; index < left.length; index++) {
        if (!_sameJsonValue(left[index], right[index])) return false;
      }
      return true;
    }
    if (left is Map && right is Map) {
      if (left.length != right.length) return false;
      for (final entry in left.entries) {
        if (!right.containsKey(entry.key) ||
            !_sameJsonValue(entry.value, right[entry.key])) {
          return false;
        }
      }
      return true;
    }
    return left == right;
  }

  FoodItem _withNutrients(FoodItem food, Map<String, double> overrides) =>
      FoodItem(
        id: food.id,
        name: food.name,
        category: food.category,
        aliases: food.aliases,
        description: food.description,
        sourceSystem: food.sourceSystem,
        sourceFoodCode: food.sourceFoodCode,
        jurisdiction: food.jurisdiction,
        textureClass: food.textureClass,
        iddsiLevel: food.iddsiLevel,
        proteinG: overrides['proteinG'] ?? food.proteinG,
        carbsG: food.carbsG,
        fatG: food.fatG,
        fiberG: overrides['fiberG'] ?? food.fiberG,
        sodiumMg: food.sodiumMg,
        missingNutrientFields: food.missingNutrientFields,
        energyKcal: food.energyKcal,
        waterG: food.waterG,
        aminoAcidProfile: food.aminoAcidProfile,
        nutrientObservationEvidence: food.nutrientObservationEvidence,
        catalogProvenanceEvidence: food.catalogProvenanceEvidence,
        basisType: food.basisType,
        preparationState: food.preparationState,
        qualifierKind: food.qualifierKind,
      );

  String _nutrientCode(String field) => switch (field) {
    'proteinG' => 'protein_g',
    'fiberG' => 'fiber_g',
    _ => throw ArgumentError.value(field, 'field'),
  };

  double _pointValue(FoodItem food, String field) => switch (field) {
    'proteinG' => food.proteinG,
    'fiberG' => food.fiberG,
    _ => throw ArgumentError.value(field, 'field'),
  };

  String _candidateName(List<FoodItem> candidates, String id) => candidates
      .firstWhere((food) => food.id == id, orElse: () => _fallbackFood(id))
      .name;

  FoodItem _fallbackFood(String id) => FoodItem(
    id: id,
    name: id,
    category: FoodCategory.other,
    proteinG: 0,
    carbsG: 0,
    fatG: 0,
    fiberG: 0,
    sodiumMg: 0,
  );

  FoodRankSensitivityAssessment _assessment(
    FoodCompositionCandidateSetSnapshot snapshot, {
    required int ranges,
    required int scenarios,
    required Map<String, int> unresolved,
  }) => FoodRankSensitivityAssessment(
    candidateSetSha256: snapshot.sha256Digest,
    supportedRangeFeatureCount: ranges,
    scenariosEvaluated: scenarios,
    unresolvedReasonCounts: unresolved,
    changedCandidateIds: const <String>[],
    topKMembershipChangedIds: const <String>[],
    possibleOrderSwaps: const <FoodRankCandidateSwap>[],
  );

  static void _increment(Map<String, int> values, String key) {
    values[key] = (values[key] ?? 0) + 1;
  }
}

class _RangeDimension {
  final int foodIndex;
  final String field;
  final List<double> values;

  const _RangeDimension({
    required this.foodIndex,
    required this.field,
    required this.values,
  });
}

class _SupportedRange {
  final double low;
  final double high;

  const _SupportedRange({required this.low, required this.high});
}
